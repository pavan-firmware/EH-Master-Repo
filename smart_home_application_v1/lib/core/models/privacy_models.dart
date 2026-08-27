enum PrivacyPermissionStatus { allowed, denied, notRequested, unavailable }

enum PrivacyDataCategoryKind {
  homeDevice,
  activityHistory,
  routineData,
  accountInfo,
}

class PrivacyPermission {
  const PrivacyPermission({
    required this.id,
    required this.title,
    required this.description,
    required this.status,
  });

  final String id;
  final String title;
  final String description;
  final PrivacyPermissionStatus status;

  String get statusLabel => switch (status) {
    PrivacyPermissionStatus.allowed => 'Allowed',
    PrivacyPermissionStatus.denied => 'Denied',
    PrivacyPermissionStatus.notRequested => 'Not requested',
    PrivacyPermissionStatus.unavailable => 'Unavailable',
  };
}

class PrivacyDataCategory {
  const PrivacyDataCategory({
    required this.kind,
    required this.title,
    required this.subtitle,
    required this.summary,
    required this.details,
    required this.whyWeUseIt,
    this.storageLabel,
    this.retentionLabel,
  });

  final PrivacyDataCategoryKind kind;
  final String title;
  final String subtitle;
  final String summary;
  final List<String> details;
  final String whyWeUseIt;
  final String? storageLabel;
  final String? retentionLabel;
}

class PrivacySummary {
  const PrivacySummary({
    required this.title,
    required this.subtitle,
    required this.statusLabel,
    required this.dataCategories,
    required this.permissions,
    required this.diagnosticSharing,
    required this.usageAnalytics,
    required this.diagnosticSupported,
    required this.analyticsSupported,
  });

  final String title;
  final String subtitle;
  final String statusLabel;
  final List<PrivacyDataCategory> dataCategories;
  final List<PrivacyPermission> permissions;
  final bool diagnosticSharing;
  final bool usageAnalytics;
  final bool diagnosticSupported;
  final bool analyticsSupported;
}
