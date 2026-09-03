import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/connectivity_models.dart';

/// Phase 26 — Multi-Protocol Connectivity Client Service
///
/// Manages device connection snapshots, transport selection,
/// health monitoring, discovery, and commissioning sessions.
class ConnectivityService extends ChangeNotifier {
  final String baseUrl;
  final http.Client _client;
  String? _authToken;

  ConnectivityService({
    required this.baseUrl,
    http.Client? client,
  }) : _client = client ?? http.Client();

  void updateToken(String? token) {
    _authToken = token;
  }

  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    if (_authToken != null) 'Authorization': 'Bearer $_authToken',
  };

  bool _loading = false;
  bool get loading => _loading;

  String? _error;
  String? get error => _error;

  DeviceConnectionSnapshot? _deviceConnection;
  DeviceConnectionSnapshot? get deviceConnection => _deviceConnection;

  List<TransportCapability> _deviceTransports = [];
  List<TransportCapability> get deviceTransports => _deviceTransports;

  FleetConnectivitySummary? _fleetConnectivity;
  FleetConnectivitySummary? get fleetConnectivity => _fleetConnectivity;

  final List<CommissioningSession> _commissioningSessions = [];
  List<CommissioningSession> get commissioningSessions => _commissioningSessions;

  List<DeviceDiscoveryResult> _discoveryResults = [];
  List<DeviceDiscoveryResult> get discoveryResults => _discoveryResults;

  // ─── 1. Load Device Connection Snapshot ───────────────────────────────────

  Future<DeviceConnectionSnapshot?> loadDeviceConnection(String deviceId) async {
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      final res = await _client.get(
        Uri.parse('$baseUrl/api/v1/connectivity/devices/$deviceId'),
        headers: _headers,
      );

      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        final data = body['data'] ?? body;
        _deviceConnection = DeviceConnectionSnapshot.fromJson(data);
        _loading = false;
        notifyListeners();
        return _deviceConnection;
      } else {
        _error = 'Failed to load connection status (${res.statusCode})';
      }
    } catch (e) {
      _error = e.toString();
    }

    _loading = false;
    notifyListeners();
    return null;
  }

  // ─── 2. Load Device Transports ────────────────────────────────────────────

  Future<List<TransportCapability>> loadDeviceTransports(String deviceId) async {
    try {
      final res = await _client.get(
        Uri.parse('$baseUrl/api/v1/connectivity/devices/$deviceId/transports'),
        headers: _headers,
      );

      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        final list = (body['data'] ?? body) as List? ?? [];
        _deviceTransports = list
            .map((item) => TransportCapability.fromJson(item as Map<String, dynamic>))
            .toList();
        notifyListeners();
        return _deviceTransports;
      }
    } catch (e) {
      _error = e.toString();
    }
    return [];
  }

  // ─── 3. Load Fleet Connectivity ───────────────────────────────────────────

  Future<FleetConnectivitySummary?> loadFleetConnectivity(String homeId) async {
    try {
      final res = await _client.get(
        Uri.parse('$baseUrl/api/v1/connectivity/homes/$homeId/devices'),
        headers: _headers,
      );

      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        final data = body['data'] ?? body;
        _fleetConnectivity = FleetConnectivitySummary.fromJson(data);
        notifyListeners();
        return _fleetConnectivity;
      }
    } catch (e) {
      _error = e.toString();
    }
    return null;
  }

  // ─── 4. Reconnect & Transport Selection Actions ───────────────────────────

  Future<bool> triggerReconnect(String deviceId, {DeviceTransportType? transportType}) async {
    try {
      final res = await _client.post(
        Uri.parse('$baseUrl/api/v1/connectivity/devices/$deviceId/reconnect'),
        headers: _headers,
        body: jsonEncode({
          if (transportType != null) 'transportType': transportType.toApiValue(),
        }),
      );

      if (res.statusCode == 200) {
        await loadDeviceConnection(deviceId);
        return true;
      }
    } catch (e) {
      _error = e.toString();
    }
    return false;
  }

  Future<bool> selectTransport(String deviceId, DeviceTransportType transportType) async {
    try {
      final res = await _client.post(
        Uri.parse('$baseUrl/api/v1/connectivity/devices/$deviceId/select-transport'),
        headers: _headers,
        body: jsonEncode({'transportType': transportType.toApiValue()}),
      );

      if (res.statusCode == 200) {
        await loadDeviceConnection(deviceId);
        return true;
      }
    } catch (e) {
      _error = e.toString();
    }
    return false;
  }

  // ─── 5. Discovery & Commissioning ─────────────────────────────────────────

  Future<List<DeviceDiscoveryResult>> scanForDevices({DeviceTransportType? protocol}) async {
    _loading = true;
    notifyListeners();

    try {
      final uri = Uri.parse('$baseUrl/api/v1/connectivity/discovery').replace(
        queryParameters: protocol != null ? {'protocol': protocol.toApiValue()} : null,
      );
      final res = await _client.get(uri, headers: _headers);

      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        final list = (body['data'] ?? body) as List? ?? [];
        _discoveryResults = list
            .map((item) => DeviceDiscoveryResult.fromJson(item as Map<String, dynamic>))
            .toList();
        _loading = false;
        notifyListeners();
        return _discoveryResults;
      }
    } catch (e) {
      _error = e.toString();
    }

    _loading = false;
    notifyListeners();
    return [];
  }

  Future<CommissioningSession?> startCommissioning({
    required String homeId,
    required String deviceId,
    required DeviceTransportType transportType,
    String? authMethod,
  }) async {
    try {
      final res = await _client.post(
        Uri.parse('$baseUrl/api/v1/connectivity/commissioning/start'),
        headers: _headers,
        body: jsonEncode({
          'homeId': homeId,
          'deviceId': deviceId,
          'transportType': transportType.toApiValue(),
          'authMethod': authMethod ?? 'PASSCODE',
        }),
      );

      if (res.statusCode == 201 || res.statusCode == 200) {
        final body = jsonDecode(res.body);
        final data = body['data'] ?? body;
        return CommissioningSession.fromJson(data);
      }
    } catch (e) {
      _error = e.toString();
    }
    return null;
  }

  Future<bool> cancelCommissioning(String sessionId, {String? errorDetails}) async {
    try {
      final res = await _client.post(
        Uri.parse('$baseUrl/api/v1/connectivity/commissioning/cancel'),
        headers: _headers,
        body: jsonEncode({
          'sessionId': sessionId,
          'errorDetails': errorDetails ?? 'Cancelled by user',
        }),
      );

      return res.statusCode == 200;
    } catch (e) {
      _error = e.toString();
    }
    return false;
  }
}
