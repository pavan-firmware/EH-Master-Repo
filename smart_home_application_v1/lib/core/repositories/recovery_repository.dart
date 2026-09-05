import '../models/recovery_models.dart';

abstract class RecoveryRepository {
  Future<List<BackupRecordModel>> listBackups({int limit = 50, int offset = 0, String? status});
  Future<BackupRecordModel> getBackup(String backupId);
  Future<BackupRecordModel> createBackup({String scope = 'FULL', String? homeId});
  Future<RecoveryIntegrityModel> verifyBackupIntegrity(String backupId);
  Future<RestorePlanModel> planRestore(String backupId, {String targetScope = 'FULL'});
  Future<RestoreOperationModel> executeRestore(String backupId, {String targetScope = 'FULL', bool dryRun = false});
  Future<RestoreOperationModel> getRestoreOperation(String operationId);
  Future<List<RecoveryCheckpointModel>> listCheckpoints();
}
