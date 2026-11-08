import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_home_application_v1/core/models/health_models.dart';
import 'package:smart_home_application_v1/core/models/update_models.dart';
import 'package:smart_home_application_v1/core/repositories/device_health_repository.dart';
import 'package:smart_home_application_v1/core/repositories/update_repository.dart';
import 'package:smart_home_application_v1/core/services/check_timestamp_service.dart';
import 'package:smart_home_application_v1/features/diagnostics/presentation/device_health_page.dart';
import 'package:smart_home_application_v1/features/settings/presentation/settings_ui.dart';
import 'package:smart_home_application_v1/features/updates/presentation/system_update_page.dart';
import 'package:smart_home_application_v1/features/updates/presentation/update_preferences_page.dart';

/// Adversarial mock for DeviceHealthRepository with controllable delay and manual completion.
class AdversarialDeviceHealthRepository implements DeviceHealthRepository {
  AdversarialDeviceHealthRepository({
    this.delay = const Duration(milliseconds: 150),
    this.throwException = false,
    this.exceptionToThrow,
  });

  final Duration delay;
  final bool throwException;
  final Object? exceptionToThrow;

  int checkCallCount = 0;
  Completer<void>? manualCompleter;

  static final defaultSummary = HomeHealthSummary(
    overall: HomeHealthOverall.healthy,
    title: 'All good!',
    subtitle: 'All devices operating normally.',
    statusLabel: 'Healthy',
    totalDevices: 4,
    onlineCount: 4,
    attentionCount: 0,
    offlineCount: 0,
    lastChecked: DateTime(2026, 8, 15, 9, 40),
    devices: const [],
    rooms: const [
      RoomHealthSummary(
        roomId: 'living-room',
        roomName: 'Living Room',
        deviceCount: 4,
        issueCount: 0,
        iconKey: 'sofa',
      ),
    ],
  );

  @override
  Future<HomeHealthSummary> getSummary() async => defaultSummary;

  @override
  Future<HomeHealthSummary> runFullCheck() async {
    checkCallCount++;
    if (manualCompleter != null) {
      await manualCompleter!.future;
    } else {
      await Future<void>.delayed(delay);
    }

    if (throwException) {
      throw exceptionToThrow ?? Exception('Telemetry connection timeout (BLE/LAN bridge unreachable)');
    }

    return defaultSummary;
  }
}

/// Adversarial mock for UpdateRepository with controllable delay, manual completion,
/// and timestampService recording mirroring CloudUpdateRepository.
class AdversarialUpdateRepository implements UpdateRepository {
  AdversarialUpdateRepository({
    this.delay = const Duration(milliseconds: 150),
    this.throwException = false,
    this.exceptionToThrow,
    this.returnUnavailable = false,
    this.unavailableErrorType = UpdateErrorType.noInternet,
    this.timestampService,
  });

  final Duration delay;
  final bool throwException;
  final Object? exceptionToThrow;
  final bool returnUnavailable;
  final UpdateErrorType unavailableErrorType;
  final CheckTimestampService? timestampService;

  int checkCallCount = 0;
  Completer<void>? manualCompleter;

  static final defaultSummary = UpdateSummary(
    overallStatus: UpdateOverallStatus.upToDate,
    title: 'Everything is up to date',
    subtitle: 'Fleet running verified production firmware.',
    statusLabel: 'Up to date',
    lastChecked: DateTime(2026, 8, 15, 9, 40),
    targets: const [],
    history: const [],
  );

  @override
  Future<UpdateSummary> getSummary() async => defaultSummary;

  @override
  Future<UpdateSummary> checkForUpdates() async {
    checkCallCount++;
    if (manualCompleter != null) {
      await manualCompleter!.future;
    } else {
      await Future<void>.delayed(delay);
    }

    if (throwException) {
      throw exceptionToThrow ?? Exception('Failed host lookup: firmware.cloud.smart-home.local');
    }

    if (returnUnavailable) {
      return UpdateSummary(
        overallStatus: UpdateOverallStatus.unavailable,
        title: 'Connection Required',
        subtitle: 'Unable to query firmware catalog offline.',
        statusLabel: 'Offline',
        lastChecked: defaultSummary.lastChecked,
        targets: const [],
        history: const [],
        errorType: unavailableErrorType,
      );
    }

    final ts = timestampService ?? CheckTimestampService.instance;
    await ts.recordSuccessfulCheck(
      CheckTimestampService.systemUpdateKey,
      ts.now,
    );

    return defaultSummary;
  }
}

