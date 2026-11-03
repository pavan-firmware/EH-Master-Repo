import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_home_application_v1/core/services/check_timestamp_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late CheckTimestampService service;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    CheckTimestampService.setMockInstance(null);
    service = CheckTimestampService();
  });

  tearDown(() {
    CheckTimestampService.setMockInstance(null);
  });

  group('Challenger M2: Boundary Condition Precision Stress', () {
    final ref = DateTime(2026, 11, 2, 14, 0, 0); // Reference: Nov 2, 2026, 2:00:00 PM

    test('Zero elapsed time (now == timestamp) returns "Just now"', () {
      expect(service.formatRelativeTime(ref, now: ref), equals('Just now'));
      expect(service.formatDeviceHealthChecked(ref, now: ref), equals('Last checked: Just now'));
      expect(service.formatSystemUpdateChecked(ref, now: ref), equals('Checked: Just now'));
    });

    test('44s boundary: 44s 0ms and 44s 999ms strictly format as "Just now"', () {
      final elapsed44s = ref.subtract(const Duration(seconds: 44));
      final elapsed44s999ms = ref.subtract(const Duration(seconds: 44, milliseconds: 999));

      expect(service.formatRelativeTime(elapsed44s, now: ref), equals('Just now'));
      expect(service.formatRelativeTime(elapsed44s999ms, now: ref), equals('Just now'));
    });

    test('45s boundary: 45s 0ms and 45s 1ms strictly format as "1m ago"', () {
      final elapsed45s = ref.subtract(const Duration(seconds: 45));
      final elapsed45s1ms = ref.subtract(const Duration(seconds: 45, milliseconds: 1));

      expect(service.formatRelativeTime(elapsed45s, now: ref), equals('1m ago'));
      expect(service.formatRelativeTime(elapsed45s1ms, now: ref), equals('1m ago'));
    });

    test('59s and 60s boundaries format as "1m ago"', () {
      final elapsed59s = ref.subtract(const Duration(seconds: 59));
      final elapsed60s = ref.subtract(const Duration(seconds: 60));
      final elapsed119s = ref.subtract(const Duration(seconds: 119));

      expect(service.formatRelativeTime(elapsed59s, now: ref), equals('1m ago'));
      expect(service.formatRelativeTime(elapsed60s, now: ref), equals('1m ago'));
      expect(service.formatRelativeTime(elapsed119s, now: ref), equals('1m ago'));
    });

    test('Minutes boundary: 2m 00s formats as "2m ago"', () {
      final elapsed2m = ref.subtract(const Duration(minutes: 2));
      expect(service.formatRelativeTime(elapsed2m, now: ref), equals('2m ago'));
    });

    test('59m 59s boundary strictly formats as "59m ago"', () {
      final elapsed59m59s = ref.subtract(const Duration(minutes: 59, seconds: 59));
      expect(service.formatRelativeTime(elapsed59m59s, now: ref), equals('59m ago'));
    });

    test('60m 00s on same calendar day formats as "Today, h:mm a"', () {
      final elapsed60m = ref.subtract(const Duration(minutes: 60)); // 1:00:00 PM
      expect(service.formatRelativeTime(elapsed60m, now: ref), equals('Today, 1:00 PM'));
    });

    test('60m boundary crossing midnight formats as "Yesterday, h:mm a"', () {
      final earlyMorning = DateTime(2026, 11, 2, 0, 30, 0); // Nov 2, 12:30 AM
      final oneHourAgo = earlyMorning.subtract(const Duration(hours: 1)); // Nov 1, 11:30 PM
      expect(service.formatRelativeTime(oneHourAgo, now: earlyMorning), equals('Yesterday, 11:30 PM'));
    });

    test('23h 59m elapsed on same calendar day formats as "Today, h:mm a"', () {
      final endOfDay = DateTime(2026, 11, 2, 23, 59, 0);
      final startOfDay = DateTime(2026, 11, 2, 0, 0, 0);
      expect(service.formatRelativeTime(startOfDay, now: endOfDay), equals('Today, 12:00 AM'));
    });

    test('Exactly 24h elapsed to previous calendar day formats as "Yesterday, h:mm a"', () {
      final todayNoon = DateTime(2026, 11, 2, 12, 0, 0);
      final yesterdayNoon = DateTime(2026, 11, 1, 12, 0, 0);
      expect(service.formatRelativeTime(yesterdayNoon, now: todayNoon), equals('Yesterday, 12:00 PM'));
    });
  });

  group('Challenger M2: Clock Skew & Future Timestamps Handling', () {
    final ref = DateTime(2026, 11, 2, 14, 0, 0);

    test('Future timestamps (skew from 1ms up to 1 year) clamp safely to "Just now"', () {
      final future1ms = ref.add(const Duration(milliseconds: 1));
      final future10s = ref.add(const Duration(seconds: 10));
      final future45s = ref.add(const Duration(seconds: 45));
      final future1h = ref.add(const Duration(hours: 1));
      final future1d = ref.add(const Duration(days: 1));
      final future1y = ref.add(const Duration(days: 365));

      final testCases = [
        future1ms,
        future10s,
        future45s,
        future1h,
        future1d,
        future1y,
      ];

      for (final futureTime in testCases) {
        final formatted = service.formatRelativeTime(futureTime, now: ref);
        expect(formatted, equals('Just now'), reason: 'Failed for future timestamp $futureTime');
        expect(formatted.contains('-'), isFalse, reason: 'Must never contain negative prefix');

        final healthFormatted = service.formatDeviceHealthChecked(futureTime, now: ref);
        expect(healthFormatted, equals('Last checked: Just now'));

        final updateFormatted = service.formatSystemUpdateChecked(futureTime, now: ref);
        expect(updateFormatted, equals('Checked: Just now'));
      }
    });

    test('Never throws an exception on negative Duration or inverse time math', () {
      expect(() => service.formatRelativeTime(DateTime(3000, 1, 1), now: ref), returnsNormally);
      expect(() => service.formatRelativeTime(DateTime(1900, 1, 1), now: ref), returnsNormally);
    });
  });

  group('Challenger M2: Leap Year & Year Transition Stress', () {
    test('Leap year: Feb 29 viewed on same day formats as "Today, h:mm a"', () {
      final ref = DateTime(2024, 2, 29, 18, 0, 0);
      final check = DateTime(2024, 2, 29, 10, 30, 0);
      expect(service.formatRelativeTime(check, now: ref), equals('Today, 10:30 AM'));
    });

    test('Leap year: Feb 29 viewed on March 1 formats as "Yesterday, h:mm a"', () {
      final ref = DateTime(2024, 3, 1, 10, 0, 0);
      final checkFeb29 = DateTime(2024, 2, 29, 15, 45, 0);
      expect(service.formatRelativeTime(checkFeb29, now: ref), equals('Yesterday, 3:45 PM'));
    });

    test('Non-leap year: Feb 28 viewed on March 1 formats as "Yesterday, h:mm a"', () {
      final ref = DateTime(2025, 3, 1, 10, 0, 0);
      final checkFeb28 = DateTime(2025, 2, 28, 15, 45, 0);
      expect(service.formatRelativeTime(checkFeb28, now: ref), equals('Yesterday, 3:45 PM'));
    });

    test('Leap day viewed later in the same leap year formats with month and day without year', () {
      final ref = DateTime(2024, 11, 2, 14, 0, 0);
      final checkFeb29 = DateTime(2024, 2, 29, 9, 15, 0);
      expect(service.formatRelativeTime(checkFeb29, now: ref), equals('Feb 29, 9:15 AM'));
    });

    test('Leap day viewed in subsequent calendar year formats with month, day, and year', () {
      final ref = DateTime(2025, 3, 1, 10, 0, 0);
      final checkFeb29Leap = DateTime(2024, 2, 29, 9, 15, 0);
      expect(service.formatRelativeTime(checkFeb29Leap, now: ref), equals('Feb 29, 2024, 9:15 AM'));
    });

    test('Year transition: Dec 31 23:59 -> Jan 1 00:01 (2 minutes elapsed) formats as "2m ago"', () {
      final ref = DateTime(2026, 1, 1, 0, 1, 0);
      final checkDec31 = DateTime(2025, 12, 31, 23, 59, 0);
      expect(service.formatRelativeTime(checkDec31, now: ref), equals('2m ago'));
    });

    test('Year transition: Dec 31 23:00 -> Jan 1 02:00 (3 hours elapsed) formats as "Yesterday, h:mm a"', () {
      final ref = DateTime(2026, 1, 1, 2, 0, 0);
      final checkDec31 = DateTime(2025, 12, 31, 23, 0, 0);
      expect(service.formatRelativeTime(checkDec31, now: ref), equals('Yesterday, 11:00 PM'));
    });

    test('Year transition: Dec 31 12:00 -> Jan 2 12:00 (48 hours across new year) formats with year', () {
      final ref = DateTime(2026, 1, 2, 12, 0, 0);
      final checkDec31 = DateTime(2025, 12, 31, 12, 0, 0);
      expect(service.formatRelativeTime(checkDec31, now: ref), equals('Dec 31, 2025, 12:00 PM'));
    });
  });

  group('Challenger M2: Rapid Consecutive & Parallel Writes Stress', () {
    test('100 rapid consecutive writes persist the final timestamp reliably', () async {
      final base = DateTime(2026, 11, 2, 10, 0, 0);
      for (int i = 0; i < 100; i++) {
        final t = base.add(Duration(seconds: i));
        await service.recordSuccessfulCheck(CheckTimestampService.deviceHealthKey, t);
      }

      final expectedFinal = base.add(const Duration(seconds: 99));
      final retrieved = await service.getLastSuccessfulCheck(CheckTimestampService.deviceHealthKey);
      expect(retrieved, isNotNull);
      expect(retrieved!.toUtc(), equals(expectedFinal.toUtc()));
    });

    test('50 parallel writes via Future.wait execute without crashing or corrupting', () async {
      final base = DateTime(2026, 11, 2, 12, 0, 0);
      final futures = <Future<void>>[];

      for (int i = 0; i < 50; i++) {
        final t = base.add(Duration(minutes: i));
        futures.add(service.recordSuccessfulCheck(CheckTimestampService.systemUpdateKey, t));
      }

      await expectLater(Future.wait(futures), completes);

      final retrieved = await service.getLastSuccessfulCheck(CheckTimestampService.systemUpdateKey);
      expect(retrieved, isNotNull);
      // The retrieved time must be one of the written timestamps
      expect(retrieved!.year, equals(2026));
      expect(retrieved.month, equals(11));
      expect(retrieved.day, equals(2));
    });

    test('Concurrent interleaved writes to deviceHealthKey and systemUpdateKey maintain strict isolation', () async {
      final healthTimes = List.generate(25, (i) => DateTime(2026, 11, 2, 8, i, 0));
      final updateTimes = List.generate(25, (i) => DateTime(2026, 11, 2, 16, i, 0));

      final futures = <Future<void>>[];
      for (int i = 0; i < 25; i++) {
        futures.add(service.recordSuccessfulCheck(CheckTimestampService.deviceHealthKey, healthTimes[i]));
        futures.add(service.recordSuccessfulCheck(CheckTimestampService.systemUpdateKey, updateTimes[i]));
      }

      await expectLater(Future.wait(futures), completes);

      final lastHealth = await service.getLastSuccessfulCheck(CheckTimestampService.deviceHealthKey);
      final lastUpdate = await service.getLastSuccessfulCheck(CheckTimestampService.systemUpdateKey);

      expect(lastHealth, isNotNull);
      expect(lastUpdate, isNotNull);
      expect(lastHealth!.hour, equals(8));
      expect(lastUpdate!.hour, equals(16));
    });
  });

  group('Challenger M2: Persistence Across Simulated Process Kill / Restart', () {
    test('Simulated app restart: new CheckTimestampService instance reads previously persisted value', () async {
      final originalTime = DateTime(2026, 11, 2, 14, 25, 30, 456);
      
      // Instance 1 records check
      final instance1 = CheckTimestampService();
      await instance1.recordSuccessfulCheck(CheckTimestampService.deviceHealthKey, originalTime);

      // Verify stored in underlying mock storage
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.containsKey(CheckTimestampService.deviceHealthKey), isTrue);

      // Kill Instance 1 and reset singleton
      CheckTimestampService.setMockInstance(null);

      // Instance 2 (simulating cold boot after process termination)
      final instance2 = CheckTimestampService();
      final retrievedTime = await instance2.getLastSuccessfulCheck(CheckTimestampService.deviceHealthKey);

      expect(retrievedTime, isNotNull);
      expect(retrievedTime!.toUtc(), equals(originalTime.toUtc()));
      expect(retrievedTime.isUtc, isFalse);
    });

    test('Persistence maintains sub-second millisecond precision across cold reload', () async {
      final preciseTime = DateTime.utc(2026, 11, 2, 21, 45, 12, 789);
      await service.recordSuccessfulCheck(CheckTimestampService.systemUpdateKey, preciseTime);

      // Emulate fresh app launch by resetting cached singleton and instantiating anew
      CheckTimestampService.setMockInstance(null);
      final restartedService = CheckTimestampService();
      final retrieved = await restartedService.getLastSuccessfulCheck(CheckTimestampService.systemUpdateKey);

      expect(retrieved, isNotNull);
      expect(retrieved!.toUtc().millisecond, equals(789));
      expect(retrieved.toUtc(), equals(preciseTime));
    });

    test('Data survives mock backing store re-instantiation simulating persistent disk', () async {
      final testTime = DateTime(2026, 10, 31, 23, 59, 0);
      final rawIso = testTime.toUtc().toIso8601String();

      // Seed mock SharedPreferences directly as if loaded from disk
      SharedPreferences.setMockInitialValues({
        CheckTimestampService.deviceHealthKey: rawIso,
      });

      final coldService = CheckTimestampService();
      final result = await coldService.getLastSuccessfulCheck(CheckTimestampService.deviceHealthKey);

      expect(result, isNotNull);
      expect(result!.toUtc(), equals(testTime.toUtc()));
    });
  });

  group('Challenger M2: Hostile Storage Malformation & Corner Cases', () {
    test('Non-date unparseable payloads return null and never throw', () async {
      final unparseablePayloads = [
        'NOT_A_DATE',
        'invalid_string_with_symbols!@#',
        'null',
        'undefined',
        '\x00\x01\x02',
        'NaN',
        '0',
        '99999999999999999999999999999999',
      ];

      final prefs = await SharedPreferences.getInstance();

      for (final payload in unparseablePayloads) {
        await prefs.setString(CheckTimestampService.deviceHealthKey, payload);
        final result = await service.getLastSuccessfulCheck(CheckTimestampService.deviceHealthKey);
        expect(result, isNull, reason: 'Failed for unparseable payload: $payload');
      }
    });

    test('Overflowing date format string does not throw and formats safely', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(CheckTimestampService.deviceHealthKey, '2026-99-99T99:99:99');

      final result = await service.getLastSuccessfulCheck(CheckTimestampService.deviceHealthKey);
      expect(result, isNotNull);
      // Even with an overflowing year in 2034, formatting should clamp safely to "Just now"
      expect(service.formatRelativeTime(result), equals('Just now'));
    });

    test('Extreme historical (epoch 1970) and far future (9999) timestamps format safely', () {
      final ref = DateTime(2026, 11, 2, 12, 0, 0);

      final epoch = DateTime(1970, 1, 1, 0, 0, 0);
      final farFuture = DateTime(9999, 12, 31, 23, 59, 59);

      expect(service.formatRelativeTime(epoch, now: ref), equals('Jan 1, 1970, 12:00 AM'));
      expect(service.formatRelativeTime(farFuture, now: ref), equals('Just now'));
    });

    test('Null timestamp safely produces fallback strings across all helper formatters', () {
      expect(service.formatRelativeTime(null), equals('Never'));
      expect(service.formatDeviceHealthChecked(null), equals('Last checked: Never'));
      expect(service.formatSystemUpdateChecked(null), equals('Checked: Never'));
    });
  });
}
