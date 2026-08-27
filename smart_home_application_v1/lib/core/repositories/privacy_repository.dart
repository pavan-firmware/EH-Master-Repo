import '../models/privacy_models.dart';

abstract interface class PrivacyRepository {
  Future<PrivacySummary> getSummary();
  Future<bool> setDiagnosticSharing(bool enabled);
  Future<bool> setUsageAnalytics(bool enabled);
}

class PreviewPrivacyRepository implements PrivacyRepository {
  PreviewPrivacyRepository();

  bool _diagnosticSharing = false;
  bool _usageAnalytics = false;

  static const _dataCategories = [
    PrivacyDataCategory(
      kind: PrivacyDataCategoryKind.homeDevice,
      title: 'Home and device data',
      subtitle: 'Devices, rooms, and configuration',
      summary:
          'EH Home stores information needed to manage your home and devices.',
      details: [
        'Home name, location, and time zone',
        'Device name, type, and configuration',
        'Firmware version and connection status',
      ],
      whyWeUseIt:
          'To display and manage your home, devices, rooms, and settings.',
      storageLabel: 'Local preview',
    ),
    PrivacyDataCategory(
      kind: PrivacyDataCategoryKind.activityHistory,
      title: 'Activity history',
      subtitle: 'Events and actions in your home',
      summary:
          'Activity records help you understand what happened in your home.',
      details: [
        'Device state changes',
        'Routine executions',
        'Connection events',
        'System events and device warnings',
      ],
      whyWeUseIt: 'To show history and help troubleshoot issues.',
      storageLabel: 'Local preview',
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
      storageLabel: 'Local preview',
    ),
    PrivacyDataCategory(
      kind: PrivacyDataCategoryKind.accountInfo,
      title: 'Account information',
      subtitle: 'Account, membership and access',
      summary: 'No cloud account is connected in this preview build.',
      details: [
        'Home ownership is stored locally for preview',
        'Membership and invitations are preview-only',
      ],
      whyWeUseIt: 'To manage access when account services are enabled.',
      storageLabel: 'Not connected yet',
    ),
  ];

  @override
  Future<PrivacySummary> getSummary() async => PrivacySummary(
    title: 'Your privacy is in your control.',
    subtitle: 'EH Home collects only the data needed to run your home.',
    statusLabel: 'All good.',
    dataCategories: _dataCategories,
    permissions: const [
      PrivacyPermission(
        id: 'bluetooth',
        title: 'Bluetooth',
        description: 'Used to discover and connect devices.',
        status: PrivacyPermissionStatus.allowed,
      ),
      PrivacyPermission(
        id: 'notifications',
        title: 'Notifications',
        description: 'Used for alerts and important updates.',
        status: PrivacyPermissionStatus.allowed,
      ),
      PrivacyPermission(
        id: 'location',
        title: 'Location',
        description: 'Used for location-based features.',
        status: PrivacyPermissionStatus.notRequested,
      ),
    ],
    diagnosticSharing: _diagnosticSharing,
    usageAnalytics: _usageAnalytics,
    diagnosticSupported: false,
    analyticsSupported: false,
  );

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
