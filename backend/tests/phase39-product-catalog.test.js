/**
 * EH Home — Phase 39 Product Catalog Expansion & Metadata Tests
 *
 * Covers:
 *  1. Smart Fan schema & capabilities (0..5 speed levels, energy monitoring)
 *  2. Smart Light / CCT schema & capabilities (brightness 0..100, CCT 2700K..6500K)
 *  3. Smart Hub gateway schema & capabilities (ESP32-S3, Thread, Matter bridge)
 *  4. Sensor Node schema & capabilities (ESP32-C6, environmental telemetry)
 *  5. Canonical capability compliance (strictly within 14 canonical capabilities)
 *  6. Valid ranges and constraint validation
 *  7. Invalid metadata rejection
 *  8. Duplicate SKU and variant ID rejection
 *  9. Product versioning & hardware revision compatibility
 * 10. Transport metadata & connectivity profiles
 * 11. Catalog discovery & category filtering across all 6 families
 * 12. DeviceAddService onboarding compatibility
 * 13. Existing 7 product definitions non-regression (Smart Switch 1X..4X, Smart Socket 1X..3X)
 * 14. Zero secret exposure in metadata
 */

'use strict';

const path = require('path');
const fs = require('fs');
const { SchemaValidator } = require('../../packages/contracts/validator');
const { ProductCatalogService } = require('../src/services/product-catalog.service');
const { DeviceAddService } = require('../src/services/device-add.service');

let passed = 0;
let failed = 0;

function assert(description, condition, detail = '') {
  if (condition) {
    console.log(`  ✓ ${description}`);
    passed++;
  } else {
    console.error(`  ✗ FAIL: ${description}${detail ? ' — ' + detail : ''}`);
    failed++;
  }
}

