// Phase 28 — Local-First Home Control & Edge Execution Models
//
// Represents route decisions, execution results, local connectivity state,
// discovered edge nodes, and execution telemetry for local-first operations.

enum ExecutionRouteMode {
  local,
  cloud,
  deferred,
  unavailable;

  String toApiValue() => switch (this) {
    ExecutionRouteMode.local => 'LOCAL',
    ExecutionRouteMode.cloud => 'CLOUD',
    ExecutionRouteMode.deferred => 'DEFERRED',
    ExecutionRouteMode.unavailable => 'UNAVAILABLE',
  };

  static ExecutionRouteMode fromJson(String? value) => switch (value?.toUpperCase()) {
    'LOCAL' => ExecutionRouteMode.local,
    'CLOUD' => ExecutionRouteMode.cloud,
    'DEFERRED' => ExecutionRouteMode.deferred,
    'UNAVAILABLE' => ExecutionRouteMode.unavailable,
    _ => ExecutionRouteMode.cloud,
  };

  String toDisplayLabel() => switch (this) {
    ExecutionRouteMode.local => 'Local Network',
    ExecutionRouteMode.cloud => 'Cloud Sync',
    ExecutionRouteMode.deferred => 'Queued Offline',
    ExecutionRouteMode.unavailable => 'Unavailable',
  };
}

enum EdgeDeviceControlStatus {
  idle,
  pending,
  confirmed,
  failed,
  offline;

  String toDisplayLabel() => switch (this) {
    EdgeDeviceControlStatus.idle => 'Ready',
    EdgeDeviceControlStatus.pending => 'Sending...',
    EdgeDeviceControlStatus.confirmed => 'Confirmed',
    EdgeDeviceControlStatus.failed => 'Failed',
    EdgeDeviceControlStatus.offline => 'Offline',
  };
}

class LocalConnectivityStatus {
  final String homeId;
  final bool isLocalNetworkActive;
  final int localDevicesCount;
  final int reachableDevicesCount;
  final double avgLocalLatencyMs;
  final Map<String, int> activeTransportSummary;
  final DateTime? lastDiscoveredAt;

  const LocalConnectivityStatus({
    required this.homeId,
    required this.isLocalNetworkActive,
    this.localDevicesCount = 0,
    this.reachableDevicesCount = 0,
    this.avgLocalLatencyMs = 0.0,
    this.activeTransportSummary = const {},
    this.lastDiscoveredAt,
  });

  factory LocalConnectivityStatus.fromJson(Map<String, dynamic> json) {
    return LocalConnectivityStatus(
      homeId: json['homeId'] as String? ?? json['home_id'] as String? ?? '',
      isLocalNetworkActive: json['isLocalNetworkActive'] as bool? ?? json['is_local_network_active'] as bool? ?? false,
      localDevicesCount: json['localDevicesCount'] as int? ?? json['local_devices_count'] as int? ?? 0,
      reachableDevicesCount: json['reachableDevicesCount'] as int? ?? json['reachable_devices_count'] as int? ?? 0,
      avgLocalLatencyMs: (json['avgLocalLatencyMs'] as num? ?? json['avg_local_latency_ms'] as num? ?? 0.0).toDouble(),
      activeTransportSummary: (json['activeTransportSummary'] as Map<String, dynamic>? ?? json['active_transport_summary'] as Map<String, dynamic>?)?.map(
        (key, value) => MapEntry(key, (value as num).toInt()),
      ) ?? {},
      lastDiscoveredAt: json['lastDiscoveredAt'] != null || json['last_discovered_at'] != null
          ? DateTime.tryParse(json['lastDiscoveredAt'] as String? ?? json['last_discovered_at'] as String? ?? '')
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'homeId': homeId,
    'isLocalNetworkActive': isLocalNetworkActive,
    'localDevicesCount': localDevicesCount,
    'reachableDevicesCount': reachableDevicesCount,
    'avgLocalLatencyMs': avgLocalLatencyMs,
    'activeTransportSummary': activeTransportSummary,
    'lastDiscoveredAt': lastDiscoveredAt?.toIso8601String(),
  };
}

class ExecutionRouteDecision {
  final String deviceId;
  final String homeId;
  final ExecutionRouteMode routeMode;
  final double confidence;
  final String transportType;
  final String? localEndpoint;
  final String reason;
  final DateTime evaluatedAt;

