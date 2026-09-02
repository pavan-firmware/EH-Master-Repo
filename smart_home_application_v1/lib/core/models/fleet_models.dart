// EH Home — Device Fleet Management & OTA Data Models (Phase 18)

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
        return OtaOperationStatus.installing;
      case 'REBOOTING':
        return OtaOperationStatus.rebooting;
      case 'CONFIRMING':
        return OtaOperationStatus.confirming;
      case 'SUCCESS':
        return OtaOperationStatus.success;
      case 'FAILED':
        return OtaOperationStatus.failed;
      case 'ROLLED_BACK':
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

  const FirmwareRelease({
    required this.id,
    required this.productVariantId,
    this.hardwareRevision,
    required this.firmwareFamily,
    required this.version,
    this.minFirmwareVersion,
    this.releaseChannel = 'production',
    required this.binarySizeBytes,
    required this.sha256,
    required this.downloadUrl,
    this.releaseNotes,
    this.status = 'PUBLISHED',
  });

  factory FirmwareRelease.fromJson(Map<String, dynamic> json) {
    return FirmwareRelease(
      id: (json['id'] ?? json['releaseId'] ?? '') as String,
      productVariantId: (json['product_variant_id'] ?? json['productVariantId'] ?? '') as String,
      hardwareRevision: (json['hardware_revision'] ?? json['hardwareRevision']) as String?,
      firmwareFamily: (json['firmware_family'] ?? json['firmwareFamily'] ?? 'esp32-switch-platform') as String,
      version: (json['version'] ?? '1.0.0') as String,
      minFirmwareVersion: (json['min_firmware_version'] ?? json['minFirmwareVersion']) as String?,
      releaseChannel: (json['release_channel'] ?? json['releaseChannel'] ?? 'production') as String,
      binarySizeBytes: (json['binary_size_bytes'] ?? json['binarySizeBytes'] ?? 0) as int,
      sha256: (json['sha256'] ?? '') as String,
      downloadUrl: (json['download_url'] ?? json['downloadUrl'] ?? '') as String,
      releaseNotes: (json['release_notes'] ?? json['releaseNotes']) as String?,
      status: (json['status'] ?? 'PUBLISHED') as String,
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
    };
  }
}

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
    this.progressPercent = 0,
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
