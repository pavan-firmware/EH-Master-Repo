import 'package:flutter/material.dart';

import '../../../app/theme_controller.dart';
import '../../../core/models/connection_models.dart';
import '../../../core/models/device_models.dart';
import '../../../core/models/health_models.dart';
import '../../../core/models/room_models.dart';
import '../../../core/models/settings_models.dart';
import '../../../core/models/update_models.dart';
import '../../../core/repositories/connection_repository.dart';
import '../../../core/repositories/device_health_repository.dart';
import '../../../core/repositories/home_connection_repository.dart';
import '../../../core/repositories/settings_repository.dart';
import '../../../core/repositories/update_repository.dart';
import '../../../core/theme/app_theme.dart';
import '../../connection/presentation/connection_page.dart';
import '../../diagnostics/presentation/device_health_page.dart';
import '../../updates/presentation/system_update_page.dart';
import 'add_room_device_page.dart';
import 'factory_reset/factory_reset_page.dart';
import 'help/help_support_page.dart';
import 'home_details_page.dart';
import 'home_profile_page.dart';
import 'people_page.dart';
import 'privacy/privacy_page.dart';
import 'settings_ui.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({
    super.key,
    this.onConnectHome,
    this.connectionState,
    this.connectionMessage,
    this.repository = const PreviewSettingsRepository(),
    this.connectionRepository = const PreviewHomeConnectionRepository(),
    this.updateRepository = const PreviewUpdateRepository(),
    this.healthRepository = const PreviewDeviceHealthRepository(),
  });

  final Future<ConnectionResult> Function()? onConnectHome;
  final HomeConnectionState? connectionState;
  final String? connectionMessage;
  final SettingsRepository repository;
  final HomeConnectionRepository connectionRepository;
  final UpdateRepository updateRepository;
  final DeviceHealthRepository healthRepository;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late Future<HomeSettingsData> _home = widget.repository.getHome();
  late Future<_SystemSummary> _systemSummary = _loadSystemSummary();

  void _reload() {
    setState(() {
      _home = widget.repository.getHome();
      _systemSummary = _loadSystemSummary();
    });
  }

  Future<_SystemSummary> _loadSystemSummary() async {
    final connection = await widget.connectionRepository.getOverview(
      liveState: widget.connectionState,
    );
    final update = await widget.updateRepository.getSummary();
    final health = await widget.healthRepository.getSummary();
    return _SystemSummary(connection: connection, update: update, health: health);
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.ehColors;
    return SafeArea(
      bottom: false,
      child: Scaffold(
        backgroundColor: tokens.bgApp,
        body: FutureBuilder<(HomeSettingsData, _SystemSummary)>(
          future: Future.wait([_home, _systemSummary]).then(
            (results) => (results[0] as HomeSettingsData, results[1] as _SystemSummary),
          ),
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const _SettingsLoading();
            }
            if (snapshot.hasError || !snapshot.hasData) {
              return _SettingsError(onRetry: _reload);
            }
            final home = snapshot.data!.$1;
            final system = snapshot.data!.$2;
            return _SettingsContent(
              home: home,
              system: system,
              repository: widget.repository,
              onConnectHome: widget.onConnectHome,
              connectionState: widget.connectionState,
              connectionMessage: widget.connectionMessage,
            );
          },
        ),
      ),
    );
  }
}

class _SystemSummary {
  const _SystemSummary({
    required this.connection,
    required this.update,
    required this.health,
  });

  final HomeConnectionOverview connection;
  final UpdateSummary update;
  final HomeHealthSummary health;
}

class _SettingsContent extends StatelessWidget {
  const _SettingsContent({
    required this.home,
    required this.system,
    required this.repository,
    required this.onConnectHome,
    required this.connectionState,
    required this.connectionMessage,
  });

  final HomeSettingsData home;
  final _SystemSummary system;
  final SettingsRepository repository;
  final Future<ConnectionResult> Function()? onConnectHome;
  final HomeConnectionState? connectionState;
  final String? connectionMessage;