  const ExecutionRouteDecision({
    required this.deviceId,
    required this.homeId,
    required this.routeMode,
    this.confidence = 1.0,
    this.transportType = 'WIFI_MQTT',
    this.localEndpoint,
    this.reason = '',
    required this.evaluatedAt,
  });

  factory ExecutionRouteDecision.fromJson(Map<String, dynamic> json) {
    return ExecutionRouteDecision(
      deviceId: json['deviceId'] as String? ?? json['device_id'] as String? ?? '',
      homeId: json['homeId'] as String? ?? json['home_id'] as String? ?? '',
      routeMode: ExecutionRouteMode.fromJson(json['routeMode'] as String? ?? json['route_mode'] as String?),
      confidence: (json['confidence'] as num? ?? 1.0).toDouble(),
      transportType: json['transportType'] as String? ?? json['transport_type'] as String? ?? 'WIFI_MQTT',
      localEndpoint: json['localEndpoint'] as String? ?? json['local_endpoint'] as String?,
      reason: json['reason'] as String? ?? '',
      evaluatedAt: json['evaluatedAt'] != null || json['evaluated_at'] != null
          ? DateTime.tryParse(json['evaluatedAt'] as String? ?? json['evaluated_at'] as String? ?? '') ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
    'deviceId': deviceId,
    'homeId': homeId,
    'routeMode': routeMode.toApiValue(),
    'confidence': confidence,
    'transportType': transportType,
    'localEndpoint': localEndpoint,
    'reason': reason,
    'evaluatedAt': evaluatedAt.toIso8601String(),
  };
}

class EdgeExecutionResult {
  final String commandId;
  final String deviceId;
  final String homeId;
  final int channelIndex;
  final String action;
  final ExecutionRouteMode routeMode;
  final String transportUsed;
  final String status;
  final bool isConfirmedByDevice;
  final Map<String, dynamic>? confirmedState;
  final double latencyMs;
  final bool isIdempotentReplay;
  final String? errorMessage;
  final DateTime executedAt;

  const EdgeExecutionResult({
    required this.commandId,
    required this.deviceId,
    required this.homeId,
    this.channelIndex = 1,
    required this.action,
    required this.routeMode,
    this.transportUsed = 'WIFI_MQTT',
    required this.status,
    required this.isConfirmedByDevice,
    this.confirmedState,
    this.latencyMs = 0.0,
    this.isIdempotentReplay = false,
    this.errorMessage,
    required this.executedAt,
  });

  factory EdgeExecutionResult.fromJson(Map<String, dynamic> json) {
    return EdgeExecutionResult(
      commandId: json['commandId'] as String? ?? json['command_id'] as String? ?? '',
      deviceId: json['deviceId'] as String? ?? json['device_id'] as String? ?? '',
      homeId: json['homeId'] as String? ?? json['home_id'] as String? ?? '',
      channelIndex: json['channelIndex'] as int? ?? json['channel_index'] as int? ?? 1,
      action: json['action'] as String? ?? '',
      routeMode: ExecutionRouteMode.fromJson(json['routeMode'] as String? ?? json['route_mode'] as String?),
      transportUsed: json['transportUsed'] as String? ?? json['transport_used'] as String? ?? 'WIFI_MQTT',
      status: json['status'] as String? ?? 'UNKNOWN',
      isConfirmedByDevice: json['isConfirmedByDevice'] as bool? ?? json['is_confirmed_by_device'] as bool? ?? false,
      confirmedState: json['confirmedState'] as Map<String, dynamic>? ?? json['confirmed_state'] as Map<String, dynamic>?,
      latencyMs: (json['latencyMs'] as num? ?? json['latency_ms'] as num? ?? 0.0).toDouble(),
      isIdempotentReplay: json['isIdempotentReplay'] as bool? ?? json['is_idempotent_replay'] as bool? ?? false,
      errorMessage: json['errorMessage'] as String? ?? json['error_message'] as String?,
      executedAt: json['executedAt'] != null || json['executed_at'] != null
          ? DateTime.tryParse(json['executedAt'] as String? ?? json['executed_at'] as String? ?? '') ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
    'commandId': commandId,
    'deviceId': deviceId,
    'homeId': homeId,
    'channelIndex': channelIndex,
    'action': action,
    'routeMode': routeMode.toApiValue(),
    'transportUsed': transportUsed,
    'status': status,
    'isConfirmedByDevice': isConfirmedByDevice,
    'confirmedState': confirmedState,
    'latencyMs': latencyMs,
    'isIdempotentReplay': isIdempotentReplay,
    'errorMessage': errorMessage,
    'executedAt': executedAt.toIso8601String(),
  };
}

class DiscoveredLocalNode {
  final String id;
  final String deviceId;
  final String homeId;
  final String? productVariantId;
  final String macAddress;
  final String ipAddress;
  final int port;
  final String transportType;
  final String protocolVersion;
  final String? firmwareVersion;
  final bool isTrusted;
  final DateTime lastSeenAt;

