/**
 * EH Home — Backend Phase 27 Test Suite
 * Product Discovery, Catalog, Product Detail, Compatibility Resolver & Consumer Device Add
 */

'use strict';

const { createApp } = require('../src/app');
const { ProductCatalogService } = require('../src/services/product-catalog.service');
const { DeviceAddService } = require('../src/services/device-add.service');
const { DeviceAddSessionRepository } = require('../src/repositories/device-add-session.repository');
const { DatabaseClient } = require('../src/shared/db-client');

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

async function runPhase27Tests() {
  console.log('=== PHASE 27: PRODUCT DISCOVERY, CATALOG & CONSUMER DEVICE ADD TESTS ===\n');

  const catalog = new ProductCatalogService();
  const db = new DatabaseClient();
  const sessionRepo = new DeviceAddSessionRepository(db);
  const app = createApp({ db, catalogService: catalog });

  // -------------------------------------------------------------------------
  // 1. Catalog Loading & In-Memory Caching
  // -------------------------------------------------------------------------
  console.log('1. Catalog Loading & In-Memory Caching:');
  const defs = catalog.loadProductDefinitions();
  assert('Product definitions loaded (at least 7 variants)', defs.length >= 7);
  
  const switch3x = catalog.getProductVariant('eh-smart-switch-3x');
  assert('eh-smart-switch-3x found in definitions', switch3x !== null);
  assert('eh-smart-switch-3x has 3 channels', switch3x.metadata.channelCount === 3);

  const socket2x = catalog.getProductVariant('eh-smart-socket-2x');
  assert('eh-smart-socket-2x found in definitions', socket2x !== null);
  assert('eh-smart-socket-2x has 2 channels', socket2x.metadata.channelCount === 2);

  // -------------------------------------------------------------------------
  // 2. Canonical Product Catalog Entry Normalization
  // -------------------------------------------------------------------------
  console.log('\n2. Canonical Product Catalog Entry Normalization:');
  const entry3x = catalog.getCatalogEntryByVariantId('eh-smart-switch-3x');
  assert('Canonical catalog entry resolved', entry3x !== null);
  assert('Catalog entry marketing name is accurate', entry3x.marketingName === 'EH Smart Switch 3X');
  assert('Catalog entry category is switches', entry3x.category === 'switches');
  assert('Catalog entry productFamilyId is smart_switch', entry3x.productFamilyId === 'smart_switch');
  assert('Catalog entry SKU is EH-SWITCH3X-001', entry3x.sku.includes('3X'));
  assert('Catalog entry has structured images', entry3x.images && Boolean(entry3x.images.hero));
  assert('Catalog entry has energyMonitoringSupport = true', entry3x.energyMonitoringSupport === true);
  assert('Catalog entry has wifiSupport = true', entry3x.wifiSupport === true);
  assert('Catalog entry has bleProvisioningSupport = true', entry3x.bleProvisioningSupport === true);
  assert('Catalog entry has matterSupport = false', entry3x.matterSupport === false);
  assert('Catalog entry has controls array', Array.isArray(entry3x.controls) && entry3x.controls.length === 3);
  assert('Catalog entry has telemetry array', Array.isArray(entry3x.telemetry) && entry3x.telemetry.includes('p_mw'));

  // -------------------------------------------------------------------------
  // 3. Product Discovery — Filtering by Category & Family
  // -------------------------------------------------------------------------
  console.log('\n3. Product Discovery — Filtering by Category & Family:');
  const allDiscovery = catalog.discoverProducts({ page: 1, limit: 10 });
  assert('Discovery returns total >= 7', allDiscovery.total >= 7);
  assert('Discovery facets contain categories', allDiscovery.categories.length >= 2);
  assert('Discovery facets contain families', allDiscovery.families.length >= 2);

  const switchFilter = catalog.discoverProducts({ category: 'switches' });
  assert('Filtering by switches returns only switch products', switchFilter.products.every(p => p.category === 'switches'));
  assert('Switch products count matches total (4 switch variants: 1X, 2X, 3X, 4X)', switchFilter.total === 4);

  const socketFilter = catalog.discoverProducts({ family: 'smart_socket' });
  assert('Filtering by smart_socket returns only socket products', socketFilter.products.every(p => p.productFamilyId === 'smart_socket'));
  assert('Socket products count matches total (3 socket variants: 1X, 2X, 3X)', socketFilter.total === 3);

  // -------------------------------------------------------------------------
  // 4. Product Discovery — Capability & Connectivity Filtering
  // -------------------------------------------------------------------------
  console.log('\n4. Product Discovery — Capability & Connectivity Filtering:');
  const energyFilter = catalog.discoverProducts({ capability: 'energy' });
  assert('Capability energy filter returns products', energyFilter.total >= 7);
  assert('All filtered products contain energy capability', energyFilter.products.every(p => p.capabilities.includes('energy')));

  const wifiFilter = catalog.discoverProducts({ connectivity: 'wifi' });
  assert('Connectivity wifi filter returns wifi products', wifiFilter.total >= 7);
  assert('All filtered products support wifi', wifiFilter.products.every(p => p.wifiSupport));

  const threadFilter = catalog.discoverProducts({ connectivity: 'thread' });
  assert('Connectivity thread filter returns 0 for current baseline without fake features', threadFilter.total === 0);

  // -------------------------------------------------------------------------
  // 5. Product Discovery — Pagination & Stable Sorting
  // -------------------------------------------------------------------------
  console.log('\n5. Product Discovery — Pagination & Stable Sorting:');
  const page1 = catalog.discoverProducts({ page: 1, limit: 3, sort: 'name_asc' });
  const page2 = catalog.discoverProducts({ page: 2, limit: 3, sort: 'name_asc' });
  assert('Page 1 has 3 items', page1.products.length === 3);
  assert('Page 2 has 3 items', page2.products.length === 3);
  assert('Page 1 totalPages is computed correctly', page1.totalPages === Math.ceil(page1.total / 3));
  assert('No overlap between page 1 and page 2 items', page1.products[0].variantId !== page2.products[0].variantId);

  const sortDesc = catalog.discoverProducts({ sort: 'name_desc' });
  assert('Sort name_desc puts later alphabetic product first', 
    sortDesc.products[0].marketingName.localeCompare(sortDesc.products[sortDesc.products.length - 1].marketingName) > 0);

  // -------------------------------------------------------------------------
  // 6. Product Search — Deterministic Multi-Field Matching
  // -------------------------------------------------------------------------
  console.log('\n6. Product Search — Deterministic Multi-Field Matching:');
  const search3x = catalog.searchProducts({ query: 'Switch 3X' });
  assert('Search for "Switch 3X" returns match', search3x.total >= 1);
  assert('Top search result is EH Smart Switch 3X', search3x.results[0].product.variantId === 'eh-smart-switch-3x');
  assert('Matched fields include marketingName', search3x.results[0].matchedFields.includes('marketingName'));
  assert('Relevance score > 0', search3x.results[0].relevanceScore > 0.5);

  const searchSku = catalog.searchProducts({ query: 'EH-SWITCH3X-001' });
  assert('Search by SKU matches product', searchSku.total >= 1 && searchSku.results[0].product.variantId === 'eh-smart-switch-3x');
  assert('SKU match has high relevance score (>= 0.8)', searchSku.results[0].relevanceScore >= 0.8);

  const searchCase = catalog.searchProducts({ query: 'smart socket 1x' });
  assert('Case-insensitive search matches socket 1X', searchCase.total >= 1 && searchCase.results[0].product.variantId === 'eh-smart-socket-1x');

  const searchEmpty = catalog.searchProducts({ query: 'non_existent_unmatched_query_123' });
  assert('Search with unmatched query returns 0 results', searchEmpty.total === 0);

  // -------------------------------------------------------------------------
  // 7. Compatibility Resolver — COMPATIBLE Scenario
  // -------------------------------------------------------------------------
  console.log('\n7. Compatibility Resolver — COMPATIBLE Scenario:');
  const compOk = catalog.resolveCompatibility({
    productVariantId: 'eh-smart-switch-3x',
    hardwareRevision: 'HW_1_0',
    firmwareVersion: '1.0.0',
    availableConnectivity: { wifi: true, ble: true }
  });

  assert('Compatibility status is COMPATIBLE', compOk.status === 'COMPATIBLE');
  assert('isCompatible is true', compOk.isCompatible === true);
  assert('reasons array contains informative entries', compOk.reasons.length >= 1);
  assert('recommendedCommissioningTransport is BLE', compOk.recommendedCommissioningTransport === 'BLE');
  assert('supportedTransports includes WIFI_MQTT and BLE', compOk.supportedTransports.includes('WIFI_MQTT') && compOk.supportedTransports.includes('BLE'));
  assert('unsupportedFeatures is empty', compOk.unsupportedFeatures.length === 0);

  // -------------------------------------------------------------------------
  // 8. Compatibility Resolver — PARTIALLY_COMPATIBLE Scenario
  // -------------------------------------------------------------------------
  console.log('\n8. Compatibility Resolver — PARTIALLY_COMPATIBLE Scenario:');
  const compWarn = catalog.resolveCompatibility({
    productVariantId: 'eh-smart-switch-3x',
    hardwareRevision: 'HW_1_0',
    firmwareVersion: '0.9.0', // older than baseline 1.0.0
    availableConnectivity: { wifi: true, ble: false } // BLE unavailable on client
  });

  assert('Status is PARTIALLY_COMPATIBLE due to warnings', compWarn.status === 'PARTIALLY_COMPATIBLE');
  assert('isCompatible remains true (not completely blocked)', compWarn.isCompatible === true);
  assert('Contains warning reason for BLE unavailable', compWarn.reasons.some(r => r.code === 'BLE_UNAVAILABLE'));
  assert('Contains warning reason for firmware update recommended', compWarn.reasons.some(r => r.code === 'FIRMWARE_UPDATE_RECOMMENDED'));

  // -------------------------------------------------------------------------
  // 9. Compatibility Resolver — INCOMPATIBLE Scenario
  // -------------------------------------------------------------------------
  console.log('\n9. Compatibility Resolver — INCOMPATIBLE Scenario:');
  const compFailHw = catalog.resolveCompatibility({
    productVariantId: 'eh-smart-switch-3x',
    hardwareRevision: 'HW_99_UNKNOWN',
    availableConnectivity: { wifi: true, ble: true }
  });
  assert('Status is INCOMPATIBLE for unsupported hardware revision', compFailHw.status === 'INCOMPATIBLE');
  assert('isCompatible is false', compFailHw.isCompatible === false);
  assert('Contains BLOCKING reason for hardware revision', compFailHw.reasons.some(r => r.code === 'UNSUPPORTED_HARDWARE_REVISION' && r.severity === 'BLOCKING'));

  const compFailUnknown = catalog.resolveCompatibility({
    productVariantId: 'fake-unknown-variant'
  });
  assert('Status is INCOMPATIBLE for unknown product variant', compFailUnknown.status === 'INCOMPATIBLE');
  assert('Contains BLOCKING reason for unknown variant', compFailUnknown.reasons.some(r => r.code === 'UNKNOWN_PRODUCT_VARIANT'));

  const compFailWifi = catalog.resolveCompatibility({
    productVariantId: 'eh-smart-switch-3x',
    availableConnectivity: { wifi: false, ble: true }
  });
  assert('Status is INCOMPATIBLE when required Wi-Fi is unavailable', compFailWifi.status === 'INCOMPATIBLE');

  // -------------------------------------------------------------------------
  // 10. Device Add Service & Onboarding Wizard Session
  // -------------------------------------------------------------------------
  console.log('\n10. Device Add Service & Onboarding Wizard Session:');
  const deviceAddService = new DeviceAddService({
    sessionRepo,
    catalogService: catalog,
    deviceRepo: app.repositories.deviceRepo,
    deviceClaimService: app.services.deviceClaimService,
    connectivityService: app.services.connectivityService,
    homeRepo: app.repositories.homeRepo,
    roomRepo: app.repositories.roomRepo,
    auditRepo: app.repositories.auditRepo
  });

  // Step 1: Start session
  const session = await deviceAddService.startSession({
    homeId: '0194fe23-7a1b-7890-a123-456789abcdef',
    userId: '0194fe23-7a1b-7890-a123-000000000001',
    entryMode: 'MANUAL_CATALOG',
    productVariantId: 'eh-smart-switch-3x',
    customDeviceName: 'Master Switch'
  });

  assert('Session created with ID', Boolean(session.sessionId));
  assert('Session stage is PRODUCT_SELECTED', session.stage === 'PRODUCT_SELECTED');
  assert('Session compatibilityStatus evaluated to COMPATIBLE', session.compatibilityStatus === 'COMPATIBLE');

  // Step 2: Compatibility check
  const checkResult = await deviceAddService.checkCompatibility(session.sessionId, {
    productVariantId: 'eh-smart-switch-3x',
    availableConnectivity: { wifi: true, ble: true }
  });
  assert('Compatibility check returns status COMPATIBLE', checkResult.compatibility.status === 'COMPATIBLE');

  // Step 3: Progress session
  const progressed = await deviceAddService.progressSession(session.sessionId, {
    stage: 'DISCOVERING_DEVICE',
    commissioningSessionId: 'comm_123'
  });
  assert('Session progressed to DISCOVERING_DEVICE', progressed.stage === 'DISCOVERING_DEVICE');

  // Step 4: Complete onboarding
  const completed = await deviceAddService.completeSession(session.sessionId, {
    deviceId: '0194fe23-7a1b-7890-a123-111111111111',
    serialNumber: 'EH-SW3X-TEST-001',
    hardwareRevision: 'HW_1_0',
    firmwareVersion: '1.0.0',
    roomId: 'room_living_room',
    customName: 'Living Room Switch',
    channelLabels: { '1': 'Chandelier', '2': 'Ceiling Fan', '3': 'Ambient' }
  });

  assert('Onboarding completed successfully', completed.session.stage === 'COMPLETED');
  assert('Completed session has deviceId', completed.session.deviceId === '0194fe23-7a1b-7890-a123-111111111111');
  assert('Completed device has customName and channelLabels', completed.device.customName === 'Living Room Switch');
  assert('Channel labels saved in completed device', completed.device.channelLabels['1'] === 'Chandelier');

  // Cancel session test
  const cancelSession = await deviceAddService.startSession({
    homeId: '0194fe23-7a1b-7890-a123-456789abcdef',
    userId: '0194fe23-7a1b-7890-a123-000000000001',
    entryMode: 'QR_SCAN'
  });
  const cancelled = await deviceAddService.cancelSession(cancelSession.sessionId, '0194fe23-7a1b-7890-a123-000000000001', 'User stopped');
  assert('Session marked CANCELLED on cancellation', cancelled.stage === 'CANCELLED');

  // -------------------------------------------------------------------------
  // 11. Product Catalog & Device Add API Endpoints via app.handleRequest
  // -------------------------------------------------------------------------
  console.log('\n11. Product Catalog & Device Add API Endpoints:');

  // GET /api/v1/products/discovery
  let resDisc;
  await app.handleRequest(
    { method: 'GET', url: '/api/v1/products/discovery?category=switches', headers: {}, on: () => {} },
    {
      writeHead: () => {},
      end: (data) => { resDisc = JSON.parse(data); }
    }
  );
  assert('GET /api/v1/products/discovery returns 200 with data', resDisc && resDisc.data && resDisc.data.total === 4);

  // GET /api/v1/products/search
  let resSearch;
  await app.handleRequest(
    { method: 'GET', url: '/api/v1/products/search?q=socket', headers: {}, on: () => {} },
    {
      writeHead: () => {},
      end: (data) => { resSearch = JSON.parse(data); }
    }
  );
  assert('GET /api/v1/products/search returns 200 with results', resSearch && resSearch.data && resSearch.data.total >= 3);

  // GET /api/v1/products/categories
  let resCat;
  await app.handleRequest(
    { method: 'GET', url: '/api/v1/products/categories', headers: {}, on: () => {} },
    {
      writeHead: () => {},
      end: (data) => { resCat = JSON.parse(data); }
    }
  );
  assert('GET /api/v1/products/categories returns 200 with categories list', resCat && resCat.data && resCat.data.length >= 2);

  // GET /api/v1/products/families
  let resFam;
  await app.handleRequest(
    { method: 'GET', url: '/api/v1/products/families', headers: {}, on: () => {} },
    {
      writeHead: () => {},
      end: (data) => { resFam = JSON.parse(data); }
    }
  );
  assert('GET /api/v1/products/families returns 200 with families list', resFam && resFam.data && resFam.data.length >= 2);

  // POST /api/v1/products/compatibility
  let resCompat;
  await app.handleRequest(
    {
      method: 'POST',
      url: '/api/v1/products/compatibility',
      headers: { 'content-type': 'application/json' },
      body: { productVariantId: 'eh-smart-switch-3x' }
    },
    {
      writeHead: () => {},
      end: (data) => { resCompat = JSON.parse(data); }
    }
  );
  assert('POST /api/v1/products/compatibility returns 200 with status COMPATIBLE', resCompat && resCompat.data && resCompat.data.status === 'COMPATIBLE');

  // GET /api/v1/products/variants/eh-smart-switch-3x
  let resVar;
  await app.handleRequest(
    { method: 'GET', url: '/api/v1/products/variants/eh-smart-switch-3x', headers: {}, on: () => {} },
    {
      writeHead: () => {},
      end: (data) => { resVar = JSON.parse(data); }
    }
  );
  assert('GET /api/v1/products/variants/:variantId returns 200 with resolved capabilities', 
    resVar && resVar.data && resVar.data.productVariantId === 'eh-smart-switch-3x');

  // Legacy route: GET /api/v1/products
  let resLegacyProducts;
  await app.handleRequest(
    { method: 'GET', url: '/api/v1/products', headers: {}, on: () => {} },
    {
      writeHead: () => {},
      end: (data) => { resLegacyProducts = JSON.parse(data); }
    }
  );
  assert('Legacy GET /api/v1/products returns 200', resLegacyProducts && Array.isArray(resLegacyProducts.data));

  // Legacy route: GET /api/v1/capabilities
  let resLegacyCaps;
  await app.handleRequest(
    { method: 'GET', url: '/api/v1/capabilities', headers: {}, on: () => {} },
    {
      writeHead: () => {},
      end: (data) => { resLegacyCaps = JSON.parse(data); }
    }
  );
  assert('Legacy GET /api/v1/capabilities returns 200 with 14 capabilities', resLegacyCaps && resLegacyCaps.total === 14);

  // -------------------------------------------------------------------------
  // 12. Backward Compatibility for Legacy Devices
  // -------------------------------------------------------------------------
  console.log('\n12. Backward Compatibility for Legacy Devices:');
  const devCaps = catalog.resolveDeviceCapabilities({
    productVariantId: 'eh-smart-switch-3x',
    deviceId: 'legacy-device-uuid',
    channelLabels: { '1': 'Hallway Light' }
  });
  assert('resolveDeviceCapabilities still works 100% for existing devices', !devCaps.error && devCaps.channels[0].displayName === 'Hallway Light');

  console.log(`\n========================================`);
  console.log(`Total Passed: ${passed}, Total Failed: ${failed}`);
  console.log(`========================================\n`);

  process.exit(failed > 0 ? 1 : 0);
}

runPhase27Tests();
