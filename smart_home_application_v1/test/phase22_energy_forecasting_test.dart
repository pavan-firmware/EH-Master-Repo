import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:smart_home_application_v1/core/models/energy_predictive_models.dart';
import 'package:smart_home_application_v1/core/services/energy_predictive_service.dart';
import 'package:smart_home_application_v1/features/energy/presentation/energy_forecast_page.dart';
import 'package:smart_home_application_v1/features/energy/presentation/energy_anomalies_page.dart';
import 'package:smart_home_application_v1/features/energy/presentation/energy_efficiency_page.dart';
import 'package:smart_home_application_v1/features/energy/presentation/predictive_optimization_page.dart';
import 'package:smart_home_application_v1/features/energy/presentation/energy_baseline_details_page.dart';

void main() {
  group('Phase 22 Predictive Models Test Suite', () {
    test('EnergyForecast model parses correctly from JSON', () {
      final json = {
        'id': 'fc_01',
        'homeId': 'home_01',
        'scopeType': 'home',
        'scopeId': 'home_01',
        'horizon': 'next_24_hours',
        'startTime': '2026-07-16T00:00:00Z',
        'endTime': '2026-07-17T00:00:00Z',
        'predictedKwh': 14.5,
        'predictedCost': 3.25,
        'currency': 'USD',
        'confidenceScore': 0.88,
        'methodology': 'HISTORICAL_HOURLY_PROFILE_DAY_OF_WEEK',
        'dataCoverage': 'FULL',
        'isEstimate': true,
        'generatedAt': '2026-07-15T23:59:59Z',
        'points': [
          {
            'timestamp': '2026-07-16T00:00:00Z',
            'predictedPowerW': 450.0,
            'predictedEnergyWh': 450.0,
            'predictedCost': 0.036,
            'confidenceScore': 0.90
          }
        ]
      };

      final fc = EnergyForecast.fromJson(json);
      expect(fc.homeId, equals('home_01'));
      expect(fc.predictedKwh, equals(14.5));
      expect(fc.predictedCost, equals(3.25));
      expect(fc.confidenceScore, equals(0.88));
      expect(fc.isEstimate, isTrue);
      expect(fc.points.length, equals(1));
      expect(fc.points.first.predictedPowerW, equals(450.0));
    });

    test('EnergyAnomaly model parses correctly from JSON', () {
      final json = {
        'id': 'anom_01',
        'homeId': 'home_01',
        'scopeType': 'device',
        'scopeId': 'dev_ac_01',
        'anomalyType': 'UNUSUAL_POWER_SPIKE',
        'severity': 'HIGH',
        'observedValue': 3200.0,
        'baselineValue': 1200.0,
        'deviationPercentage': 166.7,
        'isConfirmed': true,
        'confirmationCount': 2,
        'evidence': {'observed': 3200},
        'detectedAt': '2026-07-15T14:30:00Z'
      };

      final anom = EnergyAnomaly.fromJson(json);
      expect(anom.id, equals('anom_01'));
      expect(anom.severity, equals(AnomalySeverity.high));
      expect(anom.observedValue, equals(3200.0));
      expect(anom.isConfirmed, isTrue);
    });

    test('EnergyEfficiencyScore model parses factors correctly', () {
      final json = {
        'homeId': 'home_01',
        'score': 85.5,
        'grade': 'A',
        'factors': {
          'standbyLossScore': 90.0,
          'peakDemandScore': 80.0,
          'thresholdViolationScore': 95.0,
          'tariffEfficiencyScore': 82.0,
          'trendScore': 80.0
        },
        'calculatedAt': '2026-07-15T12:00:00Z'
      };

      final eff = EnergyEfficiencyScore.fromJson(json);
      expect(eff.score, equals(85.5));
      expect(eff.grade, equals('A'));
      expect(eff.factors.standbyLossScore, equals(90.0));
      expect(eff.factors.peakDemandScore, equals(80.0));
    });
  });

  group('EnergyPredictiveService API Operations', () {
    late EnergyPredictiveService service;

    setUp(() {
      final mockClient = MockClient((request) async {
        final path = request.url.path;

        if (path.contains('/forecast/accuracy')) {
          return http.Response(
            jsonEncode({
              'success': true,
              'data': {
                'homeId': 'home_01',
                'horizon': 'next_24_hours',
                'sampleCount': 12,
                'mae': 0.85,
                'mape': 6.2,
                'hasSufficientData': true
              }
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        } else if (path.contains('/forecast')) {
          return http.Response(
            jsonEncode({
              'success': true,
              'data': {
                'id': 'fc_01',
                'homeId': 'home_01',
                'scopeType': 'home',
                'scopeId': 'home_01',
                'horizon': 'next_24_hours',
                'startTime': '2026-07-16T00:00:00Z',
                'endTime': '2026-07-17T00:00:00Z',
                'predictedKwh': 18.5,
                'predictedCost': 4.10,
                'currency': 'USD',
                'confidenceScore': 0.91,
                'methodology': 'HISTORICAL_HOURLY_PROFILE',
                'dataCoverage': 'FULL',
                'isEstimate': true,
                'generatedAt': '2026-07-15T23:59:59Z',
                'points': [
                  {
                    'timestamp': '2026-07-16T00:00:00Z',
                    'predictedPowerW': 500.0,
                    'predictedEnergyWh': 500.0,
                    'predictedCost': 0.05,
                    'confidenceScore': 0.90
                  }
                ]
              }
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        } else if (path.contains('/anomalies')) {
          return http.Response(
            jsonEncode({
              'success': true,
              'data': [
                {
                  'id': 'anom_01',
                  'homeId': 'home_01',
                  'scopeType': 'device',
                  'scopeId': 'dev_ac_01',
                  'anomalyType': 'UNUSUAL_POWER_SPIKE',
                  'severity': 'HIGH',
                  'observedValue': 3500.0,
                  'baselineValue': 1200.0,
                  'deviationPercentage': 191.7,
                  'isConfirmed': true,
                  'confirmationCount': 2,
                  'detectedAt': '2026-07-15T15:00:00Z'
                }
              ]
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        } else if (path.contains('/efficiency-score')) {
          return http.Response(
            jsonEncode({
              'success': true,
              'data': {
                'homeId': 'home_01',
                'score': 88.0,
                'grade': 'A',
                'factors': {
                  'standbyLossScore': 92.0,
                  'peakDemandScore': 85.0,
                  'thresholdViolationScore': 90.0,
                  'tariffEfficiencyScore': 85.0,
                  'trendScore': 88.0
                },
                'calculatedAt': '2026-07-15T12:00:00Z'
              }
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        } else if (path.contains('/predictive-optimization')) {
          return http.Response(
            jsonEncode({
              'success': true,
              'data': [
                {
                  'id': 'rec_01',
                  'homeId': 'home_01',
                  'category': 'PEAK_AVOIDANCE',
                  'priority': 'HIGH',
                  'title': 'Shift AC Load Away From Peak Window',
                  'description': 'Predicted high AC draw during peak rate period (\$0.35/kWh).',
                  'reason': 'High forecasted tariff price',
                  'estimatedKwhSavings': 4.0,
                  'estimatedCostSavings': 1.20,
                  'currency': 'USD',
                  'confidence': 0.88,
                  'isEstimate': true,
                  'generatedAt': '2026-07-15T12:00:00Z'
                }
              ]
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }

        return http.Response('{"success": true, "data": {}}', 200);
      });

      service = EnergyPredictiveService(client: mockClient, authToken: 'valid_token');
    });

    test('fetchForecast fetches and sets currentForecast', () async {
      final result = await service.fetchForecast('home_01');
      expect(result, isNotNull);
      expect(result!.predictedKwh, equals(18.5));
      expect(service.currentForecast?.predictedCost, equals(4.10));
    });

    test('fetchAnomalies fetches anomaly list', () async {
      final list = await service.fetchAnomalies('home_01');
      expect(list.length, equals(1));
      expect(list.first.severity, equals(AnomalySeverity.high));
    });

    test('fetchEfficiencyScore fetches score and grade', () async {
      final score = await service.fetchEfficiencyScore('home_01');
      expect(score, isNotNull);
      expect(score!.score, equals(88.0));
      expect(score.grade, equals('A'));
    });

    test('fetchPredictiveOptimizations fetches recommendations', () async {
      final recs = await service.fetchPredictiveOptimizations('home_01');
      expect(recs.length, equals(1));
      expect(recs.first.isEstimate, isTrue);
      expect(recs.first.estimatedCostSavings, equals(1.20));
    });

    test('fetchForecastAccuracy fetches accuracy metrics', () async {
      final acc = await service.fetchForecastAccuracy('home_01');
      expect(acc, isNotNull);
      expect(acc!.sampleCount, equals(12));
      expect(acc.mae, equals(0.85));
    });
  });

  group('Phase 22 Widget Presentation Tests', () {
    late EnergyPredictiveService service;

    setUp(() {
      final mockClient = MockClient((request) async {
        final path = request.url.path;

        if (path.contains('/forecast')) {
          return http.Response(
            jsonEncode({
              'success': true,
              'data': {
                'id': 'fc_01',
                'homeId': 'home_01',
                'scopeType': 'home',
                'scopeId': 'home_01',
                'horizon': 'next_24_hours',
                'startTime': '2026-07-16T00:00:00Z',
                'endTime': '2026-07-17T00:00:00Z',
                'predictedKwh': 14.50,
                'predictedCost': 3.25,
                'currency': 'USD',
                'confidenceScore': 0.88,
                'methodology': 'HISTORICAL_HOURLY_PROFILE',
                'dataCoverage': 'FULL',
                'isEstimate': true,
                'generatedAt': '2026-07-15T23:59:59Z',
                'points': []
              }
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        } else if (path.contains('/anomalies')) {
          return http.Response(
            jsonEncode({
              'success': true,
              'data': [
                {
                  'id': 'anom_01',
                  'homeId': 'home_01',
                  'scopeType': 'device',
                  'scopeId': 'dev_ac_01',
                  'anomalyType': 'UNUSUAL_POWER_SPIKE',
                  'severity': 'HIGH',
                  'observedValue': 3500.0,
                  'baselineValue': 1200.0,
                  'deviationPercentage': 191.7,
                  'isConfirmed': true,
                  'confirmationCount': 2,
                  'detectedAt': '2026-07-15T15:00:00Z'
                }
              ]
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        } else if (path.contains('/efficiency-score')) {
          return http.Response(
            jsonEncode({
              'success': true,
              'data': {
                'homeId': 'home_01',
                'score': 85.0,
                'grade': 'A',
                'factors': {
                  'standbyLossScore': 90.0,
                  'peakDemandScore': 80.0,
                  'thresholdViolationScore': 95.0,
                  'tariffEfficiencyScore': 80.0,
                  'trendScore': 80.0
                },
                'calculatedAt': '2026-07-15T12:00:00Z'
              }
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        } else if (path.contains('/predictive-optimization')) {
          return http.Response(
            jsonEncode({
              'success': true,
              'data': [
                {
                  'id': 'rec_01',
                  'homeId': 'home_01',
                  'category': 'PEAK_AVOIDANCE',
                  'priority': 'HIGH',
                  'title': 'Pre-cool Room Before 4 PM',
                  'description': 'Avoid high tariff rates during peak window.',
                  'reason': 'High rate avoidance',
                  'estimatedKwhSavings': 4.0,
                  'estimatedCostSavings': 1.25,
                  'currency': 'USD',
                  'confidence': 0.85,
                  'isEstimate': true,
                  'generatedAt': '2026-07-15T12:00:00Z'
                }
              ]
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        } else if (path.contains('/baseline')) {
          return http.Response(
            jsonEncode({
              'success': true,
              'data': {
                'homeId': 'home_01',
                'scopeType': 'home',
                'scopeId': 'home_01',
                'typicalPowerW': 650.0,
                'typicalDailyEnergyKwh': 12.5,
                'typicalOvernightWh': 80.0,
                'typicalOperatingHours': [14, 15, 16],
                'sampleCount': 48,
                'confidence': 0.90,
                'calculatedAt': '2026-07-15T12:00:00Z'
              }
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }

        return http.Response('{"success": true}', 200);
      });

      service = EnergyPredictiveService(client: mockClient, authToken: 'valid_token');
    });

    testWidgets('EnergyForecastPage renders predicted metrics and estimate tag', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: EnergyForecastPage(homeId: 'home_01', service: service),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Energy Forecast & Predictions'), findsOneWidget);
      expect(find.text('Predicted Consumption'), findsOneWidget);
      expect(find.text('ESTIMATE'), findsOneWidget);
      expect(find.text('14.50 kWh'), findsOneWidget);
      expect(find.text('USD 3.25'), findsOneWidget);
    });

    testWidgets('EnergyAnomaliesPage renders detected anomaly with severity', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: EnergyAnomaliesPage(homeId: 'home_01', service: service),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Energy Anomalies'), findsOneWidget);
      expect(find.text('HIGH'), findsOneWidget);
      expect(find.text('UNUSUAL POWER SPIKE'), findsOneWidget);
      expect(find.text('Confirmed'), findsOneWidget);
    });

    testWidgets('EnergyEfficiencyPage renders overall score and factors', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: EnergyEfficiencyPage(homeId: 'home_01', service: service),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Energy Efficiency Score'), findsOneWidget);
      expect(find.text('Grade A'), findsOneWidget);
      expect(find.text('Standby Loss Score'), findsOneWidget);
      expect(find.text('Peak Demand Score'), findsOneWidget);
    });

    testWidgets('PredictiveOptimizationPage renders recommendation cards', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: PredictiveOptimizationPage(homeId: 'home_01', service: service),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Predictive Optimization'), findsOneWidget);
      expect(find.text('Pre-cool Room Before 4 PM'), findsOneWidget);
      expect(find.text('HIGH PRIORITY'), findsOneWidget);
    });

    testWidgets('EnergyBaselineDetailsPage renders metrics and active hours', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: EnergyBaselineDetailsPage(homeId: 'home_01', service: service),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Home Baseline'), findsOneWidget);
      expect(find.text('650.0 W'), findsOneWidget);
      expect(find.text('12.50 kWh'), findsOneWidget);
      expect(find.text('14:00'), findsOneWidget);
    });
  });
}
