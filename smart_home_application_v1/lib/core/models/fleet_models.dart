// EH Home — Device Fleet Management & OTA Data Models (Phase 18 & Phase 41)

enum OtaOperationStatus {
  queued,
  available,
  downloading,
  verifying,
  installing,
  rebooting,
  confirming,
  success,
  failed,
  rolledBack;

  static OtaOperationStatus fromString(String? val) {
    if (val == null) return OtaOperationStatus.available;
    switch (val.toUpperCase()) {
      case 'QUEUED':
        return OtaOperationStatus.queued;
      case 'AVAILABLE':
        return OtaOperationStatus.available;
      case 'DOWNLOADING':
        return OtaOperationStatus.downloading;
      case 'VERIFYING':
        return OtaOperationStatus.verifying;
      case 'INSTALLING':
      case 'APPLYING':
      case 'INSTALLED':
        return OtaOperationStatus.installing;
      case 'REBOOTING':
      case 'BOOT_VERIFIED':
        return OtaOperationStatus.rebooting;
      case 'CONFIRMING':
        return OtaOperationStatus.confirming;
      case 'SUCCESS':
      case 'HEALTH_VERIFIED':
      case 'COMPLETED':
        return OtaOperationStatus.success;
      case 'FAILED':
      case 'FAILED_THRESHOLD_PAUSED':
        return OtaOperationStatus.failed;
      case 'ROLLED_BACK':
      case 'ROLLING_BACK':
        return OtaOperationStatus.rolledBack;
      default:
        return OtaOperationStatus.available;
    }
  }

  String toApiString() {
    switch (this) {
      case OtaOperationStatus.queued:
        return 'QUEUED';
      case OtaOperationStatus.available:
        return 'AVAILABLE';
      case OtaOperationStatus.downloading:
        return 'DOWNLOADING';
      case OtaOperationStatus.verifying:
        return 'VERIFYING';
      case OtaOperationStatus.installing:
        return 'INSTALLING';
      case OtaOperationStatus.rebooting:
        return 'REBOOTING';
      case OtaOperationStatus.confirming:
        return 'CONFIRMING';
      case OtaOperationStatus.success:
        return 'SUCCESS';
      case OtaOperationStatus.failed:
        return 'FAILED';
      case OtaOperationStatus.rolledBack:
        return 'ROLLED_BACK';
    }
  }
}

/// Firmware release metadata model (Phase 18)
class FirmwareRelease {
  final String id;
  final String productVariantId;
  final String? hardwareRevision;
  final String firmwareFamily;
  final String version;
  final String? minFirmwareVersion;
  final String releaseChannel;
  final int binarySizeBytes;
  final String sha256;
  final String downloadUrl;
  final String? releaseNotes;
  final String status;
  final DateTime? createdAt;
  final DateTime? releasedAt;

  const FirmwareRelease({
    required this.id,
    required this.productVariantId,
    this.hardwareRevision,
    required this.firmwareFamily,
    required this.version,
    this.minFirmwareVersion,
    required this.releaseChannel,
    required this.binarySizeBytes,
    required this.sha256,
    required this.downloadUrl,
    this.releaseNotes,
    this.status = 'PUBLISHED',
    this.createdAt,
    this.releasedAt,
  });

