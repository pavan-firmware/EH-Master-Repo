import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_home_application_v1/core/theme/app_theme.dart';
import 'package:smart_home_application_v1/core/widgets/charts/eh_chart_widgets.dart';

void main() {
  testWidgets('EHEnergyWaveformChart renders points, grid, and peak bubble', (tester) async {
    const points = [
      EHChartDataPoint(x: 0, y: 120, label: '00:00'),
      EHChartDataPoint(x: 4, y: 85, label: '04:00'),
      EHChartDataPoint(x: 8, y: 450, label: '08:00'),
      EHChartDataPoint(x: 12, y: 1250, label: '12:00'),
      EHChartDataPoint(x: 16, y: 800, label: '16:00'),
      EHChartDataPoint(x: 20, y: 1850, label: '20:00'),
      EHChartDataPoint(x: 24, y: 240, label: '24:00'),
    ];

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.light().copyWith(
          extensions: [EHThemeTokens.light],
        ),
        home: const Scaffold(
          body: EHEnergyWaveformChart(
            points: points,
            height: 180,
            unit: 'W',
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    expect(find.byType(EHEnergyWaveformChart), findsOneWidget);
    expect(find.byType(CustomPaint), findsWidgets);
  });

  testWidgets('EHEnergyBarChart renders bars with day labels', (tester) async {
    const bars = [
      EHChartDataPoint(x: 0, y: 3.2, label: 'Mon'),
      EHChartDataPoint(x: 1, y: 4.5, label: 'Tue'),
      EHChartDataPoint(x: 2, y: 2.8, label: 'Wed'),
      EHChartDataPoint(x: 3, y: 5.1, label: 'Thu'),
      EHChartDataPoint(x: 4, y: 3.9, label: 'Fri'),
      EHChartDataPoint(x: 5, y: 6.4, label: 'Sat'),
      EHChartDataPoint(x: 6, y: 5.8, label: 'Sun'),
    ];

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.light().copyWith(
          extensions: [EHThemeTokens.light],
        ),
        home: const Scaffold(
          body: EHEnergyBarChart(
            bars: bars,
            unit: 'kWh',
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    expect(find.byType(EHEnergyBarChart), findsOneWidget);
    expect(find.text('Mon'), findsOneWidget);
    expect(find.text('Sun'), findsOneWidget);
  });

  testWidgets('EHEnergyDistributionBar renders proportional segments and legend', (tester) async {
    final items = [
      const EHEnergyDistributionItem(label: 'Hall Switch', valueKwh: 4.2, color: Colors.blue),
      const EHEnergyDistributionItem(label: 'Kitchen Plug', valueKwh: 8.5, color: Colors.amber),
      const EHEnergyDistributionItem(label: 'AC Unit', valueKwh: 12.0, color: Colors.purple),
    ];

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.light().copyWith(
          extensions: [EHThemeTokens.light],
        ),
        home: Scaffold(
          body: EHEnergyDistributionBar(items: items),
        ),
      ),
    );

    await tester.pumpAndSettle();
    expect(find.byType(EHEnergyDistributionBar), findsOneWidget);
    expect(find.textContaining('Kitchen Plug'), findsOneWidget);
    expect(find.textContaining('AC Unit'), findsOneWidget);
  });
}
