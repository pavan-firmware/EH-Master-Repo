import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_home_application_v1/core/services/check_timestamp_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late CheckTimestampService service;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    service = CheckTimestampService();
    CheckTimestampService.setMockInstance(service);
  });

  tearDown(() {
    CheckTimestampService.setMockInstance(null);
  });

  group('CheckTimestampService Contract & Storage', () {
    test('1. Defines authoritative storage keys', () {
      expect(CheckTimestampService.deviceHealthKey, equals('device_health_last_check'));
      expect(CheckTimestampService.systemUpdateKey, equals('system_update_last_check'));
    });

    test('2. Returns null when key has not been recorded', () async {
      final ts = await service.getLastSuccessfulCheck(CheckTimestampService.deviceHealthKey);
      expect(ts, isNull);
    });

    test('3. Records timestamp in UTC ISO-8601 and retrieves in local timezone', () async {
      final localTime = DateTime(2026, 11, 2, 14, 30, 45);
      await service.recordSuccessfulCheck(CheckTimestampService.deviceHealthKey, localTime);

      final prefs = await SharedPreferences.getInstance();
      final storedString = prefs.getString(CheckTimestampService.deviceHealthKey);
      expect(storedString, isNotNull);
      expect(storedString, equals(localTime.toUtc().toIso8601String()));

      final retrieved = await service.getLastSuccessfulCheck(CheckTimestampService.deviceHealthKey);
      expect(retrieved, isNotNull);
      expect(retrieved!.isUtc, isFalse);
      expect(retrieved.toUtc(), equals(localTime.toUtc()));
    });

    test('4. Preserves key isolation between Device Health and System Update', () async {
      final tHealth = DateTime(2026, 11, 2, 9, 40);
      final tUpdate = DateTime(2026, 11, 2, 11, 15);

      await service.recordSuccessfulCheck(CheckTimestampService.deviceHealthKey, tHealth);
      expect(await service.getLastSuccessfulCheck(CheckTimestampService.systemUpdateKey), isNull);

      await service.recordSuccessfulCheck(CheckTimestampService.systemUpdateKey, tUpdate);

      final readHealth = await service.getLastSuccessfulCheck(CheckTimestampService.deviceHealthKey);
      final readUpdate = await service.getLastSuccessfulCheck(CheckTimestampService.systemUpdateKey);

      expect(readHealth!.toUtc(), equals(tHealth.toUtc()));
      expect(readUpdate!.toUtc(), equals(tUpdate.toUtc()));
    });

    test('5. clearLastCheck removes persisted timestamp', () async {
      final time = DateTime(2026, 11, 2, 10, 0);
      await service.recordSuccessfulCheck(CheckTimestampService.deviceHealthKey, time);
      expect(await service.getLastSuccessfulCheck(CheckTimestampService.deviceHealthKey), isNotNull);

      await service.clearLastCheck(CheckTimestampService.deviceHealthKey);
      expect(await service.getLastSuccessfulCheck(CheckTimestampService.deviceHealthKey), isNull);
    });

    test('6. Data resilience handles corrupt or empty strings gracefully without throwing', () async {
      final prefs = await SharedPreferences.getInstance();

      await prefs.setString(CheckTimestampService.deviceHealthKey, '');
      expect(await service.getLastSuccessfulCheck(CheckTimestampService.deviceHealthKey), isNull);

      await prefs.setString(CheckTimestampService.deviceHealthKey, '   ');
      expect(await service.getLastSuccessfulCheck(CheckTimestampService.deviceHealthKey), isNull);

      await prefs.setString(CheckTimestampService.deviceHealthKey, 'invalid_non_date_string');
      expect(await service.getLastSuccessfulCheck(CheckTimestampService.deviceHealthKey), isNull);
    });
  });

  group('CheckTimestampService Relative Time Formatting', () {
    final ref = DateTime(2026, 11, 2, 15, 30, 0); // Reference time: Nov 2, 2026 at 3:30:00 PM

    test('7. Null timestamp formats as "Never"', () {
      expect(service.formatRelativeTime(null, now: ref), equals('Never'));
      expect(service.formatDeviceHealthChecked(null, now: ref), equals('Last checked: Never'));
      expect(service.formatSystemUpdateChecked(null, now: ref), equals('Checked: Never'));
    });

    test('8. Future clock skew (negative elapsed) returns "Just now"', () {
      final future10s = ref.add(const Duration(seconds: 10));
      final future60s = ref.add(const Duration(seconds: 60));

      expect(service.formatRelativeTime(future10s, now: ref), equals('Just now'));
      expect(service.formatRelativeTime(future60s, now: ref), equals('Just now'));
    });

    test('9. Elapsed < 45 seconds strictly formats as "Just now"', () {
      final elapsed0s = ref;
      final elapsed20s = ref.subtract(const Duration(seconds: 20));
      final elapsed44s = ref.subtract(const Duration(seconds: 44));

      expect(service.formatRelativeTime(elapsed0s, now: ref), equals('Just now'));
      expect(service.formatRelativeTime(elapsed20s, now: ref), equals('Just now'));
      expect(service.formatRelativeTime(elapsed44s, now: ref), equals('Just now'));
    });

    test('10. Boundary at 45 seconds clamps to "1m ago"', () {
      final elapsed45s = ref.subtract(const Duration(seconds: 45));
      final elapsed59s = ref.subtract(const Duration(seconds: 59));
      final elapsed60s = ref.subtract(const Duration(seconds: 60));
      final elapsed119s = ref.subtract(const Duration(seconds: 119));

      expect(service.formatRelativeTime(elapsed45s, now: ref), equals('1m ago'));
      expect(service.formatRelativeTime(elapsed59s, now: ref), equals('1m ago'));
      expect(service.formatRelativeTime(elapsed60s, now: ref), equals('1m ago'));
      expect(service.formatRelativeTime(elapsed119s, now: ref), equals('1m ago'));
    });

    test('11. Minutes formatting from 2m up to 59m ago', () {
      final elapsed2m = ref.subtract(const Duration(minutes: 2));
      final elapsed15m = ref.subtract(const Duration(minutes: 15));
      final elapsed59m = ref.subtract(const Duration(minutes: 59));

      expect(service.formatRelativeTime(elapsed2m, now: ref), equals('2m ago'));
      expect(service.formatRelativeTime(elapsed15m, now: ref), equals('15m ago'));
      expect(service.formatRelativeTime(elapsed59m, now: ref), equals('59m ago'));
    });

    test('12. Elapsed >= 60m on same calendar day formats as "Today, h:mm a"', () {
      final checkAt940am = DateTime(2026, 11, 2, 9, 40, 0);
      final checkAt1200pm = DateTime(2026, 11, 2, 12, 0, 0);

      expect(service.formatRelativeTime(checkAt940am, now: ref), equals('Today, 9:40 AM'));
      expect(service.formatRelativeTime(checkAt1200pm, now: ref), equals('Today, 12:00 PM'));
      expect(service.formatDeviceHealthChecked(checkAt940am, now: ref), equals('Last checked: Today, 9:40 AM'));
      expect(service.formatSystemUpdateChecked(checkAt940am, now: ref), equals('Checked: Today, 9:40 AM'));
    });

    test('13. Check on previous calendar day formats as "Yesterday, h:mm a"', () {
      final checkYesterday = DateTime(2026, 11, 1, 9, 40, 0);
      final checkYesterdayEvening = DateTime(2026, 11, 1, 19, 15, 0);

      expect(service.formatRelativeTime(checkYesterday, now: ref), equals('Yesterday, 9:40 AM'));
      expect(service.formatRelativeTime(checkYesterdayEvening, now: ref), equals('Yesterday, 7:15 PM'));
      expect(service.formatDeviceHealthChecked(checkYesterday, now: ref), equals('Last checked: Yesterday, 9:40 AM'));
      expect(service.formatSystemUpdateChecked(checkYesterday, now: ref), equals('Checked: Yesterday, 9:40 AM'));
    });

    test('14. Check earlier this calendar year formats as "MMM d, h:mm a"', () {
      final checkAug15 = DateTime(2026, 8, 15, 9, 40, 0);
      final checkJan1 = DateTime(2026, 1, 1, 0, 5, 0);

      expect(service.formatRelativeTime(checkAug15, now: ref), equals('Aug 15, 9:40 AM'));
      expect(service.formatRelativeTime(checkJan1, now: ref), equals('Jan 1, 12:05 AM'));
    });

    test('15. Check in a prior year formats as "MMM d, yyyy, h:mm a"', () {
      final check2025 = DateTime(2025, 8, 15, 9, 40, 0);
      final check2024 = DateTime(2024, 12, 31, 23, 59, 0);

      expect(service.formatRelativeTime(check2025, now: ref), equals('Aug 15, 2025, 9:40 AM'));
      expect(service.formatRelativeTime(check2024, now: ref), equals('Dec 31, 2024, 11:59 PM'));
    });

    test('16. 12-hour clock components formatting accuracy', () {
      // Midnight
      final midnight = DateTime(2026, 11, 2, 0, 0);
      expect(service.formatRelativeTime(midnight, now: ref), equals('Today, 12:00 AM'));

      // Noon
      final noon = DateTime(2026, 11, 2, 12, 0);
      expect(service.formatRelativeTime(noon, now: ref), equals('Today, 12:00 PM'));

      // 1 PM
      final onePm = DateTime(2026, 11, 2, 13, 5);
      expect(service.formatRelativeTime(onePm, now: ref), equals('Today, 1:05 PM'));
    });
  });
}
