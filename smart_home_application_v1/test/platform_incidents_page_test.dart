import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_home_application_v1/features/operations/presentation/platform_incidents_page.dart';

class MockPlatformIncidentsDataSource implements PlatformIncidentsDataSource {
  List<PlatformIncidentItem> incidents;
  bool shouldThrow = false;

  MockPlatformIncidentsDataSource({List<PlatformIncidentItem>? incidents})
      : incidents = incidents ?? [];

  @override
  Future<List<PlatformIncidentItem>> fetchIncidents({String? status, String? severity}) async {
    if (shouldThrow) {
      throw Exception('Network error');
    }
    return incidents.where((inc) {
      if (status != null && inc.status != status) return false;
      if (severity != null && inc.severity != severity) return false;
      return true;
    }).toList();
  }

  @override
  Future<PlatformIncidentItem> updateIncidentStatus(String incidentId, String newStatus, {String? notes}) async {
    final idx = incidents.indexWhere((inc) => inc.id == incidentId);
    if (idx == -1) throw Exception('Not found');
    final updated = PlatformIncidentItem(
      id: incidents[idx].id,
      title: incidents[idx].title,
      description: incidents[idx].description,
      severity: incidents[idx].severity,
      status: newStatus,
      affectedComponent: incidents[idx].affectedComponent,
      commanderUserId: incidents[idx].commanderUserId,
      openedAt: incidents[idx].openedAt,
      rootCause: incidents[idx].rootCause,
      mitigationSummary: incidents[idx].mitigationSummary,
      timeline: incidents[idx].timeline,
    );
    incidents[idx] = updated;
    return updated;
  }
}

void main() {
  group('Phase 43 — Platform Incidents Page Tests', () {
    testWidgets('renders empty state when no incidents found', (tester) async {
      final mockSource = MockPlatformIncidentsDataSource(incidents: []);

      await tester.pumpWidget(
        MaterialApp(
          home: PlatformIncidentsPage(dataSource: mockSource),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await tester.pumpAndSettle();

      expect(find.text('Platform Incidents'), findsOneWidget);
      expect(find.text('No platform incidents found'), findsOneWidget);
    });

    testWidgets('renders incident list with severity and status badges', (tester) async {
      final sampleIncident = PlatformIncidentItem(
        id: 'inc-101',
        title: 'OTA Rollout Verification Spike',
        description: 'Multiple devices reported checksum mismatch',
        severity: 'SEV1',
        status: 'OPEN',
        affectedComponent: 'FLEET_OTA',
        commanderUserId: 'usr-admin-1',
        openedAt: '2026-09-06T12:00:00Z',
        timeline: const [
          PlatformIncidentTimelineEntry(
            type: 'LIFECYCLE',
            timestamp: '2026-09-06T12:00:00Z',
            summary: 'Incident opened with severity SEV1',
          ),
        ],
      );

      final mockSource = MockPlatformIncidentsDataSource(incidents: [sampleIncident]);

      await tester.pumpWidget(
        MaterialApp(
          home: PlatformIncidentsPage(dataSource: mockSource),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('OTA Rollout Verification Spike'), findsOneWidget);
      expect(find.text('SEV1'), findsOneWidget);
      expect(find.widgetWithText(ChoiceChip, 'OPEN'), findsOneWidget);
      expect(find.textContaining('FLEET_OTA'), findsOneWidget);
    });

    testWidgets('opens incident details bottom sheet on tap', (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final sampleIncident = PlatformIncidentItem(
        id: 'inc-102',
        title: 'High 5xx Server Error Rate',
        description: 'Authentication backend degradation',
        severity: 'SEV2',
        status: 'INVESTIGATING',
        affectedComponent: 'AUTH_SERVICE',
        commanderUserId: 'usr-sec-ops',
        openedAt: '2026-09-06T14:00:00Z',
        rootCause: 'Connection pool saturation',
        mitigationSummary: 'Scaled pool size to 50',
        timeline: const [
          PlatformIncidentTimelineEntry(
            type: 'LIFECYCLE',
            timestamp: '2026-09-06T14:00:00Z',
            summary: 'Incident opened',
          ),
          PlatformIncidentTimelineEntry(
            type: 'ALERT',
            timestamp: '2026-09-06T14:01:00Z',
            summary: 'Alert triggered: High 5xx Server Error Rate',
          ),
        ],
      );

      final mockSource = MockPlatformIncidentsDataSource(incidents: [sampleIncident]);

      await tester.pumpWidget(
        MaterialApp(
          home: PlatformIncidentsPage(dataSource: mockSource),
        ),
      );

      await tester.pumpAndSettle();

      // Tap the list tile
      await tester.tap(find.text('High 5xx Server Error Rate'));
      await tester.pumpAndSettle();

      // Check sheet contents
      expect(find.text('Authentication backend degradation'), findsOneWidget);
      expect(find.text('Connection pool saturation'), findsOneWidget);
      expect(find.text('Scaled pool size to 50'), findsOneWidget);
      expect(find.text('Resolve Incident'), findsOneWidget);
    });

    testWidgets('renders error state on fetch failure', (tester) async {
      final mockSource = MockPlatformIncidentsDataSource();
      mockSource.shouldThrow = true;

      await tester.pumpWidget(
        MaterialApp(
          home: PlatformIncidentsPage(dataSource: mockSource),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.textContaining('Error: Exception: Network error'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
    });
  });
}
