import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_home_application_v1/core/services/energy_service.dart';
import 'package:smart_home_application_v1/features/energy/presentation/energy_threshold_dialog.dart';

void main() {
  group('Energy Settings Regression Tests', () {
    testWidgets('EnergyThresholdDialog renders fields and handles save/cancel', (tester) async {
      final energyService = EnergyService(baseUrl: 'http://127.0.0.1:3000');
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EnergyThresholdDialog(
              homeId: 'home-1',
              energyService: energyService,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Energy Thresholds & Budget'), findsOneWidget);
      expect(find.text('High Load Alert Limit (Watts)'), findsOneWidget);
      expect(find.text('Daily Energy Budget (kWh)'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Save'), findsOneWidget);
    });
  });
}
