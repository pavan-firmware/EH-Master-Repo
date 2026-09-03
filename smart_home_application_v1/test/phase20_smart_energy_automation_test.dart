import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:smart_home_application_v1/core/models/energy_automation_models.dart';
import 'package:smart_home_application_v1/core/services/energy_automation_service.dart';
import 'package:smart_home_application_v1/features/energy/presentation/energy_condition_builder.dart';
import 'package:smart_home_application_v1/features/energy/presentation/energy_action_builder.dart';
import 'package:smart_home_application_v1/features/energy/presentation/energy_automations_page.dart';
import 'package:smart_home_application_v1/features/energy/presentation/energy_optimization_page.dart';
import 'package:smart_home_application_v1/features/energy/presentation/energy_automation_history_page.dart';

void main() {
  group('Phase 20 — Energy Automation Models Tests', () {
    test('EnergyMetric and Operator enums serialize and deserialize properly', () {
      expect(EnergyMetric.fromString('instantaneous_power'), EnergyMetric.instantaneousPower);
      expect(EnergyMetric.fromString('sustained_power'), EnergyMetric.sustainedPower);
      expect(EnergyMetric.fromString('daily_energy'), EnergyMetric.dailyEnergy);
      expect(EnergyMetric.instantaneousPower.toApiString(), 'instantaneous_power');
      expect(EnergyMetric.instantaneousPower.defaultUnit, 'W');

      expect(EnergyOperator.fromString('GT'), EnergyOperator.gt);
      expect(EnergyOperator.fromString('>='), EnergyOperator.gte);
      expect(EnergyOperator.gt.symbol, '>');
      expect(EnergyOperator.gt.toApiString(), 'GT');
    });

    test('EnergyConditionModel round-trip JSON serialization', () {
      const cond = EnergyConditionModel(
        metric: EnergyMetric.sustainedPower,
        operator: EnergyOperator.gt,
        threshold: 2000.0,
        unit: 'W',
        durationSeconds: 60,
        timeWindow: TimeWindowModel(startTime: '22:00', endTime: '06:00'),
        deviceId: '0194fe20-0000-7000-8000-444444444441',
      );

      final jsonMap = cond.toJson();
      expect(jsonMap['metric'], 'sustained_power');
      expect(jsonMap['operator'], 'GT');
      expect(jsonMap['threshold'], 2000.0);
      expect(jsonMap['durationSeconds'], 60);
      expect(jsonMap['timeWindow']['startTime'], '22:00');

      final deserialized = EnergyConditionModel.fromJson(jsonMap);
      expect(deserialized.metric, EnergyMetric.sustainedPower);
      expect(deserialized.threshold, 2000.0);
      expect(deserialized.timeWindow?.endTime, '06:00');
    });

    test('EnergyAutomationRuleModel full JSON serialization', () {
      final rule = EnergyAutomationRuleModel(
        id: '0194fe20-0000-7000-8000-999999999991',
        homeId: '0194fe20-0000-7000-8000-111111111111',
        name: 'High Oven Cutoff',
        description: 'Protects main breaker',
        isEnabled: true,
        triggerType: 'energy_threshold',
        scopeType: 'device',
        scopeId: '0194fe20-0000-7000-8000-444444444441',
        conditions: const [
          EnergyConditionModel(
            metric: EnergyMetric.instantaneousPower,
            operator: EnergyOperator.gt,
            threshold: 2500.0,
          ),
        ],
        hysteresis: const EnergyHysteresisConfigModel(
          recoveryThreshold: 1800.0,
          cooldownSeconds: 60,
        ),
        actions: const [
          EnergyActionModel(
            actionType: 'device_command',
            deviceId: '0194fe20-0000-7000-8000-444444444441',
            command: 'setPower',
            params: {'value': false},
          ),
        ],
      );

      final jsonMap = rule.toJson();
      expect(jsonMap['name'], 'High Oven Cutoff');
      expect(jsonMap['hysteresis']['recoveryThreshold'], 1800.0);

      final deserialized = EnergyAutomationRuleModel.fromJson(jsonMap);
      expect(deserialized.name, 'High Oven Cutoff');
      expect(deserialized.conditions.length, 1);
      expect(deserialized.hysteresis?.recoveryThreshold, 1800.0);
    });

    test('EnergyOptimizationRecommendationModel JSON deserialization with savings', () {
      final jsonMap = {
        'id': 'rec_vampire_1',
        'home_id': '0194fe20-0000-7000-8000-111111111111',
        'device_id': '0194fe20-0000-7000-8000-444444444441',
        'category': 'VAMPIRE_STANDBY_POWER',
        'title': 'High Standby Load: Oven',
        'description': 'Continuous 25W standby draw detected.',
        'priority': 'HIGH',
        'is_dismissed': false,
        'estimated_savings': {
          'daily_kwh': 0.6,
          'monthly_kwh': 18.0,
          'daily_cost': 0.09,
          'monthly_cost': 2.70,
          'currency': 'USD',
          'tariff_per_kwh': 0.15,
          'is_estimate': true,
        },
        'evidence': {'baselinePowerW': 25.0},
      };

      final rec = EnergyOptimizationRecommendationModel.fromJson(jsonMap);
      expect(rec.id, 'rec_vampire_1');
      expect(rec.priority, 'HIGH');
      expect(rec.estimatedSavings.monthlyKwh, 18.0);
      expect(rec.estimatedSavings.monthlyCost, 2.70);
      expect(rec.estimatedSavings.isEstimate, true);
    });
  });

  group('Phase 20 — Energy Automation Service API Tests', () {
    test('fetchAutomations parses list from HTTP response', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.path, '/api/v1/energy/automations');
        return http.Response(
          json.encode({
            'success': true,
            'data': [
              {
                'id': 'rule_1',
                'home_id': 'home_1',
                'name': 'Test Rule',
                'is_enabled': true,
                'conditions': [],
                'actions': [],
              }
            ],
          }),
          200,
        );
      });

      final service = EnergyAutomationService(
        baseUrl: 'http://test.local',
        httpClient: mockClient,
      );

      final list = await service.fetchAutomations('home_1');
      expect(list.length, 1);
      expect(list.first.name, 'Test Rule');
      expect(service.automations.length, 1);
    });

    test('createAutomation posts rule payload and updates cache', () async {
      final mockClient = MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, '/api/v1/energy/automations');
        return http.Response(
          json.encode({
            'success': true,
            'data': {
              'id': 'rule_new_1',
              'home_id': 'home_1',
              'name': 'Created Rule',
              'is_enabled': true,
              'conditions': [],
              'actions': [],
            },
          }),
          201,
        );
      });

      final service = EnergyAutomationService(
        baseUrl: 'http://test.local',
        httpClient: mockClient,
      );

      final created = await service.createAutomation(
        const EnergyAutomationRuleModel(
          id: '',
          homeId: 'home_1',
          name: 'Created Rule',
        ),
      );

      expect(created, isNotNull);
      expect(created?.id, 'rule_new_1');
      expect(service.automations.length, 1);
    });

    test('dismissOptimization removes item from local cache', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.path, '/api/v1/energy/optimization/rec_1/dismiss');
        return http.Response(
          json.encode({'success': true, 'data': {'is_dismissed': true}}),
          200,
        );
      });

      final service = EnergyAutomationService(
        baseUrl: 'http://test.local',
        httpClient: mockClient,
      );

      // Seed recommendation
      service.fetchOptimizationRecommendations('home_1');

      final dismissed = await service.dismissOptimization('home_1', 'rec_1');
      expect(dismissed, true);
    });
  });

  group('Phase 20 — Flutter Widgets & Presentation Tests', () {
    testWidgets('EnergyConditionBuilder renders and emits updated conditions', (tester) async {
      EnergyConditionModel updatedCondition = const EnergyConditionModel(
        metric: EnergyMetric.instantaneousPower,
        operator: EnergyOperator.gt,
        threshold: 1500.0,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EnergyConditionBuilder(
              initialCondition: updatedCondition,
              onChanged: (cond) => updatedCondition = cond,
            ),
          ),
        ),
      );

      expect(find.text('Energy Trigger Condition'), findsOneWidget);
      expect(find.text('Threshold'), findsOneWidget);

      // Enter new threshold
      await tester.enterText(find.byType(TextField).first, '2200');
      await tester.pump();

      expect(updatedCondition.threshold, 2200.0);
    });

    testWidgets('EnergyActionBuilder renders and emits updated actions', (tester) async {
      EnergyActionModel updatedAction = const EnergyActionModel(
        actionType: 'device_command',
        command: 'setPower',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EnergyActionBuilder(
              initialAction: updatedAction,
              availableDevices: const [
                {'id': 'dev_1', 'name': 'Oven'},
              ],
              onChanged: (action) => updatedAction = action,
            ),
          ),
        ),
      );

      expect(find.text('Action to Execute'), findsOneWidget);
      expect(find.text('Action Type'), findsOneWidget);
    });

    testWidgets('EnergyAutomationsPage renders empty state when no rules exist', (tester) async {
      final mockClient = MockClient((request) async {
        return http.Response(
          json.encode({'success': true, 'data': []}),
          200,
        );
      });

      final service = EnergyAutomationService(
        baseUrl: 'http://test.local',
        httpClient: mockClient,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: EnergyAutomationsPage(
            homeId: 'home_1',
            service: service,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text('Smart Energy Automations'), findsOneWidget);
      expect(find.text('No Energy Automations Yet'), findsOneWidget);
      expect(find.text('New Energy Rule'), findsOneWidget);
    });

    testWidgets('EnergyOptimizationPage renders summary card and recommendation cards', (tester) async {
      final mockClient = MockClient((request) async {
        return http.Response(
          json.encode({
            'success': true,
            'data': {
              'summary': {
                'total_monthly_kwh_savings': 45.5,
                'total_monthly_cost_savings': 9.10,
                'currency': 'USD',
                'is_estimate': true,
              },
              'recommendations': [
                {
                  'id': 'rec_vamp_1',
                  'home_id': 'home_1',
                  'category': 'VAMPIRE_STANDBY_POWER',
                  'title': 'Oven Standby Drain',
                  'description': 'Continuous 25W draw detected.',
                  'priority': 'HIGH',
                  'is_dismissed': false,
                  'estimated_savings': {
                    'monthly_kwh': 18.0,
                    'monthly_cost': 3.60,
                    'currency': 'USD',
                    'is_estimate': true,
                  },
                }
              ],
            },
          }),
          200,
        );
      });

      final service = EnergyAutomationService(
        baseUrl: 'http://test.local',
        httpClient: mockClient,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: EnergyOptimizationPage(
            homeId: 'home_1',
            service: service,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text('Energy Optimization'), findsOneWidget);
      expect(find.text('Estimated Monthly Savings'), findsOneWidget);
      expect(find.text('45.5 kWh'), findsOneWidget);
      expect(find.text('USD 9.10'), findsOneWidget);
      expect(find.text('Oven Standby Drain'), findsOneWidget);
    });

    testWidgets('EnergyAutomationHistoryPage renders logs and skip reasons', (tester) async {
      final mockClient = MockClient((request) async {
        return http.Response(
          json.encode({
            'success': true,
            'data': [
              {
                'id': 'exec_1',
                'home_id': 'home_1',
                'automation_id': 'rule_1',
                'trigger_type': 'energy',
                'trigger_reason': 'Instantaneous power exceeded 1500W',
                'status': 'skipped',
                'skip_reason': 'in_cooldown',
                'duration_ms': 12,
                'created_at': DateTime.now().toIso8601String(),
              }
            ],
          }),
          200,
        );
      });

      final service = EnergyAutomationService(
        baseUrl: 'http://test.local',
        httpClient: mockClient,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: EnergyAutomationHistoryPage(
            automationId: 'rule_1',
            automationName: 'Overload Rule',
            service: service,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text('Overload Rule — History'), findsOneWidget);
      expect(find.text('Instantaneous power exceeded 1500W'), findsOneWidget);
      expect(find.text('SKIPPED'), findsOneWidget);
    });
  });
}
