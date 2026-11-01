import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_home_application_v1/app/home_controller.dart';
import 'package:smart_home_application_v1/core/models/connection_models.dart';
import 'package:smart_home_application_v1/core/models/routine_models.dart';
import 'package:smart_home_application_v1/core/repositories/fake_home_repository.dart';
import 'package:smart_home_application_v1/core/repositories/unavailable_connection_repository.dart';
import 'package:smart_home_application_v1/core/services/device_storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late DeviceStorageService storageService;
  const testDev = ConnectedDeviceSummary(
    id: '4444688e-989d-458e-820e-ac62a99ed8e1',
    name: 'EH Smart Switch 4X',
    model: 'eh-smart-switch-4x',
    firmware: '1.0.0',
    connectedVia: 'Wi-Fi (Local)',
    signalLabel: 'Local Wi-Fi',
    roomName: 'Living Room',
    online: true,
  );

  group('Routine Completion & Persistent Warning Clearance Tests', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      storageService = DeviceStorageService();
      await storageService.clearAllDevices();
      await storageService.saveDevice(testDev);
    });

    test('getActiveRoutineForChannel clears warning state once channel turns OFF and stays clear across restarts', () async {
      final now = DateTime.now();
      final timeStr = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
      const dayMap = {1: 'Mon', 2: 'Tue', 3: 'Wed', 4: 'Thu', 5: 'Fri', 6: 'Sat', 7: 'Sun'};
      final currentDay = dayMap[now.weekday]!;

      // 1. Create routine for Switch 2 (channel 2) with a 1-minute auto-off
      final repo = const PreviewRoutineRepository();
      await repo.createRoutine(
        RoutineDraft(
          name: 'Switch 2 Routine',
          icon: 'timer',
          trigger: RoutineTrigger(
            kind: RoutineTriggerKind.timeSchedule,
            title: 'Schedule: $timeStr',
            detail: '$currentDay · $timeStr',
            timeOfDay: timeStr,
            days: [currentDay],
          ),
          actions: const [
            RoutineAction(
              kind: RoutineActionKind.switchChannel,
              title: 'Switch 2',
              detail: 'Turn On (1m timer)',
              deviceId: '4444688e-989d-458e-820e-ac62a99ed8e1',
              channelIndex: 2,
              targetState: true,
              pulseDurationMinutes: 1,
            ),
          ],
        ),
      );

      final ctrl = HomeController(
        repository: FakeHomeRepository(),
        connectionRepository: const UnavailableConnectionRepository(),
        storageService: storageService,
        autoSync: false,
      );
      await ctrl.loadHomeData();

      // Initially channel 2 is OFF (power == false)
      // When channel 2 is OFF, it is NOT actively running the pulse -> returns null!
      expect(ctrl.getActiveRoutineForChannel(testDev.id, 2), isNull);

      // Simulate routine execution: channel 2 is turned ON
      await ctrl.setDeviceChannelPower(deviceId: testDev.id, channelIndex: 2, value: true);
      expect(ctrl.getDeviceChannelPower(testDev.id, 2), isTrue);

      // While channel 2 is ON during its pulse window -> getActiveRoutineForChannel returns the routine!
      final activeR = ctrl.getActiveRoutineForChannel(testDev.id, 2);
      expect(activeR, isNotNull);
      expect(activeR!.name, equals('Switch 2 Routine'));

      // Routine on other channel (e.g. channel 1) -> must be null
      expect(ctrl.getActiveRoutineForChannel(testDev.id, 1), isNull);

      // Now routine finishes its 1-minute task: hardware turns channel 2 back to OFF!
      await ctrl.setDeviceChannelPower(deviceId: testDev.id, channelIndex: 2, value: false);
      expect(ctrl.getDeviceChannelPower(testDev.id, 2), isFalse);

      // Once channel 2 turns OFF -> active routine state must immediately clear to null everywhere!
      expect(ctrl.getActiveRoutineForChannel(testDev.id, 2), isNull);

      // Simulate App Restart:
      // A new HomeController instance is created and hydrates state.
      final rehydratedCtrl = HomeController(
        repository: FakeHomeRepository(),
        connectionRepository: const UnavailableConnectionRepository(),
        storageService: storageService,
        autoSync: false,
      );
      await rehydratedCtrl.loadHomeData();

      // Channel 2 is in Standby • OFF.
      // Must NOT show warning overlay after restart!
      expect(rehydratedCtrl.getActiveRoutineForChannel(testDev.id, 2), isNull);

      ctrl.dispose();
      rehydratedCtrl.dispose();
    });
  });
}
