import 'package:flutter/foundation.dart';

/// Subsystem classification for operations and platform observability
enum OperationalSubsystem {
  device,
  connectivity,
  reliability,
  ota,
  energy,
  automation,
  matter,
  security,
  account,
  edge,
  system;

  static OperationalSubsystem fromString(String? val) {
    switch (val?.toUpperCase()) {
      case 'DEVICE':
        return OperationalSubsystem.device;
      case 'CONNECTIVITY':
        return OperationalSubsystem.connectivity;
      case 'RELIABILITY':
        return OperationalSubsystem.reliability;
      case 'OTA':
        return OperationalSubsystem.ota;
      case 'ENERGY':
        return OperationalSubsystem.energy;
      case 'AUTOMATION':
        return OperationalSubsystem.automation;
      case 'MATTER':
        return OperationalSubsystem.matter;
      case 'SECURITY':
        return OperationalSubsystem.security;
      case 'ACCOUNT':
        return OperationalSubsystem.account;
      case 'EDGE':
        return OperationalSubsystem.edge;
      case 'SYSTEM':
      default:
        return OperationalSubsystem.system;
    }
  }

  String toDisplayString() {
    switch (this) {
      case OperationalSubsystem.device:
        return 'Device';
      case OperationalSubsystem.connectivity:
        return 'Connectivity';
      case OperationalSubsystem.reliability:
        return 'Reliability';
      case OperationalSubsystem.ota:
        return 'OTA Updates';
      case OperationalSubsystem.energy:
        return 'Energy';
      case OperationalSubsystem.automation:
        return 'Automation';
      case OperationalSubsystem.matter:
        return 'Matter';
      case OperationalSubsystem.security:
        return 'Security';
      case OperationalSubsystem.account:
        return 'Account';
      case OperationalSubsystem.edge:
        return 'Edge Execution';
      case OperationalSubsystem.system:
        return 'System';
    }
  }
}

/// Execution path across local edge, cloud, or device
enum ExecutionPath {
  localEdge,
  cloud,
  device,
  hybrid,
  unknown;

  static ExecutionPath fromString(String? val) {
    switch (val?.toUpperCase()) {
      case 'LOCAL_EDGE':
        return ExecutionPath.localEdge;
      case 'CLOUD':
        return ExecutionPath.cloud;
      case 'DEVICE':
        return ExecutionPath.device;
      case 'HYBRID':
        return ExecutionPath.hybrid;
      case 'UNKNOWN':
      default:
        return ExecutionPath.unknown;
    }
  }
}

/// Operational outcome status
enum OperationOutcome {
  success,
  failure,
  partial,
  timeout,
  deferred,
  unknown;

  static OperationOutcome fromString(String? val) {
    switch (val?.toUpperCase()) {
      case 'SUCCESS':
        return OperationOutcome.success;
      case 'FAILURE':
        return OperationOutcome.failure;
      case 'PARTIAL':
        return OperationOutcome.partial;
      case 'TIMEOUT':
        return OperationOutcome.timeout;
      case 'DEFERRED':
        return OperationOutcome.deferred;
      case 'UNKNOWN':
      default:
        return OperationOutcome.unknown;
    }
  }
}

/// Canonical Operational Event Model
@immutable
class OperationalEvent {
  final String eventId;
  final String correlationId;
  final String? causationId;
  final String? homeId;
  final String? deviceId;
  final String? roomId;
  final String? userId;
  final OperationalSubsystem subsystem;
  final String operation;
  final String action;
  final String source;
  final ExecutionPath executionPath;
  final String severity;
  final String authorizationResult;
  final OperationOutcome outcome;
  final String? failureCode;
  final double? durationMs;
  final Map<String, dynamic> metadata;
  final List<String> redactionMarkers;
  final String? traceLifecycle;
  final DateTime timestamp;

