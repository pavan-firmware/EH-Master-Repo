import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../app/home_controller.dart';
import '../api/api_client.dart';
import '../config/app_config.dart';
import '../models/context_presence_models.dart';
import 'device_storage_service.dart';

/// Client Service for EH Home Presence and Context Intelligence (Phase 23)
class ContextPresenceService extends ChangeNotifier {
  final String baseUrl;
  final http.Client _client;
  final ApiClient? apiClient;
  String? authToken;

  static PresenceSnapshotModel? cachedSnapshot;
  static HomeContextModel? cachedContext;
  static List<ContextTransitionModel> cachedTransitions = [];

  PresenceSnapshotModel? _currentSnapshot;
  HomeContextModel? _currentContext;
  List<ContextTransitionModel> _transitions = [];
  List<PresenceSignalModel> _recentSignals = [];

  bool _isLoading = false;
  String? _errorMessage;

  ContextPresenceService({
    String? baseUrl,
    http.Client? client,
    this.apiClient,
    this.authToken,
  })  : baseUrl = baseUrl ?? AppConfig.backendBaseUrl,
        _client = client ?? http.Client(),
        _currentSnapshot = cachedSnapshot,
        _currentContext = cachedContext,
        _transitions = cachedTransitions.isNotEmpty ? List.from(cachedTransitions) : [];

  PresenceSnapshotModel? get currentSnapshot => _currentSnapshot;
  HomeContextModel? get currentContext => _currentContext;
  List<ContextTransitionModel> get transitions => _transitions;
  List<PresenceSignalModel> get recentSignals => _recentSignals;

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  ApiClient get effectiveApiClient =>
      apiClient ?? ApiClient(baseUrl: baseUrl, client: _client);

  Future<Map<String, String>> _getHeaders() async {
    String? token = authToken;
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
      if (token != null) authToken = token;
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
    if (homeId.isNotEmpty && homeId != 'home_default') {
      return homeId;
    }
    final ctrl = HomeController.instance;
    if (ctrl?.activeHomeId != null &&
        ctrl!.activeHomeId!.isNotEmpty &&
        ctrl.activeHomeId != 'home_default') {
      return ctrl.activeHomeId!;
    }
    final cached = DeviceStorageService.cachedActiveHomeId;
    if (cached != null && cached.isNotEmpty && cached != 'home_default') {
      return cached;
    }
    try {
      final homes = await effectiveApiClient.get('/api/v1/homes');
      if (homes != null) {
        final list = homes is List
            ? homes
            : (homes is Map && homes['data'] is List ? homes['data'] as List : []);
        if (list.isNotEmpty && list[0]['id'] != null) {
          final resolved = list[0]['id'].toString();
          DeviceStorageService.cachedActiveHomeId = resolved;
          return resolved;
        }
      }
    } catch (_) {}
    return homeId.isNotEmpty ? homeId : 'home_default';
  }

  Future<dynamic> _apiGet(String path) async {
    if (apiClient != null) {
      return apiClient!.get(path);
    }
    final headers = await _getHeaders();
    final uri = Uri.parse('$baseUrl$path');
    final response = await _client.get(uri, headers: headers);
    return _handleResponse(response, () => _apiGet(path));
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
    return _handleResponse(response, () => _apiPost(path, body: body));
  }

  Future<dynamic> _apiDelete(String path) async {
    if (apiClient != null) {
      return apiClient!.delete(path);
    }
    final headers = await _getHeaders();
    final uri = Uri.parse('$baseUrl$path');
    final response = await _client.delete(uri, headers: headers);
    return _handleResponse(response, () => _apiDelete(path));
  }

  Future<dynamic> _handleResponse(http.Response response, Future<dynamic> Function() retry) async {
    if (response.statusCode == 401 && ApiClient.defaultRefreshTokenProvider != null) {
      final refreshSuccess = await ApiClient.defaultRefreshTokenProvider!();
      if (refreshSuccess) {
        authToken = null;
        return retry();
      } else {
        ApiClient.defaultSessionExpiredHandler?.call();
        throw ApiException(statusCode: 401, message: 'Authentication required: session expired');
      }
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.isEmpty) return null;
      try {
        final data = json.decode(response.body);
        if (data is Map<String, dynamic> && data.containsKey('data')) {
          return data['data'];
        }
        return data;
      } catch (_) {
        return response.body;
      }
    }

    String msg = 'Request failed (${response.statusCode})';
    try {
      final body = json.decode(response.body);
      if (body is Map) {
        msg = body['error']?['message']?.toString() ??
            body['error']?.toString() ??
            body['message']?.toString() ??
            msg;
      }
    } catch (_) {}
    throw ApiException(statusCode: response.statusCode, message: msg);
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
      debugPrint('[ContextPresenceService] fetchPresenceSnapshot for homeId=$effectiveHomeId');
      final res = await _apiGet('/api/v1/context/homes/$effectiveHomeId/presence');

