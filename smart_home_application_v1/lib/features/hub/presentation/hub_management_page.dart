import 'dart:async';
import 'package:flutter/material.dart';
import '../../../app/home_controller.dart';
import '../../../core/services/device_storage_service.dart';
import '../../../core/services/local_lan_device_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../settings/presentation/settings_ui.dart';
import '../data/hub_repository.dart';
import '../domain/models/hub_models.dart';
import 'screens/hub_adopted_devices_screen.dart';
import 'screens/hub_automations_screen.dart';
import 'screens/hub_energy_screen.dart';
import 'screens/hub_integrations_backups_screen.dart';
import 'screens/hub_security_settings_screen.dart';
import 'screens/hub_ui_helpers.dart';
import 'screens/hub_updates_screen.dart';

class HubManagementPage extends StatefulWidget {
  const HubManagementPage({
    super.key,
    this.homeId = 'home_01',
    this.repository,
  });

  final String homeId;
  final HubRepository? repository;

  @override
  State<HubManagementPage> createState() => _HubManagementPageState();
}

class _HubManagementPageState extends State<HubManagementPage> with SingleTickerProviderStateMixin {
  late final HubRepository _repo;
  late Future<HubState> _stateFuture;
  HubState? _loadedState;
  List<Map<String, dynamic>> _hubRoutines = [];
  List<CrossDeviceRule> _crossDeviceRules = [];
  Map<String, dynamic>? _localEnergySummary;
  Map<String, dynamic>? _haStatus;
  bool _isAdopting = false;
  double _adoptionProgress = 0.0;
  String _adoptionStatusText = '';

  // Pairing & Discovery Wizard State
  int _wizardStep = 0; // 0: Overview/Ready, 1: Radar Scanning, 2: Identify & PIN Handshake, 3: Adoption
  String? _scanErrorMessage;
  bool _isBeaconActive = false;
  final TextEditingController _pinController = TextEditingController();
  String? _pinError;

  late AnimationController _radarAnim;
  Timer? _livenessTimer;
  HubConnectionStatus? _lastStatus;
  bool? _lastIsLinked;

  @override
  void initState() {
    super.initState();
    _repo = widget.repository ?? LiveHubRepository();
    _stateFuture = _repo.getHubState(homeId: widget.homeId).then((state) {
      if (mounted) {
        _loadedState = state;
        _lastStatus = state.status;
        _lastIsLinked = state.isLinked;
      }
      return state;
    });
    _radarAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
    _startLivenessHeartbeat();
    _stateFuture.then((state) {
      if (!mounted) return;
      if (state.isLinked) {
        _loadHubSubResources(state.hostname);
      }
    });
  }

  void _loadHubSubResources(String hostname) {
    _repo.getRoutines(hubHostname: hostname).then((routines) {
      if (mounted) setState(() => _hubRoutines = routines);
    });
    _repo.getCrossDeviceRules(hubHostname: hostname).then((rules) {
      if (mounted) setState(() => _crossDeviceRules = rules);
    });
    _repo.getHomeEnergySummary(hubHostname: hostname).then((summary) {
      if (mounted && summary != null) setState(() => _localEnergySummary = summary);
    });
    _repo.getHomeAssistantStatus(hubHostname: hostname).then((ha) {
      if (mounted && ha != null) setState(() => _haStatus = ha);
    });
  }

