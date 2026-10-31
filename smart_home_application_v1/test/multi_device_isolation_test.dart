import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_home_application_v1/core/models/connection_models.dart';
import 'package:smart_home_application_v1/core/capabilities/repositories/product_catalog_repository.dart';
import 'package:smart_home_application_v1/core/services/device_storage_service.dart';
import 'package:smart_home_application_v1/core/services/local_lan_device_service.dart';
import 'package:smart_home_application_v1/app/home_controller.dart';
import 'package:smart_home_application_v1/core/repositories/fake_home_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Multi-Device Isolation & Integrity Tests', () {
    late DeviceStorageService storageService;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      storageService = DeviceStorageService();
    });

    test('DeviceStorageService.deduplicateDevices keeps separate devices completely distinct', () {
      const dev1 = ConnectedDeviceSummary(
        id: 'bcae1ecc-ddf3-4509-8317-f16298267bd2',
        name: 'EH Smart Switch 4X',
        model: 'eh-smart-switch-4x',
        firmware: '1.0.0',
        connectedVia: 'Wi-Fi',
        signalLabel: 'Strong',
        roomName: 'Living Room',
        online: true,
      );
      const dev2 = ConnectedDeviceSummary(
        id: '0354e19e-7da8-43e5-a414-c0b3671505c1',
        name: 'EH Smart Socket 3X',
        model: 'eh-smart-socket-3x',
        firmware: '1.0.0',
        connectedVia: 'Wi-Fi',
        signalLabel: 'Strong',
        roomName: 'Balcony',
        online: true,
      );

      final result = DeviceStorageService.deduplicateDevices([dev1, dev2]);
      expect(result.length, 2);
      expect(result.any((d) => d.id == dev1.id && d.name == 'EH Smart Switch 4X' && d.roomName == 'Living Room'), isTrue);
      expect(result.any((d) => d.id == dev2.id && d.name == 'EH Smart Socket 3X' && d.roomName == 'Balcony'), isTrue);
    });

    test('Channel labels for Device A do not pollute Device B', () async {
      const devA = 'bcae1ecc-ddf3-4509-8317-f16298267bd2';
      const devB = '0354e19e-7da8-43e5-a414-c0b3671505c1';

      await DeviceStorageService.saveChannelLabel(devA, 1, 'Ceiling Fan');
      await DeviceStorageService.saveChannelLabel(devB, 1, 'Microwave');

      final labelsA = DeviceStorageService.getChannelLabels(devA);
      final labelsB = DeviceStorageService.getChannelLabels(devB);

      expect(labelsA[1], 'Ceiling Fan');
      expect(labelsB[1], 'Microwave');
      expect(labelsA[1], isNot(equals(labelsB[1])));
    });

    test('LocalLanDeviceService.getDeviceIp returns null for unmapped device without arbitrary fallback', () {
      final lanService = LocalLanDeviceService.instance;
      lanService.registerDeviceIp('device-alpha', '192.168.0.100');

      expect(lanService.getDeviceIp('device-alpha'), '192.168.0.100');
      // Must NOT return device-alpha's IP for an unknown device!
      expect(lanService.getDeviceIp('unknown-device-beta'), isNull);
    });

    test('ProductCatalogRepository accurately normalizes 3X Socket vs 4X Switch', () {
      expect(MockProductCatalogRepository.normalizeVariantId('EH Smart Socket 3X'), 'eh-smart-socket-3x');
      expect(MockProductCatalogRepository.normalizeVariantId('EH Smart Switch 4X'), 'eh-smart-switch-4x');
      expect(MockProductCatalogRepository.normalizeVariantId('Smart Socket 1X'), 'eh-smart-socket-1x');
    });

    test('HomeController provisioning appends quick controls instead of wiping existing ones', () async {
      final controller = HomeController(
        storageService: storageService,
        repository: FakeHomeRepository(),
      );

      // Provision Switch 4X in Living Room
      controller.markDeviceProvisioned(
        deviceId: 'bcae1ecc-ddf3-4509-8317-f16298267bd2',
        displayName: 'EH Smart Switch 4X',
        serialNumber: 'EH-SW-4X-001',
        roomName: 'Living Room',
      );

      expect(controller.devices.length, 1);
      final initialQuickControls = List<String>.from(controller.selectedQuickControlIds);
      expect(initialQuickControls.any((id) => id.contains('bcae1ecc')), isTrue);

      // Provision Socket 3X in Balcony
      controller.markDeviceProvisioned(
        deviceId: '0354e19e-7da8-43e5-a414-c0b3671505c1',
        displayName: 'EH Smart Socket 3X',
        serialNumber: 'EH-SK-3X-002',
        roomName: 'Balcony',
      );

      // Both devices must exist concurrently!
      expect(controller.devices.length, 2);
      final dev1 = controller.devices.firstWhere((d) => d.id == 'bcae1ecc-ddf3-4509-8317-f16298267bd2');
      final dev2 = controller.devices.firstWhere((d) => d.id == '0354e19e-7da8-43e5-a414-c0b3671505c1');

      expect(dev1.name, 'EH Smart Switch 4X');
      expect(dev1.roomName, 'Living Room');
      expect(dev2.name, 'EH Smart Socket 3X');
      expect(dev2.roomName, 'Balcony');

      // Quick controls must contain controls from BOTH devices!
      final combinedQuick = controller.selectedQuickControlIds;
      expect(combinedQuick.any((id) => id.contains('bcae1ecc')), isTrue);
      expect(combinedQuick.any((id) => id.contains('0354e19e')), isTrue);
    });

    test('Toggling channel power on Device A does not alter Device B channel power', () async {
      SharedPreferences.setMockInitialValues({});
      final storageService = DeviceStorageService();
      final controller = HomeController(
        storageService: storageService,
        repository: FakeHomeRepository(),
      );

      final devA = 'bcae1ecc-ddf3-4509-8317-f16298267bd2';
      final devB = '0354e19e-7da8-43e5-a414-c0b3671505c1';

      controller.markDeviceProvisioned(
        deviceId: devA,
        displayName: 'EH Smart Switch 4X',
        serialNumber: 'EH-SW-4X-001',
        roomName: 'Living Room',
      );
      controller.markDeviceProvisioned(
        deviceId: devB,
        displayName: 'EH Smart Socket 3X',
        serialNumber: 'EH-SK-3X-002',
        roomName: 'Balcony',
      );

      // Actuate Device A ch1 -> ON
      await controller.setDeviceChannelPower(
        deviceId: devA,
        channelIndex: 1,
        value: true,
      );

      // Device A ch1 must be ON
      expect(controller.getDeviceChannelPower(devA, 1), isTrue);
      // Device B ch1 MUST BE OFF (no cross-talk or leaking!)
      expect(controller.getDeviceChannelPower(devB, 1), isFalse);

      // Actuate Device B ch2 -> ON
      await controller.setDeviceChannelPower(
        deviceId: devB,
        channelIndex: 2,
        value: true,
      );

      expect(controller.getDeviceChannelPower(devB, 2), isTrue);
      expect(controller.getDeviceChannelPower(devA, 2), isFalse);
    });

    test('Removing a device purges its channel states and IP mappings cleanly', () async {
      SharedPreferences.setMockInitialValues({});
      final storageService = DeviceStorageService();
      final controller = HomeController(
        storageService: storageService,
        repository: FakeHomeRepository(),
      );

      final devA = 'bcae1ecc-ddf3-4509-8317-f16298267bd2';
      final devB = '0354e19e-7da8-43e5-a414-c0b3671505c1';

      controller.markDeviceProvisioned(
        deviceId: devA,
        displayName: 'EH Smart Switch 4X',
        serialNumber: 'EH-SW-4X-001',
        roomName: 'Living Room',
      );
      controller.markDeviceProvisioned(
        deviceId: devB,
        displayName: 'EH Smart Socket 3X',
        serialNumber: 'EH-SK-3X-002',
        roomName: 'Balcony',
      );

      LocalLanDeviceService.instance.registerDeviceIp(devA, '192.168.0.101');
      LocalLanDeviceService.instance.registerDeviceIp(devB, '192.168.0.102');

      // Remove devA
      await controller.removeDevice(devA);

      expect(controller.devices.length, 1);
      expect(controller.devices.first.id, devB);
      expect(LocalLanDeviceService.instance.getDeviceIp(devA), isNull);
      expect(LocalLanDeviceService.instance.getDeviceIp(devB), '192.168.0.102');
    });
  });
}
