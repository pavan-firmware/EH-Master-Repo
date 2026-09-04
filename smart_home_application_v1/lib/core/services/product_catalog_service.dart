import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/product_catalog_models.dart';

/// Phase 27 — Consumer Product Discovery, Catalog, Compatibility & Device Add Service
class ProductCatalogClientService extends ChangeNotifier {
  final String baseUrl;
  final http.Client _client;
  String? _authToken;

  ProductCatalogClientService({
    required this.baseUrl,
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

  ProductDiscoveryResponse? _discoveryResponse;
  ProductDiscoveryResponse? get discoveryResponse => _discoveryResponse;

  List<ProductCategoryModel> _categories = [];
  List<ProductCategoryModel> get categories => _categories;

  List<ProductFamilyModel> _families = [];
  List<ProductFamilyModel> get families => _families;

  ProductSearchResult? _lastSearchResult;
  ProductSearchResult? get lastSearchResult => _lastSearchResult;

  ProductCompatibilityResult? _lastCompatibilityResult;
  ProductCompatibilityResult? get lastCompatibilityResult => _lastCompatibilityResult;

  DeviceAddSessionModel? _activeSession;
  DeviceAddSessionModel? get activeSession => _activeSession;

  // ─── 1. Load Discovery Catalog ──────────────────────────────────────────

  Future<ProductDiscoveryResponse?> loadDiscovery({
    String? category,
    String? family,
    String? capability,
    String? connectivity,
    int page = 1,
    int limit = 20,
    String sort = 'name_asc',
    bool includeAll = false,
  }) async {
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      final queryParams = <String, String>{
        'page': page.toString(),
        'limit': limit.toString(),
        'sort': sort,
        if (category != null && category.isNotEmpty) 'category': category,
        if (family != null && family.isNotEmpty) 'family': family,
        if (capability != null && capability.isNotEmpty) 'capability': capability,
        if (connectivity != null && connectivity.isNotEmpty) 'connectivity': connectivity,
        if (includeAll) 'includeAll': 'true',
      };

      final uri = Uri.parse('$baseUrl/api/v1/products/discovery').replace(queryParameters: queryParams);
      final res = await _client.get(uri, headers: _headers);

      if (res.statusCode == 200) {
        final body = jsonDecode(res.body) as Map<String, dynamic>;
        final data = body['data'] is Map ? Map<String, dynamic>.from(body['data'] as Map) : body;
        _discoveryResponse = ProductDiscoveryResponse.fromJson(data);
        _categories = _discoveryResponse!.categories;
        _families = _discoveryResponse!.families;
        _loading = false;
        notifyListeners();
        return _discoveryResponse;
      } else {
        _error = 'Failed to load catalog: HTTP ${res.statusCode}';
      }
    } catch (e) {
      _error = 'Network error loading catalog: $e';
    }

    _loading = false;
    notifyListeners();
    return null;
  }

  // ─── 2. Search Products ─────────────────────────────────────────────────

  Future<ProductSearchResult?> searchProducts(
    String query, {
    String? category,
    String? family,
    int limit = 20,
  }) async {
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      final queryParams = <String, String>{
        'q': query,
        'limit': limit.toString(),
        if (category != null && category.isNotEmpty) 'category': category,
        if (family != null && family.isNotEmpty) 'family': family,
      };

      final uri = Uri.parse('$baseUrl/api/v1/products/search').replace(queryParameters: queryParams);
      final res = await _client.get(uri, headers: _headers);

      if (res.statusCode == 200) {
        final body = jsonDecode(res.body) as Map<String, dynamic>;
        final data = body['data'] is Map ? Map<String, dynamic>.from(body['data'] as Map) : body;
        _lastSearchResult = ProductSearchResult.fromJson(data);
        _loading = false;
        notifyListeners();
        return _lastSearchResult;
      } else {
        _error = 'Failed to search products: HTTP ${res.statusCode}';
      }
    } catch (e) {
      _error = 'Network error searching products: $e';
    }

    _loading = false;
    notifyListeners();
    return null;
  }

  // ─── 3. Categories & Families ───────────────────────────────────────────

