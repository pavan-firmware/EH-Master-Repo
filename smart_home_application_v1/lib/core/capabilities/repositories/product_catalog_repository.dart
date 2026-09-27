import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/capability_models.dart';

abstract class ProductCatalogRepository {
  static ProductCatalogRepository instance = const MockProductCatalogRepository();

  Future<List<ProductVariantDefinition>> getProductVariants({bool forceRefresh = false});
  Future<ProductVariantDefinition?> getProductVariant(String variantId, {bool forceRefresh = false});
  Future<List<CanonicalCapability>> getCapabilities();
}

/// Dynamic, API-backed Product Catalog Repository with structured persistent caching and offline fallback.
class DynamicProductCatalogRepository implements ProductCatalogRepository {
  final String baseUrl;
  final http.Client _client;
  
  // In-memory cache
  List<ProductVariantDefinition>? _cachedVariants;
  final Map<String, ProductVariantDefinition> _variantMap = {};
  List<CanonicalCapability>? _cachedCapabilities;
  DateTime? _lastFetchTime;
  String? _catalogVersion;

  // Cache duration (e.g. 1 hour default, configurable)
  final Duration cacheDuration;

  DynamicProductCatalogRepository({
    required this.baseUrl,
    http.Client? client,
    this.cacheDuration = const Duration(hours: 1),
  }) : _client = client ?? http.Client();

  bool get isCacheValid {
    if (_cachedVariants == null || _lastFetchTime == null) return false;
    return DateTime.now().difference(_lastFetchTime!) < cacheDuration;
  }

  String? get catalogVersion => _catalogVersion;
  DateTime? get lastFetchTime => _lastFetchTime;

  bool _isServingBootstrapFallback = false;
  bool get isServingBootstrapFallback => _isServingBootstrapFallback;

  void primeCacheForTesting(List<ProductVariantDefinition> list) {
    _cachedVariants = List.from(list);
    _variantMap.clear();
    for (final v in list) {
      _variantMap[v.productVariantId] = v;
    }
    _lastFetchTime = DateTime.now();
    _isServingBootstrapFallback = false;
  }

  void invalidateCache() {
    _cachedVariants = null;
    _variantMap.clear();
    _cachedCapabilities = null;
    _lastFetchTime = null;
    _isServingBootstrapFallback = false;
  }

  /// Hydrate in-memory cache from serialized JSON (e.g. from local storage)
  void hydrateFromCache({
    required String rawJson,
    String? version,
    DateTime? timestamp,
  }) {
    try {
      final decoded = jsonDecode(rawJson);
      if (decoded is List) {
        final list = decoded
            .whereType<Map>()
            .map((e) => ProductVariantDefinition.fromJson(Map<String, dynamic>.from(e)))
            .toList();
        if (list.isNotEmpty) {
          _cachedVariants = list;
          _variantMap.clear();
          for (final v in list) {
            _variantMap[v.productVariantId] = v;
          }
          _catalogVersion = version;
          _lastFetchTime = timestamp ?? DateTime.now();
          _isServingBootstrapFallback = false;
        }
      }
    } catch (_) {}
  }

  /// Export current cache to serialized JSON
  String exportCacheJson() {
    if (_cachedVariants == null) return '[]';
    final list = _cachedVariants!.map((v) => v.toJson()).toList();
    return jsonEncode(list);
  }

