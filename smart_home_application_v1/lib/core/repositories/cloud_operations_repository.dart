import '../api/api_client.dart';
import '../models/operations_models.dart';
import 'operations_repository.dart';

class CloudOperationsRepository implements OperationsRepository {
  const CloudOperationsRepository(this._apiClient);

  final ApiClient _apiClient;

  @override
  Future<SystemHealthSnapshot> getSystemHealth() async {
    final response = await _apiClient.get('/api/v1/operations/health');
    final data = (response['data'] as Map<String, dynamic>?) ?? response;
    return SystemHealthSnapshot.fromJson(data);
  }

  @override
  Future<OperationsMetricsSummary> getOperationsMetrics({String? homeId, String? since}) async {
    final queryParams = <String, String>{
      if (homeId != null && homeId.isNotEmpty) 'homeId': homeId,
      if (since != null && since.isNotEmpty) 'since': since,
    };

    final queryString = Uri(queryParameters: queryParams).query;
    final path = queryString.isEmpty
        ? '/api/v1/operations/metrics'
        : '/api/v1/operations/metrics?$queryString';

    final response = await _apiClient.get(path);
    final data = (response['data'] as Map<String, dynamic>?) ?? response;
    return OperationsMetricsSummary.fromJson(data);
  }

  @override
  Future<List<OperationalEvent>> getOperationalEvents({
    String? homeId,
    String? deviceId,
    OperationalSubsystem? subsystem,
    OperationOutcome? outcome,
    String? severity,
    String? since,
    int limit = 100,
    int offset = 0,
  }) async {
    final queryParams = <String, String>{
      'limit': limit.toString(),
      'offset': offset.toString(),
      if (homeId != null && homeId.isNotEmpty) 'homeId': homeId,
      if (deviceId != null && deviceId.isNotEmpty) 'deviceId': deviceId,
      if (subsystem != null) 'subsystem': subsystem.name.toUpperCase(),
      if (outcome != null) 'outcome': outcome.name.toUpperCase(),
      if (severity != null && severity.isNotEmpty) 'severity': severity,
      if (since != null && since.isNotEmpty) 'since': since,
    };

    final queryString = Uri(queryParameters: queryParams).query;
    final path = queryString.isEmpty
        ? '/api/v1/operations/events'
        : '/api/v1/operations/events?$queryString';

    final response = await _apiClient.get(path);
    final data = (response['data'] as Map<String, dynamic>?) ?? response;
    final list = (data['events'] as List<dynamic>?) ?? const [];
    return list.map((e) => OperationalEvent.fromJson(e as Map<String, dynamic>)).toList();
  }

  @override
  Future<OperationTrace?> getTraceByCorrelationId(String correlationId) async {
    try {
      final response = await _apiClient.get('/api/v1/operations/traces/$correlationId');
      final data = (response['data'] as Map<String, dynamic>?) ?? response;
      return OperationTrace.fromJson(data);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<List<SecurityAuditRecord>> getSecurityAuditRecords({
    String? homeId,
    String? action,
    String? outcome,
    String? since,
    int limit = 100,
    int offset = 0,
  }) async {
    final queryParams = <String, String>{
      'limit': limit.toString(),
      'offset': offset.toString(),
      if (homeId != null && homeId.isNotEmpty) 'homeId': homeId,
      if (action != null && action.isNotEmpty) 'action': action,
      if (outcome != null && outcome.isNotEmpty) 'outcome': outcome,
      if (since != null && since.isNotEmpty) 'since': since,
    };

    final queryString = Uri(queryParameters: queryParams).query;
    final path = queryString.isEmpty
        ? '/api/v1/operations/audit'
        : '/api/v1/operations/audit?$queryString';

    final response = await _apiClient.get(path);
    final data = (response['data'] as Map<String, dynamic>?) ?? response;
    final list = (data['records'] as List<dynamic>?) ?? const [];
    return list.map((r) => SecurityAuditRecord.fromJson(r as Map<String, dynamic>)).toList();
  }

  @override
  Future<AuditIntegrityResult> verifyChainIntegrity() async {
    final response = await _apiClient.get('/api/v1/operations/audit/integrity');
    final data = (response['data'] as Map<String, dynamic>?) ?? response;
    return AuditIntegrityResult.fromJson(data);
  }

  @override
  Future<Map<String, dynamic>> getErrorTaxonomy({String? homeId, String? since}) async {
    final queryParams = <String, String>{
      if (homeId != null && homeId.isNotEmpty) 'homeId': homeId,
      if (since != null && since.isNotEmpty) 'since': since,
    };

    final queryString = Uri(queryParameters: queryParams).query;
    final path = queryString.isEmpty
        ? '/api/v1/operations/errors'
        : '/api/v1/operations/errors?$queryString';

    final response = await _apiClient.get(path);
    return (response['data'] as Map<String, dynamic>?) ?? response;
  }
}
