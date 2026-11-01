// Canonical capability and product models for the Flutter Capability Engine.
// Strictly maps from canonical contracts and metadata definitions.

enum CapabilityConnectionState { online, stale, offline }

class CanonicalCapability {
  const CanonicalCapability({
    required this.capabilityId,
    required this.version,
    required this.displayName,
    required this.description,
    required this.uiComponentHint,
    this.automationTriggers = const [],
    this.automationActions = const [],
    this.telemetryFields = const [],
  });

  final String capabilityId;
  final int version;
  final String displayName;
  final String description;
  final String uiComponentHint;
  final List<String> automationTriggers;
  final List<String> automationActions;
  final List<String> telemetryFields;

  factory CanonicalCapability.fromJson(Map<String, dynamic> json) {
    return CanonicalCapability(
      capabilityId: json['capabilityId'] as String? ?? json['id'] as String? ?? '',
      version: (json['version'] as num? ?? 1).toInt(),
      displayName: json['displayName'] as String? ?? json['name'] as String? ?? '',
      description: json['description'] as String? ?? '',
      uiComponentHint: json['uiComponentHint'] as String? ?? json['componentHint'] as String? ?? '',
      automationTriggers: (json['automationTriggers'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? const [],
      automationActions: (json['automationActions'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? const [],
      telemetryFields: (json['telemetryFields'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? const [],
    );
  }

  Map<String, dynamic> toJson() => {
    'capabilityId': capabilityId,
    'version': version,
    'displayName': displayName,
    'description': description,
    'uiComponentHint': uiComponentHint,
    'automationTriggers': automationTriggers,
    'automationActions': automationActions,
    'telemetryFields': telemetryFields,
  };
}

class ProductChannelDefinition {
  const ProductChannelDefinition({
    required this.channelIndex,
    required this.defaultLabel,
    required this.capabilities,
    this.capabilityConfigs = const {},
  });

  final int channelIndex;
  final String defaultLabel;
  final List<String> capabilities;
  final Map<String, Map<String, dynamic>> capabilityConfigs;

  factory ProductChannelDefinition.fromJson(Map<String, dynamic> json) {
    final rawCaps = json['capabilities'] as List<dynamic>? ?? [];
    final capabilities = rawCaps.map((e) => e.toString()).toList();

    final configs = <String, Map<String, dynamic>>{};
    if (json['capabilityConfigs'] is Map) {
      (json['capabilityConfigs'] as Map).forEach((k, v) {
        if (v is Map) {
          configs[k.toString()] = Map<String, dynamic>.from(v);
        }
      });
    }

    return ProductChannelDefinition(
      channelIndex: (json['channelIndex'] as num? ?? json['channel_index'] as num? ?? 1).toInt(),
      defaultLabel: json['defaultLabel'] as String? ?? json['default_label'] as String? ?? json['name'] as String? ?? 'Channel ${json['channelIndex'] ?? 1}',
      capabilities: capabilities,
      capabilityConfigs: configs,
    );
  }

  Map<String, dynamic> toJson() => {
    'channelIndex': channelIndex,
    'defaultLabel': defaultLabel,
    'capabilities': capabilities,
    'capabilityConfigs': capabilityConfigs,
  };
}

class ProductVariantDefinition {
  const ProductVariantDefinition({
    required this.schemaVersion,
    required this.productVariantId,
    required this.productFamily,
    required this.displayName,
    required this.channelCount,
    required this.channels,
    required this.capabilities,
    this.images = const {},
    this.firmwareFamily = 'esp32c6-switch-platform',
    this.supportedHardwareRevisions = const ['HW_1_0'],
    this.hardwareProfile = const {},
    this.connectivityProfile = const {},
    this.electricalSpecifications = const {},
    this.sku = '',
    this.description = '',
  });

  final int schemaVersion;
  final String productVariantId;
  final String productFamily;
  final String displayName;
  final int channelCount;
  final List<ProductChannelDefinition> channels;
  final List<String> capabilities;
  final Map<String, String> images;
  final String firmwareFamily;
  final List<String> supportedHardwareRevisions;
  final Map<String, dynamic> hardwareProfile;
  final Map<String, dynamic> connectivityProfile;
  final Map<String, dynamic> electricalSpecifications;
  final String sku;
  final String description;

  String? get heroImageUrl =>
      images['hero'] ?? images['front'] ?? images['thumbnail'];

  String? get imageUrl => heroImageUrl;

  bool get hasEnergyMetering {
    if (hardwareProfile.containsKey('hasEnergyMetering')) {
      return hardwareProfile['hasEnergyMetering'] == true;
    }
    return capabilities.contains('energy');
  }

  factory ProductVariantDefinition.fromJson(Map<String, dynamic> json) {
    // Check if wrapped in API response format (e.g. { "variant": { ... }, "product": { ... } })
    final vMap = json['variant'] is Map ? Map<String, dynamic>.from(json['variant'] as Map) : json;
    final pMap = json['product'] is Map ? Map<String, dynamic>.from(json['product'] as Map) : <String, dynamic>{};
    final fMap = json['family'] is Map ? Map<String, dynamic>.from(json['family'] as Map) : <String, dynamic>{};

    final variantId = vMap['productVariantId'] as String? ??
        vMap['variantId'] as String? ??
        vMap['id'] as String? ??
        '';

    final family = vMap['productFamily'] as String? ??
        vMap['familyId'] as String? ??
        pMap['familyId'] as String? ??
        fMap['slug'] as String? ??
        fMap['id'] as String? ??
        'smart_switch';

    final displayName = vMap['displayName'] as String? ??
        vMap['marketingName'] as String? ??
        pMap['displayName'] as String? ??
        variantId;

    final channelCount = (vMap['channelCount'] as num? ?? vMap['channel_count'] as num? ?? 1).toInt();

    final rawChannels = vMap['channels'] as List<dynamic>? ?? [];
    final channels = rawChannels
        .whereType<Map>()
        .map((e) => ProductChannelDefinition.fromJson(Map<String, dynamic>.from(e)))
        .toList();

    final rawCaps = vMap['capabilities'] as List<dynamic>? ?? [];
    final capabilities = rawCaps.map((e) => e.toString()).toList();

    final images = <String, String>{};
    if (vMap['images'] is Map) {
      (vMap['images'] as Map).forEach((k, v) {
        if (v != null) images[k.toString()] = v.toString();
      });
    }

    // Also parse from API assets list if present
    if (json['assets'] is List) {
      for (final a in (json['assets'] as List).whereType<Map>()) {
        final kind = a['kind']?.toString();
        final url = a['url']?.toString();
        if (kind != null && url != null) {
          images[kind] = url;
        }
      }
    }

    final rawHwRevs = vMap['supportedHardwareRevisions'] as List<dynamic>? ??
        vMap['supported_hardware_revisions'] as List<dynamic>? ??
        ['HW_1_0'];
    final supportedHardwareRevisions = rawHwRevs.map((e) => e.toString()).toList();

    return ProductVariantDefinition(
      schemaVersion: (vMap['schemaVersion'] as num? ?? 1).toInt(),
      productVariantId: variantId,
      productFamily: family,
      displayName: displayName,
      channelCount: channelCount,
      channels: channels,
      capabilities: capabilities,
      images: images,
      firmwareFamily: vMap['firmwareFamily'] as String? ?? vMap['firmware_family'] as String? ?? 'esp32c6-switch-platform',
      supportedHardwareRevisions: supportedHardwareRevisions,
      hardwareProfile: vMap['hardwareProfile'] is Map ? Map<String, dynamic>.from(vMap['hardwareProfile'] as Map) : const {},
      connectivityProfile: vMap['connectivityProfile'] is Map ? Map<String, dynamic>.from(vMap['connectivityProfile'] as Map) : const {},
      electricalSpecifications: vMap['electricalSpecifications'] is Map ? Map<String, dynamic>.from(vMap['electricalSpecifications'] as Map) : const {},
      sku: vMap['sku'] as String? ?? '',
      description: vMap['description'] as String? ?? pMap['description'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'schemaVersion': schemaVersion,
    'productVariantId': productVariantId,
    'productFamily': productFamily,
    'displayName': displayName,
    'channelCount': channelCount,
    'channels': channels.map((c) => c.toJson()).toList(),
    'capabilities': capabilities,
    'images': images,
    'firmwareFamily': firmwareFamily,
    'supportedHardwareRevisions': supportedHardwareRevisions,
    'hardwareProfile': hardwareProfile,
    'connectivityProfile': connectivityProfile,
    'electricalSpecifications': electricalSpecifications,
    'sku': sku,
    'description': description,
  };
}

class ResolvedDeviceChannel {
  const ResolvedDeviceChannel({
    required this.channelIndex,
    required this.name,
    required this.capabilities,
    this.capabilityConfigs = const {},
    this.powerState = false,
    this.fanSpeed = 0,
    this.brightnessLevel = 100,
    this.cctKelvin = 4000,
    this.isPending = false,
  });

  final int channelIndex;
  final String name;
  final List<String> capabilities;
  final Map<String, Map<String, dynamic>> capabilityConfigs;
  final bool powerState;
  final int fanSpeed;
  final int brightnessLevel;
  final int cctKelvin;
  final bool isPending;

  bool get hasSwitch =>
      capabilities.contains('switch') || capabilities.contains('relay');
  bool get hasFanSpeed => capabilities.contains('fan_speed');
  bool get hasBrightness => capabilities.contains('brightness');
  bool get hasCCT => capabilities.contains('cct');
  bool get hasEnergy => capabilities.contains('energy');

  // Metadata-driven configuration helpers
  int get fanMinSpeed =>
      (capabilityConfigs['fan_speed']?['minSpeed'] as int?) ?? 0;
  int get fanMaxSpeed =>
      (capabilityConfigs['fan_speed']?['maxSpeed'] as int?) ?? 5;
  int get fanStep => (capabilityConfigs['fan_speed']?['step'] as int?) ?? 1;

  int get cctMinKelvin =>
      (capabilityConfigs['cct']?['minKelvin'] as int?) ?? 2700;
  int get cctMaxKelvin =>
      (capabilityConfigs['cct']?['maxKelvin'] as int?) ?? 6500;
  int get cctStepKelvin =>
      (capabilityConfigs['cct']?['stepKelvin'] as int?) ?? 100;

  int get brightnessMin =>
      (capabilityConfigs['brightness']?['min'] as int?) ?? 0;
  int get brightnessMax =>
      (capabilityConfigs['brightness']?['max'] as int?) ?? 100;
  int get brightnessStep =>
      (capabilityConfigs['brightness']?['step'] as int?) ?? 1;

  ResolvedDeviceChannel copyWith({
    bool? powerState,
    int? fanSpeed,
    int? brightnessLevel,
    int? cctKelvin,
    bool? isPending,
    String? name,
    Map<String, Map<String, dynamic>>? capabilityConfigs,
  }) {
    return ResolvedDeviceChannel(
      channelIndex: channelIndex,
      name: name ?? this.name,
      capabilities: capabilities,
      capabilityConfigs: capabilityConfigs ?? this.capabilityConfigs,
      powerState: powerState ?? this.powerState,
      fanSpeed: fanSpeed ?? this.fanSpeed,
      brightnessLevel: brightnessLevel ?? this.brightnessLevel,
      cctKelvin: cctKelvin ?? this.cctKelvin,
      isPending: isPending ?? this.isPending,
    );
  }
}

class EnergyTelemetryData {
  const EnergyTelemetryData({
    this.voltageMv,
    this.currentMa,
    this.powerMw,
    this.energyTotalWh,
    this.powerFactorX1000 = 980,
  });

  final int? voltageMv;
  final int? currentMa;
  final int? powerMw;
  final int? energyTotalWh;
  final int? powerFactorX1000;

  double? get voltageV => voltageMv != null ? voltageMv! / 1000.0 : null;
  double? get currentA => currentMa != null ? currentMa! / 1000.0 : null;
  double? get powerW => powerMw != null ? powerMw! / 1000.0 : null;
  double? get energyKwh =>
      energyTotalWh != null ? energyTotalWh! / 1000.0 : null;
  double? get powerFactor =>
      powerFactorX1000 != null ? powerFactorX1000! / 1000.0 : null;
}

class ResolvedDevice {
  const ResolvedDevice({
    required this.deviceId,
    required this.productVariantId,
    required this.displayName,
    required this.connectionState,
    required this.channels,
    required this.capabilities,
    this.energyTelemetry,
    this.heroImageUrl,
  });

  final String deviceId;
  final String productVariantId;
  final String displayName;
  final CapabilityConnectionState connectionState;
  final List<ResolvedDeviceChannel> channels;
  final List<String> capabilities;
  final EnergyTelemetryData? energyTelemetry;
  final String? heroImageUrl;

  bool get hasEnergy => capabilities.contains('energy');
  bool get hasFanSpeed => capabilities.contains('fan_speed');
  bool get hasBrightness => capabilities.contains('brightness');
  bool get hasCCT => capabilities.contains('cct');
  bool get hasOTA => capabilities.contains('ota');
  bool get hasAutomation => capabilities.contains('automation');

  bool get isOnline => connectionState == CapabilityConnectionState.online;
}
