import 'dart:async';
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:smart_home_application_v1/core/api/api_client.dart';
import 'package:smart_home_application_v1/core/api/sse_client.dart';
import 'package:smart_home_application_v1/core/models/home_dashboard_models.dart';
import 'package:smart_home_application_v1/core/repositories/cloud_account_home_repository.dart';
import 'package:smart_home_application_v1/core/repositories/cloud_home_repository.dart';
import 'package:smart_home_application_v1/core/repositories/auth_repository.dart';
import 'package:smart_home_application_v1/core/repositories/unavailable_connection_repository.dart';
import 'package:smart_home_application_v1/core/services/realtime_event_service.dart';
import 'package:smart_home_application_v1/app/home_controller.dart';
import 'package:smart_home_application_v1/features/auth/auth_controller.dart';

// ---------------------------------------------------------------------------
// Test Fake ApiClient
// ---------------------------------------------------------------------------

class _FakeApiClient extends ApiClient {
  _FakeApiClient() : super(baseUrl: 'http://127.0.0.1:3000');

  final Map<String, dynamic> _mockGet = {};
  final Map<String, dynamic> _mockPost = {};
  final List<Map<String, dynamic>> _postedBodies = [];

  void setMockGet(String path, dynamic response) {
    _mockGet[path] = response;
  }

  void setMockPost(String path, dynamic response) {
    _mockPost[path] = response;
  }

  List<Map<String, dynamic>> get postedBodies => _postedBodies;

  @override
  Future<dynamic> get(String path) async {
    if (_mockGet.containsKey(path)) {
      final res = _mockGet[path];
      if (res is Exception) throw res;
      return res;
    }
    throw ApiException(statusCode: 404, message: 'Not found: $path');
  }

  @override
  Future<dynamic> post(String path, {Map<String, dynamic>? body}) async {
    if (body != null) _postedBodies.add({'path': path, 'body': body});
    if (_mockPost.containsKey(path)) {
      final res = _mockPost[path];
      if (res is Exception) throw res;
      return res;
    }
    throw ApiException(statusCode: 404, message: 'Not found: $path');
  }

  @override
  Future<dynamic> patch(String path, {Map<String, dynamic>? body}) async {
    return {'success': true};
  }

  @override
  Future<dynamic> delete(String path, {Map<String, dynamic>? body}) async {
    return {'success': true};
  }
}

class _FakeSseClient extends SseClient {
  _FakeSseClient(super.apiClient);

  final _controller = StreamController<SseEvent>.broadcast();

  @override
  Stream<SseEvent> get events => _controller.stream;

  void emit(dynamic event) {
    if (event is SseEvent) {
      _controller.add(event);
    } else if (event is SSEEventEnvelope) {
      final jsonStr = jsonEncode({
        'schemaVersion': event.schemaVersion,
        'eventId': event.eventId,
        'type': event.type,
        'occurredAt': event.occurredAt,
        'homeId': event.homeId,
        'deviceId': event.deviceId,
        'payload': event.payload,
      });
      _controller.add(SseEvent(id: event.eventId, event: event.type, data: jsonStr));
    }
  }

  void emitJson({
    required String type,
    required String homeId,
    String? deviceId,
    required Map<String, dynamic> payload,
  }) {
    final body = jsonEncode({
      'schemaVersion': 1,
      'eventId': 'evt_${DateTime.now().millisecondsSinceEpoch}',
      'type': type,
      'occurredAt': DateTime.now().toIso8601String(),
      'homeId': homeId,
      'deviceId': deviceId,
      'payload': payload,
    });
    _controller.add(SseEvent(event: type, data: body));
  }

  @override
  void connect(String homeId) {}

  @override
  void disconnect() {}