  void _showAppearancePicker(BuildContext context) {
    final themeCtrl = ThemeScope.maybeOf(context);
    if (themeCtrl == null) return;
    final tokens = context.ehColors;

    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: tokens.surfaceCard,
      builder: (sheetContext) {
        final currentMode = themeCtrl.themeMode;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Appearance',
                  style: TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w800,
                    color: tokens.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Choose your preferred theme mode for EH Home.',
                  style: TextStyle(color: tokens.textSecondary, fontSize: 14),
                ),
                const SizedBox(height: 18),
                _AppearanceOptionTile(
                  icon: Icons.brightness_auto_rounded,
                  title: 'System default',
                  subtitle: 'Match your device light/dark settings',
                  selected: currentMode == ThemeMode.system,
                  onTap: () {
                    themeCtrl.setThemeMode(ThemeMode.system);
                    Navigator.pop(sheetContext);
                  },
                ),
                const SizedBox(height: 10),
                _AppearanceOptionTile(
                  icon: Icons.dark_mode_rounded,
                  title: 'Dark theme',
                  subtitle: 'Midnight navy EH Home at night',
                  selected: currentMode == ThemeMode.dark,
                  onTap: () {
                    themeCtrl.setThemeMode(ThemeMode.dark);
                    Navigator.pop(sheetContext);
                  },
                ),
                const SizedBox(height: 10),
                _AppearanceOptionTile(
                  icon: Icons.light_mode_rounded,
                  title: 'Light theme',
                  subtitle: 'Clean white daylight look',
                  selected: currentMode == ThemeMode.light,
                  onTap: () {
                    themeCtrl.setThemeMode(ThemeMode.light);
                    Navigator.pop(sheetContext);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.ehColors;
    final roomCount = RoomCatalog.preview.length;
    final deviceCount = RoomCatalog.preview.fold<int>(
      0,
      (sum, room) => sum + room.deviceCount,
    );
    final connection = _RootConnectionStatus.fromOverview(system.connection, tokens);
    final updateSubtitle = system.update.availableCount == 0
        ? 'Your system is up to date'
        : '${system.update.availableCount} update available';
    final healthChip = system.health.attentionCount == 0
        ? SettingsStatusChip(
            label: 'Healthy',
            color: tokens.success,
            background: tokens.successContainer,
            leading: Icon(Icons.check_rounded, color: tokens.success, size: 14),
          )
        : SettingsStatusChip(
            label: '${system.health.attentionCount} issue',
            color: tokens.warning,
            background: tokens.warningContainer,
            leading: Icon(Icons.error_outline_rounded, color: tokens.warning, size: 14),
          );

    final themeCtrl = ThemeScope.maybeOf(context);
    final currentThemeLabel = themeCtrl == null
        ? 'System default'
        : switch (themeCtrl.themeMode) {
            ThemeMode.system => 'System default',
            ThemeMode.dark => 'Dark theme',
            ThemeMode.light => 'Light theme',
          };

    return ListView(
      key: const PageStorageKey<String>('settings-scroll'),
      padding: const EdgeInsets.fromLTRB(20, 23, 20, 28),
      children: [
        Text(
          'Settings',
          style: TextStyle(
            color: tokens.textPrimary,
            fontSize: 29,
            height: 1,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Manage your home, devices, and preferences.',
          style: TextStyle(color: tokens.textSecondary, fontSize: 15),
        ),
        const SizedBox(height: 24),
        _HomeProfileCard(
          home: home,
          roomCount: roomCount,
          deviceCount: deviceCount,
          connection: connection,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => HomeProfilePage(
                home: home,
                repository: repository,
                connectionState: connectionState,
                onConnectHome: onConnectHome,
              ),
            ),
          ),
        ),
        const SizedBox(height: 27),
        const SettingsSectionTitle('Home and people'),
        SettingsSurface(
          child: Column(
            children: [
              SettingsListItem(
                icon: Icons.groups_rounded,
                title: 'People at home',
                subtitle: 'Manage access and invitations',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => PeoplePage(repository: repository, home: home),
                  ),
                ),
                showDivider: true,
              ),
              SettingsListItem(
                icon: Icons.home_outlined,
                title: 'Home details',
                subtitle: 'Name, location, and preferences',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => HomeDetailsPage(home: home, repository: repository),
                  ),
                ),
                showDivider: true,
              ),
              SettingsListItem(
                icon: Icons.palette_outlined,
                title: 'Appearance',
                subtitle: currentThemeLabel,
                onTap: () => _showAppearancePicker(context),
              ),
            ],
          ),
        ),
        const SizedBox(height: 27),
        const SettingsSectionTitle('Your system'),
        SettingsSurface(
          child: Column(
            children: [
              SettingsListItem(
                icon: Icons.add_to_queue_rounded,
                title: 'Add a room device',
                subtitle: 'Set up a nearby device',
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
                showDivider: true,
              ),
              SettingsListItem(
                icon: Icons.bluetooth_connected_rounded,
                title: 'Connect your home',
                subtitle: connection.detail,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ConnectionPage(
                      onStart: onConnectHome,
                      connectionState: connectionState,
                      connectionMessage: connectionMessage,
                    ),
                  ),
                ),
                iconColor: tokens.isDark ? tokens.bluePrimary : SettingsColors.purple,
                iconBackground: tokens.isDark ? tokens.iconBgBlue : SettingsColors.palePurple,
                trailing: SettingsStatusChip(
                  label: connection.shortLabel,
                  color: connection.color,
                  background: connection.background,
                  leading: Icon(connection.chipIcon, color: connection.color, size: 14),
                ),
                showDivider: true,
              ),
              SettingsListItem(
                icon: Icons.system_update_alt_rounded,
                title: 'System update',
                subtitle: updateSubtitle,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SystemUpdatePage()),
                ),
                trailing: SettingsStatusChip(
                  label: 'Version ${system.update.appVersion}',
                  color: tokens.isDark ? tokens.blueSelectedText : SettingsColors.purple,
                  background: tokens.isDark ? tokens.blueSelectedBg : SettingsColors.paleLavender,
                ),
                showDivider: true,
              ),
              SettingsListItem(
                icon: Icons.health_and_safety_outlined,
                title: 'Device health',
                subtitle: 'Check connection and care tips',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const DeviceHealthPage()),
                ),
                trailing: healthChip,
              ),
            ],
          ),
        ),
        const SizedBox(height: 27),
        const SettingsSectionTitle('Help and privacy'),
        SettingsSurface(
          child: Column(
            children: [
              SettingsListItem(
                icon: Icons.help_outline_rounded,
                title: 'Help and support',
                subtitle: 'Get help and find answers',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const HelpSupportPage()),
                ),
                iconColor: tokens.isDark ? tokens.bluePrimary : SettingsColors.purple,
                iconBackground: tokens.isDark ? tokens.iconBgBlue : SettingsColors.palePurple,
                showDivider: true,
              ),
              SettingsListItem(
                icon: Icons.privacy_tip_outlined,
                title: 'Privacy',
                subtitle: 'Manage your data and permissions',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const PrivacyPage()),
                ),
                iconColor: tokens.isDark ? tokens.bluePrimary : SettingsColors.purple,
                iconBackground: tokens.isDark ? tokens.iconBgBlue : SettingsColors.palePurple,
              ),
            ],
          ),
        ),
        const SizedBox(height: 27),
        const SettingsSectionTitle('Danger zone'),
        SettingsSurface(
          child: SettingsListItem(
            icon: Icons.restart_alt_rounded,
            title: 'Factory reset',
            subtitle: 'Remove this home from the device',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const FactoryResetPage()),
            ),
            destructive: true,
          ),
        ),
      ],
    );
  }
}

