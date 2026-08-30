class DeviceOtaInfo {
  const DeviceOtaInfo({
    required this.currentVersion,
    required this.updateAvailable,
    this.latestVersion,
  });

  final String currentVersion;
  final bool updateAvailable;
  final String? latestVersion;

  factory DeviceOtaInfo.fromJson(Map<String, dynamic> json) => DeviceOtaInfo(
    currentVersion: json['currentVersion'] as String? ?? '1.0.0',
    updateAvailable: json['updateAvailable'] as bool? ?? false,
    latestVersion: json['latestVersion'] as String?,
  );

  Map<String, dynamic> toJson() => {
    'currentVersion': currentVersion,
    'updateAvailable': updateAvailable,
    if (latestVersion != null) 'latestVersion': latestVersion,
  };
}

class DeviceHealthMetricsModel {
  const DeviceHealthMetricsModel({
    required this.status,
    required this.connectionState,
    this.lastSeenAt,
    this.ageSeconds,
    this.rssi,
    this.ipAddress,
    this.commandSuccessCount = 0,
    this.commandFailureCount = 0,
    this.lastErrorMessage,
    this.lastErrorAt,
    this.degradationReason,
  });

  final String status; // ONLINE, OFFLINE, STALE, DEGRADED, ERROR, UNKNOWN
  final String connectionState;
  final DateTime? lastSeenAt;
  final int? ageSeconds;
  final int? rssi;
  final String? ipAddress;
  final int commandSuccessCount;
  final int commandFailureCount;
  final String? lastErrorMessage;
  final DateTime? lastErrorAt;
  final String? degradationReason;

  bool get isOnline => status == 'ONLINE';
  bool get isOffline => status == 'OFFLINE';
  bool get isStale => status == 'STALE';
  bool get isDegraded => status == 'DEGRADED';

  factory DeviceHealthMetricsModel.fromJson(Map<String, dynamic> json) =>
      DeviceHealthMetricsModel(
        status: json['status'] as String? ?? 'UNKNOWN',
        connectionState: json['connectionState'] as String? ?? 'OFFLINE',
        lastSeenAt: json['lastSeenAt'] != null
            ? DateTime.tryParse(json['lastSeenAt'] as String)
            : null,
        ageSeconds: json['ageSeconds'] as int?,
        rssi: json['rssi'] as int?,
        ipAddress: json['ipAddress'] as String?,
        commandSuccessCount: json['commandSuccessCount'] as int? ?? 0,
        commandFailureCount: json['commandFailureCount'] as int? ?? 0,
        lastErrorMessage: json['lastErrorMessage'] as String?,
        lastErrorAt: json['lastErrorAt'] != null
            ? DateTime.tryParse(json['lastErrorAt'] as String)
            : null,
        degradationReason: json['degradationReason'] as String?,
      );

  Map<String, dynamic> toJson() => {
    'status': status,
    'connectionState': connectionState,
    if (lastSeenAt != null) 'lastSeenAt': lastSeenAt!.toIso8601String(),
    if (ageSeconds != null) 'ageSeconds': ageSeconds,
    if (rssi != null) 'rssi': rssi,
    if (ipAddress != null) 'ipAddress': ipAddress,
    'commandSuccessCount': commandSuccessCount,
    'commandFailureCount': commandFailureCount,
    if (lastErrorMessage != null) 'lastErrorMessage': lastErrorMessage,
    if (lastErrorAt != null) 'lastErrorAt': lastErrorAt!.toIso8601String(),
    if (degradationReason != null) 'degradationReason': degradationReason,
  };
}

class DeviceDetailsModel {
  const DeviceDetailsModel({
    required this.deviceId,
    required this.serialNumber,
    required this.productVariantId,
    required this.hardwareRevision,
    required this.firmwareFamily,
    required this.firmwareVersion,
    required this.displayName,
    this.homeId,
    this.roomId,
    this.roomName,
    this.floorId,
    required this.connectionState,
    this.lastSeenAt,
    required this.health,
    this.ota,
    this.channels = const [],
    this.capabilities = const [],
    this.claimedAt,
    this.updatedAt,
  });

  final String deviceId;
  final String serialNumber;
  final String productVariantId;
  final String hardwareRevision;
  final String firmwareFamily;
  final String firmwareVersion;
  final String displayName;
  final String? homeId;
  final String? roomId;
  final String? roomName;
  final String? floorId;
  final String connectionState;
  final DateTime? lastSeenAt;
  final DeviceHealthMetricsModel health;
  final DeviceOtaInfo? ota;
  final List<dynamic> channels;
  final List<dynamic> capabilities;
  final String? claimedAt;
  final String? updatedAt;