/// Helper wrapper providing navigation to test pop/unmount during async operations.
Widget buildNavWrapper({
  required Widget Function(BuildContext) pageBuilder,
}) {
  return MaterialApp(
    home: Builder(
      builder: (context) => Scaffold(
        appBar: AppBar(title: const Text('Root Navigator Screen')),
        body: Center(
          child: ElevatedButton(
            key: const ValueKey('open_target_button'),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: pageBuilder),
            ),
            child: const Text('Open Page'),
          ),
        ),
      ),
    ),
  );
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

  group('Adversarial Challenge M2: DeviceHealthPage UI Reentrancy & Concurrency', () {
    testWidgets('1. Rapid 10-tap loop on "Check again" triggers only 1 repository check', (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final repo = AdversarialDeviceHealthRepository(delay: const Duration(milliseconds: 200));
      await tester.pumpWidget(MaterialApp(
        home: DeviceHealthPage(
          repository: repo,
          timestampService: timestampService,
        ),
      ));
      await tester.pumpAndSettle();

      final checkButton = find.widgetWithText(FilledButton, 'Check again');
      expect(checkButton, findsOneWidget);

      // Rapidly fire 10 taps in a tight loop without waiting for animations
      for (int i = 0; i < 10; i++) {
        await tester.tap(checkButton, warnIfMissed: false);
      }

      await tester.pump(); // Enter checking state

      // Verify checking state active
      final heroFooter = find.byType(SettingsHeroActionFooter);
      expect(heroFooter, findsOneWidget);
      final footer = tester.widget<SettingsHeroActionFooter>(heroFooter);
      expect(footer.checking, isTrue);

      // Settle check completion
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();

      // Exactly ONE check must have been dispatched
      expect(repo.checkCallCount, equals(1), reason: 'Reentrancy guard failed: multiple calls dispatched!');
      expect(find.text('Last checked: Just now'), findsOneWidget);
    });

    testWidgets('2. Rapid 10-tap loop on secondary "Run full health check" triggers only 1 check', (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final repo = AdversarialDeviceHealthRepository(delay: const Duration(milliseconds: 200));
      await tester.pumpWidget(MaterialApp(
        home: DeviceHealthPage(
          repository: repo,
          timestampService: timestampService,
        ),
      ));
      await tester.pumpAndSettle();

      final secondaryItem = find.widgetWithText(SettingsListItem, 'Run full health check');
      expect(secondaryItem, findsOneWidget);

      // Rapidly tap secondary action 10 times
      for (int i = 0; i < 10; i++) {
        await tester.tap(secondaryItem, warnIfMissed: false);
      }

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();

      expect(repo.checkCallCount, equals(1), reason: 'Secondary action reentrancy guard failed!');
      expect(find.text('Last checked: Just now'), findsOneWidget);
    });

    testWidgets('3. Secondary action is disabled (onTap == null) and ignored while check is in-flight', (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final repo = AdversarialDeviceHealthRepository();
      repo.manualCompleter = Completer<void>();

      await tester.pumpWidget(MaterialApp(
        home: DeviceHealthPage(
          repository: repo,
          timestampService: timestampService,
        ),
      ));
      await tester.pumpAndSettle();

      // Tap primary check button
      await tester.tap(find.widgetWithText(FilledButton, 'Check again'));
      await tester.pump(); // Enter checking state

      // Verify secondary action is disabled
      final secondaryItem = find.widgetWithText(SettingsListItem, 'Run full health check');
      final listItem = tester.widget<SettingsListItem>(secondaryItem);
      expect(listItem.onTap, isNull, reason: 'Secondary action must have null onTap while checking');

      // Attempt to tap disabled secondary button
      await tester.tap(secondaryItem, warnIfMissed: false);
      await tester.pump();

      // Complete manual check
      repo.manualCompleter!.complete();
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pumpAndSettle();

      expect(repo.checkCallCount, equals(1));
    });

    testWidgets('4. Cross-button interleaving: Tapping secondary then primary triggers only 1 check', (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final repo = AdversarialDeviceHealthRepository(delay: const Duration(milliseconds: 250));
      await tester.pumpWidget(MaterialApp(
        home: DeviceHealthPage(
          repository: repo,
          timestampService: timestampService,
        ),
      ));
      await tester.pumpAndSettle();

      // Tap secondary, then immediately tap primary
      await tester.tap(find.widgetWithText(SettingsListItem, 'Run full health check'));
      await tester.tap(find.widgetWithText(FilledButton, 'Check again'), warnIfMissed: false);
      await tester.tap(find.widgetWithText(SettingsListItem, 'Run full health check'), warnIfMissed: false);

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();

      expect(repo.checkCallCount, equals(1), reason: 'Cross-button race condition permitted duplicate check!');
    });
  });

  group('Adversarial Challenge M2: DeviceHealthPage Lifecycle & Disposal Safety', () {
    testWidgets('5. Popping DeviceHealthPage during in-flight successful check produces NO assertion errors and persists timestamp', (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final repo = AdversarialDeviceHealthRepository();
      repo.manualCompleter = Completer<void>();

      await tester.pumpWidget(buildNavWrapper(
        pageBuilder: (_) => DeviceHealthPage(
          repository: repo,
          timestampService: timestampService,
        ),
      ));
      await tester.pumpAndSettle();

      // Open DeviceHealthPage
      await tester.tap(find.byKey(const ValueKey('open_target_button')));
      await tester.pumpAndSettle();
      expect(find.byType(DeviceHealthPage), findsOneWidget);

      // Start check in-flight
      await tester.tap(find.widgetWithText(FilledButton, 'Check again'));
      await tester.pump();
      expect(repo.checkCallCount, equals(1));

      // Pop the route while check is in-flight (simulates back button)
      Navigator.of(tester.element(find.byType(DeviceHealthPage))).pop();
      await tester.pump();
      await tester.pumpAndSettle();
      expect(find.byType(DeviceHealthPage), findsNothing);

      // Complete async check while screen is completely disposed
      repo.manualCompleter!.complete();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpAndSettle();

      // Assert: No "setState() called after dispose()" or unhandled errors!
      expect(tester.takeException(), isNull, reason: 'Disposal during in-flight check threw unhandled exception!');

      // Verify the check completed and persisted to storage
      final stored = await timestampService.getLastSuccessfulCheck(CheckTimestampService.deviceHealthKey);
      expect(stored, isNotNull);

      // Reopen DeviceHealthPage: hydrated timestamp must reflect the background completed check
      await tester.tap(find.byKey(const ValueKey('open_target_button')));
      await tester.pumpAndSettle();
      expect(find.text('Last checked: Just now'), findsOneWidget);
    });

    testWidgets('6. Popping DeviceHealthPage during in-flight failing check produces NO setState or deactivated context errors', (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final initialTime = DateTime.now().subtract(const Duration(minutes: 30));
      await timestampService.recordSuccessfulCheck(CheckTimestampService.deviceHealthKey, initialTime);

      final repo = AdversarialDeviceHealthRepository(
        throwException: true,
        exceptionToThrow: Exception('Adversarial fatal timeout'),
      );
      repo.manualCompleter = Completer<void>();

      await tester.pumpWidget(buildNavWrapper(
        pageBuilder: (_) => DeviceHealthPage(
          repository: repo,
          timestampService: timestampService,
        ),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('open_target_button')));
      await tester.pumpAndSettle();

      // Trigger check
      await tester.tap(find.widgetWithText(FilledButton, 'Check again'));
      await tester.pump();

      // Pop route
      Navigator.of(tester.element(find.byType(DeviceHealthPage))).pop();
      await tester.pump();
      await tester.pumpAndSettle();
      expect(find.byType(DeviceHealthPage), findsNothing);

      // Fail check while disposed
      repo.manualCompleter!.complete();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull, reason: 'Catch block attempted ScaffoldMessenger on unmounted context!');

      // Verify timestamp preserved
      final stored = await timestampService.getLastSuccessfulCheck(CheckTimestampService.deviceHealthKey);
      expect(stored!.toUtc().toIso8601String(), equals(initialTime.toUtc().toIso8601String()));
    });

    testWidgets('7. Immediate unmount during initState hydration produces NO setState-after-dispose errors', (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final repo = AdversarialDeviceHealthRepository();

      await tester.pumpWidget(MaterialApp(
        home: DeviceHealthPage(
          repository: repo,
          timestampService: timestampService,
        ),
      ));
      // Pump only 1 frame before async SharedPreferences read returns
      await tester.pump();

      // Immediately unmount by replacing root widget
      await tester.pumpWidget(const MaterialApp(home: Scaffold(body: Text('Unmounted'))));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  });

  group('Adversarial Challenge M2: DeviceHealthPage Failure Preservation & Dynamic Timer', () {
    testWidgets('8. Network failure displays floating error SnackBar and strictly preserves previous timestamp', (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final initialTime = DateTime.now().subtract(const Duration(hours: 2));
      await timestampService.recordSuccessfulCheck(CheckTimestampService.deviceHealthKey, initialTime);

      final failingRepo = AdversarialDeviceHealthRepository(
        delay: const Duration(milliseconds: 100),
        throwException: true,
        exceptionToThrow: Exception('BLE bridge gateway timeout'),
      );

      await tester.pumpWidget(MaterialApp(
        home: DeviceHealthPage(
          repository: failingRepo,
          timestampService: timestampService,
        ),
      ));
      await tester.pumpAndSettle();

      // Initial state displays formatted 2h ago / Today
      final initialLabel = timestampService.formatDeviceHealthChecked(initialTime);
      expect(find.text(initialLabel), findsOneWidget);

      // Tap check again
      await tester.tap(find.widgetWithText(FilledButton, 'Check again'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pumpAndSettle();

      // Verify SnackBar shown
      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.textContaining('BLE bridge gateway timeout'), findsOneWidget);

      // Verify timestamp preserved in SharedPreferences
      final stored = await timestampService.getLastSuccessfulCheck(CheckTimestampService.deviceHealthKey);
      expect(stored!.toUtc().toIso8601String(), equals(initialTime.toUtc().toIso8601String()));

      // Verify UI label still displays preserved timestamp
      expect(find.text(initialLabel), findsOneWidget);
      expect(find.text('Last checked: Just now'), findsNothing);

      // Verify button is re-enabled
      final heroFooter = tester.widget<SettingsHeroActionFooter>(find.byType(SettingsHeroActionFooter));
      expect(heroFooter.checking, isFalse);
    });

    testWidgets('9. Dynamic 15s timer ticks advance relative time without any user interaction', (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      var currentClock = DateTime(2026, 11, 2, 10, 0, 0);
      final customService = CheckTimestampService(nowProvider: () => currentClock);
      final repo = AdversarialDeviceHealthRepository(delay: const Duration(milliseconds: 50));

      await tester.pumpWidget(MaterialApp(
        home: DeviceHealthPage(
          repository: repo,
          timestampService: customService,
        ),
      ));
      await tester.pumpAndSettle();

      // Perform initial check
      await tester.tap(find.widgetWithText(FilledButton, 'Check again'));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpAndSettle();

      expect(find.text('Last checked: Just now'), findsOneWidget);

      // Advance clock by 46s (> 45s boundary threshold)
      currentClock = currentClock.add(const Duration(seconds: 46));
      // Ticking timer fires every 15s
      await tester.pump(const Duration(seconds: 15));

      // UI must automatically tick to "1m ago" without tapping
      expect(find.text('Last checked: 1m ago'), findsOneWidget);

      // Advance clock to 60m (calendar boundary)
      currentClock = currentClock.add(const Duration(minutes: 60));
      await tester.pump(const Duration(seconds: 15));

      // UI must automatically tick to Today format
      expect(find.textContaining('Last checked: Today,'), findsOneWidget);
    });
  });

  group('Adversarial Challenge M2: SystemUpdatePage UI Reentrancy & Concurrency', () {
    testWidgets('10. Rapid 10-tap loop on "Check now" triggers only 1 repository check', (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final repo = AdversarialUpdateRepository(
        delay: const Duration(milliseconds: 200),
        timestampService: timestampService,
      );
      await tester.pumpWidget(MaterialApp(
        home: SystemUpdatePage(
          repository: repo,
          timestampService: timestampService,
        ),
      ));
      await tester.pumpAndSettle();

      final checkButton = find.widgetWithText(ElevatedButton, 'Check now');
      expect(checkButton, findsOneWidget);

      // Fire 10 rapid taps
      for (int i = 0; i < 10; i++) {
        await tester.tap(checkButton, warnIfMissed: false);
      }

      await tester.pump();
      expect(find.text('Checking...'), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();

      expect(repo.checkCallCount, equals(1), reason: 'Reentrancy guard failed on SystemUpdatePage!');
      expect(find.text('Checked: Just now'), findsOneWidget);
    });

    testWidgets('11. Check now button is disabled (onPressed == null) while checking is in-flight', (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final repo = AdversarialUpdateRepository(timestampService: timestampService);
      repo.manualCompleter = Completer<void>();

      await tester.pumpWidget(MaterialApp(
        home: SystemUpdatePage(
          repository: repo,
          timestampService: timestampService,
        ),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(ElevatedButton, 'Check now'));
      await tester.pump();

      final checkingButtonFinder = find.widgetWithText(ElevatedButton, 'Checking...');
      expect(checkingButtonFinder, findsOneWidget);
      final elevatedButton = tester.widget<ElevatedButton>(checkingButtonFinder);
      expect(elevatedButton.onPressed, isNull, reason: 'Button must have null onPressed during check!');

      repo.manualCompleter!.complete();
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pumpAndSettle();

      expect(repo.checkCallCount, equals(1));
    });

    testWidgets('12. Navigating to Update Preferences while check is in-flight causes no crash or state loss', (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final repo = AdversarialUpdateRepository(
        delay: const Duration(milliseconds: 300),
        timestampService: timestampService,
      );
      await tester.pumpWidget(MaterialApp(
        home: SystemUpdatePage(
          repository: repo,
          timestampService: timestampService,
        ),
      ));
      await tester.pumpAndSettle();

      // Start update check
      await tester.tap(find.widgetWithText(ElevatedButton, 'Check now'));
      await tester.pump();

      // Tap settings action in AppBar to push preferences
      final settingsIcon = find.byTooltip('Update Preferences');
      expect(settingsIcon, findsOneWidget);
      await tester.tap(settingsIcon);
      await tester.pumpAndSettle();

      expect(find.byType(UpdatePreferencesPage), findsOneWidget);

      // Let check complete in the background
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();

      // Pop back to SystemUpdatePage
      Navigator.of(tester.element(find.byType(UpdatePreferencesPage))).pop();
      await tester.pumpAndSettle();

      expect(find.byType(SystemUpdatePage), findsOneWidget);
      expect(find.text('Checked: Just now'), findsOneWidget);
    });
  });

  group('Adversarial Challenge M2: SystemUpdatePage Lifecycle & Disposal Safety', () {
    testWidgets('13. Popping SystemUpdatePage during in-flight successful check cleanly disposes AnimationController without errors', (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final repo = AdversarialUpdateRepository(timestampService: timestampService);
      repo.manualCompleter = Completer<void>();

      await tester.pumpWidget(buildNavWrapper(
        pageBuilder: (_) => SystemUpdatePage(
          repository: repo,
          timestampService: timestampService,
        ),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('open_target_button')));
      await tester.pumpAndSettle();
      expect(find.byType(SystemUpdatePage), findsOneWidget);

      // Start check: AnimationController starts repeating
      await tester.tap(find.widgetWithText(ElevatedButton, 'Check now'));
      await tester.pump();
      expect(find.text('Checking...'), findsOneWidget);

      // Pop page while animation and async call are active
      Navigator.of(tester.element(find.byType(SystemUpdatePage))).pop();
      await tester.pump();
      await tester.pumpAndSettle();
      expect(find.byType(SystemUpdatePage), findsNothing);

      // Finish check while screen is disposed
      repo.manualCompleter!.complete();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpAndSettle();

      // Verify no AnimationController/Ticker assertion failure
      expect(tester.takeException(), isNull, reason: 'AnimationController leaked or stopped after disposal!');

      // Check storage recorded by repository
      final stored = await timestampService.getLastSuccessfulCheck(CheckTimestampService.systemUpdateKey);
      expect(stored, isNotNull);

      // Reopen page to confirm hydrated timestamp
      await tester.tap(find.byKey(const ValueKey('open_target_button')));
      await tester.pumpAndSettle();
      expect(find.text('Checked: Just now'), findsOneWidget);
    });

    testWidgets('14. Popping SystemUpdatePage during in-flight failure handles error without setState or deactivated context leak', (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final initialTime = DateTime.now().subtract(const Duration(hours: 1));
      await timestampService.recordSuccessfulCheck(CheckTimestampService.systemUpdateKey, initialTime);

      final repo = AdversarialUpdateRepository(
        throwException: true,
        exceptionToThrow: Exception('Fatal connection reset by peer'),
        timestampService: timestampService,
      );
      repo.manualCompleter = Completer<void>();

      await tester.pumpWidget(buildNavWrapper(
        pageBuilder: (_) => SystemUpdatePage(
          repository: repo,
          timestampService: timestampService,
        ),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('open_target_button')));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(ElevatedButton, 'Check now'));
      await tester.pump();

      // Pop route
      Navigator.of(tester.element(find.byType(SystemUpdatePage))).pop();
      await tester.pump();
      await tester.pumpAndSettle();

      // Complete with failure
      repo.manualCompleter!.complete();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);

      final stored = await timestampService.getLastSuccessfulCheck(CheckTimestampService.systemUpdateKey);
      expect(stored!.toUtc().toIso8601String(), equals(initialTime.toUtc().toIso8601String()));
    });

    testWidgets('15. Immediate unmount during SystemUpdatePage initState produces NO errors', (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final repo = AdversarialUpdateRepository(timestampService: timestampService);
      await tester.pumpWidget(MaterialApp(
        home: SystemUpdatePage(
          repository: repo,
          timestampService: timestampService,
        ),
      ));
      await tester.pump();

      // Immediately unmount
      await tester.pumpWidget(const MaterialApp(home: Scaffold(body: Text('Unmounted'))));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  });

  group('Adversarial Challenge M2: SystemUpdatePage Failure Preservation & Dynamic Timer', () {
    testWidgets('16. DNS / network failure ("Failed host lookup") shows warning SnackBar and preserves previous timestamp', (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final initialTime = DateTime.now().subtract(const Duration(minutes: 45));
      await timestampService.recordSuccessfulCheck(CheckTimestampService.systemUpdateKey, initialTime);

      final failingRepo = AdversarialUpdateRepository(
        delay: const Duration(milliseconds: 100),
        throwException: true,
        exceptionToThrow: Exception('Failed host lookup: firmware.ota.smart-home.local'),
        timestampService: timestampService,
      );

      await tester.pumpWidget(MaterialApp(
        home: SystemUpdatePage(
          repository: failingRepo,
          timestampService: timestampService,
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Checked: 45m ago'), findsOneWidget);

      await tester.tap(find.widgetWithText(ElevatedButton, 'Check now'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pumpAndSettle();

      // Verify SnackBar
      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.textContaining('Internet connection required'), findsOneWidget);

      // Verify timestamp preserved in SharedPreferences
      final stored = await timestampService.getLastSuccessfulCheck(CheckTimestampService.systemUpdateKey);
      expect(stored!.toUtc().toIso8601String(), equals(initialTime.toUtc().toIso8601String()));

      // Verify UI displays preserved timestamp
      expect(find.text('Checked: 45m ago'), findsOneWidget);
      expect(find.text('Checked: Just now'), findsNothing);
    });

    testWidgets('17. Offline unavailable error response shows floating warning and preserves timestamp', (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final initialTime = DateTime.now().subtract(const Duration(hours: 3));
      await timestampService.recordSuccessfulCheck(CheckTimestampService.systemUpdateKey, initialTime);

      final unavailableRepo = AdversarialUpdateRepository(
        delay: const Duration(milliseconds: 100),
        returnUnavailable: true,
        unavailableErrorType: UpdateErrorType.noInternet,
        timestampService: timestampService,
      );

      await tester.pumpWidget(MaterialApp(
        home: SystemUpdatePage(
          repository: unavailableRepo,
          timestampService: timestampService,
        ),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(ElevatedButton, 'Check now'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pumpAndSettle();

      expect(find.byType(SnackBar), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(SnackBar),
          matching: find.textContaining('Unable to query firmware catalog offline'),
        ),
        findsOneWidget,
      );

      final stored = await timestampService.getLastSuccessfulCheck(CheckTimestampService.systemUpdateKey);
      expect(stored!.toUtc().toIso8601String(), equals(initialTime.toUtc().toIso8601String()));

      expect(find.text('Checked: Just now'), findsNothing);
    });

    testWidgets('18. Dynamic 15s timer ticks advance relative time without user interaction', (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      var currentClock = DateTime(2026, 11, 2, 10, 0, 0);
      final customService = CheckTimestampService(nowProvider: () => currentClock);
      final repo = AdversarialUpdateRepository(
        delay: const Duration(milliseconds: 50),
        timestampService: customService,
      );

      await tester.pumpWidget(MaterialApp(
        home: SystemUpdatePage(
          repository: repo,
          timestampService: customService,
        ),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(ElevatedButton, 'Check now'));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpAndSettle();

      expect(find.text('Checked: Just now'), findsOneWidget);

      // Advance clock by 46s
      currentClock = currentClock.add(const Duration(seconds: 46));
      await tester.pump(const Duration(seconds: 15));

      // Automatically updates to "1m ago"
      expect(find.text('Checked: 1m ago'), findsOneWidget);

      // Advance clock by 10m (total elapsed 10m 46s)
      currentClock = currentClock.add(const Duration(minutes: 10));
      await tester.pump(const Duration(seconds: 15));

      // Automatically updates to "10m ago"
      expect(find.text('Checked: 10m ago'), findsOneWidget);
    });
  });
}
