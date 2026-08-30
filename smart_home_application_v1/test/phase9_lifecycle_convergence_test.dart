import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_home_application_v1/app/home_controller.dart';
import 'package:smart_home_application_v1/core/api/api_client.dart';
import 'package:smart_home_application_v1/core/api/sse_client.dart';
import 'package:smart_home_application_v1/core/models/connection_models.dart';
import 'package:smart_home_application_v1/core/models/device_models.dart';
import 'package:smart_home_application_v1/core/models/home_dashboard_models.dart';
import 'package:smart_home_application_v1/core/repositories/cloud_home_repository.dart';
import 'package:smart_home_application_v1/core/repositories/fake_home_repository.dart';
import 'package:smart_home_application_v1/core/repositories/unavailable_connection_repository.dart';
import 'package:smart_home_application_v1/core/services/device_storage_service.dart';
import 'package:smart_home_application_v1/core/services/realtime_event_service.dart';

class _FakeSseClient extends SseClient {
  _FakeSseClient() : super(ApiClient(baseUrl: 'http://localhost:3000'));

  final _controller = StreamController<SseEvent>.broadcast();

  @override
  Stream<SseEvent> get events => _controller.stream;

  @override
  bool get isConnected => true;

  void emitJson(
    Map<String, dynamic> payload, {
    String eventType = 'device.state',
    String id = 'evt_1',
  }) {
    final envelope = {
      'schemaVersion': 1,
      'eventId': id,
      'type': eventType,
      'occurredAt': DateTime.now().toIso8601String(),
      'homeId': 'home_default',
      'payload': payload,
    };
    _controller.add(
      SseEvent(id: id, event: eventType, data: jsonEncode(envelope)),
    );
  }

  @override
  void connect(String homeId) {}

  @override
  void disconnect() {}
}

class _TrackingHomeRepo extends FakeHomeRepository {
  final List<Map<String, dynamic>> dispatchedCommands = [];

  @override
  Future<CommandReceipt> sendCommand({
    required String deviceId,
    required String action,
    required Map<String, Object?> parameters,
    required String idempotencyKey,
  }) async {
    dispatchedCommands.add({
      'deviceId': deviceId,
      'action': action,
      'parameters': parameters,
      'idempotencyKey': idempotencyKey,
    });
    return CommandReceipt(
      commandId: idempotencyKey,
      state: CommandState.accepted,
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Phase 9 — Production Device Lifecycle & State Convergence Tests', () {
    late DeviceStorageService storageService;
    late FakeHomeRepository homeRepo;
    late _FakeSseClient mockSse;
    late RealtimeEventService realtimeService;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      storageService = DeviceStorageService();
      await storageService.clearAllDevices();
      homeRepo = FakeHomeRepository();
      mockSse = _FakeSseClient();
      realtimeService = RealtimeEventService(mockSse);
    });

    test(
      '1. Multi-Device Registration & Room Assignment creates distinct rooms and devices',
      () async {
        const dev1 = ConnectedDeviceSummary(
          id: '4444688e-989d-458e-820e-ac62a99ed8e1',
          name: 'EH Smart Switch 3X',
          model: 'eh-smart-switch-3x',
          firmware: '1.0.0',
          connectedVia: 'Wi-Fi (2.4 GHz)',
          signalLabel: 'Strong',
          roomName: 'Living Room',
          online: true,
        );

        const dev2 = ConnectedDeviceSummary(
          id: '5555688e-989d-458e-820e-ac62a99ed8e2',
          name: 'EH Smart Switch 3X',
          model: 'eh-smart-switch-3x',
          firmware: '1.0.0',
          connectedVia: 'Wi-Fi (2.4 GHz)',
          signalLabel: 'Strong',
          roomName: 'Master Bedroom',
          online: true,
        );

        await storageService.saveDevice(dev1);
        await storageService.saveDevice(dev2);

        final loaded = await storageService.loadDevices();
        expect(loaded.length, 2);

        final controller = HomeController(
          storageService: storageService,
          repository: homeRepo,
          connectionRepository: const UnavailableConnectionRepository(),
        );

        await Future<void>.delayed(const Duration(milliseconds: 50));

        expect(controller.devices.length, 2);
        expect(controller.rooms.length, 2);
        expect(
          controller.rooms.map((r) => r.name),
          containsAll(['Living Room', 'Master Bedroom']),
        );
      },
    );