class _AppearanceOptionTile extends StatelessWidget {
  const _AppearanceOptionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.ehColors;
    return Material(
      color: selected ? tokens.blueSelectedBg : tokens.surfaceElevated,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? tokens.bluePrimary : tokens.borderSubtle,
              width: selected ? 1.5 : 1,
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Icon(
                icon,
                color: selected ? tokens.bluePrimary : tokens.textSecondary,
                size: 24,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                        color: selected ? (tokens.isDark ? tokens.blueSelectedText : tokens.bluePrimary) : tokens.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: tokens.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              if (selected)
                Icon(Icons.check_circle_rounded, color: tokens.bluePrimary, size: 22),
            ],
          ),
        ),
      ),
    );
  }
}

class _HomeProfileCard extends StatelessWidget {
  const _HomeProfileCard({
    required this.home,
    required this.roomCount,
    required this.deviceCount,
    required this.connection,
    required this.onTap,
  });
  final HomeSettingsData home;
  final int roomCount;
  final int deviceCount;
  final _RootConnectionStatus connection;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.ehColors;
    return SettingsSurface(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              const SettingsIconBadge(icon: Icons.home_outlined, size: 66),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      home.name,
                      style: TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.w800,
                        color: tokens.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Home owner',
                      style: TextStyle(color: tokens.textSecondary, fontSize: 15),
                    ),
                    const SizedBox(height: 13),
                    Wrap(
                      spacing: 9,
                      runSpacing: 6,
                      children: [
                        _Meta(icon: connection.icon, text: connection.profileText, color: connection.color),
                        _Meta(icon: Icons.meeting_room_outlined, text: '$roomCount rooms'),
                        _Meta(icon: Icons.inventory_2_outlined, text: '$deviceCount devices'),
                      ],
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: tokens.chevron),
            ],
          ),
        ),
      ),
    );
  }
}

