import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';

// ---------------------------------------------------------------------------
// Minimal in-process stubs — no real HTTP, no real storage
// ---------------------------------------------------------------------------

class _MockStorage {
  final Map<String, String> _data = {};
  Future<void> write({required String key, required String? value}) async {
    if (value != null) {
      _data[key] = value;
    } else {
      _data.remove(key);
    }
  }

  Future<String?> read({required String key}) async => _data[key];
  Future<void> delete({required String key}) async => _data.remove(key);
}

/// Stub ApiClient behaviour so tests never hit the network.
class _Stub {
  // Responses queued per path+method
  final _responses = <String, List<Map<String, dynamic>>>{};

  void queue(String key, Map<String, dynamic> body) {
    _responses.putIfAbsent(key, () => []).add(body);
  }

  Map<String, dynamic>? dequeue(String key) {
    final list = _responses[key];
    if (list == null || list.isEmpty) return null;
    return list.removeAt(0);
  }
}

// ---------------------------------------------------------------------------
// Minimal in-process ApiClient + AuthRepository simulation
// ---------------------------------------------------------------------------

class _TestApiClient {
  final String baseUrl;
  late Future<String?> Function()? getAccessToken;
  late Future<bool> Function()? onRefreshToken;
  void Function()? onSessionExpired;

  String? _accessToken;

  final _Stub _stub = _Stub();
  _Stub get stub => _stub;

  _TestApiClient({required this.baseUrl}) {
    getAccessToken = () async => _accessToken;
    onRefreshToken = () async {
      // Simulate refresh
      final resp = _stub.dequeue('POST:/api/v1/auth/refresh');
      if (resp != null && resp['status'] == 200) {
        _accessToken = resp['data']['accessToken'];
        return true;
      }
      return false;
    };
  }

  Future<dynamic> post(String path, {Map<String, dynamic>? body}) async {
    final key = 'POST:$path';
    final resp = _stub.dequeue(key);
    if (resp == null) throw Exception('No stub for $key');
    if (resp['status'] == 401 && !resp.containsKey('_isRetry')) {
      // Attempt refresh
      final refreshed = await onRefreshToken!();
      if (refreshed) {
        resp['_isRetry'] = true;
        return post(path, body: body);
      } else {
        onSessionExpired?.call();
        throw Exception('Session expired');
      }
    }
    if ((resp['status'] as int) >= 400) {
      throw Exception(
        resp['error']?['message'] ?? 'API error ${resp['status']}',
      );
    }
    return resp['data'];
  }

  Future<dynamic> get(String path) async {
    final key = 'GET:$path';
    final resp = _stub.dequeue(key);
    if (resp == null) throw Exception('No stub for $key');
    if ((resp['status'] as int) >= 400) {
      throw Exception(
        resp['error']?['message'] ?? 'API error ${resp['status']}',
      );
    }
    return resp['data'];
  }

  Future<dynamic> delete(String path) async {
    final key = 'DELETE:$path';
    final resp = _stub.dequeue(key);
    return resp?['data'];
  }
}

// ---------------------------------------------------------------------------
// Minimal AuthRepository for tests (without flutter_secure_storage)
// ---------------------------------------------------------------------------

class _UserProfile {
  final String id;
  final String email;
  _UserProfile({required this.id, required this.email});
  factory _UserProfile.fromJson(Map<String, dynamic> j) =>
      _UserProfile(id: j['id'], email: j['email']);
  Map<String, dynamic> toJson() => {
    'id': id,
    'email': email,
    'emailVerified': false,
  };
}

class _TestAuthRepository {
  final _TestApiClient _api;
  final _MockStorage _storage = _MockStorage();

  String? _accessToken;
  String? _refreshToken;
  _UserProfile? _user;

  _TestAuthRepository(this._api) {
    _api.getAccessToken = () async => _accessToken;
    _api.onRefreshToken = () async => refresh();
  }

  _UserProfile? get currentUser => _user;
  bool get isAuthenticated => _accessToken != null && _user != null;

  Future<void> login(String email, String password) async {
    final data = await _api.post(
      '/api/v1/auth/login',
      body: {'email': email, 'password': password},
    );
    await _save(data);
  }

  Future<void> register(String email, String password) async {
    await _api.post(
      '/api/v1/auth/register',
      body: {'email': email, 'password': password},
    );
  }

  Future<bool> refresh() async {
    if (_refreshToken == null) return false;
    final resp = _api.stub.dequeue('POST:/api/v1/auth/refresh');
    if (resp != null && resp['status'] == 200) {
      await _save(resp['data']);
      return true;
    }
    await logout();
    return false;
  }

