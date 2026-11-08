import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_home_application_v1/core/models/privacy_models.dart';
import 'package:smart_home_application_v1/core/repositories/privacy_repository.dart';
import 'package:smart_home_application_v1/core/services/app_permission_service.dart';
import 'package:smart_home_application_v1/core/theme/app_theme.dart';
import 'package:smart_home_application_v1/features/settings/presentation/privacy/privacy_page.dart';
import 'package:smart_home_application_v1/features/settings/presentation/privacy/privacy_permission_detail_page.dart';

import 'ble_preflight_service_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  Widget buildTestApp({
    required Widget home,
    ThemeMode themeMode = ThemeMode.light,
  }) =>
      MaterialApp(
        theme: EHAppTheme.lightTheme,
        darkTheme: EHAppTheme.darkTheme,
        themeMode: themeMode,
        home: home,
      );

  group('PrivacyPage Dynamic Rendering & Lifecycle', () {
    testWidgets('PrivacyPage renders dynamic permission statuses from service', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final delegate = FakePermissionDelegate(
        initialStatuses: {
          Permission.bluetoothScan: PermissionStatus.granted,
          Permission.bluetoothConnect: PermissionStatus.granted,
          Permission.notification: PermissionStatus.granted,
          Permission.locationWhenInUse: PermissionStatus.granted,
        },
      );
      final sdk = FakePlatformSdkInfo(platform: TargetPlatform.android, sdkVersion: 33);
      final service = AppPermissionService(
        permissionDelegate: delegate,
        platformSdkInfo: sdk,
        preferences: prefs,
      );
      final repository = PreviewPrivacyRepository(permissionService: service);

      await tester.pumpWidget(
        buildTestApp(home: PrivacyPage(repository: repository, permissionService: service)),
      );
      await tester.pumpAndSettle();

      expect(find.text('PERMISSIONS'), findsOneWidget);
      expect(find.text('Bluetooth'), findsOneWidget);
      expect(find.text('Notifications'), findsOneWidget);
      expect(find.text('Location'), findsOneWidget);

      // Verify dynamic labels
      expect(find.text('Allowed'), findsNWidgets(2)); // Bluetooth and Notifications
      expect(find.text('While using the app'), findsOneWidget); // Location
    });

    testWidgets('PrivacyPage dynamically updates when resuming from system settings', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final delegate = FakePermissionDelegate(
        initialStatuses: {
          Permission.bluetoothScan: PermissionStatus.granted,
          Permission.bluetoothConnect: PermissionStatus.granted,
          Permission.notification: PermissionStatus.granted,
          Permission.locationWhenInUse: PermissionStatus.denied,
        },
      );
      final sdk = FakePlatformSdkInfo(platform: TargetPlatform.android, sdkVersion: 33);
      final service = AppPermissionService(
        permissionDelegate: delegate,
        platformSdkInfo: sdk,
        preferences: prefs,
      );
      final repository = PreviewPrivacyRepository(permissionService: service);

      await tester.pumpWidget(
        buildTestApp(home: PrivacyPage(repository: repository, permissionService: service)),
      );
      await tester.pumpAndSettle();

      expect(find.text('Not requested'), findsOneWidget); // Location initially unrequested

      // User switches to Android Settings, grants Location "While using the app", and resumes app
      delegate.statuses[Permission.locationWhenInUse] = PermissionStatus.granted;

      // Simulate AppLifecycleState.resumed
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();

      // UI must automatically refresh without reopening
      expect(find.text('While using the app'), findsOneWidget);
      expect(find.text('Not requested'), findsNothing);
    });

    testWidgets('Navigating to detail screen displays identical status and syncs back', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final delegate = FakePermissionDelegate(
        initialStatuses: {
          Permission.bluetoothScan: PermissionStatus.granted,
          Permission.bluetoothConnect: PermissionStatus.granted,
          Permission.notification: PermissionStatus.granted,
          Permission.locationWhenInUse: PermissionStatus.granted,
        },
      );
      final sdk = FakePlatformSdkInfo(platform: TargetPlatform.android, sdkVersion: 33);
      final service = AppPermissionService(
        permissionDelegate: delegate,
        platformSdkInfo: sdk,
        preferences: prefs,
      );
      final repository = PreviewPrivacyRepository(permissionService: service);

      await tester.pumpWidget(
        buildTestApp(home: PrivacyPage(repository: repository, permissionService: service)),
      );
      await tester.pumpAndSettle();

      // Tap Location row
      await tester.tap(find.text('Location'));
      await tester.pumpAndSettle();

      // Assert on Detail Page
      expect(find.text('Current status'), findsOneWidget);
      expect(find.text('While using the app'), findsOneWidget);
      expect(find.text('Open system settings'), findsOneWidget);

      // Pop back
      await tester.pageBack();
      await tester.pumpAndSettle();

      expect(find.text('PERMISSIONS'), findsOneWidget);
    });
  });

  group('PrivacyPermissionDetailPage Reactive Lifecycle & Guidance Card', () {
    testWidgets('Detail screen dynamically refreshes on AppLifecycleState.resumed', (tester) async {
      final delegate = FakePermissionDelegate(
        initialStatuses: {
          Permission.locationWhenInUse: PermissionStatus.denied,
        },
      );
      final service = AppPermissionService(
        permissionDelegate: delegate,
        preferences: prefs,
      );

      const permission = PrivacyPermission(
        id: 'location',
        title: 'Location',
        description: 'Used for location-based features.',
        status: PrivacyPermissionStatus.notRequested,
      );

      await tester.pumpWidget(
        buildTestApp(
          home: PrivacyPermissionDetailPage(
            permission: permission,
            permissionService: service,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Not requested'), findsOneWidget);

      // User grants location in system settings and returns
      delegate.statuses[Permission.locationWhenInUse] = PermissionStatus.granted;

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();

      expect(find.text('While using the app'), findsOneWidget);
      expect(find.text('Not requested'), findsNothing);
    });

    testWidgets('Permanently denied status renders guidance card and settings button', (tester) async {
      final delegate = FakePermissionDelegate(
        initialStatuses: {
          Permission.bluetoothScan: PermissionStatus.permanentlyDenied,
          Permission.bluetoothConnect: PermissionStatus.permanentlyDenied,
        },
      );
      final service = AppPermissionService(
        permissionDelegate: delegate,
        preferences: prefs,
      );

      const permission = PrivacyPermission(
        id: 'bluetooth',
        title: 'Bluetooth',
        description: 'Used to discover and connect devices.',
        status: PrivacyPermissionStatus.permanentlyDenied,
      );

      await tester.pumpWidget(
        buildTestApp(
          home: PrivacyPermissionDetailPage(
            permission: permission,
            permissionService: service,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Permanently denied'), findsOneWidget);
      expect(find.text('Permission permanently denied'), findsOneWidget);
      expect(find.textContaining('This permission is disabled in system settings'), findsOneWidget);

      // Only "Open system settings" should be visible (not "Request permission")
      expect(find.text('Open system settings'), findsOneWidget);
      expect(find.text('Request permission'), findsNothing);

      // Tap Open system settings
      await tester.tap(find.text('Open system settings'));
      await tester.pumpAndSettle();
      expect(delegate.appSettingsOpened, isTrue);
    });

    testWidgets('Unrequested or denied status displays Request permission and Open settings buttons', (tester) async {
      final delegate = FakePermissionDelegate(
        initialStatuses: {
          Permission.locationWhenInUse: PermissionStatus.denied,
        },
        grantOnRequest: true,
      );
      final service = AppPermissionService(
        permissionDelegate: delegate,
        preferences: prefs,
      );

      const permission = PrivacyPermission(
        id: 'location',
        title: 'Location',
        description: 'Used for location-based features.',
        status: PrivacyPermissionStatus.notRequested,
      );

      await tester.pumpWidget(
        buildTestApp(
          home: PrivacyPermissionDetailPage(
            permission: permission,
            permissionService: service,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Request permission'), findsOneWidget);
      expect(find.text('Open system settings'), findsOneWidget);

      // Tap Request permission
      await tester.tap(find.text('Request permission'));
      await tester.pumpAndSettle();

      // Should now be While using the app
      expect(find.text('While using the app'), findsOneWidget);
      expect(find.text('Request permission'), findsNothing);
    });

    testWidgets('Detail screen renders cleanly in Dark Theme with zero overflow', (tester) async {
      final delegate = FakePermissionDelegate(
        initialStatuses: {
          Permission.locationWhenInUse: PermissionStatus.permanentlyDenied,
        },
      );
      final service = AppPermissionService(
        permissionDelegate: delegate,
        preferences: prefs,
      );

      const permission = PrivacyPermission(
        id: 'location',
        title: 'Location',
        description: 'Used for location-based features.',
        status: PrivacyPermissionStatus.permanentlyDenied,
      );

      await tester.pumpWidget(
        buildTestApp(
          themeMode: ThemeMode.dark,
          home: PrivacyPermissionDetailPage(
            permission: permission,
            permissionService: service,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Location'), findsOneWidget);
      expect(find.text('Permission permanently denied'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
