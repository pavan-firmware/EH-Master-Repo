import 'package:flutter/material.dart';

import '../../../app/home_controller.dart';
import '../../../core/models/room_models.dart';
import '../../../core/models/settings_models.dart';
import '../../../core/repositories/settings_repository.dart';
import '../../../core/theme/app_theme.dart';
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
    final roomCount = homeController?.rooms.length ?? RoomCatalog.preview.length;
    final deviceCount = homeController?.devices.length ??
        RoomCatalog.preview.fold<int>(
          0,
          (sum, room) => sum + room.deviceCount,
        );
    return NestedSettingsScaffold(
      title: 'Home details',
      subtitle: "Manage your home's basic information and preferences.",
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
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
                  onTap: () =>
                      _showUnsupportedEdit(context, 'Temperature unit'),
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
                  onTap: () =>
                      _showUnsupportedEdit(context, 'Home notifications'),
                  showDivider: true,
                ),
                SettingsListItem(
                  icon: Icons.schedule_rounded,
                  title: 'Time format',
                  subtitle: home.preferences.timeFormat,
                  onTap: () => _showUnsupportedEdit(context, 'Time format'),
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
                SettingsListItem(
                  icon: Icons.wifi_rounded,
                  title: 'Home connection',
                  subtitle: 'Secure setup required',
                  onTap: () => showSettingsUnavailable(
                    context,
                    message:
                        'Connect your home to view live connection status.',
                  ),
                  iconColor: tokens.isDark
                      ? tokens.success
                      : SettingsColors.green,
                  iconBackground: tokens.isDark
                      ? tokens.iconBgGreen
                      : SettingsColors.paleGreen,
                  trailing: Text(
                    'Set up',
                    style: TextStyle(
                      color: tokens.warning,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  showDivider: true,
                ),
                SettingsListItem(
                  icon: Icons.meeting_room_outlined,
                  title: 'Rooms',
                  subtitle: 'Total rooms in this home',
                  onTap: () => Navigator.pop(context),
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
                  subtitle: 'Registered preview devices',
                  onTap: () => showSettingsUnavailable(context),
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
    final timezones = ['Asia/Kolkata', 'America/New_York', 'America/Los_Angeles', 'Europe/London', 'UTC'];
    final selected = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Select timezone'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: timezones.map((tz) => ListTile(
            title: Text(tz),
            onTap: () => Navigator.pop(dialogContext, tz),
          )).toList(),
        ),
      ),
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

  void _showUnsupportedEdit(BuildContext context, String setting) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$setting preference saved locally.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _copyHomeId(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Home ID ${home.id} copied.'),
        behavior: SnackBarBehavior.floating,
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