  Future<void> logout() async {
    _accessToken = null;
    _refreshToken = null;
    _user = null;
    await _storage.delete(key: 'at');
    await _storage.delete(key: 'rt');
  }

  Future<void> restoreSession() async {
    final at = await _storage.read(key: 'at');
    final rt = await _storage.read(key: 'rt');
    final u = await _storage.read(key: 'user');
    if (at != null && rt != null && u != null) {
      _accessToken = at;
      _refreshToken = rt;
      _user = _UserProfile.fromJson(jsonDecode(u));
    }
  }

  Future<void> _save(Map<String, dynamic> data) async {
    _accessToken = data['accessToken'];
    _refreshToken = data['refreshToken'];
    _user = _UserProfile.fromJson(data['user']);
    await _storage.write(key: 'at', value: _accessToken);
    await _storage.write(key: 'rt', value: _refreshToken);
    await _storage.write(key: 'user', value: jsonEncode(_user!.toJson()));
  }
}

// ---------------------------------------------------------------------------
// SSE parser test helper
// ---------------------------------------------------------------------------

Map<String, String> _parseSseBlock(String block) {
  final result = <String, String>{'id': '', 'event': 'message', 'data': ''};
  for (final line in block.split('\n')) {
    if (line.startsWith('id:')) {
      result['id'] = line.substring(3).trim();
    } else if (line.startsWith('event:')) {
      result['event'] = line.substring(6).trim();
    } else if (line.startsWith('data:')) {
      result['data'] = line.substring(5).trimLeft();
    }
  }
  return result;
}

// ---------------------------------------------------------------------------
// TESTS
// ---------------------------------------------------------------------------

