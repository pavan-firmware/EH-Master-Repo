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

  String? get heroImageUrl =>
      images['hero'] ?? images['front'] ?? images['thumbnail'];
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