  void dispose() {
    _controller.close();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Phase 47 Stage 3 — A. Real Email/Password Authentication & Session', () {
    late _FakeApiClient apiClient;
    late AuthRepository authRepository;
    late AuthController authController;

    setUp(() {
      FlutterSecureStorage.setMockInitialValues({});
      apiClient = _FakeApiClient();
      authRepository = AuthRepository(apiClient);
      authController = AuthController(authRepository);
    });

    test('1. Valid email + correct password succeeds and sets authenticated state', () async {
      apiClient.setMockPost('/api/v1/auth/login', {
        'accessToken': 'jwt_access_valid_token',
        'refreshToken': 'jwt_refresh_valid_token',
        'expiresIn': 900,
        'tokenType': 'Bearer',
        'user': {
          'id': 'usr_valid_001',
          'email': 'owner@ehhome.test',
          'emailVerified': false,
          'role': 'OWNER',
        },
      });

      final success = await authController.login('owner@ehhome.test', 'Password123!');
      expect(success, isTrue);
      expect(authController.state, AuthState.authenticated);
      expect(authController.currentUser?.email, 'owner@ehhome.test');
      expect(authController.currentUser?.id, 'usr_valid_001');
      expect(authRepository.isAuthenticated, isTrue);
    });

    test('2. Wrong password or unknown email fails and sets failure state without fake login', () async {
      apiClient.setMockPost(
        '/api/v1/auth/login',
        ApiException(statusCode: 401, message: 'Invalid email or password', code: 'INVALID_CREDENTIALS'),
      );

      final success = await authController.login('unknown@ehhome.test', 'wrongpassword');
      expect(success, isFalse);
      expect(authController.state, AuthState.failure);
      expect(authController.errorMessage, contains('Invalid email or password'));
      expect(authRepository.isAuthenticated, isFalse);
    });

    test('3. Duplicate registration fails with conflict message', () async {
      apiClient.setMockPost(
        '/api/v1/auth/register',
        ApiException(statusCode: 409, message: "User with email 'existing@ehhome.test' already exists", code: 'DUPLICATE_EMAIL'),
      );

      final success = await authController.register('existing@ehhome.test', 'Password123!');
      expect(success, isFalse);
      expect(authController.state, AuthState.failure);
      expect(authController.errorMessage, contains('already exists'));
    });

    test('4. Session restoration with invalid/expired refresh token terminates to unauthenticated', () async {
      // If restoreSession fails to refresh, user must remain unauthenticated
      await authRepository.restoreSession();
      expect(authRepository.isAuthenticated, isFalse);
    });

    test('5. Logout revokes token and clears session cleanly', () async {
      apiClient.setMockPost('/api/v1/auth/login', {
        'accessToken': 'jwt_access_valid_token',
        'refreshToken': 'jwt_refresh_valid_token',
        'expiresIn': 900,
        'tokenType': 'Bearer',
        'user': {'id': 'usr_001', 'email': 'owner@ehhome.test', 'emailVerified': false, 'role': 'OWNER'},
      });
      await authController.login('owner@ehhome.test', 'Password123!');
      expect(authController.state, AuthState.authenticated);

      await authController.logout();
      expect(authController.state, AuthState.unauthenticated);
      expect(authRepository.isAuthenticated, isFalse);
      expect(authController.currentUser, isNull);
    });
  });

  group('Phase 47 Stage 3 — B. Real Home, Room, and Device Discovery', () {
    late _FakeApiClient apiClient;
    late CloudHomeRepository homeRepository;
    late CloudAccountHomeRepository accountHomeRepository;
    late HomeController homeController;

    setUp(() {
      apiClient = _FakeApiClient();
      homeRepository = CloudHomeRepository(apiClient);
      accountHomeRepository = CloudAccountHomeRepository(apiClient);
      homeController = HomeController(
        repository: homeRepository,
        connectionRepository: const UnavailableConnectionRepository(),
        cloudEnabled: true,
      );
    });

    test('1. Zero homes returns empty home state without generating fake homes', () async {
      apiClient.setMockGet('/api/v1/homes', <dynamic>[]);

      final homes = await accountHomeRepository.listHomes();
      expect(homes, isEmpty);

      await homeController.loadHomeData(homeId: null);
      expect(homeController.devices, isEmpty);
      expect(homeController.rooms, isEmpty);
      expect(homeController.dashboard.deviceCount, 0);
    });

    test('2. Real homes rendered from backend response', () async {
      apiClient.setMockGet('/api/v1/homes', [
        {
          'id': 'home_alpha_001',
          'name': 'Primary Residence',
          'role': 'OWNER',
          'createdAt': '2026-09-09T00:00:00.000Z',
        }
      ]);

      final homes = await accountHomeRepository.listHomes();
      expect(homes.length, 1);
      expect(homes.first.name, 'Primary Residence');
      expect(homes.first.id, 'home_alpha_001');
    });

    test('3. Real rooms loaded from GET /api/v1/homes/:id/rooms', () async {
      apiClient.setMockGet('/api/v1/homes/home_alpha_001/rooms', [
        {'id': 'room_liv_1', 'name': 'Living Room', 'iconKey': 'living'},
        {'id': 'room_kit_2', 'name': 'Kitchen', 'iconKey': 'kitchen'},
      ]);
      apiClient.setMockGet('/api/v1/homes/home_alpha_001/devices', <dynamic>[]);

      await homeController.loadHomeData(homeId: 'home_alpha_001');
      expect(homeController.rooms.length, 2);
      expect(homeController.rooms.map((r) => r.name), containsAll(['Living Room', 'Kitchen']));
    });

    test('4. Create room calls real backend POST /api/v1/homes/:id/rooms', () async {
      homeController.setActiveHomeId('home_alpha_001');
      apiClient.setMockPost('/api/v1/homes/home_alpha_001/rooms', {
        'id': 'room_balc_3',
        'name': 'Balcony',
        'iconKey': 'living',
      });

      await homeController.addCustomRoom('Balcony');
      expect(homeController.rooms.any((r) => r.name == 'Balcony'), isTrue);
      expect(apiClient.postedBodies.any((p) => p['path'] == '/api/v1/homes/home_alpha_001/rooms'), isTrue);
    });

    test('5. Real physical ESP32 3X device loaded with dynamic channel resolution', () async {
      apiClient.setMockGet('/api/v1/homes/home_alpha_001/devices', [
        {
          'deviceId': 'ce196211-91cf-496a-9403-709d8589eb15',
          'serialNumber': 'EH-SW3X-2026W12-00001',
          'productVariantId': 'eh-smart-socket-3x',
          'hardwareRevision': 'HW_1_0',
          'firmwareFamily': 'esp32c6-socket-platform',
          'firmwareVersion': '1.0.0',
          'displayName': 'EH Smart Socket 3X',
          'roomName': 'Living Room',
          'connectionState': 'ONLINE',
          'channels': [
            {'channelIndex': 1, 'defaultLabel': 'Socket 1', 'label': 'Socket 1'},
            {'channelIndex': 2, 'defaultLabel': 'Socket 2', 'label': 'Socket 2'},
            {'channelIndex': 3, 'defaultLabel': 'Socket 3', 'label': 'Socket 3'},
          ],
          'capabilities': ['switch', 'relay', 'energy', 'voltage', 'current', 'power'],
        }
      ]);
      apiClient.setMockGet('/api/v1/homes/home_alpha_001/rooms', <dynamic>[]);

      await homeController.loadHomeData(homeId: 'home_alpha_001');
      expect(homeController.devices.length, 1);
      final dev = homeController.devices.first;
      expect(dev.id, 'ce196211-91cf-496a-9403-709d8589eb15');
      expect(dev.name, 'EH Smart Socket 3X');
      expect(dev.online, isTrue);

      // Verify dynamic 3X Socket channel rendering in rooms
      final rooms = homeController.rooms;
      expect(rooms.isNotEmpty, isTrue);
      final livingRoom = rooms.first;
      expect(livingRoom.capabilities.length, 3);
      expect(livingRoom.capabilities[0].label, contains('Socket 1'));
      expect(livingRoom.capabilities[1].label, contains('Socket 2'));
      expect(livingRoom.capabilities[2].label, contains('Socket 3'));
    });
  });

  group('Phase 47 Stage 3 — C. Real Command Flow & Authoritative State Convergence', () {
    late _FakeApiClient apiClient;
    late _FakeSseClient sseClient;
    late RealtimeEventService realtimeService;
    late CloudHomeRepository homeRepository;
    late HomeController homeController;

    setUp(() {
      apiClient = _FakeApiClient();
      sseClient = _FakeSseClient(apiClient);
      realtimeService = RealtimeEventService(sseClient);
      homeRepository = CloudHomeRepository(apiClient);
      homeController = HomeController(
        repository: homeRepository,
        connectionRepository: const UnavailableConnectionRepository(),
        realtimeEventService: realtimeService,
        cloudEnabled: true,
      );
    });

    test('1. Command dispatches canonical schema to POST /api/v1/commands/send', () async {
      const devId = 'ce196211-91cf-496a-9403-709d8589eb15';
      apiClient.setMockPost('/api/v1/commands/send', {
        'commandId': '0194fe23-7a1b-7890-a123-456789000001',
        'status': 'CREATED',
      });

      await homeController.setDeviceChannelPower(
        deviceId: devId,
        channelIndex: 2,
        value: true,
      );

      final post = apiClient.postedBodies.firstWhere(
        (p) => p['path'] == '/api/v1/commands/send',
      );
      final body = post['body'] as Map<String, dynamic>;
      expect(body['deviceId'], devId);
      expect(body['channelIndex'], 2);
      expect(body['action'], 'setPower');
      expect(body['params']['enabled'], true);
      expect(body['source'], 'APP');
      expect(body.containsKey('commandId'), isTrue);
    });

    test('2. Authoritative SSE device.state converges real channel relay state', () async {
      const devId = 'ce196211-91cf-496a-9403-709d8589eb15';

      // Initial state: ch1=false, ch2=false, ch3=false
      expect(homeController.getDeviceChannelPower(devId, 1), isFalse);
      expect(homeController.getDeviceChannelPower(devId, 2), isFalse);

      // Emit SSE authoritative state event
      sseClient.emit(SSEEventEnvelope(
        schemaVersion: 1,
        eventId: 'evt_001',
        type: 'device.state',
        occurredAt: DateTime.now().toIso8601String(),
        homeId: 'home_001',
        deviceId: devId,
        payload: {
          'deviceId': devId,
          'channels': {
            '1': {'relay': true},
            '2': {'relay': false},
            '3': {'relay': true},
          }
        },
      ));

      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(homeController.getDeviceChannelPower(devId, 1), isTrue);
      expect(homeController.getDeviceChannelPower(devId, 2), isFalse);
      expect(homeController.getDeviceChannelPower(devId, 3), isTrue);
    });

    test('3. Authoritative SSE command.receipt reconciles pending confidence', () async {
      expect(homeController.lightConfidence, ActuatorConfidence.unknown);

      sseClient.emit(SSEEventEnvelope(
        schemaVersion: 1,
        eventId: 'evt_002',
        type: 'command.receipt',
        occurredAt: DateTime.now().toIso8601String(),
        homeId: 'home_001',
        deviceId: 'ce196211-91cf-496a-9403-709d8589eb15',
        payload: {'status': 'APPLIED', 'commandId': 'cmd_001'},
      ));

      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(homeController.lightConfidence, ActuatorConfidence.confirmed);
      expect(homeController.lightCommandPending, isFalse);
    });
  });

  group('Phase 47 Stage 3 — D. Deterministic Terminal Loading States', () {
    late _FakeApiClient apiClient;
    late CloudHomeRepository homeRepository;
    late HomeController homeController;

    setUp(() {
      apiClient = _FakeApiClient();
      homeRepository = CloudHomeRepository(apiClient);
      homeController = HomeController(
        repository: homeRepository,
        connectionRepository: const UnavailableConnectionRepository(),
        cloudEnabled: true,
      );
    });

    test('1. Successful data fetch terminates loading with isLoading=false and no error', () async {
      apiClient.setMockGet('/api/v1/homes/home_001/devices', <dynamic>[]);
      apiClient.setMockGet('/api/v1/homes/home_001/rooms', <dynamic>[]);

      expect(homeController.isLoading, isFalse);
      final future = homeController.loadHomeData(homeId: 'home_001');
      expect(homeController.isLoading, isTrue);

      await future;
      expect(homeController.isLoading, isFalse);
      expect(homeController.errorMessage, isNull);
    });

    test('2. API error terminates loading with isLoading=false and explicit error message', () async {
      apiClient.setMockGet(
        '/api/v1/homes/home_001/devices',
        ApiException(statusCode: 500, message: 'Internal Server Error'),
      );

      await homeController.loadHomeData(homeId: 'home_001');
      expect(homeController.isLoading, isFalse);
      expect(homeController.errorMessage, isNotNull);
      expect(homeController.errorMessage, contains('Internal Server Error'));
    });
  });
}
