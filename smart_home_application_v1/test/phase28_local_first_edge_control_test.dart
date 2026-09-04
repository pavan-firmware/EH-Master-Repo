import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_home_application_v1/core/models/edge_control_models.dart';
import 'package:smart_home_application_v1/core/services/edge_control_service.dart';
import 'package:smart_home_application_v1/core/theme/app_theme.dart';
import 'package:smart_home_application_v1/features/edge_control/presentation/local_mode_indicator.dart';
import 'package:smart_home_application_v1/features/edge_control/presentation/edge_device_control_card.dart';
import 'package:smart_home_application_v1/features/edge_control/presentation/edge_execution_dashboard_page.dart';

void main() {
  group('Phase 28 — Local-First Edge Control Models', () {
    test('LocalConnectivityStatus serialization and deserialization', () {
      final json = {
        'homeId': 'home_001',
        'isLocalNetworkActive': true,
        'localDevicesCount': 5,
        'reachableDevicesCount': 5,
        'avgLocalLatencyMs': 12.4,
        'activeTransportSummary': {'WIFI_MQTT': 5},
        'lastDiscoveredAt': '2026-09-04T12:00:00.000Z'
      };

      final status = LocalConnectivityStatus.fromJson(json);
      expect(status.homeId, 'home_001');
      expect(status.isLocalNetworkActive, true);
      expect(status.localDevicesCount, 5);
      expect(status.avgLocalLatencyMs, 12.4);

      final outJson = status.toJson();
      expect(outJson['homeId'], 'home_001');
      expect(outJson['isLocalNetworkActive'], true);
    });

    test('ExecutionRouteDecision serialization and deserialization', () {
      final json = {
        'deviceId': 'dev_001',
        'homeId': 'home_001',
        'routeMode': 'LOCAL',
        'confidence': 0.95,
        'transportType': 'WIFI_MQTT',
        'localEndpoint': '192.168.1.100:1883',
        'reason': 'Local route cache REACHABLE',
        'evaluatedAt': '2026-09-04T12:00:00.000Z'
      };

      final decision = ExecutionRouteDecision.fromJson(json);
      expect(decision.deviceId, 'dev_001');
      expect(decision.routeMode, ExecutionRouteMode.local);
      expect(decision.confidence, 0.95);
      expect(decision.localEndpoint, '192.168.1.100:1883');
    });

    test('EdgeExecutionResult serialization and deserialization', () {
      final json = {
        'commandId': 'cmd_001',
        'deviceId': 'dev_001',
        'homeId': 'home_001',
        'channelIndex': 1,
        'action': 'setPower',
        'routeMode': 'LOCAL',
        'transportUsed': 'WIFI_MQTT',
        'status': 'CONFIRMED',
        'isConfirmedByDevice': true,
        'confirmedState': {'power': true},
        'latencyMs': 15.2,
        'isIdempotentReplay': false,
        'executedAt': '2026-09-04T12:00:00.000Z'
      };

      final result = EdgeExecutionResult.fromJson(json);
      expect(result.commandId, 'cmd_001');
      expect(result.status, 'CONFIRMED');
      expect(result.isConfirmedByDevice, true);
      expect(result.routeMode, ExecutionRouteMode.local);
    });

    test('DiscoveredLocalNode and EdgeMetricsSummary deserialization', () {
      final node = DiscoveredLocalNode.fromJson({
        'id': 'node_001',
        'deviceId': 'dev_001',
        'homeId': 'home_001',
        'macAddress': 'AA:BB:CC:11:22:33',
        'ipAddress': '192.168.1.120',
        'port': 1883,
        'transportType': 'WIFI_MQTT',
        'isTrusted': true,
        'lastSeenAt': '2026-09-04T12:00:00.000Z'
      });
      expect(node.deviceId, 'dev_001');
      expect(node.isTrusted, true);

      final metrics = EdgeMetricsSummary.fromJson({
        'homeId': 'home_001',
        'totalExecutions': 100,
        'localExecutions': 95,
        'cloudExecutions': 5,
        'localSuccessRate': 0.98,
        'avgLocalLatencyMs': 14.2,
        'avgCloudLatencyMs': 145.0
      });
      expect(metrics.totalExecutions, 100);
      expect(metrics.localExecutions, 95);
      expect(metrics.localSuccessRate, 0.98);
    });
  });

  group('Phase 28 — Presentation Widgets', () {
    Widget createThemedTestApp(Widget child) {
      return MaterialApp(
        theme: EHAppTheme.lightTheme,
        darkTheme: EHAppTheme.darkTheme,
        home: Scaffold(body: child),
      );
    }

    testWidgets('LocalModeIndicator renders Local Fast badge in LOCAL mode', (tester) async {
      await tester.pumpWidget(createThemedTestApp(
        const LocalModeIndicator(
          routeMode: ExecutionRouteMode.local,
          avgLatencyMs: 14.5,
        ),
      ));

      expect(find.text('Local Fast'), findsOneWidget);
      expect(find.text('15ms'), findsOneWidget);
    });

    testWidgets('LocalModeIndicator renders Cloud Sync badge in CLOUD mode', (tester) async {
      await tester.pumpWidget(createThemedTestApp(
        const LocalModeIndicator(
          routeMode: ExecutionRouteMode.cloud,
        ),
      ));

      expect(find.text('Cloud Sync'), findsOneWidget);
    });

    testWidgets('LocalModeIndicator renders Offline badge in UNAVAILABLE mode', (tester) async {
      await tester.pumpWidget(createThemedTestApp(
        const LocalModeIndicator(
          routeMode: ExecutionRouteMode.unavailable,
        ),
      ));

      expect(find.text('Offline'), findsOneWidget);
    });

    testWidgets('EdgeDeviceControlCard renders Ready state when idle', (tester) async {
      await tester.pumpWidget(createThemedTestApp(
        const EdgeDeviceControlCard(
          deviceId: 'dev_001',
          deviceName: 'Living Room Light',
          roomName: 'Living Room',
          isOn: true,
          controlStatus: EdgeDeviceControlStatus.idle,
          routeMode: ExecutionRouteMode.local,
        ),
      ));

      expect(find.text('Living Room Light'), findsOneWidget);
      expect(find.text('Ready'), findsOneWidget);
      expect(find.text('Local'), findsOneWidget);
    });

    testWidgets('EdgeDeviceControlCard renders Verifying hardware... when pending', (tester) async {
      await tester.pumpWidget(createThemedTestApp(
        const EdgeDeviceControlCard(
          deviceId: 'dev_001',
          deviceName: 'Kitchen Socket',
          isOn: false,
          controlStatus: EdgeDeviceControlStatus.pending,
        ),
      ));

      expect(find.text('Kitchen Socket'), findsOneWidget);
      expect(find.text('Verifying hardware...'), findsOneWidget);
    });

    testWidgets('EdgeDeviceControlCard renders Confirmed when hardware confirms', (tester) async {
      await tester.pumpWidget(createThemedTestApp(
        const EdgeDeviceControlCard(
          deviceId: 'dev_001',
          deviceName: 'Bedroom Fan',
          isOn: true,
          controlStatus: EdgeDeviceControlStatus.confirmed,
          lastLatencyMs: 16.0,
        ),
      ));

      expect(find.text('Confirmed'), findsOneWidget);
      expect(find.text('• 16ms'), findsOneWidget);
    });

    testWidgets('EdgeDeviceControlCard renders Command Failed with retry on failure', (tester) async {
      bool retryClicked = false;
      await tester.pumpWidget(createThemedTestApp(
        EdgeDeviceControlCard(
          deviceId: 'dev_001',
          deviceName: 'Balcony Light',
          isOn: false,
          controlStatus: EdgeDeviceControlStatus.failed,
          onRetry: () => retryClicked = true,
        ),
      ));

      expect(find.text('Command Failed'), findsOneWidget);
      expect(find.byType(IconButton), findsOneWidget);

      await tester.tap(find.byType(IconButton));
      expect(retryClicked, true);
    });

    testWidgets('EdgeExecutionDashboardPage renders resiliency banner & edge controls', (tester) async {
      final service = EdgeControlService(baseUrl: 'http://localhost:3000');

      await tester.pumpWidget(createThemedTestApp(
        EdgeExecutionDashboardPage(
          homeId: 'home_001',
          homeName: 'Intelligent Villa',
          edgeService: service,
        ),
      ));

      await tester.pump();

      expect(find.text('Intelligent Villa'), findsOneWidget);
      expect(find.text('Local-First Edge Control'), findsOneWidget);
      expect(find.text('Local-First Resiliency Active'), findsOneWidget);
      expect(find.text('Interactive Local Control'), findsOneWidget);
      expect(find.text('Edge-Executed Scenes'), findsOneWidget);
      expect(find.text('All Lights Off'), findsOneWidget);
      expect(find.text('Welcome Home'), findsOneWidget);
    });
  });
}
