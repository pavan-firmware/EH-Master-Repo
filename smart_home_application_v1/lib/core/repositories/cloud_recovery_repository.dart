import '../api/api_client.dart';
import '../models/recovery_models.dart';
import 'recovery_repository.dart';

class CloudRecoveryRepository implements RecoveryRepository {
  const CloudRecoveryRepository(this._apiClient);

  final ApiClient _apiClient;

  @override
  Future<List<BackupRecordModel>> listBackups({int limit = 50, int offset = 0, String? status}) async {
    final params = <String>[
      'limit=$limit',
      'offset=$offset',
    ];
    if (status != null) {
      params.add('status=$status');
    }
    final path = '/api/v1/admin/recovery/backups?${params.join('&')}';
    final response = await _apiClient.get(path);
    final list = response is List ? response : (response['data'] as List<dynamic>? ?? []);
    return list.map((e) => BackupRecordModel.fromJson(e as Map<String, dynamic>)).toList();
  }

  @override
  Future<BackupRecordModel> getBackup(String backupId) async {
    final response = await _apiClient.get('/api/v1/admin/recovery/backups/$backupId');
    final data = (response['data'] as Map<String, dynamic>?) ?? response;
    return BackupRecordModel.fromJson(data as Map<String, dynamic>);
  }

  @override
  Future<BackupRecordModel> createBackup({String scope = 'FULL', String? homeId}) async {
    final body = <String, dynamic>{
      'scope': scope,
    };
    if (homeId != null) body['homeId'] = homeId;

    final response = await _apiClient.post('/api/v1/admin/recovery/backups', body: body);
    final data = (response['data'] as Map<String, dynamic>?) ?? response;
    final manifest = (data['manifest'] as Map<String, dynamic>?) ?? data;
    return BackupRecordModel.fromJson(manifest);
  }

  @override
  Future<RecoveryIntegrityModel> verifyBackupIntegrity(String backupId) async {
    final response = await _apiClient.post('/api/v1/admin/recovery/backups/$backupId/verify');
    final data = (response['data'] as Map<String, dynamic>?) ?? response;
    return RecoveryIntegrityModel.fromJson(data as Map<String, dynamic>);
  }

  @override
  Future<RestorePlanModel> planRestore(String backupId, {String targetScope = 'FULL'}) async {
    final response = await _apiClient.post('/api/v1/admin/recovery/restore/plan', body: {
      'backupId': backupId,
      'targetScope': targetScope,
    });
    final data = (response['data'] as Map<String, dynamic>?) ?? response;
    return RestorePlanModel.fromJson(data as Map<String, dynamic>);
  }

  @override
  Future<RestoreOperationModel> executeRestore(String backupId, {String targetScope = 'FULL', bool dryRun = false}) async {
    final response = await _apiClient.post('/api/v1/admin/recovery/restore', body: {
      'backupId': backupId,
      'targetScope': targetScope,
      'dryRun': dryRun,
    });
    final data = (response['data'] as Map<String, dynamic>?) ?? response;
    return RestoreOperationModel.fromJson(data as Map<String, dynamic>);
  }

  @override
  Future<RestoreOperationModel> getRestoreOperation(String operationId) async {
    final response = await _apiClient.get('/api/v1/admin/recovery/restore/$operationId');
    final data = (response['data'] as Map<String, dynamic>?) ?? response;
    return RestoreOperationModel.fromJson(data as Map<String, dynamic>);
  }

  @override
  Future<List<RecoveryCheckpointModel>> listCheckpoints() async {
    final response = await _apiClient.get('/api/v1/admin/recovery/checkpoints');
    final list = response is List ? response : (response['data'] as List<dynamic>? ?? []);
    return list.map((e) => RecoveryCheckpointModel.fromJson(e as Map<String, dynamic>)).toList();
  }
}
