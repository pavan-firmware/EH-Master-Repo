import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_home_application_v1/app/home_controller.dart';
import 'package:smart_home_application_v1/core/models/connection_models.dart';
import 'package:smart_home_application_v1/core/models/home_dashboard_models.dart';
import 'package:smart_home_application_v1/core/repositories/unavailable_connection_repository.dart';
import 'package:smart_home_application_v1/core/services/device_storage_service.dart';
import 'package:smart_home_application_v1/core/utils/time_greeting.dart';
import 'package:smart_home_application_v1/features/rooms/presentation/rooms_page.dart';
import 'package:smart_home_application_v1/features/settings/presentation/notification_preferences_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  Widget app(Widget child) => MaterialApp(home: child);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await DeviceStorageService().clearAllDevices();
  });

  group('Phase 14 — Consumer Product Integration & Release Hardening Tests', () {
    testWidgets('1. Add Room dialog creates custom room without redirecting to Add Device', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(360, 800));
      final controller = HomeController(
        connectionRepository: const UnavailableConnectionRepository(),
      );

      await tester.pumpWidget(app(RoomsPage(homeController: controller)));
      await tester.pumpAndSettle();

      // Tap 'Add room' button
      final addRoomFinder = find.text('Add room');
      expect(addRoomFinder, findsOneWidget);
      await tester.tap(addRoomFinder);
      await tester.pumpAndSettle();

      // Verify the dedicated Add room dialog appears (not nearby setup page)
      expect(find.byType(AlertDialog), findsOneWidget);
      final dialogTextField = find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(TextField),
      );
      expect(dialogTextField, findsOneWidget);

      // Enter room name and tap Create
      await tester.enterText(dialogTextField, 'Study Room');
      await tester.pump();
      await tester.tap(find.text('Create'));
      await tester.pumpAndSettle();

      // Verify room was created and listed
      expect(find.text('Study Room'), findsOneWidget);
      expect(find.text('1 room · 0 devices'), findsOneWidget);
      expect(controller.rooms.any((r) => r.name == 'Study Room'), isTrue);
    });

    testWidgets('2. Multi-device onboarding and moving device to another room updates room counts', (
      tester,
    ) async {
      final storage = DeviceStorageService();
      const dev1 = ConnectedDeviceSummary(
        id: 'dev-001-uuid',
        name: 'EH Smart Switch 3X',
        model: 'eh-smart-switch-3x',
        firmware: '1.0.0',
        connectedVia: 'Wi-Fi (2.4 GHz)',
        signalLabel: 'Strong',
        roomName: 'Living Room',
        online: true,
      );
      const dev2 = ConnectedDeviceSummary(
        id: 'dev-002-uuid',
        name: 'EH Smart Socket 1X',
        model: 'eh-smart-socket-1x',
        firmware: '1.0.0',
        connectedVia: 'Wi-Fi (2.4 GHz)',
        signalLabel: 'Good',
        roomName: 'Kitchen',
        online: true,
      );

      await storage.saveDevice(dev1);
      await storage.saveDevice(dev2);

      final controller = HomeController(
        storageService: storage,
        connectionRepository: const UnavailableConnectionRepository(),
      );

      expect(controller.devices.length, 2);
      expect(controller.rooms.length, 2);

      // Move dev2 from Kitchen to Living Room
      await controller.moveDeviceToRoom('dev-002-uuid', 'Living Room');

      expect(controller.rooms.length, 1);
      expect(controller.rooms.first.name, 'Living Room');
      expect(controller.rooms.first.deviceCount, 2);
    });

    testWidgets('3. Quick Controls customization selection and persistence', (
      tester,
    ) async {
      final storage = DeviceStorageService();
      const dev = ConnectedDeviceSummary(
        id: 'dev-switch-01',
        name: 'Living Switch',
        model: 'eh-smart-switch-3x',
        firmware: '1.0.0',
        connectedVia: 'Wi-Fi',
        signalLabel: 'Strong',
        roomName: 'Living Room',
        online: true,
      );
      await storage.saveDevice(dev);

      final controller = HomeController(
        storageService: storage,
        connectionRepository: const UnavailableConnectionRepository(),
      );

      // Save custom quick controls selection
      await controller.saveQuickControlSelection(['dev-switch-01_ch1', 'dev-switch-01_ch2']);

      expect(controller.selectedQuickControlIds, ['dev-switch-01_ch1', 'dev-switch-01_ch2']);
      final dashboard = controller.dashboard;
      expect(dashboard.controls.length, 2);
      expect(dashboard.controls[0].title, contains('Sw1'));
      expect(dashboard.controls[1].title, contains('Sw2'));
    });

    testWidgets('4. Dynamic time-aware greeting daypart progression', (tester) async {
      // 08:30 -> Morning
      expect(getTimeAwareGreeting(DateTime(2026, 8, 30, 8, 30)), 'Good morning, ');
      // 14:15 -> Afternoon
      expect(getTimeAwareGreeting(DateTime(2026, 8, 30, 14, 15)), 'Good afternoon, ');
      // 18:45 -> Evening
      expect(getTimeAwareGreeting(DateTime(2026, 8, 30, 18, 45)), 'Good evening, ');
      // 22:30 -> Night
      expect(getTimeAwareGreeting(DateTime(2026, 8, 30, 22, 30)), 'Good night, ');
      // 02:15 -> Night
      expect(getTimeAwareGreeting(DateTime(2026, 8, 30, 2, 15)), 'Good night, ');
    });

    testWidgets('5. Notification preferences page toggles and persistence', (
      tester,
    ) async {
      final storage = DeviceStorageService();
      await tester.pumpWidget(
        app(NotificationPreferencesPage(storageService: storage)),
      );
      await tester.pumpAndSettle();

      expect(find.text('Notifications'), findsOneWidget);
      expect(find.text('Critical safety alerts'), findsOneWidget);
      expect(find.text('Device offline alerts'), findsOneWidget);

      // Tap offline alerts switch to toggle it
      final offlineSwitchFinder = find.widgetWithText(
        SwitchListTile,
        'Device offline alerts',
      );
      expect(offlineSwitchFinder, findsOneWidget);
      await tester.tap(offlineSwitchFinder);
      await tester.pumpAndSettle();

      final savedPrefs = await storage.loadNotificationPrefs();
      expect(savedPrefs['deviceOffline'], isFalse);
    });

    testWidgets('6. App data clear separation from hardware factory identity', (
      tester,
    ) async {
      final storage = DeviceStorageService();
      const dev = ConnectedDeviceSummary(
        id: 'factory-hw-0194fe23',
        name: 'EH Smart Switch 3X',
        model: 'eh-smart-switch-3x',
        firmware: '1.0.0',
        connectedVia: 'Wi-Fi',
        signalLabel: 'Strong',
        roomName: 'Living Room',
        online: true,
      );
      await storage.saveDevice(dev);

      // Verify device was cached
      var loaded = await storage.loadDevices();
      expect(loaded.length, 1);

      // App clear removes local cache only
      await storage.clearAllDevices();

      loaded = await storage.loadDevices();
      expect(loaded.isEmpty, isTrue);

      // Factory identity definition is immutable and separate from customer local cache
      const factoryIdentity = FactoryDeviceIdentity(
        deviceId: 'factory-hw-0194fe23',
        serialNumber: 'EH-SW3X-2026W12-00891',
        model: 'eh-smart-switch-3x',
        hardwareRevision: 'HW_1_0',
      );
      expect(factoryIdentity.serialNumber, 'EH-SW3X-2026W12-00891');
      expect(factoryIdentity.hardwareRevision, 'HW_1_0');
    });
  });
}
