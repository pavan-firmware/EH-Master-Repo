import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:smart_home_application_v1/core/models/energy_models.dart';
import 'package:smart_home_application_v1/core/services/energy_service.dart';
import 'package:smart_home_application_v1/features/energy/presentation/device_energy_details_page.dart';
import 'package:smart_home_application_v1/features/energy/presentation/energy_threshold_dialog.dart';
import 'package:smart_home_application_v1/features/energy/presentation/home_energy_dashboard_page.dart';

void main() {
  group('Phase 19 — Energy Models Serialization Tests', () {
    test('EnergyMeasurement serialization and deserialization', () {
      final measurement = EnergyMeasurement(
        id: 'telem_101',
        deviceId: 'dev_oven_1',
        channelIndex: 1,
        voltageV: 230.5,
        currentA: 8.2,
        powerW: 1890.1,
        totalEnergyKwh: 14.52,
        intervalEnergyWh: 2.6,
        frequencyHz: 50.01,
        powerFactor: 0.99,
        flags: 0,
        sequenceNumber: 42,
        timestamp: DateTime.parse('2026-09-02T12:00:00.000Z'),
      );

      final jsonMap = measurement.toJson();
      expect(jsonMap['id'], 'telem_101');
      expect(jsonMap['powerW'], 1890.1);
      expect(jsonMap['voltageV'], 230.5);

      final deserialized = EnergyMeasurement.fromJson(jsonMap);
      expect(deserialized.id, measurement.id);
      expect(deserialized.powerW, measurement.powerW);
      expect(deserialized.totalEnergyKwh, measurement.totalEnergyKwh);
    });

    test('EnergyUsageSummary with PeriodComparison serialization and deserialization', () {
      final summary = EnergyUsageSummary(
        schemaVersion: 1,
        entityType: 'home',
        entityId: 'home_1',
        period: 'today',
        currentPowerW: 2450.0,
        totalEnergyKwh: 18.75,
        peakPowerW: 3200.0,
        avgPowerW: 1540.0,
        costEstimate: 2.81,
        currency: 'USD',
        devicesCount: 3,
        roomsCount: 2,
        comparison: const EnergyPeriodComparison(
          currentPeriodEnergyKwh: 18.75,
          previousPeriodEnergyKwh: 17.50,
          deltaEnergyKwh: 1.25,
          percentageChange: 7.1,
          trendDirection: TrendDirection.up,
        ),
        lastUpdated: DateTime.parse('2026-09-02T14:30:00.000Z'),
      );

      final jsonMap = summary.toJson();
      expect(jsonMap['entityType'], 'home');
      expect(jsonMap['currentPowerW'], 2450.0);
      expect(jsonMap['comparison']['trendDirection'], 'UP');

      final deserialized = EnergyUsageSummary.fromJson(jsonMap);
      expect(deserialized.entityId, summary.entityId);
      expect(deserialized.costEstimate, summary.costEstimate);
      expect(deserialized.comparison?.trendDirection, TrendDirection.up);
    });

    test('EnergyThresholdConfig and EnergyAnomalyEvent serialization', () {
      final config = const EnergyThresholdConfig(
        id: 'ethr_1',
        homeId: 'home_1',
        highPowerW: 3000.0,
        dailyEnergyKwh: 35.0,
        costPerKwh: 0.18,
        currency: 'USD',
        isEnabled: true,
      );

      final configJson = config.toJson();
      expect(configJson['highPowerW'], 3000.0);
      expect(configJson['isEnabled'], true);

      final event = EnergyAnomalyEvent(
        id: 'evt_1',
        homeId: 'home_1',
        deviceId: 'dev_oven_1',
        eventType: 'HIGH_POWER_EXCEEDED',
        severity: 'WARN',
        valueRecorded: 3200.0,
        thresholdValue: 3000.0,
        message: 'High load spike detected',
        createdAt: DateTime.parse('2026-09-02T15:00:00.000Z'),
      );

      final eventJson = event.toJson();
      expect(eventJson['eventType'], 'HIGH_POWER_EXCEEDED');
      expect(eventJson['valueRecorded'], 3200.0);
    });
  });

  group('Phase 19 — EnergyService HTTP Client Tests', () {
    test('fetchHomeSummary parses API response correctly', () async {
      final mockClient = MockClient((request) async {
        if (request.url.path == '/api/v1/energy/homes/home_1/summary') {
          return http.Response(
            json.encode({
              'success': true,
              'data': {
                'schemaVersion': 1,
                'entityType': 'home',
                'entityId': 'home_1',
                'period': 'today',
                'currentPowerW': 2100.0,
                'totalEnergyKwh': 12.4,
                'peakPowerW': 2800.0,
                'avgPowerW': 1400.0,
                'costEstimate': 1.86,
                'currency': 'USD',
                'devicesCount': 2,
                'roomsCount': 2,
                'dataQuality': 'GOOD',
                'sampleCount': 85,
                'lastUpdated': '2026-09-02T12:00:00Z',
              }
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('Not Found', 404);
      });

      final service = EnergyService(
        httpClient: mockClient,
        baseUrl: 'http://mock.ehhome.local',
      );

      final summary = await service.fetchHomeSummary('home_1', period: 'today');
      expect(summary, isNotNull);
      expect(summary!.currentPowerW, 2100.0);
      expect(summary.totalEnergyKwh, 12.4);
      expect(summary.costEstimate, 1.86);
      expect(service.cachedHomeSummary?.entityId, 'home_1');
    });

    test('fetchDeviceLatest and fetchTopConsumers parses API response', () async {
      final mockClient = MockClient((request) async {
        if (request.url.path == '/api/v1/energy/devices/dev_1/latest') {
          return http.Response(
            json.encode({
              'success': true,
              'data': {
                'deviceId': 'dev_1',
                'channelIndex': 1,
                'voltageV': 230.1,
                'currentA': 4.5,
                'powerW': 1035.0,
                'totalEnergyKwh': 8.9,
                'frequencyHz': 50.0,
                'powerFactor': 0.98,
                'flags': 0,
                'sequenceNumber': 10,
                'timestamp': '2026-09-02T12:00:00Z',
              }
            }),
            200,
          );
        }
        if (request.url.path == '/api/v1/energy/homes/home_1/top-consumers') {
          return http.Response(
            json.encode({
              'success': true,
              'data': {
                'homeId': 'home_1',
                'period': 'today',
                'totalEnergyKwh': 12.4,
                'topDevices': [
                  {
                    'id': 'dev_1',
                    'name': 'Smart Oven',
                    'type': 'device',
                    'roomName': 'Kitchen',
                    'energyKwh': 8.9,
                    'currentPowerW': 1035.0,
                    'percentageOfTotal': 71.8
                  }
                ],
                'topRooms': [
                  {
                    'id': 'room_1',
                    'name': 'Kitchen',
                    'type': 'room',
                    'energyKwh': 8.9,
                    'currentPowerW': 1035.0,
                    'percentageOfTotal': 71.8
                  }
                ]
              }
            }),
            200,
          );
        }
        return http.Response('Not Found', 404);
      });

      final service = EnergyService(
        httpClient: mockClient,
        baseUrl: 'http://mock.ehhome.local',
      );

      final latest = await service.fetchDeviceLatest('dev_1');
      expect(latest, isNotNull);
      expect(latest!.voltageV, 230.1);
      expect(latest.powerW, 1035.0);

      await service.fetchTopConsumers('home_1');
      expect(service.cachedTopDevices.length, 1);
      expect(service.cachedTopDevices.first.name, 'Smart Oven');
      expect(service.cachedTopDevices.first.percentageOfTotal, 71.8);
    });
  });

  group('Phase 19 — Energy Widgets UI Tests', () {
    testWidgets('HomeEnergyDashboardPage renders live load gauge and top consumers', (tester) async {
      final initialSummary = EnergyUsageSummary(
        schemaVersion: 1,
        entityType: 'home',
        entityId: 'home_1',
        period: 'today',
        currentPowerW: 1850.0,
        totalEnergyKwh: 9.42,
        peakPowerW: 2400.0,
        avgPowerW: 1100.0,
        costEstimate: 1.41,
        currency: 'USD',
        devicesCount: 2,
        roomsCount: 2,
        lastUpdated: DateTime.now(),
      );

      final mockClient = MockClient((request) async {
        if (request.url.path.contains('/summary')) {
          return http.Response(
            json.encode({'success': true, 'data': initialSummary.toJson()}),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response(
          json.encode({'success': true, 'data': {}}),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final service = EnergyService(
        httpClient: mockClient,
        initialSummary: initialSummary,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: HomeEnergyDashboardPage(
            energyService: service,
            homeId: 'home_1',
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Energy Intelligence'), findsOneWidget);
      expect(find.text('1850 W'), findsOneWidget);
      expect(find.text('Total Current Load'), findsOneWidget);
      expect(find.text('9.42 kWh'), findsOneWidget);
    });

    testWidgets('DeviceEnergyDetailsPage renders live metrics', (tester) async {
      final mockClient = MockClient((request) async {
        if (request.url.path.contains('/latest')) {
          return http.Response(
            json.encode({
              'success': true,
              'data': {
                'deviceId': 'dev_1',
                'channelIndex': 1,
                'voltageV': 230.0,
                'currentA': 5.0,
                'powerW': 1150.0,
                'totalEnergyKwh': 4.5,
                'frequencyHz': 50.0,
                'powerFactor': 0.99,
                'flags': 0,
                'sequenceNumber': 1,
                'timestamp': '2026-09-02T12:00:00Z',
              }
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response(
          json.encode({
            'success': true,
            'data': {
              'schemaVersion': 1,
              'entityType': 'device',
              'entityId': 'dev_1',
              'period': 'today',
              'currentPowerW': 1150.0,
              'totalEnergyKwh': 4.5,
              'peakPowerW': 1500.0,
              'avgPowerW': 950.0,
              'lastUpdated': '2026-09-02T12:00:00Z',
            }
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final service = EnergyService(httpClient: mockClient);

      await tester.pumpWidget(
        MaterialApp(
          home: DeviceEnergyDetailsPage(
            energyService: service,
            deviceId: 'dev_1',
            deviceName: 'Living Room AC',
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Living Room AC'), findsOneWidget);
      expect(find.text('Live Telemetry'), findsOneWidget);
      expect(find.text('1150.0 W'), findsOneWidget);
      expect(find.text('230.0 V'), findsOneWidget);
    });

    testWidgets('EnergyThresholdDialog allows entering threshold values', (tester) async {
      final mockClient = MockClient((request) async {
        return http.Response(
          json.encode({'success': true, 'data': {'id': 'ethr_1'}}),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final service = EnergyService(httpClient: mockClient);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EnergyThresholdDialog(
              energyService: service,
              homeId: 'home_1',
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Energy Thresholds & Budget'), findsOneWidget);
      expect(find.text('Enable Energy Alerts'), findsOneWidget);
      expect(find.text('Save'), findsOneWidget);
    });
  });
}