  factory DeviceDetailsModel.fromJson(Map<String, dynamic> json) =>
      DeviceDetailsModel(
        deviceId: json['deviceId'] as String? ?? '',
        serialNumber: json['serialNumber'] as String? ?? '',
        productVariantId: json['productVariantId'] as String? ?? '',
        hardwareRevision: json['hardwareRevision'] as String? ?? 'HW_1_0',
        firmwareFamily: json['firmwareFamily'] as String? ?? '',
        firmwareVersion: json['firmwareVersion'] as String? ?? '1.0.0',
        displayName: json['displayName'] as String? ?? 'Smart Device',
        homeId: json['homeId'] as String?,
        roomId: json['roomId'] as String?,
        roomName: json['roomName'] as String?,
        floorId: json['floorId'] as String?,
        connectionState: json['connectionState'] as String? ?? 'OFFLINE',
        lastSeenAt: json['lastSeenAt'] != null
            ? DateTime.tryParse(json['lastSeenAt'] as String)
            : null,
        health: json['health'] is Map<String, dynamic>
            ? DeviceHealthMetricsModel.fromJson(
                json['health'] as Map<String, dynamic>,
              )
            : const DeviceHealthMetricsModel(
                status: 'UNKNOWN',
                connectionState: 'OFFLINE',
              ),
        ota: json['ota'] is Map<String, dynamic>
            ? DeviceOtaInfo.fromJson(json['ota'] as Map<String, dynamic>)
            : null,
        channels: json['channels'] as List<dynamic>? ?? const [],
        capabilities: json['capabilities'] as List<dynamic>? ?? const [],
        claimedAt: json['claimedAt'] as String?,
        updatedAt: json['updatedAt'] as String?,
      );

  Map<String, dynamic> toJson() => {
    'deviceId': deviceId,
    'serialNumber': serialNumber,
    'productVariantId': productVariantId,
    'hardwareRevision': hardwareRevision,
    'firmwareFamily': firmwareFamily,
    'firmwareVersion': firmwareVersion,
    'displayName': displayName,
    if (homeId != null) 'homeId': homeId,
    if (roomId != null) 'roomId': roomId,
    if (roomName != null) 'roomName': roomName,
    if (floorId != null) 'floorId': floorId,
    'connectionState': connectionState,
    if (lastSeenAt != null) 'lastSeenAt': lastSeenAt!.toIso8601String(),
    'health': health.toJson(),
    if (ota != null) 'ota': ota!.toJson(),
    'channels': channels,
    'capabilities': capabilities,
    if (claimedAt != null) 'claimedAt': claimedAt,
    if (updatedAt != null) 'updatedAt': updatedAt,
  };
}

class DeviceActivityLogItemModel {
  const DeviceActivityLogItemModel({
    required this.id,
    this.homeId,
    required this.deviceId,
    required this.eventType,
    required this.severity,
    required this.message,
    this.correlationId,
    this.details = const {},
    required this.createdAt,
  });

  final String id;
  final String? homeId;
  final String deviceId;
  final String eventType;
  final String severity;
  final String message;
  final String? correlationId;
  final Map<String, dynamic> details;
  final DateTime createdAt;

  factory DeviceActivityLogItemModel.fromJson(Map<String, dynamic> json) =>
      DeviceActivityLogItemModel(
        id: json['id'] as String? ?? '',
        homeId: json['home_id'] as String?,
        deviceId: json['device_id'] as String? ?? '',
        eventType: json['event_type'] as String? ?? 'info',
        severity: json['severity'] as String? ?? 'info',
        message: json['message'] as String? ?? '',
        correlationId: json['correlation_id'] as String?,
        details: json['details'] is Map<String, dynamic>
            ? json['details'] as Map<String, dynamic>
            : const {},
        createdAt: json['created_at'] != null
            ? DateTime.tryParse(json['created_at'] as String) ?? DateTime.now()
            : DateTime.now(),
      );

  Map<String, dynamic> toJson() => {
    'id': id,
    if (homeId != null) 'home_id': homeId,
    'device_id': deviceId,
    'event_type': eventType,
    'severity': severity,
    'message': message,
    if (correlationId != null) 'correlation_id': correlationId,
    'details': details,
    'created_at': createdAt.toIso8601String(),
  };
}
