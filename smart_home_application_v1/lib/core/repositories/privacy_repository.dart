import '../../app/home_controller.dart';
import '../../features/auth/auth_controller.dart';
import '../api/api_client.dart';
import '../models/privacy_models.dart';
import '../models/routine_models.dart';
import '../services/app_permission_service.dart';

abstract interface class PrivacyRepository {
  Future<PrivacySummary> getSummary();
  Future<bool> setDiagnosticSharing(bool enabled);
  Future<bool> setUsageAnalytics(bool enabled);
  Future<PrivacyPermissionStatus> queryPermission(String permissionId);
  Future<PrivacyPermissionStatus> requestPermission(String permissionId);
  Future<bool> openSettings();
}

/// Dynamic, authoritative privacy repository reflecting true runtime state
/// across homes, devices, telemetry, edge routines, and authenticated identity.
class AuthoritativePrivacyRepository implements PrivacyRepository {
  AuthoritativePrivacyRepository({
    this.homeController,
    this.authController,
    this.apiClient,
    AppPermissionService? permissionService,
  }) : _permissionService = permissionService ?? AppPermissionService.instance;

  final HomeController? homeController;
  final AuthController? authController;
  final ApiClient? apiClient;
  final AppPermissionService _permissionService;

  bool _diagnosticSharing = false;
  bool _usageAnalytics = false;

