import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_home_application_v1/core/models/health_models.dart';
import 'package:smart_home_application_v1/core/repositories/device_health_repository.dart';
import 'package:smart_home_application_v1/core/services/check_timestamp_service.dart';
import 'package:smart_home_application_v1/features/diagnostics/presentation/device_health_page.dart';
import 'package:smart_home_application_v1/features/settings/presentation/settings_ui.dart';

class MockDeviceHealthRepository implements DeviceHealthRepository {
  MockDeviceHealthRepository({
    this.summary,
    this.delay = const Duration(milliseconds: 100),
    this.throwOnCheck = false,
  });

  final HomeHealthSummary? summary;
  final Duration delay;
  final bool throwOnCheck;
  int checkCallCount = 0;

  static final defaultSummary = HomeHealthSummary(
    overall: HomeHealthOverall.healthy,
    title: 'All good!',
    subtitle: 'All devices online.',
    statusLabel: 'Healthy',
    totalDevices: 4,
    onlineCount: 4,
    attentionCount: 0,
    offlineCount: 0,
    lastChecked: DateTime(2026, 8, 15, 9, 40),
    devices: const [],
    rooms: const [
      RoomHealthSummary(
        roomId: 'living',
        roomName: 'Living Room',
        deviceCount: 4,
        issueCount: 0,
        iconKey: 'sofa',
      ),
    ],
  );

  @override
  Future<HomeHealthSummary> getSummary() async {
    return summary ?? defaultSummary;
  }

