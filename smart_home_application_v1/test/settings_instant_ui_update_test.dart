import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_home_application_v1/app/home_controller.dart';
import 'package:smart_home_application_v1/core/models/device_models.dart';
import 'package:smart_home_application_v1/core/models/settings_models.dart';
import 'package:smart_home_application_v1/core/repositories/settings_repository.dart';
import 'package:smart_home_application_v1/core/repositories/unavailable_connection_repository.dart';
import 'package:smart_home_application_v1/features/settings/presentation/home_details_page.dart';
import 'package:smart_home_application_v1/features/settings/presentation/settings_page_rebuild.dart';
import 'package:smart_home_application_v1/features/settings/presentation/add_room_device_page.dart';

class _MutableSettingsRepository implements SettingsRepository {
  _MutableSettingsRepository({HomeSettingsData? initialHome})
      : _home = initialHome ??
            HomeSettingsData(
              id: 'HN-TEST-123',
              name: 'Original Home Name',
              ownerName: 'Pavan',
              location: 'Bangalore, India',
              timezone: 'Asia/Kolkata',
              createdAt: DateTime(2026, 1, 1),
              preferences: const HomePreferences(
                temperatureUnit: 'Celsius (°C)',
                notificationsEnabled: true,
                timeFormat: '12-hour',
              ),
              connectionAvailability: HomeConnectionAvailability.connected,
              connectionTransport: 'Wi-Fi',
              lastChecked: null,
            );

  HomeSettingsData _home;
  final List<DiscoveredRoomDevice> _nearby = [
    const DiscoveredRoomDevice(
      id: 'DEV-1',
      name: 'Smart Lamp',
      model: 'SL-01',
      signalLabel: 'Strong',
      signal: DeviceConnection.online,
      icon: 'light',
    ),
  ];

  @override
  Future<HomeSettingsData> getHome() async => _home;

  @override
  Future<SettingsOperationResult> updateHome(HomeSettingsDraft draft) async {
    _home = _home.copyWith(
      name: draft.name,
      location: draft.location,
      timezone: draft.timezone,
      preferences: draft.preferences,
    );
    return SettingsOperationResult.success;
  }

  @override
  Future<List<DiscoveredRoomDevice>> getNearbyDevices() async => _nearby;

  @override
  Future<List<HomeMember>> getMembers() async => const [];

  @override
  Future<List<HomeInvitation>> getPendingInvitations() async => const [];

  @override
  Future<SettingsOperationResult> cancelInvitation(String invitationId) async =>
      SettingsOperationResult.success;

  @override
  Future<SettingsOperationResult> invitePerson(String recipient) async =>
      SettingsOperationResult.success;

  @override
  Future<SettingsOperationResult> invitePersonWithRole(String recipient,
          {String role = 'MEMBER'}) async =>
      SettingsOperationResult.success;

  @override
  Future<SettingsOperationResult> removeMember(String memberId) async =>
      SettingsOperationResult.success;

  @override
  Future<SettingsOperationResult> resendInvitation(String invitationId) async =>
      SettingsOperationResult.success;

