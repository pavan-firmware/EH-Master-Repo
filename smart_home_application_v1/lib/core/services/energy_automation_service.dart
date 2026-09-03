import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/energy_automation_models.dart';

/// EH Home — Smart Energy Automation & Optimization Service (Phase 20)
class EnergyAutomationService extends ChangeNotifier {
  final String baseUrl;
  final http.Client? httpClient;
  final String? Function()? getAuthToken;

  List<EnergyAutomationRuleModel> _automations = [];
  List<EnergyAutomationRuleModel> get automations => _automations;

  List<EnergyAutomationExecutionModel> _executionHistory = [];
  List<EnergyAutomationExecutionModel> get executionHistory => _executionHistory;

  List<EnergyOptimizationRecommendationModel> _optimizations = [];
  List<EnergyOptimizationRecommendationModel> get optimizations => _optimizations;

  EnergyOptimizationSummaryModel _optimizationSummary = const EnergyOptimizationSummaryModel();
  EnergyOptimizationSummaryModel get optimizationSummary => _optimizationSummary;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _lastError;
  String? get lastError => _lastError;

  EnergyAutomationService({
    this.baseUrl = 'http://127.0.0.1:3000',
    this.httpClient,
    this.getAuthToken,
  });

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

  // ---------------------------------------------------------------------------
  // 1. Fetch Automations for Home
  // ---------------------------------------------------------------------------
  Future<List<EnergyAutomationRuleModel>> fetchAutomations(String homeId) async {
    _isLoading = true;
    _lastError = null;
    notifyListeners();

    try {
      final client = httpClient ?? http.Client();
      final uri = Uri.parse('$baseUrl/api/v1/energy/automations?homeId=$homeId');
      final res = await client.get(uri, headers: _buildHeaders());

      if (res.statusCode == 200) {
        final body = json.decode(res.body);
        final list = (body['data'] as List<dynamic>? ?? [])
            .map((item) => EnergyAutomationRuleModel.fromJson(Map<String, dynamic>.from(item)))
            .toList();
        _automations = list;
        return list;
      } else {
        _lastError = 'Failed to load energy automations (HTTP ${res.statusCode})';
        return _automations;
      }
    } catch (e) {
      _lastError = e.toString();
      return _automations;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ---------------------------------------------------------------------------
  // 2. Create Automation Rule
  // ---------------------------------------------------------------------------
  Future<EnergyAutomationRuleModel?> createAutomation(EnergyAutomationRuleModel rule) async {
    _isLoading = true;
    _lastError = null;
    notifyListeners();

    try {
      final client = httpClient ?? http.Client();
      final uri = Uri.parse('$baseUrl/api/v1/energy/automations');
      final res = await client.post(
        uri,
        headers: _buildHeaders(),
        body: json.encode(rule.toJson()),
      );

      if (res.statusCode == 201) {
        final body = json.decode(res.body);
        final created = EnergyAutomationRuleModel.fromJson(Map<String, dynamic>.from(body['data']));
        _automations.insert(0, created);
        return created;
      } else {
        _lastError = 'Failed to create energy automation (HTTP ${res.statusCode})';
        return null;
      }
    } catch (e) {
      _lastError = e.toString();
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ---------------------------------------------------------------------------
  // 3. Update Automation Rule
  // ---------------------------------------------------------------------------
  Future<EnergyAutomationRuleModel?> updateAutomation(String id, Map<String, dynamic> updates) async {
    _isLoading = true;
    _lastError = null;
    notifyListeners();

    try {
      final client = httpClient ?? http.Client();
      final uri = Uri.parse('$baseUrl/api/v1/energy/automations/$id');
      final res = await client.put(
        uri,
        headers: _buildHeaders(),
        body: json.encode(updates),
      );

      if (res.statusCode == 200) {
        final body = json.decode(res.body);
        final updated = EnergyAutomationRuleModel.fromJson(Map<String, dynamic>.from(body['data']));
        final idx = _automations.indexWhere((a) => a.id == id);
        if (idx != -1) {
          _automations[idx] = updated;
        }
        return updated;
      } else {
        _lastError = 'Failed to update energy automation (HTTP ${res.statusCode})';
        return null;
      }
    } catch (e) {
      _lastError = e.toString();
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ---------------------------------------------------------------------------
  // 4. Toggle Automation (Enable / Disable)
  // ---------------------------------------------------------------------------
  Future<bool> toggleAutomation(String id, bool enable) async {
    _lastError = null;

    try {
      final client = httpClient ?? http.Client();
      final action = enable ? 'enable' : 'disable';
      final uri = Uri.parse('$baseUrl/api/v1/energy/automations/$id/$action');
      final res = await client.post(uri, headers: _buildHeaders());

      if (res.statusCode == 200) {
        final body = json.decode(res.body);
        final updated = EnergyAutomationRuleModel.fromJson(Map<String, dynamic>.from(body['data']));
        final idx = _automations.indexWhere((a) => a.id == id);
        if (idx != -1) {
          _automations[idx] = updated;
        }
        notifyListeners();
        return true;
      } else {
        _lastError = 'Failed to toggle automation (HTTP ${res.statusCode})';
        return false;
      }
    } catch (e) {
      _lastError = e.toString();
      return false;
    }
  }

  // ---------------------------------------------------------------------------
  // 5. Delete Automation Rule
  // ---------------------------------------------------------------------------
  Future<bool> deleteAutomation(String id) async {
    _isLoading = true;
    _lastError = null;
    notifyListeners();

    try {
      final client = httpClient ?? http.Client();
      final uri = Uri.parse('$baseUrl/api/v1/energy/automations/$id');
      final res = await client.delete(uri, headers: _buildHeaders());

      if (res.statusCode == 200) {
        _automations.removeWhere((a) => a.id == id);
        return true;
      } else {
        _lastError = 'Failed to delete automation (HTTP ${res.statusCode})';
        return false;
      }
    } catch (e) {
      _lastError = e.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ---------------------------------------------------------------------------
  // 6. Manual Rule Evaluation
  // ---------------------------------------------------------------------------
  Future<Map<String, dynamic>?> evaluateAutomation(String id, {Map<String, dynamic>? context}) async {
    _lastError = null;

    try {
      final client = httpClient ?? http.Client();
      final uri = Uri.parse('$baseUrl/api/v1/energy/automations/$id/evaluate');
      final res = await client.post(
        uri,
        headers: _buildHeaders(),
        body: json.encode({'context': context ?? {}}),
      );

      if (res.statusCode == 200) {
        final body = json.decode(res.body);
        return Map<String, dynamic>.from(body['data'] ?? {});
      } else {
        _lastError = 'Evaluation failed (HTTP ${res.statusCode})';
        return null;
      }
    } catch (e) {
      _lastError = e.toString();
      return null;
    }
  }

  // ---------------------------------------------------------------------------
  // 7. Execution History
  // ---------------------------------------------------------------------------
  Future<List<EnergyAutomationExecutionModel>> fetchExecutionHistory(String automationId, {int limit = 50}) async {
    _isLoading = true;
    _lastError = null;
    notifyListeners();

    try {
      final client = httpClient ?? http.Client();
      final uri = Uri.parse('$baseUrl/api/v1/energy/automations/$automationId/history?limit=$limit');
      final res = await client.get(uri, headers: _buildHeaders());

      if (res.statusCode == 200) {
        final body = json.decode(res.body);
        final list = (body['data'] as List<dynamic>? ?? [])
            .map((item) => EnergyAutomationExecutionModel.fromJson(Map<String, dynamic>.from(item)))
            .toList();
        _executionHistory = list;
        return list;
      } else {
        _lastError = 'Failed to load execution history (HTTP ${res.statusCode})';
        return _executionHistory;
      }
    } catch (e) {
      _lastError = e.toString();
      return _executionHistory;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ---------------------------------------------------------------------------
  // 8. Optimization Recommendations
  // ---------------------------------------------------------------------------
  Future<List<EnergyOptimizationRecommendationModel>> fetchOptimizationRecommendations(String homeId) async {
    _isLoading = true;
    _lastError = null;
    notifyListeners();

    try {
      final client = httpClient ?? http.Client();
      final uri = Uri.parse('$baseUrl/api/v1/energy/optimization?homeId=$homeId');
      final res = await client.get(uri, headers: _buildHeaders());

      if (res.statusCode == 200) {
        final body = json.decode(res.body);
        final data = body['data'] ?? {};
        if (data['summary'] != null) {
          _optimizationSummary = EnergyOptimizationSummaryModel.fromJson(Map<String, dynamic>.from(data['summary']));
        }
        final list = (data['recommendations'] as List<dynamic>? ?? [])
            .map((item) => EnergyOptimizationRecommendationModel.fromJson(Map<String, dynamic>.from(item)))
            .toList();
        _optimizations = list;
        return list;
      } else {
        _lastError = 'Failed to load optimization recommendations (HTTP ${res.statusCode})';
        return _optimizations;
      }
    } catch (e) {
      _lastError = e.toString();
      return _optimizations;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ---------------------------------------------------------------------------
  // 9. Dismiss Optimization Recommendation
  // ---------------------------------------------------------------------------
  Future<bool> dismissOptimization(String homeId, String recommendationId) async {
    _lastError = null;

    try {
      final client = httpClient ?? http.Client();
      final uri = Uri.parse('$baseUrl/api/v1/energy/optimization/$recommendationId/dismiss');
      final res = await client.post(
        uri,
        headers: _buildHeaders(),
        body: json.encode({'homeId': homeId}),
      );

      if (res.statusCode == 200) {
        _optimizations.removeWhere((r) => r.id == recommendationId);
        notifyListeners();
        return true;
      } else {
        _lastError = 'Failed to dismiss recommendation (HTTP ${res.statusCode})';
        return false;
      }
    } catch (e) {
      _lastError = e.toString();
      return false;
    }
  }
}
