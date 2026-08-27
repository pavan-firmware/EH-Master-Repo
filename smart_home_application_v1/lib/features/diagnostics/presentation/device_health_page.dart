import 'package:flutter/material.dart';

import '../../../core/models/activity_models.dart';
import '../../../core/models/health_models.dart';
import '../../../core/models/room_models.dart';
import '../../../core/repositories/device_health_repository.dart';
import '../../activity/presentation/activity_page.dart';
import '../../rooms/presentation/room_context_page.dart';
import '../../settings/presentation/settings_ui.dart';

class DeviceHealthPage extends StatefulWidget {
  const DeviceHealthPage({
    super.key,
    this.repository = const PreviewDeviceHealthRepository(),
  });

  final DeviceHealthRepository repository;

  @override
  State<DeviceHealthPage> createState() => _DeviceHealthPageState();
}

class _DeviceHealthPageState extends State<DeviceHealthPage> {
  late Future<HomeHealthSummary> _summary;
  bool _checking = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    setState(() {
      _summary = widget.repository.getSummary();
    });
  }

  Future<void> _checkAgain() async {
    setState(() => _checking = true);
    final result = await widget.repository.runFullCheck();
    if (mounted) {
      setState(() {
        _summary = Future.value(result);
        _checking = false;
      });
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
                    final typed = RoomCatalog.preview.firstWhere(
                      (r) => r.id == data.rooms[index].roomId,
                      orElse: () => RoomCatalog.preview.first,
                    );
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => RoomContextPage(room: typed),
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
                onTap: _checkAgain,
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
  });

  final HomeHealthSummary summary;
  final bool checking;
  final VoidCallback onCheckAgain;

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
          lastCheckedLabel: 'Last checked: Today, 9:40 AM',
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
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
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
