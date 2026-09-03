// Phase 26 — Multi-Protocol Device Connectivity & Interoperability Models
//
// Supports protocol-neutral representations for Wi-Fi/MQTT, BLE, Thread, and Matter.

enum DeviceTransportType {
  wifiMqtt,
  ble,
  thread,
  matter;

  String toApiValue() => switch (this) {
    DeviceTransportType.wifiMqtt => 'WIFI_MQTT',
    DeviceTransportType.ble => 'BLE',
    DeviceTransportType.thread => 'THREAD',
    DeviceTransportType.matter => 'MATTER',
  };

  static DeviceTransportType fromJson(String? value) => switch (value?.toUpperCase()) {
    'WIFI_MQTT' => DeviceTransportType.wifiMqtt,
    'BLE' => DeviceTransportType.ble,
    'THREAD' => DeviceTransportType.thread,
    'MATTER' => DeviceTransportType.matter,
    _ => DeviceTransportType.wifiMqtt,
  };

  String toDisplayLabel() => switch (this) {
    DeviceTransportType.wifiMqtt => 'Wi-Fi / MQTT',
    DeviceTransportType.ble => 'Bluetooth LE',
    DeviceTransportType.thread => 'Thread Mesh',
    DeviceTransportType.matter => 'Matter over Thread/Wi-Fi',
  };
}

enum TransportAvailability {
  online,
  degraded,
  unreachable,
  unconfigured;

  static TransportAvailability fromJson(String? value) => switch (value?.toUpperCase()) {
    'ONLINE' => TransportAvailability.online,
    'DEGRADED' => TransportAvailability.degraded,
    'UNREACHABLE' => TransportAvailability.unreachable,
    'UNCONFIGURED' => TransportAvailability.unconfigured,
    _ => TransportAvailability.unconfigured,
  };

  String toDisplayLabel() => switch (this) {
    TransportAvailability.online => 'Online',
    TransportAvailability.degraded => 'Degraded',
    TransportAvailability.unreachable => 'Unreachable',
    TransportAvailability.unconfigured => 'Not Configured',
  };
}

enum DeviceConnectionState {
  discovering,
  commissioning,
  connecting,
  connected,
  degraded,
  reconnecting,
  disconnected,
  failed,
  decommissioned;

  static DeviceConnectionState fromJson(String? value) => switch (value?.toUpperCase()) {
    'DISCOVERING' => DeviceConnectionState.discovering,
    'COMMISSIONING' => DeviceConnectionState.commissioning,
    'CONNECTING' => DeviceConnectionState.connecting,
    'CONNECTED' => DeviceConnectionState.connected,
    'DEGRADED' => DeviceConnectionState.degraded,
    'RECONNECTING' => DeviceConnectionState.reconnecting,
    'DISCONNECTED' => DeviceConnectionState.disconnected,
    'FAILED' => DeviceConnectionState.failed,
    'DECOMMISSIONED' => DeviceConnectionState.decommissioned,
    _ => DeviceConnectionState.disconnected,
  };

  String toDisplayLabel() => switch (this) {
    DeviceConnectionState.discovering => 'Discovering',
    DeviceConnectionState.commissioning => 'Commissioning',
    DeviceConnectionState.connecting => 'Connecting',
    DeviceConnectionState.connected => 'Connected',
    DeviceConnectionState.degraded => 'Degraded',
    DeviceConnectionState.reconnecting => 'Reconnecting',
    DeviceConnectionState.disconnected => 'Disconnected',
    DeviceConnectionState.failed => 'Connection Failed',
    DeviceConnectionState.decommissioned => 'Decommissioned',
  };
}

enum CommissioningStage {
  discovered,
  ready,
  started,
  authenticating,
  networkJoining,
  verifying,
  completed,
  failed,
  cancelled;

