import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../api/api_client.dart';
import '../config/app_config.dart';
import '../models/edge_control_models.dart';

/// Phase 28 — Local-First Home Control & Edge Execution Service
///
/// Handles deterministic execution routing (LOCAL vs CLOUD), LAN device discovery,
/// offline state queuing, and physical device confirmation.
class EdgeControlService extends ChangeNotifier {
  final String baseUrl;
  final http.Client _client;
  final ApiClient? apiClient;
  String? _authToken;

  EdgeControlService({
    String? baseUrl,
    http.Client? client,
    this.apiClient,
    String? authToken,
  })  : baseUrl = baseUrl ?? AppConfig.backendBaseUrl,
        _client = client ?? http.Client() {
    _authToken = authToken;
  }

  ApiClient get effectiveApiClient =>
      apiClient ?? ApiClient(baseUrl: baseUrl, client: _client);

  void updateToken(String? token) {
    _authToken = token;
    notifyListeners();
  }

  Future<Map<String, String>> _getHeaders() async {
    String? token = _authToken;
    if (token == null || token.isEmpty) {
      if (apiClient?.getAccessToken != null) {
        token = await apiClient!.getAccessToken!();
      } else if (ApiClient.defaultTokenProvider != null) {
        token = await ApiClient.defaultTokenProvider!();
      } else {
        try {
          final prefs = await SharedPreferences.getInstance().timeout(const Duration(milliseconds: 100));
          token = prefs.getString('auth_access_token');
        } catch (_) {}
      }
      if (token != null) _authToken = token;
    }
    return {
      'Content-Type': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  Future<dynamic> _apiGet(String path) async {
    if (apiClient != null) {
      return apiClient!.get(path);
    }
    final headers = await _getHeaders();
    final uri = Uri.parse('$baseUrl$path');
    final response = await _client.get(uri, headers: headers);
    return _handleResponse(response);
  }

  Future<dynamic> _apiPost(String path, {Map<String, dynamic>? body}) async {
    if (apiClient != null) {
      return apiClient!.post(path, body: body);
    }
    final headers = await _getHeaders();
    final uri = Uri.parse('$baseUrl$path');
    final response = await _client.post(
      uri,
      headers: headers,
      body: body != null ? json.encode(body) : null,
    );
    return _handleResponse(response);
  }

  dynamic _handleResponse(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      final body = json.decode(response.body);
      if (body is Map && body.containsKey('data')) {
        return body['data'];
      }
      return body;
    }
    throw Exception('Request failed (${response.statusCode}): ${response.body}');
  }

  bool _loading = false;
  bool get loading => _loading;

  String? _error;
  String? get error => _error;

  LocalConnectivityStatus? _localStatus;
  LocalConnectivityStatus? get localStatus => _localStatus;

  List<DiscoveredLocalNode> _localDevices = [];
  List<DiscoveredLocalNode> get localDevices => _localDevices;

  EdgeMetricsSummary? _edgeMetrics;
  EdgeMetricsSummary? get edgeMetrics => _edgeMetrics;

  final Map<String, EdgeExecutionResult> _lastExecutionResults = {};
  Map<String, EdgeExecutionResult> get lastExecutionResults => Map.unmodifiable(_lastExecutionResults);

  // ─── 1. Get Home Local Status ───────────────────────────────────────────

  Future<LocalConnectivityStatus?> fetchLocalStatus(String homeId) async {
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      final res = await _apiGet('/api/v1/homes/$homeId/local-status');
      if (res is Map<String, dynamic>) {
        _localStatus = LocalConnectivityStatus.fromJson(res);
      } else if (res is Map) {
        _localStatus = LocalConnectivityStatus.fromJson(Map<String, dynamic>.from(res));
      }
    } catch (e) {
      _error = e.toString();
      _localStatus = null;
    } finally {
      _loading = false;
      notifyListeners();
    }
    return _localStatus;
  }

  // ─── 2. Fetch Discovered Local Nodes ────────────────────────────────────

