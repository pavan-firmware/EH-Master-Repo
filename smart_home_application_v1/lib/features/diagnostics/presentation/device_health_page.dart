import 'dart:async';
import 'package:flutter/material.dart';

import '../../../app/home_controller.dart';
import '../../../core/models/activity_models.dart';
import '../../../core/models/home_dashboard_models.dart';
import '../../../core/models/health_models.dart';
import '../../../core/models/room_models.dart';
import '../../../core/repositories/device_health_repository.dart';
import '../../../core/services/check_timestamp_service.dart';
import '../../activity/presentation/activity_page.dart';
import '../../rooms/presentation/room_context_page.dart';
import '../../settings/presentation/settings_ui.dart';

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

  CheckTimestampService get _timeService =>
      widget.timestampService ?? CheckTimestampService.instance;

  @override
  void initState() {
    super.initState();
    _loadLastChecked();
    _load();
    widget.homeController?.addListener(_onHomeControllerChanged);
    _ticker = Timer.periodic(const Duration(seconds: 15), (_) {
      if (mounted) setState(() {});
    });
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

  HomeHealthSummary _buildRealSummary(HomeController controller, {DateTime? lastChecked}) {
    final devices = controller.devices;
    final onlineList = devices.where((d) => d.online).toList();
    final offlineList = devices.where((d) => !d.online).toList();

    final deviceEntries = devices.map((d) {
      return DeviceHealthEntry(
        deviceId: d.id,
        name: d.name,
        roomId: d.roomName.toLowerCase().replaceAll(' ', '-'),
        roomName: d.roomName.isNotEmpty ? d.roomName : 'Main Space',
        state: d.online ? DeviceHealthState.healthy : DeviceHealthState.offline,
        signal: d.online ? SignalStrength.strong : SignalStrength.unknown,
        lastSeen: DateTime.now(),
        statusLine: d.online ? 'Online · ${d.connectedVia}' : 'Offline · Disconnected',
        iconKey: 'switch',
        reading: d.model,
      );
    }).toList();

    final rooms = controller.rooms.map((r) {
      final roomDevices = devices.where((d) => d.roomName.toLowerCase() == r.name.toLowerCase()).toList();
      final issues = roomDevices.where((d) => !d.online).length;
      return RoomHealthSummary(
        roomId: r.id,
        roomName: r.name,
        deviceCount: roomDevices.length,
        issueCount: issues,
        iconKey: r.iconKey,
      );
    }).toList();

    final isAllOnline = offlineList.isEmpty;
    return HomeHealthSummary(
      overall: isAllOnline ? HomeHealthOverall.healthy : HomeHealthOverall.attention,
      title: isAllOnline ? 'All good!' : '${offlineList.length} device${offlineList.length == 1 ? '' : 's'} offline',
      subtitle: isAllOnline
          ? 'All ${devices.length} devices are online and communicating properly.'
          : 'Some devices require attention or are currently unreachable.',
      statusLabel: isAllOnline ? 'Healthy' : '${offlineList.length} issue${offlineList.length == 1 ? '' : 's'}',
      totalDevices: devices.length,
      onlineCount: onlineList.length,
      attentionCount: offlineList.length,
      offlineCount: offlineList.length,
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
      if (widget.homeController != null && widget.homeController!.devices.isNotEmpty) {
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
        await Future<void>.delayed(const Duration(milliseconds: 600));

        final completionTime = _timeService.now;
        await _timeService.recordSuccessfulCheck(
          CheckTimestampService.deviceHealthKey,
          completionTime,
        );

        if (mounted) {
          setState(() {
            _lastCheckedTime = completionTime;
            _summary = Future.value(_buildRealSummary(ctrl, lastChecked: completionTime));
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
    actions: [
      settingsHelpAction(
        context,
        message:
            'Device health shows connection status, recent communication, and issues that may need attention.',
      ),
    ],
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
              lastCheckedLabel: _timeService.formatDeviceHealthChecked(_lastCheckedTime),
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
                    final ctrl = widget.homeController ?? HomeController.instance;
                    final availableRooms = ctrl?.rooms ?? [];
                    final roomSummary = data.rooms[index];
                    final typed = availableRooms.firstWhere(
                      (r) => r.id == roomSummary.roomId || r.name.toLowerCase() == roomSummary.roomName.toLowerCase(),
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
                        builder: (_) => RoomContextPage(
                          room: typed,
                          homeController: ctrl,
                        ),
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
                subtitle: 'Scan all devices and network',
                onTap: _checking ? null : _checkAgain,
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
            SettingsIconBadge(
              icon: _deviceIcon(entry.iconKey),
              color: _iconColor(entry.state),
              background: _iconBg(entry.state),
              size: 44,
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
                      color: entry.state == DeviceHealthState.attention
                          ? SettingsColors.orange
                          : SettingsColors.green,
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
                Text(
                  entry.signalLabel,
                  style: const TextStyle(
                    fontSize: 11,
                    color: SettingsColors.muted,
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
    final color = bars <= 1 ? SettingsColors.orange : SettingsColors.green;
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

Color _iconColor(DeviceHealthState state) =>
    state == DeviceHealthState.attention
    ? SettingsColors.orange
    : SettingsColors.blue;

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
