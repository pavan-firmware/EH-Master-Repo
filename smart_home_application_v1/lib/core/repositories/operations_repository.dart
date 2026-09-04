import '../models/operations_models.dart';

abstract class OperationsRepository {
  /// Observational system health snapshot
  Future<SystemHealthSnapshot> getSystemHealth();

  /// Derived operational metrics summary
  Future<OperationsMetricsSummary> getOperationsMetrics({String? homeId, String? since});

  /// Query operational events
  Future<List<OperationalEvent>> getOperationalEvents({
    String? homeId,
    String? deviceId,
    OperationalSubsystem? subsystem,
    OperationOutcome? outcome,
    String? severity,
    String? since,
    int limit = 100,
    int offset = 0,
  });

  /// Reconstruct multi-hop trace by correlation ID
  Future<OperationTrace?> getTraceByCorrelationId(String correlationId);

  /// Query tamper-evident security audit log
  Future<List<SecurityAuditRecord>> getSecurityAuditRecords({
    String? homeId,
    String? action,
    String? outcome,
    String? since,
    int limit = 100,
    int offset = 0,
  });

  /// Verify cryptographic hash chain integrity
  Future<AuditIntegrityResult> verifyChainIntegrity();

  /// Subsystem failure taxonomy and error distribution
  Future<Map<String, dynamic>> getErrorTaxonomy({String? homeId, String? since});
}