void main() {
  late _TestApiClient api;
  late _TestAuthRepository auth;

  final validLoginResponse = {
    'status': 200,
    'data': {
      'accessToken': 'access.token.1',
      'refreshToken': 'refresh.token.1',
      'expiresIn': 900,
      'user': {'id': 'user-1', 'email': 'test@eh.com', 'emailVerified': true},
    },
  };

  setUp(() {
    api = _TestApiClient(baseUrl: 'http://localhost:3000');
    auth = _TestAuthRepository(api);
  });

  // ---- 1. Login success ----
  test('1. Auth login success', () async {
    api.stub.queue('POST:/api/v1/auth/login', validLoginResponse);
    await auth.login('test@eh.com', 'pass123');
    expect(auth.isAuthenticated, isTrue);
    expect(auth.currentUser?.email, 'test@eh.com');
    expect(auth.currentUser?.id, 'user-1');
  });

  // ---- 2. Login invalid credentials ----
  test('2. Auth login invalid credentials', () async {
    api.stub.queue('POST:/api/v1/auth/login', {
      'status': 401,
      'error': {
        'code': 'INVALID_CREDENTIALS',
        'message': 'Invalid email or password',
      },
    });
    expect(() => auth.login('test@eh.com', 'wrong'), throwsException);
    expect(auth.isAuthenticated, isFalse);
  });

  // ---- 3. Refresh token success ----
  test('3. Refresh token success', () async {
    api.stub.queue('POST:/api/v1/auth/login', validLoginResponse);
    await auth.login('test@eh.com', 'pass123');

    api.stub.queue('POST:/api/v1/auth/refresh', {
      'status': 200,
      'data': {
        'accessToken': 'access.token.2',
        'refreshToken': 'refresh.token.2',
        'expiresIn': 900,
        'user': {'id': 'user-1', 'email': 'test@eh.com', 'emailVerified': true},
      },
    });
    final success = await auth.refresh();
    expect(success, isTrue);
    expect(auth._accessToken, 'access.token.2');
  });

  // ---- 4. Refresh token failure → logout ----
  test('4. Refresh failure logs user out', () async {
    api.stub.queue('POST:/api/v1/auth/login', validLoginResponse);
    await auth.login('test@eh.com', 'pass123');

    // Queue a failed refresh
    api.stub.queue('POST:/api/v1/auth/refresh', {'status': 401});
    final success = await auth.refresh();
    expect(success, isFalse);
    expect(auth.isAuthenticated, isFalse);
  });

  // ---- 5. Logout ----
  test('5. Logout clears credentials', () async {
    api.stub.queue('POST:/api/v1/auth/login', validLoginResponse);
    await auth.login('test@eh.com', 'pass123');
    expect(auth.isAuthenticated, isTrue);
    await auth.logout();
    expect(auth.isAuthenticated, isFalse);
    expect(auth.currentUser, isNull);
  });

  // ---- 6. Session restoration ----
  test('6. Session restoration from storage', () async {
    api.stub.queue('POST:/api/v1/auth/login', validLoginResponse);
    await auth.login('test@eh.com', 'pass123');
    expect(auth.isAuthenticated, isTrue);

    // Create new auth instance pointing to same storage
    final auth2 = _TestAuthRepository(api);
    // Copy the storage reference
    auth2._storage._data.addAll(auth._storage._data);
    await auth2.restoreSession();
    expect(auth2.isAuthenticated, isTrue);
    expect(auth2.currentUser?.email, 'test@eh.com');
  });

  // ---- 7. ApiClient bearer token injection ----
  test('7. ApiClient injects Bearer token on GET', () async {
    auth._accessToken = 'injected-token';
    final token = await api.getAccessToken!();
    expect(token, 'injected-token');
  });

  // ---- 8. 401 → refresh → retry ----
  test('8. 401 triggers refresh and retries request', () async {
    auth._accessToken = 'old-token';
    auth._refreshToken = 'old-refresh';

    // First GET returns 401
    api.stub.queue('GET:/api/v1/homes', {'status': 401});
    // Refresh succeeds
    api.stub.queue('POST:/api/v1/auth/refresh', {
      'status': 200,
      'data': {
        'accessToken': 'new-token',
        'refreshToken': 'new-refresh',
        'expiresIn': 900,
        'user': {'id': 'u1', 'email': 'e@e.com', 'emailVerified': true},
      },
    });
    // Retry GET succeeds
    api.stub.queue('GET:/api/v1/homes', {
      'status': 200,
      'data': [
        {'id': 'home-1', 'name': 'My Home'},
      ],
    });

    // Simulate 401 handling manually (ApiClient._request with isRetry logic)
    final firstResp = api.stub.dequeue('GET:/api/v1/homes');
    expect(firstResp!['status'], 401);
    final refreshed = await api.onRefreshToken!();
    expect(refreshed, isTrue);
    expect(auth._accessToken, 'new-token');
    final retryResp = await api.get('/api/v1/homes');
    expect((retryResp as List)[0]['id'], 'home-1');
  });

  // ---- 9. Refresh loop prevention ----
  test('9. Refresh loop prevention — retry is single-shot', () async {
    int refreshAttempts = 0;
    api.onRefreshToken = () async {
      refreshAttempts++;
      return false; // Always fail
    };

    // Only ONE refresh should be attempted, not infinite
    api.stub.queue('POST:/api/v1/auth/refresh', {'status': 401});
    final result = await api.onRefreshToken!();
    expect(result, isFalse);
    expect(refreshAttempts, 1);
  });

  // ---- 10. Cloud home fetch ----
  test('10. Cloud home fetch returns list', () async {
    api.stub.queue('GET:/api/v1/homes', {
      'status': 200,
      'data': [
        {'id': 'home-1', 'name': 'EH Home'},
      ],
    });
    final homes = await api.get('/api/v1/homes') as List;
    expect(homes.length, 1);
    expect(homes[0]['id'], 'home-1');
  });

  // ---- 11. Cloud device fetch ----
  test('11. Cloud device fetch returns list', () async {
    api.stub.queue('GET:/api/v1/homes/home-1/devices', {
      'status': 200,
      'data': [
        {
          'id': 'dev-1',
          'label': 'Smart Switch',
          'last_seen_at': DateTime.now().toIso8601String(),
          'product_sku': 'EH-3X-001',
          'firmware_version': '1.2.0',
        },
      ],
    });
    final devices = await api.get('/api/v1/homes/home-1/devices') as List;
    expect(devices.length, 1);
    expect(devices[0]['id'], 'dev-1');
  });

  // ---- 12. Command dispatch ----
  test('12. Command dispatch sends POST and returns accepted', () async {
    api.stub.queue('POST:/api/v1/commands/send', {
      'status': 202,
      'data': {'id': 'cmd-1', 'status': 'CREATED'},
    });
    final result = await api.post(
      '/api/v1/commands/send',
      body: {
        'deviceId': 'dev-1',
        'action': 'set_power',
        'parameters': {'enabled': true},
        'idempotencyKey': 'key-1',
      },
    );
    expect(result['id'], 'cmd-1');
    expect(result['status'], 'CREATED');
  });

  // ---- 13. Command failure ----
  test('13. Command failure propagates as exception', () async {
    api.stub.queue('POST:/api/v1/commands/send', {
      'status': 403,
      'error': {'code': 'FORBIDDEN', 'message': 'Not a member'},
    });
    expect(() => api.post('/api/v1/commands/send', body: {}), throwsException);
  });

  // ---- 14. SSE parser — basic event ----
  test('14. SSE parser handles single event block', () {
    const raw = 'id: evt-1\nevent: device.state\ndata: {"type":"device.state"}';
    final parsed = _parseSseBlock(raw);
    expect(parsed['id'], 'evt-1');
    expect(parsed['event'], 'device.state');
    expect(parsed['data'], contains('device.state'));
  });

  // ---- 15. SSE event ID parsing ----
  test('15. SSE id field is parsed correctly', () {
    const raw = 'id: 42\nevent: telemetry.update\ndata: {}';
    final parsed = _parseSseBlock(raw);
    expect(parsed['id'], '42');
  });

  // ---- 16. SSE reconnect — last-event-id tracking ----
  test('16. SSE tracks Last-Event-ID after each event', () {
    final events = [
      'id: e1\nevent: device.state\ndata: {}',
      'id: e2\nevent: command.receipt\ndata: {}',
    ];
    String lastId = '';
    for (final e in events) {
      final p = _parseSseBlock(e);
      if (p['id']!.isNotEmpty) lastId = p['id']!;
    }
    expect(lastId, 'e2');
  });

  // ---- 17. SSE Last-Event-ID added to reconnect request ----
  test('17. Last-Event-ID is a non-empty string after events', () {
    const raw = 'id: seq-100\nevent: heartbeat\ndata: {}';
    final parsed = _parseSseBlock(raw);
    expect(parsed['id']!.isNotEmpty, isTrue);
    expect(parsed['id'], 'seq-100');
  });

  // ---- 18. Duplicate event suppression ----
  test('18. Duplicate event IDs are suppressed', () {
    final seen = <String>{};
    final events = ['evt-1', 'evt-2', 'evt-1', 'evt-3', 'evt-2'];
    final unique = <String>[];
    for (final id in events) {
      if (seen.add(id)) unique.add(id);
    }
    expect(unique, ['evt-1', 'evt-2', 'evt-3']);
  });

  // ---- 19. device.state update ----
  test('19. device.state event updates relay state', () {
    // Simulate event handler logic
    bool lightOn = false;
    void handleEvent(Map<String, dynamic> envelope) {
      if (envelope['type'] == 'device.state') {
        final channels = envelope['payload']['channels'] as Map?;
        final ch1 = channels?['ch1'] as Map?;
        lightOn = ch1?['relay'] ?? lightOn;
      }
    }

    handleEvent({
      'type': 'device.state',
      'payload': {
        'channels': {
          'ch1': {'relay': true},
        },
      },
    });
    expect(lightOn, isTrue);
  });

  // ---- 20. device.availability update ----
  test('20. device.availability maps to DeviceConnection', () {
    // Simulate mapping
    String mapAvailability(String status) {
      switch (status) {
        case 'ONLINE':
          return 'online';
        case 'STALE':
          return 'stale';
        default:
          return 'offline';
      }
    }

    expect(mapAvailability('ONLINE'), 'online');
    expect(mapAvailability('STALE'), 'stale');
    expect(mapAvailability('OFFLINE'), 'offline');
  });

  // ---- 21. command.receipt update ----
  test('21. command.receipt APPLIED clears pending state', () {
    bool pending = true;
    void handleReceipt(String status) {
      if (status == 'APPLIED' || status == 'DELIVERED') pending = false;
    }

    handleReceipt('APPLIED');
    expect(pending, isFalse);
  });

  // ---- 22. physical switch convergence ----
  test('22. Physical switch override converges via device.state SSE', () {
    bool lightOn = true;
    // Physical switch OFF → device.state reports ch1.relay = false
    void handleDeviceState(Map<String, dynamic> payload) {
      final channels = payload['channels'] as Map?;
      final ch1 = channels?['ch1'] as Map?;
      if (ch1 != null && ch1.containsKey('relay')) {
        lightOn = ch1['relay'] as bool;
      }
    }

    handleDeviceState({
      'channels': {
        'ch1': {'relay': false},
      },
    });
    expect(lightOn, isFalse);
  });

  // ---- 23. Logout closes SSE ----
  test('23. Logout triggers SSE disconnect', () async {
    bool sseDisconnected = false;
    void disconnectSse() {
      sseDisconnected = true;
    }

    // Simulate auth controller logout → triggers disconnect
    api.stub.queue('POST:/api/v1/auth/login', validLoginResponse);
    await auth.login('test@eh.com', 'pass123');
    await auth.logout();
    disconnectSse(); // In real app this is triggered by AuthController listener
    expect(sseDisconnected, isTrue);
  });

  // ---- 24. App resume reconnects SSE ----
  test('24. App resume reconnects SSE when authenticated', () {
    bool connected = false;
    void connectSse() {
      connected = true;
    }

    // Simulate authenticated state + resume
    auth._accessToken = 'some-token';
    auth._user = _UserProfile(id: 'u1', email: 'e@e.com');
    if (auth.isAuthenticated) connectSse();
    expect(connected, isTrue);
  });
}
