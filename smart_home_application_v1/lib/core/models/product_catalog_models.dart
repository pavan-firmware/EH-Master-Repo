/// Canonical models for Product Discovery, Catalog, Compatibility & Consumer Device Add (Phase 27).
library;

class ProductAssetModel {
  final String hero;
  final String front;
  final String rear;
  final String installed;
  final String packaging;
  final String technicalDiagram;
  final String icon;
  final String thumbnail;

  const ProductAssetModel({
    this.hero = '',
    this.front = '',
    this.rear = '',
    this.installed = '',
    this.packaging = '',
    this.technicalDiagram = '',
    this.icon = '',
    this.thumbnail = '',
  });

  factory ProductAssetModel.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const ProductAssetModel();
    return ProductAssetModel(
      hero: json['hero'] as String? ?? '',
      front: json['front'] as String? ?? '',
      rear: json['rear'] as String? ?? '',
      installed: json['installed'] as String? ?? '',
      packaging: json['packaging'] as String? ?? '',
      technicalDiagram: json['technicalDiagram'] as String? ?? json['technical_diagram'] as String? ?? '',
      icon: json['icon'] as String? ?? '',
      thumbnail: json['thumbnail'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'hero': hero,
    'front': front,
    'rear': rear,
    'installed': installed,
    'packaging': packaging,
    'technicalDiagram': technicalDiagram,
    'icon': icon,
    'thumbnail': thumbnail,
  };
}

class ProductCatalogEntry {
  final String productId;
  final String productFamilyId;
  final String modelId;
  final String variantId;
  final String sku;
  final String marketingName;
  final String technicalName;
  final String description;
  final String productStatus;
  final String visibility;
  final String category;
  final String? subcategory;
  final String brand;
  final ProductAssetModel images;
  final String? icon;
  final int channelCount;
  final List<Map<String, dynamic>> channels;
  final Map<String, dynamic> electricalSpecifications;
  final List<String> capabilities;
  final List<String> controls;
  final List<String> telemetry;
  final List<String> automationCapabilities;
  final List<String> connectivityCapabilities;
  final List<String> commissioningCapabilities;
  final Map<String, dynamic> otaCapabilities;
  final List<String> supportedHardwareRevisions;
  final List<String> supportedFirmwareVersions;
  final bool matterSupport;
  final bool threadSupport;
  final bool wifiSupport;
  final bool bleProvisioningSupport;
  final bool energyMonitoringSupport;
  final bool localControlSupport;

  const ProductCatalogEntry({
    required this.productId,
    required this.productFamilyId,
    required this.modelId,
    required this.variantId,
    required this.sku,
    required this.marketingName,
    required this.technicalName,
    required this.description,
    this.productStatus = 'ACTIVE',
    this.visibility = 'PUBLIC',
    required this.category,
    this.subcategory,
    this.brand = 'EH',
    this.images = const ProductAssetModel(),
    this.icon,
    this.channelCount = 1,
    this.channels = const [],
    this.electricalSpecifications = const {},
    this.capabilities = const [],
    this.controls = const [],
    this.telemetry = const [],
    this.automationCapabilities = const [],
    this.connectivityCapabilities = const [],
    this.commissioningCapabilities = const [],
    this.otaCapabilities = const {},
    this.supportedHardwareRevisions = const [],
    this.supportedFirmwareVersions = const [],
    this.matterSupport = false,
    this.threadSupport = false,
    this.wifiSupport = true,
    this.bleProvisioningSupport = true,
    this.energyMonitoringSupport = false,
    this.localControlSupport = true,
  });