  @override
  Future<PrivacySummary> getSummary() async {
    final permissionsMap = await _permissionService.queryAllPermissions();

    final permissionsList = [
      PrivacyPermission(
        id: 'bluetooth',
        title: 'Bluetooth',
        description: 'Used to discover and commission nearby hardware nodes.',
        status: permissionsMap['bluetooth'] ?? PrivacyPermissionStatus.notRequested,
      ),
      PrivacyPermission(
        id: 'notifications',
        title: 'Notifications',
        description: 'Used for critical channel alerts and hardware status updates.',
        status: permissionsMap['notifications'] ?? PrivacyPermissionStatus.notRequested,
      ),
      PrivacyPermission(
        id: 'location',
        title: 'Location',
        description: 'Required by Android to scan BLE devices during initial onboarding.',
        status: permissionsMap['location'] ?? PrivacyPermissionStatus.notRequested,
      ),
    ];

    final ctrl = homeController ?? HomeController.instance;
    final homeName = ctrl?.activeSpaceName ?? 'Primary Home';
    final homeId = ctrl?.activeHomeId ?? ctrl?.activeSpaceId ?? '';
    final rooms = ctrl?.rooms ?? [];
    final devices = ctrl?.devices ?? [];
    final onlineDevicesCount = devices.where((d) => d.online).length;
    final isCloudReachable = ctrl?.isCloudReachable ?? false;
    final hasPendingChanges = ctrl?.hasPendingCloudUpload ?? false;

    // 1. Home and Device Data
    final homeDeviceCategory = PrivacyDataCategory(
      kind: PrivacyDataCategoryKind.homeDevice,
      title: 'Home and device data',
      subtitle: '${rooms.length} ${rooms.length == 1 ? "room" : "rooms"} · ${devices.length} ${devices.length == 1 ? "device" : "devices"} ($onlineDevicesCount online)',
      summary: 'EH Home maintains configuration for "$homeName" to manage spaces, hardware nodes, and channel controls.',
      details: [
        'Home: "$homeName"${homeId.isNotEmpty ? " (ID: $homeId)" : ""} · ${rooms.length} configured rooms, ${devices.length} registered hardware nodes',
        if (rooms.isNotEmpty)
          'Configured Rooms: ${rooms.map((r) => r.name).take(4).join(", ")}${rooms.length > 4 ? "..." : ""}'
        else
          'Configured Rooms: Default space partition',
        if (devices.isNotEmpty)
          'Registered Nodes: ${devices.map((d) => "${d.name} (${d.online ? 'Online' : 'Offline'})").take(3).join(", ")}${devices.length > 3 ? "..." : ""}'
        else
          'Registered Nodes: No hardware paired yet',
        if (devices.isNotEmpty)
          'Firmware Releases: ${devices.map((d) => d.firmware).where((f) => f.isNotEmpty).toSet().join(", ")}'
        else
          'Firmware Releases: Not applicable',
        'Security Isolation: Wi-Fi credentials, private keys, and passwords are encrypted and never transmitted in application telemetry.',
      ],
      whyWeUseIt: 'To discover, orchestrate, and control your home automation hardware and channel relays.',
      storageLabel: isCloudReachable
          ? (hasPendingChanges ? 'Cloud synced (pending local modifications)' : 'Cloud synced & encrypted')
          : 'Local secure storage',
      retentionLabel: 'Retained while device is paired; wiped immediately upon device removal or factory reset.',
    );

    // 2. Activity History
    final activityHistoryCategory = PrivacyDataCategory(
      kind: PrivacyDataCategoryKind.activityHistory,
      title: 'Activity history',
      subtitle: 'Channel toggles, power state transitions, and audit logs',
      summary: 'Operational state transitions and alert events recorded to provide timeline insights and ensure audit traceability.',
      details: [
        'Relay and switch power state toggles',
        'Routine and automated scene executions',
        'Local LAN and Cloud connection transition logs',
        'Channel activity alert notifications and hardware offline events',
      ],
      whyWeUseIt: 'To visualize event timelines, troubleshoot connectivity anomalies, and maintain security auditability.',
      storageLabel: isCloudReachable ? 'Local cache & cloud encrypted audit store' : 'Local device encrypted cache',
      retentionLabel: '90-day rolling retention with automatic rolling purge.',
    );

    // 3. Routine Data
    final routines = PreviewRoutineRepository.liveRoutines;
    final enabledRoutinesCount = routines.where((r) => r.enabled).length;
    final routineCategory = PrivacyDataCategory(
      kind: PrivacyDataCategoryKind.routineData,
      title: 'Routine data',
      subtitle: '${routines.length} ${routines.length == 1 ? "routine" : "routines"} ($enabledRoutinesCount active)',
      summary: 'Automated schedules, sensor conditions, and multi-channel actions executing autonomously.',
      details: [
        if (routines.isNotEmpty)
          'Configured Routines (${routines.length}): ${routines.map((r) => r.name).take(3).join(", ")}${routines.length > 3 ? "..." : ""}'
        else
          'Configured Routines: None created yet',
        'Execution Status: $enabledRoutinesCount active schedule(s), ${routines.length - enabledRoutinesCount} paused',
        'Trigger Types: Clock schedules, environmental sensor thresholds, and manual tap controls',
        'Hardware Distribution: Synced directly to ESP32 microcontroller non-volatile storage for offline resilience',
      ],
      whyWeUseIt: 'To execute autonomous home automations locally even when Internet connectivity is down.',
      storageLabel: isCloudReachable ? 'Synchronized across local hardware & cloud engine' : 'Local hardware memory & app store',
      retentionLabel: 'Retained until edited or deleted by the user.',
    );

    // 4. Account Information
    final bool isAuthenticated = authController?.state == AuthState.authenticated;
    final user = authController?.currentUser;
    final String userEmail = user?.email ?? '';
    final String userRole = user?.role ?? (ctrl != null ? 'Owner' : 'Local Administrator');

    final accountCategory = PrivacyDataCategory(
      kind: PrivacyDataCategoryKind.accountInfo,
      title: 'Account information',
      subtitle: isAuthenticated ? (userEmail.isNotEmpty ? userEmail : 'Authenticated User') : 'Local offline profile',
      summary: isAuthenticated
          ? 'Connected to your cloud account ($userEmail) with assigned role $userRole.'
          : 'Running in local connection mode without remote cloud account dependency.',
      details: isAuthenticated
          ? [
              'Account Identity: $userEmail',
              'Role & Permissions: $userRole',
              'Home Scoping: Member of "$homeName"',
              'Session Security: Encrypted cryptographic tokens (zero raw passwords or keys logged)',
            ]
          : [
              'Operational Mode: Local LAN operational mode',
              'Account Status: Offline / Local profile',
              'Administrative Scope: Direct device access via LAN encryption',
            ],
      whyWeUseIt: 'To authenticate administrative actions, route notifications, and enforce role-based access control.',
      storageLabel: isAuthenticated ? 'Cloud Identity Provider (Encrypted)' : 'Local secure enclave',
      retentionLabel: isAuthenticated ? 'Maintained active during authenticated membership' : 'Session-only',
    );

    return PrivacySummary(
      title: 'Your privacy is in your control.',
      subtitle: 'EH Home collects only the data needed to run and secure your home.',
      statusLabel: isCloudReachable ? 'Cloud Verified' : 'Local Protected',
      dataCategories: [
        homeDeviceCategory,
        activityHistoryCategory,
        routineCategory,
        accountCategory,
      ],
      permissions: permissionsList,
      diagnosticSharing: _diagnosticSharing,
      usageAnalytics: _usageAnalytics,
      diagnosticSupported: false,
      analyticsSupported: false,
    );
  }

  @override
  Future<PrivacyPermissionStatus> queryPermission(String permissionId) =>
      _permissionService.queryPermission(permissionId);

  @override
  Future<PrivacyPermissionStatus> requestPermission(String permissionId) =>
      _permissionService.requestPermission(permissionId);

  @override
  Future<bool> openSettings() => _permissionService.openSettings();

