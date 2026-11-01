import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_home_application_v1/core/models/routine_models.dart';
import 'package:smart_home_application_v1/core/services/edge_routine_sync_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('Multi-action routine retains all actions when upsertRoutineFromEdge is called', () async {
    final repo = const PreviewRoutineRepository();

    // 1. Create a routine with 2 actions
    final draft = RoutineDraft(
      name: 'Evening Multi Action',
      icon: 'timer',
      isFavorite: false,
      trigger: const RoutineTrigger(
        kind: RoutineTriggerKind.timeSchedule,
        title: 'Schedule: 07:00 PM',
        detail: 'Every day · 07:00 PM',
        timeOfDay: '07:00 PM',
        days: ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'],
      ),
      schedule: const RoutineSchedule(
        label: 'Every day at 07:00 PM',
        timezone: 'IST',
        days: ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'],
      ),
      actions: const [
        RoutineAction(
          kind: RoutineActionKind.switchChannel,
          title: 'Smart Switch • Channel 1',
          detail: 'Turn On Channel 1 (5m timer)',
          deviceId: 'dev_1',
          channelIndex: 1,
          targetState: true,
          pulseDurationMinutes: 5,
        ),
        RoutineAction(
          kind: RoutineActionKind.switchChannel,
          title: 'Smart Switch • Channel 2',
          detail: 'Toggle Channel 2',
          deviceId: 'dev_1',
          channelIndex: 2,
          targetState: true,
          isToggle: true,
          pulseDurationMinutes: null,
        ),
      ],
    );

    final res = await repo.createRoutine(draft);
    expect(res, RepositoryResult.success);

    final routines = await repo.getRoutines();
    expect(routines.length, 1);
    expect(routines.first.actions.length, 2);
    expect(routines.first.actions[0].channelIndex, 1);
    expect(routines.first.actions[0].pulseDurationMinutes, 5);
    expect(routines.first.actions[1].channelIndex, 2);
    expect(routines.first.actions[1].isToggle, true);

    // 2. Simulate app restart edge sync: a single-action stub arrives from hardware
    final singleActionStub = Routine(
      id: 'rt_${EdgeRoutineSyncService.extractCoreId(routines.first.id)}_a1_c2',
      name: 'Evening Multi Action',
      icon: 'timer',
      isFavorite: false,
      enabled: true,
      availability: RoutineAvailability.available,
      trigger: routines.first.trigger,
      conditions: const [],
      actions: const [
        RoutineAction(
          kind: RoutineActionKind.switchChannel,
          title: 'Channel 2 • Toggle',
          detail: 'Toggle Channel 2',
          deviceId: 'dev_1',
          channelIndex: 2,
          targetState: true,
          isToggle: true,
        ),
      ],
      schedule: routines.first.schedule,
      involvedDevices: const [],
      lastExecution: null,
      nextRun: null,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      summary: 'Toggle Channel 2',
    );

    // Call upsertRoutineFromEdge with the single action stub
    await repo.upsertRoutineFromEdge(singleActionStub);

    // Verify: The routine still has BOTH actions! Action 1 was NOT deleted!
    final afterSync = await repo.getRoutines();
    expect(afterSync.length, 1);
    expect(afterSync.first.actions.length, 2, reason: 'Multi-action routine must not be truncated to 1 action!');
    expect(afterSync.first.actions[0].channelIndex, 1);
    expect(afterSync.first.actions[0].pulseDurationMinutes, 5);
    expect(afterSync.first.actions[1].channelIndex, 2);
    expect(afterSync.first.actions[1].isToggle, true);
  });
}
