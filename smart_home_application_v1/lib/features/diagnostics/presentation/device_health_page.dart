import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../app/home_controller.dart';
import '../../../core/capabilities/repositories/product_catalog_repository.dart';
import '../../../core/models/activity_models.dart';
import '../../../core/models/home_dashboard_models.dart';
import '../../../core/models/health_models.dart';
import '../../../core/models/room_models.dart';
import '../../../core/repositories/device_health_repository.dart';
import '../../../core/services/check_timestamp_service.dart';
import '../../../core/services/local_lan_device_service.dart';
import '../../../core/services/product_asset_resolver.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/product_image_widget.dart';
import '../../activity/presentation/activity_page.dart';
import '../../hub/data/hub_repository.dart';
import '../../hub/domain/models/hub_models.dart';
import '../../rooms/presentation/room_context_page.dart';
import '../../settings/presentation/settings_ui.dart';

/// Maps a live Wi-Fi RSSI (in dBm) or online state into the 4 discrete
/// signal strength levels used by Device Health cards & graphs:
/// High (>= -60 dBm), Medium (-61 to -74 dBm), Low (<= -75 dBm), Offline (Empty).
SignalStrength classifyDeviceSignal({
  required bool online,
  int? rssiDbm,
  String signalLabel = '',
}) {
  if (!online) return SignalStrength.unknown;
  if (rssiDbm != null && rssiDbm < 0 && rssiDbm > -115) {
    if (rssiDbm >= -60) return SignalStrength.strong;
    if (rssiDbm >= -74) return SignalStrength.good;
    return SignalStrength.weak;
  }
  final lower = signalLabel.toLowerCase();
  if (lower.contains('low') || lower.contains('weak') || lower.contains('poor')) {
    return SignalStrength.weak;
  }
  if (lower.contains('med') || lower.contains('fair') || lower.contains('good')) {
    return SignalStrength.good;
  }
  return SignalStrength.strong;
}

class DeviceHealthPage extends StatefulWidget {
  const DeviceHealthPage({
    super.key,
    this.repository = const PreviewDeviceHealthRepository(),
    this.homeController,
    this.timestampService,
  });

  final DeviceHealthRepository repository;
  final HomeController? homeController;
  final CheckTimestampService? timestampService;

  @override
  State<DeviceHealthPage> createState() => _DeviceHealthPageState();
}

class _DeviceHealthPageState extends State<DeviceHealthPage> {
  late Future<HomeHealthSummary> _summary;
  bool _checking = false;
  DateTime? _lastCheckedTime;
  Timer? _ticker;
  HubState? _hubState;

  CheckTimestampService get _timeService =>
      widget.timestampService ?? CheckTimestampService.instance;

  @override
  void initState() {
    super.initState();
    _loadLastChecked();
    _load();
    unawaited(_refreshHubHealthQuietly());
    widget.homeController?.addListener(_onHomeControllerChanged);
    _ticker = Timer.periodic(const Duration(seconds: 15), (_) {
      if (mounted) setState(() {});
    });
  }

  Future<void> _refreshHubHealthQuietly() async {
    if (!LiveHubRepository.isLinked && LiveHubRepository.activeHost == null) {
      return;
    }
    try {
      final hub = await LiveHubRepository()
          .getHubState(
            homeId: widget.homeController?.activeHomeId,
            allowSubnetSweep: false,
          )
          .timeout(const Duration(milliseconds: 1800));
      if (!mounted) return;
      if (hub.status != HubConnectionStatus.notConfigured) {
        setState(() {
          _hubState = hub;
          if (widget.homeController != null) {
            _summary = Future.value(_buildRealSummary(widget.homeController!));
          }
        });
      }
    } catch (_) {}
  }

  void _onHomeControllerChanged() {
    if (mounted) _load();
  }