  factory FirmwareRelease.fromJson(Map<String, dynamic> json) {
    return FirmwareRelease(
      id: (json['id'] ?? json['releaseId'] ?? '') as String,
      productVariantId: (json['product_variant_id'] ?? json['productVariantId'] ?? '') as String,
      hardwareRevision: (json['hardware_revision'] ?? json['hardwareRevision']) as String?,
      firmwareFamily: (json['firmware_family'] ?? json['firmwareFamily'] ?? 'esp32-platform') as String,
      version: (json['version'] ?? '1.0.0') as String,
      minFirmwareVersion: (json['min_firmware_version'] ?? json['minFirmwareVersion']) as String?,
      releaseChannel: (json['release_channel'] ?? json['releaseChannel'] ?? 'production') as String,
      binarySizeBytes: (json['binary_size_bytes'] ?? json['binarySizeBytes'] ?? 0) as int,
      sha256: (json['sha256'] ?? '') as String,
      downloadUrl: (json['download_url'] ?? json['downloadUrl'] ?? '') as String,
      releaseNotes: (json['release_notes'] ?? json['releaseNotes']) as String?,
      status: (json['status'] ?? 'PUBLISHED') as String,
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'].toString()) : null,
      releasedAt: json['released_at'] != null ? DateTime.tryParse(json['released_at'].toString()) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'productVariantId': productVariantId,
      'hardwareRevision': hardwareRevision,
      'firmwareFamily': firmwareFamily,
      'version': version,
      'minFirmwareVersion': minFirmwareVersion,
      'releaseChannel': releaseChannel,
      'binarySizeBytes': binarySizeBytes,
      'sha256': sha256,
      'downloadUrl': downloadUrl,
      'releaseNotes': releaseNotes,
      'status': status,
      'createdAt': createdAt?.toIso8601String(),
      'releasedAt': releasedAt?.toIso8601String(),
    };
  }
}

/// In-flight or historical OTA operation (Phase 18)
class OtaOperation {
  final String id;
  final String deviceId;
  final String homeId;
  final String releaseId;
  final String fromVersion;
  final String targetVersion;
  final OtaOperationStatus status;
  final int progressPercent;
  final String? errorCode;
  final String? errorMessage;
  final String startedAt;
  final String? completedAt;

  const OtaOperation({
    required this.id,
    required this.deviceId,
    required this.homeId,
    required this.releaseId,
    required this.fromVersion,
    required this.targetVersion,
    required this.status,
    required this.progressPercent,
    this.errorCode,
    this.errorMessage,
    required this.startedAt,
    this.completedAt,
  });

  factory OtaOperation.fromJson(Map<String, dynamic> json) {
    return OtaOperation(
      id: (json['id'] ?? '') as String,
      deviceId: (json['device_id'] ?? json['deviceId'] ?? '') as String,
      homeId: (json['home_id'] ?? json['homeId'] ?? '') as String,
      releaseId: (json['release_id'] ?? json['releaseId'] ?? '') as String,
      fromVersion: (json['from_version'] ?? json['fromVersion'] ?? '1.0.0') as String,
      targetVersion: (json['target_version'] ?? json['targetVersion'] ?? '1.0.0') as String,
      status: OtaOperationStatus.fromString((json['status'] ?? '') as String),
      progressPercent: (json['progress_percent'] ?? json['progressPercent'] ?? 0) as int,
      errorCode: (json['error_code'] ?? json['errorCode']) as String?,
      errorMessage: (json['error_message'] ?? json['errorMessage']) as String?,
      startedAt: (json['started_at'] ?? json['startedAt'] ?? '') as String,
      completedAt: (json['completed_at'] ?? json['completedAt']) as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'deviceId': deviceId,
      'homeId': homeId,
      'releaseId': releaseId,
      'fromVersion': fromVersion,
      'targetVersion': targetVersion,
      'status': status.toApiString(),
      'progressPercent': progressPercent,
      'errorCode': errorCode,
      'errorMessage': errorMessage,
      'startedAt': startedAt,
      'completedAt': completedAt,
    };
  }
}

/// Device summary item in the fleet health dashboard (Phase 18)
class FleetDeviceSummary {
  final String deviceId;
  final String? serialNumber;
  final String productVariantId;
  final String? hardwareRevision;
  final String? firmwareFamily;
  final String firmwareVersion;
  final String? customName;
  final String? homeId;
  final String? roomId;
  final String healthStatus;
  final String connectionState;
  final String? lastSeenAt;
  final OtaOperationStatus? otaStatus;
  final Map<String, dynamic>? availableUpdate;

  const FleetDeviceSummary({
    required this.deviceId,
    this.serialNumber,
    required this.productVariantId,
    this.hardwareRevision,
    this.firmwareFamily,
    required this.firmwareVersion,
    this.customName,
    this.homeId,
    this.roomId,
    required this.healthStatus,
    required this.connectionState,
    this.lastSeenAt,
    this.otaStatus,
    this.availableUpdate,
  });

