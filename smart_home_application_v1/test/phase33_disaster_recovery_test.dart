import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_home_application_v1/core/models/recovery_models.dart';
import 'package:smart_home_application_v1/core/repositories/recovery_repository.dart';
import 'package:smart_home_application_v1/features/recovery/presentation/recovery_dashboard_page.dart';

class MockRecoveryRepository implements RecoveryRepository {
  MockRecoveryRepository({
    this.backups,
    this.integrity,
    this.checkpoints,
    this.plan,
    this.restoreResult,
  });

  List<BackupRecordModel>? backups;
  RecoveryIntegrityModel? integrity;
  List<RecoveryCheckpointModel>? checkpoints;
  RestorePlanModel? plan;
  RestoreOperationModel? restoreResult;

  bool shouldThrow = false;
  bool createBackupCalled = false;
  bool verifyIntegrityCalled = false;
  bool planRestoreCalled = false;
  bool executeRestoreCalled = false;

  @override
  Future<List<BackupRecordModel>> listBackups({int limit = 50, int offset = 0, String? status}) async {
    if (shouldThrow) throw Exception('Network error');
    return backups ??
        [
          BackupRecordModel(
            backupId: '0194fe23-7a1b-7890-a123-456789abcdef',
            status: BackupStatus.completed,
            scope: 'FULL',
            provider: 'LocalBackupProvider',
            location: '0194fe23-7a1b-7890-a123-456789abcdef',
            objectCount: 15,
            totalBytes: 45056,
            manifestChecksum: 'a1b2c3d4e5f6071829304a5b6c7d8e9f0123456789abcdef0123456789abcdef',
            createdAt: DateTime.now().subtract(const Duration(hours: 2)),
            completedAt: DateTime.now().subtract(const Duration(hours: 2)),
          ),
          BackupRecordModel(
            backupId: '0194fe23-7a1b-7890-a123-456789abcdeg',
            status: BackupStatus.failed,
            scope: 'FULL',
            provider: 'LocalBackupProvider',
            location: '0194fe23-7a1b-7890-a123-456789abcdeg',
            objectCount: 0,
            totalBytes: 0,
            errorMessage: 'Disk write timeout',
            createdAt: DateTime.now().subtract(const Duration(days: 1)),
          ),
        ];
  }

  @override
  Future<BackupRecordModel> getBackup(String backupId) async {
    final list = await listBackups();
    return list.firstWhere((b) => b.backupId == backupId);
  }

  @override
  Future<BackupRecordModel> createBackup({String scope = 'FULL', String? homeId}) async {
    if (shouldThrow) throw Exception('Failed to create backup');
    createBackupCalled = true;
    final b = BackupRecordModel(
      backupId: '0194fe23-7a1b-7890-a123-456789abcnew',
      status: BackupStatus.completed,
      scope: scope,
      provider: 'LocalBackupProvider',
      location: '0194fe23-7a1b-7890-a123-456789abcnew',
      objectCount: 15,
      totalBytes: 45056,
      createdAt: DateTime.now(),
    );
    backups = [b, ...?backups];
    return b;
  }

  @override
  Future<RecoveryIntegrityModel> verifyBackupIntegrity(String backupId) async {
    if (shouldThrow) throw Exception('Verification service error');
    verifyIntegrityCalled = true;
    return integrity ??
        RecoveryIntegrityModel(
          verificationId: 'v-001',
          backupId: backupId,
          status: IntegrityStatus.valid,
          manifestValid: true,
          checksumsValid: true,
          schemaCompatible: true,
          migrationCompatible: true,
          verifiedObjectsCount: 15,
          failedObjectsCount: 0,
          verifiedBy: 'SYSTEM',
          verifiedAt: DateTime.now(),
        );
  }

  @override
  Future<RestorePlanModel> planRestore(String backupId, {String targetScope = 'FULL'}) async {
    if (shouldThrow) throw Exception('Planning error');
    planRestoreCalled = true;
    return plan ??
        RestorePlanModel(
          restorableEntities: ['users', 'homes', 'devices', 'automations'],
          excludedEntities: ['refresh_tokens', 'presence_signals'],
          conflicts: [
            const RestorePlanConflictModel(
              entityType: 'device',
              entityId: 'dev-quarantined-1',
              conflictType: 'REVOKED_IN_DB_TRUSTED_IN_BACKUP',
              resolution: 'PRESERVE_REVOCATION',
            ),
          ],
          migrationCompatibility: 'COMPATIBLE',
        );
  }

  @override
  Future<RestoreOperationModel> executeRestore(String backupId, {String targetScope = 'FULL', bool dryRun = false}) async {
    if (shouldThrow) throw Exception('Restore execution failed');
    executeRestoreCalled = true;
    return restoreResult ??
        RestoreOperationModel(
          operationId: 'op-001',
          backupId: backupId,
          status: 'COMPLETED',
          stage: RestoreStage.complete,
          targetScope: targetScope,
          initiatedBy: 'ADMIN_USER',
          dryRun: dryRun,
          reconciliation: const RestoreReconciliationModel(
            status: ReconciliationStatus.consistent,
            revocationsPreserved: 1,
            decommissionedPreserved: 0,
            expiredCredentialsPreserved: 2,
            trustReEvaluatedCount: 4,
            devicesRequiringRecommissioning: [],
            warnings: [],
          ),
          createdAt: DateTime.now(),
        );
  }

