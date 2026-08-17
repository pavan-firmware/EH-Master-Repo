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

  @override
  Future<List<ProductVariantDefinition>> getProductVariants() async {
    return [_smartSwitch3x];
  }

  @override
  Future<ProductVariantDefinition?> getProductVariant(String variantId) async {
    if (variantId == _smartSwitch3x.productVariantId) {
      return _smartSwitch3x;
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
    ];
  }
}
