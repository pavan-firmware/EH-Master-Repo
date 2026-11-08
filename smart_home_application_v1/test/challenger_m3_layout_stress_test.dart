import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_home_application_v1/core/models/privacy_models.dart';
import 'package:smart_home_application_v1/core/repositories/privacy_repository.dart';
import 'package:smart_home_application_v1/core/services/app_permission_service.dart';
import 'package:smart_home_application_v1/core/services/ble_preflight_service.dart';
import 'package:smart_home_application_v1/core/theme/app_theme.dart';
import 'package:smart_home_application_v1/features/settings/presentation/privacy/privacy_page.dart';
import 'package:smart_home_application_v1/features/settings/presentation/privacy/privacy_permission_detail_page.dart';

import 'ble_preflight_service_test.dart';

class StubPermissionDelegate implements PermissionDelegate {
  StubPermissionDelegate({this.initialStatus = PermissionStatus.denied});
  final PermissionStatus initialStatus;

  @override
  Future<PermissionStatus> checkStatus(Permission permission) async => initialStatus;

  @override
  Future<PermissionStatus> requestPermission(Permission permission) async => initialStatus;

  @override
  Future<Map<Permission, PermissionStatus>> requestPermissions(List<Permission> permissions) async =>
      {for (final p in permissions) p: initialStatus};

  @override
  Future<ServiceStatus> checkLocationServiceStatus() async => ServiceStatus.enabled;

  @override
  Future<bool> openAppSettings() async => true;

  @override
  Future<bool> openBluetoothSettings() async => true;

  @override
  Future<bool> openLocationSettings() async => true;
}

class StubPrivacyRepo implements PrivacyRepository {
  StubPrivacyRepo(this.permissions);
  final List<PrivacyPermission> permissions;

  @override
  Future<PrivacySummary> getSummary() async => PrivacySummary(
        title: 'Privacy Control Center',
        subtitle: 'Manage permissions and personal data access.',
        statusLabel: 'Active',
        dataCategories: const [],
        permissions: permissions,
        diagnosticSharing: false,
        usageAnalytics: false,
        diagnosticSupported: true,
        analyticsSupported: true,
      );

  @override
  Future<PrivacyPermissionStatus> queryPermission(String permissionId) async =>
      permissions.firstWhere((p) => p.id == permissionId).status;

  @override
  Future<PrivacyPermissionStatus> requestPermission(String permissionId) async =>
      permissions.firstWhere((p) => p.id == permissionId).status;

  @override
  Future<bool> openSettings() async => true;

  @override
  Future<bool> setDiagnosticSharing(bool enabled) async => true;

  @override
  Future<bool> setUsageAnalytics(bool enabled) async => true;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  Widget wrapWidget({
    required Widget child,
    ThemeMode themeMode = ThemeMode.light,
    Size size = const Size(320, 640),
    double textScaleFactor = 1.0,
  }) {
    return MaterialApp(
      theme: EHAppTheme.lightTheme,
      darkTheme: EHAppTheme.darkTheme,
      themeMode: themeMode,
      home: MediaQuery(
        data: MediaQueryData(
          size: size,
          textScaler: TextScaler.linear(textScaleFactor),
        ),
        child: child,
      ),
    );
  }

  const allStatusesPermissions = [
    PrivacyPermission(
      id: 'bluetooth',
      title: 'Bluetooth Scan & Connect',
      description: 'Used to discover and communicate with nearby IoT mesh devices.',
      status: PrivacyPermissionStatus.allowed,
    ),
    PrivacyPermission(
      id: 'notifications',
      title: 'Push Notifications',
      description: 'Critical system and perimeter security alert updates.',
      status: PrivacyPermissionStatus.whileUsing,
    ),
    PrivacyPermission(
      id: 'location',
      title: 'Precise Geofencing Location',
      description: 'Automates HVAC routines upon arriving home.',
      status: PrivacyPermissionStatus.permanentlyDenied,
    ),
    PrivacyPermission(
      id: 'denied_perm',
      title: 'Microphone Voice Capture',
      description: 'Voice trigger recognition.',
      status: PrivacyPermissionStatus.denied,
    ),
    PrivacyPermission(
      id: 'unrequested_perm',
      title: 'Local Network Discovery',
      description: 'LAN device ping queries.',
      status: PrivacyPermissionStatus.notRequested,
    ),
    PrivacyPermission(
      id: 'unavail_perm',
      title: 'Biometric Security Access',
      description: 'Hardware authentication.',
      status: PrivacyPermissionStatus.unavailable,
    ),
  ];