  @override
  Future<List<ProductVariantDefinition>> getProductVariants({bool forceRefresh = false}) async {
    if (!forceRefresh && isCacheValid && _cachedVariants != null) {
      _isServingBootstrapFallback = false;
      return _cachedVariants!;
    }

    try {
      final uri = Uri.parse('$baseUrl/api/v1/products');
      final res = await _client.get(uri, headers: {
        'Accept': 'application/json',
      });

      if (res.statusCode == 200) {
        final body = jsonDecode(res.body) as Map<String, dynamic>;
        final rawData = body['data'] as List<dynamic>? ?? [];
        final List<ProductVariantDefinition> parsed = [];

        for (final item in rawData) {
          if (item is Map) {
            final itemMap = Map<String, dynamic>.from(item);
            // Case 1: Item is a product with nested variants array
            if (itemMap['variants'] is List) {
              final variantsList = itemMap['variants'] as List;
              final productMap = itemMap['product'] is Map ? Map<String, dynamic>.from(itemMap['product'] as Map) : <String, dynamic>{};
              final familyMap = itemMap['family'] is Map ? Map<String, dynamic>.from(itemMap['family'] as Map) : <String, dynamic>{};
              final assetsList = itemMap['assets'] is List ? itemMap['assets'] as List : const [];

              for (final v in variantsList) {
                if (v is Map) {
                  final vMap = Map<String, dynamic>.from(v);
                  parsed.add(ProductVariantDefinition.fromJson({
                    'variant': vMap,
                    'product': productMap,
                    'family': familyMap,
                    'assets': assetsList,
                  }));
                }
              }
            } else {
              // Direct variant object
              parsed.add(ProductVariantDefinition.fromJson(itemMap));
            }
          }
        }

        if (parsed.isNotEmpty) {
          _cachedVariants = parsed;
          _variantMap.clear();
          for (final v in parsed) {
            _variantMap[v.productVariantId] = v;
          }
          _lastFetchTime = DateTime.now();
          _catalogVersion = body['meta']?['catalogVersion']?.toString() ?? 'v1';
          _isServingBootstrapFallback = false;
          return parsed;
        }
      }
    } catch (_) {
      // Network failure: fallback to stale cache or bootstrap fallback
    }

    // Fallback 1: Return stale in-memory cache if available
    if (_cachedVariants != null && _cachedVariants!.isNotEmpty) {
      _isServingBootstrapFallback = false;
      return _cachedVariants!;
    }

    // Fallback 2: Offline bootstrap seed (strictly marked as fallback)
    _isServingBootstrapFallback = true;
    return const MockProductCatalogRepository().getProductVariants();
  }

  @override
  Future<ProductVariantDefinition?> getProductVariant(String variantId, {bool forceRefresh = false}) async {
    if (!forceRefresh && _variantMap.containsKey(variantId)) {
      return _variantMap[variantId];
    }

    try {
      final uri = Uri.parse('$baseUrl/api/v1/products/variants/$variantId');
      final res = await _client.get(uri, headers: {
        'Accept': 'application/json',
      });

      if (res.statusCode == 200) {
        final body = jsonDecode(res.body) as Map<String, dynamic>;
        final data = body['data'] is Map ? Map<String, dynamic>.from(body['data'] as Map) : body;
        final variant = ProductVariantDefinition.fromJson(data);
        _variantMap[variantId] = variant;
        return variant;
      }
    } catch (_) {
      // Network failure
    }

    // Fallback 1: in-memory map
    if (_variantMap.containsKey(variantId)) {
      return _variantMap[variantId];
    }

    // Fallback 2: check all variants (e.g. from cache or bootstrap)
    final all = await getProductVariants();
    for (final v in all) {
      if (v.productVariantId == variantId) {
        _variantMap[variantId] = v;
        return v;
      }
    }

    return null;
  }