  @override
  void didUpdateWidget(covariant DeviceHealthPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.homeController != widget.homeController) {
      oldWidget.homeController?.removeListener(_onHomeControllerChanged);
      widget.homeController?.addListener(_onHomeControllerChanged);
      _load();
    }
  }

  @override
  void dispose() {
    widget.homeController?.removeListener(_onHomeControllerChanged);
    _ticker?.cancel();
    super.dispose();
  }

  Future<void> _loadLastChecked() async {
    final ts = await _timeService.getLastSuccessfulCheck(
      CheckTimestampService.deviceHealthKey,
    );
    if (mounted) {
      setState(() {
        _lastCheckedTime = ts;
      });
    }
  }

  HomeHealthSummary _buildRealSummary(
    HomeController controller, {
    DateTime? lastChecked,
  }) {
    final devices = controller.devices;
    bool devIsOnline(dynamic d) => controller.isDeviceActiveOrOnline(d);
    final offlineList = devices.where((d) => !devIsOnline(d)).toList();

    final deviceEntries = devices.map((d) {
      final isOnline = devIsOnline(d);
      final liveRssi = isOnline
          ? (d.rssiDbm ?? LocalLanDeviceService.instance.getDeviceRssi(d.id))
          : null;
      final sig = classifyDeviceSignal(
        online: isOnline,
        rssiDbm: liveRssi,
        signalLabel: d.signalLabel,
      );
      final rawVia = d.connectedVia.trim();
      final viaLabel = (rawVia.isEmpty || rawVia.toLowerCase() == 'offline')
          ? (d.signalLabel.isNotEmpty && d.signalLabel != 'Offline'
              ? d.signalLabel
              : 'Wi-Fi (Local)')
          : rawVia;
      final statusLine = !isOnline
          ? 'Offline · Disconnected'
          : (sig == SignalStrength.weak
              ? 'Online · Weak Wi-Fi ($viaLabel) — Move closer to router'
              : 'Online · $viaLabel');
      final healthState = !isOnline
          ? DeviceHealthState.offline
          : (sig == SignalStrength.weak
              ? DeviceHealthState.attention
              : DeviceHealthState.healthy);

      return DeviceHealthEntry(
        deviceId: d.id,
        name: d.name,
        roomId: d.roomName.toLowerCase().replaceAll(' ', '-'),
        roomName: d.roomName.isNotEmpty ? d.roomName : 'Main Space',
        state: healthState,
        signal: sig,
        lastSeen: DateTime.now(),
        statusLine: statusLine,
        iconKey: 'switch',
        reading: d.model,
        rssiDbm: liveRssi,
      );
    }).toList();

    // Include Smart Home Hub Coordinator in Device Health whenever linked/discovered
    if (LiveHubRepository.isLinked ||
        LiveHubRepository.activeHost != null ||
        _hubState != null) {
      final hubOnline = LiveHubRepository.isHubActive ||
          _hubState?.status == HubConnectionStatus.connected;
      final hubRssi = _hubState?.rssiDbm;
      final hubSignal = classifyDeviceSignal(
        online: hubOnline,
        rssiDbm: hubRssi,
        signalLabel: hubOnline ? 'Strong' : 'Offline',
      );
      deviceEntries.add(
        DeviceHealthEntry(
          deviceId: _hubState?.hubId ?? 'eh-hub-pi3b',
          name: 'EH Smart Hub Coordinator',
          roomId: 'hub_mesh',
          roomName: 'Gateway (${_hubState?.ipAddress ?? LiveHubRepository.activeHost ?? "eh-hub.local"})',
          state: !hubOnline
              ? DeviceHealthState.offline
              : (hubSignal == SignalStrength.weak
                  ? DeviceHealthState.attention
                  : DeviceHealthState.healthy),
          signal: hubSignal,
          lastSeen: DateTime.now(),
          statusLine: hubOnline
              ? 'Online · Smart Mesh (${_hubState?.latencyMs ?? 3}ms · ${_hubState?.sdCardOverlayFsActive == true ? "OverlayFS Safe" : "SQLite WAL"})'
              : 'Offline · Hub unreachable (Switches autonomous)',
          iconKey: 'hub',
          reading: 'eh-hub',
          rssiDbm: hubOnline ? hubRssi : null,
        ),
      );
    }

    final rooms = controller.rooms.map((r) {
      final roomDevices = devices
          .where((d) => d.roomName.toLowerCase() == r.name.toLowerCase())
          .toList();
      final issues = roomDevices.where((d) => !devIsOnline(d)).length;
      return RoomHealthSummary(
        roomId: r.id,
        roomName: r.name,
        deviceCount: roomDevices.length,
        issueCount: issues,
        iconKey: r.iconKey,
      );
    }).toList();

    final weakCount = deviceEntries
        .where((e) => e.state == DeviceHealthState.attention)
        .length;
    final totalOffline = deviceEntries
        .where((e) => e.state == DeviceHealthState.offline)
        .length;
    final totalIssues = offlineList.length + weakCount;
    final isAllHealthy = offlineList.isEmpty && totalOffline == 0 && weakCount == 0;
    final subtitleText = isAllHealthy
        ? 'All ${deviceEntries.length} devices are online with healthy Wi-Fi signal.'
        : (offlineList.isNotEmpty
            ? 'Some devices require attention or are currently unreachable.'
            : '$weakCount device${weakCount == 1 ? '' : 's'} with low Wi-Fi signal — move closer to router.');

    return HomeHealthSummary(
      overall: isAllHealthy
          ? HomeHealthOverall.healthy
          : HomeHealthOverall.attention,
      title: isAllHealthy
          ? 'All good!'
          : (offlineList.isNotEmpty
              ? '${offlineList.length} device${offlineList.length == 1 ? '' : 's'} offline'
              : '$weakCount weak signal spot${weakCount == 1 ? '' : 's'}'),
      subtitle: subtitleText,
      statusLabel: isAllHealthy
          ? 'Healthy'
          : '${totalIssues > 0 ? totalIssues : 1} issue${totalIssues == 1 ? '' : 's'}',
      totalDevices: deviceEntries.length,
      onlineCount: deviceEntries.where((e) => e.state != DeviceHealthState.offline).length,
      attentionCount: weakCount,
      offlineCount: totalOffline,
      lastChecked: lastChecked ?? _lastCheckedTime ?? DateTime.now(),
      devices: deviceEntries,
      rooms: rooms.isNotEmpty
          ? rooms
          : [
              RoomHealthSummary(
                roomId: 'main',
                roomName: 'Main Space',
                deviceCount: devices.length,
                issueCount: offlineList.length,
                iconKey: 'home',
              ),
            ],
    );
  }

  void _load() {
    setState(() {
      if (widget.homeController != null) {
        _summary = Future.value(_buildRealSummary(widget.homeController!));
      } else {
        _summary = widget.repository.getSummary();
      }
    });
  }

  Future<void> _checkAgain() async {
    if (_checking) return;
    setState(() => _checking = true);

    try {
      final ctrl = widget.homeController ?? HomeController.instance;
      if (ctrl != null && ctrl.devices.isNotEmpty) {
        await ctrl.probeLanAndPromote();
        await _refreshHubHealthQuietly();
        await Future<void>.delayed(const Duration(milliseconds: 600));

        final completionTime = _timeService.now;
        await _timeService.recordSuccessfulCheck(
          CheckTimestampService.deviceHealthKey,
          completionTime,
        );

        if (mounted) {
          setState(() {
            _lastCheckedTime = completionTime;
            _summary = Future.value(
              _buildRealSummary(ctrl, lastChecked: completionTime),
            );
            _checking = false;
          });
        }
      } else {
        final result = await widget.repository.runFullCheck();

        final completionTime = _timeService.now;
        await _timeService.recordSuccessfulCheck(
          CheckTimestampService.deviceHealthKey,
          completionTime,
        );

        if (mounted) {
          setState(() {
            _lastCheckedTime = completionTime;
            _summary = Future.value(result);
            _checking = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _checking = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Device health check failed: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => NestedSettingsScaffold(
    title: 'Device health',
    subtitle: 'Check your devices\' connection, status and performance.',
    child: FutureBuilder<HomeHealthSummary>(
      future: _summary,
      builder: (context, snapshot) {
        if (_checking && !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final data = snapshot.data!;
        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
          children: [
            _HealthHeroCard(
              summary: data,
              checking: _checking,
              onCheckAgain: _checkAgain,
              lastCheckedLabel: _timeService.formatDeviceHealthChecked(
                _lastCheckedTime,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Devices',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                  ),
                ),
                SettingsSectionLink(
                  label: 'See all',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          _AllDevicesPage(devices: data.sortedDevices),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ...data.sortedDevices
                .take(5)
                .map(
                  (d) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _DeviceHealthTile(entry: d),
                  ),
                ),
            const SizedBox(height: 16),
            const Text(
              'Room health',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 148,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: data.rooms.length,
                separatorBuilder: (_, _) => const SizedBox(width: 10),
                itemBuilder: (context, index) => _RoomHealthCard(
                  room: data.rooms[index],
                  onTap: () {
                    final ctrl =
                        widget.homeController ?? HomeController.instance;
                    final availableRooms = ctrl?.rooms ?? [];
                    final roomSummary = data.rooms[index];
                    final typed = availableRooms.firstWhere(
                      (r) =>
                          r.id == roomSummary.roomId ||
                          r.name.toLowerCase() ==
                              roomSummary.roomName.toLowerCase(),
                      orElse: () => Room(
                        id: roomSummary.roomId,
                        name: roomSummary.roomName,
                        iconKey: roomSummary.iconKey,
                        deviceCount: roomSummary.deviceCount,
                        connectivity: ConnectivityCause.deviceOffline,
                        telemetryFreshness: TelemetryFreshness.current,
                        summary: '${roomSummary.deviceCount} device(s)',
                        status: RoomStatus.normal,
                        capabilities: const [],
                        devices: const [],
                        insights: const RoomInsights(
                          energyKwh: '0.0 kWh',
                          energyChange: '0.0 kWh',
                          activeWindow: 'Today',
                          averageTemperature: '24°C',
                          averageHumidity: '55%',
                        ),
                      ),
                    );
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            RoomContextPage(room: typed, homeController: ctrl),
                      ),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 16),
            SettingsSurface(
              child: SettingsListItem(
                icon: Icons.monitor_heart_outlined,
                title: 'Run full health check',
                subtitle: 'Live signal graphs & terminal network diagnostics',
                onTap: _checking
                    ? null
                    : () {
                        final ctrl = widget.homeController ?? HomeController.instance;
                        if (ctrl == null) {
                          _checkAgain();
                          return;
                        }
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => _FullHealthDiagnosticsPage(
                              homeController: ctrl,
                              timestampService: _timeService,
                              onCompleted: () {
                                _loadLastChecked();
                                _load();
                              },
                            ),
                          ),
                        );
                      },
              ),
            ),
          ],
        );
      },
    ),
  );
}

class _HealthHeroCard extends StatelessWidget {
  const _HealthHeroCard({
    required this.summary,
    required this.checking,
    required this.onCheckAgain,
    required this.lastCheckedLabel,
  });

  final HomeHealthSummary summary;
  final bool checking;
  final VoidCallback onCheckAgain;
  final String lastCheckedLabel;

  @override
  Widget build(BuildContext context) => SettingsHeroCard(
    leading: settingsHeroIcon(
      icon: Icons.verified_user_rounded,
      color: SettingsColors.green,
      background: SettingsColors.paleGreen,
    ),
    title: summary.title,
    subtitle: summary.subtitle,
    statusChip: SettingsStatusChip(
      label: summary.statusLabel,
      color: SettingsColors.green,
      background: SettingsColors.paleGreen,
      leading: Container(
        width: 8,
        height: 8,
        decoration: const BoxDecoration(
          color: SettingsColors.green,
          shape: BoxShape.circle,
        ),
      ),
    ),
    trailing: const Icon(
      Icons.eco_outlined,
      color: SettingsColors.green,
      size: 24,
    ),
    footer: Column(
      children: [
        SettingsMetricRow(
          metrics: [
            SettingsMetricItem(
              icon: Icons.smartphone_rounded,
              label: 'Devices',
              value: '${summary.totalDevices}',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      _AllDevicesPage(devices: summary.sortedDevices),
                ),
              ),
            ),
            SettingsMetricItem(
              icon: Icons.wifi_rounded,
              label: 'Online',
              value: '${summary.onlineCount}',
              iconColor: SettingsColors.green,
            ),
            SettingsMetricItem(
              icon: Icons.warning_amber_rounded,
              label: 'Attention',
              value: '${summary.attentionCount}',
              iconColor: SettingsColors.orange,
            ),
            SettingsMetricItem(
              icon: Icons.power_settings_new_rounded,
              label: 'Offline',
              value: '${summary.offlineCount}',
              iconColor: SettingsColors.purple,
            ),
          ],
        ),
        const SizedBox(height: 12),
        SettingsHeroActionFooter(
          lastCheckedLabel: lastCheckedLabel,
          actionLabel: 'Check again',
          onAction: onCheckAgain,
          checking: checking,
        ),
      ],
    ),
  );
}

class _DeviceHealthTile extends StatelessWidget {
  const _DeviceHealthTile({required this.entry});
  final DeviceHealthEntry entry;

  @override
  Widget build(BuildContext context) => SettingsSurface(
    child: InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => DeviceDetailPage(
            device: ActivityDeviceSnapshot(
              id: entry.deviceId,
              name: entry.name,
              room: entry.roomName,
              connection: _mapConnection(entry.state),
              lastSeen: entry.lastSeen ?? DateTime.now(),
              lastReading: entry.reading ?? entry.statusLine,
            ),
          ),
        ),
      ),
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            if (entry.iconKey == 'hub')
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: entry.state == DeviceHealthState.offline
                      ? SettingsColors.paleOrange
                      : SettingsColors.paleGreen,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.hub_rounded,
                  color: entry.state == DeviceHealthState.offline
                      ? SettingsColors.orange
                      : SettingsColors.green,
                  size: 24,
                ),
              )
            else
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: ProductImageWidget(
                  imageUrl: resolveBundledProductAsset(
                    MockProductCatalogRepository.resolveCanonicalProductVariant(
                      variantId: entry.reading,
                      deviceName: entry.name,
                    ),
                  ),
                  size: 44,
                  fallbackIcon: _deviceIcon(entry.iconKey),
                  placeholderColor: _iconBg(entry.state),
                ),
              ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.name,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  Text(
                    entry.roomName,
                    style: const TextStyle(
                      color: SettingsColors.muted,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    entry.statusLine,
                    style: TextStyle(
                      color: entry.state == DeviceHealthState.offline
                          ? const Color(0xFFEF4444)
                          : (entry.state == DeviceHealthState.attention
                              ? SettingsColors.orange
                              : SettingsColors.green),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _SignalBars(strength: entry.signal),
                const SizedBox(height: 2),
                Text(
                  entry.signalLabel,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: entry.signal == SignalStrength.weak
                        ? const Color(0xFFEF4444)
                        : (entry.signal == SignalStrength.unknown
                            ? SettingsColors.muted
                            : SettingsColors.muted),
                  ),
                ),
              ],
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: SettingsColors.muted,
            ),
          ],
        ),
      ),
    ),
  );
}

