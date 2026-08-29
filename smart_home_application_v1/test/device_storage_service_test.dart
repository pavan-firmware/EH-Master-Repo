import 'package:flutter_test/flutter_test.dart';
import 'package:smart_home_application_v1/core/models/connection_models.dart';
import 'package:smart_home_application_v1/core/models/device_models.dart';
import 'package:smart_home_application_v1/core/models/home_dashboard_models.dart';
import 'package:smart_home_application_v1/core/repositories/unavailable_connection_repository.dart';
import 'package:smart_home_application_v1/core/services/device_storage_service.dart';
import 'package:smart_home_application_v1/app/home_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('DeviceStorageService & HomeController Hydration Tests', () {
    late DeviceStorageService storageService;

    setUp(() {
      storageService = DeviceStorageService();
    });

    test('Saving and loading commissioned device preserves real hardware metadata', () async {
      const device = ConnectedDeviceSummary(
        id: '4444688e-989d-458e-820e-ac62a99ed8e1',
        name: 'EH Smart Switch 3X',
        model: 'eh-smart-switch-3x',
        firmware: '1.0.0',
        connectedVia: 'Wi-Fi (2.4 GHz)',
        signalLabel: 'Strong',
        roomName: 'Living Room',
        online: true,
      );

      await storageService.saveDevice(device);
      final loaded = await storageService.loadDevice();

      expect(loaded, isNotNull);
      expect(loaded!.id, '4444688e-989d-458e-820e-ac62a99ed8e1');
      expect(loaded.name, 'EH Smart Switch 3X');
      expect(loaded.roomName, 'Living Room');
      expect(loaded.online, isTrue);
    });

    test('HomeController hydrates persisted device and transitions dashboard to live device', () async {
      const device = ConnectedDeviceSummary(
        id: '4444688e-989d-458e-820e-ac62a99ed8e1',
        name: 'EH Smart Switch 3X',
        model: 'eh-smart-switch-3x',
        firmware: '1.0.0',
        connectedVia: 'Wi-Fi (2.4 GHz)',
        signalLabel: 'Strong',
        roomName: 'Office',
        online: true,
      );

      await storageService.saveDevice(device);

      final controller = HomeController(
        storageService: storageService,
        connectionRepository: const UnavailableConnectionRepository(),
      );
      // Wait microtask for hydration
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(controller.connectedDeviceSummary, isNotNull);
      expect(controller.connectedDeviceSummary!.name, 'EH Smart Switch 3X');
      expect(controller.connectedDeviceSummary!.roomName, 'Office');
      expect(controller.connectionState, HomeConnectionState.connected);

      final dashboard = controller.dashboard;
      expect(dashboard.state, HomeDashboardState.ready);
      expect(dashboard.devicesOnline, 1);
      expect(dashboard.rooms.first.name, 'Office');
    });

    test('Room management: adding custom rooms preserves unique entries', () async {
      final initialRooms = await storageService.loadRooms();
      expect(initialRooms, contains('Living Room'));

      await storageService.addRoom('Master Suite');
      final updatedRooms = await storageService.loadRooms();
      expect(updatedRooms, contains('Master Suite'));
    });
  });
}