  @override
  Future<List<CanonicalCapability>> getCapabilities() async {
    if (_cachedCapabilities != null) return _cachedCapabilities!;
    
    _cachedCapabilities = const [
      CanonicalCapability(
        capabilityId: 'switch',
        version: 1,
        displayName: 'Switch',
        description: 'Binary power control',
        uiComponentHint: 'EHSwitchCard',
      ),
      CanonicalCapability(
        capabilityId: 'relay',
        version: 1,
        displayName: 'Relay Control',
        description: 'Physical relay actuator',
        uiComponentHint: 'EHSwitchCard',
      ),
      CanonicalCapability(
        capabilityId: 'fan_speed',
        version: 1,
        displayName: 'Fan Speed Control',
        description: 'Multi-step speed control',
        uiComponentHint: 'EHFanSpeedDial',
      ),
      CanonicalCapability(
        capabilityId: 'brightness',
        version: 1,
        displayName: 'Brightness Dimmer',
        description: 'Continuous dimming level',
        uiComponentHint: 'EHDimmerSlider',
      ),
      CanonicalCapability(
        capabilityId: 'cct',
        version: 1,
        displayName: 'Color Temperature',
        description: 'Tunable white lighting',
        uiComponentHint: 'EHCCTDial',
      ),
      CanonicalCapability(
        capabilityId: 'energy',
        version: 1,
        displayName: 'Energy Monitoring',
        description: 'Fixed-point metering',
        uiComponentHint: 'EHEnergyCard',
      ),
      CanonicalCapability(
        capabilityId: 'voltage',
        version: 1,
        displayName: 'Voltage Sensing',
        description: 'RMS Voltage Telemetry',
        uiComponentHint: 'EHEnergyMetric',
      ),
      CanonicalCapability(
        capabilityId: 'current',
        version: 1,
        displayName: 'Current Sensing',
        description: 'RMS Current Telemetry',
        uiComponentHint: 'EHEnergyMetric',
      ),
      CanonicalCapability(
        capabilityId: 'power',
        version: 1,
        displayName: 'Active Power Metering',
        description: 'Active Real Power in Watts',
        uiComponentHint: 'EHEnergyMetric',
      ),
      CanonicalCapability(
        capabilityId: 'ota',
        version: 1,
        displayName: 'Firmware Updates',
        description: 'Over-the-air firmware updates',
        uiComponentHint: 'EHOTAStatusBadge',
      ),
      CanonicalCapability(
        capabilityId: 'automation',
        version: 1,
        displayName: 'Local Automation',
        description: 'Edge automation target',
        uiComponentHint: 'EHAutomationBadge',
      ),
      CanonicalCapability(
        capabilityId: 'scene',
        version: 1,
        displayName: 'Scene Target',
        description: 'Multi-device scene execution',
        uiComponentHint: 'EHSceneTrigger',
      ),
      CanonicalCapability(
        capabilityId: 'schedule',
        version: 1,
        displayName: 'On-Device Scheduler',
        description: 'Device scheduler',
        uiComponentHint: 'EHScheduleManager',
      ),
    ];
    return _cachedCapabilities!;
  }
}

/// Mock / Bootstrap implementation using canonical seed definitions
class MockProductCatalogRepository implements ProductCatalogRepository {
  const MockProductCatalogRepository();

  static const _smartSwitch3x = ProductVariantDefinition(
    schemaVersion: 1,
    productVariantId: 'eh-smart-switch-3x',
    productFamily: 'smart_switch',
    displayName: 'EH Smart Switch 3X',
    channelCount: 3,
    channels: [
      ProductChannelDefinition(
        channelIndex: 1,
        defaultLabel: 'Channel 1',
        capabilities: ['switch', 'relay', 'local_switch', 'energy', 'ota'],
      ),
      ProductChannelDefinition(
        channelIndex: 2,
        defaultLabel: 'Channel 2',
        capabilities: ['switch', 'relay', 'local_switch', 'energy', 'ota'],
      ),
      ProductChannelDefinition(
        channelIndex: 3,
        defaultLabel: 'Channel 3',
        capabilities: ['switch', 'relay', 'local_switch', 'energy', 'ota'],
      ),
    ],
    capabilities: [
      'switch',
      'relay',
      'local_switch',
      'energy',
      'voltage',
      'current',
      'power',
      'ota',
      'automation',
      'scene',
      'schedule',
    ],
    images: {
      'hero': 'assets/products/smart_switch_3x/hero.png',
      'front': 'assets/products/smart_switch_3x/front.png',
      'thumbnail': 'assets/products/smart_switch_3x/thumb.png',
    },
    firmwareFamily: 'esp32c6-switch-platform',
    supportedHardwareRevisions: ['HW_1_0', 'HW_1_1'],
  );

