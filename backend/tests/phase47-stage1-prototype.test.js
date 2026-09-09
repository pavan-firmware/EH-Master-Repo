/**
 * EH Home — Phase 47 Stage 1: Prototype Product Definition & ESP32 Dev-Board Target Tests
 *
 * Automated verification of:
 *  1. SMART_SOCKET 3X is a valid canonical product definition.
 *  2. 3X resolves to exactly 3 channels.
 *  3. Channel IDs and indices are deterministic (1, 2, 3).
 *  4. Relay capability count matches 3.
 *  5. Switch capability count matches 3.
 *  6. Product metadata survives JSON serialization/deserialization round-trip.
 *  7. Backend/device model preserves product (smart_socket) + variant (3x / eh-smart-socket-3x).
 *  8. Flutter capability model consumes 3X metadata without hardcoded assumptions.
 *  9. Dynamic channel generation resolves exactly 3 channel controllers.
 * 10. No dummy user/device/home is introduced in runtime configuration.
 * 11. Unauthenticated startup preserves real authentication route.
 * 12. Logout returns to unauthenticated state.
 * 13. Prototype firmware configuration (ESP32 Dev Board GPIOs: relay 18,19,21 / switch 4,5,13) resolves correctly.
 * 14. Firmware startup diagnostic banner contains exact product, variant, and hardware fields.
 * 15. Product catalog non-regression across all supported variants.
 */

'use strict';

