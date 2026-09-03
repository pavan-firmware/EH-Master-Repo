import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/energy_cost_models.dart';

/// Client Service for Electricity Tariffs, Cost Analytics, Budgets & Optimizations
class EnergyCostService extends ChangeNotifier {
  final String baseUrl;
  final http.Client _client;
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
    this.baseUrl = 'http://localhost:3000',
    http.Client? client,
    this.authToken,
  }) : _client = client ?? http.Client();

  List<ElectricityTariffModel> get tariffs => _tariffs;
  EnergyCostSummaryModel? get costSummary => _costSummary;
  CostForecastModel? get forecast => _forecast;
  BudgetStatusModel? get budgetStatus => _budgetStatus;
  CheapestPeriodModel? get cheapestPeriods => _cheapestPeriods;
  CarbonFootprintModel? get carbonFootprint => _carbonFootprint;
  List<CostOptimizationRecommendationModel> get optimizations => _optimizations;
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
  // 1. Electricity Tariffs Management
  // ---------------------------------------------------------------------------

  Future<List<ElectricityTariffModel>> fetchTariffs(String homeId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final uri = Uri.parse('$baseUrl/api/v1/energy/homes/$homeId/tariffs');
      final response = await _client.get(uri, headers: _headers);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final list = (data['data'] as List<dynamic>? ?? [])
            .map((t) => ElectricityTariffModel.fromJson(t as Map<String, dynamic>))
            .toList();
        _tariffs = list;
        _isLoading = false;
        notifyListeners();
        return list;
      } else {
        throw Exception('Failed to load tariffs: ${response.statusCode}');
      }
    } catch (e) {
      _isLoading = false;
      _errorMessage = e.toString();
      notifyListeners();
      return _tariffs;
    }
  }

  Future<ElectricityTariffModel?> createTariff(ElectricityTariffModel tariff) async {
    try {
      final uri = Uri.parse('$baseUrl/api/v1/energy/homes/${tariff.homeId}/tariffs');
      final response = await _client.post(
        uri,
        headers: _headers,
        body: json.encode(tariff.toJson()),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        final data = json.decode(response.body);
        final created = ElectricityTariffModel.fromJson(data['data'] as Map<String, dynamic>);
        _tariffs = [created, ..._tariffs.where((t) => t.id != created.id)];
        notifyListeners();
        return created;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<ElectricityTariffModel?> updateTariff(ElectricityTariffModel tariff) async {
    try {
      final uri = Uri.parse('$baseUrl/api/v1/energy/homes/${tariff.homeId}/tariffs/${tariff.id}');
      final response = await _client.put(
        uri,
        headers: _headers,
        body: json.encode(tariff.toJson()),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final updated = ElectricityTariffModel.fromJson(data['data'] as Map<String, dynamic>);
        _tariffs = _tariffs.map((t) => t.id == updated.id ? updated : t).toList();
        notifyListeners();
        return updated;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<bool> deleteTariff(String homeId, String tariffId) async {
    try {
      final uri = Uri.parse('$baseUrl/api/v1/energy/homes/$homeId/tariffs/$tariffId');
      final response = await _client.delete(uri, headers: _headers);

      if (response.statusCode == 200) {
        _tariffs = _tariffs.where((t) => t.id != tariffId).toList();
        notifyListeners();
        return true;
      }
      return false;
    } catch (_) {
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
      final queryParams = <String, String>{
        'entityType': entityType,
        'period': period,
      };
      if (entityId != null) {
        queryParams['entityId'] = entityId;
      }
      final uri = Uri.parse('$baseUrl/api/v1/energy/homes/$homeId/cost')
          .replace(queryParameters: queryParams);
      final response = await _client.get(uri, headers: _headers);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        _costSummary = EnergyCostSummaryModel.fromJson(data['data'] as Map<String, dynamic>);
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
      final uri = Uri.parse('$baseUrl/api/v1/energy/homes/$homeId/cost/forecast')
          .replace(queryParameters: {'period': period});
      final response = await _client.get(uri, headers: _headers);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        _forecast = CostForecastModel.fromJson(data['data'] as Map<String, dynamic>);
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
      final uri = Uri.parse('$baseUrl/api/v1/energy/homes/$homeId/budget')
          .replace(queryParameters: {'periodType': periodType});
      final response = await _client.get(uri, headers: _headers);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        _budgetStatus = BudgetStatusModel.fromJson(data['data'] as Map<String, dynamic>);
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
      final uri = Uri.parse('$baseUrl/api/v1/energy/homes/${budget.homeId}/budget');
      final response = await _client.post(
        uri,
        headers: _headers,
        body: json.encode(budget.toJson()),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = json.decode(response.body);
        final saved = EnergyBudgetModel.fromJson(data['data'] as Map<String, dynamic>);
        await fetchBudgetStatus(budget.homeId, periodType: budget.periodType.toServerString());
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
      final uri = Uri.parse('$baseUrl/api/v1/energy/homes/$homeId/optimization/cheapest-periods')
          .replace(queryParameters: {
        'durationHours': durationHours.toString(),
        'withinHours': withinHours.toString(),
      });
      final response = await _client.get(uri, headers: _headers);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        _cheapestPeriods = CheapestPeriodModel.fromJson(data['data'] as Map<String, dynamic>);
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
      final uri = Uri.parse('$baseUrl/api/v1/energy/homes/$homeId/carbon')
          .replace(queryParameters: {'period': period});
      final response = await _client.get(uri, headers: _headers);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        _carbonFootprint = CarbonFootprintModel.fromJson(data['data'] as Map<String, dynamic>);
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
      final uri = Uri.parse('$baseUrl/api/v1/energy/homes/$homeId/optimization/cost');
      final response = await _client.get(uri, headers: _headers);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final raw = data['data'];
        List<dynamic> rawList = [];
        if (raw is List) {
          rawList = raw;
        } else if (raw is Map && raw['recommendations'] is List) {
          rawList = raw['recommendations'] as List<dynamic>;
        }
        final list = rawList
            .map((o) => CostOptimizationRecommendationModel.fromJson(o as Map<String, dynamic>))
            .toList();
        _optimizations = list;
        notifyListeners();
        return list;
      }
      return _optimizations;
    } catch (_) {
      return _optimizations;
    }
  }

  Future<bool> dismissCostOptimization(String homeId, String optimizationId) async {
    try {
      final uri = Uri.parse('$baseUrl/api/v1/energy/optimization/cost/$optimizationId/dismiss');
      final response = await _client.post(uri, headers: _headers);

      if (response.statusCode == 200) {
        _optimizations = _optimizations.where((o) => o.id != optimizationId).toList();
        notifyListeners();
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }
}
