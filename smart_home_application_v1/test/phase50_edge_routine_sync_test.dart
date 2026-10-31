import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_home_application_v1/core/models/routine_models.dart';
import 'package:smart_home_application_v1/core/services/edge_routine_sync_service.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Phase 50 — Edge Routine Synchronization Unit Tests', () {
    test('1. computeDaysMask accurately calculates POSIX tm_wday bitmasks', () {
      // All days: Sun(1) + Mon(2) + Tue(4) + Wed(8) + Thu(16) + Fri(32) + Sat(64) = 127 (0x7F)
      expect(
        EdgeRoutineSyncService.computeDaysMask(['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']),
        equals(127),
      );
      expect(EdgeRoutineSyncService.computeDaysMask([]), equals(127));

      // Weekdays: Mon(2) + Tue(4) + Wed(8) + Thu(16) + Fri(32) = 62 (0x3E)
      expect(
        EdgeRoutineSyncService.computeDaysMask(['Mon', 'Tue', 'Wed', 'Thu', 'Fri']),
        equals(62),
      );

      // Weekends: Sun(1) + Sat(64) = 65 (0x41)
      expect(
        EdgeRoutineSyncService.computeDaysMask(['Sat', 'Sun']),
        equals(65),
      );

      // Custom: Wed(8) + Fri(32) = 40
      expect(
        EdgeRoutineSyncService.computeDaysMask(['Wed', 'Fri']),
        equals(40),
      );
    });

    test('2. parseTimeOfDay accurately parses 12-hour AM/PM and 24-hour schedules', () {
      const schedule = RoutineSchedule(label: 'Daily at 07:30 AM', timezone: 'IST');

      // 07:30 AM
      const trig1 = RoutineTrigger(
        kind: RoutineTriggerKind.timeSchedule,
        title: 'Morning Trigger',
        detail: '7:30 AM',
        timeOfDay: '07:30 AM',
      );
      final (h1, m1) = EdgeRoutineSyncService.parseTimeOfDay(trig1, schedule);
      expect(h1, equals(7));
      expect(m1, equals(30));

      // 01:15 PM -> 13:15
      const trig2 = RoutineTrigger(
        kind: RoutineTriggerKind.timeSchedule,
        title: 'Afternoon Trigger',
        detail: 'Weekdays · 1:15 PM',
        timeOfDay: '1:15 PM',
      );
      final (h2, m2) = EdgeRoutineSyncService.parseTimeOfDay(trig2, schedule);
      expect(h2, equals(13));
      expect(m2, equals(15));

      // 11:45 PM -> 23:45
      const trig3 = RoutineTrigger(
        kind: RoutineTriggerKind.timeSchedule,
        title: 'Night Trigger',
        detail: '11:45 PM',
        timeOfDay: '11:45 PM',
      );
      final (h3, m3) = EdgeRoutineSyncService.parseTimeOfDay(trig3, schedule);
      expect(h3, equals(23));
      expect(m3, equals(45));

      // 12:00 AM -> 0:00 midnight
      const trig4 = RoutineTrigger(
        kind: RoutineTriggerKind.timeSchedule,
        title: 'Midnight Trigger',
        detail: '12:00 AM',
        timeOfDay: '12:00 AM',
      );
      final (h4, m4) = EdgeRoutineSyncService.parseTimeOfDay(trig4, schedule);
      expect(h4, equals(0));
      expect(m4, equals(0));
    });

    test('3. Routine creation in PreviewRoutineRepository creates local routine with edge sync hook', () async {
      const repo = PreviewRoutineRepository();
      final draft = RoutineDraft(
        name: 'Garden Pump Schedule',
        icon: 'water_drop_outlined',
        isFavorite: true,
        trigger: const RoutineTrigger(
          kind: RoutineTriggerKind.timeSchedule,
          title: 'Schedule: 06:30 AM',
          detail: 'Every day · 06:30 AM',
          timeOfDay: '06:30 AM',
          days: ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'],
        ),
        actions: [
          const RoutineAction(
            kind: RoutineActionKind.switchChannel,
            title: 'Water Pump',
            detail: 'Turn ON (15m timer)',
            deviceId: 'test_dev_1',
            channelIndex: 1,
            targetState: true,
            pulseDurationMinutes: 15,
          ),
        ],
      );

      final result = await repo.createRoutine(draft);
      expect(result, equals(RepositoryResult.success));

      final routines = await repo.getRoutines();
      expect(routines.any((r) => r.name == 'Garden Pump Schedule'), isTrue);

      final created = routines.firstWhere((r) => r.name == 'Garden Pump Schedule');
      expect(created.actions.first.channelIndex, equals(1));
      expect(created.actions.first.pulseDurationMinutes, equals(15));
      expect(created.enabled, isTrue);
    });

    test('4. isRoutineCurrentlyActive returns true during pulse when channel is ON and false once channel turns OFF', () {
      final now = DateTime.now();
      final timeStr = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
      const dayMap = {1: 'Mon', 2: 'Tue', 3: 'Wed', 4: 'Thu', 5: 'Fri', 6: 'Sat', 7: 'Sun'};
      final currentDay = dayMap[now.weekday]!;

      final routine1MinAutoOff = Routine(
        id: 'rt_switch2_auto_off',
        name: 'Switch 2 Auto Off',
        icon: 'timer',
        isFavorite: false,
        enabled: true,
        availability: RoutineAvailability.available,
        trigger: RoutineTrigger(
          kind: RoutineTriggerKind.timeSchedule,
          title: 'Schedule: $timeStr',
          detail: '$currentDay · $timeStr',
          timeOfDay: timeStr,
          days: [currentDay],
        ),
        conditions: const [],
        actions: const [
          RoutineAction(
            kind: RoutineActionKind.switchChannel,
            title: 'Switch 2',
            detail: 'Turn On (1m timer)',
            deviceId: 'test_dev_1',
            channelIndex: 2,
            targetState: true,
            pulseDurationMinutes: 1,
          ),
        ],
        schedule: RoutineSchedule(label: timeStr, timezone: 'IST'),
        involvedDevices: const [],
        lastExecution: null,
        nextRun: 'Scheduled',
        createdAt: now,
        updatedAt: now,
        summary: 'Test summary',
      );

      final service = EdgeRoutineSyncService.instance;

      // When channel is ON during active pulse -> active
      expect(
        service.isRoutineCurrentlyActive(
          routine1MinAutoOff,
          targetChannel: 2,
          currentPower: true,
        ),
        isTrue,
      );

      // When routine finishes and channel is OFF -> must NOT be active!
      expect(
        service.isRoutineCurrentlyActive(
          routine1MinAutoOff,
          targetChannel: 2,
          currentPower: false,
        ),
        isFalse,
      );

      // For another channel (e.g. channel 1) -> must NOT be active
      expect(
        service.isRoutineCurrentlyActive(
          routine1MinAutoOff,
          targetChannel: 1,
          currentPower: true,
        ),
        isFalse,
      );
    });

    test('5. isRoutineCurrentlyActive returns false for one-shot actions without auto-off timer', () {
      final now = DateTime.now();
      final timeStr = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

      final oneShotRoutine = Routine(
        id: 'rt_oneshot',
        name: 'One-shot Toggle',
        icon: 'toggle_on',
        isFavorite: false,
        enabled: true,
        availability: RoutineAvailability.available,
        trigger: RoutineTrigger(
          kind: RoutineTriggerKind.timeSchedule,
          title: 'Schedule: $timeStr',
          detail: timeStr,
          timeOfDay: timeStr,
          days: const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'],
        ),
        conditions: const [],
        actions: const [
          RoutineAction(
            kind: RoutineActionKind.switchChannel,
            title: 'Fan',
            detail: 'Turn On',
            deviceId: 'test_dev_1',
            channelIndex: 1,
            targetState: true,
            pulseDurationMinutes: null, // No pulse duration
          ),
        ],
        schedule: RoutineSchedule(label: timeStr, timezone: 'IST'),
        involvedDevices: const [],
        lastExecution: null,
        nextRun: 'Scheduled',
        createdAt: now,
        updatedAt: now,
        summary: 'Test summary',
      );

      final service = EdgeRoutineSyncService.instance;
      // Momentary command without auto-off timer must NOT lock the UI
      expect(
        service.isRoutineCurrentlyActive(oneShotRoutine, targetChannel: 1, currentPower: true),
        isFalse,
      );
    });
  });
}
