import 'dart:convert';

// ── Enums ─────────────────────────────────────────────────────────────────────

enum DeviceHealthState {
  healthy,
  degraded,
  unstable,
  unavailable,
  unknown;

  static DeviceHealthState fromJson(String v) => switch (v) {
    'HEALTHY' => healthy,
    'DEGRADED' => degraded,
    'UNSTABLE' => unstable,
    'UNAVAILABLE' => unavailable,
    _ => unknown,
  };

  String toDisplayLabel() => switch (this) {
    healthy => 'Healthy',
    degraded => 'Degraded',
    unstable => 'Unstable',
    unavailable => 'Unavailable',
    unknown => 'Unknown',
  };
}

enum ReliabilityIncidentType {
  deviceOffline,
  telemetryStale,
  commandFailure,
  commandLatency,
  mqttInstability,
  otaFailure,
  repeatedReconnect,
  reliabilityDegradation;

  static ReliabilityIncidentType fromJson(String v) => switch (v) {
    'DEVICE_OFFLINE' => deviceOffline,
    'TELEMETRY_STALE' => telemetryStale,
    'COMMAND_FAILURE' => commandFailure,
    'COMMAND_LATENCY' => commandLatency,
    'MQTT_INSTABILITY' => mqttInstability,
    'OTA_FAILURE' => otaFailure,
    'REPEATED_RECONNECT' => repeatedReconnect,
    _ => reliabilityDegradation,
  };

  String toDisplayLabel() => switch (this) {
    deviceOffline => 'Device Offline',
    telemetryStale => 'Telemetry Stale',
    commandFailure => 'Command Failure',
    commandLatency => 'Command Latency',
    mqttInstability => 'MQTT Instability',
    otaFailure => 'OTA Failure',
    repeatedReconnect => 'Repeated Reconnect',
    reliabilityDegradation => 'Reliability Degradation',
  };
}

enum ReliabilitySeverity {
  low,
  medium,
  high,
  critical;

  static ReliabilitySeverity fromJson(String v) => switch (v) {
    'LOW' => low,
    'MEDIUM' => medium,
    'HIGH' => high,
    'CRITICAL' => critical,
    _ => low,
  };
}

enum RecoveryActionType {
  retryCommand,
  refreshState,
  requestTelemetryRefresh,
  retryFailedOperation,
  reEvaluateOtaEligibility,
  markDegraded,
  createMaintenanceRecommendation;

  String toApiValue() => switch (this) {
    retryCommand => 'RETRY_COMMAND',
    refreshState => 'REFRESH_STATE',
    requestTelemetryRefresh => 'REQUEST_TELEMETRY_REFRESH',
    retryFailedOperation => 'RETRY_FAILED_OPERATION',
    reEvaluateOtaEligibility => 'RE_EVALUATE_OTA_ELIGIBILITY',
    markDegraded => 'MARK_DEGRADED',
    createMaintenanceRecommendation => 'CREATE_MAINTENANCE_RECOMMENDATION',
  };

  String toDisplayLabel() => switch (this) {
    retryCommand => 'Retry Command',
    refreshState => 'Refresh Device State',
    requestTelemetryRefresh => 'Request Telemetry Refresh',
    retryFailedOperation => 'Retry Failed Operation',
    reEvaluateOtaEligibility => 'Re-evaluate OTA Eligibility',
    markDegraded => 'Mark as Degraded',
    createMaintenanceRecommendation => 'Create Maintenance Task',
  };
}

enum RecoveryStatus {
  pending,
  executing,
  verifying,
  recovered,
  partiallyRecovered,
  failed;

  static RecoveryStatus fromJson(String v) => switch (v) {
    'PENDING' => pending,
    'EXECUTING' => executing,
    'VERIFYING' => verifying,
    'RECOVERED' => recovered,
    'PARTIALLY_RECOVERED' => partiallyRecovered,
    'FAILED' => failed,
    _ => failed,
  };
}

// ── Models ────────────────────────────────────────────────────────────────────

class DeviceHealthSnapshot {
  final String id;
  final String homeId;
  final String deviceId;
  final DeviceHealthState healthState;
  final double healthScore;
  final double? connectivityScore;
  final double? telemetryScore;
  final double? commandScore;
  final double? uptimeScore;
  final Map<String, dynamic>? factors;
  final int activeIncidents;
  final DateTime snapshottedAt;

