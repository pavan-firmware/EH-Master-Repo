import '../api/api_client.dart';
import '../models/operational_readiness_models.dart';
import 'operational_readiness_repository.dart';

class CloudOperationalReadinessRepository implements OperationalReadinessRepository {
  const CloudOperationalReadinessRepository(this._apiClient);

  final ApiClient _apiClient;

  @override
  Future<SystemReadinessModel> getSystemReadiness() async {
    final response = await _apiClient.get('/api/v1/health/readiness');
    final data = response is Map<String, dynamic> ? response : <String, dynamic>{};
    return SystemReadinessModel.fromJson(data);
  }

  @override
  Future<OperationalDiagnosticsModel> getOperationalDiagnostics() async {
    final response = await _apiClient.get('/api/v1/admin/operations/diagnostics');
    final data = (response['data'] as Map<String, dynamic>?) ?? (response is Map<String, dynamic> ? response : <String, dynamic>{});
    return OperationalDiagnosticsModel.fromJson(data);
  }
}
