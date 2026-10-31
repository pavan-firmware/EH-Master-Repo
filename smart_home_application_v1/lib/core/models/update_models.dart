enum UpdateTargetKind { app, hub, device }

enum UpdateTargetStatus {
  upToDate,
  updateAvailable,
  unavailable,
  updating,
  failed,
}

enum UpdateOverallStatus { upToDate, updateAvailable, checking, unavailable }

enum UpdateErrorType { none, noInternet, serverUnreachable, serverError }

class UpdateTarget {
  const UpdateTarget({
    required this.kind,
    required this.name,
    required this.currentVersion,
    required this.status,
    this.availableVersion,
    this.statusDetail,
    this.iconKey,
    this.deviceId,
    this.releaseId,
    this.downloadUrl,
    this.releaseNotes,
    this.homeId,
    this.sha256,
    this.binarySizeBytes,
    this.whyUpdate,
    this.component,
  });

  final UpdateTargetKind kind;
  final String name;
  final String currentVersion;
  final UpdateTargetStatus status;
  final String? availableVersion;
  final String? statusDetail;
  final String? iconKey;
  final String? deviceId;
  final String? releaseId;
  final String? downloadUrl;
  final String? releaseNotes;
  final String? homeId;
  final String? sha256;
  final int? binarySizeBytes;
  final String? whyUpdate;
  final String? component;

  String get formattedSize {
    if (binarySizeBytes == null || binarySizeBytes! <= 0) return '';
    final mb = binarySizeBytes! / (1024 * 1024);
    return '${mb.toStringAsFixed(2)} MB';
  }

  bool get isDirectUpgrade {
    if (availableVersion == null) return false;
    // Cleans strings like 'Version 1.0.1' and 'Firmware 1.0.0'
    final cur = currentVersion.replaceAll(RegExp(r'[^0-9.]'), '');
    final target = availableVersion!.replaceAll(RegExp(r'[^0-9.]'), '');
    return cur.isNotEmpty && target.isNotEmpty && cur != target;
  }

  String get effectiveWhyUpdate {
    if (whyUpdate != null && whyUpdate!.isNotEmpty) return whyUpdate!;
    if (releaseNotes != null && releaseNotes!.isNotEmpty) {
      return 'Essential system upgrade: optimizes hardware timing, provides secure communications, and installs safety patches.';
    }
    return 'Recommended maintenance update to ensure stability, responsiveness, and safe operation.';
  }

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
    this.errorType = UpdateErrorType.none,
    this.errorMessage,
  });

  final UpdateOverallStatus overallStatus;
  final String title;
  final String subtitle;
  final String statusLabel;
  final DateTime lastChecked;
  final List<UpdateTarget> targets;
  final List<UpdateHistoryEntry> history;
  final String appVersion;
  final UpdateErrorType errorType;
  final String? errorMessage;

  bool get isUnavailable => overallStatus == UpdateOverallStatus.unavailable || errorType != UpdateErrorType.none;

  int get availableCount => targets
      .where((t) => t.status == UpdateTargetStatus.updateAvailable)
      .length;
}
