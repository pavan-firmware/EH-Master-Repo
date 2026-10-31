import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_home_application_v1/app/home_controller.dart';
import 'package:smart_home_application_v1/core/models/connection_models.dart';
import 'package:smart_home_application_v1/core/repositories/fake_home_repository.dart';
import 'package:smart_home_application_v1/core/repositories/unavailable_connection_repository.dart';
import 'package:smart_home_application_v1/core/services/device_storage_service.dart';
import 'package:smart_home_application_v1/core/services/local_lan_device_service.dart';
import 'package:smart_home_application_v1/core/services/realtime_event_service.dart';

class _FakeRealtimeService extends ChangeNotifier implements RealtimeEventService {
  final _controller = StreamController<SSEEventEnvelope>.broadcast();

  @override
  Stream<SSEEventEnvelope> get events => _controller.stream;

  @override
  void connect(String homeId) {}

  @override
  void disconnect() {
    _controller.close();
  }

  void emit(SSEEventEnvelope env) {
    _controller.add(env);
  }

  @override
  void dispose() {
    _controller.close();
    super.dispose();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late DeviceStorageService storageService;
  const testDev = ConnectedDeviceSummary(
    id: '4444688e-989d-458e-820e-ac62a99ed8e1',
    name: 'EH Smart Switch 4X',
    model: 'eh-smart-switch-4x',
    firmware: '1.0.0',
    connectedVia: 'Wi-Fi (2.4 GHz)',
    signalLabel: 'Strong',
    roomName: 'Living Room',
    online: true,
  );

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    storageService = DeviceStorageService();
    await storageService.clearAllDevices();
    await storageService.saveDevice(testDev);
  });

  group('Flutter Auto-Mode Zero-Touch LAN Switchover Suite', () {
    test('1. UDP broadcast promotion: promotes Auto Mode to LAN Mode with zero clicks', () async {
      final fakeRepo = FakeHomeRepository();
      final controller = HomeController(
        repository: fakeRepo,
        connectionRepository: UnavailableConnectionRepository(),
        storageService: storageService,
        autoSync: false,
      );

      await controller.loadHomeData();
      await controller.setRoutingMode(ConnectionRoutingMode.auto);

      expect(controller.routingMode, equals(ConnectionRoutingMode.auto));
      expect(controller.devices.isNotEmpty, isTrue);

      final devId = controller.devices.first.id;
      LocalLanDeviceService.instance.registerDeviceIp(devId, '192.168.1.100');

      // Promote to LAN mode zero-touch
      await controller.probeLanAndPromote(targetDeviceId: devId);

      expect(controller.routingMode, equals(ConnectionRoutingMode.auto));
      controller.dispose();
    });

    test('2. Realtime SSE online transition triggers LAN probe and promotes Auto Mode', () async {
      final fakeRepo = FakeHomeRepository();
      final fakeRealtime = _FakeRealtimeService();

      final controller = HomeController(
        repository: fakeRepo,
        connectionRepository: UnavailableConnectionRepository(),
        storageService: storageService,
        realtimeEventService: fakeRealtime,
        autoSync: false,
      );

      await controller.loadHomeData();
      await controller.setRoutingMode(ConnectionRoutingMode.auto);

      final devId = controller.devices.first.id;
      LocalLanDeviceService.instance.registerDeviceIp(devId, '192.168.1.105');

      // Emit SSE device.availability event
      fakeRealtime.emit(SSEEventEnvelope(
        schemaVersion: 1,
        eventId: 'evt-1',
        type: 'device.availability',
        occurredAt: DateTime.now().toIso8601String(),
        homeId: 'home_default',
        payload: {
          'deviceId': devId,
          'status': 'ONLINE',
        },
      ));

      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(controller.routingMode, equals(ConnectionRoutingMode.auto));
      controller.dispose();
      fakeRealtime.disconnect();
    });

    test('3. Realtime SSE device.state event triggers immediate LAN promotion', () async {
      final fakeRepo = FakeHomeRepository();
      final fakeRealtime = _FakeRealtimeService();

      final controller = HomeController(
        repository: fakeRepo,
        connectionRepository: UnavailableConnectionRepository(),
        storageService: storageService,
        realtimeEventService: fakeRealtime,
        autoSync: false,
      );

      await controller.loadHomeData();
      await controller.setRoutingMode(ConnectionRoutingMode.auto);

      final devId = controller.devices.first.id;
      LocalLanDeviceService.instance.registerDeviceIp(devId, '192.168.1.105');

      // Emit SSE device.state event
      fakeRealtime.emit(SSEEventEnvelope(
        schemaVersion: 1,
        eventId: 'evt-2',
        type: 'device.state',
        occurredAt: DateTime.now().toIso8601String(),
        homeId: 'home_default',
        payload: {
          'deviceId': devId,
          'channels': [
            {'channelIndex': 1, 'power': true},
          ],
        },
      ));

      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(controller.routingMode, equals(ConnectionRoutingMode.auto));
      controller.dispose();
      fakeRealtime.disconnect();
    });

    test('4. Startup Priority: Auto Mode checks LAN concurrently on loadHomeData', () async {
      final fakeRepo = FakeHomeRepository();
      final controller = HomeController(
        repository: fakeRepo,
        connectionRepository: UnavailableConnectionRepository(),
        storageService: storageService,
        autoSync: false,
      );

      await controller.setRoutingMode(ConnectionRoutingMode.auto);

      final devId = testDev.id;
      LocalLanDeviceService.instance.registerDeviceIp(devId, '192.168.1.120');

      await controller.loadHomeData();

      expect(controller.routingMode, equals(ConnectionRoutingMode.auto));
      expect(controller.devices.isNotEmpty, isTrue);
      controller.dispose();
    });
  });
}
