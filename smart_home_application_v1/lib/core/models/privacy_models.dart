enum PrivacyPermissionStatus {
  allowed,
  whileUsing,
  denied,
  notRequested,
  permanentlyDenied,
  unavailable;

  String get label => switch (this) {
    PrivacyPermissionStatus.allowed => 'Allowed',
    PrivacyPermissionStatus.whileUsing => 'While using the app',
    PrivacyPermissionStatus.denied => 'Denied',
    PrivacyPermissionStatus.notRequested => 'Not requested',
    PrivacyPermissionStatus.permanentlyDenied => 'Permanently denied',
    PrivacyPermissionStatus.unavailable => 'Unavailable',
  };

  bool get isGranted =>
      this == PrivacyPermissionStatus.allowed ||
      this == PrivacyPermissionStatus.whileUsing;

  bool get isDenied =>
      this == PrivacyPermissionStatus.denied ||
      this == PrivacyPermissionStatus.permanentlyDenied;

  bool get isPermanentlyDenied =>
      this == PrivacyPermissionStatus.permanentlyDenied;
}

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

  String get statusLabel => status.label;

  PrivacyPermission copyWith({
    String? id,
    String? title,
    String? description,
    PrivacyPermissionStatus? status,
  }) =>
      PrivacyPermission(
        id: id ?? this.id,
        title: title ?? this.title,
        description: description ?? this.description,
        status: status ?? this.status,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PrivacyPermission &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          title == other.title &&
          description == other.description &&
          status == other.status;

  @override
  int get hashCode => Object.hash(id, title, description, status);
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

  PrivacySummary copyWith({
    String? title,
    String? subtitle,
    String? statusLabel,
    List<PrivacyDataCategory>? dataCategories,
    List<PrivacyPermission>? permissions,
    bool? diagnosticSharing,
    bool? usageAnalytics,
    bool? diagnosticSupported,
    bool? analyticsSupported,
  }) =>
      PrivacySummary(
        title: title ?? this.title,
        subtitle: subtitle ?? this.subtitle,
        statusLabel: statusLabel ?? this.statusLabel,
        dataCategories: dataCategories ?? this.dataCategories,
        permissions: permissions ?? this.permissions,
        diagnosticSharing: diagnosticSharing ?? this.diagnosticSharing,
        usageAnalytics: usageAnalytics ?? this.usageAnalytics,
        diagnosticSupported: diagnosticSupported ?? this.diagnosticSupported,
        analyticsSupported: analyticsSupported ?? this.analyticsSupported,
      );
}
