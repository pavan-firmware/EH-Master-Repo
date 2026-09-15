import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../api/api_client.dart';
import '../models/context_presence_models.dart';

/// Client Service for EH Home Presence and Context Intelligence (Phase 23)
class ContextPresenceService extends ChangeNotifier {
  final String baseUrl;
  final http.Client _client;
  final ApiClient? apiClient;
  String? authToken;

  PresenceSnapshotModel? _currentSnapshot;
  HomeContextModel? _currentContext;
  List<ContextTransitionModel> _transitions = [];
  List<PresenceSignalModel> _recentSignals = [];

  bool _isLoading = false;
  String? _errorMessage;

  ContextPresenceService({
    this.baseUrl = 'http://localhost:3000',
    http.Client? client,
    this.apiClient,
    this.authToken,
  }) : _client = client ?? http.Client();

  PresenceSnapshotModel? get currentSnapshot => _currentSnapshot;
  HomeContextModel? get currentContext => _currentContext;
  List<ContextTransitionModel> get transitions => _transitions;
  List<PresenceSignalModel> get recentSignals => _recentSignals;

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<Map<String, String>> _getHeaders() async {
    String? token = authToken;
    if (token == null || token.isEmpty) {
      if (apiClient?.getAccessToken != null) {
        token = await apiClient!.getAccessToken!();
      }
    }
    return {
      'Content-Type': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  void updateAuthToken(String? token) {
    authToken = token;
    notifyListeners();
  }

  Future<String> _resolveHomeId(String homeId) async {
    if ((homeId.isEmpty || homeId == 'HN-7A28F91C' || homeId == 'home_preview') && apiClient != null) {
      try {
        final homes = await apiClient!.get('/api/v1/homes');
        if (homes != null) {
          final list = homes is List
              ? homes
              : (homes is Map && homes['data'] is List ? homes['data'] as List : []);
          if (list.isNotEmpty && list[0]['id'] != null) {
            return list[0]['id'].toString();
          }
        }
      } catch (_) {}
    }
    return homeId;
  }

  // ---------------------------------------------------------------------------
  // 1. Presence Snapshot & Signal Ingestion
  // ---------------------------------------------------------------------------

  Future<PresenceSnapshotModel?> fetchPresenceSnapshot(String homeId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final effectiveHomeId = await _resolveHomeId(homeId);
      final headers = await _getHeaders();
      final response = await _client.get(
        Uri.parse('$baseUrl/api/v1/context/homes/$effectiveHomeId/presence'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final body = json.decode(response.body);
        if (body['success'] == true && body['data'] != null) {
          _currentSnapshot = PresenceSnapshotModel.fromJson(Map<String, dynamic>.from(body['data']));
          _isLoading = false;
          notifyListeners();
          return _currentSnapshot;
        }
      }
      try {
        final body = json.decode(response.body);
        _errorMessage = body['error']?.toString() ?? 'Failed to load presence snapshot (${response.statusCode})';
      } catch (_) {
        _errorMessage = 'Failed to load presence snapshot: ${response.statusCode}';
      }
    } catch (e) {
      _errorMessage = 'Network error: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
    return null;
  }

  Future<bool> submitPresenceSignal({
    required String homeId,
    String? userId,
    required PresenceSource source,
    required PresenceState state,
    double confidence = 1.0,
    Map<String, dynamic> evidence = const {},
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final effectiveHomeId = await _resolveHomeId(homeId);
      final payload = {
        'userId': ?userId,
        'source': source.toApiValue(),
        'state': state.toApiValue(),
        'confidence': confidence,
        'evidence': evidence,
      };

      final headers = await _getHeaders();
      final response = await _client.post(
        Uri.parse('$baseUrl/api/v1/context/homes/$effectiveHomeId/presence'),
        headers: headers,
        body: json.encode(payload),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        final body = json.decode(response.body);
        if (body['success'] == true) {
          if (body['data']?['context'] != null) {
            _currentContext = HomeContextModel.fromJson(Map<String, dynamic>.from(body['data']['context']));
          }
          await fetchPresenceSnapshot(effectiveHomeId);
          return true;
        }
      }
      try {
        final body = json.decode(response.body);
        _errorMessage = body['error']?.toString() ?? 'Failed to submit presence signal (${response.statusCode})';
      } catch (_) {
        _errorMessage = 'Failed to submit presence signal: ${response.statusCode}';
      }
    } catch (e) {
      _errorMessage = 'Network error: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
    return false;
  }

  // ---------------------------------------------------------------------------
  // 2. Home Context & State Machine
  // ---------------------------------------------------------------------------

  Future<HomeContextModel?> fetchHomeContext(String homeId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final headers = await _getHeaders();
      final response = await _client.get(
        Uri.parse('$baseUrl/api/v1/context/homes/$homeId/context'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final body = json.decode(response.body);
        if (body['success'] == true && body['data'] != null) {
          _currentContext = HomeContextModel.fromJson(Map<String, dynamic>.from(body['data']));
          _isLoading = false;
          notifyListeners();
          return _currentContext;
        }
      }
      _errorMessage = 'Failed to load home context: ${response.statusCode}';
    } catch (e) {
      _errorMessage = 'Network error: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
    return null;
  }

  Future<bool> setContextOverride({
    required String homeId,
    required ContextMode mode,
    String reason = '',
    int? durationHours,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final payload = {
        'mode': mode.toApiValue(),
        'reason': reason,
        'durationHours': ?durationHours,
      };

      final headers = await _getHeaders();
      final response = await _client.post(
        Uri.parse('$baseUrl/api/v1/context/homes/$homeId/override'),
        headers: headers,
        body: json.encode(payload),
      );

      if (response.statusCode == 200) {
        final body = json.decode(response.body);
        if (body['success'] == true && body['data']?['context'] != null) {
          _currentContext = HomeContextModel.fromJson(Map<String, dynamic>.from(body['data']['context']));
          _isLoading = false;
          notifyListeners();
          return true;
        }
      }
      _errorMessage = 'Failed to set context override: ${response.statusCode}';
    } catch (e) {
      _errorMessage = 'Network error: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
    return false;
  }

  Future<bool> clearContextOverride(String homeId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final headers = await _getHeaders();
      final response = await _client.delete(
        Uri.parse('$baseUrl/api/v1/context/homes/$homeId/override'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final body = json.decode(response.body);
        if (body['success'] == true && body['data']?['context'] != null) {
          _currentContext = HomeContextModel.fromJson(Map<String, dynamic>.from(body['data']['context']));
          _isLoading = false;
          notifyListeners();
          return true;
        }
      }
      _errorMessage = 'Failed to clear context override: ${response.statusCode}';
    } catch (e) {
      _errorMessage = 'Network error: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
    return false;
  }

  Future<bool> setQuickMode(String homeId, ContextMode mode) async {
    return setContextOverride(homeId: homeId, mode: mode, reason: 'Quick mode selector');
  }

  Future<bool> setVacationMode(
    String homeId, {
    int durationDays = 7,
    String reason = 'Vacation Mode',
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final payload = {
        'durationDays': durationDays,
        'reason': reason,
      };

      final headers = await _getHeaders();
      final response = await _client.post(
        Uri.parse('$baseUrl/api/v1/context/homes/$homeId/vacation'),
        headers: headers,
        body: json.encode(payload),
      );

      if (response.statusCode == 200) {
        final body = json.decode(response.body);
        if (body['success'] == true && body['data']?['context'] != null) {
          _currentContext = HomeContextModel.fromJson(Map<String, dynamic>.from(body['data']['context']));
          _isLoading = false;
          notifyListeners();
          return true;
        }
      }
      _errorMessage = 'Failed to set vacation mode: ${response.statusCode}';
    } catch (e) {
      _errorMessage = 'Network error: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
    return false;
  }

  // ---------------------------------------------------------------------------
  // 3. Transitions & Signal History
  // ---------------------------------------------------------------------------

  Future<List<ContextTransitionModel>> fetchTransitions(String homeId, {int limit = 50}) async {
    try {
      final headers = await _getHeaders();
      final response = await _client.get(
        Uri.parse('$baseUrl/api/v1/context/homes/$homeId/transitions?limit=$limit'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final body = json.decode(response.body);
        if (body['success'] == true && body['data'] is List) {
          _transitions = (body['data'] as List)
              .map((e) => ContextTransitionModel.fromJson(Map<String, dynamic>.from(e as Map)))
              .toList();
          notifyListeners();
          return _transitions;
        }
      }
    } catch (e) {
      _errorMessage = 'Error fetching transitions: $e';
    }
    return [];
  }

  Future<List<PresenceSignalModel>> fetchSignals(String homeId, {int limit = 50, String? userId}) async {
    try {
      var url = '$baseUrl/api/v1/context/homes/$homeId/signals?limit=$limit';
      if (userId != null) url += '&userId=$userId';

      final headers = await _getHeaders();
      final response = await _client.get(
        Uri.parse(url),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final body = json.decode(response.body);
        if (body['success'] == true && body['data'] is List) {
          _recentSignals = (body['data'] as List)
              .map((e) => PresenceSignalModel.fromJson(Map<String, dynamic>.from(e as Map)))
              .toList();
          notifyListeners();
          return _recentSignals;
        }
      }
    } catch (e) {
      _errorMessage = 'Error fetching signals: $e';
    }
    return [];
  }
}