  factory ProductCatalogEntry.fromJson(Map<String, dynamic> json) {
    return ProductCatalogEntry(
      productId: json['productId'] as String? ?? json['product_id'] as String? ?? '',
      productFamilyId: json['productFamilyId'] as String? ?? json['product_family_id'] as String? ?? '',
      modelId: json['modelId'] as String? ?? json['model_id'] as String? ?? '',
      variantId: json['variantId'] as String? ?? json['variant_id'] as String? ?? json['productVariantId'] as String? ?? '',
      sku: json['sku'] as String? ?? '',
      marketingName: json['marketingName'] as String? ?? json['display_name'] as String? ?? json['displayName'] as String? ?? '',
      technicalName: json['technicalName'] as String? ?? json['technical_name'] as String? ?? '',
      description: json['description'] as String? ?? '',
      productStatus: json['productStatus'] as String? ?? json['product_status'] as String? ?? 'ACTIVE',
      visibility: json['visibility'] as String? ?? 'PUBLIC',
      category: json['category'] as String? ?? 'switches',
      subcategory: json['subcategory'] as String?,
      brand: json['brand'] as String? ?? 'EH',
      images: json['images'] is Map<String, dynamic>
          ? ProductAssetModel.fromJson(json['images'] as Map<String, dynamic>)
          : const ProductAssetModel(),
      icon: json['icon'] as String?,
      channelCount: (json['channelCount'] as num? ?? json['channel_count'] as num? ?? 1).toInt(),
      channels: (json['channels'] as List<dynamic>?)
              ?.map((e) => Map<String, dynamic>.from(e as Map))
              .toList() ??
          const [],
      electricalSpecifications: json['electricalSpecifications'] is Map
          ? Map<String, dynamic>.from(json['electricalSpecifications'] as Map)
          : json['electrical_specifications'] is Map
              ? Map<String, dynamic>.from(json['electrical_specifications'] as Map)
              : const {},
      capabilities: (json['capabilities'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? const [],
      controls: (json['controls'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? const [],
      telemetry: (json['telemetry'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? const [],
      automationCapabilities: (json['automationCapabilities'] as List<dynamic>?)?.map((e) => e.toString()).toList() ??
          (json['automation_capabilities'] as List<dynamic>?)?.map((e) => e.toString()).toList() ??
          const [],
      connectivityCapabilities: (json['connectivityCapabilities'] as List<dynamic>?)?.map((e) => e.toString()).toList() ??
          (json['connectivity_capabilities'] as List<dynamic>?)?.map((e) => e.toString()).toList() ??
          const [],
      commissioningCapabilities: (json['commissioningCapabilities'] as List<dynamic>?)?.map((e) => e.toString()).toList() ??
          (json['commissioning_capabilities'] as List<dynamic>?)?.map((e) => e.toString()).toList() ??
          const [],
      otaCapabilities: json['otaCapabilities'] is Map
          ? Map<String, dynamic>.from(json['otaCapabilities'] as Map)
          : json['ota_capabilities'] is Map
              ? Map<String, dynamic>.from(json['ota_capabilities'] as Map)
              : const {},
      supportedHardwareRevisions: (json['supportedHardwareRevisions'] as List<dynamic>?)?.map((e) => e.toString()).toList() ??
          (json['supported_hardware_revisions'] as List<dynamic>?)?.map((e) => e.toString()).toList() ??
          const [],
      supportedFirmwareVersions: (json['supportedFirmwareVersions'] as List<dynamic>?)?.map((e) => e.toString()).toList() ??
          (json['supported_firmware_versions'] as List<dynamic>?)?.map((e) => e.toString()).toList() ??
          const [],
      matterSupport: json['matterSupport'] as bool? ?? json['matter_support'] as bool? ?? false,
      threadSupport: json['threadSupport'] as bool? ?? json['thread_support'] as bool? ?? false,
      wifiSupport: json['wifiSupport'] as bool? ?? json['wifi_support'] as bool? ?? true,
      bleProvisioningSupport: json['bleProvisioningSupport'] as bool? ?? json['ble_provisioning_support'] as bool? ?? true,
      energyMonitoringSupport: json['energyMonitoringSupport'] as bool? ?? json['energy_monitoring_support'] as bool? ?? false,
      localControlSupport: json['localControlSupport'] as bool? ?? json['local_control_support'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
    'productId': productId,
    'productFamilyId': productFamilyId,
    'modelId': modelId,
    'variantId': variantId,
    'sku': sku,
    'marketingName': marketingName,
    'technicalName': technicalName,
    'description': description,
    'productStatus': productStatus,
    'visibility': visibility,
    'category': category,
    'subcategory': subcategory,
    'brand': brand,
    'images': images.toJson(),
    'icon': icon,
    'channelCount': channelCount,
    'channels': channels,
    'electricalSpecifications': electricalSpecifications,
    'capabilities': capabilities,
    'controls': controls,
    'telemetry': telemetry,
    'automationCapabilities': automationCapabilities,
    'connectivityCapabilities': connectivityCapabilities,
    'commissioningCapabilities': commissioningCapabilities,
    'otaCapabilities': otaCapabilities,
    'supportedHardwareRevisions': supportedHardwareRevisions,
    'supportedFirmwareVersions': supportedFirmwareVersions,
    'matterSupport': matterSupport,
    'threadSupport': threadSupport,
    'wifiSupport': wifiSupport,
    'bleProvisioningSupport': bleProvisioningSupport,
    'energyMonitoringSupport': energyMonitoringSupport,
    'localControlSupport': localControlSupport,
  };
}

class ProductCategoryModel {
  final String id;
  final String displayName;
  final int count;
  final String icon;

  const ProductCategoryModel({
    required this.id,
    required this.displayName,
    this.count = 0,
    this.icon = 'device_hub_rounded',
  });

  factory ProductCategoryModel.fromJson(Map<String, dynamic> json) {
    return ProductCategoryModel(
      id: json['id'] as String? ?? '',
      displayName: json['displayName'] as String? ?? json['display_name'] as String? ?? json['id'] as String? ?? '',
      count: (json['count'] as num? ?? 0).toInt(),
      icon: json['icon'] as String? ?? 'device_hub_rounded',
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'displayName': displayName,
    'count': count,
    'icon': icon,
  };
}

class ProductFamilyModel {
  final String id;
  final String displayName;
  final String category;
  final int count;

  const ProductFamilyModel({
    required this.id,
    required this.displayName,
    required this.category,
    this.count = 0,
  });

  factory ProductFamilyModel.fromJson(Map<String, dynamic> json) {
    return ProductFamilyModel(
      id: json['id'] as String? ?? '',
      displayName: json['displayName'] as String? ?? json['display_name'] as String? ?? json['id'] as String? ?? '',
      category: json['category'] as String? ?? 'switches',
      count: (json['count'] as num? ?? 0).toInt(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'displayName': displayName,
    'category': category,
    'count': count,
  };
}

class ProductDiscoveryResponse {
  final List<ProductCatalogEntry> products;
  final int total;
  final int page;
  final int limit;
  final int totalPages;
  final List<ProductCategoryModel> categories;
  final List<ProductFamilyModel> families;
  final List<String> availableCapabilities;

  const ProductDiscoveryResponse({
    this.products = const [],
    this.total = 0,
    this.page = 1,
    this.limit = 20,
    this.totalPages = 0,
    this.categories = const [],
    this.families = const [],
    this.availableCapabilities = const [],
  });

  factory ProductDiscoveryResponse.fromJson(Map<String, dynamic> json) {
    final rawList = json['products'] as List<dynamic>? ?? [];
    final products = rawList
        .whereType<Map>()
        .map((e) => ProductCatalogEntry.fromJson(Map<String, dynamic>.from(e)))
        .toList();

    final rawCats = json['categories'] as List<dynamic>? ?? [];
    final categories = rawCats
        .whereType<Map>()
        .map((e) => ProductCategoryModel.fromJson(Map<String, dynamic>.from(e)))
        .toList();

    final rawFams = json['families'] as List<dynamic>? ?? [];
    final families = rawFams
        .whereType<Map>()
        .map((e) => ProductFamilyModel.fromJson(Map<String, dynamic>.from(e)))
        .toList();

    final rawCaps = json['availableCapabilities'] as List<dynamic>? ??
        json['available_capabilities'] as List<dynamic>? ??
        [];
    final availableCapabilities = rawCaps.map((e) => e.toString()).toList();

    return ProductDiscoveryResponse(
      products: products,
      total: (json['total'] as num? ?? products.length).toInt(),
      page: (json['page'] as num? ?? 1).toInt(),
      limit: (json['limit'] as num? ?? 20).toInt(),
      totalPages: (json['totalPages'] as num? ?? json['total_pages'] as num? ?? 1).toInt(),
      categories: categories,
      families: families,
      availableCapabilities: availableCapabilities,
    );
  }
}

class ProductSearchResultItem {
  final ProductCatalogEntry product;
  final List<String> matchedFields;
  final double relevanceScore;

  const ProductSearchResultItem({
    required this.product,
    this.matchedFields = const [],
    this.relevanceScore = 0.0,
  });

  factory ProductSearchResultItem.fromJson(Map<String, dynamic> json) {
    final productJson = json['product'] is Map ? Map<String, dynamic>.from(json['product'] as Map) : <String, dynamic>{};
    return ProductSearchResultItem(
      product: ProductCatalogEntry.fromJson(productJson),
      matchedFields: (json['matchedFields'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? const [],
      relevanceScore: (json['relevanceScore'] as num? ?? 0.0).toDouble(),
    );
  }
}

class ProductSearchResult {
  final String query;
  final List<ProductSearchResultItem> results;
  final int total;

  const ProductSearchResult({
    this.query = '',
    this.results = const [],
    this.total = 0,
  });

  factory ProductSearchResult.fromJson(Map<String, dynamic> json) {
    final rawList = json['results'] as List<dynamic>? ?? [];
    final results = rawList
        .whereType<Map>()
        .map((e) => ProductSearchResultItem.fromJson(Map<String, dynamic>.from(e)))
        .toList();

    return ProductSearchResult(
      query: json['query'] as String? ?? '',
      results: results,
      total: (json['total'] as num? ?? results.length).toInt(),
    );
  }
}

class ProductCompatibilityReason {
  final String code;
  final String message;
  final String severity; // INFO, WARNING, BLOCKING
  final String? remedy;

  const ProductCompatibilityReason({
    required this.code,
    required this.message,
    this.severity = 'INFO',
    this.remedy,
  });

  factory ProductCompatibilityReason.fromJson(Map<String, dynamic> json) {
    return ProductCompatibilityReason(
      code: json['code'] as String? ?? '',
      message: json['message'] as String? ?? '',
      severity: json['severity'] as String? ?? 'INFO',
      remedy: json['remedy'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'code': code,
    'message': message,
    'severity': severity,
    'remedy': remedy,
  };
}

class ProductCompatibilityResult {
  final String status; // COMPATIBLE, PARTIALLY_COMPATIBLE, INCOMPATIBLE
  final bool isCompatible;
  final List<ProductCompatibilityReason> reasons;
  final List<String> supportedTransports;
  final String recommendedCommissioningTransport;
  final List<String> unsupportedFeatures;
  final String evaluatedAt;

  const ProductCompatibilityResult({
    this.status = 'COMPATIBLE',
    this.isCompatible = true,
    this.reasons = const [],
    this.supportedTransports = const [],
    this.recommendedCommissioningTransport = 'BLE',
    this.unsupportedFeatures = const [],
    required this.evaluatedAt,
  });

  factory ProductCompatibilityResult.fromJson(Map<String, dynamic> json) {
    final rawReasons = json['reasons'] as List<dynamic>? ?? [];
    final reasons = rawReasons
        .whereType<Map>()
        .map((e) => ProductCompatibilityReason.fromJson(Map<String, dynamic>.from(e)))
        .toList();

    return ProductCompatibilityResult(
      status: json['status'] as String? ?? 'COMPATIBLE',
      isCompatible: json['isCompatible'] as bool? ?? json['is_compatible'] as bool? ?? true,
      reasons: reasons,
      supportedTransports: (json['supportedTransports'] as List<dynamic>?)?.map((e) => e.toString()).toList() ??
          (json['supported_transports'] as List<dynamic>?)?.map((e) => e.toString()).toList() ??
          const [],
      recommendedCommissioningTransport: json['recommendedCommissioningTransport'] as String? ??
          json['recommended_commissioning_transport'] as String? ??
          'BLE',
      unsupportedFeatures: (json['unsupportedFeatures'] as List<dynamic>?)?.map((e) => e.toString()).toList() ??
          (json['unsupported_features'] as List<dynamic>?)?.map((e) => e.toString()).toList() ??
          const [],
      evaluatedAt: json['evaluatedAt'] as String? ?? json['evaluated_at'] as String? ?? DateTime.now().toIso8601String(),
    );
  }
}

class DeviceAddSessionModel {
  final String sessionId;
  final String homeId;
  final String userId;
  final String entryMode;
  final String stage;
  final String? productVariantId;
  final String? deviceId;
  final String? commissioningSessionId;
  final String? selectedRoomId;
  final String? customDeviceName;
  final Map<String, String> channelLabels;
  final String? compatibilityStatus;
  final String? errorMessage;
  final String createdAt;
  final String updatedAt;
  final String? completedAt;

  const DeviceAddSessionModel({
    required this.sessionId,
    required this.homeId,
    required this.userId,
    this.entryMode = 'MANUAL_CATALOG',
    this.stage = 'PRODUCT_SELECTED',
    this.productVariantId,
    this.deviceId,
    this.commissioningSessionId,
    this.selectedRoomId,
    this.customDeviceName,
    this.channelLabels = const {},
    this.compatibilityStatus,
    this.errorMessage,
    required this.createdAt,
    required this.updatedAt,
    this.completedAt,
  });

  factory DeviceAddSessionModel.fromJson(Map<String, dynamic> json) {
    Map<String, String> labels = {};
    if (json['channelLabels'] is Map) {
      labels = Map<String, String>.from((json['channelLabels'] as Map).map((k, v) => MapEntry(k.toString(), v.toString())));
    } else if (json['channel_labels'] is Map) {
      labels = Map<String, String>.from((json['channel_labels'] as Map).map((k, v) => MapEntry(k.toString(), v.toString())));
    }

    return DeviceAddSessionModel(
      sessionId: json['sessionId'] as String? ?? json['session_id'] as String? ?? json['id'] as String? ?? '',
      homeId: json['homeId'] as String? ?? json['home_id'] as String? ?? '',
      userId: json['userId'] as String? ?? json['user_id'] as String? ?? '',
      entryMode: json['entryMode'] as String? ?? json['entry_mode'] as String? ?? 'MANUAL_CATALOG',
      stage: json['stage'] as String? ?? 'PRODUCT_SELECTED',
      productVariantId: json['productVariantId'] as String? ?? json['product_variant_id'] as String?,
      deviceId: json['deviceId'] as String? ?? json['device_id'] as String?,
      commissioningSessionId: json['commissioningSessionId'] as String? ?? json['commissioning_session_id'] as String?,
      selectedRoomId: json['selectedRoomId'] as String? ?? json['selected_room_id'] as String?,
      customDeviceName: json['customDeviceName'] as String? ?? json['custom_device_name'] as String?,
      channelLabels: labels,
      compatibilityStatus: json['compatibilityStatus'] as String? ?? json['compatibility_status'] as String?,
      errorMessage: json['errorMessage'] as String? ?? json['error_message'] as String?,
      createdAt: json['createdAt'] as String? ?? json['created_at'] as String? ?? DateTime.now().toIso8601String(),
      updatedAt: json['updatedAt'] as String? ?? json['updated_at'] as String? ?? DateTime.now().toIso8601String(),
      completedAt: json['completedAt'] as String? ?? json['completed_at'] as String?,
    );
  }
}
