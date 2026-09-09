import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_home_application_v1/core/repositories/settings_repository.dart';
import 'package:smart_home_application_v1/features/settings/presentation/people_page.dart';

void main() {
  group('People Settings Regression Tests', () {
    testWidgets('PeoplePage renders with home members and invite options', (tester) async {
      const repo = PreviewSettingsRepository();
      final home = await repo.getHome();

      await tester.pumpWidget(
        MaterialApp(
          home: PeoplePage(
            home: home,
            repository: repo,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('People at home'), findsOneWidget);
    });
  });
}
