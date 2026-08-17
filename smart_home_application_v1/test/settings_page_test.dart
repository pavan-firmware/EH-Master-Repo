import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_home_application_v1/core/models/settings_models.dart';
import 'package:smart_home_application_v1/core/repositories/settings_repository.dart';
import 'package:smart_home_application_v1/features/settings/presentation/settings_page.dart';
import 'package:smart_home_application_v1/features/settings/presentation/settings_ui.dart';

Future<void> _scrollSettingsToBottom(WidgetTester tester) async {
  final listFinder = find.byType(Scrollable).first;
  await tester.drag(listFinder, const Offset(0, -600));
  await tester.pumpAndSettle();
}

Future<void> _tapSettingsRow(WidgetTester tester, String label) async {
  final row = find.descendant(
    of: find.byType(SettingsListItem),
    matching: find.text(label),
  );
  final target = row.evaluate().isNotEmpty ? row.first : find.text(label);
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
  await tester.tap(target);
  await tester.pumpAndSettle(const Duration(milliseconds: 300));
}

void main() {
  test('settings preview data keeps mutation results explicit', () async {
    const repository = PreviewSettingsRepository();
    final home = await repository.getHome();
    final members = await repository.getMembers();
    final result = await repository.invitePerson('Test person');

    expect(home.name, 'Pavan’s home');
    expect(members, hasLength(3));
    expect(result, SettingsOperationResult.unsupported);
  });

  testWidgets('Settings root is responsive at 360dp and exposes all sections', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(const MaterialApp(home: SettingsPage()));
    await tester.pumpAndSettle();

    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('Pavan’s home'), findsOneWidget);
    expect(find.text('People at home'), findsOneWidget);
    expect(find.text('Add a room device'), findsOneWidget);

    await _scrollSettingsToBottom(tester);
    expect(find.text('Help and support'), findsOneWidget);
    expect(find.text('Factory reset'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Settings routes to nested pages without footer and shows dynamic chips',
    (tester) async {
      tester.view.physicalSize = const Size(360, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(const MaterialApp(home: SettingsPage()));
      await tester.pumpAndSettle();

      expect(find.text('Connected'), findsOneWidget);
      expect(find.text('Version 1.0.0'), findsOneWidget);
      expect(find.text('1 issue'), findsOneWidget);

      await _tapSettingsRow(tester, 'Connect your home');
      expect(find.text('Your home is connected'), findsOneWidget);
      expect(find.text('Home'), findsNothing);
      await tester.pageBack();
      await tester.pumpAndSettle();

      await _tapSettingsRow(tester, 'System update');
      expect(find.text('Everything is up to date'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();

      await _tapSettingsRow(tester, 'Device health');
      expect(find.text('All good!'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();

      await _scrollSettingsToBottom(tester);
      await _tapSettingsRow(tester, 'Help and support');
      expect(find.text('Quick help'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();

      await _scrollSettingsToBottom(tester);
      await _tapSettingsRow(tester, 'Privacy');
      expect(find.text('YOUR DATA'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();

      await _scrollSettingsToBottom(tester);
      await _tapSettingsRow(tester, 'Factory reset');
      expect(find.text('This action cannot be undone'), findsOneWidget);
    },
  );

  testWidgets(
    'Settings routes to the requested nested pages without a footer',
    (tester) async {
      tester.view.physicalSize = const Size(360, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(const MaterialApp(home: SettingsPage()));
      await tester.pumpAndSettle();

      await _tapSettingsRow(tester, 'Pavan’s home');
      expect(find.text('HOME OVERVIEW'), findsOneWidget);
      expect(find.text('Home'), findsNothing);

      await tester.pageBack();
      await tester.pumpAndSettle();
      await _tapSettingsRow(tester, 'People at home');
      expect(find.text('PEOPLE WITH ACCESS'), findsOneWidget);

      await tester.pageBack();
      await tester.pumpAndSettle();
      await _tapSettingsRow(tester, 'Home details');
      expect(find.textContaining('Created Aug 12, 2026'), findsOneWidget);

      await tester.pageBack();
      await tester.pumpAndSettle();
      await _tapSettingsRow(tester, 'Add a room device');
      expect(find.text('Nearby devices'), findsOneWidget);
      expect(find.text('Smart Mist Maker'), findsOneWidget);
    },
  );
}
