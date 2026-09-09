import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_home_application_v1/core/repositories/settings_repository.dart';
import 'package:smart_home_application_v1/features/settings/presentation/add_room_device_page.dart';

void main() {
  group('Add Device Flow Tests', () {
    testWidgets('AddRoomDevicePage displays discovery steps and scanner', (tester) async {
      const repository = PreviewSettingsRepository();
      await tester.pumpWidget(
        const MaterialApp(
          home: AddRoomDevicePage(
            repository: repository,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Add a room device'), findsOneWidget);
      expect(find.text('Finding nearby devices…'), findsOneWidget);
      expect(find.text('Discover'), findsOneWidget);
    });
  });
}
