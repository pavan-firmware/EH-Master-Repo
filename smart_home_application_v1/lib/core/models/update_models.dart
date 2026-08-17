enum UpdateTargetKind { app, hub, device }

enum UpdateTargetStatus {
  upToDate,
  updateAvailable,
  unavailable,
  updating,
  failed,
}

enum UpdateOverallStatus { upToDate, updateAvailable, checking, unavailable }

class UpdateTarget {
  const UpdateTarget({
    required this.kind,
    required this.name,
    required this.currentVersion,
    required this.status,
    this.availableVersion,
    this.statusDetail,
    this.iconKey,
  });

  final UpdateTargetKind kind;
  final String name;
  final String currentVersion;
  final UpdateTargetStatus status;
  final String? availableVersion;
  final String? statusDetail;
  final String? iconKey;

  String get statusLabel => switch (status) {
        UpdateTargetStatus.upToDate => 'Up to date',
        UpdateTargetStatus.updateAvailable => 'Update available',
        UpdateTargetStatus.unavailable => statusDetail ?? 'Unavailable',
        UpdateTargetStatus.updating => 'Updating',
        UpdateTargetStatus.failed => 'Update failed',
      };
}

class UpdateHistoryEntry {
  const UpdateHistoryEntry({
    required this.id,
    required this.title,
    required this.deviceName,
    required this.result,
    required this.installedAt,
    this.releaseNotes,
  });

  final String id;
  final String title;
  final String deviceName;
  final String result;
  final DateTime installedAt;
  final String? releaseNotes;
}

class UpdateSummary {
  const UpdateSummary({
    required this.overallStatus,
    required this.title,
    required this.subtitle,
    required this.statusLabel,
    required this.lastChecked,
    required this.targets,
    required this.history,
    this.appVersion = '1.0.0',
  });

  final UpdateOverallStatus overallStatus;
  final String title;
  final String subtitle;
  final String statusLabel;
  final DateTime lastChecked;
  final List<UpdateTarget> targets;
  final List<UpdateHistoryEntry> history;
  final String appVersion;

  int get availableCount =>
      targets.where((t) => t.status == UpdateTargetStatus.updateAvailable).length;
}
