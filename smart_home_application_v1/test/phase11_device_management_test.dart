import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:smart_home_application_v1/core/api/api_client.dart';
import 'package:smart_home_application_v1/core/models/device_management_models.dart';
import 'package:smart_home_application_v1/core/repositories/cloud_device_management_repository.dart';
import 'package:smart_home_application_v1/features/diagnostics/presentation/device_management_page.dart';

class MockApiClient implements ApiClient {
  final Map<String, dynamic> mockResponses = {};
  final List<String> recordedCalls = [];

  @override
  String get baseUrl => 'http://127.0.0.1:3000';

  @override
  Future<Map<String, dynamic>> get(String path, {Map<String, String>? headers}) async {
    recordedCalls.add('GET $path');
    if (mockResponses.containsKey('GET $path')) {
      return mockResponses['GET $path'] as Map<String, dynamic>;
    }
    return {'success': true, 'data': {}};
  }

  @override
  Future<dynamic> post(String path, {Map<String, dynamic>? body}) async {
    recordedCalls.add('POST $path');
    return {'success': true, 'data': {}};
  }

  @override
  Future<dynamic> put(String path, {Map<String, dynamic>? body}) async {
    recordedCalls.add('PUT $path');
    return {'success': true, 'data': {}};
  }

  @override
  Future<dynamic> patch(String path, {Map<String, dynamic>? body}) async {
    recordedCalls.add('PATCH $path');
    return {'success': true, 'data': {}};
  }