  const DiscoveredLocalNode({
    required this.id,
    required this.deviceId,
    required this.homeId,
    this.productVariantId,
    required this.macAddress,
    required this.ipAddress,
    this.port = 1883,
    this.transportType = 'WIFI_MQTT',
    this.protocolVersion = '1.0.0',
    this.firmwareVersion,
    this.isTrusted = true,
    required this.lastSeenAt,
  });

  factory DiscoveredLocalNode.fromJson(Map<String, dynamic> json) {
    return DiscoveredLocalNode(
      id: json['id'] as String? ?? '',
      deviceId: json['deviceId'] as String? ?? json['device_id'] as String? ?? '',
      homeId: json['homeId'] as String? ?? json['home_id'] as String? ?? '',
      productVariantId: json['productVariantId'] as String? ?? json['product_variant_id'] as String?,
      macAddress: json['macAddress'] as String? ?? json['mac_address'] as String? ?? '',
      ipAddress: json['ipAddress'] as String? ?? json['ip_address'] as String? ?? '',
      port: json['port'] as int? ?? 1883,
      transportType: json['transportType'] as String? ?? json['transport_type'] as String? ?? 'WIFI_MQTT',
      protocolVersion: json['protocolVersion'] as String? ?? json['protocol_version'] as String? ?? '1.0.0',
      firmwareVersion: json['firmwareVersion'] as String? ?? json['firmware_version'] as String?,
      isTrusted: json['isTrusted'] as bool? ?? json['is_trusted'] as bool? ?? true,
      lastSeenAt: json['lastSeenAt'] != null || json['last_seen_at'] != null
          ? DateTime.tryParse(json['lastSeenAt'] as String? ?? json['last_seen_at'] as String? ?? '') ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'deviceId': deviceId,
    'homeId': homeId,
    'productVariantId': productVariantId,
    'macAddress': macAddress,
    'ipAddress': ipAddress,
    'port': port,
    'transportType': transportType,
    'protocolVersion': protocolVersion,
    'firmwareVersion': firmwareVersion,
    'isTrusted': isTrusted,
    'lastSeenAt': lastSeenAt.toIso8601String(),
  };
}

class EdgeMetricsSummary {
  final String homeId;
  final int totalExecutions;
  final int localExecutions;
  final int cloudExecutions;
  final double localSuccessRate;
  final double avgLocalLatencyMs;
  final double avgCloudLatencyMs;

  const EdgeMetricsSummary({
    required this.homeId,
    this.totalExecutions = 0,
    this.localExecutions = 0,
    this.cloudExecutions = 0,
    this.localSuccessRate = 1.0,
    this.avgLocalLatencyMs = 0.0,
    this.avgCloudLatencyMs = 0.0,
  });

  factory EdgeMetricsSummary.fromJson(Map<String, dynamic> json) {
    return EdgeMetricsSummary(
      homeId: json['homeId'] as String? ?? json['home_id'] as String? ?? '',
      totalExecutions: json['totalExecutions'] as int? ?? json['total_executions'] as int? ?? 0,
      localExecutions: json['localExecutions'] as int? ?? json['local_executions'] as int? ?? 0,
      cloudExecutions: json['cloudExecutions'] as int? ?? json['cloud_executions'] as int? ?? 0,
      localSuccessRate: (json['localSuccessRate'] as num? ?? json['local_success_rate'] as num? ?? 1.0).toDouble(),
      avgLocalLatencyMs: (json['avgLocalLatencyMs'] as num? ?? json['avg_local_latency_ms'] as num? ?? 0.0).toDouble(),
      avgCloudLatencyMs: (json['avgCloudLatencyMs'] as num? ?? json['avg_cloud_latency_ms'] as num? ?? 0.0).toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {
    'homeId': homeId,
    'totalExecutions': totalExecutions,
    'localExecutions': localExecutions,
    'cloudExecutions': cloudExecutions,
    'localSuccessRate': localSuccessRate,
    'avgLocalLatencyMs': avgLocalLatencyMs,
    'avgCloudLatencyMs': avgCloudLatencyMs,
  };
}
