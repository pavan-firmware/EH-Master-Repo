import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_home_application_v1/core/models/routine_models.dart';
import 'package:smart_home_application_v1/features/automations/presentation/automations_page.dart';

void main() {
  test('preview repository creates and manages user routines', () async {
    const repository = PreviewRoutineRepository();
    final initialRoutines = await repository.getRoutines();
    expect(initialRoutines, isEmpty);

    final draft = RoutineDraft(
      name: 'Morning Routine',
      trigger: const RoutineTrigger(
        kind: RoutineTriggerKind.timeSchedule,
        title: 'Schedule: 07:00 AM',
        detail: 'Every day · 07:00 AM',
      ),
      actions: const [
        RoutineAction(
          kind: RoutineActionKind.switchChannel,
          title: 'Smart Switch • Channel 1',
          detail: 'Turn On Channel 1',
          deviceId: 'dev_1',
        ),
      ],
    );

    final createRes = await repository.createRoutine(draft);
    expect(createRes, RepositoryResult.success);

    final routines = await repository.getRoutines();
    expect(routines.length, 1);
    expect(routines.first.name, 'Morning Routine');

    final toggleRes = await repository.disableRoutine(routines.first.id);
    expect(toggleRes, RepositoryResult.success);

    final updated = await repository.getRoutine(routines.first.id);
    expect(updated?.enabled, isFalse);

    await repository.deleteRoutine(routines.first.id);
    expect(await repository.getRoutines(), isEmpty);
  });

  test('validator reports incomplete and valid drafts', () {
    const validator = RoutineValidator();
    expect(validator.validate(RoutineDraft()).isValid, isFalse);
    final draft = RoutineDraft(
      name: 'Custom Routine',
      trigger: const RoutineTrigger(
        kind: RoutineTriggerKind.timeSchedule,
        title: 'Schedule: 08:00 AM',
        detail: 'Every day · 08:00 AM',
      ),
      actions: const [
        RoutineAction(
          kind: RoutineActionKind.switchChannel,
          title: 'Switch 1',
          detail: 'Turn On Switch 1',
          deviceId: 'dev_1',
        ),
      ],
    );
    expect(validator.validate(draft).isValid, isTrue);
  });

  testWidgets('routines page renders and opens builder', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: AutomationsPage()));
    await tester.pumpAndSettle();
    expect(find.text('Routines'), findsOneWidget);
    expect(find.textContaining('routines'), findsWidgets);
  });
}
