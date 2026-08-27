import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_home_application_v1/core/models/activity_models.dart';
import 'package:smart_home_application_v1/features/activity/presentation/activity_page.dart';

void main() {
  test('preview activity repository exposes six typed events', () async {
    const repository = PreviewActivityRepository();
    final page = await repository.getEvents(const ActivityQuery());

    expect(page.events, hasLength(6));
    expect(
      page.events.map((event) => event.type),
      contains(ActivityEventType.deviceWarning),
    );
    expect(
      page.events.map((event) => event.type),
      contains(ActivityEventType.routineCompleted),
    );
    expect(
      page.events.map((event) => event.eventTimezone),
      everyElement('Home timezone'),
    );
    expect(page.events.first.isNavigable, isTrue);
  });

  test('filters and chronological sorting are repository-backed', () async {
    const repository = PreviewActivityRepository();
    final alerts = await repository.getEvents(
      const ActivityQuery(filter: ActivityFilter.alerts),
    );
    final oldest = await repository.getEvents(
      const ActivityQuery(sort: ActivitySort.oldest),
    );

    expect(alerts.events, hasLength(2));
    expect(
      oldest.events.first.timestamp.isBefore(oldest.events.last.timestamp),
      isTrue,
    );
  });

  testWidgets('activity list opens an event detail page at 360dp', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(const MaterialApp(home: ActivityPage()));
    await tester.pumpAndSettle();

    expect(find.text('Activity'), findsOneWidget);
    expect(find.text('6 events'), findsOneWidget);
    expect(find.text('Kitchen needs attention'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byIcon(Icons.chevron_right_rounded).first);
    await tester.pumpAndSettle();

    expect(find.byType(ActivityEventDetailPage), findsOneWidget);
    expect(find.text('What happened'), findsOneWidget);
    expect(find.textContaining('Today'), findsWidgets);
    expect(find.text('Kitchen'), findsWidgets);
    expect(find.textContaining('Offline'), findsOneWidget);
  });

  testWidgets('collapsed search expands and filters event content', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: ActivityPage()));
    await tester.pumpAndSettle();

    await tester.tap(find.bySemanticsLabel('Search activity'));
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Kitchen');
    await tester.pumpAndSettle();
    expect(find.text('Kitchen needs attention'), findsOneWidget);
    expect(find.text('Plant care completed'), findsNothing);
  });
}
