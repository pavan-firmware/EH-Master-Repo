import 'package:flutter/material.dart';

import '../../../core/models/device_models.dart';
import '../../../core/models/room_models.dart';
import '../../../core/models/settings_models.dart';
import '../../../core/repositories/connection_repository.dart';
import '../../../core/repositories/settings_repository.dart';
import '../../connection/presentation/connection_page.dart';
import '../../rooms/presentation/room_context_page.dart';
import 'add_room_device_page.dart';
import 'home_details_page.dart';
import 'people_page.dart';
import 'settings_ui.dart';

class HomeProfilePage extends StatelessWidget {
  const HomeProfilePage({
    super.key,
    required this.home,
    required this.repository,
    this.connectionState,
    this.onConnectHome,
  });

  final HomeSettingsData home;
  final SettingsRepository repository;
  final HomeConnectionState? connectionState;
  final Future<ConnectionResult> Function()? onConnectHome;

  @override
  Widget build(BuildContext context) {
    final rooms = RoomCatalog.preview;
    final deviceCount = rooms.fold<int>(
      0,
      (sum, room) => sum + room.deviceCount,
    );
    final attention = rooms
        .where((room) => room.needsAttention)
        .fold<int>(0, (sum, room) => sum + room.deviceCount);
    final online = rooms
        .where((room) => room.isOnline)
        .fold<int>(0, (sum, room) => sum + room.deviceCount);

    return NestedSettingsScaffold(
      title: home.name,
      actions: [
        PopupMenuButton<_HomeProfileAction>(
          tooltip: 'Home actions',
          onSelected: (action) {
            switch (action) {
              case _HomeProfileAction.details:
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        HomeDetailsPage(home: home, repository: repository),
                  ),
                );
              case _HomeProfileAction.people:
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        PeoplePage(repository: repository, home: home),
                  ),
                );
            }
          },
          itemBuilder: (context) => const [
            PopupMenuItem(
              value: _HomeProfileAction.details,
              child: Text('Home details'),
            ),
            PopupMenuItem(
              value: _HomeProfileAction.people,
              child: Text('Manage people'),
            ),
          ],
        ),
      ],
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          _HomeIdentityCard(
            home: home,
            connectionState: connectionState,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    HomeDetailsPage(home: home, repository: repository),
              ),
            ),
            roomCount: rooms.length,
            deviceCount: deviceCount,
          ),
          const SizedBox(height: 24),
          const SettingsSectionTitle('Home overview'),
          _OverviewStats(
            roomCount: rooms.length,
            deviceCount: deviceCount,
            onlineCount: online,
            attentionCount: attention,
          ),
          const SizedBox(height: 24),
          SettingsSectionTitle(
            'Rooms',
            trailing: TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('View all rooms'),
            ),
          ),
          SettingsSurface(
            child: Column(
              children: [
                for (var index = 0; index < rooms.length; index++)
                  _RoomSummaryRow(
                    room: rooms[index],
                    showDivider: index != rooms.length - 1,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => RoomContextPage(room: rooms[index]),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          SettingsSectionTitle(
            'Devices',
            trailing: TextButton(
              onPressed: () => showSettingsUnavailable(
                context,
                message:
                    'Device management will be available after secure home setup.',
              ),
              child: const Text('View all devices'),
            ),
          ),
          SettingsSurface(
            child: SettingsListItem(
              icon: Icons.devices_other_rounded,
              title: '$deviceCount devices',
              subtitle:
                  '$online online · $attention need${attention == 1 ? 's' : ''} attention',
              onTap: () => showSettingsUnavailable(
                context,
                message:
                    'Device management will be available after secure home setup.',
              ),
              trailing: const Icon(
                Icons.chevron_right_rounded,
                color: SettingsColors.muted,
              ),
            ),
          ),
          const SizedBox(height: 24),
          const SettingsSectionTitle('People'),
          SettingsSurface(
            child: SettingsListItem(
              icon: Icons.groups_rounded,
              title: 'People at home',
              subtitle: 'Manage access and invitations',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      PeoplePage(repository: repository, home: home),
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          const SettingsSectionTitle('Home connection'),
          _ConnectionSummary(
            connectionState: connectionState,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => AddRoomDevicePage(
                  repository: repository,
                  onStartSecureSetup: onConnectHome,
                  connectionState: connectionState,
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          const SettingsSectionTitle('Preferences'),
          SettingsSurface(
            child: Column(
              children: [
                SettingsListItem(
                  icon: Icons.thermostat_rounded,
                  title: 'Temperature unit',
                  subtitle: home.preferences.temperatureUnit,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          HomeDetailsPage(home: home, repository: repository),
                    ),
                  ),
                  showDivider: true,
                ),
                SettingsListItem(
                  icon: Icons.notifications_none_rounded,
                  title: 'Home notifications',
                  subtitle: home.preferences.notificationsEnabled
                      ? 'Enabled'
                      : 'Disabled',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          HomeDetailsPage(home: home, repository: repository),
                    ),
                  ),
                  showDivider: true,
                ),
                SettingsListItem(
                  icon: Icons.schedule_rounded,
                  title: 'Time zone',
                  subtitle: home.timezone,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          HomeDetailsPage(home: home, repository: repository),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const SettingsSectionTitle('Advanced'),
          SettingsSurface(
            child: SettingsListItem(
              icon: Icons.remove_circle_outline_rounded,
              title: 'Remove home',
              subtitle: 'Remove this home from the app',
              onTap: () => showSettingsUnavailable(
                context,
                message:
                    'Home management is unavailable until your home is securely connected.',
              ),
              destructive: true,
            ),
          ),
        ],
      ),
    );
  }
}

enum _HomeProfileAction { details, people }

class _HomeIdentityCard extends StatelessWidget {
  const _HomeIdentityCard({
    required this.home,
    required this.connectionState,
    required this.onTap,
    required this.roomCount,
    required this.deviceCount,
  });

  final HomeSettingsData home;
  final HomeConnectionState? connectionState;
  final VoidCallback onTap;
  final int roomCount;
  final int deviceCount;

  @override
  Widget build(BuildContext context) {
    final connection = _connectionPresentation(connectionState);
    return SettingsSurface(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SettingsIconBadge(icon: Icons.home_outlined, size: 76),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      home.name,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    const Text(
                      'Home owner',
                      style: TextStyle(
                        color: SettingsColors.muted,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Icon(
                          connection.icon,
                          color: connection.color,
                          size: 17,
                        ),
                        const SizedBox(width: 7),
                        Expanded(
                          child: Text(
                            connection.label,
                            style: TextStyle(
                              color: connection.color,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '$roomCount rooms   |   $deviceCount devices',
                      style: const TextStyle(color: SettingsColors.muted),
                    ),
                  ],
                ),
              ),
              const Padding(
                padding: EdgeInsets.only(top: 27),
                child: Icon(
                  Icons.chevron_right_rounded,
                  color: SettingsColors.muted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OverviewStats extends StatelessWidget {
  const _OverviewStats({
    required this.roomCount,
    required this.deviceCount,
    required this.onlineCount,
    required this.attentionCount,
  });

  final int roomCount;
  final int deviceCount;
  final int onlineCount;
  final int attentionCount;

  @override
  Widget build(BuildContext context) => SettingsSurface(
    padding: const EdgeInsets.all(10),
    child: Row(
      children: [
        _Stat(
          icon: Icons.meeting_room_outlined,
          value: '$roomCount',
          label: 'Rooms',
          color: SettingsColors.blue,
          background: SettingsColors.paleBlue,
        ),
        _Stat(
          icon: Icons.inventory_2_outlined,
          value: '$deviceCount',
          label: 'Devices',
          color: SettingsColors.green,
          background: SettingsColors.paleGreen,
        ),
        _Stat(
          icon: Icons.check_circle_outline_rounded,
          value: '$onlineCount',
          label: 'Online',
          color: SettingsColors.green,
          background: SettingsColors.paleGreen,
        ),
        _Stat(
          icon: Icons.priority_high_rounded,
          value: '$attentionCount',
          label: 'Attention',
          color: SettingsColors.orange,
          background: SettingsColors.paleOrange,
        ),
      ],
    ),
  );
}

class _Stat extends StatelessWidget {
  const _Stat({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
    required this.background,
  });
  final IconData icon;
  final String value;
  final String label;
  final Color color;
  final Color background;
  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      height: 115,
      margin: const EdgeInsets.symmetric(horizontal: 3),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 23),
          const SizedBox(height: 10),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: SettingsColors.muted, fontSize: 12),
          ),
        ],
      ),
    ),
  );
}

class _RoomSummaryRow extends StatelessWidget {
  const _RoomSummaryRow({
    required this.room,
    required this.showDivider,
    required this.onTap,
  });
  final Room room;
  final bool showDivider;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => SettingsListItem(
    icon: _roomIcon(room.iconKey),
    title: room.name,
    subtitle:
        '${room.deviceCount} ${room.deviceCount == 1 ? 'device' : 'devices'} · ${room.connectivityLabel}',
    onTap: onTap,
    iconColor: room.needsAttention
        ? SettingsColors.orange
        : SettingsColors.green,
    iconBackground: room.needsAttention
        ? SettingsColors.paleOrange
        : SettingsColors.paleGreen,
    showDivider: showDivider,
  );
}

class _ConnectionSummary extends StatelessWidget {
  const _ConnectionSummary({
    required this.connectionState,
    required this.onTap,
  });
  final HomeConnectionState? connectionState;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final connection = _connectionPresentation(connectionState);
    return SettingsSurface(
      child: SettingsListItem(
        icon: Icons.wifi_rounded,
        title: connection.label,
        subtitle: connection.detail,
        onTap: onTap,
        iconColor: connection.color,
        iconBackground: connection.background,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              connection.action,
              style: TextStyle(
                color: connection.color,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: SettingsColors.muted,
            ),
          ],
        ),
      ),
    );
  }
}

