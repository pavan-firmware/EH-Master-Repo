import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_home_application_v1/app/home_controller.dart';
import 'package:smart_home_application_v1/core/models/home_dashboard_models.dart';
import 'package:smart_home_application_v1/core/models/room_models.dart';
import 'package:smart_home_application_v1/core/repositories/fake_home_repository.dart';
import 'package:smart_home_application_v1/core/repositories/unavailable_connection_repository.dart';
import 'package:smart_home_application_v1/core/services/device_storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Post-Phase-9 Control & Blocker Resolution Tests', () {
    late HomeController controller;
    late FakeHomeRepository fakeRepo;
    late DeviceStorageService storage;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      storage = DeviceStorageService();
      await storage.clearAllDevices();
      fakeRepo = FakeHomeRepository();
      controller = HomeController(
        repository: fakeRepo,
        connectionRepository: const UnavailableConnectionRepository(),
        storageService: storage,
      );
      await Future<void>.delayed(const Duration(milliseconds: 20));
    });

    tearDown(() async {
      await Future<void>.delayed(const Duration(milliseconds: 20));
      controller.dispose();
    });

    test('1. Real Local Control: setLivingRoomLight dispatches command and confirms state', () async {
      controller.markDeviceProvisioned(
        deviceId: '4444688e-989d-458e-820e-ac62a99ed8e1',
        displayName: 'EH Smart Switch 3X',
        serialNumber: 'EH-SW3X-2026W12-00001',
        roomName: 'Living Room',
      );

      expect(controller.livingRoomLightOn, isFalse);
      await controller.setLivingRoomLight(true);
      expect(controller.livingRoomLightOn, isTrue);
      expect(controller.lightConfidence, ActuatorConfidence.confirmed);
      expect(controller.lightCommandPending, isFalse);

      await controller.setLivingRoomLight(false);
      expect(controller.livingRoomLightOn, isFalse);
      expect(controller.lightConfidence, ActuatorConfidence.confirmed);
    });

    test('2. Quick Controls: Customization and persistence across app reload', () async {
      controller.markDeviceProvisioned(
        deviceId: '4444688e-989d-458e-820e-ac62a99ed8e1',
        displayName: 'EH Smart Switch 3X',
        serialNumber: 'EH-SW3X-2026W12-00001',
        roomName: 'Living Room',
      );

      final customList = [
        '4444688e-989d-458e-820e-ac62a99ed8e1:1',
        '4444688e-989d-458e-820e-ac62a99ed8e1:2',
      ];

      await controller.setQuickControls(customList);
      expect(controller.quickControlIds, customList);
      expect(controller.dashboard.controls.length, 2);

      // Recreate controller to simulate restart
      final newController = HomeController(
        repository: fakeRepo,
        connectionRepository: const UnavailableConnectionRepository(),
        storageService: storage,
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(newController.quickControlIds, customList);
      newController.dispose();
    });

    test('3. Add Room: Custom rooms are created, persisted, and visible in rooms list', () async {
      controller.markDeviceProvisioned(
        deviceId: '4444688e-989d-458e-820e-ac62a99ed8e1',
        displayName: 'EH Smart Switch 3X',
        serialNumber: 'EH-SW3X-2026W12-00001',
        roomName: 'Living Room',
      );

      await controller.addCustomRoom('Balcony');
      await controller.addCustomRoom('Office');

      final roomNames = controller.rooms.map((r) => r.name).toList();
      expect(roomNames, contains('Living Room'));
      expect(roomNames, contains('Balcony'));
      expect(roomNames, contains('Office'));
    });

    test('4. Add Device: Provisioning second device maintains isolation and multi-room assignment', () async {
      controller.markDeviceProvisioned(
        deviceId: '4444688e-989d-458e-820e-ac62a99ed8e1',
        displayName: 'EH Smart Switch 3X A',
        serialNumber: 'EH-SW3X-2026W12-00001',
        roomName: 'Living Room',
      );

      controller.markDeviceProvisioned(
        deviceId: '5555688e-989d-458e-820e-ac62a99ed8e2',
        displayName: 'EH Smart Switch 3X B',
        serialNumber: 'EH-SW3X-2026W12-00002',
        roomName: 'Master Bedroom',
      );

      expect(controller.devices.length, 2);
      expect(controller.dashboard.deviceCount, 2);
      expect(controller.dashboard.rooms.length, 2);

      // Commanding Device A does not touch Device B
      await controller.setDeviceChannelPower(
        deviceId: '4444688e-989d-458e-820e-ac62a99ed8e1',
        channelIndex: 2,
        value: true,
      );

      expect(controller.getDeviceChannelPower('4444688e-989d-458e-820e-ac62a99ed8e1', 2), isTrue);
      expect(controller.getDeviceChannelPower('5555688e-989d-458e-820e-ac62a99ed8e2', 2), isFalse);
    });

    test('5. Capability Driven Model: Channels map to distinct capability kinds', () {
      controller.markDeviceProvisioned(
        deviceId: '4444688e-989d-458e-820e-ac62a99ed8e1',
        displayName: 'EH Smart Switch 3X',
        serialNumber: 'EH-SW3X-2026W12-00001',
        roomName: 'Living Room',
      );

      final room = controller.rooms.first;
      expect(room.capabilities.length, 3);
      expect(room.capabilities[0].kind, RoomCapabilityKind.light);
      expect(room.capabilities[1].kind, RoomCapabilityKind.outlet);
      expect(room.capabilities[2].kind, RoomCapabilityKind.switchControl);
    });
  });
}
