import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:smart_home_application_v1/core/models/fleet_models.dart';
import 'package:smart_home_application_v1/core/services/fleet_management_service.dart';
import 'package:smart_home_application_v1/features/fleet/presentation/firmware_update_card.dart';
import 'package:smart_home_application_v1/features/fleet/presentation/fleet_health_dashboard_page.dart';

void main() {
  group('Phase 18 — Fleet & OTA Models Serialization Tests', () {
    test('FirmwareRelease serialization and deserialization', () {
      final release = FirmwareRelease(
        id: 'rel_101',
        productVariantId: 'eh-smart-switch-3x',
        hardwareRevision: 'HW_1_0',
        firmwareFamily: 'esp32-switch-platform',
        version: '1.2.0',
        minFirmwareVersion: '1.0.0',
        releaseChannel: 'production',
        binarySizeBytes: 1048576,
        sha256: 'a1b2c3d4e5f6',
        downloadUrl: 'https://ota.ehhome.io/firmware/v1.2.0.bin',
        releaseNotes: 'Fixed power spike bugs',
      );

      final jsonMap = release.toJson();
      expect(jsonMap['id'], 'rel_101');
      expect(jsonMap['version'], '1.2.0');
      expect(jsonMap['binarySizeBytes'], 1048576);

      final deserialized = FirmwareRelease.fromJson(jsonMap);
      expect(deserialized.id, release.id);
      expect(deserialized.version, release.version);
      expect(deserialized.productVariantId, release.productVariantId);
    });

    test('OtaOperation serialization and deserialization', () {
      final op = OtaOperation(
        id: 'op_101',
        deviceId: 'dev_1',
        homeId: 'home_1',
        releaseId: 'rel_101',
        fromVersion: '1.0.0',
        targetVersion: '1.2.0',
        status: OtaOperationStatus.downloading,
        progressPercent: 45,
        startedAt: DateTime.now().toIso8601String(),
      );

      final jsonMap = op.toJson();
      expect(jsonMap['id'], 'op_101');
      expect(jsonMap['status'], 'DOWNLOADING');
      expect(jsonMap['progressPercent'], 45);

      final deserialized = OtaOperation.fromJson(jsonMap);
      expect(deserialized.id, op.id);
      expect(deserialized.status, OtaOperationStatus.downloading);
      expect(deserialized.progressPercent, 45);
    });

    test('FleetStatus serialization and aggregation', () {
      final summary = FleetDeviceSummary(
        deviceId: 'dev_1',
        productVariantId: 'eh-smart-switch-3x',
        firmwareVersion: '1.0.0',
        healthStatus: 'HEALTHY',
        connectionState: 'ONLINE',
        otaStatus: OtaOperationStatus.available,
        availableUpdate: {
          'releaseId': 'rel_101',
          'version': '1.2.0',
          'releaseNotes': 'New features',
        },
      );

      final fleetStatus = FleetStatus(
        totalDevices: 1,
        onlineDevices: 1,
        offlineDevices: 0,
        staleDevices: 0,
        degradedDevices: 0,
        otaUpdateAvailableCount: 1,
        otaInProgressCount: 0,
        otaFailedCount: 0,
        devices: [summary],
      );

      final jsonMap = fleetStatus.toJson();
      expect(jsonMap['totalDevices'], 1);
      expect(jsonMap['otaUpdateAvailableCount'], 1);

      final deserialized = FleetStatus.fromJson(jsonMap);
      expect(deserialized.totalDevices, 1);
      expect(deserialized.devices.first.firmwareVersion, '1.0.0');
      expect(deserialized.devices.first.otaStatus, OtaOperationStatus.available);
    });
  });

  group('Phase 18 — FleetManagementService HTTP Client Tests', () {
    test('fetchFleetStatus parses API envelope successfully', () async {
      final mockClient = MockClient((request) async {
        if (request.url.path.contains('/api/v1/fleet/status')) {
          final payload = {
            'success': true,
            'data': {
              'schemaVersion': 1,
              'homeId': 'home_123',
              'totalDevices': 2,
              'onlineDevices': 2,
              'offlineDevices': 0,
              'staleDevices': 0,
              'degradedDevices': 0,
              'otaUpdateAvailableCount': 1,
              'otaInProgressCount': 0,
              'otaFailedCount': 0,
              'devices': [
                {
                  'deviceId': 'd1',
                  'productVariantId': 'eh-smart-switch-3x',
                  'firmwareVersion': '1.0.0',
                  'healthStatus': 'HEALTHY',
                  'connectionState': 'ONLINE',
                  'availableUpdate': {
                    'releaseId': 'rel_2',
                    'version': '1.1.0',
                  }
                },
                {
                  'deviceId': 'd2',
                  'productVariantId': 'eh-smart-switch-3x',
                  'firmwareVersion': '1.1.0',
                  'healthStatus': 'HEALTHY',
                  'connectionState': 'ONLINE',
                }
              ]
            }
          };
          return http.Response(json.encode(payload), 200,
              headers: {'content-type': 'application/json'});
        }
        return http.Response('Not Found', 404);
      });

      final service = FleetManagementService(httpClient: mockClient);
      final status = await service.fetchFleetStatus(homeId: 'home_123');

      expect(status.totalDevices, 2);
      expect(status.otaUpdateAvailableCount, 1);
      expect(service.cachedFleetStatus, isNotNull);
    });

    test('initiateOtaUpdate posts to API and returns operation', () async {
      final mockClient = MockClient((request) async {
        if (request.url.path.contains('/api/v1/ota/operations') && request.method == 'POST') {
          final payload = {
            'success': true,
            'data': {
              'id': 'op_999',
              'deviceId': 'd1',
              'homeId': 'home_123',
              'releaseId': 'rel_2',
              'fromVersion': '1.0.0',
              'targetVersion': '1.1.0',
              'status': 'DOWNLOADING',
              'progressPercent': 10,
              'startedAt': DateTime.now().toIso8601String(),
            }
          };
          return http.Response(json.encode(payload), 201,
              headers: {'content-type': 'application/json'});
        }
        return http.Response('Not Found', 404);
      });

      final service = FleetManagementService(httpClient: mockClient);
      final op = await service.initiateOtaUpdate(
        deviceId: 'd1',
        releaseId: 'rel_2',
        homeId: 'home_123',
      );

      expect(op.id, 'op_999');
      expect(op.status, OtaOperationStatus.downloading);
      expect(op.targetVersion, '1.1.0');
    });
  });

  group('Phase 18 — Fleet & OTA UI Widgets Tests', () {
    testWidgets('FirmwareUpdateCard displays up-to-date and update states', (tester) async {
      final service = FleetManagementService();

      // 1. Up-to-date
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FirmwareUpdateCard(
              deviceId: 'dev_1',
              homeId: 'home_1',
              currentVersion: '1.2.0',
              productVariantId: 'eh-smart-switch-3x',
              fleetService: service,
            ),
          ),
        ),
      );

      expect(find.text('Device Firmware'), findsOneWidget);
      expect(find.text('v1.2.0'), findsOneWidget);
      expect(find.text('Firmware is up to date'), findsOneWidget);

      // 2. Update Available
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FirmwareUpdateCard(
              deviceId: 'dev_1',
              homeId: 'home_1',
              currentVersion: '1.0.0',
              productVariantId: 'eh-smart-switch-3x',
              availableUpdate: const {
                'releaseId': 'rel_2',
                'version': '1.1.0',
                'releaseNotes': 'Bug fixes and performance boost',
              },
              fleetService: service,
            ),
          ),
        ),
      );

      expect(find.text('Update Available: v1.1.0'), findsOneWidget);
      expect(find.text('Install Update Now'), findsOneWidget);
      expect(find.text('Bug fixes and performance boost'), findsOneWidget);
    });

    testWidgets('FleetHealthDashboardPage renders KPIs and filters', (tester) async {
      final initialFleet = FleetStatus(
        totalDevices: 3,
        onlineDevices: 2,
        offlineDevices: 1,
        staleDevices: 0,
        degradedDevices: 0,
        otaUpdateAvailableCount: 1,
        otaInProgressCount: 0,
        otaFailedCount: 0,
        devices: [
          const FleetDeviceSummary(
            deviceId: 'dev_101',
            productVariantId: 'eh-smart-switch-3x',
            firmwareVersion: '1.0.0',
            healthStatus: 'HEALTHY',
            connectionState: 'ONLINE',
            availableUpdate: {
              'releaseId': 'rel_1',
              'version': '1.1.0',
            },
          ),
        ],
      );

      final service = FleetManagementService(initialStatus: initialFleet);

      await tester.pumpWidget(
        MaterialApp(
          home: FleetHealthDashboardPage(fleetService: service, homeId: 'home_1'),
        ),
      );

      expect(find.text('Fleet & Firmware Health'), findsOneWidget);
      expect(find.text('Total'), findsOneWidget);
      expect(find.text('Online'), findsOneWidget);
      expect(find.text('Updates'), findsOneWidget);
      expect(find.text('All (3)'), findsOneWidget);
    });
  });
}
