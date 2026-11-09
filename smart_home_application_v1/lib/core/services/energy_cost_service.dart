import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../app/home_controller.dart';
import '../api/api_client.dart';
import '../config/app_config.dart';
import '../models/energy_cost_models.dart';
import 'device_storage_service.dart';

/// Client Service for Electricity Tariffs, Cost Analytics, Budgets & Optimizations
class EnergyCostService extends ChangeNotifier {
  final String baseUrl;
  final http.Client _client;
  final ApiClient? apiClient;
  String? authToken;

  List<ElectricityTariffModel> _tariffs = [];
  EnergyCostSummaryModel? _costSummary;
  CostForecastModel? _forecast;
  BudgetStatusModel? _budgetStatus;
  CheapestPeriodModel? _cheapestPeriods;
  CarbonFootprintModel? _carbonFootprint;
  List<CostOptimizationRecommendationModel> _optimizations = [];
  bool _isLoading = false;
  String? _errorMessage;

  EnergyCostService({
    String? baseUrl,
    http.Client? client,
    this.apiClient,
    this.authToken,
  })  : baseUrl = baseUrl ?? AppConfig.backendBaseUrl,
        _client = client ?? http.Client();

  List<ElectricityTariffModel> get tariffs => _tariffs;
  EnergyCostSummaryModel? get costSummary => _costSummary;
  CostForecastModel? get forecast => _forecast;
  BudgetStatusModel? get budgetStatus => _budgetStatus;
  CheapestPeriodModel? get cheapestPeriods => _cheapestPeriods;
  CarbonFootprintModel? get carbonFootprint => _carbonFootprint;
  List<CostOptimizationRecommendationModel> get optimizations => _optimizations;
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
    final client = effectiveApiClient;
    try {
      final homes = await client.get('/api/v1/homes');
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
    return homeId;
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

  Future<dynamic> _apiPut(String path, {Map<String, dynamic>? body}) async {
    if (apiClient != null) {
      return apiClient!.put(path, body: body);
    }
    final headers = await _getHeaders();
    final uri = Uri.parse('$baseUrl$path');
    final response = await _client.put(
      uri,
      headers: headers,
      body: body != null ? json.encode(body) : null,
    );
    return _handleResponse(response, () => _apiPut(path, body: body));
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
  // 1. Electricity Tariffs Management
  // ---------------------------------------------------------------------------

  Future<List<ElectricityTariffModel>> fetchTariffs(String homeId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final effectiveHomeId = await _resolveHomeId(homeId);
      final res = await _apiGet('/api/v1/energy/homes/$effectiveHomeId/tariffs');
      List<dynamic> listData = [];
      if (res is List) {
        listData = res;
      } else if (res is Map && res['data'] is List) {
        listData = res['data'] as List;
      }
      final list = listData
          .map((t) => ElectricityTariffModel.fromJson(Map<String, dynamic>.from(t as Map)))
          .toList();
      _tariffs = list;
      _isLoading = false;
      notifyListeners();
      return list;
    } on ApiException catch (e) {
      _isLoading = false;
      _errorMessage = e.message;
      notifyListeners();
      return _tariffs;
    } catch (e) {
      _isLoading = false;
      _errorMessage = e.toString();
      notifyListeners();
      return _tariffs;
    }
  }

  Future<ElectricityTariffModel?> createTariff(ElectricityTariffModel tariff) async {
    try {
      final effectiveHomeId = await _resolveHomeId(tariff.homeId);
      final payload = tariff.copyWith(homeId: effectiveHomeId).toJson();
      final res = await _apiPost(
        '/api/v1/energy/homes/$effectiveHomeId/tariffs',
        body: payload,
      );

      if (res is Map<String, dynamic>) {
        final created = ElectricityTariffModel.fromJson(res);
        if (created.isActive) {
          _tariffs = [created, ..._tariffs.map((t) => t.copyWith(isActive: false))];
        } else {
          _tariffs = [created, ..._tariffs.where((t) => t.id != created.id)];
        }
        _costSummary = null;
        _forecast = null;
        _errorMessage = null;
        notifyListeners();
        return created;
      }
      return null;
    } on ApiException catch (e) {
      _errorMessage = e.message;
      notifyListeners();
      return null;
    } catch (e) {
      _errorMessage = 'Network connection error: $e';
      notifyListeners();
      return null;
    }
  }

  Future<ElectricityTariffModel?> updateTariff(ElectricityTariffModel tariff) async {
    try {
      final effectiveHomeId = await _resolveHomeId(tariff.homeId);
      final payload = tariff.copyWith(homeId: effectiveHomeId).toJson();
      final res = await _apiPut(
        '/api/v1/energy/homes/$effectiveHomeId/tariffs/${tariff.id}',
        body: payload,
      );

      if (res is Map<String, dynamic>) {
        final updated = ElectricityTariffModel.fromJson(res);
        if (updated.isActive) {
          _tariffs = _tariffs.map((t) => t.id == updated.id ? updated : t.copyWith(isActive: false)).toList();
        } else {
          _tariffs = _tariffs.map((t) => t.id == updated.id ? updated : t).toList();
        }
        _costSummary = null;
        _forecast = null;
        _errorMessage = null;
        notifyListeners();
        return updated;
      }
      return null;
    } on ApiException catch (e) {
      _errorMessage = e.message;
      notifyListeners();
      return null;
    } catch (e) {
      _errorMessage = 'Network connection error: $e';
      notifyListeners();
      return null;
    }
  }

  Future<bool> activateTariff(String homeId, String tariffId) async {
    try {
      final effectiveHomeId = await _resolveHomeId(homeId);
      final res = await _apiPut(
        '/api/v1/energy/homes/$effectiveHomeId/tariffs/$tariffId',
        body: {'isActive': true},
      );
      if (res != null) {
        _tariffs = _tariffs.map((t) => t.copyWith(isActive: t.id == tariffId)).toList();
        _costSummary = null;
        _forecast = null;
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteTariff(String homeId, String tariffId) async {
    try {
      final effectiveHomeId = await _resolveHomeId(homeId);
      await _apiDelete('/api/v1/energy/homes/$effectiveHomeId/tariffs/$tariffId');
      _tariffs = _tariffs.where((t) => t.id != tariffId).toList();
      _costSummary = null;
      _forecast = null;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  // ---------------------------------------------------------------------------
  // 2. Authoritative Cost Calculations & Forecasting
  // ---------------------------------------------------------------------------

  Future<EnergyCostSummaryModel?> fetchCostSummary(
    String homeId, {
    String entityType = 'home',
    String? entityId,
    String period = 'today',
  }) async {
    try {
      final effectiveHomeId = await _resolveHomeId(homeId);
      var path = '/api/v1/energy/homes/$effectiveHomeId/cost?entityType=$entityType&period=$period';
      if (entityId != null) path += '&entityId=$entityId';
      final res = await _apiGet(path);
      if (res is Map<String, dynamic>) {
        _costSummary = EnergyCostSummaryModel.fromJson(res);
        notifyListeners();
        return _costSummary;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<CostForecastModel?> fetchCostForecast(
    String homeId, {
    String period = 'monthly',
  }) async {
    try {
      final effectiveHomeId = await _resolveHomeId(homeId);
      final res = await _apiGet('/api/v1/energy/homes/$effectiveHomeId/cost/forecast?period=$period');
      if (res is Map<String, dynamic>) {
        _forecast = CostForecastModel.fromJson(res);
        notifyListeners();
        return _forecast;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  // ---------------------------------------------------------------------------
  // 3. Energy Budget Management
  // ---------------------------------------------------------------------------

  Future<BudgetStatusModel?> fetchBudgetStatus(
    String homeId, {
    String periodType = 'monthly',
  }) async {
    try {
      final effectiveHomeId = await _resolveHomeId(homeId);
      final res = await _apiGet('/api/v1/energy/homes/$effectiveHomeId/budget?periodType=$periodType');
      if (res is Map<String, dynamic>) {
        _budgetStatus = BudgetStatusModel.fromJson(res);
        notifyListeners();
        return _budgetStatus;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<EnergyBudgetModel?> saveBudget(EnergyBudgetModel budget) async {
    try {
      final effectiveHomeId = await _resolveHomeId(budget.homeId);
      final res = await _apiPost(
        '/api/v1/energy/homes/$effectiveHomeId/budget',
        body: budget.toJson(),
      );
      if (res is Map<String, dynamic>) {
        final saved = EnergyBudgetModel.fromJson(res);
        await fetchBudgetStatus(effectiveHomeId, periodType: budget.periodType.toServerString());
        return saved;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  // ---------------------------------------------------------------------------
  // 4. Cheapest Periods, Carbon Footprint & Optimizations
  // ---------------------------------------------------------------------------

  Future<CheapestPeriodModel?> fetchCheapestPeriods(
    String homeId, {
    int durationHours = 2,
    int withinHours = 24,
  }) async {
    try {
      final effectiveHomeId = await _resolveHomeId(homeId);
      final res = await _apiGet(
        '/api/v1/energy/homes/$effectiveHomeId/optimization/cheapest-periods?durationHours=$durationHours&withinHours=$withinHours',
      );
      if (res is Map<String, dynamic>) {
        _cheapestPeriods = CheapestPeriodModel.fromJson(res);
        notifyListeners();
        return _cheapestPeriods;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<CarbonFootprintModel?> fetchCarbonFootprint(
    String homeId, {
    String period = 'today',
  }) async {
    try {
      final effectiveHomeId = await _resolveHomeId(homeId);
      final res = await _apiGet('/api/v1/energy/homes/$effectiveHomeId/carbon?period=$period');
      if (res is Map<String, dynamic>) {
        _carbonFootprint = CarbonFootprintModel.fromJson(res);
        notifyListeners();
        return _carbonFootprint;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<List<CostOptimizationRecommendationModel>> fetchCostOptimizations(String homeId) async {
    try {
      final effectiveHomeId = await _resolveHomeId(homeId);
      final res = await _apiGet('/api/v1/energy/homes/$effectiveHomeId/optimization/cost');
      List<dynamic> rawList = [];
      if (res is List) {
        rawList = res;
      } else if (res is Map && res['recommendations'] is List) {
        rawList = res['recommendations'] as List;
      }
      final list = rawList
          .map((o) => CostOptimizationRecommendationModel.fromJson(Map<String, dynamic>.from(o as Map)))
          .toList();
      _optimizations = list;
      notifyListeners();
      return list;
    } catch (_) {
      return _optimizations;
    }
  }

  Future<bool> dismissCostOptimization(String homeId, String optimizationId) async {
    try {
      await _apiPost('/api/v1/energy/optimization/cost/$optimizationId/dismiss');
      _optimizations = _optimizations.where((o) => o.id != optimizationId).toList();
      notifyListeners();
      return true;
    } catch (_) {
      return false;
    }
  }
}