  static const _smartSocket3x = ProductVariantDefinition(
    schemaVersion: 1,
    productVariantId: 'eh-smart-socket-3x',
    productFamily: 'smart_socket',
    displayName: 'EH Smart Socket 3X',
    channelCount: 3,
    channels: [
      ProductChannelDefinition(
        channelIndex: 1,
        defaultLabel: 'Socket 1',
        capabilities: ['switch', 'relay', 'local_switch', 'energy', 'ota'],
      ),
      ProductChannelDefinition(
        channelIndex: 2,
        defaultLabel: 'Socket 2',
        capabilities: ['switch', 'relay', 'local_switch', 'energy', 'ota'],
      ),
      ProductChannelDefinition(
        channelIndex: 3,
        defaultLabel: 'Socket 3',
        capabilities: ['switch', 'relay', 'local_switch', 'energy', 'ota'],
      ),
    ],
    capabilities: [
      'switch',
      'relay',
      'local_switch',
      'energy',
      'voltage',
      'current',
      'power',
      'ota',
      'automation',
      'scene',
      'schedule',
    ],
    images: {
      'hero': 'assets/products/smart_socket_3x/hero.png',
      'front': 'assets/products/smart_socket_3x/front.png',
      'thumbnail': 'assets/products/smart_socket_3x/thumb.png',
    },
    firmwareFamily: 'esp32c6-socket-platform',
    supportedHardwareRevisions: ['HW_1_0', 'HW_1_1'],
  );

  static const _smartFan1x = ProductVariantDefinition(
    schemaVersion: 1,
    productVariantId: 'eh-smart-fan-1x',
    productFamily: 'smart_fan',
    displayName: 'EH Smart Fan 1X',
    channelCount: 1,
    channels: [
      ProductChannelDefinition(
        channelIndex: 1,
        defaultLabel: 'Ceiling Fan',
        capabilities: ['switch', 'relay', 'fan_speed', 'local_switch', 'energy', 'ota'],
      ),
    ],
    capabilities: [
      'switch',
      'relay',
      'fan_speed',
      'local_switch',
      'energy',
      'voltage',
      'current',
      'power',
      'ota',
      'automation',
      'scene',
      'schedule',
    ],
    images: {
      'hero': 'assets/products/smart_fan_1x/hero.png',
      'front': 'assets/products/smart_fan_1x/front.png',
      'thumbnail': 'assets/products/smart_fan_1x/thumb.png',
    },
    firmwareFamily: 'esp32c6-fan-platform',
    supportedHardwareRevisions: ['HW_1_0', 'HW_1_1'],
  );

  static const _smartLightCct = ProductVariantDefinition(
    schemaVersion: 1,
    productVariantId: 'eh-smart-light-cct',
    productFamily: 'smart_lighting',
    displayName: 'EH Smart Light CCT',
    channelCount: 1,
    channels: [
      ProductChannelDefinition(
        channelIndex: 1,
        defaultLabel: 'Light',
        capabilities: ['switch', 'brightness', 'cct', 'energy', 'ota'],
      ),
    ],
    capabilities: [
      'switch',
      'brightness',
      'cct',
      'energy',
      'voltage',
      'current',
      'power',
      'ota',
      'automation',
      'scene',
      'schedule',
    ],
    images: {
      'hero': 'assets/products/smart_light_cct/hero.png',
      'front': 'assets/products/smart_light_cct/front.png',
      'thumbnail': 'assets/products/smart_light_cct/thumb.png',
    },
    firmwareFamily: 'esp32c6-light-platform',
    supportedHardwareRevisions: ['HW_1_0'],
  );

  static const _smartHubV1 = ProductVariantDefinition(
    schemaVersion: 1,
    productVariantId: 'eh-smart-hub-v1',
    productFamily: 'smart_controller',
    displayName: 'EH Smart Hub Gateway V1',
    channelCount: 1,
    channels: [
      ProductChannelDefinition(
        channelIndex: 1,
        defaultLabel: 'Gateway Controller',
        capabilities: ['switch', 'ota', 'automation', 'schedule'],
      ),
    ],
    capabilities: [
      'switch',
      'ota',
      'automation',
      'schedule',
    ],
    images: {
      'hero': 'assets/products/smart_hub_v1/hero.png',
      'front': 'assets/products/smart_hub_v1/front.png',
      'thumbnail': 'assets/products/smart_hub_v1/thumb.png',
    },
    firmwareFamily: 'esp32s3-hub-platform',
    supportedHardwareRevisions: ['HW_1_0'],
  );