class _RoomHealthCard extends StatelessWidget {
  const _RoomHealthCard({required this.room, required this.onTap});
  final RoomHealthSummary room;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 148,
    child: SettingsSurface(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                _roomIcon(room.iconKey),
                color: SettingsColors.blue,
                size: 22,
              ),
              const SizedBox(height: 10),
              Text(
                room.roomName,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${room.deviceCount} devices',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: SettingsColors.muted,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 10),
              SettingsStatusChip(
                label: room.statusLabel,
                color: room.isHealthy
                    ? SettingsColors.green
                    : SettingsColors.orange,
                background: room.isHealthy
                    ? SettingsColors.paleGreen
                    : SettingsColors.paleOrange,
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _AllDevicesPage extends StatelessWidget {
  const _AllDevicesPage({required this.devices});
  final List<DeviceHealthEntry> devices;

  @override
  Widget build(BuildContext context) => NestedSettingsScaffold(
    title: 'All devices',
    child: ListView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
      children: devices
          .map(
            (d) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _DeviceHealthTile(entry: d),
            ),
          )
          .toList(),
    ),
  );
}

class _SignalBars extends StatelessWidget {
  const _SignalBars({required this.strength});
  final SignalStrength strength;

  @override
  Widget build(BuildContext context) {
    final bars = switch (strength) {
      SignalStrength.strong => 3,
      SignalStrength.good => 2,
      SignalStrength.weak => 1,
      SignalStrength.unknown => 0,
    };
    final color = switch (strength) {
      SignalStrength.strong => SettingsColors.green,
      SignalStrength.good => const Color(0xFFF59E0B),
      SignalStrength.weak => const Color(0xFFEF4444),
      SignalStrength.unknown => SettingsColors.line,
    };
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 1; i <= 3; i++)
          Container(
            width: 4,
            height: 4 + (i * 4),
            margin: const EdgeInsets.only(left: 2),
            decoration: BoxDecoration(
              color: i <= bars ? color : SettingsColors.line,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
      ],
    );
  }
}

