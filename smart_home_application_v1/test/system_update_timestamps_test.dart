import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_home_application_v1/core/api/api_client.dart';
import 'package:smart_home_application_v1/core/models/update_models.dart';
import 'package:smart_home_application_v1/core/repositories/cloud_update_repository.dart';
import 'package:smart_home_application_v1/core/repositories/update_repository.dart';
import 'package:smart_home_application_v1/core/services/check_timestamp_service.dart';
import 'package:smart_home_application_v1/features/updates/presentation/system_update_page.dart';

class MockUpdateRepository implements UpdateRepository {
  MockUpdateRepository({
    this.summary,
    this.delay = const Duration(milliseconds: 100),
    this.throwOnCheck = false,
    this.returnUnavailable = false,
  });

  final UpdateSummary? summary;
  final Duration delay;
  final bool throwOnCheck;
  final bool returnUnavailable;
  int checkCallCount = 0;

  static final defaultSummary = UpdateSummary(
    overallStatus: UpdateOverallStatus.upToDate,
    title: 'Everything is up to date',
    subtitle: 'All devices running verified firmware.',
    statusLabel: 'Up to date',
    lastChecked: DateTime(2026, 8, 15, 9, 40),
    targets: const [],
    history: const [],
  );

  @override
  Future<UpdateSummary> getSummary() async => summary ?? defaultSummary;

  @override
  Future<UpdateSummary> checkForUpdates() async {
    checkCallCount++;
    await Future<void>.delayed(delay);
    if (throwOnCheck) {
      throw Exception('Server unreachable');
    }
    if (returnUnavailable) {
      return UpdateSummary(
        overallStatus: UpdateOverallStatus.unavailable,
        title: 'Internet Connection Required',
        subtitle: 'Cannot check for updates offline.',
        statusLabel: 'Internet Required',
        lastChecked: summary?.lastChecked ?? DateTime(2026, 8, 15, 9, 40),
        targets: const [],
        history: const [],
        errorType: UpdateErrorType.noInternet,
      );
    }
    return getSummary();
  }
}

class MockApiClient extends ApiClient {
  MockApiClient({this.throwError = false}) : super(baseUrl: 'http://127.0.0.1:8080');

  final bool throwError;
  int getCalls = 0;

