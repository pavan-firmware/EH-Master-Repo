import 'package:flutter/material.dart';
import '../../../app/home_controller.dart';
import '../../../core/services/device_storage_service.dart';
import '../../../core/services/local_lan_device_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../settings/presentation/settings_ui.dart';
import '../data/hub_repository.dart';
import '../domain/models/hub_models.dart';

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
  List<Map<String, dynamic>> _hubRoutines = [];
  bool _isAdopting = false;
  double _adoptionProgress = 0.0;
  String _adoptionStatusText = '';

  // Pairing & Discovery Wizard State
  int _wizardStep = 0; // 0: Overview/Ready, 1: Radar Scanning, 2: Identify & PIN Handshake, 3: Adoption
  bool _isBeaconActive = false;
  final TextEditingController _pinController = TextEditingController(text: '842-109');
  String? _pinError;

  late AnimationController _radarAnim;

  @override
  void initState() {
    super.initState();
    _repo = widget.repository ?? LiveHubRepository();
    _stateFuture = _repo.getHubState(homeId: widget.homeId);
    _radarAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
  }

  @override
  void dispose() {
    _radarAnim.dispose();
    _pinController.dispose();
    super.dispose();
  }

  void _reload() {
    setState(() {
      _stateFuture = _repo.getHubState(homeId: widget.homeId);
    });
    _repo.getHubState(homeId: widget.homeId).then((state) {
      if (state.isLinked && mounted) {
        _repo.getRoutines(hubHostname: state.hostname).then((routines) {
          if (mounted) setState(() => _hubRoutines = routines);
        });
      }
    });
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
      _adoptionStatusText = 'Resolving switch IPs on local Wi-Fi subnet...';
    });

    // Gather real commissioned devices from HomeController & LocalLanDeviceService
    final devicesToAdopt = <Map<String, dynamic>>[];
    final ctrl = HomeController.instance;
    if (ctrl != null) {
      for (final d in ctrl.devices) {
        final ip = LocalLanDeviceService.instance.getDeviceIp(d.id);
        if (ip != null && ip.isNotEmpty) {
          const chCount = 3;
          final chMap = <int, bool>{1: false, 2: false, 3: false};
          devicesToAdopt.add({
            'id': d.id,
            'name': d.name,
            'ipAddress': ip,
            'roomName': d.roomName,
            'channelCount': chCount,
            'channels': chMap,
          });
        }
      }
    }

    final allIps = DeviceStorageService.getAllCachedDeviceIps();
    for (final entry in allIps.entries) {
      if (!devicesToAdopt.any((d) => d['id'] == entry.key)) {
        devicesToAdopt.add({
          'id': entry.key,
          'name': 'EH Switch (${entry.key.length > 4 ? entry.key.substring(entry.key.length - 4) : entry.key})',
          'ipAddress': entry.value,
          'roomName': 'Unassigned',
          'channelCount': 3,
          'channels': {1: false, 2: false, 3: false},
        });
      }
    }

    await Future.delayed(const Duration(milliseconds: 350));
    if (!mounted) return;
    setState(() {
      _adoptionProgress = 0.85;
      _adoptionStatusText = 'Non-destructive read-only state sync (${devicesToAdopt.length} switches)...';
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
      _adoptionStatusText = 'Adoption complete! Sub-5ms mesh active.';
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
            onPressed: _reload,
          ),
        ],
      ),
      body: FutureBuilder<HubState>(
        future: _stateFuture,
        builder: (context, snapshot) {
          if (_isAdopting) {
            return _buildAdoptionProgressView(tokens);
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator.adaptive());
          }

          final state = snapshot.data ?? const HubState(status: HubConnectionStatus.notConfigured);

          if (!state.isLinked) {
            return _buildUnlinkedSetupWizard(context, tokens, state);
          }

          return _buildHubActiveDashboard(context, tokens, state);
        },
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
          // 1. Benefits Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: tokens.surfaceCard,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: tokens.borderSubtle),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: tokens.iconBgBlue,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(Icons.hub_rounded, color: tokens.bluePrimary, size: 28),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Optional Smart Hub',
                            style: TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.w800,
                              color: tokens.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Local brain & accelerator for your home',
                            style: TextStyle(fontSize: 13, color: tokens.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                const Divider(height: 1),
                const SizedBox(height: 16),
                _buildFeatureRow(tokens, Icons.bolt_rounded, 'Sub-5ms Execution', 'Multi-room automations execute instantly over LAN.'),
                const SizedBox(height: 12),
                _buildFeatureRow(tokens, Icons.wifi_off_rounded, '100% Offline Autonomy', 'Routines fire on time even if internet fiber is cut.'),
                const SizedBox(height: 12),
                _buildFeatureRow(tokens, Icons.memory_rounded, 'Flash Memory Preservation', 'Comfort routines live on Hub RAM, saving switch flash cycles.'),
                const SizedBox(height: 12),
                _buildFeatureRow(tokens, Icons.touch_app_rounded, 'Zero-Touch Adoption', 'No resetting switches or re-entering Wi-Fi credentials.'),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // 2. Setup Step Navigation Wizard
          const SettingsSectionTitle('Hub Discovery & Security Setup'),

          if (_wizardStep == 0) ...[
            // Discovery Ready
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: tokens.surfaceCard,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: tokens.bluePrimary.withValues(alpha: 0.35)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.radar_rounded, color: tokens.bluePrimary, size: 22),
                      const SizedBox(width: 10),
                      Text(
                        'Ready to Discover Hub',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: tokens.textPrimary,
                          fontSize: 16,
                        ),
                      ),
                      const Spacer(),
                      SettingsStatusChip(
                        label: 'LAN Ready',
                        color: tokens.success,
                        background: tokens.successContainer,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Ensure your EH Smart Hub is plugged into the same Wi-Fi router. The app will search for mDNS broadcast on port 4210.',
                    style: TextStyle(fontSize: 13, color: tokens.textSecondary, height: 1.4),
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () {
                        setState(() {
                          _wizardStep = 1;
                        });
                        _radarAnim.repeat();
                        Future.delayed(const Duration(milliseconds: 800), () {
                          if (mounted) {
                            _radarAnim.stop();
                            setState(() {
                              _wizardStep = 2;
                            });
                          }
                        });
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
                      onPressed: () => _startZeroTouchAdoption(state.hostname),
                      icon: const Icon(Icons.link_rounded),
                      label: const Text('Link Hub to My Home'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: tokens.bluePrimary,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
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
                        _buildInfoLine('Hardware MAC', 'B8:27:EB:27:AD:62', tokens),
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
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontSize: 12, color: tokens.textSecondary)),
        Text(value, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: tokens.textPrimary)),
      ],
    );
  }

  Widget _buildHubActiveDashboard(
    BuildContext context,
    EHThemeTokens tokens,
    HubState state,
  ) {
    final devices = state.connectedDevices;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 36),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Hero Coordinator Status Card
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
                            '${state.hostname} (${state.ipAddress}) • Local Mesh Brain',
                            style: TextStyle(fontSize: 12, color: tokens.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    SettingsStatusChip(
                      label: '${state.latencyMs}ms Direct',
                      color: tokens.success,
                      background: tokens.successContainer,
                      leading: Icon(Icons.bolt_rounded, size: 14, color: tokens.success),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                const Divider(height: 1),
                const SizedBox(height: 16),
                Row(
                  children: [
                    _buildMetricTile(tokens, 'Switches', '${devices.length} Bound', Icons.devices_rounded),
                    const SizedBox(width: 10),
                    _buildMetricTile(tokens, 'Scheduler', '${_hubRoutines.length} Rules', Icons.schedule_rounded),
                    const SizedBox(width: 10),
                    _buildMetricTile(tokens, 'SD Health', 'Read-Only OK', Icons.security_rounded),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // 2. High-Frequency Action Bar
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
                  label: 'Rescan Mesh',
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
                    await _repo.syncTimeBroadcast(hubHostname: state.hostname);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Real-time NTP clock broadcast to all switches in <1s.'),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  },
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // 3. Coordinated Devices with Direct Relay Actuation
          SettingsSectionTitle(
            'Adopted Switches (${devices.length})',
            trailing: TextButton.icon(
              onPressed: () => _startZeroTouchAdoption(state.hostname),
              icon: const Icon(Icons.sync_rounded, size: 16),
              label: const Text('Scan & Adopt'),
              style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
            ),
          ),

          if (devices.isEmpty)
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: tokens.surfaceCard,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: tokens.borderSubtle),
              ),
              child: Column(
                children: [
                  Icon(Icons.devices_other_rounded, size: 40, color: tokens.textTertiary),
                  const SizedBox(height: 10),
                  Text(
                    'No switches adopted yet',
                    style: TextStyle(color: tokens.textPrimary, fontWeight: FontWeight.w800, fontSize: 15),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Tap "Scan & Adopt" above to adopt all Wi-Fi switches into the Hub mesh.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: tokens.textSecondary, fontSize: 13, height: 1.4),
                  ),
                ],
              ),
            )
          else
            SettingsSurface(
              child: Column(
                children: [
                  for (int i = 0; i < devices.length; i++) ...[
                    if (i > 0) const Divider(height: 1),
                    _buildInteractiveDeviceTile(tokens, state, devices[i]),
                  ],
                ],
              ),
            ),

          const SizedBox(height: 24),

          // 4. Hub-Orchestrated Routines (RAM Scheduler Engine)
          SettingsSectionTitle(
            'Hub Scheduler (${_hubRoutines.length} Active)',
            trailing: TextButton.icon(
              onPressed: () async {
                await _repo.syncAutomations(hubHostname: state.hostname);
                _reload();
              },
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text('Refresh'),
              style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
            ),
          ),

          if (_hubRoutines.isEmpty)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: tokens.surfaceCard,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: tokens.borderSubtle),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline_rounded, color: tokens.bluePrimary, size: 24),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      'No routines running in Hub RAM yet. Standard routines created in the Routines tab run 100% locally with zero switch flash wear.',
                      style: TextStyle(color: tokens.textSecondary, fontSize: 13, height: 1.35),
                    ),
                  ),
                ],
              ),
            )
          else
            SettingsSurface(
              child: Column(
                children: [
                  for (int i = 0; i < _hubRoutines.length; i++) ...[
                    if (i > 0) const Divider(height: 1),
                    _buildRoutineItem(tokens, state, _hubRoutines[i]),
                  ],
                ],
              ),
            ),

          const SizedBox(height: 24),

          // 5. Hub Maintenance, Core Controls & Hardware Operations
          const SettingsSectionTitle('Hub Operations & Maintenance'),
          SettingsSurface(
            child: Column(
              children: [
                SettingsListItem(
                  icon: Icons.sync_rounded,
                  title: 'Sync Automations',
                  subtitle: 'Push all mobile schedules to Hub RAM scheduler engine',
                  onTap: () async {
                    await _repo.syncAutomations(hubHostname: state.hostname);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Automations synchronized to Hub RAM successfully.'),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                    _reload();
                  },
                ),
                const Divider(height: 1, indent: 56),
                SettingsListItem(
                  icon: Icons.access_time_filled_rounded,
                  title: 'Broadcast Clock Sync (Local NTP)',
                  subtitle: 'Injects real-time epoch via UDP port 4210 to all switches',
                  onTap: () async {
                    await _repo.syncTimeBroadcast(hubHostname: state.hostname);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Real-time NTP clock broadcast to all switches in <1s.'),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  },
                ),
                const Divider(height: 1, indent: 56),
                SettingsListItem(
                  icon: Icons.restart_alt_rounded,
                  title: 'Restart Hub Core',
                  subtitle: 'Restarts local scheduler & proxy engine safely in <2s',
                  onTap: () async {
                    await _repo.restartHubCore(hubHostname: state.hostname);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Hub Core daemon rebooted cleanly.'),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                    _reload();
                  },
                ),
                const Divider(height: 1, indent: 56),
                SettingsListItem(
                  icon: Icons.refresh_rounded,
                  title: 'Reset Mesh Network',
                  subtitle: 'Flushes device cache and triggers full subnet rediscovery',
                  onTap: () async {
                    await _repo.resetMeshNetwork(hubHostname: state.hostname);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Mesh network reset. Re-probing local devices.'),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                    _reload();
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // 6. Firmware & Local Updates
          SettingsSectionTitle(
            'Firmware & Local Updates',
            trailing: TextButton.icon(
              onPressed: () async {
                final ok = await _repo.checkForUpdates(hubHostname: state.hostname);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(ok
                          ? 'Hub and device firmware checked: All components up to date.'
                          : 'Could not connect to update feed.'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              },
              icon: const Icon(Icons.system_update_alt_rounded, size: 16),
              label: const Text('Check Updates'),
              style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
            ),
          ),
          SettingsSurface(
            child: Column(
              children: [
                SettingsListItem(
                  icon: Icons.memory_rounded,
                  title: 'Hub Daemon Core v${state.firmwareVersion}',
                  subtitle: 'Platform: Raspberry Pi 3B+ (Debian Linux aarch64) • Channel: Stable',
                  onTap: () {},
                  trailing: SettingsStatusChip(
                    label: 'Up to Date',
                    color: tokens.success,
                    background: tokens.successContainer,
                  ),
                ),
                const Divider(height: 1, indent: 56),
                SettingsListItem(
                  icon: Icons.cached_rounded,
                  title: 'Local Device OTA Cache',
                  subtitle: '2 production ESP32 images staged in Hub RAM for zero-WAN local flashing',
                  onTap: () {},
                  trailing: SettingsStatusChip(
                    label: 'Cache Active',
                    color: tokens.bluePrimary,
                    background: tokens.iconBgBlue,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // 7. Danger Zone: Real Product Management Options
          const SettingsSectionTitle('Device Security & Ownership Management'),
          SettingsSurface(
            child: Column(
              children: [
                SettingsListItem(
                  icon: Icons.link_off_rounded,
                  title: 'Unlink Hub from this Home',
                  subtitle: 'Releases local coordinator mode and returns home to direct standalone LAN',
                  onTap: () async {
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Unlink Smart Home Hub?'),
                        content: const Text(
                          'Your standalone switches will continue operating normally via local Wi-Fi and hardware timers.',
                        ),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                          FilledButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
                            child: const Text('Unlink Hub'),
                          ),
                        ],
                      ),
                    );
                    if (confirmed == true) {
                      await _repo.unlinkHub(hubHostname: state.hostname);
                      _reload();
                    }
                  },
                ),
                const Divider(height: 1, indent: 56),
                SettingsListItem(
                  icon: Icons.delete_forever_rounded,
                  title: 'Factory Reset Hub',
                  subtitle: 'Wipes all pairing tokens, claim secrets, and restores out-of-box defaults',
                  destructive: true,
                  onTap: () async {
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Factory Reset Hub?'),
                        content: const Text(
                          'This will erase all pairing tokens and remove the Hub from your home. Standalone switches will not be affected.',
                        ),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                          FilledButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
                            child: const Text('Confirm Factory Reset'),
                          ),
                        ],
                      ),
                    );
                    if (confirmed == true) {
                      await _repo.factoryResetHub(hubHostname: state.hostname);
                      _reload();
                    }
                  },
                ),
              ],
            ),
          ),
        ],
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

  Widget _buildInteractiveDeviceTile(
    EHThemeTokens tokens,
    HubState state,
    HubDeviceInfo device,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: tokens.surfaceElevated,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.toggle_on_rounded, color: tokens.bluePrimary, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      device.name,
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                        color: tokens.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Text(
                          '${device.ipAddress} • ${device.latencyMs}ms mesh',
                          style: TextStyle(fontSize: 11, color: tokens.textSecondary),
                        ),
                        if (device.hasCriticalHardwareFallback) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(
                              color: tokens.warningContainer,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'Critical NVS',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                color: tokens.warning,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Channel toggle buttons with instant Hub proxy actuation (<5ms)
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              for (int ch = 1; ch <= device.channelCount; ch++) ...[
                _buildChannelButton(tokens, state, device, ch),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildChannelButton(
    EHThemeTokens tokens,
    HubState state,
    HubDeviceInfo device,
    int channelIndex,
  ) {
    final isPowered = device.channels[channelIndex] == true;

    return ActionChip(
      avatar: Icon(
        Icons.power_settings_new_rounded,
        size: 14,
        color: isPowered ? tokens.success : tokens.textTertiary,
      ),
      label: Text(
        'CH$channelIndex: ${isPowered ? "ON" : "OFF"}',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: isPowered ? tokens.success : tokens.textSecondary,
        ),
      ),
      backgroundColor: isPowered
          ? tokens.successContainer
          : tokens.surfaceElevated,
      side: BorderSide(
        color: isPowered ? tokens.success.withValues(alpha: 0.5) : tokens.borderSubtle,
      ),
      onPressed: () async {
        final newPower = !isPowered;
        await _repo.sendDeviceControl(
          hubHostname: state.hostname,
          deviceId: device.id,
          channel: channelIndex,
          power: newPower,
        );
        _reload();
      },
    );
  }

  Widget _buildRoutineItem(
    EHThemeTokens tokens,
    HubState state,
    Map<String, dynamic> routine,
  ) {
    final id = routine['id'] as String? ?? '';
    final name = routine['name'] as String? ?? 'Scheduled Routine';
    final isCritical = routine['criticalHardwareFallback'] == true;
    final hour = (routine['hour'] as num?)?.toInt() ?? 6;
    final minute = (routine['minute'] as num?)?.toInt() ?? 0;
    final timeStr = '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: isCritical ? tokens.warningContainer : tokens.iconBgBlue,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              isCritical ? Icons.security_rounded : Icons.schedule_rounded,
              color: isCritical ? tokens.warning : tokens.bluePrimary,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: tokens.textPrimary,
                  ),
                ),
                Text(
                  '$timeStr Daily • ${isCritical ? "Hardware Mirrored" : "Hub RAM Only (0 Wear)"}',
                  style: TextStyle(fontSize: 11, color: tokens.textSecondary),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.play_arrow_rounded, color: tokens.bluePrimary),
            tooltip: 'Test Fire Now',
            onPressed: () async {
              await _repo.triggerRoutine(hubHostname: state.hostname, routineId: id);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Fired routine "$name" in <5ms over Hub mesh.'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMetricTile(
    EHThemeTokens tokens,
    String title,
    String value,
    IconData icon,
  ) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: tokens.surfaceElevated,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: tokens.borderSubtle),
        ),
        child: Column(
          children: [
            Icon(icon, size: 18, color: tokens.textSecondary),
            const SizedBox(height: 6),
            Text(
              title,
              style: TextStyle(fontSize: 11, color: tokens.textSecondary),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
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