  @override
  Future<bool> setDiagnosticSharing(bool enabled) async {
    if (!_diagnosticSharing && enabled) return false;
    _diagnosticSharing = enabled;
    return false;
  }

  @override
  Future<bool> setUsageAnalytics(bool enabled) async {
    if (!_usageAnalytics && enabled) return false;
    _usageAnalytics = enabled;
    return false;
  }
}

/// Fallback preview privacy repository that preserves backward compatibility
class PreviewPrivacyRepository implements PrivacyRepository {
  PreviewPrivacyRepository({
    AppPermissionService? permissionService,
  }) : _permissionService = permissionService ?? AppPermissionService.instance;

  final AppPermissionService _permissionService;
  bool _diagnosticSharing = false;
  bool _usageAnalytics = false;

  static const _dataCategories = [
    PrivacyDataCategory(
      kind: PrivacyDataCategoryKind.homeDevice,
      title: 'Home and device data',
      subtitle: 'Devices, rooms, and configuration',
      summary: 'EH Home stores configuration needed to manage your home and devices.',
      details: [
        'Home name, location, and time zone',
        'Device name, type, and configuration',
        'Firmware version and connection status',
      ],
      whyWeUseIt: 'To display and manage your home, devices, rooms, and settings.',
      storageLabel: 'Local secure storage',
    ),
    PrivacyDataCategory(
      kind: PrivacyDataCategoryKind.activityHistory,
      title: 'Activity history',
      subtitle: 'Events and actions in your home',
      summary: 'Activity records provide timeline transparency and diagnostic monitoring.',
      details: [
        'Device state changes',
        'Routine executions',
        'Connection events',
        'System events and device warnings',
      ],
      whyWeUseIt: 'To show history and help troubleshoot issues.',
      storageLabel: 'Local secure storage',
      retentionLabel: 'Until you delete it',
    ),
    PrivacyDataCategory(
      kind: PrivacyDataCategoryKind.routineData,
      title: 'Routine data',
      subtitle: 'Your routines, schedules and actions',
      summary: 'Your routines include triggers, conditions, and actions.',
      details: [
        'Routine name and schedule',
        'Triggers, conditions, and actions',
        'Device references used by routines',
      ],
      whyWeUseIt: 'To run and display your routines.',
      storageLabel: 'Local secure storage',
    ),
    PrivacyDataCategory(
      kind: PrivacyDataCategoryKind.accountInfo,
      title: 'Account information',
      subtitle: 'Account, membership and access',
      summary: 'Operating in local profile mode without remote cloud account dependency.',
      details: [
        'Operational Mode: Local LAN operational mode',
        'Access Control: Local device administrator',
      ],
      whyWeUseIt: 'To manage access and permissions.',
      storageLabel: 'Local device enclave',
    ),
  ];

  @override
  Future<PrivacySummary> getSummary() async {
    final permissionsMap = await _permissionService.queryAllPermissions();

    final permissionsList = [
      PrivacyPermission(
        id: 'bluetooth',
        title: 'Bluetooth',
        description: 'Used to discover and connect devices.',
        status: permissionsMap['bluetooth'] ?? PrivacyPermissionStatus.notRequested,
      ),
      PrivacyPermission(
        id: 'notifications',
        title: 'Notifications',
        description: 'Used for alerts and important updates.',
        status: permissionsMap['notifications'] ?? PrivacyPermissionStatus.notRequested,
      ),
      PrivacyPermission(
        id: 'location',
        title: 'Location',
        description: 'Used for location-based features.',
        status: permissionsMap['location'] ?? PrivacyPermissionStatus.notRequested,
      ),
    ];

    return PrivacySummary(
      title: 'Your privacy is in your control.',
      subtitle: 'EH Home collects only the data needed to run your home.',
      statusLabel: 'Local Protected',
      dataCategories: _dataCategories,
      permissions: permissionsList,
      diagnosticSharing: _diagnosticSharing,
      usageAnalytics: _usageAnalytics,
      diagnosticSupported: false,
      analyticsSupported: false,
    );
  }

  @override
  Future<PrivacyPermissionStatus> queryPermission(String permissionId) =>
      _permissionService.queryPermission(permissionId);

  @override
  Future<PrivacyPermissionStatus> requestPermission(String permissionId) =>
      _permissionService.requestPermission(permissionId);

  @override
  Future<bool> openSettings() => _permissionService.openSettings();

  @override
  Future<bool> setDiagnosticSharing(bool enabled) async {
    if (!_diagnosticSharing && enabled) return false;
    _diagnosticSharing = enabled;
    return false;
  }

  @override
  Future<bool> setUsageAnalytics(bool enabled) async {
    if (!_usageAnalytics && enabled) return false;
    _usageAnalytics = enabled;
    return false;
  }
}