  const DeviceHealthSnapshot({
    required this.id,
    required this.homeId,
    required this.deviceId,
    required this.healthState,
    required this.healthScore,
    this.connectivityScore,
    this.telemetryScore,
    this.commandScore,
    this.uptimeScore,
    this.factors,
    required this.activeIncidents,
    required this.snapshottedAt,
  });

  factory DeviceHealthSnapshot.fromJson(Map<String, dynamic> j) =>
      DeviceHealthSnapshot(
        id: j['id'] as String,
        homeId: j['homeId'] as String? ?? j['home_id'] as String,
        deviceId: j['deviceId'] as String? ?? j['device_id'] as String,
        healthState: DeviceHealthState.fromJson(
            j['healthState'] as String? ?? j['health_state'] as String),
        healthScore: (j['healthScore'] ?? j['health_score'] as num).toDouble(),
        connectivityScore: (j['connectivityScore'] ?? j['connectivity_score'] as num?)?.toDouble(),
        telemetryScore: (j['telemetryScore'] ?? j['telemetry_score'] as num?)?.toDouble(),
        commandScore: (j['commandScore'] ?? j['command_score'] as num?)?.toDouble(),
        uptimeScore: (j['uptimeScore'] ?? j['uptime_score'] as num?)?.toDouble(),
        factors: j['factors'] is String
            ? jsonDecode(j['factors'] as String) as Map<String, dynamic>?
            : j['factors'] as Map<String, dynamic>?,
        activeIncidents: (j['activeIncidents'] ?? j['active_incidents'] as int?) ?? 0,
        snapshottedAt: DateTime.parse(
            j['snapshottedAt'] as String? ?? j['snapshotted_at'] as String),
      );

  String get scoreFormatted => '${healthScore.toStringAsFixed(0)}/100';
}

class ReliabilityIncident {
  final String id;
  final String homeId;
  final String deviceId;
  final ReliabilityIncidentType incidentType;
  final ReliabilitySeverity severity;
  final String status;
  final String title;
  final String? description;
  final int signalCount;
  final DateTime firstObservedAt;
  final DateTime lastObservedAt;
  final DateTime? resolvedAt;
  final DateTime createdAt;

  const ReliabilityIncident({
    required this.id,
    required this.homeId,
    required this.deviceId,
    required this.incidentType,
    required this.severity,
    required this.status,
    required this.title,
    this.description,
    required this.signalCount,
    required this.firstObservedAt,
    required this.lastObservedAt,
    this.resolvedAt,
    required this.createdAt,
  });

  factory ReliabilityIncident.fromJson(Map<String, dynamic> j) =>
      ReliabilityIncident(
        id: j['id'] as String,
        homeId: j['homeId'] as String? ?? j['home_id'] as String,
        deviceId: j['deviceId'] as String? ?? j['device_id'] as String,
        incidentType: ReliabilityIncidentType.fromJson(
            j['incidentType'] as String? ?? j['incident_type'] as String),
        severity: ReliabilitySeverity.fromJson(
            j['severity'] as String),
        status: j['status'] as String,
        title: j['title'] as String,
        description: j['description'] as String?,
        signalCount: (j['signalCount'] ?? j['signal_count'] as int?) ?? 1,
        firstObservedAt: DateTime.parse(
            j['firstObservedAt'] as String? ?? j['first_observed_at'] as String),
        lastObservedAt: DateTime.parse(
            j['lastObservedAt'] as String? ?? j['last_observed_at'] as String),
        resolvedAt: j['resolvedAt'] != null
            ? DateTime.parse(j['resolvedAt'] as String)
            : null,
        createdAt: DateTime.parse(
            j['createdAt'] as String? ?? j['created_at'] as String),
      );

  bool get isActive => status == 'OPEN' || status == 'INVESTIGATING';
}

class RecoveryAttempt {
  final String id;
  final String incidentId;
  final String homeId;
  final String deviceId;
  final RecoveryActionType actionType;
  final RecoveryStatus status;
  final bool commandAccepted;
  final String? failureReason;
  final DateTime initiatedAt;
  final DateTime? completedAt;

  const RecoveryAttempt({
    required this.id,
    required this.incidentId,
    required this.homeId,
    required this.deviceId,
    required this.actionType,
    required this.status,
    required this.commandAccepted,
    this.failureReason,
    required this.initiatedAt,
    this.completedAt,
  });

