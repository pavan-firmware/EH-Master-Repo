import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/energy_predictive_models.dart';

/// Client Service for Energy Forecasting, Baselines, Anomalies, Efficiency & Predictive Optimization
class EnergyPredictiveService extends ChangeNotifier {
  final String baseUrl;
  final http.Client _client;
  String? authToken;

  EnergyForecast? _currentForecast;
  EnergyBaseline? _homeBaseline;
  EnergyBaseline? _deviceBaseline;
  List<EnergyAnomaly> _anomalies = [];
  EnergyEfficiencyScore? _efficiencyScore;
  List<PredictiveOptimizationRecommendation> _recommendations = [];
  ForecastAccuracy? _forecastAccuracy;

  bool _isLoading = false;
  String? _errorMessage;

  EnergyPredictiveService({
    this.baseUrl = 'http://localhost:3000',
    http.Client? client,
    this.authToken,
  }) : _client = client ?? http.Client();

  EnergyForecast? get currentForecast => _currentForecast;
  EnergyBaseline? get homeBaseline => _homeBaseline;
  EnergyBaseline? get deviceBaseline => _deviceBaseline;
  List<EnergyAnomaly> get anomalies => _anomalies;
  EnergyEfficiencyScore? get efficiencyScore => _efficiencyScore;
  List<PredictiveOptimizationRecommendation> get recommendations => _recommendations;
  ForecastAccuracy? get forecastAccuracy => _forecastAccuracy;

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
  // 1. Forecast Operations
  // ---------------------------------------------------------------------------

  Future<EnergyForecast?> fetchForecast(
    String homeId, {
    ForecastHorizon horizon = ForecastHorizon.next24Hours,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final uri = Uri.parse('$baseUrl/api/v1/energy/homes/$homeId/forecast?horizon=${horizon.toApiValue()}');
      final response = await _client.get(uri, headers: _headers);

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body) as Map<String, dynamic>;
        if (decoded['success'] == true && decoded['data'] != null) {
          _currentForecast = EnergyForecast.fromJson(decoded['data'] as Map<String, dynamic>);
          return _currentForecast;
        }
      }
      _errorMessage = 'Failed to load forecast (Status ${response.statusCode})';
      return null;
    } catch (e) {
      _errorMessage = 'Network error fetching forecast: $e';
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ---------------------------------------------------------------------------
  // 2. Baseline Operations
  // ---------------------------------------------------------------------------

  Future<EnergyBaseline?> fetchHomeBaseline(String homeId) async {
    try {
      final uri = Uri.parse('$baseUrl/api/v1/energy/homes/$homeId/baseline');
      final response = await _client.get(uri, headers: _headers);

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body) as Map<String, dynamic>;
        if (decoded['success'] == true && decoded['data'] != null) {
          _homeBaseline = EnergyBaseline.fromJson(decoded['data'] as Map<String, dynamic>);
          notifyListeners();
          return _homeBaseline;
        }
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<EnergyBaseline?> fetchDeviceBaseline(String deviceId) async {
    try {
      final uri = Uri.parse('$baseUrl/api/v1/energy/devices/$deviceId/baseline');
      final response = await _client.get(uri, headers: _headers);

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body) as Map<String, dynamic>;
        if (decoded['success'] == true && decoded['data'] != null) {
          _deviceBaseline = EnergyBaseline.fromJson(decoded['data'] as Map<String, dynamic>);
          notifyListeners();
          return _deviceBaseline;
        }
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  // ---------------------------------------------------------------------------
  // 3. Anomaly Operations
  // ---------------------------------------------------------------------------

  Future<List<EnergyAnomaly>> fetchAnomalies(String homeId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final uri = Uri.parse('$baseUrl/api/v1/energy/homes/$homeId/anomalies');
      final response = await _client.get(uri, headers: _headers);

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body) as Map<String, dynamic>;
        if (decoded['success'] == true && decoded['data'] != null) {
          final list = (decoded['data'] as List<dynamic>)
              .map((a) => EnergyAnomaly.fromJson(a as Map<String, dynamic>))
              .toList();
          _anomalies = list;
          return _anomalies;
        }
      }
      return [];
    } catch (e) {
      _errorMessage = 'Failed to fetch anomalies: $e';
      return [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ---------------------------------------------------------------------------
  // 4. Energy Efficiency Score
  // ---------------------------------------------------------------------------

  Future<EnergyEfficiencyScore?> fetchEfficiencyScore(String homeId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final uri = Uri.parse('$baseUrl/api/v1/energy/homes/$homeId/efficiency-score');
      final response = await _client.get(uri, headers: _headers);

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body) as Map<String, dynamic>;
        if (decoded['success'] == true && decoded['data'] != null) {
          _efficiencyScore = EnergyEfficiencyScore.fromJson(decoded['data'] as Map<String, dynamic>);
          return _efficiencyScore;
        }
      }
      return null;
    } catch (e) {
      _errorMessage = 'Failed to fetch efficiency score: $e';
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ---------------------------------------------------------------------------
  // 5. Predictive Optimizations
  // ---------------------------------------------------------------------------

  Future<List<PredictiveOptimizationRecommendation>> fetchPredictiveOptimizations(String homeId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final uri = Uri.parse('$baseUrl/api/v1/energy/homes/$homeId/predictive-optimization');
      final response = await _client.get(uri, headers: _headers);

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body) as Map<String, dynamic>;
        if (decoded['success'] == true && decoded['data'] != null) {
          final list = (decoded['data'] as List<dynamic>)
              .map((r) => PredictiveOptimizationRecommendation.fromJson(r as Map<String, dynamic>))
              .toList();
          _recommendations = list;
          return _recommendations;
        }
      }
      return [];
    } catch (e) {
      _errorMessage = 'Failed to fetch predictive optimizations: $e';
      return [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ---------------------------------------------------------------------------
  // 6. Forecast Accuracy
  // ---------------------------------------------------------------------------

  Future<ForecastAccuracy?> fetchForecastAccuracy(String homeId, {String horizon = 'next_24_hours'}) async {
    try {
      final uri = Uri.parse('$baseUrl/api/v1/energy/homes/$homeId/forecast/accuracy?horizon=$horizon');
      final response = await _client.get(uri, headers: _headers);

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body) as Map<String, dynamic>;
        if (decoded['success'] == true && decoded['data'] != null) {
          _forecastAccuracy = ForecastAccuracy.fromJson(decoded['data'] as Map<String, dynamic>);
          notifyListeners();
          return _forecastAccuracy;
        }
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<void> refreshAll(String homeId) async {
    await Future.wait([
      fetchForecast(homeId),
      fetchAnomalies(homeId),
      fetchEfficiencyScore(homeId),
      fetchPredictiveOptimizations(homeId),
      fetchForecastAccuracy(homeId)
    ]);
  }
}
