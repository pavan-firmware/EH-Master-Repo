import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_home_application_v1/core/models/routine_models.dart';
import 'package:smart_home_application_v1/features/automations/presentation/automations_page.dart';

void main() {
  test('preview repository exposes routines and rejects mutations', () async {
    const repository = PreviewRoutineRepository();
    final routines = await repository.getRoutines();
    expect(
      routines.map((routine) => routine.name),
      containsAll(<String>[
        'Plant care',
        'Gentle night light',
        'Tank reminder',
      ]),
    );
    expect(
      await repository.enableRoutine('plant-care'),
      RepositoryResult.unsupported,
    );
    expect(
      await repository.executeRoutine('plant-care'),
      RepositoryResult.unsupported,
    );
    expect(
      routines.firstWhere((routine) => routine.id == 'plant-care').availability,
      RoutineAvailability.partiallyAvailable,
    );
  });

  test('validator reports incomplete and valid drafts', () {
    const validator = RoutineValidator();
    expect(validator.validate(RoutineDraft()).isValid, isFalse);
    final draft = RoutineDraft(
      name: 'Plant care',
      trigger: const RoutineTrigger(
        kind: RoutineTriggerKind.soilMoisture,
        title: 'Soil moisture drops below 35%',
        detail: 'Every day',
        threshold: 35,
      ),
      actions: const [
        RoutineAction(
          kind: RoutineActionKind.mistMaker,
          title: 'Mist maker',
          detail: 'Run for 30 seconds',
          deviceId: 'mist',
        ),
      ],
    );
    expect(validator.validate(draft).isValid, isTrue);
  });

  testWidgets('routines list opens detail and secure setup guidance', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: AutomationsPage()));
    await tester.pumpAndSettle();
    expect(find.text('Routines'), findsOneWidget);
    expect(find.text('Plant care'), findsOneWidget);
    expect(find.textContaining('routines'), findsWidgets);
    await tester.tap(find.text('Plant care'));
    await tester.pumpAndSettle();
    expect(find.text('WHEN'), findsOneWidget);
    expect(find.text('DEVICES INVOLVED'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.arrow_back_rounded).first);
    await tester.pumpAndSettle();
    await tester.pumpAndSettle();
    await tester.tap(find.byType(Switch).first);
    await tester.pumpAndSettle();
    expect(find.text('Secure setup required'), findsOneWidget);
  });
}