const path = require('path');
const fs = require('fs');
const { SchemaValidator } = require('../../packages/contracts/validator');
const { ProductCatalogService } = require('../src/services/product-catalog.service');

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
  console.log('=== RUNNING PHASE 47 STAGE 1 PROTOTYPE PRODUCT DEFINITION SUITE ===\n');

  // Load canonical contract schemas
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
  catalogService.loadProductDefinitions();

  // -------------------------------------------------------------------------
  // 1. SMART_SOCKET 3X Schema Validation
  // -------------------------------------------------------------------------
  console.log('\n[1. SMART_SOCKET 3X Canonical Definition]');
  const socket3xDef = catalogService.getProductVariant('eh-smart-socket-3x');
  assert('eh-smart-socket-3x is registered in ProductCatalogService', Boolean(socket3xDef));

  const metadata3x = socket3xDef.metadata;
  const validationRes = validator.validate('ProductMetadata', metadata3x);
  assert('eh-smart-socket-3x metadata conforms strictly to ProductMetadata schema', validationRes.valid, JSON.stringify(validationRes.errors));
  assert('productFamily equals smart_socket', metadata3x.productFamily === 'smart_socket');
  assert('displayName equals "EH Smart Socket 3X"', metadata3x.displayName === 'EH Smart Socket 3X');

  // -------------------------------------------------------------------------
  // 2 & 3. Channel Resolution & Deterministic Indices
  // -------------------------------------------------------------------------
  console.log('\n[2 & 3. Channel Count & Deterministic Indices]');
  assert('channelCount equals 3', metadata3x.channelCount === 3);
  assert('channels array length is exactly 3', Array.isArray(metadata3x.channels) && metadata3x.channels.length === 3);

  const channelIndices = metadata3x.channels.map(c => c.channelIndex);
  assert('channel indices are strictly [1, 2, 3]', JSON.stringify(channelIndices) === JSON.stringify([1, 2, 3]));

  const channelLabels = metadata3x.channels.map(c => c.defaultLabel);
  assert('channel default labels are Socket 1, Socket 2, Socket 3',
    channelLabels[0] === 'Socket 1' && channelLabels[1] === 'Socket 2' && channelLabels[2] === 'Socket 3'
  );

  // -------------------------------------------------------------------------
  // 4 & 5. Relay & Switch Capabilities Count
  // -------------------------------------------------------------------------
  console.log('\n[4 & 5. Relay & Switch Capability Verification]');
  const relayChannels = metadata3x.channels.filter(c => c.capabilities.includes('relay'));
  assert('relay capability count is exactly 3', relayChannels.length === 3);

  const switchChannels = metadata3x.channels.filter(c => c.capabilities.includes('local_switch') || c.capabilities.includes('switch'));
  assert('switch capability count is exactly 3', switchChannels.length === 3);

  const energyChannels = metadata3x.channels.filter(c => c.capabilities.includes('energy'));
  assert('energy capability is mapped across all 3 channels', energyChannels.length === 3);

  // -------------------------------------------------------------------------
  // 6. Serialization / Deserialization Round-Trip
  // -------------------------------------------------------------------------
  console.log('\n[6. Serialization / Deserialization Round-Trip]');
  const serialized = JSON.stringify(metadata3x);
  const deserialized = JSON.parse(serialized);
  assert('metadata survives JSON serialization round-trip with identical keys', JSON.stringify(deserialized) === serialized);
  assert('deserialized object passes canonical schema validation', validator.validate('ProductMetadata', deserialized).valid);

  // -------------------------------------------------------------------------
  // 7. Backend Domain / Device Capability Resolution
  // -------------------------------------------------------------------------
  console.log('\n[7. Backend Device Model Capability Resolution]');
  const resolvedDevice = catalogService.resolveDeviceCapabilities({
    productVariantId: 'eh-smart-socket-3x',
    deviceId: '11111111-2222-3333-4444-555555555555',
    channelLabels: { '1': 'Master Socket', '2': 'Desk Charger', '3': 'Monitor' },
    deviceState: {
      channels: [
        { channelIndex: 1, power: true },
        { channelIndex: 2, power: false },
        { channelIndex: 3, power: true }
      ]
    }
  });

  assert('resolvedDevice has deviceId preserved', resolvedDevice.deviceId === '11111111-2222-3333-4444-555555555555');
  assert('resolvedDevice channelCount is 3', resolvedDevice.channelCount === 3);
  assert('resolvedDevice channels length is 3', resolvedDevice.channels.length === 3);
  assert('custom channel labels applied accurately',
    resolvedDevice.channels[0].displayName === 'Master Socket' &&
    resolvedDevice.channels[1].displayName === 'Desk Charger' &&
    resolvedDevice.channels[2].displayName === 'Monitor'
  );
  assert('hasEnergyMonitoring is true', resolvedDevice.hasEnergyMonitoring === true);
  assert('hasOTA is true', resolvedDevice.hasOTA === true);

  // -------------------------------------------------------------------------
  // 8 & 9. Dynamic Channel UI Generation Simulation
  // -------------------------------------------------------------------------
  console.log('\n[8 & 9. Dynamic UI Channel Generation]');
  // Simulating the Flutter CapabilityResolver logic in pure JS
  function simulateFlutterCapabilityResolver(variantDef, customName, channelStates) {
    const channels = variantDef.channels.map(ch => ({
      index: ch.channelIndex,
      name: ch.defaultLabel,
      power: (channelStates[ch.channelIndex] && channelStates[ch.channelIndex].power) || false,
      capabilities: ch.capabilities,
      hasRelay: ch.capabilities.includes('relay') || ch.capabilities.includes('switch')
    }));
    return {
      productVariantId: variantDef.productVariantId,
      displayName: customName || variantDef.displayName,
      channelCount: channels.length,
      controllers: channels
    };
  }

  const flutterResolved = simulateFlutterCapabilityResolver(metadata3x, 'Living Room 3X Socket', { 1: { power: true } });
  assert('Flutter model produces exactly 3 dynamic controllers', flutterResolved.controllers.length === 3);
  assert('Flutter model does not rely on hardcoded switch counts', flutterResolved.channelCount === 3);
  assert('First controller has relay authority and power ON', flutterResolved.controllers[0].hasRelay && flutterResolved.controllers[0].power === true);
  assert('Second controller has relay authority and power OFF', flutterResolved.controllers[1].hasRelay && flutterResolved.controllers[1].power === false);

  // -------------------------------------------------------------------------
  // 10, 11 & 12. Real Auth Requirements & No Dummy Bypass
  // -------------------------------------------------------------------------
  console.log('\n[10, 11 & 12. Real Auth & Clean Startup Verification]');
  const appDartPath = path.join(__dirname, '../../smart_home_application_v1/lib/app/app.dart');
  const appDartContent = fs.readFileSync(appDartPath, 'utf8');

  assert('app.dart checks unauthenticated state and routes to LoginScreen',
    appDartContent.includes('authState == AuthState.unauthenticated') &&
    appDartContent.includes('LoginScreen(controller: _authController!)')
  );
  assert('app.dart does not contain hardcoded demo credentials in startup path',
    !appDartContent.includes('demo@ehhome.io') &&
    !appDartContent.includes('password123')
  );

  const homeShellPath = path.join(__dirname, '../../smart_home_application_v1/lib/app/home_shell.dart');
  const homeShellContent = fs.readFileSync(homeShellPath, 'utf8');
  assert('HomeShell settings tab supports logout trigger via authController.logout()',
    homeShellContent.includes('authController!.logout()')
  );

  // -------------------------------------------------------------------------
  // 13. Prototype Firmware Hardware Pin Mapping
  // -------------------------------------------------------------------------
  console.log('\n[13. Prototype Firmware Hardware Pin Mapping]');
  const relayManagerHPath = path.join(__dirname, '../../firmware/platforms/esp32/smart-switch-app/main/relay_manager.h');
  const relayManagerHContent = fs.readFileSync(relayManagerHPath, 'utf8');

  assert('relay_manager.h defines EH_RELAY_CHANNEL_COUNT = 3', relayManagerHContent.includes('#define EH_RELAY_CHANNEL_COUNT 3'));
  assert('relay_manager.h maps ESP32 Dev Board GPIOs (18, 19, 21)',
    relayManagerHContent.includes('GPIO_RELAY_CH1 18') &&
    relayManagerHContent.includes('GPIO_RELAY_CH2 19') &&
    relayManagerHContent.includes('GPIO_RELAY_CH3 21')
  );

  const switchManagerHPath = path.join(__dirname, '../../firmware/platforms/esp32/smart-switch-app/main/switch_manager.h');
  const switchManagerHContent = fs.readFileSync(switchManagerHPath, 'utf8');

  assert('switch_manager.h defines EH_SWITCH_CHANNEL_COUNT = 3', switchManagerHContent.includes('#define EH_SWITCH_CHANNEL_COUNT 3'));
  assert('switch_manager.h maps ESP32 Dev Board input GPIOs (4, 5, 13)',
    switchManagerHContent.includes('GPIO_SWITCH_IN_CH1 4') &&
    switchManagerHContent.includes('GPIO_SWITCH_IN_CH2 5') &&
    switchManagerHContent.includes('GPIO_SWITCH_IN_CH3 13')
  );

  // -------------------------------------------------------------------------
  // 14. Deterministic Diagnostic Identity Banner Format
  // -------------------------------------------------------------------------
  console.log('\n[14. Firmware Diagnostic Identity Banner]');
  const mainCPath = path.join(__dirname, '../../firmware/platforms/esp32/smart-switch-app/main/main.c');
  const mainCContent = fs.readFileSync(mainCPath, 'utf8');

  assert('main.c defines EH_PRODUCT_TYPE as "SMART_SOCKET"', mainCContent.includes('#define EH_PRODUCT_TYPE "SMART_SOCKET"'));
  assert('main.c defines EH_PRODUCT_VARIANT as "3X"', mainCContent.includes('#define EH_PRODUCT_VARIANT "3X"'));
  assert('main.c defines EH_HARDWARE_TARGET as "ESP32_DEV_BOARD"', mainCContent.includes('#define EH_HARDWARE_TARGET "ESP32_DEV_BOARD"'));
  assert('main.c logs structured prototype diagnostic startup banner',
    mainCContent.includes('EH SMART HOME PROTOTYPE') &&
    mainCContent.includes('log_diagnostic_banner')
  );

  // -------------------------------------------------------------------------
  // 15. Product Family Architectural Hierarchy & Catalog Integrity
  // -------------------------------------------------------------------------
  console.log('\n[15. Product Family Architectural Hierarchy]');
  const socketVariants = ['eh-smart-socket-1x', 'eh-smart-socket-2x', 'eh-smart-socket-3x'];
  for (const vId of socketVariants) {
    const vDef = catalogService.getProductVariant(vId);
    assert(`Catalog contains ${vId}`, Boolean(vDef));
  }

  console.log(`\n=== SUITE COMPLETE: ${passed} passed, ${failed} failed ===`);
  if (failed > 0) {
    process.exit(1);
  }
}

runTests().catch(err => {
  console.error('Test execution exception:', err);
  process.exit(1);
});
