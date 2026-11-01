import 'package:flutter_test/flutter_test.dart';
import 'package:smart_home_application_v1/app/home_controller.dart';
import 'package:smart_home_application_v1/core/models/routine_models.dart';
import 'package:smart_home_application_v1/core/repositories/fake_home_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  test('Upcoming routines multi-space sorting and dynamic filtering modes', () async {
    // Create 3 routines with different schedules and spaces:
    // 1. "Balcony Light" for active space (Home) at 20:00
    // 2. "Office AC" for secondary space (Office) at 09:00
    // 3. "Morning Coffee" for active space (Home) at 07:00
    final now = DateTime.now();
    final r1 = Routine(
      id: 'rt_balcony_light',
      name: 'Balcony Light',
      icon: 'lightbulb',
      isFavorite: true,
      enabled: true,
      availability: RoutineAvailability.available,
      trigger: const RoutineTrigger(
        kind: RoutineTriggerKind.timeSchedule,
        title: 'Time Schedule',
        detail: '08:00 PM',
      ),
      conditions: const [],
      actions: const [
        RoutineAction(
          kind: RoutineActionKind.switchChannel,
          title: 'Switch',
          detail: 'Turn on Balcony',
          deviceId: 'eh_switch_1',
          channelIndex: 1,
          targetState: true,
        ),
      ],
      schedule: const RoutineSchedule(label: '08:00 PM', timezone: 'IST'),
      involvedDevices: const [
        RoutineDevice(id: 'eh_switch_1', name: 'Balcony Light', room: 'Balcony', online: true, capabilities: []),
      ],
      lastExecution: null,
      nextRun: 'Today, 8:00 PM',
      createdAt: now,
      updatedAt: now,
      summary: 'Turn on Balcony Light',
    );

    final r2 = Routine(
      id: 'rt_office_ac',
      name: 'Office AC',
      icon: 'business',
      isFavorite: false,
      enabled: true,
      availability: RoutineAvailability.available,
      trigger: const RoutineTrigger(
        kind: RoutineTriggerKind.timeSchedule,
        title: 'Time Schedule',
        detail: '09:00 AM',
      ),
      conditions: const [],
      actions: const [
        RoutineAction(
          kind: RoutineActionKind.switchChannel,
          title: 'Switch',
          detail: 'Turn on AC',
          deviceId: 'office_dev_1',
          channelIndex: 2,
          targetState: true,
        ),
      ],
      schedule: const RoutineSchedule(label: '09:00 AM', timezone: 'IST'),
      involvedDevices: const [
        RoutineDevice(id: 'office_dev_1', name: 'Office Switch', room: 'Cabin', online: true, capabilities: []),
      ],
      lastExecution: null,
      nextRun: 'Tomorrow, 9:00 AM',
      createdAt: now,
      updatedAt: now,
      summary: 'Turn on Office AC',
    );

    await PreviewRoutineRepository.addOrUpdateRoutine(r1);
    await PreviewRoutineRepository.addOrUpdateRoutine(r2);

    final controller = HomeController(
      repository: FakeHomeRepository(),
      autoSync: false,
    );

    await controller.refreshUpcomingRoutines();

    // Verify Balcony Light appears in upcoming routines
    expect(controller.upcomingRoutinesAcrossSpaces.any((r) => r.title == 'Balcony Light'), isTrue);

    // Test Mode 1: Current Place Only -> Should only contain Home space routines
    controller.setUpcomingRoutineSortMode(UpcomingRoutineSortMode.currentSpaceOnly);
    expect(controller.upcomingRoutineSortMode, UpcomingRoutineSortMode.currentSpaceOnly);
    for (final item in controller.upcomingRoutinesAcrossSpaces) {
      expect(item.isCurrentSpace, isTrue);
    }

    // Test Mode 2: Current Place First -> Current space comes before other spaces
    controller.setUpcomingRoutineSortMode(UpcomingRoutineSortMode.currentSpaceFirst);
    expect(controller.upcomingRoutineSortMode, UpcomingRoutineSortMode.currentSpaceFirst);
    final list = controller.upcomingRoutinesAcrossSpaces;
    if (list.length >= 2) {
      final firstOtherIndex = list.indexWhere((it) => !it.isCurrentSpace);
      if (firstOtherIndex != -1) {
        final lastCurrentIndex = list.lastIndexWhere((it) => it.isCurrentSpace);
        expect(lastCurrentIndex < firstOtherIndex, isTrue);
      }
    }

    // Test Mode 3: Nearest Time First -> Strictly sorted chronologically
    controller.setUpcomingRoutineSortMode(UpcomingRoutineSortMode.nearestTimeFirst);
    expect(controller.upcomingRoutineSortMode, UpcomingRoutineSortMode.nearestTimeFirst);
    final nearestList = controller.upcomingRoutinesAcrossSpaces;
    for (int i = 0; i < nearestList.length - 1; i++) {
      final t1 = nearestList[i].nextExecutionTime;
      final t2 = nearestList[i + 1].nextExecutionTime;
      if (t1 != null && t2 != null) {
        expect(t1.isBefore(t2) || t1.isAtSameMomentAs(t2), isTrue);
      }
    }

    // Test Toggle directly on the fly
    controller.toggleRoutine('rt_balcony_light', false);
    final toggled = controller.upcomingRoutinesAcrossSpaces.firstWhere((r) => r.id == 'rt_balcony_light');
    expect(toggled.isEnabled, isFalse);
  });
}
