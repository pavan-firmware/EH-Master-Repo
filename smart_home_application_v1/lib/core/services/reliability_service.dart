import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/reliability_models.dart';

/// Phase 25 — Flutter Reliability Service
///
/// Manages API calls to /api/v1/reliability/* and caches results.
/// Notifies listeners on state change.
class ReliabilityService extends ChangeNotifier {
  final String baseUrl;
  final String Function()? tokenProvider;
  final http.Client _client;

  // ── State ──────────────────────────────────────────────────────────────────

  bool _loading = false;
  String? _error;

  FleetHealthSummary? _fleetHealth;
  DeviceHealthSnapshot? _deviceHealth;
  List<ReliabilityIncident> _activeIncidents = [];
  List<RecoveryAttempt> _recoveryHistory = [];
  List<MaintenanceRecommendation> _maintenanceRecommendations = [];

  // ── Getters ────────────────────────────────────────────────────────────────

  bool get loading => _loading;
  String? get error => _error;
  FleetHealthSummary? get fleetHealth => _fleetHealth;
  DeviceHealthSnapshot? get deviceHealth => _deviceHealth;
  List<ReliabilityIncident> get activeIncidents => List.unmodifiable(_activeIncidents);
  List<RecoveryAttempt> get recoveryHistory => List.unmodifiable(_recoveryHistory);
  List<MaintenanceRecommendation> get maintenanceRecommendations =>
      List.unmodifiable(_maintenanceRecommendations);

  // ── Constructor ────────────────────────────────────────────────────────────

  ReliabilityService({
    required this.baseUrl,
    this.tokenProvider,
    http.Client? client,
  }) : _client = client ?? http.Client();

  // ── Helpers ────────────────────────────────────────────────────────────────

  Map<String, String> get _headers {
    final token = tokenProvider?.call();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  void _setLoading(bool v) {
    _loading = v;
    notifyListeners();
  }

  void _setError(String? e) {
    _error = e;
    notifyListeners();
  }

  Future<Map<String, dynamic>?> _get(String path) async {
    try {
      final res = await _client.get(Uri.parse('$baseUrl$path'), headers: _headers);
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      if (res.statusCode >= 200 && res.statusCode < 300 && body['success'] == true) {
        return body['data'] as Map<String, dynamic>?;
      }
      _setError(body['error']?['message'] as String? ?? 'Request failed');
      return null;
    } catch (e) {
      _setError(e.toString());
      return null;
    }
  }

  Future<Map<String, dynamic>?> _post(String path, Map<String, dynamic> data) async {
    try {
      final res = await _client.post(
        Uri.parse('$baseUrl$path'),
        headers: _headers,
        body: jsonEncode(data),
      );
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      if (res.statusCode >= 200 && res.statusCode < 300 && body['success'] == true) {
        return body['data'] as Map<String, dynamic>?;
      }
      _setError(body['error']?['message'] as String? ?? 'Request failed');
      return null;
    } catch (e) {
      _setError(e.toString());
      return null;
    }
  }

  Future<List<T>> _getList<T>(
    String path,
    T Function(Map<String, dynamic>) fromJson,
  ) async {
    try {
      final res = await _client.get(Uri.parse('$baseUrl$path'), headers: _headers);
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      if (res.statusCode >= 200 && res.statusCode < 300 && body['success'] == true) {
        final data = body['data'];
        if (data is List) return data.cast<Map<String, dynamic>>().map(fromJson).toList();
      }
      _setError(body['error']?['message'] as String? ?? 'Request failed');
    } catch (e) {
      _setError(e.toString());
    }
    return [];
  }

  // ── Public API ─────────────────────────────────────────────────────────────

  Future<void> loadFleetHealth(String homeId) async {
    _setLoading(true);
    _setError(null);
    final data = await _get('/api/v1/reliability/homes/$homeId/fleet');
    if (data != null) {
      _fleetHealth = FleetHealthSummary.fromJson(data);
    }
    _setLoading(false);
  }

  Future<void> loadDeviceHealth(String deviceId) async {
    _setLoading(true);
    _setError(null);
    final data = await _get('/api/v1/reliability/devices/$deviceId/health');
    if (data != null) {
      _deviceHealth = DeviceHealthSnapshot.fromJson(data);
    }
    _setLoading(false);
  }

  Future<void> loadActiveIncidents(String homeId) async {
    _setLoading(true);
    _setError(null);
    _activeIncidents = await _getList(
      '/api/v1/reliability/homes/$homeId/incidents',
      ReliabilityIncident.fromJson,
    );
    _setLoading(false);
  }

  Future<void> loadRecoveryHistory(String deviceId) async {
    _setLoading(true);
    _setError(null);
    _recoveryHistory = await _getList(
      '/api/v1/reliability/devices/$deviceId/recovery-history',
      RecoveryAttempt.fromJson,
    );
    _setLoading(false);
  }

  Future<void> loadMaintenanceRecommendations(String homeId) async {
    _setLoading(true);
    _setError(null);
    _maintenanceRecommendations = await _getList(
      '/api/v1/reliability/homes/$homeId/maintenance',
      MaintenanceRecommendation.fromJson,
    );
    _setLoading(false);
  }

  Future<Map<String, dynamic>?> diagnoseIncident(String incidentId) async {
    _setLoading(true);
    _setError(null);
    final result = await _post(
      '/api/v1/reliability/incidents/$incidentId/diagnose',
      {},
    );
    _setLoading(false);
    return result;
  }

  Future<Map<String, dynamic>?> initiateRecovery(
    String incidentId,
    RecoveryActionType actionType,
  ) async {
    _setLoading(true);
    _setError(null);
    final result = await _post(
      '/api/v1/reliability/incidents/$incidentId/recover',
      {'actionType': actionType.toApiValue()},
    );
    _setLoading(false);
    return result;
  }

  Future<Map<String, dynamic>?> verifyRecovery(String attemptId) async {
    _setLoading(true);
    _setError(null);
    final result = await _post(
      '/api/v1/reliability/recovery/$attemptId/verify',
      {},
    );
    _setLoading(false);
    return result;
  }

  @override
  void dispose() {
    _client.close();
    super.dispose();
  }
}
