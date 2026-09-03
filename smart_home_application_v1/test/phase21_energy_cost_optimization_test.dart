import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:smart_home_application_v1/core/models/energy_cost_models.dart';
import 'package:smart_home_application_v1/core/services/energy_cost_service.dart';
import 'package:smart_home_application_v1/features/energy/presentation/energy_cost_dashboard_page.dart';
import 'package:smart_home_application_v1/features/energy/presentation/tariff_management_page.dart';
import 'package:smart_home_application_v1/features/energy/presentation/tariff_editor_page.dart';
import 'package:smart_home_application_v1/features/energy/presentation/energy_budget_page.dart';
import 'package:smart_home_application_v1/features/energy/presentation/cost_optimization_page.dart';

void main() {
  group('Phase 21: Energy Cost Models', () {
    test('TariffModel JSON Serialization and Deserialization', () {
      final period = TariffPeriodModel(
        id: 'p_1',
        periodType: TariffPeriodType.offPeak,
        startTime: '22:00',
        endTime: '06:00',
        applicableWeekdays: [1, 2, 3, 4, 5, 6, 7],
        pricePerKwh: 0.08,
      );

      final tariff = ElectricityTariffModel(
        id: 'tariff_01',
        homeId: 'home_01',
        name: 'Summer TOU Plan',
        tariffType: TariffType.timeOfUse,
        currency: 'USD',
        fixedDailyCharge: 0.50,
        effectiveFrom: DateTime.parse('2026-06-01T00:00:00Z'),
        carbonIntensityGPerKwh: 410.0,
        isActive: true,
        periods: [period],
      );

      final jsonMap = tariff.toJson();
      expect(jsonMap['name'], 'Summer TOU Plan');
      expect(jsonMap['tariffType'], 'TIME_OF_USE');
      expect(jsonMap['currency'], 'USD');
      expect((jsonMap['periods'] as List).length, 1);

      final reconstructed = ElectricityTariffModel.fromJson(jsonMap);
      expect(reconstructed.name, 'Summer TOU Plan');
      expect(reconstructed.tariffType, TariffType.timeOfUse);
      expect(reconstructed.periods.first.periodType, TariffPeriodType.offPeak);
      expect(reconstructed.periods.first.pricePerKwh, 0.08);
    });

    test('EnergyBudgetModel & Status Serialization', () {
      final budget = EnergyBudgetModel(
        id: 'b_01',
        homeId: 'home_01',
        periodType: BudgetPeriodType.monthly,
        budgetAmount: 120.0,
        currency: 'USD',
        alertThresholdPercent: 85.0,
        isEnabled: true,
      );

      final jsonMap = budget.toJson();
      expect(jsonMap['periodType'], 'monthly');
      expect(jsonMap['budgetAmount'], 120.0);

      final statusJson = {
        'configured': true,
        'homeId': 'home_01',
        'periodType': 'monthly',
        'budgetAmount': 120.0,
        'currency': 'USD',
        'actualCostToDate': 45.50,
        'budgetRemaining': 74.50,
        'percentConsumed': 37.9,
        'projectedTotalCost': 135.00,
        'percentProjected': 112.5,
        'projectedOverrun': 15.00,
        'isProjectedToExceed': true,
      };

      final status = BudgetStatusModel.fromJson(statusJson);
      expect(status.configured, isTrue);
      expect(status.isProjectedToExceed, isTrue);
      expect(status.projectedOverrun, 15.00);
    });

    test('CostSummary & Forecast Model Deserialization', () {
      final summaryJson = {
        'homeId': 'home_01',
        'entityType': 'home',
        'period': 'today',
        'totalCost': 2.58,
        'variableCost': 2.08,
        'fixedCharges': 0.50,
        'currency': 'USD',
        'totalKwh': 11.5,
        'breakdown': {
          'peak': {'cost': 1.28, 'kwh': 4.0},
          'offPeak': {'cost': 0.40, 'kwh': 5.0},
          'standard': {'cost': 0.40, 'kwh': 2.5},
        },
        'effectiveTariff': {'name': 'Summer TOU Plan'},
        'dataQuality': 'GOOD',
      };

      final summary = EnergyCostSummaryModel.fromJson(summaryJson);
      expect(summary.totalCost, 2.58);
      expect(summary.peak.cost, 1.28);
      expect(summary.offPeak.kwh, 5.0);
      expect(summary.effectiveTariffName, 'Summer TOU Plan');

      final forecastJson = {
        'homeId': 'home_01',
        'period': 'monthly',
        'currency': 'USD',
        'actualCostToDate': 45.0,
        'estimatedRemainingCost': 50.0,
        'projectedTotalCost': 95.0,
        'actualKwhToDate': 250.0,
        'projectedTotalKwh': 520.0,
        'daysElapsed': 15,
        'daysRemaining': 16,
        'confidenceScore': 0.85,
        'isEstimate': true,
      };

      final forecast = CostForecastModel.fromJson(forecastJson);
      expect(forecast.projectedTotalCost, 95.0);
      expect(forecast.isEstimate, isTrue);
      expect(forecast.confidenceScore, 0.85);
    });

    test('CheapestPeriod & CarbonFootprint Model Deserialization', () {
      final cheapestJson = {
        'homeId': 'home_01',
        'currency': 'USD',
        'durationHours': 2,
        'cheapestWindow': {
          'startTime': '2026-07-15T22:00:00Z',
          'endTime': '2026-07-16T00:00:00Z',
          'avgPricePerKwh': 0.08,
          'periodType': 'OFF_PEAK',
        },
        'peakWindow': {
          'startTime': '2026-07-15T16:00:00Z',
          'endTime': '2026-07-15T18:00:00Z',
          'avgPricePerKwh': 0.32,
          'periodType': 'PEAK',
        },
        'potentialSavingsPercent': 75.0,
      };

      final cheapest = CheapestPeriodModel.fromJson(cheapestJson);
      expect(cheapest.potentialSavingsPercent, 75.0);
      expect(cheapest.cheapestWindow.avgPricePerKwh, 0.08);

      final carbonJson = {
        'entityId': 'home_01',
        'entityType': 'home',
        'period': 'today',
        'carbonIntensityGPerKwh': 410.0,
        'totalGramsCO2': 4715.0,
        'totalKgCO2': 4.72,
        'source': 'configured_tariff',
        'isEstimate': true,
      };

      final carbon = CarbonFootprintModel.fromJson(carbonJson);
      expect(carbon.totalKgCO2, 4.72);
      expect(carbon.source, 'configured_tariff');
    });
  });

  group('Phase 21: EnergyCostService API integration', () {
    test('fetchTariffs calls endpoint and parses response', () async {
      final mockClient = MockClient((request) async {
        if (request.url.path.contains('/tariffs')) {
          return http.Response(
            json.encode({
              'data': [
                {
                  'id': 'tariff_01',
                  'home_id': 'home_01',
                  'name': 'Standard Flat Rate',
                  'tariff_type': 'FLAT',
                  'currency': 'USD',
                  'flat_rate_per_kwh': 0.15,
                  'is_active': 1,
                  'effective_from': '2026-01-01T00:00:00Z',
                }
              ]
            }),
            200,
          );
        }
        return http.Response('Not Found', 404);
      });

      final service = EnergyCostService(client: mockClient);
      final list = await service.fetchTariffs('home_01');
      expect(list.length, 1);
      expect(list.first.name, 'Standard Flat Rate');
      expect(list.first.tariffType, TariffType.flat);
    });

    test('fetchCostSummary calls cost endpoint', () async {
      final mockClient = MockClient((request) async {
        if (request.url.path.contains('/cost')) {
          return http.Response(
            json.encode({
              'data': {
                'homeId': 'home_01',
                'period': 'today',
                'totalCost': 4.25,
                'variableCost': 3.75,
                'fixedCharges': 0.50,
                'currency': 'USD',
                'totalKwh': 18.0,
                'breakdown': {
                  'peak': {'cost': 2.0, 'kwh': 8.0},
                  'offPeak': {'cost': 1.0, 'kwh': 6.0},
                  'standard': {'cost': 0.75, 'kwh': 4.0},
                },
                'dataQuality': 'GOOD',
              }
            }),
            200,
          );
        }
        return http.Response('Not Found', 404);
      });

      final service = EnergyCostService(client: mockClient);
      final cost = await service.fetchCostSummary('home_01');
      expect(cost, isNotNull);
      expect(cost!.totalCost, 4.25);
      expect(cost.totalKwh, 18.0);
    });
  });

  group('Phase 21: UI Widget Tests', () {
    late MockClient mockClient;
    late EnergyCostService costService;

    setUp(() {
      mockClient = MockClient((request) async {
        final path = request.url.path;
        if (path.contains('/tariffs')) {
          return http.Response(
            json.encode({
              'data': [
                {
                  'id': 'tariff_01',
                  'home_id': 'home_01',
                  'name': 'Summer TOU Plan',
                  'tariff_type': 'TIME_OF_USE',
                  'currency': 'USD',
                  'is_active': 1,
                  'effective_from': '2026-06-01T00:00:00Z',
                  'periods': [
                    {
                      'id': 'p_1',
                      'period_type': 'OFF_PEAK',
                      'start_time': '22:00',
                      'end_time': '06:00',
                      'price_per_kwh': 0.08,
                    },
                    {
                      'id': 'p_2',
                      'period_type': 'PEAK',
                      'start_time': '16:00',
                      'end_time': '21:00',
                      'price_per_kwh': 0.32,
                    }
                  ]
                }
              ]
            }),
            200,
          );
        } else if (path.contains('/optimization/cost')) {
          return http.Response(
            json.encode({
              'data': {
                'recommendations': [
                  {
                    'id': 'opt_01',
                    'home_id': 'home_01',
                    'device_id': 'dev_ac_01',
                    'category': 'LOAD_SHIFTING',
                    'priority': 'HIGH',
                    'title': 'Shift AC Load to Off-Peak',
                    'description': 'Run during off-peak hours to save up to \$18/month.',
                    'estimated_savings': {'monthlyCostSavings': 18.0, 'currency': 'USD'},
                    'is_dismissed': false,
                  }
                ]
              }
            }),
            200,
          );
        } else if (path.contains('/optimization/cheapest-periods')) {
          return http.Response(
            json.encode({
              'data': {
                'homeId': 'home_01',
                'currency': 'USD',
                'durationHours': 2,
                'cheapestWindow': {
                  'startTime': '2026-07-15T22:00:00Z',
                  'endTime': '2026-07-16T00:00:00Z',
                  'avgPricePerKwh': 0.08,
                  'periodType': 'OFF_PEAK',
                },
                'peakWindow': {
                  'startTime': '2026-07-15T16:00:00Z',
                  'endTime': '2026-07-15T18:00:00Z',
                  'avgPricePerKwh': 0.32,
                  'periodType': 'PEAK',
                },
                'potentialSavingsPercent': 75.0,
              }
            }),
            200,
          );
        } else if (path.contains('/cost/forecast')) {
          return http.Response(
            json.encode({
              'data': {
                'homeId': 'home_01',
                'period': 'monthly',
                'currency': 'USD',
                'actualCostToDate': 42.50,
                'estimatedRemainingCost': 48.00,
                'projectedTotalCost': 90.50,
                'actualKwhToDate': 220.0,
                'projectedTotalKwh': 480.0,
                'daysElapsed': 14,
                'daysRemaining': 17,
                'confidenceScore': 0.82,
                'isEstimate': true,
              }
            }),
            200,
          );
        } else if (path.contains('/cost')) {
          return http.Response(
            json.encode({
              'data': {
                'homeId': 'home_01',
                'period': 'today',
                'totalCost': 3.50,
                'variableCost': 3.00,
                'fixedCharges': 0.50,
                'currency': 'USD',
                'totalKwh': 14.0,
                'breakdown': {
                  'peak': {'cost': 1.80, 'kwh': 5.0},
                  'offPeak': {'cost': 0.80, 'kwh': 6.0},
                  'standard': {'cost': 0.40, 'kwh': 3.0},
                },
                'effectiveTariff': {'name': 'Summer TOU Plan'},
                'dataQuality': 'GOOD',
              }
            }),
            200,
          );
        } else if (path.contains('/budget')) {
          return http.Response(
            json.encode({
              'data': {
                'configured': true,
                'homeId': 'home_01',
                'periodType': 'monthly',
                'budgetAmount': 100.0,
                'currency': 'USD',
                'actualCostToDate': 42.50,
                'budgetRemaining': 57.50,
                'percentConsumed': 42.5,
                'projectedTotalCost': 90.50,
                'percentProjected': 90.5,
                'projectedOverrun': 0.0,
                'isProjectedToExceed': false,
              }
            }),
            200,
          );
        } else if (path.contains('/optimization/cheapest-periods')) {
          return http.Response(
            json.encode({
              'data': {
                'homeId': 'home_01',
                'currency': 'USD',
                'durationHours': 2,
                'cheapestWindow': {
                  'startTime': '2026-07-15T22:00:00Z',
                  'endTime': '2026-07-16T00:00:00Z',
                  'avgPricePerKwh': 0.08,
                  'periodType': 'OFF_PEAK',
                },
                'peakWindow': {
                  'startTime': '2026-07-15T16:00:00Z',
                  'endTime': '2026-07-15T18:00:00Z',
                  'avgPricePerKwh': 0.32,
                  'periodType': 'PEAK',
                },
                'potentialSavingsPercent': 75.0,
              }
            }),
            200,
          );
        } else if (path.contains('/carbon')) {
          return http.Response(
            json.encode({
              'data': {
                'entityId': 'home_01',
                'entityType': 'home',
                'period': 'today',
                'carbonIntensityGPerKwh': 410.0,
                'totalGramsCO2': 5740.0,
                'totalKgCO2': 5.74,
                'source': 'configured_tariff',
                'isEstimate': true,
              }
            }),
            200,
          );
        }
        return http.Response('OK', 200);
      });

      costService = EnergyCostService(client: mockClient);
    });

    testWidgets('EnergyCostDashboardPage renders KPIs, forecast and breakdown', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: EnergyCostDashboardPage(homeId: 'home_01', costService: costService),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Energy Cost & Optimization'), findsOneWidget);
      expect(find.text('USD 3.50'), findsOneWidget);
      expect(find.text('Monthly Cost Projection'), findsOneWidget);
      expect(find.text('Tariff Period Breakdown'), findsOneWidget);
      expect(find.text('Cheapest Upcoming Window'), findsOneWidget);
    });

    testWidgets('TariffManagementPage renders tariff list and handles add', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: TariffManagementPage(homeId: 'home_01', costService: costService),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Electricity Tariffs'), findsOneWidget);
      expect(find.text('Summer TOU Plan'), findsOneWidget);
      expect(find.text('Time of Use (TOU)'), findsOneWidget);
      expect(find.byKey(const Key('btn_add_tariff')), findsOneWidget);
    });

    testWidgets('TariffEditorPage can enter data and submit', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: TariffEditorPage(homeId: 'home_01', costService: costService),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('New Electricity Tariff'), findsOneWidget);
      expect(find.byKey(const Key('field_tariff_name')), findsOneWidget);
      expect(find.byKey(const Key('btn_save_tariff')), findsOneWidget);

      await tester.enterText(find.byKey(const Key('field_tariff_name')), 'Test Flat Rate');
      await tester.pump();

      expect(find.text('Test Flat Rate'), findsOneWidget);
    });

    testWidgets('EnergyBudgetPage renders spending meter and controls', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: EnergyBudgetPage(homeId: 'home_01', costService: costService),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Energy Budget & Alerts'), findsOneWidget);
      expect(find.byKey(const Key('field_budget_amount')), findsOneWidget);
      expect(find.byKey(const Key('btn_save_budget')), findsOneWidget);
    });

    testWidgets('CostOptimizationPage renders recommendations and cheapest window', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: CostOptimizationPage(homeId: 'home_01', costService: costService),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Cost Optimization Hub'), findsOneWidget);
      expect(find.text('Cheapest Next 24h Window'), findsOneWidget);
      expect(find.text('Shift AC Load to Off-Peak'), findsOneWidget);
      expect(find.text('Dismiss'), findsOneWidget);
    });
  });
}
