import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_home_application_v1/app/home_controller.dart';
import 'package:smart_home_application_v1/core/models/connection_models.dart';
import 'package:smart_home_application_v1/core/models/routine_models.dart';
import 'package:smart_home_application_v1/core/repositories/fake_home_repository.dart';
import 'package:smart_home_application_v1/core/repositories/unavailable_connection_repository.dart';
import 'package:smart_home_application_v1/core/services/device_storage_service.dart';
import 'package:smart_home_application_v1/core/services/edge_routine_sync_service.dart';
import 'package:smart_home_application_v1/features/automations/presentation/active_routine_guard.dart';
import 'package:smart_home_application_v1/features/devices/presentation/device_control_page.dart';

Routine _buildTestRoutine({
  required String id,
  required String name,
  required String deviceId,
  int channelIndex = 1,
  bool targetState = true,
  bool isToggle = false,
  int? pulseDurationMinutes,
  DateTime? scheduledAt,
  RoutineExecution? lastExecution,
}) {
  final schedTime = scheduledAt ?? DateTime.now();
  final hh = schedTime.hour.toString().padLeft(2, '0');
  final mm = schedTime.minute.toString().padLeft(2, '0');
  return Routine(
    id: id,
    name: name,
    icon: 'timer',
    isFavorite: false,
    enabled: true,
    trigger: RoutineTrigger(
      kind: RoutineTriggerKind.timeSchedule,
      title: 'Scheduled Trigger',
      detail: '$hh:$mm',
      timeOfDay: '$hh:$mm',
      days: const [],
    ),
    conditions: const [],
    actions: [
      RoutineAction(
        kind: channelIndex == 0
            ? RoutineActionKind.allChannels
            : RoutineActionKind.switchChannel,
        title: 'Channel $channelIndex',
        detail: isToggle ? 'Toggle' : (targetState ? 'Turn On' : 'Turn Off'),
        deviceId: deviceId,
        channelIndex: channelIndex,
        targetState: targetState,
        isToggle: isToggle,
        pulseDurationMinutes: pulseDurationMinutes,
      ),
    ],
    schedule: RoutineSchedule(label: '$hh:$mm', timezone: 'IST'),
    availability: RoutineAvailability.available,
    involvedDevices: [
      RoutineDevice(
        id: deviceId,
        name: 'EH Smart Switch 3X',
        room: 'Living Room',
        online: true,
        capabilities: const [],
      ),
    ],
    lastExecution: lastExecution,
    nextRun: null,
    summary: name,
    createdAt: schedTime,
    updatedAt: schedTime,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const devId = '8a629cef-a0d9-4fa5-8d38-c1014753aa30';

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    EdgeRoutineSyncService.instance.clearActiveRoutineExecution(devId, 1);
    EdgeRoutineSyncService.instance.clearActiveRoutineExecution(devId, 2);
    EdgeRoutineSyncService.instance.clearActiveRoutineExecution(devId, 3);
  });

  group('Active Routine Warning Detection (ON / OFF / Toggle)', () {
    test('1. Timed ON, OFF, and Toggle routines report active during execution', () {
      final now = DateTime.now();
      final rOn = _buildTestRoutine(
        id: 'rt_on_timed',
        name: 'Timed On',
        deviceId: devId,
        targetState: true,
        isToggle: false,
        pulseDurationMinutes: 2,
        scheduledAt: now,
      );
      final rOff = _buildTestRoutine(
        id: 'rt_off_timed',
        name: 'Timed Off',
        deviceId: devId,
        targetState: false,
        isToggle: false,
        pulseDurationMinutes: 2,
        scheduledAt: now,
      );
      final rToggle = _buildTestRoutine(
        id: 'rt_tog_timed',
        name: 'Timed Toggle',
        deviceId: devId,
        targetState: true,
        isToggle: true,
        pulseDurationMinutes: 2,
        scheduledAt: now,
      );

      final svc = EdgeRoutineSyncService.instance;
      expect(svc.isRoutineCurrentlyActive(rOn, targetChannel: 1, currentPower: true), isTrue);
      expect(svc.isRoutineCurrentlyActive(rOff, targetChannel: 1, currentPower: false), isTrue);
      expect(svc.isRoutineCurrentlyActive(rToggle, targetChannel: 1, currentPower: false), isTrue);
      expect(svc.isRoutineCurrentlyActive(rToggle, targetChannel: 1, currentPower: true), isTrue);
    });

    test('2. No-timer (continuous) ON, OFF, and Toggle routines report active during trigger window', () {
      final now = DateTime.now();
      final rOn = _buildTestRoutine(
        id: 'rt_on_notimer',
        name: 'On Continuous',
        deviceId: devId,
        targetState: true,
        isToggle: false,
        pulseDurationMinutes: null,
        scheduledAt: now,
      );
      final rOff = _buildTestRoutine(
        id: 'rt_off_notimer',
        name: 'Off Continuous',
        deviceId: devId,
        targetState: false,
        isToggle: false,
        pulseDurationMinutes: null,
        scheduledAt: now,
      );
      final rToggle = _buildTestRoutine(
        id: 'rt_tog_notimer',
        name: 'Toggle Continuous',
        deviceId: devId,
        targetState: true,
        isToggle: true,
        pulseDurationMinutes: null,
        scheduledAt: now,
      );

      final svc = EdgeRoutineSyncService.instance;
      expect(svc.isRoutineCurrentlyActive(rOn, targetChannel: 1, currentPower: true), isTrue);
      expect(svc.isRoutineCurrentlyActive(rOff, targetChannel: 1, currentPower: false), isTrue);
      expect(svc.isRoutineCurrentlyActive(rToggle, targetChannel: 1, currentPower: true), isTrue);
    });

    test('3. Registering active execution resolves via HomeController across normalized IDs', () async {
      final storage = DeviceStorageService();
      await storage.clearAllDevices();
      const dev = ConnectedDeviceSummary(
        id: devId,
        name: 'EH Smart Switch 3X',
        model: 'eh-smart-switch-3x',
        firmware: '1.1.0',
        connectedVia: 'Wi-Fi',
        signalLabel: 'Strong',
        roomName: 'Living Room',
        online: true,
      );
      await storage.saveDevice(dev);

      final ctrl = HomeController(
        repository: FakeHomeRepository(),
        connectionRepository: UnavailableConnectionRepository(),
        storageService: storage,
        autoSync: false,
      );
      addTearDown(ctrl.dispose);
      addTearDown(() => EdgeRoutineSyncService.instance.clearActiveRoutineExecution(devId, 2));
      await ctrl.setRoutingMode(ConnectionRoutingMode.cloudOnly);
      await ctrl.loadHomeData();

      final toggleRoutine = _buildTestRoutine(
        id: 'test_runtime_toggle',
        name: 'Night Toggle',
        deviceId: '8a629cefa0d94fa58d38c1014753aa30', // punctuation stripped
        channelIndex: 2,
        isToggle: true,
        pulseDurationMinutes: 1,
      );

      EdgeRoutineSyncService.instance.registerActiveRoutineExecution(
        toggleRoutine,
        targetChannel: 2,
        pulseDurationSeconds: 60,
      );

      expect(ctrl.getActiveRoutineForChannel(devId, 1), isNull);
      expect(ctrl.getActiveRoutineForChannel(devId, 2)?.id, equals('test_runtime_toggle'));
      expect(ctrl.getActiveRoutineForChannel(devId, 3), isNull);

      EdgeRoutineSyncService.instance.clearActiveRoutineExecution(devId, 2);
      expect(ctrl.getActiveRoutineForChannel(devId, 2), isNull);
    });

    testWidgets('4. DeviceControlPage renders RoutineControlWarningOverlay only on active channel', (tester) async {
      tester.view.physicalSize = const Size(900, 1800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final storage = DeviceStorageService();
      await storage.clearAllDevices();
      const dev = ConnectedDeviceSummary(
        id: devId,
        name: 'EH Smart Switch 3X',
        model: 'eh-smart-switch-3x',
        firmware: '1.1.0',
        connectedVia: 'Wi-Fi',
        signalLabel: 'Strong',
        roomName: 'Living Room',
        online: true,
      );
      await storage.saveDevice(dev);

      final ctrl = HomeController(
        repository: FakeHomeRepository(),
        connectionRepository: UnavailableConnectionRepository(),
        storageService: storage,
        autoSync: false,
      );
      addTearDown(ctrl.dispose);
      addTearDown(() => EdgeRoutineSyncService.instance.clearActiveRoutineExecution(devId, 1));
      await tester.runAsync(() async {
        await ctrl.setRoutingMode(ConnectionRoutingMode.cloudOnly);
        await ctrl.loadHomeData();
      });

      final activeCh1 = _buildTestRoutine(
        id: 'test_ch1_off',
        name: 'Auto Turn Off CH1',
        deviceId: devId,
        channelIndex: 1,
        targetState: false,
        isToggle: false,
        pulseDurationMinutes: 1,
      );
      EdgeRoutineSyncService.instance.registerActiveRoutineExecution(
        activeCh1,
        targetChannel: 1,
        pulseDurationSeconds: 60,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: DeviceControlPage(
            device: dev,
            homeController: ctrl,
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(RoutineControlWarningOverlay), findsOneWidget);
      expect(find.text('This control is being operated by a routine right now.'), findsOneWidget);
      expect(find.text('Stop Routine'), findsOneWidget);
      // Channels 2 and 3 remain controllable normally
      expect(find.text('Switch 2'), findsOneWidget);
      expect(find.text('Switch 3'), findsOneWidget);
    });
  });
}