    test(
      '2. Multi-Channel Switch resolves independent channel states',
      () async {
        const dev = ConnectedDeviceSummary(
          id: '4444688e-989d-458e-820e-ac62a99ed8e1',
          name: 'EH Smart Switch 3X',
          model: 'eh-smart-switch-3x',
          firmware: '1.0.0',
          connectedVia: 'Wi-Fi (2.4 GHz)',
          signalLabel: 'Strong',
          roomName: 'Balcony',
          online: true,
        );

        await storageService.saveDevice(dev);

        final controller = HomeController(
          storageService: storageService,
          repository: homeRepo,
          connectionRepository: const UnavailableConnectionRepository(),
          realtimeEventService: realtimeService,
        );

        await Future<void>.delayed(const Duration(milliseconds: 50));

        // Toggle Channel 2
        await controller.setDeviceChannelPower(
          deviceId: dev.id,
          channelIndex: 2,
          value: true,
        );

        expect(controller.getDeviceChannelPower(dev.id, 2), isTrue);
        expect(controller.getDeviceChannelPower(dev.id, 3), isFalse);

        // Verify room capabilities expose all 3 channels
        final room = controller.rooms.firstWhere((r) => r.name == 'Balcony');
        expect(room.capabilities.length, 3);
        expect(room.capabilities[1].value, 'On');
        expect(room.capabilities[2].value, 'Off');
      },
    );

    test(
      '3. Physical Switch Override converges state authoritatively via SSE',
      () async {
        const dev = ConnectedDeviceSummary(
          id: '4444688e-989d-458e-820e-ac62a99ed8e1',
          name: 'EH Smart Switch 3X',
          model: 'eh-smart-switch-3x',
          firmware: '1.0.0',
          connectedVia: 'Wi-Fi (2.4 GHz)',
          signalLabel: 'Strong',
          roomName: 'Living Room',
          online: true,
        );

        await storageService.saveDevice(dev);

        final controller = HomeController(
          storageService: storageService,
          repository: homeRepo,
          connectionRepository: const UnavailableConnectionRepository(),
          realtimeEventService: realtimeService,
        );

        await Future<void>.delayed(const Duration(milliseconds: 50));

        // Simulate ESP32 physical switch toggle ISR publishing SSE device.state
        mockSse.emitJson({
          'deviceId': '4444688e-989d-458e-820e-ac62a99ed8e1',
          'source': 'PHYSICAL_SWITCH',
          'channels': {
            'ch1': {'relay': false},
            'ch2': {'relay': true},
          },
        });

        await Future<void>.delayed(const Duration(milliseconds: 50));

        expect(
          controller.getDeviceChannelPower(
            '4444688e-989d-458e-820e-ac62a99ed8e1',
            1,
          ),
          isFalse,
        );
        expect(
          controller.getDeviceChannelPower(
            '4444688e-989d-458e-820e-ac62a99ed8e1',
            2,
          ),
          isTrue,
        );
        expect(controller.livingRoomLightOn, isFalse);
        expect(controller.lightConfidence, ActuatorConfidence.confirmed);
      },
    );

    test(
      '4. App restart rehydration restores complete device and room state without data loss',
      () async {
        const dev = ConnectedDeviceSummary(
          id: '4444688e-989d-458e-820e-ac62a99ed8e1',
          name: 'Smart Switch 3X',
          model: 'eh-smart-switch-3x',
          firmware: '1.0.0',
          connectedVia: 'Wi-Fi (2.4 GHz)',
          signalLabel: 'Strong',
          roomName: 'Kitchen',
          online: true,
        );

        await storageService.saveDevice(dev);

        // Re-initialize controller (simulating app restart)
        final rehydratedController = HomeController(
          storageService: storageService,
          repository: homeRepo,
          connectionRepository: const UnavailableConnectionRepository(),
        );

        await Future<void>.delayed(const Duration(milliseconds: 50));

        expect(
          rehydratedController.connectionState,
          HomeConnectionState.connected,
        );
        expect(rehydratedController.devices.length, 1);
        expect(rehydratedController.rooms.first.name, 'Kitchen');
        expect(rehydratedController.dashboard.state, HomeDashboardState.ready);
        expect(rehydratedController.dashboard.devicesOnline, 1);
      },
    );