  @override
  Future<SettingsOperationResult> updateMemberRole(
          String memberId, String role) async =>
      SettingsOperationResult.success;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Instant Settings UI Updates', () {
    testWidgets('HomeDetailsPage updates home name immediately without leaving screen',
        (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final repo = _MutableSettingsRepository();
      final home = await repo.getHome();

      await tester.pumpWidget(
        MaterialApp(
          home: HomeDetailsPage(
            home: home,
            repository: repo,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Original Home Name'), findsNWidgets(2)); // Title in header and list item

      // Tap on Home name tile to open edit dialog
      await tester.tap(find.text('Home name'));
      await tester.pumpAndSettle();

      // Enter new name in dialog
      final inputFinder = find.byType(TextField);
      expect(inputFinder, findsOneWidget);
      await tester.enterText(inputFinder, 'Sunset Villa');
      await tester.pumpAndSettle();

      // Tap Save
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      // Verifies instant UI change without popping or navigating away!
      expect(find.text('Sunset Villa'), findsOneWidget);
      expect(find.textContaining('Sunset Villa · Created'), findsOneWidget);
      expect(find.textContaining('Original Home Name'), findsNothing);
    });

    testWidgets(
        'HomeDetailsPage updates temperature unit and time format immediately without leaving screen',
        (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final repo = _MutableSettingsRepository();
      final home = await repo.getHome();

      await tester.pumpWidget(
        MaterialApp(
          home: HomeDetailsPage(
            home: home,
            repository: repo,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Celsius (°C)'), findsOneWidget);

      // Tap Temperature unit
      await tester.tap(find.text('Temperature unit'));
      await tester.pumpAndSettle();

      // Select Fahrenheit
      await tester.tap(find.text('Fahrenheit (°F)'));
      await tester.pumpAndSettle();

      // Verifies instant UI update on screen!
      expect(find.text('Fahrenheit (°F)'), findsOneWidget);

      // Now change time format
      expect(find.text('12-hour'), findsOneWidget);
      await tester.tap(find.text('Time format'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('24-hour (e.g. 14:30)'));
      await tester.pumpAndSettle();

      expect(find.text('24-hour'), findsOneWidget);
    });

    testWidgets(
        'SettingsPage immediately reflects updated home name when returning from HomeDetailsPage',
        (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final repo = _MutableSettingsRepository();

      await tester.pumpWidget(
        MaterialApp(
          home: SettingsPage(
            repository: repo,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Original Home Name'), findsOneWidget);

      // Tap on the home profile card to navigate to HomeDetailsPage
      await tester.tap(find.text('Original Home Name'));
      await tester.pumpAndSettle();

      // On HomeDetailsPage now
      expect(find.text('Home details'), findsOneWidget);

      // Edit home name
      await tester.tap(find.text('Home name'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'Ocean Breeze Estate');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(find.text('Ocean Breeze Estate'), findsWidgets);

      // Pop back to SettingsPage
      final backButton = find.byType(BackButton);
      if (backButton.evaluate().isNotEmpty) {
        await tester.tap(backButton);
      } else {
        await tester.pageBack();
      }
      await tester.pumpAndSettle();

      // Verifies SettingsPage instantly has the updated name without another round-trip!
      expect(find.text('Ocean Breeze Estate'), findsOneWidget);
    });

    testWidgets('HomeController listener updates HomeDetailsPage dynamically',
        (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final controller = HomeController(
        connectionRepository: const UnavailableConnectionRepository(),
      );

      final repo = _MutableSettingsRepository();
      final home = await repo.getHome();

      await tester.pumpWidget(
        MaterialApp(
          home: HomeDetailsPage(
            home: home,
            repository: repo,
            homeController: controller,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final initialRooms = controller.rooms.length;
      expect(find.text('$initialRooms ${initialRooms == 1 ? "room" : "rooms"} · 0 devices'),
          findsOneWidget);

      // Trigger update via controller space change
      await controller.updateSpace(controller.activeSpaceId, 'Updated Living Home');
      await tester.pumpAndSettle();

      expect(controller.activeSpaceName, 'Updated Living Home');
    });

    testWidgets('AddRoomDevicePage reacts to homeController listener dynamically',
        (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final controller = HomeController(
        connectionRepository: const UnavailableConnectionRepository(),
      );

      final repo = _MutableSettingsRepository();

      await tester.pumpWidget(
        MaterialApp(
          home: AddRoomDevicePage(
            repository: repo,
            homeController: controller,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Nearby devices'), findsOneWidget);
      expect(find.text('Smart Lamp'), findsOneWidget);

      // Notify controller
      controller.notifyListeners();
      await tester.pumpAndSettle();

      expect(find.text('Smart Lamp'), findsOneWidget);
    });
  });
}
