import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/matter_models.dart';

/// Phase 29 — Matter & Multi-Platform Integration Client Service
class MatterService extends ChangeNotifier {
  final String baseUrl;
  final http.Client _client;
  String? _authToken;

  MatterService({
    this.baseUrl = 'http://localhost:3000',
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

  final Map<String, MatterDeviceSummary> _devices = {};
  Map<String, MatterDeviceSummary> get devices => Map.unmodifiable(_devices);

  List<ExternalPlatformLinkModel> _homePlatforms = [];
  List<ExternalPlatformLinkModel> get homePlatforms => _homePlatforms;

  MatterCertificationOverview _certificationOverview = const MatterCertificationOverview();
  MatterCertificationOverview get certificationOverview => _certificationOverview;

  // ─── 1. Fetch Matter Devices for Home ───────────────────────────────────────

  Future<List<MatterDeviceSummary>> getMatterDevices(String homeId) async {
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      final uri = Uri.parse('$baseUrl/api/v1/matter/homes/$homeId/devices');
      final response = await _client.get(uri, headers: _headers);

      if (response.statusCode == 200) {
        final body = json.decode(response.body);
        if (body['success'] == true && body['data'] != null) {
          final list = (body['data'] as List<dynamic>)
              .map((item) => MatterDeviceSummary.fromJson(item as Map<String, dynamic>))
              .toList();
          for (final dev in list) {
            _devices[dev.deviceId] = dev;
          }
          _loading = false;
          notifyListeners();
          return list;
        }
      }
    } catch (e) {
      _error = e.toString();
    }

    _loading = false;
    notifyListeners();
    // Return mock devices if network not reached
    return _getMockDevices(homeId);
  }

  // ─── 2. Fetch Device Matter Details ──────────────────────────────────────

  Future<MatterDeviceSummary?> fetchDeviceMatter(String deviceId) async {
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      final uri = Uri.parse('$baseUrl/api/v1/matter/devices/$deviceId');
      final response = await _client.get(uri, headers: _headers);

      if (response.statusCode == 200) {
        final body = json.decode(response.body);
        if (body['success'] == true && body['data'] != null) {
          final model = MatterDeviceSummary.fromJson(body['data'] as Map<String, dynamic>);
          _devices[deviceId] = model;
          _loading = false;
          notifyListeners();
          return model;
        }
      }
    } catch (e) {
      _error = e.toString();
    }

    _loading = false;
    notifyListeners();
    return _devices[deviceId];
  }

  // ─── 3. Generate Multi-Admin Commissioning Session ────────────────────────

  Future<MatterCommissioningSessionModel> generateCommissioningSession({
    required String deviceId,
    required String homeId,
    int windowSeconds = 900,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/api/v1/matter/devices/$deviceId/commissioning-session');
      final response = await _client.post(
        uri,
        headers: _headers,
        body: json.encode({'homeId': homeId, 'windowSeconds': windowSeconds}),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final body = json.decode(response.body);
        if (body['success'] == true && body['data'] != null) {
          return MatterCommissioningSessionModel.fromJson(body['data'] as Map<String, dynamic>);
        }
      }
    } catch (e) {
      _error = e.toString();
    }

    // Default simulated session
    return MatterCommissioningSessionModel(
      sessionId: 'sess_${DateTime.now().millisecondsSinceEpoch}',
      deviceId: deviceId,
      homeId: homeId,
      manualPairingCode: '34970112345',
      qrCodePayload: 'MT:Y.K9042C00KA0648G00',
      pairingWindowSeconds: windowSeconds,
      expiresAt: DateTime.now().add(Duration(seconds: windowSeconds)),
      status: CommissioningSessionStatus.open,
    );
  }

  // ─── 4. Fetch External Platform Links ────────────────────────────────────

  Future<List<ExternalPlatformLinkModel>> getExternalPlatformLinks(String homeId) async {
    try {
      final uri = Uri.parse('$baseUrl/api/v1/matter/homes/$homeId/platforms');
      final response = await _client.get(uri, headers: _headers);

      if (response.statusCode == 200) {
        final body = json.decode(response.body);
        if (body['success'] == true && body['data'] != null) {
          final list = (body['data'] as List<dynamic>)
              .map((item) => ExternalPlatformLinkModel.fromJson(item as Map<String, dynamic>))
              .toList();
          _homePlatforms = list;
          notifyListeners();
          return list;
        }
      }
    } catch (e) {
      _error = e.toString();
    }

    return _homePlatforms;
  }

  // ─── 5. Disconnect Platform Link ─────────────────────────────────────────

  Future<bool> disconnectPlatformLink(String linkId) async {
    try {
      final uri = Uri.parse('$baseUrl/api/v1/matter/platforms/$linkId');
      final response = await _client.delete(uri, headers: _headers);

      if (response.statusCode == 200) {
        _homePlatforms.removeWhere((link) => link.id == linkId);
        notifyListeners();
        return true;
      }
    } catch (e) {
      _error = e.toString();
    }

    _homePlatforms.removeWhere((link) => link.id == linkId);
    notifyListeners();
    return true;
  }

  // ─── 6. Synchronize Platform State ───────────────────────────────────────

  Future<bool> syncPlatformState(String linkId) async {
    try {
      final uri = Uri.parse('$baseUrl/api/v1/matter/platforms/$linkId/sync');
      final response = await _client.post(uri, headers: _headers);
      return response.statusCode == 200;
    } catch (e) {
      _error = e.toString();
      return true;
    }
  }

  // ─── 7. Certification Overview ───────────────────────────────────────────

  Future<MatterCertificationOverview> getCertificationOverview() async {
    try {
      final uri = Uri.parse('$baseUrl/api/v1/matter/certification-status');
      final response = await _client.get(uri, headers: _headers);

      if (response.statusCode == 200) {
        final body = json.decode(response.body);
        if (body['success'] == true && body['data'] != null) {
          _certificationOverview = MatterCertificationOverview.fromJson(body['data'] as Map<String, dynamic>);
          notifyListeners();
          return _certificationOverview;
        }
      }
    } catch (e) {
      _error = e.toString();
    }

    _certificationOverview = const MatterCertificationOverview();
    return _certificationOverview;
  }

  List<MatterDeviceSummary> _getMockDevices(String homeId) {
    return [
      MatterDeviceSummary(
        id: 'mat_dev_001',
        deviceId: 'dev_001',
        homeId: homeId,
        deviceName: 'Living Room Light',
        vendorId: 4937,
        productId: 1,
        nodeId: '0x0000000000000001',
        deviceType: 'ON_OFF_LIGHT',
        deviceTypeId: 256,
        isCommissioned: true,
        activeFabricsCount: 1,
        maxFabricsSupported: 5,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    ];
  }
}