    test(
      '5. Multi-Device Command Isolation: commanding Device A does not alter Device B',
      () async {
        const devA = ConnectedDeviceSummary(
          id: 'dev_aaaa_1111',
          name: 'Living Switch',
          model: 'eh-smart-switch-3x',
          firmware: '1.0.0',
          connectedVia: 'Wi-Fi',
          signalLabel: 'Strong',
          roomName: 'Living Room',
          online: true,
        );

        const devB = ConnectedDeviceSummary(
          id: 'dev_bbbb_2222',
          name: 'Bedroom Switch',
          model: 'eh-smart-switch-3x',
          firmware: '1.0.0',
          connectedVia: 'Wi-Fi',
          signalLabel: 'Strong',
          roomName: 'Bedroom',
          online: true,
        );

        await storageService.saveDevice(devA);
        await storageService.saveDevice(devB);

        final trackingRepo = _TrackingHomeRepo();
        final controller = HomeController(
          storageService: storageService,
          repository: trackingRepo,
          connectionRepository: const UnavailableConnectionRepository(),
        );

        await Future<void>.delayed(const Duration(milliseconds: 50));

        // Command Device A channel 1 to ON
        await controller.setDeviceChannelPower(
          deviceId: devA.id,
          channelIndex: 1,
          value: true,
        );

        // Verify Device A channel 1 is ON, Device B channel 1 is untouched (false)
        expect(controller.getDeviceChannelPower(devA.id, 1), isTrue);
        expect(controller.getDeviceChannelPower(devB.id, 1), isFalse);
        expect(trackingRepo.dispatchedCommands.last['deviceId'], devA.id);
      },
    );

    test(
      '6. Multi-Device Physical Event Isolation: SSE event for Device B leaves Device A untouched',
      () async {
        const devA = ConnectedDeviceSummary(
          id: 'dev_aaaa_1111',
          name: 'Living Switch',
          model: 'eh-smart-switch-3x',
          firmware: '1.0.0',
          connectedVia: 'Wi-Fi',
          signalLabel: 'Strong',
          roomName: 'Living Room',
          online: true,
        );

        const devB = ConnectedDeviceSummary(
          id: 'dev_bbbb_2222',
          name: 'Bedroom Switch',
          model: 'eh-smart-switch-3x',
          firmware: '1.0.0',
          connectedVia: 'Wi-Fi',
          signalLabel: 'Strong',
          roomName: 'Bedroom',
          online: true,
        );

        await storageService.saveDevice(devA);
        await storageService.saveDevice(devB);

        final controller = HomeController(
          storageService: storageService,
          repository: homeRepo,
          connectionRepository: const UnavailableConnectionRepository(),
          realtimeEventService: realtimeService,
        );

        await Future<void>.delayed(const Duration(milliseconds: 50));

        // Device A starts with ch1 ON
        await controller.setDeviceChannelPower(
          deviceId: devA.id,
          channelIndex: 1,
          value: true,
        );
        expect(controller.getDeviceChannelPower(devA.id, 1), isTrue);

        // Incoming physical switch event for Device B (ch2 turns ON)
        mockSse.emitJson({
          'deviceId': devB.id,
          'source': 'PHYSICAL_SWITCH',
          'channels': {
            'ch2': {'relay': true},
          },
        });

        await Future<void>.delayed(const Duration(milliseconds: 50));

        // Verify Device B ch2 is ON, but Device A ch1 remains ON and Device A ch2 remains OFF
        expect(controller.getDeviceChannelPower(devB.id, 2), isTrue);
        expect(controller.getDeviceChannelPower(devA.id, 1), isTrue);
        expect(controller.getDeviceChannelPower(devA.id, 2), isFalse);
      },
    );

    test('7. Multi-Home Explicit Context in CloudHomeRepository', () async {
      final apiClient = ApiClient(baseUrl: 'http://localhost:3000');
      final cloudRepo = CloudHomeRepository(
        apiClient,
        activeHomeId: 'home_custom_99',
      );

      expect(cloudRepo.activeHomeId, 'home_custom_99');
      cloudRepo.setActiveHomeId('home_new_101');
      expect(cloudRepo.activeHomeId, 'home_new_101');
    });
  });
}
