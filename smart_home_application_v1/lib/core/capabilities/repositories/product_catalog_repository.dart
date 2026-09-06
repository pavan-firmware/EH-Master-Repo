import '../models/capability_models.dart';

abstract class ProductCatalogRepository {
  Future<List<ProductVariantDefinition>> getProductVariants();
  Future<ProductVariantDefinition?> getProductVariant(String variantId);
  Future<List<CanonicalCapability>> getCapabilities();
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

  static const _allVariants = [
    _smartSwitch3x,
    _smartFan1x,
    _smartLightCct,
    _smartHubV1,
    _sensorNodeV1,
  ];

  @override
  Future<List<ProductVariantDefinition>> getProductVariants() async {
    return _allVariants;
  }

  @override
  Future<ProductVariantDefinition?> getProductVariant(String variantId) async {
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
