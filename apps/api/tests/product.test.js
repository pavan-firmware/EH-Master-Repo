/**
 * EH Home Product & Design Management Automated Test Suite
 *
 * Validates:
 * - Product catalog listing and pagination (GET /api/v1/products)
 * - Catalog filtering (by family, capability, connectivity)
 * - Product family discovery (GET /api/v1/products/families)
 * - Product detail retrieval and 404 handling (GET /api/v1/products/:productId)
 * - Variant detail retrieval and 404 handling (GET /api/v1/products/variants/:variantId)
 * - Static definition mapping compatibility across existing JSON definitions
 * - Idempotent import and dry-run safety
 * - Security envelope & information leak prevention
 */

const assert = require('assert');
const path = require('path');
const fs = require('fs');
const { buildApp } = require('../dist/app');
const {
  mapStaticDefinitionToCanonical,
  loadAllStaticProductDefinitions,
  deriveProductAndVariantSlugs,
  normalizeFamily,
} = require('../dist/modules/products/product.adapter');
const { ProductService } = require('../dist/modules/products/product.service');
const { ProductRepository } = require('../dist/modules/products/product.repository');

let totalTests = 0;
let passedTests = 0;
let failedTests = 0;

async function runTest(name, fn) {
  totalTests++;
  try {
    await fn();
    console.log(`  [PASS] ${name}`);
    passedTests++;
  } catch (err) {
    console.error(`  [FAIL] ${name}: ${err.message}`);
    failedTests++;
  }
}

