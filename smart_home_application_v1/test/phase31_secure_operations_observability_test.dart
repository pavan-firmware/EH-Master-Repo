import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_home_application_v1/core/models/operations_models.dart';
import 'package:smart_home_application_v1/core/repositories/operations_repository.dart';
import 'package:smart_home_application_v1/features/operations/presentation/operations_dashboard_page.dart';

class MockOperationsRepository implements OperationsRepository {
  MockOperationsRepository({
    this.healthSnapshot,
    this.metricsSummary,
    List<OperationalEvent>? events,
    this.integrityResult,
  }) {
    this.events = events ?? [];
  }

  SystemHealthSnapshot? healthSnapshot;
  OperationsMetricsSummary? metricsSummary;
  late List<OperationalEvent> events;
  AuditIntegrityResult? integrityResult;
  bool shouldThrow = false;

  @override
  Future<SystemHealthSnapshot> getSystemHealth() async {
    if (shouldThrow) throw Exception('Failed to connect to health service');
    return healthSnapshot ??
        SystemHealthSnapshot(
          status: HealthStatus.healthy,
          timestamp: DateTime.now(),
          subsystems: {
            'DATABASE': {'status': 'HEALTHY', 'latencyMs': 5},
            'MQTT': {'status': 'HEALTHY', 'latencyMs': 10},
          },
        );
  }

  @override
  Future<OperationsMetricsSummary> getOperationsMetrics({String? homeId, String? since}) async {
    if (shouldThrow) throw Exception('Failed to query metrics');
    return metricsSummary ??
        const OperationsMetricsSummary(
          totalEvents: 10,
          successCount: 9,
          failureCount: 1,
          partialCount: 0,
          timeoutCount: 0,
          successRate: 0.9,
          isStatisticallySignificant: true,
          avgDurationMs: 42,
          subsystems: {'DEVICE': 6, 'AUTOMATION': 4},
          executionPaths: {'CLOUD': 7, 'LOCAL_EDGE': 3},
          failureCodes: {'TIMEOUT': 1},
        );
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
    if (shouldThrow) throw Exception('Failed to fetch events');
    return events.where((e) {
      if (subsystem != null && e.subsystem != subsystem) return false;
      if (outcome != null && e.outcome != outcome) return false;
      return true;
    }).toList();
  }

  @override
  Future<OperationTrace?> getTraceByCorrelationId(String correlationId) async {
    return null;
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
    return [];
  }

  @override
  Future<AuditIntegrityResult> verifyChainIntegrity() async {
    if (shouldThrow) throw Exception('Integrity check failed');
    return integrityResult ??
        const AuditIntegrityResult(
          valid: true,
          totalRecords: 15,
          brokenAtSequence: null,
          error: null,
        );
  }

  @override
  Future<Map<String, dynamic>> getErrorTaxonomy({String? homeId, String? since}) async {
    return {'failureCodes': {'TIMEOUT': 1}};
  }
}