ActivityDeviceConnection _mapConnection(DeviceHealthState state) =>
    switch (state) {
      DeviceHealthState.offline => ActivityDeviceConnection.offline,
      DeviceHealthState.stale => ActivityDeviceConnection.stale,
      DeviceHealthState.unknown => ActivityDeviceConnection.unavailable,
      _ => ActivityDeviceConnection.online,
    };

IconData _deviceIcon(String key) => switch (key) {
  'light' => Icons.lightbulb_outline_rounded,
  'temperature' => Icons.thermostat_rounded,
  'plug' => Icons.power_rounded,
  'water' => Icons.water_drop_outlined,
  'plant' => Icons.eco_outlined,
  'mist' => Icons.water_rounded,
  'air' => Icons.air_rounded,
  'level' => Icons.waves_rounded,
  _ => Icons.sensors_rounded,
};

IconData _roomIcon(String key) => switch (key) {
  'sofa' => Icons.weekend_rounded,
  'kitchen' => Icons.kitchen_rounded,
  'plant' => Icons.eco_outlined,
  'water' => Icons.water_drop_outlined,
  _ => Icons.meeting_room_outlined,
};

Color _iconBg(DeviceHealthState state) => state == DeviceHealthState.attention
    ? SettingsColors.paleOrange
    : SettingsColors.paleBlue;