  const OperationalEvent({
    required this.eventId,
    required this.correlationId,
    this.causationId,
    this.homeId,
    this.deviceId,
    this.roomId,
    this.userId,
    required this.subsystem,
    required this.operation,
    required this.action,
    required this.source,
    this.executionPath = ExecutionPath.cloud,
    this.severity = 'INFO',
    this.authorizationResult = 'AUTHORIZED',
    this.outcome = OperationOutcome.success,
    this.failureCode,
    this.durationMs,
    this.metadata = const {},
    this.redactionMarkers = const [],
    this.traceLifecycle,
    required this.timestamp,
  });

  factory OperationalEvent.fromJson(Map<String, dynamic> json) {
    return OperationalEvent(
      eventId: json['eventId'] ?? json['id'] ?? '',
      correlationId: json['correlationId'] ?? json['correlation_id'] ?? '',
      causationId: json['causationId'] ?? json['causation_id'],
      homeId: json['homeId'] ?? json['home_id'],
      deviceId: json['deviceId'] ?? json['device_id'],
      roomId: json['roomId'] ?? json['room_id'],
      userId: json['userId'] ?? json['user_id'],
      subsystem: OperationalSubsystem.fromString(json['subsystem']),
      operation: json['operation'] ?? '',
      action: json['action'] ?? '',
      source: json['source'] ?? '',
      executionPath: ExecutionPath.fromString(json['executionPath'] ?? json['execution_path']),
      severity: json['severity'] ?? 'INFO',
      authorizationResult: json['authorizationResult'] ?? json['authorization_result'] ?? 'AUTHORIZED',
      outcome: OperationOutcome.fromString(json['outcome']),
      failureCode: json['failureCode'] ?? json['failure_code'],
      durationMs: (json['durationMs'] ?? json['duration_ms']) != null
          ? (json['durationMs'] ?? json['duration_ms'] as num).toDouble()
          : null,
      metadata: (json['metadata'] as Map<String, dynamic>?) ?? const {},
      redactionMarkers: (json['redactionMarkers'] as List<dynamic>?)?.map((e) => e.toString()).toList() ??
          (json['redaction_markers'] as List<dynamic>?)?.map((e) => e.toString()).toList() ??
          const <String>[],
      traceLifecycle: json['traceLifecycle'] ?? json['trace_lifecycle'],
      timestamp: DateTime.tryParse(json['timestamp'] ?? json['occurred_at'] ?? '') ?? DateTime.now(),
    );
  }
}

/// Tamper-Evident Hash-Chained Audit Record Model
@immutable
class SecurityAuditRecord {
  final String auditId;
  final int sequenceNumber;
  final String recordHash;
  final String prevRecordHash;
  final String? actorUserId;
  final String? homeId;
  final String? deviceId;
  final String action;
  final String resourceType;
  final String? resourceId;
  final String outcome;
  final String? ipAddress;
  final String? correlationId;
  final Map<String, dynamic> canonicalPayload;
  final Map<String, dynamic> metadata;
  final DateTime timestamp;

  const SecurityAuditRecord({
    required this.auditId,
    required this.sequenceNumber,
    required this.recordHash,
    required this.prevRecordHash,
    this.actorUserId,
    this.homeId,
    this.deviceId,
    required this.action,
    required this.resourceType,
    this.resourceId,
    required this.outcome,
    this.ipAddress,
    this.correlationId,
    this.canonicalPayload = const {},
    this.metadata = const {},
    required this.timestamp,
  });

