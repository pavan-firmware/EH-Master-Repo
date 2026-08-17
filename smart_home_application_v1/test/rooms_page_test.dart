import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_home_application_v1/core/models/home_dashboard_models.dart';
import 'package:smart_home_application_v1/core/models/room_models.dart';
import 'package:smart_home_application_v1/features/rooms/presentation/room_context_page.dart';
import 'package:smart_home_application_v1/features/rooms/presentation/rooms_page.dart';

void main() {
  Widget app(Widget child) => MaterialApp(home: child);

  testWidgets('rooms list shows the four capability-driven preview rooms', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(360, 800));
    await tester.pumpWidget(app(const RoomsPage()));

    expect(find.text('Living Room'), findsOneWidget);
    expect(find.text('Kitchen'), findsOneWidget);
    await tester.drag(find.byType(ListView).first, const Offset(0, -500));
    await tester.pumpAndSettle();
    expect(find.text('Plant Corner'), findsOneWidget);
    expect(find.text('Water Tank'), findsOneWidget);
    expect(find.byType(Switch), findsNothing);
  });

  testWidgets('attention filter shows Kitchen only', (tester) async {
    await tester.pumpWidget(app(const RoomsPage()));
    await tester.ensureVisible(find.text('Attention'));
    await tester.tap(find.text('Attention'));
    await tester.pumpAndSettle();

    expect(find.text('Kitchen'), findsOneWidget);
    expect(find.text('Living Room'), findsNothing);
  });

  testWidgets('tapping a room opens the reusable room detail page', (
    tester,
  ) async {
    await tester.pumpWidget(app(const RoomsPage()));
    await tester.tap(find.text('Living Room').first);
    await tester.pumpAndSettle();

    expect(find.byType(RoomContextPage), findsOneWidget);
    expect(find.text('Quick controls'), findsOneWidget);
    await tester.drag(find.byType(ListView).first, const Offset(0, -700));
    await tester.pumpAndSettle();
    expect(find.text('Room insights'), findsOneWidget);
  });

  testWidgets('stale safety capability is never shown as safe', (tester) async {
    const room = Room(
      id: 'stale-kitchen',
      name: 'Kitchen',
      iconKey: 'kitchen',
      deviceCount: 1,
      connectivity: ConnectivityCause.online,
      telemetryFreshness: TelemetryFreshness.stale,
      summary: 'Last checked 20 min ago',
      status: RoomStatus.attention,
      capabilities: [
        RoomCapability(
          id: 'gas',
          label: 'Gas sensor',
          value: 'State unavailable',
          kind: RoomCapabilityKind.gasSensor,
          safetyCritical: true,
        ),
      ],
      devices: [],
      insights: RoomInsights(
        energyKwh: '—',
        energyChange: '—',
        activeWindow: '—',
        averageTemperature: '—',
        averageHumidity: '—',
      ),
    );
    await tester.pumpWidget(app(const RoomContextPage(room: room)));
    expect(find.text('State unavailable'), findsOneWidget);
    expect(find.text('Comfortable'), findsNothing);
  });
}