  factory RecoveryAttempt.fromJson(Map<String, dynamic> j) {
    final actionStr = j['actionType'] as String? ?? j['action_type'] as String;
    return RecoveryAttempt(
      id: j['id'] as String,
      incidentId: j['incidentId'] as String? ?? j['incident_id'] as String,
      homeId: j['homeId'] as String? ?? j['home_id'] as String,
      deviceId: j['deviceId'] as String? ?? j['device_id'] as String,
      actionType: RecoveryActionType.values.firstWhere(
          (e) => e.toApiValue() == actionStr,
          orElse: () => RecoveryActionType.refreshState),
      status: RecoveryStatus.fromJson(j['status'] as String),
      commandAccepted: (j['commandAccepted'] ?? j['command_accepted']) == true ||
          (j['commandAccepted'] ?? j['command_accepted']) == 1,
      failureReason: j['failureReason'] as String? ?? j['failure_reason'] as String?,
      initiatedAt: DateTime.parse(
          j['initiatedAt'] as String? ?? j['initiated_at'] as String),
      completedAt: j['completedAt'] != null
          ? DateTime.parse(j['completedAt'] as String)
          : j['completed_at'] != null
              ? DateTime.parse(j['completed_at'] as String)
              : null,
    );
  }
}

class MaintenanceRecommendation {
  final String id;
  final String homeId;
  final String deviceId;
  final String? incidentId;
  final String recommendationType;
  final ReliabilitySeverity priority;
  final String title;
  final String description;
  final List<String> actionSteps;
  final String status;
  final DateTime createdAt;

  const MaintenanceRecommendation({
    required this.id,
    required this.homeId,
    required this.deviceId,
    this.incidentId,
    required this.recommendationType,
    required this.priority,
    required this.title,
    required this.description,
    required this.actionSteps,
    required this.status,
    required this.createdAt,
  });

  factory MaintenanceRecommendation.fromJson(Map<String, dynamic> j) {
    final stepsRaw = j['actionSteps'] ?? j['action_steps'];
    List<String> steps = [];
    if (stepsRaw is String) {
      final decoded = jsonDecode(stepsRaw);
      if (decoded is List) steps = decoded.cast<String>();
    } else if (stepsRaw is List) {
      steps = stepsRaw.cast<String>();
    }
    return MaintenanceRecommendation(
      id: j['id'] as String,
      homeId: j['homeId'] as String? ?? j['home_id'] as String,
      deviceId: j['deviceId'] as String? ?? j['device_id'] as String,
      incidentId: j['incidentId'] as String? ?? j['incident_id'] as String?,
      recommendationType: j['recommendationType'] as String? ??
          j['recommendation_type'] as String,
      priority: ReliabilitySeverity.fromJson(j['priority'] as String),
      title: j['title'] as String,
      description: j['description'] as String,
      actionSteps: steps,
      status: j['status'] as String,
      createdAt: DateTime.parse(
          j['createdAt'] as String? ?? j['created_at'] as String),
    );
  }
}

class FleetHealthSummary {
  final String homeId;
  final int totalDevices;
  final Map<String, int> stateDistribution;
  final double fleetHealthScore;
  final int activeIncidents;
  final int criticalIncidents;
  final int pendingRecoveries;
  final DateTime generatedAt;

  const FleetHealthSummary({
    required this.homeId,
    required this.totalDevices,
    required this.stateDistribution,
    required this.fleetHealthScore,
    required this.activeIncidents,
    required this.criticalIncidents,
    required this.pendingRecoveries,
    required this.generatedAt,
  });

  factory FleetHealthSummary.fromJson(Map<String, dynamic> j) =>
      FleetHealthSummary(
        homeId: j['homeId'] as String,
        totalDevices: j['totalDevices'] as int,
        stateDistribution: Map<String, int>.from(j['stateDistribution'] as Map),
        fleetHealthScore: (j['fleetHealthScore'] as num).toDouble(),
        activeIncidents: j['activeIncidents'] as int,
        criticalIncidents: j['criticalIncidents'] as int,
        pendingRecoveries: j['pendingRecoveries'] as int,
        generatedAt: DateTime.parse(j['generatedAt'] as String),
      );

  String get scoreFormatted => '${fleetHealthScore.toStringAsFixed(0)}/100';
}
