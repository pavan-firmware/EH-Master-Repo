import 'package:flutter/material.dart';

import '../../../app/home_controller.dart';
import '../../../core/api/api_client.dart';
import '../../../core/config/app_config.dart';
import '../../../core/models/settings_models.dart';
import '../../../core/repositories/settings_repository.dart';
import '../../../core/services/device_storage_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/iana_timezones.dart';
import 'notification_preferences_page.dart';
import 'people_page.dart';
import 'settings_ui.dart';


class HomeDetailsPage extends StatelessWidget {
  const HomeDetailsPage({
    super.key,
    required this.home,
    required this.repository,
    this.homeController,
  });

  final HomeSettingsData home;
  final SettingsRepository repository;
  final HomeController? homeController;

  @override
  Widget build(BuildContext context) {
    final tokens = context.ehColors;
    final roomCount = homeController?.rooms.length ?? 0;
    final deviceCount = homeController?.devices.length ?? 0;
    return NestedSettingsScaffold(
      title: 'Home details',
      subtitle: "Manage your home's basic information and preferences.",
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          const SettingsSectionTitle('Home overview'),
          SettingsSurface(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          home.name,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: tokens.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '$roomCount ${roomCount == 1 ? "room" : "rooms"} · $deviceCount ${deviceCount == 1 ? "device" : "devices"}',
                          style: TextStyle(
                            fontSize: 13,
                            color: tokens.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: tokens.successContainer,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check_circle_rounded, color: tokens.success, size: 14),
                        const SizedBox(width: 5),
                        Text(
                          'Active',
                          style: TextStyle(
                            color: tokens.success,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          const SettingsSectionTitle('Home identity'),
          SettingsSurface(
            child: Column(
              children: [
                SettingsListItem(
                  icon: Icons.home_outlined,
                  title: 'Home name',
                  subtitle: '${home.name} · Created ${_date(home.createdAt)}',
                  onTap: () => _editHomeName(context),
                  showDivider: true,
                ),
                SettingsListItem(
                  icon: Icons.location_on_outlined,
                  title: 'Location',
                  subtitle: home.location ?? 'Not set',
                  onTap: () => _editLocation(context),
                  iconColor: tokens.isDark
                      ? tokens.success
                      : SettingsColors.green,
                  iconBackground: tokens.isDark
                      ? tokens.iconBgGreen
                      : SettingsColors.paleGreen,
                  showDivider: true,
                ),
                SettingsListItem(
                  icon: Icons.public_rounded,
                  title: 'Time zone',
                  subtitle: home.timezone,
                  onTap: () => _editTimezone(context),
                  iconColor: tokens.isDark
                      ? tokens.iconFgPurple
                      : const Color(0xFF7A3DD5),
                  iconBackground: tokens.isDark
                      ? tokens.iconBgPurple
                      : const Color(0xFFF3ECFF),
                ),
              ],
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
                  onTap: () => _editTemperatureUnit(context),
                  iconColor: tokens.isDark
                      ? tokens.warning
                      : SettingsColors.orange,
                  iconBackground: tokens.isDark
                      ? tokens.iconBgOrange
                      : SettingsColors.paleOrange,
                  showDivider: true,
                ),
                SettingsListItem(
                  icon: Icons.notifications_none_rounded,
                  title: 'Home notifications',
                  subtitle: home.preferences.notificationsEnabled
                      ? 'Enabled'
                      : 'Disabled',
                  onTap: () => _editNotifications(context),
                  showDivider: true,
                ),
                SettingsListItem(
                  icon: Icons.schedule_rounded,
                  title: 'Time format',
                  subtitle: home.preferences.timeFormat,
                  onTap: () => _editTimeFormat(context),
                  iconColor: tokens.isDark
                      ? tokens.iconFgPurple
                      : const Color(0xFF7A3DD5),
                  iconBackground: tokens.isDark
                      ? tokens.iconBgPurple
                      : const Color(0xFFF3ECFF),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const SettingsSectionTitle('Home status'),
          SettingsSurface(
            child: Column(
              children: [
                Builder(
                  builder: (context) {
                    final effectiveHomeId = (homeController?.activeHomeId != null && homeController!.activeHomeId!.isNotEmpty)
                        ? homeController!.activeHomeId
                        : ((home.id.isNotEmpty && home.id != 'home_default')
                            ? home.id
                            : (DeviceStorageService.cachedActiveHomeId ?? homeController?.activeSpaceId));
                    final hasResolvedHome = effectiveHomeId != null && effectiveHomeId.isNotEmpty && effectiveHomeId != 'home_default';
                    final hasConnectedDevices = homeController?.devices.any((d) => d.online) ?? false;
                    final isLocalActive = homeController?.isLocalMode == true;
                    final isConnected = hasResolvedHome || hasConnectedDevices || isLocalActive;

                    final String statusSubtitle = isLocalActive
                        ? 'Connected (Local Mode)'
                        : (isConnected ? 'Connected' : 'No home selected');

                    final String statusTrailing = isLocalActive
                        ? 'Local'
                        : (isConnected ? 'Online' : 'Set up');

                    final Color statusColor = isConnected ? tokens.success : tokens.warning;

                    return SettingsListItem(
                      icon: Icons.wifi_rounded,
                      title: 'Home connection',
                      subtitle: statusSubtitle,
                      onTap: () {
                        showModalBottomSheet<void>(
                          context: context,
                          isScrollControlled: true,
                          backgroundColor: Colors.transparent,
                          builder: (ctx) => _HomeConnectionDiagnosticsSheet(
                            homeController: homeController,
                            activeHomeId: effectiveHomeId ?? home.id,
                          ),
                        );
                      },
                      iconColor: tokens.isDark
                          ? tokens.success
                          : SettingsColors.green,
                      iconBackground: tokens.isDark
                          ? tokens.iconBgGreen
                          : SettingsColors.paleGreen,
                      trailing: Text(
                        statusTrailing,
                        style: TextStyle(
                          color: statusColor,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      showDivider: true,
                    );
                  },
                ),
                SettingsListItem(
                  icon: Icons.meeting_room_outlined,
                  title: 'Rooms',
                  subtitle: 'Total rooms in this home',
                  onTap: () => _showRoomsSheet(context),
                  trailing: Text(
                    '$roomCount',
                    style: TextStyle(
                      color: tokens.textSecondary,
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                  showDivider: true,
                ),
                SettingsListItem(
                  icon: Icons.inventory_2_outlined,
                  title: 'Devices',
                  subtitle: 'Active connected devices',
                  onTap: () => _showDevicesSheet(context),
                  iconColor: tokens.isDark
                      ? tokens.success
                      : SettingsColors.green,
                  iconBackground: tokens.isDark
                      ? tokens.iconBgGreen
                      : SettingsColors.paleGreen,
                  trailing: Text(
                    '$deviceCount',
                    style: TextStyle(
                      color: tokens.textSecondary,
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                  showDivider: true,
                ),
                SettingsListItem(
                  icon: Icons.groups_outlined,
                  title: 'People',
                  subtitle: 'People with access',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => PeoplePage(repository: repository, home: home),
                    ),
                  ),
                  iconColor: tokens.isDark
                      ? tokens.iconFgPurple
                      : const Color(0xFF7A3DD5),
                  iconBackground: tokens.isDark
                      ? tokens.iconBgPurple
                      : const Color(0xFFF3ECFF),
                  trailing: Icon(
                    Icons.chevron_right_rounded,
                    color: tokens.chevron,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const SettingsSectionTitle('Advanced'),
          SettingsSurface(
            child: SettingsListItem(
              icon: Icons.badge_outlined,
              title: 'Home ID',
              subtitle: home.id,
              onTap: () => _copyHomeId(context),
              iconColor: tokens.textSecondary,
              iconBackground: tokens.surfaceElevated,
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.copy_rounded, color: tokens.bluePrimary, size: 18),
                  const SizedBox(width: 5),
                  Text(
                    'Copy',
                    style: TextStyle(
                      color: tokens.bluePrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              'Home ID is used only for support and troubleshooting.',
              style: TextStyle(color: tokens.textSecondary, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _editHomeName(BuildContext context) async {
    final draftName = await showDialog<String>(
      context: context,
      builder: (dialogContext) => _HomeNameDialog(initialName: home.name),
    );
    if (draftName == null || !context.mounted) return;
    final result = await repository.updateHome(
      HomeSettingsDraft(
        name: draftName,
        location: home.location,
        timezone: home.timezone,
        preferences: home.preferences,
      ),
    );
    if (!context.mounted) return;
    if (result == SettingsOperationResult.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Home name updated to "$draftName".'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      showSettingsUnavailable(context, message: 'Could not update home name. Please retry.');
    }
  }

  Future<void> _editLocation(BuildContext context) async {
    final draftLocation = await showDialog<String>(
      context: context,
      builder: (dialogContext) => _HomeLocationDialog(initialLocation: home.location ?? ''),
    );
    if (draftLocation == null || !context.mounted) return;
    final result = await repository.updateHome(
      HomeSettingsDraft(
        name: home.name,
        location: draftLocation,
        timezone: home.timezone,
        preferences: home.preferences,
      ),
    );
    if (!context.mounted) return;
    if (result == SettingsOperationResult.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Home location updated.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _editTimezone(BuildContext context) async {
    final selected = await showIanaTimezonePicker(
      context,
      initialValue: home.timezone,
    );
    if (selected == null || !context.mounted) return;
    final result = await repository.updateHome(
      HomeSettingsDraft(
        name: home.name,
        location: home.location,
        timezone: selected,
        preferences: home.preferences,
      ),
    );
    if (!context.mounted) return;
    if (result == SettingsOperationResult.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Timezone updated to $selected.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _editTemperatureUnit(BuildContext context) async {
    final selected = await showDialog<String>(
      context: context,
      builder: (dCtx) => SimpleDialog(
        title: const Text('Temperature Unit'),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(dCtx, 'Celsius (°C)'),
            child: const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text('Celsius (°C)'),
            ),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(dCtx, 'Fahrenheit (°F)'),
            child: const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text('Fahrenheit (°F)'),
            ),
          ),
        ],
      ),
    );
    if (selected == null || !context.mounted) return;
    final newPrefs = HomePreferences(
      temperatureUnit: selected,
      notificationsEnabled: home.preferences.notificationsEnabled,
      timeFormat: home.preferences.timeFormat,
    );
    await DeviceStorageService.saveHomePreferencesJson({
      'temperatureUnit': selected,
      'notificationsEnabled': home.preferences.notificationsEnabled,
      'timeFormat': home.preferences.timeFormat,
    });
    await repository.updateHome(
      HomeSettingsDraft(
        name: home.name,
        location: home.location,
        timezone: home.timezone,
        preferences: newPrefs,
      ),
    );
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Temperature unit updated to $selected.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _editNotifications(BuildContext context) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const NotificationPreferencesPage(),
      ),
    );
  }


  Future<void> _editTimeFormat(BuildContext context) async {
    final selected = await showDialog<String>(
      context: context,
      builder: (dCtx) => SimpleDialog(
        title: const Text('Time Format'),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(dCtx, '12-hour'),
            child: const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text('12-hour (e.g. 2:30 PM)'),
            ),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(dCtx, '24-hour'),
            child: const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text('24-hour (e.g. 14:30)'),
            ),
          ),
        ],
      ),
    );
    if (selected == null || !context.mounted) return;
    final newPrefs = HomePreferences(
      temperatureUnit: home.preferences.temperatureUnit,
      notificationsEnabled: home.preferences.notificationsEnabled,
      timeFormat: selected,
    );
    await DeviceStorageService.saveHomePreferencesJson({
      'temperatureUnit': home.preferences.temperatureUnit,
      'notificationsEnabled': home.preferences.notificationsEnabled,
      'timeFormat': selected,
    });
    await repository.updateHome(
      HomeSettingsDraft(
        name: home.name,
        location: home.location,
        timezone: home.timezone,
        preferences: newPrefs,
      ),
    );
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Time format updated to $selected.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _copyHomeId(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Home ID ${home.id} copied.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showRoomsSheet(BuildContext context) {
    final tokens = context.ehColors;
    final rooms = homeController?.rooms ?? [];
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: tokens.surfaceCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Rooms in ${home.name}',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: tokens.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '${rooms.length} configured room${rooms.length == 1 ? '' : 's'}',
                style: TextStyle(color: tokens.textSecondary, fontSize: 14),
              ),
              const SizedBox(height: 16),
              if (rooms.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Center(
                    child: Text(
                      'No rooms configured yet.',
                      style: TextStyle(color: tokens.textSecondary),
                    ),
                  ),
                )
              else
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: rooms.length,
                    separatorBuilder: (_, _) => Divider(height: 1, color: tokens.borderSubtle),
                    itemBuilder: (c, idx) {
                      final r = rooms[idx];
                      return ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: tokens.iconBgBlue,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(Icons.meeting_room_outlined, color: tokens.bluePrimary, size: 20),
                        ),
                        title: Text(r.name, style: TextStyle(color: tokens.textPrimary, fontWeight: FontWeight.w700)),
                        subtitle: Text('${r.deviceCount} device${r.deviceCount == 1 ? '' : 's'}', style: TextStyle(color: tokens.textSecondary, fontSize: 13)),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDevicesSheet(BuildContext context) {
    final tokens = context.ehColors;
    final devices = homeController?.devices ?? [];
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: tokens.surfaceCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Connected Devices',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: tokens.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '${devices.length} registered device${devices.length == 1 ? '' : 's'} in ${home.name}',
                style: TextStyle(color: tokens.textSecondary, fontSize: 14),
              ),
              const SizedBox(height: 16),
              if (devices.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Center(
                    child: Text(
                      'No devices connected yet.',
                      style: TextStyle(color: tokens.textSecondary),
                    ),
                  ),
                )
              else
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: devices.length,
                    separatorBuilder: (_, _) => Divider(height: 1, color: tokens.borderSubtle),
                    itemBuilder: (c, idx) {
                      final d = devices[idx];
                      return ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: d.online ? tokens.iconBgGreen : tokens.iconBgOrange,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            d.online ? Icons.check_circle_rounded : Icons.sensors_off_rounded,
                            color: d.online ? tokens.success : tokens.warning,
                            size: 20,
                          ),
                        ),
                        title: Text(d.name, style: TextStyle(color: tokens.textPrimary, fontWeight: FontWeight.w700)),
                        subtitle: Text(
                          '${d.model} · ${d.roomName.isNotEmpty ? d.roomName : "Main Space"} · ${d.connectedVia}',
                          style: TextStyle(color: tokens.textSecondary, fontSize: 13),
                        ),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: d.online ? tokens.iconBgGreen : tokens.iconBgOrange,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            d.online ? 'Online' : 'Offline',
                            style: TextStyle(
                              color: d.online ? tokens.success : tokens.warning,
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

String _date(DateTime value) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${months[value.month - 1]} ${value.day}, ${value.year}';
}

class _HomeNameDialog extends StatefulWidget {
  const _HomeNameDialog({required this.initialName});
  final String initialName;

  @override
  State<_HomeNameDialog> createState() => _HomeNameDialogState();
}

class _HomeNameDialogState extends State<_HomeNameDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialName);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Home name'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        maxLength: 48,
        decoration: const InputDecoration(
          hintText: 'What would you like to call your home?',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            final name = _controller.text.trim();
            if (name.isNotEmpty) Navigator.pop(context, name);
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}

class _HomeLocationDialog extends StatefulWidget {
  const _HomeLocationDialog({required this.initialLocation});
  final String initialLocation;

  @override
  State<_HomeLocationDialog> createState() => _HomeLocationDialogState();
}

class _HomeLocationDialogState extends State<_HomeLocationDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialLocation);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Home location'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        decoration: const InputDecoration(
          hintText: 'e.g. Hyderabad, Telangana, India',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            final loc = _controller.text.trim();
            Navigator.pop(context, loc);
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}

class _HomeConnectionDiagnosticsSheet extends StatefulWidget {

  const _HomeConnectionDiagnosticsSheet({
    required this.homeController,
    required this.activeHomeId,
  });

  final HomeController? homeController;
  final String activeHomeId;

  @override
  State<_HomeConnectionDiagnosticsSheet> createState() => _HomeConnectionDiagnosticsSheetState();
}

class _HomeConnectionDiagnosticsSheetState extends State<_HomeConnectionDiagnosticsSheet> {
  int? _latencyMs;
  bool _pingTimedOut = false;
  bool _isPinging = false;
  bool _isProbingLan = false;

  @override
  void initState() {
    super.initState();
    _testPing();
  }

  Future<void> _testPing() async {
    setState(() {
      _isPinging = true;
      _pingTimedOut = false;
    });
    final stopwatch = Stopwatch()..start();
    try {
      final client = ApiClient(baseUrl: AppConfig.backendBaseUrl);
      await client.get('/api/v1/health').timeout(const Duration(seconds: 3));
      stopwatch.stop();
      if (mounted) {
        setState(() {
          _latencyMs = stopwatch.elapsedMilliseconds;
          _pingTimedOut = false;
          _isPinging = false;
        });
      }
    } catch (_) {
      stopwatch.stop();
      if (mounted) {
        setState(() {
          _latencyMs = null;
          _pingTimedOut = true;
          _isPinging = false;
        });
      }
    }
  }

  Future<void> _probeLan() async {
    setState(() => _isProbingLan = true);
    try {
      final count = await widget.homeController?.probeLanAndPromote() ?? false;
      if (mounted) {
        setState(() => _isProbingLan = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(count ? 'LAN scan discovered responsive smart devices!' : 'LAN scan complete. Fleet synchronized.'),
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (_) {
      if (mounted) setState(() => _isProbingLan = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.ehColors;
    final devices = widget.homeController?.devices ?? [];
    final onlineCount = devices.where((d) => d.online).length;
    final isCloudReachable = widget.homeController?.isCloudReachable ?? false;
    final isLocalMode = widget.homeController?.isLocalMode ?? false;
    final hasOnlineDevices = onlineCount > 0;

    final bool isConnected = isCloudReachable || isLocalMode || hasOnlineDevices;

    final String statusBadge;
    final Color statusColor;
    final String statusSubtitle;

    if (isCloudReachable && (isLocalMode || hasOnlineDevices)) {
      statusBadge = 'Online';
      statusColor = const Color(0xFF10B981);
      statusSubtitle = 'Active over Local LAN & Cloud MQTT';
    } else if (isLocalMode || hasOnlineDevices) {
      statusBadge = 'Local Mode';
      statusColor = tokens.bluePrimary;
      statusSubtitle = 'Local Wi-Fi Mode Active (Direct Device Control)';
    } else if (isCloudReachable) {
      statusBadge = 'Cloud Only';
      statusColor = const Color(0xFF10B981);
      statusSubtitle = 'Connected to Cloud (Scanning for Devices)';
    } else {
      statusBadge = 'Offline';
      statusColor = const Color(0xFFF59E0B);
      statusSubtitle = 'Disconnected / Standalone mode';
    }

    return Container(
      decoration: BoxDecoration(
        color: tokens.surfaceCard,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(context).viewInsets.bottom + 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
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
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: isConnected
                      ? statusColor.withValues(alpha: 0.12)
                      : const Color(0xFFF59E0B).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  isConnected ? Icons.wifi_rounded : Icons.wifi_off_rounded,
                  color: isConnected ? statusColor : const Color(0xFFF59E0B),
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Connection Diagnostics',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: tokens.textPrimary),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      statusSubtitle,
                      style: TextStyle(fontSize: 12.5, color: tokens.textSecondary),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  statusBadge,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: tokens.bgSecondary,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: tokens.borderSubtle),
            ),
            child: Column(
              children: [
                _statRow('Home Identifier', widget.activeHomeId, tokens),
                const Divider(height: 18),
                _statRow('Active Host Gateway', AppConfig.backendBaseUrl, tokens),
                const Divider(height: 18),
                _statRow('Primary Transport', widget.homeController?.isLocalMode == true ? 'Direct LAN Wi-Fi' : 'Cloud MQTT Mesh', tokens),
                const Divider(height: 18),
                _statRow('Fleet Nodes Online', '$onlineCount / ${devices.length} registered', tokens),
                const Divider(height: 18),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Ping Roundtrip', style: TextStyle(fontSize: 13, color: tokens.textSecondary)),
                    if (_isPinging)
                      const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                    else
                      Text(
                        _latencyMs != null
                            ? '$_latencyMs ms'
                            : (_pingTimedOut ? 'Timed out' : 'Unreachable'),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: _latencyMs != null ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _isProbingLan ? null : _probeLan,
                  icon: _isProbingLan
                      ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.radar_rounded, size: 18),
                  label: const Text('Probe Local LAN', style: TextStyle(fontWeight: FontWeight.w700)),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _isPinging ? null : _testPing,
                  icon: _isPinging
                      ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.speed_rounded, size: 18),
                  label: const Text('Test Ping', style: TextStyle(fontWeight: FontWeight.w700)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: tokens.bluePrimary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statRow(String label, String value, EHThemeTokens tokens) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontSize: 13, color: tokens.textSecondary)),
        Flexible(
          child: Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: tokens.textPrimary),
          ),
        ),
      ],
    );
  }
}
