import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/fleet_models.dart';

/// EH Home — Device Fleet Management & OTA Client Service (Phase 18)
class FleetManagementService extends ChangeNotifier {
  final String baseUrl;
  final http.Client? httpClient;
  final String? Function()? getAuthToken;

  FleetStatus? _cachedFleetStatus;
  FleetStatus? get cachedFleetStatus => _cachedFleetStatus;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _lastError;
  String? get lastError => _lastError;

  FleetManagementService({
    this.baseUrl = 'http://127.0.0.1:3000',
    this.httpClient,
    this.getAuthToken,
    FleetStatus? initialStatus,
  }) : _cachedFleetStatus = initialStatus;

  Future<FleetStatus> fetchFleetStatus({String? homeId}) async {
    _isLoading = true;
    _lastError = null;
    notifyListeners();

    try {
      final client = httpClient ?? http.Client();
      final token = getAuthToken != null ? getAuthToken!() : null;

      final queryParams = <String, String>{};
      if (homeId != null) {
        queryParams['homeId'] = homeId;
      }

      final uri = Uri.parse('$baseUrl/api/v1/fleet/status')
          .replace(queryParameters: queryParams);

      final headers = <String, String>{
        'Content-Type': 'application/json',
      };
      if (token != null) {
        headers['Authorization'] = 'Bearer $token';
      }

      final response = await client.get(uri, headers: headers);
      if (response.statusCode != 200) {
        throw Exception('Failed to load fleet status: ${response.body}');
      }

      final body = json.decode(response.body) as Map<String, dynamic>;
      final data = Map<String, dynamic>.from(body['data'] as Map);
      final status = FleetStatus.fromJson(data);

      _cachedFleetStatus = status;
      _isLoading = false;
      notifyListeners();
      return status;
    } catch (e) {
      _lastError = e.toString();
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  Future<Map<String, dynamic>> checkUpdate({
    required String productVariantId,
    required String currentVersion,
    String? hardwareRevision,
  }) async {
    final client = httpClient ?? http.Client();
    final token = getAuthToken != null ? getAuthToken!() : null;

    final queryParams = <String, String>{
      'productVariantId': productVariantId,
      'currentVersion': currentVersion,
    };
    if (hardwareRevision != null) {
      queryParams['hardwareRevision'] = hardwareRevision;
    }

    final uri = Uri.parse('$baseUrl/api/v1/ota/check')
        .replace(queryParameters: queryParams);

    final headers = <String, String>{
      'Content-Type': 'application/json',
    };
    if (token != null) {
      headers['Authorization'] = 'Bearer $token';
    }

    final response = await client.get(uri, headers: headers);
    if (response.statusCode != 200) {
      throw Exception('Update check failed: ${response.body}');
    }

    final body = json.decode(response.body) as Map<String, dynamic>;
    return Map<String, dynamic>.from(body['data'] as Map);
  }

  Future<OtaOperation> initiateOtaUpdate({
    required String deviceId,
    required String releaseId,
    required String homeId,
  }) async {
    final client = httpClient ?? http.Client();
    final token = getAuthToken != null ? getAuthToken!() : null;

    final uri = Uri.parse('$baseUrl/api/v1/ota/operations');
    final headers = <String, String>{
      'Content-Type': 'application/json',
    };
    if (token != null) {
      headers['Authorization'] = 'Bearer $token';
    }

    final body = {
      'deviceId': deviceId,
      'releaseId': releaseId,
      'homeId': homeId,
    };

    final response = await client.post(
      uri,
      headers: headers,
      body: json.encode(body),
    );

    if (response.statusCode != 201 && response.statusCode != 200) {
      throw Exception('Failed to initiate OTA update: ${response.body}');
    }

    final resBody = json.decode(response.body) as Map<String, dynamic>;
    final data = Map<String, dynamic>.from(resBody['data'] as Map);
    final op = OtaOperation.fromJson(data);

    // Refresh status if homeId is active
    if (_cachedFleetStatus != null && _cachedFleetStatus!.homeId == homeId) {
      fetchFleetStatus(homeId: homeId).ignore();
    }

    return op;
  }

  Future<List<DeviceMaintenanceLog>> fetchMaintenanceHistory({
    String? homeId,
    String? deviceId,
  }) async {
    final client = httpClient ?? http.Client();
    final token = getAuthToken != null ? getAuthToken!() : null;

    final queryParams = <String, String>{};
    if (homeId != null) queryParams['homeId'] = homeId;
    if (deviceId != null) queryParams['deviceId'] = deviceId;

    final uri = Uri.parse('$baseUrl/api/v1/ota/maintenance')
        .replace(queryParameters: queryParams);

    final headers = <String, String>{
      'Content-Type': 'application/json',
    };
    if (token != null) {
      headers['Authorization'] = 'Bearer $token';
    }

    final response = await client.get(uri, headers: headers);
    if (response.statusCode != 200) {
      throw Exception('Failed to fetch maintenance history: ${response.body}');
    }

    final body = json.decode(response.body) as Map<String, dynamic>;
    final data = body['data'] as List? ?? [];
    return data
        .map((log) => DeviceMaintenanceLog.fromJson(Map<String, dynamic>.from(log as Map)))
        .toList();
  }

  Future<List<FirmwareRelease>> listReleases({String? productVariantId}) async {
    final client = httpClient ?? http.Client();
    final token = getAuthToken != null ? getAuthToken!() : null;

    final queryParams = <String, String>{};
    if (productVariantId != null) queryParams['productVariantId'] = productVariantId;

    final uri = Uri.parse('$baseUrl/api/v1/ota/releases')
        .replace(queryParameters: queryParams);

    final headers = <String, String>{
      'Content-Type': 'application/json',
    };
    if (token != null) {
      headers['Authorization'] = 'Bearer $token';
    }

    final response = await client.get(uri, headers: headers);
    if (response.statusCode != 200) {
      throw Exception('Failed to list releases: ${response.body}');
    }

    final body = json.decode(response.body) as Map<String, dynamic>;
    final data = body['data'] as List? ?? [];
    return data
        .map((r) => FirmwareRelease.fromJson(Map<String, dynamic>.from(r as Map)))
        .toList();
  }
}
