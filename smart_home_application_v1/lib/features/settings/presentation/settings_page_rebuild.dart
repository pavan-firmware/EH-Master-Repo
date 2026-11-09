import 'package:flutter/material.dart';

import '../../../app/home_controller.dart';
import '../../../app/theme_controller.dart';
import '../../../core/api/api_client.dart';
import '../../../core/config/app_config.dart';
import '../../../core/models/connection_models.dart';
import '../../../core/models/device_models.dart';
import '../../../core/models/health_models.dart';
import '../../../core/models/room_models.dart';
import '../../../core/models/settings_models.dart';
import '../../../core/models/update_models.dart';
import '../../../core/repositories/connection_repository.dart';
import '../../../core/repositories/device_health_repository.dart';
import '../../../core/repositories/fake_home_repository.dart';
import '../../../core/repositories/home_connection_repository.dart';
import '../../../core/repositories/settings_repository.dart';
import '../../../core/repositories/update_repository.dart';
import '../../../core/services/device_storage_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/auth_controller.dart';
import '../../dashboard/presentation/cloud_sync_center_sheet.dart';
import '../../connection/presentation/connection_page.dart';
import '../../diagnostics/presentation/device_health_page.dart';
import '../../updates/presentation/system_update_page.dart';
import 'add_room_device_page.dart';
import 'advanced_fleet_operations_page.dart';
import 'factory_reset/factory_reset_page.dart';
import 'help/help_support_page.dart';
import 'home_details_page.dart';
import 'notification_preferences_page.dart';
import 'people_page.dart';
import 'privacy/privacy_page.dart';
import 'settings_ui.dart';
import '../../hub/presentation/hub_management_page.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({
    super.key,
    this.homeController,
    this.onConnectHome,
    this.connectionState,
    this.connectionMessage,
    this.repository = const PreviewSettingsRepository(),
    this.connectionRepository = const PreviewHomeConnectionRepository(),
    this.updateRepository = const PreviewUpdateRepository(),
    this.healthRepository = const PreviewDeviceHealthRepository(),
    this.apiClient,
    this.authController,
    this.homeId,
    this.isAdmin = false,
    this.onLogout,
  });

  final HomeController? homeController;
  final Future<ConnectionResult> Function()? onConnectHome;
  final HomeConnectionState? connectionState;
  final String? connectionMessage;
  final SettingsRepository repository;
  final HomeConnectionRepository connectionRepository;
  final UpdateRepository updateRepository;
  final DeviceHealthRepository healthRepository;
  final ApiClient? apiClient;
  final AuthController? authController;
  final String? homeId;
  final bool isAdmin;
  final VoidCallback? onLogout;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> with WidgetsBindingObserver {
  (HomeSettingsData, _SystemSummary)? _cachedData;
  late Future<(HomeSettingsData, _SystemSummary)> _future;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _future = _fetchData();
    widget.homeController?.addListener(_onHomeStateChanged);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.homeController?.removeListener(_onHomeStateChanged);
    super.dispose();
  }

  void _onHomeStateChanged() {
    if (mounted) _reload();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      _reload();
    }
  }

  @override
  void didUpdateWidget(covariant SettingsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.homeController != widget.homeController) {
      oldWidget.homeController?.removeListener(_onHomeStateChanged);
      widget.homeController?.addListener(_onHomeStateChanged);
      _reload();
    } else if (oldWidget.connectionState != widget.connectionState ||
        oldWidget.homeId != widget.homeId ||
        oldWidget.connectionMessage != widget.connectionMessage) {
      _reload();
    }
  }

  void _reload() {
    setState(() {
      _future = _fetchData();
    });
  }

  Future<(HomeSettingsData, _SystemSummary)> _fetchData() async {
    try {
      final homeFuture = widget.repository
          .getHome()
          .timeout(const Duration(seconds: 3));
      final systemFuture =
          _loadSystemSummary().timeout(const Duration(seconds: 3));
      final results = await Future.wait([homeFuture, systemFuture]);
      var home = results[0] as HomeSettingsData;
      if (widget.homeController?.activeSpaceName != null &&
          widget.homeController!.activeSpaceName.isNotEmpty) {
        home = home.copyWith(name: widget.homeController!.activeSpaceName);
      }
      final system = results[1] as _SystemSummary;
      _cachedData = (home, system);
      return (home, system);
    } catch (_) {
      if (_cachedData != null) return _cachedData!;
      rethrow;
    }
  }

  Future<_SystemSummary> _loadSystemSummary() async {
    final authoritative = widget.homeController?.authoritativeConnectionState;
    final effectiveState = authoritative != null
        ? (authoritative.isOnline ? HomeConnectionState.connected : HomeConnectionState.offline)
        : (widget.homeController?.connectionState ?? widget.connectionState);
    final connection = await widget.connectionRepository
        .getOverview(
          liveState: effectiveState,
        )
        .timeout(const Duration(seconds: 3));
    final update = await widget.updateRepository
        .getSummary()
        .timeout(const Duration(seconds: 3));
    final health = await widget.healthRepository
        .getSummary()
        .timeout(const Duration(seconds: 3));
    return _SystemSummary(
      connection: connection,
      update: update,
      health: health,
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.ehColors;

    return SafeArea(
      bottom: false,
      child: Scaffold(
        backgroundColor: tokens.bgApp,
        body: FutureBuilder<(HomeSettingsData, _SystemSummary)>(
          future: _future,
          initialData: _cachedData,
          builder: (context, snapshot) {
            final data = snapshot.data ?? _cachedData;
            if (data != null) {
              return _SettingsContent(
                home: data.$1,
                system: data.$2,
                homeController: widget.homeController,
                repository: widget.repository,
                connectionRepository: widget.connectionRepository,
                updateRepository: widget.updateRepository,
                onReload: _reload,
                onConnectHome: widget.onConnectHome,
                connectionState: widget.connectionState,
                connectionMessage: widget.connectionMessage,
                apiClient: widget.apiClient,
                authController: widget.authController,
                homeId: widget.homeId,
                isAdmin: widget.isAdmin,
                onLogout: widget.onLogout,
              );
            }
            if (snapshot.connectionState != ConnectionState.done) {
              return const _SettingsLoading();
            }
            if (snapshot.hasError) {
              return _SettingsError(onRetry: _reload);
            }
            return const _SettingsLoading();
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
    this.homeController,
    required this.repository,
    required this.connectionRepository,
    required this.updateRepository,
    required this.onReload,
    required this.onConnectHome,
    required this.connectionState,
    required this.connectionMessage,
    this.apiClient,
    this.authController,
    this.homeId,
    this.isAdmin = false,
    this.onLogout,
  });

  final HomeSettingsData home;
  final _SystemSummary system;
  final HomeController? homeController;
  final SettingsRepository repository;
  final HomeConnectionRepository connectionRepository;
  final UpdateRepository updateRepository;
  final VoidCallback onReload;
  final Future<ConnectionResult> Function()? onConnectHome;
  final HomeConnectionState? connectionState;
  final String? connectionMessage;
  final ApiClient? apiClient;
  final AuthController? authController;
  final String? homeId;
  final bool isAdmin;
  final VoidCallback? onLogout;

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
    final roomCount = homeController != null
        ? homeController!.rooms.length
        : RoomCatalog.preview.length;
    final deviceCount = homeController != null
        ? homeController!.devices.length
        : RoomCatalog.preview.fold<int>(
            0,
            (sum, room) => sum + room.deviceCount,
          );
    final connection = _RootConnectionStatus.fromOverview(
      system.connection,
      tokens,
      homeController: homeController,
    );
    final isUpdateUnavailable = system.update.isUnavailable;
    final hasUpdates = !isUpdateUnavailable && system.update.availableCount > 0;
    final updateSubtitle = isUpdateUnavailable
        ? system.update.title
        : (hasUpdates
            ? '${system.update.availableCount} update${system.update.availableCount == 1 ? '' : 's'} ready to install'
            : 'Your system is up to date');
    final firstUpdateTarget = system.update.targets.where(
      (t) => t.status == UpdateTargetStatus.updateAvailable,
    ).firstOrNull;
    final updateChipLabel = isUpdateUnavailable
        ? (system.update.errorType == UpdateErrorType.noInternet ? 'Offline' : 'Unreachable')
        : (hasUpdates
            ? (firstUpdateTarget?.availableVersion?.replaceAll('Version ', 'v') ?? 'Update Ready')
            : 'Version ${system.update.appVersion}');
    final realAttentionCount = homeController != null && homeController!.devices.isNotEmpty
        ? homeController!.devices.where((d) => !d.online).length
        : system.health.attentionCount;
    final healthChip = realAttentionCount == 0
        ? SettingsStatusChip(
            label: 'Healthy',
            color: tokens.success,
            background: tokens.successContainer,
            leading: Icon(Icons.check_rounded, color: tokens.success, size: 14),
          )
        : SettingsStatusChip(
            label: '$realAttentionCount issue${realAttentionCount == 1 ? '' : 's'}',
            color: tokens.warning,
            background: tokens.warningContainer,
            leading: Icon(
              Icons.error_outline_rounded,
              color: tokens.warning,
              size: 14,
            ),
          );

    final themeCtrl = ThemeScope.maybeOf(context);
    final currentThemeLabel = themeCtrl == null
        ? 'System default'
        : switch (themeCtrl.themeMode) {
            ThemeMode.system => 'System default',
            ThemeMode.dark => 'Dark theme',
            ThemeMode.light => 'Light theme',
          };

    final effectiveHomeId = (homeId != null && homeId!.isNotEmpty)
        ? homeId!
        : (homeController?.activeHomeId != null &&
                homeController!.activeHomeId!.isNotEmpty)
            ? homeController!.activeHomeId!
            : (home.id.isNotEmpty ? home.id : 'home_01');
    final effectiveClient = apiClient ?? ApiClient(baseUrl: AppConfig.backendBaseUrl);

    return ListView(
      key: const PageStorageKey<String>('settings-scroll'),
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 24),
      children: [
        Text(
          'Settings',
          style: TextStyle(
            color: tokens.textPrimary,
            fontSize: 28,
            height: 1,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Manage your home, devices, and preferences.',
          style: TextStyle(color: tokens.textSecondary, fontSize: 14),
        ),
        const SizedBox(height: 16),
        _HomeProfileCard(
          home: home,
          roomCount: roomCount,
          deviceCount: deviceCount,
          connection: connection,
          homeController: homeController,
          onTap: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => HomeDetailsPage(
                  home: home,
                  repository: repository,
                  homeController: homeController,
                ),
              ),
            );
            if (context.mounted) onReload();
          },
        ),
        const SizedBox(height: 18),
        const SettingsSectionTitle('Your system'),
        SettingsSurface(
          child: Column(
            children: [
              SettingsListItem(
                icon: Icons.hub_rounded,
                title: 'Smart Home Hub',
                subtitle: 'Local brain • Sub-5ms mesh & 100% offline control',
                trailing: SettingsStatusChip(
                  label: 'Setup Hub',
                  color: tokens.bluePrimary,
                  background: tokens.iconBgBlue,
                  leading: Icon(Icons.bolt_rounded, size: 14, color: tokens.bluePrimary),
                ),
                onTap: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => HubManagementPage(
                        homeId: effectiveHomeId,
                      ),
                    ),
                  );
                  if (context.mounted) onReload();
                },
                showDivider: true,
              ),
              SettingsListItem(
                icon: Icons.add_to_queue_rounded,
                title: 'Add a room device',
                subtitle: 'Set up a nearby device',
                onTap: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AddRoomDevicePage(
                        repository: repository,
                        onStartSecureSetup: onConnectHome,
                        connectionState: connectionState,
                        homeController: homeController,
                      ),
                    ),
                  );
                  if (context.mounted) onReload();
                },
                showDivider: true,
              ),
              SettingsListItem(
                icon: Icons.bluetooth_connected_rounded,
                title: 'Connect your home',
                subtitle: connection.detail,
                onTap: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ConnectionPage(
                        onStart: onConnectHome,
                        connectionState: homeController?.authoritativeConnectionState.isOnline == false
                            ? HomeConnectionState.offline
                            : (connectionState ?? homeController?.connectionState),
                        connectionMessage: connectionMessage ?? homeController?.connectionMessage,
                        repository: connectionRepository,
                      ),
                    ),
                  );
                  if (context.mounted) onReload();
                },
                iconColor: tokens.isDark
                    ? tokens.bluePrimary
                    : SettingsColors.purple,
                iconBackground: tokens.isDark
                    ? tokens.iconBgBlue
                    : SettingsColors.palePurple,
                trailing: SettingsStatusChip(
                  label: connection.shortLabel,
                  color: connection.color,
                  background: connection.background,
                  leading: Icon(
                    connection.chipIcon,
                    color: connection.color,
                    size: 14,
                  ),
                ),
                showDivider: true,
              ),
              SettingsListItem(
                icon: Icons.system_update_alt_rounded,
                title: 'System update',
                subtitle: updateSubtitle,
                onTap: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => SystemUpdatePage(
                        repository: updateRepository,
                        homeController: homeController,
                      ),
                    ),
                  );
                  if (context.mounted) onReload();
                },
                trailing: SettingsStatusChip(
                  label: updateChipLabel,
                  color: isUpdateUnavailable
                      ? tokens.warning
                      : (hasUpdates
                          ? const Color(0xFFD97706)
                          : (tokens.isDark ? tokens.blueSelectedText : SettingsColors.purple)),
                  background: isUpdateUnavailable
                      ? tokens.warningContainer
                      : (hasUpdates
                          ? const Color(0xFFFEF3C7)
                          : (tokens.isDark ? tokens.blueSelectedBg : SettingsColors.paleLavender)),
                  leading: isUpdateUnavailable
                      ? Icon(
                          system.update.errorType == UpdateErrorType.noInternet
                              ? Icons.wifi_off_rounded
                              : Icons.dns_rounded,
                          color: tokens.warning,
                          size: 14,
                        )
                      : (hasUpdates
                          ? const Icon(
                              Icons.arrow_upward_rounded,
                              color: Color(0xFFD97706),
                              size: 14,
                            )
                          : null),
                ),
                showDivider: true,
              ),
              SettingsListItem(
                icon: Icons.health_and_safety_outlined,
                title: 'Device health',
                subtitle: 'Check connection and care tips',
                onTap: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => DeviceHealthPage(
                        homeController: homeController,
                      ),
                    ),
                  );
                  if (context.mounted) onReload();
                },
                trailing: healthChip,
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        const SettingsSectionTitle('Home and members'),
        SettingsSurface(
          child: Column(
            children: [
              SettingsListItem(
                icon: Icons.groups_rounded,
                title: 'People at home',
                subtitle: 'Manage access and invitations',
                onTap: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          PeoplePage(repository: repository, home: home),
                    ),
                  );
                  if (context.mounted) onReload();
                },
                showDivider: false,
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        const SettingsSectionTitle('Preferences & tools'),
        SettingsSurface(
          child: Column(
            children: [
              SettingsListItem(
                icon: Icons.cloud_sync_rounded,
                title: 'Cloud sync & backup center',
                subtitle: 'Backup local setups, rooms, and devices or restore from cloud',
                onTap: () async {
                  final effectiveCtrl = homeController ??
                      HomeController.instance ??
                      HomeController(repository: FakeHomeRepository());
                  await showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    builder: (_) => CloudSyncCenterSheet(
                      homeController: effectiveCtrl,
                    ),
                  );
                  if (context.mounted) onReload();
                },
                showDivider: true,
              ),
              SettingsListItem(
                icon: Icons.palette_outlined,
                title: 'Appearance',
                subtitle: currentThemeLabel,
                onTap: () => _showAppearancePicker(context),
                showDivider: true,
              ),
              SettingsListItem(
                icon: Icons.notifications_none_rounded,
                title: 'Notification preferences',
                subtitle: 'Safety, offline, and update alerts',
                onTap: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const NotificationPreferencesPage(),
                    ),
                  );
                  if (context.mounted) onReload();
                },
                showDivider: true,
              ),
              SettingsListItem(
                icon: Icons.tune_rounded,
                title: 'System tools & diagnostics',
                subtitle: 'Firmware updates, diagnostics, and system security',
                trailing: SettingsStatusChip(
                  label: isAdmin ? 'Admin' : 'Advanced',
                  color: tokens.bluePrimary,
                  background: tokens.blueSelectedBg,
                ),
                onTap: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AdvancedFleetOperationsPage(
                        homeId: effectiveHomeId,
                        apiClient: effectiveClient,
                        homeController: homeController,
                        isAdmin: isAdmin,
                      ),
                    ),
                  );
                  if (context.mounted) onReload();
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        const SettingsSectionTitle('Help and privacy'),
        SettingsSurface(
          child: Column(
            children: [
              SettingsListItem(
                icon: Icons.help_outline_rounded,
                title: 'Help and support',
                subtitle: 'Get help and find answers',
                onTap: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => HelpSupportPage(
                        settingsRepository: repository,
                        homeController: homeController,
                        homeConnectionRepository: connectionRepository,
                      ),
                    ),
                  );
                  if (context.mounted) onReload();
                },
                iconColor: tokens.isDark
                    ? tokens.bluePrimary
                    : SettingsColors.purple,
                iconBackground: tokens.isDark
                    ? tokens.iconBgBlue
                    : SettingsColors.palePurple,
                showDivider: true,
              ),
              SettingsListItem(
                icon: Icons.privacy_tip_outlined,
                title: 'Privacy',
                subtitle: 'Manage your data and permissions',
                onTap: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const PrivacyPage()),
                  );
                  if (context.mounted) onReload();
                },
                iconColor: tokens.isDark
                    ? tokens.bluePrimary
                    : SettingsColors.purple,
                iconBackground: tokens.isDark
                    ? tokens.iconBgBlue
                    : SettingsColors.palePurple,
                showDivider: true,
              ),
              if (onLogout != null) ...[
                SettingsListItem(
                  icon: Icons.logout_rounded,
                  title: 'Sign out',
                  subtitle: 'Disconnect this session and stop background sync',
                  onTap: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Sign Out'),
                        content: const Text(
                          'Are you sure you want to sign out of EH Home? Your live connection will be closed.',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: const Text('Cancel'),
                          ),
                          FilledButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            child: const Text('Sign Out'),
                          ),
                        ],
                      ),
                    );
                    if (confirm == true) {
                      onLogout!();
                    }
                  },
                  destructive: true,
                  showDivider: true,
                ),
              ],
              SettingsListItem(
                icon: Icons.restart_alt_rounded,
                title: 'Factory reset',
                subtitle: 'Remove this home from the device',
                onTap: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const FactoryResetPage()),
                  );
                  if (context.mounted) onReload();
                },
                destructive: true,
              ),
            ],
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
                        color: selected
                            ? (tokens.isDark
                                  ? tokens.blueSelectedText
                                  : tokens.bluePrimary)
                            : tokens.textPrimary,
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
                Icon(
                  Icons.check_circle_rounded,
                  color: tokens.bluePrimary,
                  size: 22,
                ),
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
    this.homeController,
  });
  final HomeSettingsData home;
  final int roomCount;
  final int deviceCount;
  final _RootConnectionStatus connection;
  final VoidCallback onTap;
  final HomeController? homeController;

  @override
  Widget build(BuildContext context) {
    final tokens = context.ehColors;
    final effectiveName = (homeController?.activeSpaceName != null &&
            homeController!.activeSpaceName.isNotEmpty)
        ? homeController!.activeSpaceName
        : home.name;
    return SettingsSurface(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: tokens.isDark
                        ? [tokens.bluePrimary, const Color(0xFF1D4ED8)]
                        : [const Color(0xFF3B82F6), const Color(0xFF1D4ED8)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.home_rounded,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      effectiveName,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: tokens.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Home owner',
                      style: TextStyle(
                        color: tokens.textSecondary,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        _Meta(
                          icon: connection.icon,
                          text: connection.profileText,
                          color: connection.color,
                        ),
                        _Meta(
                          icon: Icons.meeting_room_outlined,
                          text: '$roomCount rooms',
                        ),
                        _Meta(
                          icon: Icons.inventory_2_outlined,
                          text: '$deviceCount devices',
                        ),
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
              style: TextStyle(
                color: resolvedColor,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
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

  factory _RootConnectionStatus.fromOverview(
    dynamic overview,
    EHThemeTokens tokens, {
    HomeController? homeController,
  }) {
    final ctrl = homeController ?? HomeController.instance;
    final authoritative = ctrl?.authoritativeConnectionState;

    if (authoritative != null) {
      if (!authoritative.isOnline) {
        return _RootConnectionStatus(
          shortLabel: 'Unavailable',
          detail: 'Your home device is currently unavailable',
          icon: Icons.wifi_off_rounded,
          color: tokens.warning,
          background: tokens.warningContainer,
          chipIcon: Icons.error_outline_rounded,
          profileLabel: 'Disconnected',
        );
      }
      final isLocal = authoritative.isLocalMode;
      return _RootConnectionStatus(
        shortLabel: isLocal ? 'Local' : 'Connected',
        detail: isLocal
            ? 'Direct Local Wi-Fi (<10ms)'
            : 'Bluetooth, Wi-Fi, and hub connection',
        icon: isLocal ? Icons.wifi_rounded : Icons.bluetooth_connected_rounded,
        color: tokens.success,
        background: tokens.successContainer,
        chipIcon: Icons.check_rounded,
        profileLabel: isLocal ? 'Local mode' : 'Home connected',
      );
    }

    final hasDevices = (ctrl?.devices.isNotEmpty ?? false) || DeviceStorageService.cachedDevices.isNotEmpty;
    if (overview.isFullyConnected || (hasDevices && (ctrl?.isLocalMode == true || ctrl?.isCloudReachable == true))) {
      return _RootConnectionStatus(
        shortLabel: 'Connected',
        detail: ctrl?.isLocalMode == true
            ? 'Direct Local Wi-Fi (<10ms)'
            : 'Bluetooth, Wi-Fi, and hub connection',
        icon: Icons.bluetooth_connected_rounded,
        color: tokens.success,
        background: tokens.successContainer,
        chipIcon: Icons.check_rounded,
        profileLabel: 'Home connected',
      );
    }
    return _RootConnectionStatus.fromState(overview.overall, tokens);
  }

  factory _RootConnectionStatus.fromState(
    HomeConnectionState? state,
    EHThemeTokens tokens,
  ) => switch (state) {
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
    HomeConnectionState.offline ||
    HomeConnectionState.failed => _RootConnectionStatus(
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
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: tokens.textPrimary,
              ),
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