  @override
  Future<dynamic> delete(String path) async {
    recordedCalls.add('DELETE $path');
    return {'success': true, 'data': {}};
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeDeviceManagementRepository implements DeviceManagementRepository {
  DeviceDetailsModel? currentDetails;
  List<DeviceActivityLogItemModel> currentActivity = [];
  bool wasRemoved = false;
  String? lastRenamed;
  String? lastMovedRoom;

  @override
  Future<DeviceDetailsModel> getDeviceDetails(String homeId, String deviceId) async {
    return currentDetails ??
        DeviceDetailsModel(
          deviceId: deviceId,
          serialNumber: 'EH-SW3X-2026W12-00001',
          productVariantId: 'eh-smart-switch-3x',
          hardwareRevision: 'HW_1_0',
          firmwareFamily: 'esp32c6-switch-platform',
          firmwareVersion: '1.2.0',
          displayName: 'Kitchen Switch',
          homeId: homeId,
          roomId: 'room_kitchen',
          roomName: 'Kitchen',
          connectionState: 'ONLINE',
          lastSeenAt: DateTime.now(),
          health: const DeviceHealthMetricsModel(
            status: 'ONLINE',
            connectionState: 'ONLINE',
            commandSuccessCount: 15,
            commandFailureCount: 0,
          ),
          ota: const DeviceOtaInfo(
            currentVersion: '1.2.0',
            updateAvailable: false,
          ),
        );
  }

  @override
  Future<DeviceHealthMetricsModel> getDeviceHealth(String homeId, String deviceId) async {
    return const DeviceHealthMetricsModel(
      status: 'ONLINE',
      connectionState: 'ONLINE',
      commandSuccessCount: 15,
      commandFailureCount: 0,
    );
  }

  @override
  Future<List<DeviceActivityLogItemModel>> getDeviceActivity(
    String homeId,
    String deviceId, {
    int limit = 50,
  }) async {
    return currentActivity;
  }

  @override
  Future<void> renameDevice(String homeId, String deviceId, String newName) async {
    lastRenamed = newName;
  }

  @override
  Future<void> moveDevice(String homeId, String deviceId, String? newRoomId) async {
    lastMovedRoom = newRoomId;
  }

  @override
  Future<void> removeDevice(String homeId, String deviceId) async {
    wasRemoved = true;
  }
}

void main() {
  group('Phase 11 — Device Management Models & Repository Tests', () {
    test('DeviceDetailsModel JSON roundtrip', () {
      final json = {
        'deviceId': 'dev_test_123',
        'serialNumber': 'EH-SW3X-2026W12-00001',
        'productVariantId': 'eh-smart-switch-3x',
        'hardwareRevision': 'HW_1_0',
        'firmwareFamily': 'esp32c6-switch-platform',
        'firmwareVersion': '1.2.0',
        'displayName': 'Hallway Switch',
        'homeId': 'home_test_1',
        'roomId': 'room_hallway',
        'roomName': 'Hallway',
        'connectionState': 'ONLINE',
        'health': {
          'status': 'ONLINE',
          'connectionState': 'ONLINE',
          'commandSuccessCount': 10,
          'commandFailureCount': 1,
        },
        'channels': [],
        'capabilities': ['power'],
      };

      final model = DeviceDetailsModel.fromJson(json);
      expect(model.deviceId, 'dev_test_123');
      expect(model.displayName, 'Hallway Switch');
      expect(model.health.status, 'ONLINE');
      expect(model.health.commandSuccessCount, 10);

      final outJson = model.toJson();
      expect(outJson['displayName'], 'Hallway Switch');
    });

    test('DeviceActivityLogItemModel JSON roundtrip', () {
      final json = {
        'id': 'log_123',
        'home_id': 'home_test_1',
        'device_id': 'dev_test_123',
        'event_type': 'device_renamed',
        'severity': 'info',
        'message': 'Device renamed to Front Switch',
        'correlation_id': 'corr_999',
        'details': {'oldName': 'Switch 1', 'newName': 'Front Switch'},
        'created_at': '2026-08-30T10:00:00.000Z',
      };

      final model = DeviceActivityLogItemModel.fromJson(json);
      expect(model.id, 'log_123');
      expect(model.eventType, 'device_renamed');
      expect(model.message, 'Device renamed to Front Switch');
      expect(model.correlationId, 'corr_999');
    });

    test('CloudDeviceManagementRepository routes API calls correctly', () async {
      final mockApi = MockApiClient();
      mockApi.mockResponses['GET /api/v1/homes/home_1/devices/dev_1/details'] = {
        'data': {
          'deviceId': 'dev_1',
          'serialNumber': 'EH-SW3X-001',
          'productVariantId': 'eh-smart-switch-3x',
          'hardwareRevision': 'HW_1_0',
          'firmwareFamily': 'esp32c6-switch-platform',
          'firmwareVersion': '1.0.0',
          'displayName': 'Balcony Switch',
          'connectionState': 'ONLINE',
          'health': {'status': 'ONLINE', 'connectionState': 'ONLINE'},
        }
      };

      mockApi.mockResponses['GET /api/v1/homes/home_1/devices/dev_1/activity?limit=50'] = {
        'data': [
          {
            'id': 'act_1',
            'device_id': 'dev_1',
            'event_type': 'connected',
            'severity': 'info',
            'message': 'Device connected',
            'created_at': '2026-08-30T12:00:00.000Z',
          }
        ]
      };

      final repo = CloudDeviceManagementRepository(mockApi);

      final details = await repo.getDeviceDetails('home_1', 'dev_1');
      expect(details.displayName, 'Balcony Switch');
      expect(mockApi.recordedCalls, contains('GET /api/v1/homes/home_1/devices/dev_1/details'));

      final activity = await repo.getDeviceActivity('home_1', 'dev_1');
      expect(activity.length, 1);
      expect(activity[0].eventType, 'connected');

      await repo.renameDevice('home_1', 'dev_1', 'New Name');
      expect(mockApi.recordedCalls, contains('PATCH /api/v1/homes/home_1/devices/dev_1/rename'));

      await repo.moveDevice('home_1', 'dev_1', 'room_2');
      expect(mockApi.recordedCalls, contains('PATCH /api/v1/homes/home_1/devices/dev_1/move'));

      await repo.removeDevice('home_1', 'dev_1');
      expect(mockApi.recordedCalls, contains('DELETE /api/v1/homes/home_1/devices/dev_1'));
    });
  });

  group('Phase 11 — DeviceManagementPage Widget Tests', () {
    testWidgets('DeviceManagementPage renders details, health, and activity', (tester) async {
      final fakeRepo = FakeDeviceManagementRepository();
      fakeRepo.currentActivity = [
        DeviceActivityLogItemModel(
          id: 'act_test_1',
          deviceId: 'dev_kitchen_1',
          eventType: 'connected',
          severity: 'info',
          message: 'Device connected via MQTT',
          createdAt: DateTime.now(),
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: DeviceManagementPage(
            homeId: 'home_test_1',
            deviceId: 'dev_kitchen_1',
            repository: fakeRepo,
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Device Management'), findsOneWidget);
      expect(find.text('Kitchen Switch'), findsOneWidget);
      expect(find.text('Health & Reliability'), findsOneWidget);
      expect(find.text('Hardware & Firmware'), findsOneWidget);
      expect(find.text('EH-SW3X-2026W12-00001'), findsOneWidget);
      expect(find.text('Rename Device'), findsOneWidget);
      expect(find.text('Remove from Home'), findsOneWidget);

      await tester.scrollUntilVisible(
        find.text('Device connected via MQTT'),
        200,
      );
      expect(find.text('Device connected via MQTT'), findsOneWidget);
    });
  });
}
