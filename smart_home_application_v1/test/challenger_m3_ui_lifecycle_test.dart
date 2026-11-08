import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

/// Fully controllable adversarial mock delegate for stress and chaos testing.
class AdversarialPermissionDelegate implements PermissionDelegate {
  AdversarialPermissionDelegate({
    Map<Permission, PermissionStatus>? initialStatuses,
    this.grantOnRequest = true,
  }) : statuses = Map<Permission, PermissionStatus>.from(initialStatuses ?? {});

  final Map<Permission, PermissionStatus> statuses;
  final bool grantOnRequest;
  int requestCount = 0;
  Completer<PermissionStatus>? pendingRequestCompleter;
  Completer<PermissionStatus>? pendingCheckCompleter;
  Completer<bool>? pendingSettingsCompleter;
  bool shouldThrowOnRequest = false;
  bool shouldThrowOnCheck = false;
  bool appSettingsOpened = false;

  @override
  Future<PermissionStatus> checkStatus(Permission permission) async {
    if (shouldThrowOnCheck) {
      throw PlatformException(
        code: 'SIMULATED_CHECK_ERROR',
        message: 'Underlying platform check failed',
      );
    }
    if (pendingCheckCompleter != null) {
      return pendingCheckCompleter!.future;
    }
    return statuses[permission] ?? PermissionStatus.denied;
  }

  @override
  Future<PermissionStatus> requestPermission(Permission permission) async {
    requestCount++;
    if (shouldThrowOnRequest) {
      throw PlatformException(
        code: 'SIMULATED_REQUEST_ERROR',
        message: 'Underlying platform request failed',
      );
    }
    if (pendingRequestCompleter != null) {
      return pendingRequestCompleter!.future;
    }
    final status = grantOnRequest ? PermissionStatus.granted : (statuses[permission] ?? PermissionStatus.denied);
    statuses[permission] = status;
    return status;
  }

  @override
  Future<Map<Permission, PermissionStatus>> requestPermissions(
    List<Permission> permissions,
  ) async {
    requestCount++;
    if (shouldThrowOnRequest) {
      throw PlatformException(
        code: 'SIMULATED_REQUEST_ERROR',
        message: 'Underlying platform request failed',
      );
    }
    final result = <Permission, PermissionStatus>{};
    for (final p in permissions) {
      final status = grantOnRequest ? PermissionStatus.granted : (statuses[p] ?? PermissionStatus.denied);
      statuses[p] = status;
      result[p] = status;
    }
    return result;
  }

  @override
  Future<ServiceStatus> checkLocationServiceStatus() async {
    return ServiceStatus.enabled;
  }

  @override
  Future<bool> openAppSettings() async {
    appSettingsOpened = true;
    if (pendingSettingsCompleter != null) {
      return pendingSettingsCompleter!.future;
    }
    return true;
  }

  @override
  Future<bool> openBluetoothSettings() => openAppSettings();

  @override
  Future<bool> openLocationSettings() => openAppSettings();
}

/// Custom test repository to supply arbitrary combinations of permission statuses.
class FakeCustomSummaryPrivacyRepository implements PrivacyRepository {
  FakeCustomSummaryPrivacyRepository({required this.permissions});

  final List<PrivacyPermission> permissions;

  @override
  Future<PrivacySummary> getSummary() async {
    return PrivacySummary(
      title: 'Your privacy is in your control.',
      subtitle: 'EH Home collects only the data needed to run your home.',
      statusLabel: 'All good.',
      dataCategories: const [],
      permissions: permissions,
      diagnosticSharing: false,
      usageAnalytics: false,
      diagnosticSupported: false,
      analyticsSupported: false,
    );
  }

  @override
  Future<PrivacyPermissionStatus> queryPermission(String permissionId) async =>
      permissions.firstWhere((p) => p.id == permissionId).status;

  @override
  Future<PrivacyPermissionStatus> requestPermission(String permissionId) async =>
      permissions.firstWhere((p) => p.id == permissionId).status;

  @override
  Future<bool> openSettings() async => true;

  @override
  Future<bool> setDiagnosticSharing(bool enabled) async => false;

