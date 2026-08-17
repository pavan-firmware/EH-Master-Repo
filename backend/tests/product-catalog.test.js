/**
 * EH Home — Product Catalog Service & API Router Tests (Phase 3)
 */

const { ProductCatalogService } = require('../src/services/product-catalog.service');
const { ApiRouter } = require('../src/api/product-catalog.router');

let passed = 0;
let failed = 0;

function assert(description, condition, detail = '') {
  if (condition) {
    console.log(`  [PASS] ${description}`);
    passed++;
  } else {
    console.error(`  [FAIL] ${description}${detail ? ' — ' + detail : ''}`);
    failed++;
  }
}

async function runProductCatalogTests() {
  console.log('=== PRODUCT CATALOG SERVICE & CAPABILITY ENGINE TESTS ===\n');

  const catalog = new ProductCatalogService();
  const router = new ApiRouter();

  // 1. Capability Registry Loading
  console.log('1. Capability Registry Loading:');
  const allCaps = catalog.getAllCapabilities();
  assert('Capability registry loads 14 canonical capabilities', allCaps.length === 14);
  
  const switchCap = catalog.getCapability('switch');
  assert('Capability switch loaded with uiComponentHint EHSwitchCard', switchCap && switchCap.uiComponentHint === 'EHSwitchCard');
  
  const energyCap = catalog.getCapability('energy');
  assert('Capability energy loaded with telemetry fields', energyCap && energyCap.telemetryFields.length === 7);

  // 2. Product Definition Loading & Validation
  console.log('\n2. Product Definition Loading & Validation:');
  const defs = catalog.loadProductDefinitions();
  assert('Product definitions loaded (at least 1)', defs.length >= 1);
  
  const switch3x = catalog.getProductVariant('eh-smart-switch-3x');
  assert('EH Smart Switch 3X variant found', switch3x !== null);
  assert('EH Smart Switch 3X has 3 channels', switch3x.metadata.channelCount === 3);
  assert('EH Smart Switch 3X has images', switch3x.metadata.images && switch3x.metadata.images.hero !== undefined);

  const validation = catalog.validateProductDefinition(switch3x.metadata);
  assert('EH Smart Switch 3X metadata is 100% valid', validation.valid, validation.errors.join(', '));

  // 3. Validation Rejection Tests
  console.log('\n3. Product Definition Validation Rejection:');
  const invalidChannelCount = { ...switch3x.metadata, channelCount: 2 }; // mismatch with 3 channel objects
  const v1 = catalog.validateProductDefinition(invalidChannelCount);
  assert('Rejects channelCount mismatch with channels array length', !v1.valid);

  const invalidCapability = { ...switch3x.metadata, capabilities: ['unknown_fake_cap'] };
  const v2 = catalog.validateProductDefinition(invalidCapability);
  assert('Rejects unknown capability not in canonical registry', !v2.valid);

  const missingField = { ...switch3x.metadata };
  delete missingField.hardwareProfile;
  const v3 = catalog.validateProductDefinition(missingField);
  assert('Rejects missing required hardwareProfile', !v3.valid);

  // 4. Device Capability Resolution
  console.log('\n4. Device Capability Resolution:');
  const resolved = catalog.resolveDeviceCapabilities({
    productVariantId: 'eh-smart-switch-3x',
    deviceId: 'test-device-uuid-1',
    channelLabels: { '1': 'Living Chandelier', '2': 'Ceiling Fan', '3': 'Accent Light' },
    deviceState: {
      connectionState: 'ONLINE',
      channels: [
        { channelIndex: 1, desiredState: { power: true }, reportedState: { power: true } },
        { channelIndex: 2, desiredState: { power: false }, reportedState: { power: false } },
        { channelIndex: 3, desiredState: { power: true }, reportedState: { power: false } }
      ]
    }
  });

  assert('Device capabilities resolved successfully', !resolved.error);
  assert('Resolved 3 channels', resolved.channels.length === 3);
  assert('Custom channel name applied for channel 1', resolved.channels[0].displayName === 'Living Chandelier');
  assert('Channel 1 contains state', resolved.channels[0].state.reportedState.power === true);
  assert('Feature flag hasEnergyMonitoring is true', resolved.hasEnergyMonitoring === true);
  assert('Feature flag hasFanSpeed is false', resolved.hasFanSpeed === false);
  assert('Capability UI hints mapped', resolved.capabilityUiHints['switch'] === 'EHSwitchCard');

  // 5. Read-Only API Router Endpoints
  console.log('\n5. Read-Only Product Catalog API Endpoints:');
  
  const resProducts = await router.handle('GET', '/api/v1/products');
  assert('GET /api/v1/products returns 200 with data array', resProducts.status === 200 && Array.isArray(resProducts.body.data));

  const resVariant = await router.handle('GET', '/api/v1/product-variants/eh-smart-switch-3x');
  assert('GET /api/v1/product-variants/:variantId returns 200 with resolved capabilities', 
    resVariant.status === 200 && resVariant.body.data.productVariantId === 'eh-smart-switch-3x');

  const resVariant404 = await router.handle('GET', '/api/v1/product-variants/non-existent-sku');
  assert('GET /api/v1/product-variants/:variantId returns 404 for unknown variant', resVariant404.status === 404);

  const resCaps = await router.handle('GET', '/api/v1/capabilities');
  assert('GET /api/v1/capabilities returns 200 with 14 capabilities', resCaps.status === 200 && resCaps.body.total === 14);

  const resCap = await router.handle('GET', '/api/v1/capabilities/switch');
  assert('GET /api/v1/capabilities/switch returns 200', resCap.status === 200 && resCap.body.data.capabilityId === 'switch');

  const resDeviceCaps = await router.handle('GET', '/api/v1/devices/dev-123/capabilities', {
    productVariantId: 'eh-smart-switch-3x',
    channelLabels: { '1': 'Hall Light' }
  });
  assert('GET /api/v1/devices/:deviceId/capabilities returns 200 with resolved channels',
    resDeviceCaps.status === 200 && resDeviceCaps.body.data.channels[0].displayName === 'Hall Light');

  // 6. Future Product Extensibility Test (e.g. Smart Curtain / Smart Fan)
  console.log('\n6. Future Product Extensibility Test:');
  const futureProductDef = {
    schemaVersion: 1,
    productVariantId: 'eh-smart-fan-1x',
    productFamily: 'smart_fan',
    displayName: 'EH Smart Ceiling Fan 1X',
    channelCount: 1,
    channels: [
      {
        channelIndex: 1,
        defaultLabel: 'Ceiling Fan',
        capabilities: ['switch', 'relay', 'fan_speed', 'energy', 'ota', 'automation', 'scene', 'schedule']
      }
    ],
    hardwareProfile: {
      schemaVersion: 1,
      mcuFamily: 'esp32-c6',
      flashSizeBytes: 4194304,
      psramSizeBytes: null,
      hasEnergyMetering: true,
      energyMeterChip: 'BL0942',
      maxRelayAmpsPerChannel: 5.0,
      maxTotalAmps: 5.0,
      gpioMap: { relay_ch1: 18, fan_regulator_ch1: 19 }
    },
    connectivityProfile: {
      schemaVersion: 1,
      supportsWifi: true,
      wifiStandards: ['802.11b', '802.11g', '802.11n', '802.11ax'],
      supportsBle: true,
      bleVersion: '5.0',
      supportsThread: false,
      threadVersion: null,
      supportsMatter: false,
      matterDeviceType: null
    },
    capabilities: ['switch', 'relay', 'fan_speed', 'energy', 'ota', 'automation', 'scene', 'schedule'],
    electricalSpecifications: {
      voltageRange: '90V - 250V AC',
      frequencyHz: '50/60Hz',
      maxCurrentPerChannelAmps: 5.0,
      maxTotalCurrentAmps: 5.0
    },
    images: {
      hero: 'assets/products/smart_fan/hero.png'
    },
    firmwareFamily: 'esp32c6-fan-platform',
    supportedHardwareRevisions: ['HW_1_0']
  };

  const futureValidation = catalog.validateProductDefinition(futureProductDef);
  assert('Future product (Smart Fan) metadata passes validation seamlessly without engine modifications', futureValidation.valid, futureValidation.errors.join(', '));

  console.log(`\n========================================`);
  console.log(`Total Passed: ${passed}, Total Failed: ${failed}`);
  console.log(`========================================\n`);

  process.exit(failed > 0 ? 1 : 0);
}

runProductCatalogTests();
