import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_home_application_v1/core/repositories/settings_repository.dart';
import 'package:smart_home_application_v1/features/settings/presentation/add_device_page.dart';

void main() {
  group('Add Device Flow Tests', () {
    testWidgets('AddDevicePage displays scanning card and nearby devices', (tester) async {
      const repository = PreviewSettingsRepository();
      await tester.pumpWidget(
        const MaterialApp(
          home: AddDevicePage(
            repository: repository,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Add a device'), findsOneWidget);
      expect(find.text('Nearby devices'), findsOneWidget);
      expect(find.text('EH Smart Switch 3X'), findsOneWidget);
      expect(find.text('EH Smart Switch 5X'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Connect'), findsWidgets);
    });
  });
}