class TechnicalDetailsPage extends StatelessWidget {
  const TechnicalDetailsPage({super.key});

  @override
  Widget build(BuildContext context) => NestedSettingsScaffold(
    title: 'Technical details',
    child: ListView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
      children: const [
        Text(
          'Diagnostic information for support.',
          style: TextStyle(color: SettingsColors.muted),
        ),
        SizedBox(height: 16),
        SettingsSurface(
          child: Column(
            children: [
              _TechLine('Home device', 'Connected'),
              Divider(height: 1, color: SettingsColors.line),
              _TechLine('Software version', '1.0.0'),
              Divider(height: 1, color: SettingsColors.line),
              _TechLine('Connection', 'Wi-Fi'),
            ],
          ),
        ),
      ],
    ),
  );
}

class _TechLine extends StatelessWidget {
  const _TechLine(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    child: Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(color: SettingsColors.muted),
          ),
        ),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
      ],
    ),
  );
}

enum _DiagLogLevel { info, ok, warn, err }

class _DiagTerminalEntry {
  const _DiagTerminalEntry({
    required this.timestamp,
    required this.level,
    required this.message,
  });

  final String timestamp;
  final _DiagLogLevel level;
  final String message;
}

class _DeviceProbeMetric {
  const _DeviceProbeMetric({
    required this.name,
    required this.endpoint,
    required this.online,
    required this.latencyMs,
    required this.signal,
    this.rssiDbm,
    this.firmware,
    this.isHub = false,
  });