  factory SecurityAuditRecord.fromJson(Map<String, dynamic> json) {
    return SecurityAuditRecord(
      auditId: json['auditId'] ?? json['id'] ?? '',
      sequenceNumber: (json['sequenceNumber'] ?? json['sequence_number'] ?? 0) as int,
      recordHash: json['recordHash'] ?? json['record_hash'] ?? '',
      prevRecordHash: json['prevRecordHash'] ?? json['prev_record_hash'] ?? '',
      actorUserId: json['actorUserId'] ?? json['actor_user_id'],
      homeId: json['homeId'] ?? json['home_id'],
      deviceId: json['deviceId'] ?? json['device_id'],
      action: json['action'] ?? '',
      resourceType: json['resourceType'] ?? json['resource_type'] ?? '',
      resourceId: json['resourceId'] ?? json['resource_id'],
      outcome: json['outcome'] ?? 'SUCCESS',
      ipAddress: json['ipAddress'] ?? json['ip_address'],
      correlationId: json['correlationId'] ?? json['correlation_id'],
      canonicalPayload: (json['canonicalPayload'] ?? json['canonical_payload'] as Map<String, dynamic>?) ?? const {},
      metadata: (json['metadata'] as Map<String, dynamic>?) ?? const {},
      timestamp: DateTime.tryParse(json['timestamp'] ?? json['created_at'] ?? '') ?? DateTime.now(),
    );
  }
}

/// Operation Trace Span Model
@immutable
class OperationTraceSpan {
  final String spanId;
  final String? parentSpanId;
  final String subsystem;
  final String operation;
  final ExecutionPath executionPath;
  final OperationOutcome outcome;
  final double? durationMs;
  final DateTime timestamp;
  final Map<String, dynamic> details;

  const OperationTraceSpan({
    required this.spanId,
    this.parentSpanId,
    required this.subsystem,
    required this.operation,
    required this.executionPath,
    required this.outcome,
    this.durationMs,
    required this.timestamp,
    this.details = const {},
  });

  factory OperationTraceSpan.fromJson(Map<String, dynamic> json) {
    return OperationTraceSpan(
      spanId: json['spanId'] ?? '',
      parentSpanId: json['parentSpanId'],
      subsystem: json['subsystem'] ?? '',
      operation: json['operation'] ?? '',
      executionPath: ExecutionPath.fromString(json['executionPath']),
      outcome: OperationOutcome.fromString(json['outcome']),
      durationMs: json['durationMs'] != null ? (json['durationMs'] as num).toDouble() : null,
      timestamp: DateTime.tryParse(json['timestamp'] ?? '') ?? DateTime.now(),
      details: (json['details'] as Map<String, dynamic>?) ?? const {},
    );
  }
}

/// End-to-End Multi-Hop Operation Trace Model
@immutable
class OperationTrace {
  final String traceId;
  final String correlationId;
  final String rootOperation;
  final String status;
  final DateTime startTime;
  final DateTime? endTime;
  final double? totalDurationMs;
  final List<OperationTraceSpan> spans;
  final Map<String, dynamic> metadata;

  const OperationTrace({
    required this.traceId,
    required this.correlationId,
    required this.rootOperation,
    required this.status,
    required this.startTime,
    this.endTime,
    this.totalDurationMs,
    required this.spans,
    this.metadata = const {},
  });

  factory OperationTrace.fromJson(Map<String, dynamic> json) {
    final spansList = (json['spans'] as List<dynamic>?)
            ?.map((s) => OperationTraceSpan.fromJson(s as Map<String, dynamic>))
            .toList() ??
        [];

    return OperationTrace(
      traceId: json['traceId'] ?? '',
      correlationId: json['correlationId'] ?? '',
      rootOperation: json['rootOperation'] ?? '',
      status: json['status'] ?? 'COMPLETED',
      startTime: DateTime.tryParse(json['startTime'] ?? '') ?? DateTime.now(),
      endTime: json['endTime'] != null ? DateTime.tryParse(json['endTime']) : null,
      totalDurationMs: json['totalDurationMs'] != null ? (json['totalDurationMs'] as num).toDouble() : null,
      spans: spansList,
      metadata: (json['metadata'] as Map<String, dynamic>?) ?? const {},
    );
  }
}

/// Subsystem Health Status Model
enum HealthStatus {
  healthy,
  degraded,
  unavailable,
  notChecked,
  unknown;

  static HealthStatus fromString(String? val) {
    switch (val?.toUpperCase()) {
      case 'HEALTHY':
        return HealthStatus.healthy;
      case 'DEGRADED':
        return HealthStatus.degraded;
      case 'UNAVAILABLE':
        return HealthStatus.unavailable;
      case 'NOT_CHECKED':
        return HealthStatus.notChecked;
      case 'UNKNOWN':
      default:
        return HealthStatus.unknown;
    }
  }
}

