import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/intelligence_models.dart';

/// Client Service for EH Home Intelligence & Unified Decision Engine (Phase 24)
class HomeIntelligenceService extends ChangeNotifier {
  final String baseUrl;
  final http.Client _client;
  String? authToken;

  IntelligenceSummary? _currentSummary;
  List<IntelligenceRecommendation> _recommendations = [];
  List<IntelligenceDecision> _decisions = [];
  List<DecisionOutcome> _historyOutcomes = [];

  bool _isLoading = false;
  String? _errorMessage;

  HomeIntelligenceService({
    this.baseUrl = 'http://localhost:3000',
    http.Client? client,
    this.authToken,
  }) : _client = client ?? http.Client();

  IntelligenceSummary? get currentSummary => _currentSummary;
  List<IntelligenceRecommendation> get recommendations => _recommendations;
  List<IntelligenceDecision> get decisions => _decisions;
  List<DecisionOutcome> get historyOutcomes => _historyOutcomes;

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (authToken != null) 'Authorization': 'Bearer $authToken',
      };

  void updateAuthToken(String? token) {
    authToken = token;
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // 1. Intelligence Summary & Snapshots
  // ---------------------------------------------------------------------------

  Future<IntelligenceSummary?> fetchSummary(String homeId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _client.get(
        Uri.parse('$baseUrl/api/v1/intelligence/homes/$homeId/summary'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final body = json.decode(response.body);
        if (body['success'] == true && body['data'] != null) {
          _currentSummary = IntelligenceSummary.fromJson(Map<String, dynamic>.from(body['data'] as Map));
          _recommendations = _currentSummary!.recommendations;
          _decisions = _currentSummary!.recentDecisions;
          _historyOutcomes = _currentSummary!.recentOutcomes;
          _errorMessage = null;
          return _currentSummary;
        }
      }
      _errorMessage = 'Failed to load summary: ${response.statusCode}';
      return null;
    } catch (e) {
      _errorMessage = 'Error fetching summary: $e';
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ---------------------------------------------------------------------------
  // 2. Recommendations & Decisions Listing
  // ---------------------------------------------------------------------------

  Future<List<IntelligenceRecommendation>> fetchRecommendations(
    String homeId, {
    DecisionStatus? status,
    RecommendationType? type,
    int limit = 50,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final queryParams = <String, String>{
        'limit': limit.toString(),
        if (status != null) 'status': status.toApiValue(),
        if (type != null) 'type': type.toApiValue(),
      };

      final uri = Uri.parse('$baseUrl/api/v1/intelligence/homes/$homeId/recommendations').replace(queryParameters: queryParams);
      final response = await _client.get(uri, headers: _headers);

      if (response.statusCode == 200) {
        final body = json.decode(response.body);
        if (body['success'] == true && body['data'] is List) {
          _recommendations = (body['data'] as List)
              .map((e) => IntelligenceRecommendation.fromJson(Map<String, dynamic>.from(e as Map)))
              .toList();
          return _recommendations;
        }
      }
      _errorMessage = 'Failed to fetch recommendations: ${response.statusCode}';
      return [];
    } catch (e) {
      _errorMessage = 'Error fetching recommendations: $e';
      return [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<List<IntelligenceDecision>> fetchDecisions(
    String homeId, {
    DecisionStatus? status,
    DecisionPriority? priority,
    int limit = 50,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final queryParams = <String, String>{
        'limit': limit.toString(),
        if (status != null) 'status': status.toApiValue(),
        if (priority != null) 'priority': priority.toApiValue(),
      };

      final uri = Uri.parse('$baseUrl/api/v1/intelligence/homes/$homeId/decisions').replace(queryParameters: queryParams);
      final response = await _client.get(uri, headers: _headers);

      if (response.statusCode == 200) {
        final body = json.decode(response.body);
        if (body['success'] == true && body['data'] is List) {
          _decisions = (body['data'] as List)
              .map((e) => IntelligenceDecision.fromJson(Map<String, dynamic>.from(e as Map)))
              .toList();
          return _decisions;
        }
      }
      _errorMessage = 'Failed to fetch decisions: ${response.statusCode}';
      return [];
    } catch (e) {
      _errorMessage = 'Error fetching decisions: $e';
      return [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ---------------------------------------------------------------------------
  // 3. Recommendation Lifecycle (Accept / Reject / Execute)
  // ---------------------------------------------------------------------------

  Future<bool> acceptRecommendation(String homeId, String recommendationId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _client.post(
        Uri.parse('$baseUrl/api/v1/intelligence/homes/$homeId/recommendations/$recommendationId/accept'),
        headers: _headers,
        body: json.encode({}),
      );

      if (response.statusCode == 200) {
        await fetchSummary(homeId);
        return true;
      }
      _errorMessage = 'Failed to accept recommendation: ${response.statusCode}';
      return false;
    } catch (e) {
      _errorMessage = 'Error accepting recommendation: $e';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> rejectRecommendation(String homeId, String recommendationId, {String? reason}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _client.post(
        Uri.parse('$baseUrl/api/v1/intelligence/homes/$homeId/recommendations/$recommendationId/reject'),
        headers: _headers,
        body: json.encode({'reason': reason ?? 'Rejected by user'}),
      );

      if (response.statusCode == 200) {
        await fetchSummary(homeId);
        return true;
      }
      _errorMessage = 'Failed to reject recommendation: ${response.statusCode}';
      return false;
    } catch (e) {
      _errorMessage = 'Error rejecting recommendation: $e';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> executeDecision(String homeId, String decisionId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _client.post(
        Uri.parse('$baseUrl/api/v1/intelligence/homes/$homeId/decisions/$decisionId/execute'),
        headers: _headers,
        body: json.encode({}),
      );

      if (response.statusCode == 200) {
        await fetchSummary(homeId);
        return true;
      }
      _errorMessage = 'Failed to execute decision: ${response.statusCode}';
      return false;
    } catch (e) {
      _errorMessage = 'Error executing decision: $e';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ---------------------------------------------------------------------------
  // 4. Deterministic Evaluation & Auto-Execution Triggers
  // ---------------------------------------------------------------------------

  Future<bool> triggerEvaluation(String homeId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _client.post(
        Uri.parse('$baseUrl/api/v1/intelligence/homes/$homeId/evaluate'),
        headers: _headers,
        body: json.encode({}),
      );

      if (response.statusCode == 200) {
        await fetchSummary(homeId);
        return true;
      }
      _errorMessage = 'Evaluation failed: ${response.statusCode}';
      return false;
    } catch (e) {
      _errorMessage = 'Error triggering evaluation: $e';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> triggerAutoExecution(String homeId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _client.post(
        Uri.parse('$baseUrl/api/v1/intelligence/homes/$homeId/auto-execute'),
        headers: _headers,
        body: json.encode({}),
      );

      if (response.statusCode == 200) {
        await fetchSummary(homeId);
        return true;
      }
      _errorMessage = 'Auto-execution failed: ${response.statusCode}';
      return false;
    } catch (e) {
      _errorMessage = 'Error triggering auto-execution: $e';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ---------------------------------------------------------------------------
  // 5. Outcome History
  // ---------------------------------------------------------------------------

  Future<List<DecisionOutcome>> fetchHistory(String homeId, {int limit = 50}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _client.get(
        Uri.parse('$baseUrl/api/v1/intelligence/homes/$homeId/history?limit=$limit'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final body = json.decode(response.body);
        if (body['success'] == true && body['data'] is List) {
          _historyOutcomes = (body['data'] as List)
              .map((e) => DecisionOutcome.fromJson(Map<String, dynamic>.from(e as Map)))
              .toList();
          return _historyOutcomes;
        }
      }
      _errorMessage = 'Failed to fetch history: ${response.statusCode}';
      return [];
    } catch (e) {
      _errorMessage = 'Error fetching history: $e';
      return [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
