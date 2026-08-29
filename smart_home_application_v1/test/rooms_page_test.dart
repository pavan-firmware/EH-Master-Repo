import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_home_application_v1/app/home_controller.dart';
import 'package:smart_home_application_v1/core/models/connection_models.dart';
import 'package:smart_home_application_v1/core/models/home_dashboard_models.dart';
import 'package:smart_home_application_v1/core/models/room_models.dart';
import 'package:smart_home_application_v1/core/repositories/unavailable_connection_repository.dart';
import 'package:smart_home_application_v1/core/services/device_storage_service.dart';
import 'package:smart_home_application_v1/features/rooms/presentation/room_context_page.dart';
import 'package:smart_home_application_v1/features/rooms/presentation/rooms_page.dart';

import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  Widget app(Widget child) => MaterialApp(home: child);

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('rooms list shows zero state when no device is provisioned', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(360, 800));
    final controller = HomeController(
      connectionRepository: const UnavailableConnectionRepository(),
    );
    await tester.pumpWidget(app(RoomsPage(homeController: controller)));
    await tester.pumpAndSettle();

    expect(find.text('0 rooms · 0 devices'), findsOneWidget);
    expect(find.text('No rooms match your search.'), findsOneWidget);
    expect(find.text('Add room'), findsOneWidget);
  });

  testWidgets('rooms list shows dynamic provisioned room (e.g. Balcony)', (
    tester,
  ) async {
    final storage = DeviceStorageService();
    const device = ConnectedDeviceSummary(
      id: '4444688e-989d-458e-820e-ac62a99ed8e1',
      name: 'EH Smart Switch 3X',
      model: 'eh-smart-switch-3x',
      firmware: '1.0.0',
      connectedVia: 'Wi-Fi (2.4 GHz)',
      signalLabel: 'Strong',
      roomName: 'Balcony',
      online: true,
    );
    await storage.saveDevice(device);

    final controller = HomeController(
      storageService: storage,
      connectionRepository: const UnavailableConnectionRepository(),
    );

    await tester.pumpWidget(app(RoomsPage(homeController: controller)));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('Balcony'), findsOneWidget);
    expect(find.text('1 room · 1 device'), findsOneWidget);
  });

  testWidgets('tapping a room opens the reusable room detail page', (
    tester,
  ) async {
    const room = Room(
      id: 'living',
      name: 'Living Room',
      iconKey: 'living',
      deviceCount: 1,
      connectivity: ConnectivityCause.online,
      telemetryFreshness: TelemetryFreshness.current,
      summary: 'Light on · Normal',
      status: RoomStatus.normal,
      capabilities: [
        RoomCapability(
          id: 'light',
          label: 'Living Room light',
          value: 'On',
          kind: RoomCapabilityKind.light,
        ),
      ],
      devices: [
        RoomDevice(
          id: 'dev-1',
          name: 'EH Smart Switch 3X',
          type: 'Smart Switch',
          value: 'On',
          kind: RoomCapabilityKind.light,
          confidence: ActuatorConfidence.confirmed,
        ),
      ],
      insights: RoomInsights(
        energyKwh: '1.2 kWh',
        energyChange: '+0.1 kWh',
        activeWindow: 'Today',
        averageTemperature: '24°C',
        averageHumidity: '55%',
      ),
    );

    await tester.pumpWidget(app(const RoomContextPage(room: room)));
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