void main() {
  group('Phase 31 — Secure Operations & Observability Flutter Tests', () {
    test('OperationalEvent.fromJson parses canonical operational event', () {
      final json = {
        'eventId': 'evt_001',
        'correlationId': 'corr_001',
        'causationId': 'caus_001',
        'homeId': 'home_01',
        'subsystem': 'DEVICE',
        'operation': 'LIGHT_TOGGLE',
        'action': 'TURN_ON',
        'source': 'MOBILE_APP',
        'executionPath': 'LOCAL_EDGE',
        'severity': 'INFO',
        'authorizationResult': 'AUTHORIZED',
        'outcome': 'SUCCESS',
        'durationMs': 45.5,
        'metadata': {'retries': 0},
        'redactionMarkers': ['wifiPassword'],
        'timestamp': '2026-09-04T12:00:00.000Z',
      };

      final event = OperationalEvent.fromJson(json);
      expect(event.eventId, 'evt_001');
      expect(event.correlationId, 'corr_001');
      expect(event.subsystem, OperationalSubsystem.device);
      expect(event.executionPath, ExecutionPath.localEdge);
      expect(event.outcome, OperationOutcome.success);
      expect(event.durationMs, 45.5);
      expect(event.redactionMarkers, contains('wifiPassword'));
    });

    test('SecurityAuditRecord.fromJson parses tamper-evident audit record', () {
      final json = {
        'auditId': 'sec_001',
        'sequenceNumber': 42,
        'recordHash': 'a' * 64,
        'prevRecordHash': '0' * 64,
        'actorUserId': 'usr_alice',
        'homeId': 'home_01',
        'action': 'ROLE_ELEVATION',
        'resourceType': 'MEMBER',
        'resourceId': 'usr_bob',
        'outcome': 'SUCCESS',
        'canonicalPayload': {'role': 'ADMIN'},
        'timestamp': '2026-09-04T12:00:00.000Z',
      };

      final record = SecurityAuditRecord.fromJson(json);
      expect(record.auditId, 'sec_001');
      expect(record.sequenceNumber, 42);
      expect(record.recordHash.length, 64);
      expect(record.action, 'ROLE_ELEVATION');
      expect(record.canonicalPayload['role'], 'ADMIN');
    });

    test('OperationTrace.fromJson parses multi-hop spans', () {
      final json = {
        'traceId': 'trace_001',
        'correlationId': 'corr_001',
        'rootOperation': 'EXECUTE_AUTOMATION',
        'status': 'COMPLETED',
        'startTime': '2026-09-04T12:00:00.000Z',
        'endTime': '2026-09-04T12:00:00.050Z',
        'totalDurationMs': 50.0,
        'spans': [
          {
            'spanId': 'span_1',
            'parentSpanId': null,
            'subsystem': 'AUTOMATION',
            'operation': 'EVALUATE_RULE',
            'executionPath': 'CLOUD',
            'outcome': 'SUCCESS',
            'durationMs': 20.0,
            'timestamp': '2026-09-04T12:00:00.000Z',
          },
          {
            'spanId': 'span_2',
            'parentSpanId': 'span_1',
            'subsystem': 'DEVICE',
            'operation': 'SEND_COMMAND',
            'executionPath': 'LOCAL_EDGE',
            'outcome': 'SUCCESS',
            'durationMs': 30.0,
            'timestamp': '2026-09-04T12:00:00.020Z',
          }
        ],
      };

      final trace = OperationTrace.fromJson(json);
      expect(trace.traceId, 'trace_001');
      expect(trace.spans.length, 2);
      expect(trace.spans.first.operation, 'EVALUATE_RULE');
      expect(trace.spans.last.parentSpanId, 'span_1');
    });

    testWidgets('OperationsDashboardPage renders health and metric summaries', (tester) async {
      final mockRepo = MockOperationsRepository(
        events: [
          OperationalEvent(
            eventId: 'e1',
            correlationId: 'c1',
            subsystem: OperationalSubsystem.device,
            operation: 'LIGHT_ON',
            action: 'ACTUATION',
            source: 'APP',
            timestamp: DateTime.now(),
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: OperationsDashboardPage(
            repository: mockRepo,
            isAdmin: true,
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify app bar title
      expect(find.text('Operations & Observability'), findsOneWidget);

      // Verify health tab content
      expect(find.text('Overall Status: HEALTHY'), findsOneWidget);
      expect(find.text('DATABASE'), findsOneWidget);
      expect(find.text('MQTT'), findsOneWidget);

      // Switch to Metrics tab
      await tester.tap(find.text('Metrics'));
      await tester.pumpAndSettle();

      expect(find.text('Operational Summary'), findsOneWidget);
      expect(find.text('Total Events'), findsOneWidget);
      expect(find.text('10'), findsOneWidget);

      // Switch to Events tab
      await tester.tap(find.text('Events'));
      await tester.pumpAndSettle();

      expect(find.text('Device • LIGHT_ON'), findsOneWidget);

      // Switch to Audit Chain tab
      await tester.tap(find.text('Audit Chain'));
      await tester.pumpAndSettle();

      expect(find.text('Cryptographic Hash Chain Valid'), findsOneWidget);
      expect(find.textContaining('Verified 15 sequential security audit blocks'), findsOneWidget);
    });

    testWidgets('OperationsDashboardPage displays insignificance warning when sample < 5', (tester) async {
      final mockRepo = MockOperationsRepository(
        metricsSummary: const OperationsMetricsSummary(
          totalEvents: 2,
          successCount: 2,
          failureCount: 0,
          partialCount: 0,
          timeoutCount: 0,
          isStatisticallySignificant: false,
          avgDurationMs: 15,
          sampleSizeNote: 'Sample size too small (<5) for statistically reliable percentage',
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: OperationsDashboardPage(
            repository: mockRepo,
            isAdmin: true,
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Switch to Metrics tab
      await tester.tap(find.text('Metrics'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Sample size too small (<5)'), findsOneWidget);
    });
  });
}