  Future<List<ProductCategoryModel>> loadCategories() async {
    try {
      final res = await _client.get(Uri.parse('$baseUrl/api/v1/products/categories'), headers: _headers);
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body) as Map<String, dynamic>;
        final raw = body['data'] as List<dynamic>? ?? [];
        _categories = raw.whereType<Map>().map((e) => ProductCategoryModel.fromJson(Map<String, dynamic>.from(e))).toList();
        notifyListeners();
        return _categories;
      }
    } catch (_) {}
    return _categories;
  }

  Future<List<ProductFamilyModel>> loadFamilies() async {
    try {
      final res = await _client.get(Uri.parse('$baseUrl/api/v1/products/families'), headers: _headers);
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body) as Map<String, dynamic>;
        final raw = body['data'] as List<dynamic>? ?? [];
        _families = raw.whereType<Map>().map((e) => ProductFamilyModel.fromJson(Map<String, dynamic>.from(e))).toList();
        notifyListeners();
        return _families;
      }
    } catch (_) {}
    return _families;
  }

  // ─── 4. Product Variant Detail ──────────────────────────────────────────

  Future<ProductCatalogEntry?> loadVariantDetail(String variantId) async {
    try {
      final res = await _client.get(Uri.parse('$baseUrl/api/v1/products/variants/$variantId'), headers: _headers);
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body) as Map<String, dynamic>;
        final data = body['data'] is Map ? Map<String, dynamic>.from(body['data'] as Map) : body;
        if (data['catalogEntry'] is Map) {
          return ProductCatalogEntry.fromJson(Map<String, dynamic>.from(data['catalogEntry'] as Map));
        }
        return ProductCatalogEntry.fromJson(data);
      }
    } catch (_) {}
    return null;
  }

  // ─── 5. Check Compatibility ─────────────────────────────────────────────

  Future<ProductCompatibilityResult?> checkCompatibility({
    required String productVariantId,
    String? hardwareRevision,
    String? firmwareVersion,
    Map<String, dynamic>? availableConnectivity,
    List<String>? installedHubProtocols,
  }) async {
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      final payload = <String, dynamic>{
        'productVariantId': productVariantId,
      };
      if (hardwareRevision != null) payload['hardwareRevision'] = hardwareRevision;
      if (firmwareVersion != null) payload['firmwareVersion'] = firmwareVersion;
      if (availableConnectivity != null) payload['availableConnectivity'] = availableConnectivity;
      if (installedHubProtocols != null) payload['installedHubProtocols'] = installedHubProtocols;

      final res = await _client.post(
        Uri.parse('$baseUrl/api/v1/products/compatibility'),
        headers: _headers,
        body: jsonEncode(payload),
      );

      if (res.statusCode == 200) {
        final body = jsonDecode(res.body) as Map<String, dynamic>;
        final data = body['data'] is Map ? Map<String, dynamic>.from(body['data'] as Map) : body;
        _lastCompatibilityResult = ProductCompatibilityResult.fromJson(data);
        _loading = false;
        notifyListeners();
        return _lastCompatibilityResult;
      } else {
        _error = 'Failed compatibility check: HTTP ${res.statusCode}';
      }
    } catch (e) {
      _error = 'Network error checking compatibility: $e';
    }

    _loading = false;
    notifyListeners();
    return null;
  }

  // ─── 6. Device Add Wizard Sessions ──────────────────────────────────────

  Future<DeviceAddSessionModel?> startDeviceAddSession({
    required String homeId,
    required String userId,
    String entryMode = 'MANUAL_CATALOG',
    String? productVariantId,
    String? selectedRoomId,
    String? customDeviceName,
    Map<String, String>? channelLabels,
  }) async {
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      final payload = <String, dynamic>{
        'homeId': homeId,
        'userId': userId,
        'entryMode': entryMode,
      };
      if (productVariantId != null) payload['productVariantId'] = productVariantId;
      if (selectedRoomId != null) payload['selectedRoomId'] = selectedRoomId;
      if (customDeviceName != null) payload['customDeviceName'] = customDeviceName;
      if (channelLabels != null) payload['channelLabels'] = channelLabels;

      final res = await _client.post(
        Uri.parse('$baseUrl/api/v1/device-add/sessions'),
        headers: _headers,
        body: jsonEncode(payload),
      );

      if (res.statusCode == 200 || res.statusCode == 201) {
        final body = jsonDecode(res.body) as Map<String, dynamic>;
        final data = body['data'] is Map ? Map<String, dynamic>.from(body['data'] as Map) : body;
        _activeSession = DeviceAddSessionModel.fromJson(data);
        _loading = false;
        notifyListeners();
        return _activeSession;
      } else {
        _error = 'Failed to start add device session: HTTP ${res.statusCode}';
      }
    } catch (e) {
      _error = 'Network error starting device add session: $e';
    }

    _loading = false;
    notifyListeners();
    return null;
  }

  Future<DeviceAddSessionModel?> progressDeviceAddSession(
    String sessionId,
    Map<String, dynamic> updates,
  ) async {
    try {
      final res = await _client.post(
        Uri.parse('$baseUrl/api/v1/device-add/sessions/$sessionId/progress'),
        headers: _headers,
        body: jsonEncode(updates),
      );

      if (res.statusCode == 200) {
        final body = jsonDecode(res.body) as Map<String, dynamic>;
        final data = body['data'] is Map ? Map<String, dynamic>.from(body['data'] as Map) : body;
        _activeSession = DeviceAddSessionModel.fromJson(data);
        notifyListeners();
        return _activeSession;
      }
    } catch (_) {}
    return null;
  }

  Future<bool> completeDeviceAddSession(
    String sessionId,
    Map<String, dynamic> data,
  ) async {
    try {
      final res = await _client.post(
        Uri.parse('$baseUrl/api/v1/device-add/sessions/$sessionId/complete'),
        headers: _headers,
        body: jsonEncode(data),
      );

      if (res.statusCode == 200) {
        final body = jsonDecode(res.body) as Map<String, dynamic>;
        if (body['data']?['session'] is Map) {
          _activeSession = DeviceAddSessionModel.fromJson(Map<String, dynamic>.from(body['data']['session'] as Map));
        }
        notifyListeners();
        return true;
      }
    } catch (_) {}
    return false;
  }

  Future<bool> cancelDeviceAddSession(String sessionId, {String? reason}) async {
    try {
      final res = await _client.post(
        Uri.parse('$baseUrl/api/v1/device-add/sessions/$sessionId/cancel'),
        headers: _headers,
        body: jsonEncode({'reason': reason ?? 'User cancelled onboarding'}),
      );
      if (res.statusCode == 200) {
        _activeSession = null;
        notifyListeners();
        return true;
      }
    } catch (_) {}
    return false;
  }

  Future<DeviceAddSessionModel?> getDeviceAddSession(String sessionId, {String? homeId}) async {
    try {
      final uri = Uri.parse('$baseUrl/api/v1/device-add/sessions/$sessionId')
          .replace(queryParameters: homeId != null ? {'homeId': homeId} : null);
      final res = await _client.get(uri, headers: _headers);
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body) as Map<String, dynamic>;
        final data = body['data'] is Map ? Map<String, dynamic>.from(body['data'] as Map) : body;
        return DeviceAddSessionModel.fromJson(data);
      }
    } catch (_) {}
    return null;
  }
}