/// System Health Snapshot Model
@immutable
class SystemHealthSnapshot {
  final HealthStatus status;
  final DateTime timestamp;
  final Map<String, Map<String, dynamic>> subsystems;
  final Map<String, dynamic> metadata;

  const SystemHealthSnapshot({
    required this.status,
    required this.timestamp,
    required this.subsystems,
    this.metadata = const {},
  });

  factory SystemHealthSnapshot.fromJson(Map<String, dynamic> json) {
    final rawSubs = (json['subsystems'] as Map<String, dynamic>?) ?? {};
    final mappedSubs = <String, Map<String, dynamic>>{};
    rawSubs.forEach((k, v) {
      if (v is Map<String, dynamic>) {
        mappedSubs[k] = v;
      }
    });

    return SystemHealthSnapshot(
      status: HealthStatus.fromString(json['status']),
      timestamp: DateTime.tryParse(json['timestamp'] ?? '') ?? DateTime.now(),
      subsystems: mappedSubs,
      metadata: (json['metadata'] as Map<String, dynamic>?) ?? const {},
    );
  }
}

/// Aggregated Derived Operations Metrics Summary
@immutable
class OperationsMetricsSummary {
  final int totalEvents;
  final int successCount;
  final int failureCount;
  final int partialCount;
  final int timeoutCount;
  final double? successRate;
  final bool isStatisticallySignificant;
  final int avgDurationMs;
  final Map<String, int> subsystems;
  final Map<String, int> executionPaths;
  final Map<String, int> failureCodes;
  final String? sampleSizeNote;

  const OperationsMetricsSummary({
    required this.totalEvents,
    required this.successCount,
    required this.failureCount,
    required this.partialCount,
    required this.timeoutCount,
    this.successRate,
    required this.isStatisticallySignificant,
    required this.avgDurationMs,
    this.subsystems = const {},
    this.executionPaths = const {},
    this.failureCodes = const {},
    this.sampleSizeNote,
  });

  factory OperationsMetricsSummary.fromJson(Map<String, dynamic> json) {
    Map<String, int> parseMap(dynamic map) {
      if (map is Map) {
        return map.map((k, v) => MapEntry(k.toString(), (v as num).toInt()));
      }
      return {};
    }

    return OperationsMetricsSummary(
      totalEvents: (json['totalEvents'] ?? 0) as int,
      successCount: (json['successCount'] ?? 0) as int,
      failureCount: (json['failureCount'] ?? 0) as int,
      partialCount: (json['partialCount'] ?? 0) as int,
      timeoutCount: (json['timeoutCount'] ?? 0) as int,
      successRate: json['successRate'] != null ? (json['successRate'] as num).toDouble() : null,
      isStatisticallySignificant: json['isStatisticallySignificant'] ?? false,
      avgDurationMs: (json['avgDurationMs'] ?? 0) as int,
      subsystems: parseMap(json['subsystems']),
      executionPaths: parseMap(json['executionPaths']),
      failureCodes: parseMap(json['failureCodes']),
      sampleSizeNote: json['sampleSizeNote'],
    );
  }
}

/// Audit Chain Integrity Verification Result
@immutable
class AuditIntegrityResult {
  final bool valid;
  final int totalRecords;
  final int? brokenAtSequence;
  final String? error;

  const AuditIntegrityResult({
    required this.valid,
    required this.totalRecords,
    this.brokenAtSequence,
    this.error,
  });

  factory AuditIntegrityResult.fromJson(Map<String, dynamic> json) {
    return AuditIntegrityResult(
      valid: json['valid'] ?? false,
      totalRecords: (json['totalRecords'] ?? 0) as int,
      brokenAtSequence: json['brokenAtSequence'],
      error: json['error'],
    );
  }
}