  factory FleetDeviceSummary.fromJson(Map<String, dynamic> json) {
    return FleetDeviceSummary(
      deviceId: (json['deviceId'] ?? json['device_id'] ?? '') as String,
      serialNumber: (json['serialNumber'] ?? json['serial_number']) as String?,
      productVariantId: (json['productVariantId'] ?? json['product_variant_id'] ?? '') as String,
      hardwareRevision: (json['hardwareRevision'] ?? json['hardware_revision']) as String?,
      firmwareFamily: (json['firmwareFamily'] ?? json['firmware_family']) as String?,
      firmwareVersion: (json['firmwareVersion'] ?? json['firmware_version'] ?? '1.0.0') as String,
      customName: (json['customName'] ?? json['custom_name']) as String?,
      homeId: (json['homeId'] ?? json['home_id']) as String?,
      roomId: (json['roomId'] ?? json['room_id']) as String?,
      healthStatus: (json['healthStatus'] ?? json['health_status'] ?? 'UNKNOWN') as String,
      connectionState: (json['connectionState'] ?? json['connection_state'] ?? 'OFFLINE') as String,
      lastSeenAt: (json['lastSeenAt'] ?? json['last_seen_at']) as String?,
      otaStatus: json['otaStatus'] != null
          ? OtaOperationStatus.fromString(json['otaStatus'] as String)
          : null,
      availableUpdate: json['availableUpdate'] != null
          ? Map<String, dynamic>.from(json['availableUpdate'] as Map)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'deviceId': deviceId,
      'serialNumber': serialNumber,
      'productVariantId': productVariantId,
      'hardwareRevision': hardwareRevision,
      'firmwareFamily': firmwareFamily,
      'firmwareVersion': firmwareVersion,
      'customName': customName,
      'homeId': homeId,
      'roomId': roomId,
      'healthStatus': healthStatus,
      'connectionState': connectionState,
      'lastSeenAt': lastSeenAt,
      'otaStatus': otaStatus?.toApiString(),
      'availableUpdate': availableUpdate,
    };
  }
}

/// Aggregated fleet status metrics (Phase 18)
class FleetStatus {
  final int schemaVersion;
  final String? homeId;
  final int totalDevices;
  final int onlineDevices;
  final int offlineDevices;
  final int staleDevices;
  final int degradedDevices;
  final int otaUpdateAvailableCount;
  final int otaInProgressCount;
  final int otaFailedCount;
  final List<FleetDeviceSummary> devices;

  const FleetStatus({
    this.schemaVersion = 1,
    this.homeId,
    required this.totalDevices,
    required this.onlineDevices,
    required this.offlineDevices,
    required this.staleDevices,
    required this.degradedDevices,
    required this.otaUpdateAvailableCount,
    required this.otaInProgressCount,
    required this.otaFailedCount,
    required this.devices,
  });

  factory FleetStatus.fromJson(Map<String, dynamic> json) {
    final devList = (json['devices'] as List? ?? [])
        .map((d) => FleetDeviceSummary.fromJson(Map<String, dynamic>.from(d as Map)))
        .toList();

    return FleetStatus(
      schemaVersion: (json['schemaVersion'] ?? 1) as int,
      homeId: json['homeId'] as String?,
      totalDevices: (json['totalDevices'] ?? devList.length) as int,
      onlineDevices: (json['onlineDevices'] ?? 0) as int,
      offlineDevices: (json['offlineDevices'] ?? 0) as int,
      staleDevices: (json['staleDevices'] ?? 0) as int,
      degradedDevices: (json['degradedDevices'] ?? 0) as int,
      otaUpdateAvailableCount: (json['otaUpdateAvailableCount'] ?? 0) as int,
      otaInProgressCount: (json['otaInProgressCount'] ?? 0) as int,
      otaFailedCount: (json['otaFailedCount'] ?? 0) as int,
      devices: devList,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'schemaVersion': schemaVersion,
      'homeId': homeId,
      'totalDevices': totalDevices,
      'onlineDevices': onlineDevices,
      'offlineDevices': offlineDevices,
      'staleDevices': staleDevices,
      'degradedDevices': degradedDevices,
      'otaUpdateAvailableCount': otaUpdateAvailableCount,
      'otaInProgressCount': otaInProgressCount,
      'otaFailedCount': otaFailedCount,
      'devices': devices.map((d) => d.toJson()).toList(),
    };
  }
}