  static const _sensorNodeV1 = ProductVariantDefinition(
    schemaVersion: 1,
    productVariantId: 'eh-sensor-node-v1',
    productFamily: 'smart_sensor',
    displayName: 'EH Environmental Sensor Node V1',
    channelCount: 1,
    channels: [
      ProductChannelDefinition(
        channelIndex: 1,
        defaultLabel: 'Environmental Sensor',
        capabilities: ['switch', 'ota', 'automation'],
      ),
    ],
    capabilities: [
      'switch',
      'ota',
      'automation',
      'schedule',
    ],
    images: {
      'hero': 'assets/products/sensor_node_v1/hero.png',
      'front': 'assets/products/sensor_node_v1/front.png',
      'thumbnail': 'assets/products/sensor_node_v1/thumb.png',
    },
    firmwareFamily: 'esp32c6-sensor-platform',
    supportedHardwareRevisions: ['HW_1_0'],
  );

  static const _smartSwitch1x = ProductVariantDefinition(
    schemaVersion: 1,
    productVariantId: 'eh-smart-switch-1x',
    productFamily: 'smart_switch',
    displayName: 'EH Smart Switch 1X',
    channelCount: 1,
    channels: [
      ProductChannelDefinition(
        channelIndex: 1,
        defaultLabel: 'Channel 1',
        capabilities: ['switch', 'relay', 'local_switch', 'energy', 'ota'],
      ),
    ],
    capabilities: ['switch', 'relay', 'local_switch', 'energy', 'ota', 'automation', 'scene', 'schedule'],
    firmwareFamily: 'esp32c6-switch-platform',
    supportedHardwareRevisions: ['HW_1_0', 'HW_1_1'],
  );

  static const _smartSwitch2x = ProductVariantDefinition(
    schemaVersion: 1,
    productVariantId: 'eh-smart-switch-2x',
    productFamily: 'smart_switch',
    displayName: 'EH Smart Switch 2X',
    channelCount: 2,
    channels: [
      ProductChannelDefinition(
        channelIndex: 1,
        defaultLabel: 'Channel 1',
        capabilities: ['switch', 'relay', 'local_switch', 'energy', 'ota'],
      ),
      ProductChannelDefinition(
        channelIndex: 2,
        defaultLabel: 'Channel 2',
        capabilities: ['switch', 'relay', 'local_switch', 'energy', 'ota'],
      ),
    ],
    capabilities: ['switch', 'relay', 'local_switch', 'energy', 'ota', 'automation', 'scene', 'schedule'],
    firmwareFamily: 'esp32c6-switch-platform',
    supportedHardwareRevisions: ['HW_1_0', 'HW_1_1'],
  );

  static const _smartSwitch4x = ProductVariantDefinition(
    schemaVersion: 1,
    productVariantId: 'eh-smart-switch-4x',
    productFamily: 'smart_switch',
    displayName: 'EH Smart Switch 4X',
    channelCount: 4,
    channels: [
      ProductChannelDefinition(
        channelIndex: 1,
        defaultLabel: 'Channel 1',
        capabilities: ['switch', 'relay', 'local_switch', 'energy', 'ota'],
      ),
      ProductChannelDefinition(
        channelIndex: 2,
        defaultLabel: 'Channel 2',
        capabilities: ['switch', 'relay', 'local_switch', 'energy', 'ota'],
      ),
      ProductChannelDefinition(
        channelIndex: 3,
        defaultLabel: 'Channel 3',
        capabilities: ['switch', 'relay', 'local_switch', 'energy', 'ota'],
      ),
      ProductChannelDefinition(
        channelIndex: 4,
        defaultLabel: 'Channel 4',
        capabilities: ['switch', 'relay', 'local_switch', 'energy', 'ota'],
      ),
    ],
    capabilities: ['switch', 'relay', 'local_switch', 'energy', 'ota', 'automation', 'scene', 'schedule'],
    firmwareFamily: 'esp32c6-switch-platform',
    supportedHardwareRevisions: ['HW_1_0', 'HW_1_1'],
  );