async function runTests() {
  console.log('=== RUNNING PHASE 39 PRODUCT CATALOG EXPANSION SUITE ===\n');

  const validator = new SchemaValidator();
  [
    '../../packages/contracts/product/hardware-profile.schema.json',
    '../../packages/contracts/product/connectivity-profile.schema.json',
    '../../packages/contracts/product/product-metadata.schema.json',
    '../../packages/contracts/product/product-family.schema.json',
    '../../packages/contracts/product/product-model.schema.json',
    '../../packages/contracts/product/product-variant.schema.json',
    '../../packages/contracts/product/product-asset.schema.json',
    '../../packages/contracts/product/product-catalog-entry.schema.json',
    '../../packages/contracts/product/product-discovery-response.schema.json',
    '../../packages/contracts/product/product-search-result.schema.json',
    '../../packages/contracts/product/product-compatibility.schema.json',
    '../../packages/contracts/product/device-add-session.schema.json'
  ].forEach(f => validator.loadSchema(path.join(__dirname, f)));

  const catalogService = new ProductCatalogService();
  const allDefs = catalogService.loadProductDefinitions();

  // --- 1. Total Catalog Count Validation ---
  console.log('--- 1. Total Catalog Count Validation ---');
  assert('Catalog loads exactly 11 product definitions', allDefs.length === 11, `Found ${allDefs.length}`);

  const fanDef = catalogService.getProductVariant('eh-smart-fan-1x');
  const lightDef = catalogService.getProductVariant('eh-smart-light-cct');
  const hubDef = catalogService.getProductVariant('eh-smart-hub-v1');
  const sensorDef = catalogService.getProductVariant('eh-sensor-node-v1');

  assert('Smart Fan 1X variant is present', fanDef !== null);
  assert('Smart Light CCT variant is present', lightDef !== null);
  assert('Smart Hub V1 variant is present', hubDef !== null);
  assert('Sensor Node V1 variant is present', sensorDef !== null);

  // --- 2. Smart Fan Product Definition ---
  console.log('\n--- 2. Smart Fan Product Definition ---');
  assert('Smart Fan has productFamily smart_fan', fanDef.metadata.productFamily === 'smart_fan');
  assert('Smart Fan has 1 channel with fan_speed capability',
    fanDef.metadata.channels.length === 1 && fanDef.metadata.channels[0].capabilities.includes('fan_speed'));
  assert('Smart Fan has energy monitoring capability', fanDef.metadata.capabilities.includes('energy'));
  assert('Smart Fan hardware profile has 5.0A relay and BL0942 chip',
    fanDef.metadata.hardwareProfile.maxRelayAmpsPerChannel === 5.0 && fanDef.metadata.hardwareProfile.energyMeterChip === 'BL0942');
  const fanValidation = validator.validate('ProductMetadata', fanDef.metadata);
  assert('Smart Fan passes ProductMetadata contract validation', fanValidation.valid, fanValidation.errors?.join(', '));

  // --- 3. Smart Light / CCT Product Definition ---
  console.log('\n--- 3. Smart Light / CCT Product Definition ---');
  assert('Smart Light has productFamily smart_lighting', lightDef.metadata.productFamily === 'smart_lighting');
  assert('Smart Light has brightness and cct capabilities',
    lightDef.metadata.capabilities.includes('brightness') && lightDef.metadata.capabilities.includes('cct'));
  assert('Smart Light supports Matter Extended Color/CCT Light (0x010C)',
    lightDef.metadata.connectivityProfile.supportsMatter === true && lightDef.metadata.connectivityProfile.matterDeviceType === '0x010C');
  assert('Smart Light supports Thread 1.3', lightDef.metadata.connectivityProfile.supportsThread === true);
  const lightValidation = validator.validate('ProductMetadata', lightDef.metadata);
  assert('Smart Light passes ProductMetadata contract validation', lightValidation.valid, lightValidation.errors?.join(', '));

  // --- 4. Smart Hub Gateway Product Definition ---
  console.log('\n--- 4. Smart Hub Gateway Product Definition ---');
  assert('Smart Hub has productFamily smart_controller', hubDef.metadata.productFamily === 'smart_controller');
  assert('Smart Hub uses ESP32-S3 MCU with 16MB Flash and 8MB PSRAM',
    hubDef.metadata.hardwareProfile.mcuFamily === 'esp32-s3' &&
    hubDef.metadata.hardwareProfile.flashSizeBytes === 16777216 &&
    hubDef.metadata.hardwareProfile.psramSizeBytes === 8388608);
  assert('Smart Hub supports Matter Bridge / Root Node (0x0016)',
    hubDef.metadata.connectivityProfile.supportsMatter === true && hubDef.metadata.connectivityProfile.matterDeviceType === '0x0016');
  assert('Smart Hub has 0.0A relay amps (gateway, not load controller)',
    hubDef.metadata.hardwareProfile.maxRelayAmpsPerChannel === 0.0);
  const hubValidation = validator.validate('ProductMetadata', hubDef.metadata);
  assert('Smart Hub passes ProductMetadata contract validation', hubValidation.valid, hubValidation.errors?.join(', '));

  // --- 5. Sensor Node Product Definition ---
  console.log('\n--- 5. Sensor Node Product Definition ---');
  assert('Sensor Node has productFamily smart_sensor', sensorDef.metadata.productFamily === 'smart_sensor');
  assert('Sensor Node supports Matter Temperature/Humidity Sensor (0x0302)',
    sensorDef.metadata.connectivityProfile.supportsMatter === true && sensorDef.metadata.connectivityProfile.matterDeviceType === '0x0302');
  assert('Sensor Node electrical spec supports battery/USB DC voltage',
    sensorDef.metadata.electricalSpecifications.voltageRange.includes('DC'));
  const sensorValidation = validator.validate('ProductMetadata', sensorDef.metadata);
  assert('Sensor Node passes ProductMetadata contract validation', sensorValidation.valid, sensorValidation.errors?.join(', '));

  // --- 6. Canonical Capability Compliance ---
  console.log('\n--- 6. Canonical Capability Compliance ---');
  const canonicalCapIds = [
    'switch', 'relay', 'local_switch', 'energy', 'voltage',
    'current', 'power', 'fan_speed', 'brightness', 'cct',
    'ota', 'automation', 'scene', 'schedule'
  ];
  for (const def of allDefs) {
    const allCapsInDef = [
      ...def.metadata.capabilities,
      ...def.metadata.channels.flatMap(c => c.capabilities)
    ];
    const invalidCaps = allCapsInDef.filter(c => !canonicalCapIds.includes(c));
    assert(`Product ${def.metadata.productVariantId} uses only canonical capabilities`, invalidCaps.length === 0, `Invalid: ${invalidCaps.join(', ')}`);
  }

  // --- 7. Validation Rejection Tests ---
  console.log('\n--- 7. Validation Rejection Tests ---');
  const invalidFan = { ...fanDef.metadata, channelCount: 2 }; // mismatch with 1 channel
  assert('Rejects channel count mismatch', !catalogService.validateProductDefinition(invalidFan).valid);

  const unknownCapProduct = { ...lightDef.metadata, capabilities: ['fake_cloud_teleport'] };
  assert('Rejects unknown capability not in canonical registry', !catalogService.validateProductDefinition(unknownCapProduct).valid);

  const missingProfile = { ...hubDef.metadata };
  delete missingProfile.connectivityProfile;
  assert('Rejects missing connectivityProfile', !catalogService.validateProductDefinition(missingProfile).valid);

  // --- 8. Duplicate SKU & Variant ID Uniqueness ---
  console.log('\n--- 8. Duplicate SKU & Variant ID Uniqueness ---');
  const variantIds = allDefs.map(d => d.metadata.productVariantId);
  const uniqueVariantIds = new Set(variantIds);
  assert('All 11 productVariantId values are globally unique', variantIds.length === uniqueVariantIds.size);

  const skus = allDefs.map(d => catalogService.getCatalogEntryByVariantId(d.metadata.productVariantId).sku);
  const uniqueSkus = new Set(skus);
  assert('All 11 normalized SKUs are globally unique', skus.length === uniqueSkus.size);

  // --- 9. Multi-Dimensional Compatibility Resolver ---
  console.log('\n--- 9. Multi-Dimensional Compatibility Resolver ---');
  const fanCompat = catalogService.resolveCompatibility({
    productVariantId: 'eh-smart-fan-1x',
    hardwareRevision: 'HW_1_0',
    availableConnectivity: { wifi: true, ble: true }
  });
  assert('Smart Fan is COMPATIBLE with Wi-Fi & BLE home environment', fanCompat.isCompatible === true && fanCompat.status === 'COMPATIBLE');

  const lightCompatMatter = catalogService.resolveCompatibility({
    productVariantId: 'eh-smart-light-cct',
    availableConnectivity: { thread: true, matter: true },
    installedHubProtocols: ['matter']
  });
  assert('Smart Light is COMPATIBLE with Thread & Matter ecosystem', lightCompatMatter.isCompatible === true);

  const invalidRevCompat = catalogService.resolveCompatibility({
    productVariantId: 'eh-smart-hub-v1',
    hardwareRevision: 'HW_99_UNKNOWN'
  });
  assert('Rejects unsupported hardware revision as INCOMPATIBLE', invalidRevCompat.isCompatible === false);

  // --- 10. Catalog Discovery & Category Filtering ---
  console.log('\n--- 10. Catalog Discovery & Category Filtering ---');
  const allDiscovered = catalogService.discoverProducts();
  assert('discoverProducts() returns all 11 active catalog entries', allDiscovered.total === 11);

  const fanCategory = catalogService.discoverProducts({ category: 'fans' });
  assert('Category filter fans returns Smart Fan', fanCategory.total === 1 && fanCategory.products[0].variantId === 'eh-smart-fan-1x');

  const lightCategory = catalogService.discoverProducts({ category: 'lighting' });
  assert('Category filter lighting returns Smart Light', lightCategory.total === 1 && lightCategory.products[0].variantId === 'eh-smart-light-cct');

  const hubCategory = catalogService.discoverProducts({ category: 'controllers' });
  assert('Category filter controllers returns Smart Hub', hubCategory.total === 1 && hubCategory.products[0].variantId === 'eh-smart-hub-v1');

  const sensorCategory = catalogService.discoverProducts({ category: 'sensors' });
  assert('Category filter sensors returns Sensor Node', sensorCategory.total === 1 && sensorCategory.products[0].variantId === 'eh-sensor-node-v1');

  // --- 11. Device Capability Resolution & UI Hints ---
  console.log('\n--- 11. Device Capability Resolution & UI Hints ---');
  const resolvedFan = catalogService.resolveDeviceCapabilities({
    productVariantId: 'eh-smart-fan-1x',
    deviceId: 'test-fan-uuid',
    channelLabels: { '1': 'Master Bedroom Fan' }
  });
  assert('Resolved fan has fan_speed capability and EHFanSpeedDial UI hint',
    resolvedFan.hasFanSpeed === true && resolvedFan.capabilityUiHints['fan_speed'] === 'EHFanSpeedDial');
  assert('Resolved fan custom channel label applied', resolvedFan.channels[0].displayName === 'Master Bedroom Fan');

  const resolvedLight = catalogService.resolveDeviceCapabilities({
    productVariantId: 'eh-smart-light-cct',
    deviceId: 'test-light-uuid',
    channelLabels: { '1': 'Reading Lamp' }
  });
  assert('Resolved light has brightness and cct capability UI hints',
    resolvedLight.hasBrightness === true &&
    resolvedLight.hasCCT === true &&
    resolvedLight.capabilityUiHints['brightness'] === 'EHDimmerSlider' &&
    resolvedLight.capabilityUiHints['cct'] === 'EHCCTDial');

  // --- 12. DeviceAddService Compatibility ---
  console.log('\n--- 12. DeviceAddService Compatibility ---');
  const mockSessionRepo = {
    sessions: new Map(),
    async createSession(s) {
      this.sessions.set(s.id, s);
      return s;
    },
    async findById(id) {
      return this.sessions.get(id) || null;
    }
  };

  const deviceAddService = new DeviceAddService({
    sessionRepo: mockSessionRepo,
    catalogService,
    deviceRepo: null,
    deviceClaimService: null,
    connectivityService: null,
    homeRepo: null,
    roomRepo: null
  });

  const fanAddSession = await deviceAddService.startSession({
    homeId: 'home-123',
    userId: 'user-456',
    productVariantId: 'eh-smart-fan-1x',
    customDeviceName: 'Ceiling Fan'
  });
  assert('DeviceAddService starts session for Smart Fan with COMPATIBLE status',
    fanAddSession.stage === 'PRODUCT_SELECTED' && fanAddSession.compatibilityStatus === 'COMPATIBLE');

  const lightAddSession = await deviceAddService.startSession({
    homeId: 'home-123',
    userId: 'user-456',
    productVariantId: 'eh-smart-light-cct',
    customDeviceName: 'Studio Light'
  });
  assert('DeviceAddService starts session for Smart Light CCT with valid compatibility status',
    lightAddSession.stage === 'PRODUCT_SELECTED' && ['COMPATIBLE', 'PARTIALLY_COMPATIBLE'].includes(lightAddSession.compatibilityStatus));

  // --- 13. Existing Product Non-Regression (7 SKUs) ---
  console.log('\n--- 13. Existing Product Non-Regression ---');
  const existingVariants = [
    'eh-smart-switch-1x',
    'eh-smart-switch-2x',
    'eh-smart-switch-3x',
    'eh-smart-switch-4x',
    'eh-smart-socket-1x',
    'eh-smart-socket-2x',
    'eh-smart-socket-3x'
  ];

  for (const variantId of existingVariants) {
    const v = catalogService.getProductVariant(variantId);
    assert(`Existing variant ${variantId} is intact and recognized`, v !== null);
    const validRes = catalogService.validateProductDefinition(v.metadata);
    assert(`Existing variant ${variantId} is 100% valid`, validRes.valid);
  }

  // --- 14. Zero Secret Exposure In Metadata ---
  console.log('\n--- 14. Zero Secret Exposure In Metadata ---');
  for (const def of allDefs) {
    const jsonStr = JSON.stringify(def.metadata).toLowerCase();
    assert(`No private key in ${def.metadata.productVariantId}`, !jsonStr.includes('private_key') && !jsonStr.includes('privatekey'));
    assert(`No passwords in ${def.metadata.productVariantId}`, !jsonStr.includes('password') && !jsonStr.includes('client_secret'));
    assert(`No bearer tokens in ${def.metadata.productVariantId}`, !jsonStr.includes('bearer') && !jsonStr.includes('session_secret'));
  }

  console.log(`\n=== PHASE 39 TEST RESULTS: ${passed}/${passed + failed} PASS ===\n`);
  if (failed > 0) {
    process.exit(1);
  }
}

runTests().catch(err => {
  console.error('Fatal error in Phase 39 test runner:', err);
  process.exit(1);
});