  static CommissioningStage fromJson(String? value) => switch (value?.toUpperCase()) {
    'DISCOVERED' => CommissioningStage.discovered,
    'READY' => CommissioningStage.ready,
    'STARTED' => CommissioningStage.started,
    'AUTHENTICATING' => CommissioningStage.authenticating,
    'NETWORK_JOINING' => CommissioningStage.networkJoining,
    'VERIFYING' => CommissioningStage.verifying,
    'COMPLETED' => CommissioningStage.completed,
    'FAILED' => CommissioningStage.failed,
    'CANCELLED' => CommissioningStage.cancelled,
    _ => CommissioningStage.discovered,
  };

  String toDisplayLabel() => switch (this) {
    CommissioningStage.discovered => 'Discovered',
    CommissioningStage.ready => 'Ready to Pair',
    CommissioningStage.started => 'Pairing Started',
    CommissioningStage.authenticating => 'Authenticating Credentials',
    CommissioningStage.networkJoining => 'Joining Secure Network',
    CommissioningStage.verifying => 'Verifying Connectivity',
    CommissioningStage.completed => 'Commissioning Completed',
    CommissioningStage.failed => 'Commissioning Failed',
    CommissioningStage.cancelled => 'Cancelled',
  };
}

class TransportCapability {
  final DeviceTransportType transportType;
  final bool isSupported;
  final bool isConfigured;
  final int priorityRank;
  final bool directIp;
  final bool meshCapable;
  final bool lowPower;
  final bool localOnly;
  final int maxPayloadBytes;

  const TransportCapability({
    required this.transportType,
    required this.isSupported,
    required this.isConfigured,
    required this.priorityRank,
    this.directIp = false,
    this.meshCapable = false,
    this.lowPower = false,
    this.localOnly = false,
    this.maxPayloadBytes = 65536,
  });

  factory TransportCapability.fromJson(Map<String, dynamic> json) {
    return TransportCapability(
      transportType: DeviceTransportType.fromJson(json['transportType'] ?? json['transport_type']),
      isSupported: json['isSupported'] == true || json['is_supported'] == 1,
      isConfigured: json['isConfigured'] == true || json['is_configured'] == 1,
      priorityRank: (json['priorityRank'] ?? json['priority_rank'] as num?)?.toInt() ?? 1,
      directIp: json['directIp'] == true || json['direct_ip'] == 1,
      meshCapable: json['meshCapable'] == true || json['mesh_capable'] == 1,
      lowPower: json['lowPower'] == true || json['low_power'] == 1,
      localOnly: json['localOnly'] == true || json['local_only'] == 1,
      maxPayloadBytes: (json['maxPayloadBytes'] ?? json['max_payload_bytes'] as num?)?.toInt() ?? 65536,
    );
  }
}

class TransportHealth {
  final DeviceTransportType transportType;
  final TransportAvailability availability;
  final double latencyMs;
  final double errorRate;
  final int reconnectCount;
  final DateTime? lastSuccessfulCommand;
  final DateTime? lastSuccessfulTelemetry;
  final double? signalRssi;

  const TransportHealth({
    required this.transportType,
    required this.availability,
    required this.latencyMs,
    required this.errorRate,
    required this.reconnectCount,
    this.lastSuccessfulCommand,
    this.lastSuccessfulTelemetry,
    this.signalRssi,
  });

  factory TransportHealth.fromJson(Map<String, dynamic> json) {
    return TransportHealth(
      transportType: DeviceTransportType.fromJson(json['transportType'] ?? json['transport_type']),
      availability: TransportAvailability.fromJson(json['availability']),
      latencyMs: (json['latencyMs'] ?? json['latency_ms'] as num?)?.toDouble() ?? 0.0,
      errorRate: (json['errorRate'] ?? json['error_rate'] as num?)?.toDouble() ?? 0.0,
      reconnectCount: (json['reconnectCount'] ?? json['reconnect_count'] as num?)?.toInt() ?? 0,
      lastSuccessfulCommand: json['lastSuccessfulCommand'] != null
          ? DateTime.tryParse(json['lastSuccessfulCommand'].toString())
          : json['last_successful_command'] != null
          ? DateTime.tryParse(json['last_successful_command'].toString())
          : null,
      lastSuccessfulTelemetry: json['lastSuccessfulTelemetry'] != null
          ? DateTime.tryParse(json['lastSuccessfulTelemetry'].toString())
          : json['last_successful_telemetry'] != null
          ? DateTime.tryParse(json['last_successful_telemetry'].toString())
          : null,
      signalRssi: (json['signalRssi'] ?? json['signal_rssi'] as num?)?.toDouble(),
    );
  }
}