/// Device maintenance & upgrade audit log (Phase 18)
class DeviceMaintenanceLog {
  final String id;
  final String deviceId;
  final String homeId;
  final String operationType;
  final String? releaseId;
  final String? fromVersion;
  final String? toVersion;
  final String status;
  final Map<String, dynamic>? details;
  final DateTime createdAt;

  const DeviceMaintenanceLog({
    required this.id,
    required this.deviceId,
    required this.homeId,
    required this.operationType,
    this.releaseId,
    this.fromVersion,
    this.toVersion,
    required this.status,
    this.details,
    required this.createdAt,
  });

  factory DeviceMaintenanceLog.fromJson(Map<String, dynamic> json) {
    return DeviceMaintenanceLog(
      id: (json['id'] ?? '') as String,
      deviceId: (json['device_id'] ?? json['deviceId'] ?? '') as String,
      homeId: (json['home_id'] ?? json['homeId'] ?? '') as String,
      operationType: (json['operation_type'] ?? json['operationType'] ?? 'FIRMWARE_UPGRADE') as String,
      releaseId: (json['release_id'] ?? json['releaseId']) as String?,
      fromVersion: (json['from_version'] ?? json['fromVersion']) as String?,
      toVersion: (json['to_version'] ?? json['toVersion']) as String?,
      status: (json['status'] ?? 'SUCCESS') as String,
      details: json['details_json'] != null
          ? (json['details_json'] is String
              ? null
              : Map<String, dynamic>.from(json['details_json'] as Map))
          : (json['details'] != null ? Map<String, dynamic>.from(json['details'] as Map) : null),
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
    );
  }
}

// ==========================================
// PHASE 41 — PRODUCTION FLEET & SAFE OTA MODELS
// ==========================================

class FirmwareReleaseModel {
  const FirmwareReleaseModel({
    required this.id,
    required this.productVariantId,
    this.hardwareRevision,
    required this.firmwareFamily,
    required this.version,
    this.minFirmwareVersion,
    required this.releaseChannel,
    required this.binarySizeBytes,
    required this.sha256,
    required this.ed25519Signature,
    required this.downloadUrl,
    this.releaseNotes,
    required this.status,
    required this.createdAt,
    this.releasedAt,
  });

  final String id;
  final String productVariantId;
  final String? hardwareRevision;
  final String firmwareFamily;
  final String version;
  final String? minFirmwareVersion;
  final String releaseChannel;
  final int binarySizeBytes;
  final String sha256;
  final String ed25519Signature;
  final String downloadUrl;
  final String? releaseNotes;
  final String status;
  final String createdAt;
  final String? releasedAt;

  factory FirmwareReleaseModel.fromJson(Map<String, dynamic> json) {
    return FirmwareReleaseModel(
      id: (json['id'] ?? json['releaseId'] ?? '').toString(),
      productVariantId: (json['productVariantId'] ?? json['product_variant_id'] ?? '').toString(),
      hardwareRevision: json['hardwareRevision']?.toString() ?? json['hardware_revision']?.toString(),
      firmwareFamily: (json['firmwareFamily'] ?? json['firmware_family'] ?? 'esp32-platform').toString(),
      version: (json['version'] ?? '1.0.0').toString(),
      minFirmwareVersion: json['minFirmwareVersion']?.toString() ?? json['min_firmware_version']?.toString(),
      releaseChannel: (json['releaseChannel'] ?? json['release_channel'] ?? 'production').toString(),
      binarySizeBytes: json['binarySizeBytes'] is num
          ? (json['binarySizeBytes'] as num).toInt()
          : (json['binary_size_bytes'] is num ? (json['binary_size_bytes'] as num).toInt() : 0),
      sha256: (json['sha256'] ?? '').toString(),
      ed25519Signature: (json['ed25519Signature'] ?? json['ed25519_signature'] ?? '').toString(),
      downloadUrl: (json['downloadUrl'] ?? json['download_url'] ?? '').toString(),
      releaseNotes: json['releaseNotes']?.toString() ?? json['release_notes']?.toString(),
      status: (json['status'] ?? 'PUBLISHED').toString(),
      createdAt: (json['createdAt'] ?? json['created_at'] ?? '').toString(),
      releasedAt: json['releasedAt']?.toString() ?? json['released_at']?.toString(),
    );
  }
}