  @override
  Future<RestoreOperationModel> getRestoreOperation(String operationId) async {
    return executeRestore('any');
  }

  @override
  Future<List<RecoveryCheckpointModel>> listCheckpoints() async {
    return checkpoints ??
        [
          RecoveryCheckpointModel(
            checkpointId: 'chk-001',
            name: 'pre_migration_26',
            checkpointType: 'PRE_MIGRATION',
            schemaVersionRecorded: 1,
            migrationVersionRecorded: 26,
            stateSummary: {'userCount': 5, 'deviceCount': 10},
            createdAt: DateTime.now().subtract(const Duration(days: 2)),
          ),
        ];
  }
}

void main() {
  group('Phase 33 — Disaster Recovery Flutter UI Tests', () {
    testWidgets('Renders Recovery Dashboard with overview, backup cards, and status badges', (tester) async {
      final repo = MockRecoveryRepository();
      await tester.pumpWidget(MaterialApp(
        home: RecoveryDashboardPage(repository: repo),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Disaster Recovery & Resilience'), findsOneWidget);
      expect(find.text('RECOVERY STATE OVERVIEW'), findsOneWidget);
      expect(find.text('AVAILABLE BACKUP SNAPSHOTS (2)'), findsOneWidget);
      expect(find.text('COMPLETED'), findsOneWidget);
      expect(find.text('FAILED'), findsOneWidget);
      expect(find.text('Plan Restore'), findsWidgets);
    });

    testWidgets('Triggers backup creation from dashboard', (tester) async {
      final repo = MockRecoveryRepository();
      await tester.pumpWidget(MaterialApp(
        home: RecoveryDashboardPage(repository: repo),
      ));
      await tester.pumpAndSettle();

      final createBtn = find.text('Create New Backup Snapshot');
      expect(createBtn, findsOneWidget);
      await tester.tap(createBtn);
      await tester.pumpAndSettle();

      expect(repo.createBackupCalled, isTrue);
    });

    testWidgets('Navigates to Integrity tab and displays verification results', (tester) async {
      final repo = MockRecoveryRepository();
      await tester.pumpWidget(MaterialApp(
        home: RecoveryDashboardPage(repository: repo),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Integrity'));
      await tester.pumpAndSettle();

      expect(find.text('INTEGRITY AUDIT REPORT'), findsOneWidget);
      expect(find.text('SHA-256 Checksums'), findsOneWidget);
      expect(find.text('MATCHED'), findsOneWidget);
      expect(find.text('15 / 15'), findsOneWidget);
    });

    testWidgets('Plans restore and previews conflicts and restorable entities', (tester) async {
      final repo = MockRecoveryRepository();
      await tester.pumpWidget(MaterialApp(
        home: RecoveryDashboardPage(repository: repo),
      ));
      await tester.pumpAndSettle();

      final planBtn = find.text('Plan Restore').first;
      await tester.tap(planBtn);
      await tester.pumpAndSettle();

      expect(repo.planRestoreCalled, isTrue);
      expect(find.text('RESTORE PRE-FLIGHT PLAN'), findsOneWidget);
      expect(find.text('users'), findsOneWidget);
      expect(find.text('devices'), findsOneWidget);
      expect(find.text('refresh_tokens'), findsOneWidget);
      expect(find.text('Detected State Conflicts & Enforced Resolutions:'), findsOneWidget);
      expect(find.text('Execute State Restore'), findsOneWidget);
    });

    testWidgets('Executes restore after confirmation dialog and displays reconciliation result', (tester) async {
      final repo = MockRecoveryRepository();
      await tester.pumpWidget(MaterialApp(
        home: RecoveryDashboardPage(repository: repo),
      ));
      await tester.pumpAndSettle();

      // First plan restore
      await tester.tap(find.text('Plan Restore').first);
      await tester.pumpAndSettle();

      // Tap Execute State Restore
      await tester.tap(find.text('Execute State Restore'));
      await tester.pumpAndSettle();

      // Confirm in dialog
      expect(find.text('Confirm Platform State Restore'), findsOneWidget);
      await tester.tap(find.text('Execute Restore'));
      await tester.pumpAndSettle();

      expect(repo.executeRestoreCalled, isTrue);
      expect(find.text('RESTORE RECONCILIATION RESULT'), findsOneWidget);
      expect(find.text('Revocations Preserved'), findsOneWidget);
      expect(find.text('Trust Re-evaluated Devices'), findsOneWidget);
    });

    testWidgets('Handles network error gracefully with retry option', (tester) async {
      final repo = MockRecoveryRepository()..shouldThrow = true;
      await tester.pumpWidget(MaterialApp(
        home: RecoveryDashboardPage(repository: repo),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Failed to load recovery platform data'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
    });

    testWidgets('Sanitization & Secret Redaction: confirms no plaintext passwords or private keys displayed', (tester) async {
      final repo = MockRecoveryRepository();
      await tester.pumpWidget(MaterialApp(
        home: RecoveryDashboardPage(repository: repo),
      ));
      await tester.pumpAndSettle();

      expect(find.textContaining('password_hash'), findsNothing);
      expect(find.textContaining('private_key'), findsNothing);
      expect(find.textContaining('rawSecret'), findsNothing);
      expect(find.textContaining('authToken'), findsNothing);
    });
  });
}
