import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_home_application_v1/core/models/operational_readiness_models.dart';
import 'package:smart_home_application_v1/core/repositories/operational_readiness_repository.dart';
import 'package:smart_home_application_v1/features/operations/presentation/system_operational_status_page.dart';

class MockOperationalReadinessRepository implements OperationalReadinessRepository {
  MockOperationalReadinessRepository({
    this.readinessResponse,
    this.diagnosticsResponse,
    this.shouldThrow = false,
  });

  final SystemReadinessModel? readinessResponse;
  final OperationalDiagnosticsModel? diagnosticsResponse;
  final bool shouldThrow;

  @override
  Future<SystemReadinessModel> getSystemReadiness() async {
    if (shouldThrow) {
      throw Exception('Network connection failed');
    }
    return readinessResponse ??
        const SystemReadinessModel(
          status: 'READY',
          service: 'eh-home-backend',
          version: '1.0.0',
          timestamp: '2026-09-05T12:00:00.000Z',
          schemaVersionNumber: 26,
          latestMigration: '026_disaster_recovery_state_resilience',
          checks: {
            'database': 'PASS',
            'redis': 'PASS',
            'mqtt': 'PASS',
            'workers': 'PASS',
          },
        );
  }

  @override
  Future<OperationalDiagnosticsModel> getOperationalDiagnostics() async {
    if (shouldThrow) {
      throw Exception('Network connection failed');
    }
    return diagnosticsResponse ??
        const OperationalDiagnosticsModel(
          service: 'eh-home-backend',
          version: '1.0.0',
          environment: 'production',
          lifecycleState: 'READY',
          uptimeSeconds: 3600,
          timestamp: '2026-09-05T12:00:00.000Z',
        );
  }
}

void main() {
  group('Phase 34 — Operational Readiness Dart Models', () {
    test('SystemReadinessModel parses and serializes correctly', () {
      final json = {
        'status': 'READY',
        'service': 'eh-home-backend',
        'version': '1.0.0',
        'schema_version': 26,
        'migration_version': '026_disaster_recovery_state_resilience',
        'uptimeSeconds': 120.5,
        'timestamp': '2026-09-05T12:00:00.000Z',
        'checks': {
          'database': 'PASS',
          'redis': 'STANDBY',
          'mqtt': 'PASS',
          'workers': 'RUNNING',
        },
      };

      final model = SystemReadinessModel.fromJson(json);
      expect(model.status, 'READY');
      expect(model.isReady, isTrue);
      expect(model.isDegraded, isFalse);
      expect(model.isNotReady, isFalse);
      expect(model.databaseCheck, 'PASS');
      expect(model.redisCheck, 'STANDBY');
      expect(model.schemaVersionNumber, 26);
      expect(model.latestMigration, '026_disaster_recovery_state_resilience');

      final serialized = model.toJson();
      expect(serialized['status'], 'READY');
      expect(serialized['schema_version'], 26);
    });

    test('SystemReadinessModel degraded state evaluates correctly', () {
      final json = {
        'status': 'DEGRADED',
        'service': 'eh-home-backend',
        'version': '1.0.0',
        'timestamp': '2026-09-05T12:00:00.000Z',
        'checks': {
          'database': 'PASS',
          'redis': 'FAIL',
        },
      };

      final model = SystemReadinessModel.fromJson(json);
      expect(model.status, 'DEGRADED');
      expect(model.isReady, isTrue);
      expect(model.isDegraded, isTrue);
      expect(model.isNotReady, isFalse);
    });

    test('SystemReadinessModel not ready state evaluates correctly', () {
      final json = {
        'status': 'NOT_READY',
        'service': 'eh-home-backend',
        'version': '1.0.0',
        'timestamp': '2026-09-05T12:00:00.000Z',
        'checks': {
          'database': 'FAIL',
        },
      };

      final model = SystemReadinessModel.fromJson(json);
      expect(model.status, 'NOT_READY');
      expect(model.isReady, isFalse);
      expect(model.isNotReady, isTrue);
    });

    test('OperationalDiagnosticsModel parses correctly', () {
      final json = {
        'service': 'eh-home-backend',
        'version': '1.0.0',
        'flutterAppVersion': '0.1.0+1',
        'environment': 'production',
        'lifecycleState': 'READY',
        'uptimeSeconds': 7200,
        'timestamp': '2026-09-05T12:00:00.000Z',
        'release': {'appName': 'EH Home'},
        'dependencies': {'database': {'status': 'HEALTHY'}},
      };

      final model = OperationalDiagnosticsModel.fromJson(json);
      expect(model.service, 'eh-home-backend');
      expect(model.environment, 'production');
      expect(model.lifecycleState, 'READY');
      expect(model.uptimeSeconds, 7200);
      expect(model.flutterAppVersion, '0.1.0+1');
      expect(model.release['appName'], 'EH Home');
    });
  });

  group('Phase 34 — SystemOperationalStatusPage Widget Tests', () {
    testWidgets('renders platform ready status correctly', (WidgetTester tester) async {
      final mockRepo = MockOperationalReadinessRepository();

      await tester.pumpWidget(
        MaterialApp(
          home: SystemOperationalStatusPage(repository: mockRepo),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('System Operational Status'), findsOneWidget);
      expect(find.text('Platform Status: READY'), findsOneWidget);
      expect(find.text('Database (PostgreSQL)'), findsOneWidget);
      expect(find.text('PASS'), findsNWidgets(4));
      expect(find.text('Backend Version'), findsOneWidget);
      expect(find.text('v26'), findsOneWidget);
      expect(find.text('026_disaster_recovery_state_resilience'), findsOneWidget);
    });

    testWidgets('renders error view when repository throws', (WidgetTester tester) async {
      final mockRepo = MockOperationalReadinessRepository(shouldThrow: true);

      await tester.pumpWidget(
        MaterialApp(
          home: SystemOperationalStatusPage(repository: mockRepo),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Failed to retrieve system status'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
    });
  });
}