class DeviceConnectionSnapshot {
  final String deviceId;
  final String homeId;
  final DeviceTransportType activeTransport;
  final DeviceConnectionState connectionState;
  final List<DeviceTransportType> supportedTransports;
  final Map<String, TransportHealth> transportHealth;
  final String? lastSelectedReason;
  final int reconnectCount;
  final DateTime? lastConnectedAt;
  final DateTime? lastDisconnectedAt;
  final DateTime updatedAt;

  const DeviceConnectionSnapshot({
    required this.deviceId,
    required this.homeId,
    required this.activeTransport,
    required this.connectionState,
    required this.supportedTransports,
    required this.transportHealth,
    this.lastSelectedReason,
    this.reconnectCount = 0,
    this.lastConnectedAt,
    this.lastDisconnectedAt,
    required this.updatedAt,
  });

  factory DeviceConnectionSnapshot.fromJson(Map<String, dynamic> json) {
    final rawHealth = json['transportHealth'] ?? json['transport_health'] as Map<String, dynamic>? ?? {};
    final healthMap = <String, TransportHealth>{};
    rawHealth.forEach((k, v) {
      if (v is Map<String, dynamic>) {
        healthMap[k] = TransportHealth.fromJson(v);
      }
    });

    final rawSupported = (json['supportedTransports'] ?? json['supported_transports']) as List? ?? ['WIFI_MQTT'];
    final supportedList = rawSupported.map((e) => DeviceTransportType.fromJson(e.toString())).toList();

    return DeviceConnectionSnapshot(
      deviceId: (json['deviceId'] ?? json['device_id'] ?? '').toString(),
      homeId: (json['homeId'] ?? json['home_id'] ?? '').toString(),
      activeTransport: DeviceTransportType.fromJson(json['activeTransport'] ?? json['active_transport']),
      connectionState: DeviceConnectionState.fromJson(json['connectionState'] ?? json['connection_state']),
      supportedTransports: supportedList,
      transportHealth: healthMap,
      lastSelectedReason: json['lastSelectedReason'] ?? json['last_selected_reason'],
      reconnectCount: (json['reconnectCount'] ?? json['reconnect_count'] as num?)?.toInt() ?? 0,
      lastConnectedAt: json['lastConnectedAt'] != null
          ? DateTime.tryParse(json['lastConnectedAt'].toString())
          : json['last_connected_at'] != null
          ? DateTime.tryParse(json['last_connected_at'].toString())
          : null,
      lastDisconnectedAt: json['lastDisconnectedAt'] != null
          ? DateTime.tryParse(json['lastDisconnectedAt'].toString())
          : json['last_disconnected_at'] != null
          ? DateTime.tryParse(json['last_disconnected_at'].toString())
          : null,
      updatedAt: DateTime.tryParse(json['updatedAt']?.toString() ?? json['updated_at']?.toString() ?? '') ?? DateTime.now(),
    );
  }
}

class DeviceDiscoveryResult {
  final String provisionalIdentity;
  final DeviceTransportType protocol;
  final String? deviceModel;
  final String? vendorId;
  final String? productId;
  final int? discriminator;
  final bool isCommissionable;
  final double? signalStrength;
  final DateTime discoveredAt;

  const DeviceDiscoveryResult({
    required this.provisionalIdentity,
    required this.protocol,
    this.deviceModel,
    this.vendorId,
    this.productId,
    this.discriminator,
    required this.isCommissionable,
    this.signalStrength,
    required this.discoveredAt,
  });