  @override
  Future<dynamic> get(String path, {Map<String, String>? headers}) async {
    getCalls++;
    if (throwError) {
      throw Exception('Failed host lookup');
    }
    return {
      'devices': [],
      'success': true,
    };
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

  Widget buildTestApp({
    Key? key,
    UpdateRepository? repository,
    CheckTimestampService? service,
  }) {
    return MaterialApp(
      home: SystemUpdatePage(
        key: key,
        repository: repository ?? MockUpdateRepository(),
        timestampService: service ?? timestampService,
      ),
    );
  }

  group('Milestone M2: SystemUpdatePage & CloudUpdateRepository Timestamps', () {
    testWidgets('1. Permanent "Checked: Just now" bug eliminated on initial load with past timestamp', (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      // Pre-populate storage with timestamp from 3 hours ago today
      final now = DateTime.now();
      final threeHoursAgo = now.subtract(const Duration(hours: 3));
      await timestampService.recordSuccessfulCheck(
        CheckTimestampService.systemUpdateKey,
        threeHoursAgo,
      );

      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      // Must display Today or calendar time, NEVER "Just now"
      expect(find.textContaining('Checked: Today,'), findsOneWidget);
      expect(find.text('Checked: Just now'), findsNothing);
    });

    testWidgets('2. Date formatter accurately formats past dates (Yesterday, Older dates)', (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      // Part A: Yesterday at 9:40 AM
      final now = DateTime.now();
      final yesterday940 = DateTime(now.year, now.month, now.day - 1, 9, 40);
      await timestampService.recordSuccessfulCheck(
        CheckTimestampService.systemUpdateKey,
        yesterday940,
      );

      await tester.pumpWidget(buildTestApp(key: const ValueKey('yesterday')));
      await tester.pumpAndSettle();

      expect(find.text('Checked: Yesterday, 9:40 AM'), findsOneWidget);
      expect(find.textContaining('Checked: Today,'), findsNothing);

      // Part B: Aug 15 at 9:40 AM
      final aug15 = DateTime(now.year, 8, 15, 9, 40);
      await timestampService.recordSuccessfulCheck(
        CheckTimestampService.systemUpdateKey,
        aug15,
      );

      await tester.pumpWidget(buildTestApp(key: const ValueKey('aug15')));
      await tester.pumpAndSettle();

      expect(find.text('Checked: Aug 15, 9:40 AM'), findsOneWidget);
    });

    testWidgets('3. Initial load with no previous checks displays "Checked: Never"', (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(buildTestApp(repository: const PreviewUpdateRepository()));
      await tester.pumpAndSettle();

      expect(find.text('Checked: Never'), findsOneWidget);
    });

    testWidgets('4. Successful update check records completion timestamp and updates header to "Checked: Just now"', (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final mockRepo = MockUpdateRepository(delay: const Duration(milliseconds: 200));
      await tester.pumpWidget(buildTestApp(repository: mockRepo));
      await tester.pumpAndSettle();

      final checkButton = find.widgetWithText(ElevatedButton, 'Check now');
      expect(checkButton, findsOneWidget);

      await tester.tap(checkButton);
      await tester.pump();

      // In flight: button displays Checking...
      expect(find.text('Checking...'), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();

      // Stored in CheckTimestampService
      final stored = await timestampService.getLastSuccessfulCheck(CheckTimestampService.systemUpdateKey);
      expect(stored, isNotNull);
      expect(DateTime.now().difference(stored!).inSeconds, lessThan(5));

      // Header updated
      expect(find.text('Checked: Just now'), findsOneWidget);
    });

    testWidgets('5. Update check error/unavailable preserves previous timestamp and displays warning SnackBar', (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final initialTime = DateTime.now().subtract(const Duration(minutes: 15));
      await timestampService.recordSuccessfulCheck(
        CheckTimestampService.systemUpdateKey,
        initialTime,
      );

      final errorRepo = MockUpdateRepository(
        delay: const Duration(milliseconds: 100),
        returnUnavailable: true,
      );

      await tester.pumpWidget(buildTestApp(repository: errorRepo));
      await tester.pumpAndSettle();

      expect(find.text('Checked: 15m ago'), findsOneWidget);

      await tester.tap(find.widgetWithText(ElevatedButton, 'Check now'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pumpAndSettle();

      // Error SnackBar appears
      expect(find.byType(SnackBar), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(SnackBar),
          matching: find.textContaining('Cannot check for updates offline'),
        ),
        findsOneWidget,
      );

      // Previous timestamp preserved in storage
      final storedAfterError = await timestampService.getLastSuccessfulCheck(CheckTimestampService.systemUpdateKey);
      expect(storedAfterError!.toUtc().toIso8601String(), equals(initialTime.toUtc().toIso8601String()));

      // Header still displays 15m ago, never "Just now"
      expect(find.text('Checked: 15m ago'), findsOneWidget);
      expect(find.text('Checked: Just now'), findsNothing);
    });

    testWidgets('6. Rapid repeated taps on "Check now" are debounced', (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final mockRepo = MockUpdateRepository(delay: const Duration(milliseconds: 300));
      await tester.pumpWidget(buildTestApp(repository: mockRepo));
      await tester.pumpAndSettle();

      final checkButton = find.widgetWithText(ElevatedButton, 'Check now');

      // Tap multiple times in rapid succession
      await tester.tap(checkButton);
      await tester.tap(checkButton, warnIfMissed: false);
      await tester.tap(checkButton, warnIfMissed: false);
      await tester.tap(checkButton, warnIfMissed: false);

      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();

      expect(mockRepo.checkCallCount, equals(1));
    });

    testWidgets('7. CloudUpdateRepository does not stamp DateTime.now() on passive getSummary() or on error', (tester) async {
      final initialTime = DateTime(2026, 11, 2, 8, 30);
      await timestampService.recordSuccessfulCheck(
        CheckTimestampService.systemUpdateKey,
        initialTime,
      );

      // Part A: Passive getSummary() preserves stored timestamp
      final successClient = MockApiClient(throwError: false);
      final repo = CloudUpdateRepository(
        apiClient: successClient,
        timestampService: timestampService,
      );

      final summary = await repo.getSummary();
      expect(summary.lastChecked.toUtc(), equals(initialTime.toUtc()));
      expect(summary.lastChecked.isAtSameMomentAs(DateTime.now()), isFalse);

      // Part B: Network error preserves stored timestamp
      final errorClient = MockApiClient(throwError: true);
      final errorRepo = CloudUpdateRepository(
        apiClient: errorClient,
        timestampService: timestampService,
      );

      final errorSummary = await errorRepo.getSummary();
      expect(errorSummary.isUnavailable, isTrue);
      expect(errorSummary.lastChecked.toUtc(), equals(initialTime.toUtc()));
    });

    testWidgets('8. Dynamic periodic ticking updates relative time without page reload', (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      var currentClock = DateTime(2026, 11, 2, 10, 0, 0);
      final customService = CheckTimestampService(nowProvider: () => currentClock);
      final mockRepo = MockUpdateRepository(delay: const Duration(milliseconds: 50));

      await tester.pumpWidget(buildTestApp(
        repository: mockRepo,
        service: customService,
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(ElevatedButton, 'Check now'));
      await tester.pumpAndSettle();

      expect(find.text('Checked: Just now'), findsOneWidget);

      // Advance clock by 50 seconds
      currentClock = currentClock.add(const Duration(seconds: 50));
      await tester.pump(const Duration(seconds: 15));

      // Header dynamically ticks to "1m ago"
      expect(find.text('Checked: 1m ago'), findsOneWidget);
    });
  });
}