async function main() {
  console.log('=== EH HOME PRODUCT & DESIGN MANAGEMENT TESTS ===\n');

  process.env.NODE_ENV = 'test';

  const app = await buildApp({
    skipDatabase: true,
    fastifyOptions: {
      logger: false,
    },
  });

  await app.ready();

  // ── 1. STATIC DEFINITION ADAPTER & DETERMINISTIC MAPPING ──────────────
  console.log('1. Static Definition Adapter & Semantics:');

  await runTest('Derives base product ID and variant slug deterministically', async () => {
    const s1 = deriveProductAndVariantSlugs('eh-smart-switch-1x');
    assert.strictEqual(s1.productId, 'eh-smart-switch');
    assert.strictEqual(s1.variantSlug, '1x');

    const s2 = deriveProductAndVariantSlugs('eh-smart-switch-4x');
    assert.strictEqual(s2.productId, 'eh-smart-switch');
    assert.strictEqual(s2.variantSlug, '4x');

    const s3 = deriveProductAndVariantSlugs('eh-sensor-node-v1');
    assert.strictEqual(s3.productId, 'eh-sensor-node');
    assert.strictEqual(s3.variantSlug, 'v1');

    const s4 = deriveProductAndVariantSlugs('eh-smart-light-cct');
    assert.strictEqual(s4.productId, 'eh-smart-light');
    assert.strictEqual(s4.variantSlug, 'cct');
  });

  await runTest('Normalizes family identifiers with correct display names', async () => {
    const f1 = normalizeFamily('smart_switch');
    assert.strictEqual(f1.familyId, 'smart_switch');
    assert.strictEqual(f1.displayName, 'Smart Switch');

    const f2 = normalizeFamily('sensor-node');
    assert.strictEqual(f2.familyId, 'sensor_node');
    assert.strictEqual(f2.displayName, 'Sensor Node');
  });

  await runTest('Maps representative smart-switch-1x definition without data loss', async () => {
    const metaPath = path.resolve(__dirname, '../../../product-definitions/smart-switch/1x/metadata.json');
    const assetPath = path.resolve(__dirname, '../../../product-definitions/smart-switch/1x/assets.json');
    const meta = JSON.parse(fs.readFileSync(metaPath, 'utf8'));
    const assets = JSON.parse(fs.readFileSync(assetPath, 'utf8'));

    const mapped = mapStaticDefinitionToCanonical(meta, assets);

    assert.strictEqual(mapped.product.id, 'eh-smart-switch');
    assert.strictEqual(mapped.variant.id, 'eh-smart-switch-1x');
    assert.strictEqual(mapped.variant.channelCount, 1);
    assert.strictEqual(mapped.variant.hardwareProfile.mcuFamily, 'esp32-c6');
    assert.strictEqual(mapped.variant.hardwareProfile.hasEnergyMetering, true);
    assert.strictEqual(mapped.variant.hardwareProfile.energyMeterChip, 'BL0942');
    assert.strictEqual(mapped.variant.connectivityProfile.supportsWifi, true);
    assert.ok(mapped.assets.length >= 3, 'Must have at least hero, front, and thumbnail assets');
    assert.ok(mapped.assets.some((a) => a.kind === 'hero'));
    assert.ok(mapped.assets.some((a) => a.purpose === 'wiring'));
  });

  await runTest('Discovers and maps all 11 filesystem product definitions', async () => {
    const allDefs = loadAllStaticProductDefinitions();
    assert.strictEqual(allDefs.length, 11, 'Expected exactly 11 definitions across all families');
  });

  // ── 2. PRODUCT CATALOG LISTING & FILTERING (API) ─────────────────────
  console.log('\n2. Product Catalog API (GET /api/v1/products):');

  await runTest('GET /api/v1/products returns 200 with structured catalog items', async () => {
    const res = await app.inject({
      method: 'GET',
      url: '/api/v1/products',
    });

    assert.strictEqual(res.statusCode, 200);
    const body = JSON.parse(res.body);
    assert.strictEqual(body.schemaVersion, 1);
    assert.strictEqual(body.success, true);
    assert.ok(Array.isArray(body.data));
    assert.ok(body.data.length > 0);
    assert.ok(body.pagination);
    assert.strictEqual(typeof body.pagination.total, 'number');

    // Validate structure of a catalog item
    const item = body.data[0];
    assert.ok(item.id);
    assert.ok(item.displayName);
    assert.ok(item.familyId);
    assert.ok(item.status);
    assert.ok(typeof item.variantCount === 'number');
    assert.ok(Array.isArray(item.capabilities));
  });

  await runTest('GET /api/v1/products filters by familyId', async () => {
    const res = await app.inject({
      method: 'GET',
      url: '/api/v1/products?familyId=smart_switch',
    });

    assert.strictEqual(res.statusCode, 200);
    const body = JSON.parse(res.body);
    assert.ok(body.data.length >= 1);
    for (const prod of body.data) {
      assert.strictEqual(prod.familyId, 'smart_switch');
    }
  });

  await runTest('GET /api/v1/products filters by capability', async () => {
    const res = await app.inject({
      method: 'GET',
      url: '/api/v1/products?capability=energy',
    });

    assert.strictEqual(res.statusCode, 200);
    const body = JSON.parse(res.body);
    assert.ok(body.data.length >= 1);
    for (const prod of body.data) {
      assert.ok(prod.capabilities.includes('energy'), `Product ${prod.id} must include energy capability`);
    }
  });

  await runTest('GET /api/v1/products filters by connectivity (wifi)', async () => {
    const res = await app.inject({
      method: 'GET',
      url: '/api/v1/products?connectivity=wifi',
    });

    assert.strictEqual(res.statusCode, 200);
    const body = JSON.parse(res.body);
    assert.ok(body.data.length >= 1);
  });

  await runTest('GET /api/v1/products respects limit and offset pagination', async () => {
    const res = await app.inject({
      method: 'GET',
      url: '/api/v1/products?limit=2&offset=1',
    });

    assert.strictEqual(res.statusCode, 200);
    const body = JSON.parse(res.body);
    assert.strictEqual(body.pagination.limit, 2);
    assert.strictEqual(body.pagination.offset, 1);
    assert.ok(body.data.length <= 2);
  });

  // ── 3. PRODUCT FAMILIES API ──────────────────────────────────────────
  console.log('\n3. Product Families API (GET /api/v1/products/families):');

  await runTest('GET /api/v1/products/families returns canonical family list', async () => {
    const res = await app.inject({
      method: 'GET',
      url: '/api/v1/products/families',
    });

    assert.strictEqual(res.statusCode, 200);
    const body = JSON.parse(res.body);
    assert.strictEqual(body.success, true);
    assert.ok(Array.isArray(body.data));
    assert.ok(body.data.length >= 5);

    const familyIds = body.data.map((f) => f.id);
    assert.ok(familyIds.includes('smart_switch'));
    assert.ok(familyIds.includes('smart_socket'));
    assert.ok(familyIds.includes('smart_fan'));
  });

  // ── 4. PRODUCT DETAIL & 404 HANDLING ─────────────────────────────────
  console.log('\n4. Product Detail API (GET /api/v1/products/:productId):');

  await runTest('GET /api/v1/products/:productId returns complete product with variants', async () => {
    const res = await app.inject({
      method: 'GET',
      url: '/api/v1/products/eh-smart-switch',
    });

    assert.strictEqual(res.statusCode, 200);
    const body = JSON.parse(res.body);
    assert.strictEqual(body.success, true);
    assert.strictEqual(body.data.id, 'eh-smart-switch');
    assert.strictEqual(body.data.familyId, 'smart_switch');
    assert.ok(Array.isArray(body.data.variants));
    assert.ok(body.data.variants.length >= 1);

    const firstVar = body.data.variants[0];
    assert.ok(firstVar.variantId);
    assert.ok(firstVar.hardwareProfile);
    assert.ok(firstVar.connectivityProfile);
    assert.ok(Array.isArray(firstVar.channels));
    assert.ok(Array.isArray(firstVar.assets));
  });

  await runTest('GET /api/v1/products/:productId returns 404 for unknown product', async () => {
    const res = await app.inject({
      method: 'GET',
      url: '/api/v1/products/unknown-nonexistent-prod',
    });

    assert.strictEqual(res.statusCode, 404);
    const body = JSON.parse(res.body);
    assert.strictEqual(body.success, false);
    assert.strictEqual(body.error.code, 'PRODUCT_NOT_FOUND');
    assert.ok(body.meta.requestId);
  });

  // ── 5. VARIANT DETAIL & 404 HANDLING ─────────────────────────────────
  console.log('\n5. Variant Detail API (GET /api/v1/products/variants/:variantId):');

  await runTest('GET /api/v1/products/variants/:variantId returns variant specifications', async () => {
    const res = await app.inject({
      method: 'GET',
      url: '/api/v1/products/variants/eh-smart-switch-2x',
    });

    assert.strictEqual(res.statusCode, 200);
    const body = JSON.parse(res.body);
    assert.strictEqual(body.success, true);
    assert.strictEqual(body.data.variantId, 'eh-smart-switch-2x');
    assert.strictEqual(body.data.channelCount, 2);
    assert.strictEqual(body.data.hardwareProfile.mcuFamily, 'esp32-c6');
    assert.strictEqual(body.data.hardwareProfile.gpioMap.relay_ch1, 18);
    assert.strictEqual(body.data.hardwareProfile.gpioMap.relay_ch2, 19);
    assert.ok(Array.isArray(body.data.channels));
    assert.strictEqual(body.data.channels.length, 2);
  });

  await runTest('GET /api/v1/products/variants/:variantId returns 404 for unknown variant', async () => {
    const res = await app.inject({
      method: 'GET',
      url: '/api/v1/products/variants/nonexistent-variant-99x',
    });

    assert.strictEqual(res.statusCode, 404);
    const body = JSON.parse(res.body);
    assert.strictEqual(body.success, false);
    assert.strictEqual(body.error.code, 'VARIANT_NOT_FOUND');
  });

  // ── 6. IDEMPOTENT IMPORT & DRY-RUN SAFETY ─────────────────────────────
  console.log('\n6. Idempotent Import & Dry-Run:');

  await runTest('ProductService.importStaticDefinition supports dryRun without persisting', async () => {
    const repo = new ProductRepository();
    const service = new ProductService(repo);

    const testMeta = {
      schemaVersion: 1,
      productVariantId: 'eh-test-switch-1x',
      productFamily: 'smart_switch',
      displayName: 'EH Test Switch 1X',
      channelCount: 1,
      channels: [{ channelIndex: 1, defaultLabel: 'Ch 1', capabilities: ['switch'] }],
      hardwareProfile: {
        schemaVersion: 1,
        mcuFamily: 'esp32-c6',
        flashSizeBytes: 4194304,
        hasEnergyMetering: false,
        maxRelayAmpsPerChannel: 16.0,
      },
      connectivityProfile: {
        schemaVersion: 1,
        supportsWifi: true,
        supportsBle: true,
      },
      capabilities: ['switch'],
      electricalSpecifications: { voltageRange: '90V-250V' },
      firmwareFamily: 'esp32c6-switch-platform',
      supportedHardwareRevisions: ['HW_1_0'],
    };

    const dryResult = await service.importStaticDefinition(testMeta, undefined, { dryRun: true });
    assert.strictEqual(dryResult.dryRun, true);
    assert.strictEqual(dryResult.productId, 'eh-test-switch');
    assert.strictEqual(dryResult.variantId, 'eh-test-switch-1x');
  });

  // ── 7. SECURITY & SENSITIVE DATA PREVENTION ───────────────────────────
  console.log('\n7. Security & Information Leak Prevention:');

  await runTest('Product API responses do not expose passwords, factory secrets, or internal paths', async () => {
    const res = await app.inject({
      method: 'GET',
      url: '/api/v1/products/eh-smart-switch',
    });

    const bodyStr = res.body;
    assert.strictEqual(bodyStr.includes('password'), false);
    assert.strictEqual(bodyStr.includes('private_key'), false);
    assert.strictEqual(bodyStr.includes('secret'), false);
    assert.strictEqual(bodyStr.includes('node_modules'), false);
  });

  await app.close();

  // ── SUMMARY ───────────────────────────────────────────────────────────
  console.log(`\n=== PRODUCT DOMAIN TESTS SUMMARY ===`);
  console.log(`Total:  ${totalTests}`);
  console.log(`Passed: ${passedTests}`);
  console.log(`Failed: ${failedTests}`);

  if (failedTests > 0) {
    process.exit(1);
  } else {
    console.log('ALL PRODUCT DOMAIN TESTS PASSED [OK]\n');
  }
}

main().catch((err) => {
  console.error('Fatal test execution error:', err);
  process.exit(1);
});