  group('Adversarial Stress Test: Ultra-Narrow Viewports (280px)', () {
    testWidgets('PrivacyPage renders all 6 permission statuses on 280px width (Light & Dark)', (tester) async {
      tester.view.physicalSize = const Size(280, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final repo = StubPrivacyRepo(allStatusesPermissions);

      // Light mode test
      await tester.pumpWidget(wrapWidget(
        child: PrivacyPage(repository: repo),
        size: const Size(280, 600),
        themeMode: ThemeMode.light,
      ));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'Must not throw RenderFlex error on 280px Light');
      expect(find.text('Bluetooth Scan & Connect'), findsOneWidget);
      expect(find.text('Allowed'), findsOneWidget);
      expect(find.text('While using the app'), findsOneWidget);
      expect(find.text('Permanently denied'), findsOneWidget);

      // Dark mode test
      await tester.pumpWidget(wrapWidget(
        child: PrivacyPage(repository: repo),
        size: const Size(280, 600),
        themeMode: ThemeMode.dark,
      ));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'Must not throw RenderFlex error on 280px Dark');
      expect(find.text('Allowed'), findsOneWidget);
    });

    testWidgets('PrivacyPermissionDetailPage renders permanentlyDenied card on 280px width (Light & Dark)', (tester) async {
      tester.view.physicalSize = const Size(280, 700);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final service = AppPermissionService(
        permissionDelegate: StubPermissionDelegate(initialStatus: PermissionStatus.permanentlyDenied),
        platformSdkInfo: FakePlatformSdkInfo(platform: TargetPlatform.android, sdkVersion: 33),
        preferences: prefs,
      );

      const perm = PrivacyPermission(
        id: 'location',
        title: 'Location Services',
        description: 'Used for geofencing automation routines.',
        status: PrivacyPermissionStatus.permanentlyDenied,
      );

      // Light mode
      await tester.pumpWidget(wrapWidget(
        child: PrivacyPermissionDetailPage(permission: perm, permissionService: service),
        size: const Size(280, 700),
        themeMode: ThemeMode.light,
      ));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Current status'), findsOneWidget);
      expect(find.text('Permission permanently denied'), findsOneWidget);
      expect(find.text('Permanently denied'), findsOneWidget);
      expect(find.text('Open system settings'), findsOneWidget);

      // Dark mode
      await tester.pumpWidget(wrapWidget(
        child: PrivacyPermissionDetailPage(permission: perm, permissionService: service),
        size: const Size(280, 700),
        themeMode: ThemeMode.dark,
      ));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Open system settings'), findsOneWidget);
    });
  });

  group('Adversarial Stress Test: Extreme Font Scaling (1.5x and 2.0x)', () {
    testWidgets('PrivacyPage renders at 1.5x font scale on 320px width without overflow', (tester) async {
      tester.view.physicalSize = const Size(320, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final repo = StubPrivacyRepo(allStatusesPermissions);
      await tester.pumpWidget(wrapWidget(
        child: PrivacyPage(repository: repo),
        size: const Size(320, 1000),
        textScaleFactor: 1.5,
      ));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Allowed'), findsOneWidget);
      expect(find.text('While using the app'), findsOneWidget);
      expect(find.text('Permanently denied'), findsOneWidget);
    });

    testWidgets('PrivacyPage renders at 2.0x font scale on 320px width without overflow', (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final repo = StubPrivacyRepo(allStatusesPermissions);
      await tester.pumpWidget(wrapWidget(
        child: PrivacyPage(repository: repo),
        size: const Size(320, 640),
        textScaleFactor: 2.0,
      ));
      await tester.pumpAndSettle();
      // Scroll through the entire page to ensure all lazy children in ListView are laid out
      await tester.drag(find.byType(ListView), const Offset(0, -400));
      await tester.pumpAndSettle();
      await tester.drag(find.byType(ListView), const Offset(0, -400));
      await tester.pumpAndSettle();
      final exc = tester.takeException();
      expect(exc, isNull, reason: 'PrivacyPage must not throw RenderFlex overflow when scrolled at 2.0x font scale');
    });

    testWidgets('PrivacyPermissionDetailPage renders at 2.0x font scale on 320px width with dual action buttons', (tester) async {
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final service = AppPermissionService(
        permissionDelegate: StubPermissionDelegate(initialStatus: PermissionStatus.denied),
        platformSdkInfo: FakePlatformSdkInfo(platform: TargetPlatform.android, sdkVersion: 33),
        preferences: prefs,
      );

      const perm = PrivacyPermission(
        id: 'bluetooth',
        title: 'Bluetooth',
        description: 'Used to discover and pair devices.',
        status: PrivacyPermissionStatus.denied,
      );

      await tester.pumpWidget(wrapWidget(
        child: PrivacyPermissionDetailPage(permission: perm, permissionService: service),
        size: const Size(320, 800),
        textScaleFactor: 2.0,
      ));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Current status'), findsOneWidget);
      expect(find.text('Not requested'), findsOneWidget);
      expect(find.text('Request permission'), findsOneWidget);
      expect(find.text('Open system settings'), findsOneWidget);
    });

    testWidgets('PrivacyPermissionDetailPage renders at 2.0x font scale with permanentlyDenied guidance card', (tester) async {
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final service = AppPermissionService(
        permissionDelegate: StubPermissionDelegate(initialStatus: PermissionStatus.permanentlyDenied),
        platformSdkInfo: FakePlatformSdkInfo(platform: TargetPlatform.android, sdkVersion: 33),
        preferences: prefs,
      );

      const perm = PrivacyPermission(
        id: 'location',
        title: 'Location',
        description: 'Used for geofencing.',
        status: PrivacyPermissionStatus.permanentlyDenied,
      );

      await tester.pumpWidget(wrapWidget(
        child: PrivacyPermissionDetailPage(permission: perm, permissionService: service),
        size: const Size(320, 800),
        textScaleFactor: 2.0,
      ));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Current status'), findsOneWidget);
      expect(find.text('Permission permanently denied'), findsOneWidget);
      expect(find.text('Permanently denied'), findsOneWidget);
      expect(find.text('Open system settings'), findsOneWidget);
    });
  });

  group('Adversarial Stress Test: Threshold Boundary Widths (299px, 300px, 301px, 380px)', () {
    for (final width in [299.0, 300.0, 301.0, 380.0]) {
      testWidgets('PrivacyPage at width $width px renders cleanly without RenderFlex overflow', (tester) async {
        tester.view.physicalSize = Size(width, 700);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final repo = StubPrivacyRepo(allStatusesPermissions);
        await tester.pumpWidget(wrapWidget(
          child: PrivacyPage(repository: repo),
          size: Size(width, 700),
        ));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: 'Layout must not throw at boundary width $width');
      });
    }
  });
}