  void _startLivenessHeartbeat() {
    _livenessTimer?.cancel();
    // Silent 5s liveness heartbeat for linked Hub so disconnects surface quickly without page flashes
    _livenessTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
      if (!mounted) return;
      if (_lastIsLinked != true) return;
      try {
        final state = await _repo.getHubState(homeId: widget.homeId);
        if (!mounted) return;
        if (_lastStatus != state.status ||
            _lastIsLinked != state.isLinked ||
            _loadedState?.connectedDevices.length != state.connectedDevices.length) {
          _lastStatus = state.status;
          _lastIsLinked = state.isLinked;
          setState(() {
            _loadedState = state;
            _stateFuture = Future.value(state);
          });
        }
      } catch (_) {
        if (!mounted) return;
        if (_lastStatus != HubConnectionStatus.unreachable) {
          _lastStatus = HubConnectionStatus.unreachable;
          const offlineState = HubState(status: HubConnectionStatus.unreachable);
          setState(() {
            _loadedState = offlineState;
            _stateFuture = Future.value(offlineState);
          });
        }
      }
    });
  }

  @override
  void dispose() {
    _livenessTimer?.cancel();
    _radarAnim.dispose();
    _pinController.dispose();
    super.dispose();
  }

  void _reload({bool forceSpinner = false}) {
    if (forceSpinner || _loadedState == null) {
      setState(() {
        _stateFuture = _repo.getHubState(homeId: widget.homeId).then((state) {
          if (mounted) {
            _loadedState = state;
            _lastStatus = state.status;
            _lastIsLinked = state.isLinked;
          }
          return state;
        });
      });
    }
    _repo.getHubState(homeId: widget.homeId).then((state) {
      if (!mounted) return;
      setState(() {
        _loadedState = state;
        _lastStatus = state.status;
        _lastIsLinked = state.isLinked;
        _stateFuture = Future.value(state);
      });
      if (state.isLinked) {
        _loadHubSubResources(state.hostname);
      }
    });
  }

  List<Map<String, dynamic>> _collectDevicesForAdoption() {
    final devicesToAdopt = <Map<String, dynamic>>[];
    final ctrl = HomeController.instance;
    if (ctrl != null) {
      for (final d in ctrl.devices) {
        final ip = LocalLanDeviceService.instance.getDeviceIp(d.id);
        if (ip != null && ip.isNotEmpty) {
          final category = HubDeviceCategory.resolve(model: d.model, name: d.name);
          final gangMatch = RegExp(r'(\d)\s*X', caseSensitive: false).firstMatch(d.model);
          final chCount = category == HubDeviceCategory.sensors
              ? 0
              : (gangMatch != null
                  ? (int.tryParse(gangMatch.group(1)!) ?? 3)
                  : (category == HubDeviceCategory.sockets
                      ? 2
                      : (category == HubDeviceCategory.fans ? 1 : 3)));
          final chMap = {for (int ch = 1; ch <= chCount; ch++) ch.toString(): false};
          final preview = HubDeviceInfo(
            id: d.id,
            name: d.name,
            ipAddress: ip,
            macAddress: '',
            roomName: d.roomName,
            online: d.online,
            activeRoutinesCount: 0,
            hasCriticalHardwareFallback: false,
            latencyMs: 3,
            model: d.model,
            firmwareVersion: d.firmware,
            category: category,
            channelCount: chCount,
          );
          devicesToAdopt.add({
            'id': d.id,
            'name': preview.resolveCanonicalName(appCustomName: d.name, appModelVariant: d.model),
            'ipAddress': ip,
            'roomName': d.roomName,
            'model': d.model,
            'firmwareVersion': d.firmware,
            'category': category.name,
            'online': d.online,
            if (d.rssiDbm != null) 'rssiDbm': d.rssiDbm,
            'channelCount': chCount,
            'channels': chMap,
          });
        }
      }
    }

    final allIps = DeviceStorageService.getAllCachedDeviceIps();
    for (final entry in allIps.entries) {
      if (!devicesToAdopt.any((d) => d['id'] == entry.key)) {
        final cached = DeviceStorageService.cachedDevices
            .where((c) => c.id == entry.key)
            .firstOrNull;
        final category = HubDeviceCategory.resolve(
          model: cached?.model,
          name: cached?.name,
        );
        final gangMatch = RegExp(r'(\d)\s*X', caseSensitive: false)
            .firstMatch(cached?.model ?? '');
        final chCount = category == HubDeviceCategory.sensors
            ? 0
            : (gangMatch != null
                ? (int.tryParse(gangMatch.group(1)!) ?? 3)
                : (category == HubDeviceCategory.sockets ? 2 : 3));
        final preview = HubDeviceInfo(
          id: entry.key,
          name: cached?.name ?? '',
          ipAddress: entry.value,
          macAddress: '',
          roomName: cached?.roomName ?? 'Unassigned',
          online: cached?.online ?? false,
          activeRoutinesCount: 0,
          hasCriticalHardwareFallback: false,
          latencyMs: 3,
          model: cached?.model,
          firmwareVersion: cached?.firmware,
          category: category,
          channelCount: chCount,
        );
        devicesToAdopt.add({
          'id': entry.key,
          'name': preview.resolveCanonicalName(
            appCustomName: cached?.name,
            appModelVariant: cached?.model,
          ),
          'ipAddress': entry.value,
          'roomName': cached?.roomName ?? 'Unassigned',
          if (cached?.model != null && cached!.model.isNotEmpty) 'model': cached.model,
          if (cached?.firmware != null && cached!.firmware.isNotEmpty)
            'firmwareVersion': cached.firmware,
          'category': category.name,
          'channelCount': chCount,
          'channels': {for (int ch = 1; ch <= chCount; ch++) ch.toString(): false},
        });
      }
    }
    return devicesToAdopt;
  }

  Future<List<HubDeviceInfo>> _scanAndAdoptForSubScreen(String hostname) async {
    final devicesToAdopt = _collectDevicesForAdoption();
    final adopted = await _repo.adoptDiscoveredSwitches(
      hubHostname: hostname,
      switchIds: devicesToAdopt.map((d) => d['id'] as String).toList(),
      devices: devicesToAdopt,
    );
    _reload();
    return adopted;
  }

  Future<void> _startZeroTouchAdoption(String hostname) async {
    setState(() {
      _isAdopting = true;
      _adoptionProgress = 0.15;
      _adoptionStatusText = 'Broadcasting UDP EH_DISCOVER on port 4210...';
    });

    await Future.delayed(const Duration(milliseconds: 350));
    if (!mounted) return;
    setState(() {
      _adoptionProgress = 0.45;
      _adoptionStatusText = 'Resolving device IPs & capabilities on local Wi-Fi...';
    });

    final devicesToAdopt = _collectDevicesForAdoption();

    await Future.delayed(const Duration(milliseconds: 350));
    if (!mounted) return;
    setState(() {
      _adoptionProgress = 0.85;
      _adoptionStatusText = 'Non-destructive state sync (${devicesToAdopt.length} devices)...';
    });

    await _repo.linkHub(hubHostname: hostname, homeId: widget.homeId);
    await _repo.adoptDiscoveredSwitches(
      hubHostname: hostname,
      switchIds: devicesToAdopt.map((d) => d['id'] as String).toList(),
      devices: devicesToAdopt,
    );

    if (!mounted) return;
    setState(() {
      _adoptionProgress = 1.0;
      _adoptionStatusText = 'Adoption complete! Local mesh active.';
      _isAdopting = false;
      _wizardStep = 0;
    });
    _reload();
  }

  Future<void> _triggerIdentify(String hostname) async {
    setState(() => _isBeaconActive = true);
    await _repo.identifyHub(hubHostname: hostname);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Hub beacon signal sent! LED flashing on physical Hub.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
    await Future.delayed(const Duration(seconds: 4));
    if (mounted) setState(() => _isBeaconActive = false);
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.ehColors;

    return Scaffold(
      backgroundColor: tokens.bgApp,
      appBar: AppBar(
        backgroundColor: tokens.bgApp,
        elevation: 0,
        title: Text(
          'Smart Home Hub',
          style: TextStyle(
            color: tokens.textPrimary,
            fontWeight: FontWeight.w800,
            fontSize: 20,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh_rounded, color: tokens.headerAction),
            tooltip: 'Refresh Status',
            onPressed: () => _reload(forceSpinner: false),
          ),
          IconButton(
            icon: Icon(Icons.help_outline_rounded, color: tokens.headerAction),
            tooltip: 'Hub Guide & FAQ',
            onPressed: () => _showHubGuideModal(context, tokens),
          ),
        ],
      ),
      body: FutureBuilder<HubState>(
        future: _stateFuture,
        builder: (context, snapshot) {
          if (_isAdopting) {
            return _buildAdoptionProgressView(tokens);
          }

          if (snapshot.connectionState == ConnectionState.waiting && _loadedState == null) {
            return const Center(child: CircularProgressIndicator.adaptive());
          }

          final state = snapshot.data ??
              _loadedState ??
              const HubState(status: HubConnectionStatus.notConfigured);
          _loadedState = state;

          if (state.isLinked && state.status == HubConnectionStatus.unreachable) {
            return _buildHubUnreachableView(context, tokens);
          }

          if (!state.isLinked) {
            return _buildUnlinkedSetupWizard(context, tokens, state);
          }

          return _buildHubActiveDashboard(context, tokens, state);
        },
      ),
    );
  }

  Widget _buildHubUnreachableView(BuildContext context, EHThemeTokens tokens) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: tokens.errorContainer.withValues(alpha: 0.25),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.hub_outlined, size: 54, color: tokens.textSecondary),
            ),
            const SizedBox(height: 20),
            Text(
              'Smart Hub Offline',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: tokens.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Cannot reach EH Hub on local network.\nCheck that your Raspberry Pi is powered on and connected to the same Wi-Fi router.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: tokens.textSecondary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _reload,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Retry Discovery'),
              style: FilledButton.styleFrom(
                backgroundColor: tokens.bluePrimary,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAdoptionProgressView(EHThemeTokens tokens) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                color: tokens.successContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.hub_rounded, color: tokens.success, size: 38),
            ),
            const SizedBox(height: 24),
            Text(
              'Zero-Touch Device Adoption',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 21,
                fontWeight: FontWeight.w800,
                color: tokens.textPrimary,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              _adoptionStatusText,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: tokens.textSecondary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 32),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: LinearProgressIndicator(
                value: _adoptionProgress,
                minHeight: 10,
                backgroundColor: tokens.surfaceCard,
                valueColor: AlwaysStoppedAnimation(tokens.success),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              '${(_adoptionProgress * 100).toInt()}% Complete',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: tokens.success,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showHubGuideModal(BuildContext context, EHThemeTokens tokens) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: tokens.surfaceCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetCtx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.75,
          minChildSize: 0.5,
          maxChildSize: 0.92,
          expand: false,
          builder: (ctx, scrollCtrl) {
            return SingleChildScrollView(
              controller: scrollCtrl,
              padding: const EdgeInsets.fromLTRB(22, 16, 22, 36),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 44,
                      height: 4,
                      decoration: BoxDecoration(
                        color: tokens.borderControl,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: tokens.iconBgBlue,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(Icons.hub_rounded, color: tokens.bluePrimary, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Smart Home Hub Architecture',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: tokens.textPrimary,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.close_rounded, color: tokens.textSecondary),
                        onPressed: () => Navigator.pop(sheetCtx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'The EH Smart Hub (Raspberry Pi Platform) acts as a local coordinator and intelligence accelerator for your home.',
                    style: TextStyle(fontSize: 13, color: tokens.textSecondary, height: 1.45),
                  ),
                  const SizedBox(height: 20),

                  // Capabilities Card
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: tokens.bgApp,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: tokens.borderSubtle),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Optional Smart Hub',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: tokens.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Key Capabilities',
                          style: TextStyle(
                            fontSize: 13,
                            color: tokens.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 14),
                        _buildFeatureRow(tokens, Icons.bolt_rounded, 'Sub-5ms Execution', 'Multi-room automations execute instantly over LAN.'),
                        const SizedBox(height: 12),
                        _buildFeatureRow(tokens, Icons.wifi_off_rounded, '100% Offline Autonomy', 'Routines fire on time even if internet fiber is cut.'),
                        const SizedBox(height: 12),
                        _buildFeatureRow(tokens, Icons.memory_rounded, 'Flash Memory Preservation', 'Comfort routines live on Hub RAM, saving switch flash cycles.'),
                        const SizedBox(height: 12),
                        _buildFeatureRow(tokens, Icons.touch_app_rounded, 'Zero-Touch Adoption', 'No resetting switches or re-entering Wi-Fi credentials.'),
                        const SizedBox(height: 12),
                        _buildFeatureRow(tokens, Icons.query_stats_rounded, '365-Day Local Energy', 'On-premise hourly power rollups without cloud subscriptions.'),
                        const SizedBox(height: 12),
                        _buildFeatureRow(tokens, Icons.access_time_rounded, 'RFC 5905 NTP Timekeeper', 'Embedded port 123 clock sync prevents schedule drift in outages.'),
                      ],
                    ),
                  ),

                  const SizedBox(height: 18),

                  // Buyer Guide Card
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: tokens.bgApp,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: tokens.borderSubtle),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.help_outline_rounded, color: tokens.bluePrimary, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              'Do You Need a Hub?',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: tokens.textPrimary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: tokens.successContainer.withValues(alpha: 0.35),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: tokens.success.withValues(alpha: 0.3)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Recommended for:',
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: tokens.success),
                              ),
                              const SizedBox(height: 6),
                              Text('â€¢ Multi-floor homes with concrete walls or Wi-Fi extenders', style: TextStyle(fontSize: 12, color: tokens.textPrimary)),
                              Text('â€¢ Large installations with 20+ devices or cross-room group automations', style: TextStyle(fontSize: 12, color: tokens.textPrimary)),
                              Text('â€¢ Critical offline homes needing schedules during fiber outages', style: TextStyle(fontSize: 12, color: tokens.textPrimary)),
                              Text('â€¢ Home Assistant, Matter, or local MQTT power users', style: TextStyle(fontSize: 12, color: tokens.textPrimary)),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: tokens.surfaceCard,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: tokens.borderSubtle),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'NOT needed for:',
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: tokens.textSecondary),
                              ),
                              const SizedBox(height: 6),
                              Text('â€¢ 1-floor apartments with reliable single-router Wi-Fi coverage', style: TextStyle(fontSize: 12, color: tokens.textSecondary)),
                              Text('â€¢ Direct switch-to-switch Fast-Path UDP (<3ms) is already built-in without a Hub', style: TextStyle(fontSize: 12, color: tokens.textSecondary)),
                              Text('â€¢ On-chip NVS memory runs up to 16 standalone schedules per switch independently', style: TextStyle(fontSize: 12, color: tokens.textSecondary)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _showManualIpDialog(BuildContext context, EHThemeTokens tokens) async {
    final ipCtrl = TextEditingController(text: LiveHubRepository.customHost ?? '192.168.0.');
    final confirmed = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.settings_ethernet_rounded, color: Color(0xFF2563EB)),
            SizedBox(width: 10),
            Text('Connect by IP Address'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter the local IP address or hostname of your Raspberry Pi Smart Hub (e.g. 192.168.0.174 or eh-hub.local):',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: ipCtrl,
              autofocus: true,
              keyboardType: TextInputType.url,
              decoration: InputDecoration(
                labelText: 'Hub Hostname / IP',
                hintText: '192.168.0.174',
                prefixIcon: const Icon(Icons.lan_rounded),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ipCtrl.text.trim()),
            child: const Text('Connect'),
          ),
        ],
      ),
    );

    if (confirmed != null && confirmed.isNotEmpty) {
      LiveHubRepository.customHost = confirmed;
      LiveHubRepository.activeHost = confirmed;
      DeviceStorageService.setPersistedHubHost(confirmed);
      setState(() {
        _wizardStep = 1;
        _scanErrorMessage = null;
      });
      _radarAnim.repeat();
      try {
        final probeState = await _repo.getHubState(homeId: widget.homeId);
        if (!mounted) return;
        _radarAnim.stop();
        if (probeState.status != HubConnectionStatus.unreachable) {
          setState(() {
            _stateFuture = Future.value(probeState);
            _wizardStep = 2;
          });
        } else {
          setState(() {
            _wizardStep = 0;
            _scanErrorMessage = 'Cannot connect to Hub at $confirmed. Verify device IP address and port 4210.';
          });
        }
      } catch (e) {
        if (!mounted) return;
        _radarAnim.stop();
        setState(() {
          _wizardStep = 0;
          _scanErrorMessage = 'Connection error: $e';
        });
      }
    }
  }

  Widget _buildUnlinkedSetupWizard(
    BuildContext context,
    EHThemeTokens tokens,
    HubState state,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 36),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_wizardStep == 0) ...[
            // Remodeled Sleek Hub Discovery Hero Section
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: tokens.surfaceCard,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: tokens.borderSubtle),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: tokens.isDark ? 0.2 : 0.04),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Container(
                    width: 68,
                    height: 68,
                    decoration: BoxDecoration(
                      color: tokens.bluePrimary.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: tokens.bluePrimary.withValues(alpha: 0.35),
                        width: 2,
                      ),
                    ),
                    child: Center(
                      child: Icon(Icons.hub_rounded, color: tokens.bluePrimary, size: 36),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'EH Smart Hub',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: tokens.textPrimary,
                      fontSize: 20,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Connect your Raspberry Pi Hub for local sub-5ms routing, offline schedules, and energy intelligence.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: tokens.textSecondary,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SettingsStatusChip(
                        label: 'LAN Ready',
                        color: tokens.success,
                        background: tokens.successContainer,
                      ),
                      const SizedBox(width: 8),
                      SettingsStatusChip(
                        label: 'Port 4210',
                        color: tokens.bluePrimary,
                        background: tokens.bluePrimary.withValues(alpha: 0.12),
                      ),
                    ],
                  ),
                  if (_scanErrorMessage != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: tokens.errorContainer.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: tokens.error.withValues(alpha: 0.45)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(Icons.warning_amber_rounded, color: tokens.error, size: 20),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  _scanErrorMessage!,
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    color: tokens.isDark ? const Color(0xFFFCA5A5) : const Color(0xFFB91C1C),
                                    height: 1.4,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton.icon(
                              onPressed: () => _showManualIpDialog(context, tokens),
                              icon: const Icon(Icons.settings_ethernet_rounded, size: 16),
                              label: const Text('Connect by IP Address', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                              style: TextButton.styleFrom(
                                foregroundColor: tokens.bluePrimary,
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () async {
                        setState(() {
                          _wizardStep = 1;
                          _scanErrorMessage = null;
                        });
                        _radarAnim.repeat();
                        try {
                          await LocalLanDeviceService.instance.discoverHubNow(timeout: const Duration(milliseconds: 1500));
                          final probeState = await _repo.getHubState(homeId: widget.homeId, allowSubnetSweep: true);
                          if (!mounted) return;
                          _radarAnim.stop();
                          if (probeState.status == HubConnectionStatus.unreachable) {
                            setState(() {
                              _wizardStep = 0;
                              _scanErrorMessage =
                                  'No Smart Hub detected automatically on local Wi-Fi. Ensure your Raspberry Pi is powered and connected to the same Wi-Fi network.';
                            });
                          } else {
                            setState(() {
                              _stateFuture = Future.value(probeState);
                              _wizardStep = 2;
                            });
                          }
                        } catch (e) {
                          if (!mounted) return;
                          _radarAnim.stop();
                          setState(() {
                            _wizardStep = 0;
                            _scanErrorMessage = 'Scan failed: $e. Verify device network connection.';
                          });
                        }
                      },
                      icon: const Icon(Icons.search_rounded),
                      label: const Text('Scan Local Wi-Fi for Hub'),
                      style: FilledButton.styleFrom(
                        backgroundColor: tokens.bluePrimary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => _showManualIpDialog(context, tokens),
                      icon: const Icon(Icons.settings_ethernet_rounded),
                      label: const Text('Connect by IP Address'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: tokens.textPrimary,
                        side: BorderSide(color: tokens.borderControl),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextButton.icon(
                    onPressed: () => _showHubGuideModal(context, tokens),
                    icon: Icon(Icons.help_outline_rounded, size: 16, color: tokens.bluePrimary),
                    label: Text(
                      'Learn about Hub capabilities & requirements',
                      style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: tokens.bluePrimary),
                    ),
                  ),
                ],
              ),
            ),
          ] else if (_wizardStep == 1) ...[
            // Radar Scanning Step
            Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: tokens.surfaceCard,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: tokens.bluePrimary.withValues(alpha: 0.35)),
              ),
              child: Center(
                child: Column(
                  children: [
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        AnimatedBuilder(
                          animation: _radarAnim,
                          builder: (context, _) => Container(
                            width: 80 + (_radarAnim.value * 40),
                            height: 80 + (_radarAnim.value * 40),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: tokens.bluePrimary.withValues(alpha: (1.0 - _radarAnim.value) * 0.3),
                            ),
                          ),
                        ),
                        Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            color: tokens.bluePrimary,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.radar_rounded, color: Colors.white, size: 32),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Scanning Wi-Fi Subnet...',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: tokens.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Listening for _eh-hub._tcp on port 4210',
                      style: TextStyle(fontSize: 12, color: tokens.textSecondary),
                    ),
                  ],
                ),
              ),
            ),
          ] else if (_wizardStep == 2) ...[
            // Hub Found: Device Identification & 6-Digit PIN Handshake
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: tokens.surfaceCard,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: tokens.success.withValues(alpha: 0.45)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: tokens.successContainer,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(Icons.check_circle_rounded, color: tokens.success, size: 24),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'EH Smart Hub Discovered!',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                                color: tokens.textPrimary,
                              ),
                            ),
                            Text(
                              state.model,
                              style: TextStyle(fontSize: 12, color: tokens.textSecondary),
                            ),
                          ],
                        ),
                      ),
                      SettingsStatusChip(
                        label: '${state.latencyMs}ms Direct',
                        color: tokens.success,
                        background: tokens.successContainer,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: tokens.bgApp,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: tokens.borderSubtle),
                    ),
                    child: Column(
                      children: [
                        _buildInfoLine('Hostname', state.hostname, tokens),
                        const SizedBox(height: 6),
                        _buildInfoLine('IP Address', state.ipAddress, tokens),
                        const SizedBox(height: 6),
                        _buildInfoLine('Hardware Platform', state.model, tokens),
                        const SizedBox(height: 6),
                        _buildInfoLine('Port', '4210 (HTTP REST & UDP)', tokens),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Physical Identification Beacon
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _triggerIdentify(state.hostname),
                          icon: Icon(
                            _isBeaconActive ? Icons.flash_on_rounded : Icons.lightbulb_outline_rounded,
                            size: 18,
                            color: tokens.bluePrimary,
                          ),
                          label: Text(_isBeaconActive ? 'Beacon Active...' : 'Identify (Flash LED)'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: tokens.bluePrimary,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const Divider(height: 1),
                  const SizedBox(height: 16),
                  Text(
                    'Security Claim Verification',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: tokens.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Enter the 6-digit setup PIN printed on your Hub case label to establish HMAC ownership.',
                    style: TextStyle(fontSize: 12, color: tokens.textSecondary),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _pinController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Hub Setup Code / PIN',
                      hintText: '842-109',
                      errorText: _pinError,
                      prefixIcon: const Icon(Icons.security_rounded),
                      filled: true,
                      fillColor: tokens.bgApp,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () async {
                        final pin = _pinController.text.trim();
                        final ok = await _repo.verifyHubPin(hubHostname: state.hostname, pin: pin);
                        if (!ok) {
                          setState(() => _pinError = 'Invalid PIN. Check the label on your hub.');
                          return;
                        }
                        setState(() => _pinError = null);
                        await _startZeroTouchAdoption(state.hostname);
                      },
                      icon: const Icon(Icons.verified_user_rounded),
                      label: const Text('Authenticate & Adopt Devices'),
                      style: FilledButton.styleFrom(
                        backgroundColor: tokens.success,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoLine(String label, String value, EHThemeTokens tokens) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 12, color: tokens.textSecondary)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: tokens.textPrimary),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHubActiveDashboard(
    BuildContext context,
    EHThemeTokens tokens,
    HubState state,
  ) {
    final devices = state.connectedDevices;
    final onlineCount = devices.where((d) => d.online).length;
    final categoryCounts = <HubDeviceCategory, int>{};
    for (final d in devices) {
      categoryCounts[d.category] = (categoryCounts[d.category] ?? 0) + 1;
    }

    final haConnected = _haStatus?['mqttConnected'] == true;
    final haEntities = (_haStatus?['entitiesCount'] as num?)?.toInt() ?? 0;
    final haSubtitle = _haStatus == null
        ? 'Manage Home Assistant MQTT, snapshots & webhooks'
        : (haConnected
            ? 'MQTT Connected ($haEntities entities) • Snapshots & webhooks'
            : '$haEntities HA entities ready • Snapshots & webhooks');

    final powerW = (_localEnergySummary?['currentPowerW'] as num?)?.toDouble();
    final energySubtitle = powerW != null && powerW > 0
        ? '${powerW.toStringAsFixed(0)} W live draw • Hourly & 365-day rollups'
        : '365-day offline energy history & rollups';

    final versionLabel = state.firmwareVersion.isNotEmpty
        ? 'Core v${state.firmwareVersion}'
        : 'Release & local binary cache';

    void openSubScreen(Widget screen) {
      Navigator.of(context)
          .push(MaterialPageRoute<void>(builder: (_) => screen))
          .then((_) {
        if (mounted) _reload();
      });
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 36),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (state.isLinked && !LiveHubRepository.isHubActive)
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: const Color(0xFFF59E0B).withValues(alpha: 0.4),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.wifi_tethering_off_rounded,
                    color: Color(0xFFF59E0B),
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Hub Unreachable — Operating in Autonomous LAN Mode',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                            color: Color(0xFFD97706),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Adopted devices keep running critical schedules and wall touch locally.',
                          style: TextStyle(fontSize: 12, color: tokens.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

          // 1. Live Hub Coordinator Hero Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: tokens.surfaceCard,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: tokens.success.withValues(alpha: 0.45)),
              boxShadow: [
                BoxShadow(
                  color: tokens.success.withValues(alpha: 0.08),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: tokens.successContainer,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(Icons.hub_rounded, color: tokens.success, size: 30),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                'Local Hub Active',
                                style: TextStyle(
                                  fontSize: 19,
                                  fontWeight: FontWeight.w800,
                                  color: tokens.textPrimary,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  color: Color(0xFF10B981),
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            state.ipAddress.isNotEmpty
                                ? '${state.hostname} (${state.ipAddress}) • Uptime ${state.uptime}'
                                : '${state.hostname} • Uptime ${state.uptime}',
                            style: TextStyle(fontSize: 12, color: tokens.textSecondary),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        SettingsStatusChip(
                          label: '${state.latencyMs}ms Direct',
                          color: tokens.success,
                          background: tokens.successContainer,
                          leading: Icon(Icons.bolt_rounded, size: 14, color: tokens.success),
                        ),
                        if (state.rssiDbm != null) ...[
                          const SizedBox(height: 6),
                          HubUiHelpers.buildSignalPill(
                            tokens,
                            state.rssiDbm,
                            state.status == HubConnectionStatus.connected,
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                const Divider(height: 1),
                const SizedBox(height: 16),
                Row(
                  children: [
                    HubUiHelpers.buildMetricTile(
                      tokens,
                      'Devices',
                      '${devices.length} ($onlineCount On)',
                      Icons.devices_rounded,
                    ),
                    const SizedBox(width: 10),
                    HubUiHelpers.buildMetricTile(
                      tokens,
                      'Automations',
                      '${_hubRoutines.length} Sch • ${_crossDeviceRules.length} Rules',
                      Icons.schedule_rounded,
                    ),
                    const SizedBox(width: 10),
                    HubUiHelpers.buildMetricTile(
                      tokens,
                      'Storage',
                      state.storageEngine.toUpperCase(),
                      Icons.storage_rounded,
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // 2. High-Frequency Quick Actions
          Row(
            children: [
              Expanded(
                child: _buildActionPill(
                  tokens: tokens,
                  icon: _isBeaconActive ? Icons.flash_on_rounded : Icons.lightbulb_outline_rounded,
                  label: _isBeaconActive ? 'Blinking...' : 'Identify Hub',
                  color: tokens.bluePrimary,
                  onTap: () => _triggerIdentify(state.hostname),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildActionPill(
                  tokens: tokens,
                  icon: Icons.sync_rounded,
                  label: 'Scan & Adopt',
                  color: tokens.success,
                  onTap: () => _startZeroTouchAdoption(state.hostname),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildActionPill(
                  tokens: tokens,
                  icon: Icons.access_time_rounded,
                  label: 'Sync Clock',
                  color: const Color(0xFFF59E0B),
                  onTap: () async {
                    final ok = await _repo.syncTimeBroadcast(hubHostname: state.hostname);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            ok
                                ? 'Local NTP clock synced across Hub devices.'
                                : 'Clock broadcast failed — verify Hub connectivity.',
                          ),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  },
                ),
              ),
            ],
          ),

          const SizedBox(height: 22),

          // 3. Adopted Devices Summary & Quick Launcher (Switches, Sockets, Fans, Sensors & More)
          SettingsSectionTitle(
            'Adopted Devices (${devices.length})',
            trailing: TextButton.icon(
              onPressed: () => openSubScreen(
                HubAdoptedDevicesScreen(
                  repository: _repo,
                  initialState: state,
                  onScanAndAdopt: () => _scanAndAdoptForSubScreen(state.hostname),
                ),
              ),
              icon: const Icon(Icons.open_in_new_rounded, size: 16),
              label: const Text('Manage All'),
              style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
            ),
          ),

          if (categoryCounts.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Wrap(
                spacing: 8,
                runSpacing: 6,
                children: categoryCounts.entries.map((e) {
                  return Chip(
                    avatar: Icon(HubUiHelpers.categoryIcon(e.key), size: 15),
                    label: Text(
                      '${e.key.displayLabel}: ${e.value}',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                    ),
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  );
                }).toList(),
              ),
            ),

          if (devices.isEmpty)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: tokens.surfaceCard,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: tokens.borderSubtle),
              ),
              child: Row(
                children: [
                  Icon(Icons.devices_other_rounded, size: 32, color: tokens.textTertiary),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'No devices adopted yet',
                          style: TextStyle(
                            color: tokens.textPrimary,
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Tap "Scan & Adopt" to adopt switches, sockets, fans, and sensors.',
                          style: TextStyle(color: tokens.textSecondary, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            )
          else
            SettingsSurface(
              child: Column(
                children: [
                  for (int i = 0; i < devices.length && i < 3; i++) ...[
                    if (i > 0) const Divider(height: 1),
                    _buildAdoptedPreviewRow(tokens, state, devices[i], openSubScreen),
                  ],
                  if (devices.length > 3) ...[
                    const Divider(height: 1),
                    ListTile(
                      dense: true,
                      onTap: () => openSubScreen(
                        HubAdoptedDevicesScreen(
                          repository: _repo,
                          initialState: state,
                          onScanAndAdopt: () => _scanAndAdoptForSubScreen(state.hostname),
                        ),
                      ),
                      title: Text(
                        'View & control all ${devices.length} adopted devices',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: tokens.bluePrimary,
                        ),
                      ),
                      trailing: Icon(Icons.chevron_right_rounded, color: tokens.bluePrimary),
                    ),
                  ],
                ],
              ),
            ),

          const SizedBox(height: 24),

          // 4. Nested Hub Management Sub-Screens (Full CRUD & Real Telemetry)
          const SettingsSectionTitle('Hub Subsystems & Settings'),
          SettingsSurface(
            child: Column(
              children: [
                SettingsListItem(
                  icon: Icons.devices_other_rounded,
                  iconBackground: tokens.bluePrimary.withValues(alpha: 0.14),
                  iconColor: tokens.bluePrimary,
                  title: 'Adopted Devices & Hardware Controls',
                  subtitle: '${devices.length} adopted ($onlineCount online) • Categories, Edit & Remove',
                  onTap: () => openSubScreen(
                    HubAdoptedDevicesScreen(
                      repository: _repo,
                      initialState: state,
                      onScanAndAdopt: () => _scanAndAdoptForSubScreen(state.hostname),
                    ),
                  ),
                ),
                const Divider(height: 1),
                SettingsListItem(
                  icon: Icons.auto_awesome_rounded,
                  iconBackground: const Color(0xFF8B5CF6).withValues(alpha: 0.14),
                  iconColor: const Color(0xFF8B5CF6),
                  title: 'Schedules, Timers & Fast Rules',
                  subtitle: '${_hubRoutines.length} schedules • ${_crossDeviceRules.length} P2P rules • Full CRUD',
                  onTap: () => openSubScreen(
                    HubAutomationsScreen(repository: _repo, hubState: state),
                  ),
                ),
                const Divider(height: 1),
                SettingsListItem(
                  icon: Icons.bolt_rounded,
                  iconBackground: tokens.successContainer,
                  iconColor: tokens.success,
                  title: 'Local 365-Day Energy History',
                  subtitle: energySubtitle,
                  onTap: () => openSubScreen(
                    HubEnergyScreen(repository: _repo, hubState: state),
                  ),
                ),
                const Divider(height: 1),
                SettingsListItem(
                  icon: Icons.system_update_rounded,
                  iconBackground: const Color(0xFFF59E0B).withValues(alpha: 0.14),
                  iconColor: const Color(0xFFF59E0B),
                  title: 'Firmware & Local OTA Cache',
                  subtitle: versionLabel,
                  onTap: () => openSubScreen(
                    HubUpdatesScreen(repository: _repo, hubState: state),
                  ),
                ),
                const Divider(height: 1),
                SettingsListItem(
                  icon: Icons.extension_rounded,
                  iconBackground: const Color(0xFF06B6D4).withValues(alpha: 0.14),
                  iconColor: const Color(0xFF06B6D4),
                  title: 'Backups, Home Assistant & Webhooks',
                  subtitle: haSubtitle,
                  onTap: () => openSubScreen(
                    HubIntegrationsBackupsScreen(
                      repository: _repo,
                      hubState: state,
                      onMutated: _reload,
                    ),
                  ),
                ),
                const Divider(height: 1),
                SettingsListItem(
                  icon: Icons.security_rounded,
                  iconBackground: const Color(0xFFEF4444).withValues(alpha: 0.12),
                  iconColor: const Color(0xFFEF4444),
                  title: 'Network, Security & Ownership',
                  subtitle: 'Rotate Hub auth token, restart core, reset or unlink',
                  onTap: () => openSubScreen(
                    HubSecuritySettingsScreen(
                      repository: _repo,
                      hubState: state,
                      onMutated: _reload,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdoptedPreviewRow(
    EHThemeTokens tokens,
    HubState state,
    HubDeviceInfo device,
    void Function(Widget screen) openSubScreen,
  ) {
    final fullName = HubUiHelpers.resolveFullDeviceName(device);
    final statusText = device.online
        ? '${device.category.displayLabel} • ${device.roomName} • Online (${device.latencyMs}ms)'
        : '${device.category.displayLabel} • ${device.roomName} • Offline (Powered Off)';

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: (device.online ? tokens.bluePrimary : tokens.textTertiary)
              .withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          HubUiHelpers.categoryIcon(device.category),
          color: device.online ? tokens.bluePrimary : tokens.textTertiary,
          size: 20,
        ),
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(
              fullName,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 14,
                color: device.online ? tokens.textPrimary : tokens.textSecondary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: (device.online ? tokens.success : const Color(0xFFEF4444))
                  .withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              device.online ? 'Online' : 'Offline',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: device.online ? tokens.success : const Color(0xFFEF4444),
              ),
            ),
          ),
        ],
      ),
      subtitle: Text(
        statusText,
        style: TextStyle(fontSize: 11.5, color: tokens.textSecondary),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Icon(Icons.chevron_right_rounded, color: tokens.textTertiary),
      onTap: () => openSubScreen(
        HubAdoptedDevicesScreen(
          repository: _repo,
          initialState: state,
          onScanAndAdopt: () => _scanAndAdoptForSubScreen(state.hostname),
        ),
      ),
    );
  }

  Widget _buildActionPill({
    required EHThemeTokens tokens,
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: tokens.surfaceCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: tokens.textPrimary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureRow(EHThemeTokens tokens, IconData icon, String title, String subtitle) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: tokens.bluePrimary),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  color: tokens.textPrimary,
                ),
              ),
              Text(
                subtitle,
                style: TextStyle(fontSize: 12, color: tokens.textSecondary),
              ),
            ],
          ),
        ),
      ],
    );
  }

}
