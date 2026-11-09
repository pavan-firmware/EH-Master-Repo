import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_home_application_v1/core/models/recovery_models.dart';
import 'package:smart_home_application_v1/core/repositories/recovery_repository.dart';
import 'package:smart_home_application_v1/features/recovery/presentation/recovery_dashboard_page.dart';

class DecoupledMockRecoveryRepository implements RecoveryRepository {
  bool failBackups = false;
  bool failIntegrity = false;
  bool failCheckpoints = false;

  final BackupRecordModel sampleBackup = BackupRecordModel(
    backupId: 'backup-001',
    status: BackupStatus.completed,
    scope: 'FULL',
    provider: 'LocalBackupProvider',
    location: 'loc-001',
    objectCount: 10,
    totalBytes: 20480,
    createdAt: DateTime.now(),
  );

  final RecoveryIntegrityModel sampleIntegrity = RecoveryIntegrityModel(
    verificationId: 'v-001',
    backupId: 'backup-001',
    status: IntegrityStatus.valid,
    manifestValid: true,
    checksumsValid: true,
    schemaCompatible: true,
    migrationCompatible: true,
    verifiedObjectsCount: 10,
    failedObjectsCount: 0,
    verifiedBy: 'AUDIT_AGENT',
    verifiedAt: DateTime.now(),
  );

  final RecoveryCheckpointModel sampleCheckpoint = RecoveryCheckpointModel(
    checkpointId: 'chk-001',
    name: 'auto_checkpoint',
    checkpointType: 'HOURLY',
    schemaVersionRecorded: 1,
    migrationVersionRecorded: 30,
    stateSummary: {},
    createdAt: DateTime.now(),
  );

  @override
  Future<List<BackupRecordModel>> listBackups({int limit = 50, int offset = 0, String? status}) async {
    if (failBackups) throw Exception('503 Service Unavailable: storage backend unreachable');
    return [sampleBackup];
  }

  @override
  Future<BackupRecordModel> getBackup(String backupId) async => sampleBackup;

  @override
  Future<BackupRecordModel> createBackup({String scope = 'FULL', String? homeId}) async => sampleBackup;

  @override
  Future<RecoveryIntegrityModel> verifyBackupIntegrity(String backupId) async => sampleIntegrity;

  @override
  Future<List<RecoveryIntegrityModel>> listIntegrityResults({int limit = 50, int offset = 0, String? backupId}) async {
    if (failIntegrity) throw Exception('Connection reset by peer');
    return [sampleIntegrity];
  }

  @override
  Future<List<RecoveryCheckpointModel>> listCheckpoints() async {
    if (failCheckpoints) throw Exception('401 Unauthorized');
    return [sampleCheckpoint];
  }

  @override
  Future<RestorePlanModel> planRestore(String backupId, {String targetScope = 'FULL'}) async =>
      const RestorePlanModel(
        restorableEntities: ['homes'],
        excludedEntities: [],
        conflicts: [],
        migrationCompatibility: 'COMPATIBLE',
      );

  @override
  Future<RestoreOperationModel> executeRestore(String backupId, {String targetScope = 'FULL', bool dryRun = false}) async =>
      RestoreOperationModel(
        operationId: 'op-001',
        backupId: backupId,
        status: 'COMPLETED',
        stage: RestoreStage.complete,
        targetScope: targetScope,
        initiatedBy: 'ADMIN',
        dryRun: dryRun,
        createdAt: DateTime.now(),
      );

  @override
  Future<RestoreOperationModel> getRestoreOperation(String operationId) async =>
      executeRestore('backup-001');
}

void main() {
  group('Recovery Tabs Decoupling Tests', () {
    testWidgets('Failure in Backups tab maps 503 to storage unavailable without crashing other tabs', (tester) async {
      final repo = DecoupledMockRecoveryRepository()..failBackups = true;
      await tester.pumpWidget(MaterialApp(
        home: RecoveryDashboardPage(repository: repo),
      ));
      await tester.pumpAndSettle();

      // Backups tab should show mapped error message
      expect(find.text('Backup storage is currently unavailable. Please retry shortly.'), findsOneWidget);

      // Tab bar is still present and clickable
      expect(find.text('Integrity'), findsOneWidget);
      await tester.tap(find.text('Integrity'));
      await tester.pumpAndSettle();

      // Integrity tab loaded its own data smoothly
      expect(find.text('INTEGRITY AUDIT REPORT'), findsOneWidget);
      expect(find.text('AUDIT_AGENT'), findsOneWidget);
    });

    testWidgets('Failure in Integrity tab does not affect Backups tab', (tester) async {
      final repo = DecoupledMockRecoveryRepository()..failIntegrity = true;
      await tester.pumpWidget(MaterialApp(
        home: RecoveryDashboardPage(repository: repo),
      ));
      await tester.pumpAndSettle();

      // Backups tab loaded successfully
      expect(find.text('backup-001'), findsOneWidget);

      // Switch to Integrity tab
      await tester.tap(find.text('Integrity'));
      await tester.pumpAndSettle();

      // Shows mapped network error
      expect(find.text('Unable to reach the recovery API. Please check your network and retry.'), findsOneWidget);
    });

    testWidgets('Failure in Restore tab maps 401 to session expired', (tester) async {
      final repo = DecoupledMockRecoveryRepository()..failCheckpoints = true;
      await tester.pumpWidget(MaterialApp(
        home: RecoveryDashboardPage(repository: repo),
      ));
      await tester.pumpAndSettle();

      // Switch to Restore tab
      await tester.tap(find.text('Restore'));
      await tester.pumpAndSettle();

      expect(find.text('Authentication session expired. Please sign in again.'), findsOneWidget);
    });
  });
}