  static const _smartSocket1x = ProductVariantDefinition(
    schemaVersion: 1,
    productVariantId: 'eh-smart-socket-1x',
    productFamily: 'smart_socket',
    displayName: 'EH Smart Socket 1X',
    channelCount: 1,
    channels: [
      ProductChannelDefinition(
        channelIndex: 1,
        defaultLabel: 'Socket 1',
        capabilities: ['switch', 'relay', 'energy', 'ota'],
      ),
    ],
    capabilities: ['switch', 'relay', 'energy', 'voltage', 'current', 'power', 'ota', 'automation'],
    firmwareFamily: 'esp32c6-socket-platform',
    supportedHardwareRevisions: ['HW_1_0', 'HW_1_1'],
  );

  static const _smartSocket2x = ProductVariantDefinition(
    schemaVersion: 1,
    productVariantId: 'eh-smart-socket-2x',
    productFamily: 'smart_socket',
    displayName: 'EH Smart Socket 2X',
    channelCount: 2,
    channels: [
      ProductChannelDefinition(
        channelIndex: 1,
        defaultLabel: 'Socket 1',
        capabilities: ['switch', 'relay', 'energy', 'ota'],
      ),
      ProductChannelDefinition(
        channelIndex: 2,
        defaultLabel: 'Socket 2',
        capabilities: ['switch', 'relay', 'energy', 'ota'],
      ),
    ],
    capabilities: ['switch', 'relay', 'energy', 'voltage', 'current', 'power', 'ota', 'automation'],
    firmwareFamily: 'esp32c6-socket-platform',
    supportedHardwareRevisions: ['HW_1_0', 'HW_1_1'],
  );

  static const _allVariants = [
    _smartSwitch1x,
    _smartSwitch2x,
    _smartSwitch3x,
    _smartSwitch4x,
    _smartSocket1x,
    _smartSocket2x,
    _smartSocket3x,
    _smartFan1x,
    _smartLightCct,
    _smartHubV1,
    _sensorNodeV1,
  ];

  static const List<ProductVariantDefinition> bootstrapVariants = _allVariants;

  @override
  Future<List<ProductVariantDefinition>> getProductVariants({bool forceRefresh = false}) async {
    return _allVariants;
  }

  @override
  Future<ProductVariantDefinition?> getProductVariant(String variantId, {bool forceRefresh = false}) async {
    for (final v in _allVariants) {
      if (v.productVariantId == variantId) return v;
    }
    return null;
  }

  @override
  Future<List<CanonicalCapability>> getCapabilities() async {
    return const [
      CanonicalCapability(
        capabilityId: 'switch',
        version: 1,
        displayName: 'Switch',
        description: 'Binary power control',
        uiComponentHint: 'EHSwitchCard',
      ),
      CanonicalCapability(
        capabilityId: 'fan_speed',
        version: 1,
        displayName: 'Fan Speed Control',
        description: 'Multi-step speed control',
        uiComponentHint: 'EHFanSpeedDial',
      ),
      CanonicalCapability(
        capabilityId: 'brightness',
        version: 1,
        displayName: 'Brightness Dimmer',
        description: 'Continuous dimming level',
        uiComponentHint: 'EHDimmerSlider',
      ),
      CanonicalCapability(
        capabilityId: 'cct',
        version: 1,
        displayName: 'Color Temperature',
        description: 'Tunable white lighting',
        uiComponentHint: 'EHCCTDial',
      ),
      CanonicalCapability(
        capabilityId: 'energy',
        version: 1,
        displayName: 'Energy Monitoring',
        description: 'Fixed-point metering',
        uiComponentHint: 'EHEnergyCard',
      ),
      CanonicalCapability(
        capabilityId: 'ota',
        version: 1,
        displayName: 'Firmware Updates',
        description: 'Over-the-air firmware updates',
        uiComponentHint: 'EHOTAStatusBadge',
      ),
      CanonicalCapability(
        capabilityId: 'automation',
        version: 1,
        displayName: 'Local Automation',
        description: 'Edge automation target',
        uiComponentHint: 'EHAutomationBadge',
      ),
      CanonicalCapability(
        capabilityId: 'schedule',
        version: 1,
        displayName: 'On-Device Scheduler',
        description: 'Device scheduler',
        uiComponentHint: 'EHScheduleManager',
      ),
    ];
  }
}
