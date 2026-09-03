import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:smart_home_application_v1/core/models/connectivity_models.dart';
import 'package:smart_home_application_v1/core/services/connectivity_service.dart';
import 'package:smart_home_application_v1/features/connectivity/presentation/device_connectivity_page.dart';
import 'package:smart_home_application_v1/features/connectivity/presentation/transport_details_page.dart';
import 'package:smart_home_application_v1/features/connectivity/presentation/commissioning_status_page.dart';
import 'package:smart_home_application_v1/features/connectivity/presentation/transport_health_card.dart';
import 'package:smart_home_application_v1/features/connectivity/presentation/transport_selector.dart';

void main() {
  group('Phase 26 — Multi-Protocol Connectivity Model Tests', () {
    test('DeviceTransportType serialization and display labels', () {
      expect(DeviceTransportType.wifiMqtt.toApiValue(), 'WIFI_MQTT');
      expect(DeviceTransportType.ble.toApiValue(), 'BLE');
      expect(DeviceTransportType.thread.toApiValue(), 'THREAD');
      expect(DeviceTransportType.matter.toApiValue(), 'MATTER');

      expect(DeviceTransportType.fromJson('WIFI_MQTT'), DeviceTransportType.wifiMqtt);
      expect(DeviceTransportType.fromJson('BLE'), DeviceTransportType.ble);
      expect(DeviceTransportType.fromJson('THREAD'), DeviceTransportType.thread);
      expect(DeviceTransportType.fromJson('MATTER'), DeviceTransportType.matter);

      expect(DeviceTransportType.wifiMqtt.toDisplayLabel(), 'Wi-Fi / MQTT');
      expect(DeviceTransportType.matter.toDisplayLabel(), 'Matter over Thread/Wi-Fi');
    });

    test('TransportCapability parsing', () {
      final json = {
        'transportType': 'MATTER',
        'isSupported': true,
        'isConfigured': true,
        'priorityRank': 2,
        'directIp': true,
        'meshCapable': true,
        'lowPower': false,
        'localOnly': true,
        'maxPayloadBytes': 65536,
      };
      final cap = TransportCapability.fromJson(json);
      expect(cap.transportType, DeviceTransportType.matter);
      expect(cap.isSupported, true);
      expect(cap.priorityRank, 2);
      expect(cap.directIp, true);
      expect(cap.meshCapable, true);
    });

    test('TransportHealth parsing', () {
      final json = {
        'transportType': 'BLE',
        'availability': 'ONLINE',
        'latencyMs': 28.5,
        'errorRate': 0.02,
        'reconnectCount': 1,
        'signalRssi': -68,
      };
      final health = TransportHealth.fromJson(json);
      expect(health.transportType, DeviceTransportType.ble);
      expect(health.availability, TransportAvailability.online);
      expect(health.latencyMs, 28.5);
      expect(health.errorRate, 0.02);
      expect(health.signalRssi, -68);
    });

    test('DeviceConnectionSnapshot parsing', () {
      final json = {
        'deviceId': 'dev_100',
        'homeId': 'home_200',
        'activeTransport': 'THREAD',
        'connectionState': 'CONNECTED',
        'supportedTransports': ['WIFI_MQTT', 'THREAD', 'BLE'],
        'transportHealth': {
          'THREAD': {
            'transportType': 'THREAD',
            'availability': 'ONLINE',
            'latencyMs': 19.0,
            'errorRate': 0.0,
            'reconnectCount': 0,
          },
        },
        'reconnectCount': 0,
        'updatedAt': '2026-09-03T12:00:00.000Z',
      };
      final snap = DeviceConnectionSnapshot.fromJson(json);
      expect(snap.deviceId, 'dev_100');
      expect(snap.homeId, 'home_200');
      expect(snap.activeTransport, DeviceTransportType.thread);
      expect(snap.connectionState, DeviceConnectionState.connected);
      expect(snap.supportedTransports.length, 3);
      expect(snap.transportHealth['THREAD']?.latencyMs, 19.0);
    });

    test('CommissioningSession parsing', () {
      final json = {
        'id': 'comm_abc',
        'home_id': 'home_200',
        'device_id': 'dev_100',
        'transport_type': 'MATTER',
        'stage': 'AUTHENTICATING',
        'started_at': '2026-09-03T12:00:00.000Z',
      };
      final session = CommissioningSession.fromJson(json);
      expect(session.sessionId, 'comm_abc');
      expect(session.transportType, DeviceTransportType.matter);
      expect(session.stage, CommissioningStage.authenticating);
    });

    test('FleetConnectivitySummary parsing', () {
      final json = {
        'homeId': 'home_200',
        'totalDevices': 12,
        'stateDistribution': {'CONNECTED': 10, 'DEGRADED': 2},
        'transportDistribution': {'WIFI_MQTT': 8, 'THREAD': 4},
        'generatedAt': '2026-09-03T12:00:00.000Z',
      };
      final summary = FleetConnectivitySummary.fromJson(json);
      expect(summary.totalDevices, 12);
      expect(summary.stateDistribution['CONNECTED'], 10);
      expect(summary.transportDistribution['WIFI_MQTT'], 8);
    });
  });

  group('Phase 26 — ConnectivityService HTTP Tests', () {
    test('loadDeviceConnection success', () async {
      final mockClient = MockClient((request) async {
        if (request.url.path.contains('/api/v1/connectivity/devices/dev_100')) {
          return http.Response(
            jsonEncode({
              'success': true,
              'data': {
                'deviceId': 'dev_100',
                'homeId': 'home_200',
                'activeTransport': 'WIFI_MQTT',
                'connectionState': 'CONNECTED',
                'supportedTransports': ['WIFI_MQTT'],
                'transportHealth': {},
                'updatedAt': '2026-09-03T12:00:00.000Z',
              },
            }),
            200,
          );
        }
        return http.Response('Not Found', 404);
      });

      final service = ConnectivityService(baseUrl: 'http://localhost:3000', client: mockClient);
      final snap = await service.loadDeviceConnection('dev_100');
      expect(snap, isNotNull);
      expect(snap?.activeTransport, DeviceTransportType.wifiMqtt);
      expect(snap?.connectionState, DeviceConnectionState.connected);
    });

    test('triggerReconnect success', () async {
      final mockClient = MockClient((request) async {
        if (request.url.path.contains('/reconnect')) {
          return http.Response(jsonEncode({'success': true, 'data': {}}), 200);
        }
        if (request.url.path.contains('/api/v1/connectivity/devices/dev_100')) {
          return http.Response(
            jsonEncode({
              'success': true,
              'data': {
                'deviceId': 'dev_100',
                'homeId': 'home_200',
                'activeTransport': 'WIFI_MQTT',
                'connectionState': 'RECONNECTING',
                'supportedTransports': ['WIFI_MQTT'],
                'transportHealth': {},
                'updatedAt': '2026-09-03T12:00:00.000Z',
              },
            }),
            200,
          );
        }
        return http.Response('Not Found', 404);
      });

      final service = ConnectivityService(baseUrl: 'http://localhost:3000', client: mockClient);
      final success = await service.triggerReconnect('dev_100');
      expect(success, true);
    });
  });

  group('Phase 26 — Presentation Widget Smoke Tests', () {
    testWidgets('TransportHealthCard renders correctly', (tester) async {
      const health = TransportHealth(
        transportType: DeviceTransportType.matter,
        availability: TransportAvailability.online,
        latencyMs: 16.0,
        errorRate: 0.0,
        reconnectCount: 0,
        signalRssi: -55,
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: TransportHealthCard(health: health, isActive: true),
          ),
        ),
      );

      expect(find.text('Matter over Thread/Wi-Fi'), findsOneWidget);
      expect(find.text('ACTIVE'), findsOneWidget);
      expect(find.text('Online'), findsOneWidget);
      expect(find.text('16 ms'), findsOneWidget);
    });

    testWidgets('TransportSelector selects transport', (tester) async {
      DeviceTransportType selected = DeviceTransportType.wifiMqtt;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) => TransportSelector(
                availableTransports: const [DeviceTransportType.wifiMqtt, DeviceTransportType.ble],
                selectedTransport: selected,
                onTransportSelected: (t) => setState(() => selected = t),
              ),
            ),
          ),
        ),
      );

      expect(find.text('Wi-Fi / MQTT'), findsOneWidget);
      expect(find.text('Bluetooth LE'), findsOneWidget);

      await tester.tap(find.text('Bluetooth LE'));
      await tester.pumpAndSettle();
      expect(selected, DeviceTransportType.ble);
    });

    testWidgets('DeviceConnectivityPage renders hero and controls', (tester) async {
      final service = ConnectivityService(baseUrl: 'http://localhost:3000');

      await tester.pumpWidget(
        MaterialApp(
          home: DeviceConnectivityPage(
            deviceId: 'dev_01',
            deviceName: 'Living Room Light',
            connectivityService: service,
          ),
        ),
      );

      expect(find.text('Living Room Light'), findsOneWidget);
      expect(find.text('Connectivity'), findsOneWidget);
    });

    testWidgets('TransportDetailsPage renders empty state gracefully', (tester) async {
      final service = ConnectivityService(baseUrl: 'http://localhost:3000');

      await tester.pumpWidget(
        MaterialApp(
          home: TransportDetailsPage(
            deviceId: 'dev_01',
            deviceName: 'Living Room Light',
            connectivityService: service,
          ),
        ),
      );

      expect(find.text('Living Room Light'), findsOneWidget);
      expect(find.text('Supported Protocols'), findsOneWidget);
      expect(find.text('No configured transport details available'), findsOneWidget);
    });

    testWidgets('CommissioningStatusPage renders pipeline', (tester) async {
      final session = CommissioningSession(
        sessionId: 'comm_01',
        homeId: 'home_01',
        deviceId: 'dev_01',
        transportType: DeviceTransportType.matter,
        stage: CommissioningStage.authenticating,
        startedAt: DateTime.now(),
      );

      final service = ConnectivityService(baseUrl: 'http://localhost:3000');

      await tester.pumpWidget(
        MaterialApp(
          home: CommissioningStatusPage(
            sessionId: 'comm_01',
            deviceName: 'Living Room Light',
            session: session,
            connectivityService: service,
          ),
        ),
      );

      expect(find.text('Living Room Light'), findsOneWidget);
      expect(find.text('Authenticating Credentials'), findsWidgets);
      expect(find.text('Cancel Commissioning'), findsOneWidget);
    });
  });
}
