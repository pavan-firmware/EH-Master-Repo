import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_home_application_v1/core/repositories/settings_repository.dart';
import 'package:smart_home_application_v1/core/theme/app_theme.dart';
import 'package:smart_home_application_v1/features/settings/presentation/home_details_page.dart';
import 'package:smart_home_application_v1/features/settings/presentation/people_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Settings Form Cancel & Lifecycle Regression Tests', () {
    testWidgets('Edit home name dialog opens, types text, and cancels cleanly', (tester) async {
      final repository = const PreviewSettingsRepository();
      final home = await repository.getHome();

      await tester.pumpWidget(
        MaterialApp(
          theme: EHAppTheme.lightTheme,
          home: Scaffold(
            body: HomeDetailsPage(
              repository: repository,
              home: home,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Tap to edit home name
      final nameFinder = find.text('Home name');
      expect(nameFinder, findsAtLeastNWidgets(1));
      await tester.tap(nameFinder.first);
      await tester.pumpAndSettle();

      // Verify dialog is visible with text field
      expect(find.byType(TextField), findsOneWidget);

      // Enter text
      await tester.enterText(find.byType(TextField), 'Cancelled Home Name');
      await tester.pumpAndSettle();

      // Tap Cancel
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      // Verify dialog is dismissed
      expect(find.byType(TextField), findsNothing);
    });

    testWidgets('Invite person dialog opens, types email, and cancels cleanly without leak', (tester) async {
      final repository = const PreviewSettingsRepository();
      final home = await repository.getHome();

      await tester.pumpWidget(
        MaterialApp(
          theme: EHAppTheme.lightTheme,
          home: Scaffold(
            body: PeoplePage(
              repository: repository,
              home: home,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Tap Invite someone
      final inviteFinder = find.text('Invite someone');
      expect(inviteFinder, findsAtLeastNWidgets(1));
      await tester.tap(inviteFinder.first);
      await tester.pumpAndSettle();

      // Verify dialog
      expect(find.text('Invite to Home'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'test@example.com');
      await tester.pumpAndSettle();

      // Tap Cancel
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.text('Invite to Home'), findsNothing);
    });
  });
}