      if (res is Map<String, dynamic>) {
        _currentSnapshot = PresenceSnapshotModel.fromJson(res);
        cachedSnapshot = _currentSnapshot;
        _isLoading = false;
        notifyListeners();
        return _currentSnapshot;
      }
      _errorMessage = 'Invalid presence data received';
    } on ApiException catch (e) {
      _errorMessage = e.message;
      debugPrint('[ContextPresenceService] Presence API error: ${e.message} (${e.statusCode})');
    } catch (e) {
      _errorMessage = 'Network error: $e';
      debugPrint('[ContextPresenceService] Presence network error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
    return _currentSnapshot;
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

      debugPrint('[ContextPresenceService] submitPresenceSignal for homeId=$effectiveHomeId state=${state.toApiValue()}');
      final res = await _apiPost(
        '/api/v1/context/homes/$effectiveHomeId/presence',
        body: payload,
      );

      if (res is Map<String, dynamic>) {
        if (res['context'] != null && res['context'] is Map<String, dynamic>) {
          _currentContext = HomeContextModel.fromJson(Map<String, dynamic>.from(res['context'] as Map));
        }
        await fetchPresenceSnapshot(effectiveHomeId);
        return true;
      }
      return false;
    } on ApiException catch (e) {
      _errorMessage = e.message;
      debugPrint('[ContextPresenceService] submit signal API error: ${e.message}');
    } catch (e) {
      _errorMessage = 'Network error: $e';
      debugPrint('[ContextPresenceService] submit signal error: $e');
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
      final effectiveHomeId = await _resolveHomeId(homeId);
      debugPrint('[ContextPresenceService] fetchHomeContext for homeId=$effectiveHomeId');
      final res = await _apiGet('/api/v1/context/homes/$effectiveHomeId/context');

      if (res is Map<String, dynamic>) {
        _currentContext = HomeContextModel.fromJson(res);
        cachedContext = _currentContext;
        _isLoading = false;
        notifyListeners();
        return _currentContext;
      }
      _errorMessage = 'Invalid context data received';
    } on ApiException catch (e) {
      _errorMessage = e.message;
      debugPrint('[ContextPresenceService] Context API error: ${e.message} (${e.statusCode})');
    } catch (e) {
      _errorMessage = 'Network error: $e';
      debugPrint('[ContextPresenceService] Context network error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
    return _currentContext;
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
      final effectiveHomeId = await _resolveHomeId(homeId);
      final payload = {
        'mode': mode.toApiValue(),
        'reason': reason,
        'durationHours': ?durationHours,
      };

      debugPrint('[ContextPresenceService] setContextOverride mode=${mode.toApiValue()} homeId=$effectiveHomeId');
      final res = await _apiPost(
        '/api/v1/context/homes/$effectiveHomeId/override',
        body: payload,
      );

      if (res is Map<String, dynamic>) {
        if (res['context'] != null && res['context'] is Map<String, dynamic>) {
          _currentContext = HomeContextModel.fromJson(Map<String, dynamic>.from(res['context'] as Map));
          cachedContext = _currentContext;
        }
        await fetchTransitions(effectiveHomeId);
        _isLoading = false;
        notifyListeners();
        return true;
      }
      _errorMessage = 'Failed to set context override';
    } on ApiException catch (e) {
      _errorMessage = e.message;
      debugPrint('[ContextPresenceService] Override API error: ${e.message}');
    } catch (e) {
      _errorMessage = 'Network error: $e';
      debugPrint('[ContextPresenceService] Override network error: $e');
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
      final effectiveHomeId = await _resolveHomeId(homeId);
      debugPrint('[ContextPresenceService] clearContextOverride homeId=$effectiveHomeId');
      final res = await _apiDelete('/api/v1/context/homes/$effectiveHomeId/override');

      if (res is Map<String, dynamic>) {
        if (res['context'] != null && res['context'] is Map<String, dynamic>) {
          _currentContext = HomeContextModel.fromJson(Map<String, dynamic>.from(res['context'] as Map));
          cachedContext = _currentContext;
        }
        await fetchTransitions(effectiveHomeId);
        _isLoading = false;
        notifyListeners();
        return true;
      }
      _errorMessage = 'Failed to clear context override';
    } on ApiException catch (e) {
      _errorMessage = e.message;
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
      final effectiveHomeId = await _resolveHomeId(homeId);
      final payload = {
        'durationDays': durationDays,
        'reason': reason,
      };

      final res = await _apiPost(
        '/api/v1/context/homes/$effectiveHomeId/vacation',
        body: payload,
      );

      if (res is Map<String, dynamic>) {
        if (res['context'] != null && res['context'] is Map<String, dynamic>) {
          _currentContext = HomeContextModel.fromJson(Map<String, dynamic>.from(res['context'] as Map));
          cachedContext = _currentContext;
        }
        await fetchTransitions(effectiveHomeId);
        _isLoading = false;
        notifyListeners();
        return true;
      }
      _errorMessage = 'Failed to set vacation mode';
    } on ApiException catch (e) {
      _errorMessage = e.message;
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
      final effectiveHomeId = await _resolveHomeId(homeId);
      debugPrint('[ContextPresenceService] fetchTransitions homeId=$effectiveHomeId');
      final res = await _apiGet('/api/v1/context/homes/$effectiveHomeId/transitions?limit=$limit');

      List<dynamic> listData = [];
      if (res is List) {
        listData = res;
      } else if (res is Map && res['data'] is List) {
        listData = res['data'] as List;
      }
      _transitions = listData
          .map((e) => ContextTransitionModel.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
      cachedTransitions = List.from(_transitions);
      notifyListeners();
      return _transitions;
    } catch (e) {
      debugPrint('[ContextPresenceService] Error fetching transitions: $e');
    }
    return _transitions;
  }

  Future<List<PresenceSignalModel>> fetchSignals(String homeId, {int limit = 50, String? userId}) async {
    try {
      final effectiveHomeId = await _resolveHomeId(homeId);
      var path = '/api/v1/context/homes/$effectiveHomeId/signals?limit=$limit';
      if (userId != null) path += '&userId=$userId';

      final res = await _apiGet(path);
      List<dynamic> listData = [];
      if (res is List) {
        listData = res;
      } else if (res is Map && res['data'] is List) {
        listData = res['data'] as List;
      }
      _recentSignals = listData
          .map((e) => PresenceSignalModel.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
      notifyListeners();
      return _recentSignals;
    } catch (e) {
      debugPrint('[ContextPresenceService] Error fetching signals: $e');
    }
    return _recentSignals;
  }
}