  @override
  Future<bool> setUsageAnalytics(bool enabled) async => false;
}

/// Repository for testing delayed summary loading and premature route disposal.
class DelayedSummaryPrivacyRepository implements PrivacyRepository {
  DelayedSummaryPrivacyRepository({required this.summaryCompleter});

  final Completer<PrivacySummary> summaryCompleter;

  @override
  Future<PrivacySummary> getSummary() => summaryCompleter.future;

  @override
  Future<PrivacyPermissionStatus> queryPermission(String permissionId) async =>
      PrivacyPermissionStatus.allowed;

  @override
  Future<PrivacyPermissionStatus> requestPermission(String permissionId) async =>
      PrivacyPermissionStatus.allowed;

  @override
  Future<bool> openSettings() async => true;

  @override
  Future<bool> setDiagnosticSharing(bool enabled) async => false;

  @override
  Future<bool> setUsageAnalytics(bool enabled) async => false;
}

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

  group('Group 1: Rapid Lifecycle Churn & State Looping Stress', () {
    testWidgets(
      'Rapid resumed -> inactive -> paused -> resumed loops on PrivacyPage execute without exception or state corruption',
      (tester) async {
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final delegate = AdversarialPermissionDelegate(
          initialStatuses: {
            Permission.bluetoothScan: PermissionStatus.granted,
            Permission.bluetoothConnect: PermissionStatus.granted,
            Permission.notification: PermissionStatus.granted,
            Permission.locationWhenInUse: PermissionStatus.granted,
          },
        );
        final service = AppPermissionService(
          permissionDelegate: delegate,
          platformSdkInfo: FakePlatformSdkInfo(
            platform: TargetPlatform.android,
            sdkVersion: 33,
          ),
          preferences: prefs,
        );
        final repository = PreviewPrivacyRepository(permissionService: service);

        await tester.pumpWidget(
          buildTestApp(
            home: PrivacyPage(repository: repository, permissionService: service),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('PERMISSIONS'), findsOneWidget);

        // Churn lifecycle state 20 times in rapid succession
        for (int i = 0; i < 20; i++) {
          tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
          tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
          tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
          tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
          tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
        }

        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.text('PERMISSIONS'), findsOneWidget);
        expect(find.text('Bluetooth'), findsOneWidget);
        expect(find.text('Notifications'), findsOneWidget);
        expect(find.text('Location'), findsOneWidget);
        expect(find.text('Allowed'), findsNWidgets(2));
        expect(find.text('While using the app'), findsOneWidget);
      },
    );

    testWidgets(
      'Rapid lifecycle churn while queryPermission is delayed on PrivacyPage settles gracefully without errors',
      (tester) async {
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final delegate = AdversarialPermissionDelegate(
          initialStatuses: {
            Permission.bluetoothScan: PermissionStatus.granted,
            Permission.bluetoothConnect: PermissionStatus.granted,
            Permission.notification: PermissionStatus.granted,
            Permission.locationWhenInUse: PermissionStatus.granted,
          },
        );
        final checkCompleter = Completer<PermissionStatus>();
        delegate.pendingCheckCompleter = checkCompleter;

        final service = AppPermissionService(
          permissionDelegate: delegate,
          platformSdkInfo: FakePlatformSdkInfo(
            platform: TargetPlatform.android,
            sdkVersion: 33,
          ),
          preferences: prefs,
        );
        final repository = PreviewPrivacyRepository(permissionService: service);

        await tester.pumpWidget(
          buildTestApp(
            home: PrivacyPage(repository: repository, permissionService: service),
          ),
        );
        await tester.pump(); // Starts loading

        // Fire 10 resume events while first check is still in-flight
        for (int i = 0; i < 10; i++) {
          tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
        }

        // Now resolve checkCompleter
        checkCompleter.complete(PermissionStatus.granted);
        delegate.pendingCheckCompleter = null;

        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.text('PERMISSIONS'), findsOneWidget);
      },
    );

    testWidgets(
      'Rapid lifecycle loops on PrivacyPermissionDetailPage do not cause state corruption or crash',
      (tester) async {
        final delegate = AdversarialPermissionDelegate(
          initialStatuses: {
            Permission.locationWhenInUse: PermissionStatus.granted,
          },
        );
        final service = AppPermissionService(
          permissionDelegate: delegate,
          platformSdkInfo: FakePlatformSdkInfo(
            platform: TargetPlatform.android,
            sdkVersion: 33,
          ),
          preferences: prefs,
        );

        const permission = PrivacyPermission(
          id: 'location',
          title: 'Location',
          description: 'Used for geofencing.',
          status: PrivacyPermissionStatus.whileUsing,
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

        expect(find.text('While using the app'), findsOneWidget);

        // Rapidly churn lifecycle 25 times
        for (int i = 0; i < 25; i++) {
          tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
          tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
          tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
        }

        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.text('While using the app'), findsOneWidget);
        expect(find.text('Current status'), findsOneWidget);
      },
    );
  });

  group('Group 2: Screen Disposal & Async Race Condition Stress', () {
    testWidgets(
      'Popping PrivacyPermissionDetailPage while requestPermission is in-flight does not trigger setState-after-dispose',
      (tester) async {
        final delegate = AdversarialPermissionDelegate(
          initialStatuses: {
            Permission.locationWhenInUse: PermissionStatus.denied,
          },
        );
        final completer = Completer<PermissionStatus>();
        delegate.pendingRequestCompleter = completer;

        final service = AppPermissionService(
          permissionDelegate: delegate,
          platformSdkInfo: FakePlatformSdkInfo(
            platform: TargetPlatform.android,
            sdkVersion: 33,
          ),
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
            home: Navigator(
              onGenerateRoute: (settings) => MaterialPageRoute(
                builder: (context) => Scaffold(
                  body: TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => PrivacyPermissionDetailPage(
                            permission: permission,
                            permissionService: service,
                          ),
                        ),
                      );
                    },
                    child: const Text('Open Detail'),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Open detail page
        await tester.tap(find.text('Open Detail'));
        await tester.pumpAndSettle();

        expect(find.text('Request permission'), findsOneWidget);

        // Tap Request permission (initiates in-flight request)
        await tester.tap(find.text('Request permission'));
        await tester.pump(); // Start async call, shows spinner

        // Pop screen while request is pending
        await tester.pageBack();
        await tester.pump(); // Start pop animation
        await tester.pump(const Duration(milliseconds: 300)); // Finish pop

        expect(find.text('Open Detail'), findsOneWidget);

        // Now resolve the in-flight request
        completer.complete(PermissionStatus.granted);
        await tester.pumpAndSettle();

        // No setState after dispose exception should have occurred
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'Popping PrivacyPermissionDetailPage while openSettings is in-flight does not trigger exceptions',
      (tester) async {
        final delegate = AdversarialPermissionDelegate(
          initialStatuses: {
            Permission.bluetoothScan: PermissionStatus.permanentlyDenied,
            Permission.bluetoothConnect: PermissionStatus.permanentlyDenied,
          },
        );
        final settingsCompleter = Completer<bool>();
        delegate.pendingSettingsCompleter = settingsCompleter;

        final service = AppPermissionService(
          permissionDelegate: delegate,
          platformSdkInfo: FakePlatformSdkInfo(
            platform: TargetPlatform.android,
            sdkVersion: 33,
          ),
          preferences: prefs,
        );

        const permission = PrivacyPermission(
          id: 'bluetooth',
          title: 'Bluetooth',
          description: 'Used to discover devices.',
          status: PrivacyPermissionStatus.permanentlyDenied,
        );

        await tester.pumpWidget(
          buildTestApp(
            home: Navigator(
              onGenerateRoute: (settings) => MaterialPageRoute(
                builder: (context) => Scaffold(
                  body: TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => PrivacyPermissionDetailPage(
                            permission: permission,
                            permissionService: service,
                          ),
                        ),
                      );
                    },
                    child: const Text('Open Detail'),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Open Detail'));
        await tester.pumpAndSettle();

        expect(find.text('Open system settings'), findsOneWidget);

        // Tap open settings
        await tester.tap(find.text('Open system settings'));
        await tester.pump();

        // Pop screen while settings call is pending
        await tester.pageBack();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.text('Open Detail'), findsOneWidget);

        settingsCompleter.complete(true);
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'Popping PrivacyPermissionDetailPage immediately while initState _refreshStatus is pending',
      (tester) async {
        final delegate = AdversarialPermissionDelegate(
          initialStatuses: {
            Permission.locationWhenInUse: PermissionStatus.denied,
          },
        );
        final checkCompleter = Completer<PermissionStatus>();
        delegate.pendingCheckCompleter = checkCompleter;

        final service = AppPermissionService(
          permissionDelegate: delegate,
          platformSdkInfo: FakePlatformSdkInfo(
            platform: TargetPlatform.android,
            sdkVersion: 33,
          ),
          preferences: prefs,
        );

        const permission = PrivacyPermission(
          id: 'location',
          title: 'Location',
          description: 'Used for location.',
          status: PrivacyPermissionStatus.notRequested,
        );

        await tester.pumpWidget(
          buildTestApp(
            home: Navigator(
              onGenerateRoute: (settings) => MaterialPageRoute(
                builder: (context) => Scaffold(
                  body: TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => PrivacyPermissionDetailPage(
                            permission: permission,
                            permissionService: service,
                          ),
                        ),
                      );
                    },
                    child: const Text('Open Detail'),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Tap to open detail
        await tester.tap(find.text('Open Detail'));
        await tester.pump(); // Start push animation

        // Immediately pop before checkCompleter resolves
        await tester.pageBack();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.text('Open Detail'), findsOneWidget);

        // Now resolve checkCompleter
        checkCompleter.complete(PermissionStatus.granted);
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'Popping PrivacyPage while getSummary is in-flight does not cause crash or memory leak',
      (tester) async {
        final completer = Completer<PrivacySummary>();
        final repo = DelayedSummaryPrivacyRepository(summaryCompleter: completer);

        await tester.pumpWidget(
          buildTestApp(
            home: Navigator(
              onGenerateRoute: (settings) => MaterialPageRoute(
                builder: (context) => Scaffold(
                  body: TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => PrivacyPage(repository: repo),
                        ),
                      );
                    },
                    child: const Text('Open Privacy'),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Push PrivacyPage
        await tester.tap(find.text('Open Privacy'));
        await tester.pump(); // Starts push animation
        await tester.pump(const Duration(milliseconds: 300));

        // It shows CircularProgressIndicator while waiting for summary
        expect(find.byType(CircularProgressIndicator), findsOneWidget);

        // Pop screen before summary completes
        await tester.pageBack();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.text('Open Privacy'), findsOneWidget);

        // Complete summary now
        completer.complete(
          const PrivacySummary(
            title: 'Title',
            subtitle: 'Sub',
            statusLabel: 'OK',
            dataCategories: [],
            permissions: [],
            diagnosticSharing: false,
            usageAnalytics: false,
            diagnosticSupported: false,
            analyticsSupported: false,
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
      },
    );
  });

  group('Group 3: Detail Screen & Main Screen State Synchronization Stress', () {
    testWidgets(
      'Simulating permission change in OS settings while on detail page updates both detail page and main page upon pop',
      (tester) async {
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final delegate = AdversarialPermissionDelegate(
          initialStatuses: {
            Permission.bluetoothScan: PermissionStatus.granted,
            Permission.bluetoothConnect: PermissionStatus.granted,
            Permission.notification: PermissionStatus.granted,
            Permission.locationWhenInUse: PermissionStatus.denied,
          },
        );
        final service = AppPermissionService(
          permissionDelegate: delegate,
          platformSdkInfo: FakePlatformSdkInfo(
            platform: TargetPlatform.android,
            sdkVersion: 33,
          ),
          preferences: prefs,
        );
        final repository = PreviewPrivacyRepository(permissionService: service);

        await tester.pumpWidget(
          buildTestApp(
            home: PrivacyPage(repository: repository, permissionService: service),
          ),
        );
        await tester.pumpAndSettle();

        // Location is initially Not requested
        expect(find.text('Not requested'), findsOneWidget);

        // Tap Location to navigate to detail
        await tester.tap(find.text('Location'));
        await tester.pumpAndSettle();

        expect(find.text('Current status'), findsOneWidget);
        expect(find.text('Not requested'), findsOneWidget);

        // User switches to system settings, grants location, and resumes app
        delegate.statuses[Permission.locationWhenInUse] = PermissionStatus.granted;
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
        await tester.pumpAndSettle();

        // Detail page must reflect new status
        expect(find.text('While using the app'), findsOneWidget);
        expect(find.text('Not requested'), findsNothing);

        // Pop back to PrivacyPage
        await tester.pageBack();
        await tester.pumpAndSettle();

        // PrivacyPage must reflect new status without page reload
        expect(find.text('PERMISSIONS'), findsOneWidget);
        expect(find.text('While using the app'), findsOneWidget);
        expect(find.text('Not requested'), findsNothing);
      },
    );

    testWidgets(
      'In-app permission grant on detail page synchronizes immediately to PrivacyPage upon pop',
      (tester) async {
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final delegate = AdversarialPermissionDelegate(
          initialStatuses: {
            Permission.bluetoothScan: PermissionStatus.denied,
            Permission.bluetoothConnect: PermissionStatus.denied,
            Permission.notification: PermissionStatus.granted,
            Permission.locationWhenInUse: PermissionStatus.granted,
          },
        );
        final service = AppPermissionService(
          permissionDelegate: delegate,
          platformSdkInfo: FakePlatformSdkInfo(
            platform: TargetPlatform.android,
            sdkVersion: 33,
          ),
          preferences: prefs,
        );
        final repository = PreviewPrivacyRepository(permissionService: service);

        await tester.pumpWidget(
          buildTestApp(
            home: PrivacyPage(repository: repository, permissionService: service),
          ),
        );
        await tester.pumpAndSettle();

        // Bluetooth initially Not requested
        expect(find.text('Not requested'), findsOneWidget);

        // Tap Bluetooth row
        await tester.tap(find.text('Bluetooth'));
        await tester.pumpAndSettle();

        expect(find.text('Current status'), findsOneWidget);
        expect(find.text('Not requested'), findsOneWidget);

        // Tap Request permission on detail page
        await tester.tap(find.text('Request permission'));
        await tester.pumpAndSettle();

        // Detail page reflects Allowed
        expect(find.text('Allowed'), findsOneWidget);
        expect(find.text('Not requested'), findsNothing);

        // Pop back to PrivacyPage
        await tester.pageBack();
        await tester.pumpAndSettle();

        // Both Bluetooth and Notifications should now be Allowed
        expect(find.text('PERMISSIONS'), findsOneWidget);
        expect(find.text('Allowed'), findsNWidgets(2)); // Bluetooth and Notifications
        expect(find.text('Not requested'), findsNothing);
      },
    );

    testWidgets(
      'Sequential permission grants across Bluetooth, Notifications, and Location remain synchronized',
      (tester) async {
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final delegate = AdversarialPermissionDelegate(
          initialStatuses: {
            Permission.bluetoothScan: PermissionStatus.denied,
            Permission.bluetoothConnect: PermissionStatus.denied,
            Permission.notification: PermissionStatus.denied,
            Permission.locationWhenInUse: PermissionStatus.denied,
          },
        );
        final service = AppPermissionService(
          permissionDelegate: delegate,
          platformSdkInfo: FakePlatformSdkInfo(
            platform: TargetPlatform.android,
            sdkVersion: 33,
          ),
          preferences: prefs,
        );
        final repository = PreviewPrivacyRepository(permissionService: service);

        await tester.pumpWidget(
          buildTestApp(
            home: PrivacyPage(repository: repository, permissionService: service),
          ),
        );
        await tester.pumpAndSettle();

        // Initially all 3 are Not requested
        expect(find.text('Not requested'), findsNWidgets(3));

        // 1. Grant Bluetooth
        await tester.tap(find.text('Bluetooth'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Request permission'));
        await tester.pumpAndSettle();
        await tester.pageBack();
        await tester.pumpAndSettle();

        expect(find.text('Allowed'), findsOneWidget);
        expect(find.text('Not requested'), findsNWidgets(2));

        // 2. Grant Notifications
        await tester.tap(find.text('Notifications'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Request permission'));
        await tester.pumpAndSettle();
        await tester.pageBack();
        await tester.pumpAndSettle();

        expect(find.text('Allowed'), findsNWidgets(2));
        expect(find.text('Not requested'), findsOneWidget);

        // 3. Grant Location
        await tester.tap(find.text('Location'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Request permission'));
        await tester.pumpAndSettle();
        await tester.pageBack();
        await tester.pumpAndSettle();

        expect(find.text('Allowed'), findsNWidgets(2));
        expect(find.text('While using the app'), findsOneWidget);
        expect(find.text('Not requested'), findsNothing);
      },
    );
  });

  group('Group 4: Narrow Screen (320px) and Dark Theme Layout Stress', () {
    testWidgets(
      'PrivacyPage renders all 6 permission statuses on narrow 320px screen without overflow (Light Theme)',
      (tester) async {
        tester.view.physicalSize = const Size(320, 640);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        // Set 1: allowed, whileUsing, permanentlyDenied
        final mockRepo1 = FakeCustomSummaryPrivacyRepository(
          permissions: const [
            PrivacyPermission(
              id: 'bluetooth',
              title: 'Bluetooth',
              description: 'Used to discover and connect devices in your home.',
              status: PrivacyPermissionStatus.allowed,
            ),
            PrivacyPermission(
              id: 'notifications',
              title: 'Notifications',
              description: 'Used for critical alerts and updates.',
              status: PrivacyPermissionStatus.whileUsing,
            ),
            PrivacyPermission(
              id: 'location',
              title: 'Location',
              description: 'Used for geofencing and automation routines.',
              status: PrivacyPermissionStatus.permanentlyDenied,
            ),
          ],
        );

        await tester.pumpWidget(
          buildTestApp(
            themeMode: ThemeMode.light,
            home: PrivacyPage(repository: mockRepo1),
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.text('Allowed'), findsOneWidget);
        expect(find.text('While using the app'), findsOneWidget);
        expect(find.text('Permanently denied'), findsOneWidget);

        // Set 2: denied, notRequested, unavailable
        final mockRepo2 = FakeCustomSummaryPrivacyRepository(
          permissions: const [
            PrivacyPermission(
              id: 'bluetooth',
              title: 'Bluetooth',
              description: 'Used to discover and connect devices in your home.',
              status: PrivacyPermissionStatus.denied,
            ),
            PrivacyPermission(
              id: 'notifications',
              title: 'Notifications',
              description: 'Used for critical alerts and updates.',
              status: PrivacyPermissionStatus.notRequested,
            ),
            PrivacyPermission(
              id: 'location',
              title: 'Location',
              description: 'Used for geofencing and automation routines.',
              status: PrivacyPermissionStatus.unavailable,
            ),
          ],
        );

        await tester.pumpWidget(
          buildTestApp(
            themeMode: ThemeMode.light,
            home: PrivacyPage(repository: mockRepo2),
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.text('Denied'), findsOneWidget);
        expect(find.text('Not requested'), findsOneWidget);
        expect(find.text('Unavailable'), findsOneWidget);
      },
    );

    testWidgets(
      'PrivacyPage renders all 6 permission statuses on narrow 320px screen without overflow (Dark Theme)',
      (tester) async {
        tester.view.physicalSize = const Size(320, 640);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        // Set 1: allowed, whileUsing, permanentlyDenied in Dark Theme
        final mockRepo1 = FakeCustomSummaryPrivacyRepository(
          permissions: const [
            PrivacyPermission(
              id: 'bluetooth',
              title: 'Bluetooth',
              description: 'Used to discover and connect devices in your home.',
              status: PrivacyPermissionStatus.allowed,
            ),
            PrivacyPermission(
              id: 'notifications',
              title: 'Notifications',
              description: 'Used for critical alerts and updates.',
              status: PrivacyPermissionStatus.whileUsing,
            ),
            PrivacyPermission(
              id: 'location',
              title: 'Location',
              description: 'Used for geofencing and automation routines.',
              status: PrivacyPermissionStatus.permanentlyDenied,
            ),
          ],
        );

        await tester.pumpWidget(
          buildTestApp(
            themeMode: ThemeMode.dark,
            home: PrivacyPage(repository: mockRepo1),
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.text('Allowed'), findsOneWidget);
        expect(find.text('While using the app'), findsOneWidget);
        expect(find.text('Permanently denied'), findsOneWidget);

        // Set 2: denied, notRequested, unavailable in Dark Theme
        final mockRepo2 = FakeCustomSummaryPrivacyRepository(
          permissions: const [
            PrivacyPermission(
              id: 'bluetooth',
              title: 'Bluetooth',
              description: 'Used to discover and connect devices in your home.',
              status: PrivacyPermissionStatus.denied,
            ),
            PrivacyPermission(
              id: 'notifications',
              title: 'Notifications',
              description: 'Used for critical alerts and updates.',
              status: PrivacyPermissionStatus.notRequested,
            ),
            PrivacyPermission(
              id: 'location',
              title: 'Location',
              description: 'Used for geofencing and automation routines.',
              status: PrivacyPermissionStatus.unavailable,
            ),
          ],
        );

        await tester.pumpWidget(
          buildTestApp(
            themeMode: ThemeMode.dark,
            home: PrivacyPage(repository: mockRepo2),
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.text('Denied'), findsOneWidget);
        expect(find.text('Not requested'), findsOneWidget);
        expect(find.text('Unavailable'), findsOneWidget);
      },
    );

    testWidgets(
      'PrivacyPermissionDetailPage renders permanentlyDenied guidance card on 320px screen without overflow (Light Theme)',
      (tester) async {
        tester.view.physicalSize = const Size(320, 1000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final delegate = AdversarialPermissionDelegate(
          initialStatuses: {
            Permission.locationWhenInUse: PermissionStatus.permanentlyDenied,
          },
        );
        final service = AppPermissionService(
          permissionDelegate: delegate,
          platformSdkInfo: FakePlatformSdkInfo(
            platform: TargetPlatform.android,
            sdkVersion: 33,
          ),
          preferences: prefs,
        );

        const permission = PrivacyPermission(
          id: 'location',
          title: 'Location',
          description:
              'Used for location-based automation and presence detection routines.',
          status: PrivacyPermissionStatus.permanentlyDenied,
        );

        await tester.pumpWidget(
          buildTestApp(
            themeMode: ThemeMode.light,
            home: PrivacyPermissionDetailPage(
              permission: permission,
              permissionService: service,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.text('Permission permanently denied'), findsOneWidget);
        expect(find.text('Open system settings'), findsOneWidget);
      },
    );

    testWidgets(
      'PrivacyPermissionDetailPage renders permanentlyDenied guidance card on 320px screen without overflow (Dark Theme)',
      (tester) async {
        tester.view.physicalSize = const Size(320, 1000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final delegate = AdversarialPermissionDelegate(
          initialStatuses: {
            Permission.locationWhenInUse: PermissionStatus.permanentlyDenied,
          },
        );
        final service = AppPermissionService(
          permissionDelegate: delegate,
          platformSdkInfo: FakePlatformSdkInfo(
            platform: TargetPlatform.android,
            sdkVersion: 33,
          ),
          preferences: prefs,
        );

        const permission = PrivacyPermission(
          id: 'location',
          title: 'Location',
          description:
              'Used for location-based automation and presence detection routines.',
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

        expect(tester.takeException(), isNull);
        expect(find.text('Permission permanently denied'), findsOneWidget);
        expect(find.text('Open system settings'), findsOneWidget);
      },
    );

    testWidgets(
      'PrivacyPermissionDetailPage renders under extreme font scale (1.5x) on 320px screen without overflow',
      (tester) async {
        tester.view.physicalSize = const Size(320, 640);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final delegate = AdversarialPermissionDelegate(
          initialStatuses: {
            Permission.bluetoothScan: PermissionStatus.permanentlyDenied,
            Permission.bluetoothConnect: PermissionStatus.permanentlyDenied,
          },
        );
        final service = AppPermissionService(
          permissionDelegate: delegate,
          platformSdkInfo: FakePlatformSdkInfo(
            platform: TargetPlatform.android,
            sdkVersion: 33,
          ),
          preferences: prefs,
        );

        const permission = PrivacyPermission(
          id: 'bluetooth',
          title: 'Bluetooth',
          description: 'Used to discover and pair devices.',
          status: PrivacyPermissionStatus.permanentlyDenied,
        );

        await tester.pumpWidget(
          MaterialApp(
            theme: EHAppTheme.lightTheme,
            home: MediaQuery(
              data: const MediaQueryData(
                size: Size(320, 640),
                textScaler: TextScaler.linear(1.5),
              ),
              child: PrivacyPermissionDetailPage(
                permission: permission,
                permissionService: service,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.text('Permission permanently denied'), findsOneWidget);
        expect(find.text('Open system settings'), findsOneWidget);
      },
    );
  });

  group('Group 5: Adversarial Edge Cases & Hostile Environment Stress', () {
    testWidgets(
      'Double-tapping "Request permission" button is properly debounced',
      (tester) async {
        final delegate = AdversarialPermissionDelegate(
          initialStatuses: {
            Permission.locationWhenInUse: PermissionStatus.denied,
          },
        );
        final completer = Completer<PermissionStatus>();
        delegate.pendingRequestCompleter = completer;

        final service = AppPermissionService(
          permissionDelegate: delegate,
          platformSdkInfo: FakePlatformSdkInfo(
            platform: TargetPlatform.android,
            sdkVersion: 33,
          ),
          preferences: prefs,
        );

        const permission = PrivacyPermission(
          id: 'location',
          title: 'Location',
          description: 'Used for location.',
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

        // Tap once
        await tester.tap(find.text('Request permission'));
        await tester.pump(); // Starts request, button shows spinner

        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        // Attempt second tap while first is in-flight
        await tester.tap(find.byType(FilledButton), warnIfMissed: false);
        await tester.pump();

        expect(delegate.requestCount, equals(1));

        // Complete request
        completer.complete(PermissionStatus.granted);
        await tester.pumpAndSettle();

        expect(find.text('While using the app'), findsOneWidget);
        expect(delegate.requestCount, equals(1));
      },
    );

    testWidgets(
      'Platform exception during checkStatus does not crash PrivacyPage',
      (tester) async {
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final delegate = AdversarialPermissionDelegate(
          initialStatuses: {
            Permission.bluetoothScan: PermissionStatus.granted,
          },
        );
        delegate.shouldThrowOnCheck = true;

        final service = AppPermissionService(
          permissionDelegate: delegate,
          platformSdkInfo: FakePlatformSdkInfo(
            platform: TargetPlatform.android,
            sdkVersion: 33,
          ),
          preferences: prefs,
        );
        final repository = PreviewPrivacyRepository(permissionService: service);

        await tester.pumpWidget(
          buildTestApp(
            home: PrivacyPage(repository: repository, permissionService: service),
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        // AppPermissionService catches exceptions and returns unavailable
        expect(find.text('Unavailable'), findsWidgets);
      },
    );

    testWidgets(
      'Platform exception during requestPermission in detail page is handled gracefully',
      (tester) async {
        final delegate = AdversarialPermissionDelegate(
          initialStatuses: {
            Permission.locationWhenInUse: PermissionStatus.denied,
          },
        );
        delegate.shouldThrowOnRequest = true;

        final service = AppPermissionService(
          permissionDelegate: delegate,
          platformSdkInfo: FakePlatformSdkInfo(
            platform: TargetPlatform.android,
            sdkVersion: 33,
          ),
          preferences: prefs,
        );

        const permission = PrivacyPermission(
          id: 'location',
          title: 'Location',
          description: 'Used for location.',
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

        // Tap Request permission
        await tester.tap(find.text('Request permission'));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        // Service catches exception and returns unavailable
        expect(find.text('Unavailable'), findsOneWidget);
      },
    );
  });
}
