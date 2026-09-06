import 'package:flutter/material.dart';

import '../../../app/theme_controller.dart';
import '../../../core/api/api_client.dart';
import '../../../core/config/app_config.dart';
import '../../../core/models/connection_models.dart';
import '../../../core/models/device_models.dart';
import '../../../core/models/health_models.dart';
import '../../../core/models/room_models.dart';
import '../../../core/models/settings_models.dart';
import '../../../core/models/update_models.dart';
import '../../../core/repositories/cloud_device_trust_repository.dart';
import '../../../core/repositories/cloud_fleet_firmware_repository.dart';
import '../../../core/repositories/cloud_notification_repository.dart';
import '../../../core/repositories/cloud_operational_readiness_repository.dart';
import '../../../core/repositories/cloud_operations_repository.dart';
import '../../../core/repositories/cloud_recovery_repository.dart';
import '../../../core/repositories/connection_repository.dart';
import '../../../core/repositories/device_health_repository.dart';
import '../../../core/repositories/home_connection_repository.dart';
import '../../../core/repositories/settings_repository.dart';
import '../../../core/repositories/update_repository.dart';
import '../../../core/services/connectivity_service.dart';
import '../../../core/services/context_presence_service.dart';
import '../../../core/services/edge_control_service.dart';
import '../../../core/services/energy_automation_service.dart';
import '../../../core/services/energy_cost_service.dart';
import '../../../core/services/energy_service.dart';
import '../../../core/services/intelligence_service.dart';
import '../../../core/services/matter_service.dart';
import '../../../core/services/product_catalog_service.dart';
import '../../../core/services/reliability_service.dart';
import '../../../core/services/sync_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/auth_controller.dart';
import '../../connection/presentation/connection_page.dart';
import '../../connectivity/presentation/device_connectivity_page.dart';
import '../../context/presentation/home_context_page.dart';
import '../../context/presentation/presence_dashboard_page.dart';
import '../../device_trust/presentation/device_security_status_page.dart';
import '../../diagnostics/presentation/device_health_page.dart';
import '../../edge_control/presentation/edge_execution_dashboard_page.dart';
import '../../energy/presentation/energy_optimization_page.dart';
import '../../fleet/presentation/firmware_releases_page.dart';
import '../../fleet/presentation/fleet_firmware_status_page.dart';
import '../../fleet/presentation/ota_rollouts_page.dart';
import '../../energy/presentation/home_energy_dashboard_page.dart';
import '../../energy/presentation/tariff_management_page.dart';
import '../../integrations/presentation/matter_integration_page.dart';
import '../../intelligence/presentation/intelligence_center_page.dart';
import '../../notifications/presentation/notification_center_page.dart';
import '../../operations/presentation/operations_dashboard_page.dart';
import '../../operations/presentation/system_operational_status_page.dart';
import '../../product_discovery/presentation/product_discovery_page.dart';
import '../../recovery/presentation/recovery_dashboard_page.dart';
import '../../reliability/presentation/fleet_health_page.dart';
import '../../sync/presentation/sync_center_page.dart';
import '../../updates/presentation/system_update_page.dart';
import 'add_room_device_page.dart';
import 'factory_reset/factory_reset_page.dart';
import 'help/help_support_page.dart';
import 'home_details_page.dart';
import 'home_profile_page.dart';
import 'notification_preferences_page.dart';
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
    this.apiClient,
    this.authController,
    this.homeId,
    this.isAdmin = false,
    this.onLogout,
  });

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
          future: Future.wait([_home, _systemSummary]).then(
            (results) =>
                (results[0] as HomeSettingsData, results[1] as _SystemSummary),
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
              connectionRepository: widget.connectionRepository,
              onConnectHome: widget.onConnectHome,
              connectionState: widget.connectionState,
              connectionMessage: widget.connectionMessage,
              apiClient: widget.apiClient,
              authController: widget.authController,
              homeId: widget.homeId,
              isAdmin: widget.isAdmin,
              onLogout: widget.onLogout,
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
    required this.connectionRepository,
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
  final SettingsRepository repository;
  final HomeConnectionRepository connectionRepository;
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
    final roomCount = RoomCatalog.preview.length;
    final deviceCount = RoomCatalog.preview.fold<int>(
      0,
      (sum, room) => sum + room.deviceCount,
    );
    final connection = _RootConnectionStatus.fromOverview(
      system.connection,
      tokens,
    );
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

    final effectiveHomeId = homeId ?? home.id;
    final effectiveClient = apiClient ?? ApiClient(baseUrl: AppConfig.backendBaseUrl);

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
                      repository: connectionRepository,
                    ),
                  ),
                ),
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
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SystemUpdatePage()),
                ),
                trailing: SettingsStatusChip(
                  label: 'Version ${system.update.appVersion}',
                  color: tokens.isDark
                      ? tokens.blueSelectedText
                      : SettingsColors.purple,
                  background: tokens.isDark
                      ? tokens.blueSelectedBg
                      : SettingsColors.paleLavender,
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
                    builder: (_) =>
                        PeoplePage(repository: repository, home: home),
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
                    builder: (_) =>
                        HomeDetailsPage(home: home, repository: repository),
                  ),
                ),
                showDivider: true,
              ),
              SettingsListItem(
                icon: Icons.notifications_none_rounded,
                title: 'Notification preferences',
                subtitle: 'Safety, offline, and update alerts',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const NotificationPreferencesPage(),
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
        const SettingsSectionTitle('Energy and efficiency'),
        SettingsSurface(
          child: Column(
            children: [
              SettingsListItem(
                icon: Icons.bolt_rounded,
                title: 'Energy dashboard',
                subtitle: 'Live consumption, load trends, and analytics',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => HomeEnergyDashboardPage(
                      homeId: effectiveHomeId,
                      energyService: EnergyService(baseUrl: effectiveClient.baseUrl),
                    ),
                  ),
                ),
                showDivider: true,
              ),
              SettingsListItem(
                icon: Icons.eco_rounded,
                title: 'Energy optimization',
                subtitle: 'Smart schedules and cost saving recommendations',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => EnergyOptimizationPage(
                      homeId: effectiveHomeId,
                      service: EnergyAutomationService(baseUrl: effectiveClient.baseUrl),
                    ),
                  ),
                ),
                showDivider: true,
              ),
              SettingsListItem(
                icon: Icons.price_change_outlined,
                title: 'Electricity tariffs',
                subtitle: 'Time-of-use rates and utility pricing',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => TariffManagementPage(
                      homeId: effectiveHomeId,
                      costService: EnergyCostService(baseUrl: effectiveClient.baseUrl),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 27),
        const SettingsSectionTitle('Intelligence and context'),
        SettingsSurface(
          child: Column(
            children: [
              SettingsListItem(
                icon: Icons.auto_awesome_rounded,
                title: 'Intelligence center',
                subtitle: 'Autonomous decisions, routines, and confidence',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => IntelligenceCenterPage(
                      homeId: effectiveHomeId,
                      service: HomeIntelligenceService(baseUrl: effectiveClient.baseUrl),
                    ),
                  ),
                ),
                showDivider: true,
              ),
              SettingsListItem(
                icon: Icons.person_pin_circle_outlined,
                title: 'Presence & occupancy',
                subtitle: 'Real-time room occupancy and presence timeline',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => PresenceDashboardPage(
                      homeId: effectiveHomeId,
                      service: ContextPresenceService(baseUrl: effectiveClient.baseUrl),
                    ),
                  ),
                ),
                showDivider: true,
              ),
              SettingsListItem(
                icon: Icons.timeline_rounded,
                title: 'Context history',
                subtitle: 'Environmental events and context shifts',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => HomeContextPage(
                      homeId: effectiveHomeId,
                      service: ContextPresenceService(baseUrl: effectiveClient.baseUrl),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 27),
        const SettingsSectionTitle('Devices and ecosystem'),
        SettingsSurface(
          child: Column(
            children: [
              SettingsListItem(
                icon: Icons.storefront_outlined,
                title: 'Product discovery',
                subtitle: 'Browse compatible smart hardware and accessories',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ProductDiscoveryPage(
                      homeId: effectiveHomeId,
                      catalogService: ProductCatalogClientService(baseUrl: effectiveClient.baseUrl),
                    ),
                  ),
                ),
                showDivider: true,
              ),
              SettingsListItem(
                icon: Icons.health_and_safety_outlined,
                title: 'Fleet reliability',
                subtitle: 'Device health scores and incident diagnostics',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => FleetHealthPage(
                      homeId: effectiveHomeId,
                      reliabilityService: ReliabilityService(baseUrl: effectiveClient.baseUrl),
                    ),
                  ),
                ),
                showDivider: true,
              ),
              SettingsListItem(
                icon: Icons.hub_outlined,
                title: 'Multi-protocol connectivity',
                subtitle: 'BLE, MQTT, Local HTTP, and fallback transports',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => DeviceConnectivityPage(
                      deviceId: 'primary-gateway',
                      deviceName: 'Primary Home Gateway',
                      connectivityService: ConnectivityService(baseUrl: effectiveClient.baseUrl),
                    ),
                  ),
                ),
                showDivider: true,
              ),
              SettingsListItem(
                icon: Icons.share_rounded,
                title: 'Matter & Ecosystems',
                subtitle: 'Apple Home, Google Home, Alexa & Matter fabrics',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => MatterIntegrationPage(
                      homeId: effectiveHomeId,
                      matterService: MatterService(baseUrl: effectiveClient.baseUrl),
                    ),
                  ),
                ),
                showDivider: true,
              ),
              SettingsListItem(
                icon: Icons.memory_rounded,
                title: 'Edge control dashboard',
                subtitle: 'Local-first LAN control with zero cloud latency',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => EdgeExecutionDashboardPage(
                      homeId: effectiveHomeId,
                      edgeService: EdgeControlService(baseUrl: effectiveClient.baseUrl),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 27),
        const SettingsSectionTitle('Notifications and sync'),
        SettingsSurface(
          child: Column(
            children: [
              SettingsListItem(
                icon: Icons.notifications_active_outlined,
                title: 'Notification center',
                subtitle: 'Safety alerts, system events, and priority logs',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => NotificationCenterPage(
                      homeId: effectiveHomeId,
                      repository: CloudNotificationRepository(effectiveClient),
                    ),
                  ),
                ),
                showDivider: true,
              ),
              SettingsListItem(
                icon: Icons.sync_rounded,
                title: 'Sync center',
                subtitle: 'Offline queue, cache status, and conflict resolution',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => SyncCenterPage(
                      syncService: SyncService(baseUrl: effectiveClient.baseUrl),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 27),
        const SettingsSectionTitle('Observability and operations'),
        SettingsSurface(
          child: Column(
            children: [
              SettingsListItem(
                icon: Icons.monitor_heart_outlined,
                title: 'Operations dashboard',
                subtitle: 'Subsystem metrics, event audit, and API health',
                trailing: isAdmin
                    ? null
                    : SettingsStatusChip(
                        label: 'Admin only',
                        color: tokens.textSecondary,
                        background: tokens.surfaceCard,
                      ),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => OperationsDashboardPage(
                      homeId: effectiveHomeId,
                      isAdmin: isAdmin,
                      repository: CloudOperationsRepository(effectiveClient),
                    ),
                  ),
                ),
                showDivider: true,
              ),
              SettingsListItem(
                icon: Icons.verified_user_outlined,
                title: 'System readiness',
                subtitle: 'Platform operational status and subsystem health',
                trailing: isAdmin
                    ? null
                    : SettingsStatusChip(
                        label: 'Admin only',
                        color: tokens.textSecondary,
                        background: tokens.surfaceCard,
                      ),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => SystemOperationalStatusPage(
                      repository: CloudOperationalReadinessRepository(effectiveClient),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 27),
        const SettingsSectionTitle('Fleet & OTA rollouts'),
        SettingsSurface(
          child: Column(
            children: [
              SettingsListItem(
                icon: Icons.developer_board_rounded,
                title: 'Firmware releases',
                subtitle: 'Manage signed artifacts, channels, and release notes',
                trailing: isAdmin
                    ? null
                    : SettingsStatusChip(
                        label: 'Admin only',
                        color: tokens.textSecondary,
                        background: tokens.surfaceCard,
                      ),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => FirmwareReleasesPage(
                      repository: CloudFleetFirmwareRepository(effectiveClient),
                    ),
                  ),
                ),
                showDivider: true,
              ),
              SettingsListItem(
                icon: Icons.campaign_rounded,
                title: 'OTA rollout campaigns',
                subtitle: 'Controlled batched deployments, canary gates & rollbacks',
                trailing: isAdmin
                    ? null
                    : SettingsStatusChip(
                        label: 'Admin only',
                        color: tokens.textSecondary,
                        background: tokens.surfaceCard,
                      ),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => OtaRolloutsPage(
                      repository: CloudFleetFirmwareRepository(effectiveClient),
                    ),
                  ),
                ),
                showDivider: true,
              ),
              SettingsListItem(
                icon: Icons.devices_other_rounded,
                title: 'Fleet firmware status',
                subtitle: 'Per-device firmware versions, rollout states & health',
                trailing: isAdmin
                    ? null
                    : SettingsStatusChip(
                        label: 'Admin only',
                        color: tokens.textSecondary,
                        background: tokens.surfaceCard,
                      ),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => FleetFirmwareStatusPage(
                      repository: CloudFleetFirmwareRepository(effectiveClient),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 27),
        const SettingsSectionTitle('Security and resilience'),
        SettingsSurface(
          child: Column(
            children: [
              SettingsListItem(
                icon: Icons.security_rounded,
                title: 'Device trust center',
                subtitle: 'Certificate trust, secure boot, and anomaly detection',
                trailing: isAdmin
                    ? null
                    : SettingsStatusChip(
                        label: 'Admin only',
                        color: tokens.textSecondary,
                        background: tokens.surfaceCard,
                      ),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => DeviceSecurityStatusPage(
                      deviceId: 'gateway-root',
                      deviceName: 'Hardware Root of Trust',
                      isAdmin: isAdmin,
                      repository: CloudDeviceTrustRepository(effectiveClient),
                    ),
                  ),
                ),
                showDivider: true,
              ),
              SettingsListItem(
                icon: Icons.backup_rounded,
                title: 'Disaster recovery',
                subtitle: 'Configuration backups, checkpoints, and restore plans',
                trailing: isAdmin
                    ? null
                    : SettingsStatusChip(
                        label: 'Admin only',
                        color: tokens.textSecondary,
                        background: tokens.surfaceCard,
                      ),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => RecoveryDashboardPage(
                      isAdmin: isAdmin,
                      repository: CloudRecoveryRepository(effectiveClient),
                    ),
                  ),
                ),
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
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const PrivacyPage()),
                ),
                iconColor: tokens.isDark
                    ? tokens.bluePrimary
                    : SettingsColors.purple,
                iconBackground: tokens.isDark
                    ? tokens.iconBgBlue
                    : SettingsColors.palePurple,
              ),
            ],
          ),
        ),
        if (onLogout != null) ...[
          const SizedBox(height: 27),
          const SettingsSectionTitle('Account session'),
          SettingsSurface(
            child: SettingsListItem(
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
            ),
          ),
        ],
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
                      style: TextStyle(
                        color: tokens.textSecondary,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 13),
                    Wrap(
                      spacing: 9,
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
    EHThemeTokens tokens,
  ) {
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
