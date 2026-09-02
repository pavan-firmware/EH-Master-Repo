import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/energy_models.dart';

/// EH Home — Energy Intelligence & Telemetry Client Service (Phase 19)
class EnergyService extends ChangeNotifier {
  final String baseUrl;
  final http.Client? httpClient;
  final String? Function()? getAuthToken;

  EnergyUsageSummary? _cachedHomeSummary;
  EnergyUsageSummary? get cachedHomeSummary => _cachedHomeSummary;

  List<EnergyTrendPoint> _cachedTrends = [];
  List<EnergyTrendPoint> get cachedTrends => _cachedTrends;

  List<TopEnergyConsumer> _cachedTopDevices = [];
  List<TopEnergyConsumer> get cachedTopDevices => _cachedTopDevices;

  List<TopEnergyConsumer> _cachedTopRooms = [];
  List<TopEnergyConsumer> get cachedTopRooms => _cachedTopRooms;

  List<EnergyThresholdConfig> _cachedThresholds = [];
  List<EnergyThresholdConfig> get cachedThresholds => _cachedThresholds;

  List<EnergyAnomalyEvent> _cachedEvents = [];
  List<EnergyAnomalyEvent> get cachedEvents => _cachedEvents;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _lastError;
  String? get lastError => _lastError;

  EnergyService({
    this.baseUrl = 'http://127.0.0.1:3000',
    this.httpClient,
    this.getAuthToken,
    EnergyUsageSummary? initialSummary,
  }) : _cachedHomeSummary = initialSummary;

  Map<String, String> _buildHeaders() {
    final headers = <String, String>{
      'Content-Type': 'application/json',
    };
    if (getAuthToken != null) {
      final token = getAuthToken!();
      if (token != null) {
        headers['Authorization'] = 'Bearer $token';
      }
    }
    return headers;
  }

  /// 1. Fetch Latest Telemetry for a Device
  Future<EnergyMeasurement?> fetchDeviceLatest(String deviceId, {int channelIndex = 1}) async {
    try {
      final client = httpClient ?? http.Client();
      final uri = Uri.parse('$baseUrl/api/v1/energy/devices/$deviceId/latest')
          .replace(queryParameters: {'channelIndex': channelIndex.toString()});

      final response = await client.get(uri, headers: _buildHeaders());
      if (response.statusCode != 200) {
        throw Exception('Failed to load device latest telemetry: ${response.body}');
      }

      final body = json.decode(response.body) as Map<String, dynamic>;
      if (body['data'] == null) return null;
      return EnergyMeasurement.fromJson(Map<String, dynamic>.from(body['data'] as Map));
    } catch (e) {
      _lastError = e.toString();
      notifyListeners();
      return null;
    }
  }

  /// 2. Fetch Device Energy Summary
  Future<EnergyUsageSummary?> fetchDeviceSummary(String deviceId, {String period = 'today'}) async {
    try {
      final client = httpClient ?? http.Client();
      final uri = Uri.parse('$baseUrl/api/v1/energy/devices/$deviceId/summary')
          .replace(queryParameters: {'period': period});

      final response = await client.get(uri, headers: _buildHeaders());
      if (response.statusCode != 200) {
        throw Exception('Failed to load device energy summary: ${response.body}');
      }

      final body = json.decode(response.body) as Map<String, dynamic>;
      final data = Map<String, dynamic>.from(body['data'] as Map);
      return EnergyUsageSummary.fromJson(data);
    } catch (e) {
      _lastError = e.toString();
      notifyListeners();
      return null;
    }
  }

  /// 3. Fetch Home Energy Summary
  Future<EnergyUsageSummary?> fetchHomeSummary(String homeId, {String period = 'today'}) async {
    _isLoading = true;
    _lastError = null;
    notifyListeners();

    try {
      final client = httpClient ?? http.Client();
      final uri = Uri.parse('$baseUrl/api/v1/energy/homes/$homeId/summary')
          .replace(queryParameters: {'period': period});

      final response = await client.get(uri, headers: _buildHeaders());
      if (response.statusCode != 200) {
        throw Exception('Failed to load home energy summary: ${response.body}');
      }

      final body = json.decode(response.body) as Map<String, dynamic>;
      final data = Map<String, dynamic>.from(body['data'] as Map);
      _cachedHomeSummary = EnergyUsageSummary.fromJson(data);
      _isLoading = false;
      notifyListeners();
      return _cachedHomeSummary;
    } catch (e) {
      _isLoading = false;
      _lastError = e.toString();
      notifyListeners();
      return null;
    }
  }