class _ConnectionPresentation {
  const _ConnectionPresentation({
    required this.label,
    required this.detail,
    required this.action,
    required this.icon,
    required this.color,
    required this.background,
  });
  final String label;
  final String detail;
  final String action;
  final IconData icon;
  final Color color;
  final Color background;
}

_ConnectionPresentation _connectionPresentation(HomeConnectionState? state) =>
    switch (state) {
      HomeConnectionState.connected => const _ConnectionPresentation(
        label: 'Nearby device connected',
        detail: 'Wi-Fi setup is still required',
        action: 'Continue setup',
        icon: Icons.bluetooth_connected_rounded,
        color: SettingsColors.blue,
        background: SettingsColors.paleBlue,
      ),
      HomeConnectionState.connecting => const _ConnectionPresentation(
        label: 'Connecting…',
        detail: 'Looking for your nearby EH Home device',
        action: 'View',
        icon: Icons.bluetooth_searching_rounded,
        color: SettingsColors.blue,
        background: SettingsColors.paleBlue,
      ),
      HomeConnectionState.offline ||
      HomeConnectionState.failed => const _ConnectionPresentation(
        label: 'Home connection unavailable',
        detail: 'Make sure your home device is powered on',
        action: 'Try again',
        icon: Icons.wifi_off_rounded,
        color: SettingsColors.orange,
        background: SettingsColors.paleOrange,
      ),
      _ => const _ConnectionPresentation(
        label: 'Secure setup required',
        detail: 'Connect your home to unlock device controls',
        action: 'Connect',
        icon: Icons.wifi_off_rounded,
        color: SettingsColors.muted,
        background: Color(0xFFF0F3F7),
      ),
    };

IconData _roomIcon(String key) => switch (key) {
  'living' => Icons.weekend_outlined,
  'kitchen' => Icons.kitchen_outlined,
  'plant' => Icons.local_florist_outlined,
  'water' => Icons.water_drop_outlined,
  _ => Icons.meeting_room_outlined,
};