class _Meta extends StatelessWidget {
  const _Meta({required this.icon, required this.text, this.color});
  final IconData icon;
  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final tokens = context.ehColors;
    final resolvedColor = color ?? tokens.textSecondary;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 148),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: resolvedColor, size: 17),
          const SizedBox(width: 5),
          Expanded(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: resolvedColor, fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _RootConnectionStatus {
  const _RootConnectionStatus({
    required this.shortLabel,
    required this.detail,
    required this.icon,
    required this.color,
    required this.background,
    required this.chipIcon,
    this.profileLabel,
  });
  final String shortLabel;
  final String detail;
  final IconData icon;
  final Color color;
  final Color background;
  final IconData chipIcon;
  final String? profileLabel;

  String get profileText => profileLabel ?? shortLabel;

  factory _RootConnectionStatus.fromOverview(dynamic overview, EHThemeTokens tokens) {
    if (overview.isFullyConnected) {
      return _RootConnectionStatus(
        shortLabel: 'Connected',
        detail: 'Bluetooth, Wi-Fi, and hub connection',
        icon: Icons.bluetooth_connected_rounded,
        color: tokens.success,
        background: tokens.successContainer,
        chipIcon: Icons.check_rounded,
        profileLabel: 'Home connected',
      );
    }
    return _RootConnectionStatus.fromState(overview.overall, tokens);
  }

  factory _RootConnectionStatus.fromState(HomeConnectionState? state, EHThemeTokens tokens) => switch (state) {
        HomeConnectionState.connected => _RootConnectionStatus(
          shortLabel: 'Connected',
          detail: 'Bluetooth, Wi-Fi, and hub connection',
          icon: Icons.bluetooth_connected_rounded,
          color: tokens.success,
          background: tokens.successContainer,
          chipIcon: Icons.check_rounded,
          profileLabel: 'Home connected',
        ),
        HomeConnectionState.connecting => _RootConnectionStatus(
          shortLabel: 'Connecting',
          detail: 'Looking for your nearby EH Home device',
          icon: Icons.bluetooth_searching_rounded,
          color: tokens.bluePrimary,
          background: tokens.blueSelectedBg,
          chipIcon: Icons.sync_rounded,
        ),
        HomeConnectionState.offline || HomeConnectionState.failed => _RootConnectionStatus(
          shortLabel: 'Unavailable',
          detail: 'Your home device is currently unavailable',
          icon: Icons.wifi_off_rounded,
          color: tokens.warning,
          background: tokens.warningContainer,
          chipIcon: Icons.error_outline_rounded,
        ),
        _ => _RootConnectionStatus(
          shortLabel: 'Set up required',
          detail: 'Bluetooth, Wi-Fi, and secure hub connection',
          icon: Icons.wifi_off_rounded,
          color: tokens.textSecondary,
          background: tokens.surfaceElevated,
          chipIcon: Icons.info_outline_rounded,
        ),
      };
}

class _SettingsLoading extends StatelessWidget {
  const _SettingsLoading();
  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
    children: const [
      SizedBox(width: 140, height: 32),
      SizedBox(height: 18),
      SettingsSurface(child: SizedBox(height: 142)),
      SizedBox(height: 30),
      SettingsSurface(child: SizedBox(height: 152)),
      SizedBox(height: 24),
      SettingsSurface(child: SizedBox(height: 280)),
    ],
  );
}

class _SettingsError extends StatelessWidget {
  const _SettingsError({required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final tokens = context.ehColors;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.home_outlined, color: tokens.textSecondary, size: 48),
            const SizedBox(height: 14),
            Text(
              'Couldn’t load your home',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: tokens.textPrimary),
            ),
            const SizedBox(height: 8),
            Text(
              'Check your connection and try again.',
              textAlign: TextAlign.center,
              style: TextStyle(color: tokens.textSecondary),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: onRetry,
              style: FilledButton.styleFrom(
                backgroundColor: tokens.blueDarker,
                foregroundColor: tokens.textPrimary,
              ),
              child: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }
}