  Future<List<DiscoveredLocalNode>> fetchLocalDevices(String homeId) async {
    try {
      final res = await _apiGet('/api/v1/homes/$homeId/local-devices');
      List<dynamic> rawList = [];
      if (res is Map && res['devices'] is List) {
        rawList = res['devices'] as List;
      } else if (res is Map && res['data'] is Map && res['data']['devices'] is List) {
        rawList = res['data']['devices'] as List;
      } else if (res is Map && res['data'] is List) {
        rawList = res['data'] as List;
      } else if (res is List) {
        rawList = res;
      }

      final Map<String, DiscoveredLocalNode> deduped = {};
      for (final item in rawList) {
        if (item is Map) {
          final node = DiscoveredLocalNode.fromJson(Map<String, dynamic>.from(item));
          final key = node.deviceId.isNotEmpty ? node.deviceId : node.macAddress;
          if (key.isNotEmpty) {
            deduped[key] = node;
          }
        }
      }
      _localDevices = deduped.values.toList();
      notifyListeners();
      return _localDevices;
    } catch (e) {
      _error = e.toString();
    }
    return _localDevices;
  }

  // ─── 3. Trigger Local Network Discovery / Rescan ────────────────────────

  Future<Map<String, dynamic>?> scanLocalNetwork(String homeId) async {
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      final res = await _apiPost('/api/v1/homes/$homeId/local-discovery/scan');
      await fetchLocalDevices(homeId);
      await fetchLocalStatus(homeId);
      _loading = false;
      notifyListeners();
      if (res is Map<String, dynamic>) return res;
      if (res is Map) return Map<String, dynamic>.from(res);
      return null;
    } catch (e) {
      _error = e.toString();
    } finally {
      _loading = false;
      notifyListeners();
    }
    return null;
  }

  // ─── 4. Execute Command with Auto-Routing ───────────────────────────────

  Future<EdgeExecutionResult?> executeCommand({
    required String deviceId,
    required String homeId,
    int channelIndex = 1,
    required String action,
    Map<String, dynamic>? params,
    String? idempotencyKey,
  }) async {
    _loading = true;
    _error = null;
    notifyListeners();

    final payload = {
      'homeId': homeId,
      'channelIndex': channelIndex,
      'action': action,
      'params': params ?? {},
      'idempotencyKey': ?idempotencyKey,
    };

    try {
      final res = await _apiPost(
        '/api/v1/devices/$deviceId/execute',
        body: payload,
      );
      if (res is Map<String, dynamic>) {
        final result = EdgeExecutionResult.fromJson(res);
        _lastExecutionResults[deviceId] = result;
        _loading = false;
        notifyListeners();
        return result;
      } else if (res is Map) {
        final result = EdgeExecutionResult.fromJson(Map<String, dynamic>.from(res));
        _lastExecutionResults[deviceId] = result;
        _loading = false;
        notifyListeners();
        return result;
      }
      _error = 'Execution failed';
    } catch (e) {
      _error = e.toString();
    } finally {
      _loading = false;
      notifyListeners();
    }
    return null;
  }

  // ─── 5. Execute Edge Scene ──────────────────────────────────────────────

  Future<Map<String, dynamic>?> executeEdgeScene({
    required String homeId,
    required String sceneId,
  }) async {
    _loading = true;
    notifyListeners();

    try {
      final res = await _apiPost('/api/v1/homes/$homeId/scenes/$sceneId/execute-edge');
      _loading = false;
      notifyListeners();
      if (res is Map<String, dynamic>) return res;
      if (res is Map) return Map<String, dynamic>.from(res);
      return null;
    } catch (e) {
      _error = e.toString();
    } finally {
      _loading = false;
      notifyListeners();
    }
    return null;
  }

  // ─── 6. Fetch Edge Metrics ──────────────────────────────────────────────

  Future<EdgeMetricsSummary?> fetchEdgeMetrics(String homeId) async {
    try {
      final res = await _apiGet('/api/v1/homes/$homeId/edge-metrics');
      if (res is Map<String, dynamic>) {
        _edgeMetrics = EdgeMetricsSummary.fromJson(res);
      } else if (res is Map) {
        _edgeMetrics = EdgeMetricsSummary.fromJson(Map<String, dynamic>.from(res));
      }
      notifyListeners();
      return _edgeMetrics;
    } catch (e) {
      _error = e.toString();
    }
    return _edgeMetrics;
  }
}