class OtaRolloutStatistics {
  const OtaRolloutStatistics({
    this.totalEligible = 0,
    this.totalTargeted = 0,
    this.inProgress = 0,
    this.installed = 0,
    this.bootVerified = 0,
    this.healthVerified = 0,
    this.failed = 0,
    this.rolledBack = 0,
  });

  final int totalEligible;
  final int totalTargeted;
  final int inProgress;
  final int installed;
  final int bootVerified;
  final int healthVerified;
  final int failed;
  final int rolledBack;

  factory OtaRolloutStatistics.fromJson(Map<String, dynamic> json) {
    return OtaRolloutStatistics(
      totalEligible: (json['totalEligible'] as num?)?.toInt() ?? 0,
      totalTargeted: (json['totalTargeted'] as num?)?.toInt() ?? 0,
      inProgress: (json['inProgress'] as num?)?.toInt() ?? 0,
      installed: (json['installed'] as num?)?.toInt() ?? 0,
      bootVerified: (json['bootVerified'] as num?)?.toInt() ?? 0,
      healthVerified: (json['healthVerified'] as num?)?.toInt() ?? 0,
      failed: (json['failed'] as num?)?.toInt() ?? 0,
      rolledBack: (json['rolledBack'] as num?)?.toInt() ?? 0,
    );
  }
}

class OtaRolloutModel {
  const OtaRolloutModel({
    required this.id,
    required this.releaseId,
    this.homeId,
    this.productScope,
    this.channel = 'production',
    required this.rolloutState,
    this.rolloutPercentage = 10,
    this.batchSize = 5,
    this.maxConcurrency = 3,
    this.failureThresholdPercentage = 20,
    this.failureThresholdCount = 3,
    this.statistics = const OtaRolloutStatistics(),
    this.startedAt,
    this.pausedAt,
    this.completedAt,
    required this.createdAt,
  });

  final String id;
  final String releaseId;
  final String? homeId;
  final String? productScope;
  final String channel;
  final String rolloutState;
  final int rolloutPercentage;
  final int batchSize;
  final int maxConcurrency;
  final int failureThresholdPercentage;
  final int failureThresholdCount;
  final OtaRolloutStatistics statistics;
  final String? startedAt;
  final String? pausedAt;
  final String? completedAt;
  final String createdAt;

  factory OtaRolloutModel.fromJson(Map<String, dynamic> json) {
    final statsJson = json['statistics'] is Map<String, dynamic>
        ? json['statistics'] as Map<String, dynamic>
        : (json['statistics_json'] is Map<String, dynamic> ? json['statistics_json'] as Map<String, dynamic> : <String, dynamic>{});

    return OtaRolloutModel(
      id: (json['id'] ?? '').toString(),
      releaseId: (json['releaseId'] ?? json['release_id'] ?? '').toString(),
      homeId: json['homeId']?.toString() ?? json['home_id']?.toString(),
      productScope: json['productScope']?.toString() ?? json['product_scope']?.toString(),
      channel: (json['channel'] ?? 'production').toString(),
      rolloutState: (json['rolloutState'] ?? json['rollout_state'] ?? json['status'] ?? 'DRAFT').toString(),
      rolloutPercentage: (json['rolloutPercentage'] as num?)?.toInt() ?? (json['rollout_percentage'] as num?)?.toInt() ?? 10,
      batchSize: (json['batchSize'] as num?)?.toInt() ?? (json['batch_size'] as num?)?.toInt() ?? 5,
      maxConcurrency: (json['maxConcurrency'] as num?)?.toInt() ?? (json['max_concurrency'] as num?)?.toInt() ?? 3,
      failureThresholdPercentage: (json['failureThresholdPercentage'] as num?)?.toInt() ?? (json['failure_threshold_percentage'] as num?)?.toInt() ?? 20,
      failureThresholdCount: (json['failureThresholdCount'] as num?)?.toInt() ?? (json['failure_threshold_count'] as num?)?.toInt() ?? 3,
      statistics: OtaRolloutStatistics.fromJson(statsJson),
      startedAt: json['startedAt']?.toString() ?? json['started_at']?.toString(),
      pausedAt: json['pausedAt']?.toString() ?? json['paused_at']?.toString(),
      completedAt: json['completedAt']?.toString() ?? json['completed_at']?.toString(),
      createdAt: (json['createdAt'] ?? json['created_at'] ?? '').toString(),
    );
  }
}