  factory DeviceDiscoveryResult.fromJson(Map<String, dynamic> json) {
    return DeviceDiscoveryResult(
      provisionalIdentity: (json['provisionalIdentity'] ?? json['provisional_identity'] ?? '').toString(),
      protocol: DeviceTransportType.fromJson(json['protocol']),
      deviceModel: json['deviceModel'] ?? json['device_model'],
      vendorId: json['vendorId'] ?? json['vendor_id'],
      productId: json['productId'] ?? json['product_id'],
      discriminator: (json['discriminator'] as num?)?.toInt(),
      isCommissionable: json['isCommissionable'] == true || json['is_commissionable'] == 1,
      signalStrength: (json['signalStrength'] ?? json['signal_strength'] as num?)?.toDouble(),
      discoveredAt: DateTime.tryParse(json['discoveredAt']?.toString() ?? json['discovered_at']?.toString() ?? '') ?? DateTime.now(),
    );
  }
}

class CommissioningSession {
  final String sessionId;
  final String homeId;
  final String deviceId;
  final DeviceTransportType transportType;
  final CommissioningStage stage;
  final String? authMethod;
  final String? errorDetails;
  final DateTime startedAt;
  final DateTime? completedAt;

  const CommissioningSession({
    required this.sessionId,
    required this.homeId,
    required this.deviceId,
    required this.transportType,
    required this.stage,
    this.authMethod,
    this.errorDetails,
    required this.startedAt,
    this.completedAt,
  });

  factory CommissioningSession.fromJson(Map<String, dynamic> json) {
    return CommissioningSession(
      sessionId: (json['sessionId'] ?? json['session_id'] ?? json['id'] ?? '').toString(),
      homeId: (json['homeId'] ?? json['home_id'] ?? '').toString(),
      deviceId: (json['deviceId'] ?? json['device_id'] ?? '').toString(),
      transportType: DeviceTransportType.fromJson(json['transportType'] ?? json['transport_type']),
      stage: CommissioningStage.fromJson(json['stage']),
      authMethod: json['authMethod'] ?? json['auth_method'],
      errorDetails: json['errorDetails'] ?? json['error_details'],
      startedAt: DateTime.tryParse(json['startedAt']?.toString() ?? json['started_at']?.toString() ?? '') ?? DateTime.now(),
      completedAt: json['completedAt'] != null
          ? DateTime.tryParse(json['completedAt'].toString())
          : json['completed_at'] != null
          ? DateTime.tryParse(json['completed_at'].toString())
          : null,
    );
  }
}

class FleetConnectivitySummary {
  final String homeId;
  final int totalDevices;
  final Map<String, int> stateDistribution;
  final Map<String, int> transportDistribution;
  final DateTime generatedAt;

  const FleetConnectivitySummary({
    required this.homeId,
    required this.totalDevices,
    required this.stateDistribution,
    required this.transportDistribution,
    required this.generatedAt,
  });

  factory FleetConnectivitySummary.fromJson(Map<String, dynamic> json) {
    return FleetConnectivitySummary(
      homeId: (json['homeId'] ?? json['home_id'] ?? '').toString(),
      totalDevices: (json['totalDevices'] ?? json['total_devices'] as num?)?.toInt() ?? 0,
      stateDistribution: Map<String, int>.from(
        (json['stateDistribution'] ?? json['state_distribution'] as Map? ?? {}).map(
          (k, v) => MapEntry(k.toString(), (v as num).toInt()),
        ),
      ),
      transportDistribution: Map<String, int>.from(
        (json['transportDistribution'] ?? json['transport_distribution'] as Map? ?? {}).map(
          (k, v) => MapEntry(k.toString(), (v as num).toInt()),
        ),
      ),
      generatedAt: DateTime.tryParse(json['generatedAt']?.toString() ?? json['generated_at']?.toString() ?? '') ?? DateTime.now(),
    );
  }
}