  @override
  Future<HomeHealthSummary> runFullCheck() async {
    checkCallCount++;
    await Future<void>.delayed(delay);
    if (throwOnCheck) {
      throw Exception('LAN/BLE connection timeout');
    }
    return getSummary();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late CheckTimestampService timestampService;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    timestampService = CheckTimestampService();
    CheckTimestampService.setMockInstance(timestampService);
  });

  tearDown(() {
    CheckTimestampService.setMockInstance(null);
  });

  Widget buildTestApp({DeviceHealthRepository? repository}) {
    return MaterialApp(
      home: DeviceHealthPage(
        repository: repository ?? MockDeviceHealthRepository(),
        timestampService: timestampService,
      ),
    );
  }

  group('Milestone M2: DeviceHealthPage Persistent & Dynamic Timestamps', () {
    testWidgets('1. Initial open with no previous checks displays "Last checked: Never"', (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      // Verify dynamic footer displays "Last checked: Never"
      expect(find.text('Last checked: Never'), findsOneWidget);

      // Verify the old static hardcoded label is NOT present
      expect(find.text('Last checked: Today, 9:40 AM'), findsNothing);
    });

    testWidgets('2. Initial open with persisted check hydrates timestamp dynamically', (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      // Seed SharedPreferences with timestamp from 5 minutes ago
      final fiveMinAgo = DateTime.now().subtract(const Duration(minutes: 5));
      await timestampService.recordSuccessfulCheck(
        CheckTimestampService.deviceHealthKey,
        fiveMinAgo,
      );

      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      expect(find.text('Last checked: 5m ago'), findsOneWidget);
    });

    testWidgets('3. Successful check records completion timestamp and updates footer to "Just now"', (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final mockRepo = MockDeviceHealthRepository(delay: const Duration(milliseconds: 200));
      await tester.pumpWidget(buildTestApp(repository: mockRepo));
      await tester.pumpAndSettle();

      expect(find.text('Last checked: Never'), findsOneWidget);

      // Tap "Check again"
      final checkButton = find.widgetWithText(FilledButton, 'Check again');
      expect(checkButton, findsOneWidget);
      await tester.tap(checkButton);
      await tester.pump(); // Start check

      // In flight: circular progress indicator rendered in footer
      final heroFooter = find.byType(SettingsHeroActionFooter);
      expect(heroFooter, findsOneWidget);
      final footerWidget = tester.widget<SettingsHeroActionFooter>(heroFooter);
      expect(footerWidget.checking, isTrue);

      // Settle check completion
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();

      // Verify recorded in storage
      final stored = await timestampService.getLastSuccessfulCheck(CheckTimestampService.deviceHealthKey);
      expect(stored, isNotNull);
      expect(DateTime.now().difference(stored!).inSeconds, lessThan(5));

      // Verify footer shows "Last checked: Just now"
      expect(find.text('Last checked: Just now'), findsOneWidget);
    });

    testWidgets('4. Check failure preserves previous timestamp and displays error SnackBar', (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      // Seed SharedPreferences with timestamp from 15 minutes ago
      final initialTime = DateTime.now().subtract(const Duration(minutes: 15));
      await timestampService.recordSuccessfulCheck(
        CheckTimestampService.deviceHealthKey,
        initialTime,
      );

      final failingRepo = MockDeviceHealthRepository(
        delay: const Duration(milliseconds: 100),
        throwOnCheck: true,
      );

      await tester.pumpWidget(buildTestApp(repository: failingRepo));
      await tester.pumpAndSettle();

      expect(find.text('Last checked: 15m ago'), findsOneWidget);

      // Tap "Check again"
      await tester.tap(find.widgetWithText(FilledButton, 'Check again'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pumpAndSettle();

      // Verify error snackbar appears
      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.textContaining('Device health check failed'), findsOneWidget);

      // Verify stored timestamp was NOT overwritten and remains initialTime
      final storedAfterFailure = await timestampService.getLastSuccessfulCheck(
        CheckTimestampService.deviceHealthKey,
      );
      expect(storedAfterFailure!.toUtc().toIso8601String(), equals(initialTime.toUtc().toIso8601String()));

      // Verify footer continues displaying 15m ago (never overwritten with "Just now")
      expect(find.text('Last checked: 15m ago'), findsOneWidget);
      expect(find.text('Last checked: Just now'), findsNothing);
    });

    testWidgets('5. Rapid repeated taps on "Check again" and secondary action are debounced', (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final mockRepo = MockDeviceHealthRepository(delay: const Duration(milliseconds: 300));
      await tester.pumpWidget(buildTestApp(repository: mockRepo));
      await tester.pumpAndSettle();

      final checkButton = find.widgetWithText(FilledButton, 'Check again');

      // Tap 5 times rapidly
      await tester.tap(checkButton);
      await tester.tap(checkButton, warnIfMissed: false);
      await tester.tap(checkButton, warnIfMissed: false);
      await tester.tap(checkButton, warnIfMissed: false);
      await tester.tap(checkButton, warnIfMissed: false);

      await tester.pump(); // In flight

      // Verify secondary trigger "Run full health check" is disabled
      final secondaryItem = find.widgetWithText(SettingsListItem, 'Run full health check');
      expect(secondaryItem, findsOneWidget);
      final listItem = tester.widget<SettingsListItem>(secondaryItem);
      expect(listItem.onTap, isNull, reason: 'Secondary button must be disabled while checking is in progress');

      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();

      // Verify repository was called exactly once
      expect(mockRepo.checkCallCount, equals(1));
    });

    testWidgets('6. Dynamic periodic ticking updates relative time without page reload', (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      var currentClock = DateTime(2026, 11, 2, 10, 0, 0);
      final customService = CheckTimestampService(nowProvider: () => currentClock);
      final mockRepo = MockDeviceHealthRepository(delay: const Duration(milliseconds: 50));

      await tester.pumpWidget(MaterialApp(
        home: DeviceHealthPage(
          repository: mockRepo,
          timestampService: customService,
        ),
      ));
      await tester.pumpAndSettle();

      // Perform check
      await tester.tap(find.widgetWithText(FilledButton, 'Check again'));
      await tester.pumpAndSettle();

      expect(find.text('Last checked: Just now'), findsOneWidget);

      // Advance clock by 50 seconds (boundary from <45s to >=45s)
      currentClock = currentClock.add(const Duration(seconds: 50));
      await tester.pump(const Duration(seconds: 15));

      // Periodic 15s timer fired, relative text updated to "1m ago"
      expect(find.text('Last checked: 1m ago'), findsOneWidget);
    });

    testWidgets('7. Screen unmount and remount preserves recorded timestamp', (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final mockRepo = MockDeviceHealthRepository(delay: const Duration(milliseconds: 50));
      await tester.pumpWidget(buildTestApp(repository: mockRepo));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(FilledButton, 'Check again'));
      await tester.pumpAndSettle();

      expect(find.text('Last checked: Just now'), findsOneWidget);

      // Unmount page
      await tester.pumpWidget(const MaterialApp(home: Scaffold(body: Text('Other page'))));
      await tester.pumpAndSettle();
      expect(find.text('Other page'), findsOneWidget);

      // Remount DeviceHealthPage
      await tester.pumpWidget(buildTestApp(repository: mockRepo));
      await tester.pumpAndSettle();

      // Recorded timestamp should be hydrated immediately upon init
      expect(find.text('Last checked: Just now'), findsOneWidget);
    });
  });
}
