import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_home_application_v1/core/models/home_dashboard_models.dart';
import 'package:smart_home_application_v1/core/models/room_models.dart';
import 'package:smart_home_application_v1/core/theme/app_theme.dart';
import 'package:smart_home_application_v1/core/widgets/charts/eh_chart_widgets.dart';
import 'package:smart_home_application_v1/features/rooms/presentation/room_context_page.dart';

void main() {
  testWidgets('RoomContextPage renders waveform and distribution when EM devices present', (tester) async {
    const room = Room(
      id: 'living',
      name: 'Living Room',
      iconKey: 'living',
      deviceCount: 2,
      connectivity: ConnectivityCause.online,
      telemetryFreshness: TelemetryFreshness.current,
      summary: '2 Devices Active',
      status: RoomStatus.normal,
      capabilities: [],
      devices: [],
      insights: RoomInsights(
        energyKwh: '3.4 kWh',
        energyChange: '+8% vs yesterday',
        activeWindow: 'Today (2 metered devices)',
        averageTemperature: '24.0°C',
        averageHumidity: '55%',
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.light().copyWith(
          extensions: [EHThemeTokens.light],
        ),
        home: const Scaffold(
          body: RoomContextPage(room: room),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify room insights and energy chart are rendered
    expect(find.text('Room insights'), findsOneWidget);
    expect(find.text("Today's Room Energy"), findsOneWidget);
    expect(find.text('3.4 kWh'), findsOneWidget);
    expect(find.byType(EHEnergyWaveformChart), findsOneWidget);
  });

  testWidgets('RoomContextPage hides energy section when no EM device in room', (tester) async {
    const roomNoEm = Room(
      id: 'guest',
      name: 'Guest Room',
      iconKey: 'bedroom',
      deviceCount: 1,
      connectivity: ConnectivityCause.online,
      telemetryFreshness: TelemetryFreshness.current,
      summary: '1 Device',
      status: RoomStatus.normal,
      capabilities: [],
      devices: [],
      insights: RoomInsights(
        energyKwh: '—',
        energyChange: '—',
        activeWindow: 'Inactive',
        averageTemperature: '25.0°C',
        averageHumidity: '50%',
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.light().copyWith(
          extensions: [EHThemeTokens.light],
        ),
        home: const Scaffold(
          body: RoomContextPage(room: roomNoEm),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify energy section is hidden
    expect(find.text('Room insights'), findsNothing);
    expect(find.byType(EHEnergyWaveformChart), findsNothing);
  });
}