  /// 4. Fetch Home Energy Trends
  Future<List<EnergyTrendPoint>> fetchHomeTrends(String homeId, {String period = 'week', String interval = 'day'}) async {
    try {
      final client = httpClient ?? http.Client();
      final uri = Uri.parse('$baseUrl/api/v1/energy/homes/$homeId/trends')
          .replace(queryParameters: {'period': period, 'interval': interval});

      final response = await client.get(uri, headers: _buildHeaders());
      if (response.statusCode != 200) {
        throw Exception('Failed to load home energy trends: ${response.body}');
      }

      final body = json.decode(response.body) as Map<String, dynamic>;
      final data = Map<String, dynamic>.from(body['data'] as Map);
      final rawPoints = (data['points'] as List?) ?? [];
      _cachedTrends = rawPoints
          .map((p) => EnergyTrendPoint.fromJson(Map<String, dynamic>.from(p as Map)))
          .toList();
      notifyListeners();
      return _cachedTrends;
    } catch (e) {
      _lastError = e.toString();
      notifyListeners();
      return [];
    }
  }

  /// 5. Fetch Top Consumers
  Future<void> fetchTopConsumers(String homeId, {String period = 'today', int limit = 5}) async {
    try {
      final client = httpClient ?? http.Client();
      final uri = Uri.parse('$baseUrl/api/v1/energy/homes/$homeId/top-consumers')
          .replace(queryParameters: {'period': period, 'limit': limit.toString()});

      final response = await client.get(uri, headers: _buildHeaders());
      if (response.statusCode != 200) {
        throw Exception('Failed to load top consumers: ${response.body}');
      }

      final body = json.decode(response.body) as Map<String, dynamic>;
      final data = Map<String, dynamic>.from(body['data'] as Map);
      final rawDevices = (data['topDevices'] as List?) ?? [];
      final rawRooms = (data['topRooms'] as List?) ?? [];

      _cachedTopDevices = rawDevices
          .map((d) => TopEnergyConsumer.fromJson(Map<String, dynamic>.from(d as Map)))
          .toList();
      _cachedTopRooms = rawRooms
          .map((r) => TopEnergyConsumer.fromJson(Map<String, dynamic>.from(r as Map)))
          .toList();

      notifyListeners();
    } catch (e) {
      _lastError = e.toString();
      notifyListeners();
    }
  }

  /// 6. Fetch Energy Thresholds
  Future<List<EnergyThresholdConfig>> fetchThresholds(String homeId) async {
    try {
      final client = httpClient ?? http.Client();
      final uri = Uri.parse('$baseUrl/api/v1/energy/homes/$homeId/thresholds');

      final response = await client.get(uri, headers: _buildHeaders());
      if (response.statusCode != 200) {
        throw Exception('Failed to load thresholds: ${response.body}');
      }

      final body = json.decode(response.body) as Map<String, dynamic>;
      final rawList = (body['data'] as List?) ?? [];
      _cachedThresholds = rawList
          .map((t) => EnergyThresholdConfig.fromJson(Map<String, dynamic>.from(t as Map)))
          .toList();
      notifyListeners();
      return _cachedThresholds;
    } catch (e) {
      _lastError = e.toString();
      notifyListeners();
      return [];
    }
  }

  /// 7. Upsert Threshold
  Future<bool> setThreshold(String homeId, EnergyThresholdConfig config) async {
    try {
      final client = httpClient ?? http.Client();
      final uri = Uri.parse('$baseUrl/api/v1/energy/homes/$homeId/thresholds');

      final response = await client.post(
        uri,
        headers: _buildHeaders(),
        body: json.encode(config.toJson()),
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to save threshold: ${response.body}');
      }

      await fetchThresholds(homeId);
      return true;
    } catch (e) {
      _lastError = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// 8. Fetch Energy Events
  Future<List<EnergyAnomalyEvent>> fetchEvents(String homeId, {int limit = 50}) async {
    try {
      final client = httpClient ?? http.Client();
      final uri = Uri.parse('$baseUrl/api/v1/energy/homes/$homeId/events')
          .replace(queryParameters: {'limit': limit.toString()});

      final response = await client.get(uri, headers: _buildHeaders());
      if (response.statusCode != 200) {
        throw Exception('Failed to load energy events: ${response.body}');
      }

      final body = json.decode(response.body) as Map<String, dynamic>;
      final rawList = (body['data'] as List?) ?? [];
      _cachedEvents = rawList
          .map((e) => EnergyAnomalyEvent.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
      notifyListeners();
      return _cachedEvents;
    } catch (e) {
      _lastError = e.toString();
      notifyListeners();
      return [];
    }
  }

  /// Ingest realtime telemetry update from SSE
  void handleRealtimeTelemetryUpdate(Map<String, dynamic> payload) {
    // Notify listeners so UI updates live
    notifyListeners();
  }
}