  final String name;
  final String endpoint;
  final bool online;
  final int latencyMs;
  final SignalStrength signal;
  final int? rssiDbm;
  final String? firmware;
  final bool isHub;

  double get signalPercent {
    if (!online) return 0.0;
    if (rssiDbm != null && rssiDbm! < 0 && rssiDbm! > -115) {
      // Map -90 dBm .. -35 dBm cleanly to 10% .. 100%
      final pct = ((rssiDbm! + 95) / 60.0).clamp(0.12, 1.0);
      return pct;
    }
    return switch (signal) {
      SignalStrength.strong => 0.92,
      SignalStrength.good => 0.65,
      SignalStrength.weak => 0.30,
      SignalStrength.unknown => 0.0,
    };
  }
}

class _FullHealthDiagnosticsPage extends StatefulWidget {
  const _FullHealthDiagnosticsPage({
    required this.homeController,
    required this.timestampService,
    required this.onCompleted,
  });

  final HomeController? homeController;
  final CheckTimestampService timestampService;
  final VoidCallback onCompleted;

  @override
  State<_FullHealthDiagnosticsPage> createState() =>
      _FullHealthDiagnosticsPageState();
}

class _FullHealthDiagnosticsPageState
    extends State<_FullHealthDiagnosticsPage> {
  bool _running = true;
  double _progress = 0.0;
  final List<_DiagTerminalEntry> _logs = [];
  final List<_DeviceProbeMetric> _metrics = [];

  @override
  void initState() {
    super.initState();
    unawaited(_runScan());
  }

  String _nowTag() {
    final now = DateTime.now();
    return '${now.hour.toString().padLeft(2, '0')}:'
        '${now.minute.toString().padLeft(2, '0')}:'
        '${now.second.toString().padLeft(2, '0')}';
  }

  void _appendLog(_DiagLogLevel level, String message) {
    if (!mounted) return;
    setState(() {
      _logs.add(
        _DiagTerminalEntry(
          timestamp: _nowTag(),
          level: level,
          message: message,
        ),
      );
    });
  }

  Future<void> _runScan() async {
    setState(() {
      _running = true;
      _progress = 0.05;
      _logs.clear();
      _metrics.clear();
    });

    final ctrl = widget.homeController ?? HomeController.instance;
    final devices = ctrl?.devices ?? const [];
    final hasHubTarget = LiveHubRepository.isLinked ||
        LiveHubRepository.activeHost != null ||
        LocalLanDeviceService.instance.cachedHubHost != null;
    final totalSteps = 1 + (hasHubTarget ? 1 : 0) + (devices.isEmpty ? 1 : devices.length);
    int completedSteps = 0;

    void advanceProgress() {
      completedSteps++;
      if (mounted) {
        setState(() {
          _progress = (completedSteps / totalSteps).clamp(0.1, 1.0);
        });
      }
    }

    _appendLog(_DiagLogLevel.info, r'$ eh-diag --full-scan --targets=wifi,hub,nodes');

    // Step 1: Cloud / Backend Reachability Check
    final cloudWatch = Stopwatch()..start();
    final cloudUp = ctrl?.isCloudReachable ?? false;
    await Future<void>.delayed(const Duration(milliseconds: 120));
    cloudWatch.stop();
    if (cloudUp) {
      _appendLog(
        _DiagLogLevel.ok,
        '[OK]   CLOUD_API    Reachable | Mode=${ctrl?.effectiveConnectionMode.name ?? "auto"} | Check=${cloudWatch.elapsedMilliseconds}ms',
      );
    } else {
      _appendLog(
        _DiagLogLevel.warn,
        '[WARN] CLOUD_API    Unreachable / Local-First active (${ctrl?.routingMode.name ?? "auto"})',
      );
    }
    advanceProgress();

    // Step 2: Smart Hub Gateway Check (if linked or discovered)
    if (hasHubTarget) {
      final hubWatch = Stopwatch()..start();
      HubState hubState = const HubState(status: HubConnectionStatus.unreachable);
      try {
        hubState = await LiveHubRepository()
            .getHubState(homeId: ctrl?.activeHomeId, allowSubnetSweep: false)
            .timeout(const Duration(milliseconds: 2200));
      } catch (_) {}
      hubWatch.stop();
      final hubOk = hubState.status == HubConnectionStatus.connected;
      final hubSig = classifyDeviceSignal(
        online: hubOk,
        rssiDbm: hubState.rssiDbm,
        signalLabel: hubOk ? 'Strong' : 'Offline',
      );
      _metrics.add(
        _DeviceProbeMetric(
          name: 'EH Smart Hub',
          endpoint: '${hubState.ipAddress}:4210',
          online: hubOk,
          latencyMs: hubOk ? hubWatch.elapsedMilliseconds : 0,
          signal: hubSig,
          rssiDbm: hubOk ? hubState.rssiDbm : null,
          firmware: hubState.firmwareVersion,
          isHub: true,
        ),
      );
      if (hubOk) {
        final rssiNote = hubState.rssiDbm != null ? '${hubState.rssiDbm} dBm' : 'LAN Ethernet/Wi-Fi';
        _appendLog(
          hubSig == SignalStrength.weak ? _DiagLogLevel.warn : _DiagLogLevel.ok,
          '${hubSig == SignalStrength.weak ? "[WARN]" : "[OK]  "} HUB_GATEWAY  ${hubState.ipAddress}:4210 | RTT=${hubWatch.elapsedMilliseconds}ms | Signal=$rssiNote | FW=${hubState.firmwareVersion}',
        );
      } else {
        _appendLog(
          _DiagLogLevel.err,
          '[ERR]  HUB_GATEWAY  Timeout / Offline (${LiveHubRepository.activeHost ?? "eh-hub.local"}:4210)',
        );
      }
      advanceProgress();
    }

    // Step 3: Live Probe of Every Commissioned ESP32 Device
    if (devices.isEmpty) {
      _appendLog(_DiagLogLevel.warn, '[WARN] LAN_NODES    No commissioned smart devices found in current space');
      advanceProgress();
    } else {
      await LocalLanDeviceService.instance.autoDiscoverDevices(
        expectedDeviceIds: devices.map((d) => d.id).toList(),
        timeout: const Duration(milliseconds: 650),
        allowSubnetSweep: false,
      );

      for (final d in devices) {
        final ip = LocalLanDeviceService.instance.getDeviceIp(d.id);
        final sw = Stopwatch()..start();
        LanDeviceState? state;
        if (ip != null && ip.isNotEmpty) {
          state = await LocalLanDeviceService.instance.fetchLocalDeviceState(
            deviceId: d.id,
            explicitIp: ip,
          );
        }
        sw.stop();

        final activeRoutine = ctrl?.hasActiveRoutineForDevice(d.id) ?? false;
        final isOnline = (state != null) || d.online || activeRoutine;
        final liveRssi = isOnline
            ? (state?.rssiDbm ?? d.rssiDbm ?? LocalLanDeviceService.instance.getDeviceRssi(d.id))
            : null;
        final sig = classifyDeviceSignal(
          online: isOnline,
          rssiDbm: liveRssi,
          signalLabel: d.signalLabel,
        );
        final fw = state?.firmwareVersion ?? d.firmware;
        final endpointLabel = ip ?? (d.connectedVia.isNotEmpty ? d.connectedVia : 'No LAN IP');

        if (!mounted) return;
        setState(() {
          _metrics.add(
            _DeviceProbeMetric(
              name: d.name,
              endpoint: endpointLabel,
              online: isOnline,
              latencyMs: state != null ? sw.elapsedMilliseconds : 0,
              signal: sig,
              rssiDbm: liveRssi,
              firmware: fw,
            ),
          );
        });

        final tierLabel = switch (sig) {
          SignalStrength.strong => 'HIGH',
          SignalStrength.good => 'MEDIUM',
          SignalStrength.weak => 'LOW',
          SignalStrength.unknown => 'OFFLINE',
        };
        final rssiStr = liveRssi != null ? '$liveRssi dBm ($tierLabel)' : tierLabel;

        if (!isOnline) {
          _appendLog(
            _DiagLogLevel.err,
            '[ERR]  ${d.name} ($endpointLabel)  UNREACHABLE / OFFLINE | Check mains power or Wi-Fi range',
          );
        } else if (sig == SignalStrength.weak) {
          _appendLog(
            _DiagLogLevel.warn,
            '[WARN] ${d.name} ($endpointLabel)  RSSI=$rssiStr | RTT=${state != null ? "${sw.elapsedMilliseconds}ms" : "cloud"} | FW=$fw -> Move closer to router',
          );
        } else if (state == null && activeRoutine) {
          _appendLog(
            _DiagLogLevel.ok,
            '[OK]   ${d.name}  Active Routine Executing | FW=$fw | Online preserved',
          );
        } else {
          _appendLog(
            _DiagLogLevel.ok,
            '[OK]   ${d.name} ($endpointLabel)  RSSI=$rssiStr | RTT=${state != null ? "${sw.elapsedMilliseconds}ms" : "cloud"} | FW=$fw',
          );
        }
        advanceProgress();
      }
    }

    final completionTime = widget.timestampService.now;
    await widget.timestampService.recordSuccessfulCheck(
      CheckTimestampService.deviceHealthKey,
      completionTime,
    );
    widget.onCompleted();

    final onlineCount = _metrics.where((m) => m.online).length;
    final weakCount = _metrics.where((m) => m.signal == SignalStrength.weak).length;
    _appendLog(
      _DiagLogLevel.info,
      '[DONE] Scan complete: $onlineCount/${_metrics.length} online'
      '${weakCount > 0 ? " ($weakCount weak signal)" : ""} | Exit 0',
    );
    if (mounted) {
      setState(() {
        _running = false;
        _progress = 1.0;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.ehColors;
    final maxRtt = _metrics.fold<int>(20, (m, e) => e.latencyMs > m ? e.latencyMs : m);

    return Scaffold(
      backgroundColor: tokens.bgApp,
      appBar: AppBar(
        backgroundColor: tokens.bgApp,
        elevation: 0,
        title: Text(
          'Full Health & Signal Scan',
          style: TextStyle(
            color: tokens.textPrimary,
            fontWeight: FontWeight.w800,
            fontSize: 19,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Copy Terminal Output',
            icon: Icon(Icons.copy_rounded, color: tokens.headerAction),
            onPressed: _logs.isEmpty
                ? null
                : () {
                    final dump = _logs
                        .map((l) => '[${l.timestamp}] ${l.message}')
                        .join('\n');
                    Clipboard.setData(ClipboardData(text: dump));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Diagnostics log copied to clipboard.'),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
          ),
          IconButton(
            tooltip: 'Re-run Scan',
            icon: Icon(Icons.refresh_rounded, color: tokens.headerAction),
            onPressed: _running ? null : _runScan,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        children: [
          if (_running) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(value: _progress, minHeight: 5),
            ),
            const SizedBox(height: 14),
          ],

          // Visual Signal Strength & Latency Graphs Card
          Container(
            padding: const EdgeInsets.all(16),
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
                    Icon(Icons.bar_chart_rounded, color: tokens.bluePrimary, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Live Signal & Latency Telemetry',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                          color: tokens.textPrimary,
                        ),
                      ),
                    ),
                    Text(
                      _running ? 'Probing...' : 'Live',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: _running ? tokens.bluePrimary : tokens.success,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (_metrics.isEmpty)
                  Text(
                    'Collecting real-time metrics from Wi-Fi nodes and Hub...',
                    style: TextStyle(color: tokens.textSecondary, fontSize: 12),
                  )
                else
                  ..._metrics.map((m) {
                    final sigColor = switch (m.signal) {
                      SignalStrength.strong => const Color(0xFF10B981),
                      SignalStrength.good => const Color(0xFFF59E0B),
                      SignalStrength.weak => const Color(0xFFEF4444),
                      SignalStrength.unknown => tokens.textTertiary,
                    };
                    final sigName = switch (m.signal) {
                      SignalStrength.strong => 'High',
                      SignalStrength.good => 'Med',
                      SignalStrength.weak => 'Low',
                      SignalStrength.unknown => 'Offline',
                    };
                    final rssiText = m.rssiDbm != null ? '${m.rssiDbm} dBm ($sigName)' : sigName;
                    final rttFraction = m.online && m.latencyMs > 0
                        ? (m.latencyMs / maxRtt).clamp(0.08, 1.0)
                        : 0.0;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                m.isHub ? Icons.hub_rounded : Icons.memory_rounded,
                                size: 15,
                                color: m.online ? sigColor : tokens.textTertiary,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  m.name,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                    color: tokens.textPrimary,
                                  ),
                                ),
                              ),
                              Text(
                                '$rssiText • ${m.online ? "${m.latencyMs}ms" : "--"}',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: sigColor,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 5),
                          // Signal bar
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: m.signalPercent,
                              minHeight: 7,
                              backgroundColor: tokens.surfaceElevated,
                              valueColor: AlwaysStoppedAnimation<Color>(sigColor),
                            ),
                          ),
                          const SizedBox(height: 4),
                          // Latency bar
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: rttFraction,
                              minHeight: 4,
                              backgroundColor: tokens.surfaceElevated,
                              valueColor: AlwaysStoppedAnimation<Color>(tokens.bluePrimary),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Monospace Terminal Diagnostic Console
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF0B1220),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF1E293B)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: _running ? const Color(0xFFF59E0B) : const Color(0xFF10B981),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'TERMINAL DIAGNOSTICS',
                      style: TextStyle(
                        fontFamily: 'monospace',
                        color: Color(0xFF94A3B8),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                for (final entry in _logs)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 5),
                    child: Text(
                      '[${entry.timestamp}] ${entry.message}',
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 11.5,
                        height: 1.35,
                        color: switch (entry.level) {
                          _DiagLogLevel.ok => const Color(0xFF4ADE80),
                          _DiagLogLevel.warn => const Color(0xFFFBBF24),
                          _DiagLogLevel.err => const Color(0xFFF87171),
                          _DiagLogLevel.info => const Color(0xFF93C5FD),
                        },
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
}
