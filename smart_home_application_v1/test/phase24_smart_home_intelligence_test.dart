import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:smart_home_application_v1/core/models/intelligence_models.dart';
import 'package:smart_home_application_v1/core/services/intelligence_service.dart';
import 'package:smart_home_application_v1/features/intelligence/presentation/intelligence_center_page.dart';
import 'package:smart_home_application_v1/features/intelligence/presentation/intelligence_recommendations_page.dart';
import 'package:smart_home_application_v1/features/intelligence/presentation/intelligence_decision_details_page.dart';
import 'package:smart_home_application_v1/features/intelligence/presentation/intelligence_history_page.dart';

void main() {
  group('Phase 24: Smart Home Intelligence Models', () {
    test('HomeIntelligenceSnapshot JSON serialization and defaults', () {
      final jsonMap = {
        'homeId': 'home_01',
        'timestamp': '2026-07-16T12:00:00Z',
        'homeContext': 'AWAY',
        'presenceState': 'AWAY',
        'isOccupied': false,
        'contextConfidence': 0.95,
        'deviceCount': 8,
        'activeDevicesCount': 2,
        'totalPowerW': 450.5,
        'tariffPeriod': 'PEAK',
        'tariffPrice': 0.45,
        'forecastPredictedKwh': 14.2,
        'activeAnomalyCount': 1,
        'activeAutomationCount': 5,
        'activeScheduleCount': 2,
        'devicesSummary': [
          {'id': 'dev_1', 'name': 'Living Light', 'isOn': true, 'powerW': 50.5}
        ]
      };

      final snapshot = HomeIntelligenceSnapshot.fromJson(jsonMap);
      expect(snapshot.homeId, 'home_01');
      expect(snapshot.isOccupied, false);
      expect(snapshot.totalPowerW, 450.5);
      expect(snapshot.tariffPeriod, 'PEAK');
      expect(snapshot.devicesSummary.length, 1);
    });

    test('DecisionPriority ranks and conversions', () {
      expect(DecisionPriority.safety.rank, 1);
      expect(DecisionPriority.manualUserAction.rank, 2);
      expect(DecisionPriority.explicitHomeMode.rank, 3);
      expect(DecisionPriority.scheduledAutomation.rank, 4);
      expect(DecisionPriority.energyCostOptimization.rank, 5);
      expect(DecisionPriority.predictiveOptimization.rank, 6);
      expect(DecisionPriority.convenienceRecommendation.rank, 7);

      expect(DecisionPriority.fromApiValue('SAFETY'), DecisionPriority.safety);
      expect(DecisionPriority.fromApiValue('ENERGY_COST_OPTIMIZATION'), DecisionPriority.energyCostOptimization);
    });

    test('IntelligenceDecision JSON parsing with safetyResult', () {
      final jsonMap = {
        'id': 'dec_01',
        'home_id': 'home_01',
        'decision_type': 'TURN_OFF_IDLE_DEVICE',
        'priority': 'CONVENIENCE_RECOMMENDATION',
        'priority_rank': 7,
        'confidence': 'HIGH',
        'confidence_score': 0.90,
        'risk': 'LOW',
        'evidence': {'powerW': 60, 'presence': 'AWAY'},
        'proposed_action': {'actionType': 'device_command', 'deviceId': 'dev_1'},
        'expected_effect': 'Turn off idle lamp',
        'is_auto_executable': true,
        'safety_result': {'isSafe': true, 'riskLevel': 'LOW', 'reason': 'Safe non-critical device'},
        'status': 'GENERATED',
        'created_at': '2026-07-16T12:00:00Z',
      };

      final dec = IntelligenceDecision.fromJson(jsonMap);
      expect(dec.id, 'dec_01');
      expect(dec.priority, DecisionPriority.convenienceRecommendation);
      expect(dec.risk, RiskLevel.low);
      expect(dec.isAutoExecutable, true);
      expect(dec.safetyResult['isSafe'], true);
    });

    test('IntelligenceRecommendation JSON parsing and expected benefit', () {
      final jsonMap = {
        'id': 'rec_01',
        'home_id': 'home_01',
        'recommendation_type': 'SHIFT_LOAD_TO_CHEAPER_PERIOD',
        'priority': 'ENERGY_COST_OPTIMIZATION',
        'priority_rank': 5,
        'confidence': 'HIGH',
        'risk': 'MEDIUM',
        'title': 'Shift Heavy Load Outside Peak Tariff',
        'description': 'Tariff is in peak period',
        'expected_benefit': 'Save ~\$0.45/hr',
        'status': 'GENERATED',
        'created_at': '2026-07-16T12:00:00Z',
      };

      final rec = IntelligenceRecommendation.fromJson(jsonMap);
      expect(rec.id, 'rec_01');
      expect(rec.recommendationType, RecommendationType.shiftLoadToCheaperPeriod);
      expect(rec.expectedBenefit, 'Save ~\$0.45/hr');
    });

    test('DecisionOutcome JSON parsing', () {
      final jsonMap = {
        'id': 'out_01',
        'decision_id': 'dec_01',
        'home_id': 'home_01',
        'status': 'AUTO_EXECUTED',
        'executed_at': '2026-07-16T12:01:00Z',
        'expected_benefit': 'Save 60W',
        'actual_benefit': 'Power dropped by 59.8W',
        'feedback': 'Autonomous rule execution',
      };

      final outcome = DecisionOutcome.fromJson(jsonMap);
      expect(outcome.id, 'out_01');
      expect(outcome.status, DecisionStatus.autoExecuted);
      expect(outcome.actualBenefit, 'Power dropped by 59.8W');
    });
  });

  group('Phase 24: HomeIntelligenceService HTTP Client', () {
    test('fetchSummary parses full snapshot, recommendations, and decisions', () async {
      final mockClient = MockClient((request) async {
        if (request.url.path.contains('/summary')) {
          final body = {
            'success': true,
            'data': {
              'snapshot': {
                'homeId': 'home_01',
                'timestamp': '2026-07-16T12:00:00Z',
                'homeContext': 'AWAY',
                'presenceState': 'AWAY',
                'isOccupied': false,
                'totalPowerW': 1200.0,
                'tariffPeriod': 'PEAK',
                'tariffPrice': 0.45,
                'activeAnomalyCount': 1,
                'devicesSummary': []
              },
              'activeRecommendationsCount': 1,
              'recommendations': [
                {
                  'id': 'rec_01',
                  'home_id': 'home_01',
                  'recommendation_type': 'TURN_OFF_UNUSED_DEVICE',
                  'priority': 'CONVENIENCE_RECOMMENDATION',
                  'confidence': 'HIGH',
                  'risk': 'LOW',
                  'title': 'Turn Off Light',
                  'description': 'Light left on in empty home',
                  'expected_benefit': 'Saves 0.1 kWh',
                  'status': 'GENERATED',
                  'created_at': '2026-07-16T12:00:00Z'
                }
              ],
              'recentDecisions': [],
              'recentOutcomes': []
            }
          };
          return http.Response(json.encode(body), 200);
        }
        return http.Response('Not found', 404);
      });

      final service = HomeIntelligenceService(client: mockClient);
      final summary = await service.fetchSummary('home_01');

      expect(summary, isNotNull);
      expect(summary!.snapshot.totalPowerW, 1200.0);
      expect(summary.recommendations.length, 1);
      expect(summary.recommendations[0].title, 'Turn Off Light');
    });

    test('acceptRecommendation and rejectRecommendation execute successfully', () async {
      final mockClient = MockClient((request) async {
        if (request.url.path.contains('/accept') || request.url.path.contains('/reject')) {
          return http.Response(json.encode({'success': true, 'data': {'status': 'OK'}}), 200);
        }
        if (request.url.path.contains('/summary')) {
          return http.Response(json.encode({'success': true, 'data': {'snapshot': {'homeId': 'home_01', 'timestamp': '2026-07-16T12:00:00Z', 'homeContext': 'HOME', 'presenceState': 'HOME', 'totalPowerW': 0.0}, 'recommendations': [], 'recentDecisions': [], 'recentOutcomes': []}}), 200);
        }
        return http.Response('Not found', 404);
      });

      final service = HomeIntelligenceService(client: mockClient);
      final accepted = await service.acceptRecommendation('home_01', 'rec_01');
      expect(accepted, true);

      final rejected = await service.rejectRecommendation('home_01', 'rec_01', reason: 'Not now');
      expect(rejected, true);
    });
  });

  group('Phase 24: Flutter UI Presentation Widgets', () {
    testWidgets('IntelligenceCenterPage renders snapshot and actions', (tester) async {
      final mockClient = MockClient((request) async {
        final body = {
          'success': true,
          'data': {
            'snapshot': {
              'homeId': 'home_01',
              'timestamp': '2026-07-16T12:00:00Z',
              'homeContext': 'AWAY',
              'presenceState': 'AWAY',
              'isOccupied': false,
              'deviceCount': 4,
              'activeDevicesCount': 2,
              'totalPowerW': 850.0,
              'tariffPeriod': 'PEAK',
              'tariffPrice': 0.40,
              'activeAnomalyCount': 1,
              'devicesSummary': []
            },
            'activeRecommendationsCount': 1,
            'recommendations': [
              {
                'id': 'rec_01',
                'home_id': 'home_01',
                'recommendation_type': 'TURN_OFF_UNUSED_DEVICE',
                'priority': 'CONVENIENCE_RECOMMENDATION',
                'confidence': 'HIGH',
                'risk': 'LOW',
                'title': 'Turn Off Basement Light',
                'description': 'Light has been on for 4 hours',
                'expected_benefit': 'Save 0.2 kWh',
                'status': 'GENERATED',
                'created_at': '2026-07-16T12:00:00Z'
              }
            ],
            'recentDecisions': [],
            'recentOutcomes': []
          }
        };
        return http.Response(json.encode(body), 200);
      });

      final service = HomeIntelligenceService(client: mockClient);

      await tester.pumpWidget(
        MaterialApp(
          home: IntelligenceCenterPage(
            homeId: 'home_01',
            service: service,
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Home Intelligence Center'), findsOneWidget);
      expect(find.text('Mode: AWAY'), findsOneWidget);
      expect(find.text('850 W'), findsOneWidget);
      expect(find.text('Evaluate Rules'), findsOneWidget);
      expect(find.text('Auto-Execute Safe'), findsOneWidget);
      expect(find.text('Turn Off Basement Light'), findsOneWidget);
    });

    testWidgets('IntelligenceRecommendationsPage renders list and filters', (tester) async {
      final mockClient = MockClient((request) async {
        final body = {
          'success': true,
          'data': [
            {
              'id': 'rec_01',
              'home_id': 'home_01',
              'recommendation_type': 'SHIFT_LOAD_TO_CHEAPER_PERIOD',
              'priority': 'ENERGY_COST_OPTIMIZATION',
              'confidence': 'HIGH',
              'risk': 'MEDIUM',
              'title': 'Shift EV Charging',
              'description': 'Shift charging to OFF_PEAK rate period',
              'expected_benefit': 'Save \$2.40/day',
              'evidence': {'currentRate': 'PEAK', 'evPower': 3600},
              'status': 'GENERATED',
              'created_at': '2026-07-16T12:00:00Z'
            }
          ]
        };
        return http.Response(json.encode(body), 200);
      });

      final service = HomeIntelligenceService(client: mockClient);

      await tester.pumpWidget(
        MaterialApp(
          home: IntelligenceRecommendationsPage(
            homeId: 'home_01',
            service: service,
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Recommendations'), findsOneWidget);
      expect(find.text('Shift EV Charging'), findsOneWidget);
      expect(find.text('Accept & Execute'), findsOneWidget);
      expect(find.text('Reasoning & Evidence'), findsOneWidget);
    });

    testWidgets('IntelligenceDecisionDetailsPage renders safety check and evidence', (tester) async {
      final mockClient = MockClient((request) async {
        return http.Response(json.encode({'success': true, 'data': []}), 200);
      });

      final service = HomeIntelligenceService(client: mockClient);
      final dec = IntelligenceDecision(
        id: 'dec_test_01',
        homeId: 'home_01',
        decisionType: 'AUTO_SET_AWAY_MODE',
        priority: DecisionPriority.explicitHomeMode,
        priorityRank: 3,
        confidence: ConfidenceLevel.high,
        confidenceScore: 0.95,
        risk: RiskLevel.low,
        expectedEffect: 'Synchronize home context to AWAY mode',
        safetyResult: const {'isSafe': true, 'riskLevel': 'LOW', 'reason': 'All users confirmed away'},
        evidence: const {'usersDeparted': 2, 'presenceState': 'AWAY'},
        status: DecisionStatus.generated,
        createdAt: DateTime.now(),
      );

      await service.fetchDecisions('home_01');
      // Inject decision directly into service state for testing details
      service.decisions.add(dec);

      await tester.pumpWidget(
        MaterialApp(
          home: IntelligenceDecisionDetailsPage(
            homeId: 'home_01',
            decisionId: 'dec_test_01',
            service: service,
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Decision Details'), findsWidgets);
      expect(find.text('AUTO_SET_AWAY_MODE'), findsOneWidget);
      expect(find.text('Safety Pre-Check'), findsOneWidget);
      expect(find.text('All users confirmed away'), findsOneWidget);

      await tester.ensureVisible(find.text('Execute Decision Now'));
      await tester.pumpAndSettle();
      expect(find.text('Execute Decision Now'), findsOneWidget);
    });

    testWidgets('IntelligenceHistoryPage renders outcomes history list', (tester) async {
      final mockClient = MockClient((request) async {
        final body = {
          'success': true,
          'data': [
            {
              'id': 'out_test_01',
              'decision_id': 'dec_01',
              'home_id': 'home_01',
              'status': 'AUTO_EXECUTED',
              'executed_at': '2026-07-16T12:01:00Z',
              'expected_benefit': 'Save 50W',
              'actual_benefit': 'Saved 49.5W',
              'feedback': 'Autonomous action',
            }
          ]
        };
        return http.Response(json.encode(body), 200);
      });

      final service = HomeIntelligenceService(client: mockClient);

      await tester.pumpWidget(
        MaterialApp(
          home: IntelligenceHistoryPage(
            homeId: 'home_01',
            service: service,
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Intelligence Outcomes History'), findsOneWidget);
      expect(find.text('AUTO_EXECUTED'), findsOneWidget);
      expect(find.text('Expected Effect: Save 50W'), findsOneWidget);
      expect(find.text('Actual Outcome: Saved 49.5W'), findsOneWidget);
    });
  });
}