class FleetDeviceFirmwareStateModel {
  const FleetDeviceFirmwareStateModel({
    required this.deviceId,
    required this.productVariantId,
    required this.currentFirmwareVersion,
    this.targetFirmwareVersion,
    this.rolloutId,
    this.rolloutState,
    this.lastOtaResult,
    this.lastAttemptAt,
    this.failureReason,
    required this.healthVerificationState,
    required this.updatedAt,
  });

  final String deviceId;
  final String productVariantId;
  final String currentFirmwareVersion;
  final String? targetFirmwareVersion;
  final String? rolloutId;
  final String? rolloutState;
  final String? lastOtaResult;
  final String? lastAttemptAt;
  final String? failureReason;
  final String healthVerificationState;
  final String updatedAt;

  factory FleetDeviceFirmwareStateModel.fromJson(Map<String, dynamic> json) {
    return FleetDeviceFirmwareStateModel(
      deviceId: (json['deviceId'] ?? json['device_id'] ?? '').toString(),
      productVariantId: (json['productVariantId'] ?? json['product_variant_id'] ?? '').toString(),
      currentFirmwareVersion: (json['currentFirmwareVersion'] ?? json['current_firmware_version'] ?? '1.0.0').toString(),
      targetFirmwareVersion: json['targetFirmwareVersion']?.toString() ?? json['target_firmware_version']?.toString(),
      rolloutId: json['rolloutId']?.toString() ?? json['rollout_id']?.toString(),
      rolloutState: json['rolloutState']?.toString() ?? json['rollout_state']?.toString(),
      lastOtaResult: json['lastOtaResult']?.toString() ?? json['last_ota_result']?.toString(),
      lastAttemptAt: json['lastAttemptAt']?.toString() ?? json['last_attempt_at']?.toString(),
      failureReason: json['failureReason']?.toString() ?? json['failure_reason']?.toString(),
      healthVerificationState: (json['healthVerificationState'] ?? json['health_verification_state'] ?? 'PENDING').toString(),
      updatedAt: (json['updatedAt'] ?? json['updated_at'] ?? '').toString(),
    );
  }
}

class OtaAttemptModel {
  const OtaAttemptModel({
    required this.id,
    required this.rolloutId,
    required this.deviceId,
    required this.releaseId,
    required this.attemptNumber,
    required this.status,
    this.errorCode,
    this.errorMessage,
    required this.attemptedAt,
    this.completedAt,
  });

  final String id;
  final String rolloutId;
  final String deviceId;
  final String releaseId;
  final int attemptNumber;
  final String status;
  final String? errorCode;
  final String? errorMessage;
  final String attemptedAt;
  final String? completedAt;

  factory OtaAttemptModel.fromJson(Map<String, dynamic> json) {
    return OtaAttemptModel(
      id: (json['id'] ?? '').toString(),
      rolloutId: (json['rolloutId'] ?? json['rollout_id'] ?? '').toString(),
      deviceId: (json['deviceId'] ?? json['device_id'] ?? '').toString(),
      releaseId: (json['releaseId'] ?? json['release_id'] ?? '').toString(),
      attemptNumber: (json['attemptNumber'] as num?)?.toInt() ?? (json['attempt_number'] as num?)?.toInt() ?? 1,
      status: (json['status'] ?? 'REQUESTED').toString(),
      errorCode: json['errorCode']?.toString() ?? json['error_code']?.toString(),
      errorMessage: json['errorMessage']?.toString() ?? json['error_message']?.toString(),
      attemptedAt: (json['attemptedAt'] ?? json['attempted_at'] ?? '').toString(),
      completedAt: json['completedAt']?.toString() ?? json['completed_at']?.toString(),
    );
  }
}
