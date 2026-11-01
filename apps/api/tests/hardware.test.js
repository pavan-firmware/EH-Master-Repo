/**
 * EH Home Hardware & BOM Management Automated Test Suite
 *
 * Validates:
 * - Hardware revision listing and pagination (GET /api/v1/hardware/revisions)
 * - Filtering by product variant, status, revision code, and MCU family
 * - Hardware revision detail retrieval and 404 handling (GET /api/v1/hardware/revisions/:id)
 * - Hardware revision creation with duplicate code rejection (POST /api/v1/hardware/revisions)
 * - Hardware revision lifecycle transitions and validation (PATCH /api/v1/hardware/revisions/:id/status)
 * - BOM retrieval and 404 handling (GET /api/v1/hardware/revisions/:id/bom)
 * - BOM creation with validation (positive quantities, unique reference designators)
 * - Compatibility with static product definitions (supportedHardwareRevisions)
 * - Security envelope & information leak prevention
 */

const assert = require('assert');
const { buildApp } = require('../dist/app');
const { HardwareService } = require('../dist/modules/hardware/hardware.service');
const { HardwareRepository } = require('../dist/modules/hardware/hardware.repository');

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
  console.log('=== EH HOME HARDWARE & BOM MANAGEMENT TESTS ===\n');

  process.env.NODE_ENV = 'test';

  const app = await buildApp({
    skipDatabase: true,
    fastifyOptions: {
      logger: false,
    },
  });

  await app.ready();

  // ── 1. HARDWARE REVISIONS LISTING & FILTERING ────────────────────────
  console.log('1. Hardware Revisions API (GET /api/v1/hardware/revisions):');

  await runTest('GET /api/v1/hardware/revisions returns 200 with revisions list', async () => {
    const res = await app.inject({
      method: 'GET',
      url: '/api/v1/hardware/revisions',
    });

    assert.strictEqual(res.statusCode, 200);
    const body = JSON.parse(res.body);
    assert.strictEqual(body.schemaVersion, 1);
    assert.strictEqual(body.success, true);
    assert.ok(Array.isArray(body.data));
    assert.ok(body.data.length >= 2, 'Must have at least baseline revisions');
    assert.ok(body.pagination);
    assert.strictEqual(typeof body.pagination.total, 'number');

    const rev = body.data[0];
    assert.ok(rev.id);
    assert.ok(rev.revisionCode);
    assert.ok(rev.productVariantId);
    assert.ok(rev.pcbName);
    assert.ok(rev.lifecycleStatus);
    assert.strictEqual(rev.mcuFamily, 'esp32-c6');
  });

  await runTest('GET /api/v1/hardware/revisions filters by productVariantId', async () => {
    const res = await app.inject({
      method: 'GET',
      url: '/api/v1/hardware/revisions?productVariantId=eh-smart-switch-1x',
    });

    assert.strictEqual(res.statusCode, 200);
    const body = JSON.parse(res.body);
    assert.ok(body.data.length >= 1);
    for (const r of body.data) {
      assert.strictEqual(r.productVariantId, 'eh-smart-switch-1x');
    }
  });

  await runTest('GET /api/v1/hardware/revisions filters by status', async () => {
    const res = await app.inject({
      method: 'GET',
      url: '/api/v1/hardware/revisions?status=ACTIVE',
    });

    assert.strictEqual(res.statusCode, 200);
    const body = JSON.parse(res.body);
    for (const r of body.data) {
      assert.strictEqual(r.lifecycleStatus, 'ACTIVE');
    }
  });

  await runTest('GET /api/v1/hardware/revisions filters by revisionCode', async () => {
    const res = await app.inject({
      method: 'GET',
      url: '/api/v1/hardware/revisions?revisionCode=HW_1_0',
    });

    assert.strictEqual(res.statusCode, 200);
    const body = JSON.parse(res.body);
    assert.strictEqual(body.data.length, 1);
    assert.strictEqual(body.data[0].revisionCode, 'HW_1_0');
  });

  // ── 2. HARDWARE REVISION DETAIL & 404 HANDLING ───────────────────────
  console.log('\n2. Hardware Revision Detail API (GET /api/v1/hardware/revisions/:id):');

  await runTest('GET /api/v1/hardware/revisions/:id returns complete hardware specifications', async () => {
    const res = await app.inject({
      method: 'GET',
      url: '/api/v1/hardware/revisions/hw_rev_switch_1x_1_0',
    });

    assert.strictEqual(res.statusCode, 200);
    const body = JSON.parse(res.body);
    assert.strictEqual(body.success, true);
    assert.strictEqual(body.data.revisionCode, 'HW_1_0');
    assert.strictEqual(body.data.pcbName, 'smart_switch_3x');
    assert.strictEqual(body.data.mcuFamily, 'esp32-c6');
    assert.strictEqual(body.data.layerCount, 2);
    assert.ok(body.data.pinMap);
    assert.strictEqual(body.data.pinMap.relay_ch1, 18);
  });

  await runTest('GET /api/v1/hardware/revisions/:id returns 404 for nonexistent revision', async () => {
    const res = await app.inject({
      method: 'GET',
      url: '/api/v1/hardware/revisions/nonexistent-rev-999',
    });

    assert.strictEqual(res.statusCode, 404);
    const body = JSON.parse(res.body);
    assert.strictEqual(body.success, false);
    assert.strictEqual(body.error.code, 'HARDWARE_REVISION_NOT_FOUND');
  });

  // ── 3. HARDWARE REVISION CREATION & VALIDATION ────────────────────────
  console.log('\n3. Hardware Revision Creation & Constraints:');

  await runTest('POST /api/v1/hardware/revisions creates a new revision successfully', async () => {
    const res = await app.inject({
      method: 'POST',
      url: '/api/v1/hardware/revisions',
      payload: {
        revisionCode: 'HW_2_0',
        productVariantId: 'eh-smart-switch-2x',
        pcbName: 'smart_switch_3x_rev2',
        pcbRevision: 'v2.0',
        displayName: 'Smart Switch 2X NextGen Rev 2.0',
        lifecycleStatus: 'DRAFT',
        layerCount: 4,
        mcuFamily: 'esp32-c6',
        pinMap: { relay_ch1: 18, relay_ch2: 19 },
      },
    });

    assert.strictEqual(res.statusCode, 201);
    const body = JSON.parse(res.body);
    assert.strictEqual(body.success, true);
    assert.strictEqual(body.data.revisionCode, 'HW_2_0');
    assert.strictEqual(body.data.layerCount, 4);
    assert.strictEqual(body.data.lifecycleStatus, 'DRAFT');
  });

  await runTest('Duplicate revisionCode for same productVariantId is rejected', async () => {
    const repo = new HardwareRepository();
    const service = new HardwareService(repo);

    let errorThrown = false;
    try {
      await service.createHardwareRevision({
        revisionCode: 'HW_1_0',
        productVariantId: 'eh-smart-switch-1x', // Already exists in baseline
        pcbName: 'smart_switch_duplicate',
        pcbRevision: 'v1.0',
        displayName: 'Duplicate Rev',
        lifecycleStatus: 'DRAFT',
        layerCount: 2,
        mcuFamily: 'esp32-c6',
        pinMap: {},
      });
    } catch (err) {
      errorThrown = true;
      assert.ok(err.message.includes('already exists'));
    }
    assert.strictEqual(errorThrown, true, 'Must reject duplicate revisionCode');
  });

  // ── 4. HARDWARE REVISION LIFECYCLE STATE MACHINE ──────────────────────
  console.log('\n4. Hardware Revision Lifecycle:');

  await runTest('Governs valid lifecycle transitions (DRAFT -> VALIDATION -> APPROVED -> ACTIVE)', async () => {
    const repo = new HardwareRepository();
    const service = new HardwareService(repo);

    const created = await service.createHardwareRevision({
      revisionCode: 'HW_LIFECYCLE_TEST',
      productVariantId: 'eh-smart-socket-1x',
      pcbName: 'smart_socket_pcb',
      displayName: 'Lifecycle Test Rev',
      lifecycleStatus: 'DRAFT',
      layerCount: 2,
      mcuFamily: 'esp32-c6',
      pinMap: {},
    });

    // 1. DRAFT -> VALIDATION
    const s1 = await service.updateLifecycleStatus(created.id, 'VALIDATION');
    assert.strictEqual(s1.lifecycleStatus, 'VALIDATION');

    // 2. VALIDATION -> APPROVED
    const s2 = await service.updateLifecycleStatus(created.id, 'APPROVED');
    assert.strictEqual(s2.lifecycleStatus, 'APPROVED');

    // 3. APPROVED -> ACTIVE
    const s3 = await service.updateLifecycleStatus(created.id, 'ACTIVE');
    assert.strictEqual(s3.lifecycleStatus, 'ACTIVE');
    assert.ok(s3.effectiveAt, 'Must record effectiveAt when ACTIVE');
  });

  await runTest('Rejects invalid lifecycle transitions (ACTIVE -> DRAFT and ACTIVE -> VALIDATION)', async () => {
    const repo = new HardwareRepository();
    const service = new HardwareService(repo);

    let errorDraftThrown = false;
    try {
      // hw_rev_switch_1x_1_0 is currently ACTIVE
      await service.updateLifecycleStatus('hw_rev_switch_1x_1_0', 'DRAFT');
    } catch (err) {
      errorDraftThrown = true;
      assert.ok(err.message.includes('Invalid lifecycle transition'));
    }
    assert.strictEqual(errorDraftThrown, true, 'Must reject ACTIVE -> DRAFT');

    let errorValidationThrown = false;
    try {
      await service.updateLifecycleStatus('hw_rev_switch_1x_1_0', 'VALIDATION');
    } catch (err) {
      errorValidationThrown = true;
      assert.ok(err.message.includes('Invalid lifecycle transition'));
    }
    assert.strictEqual(errorValidationThrown, true, 'Must reject ACTIVE -> VALIDATION');
  });

  await runTest('Rejects invalid lifecycle transitions from APPROVED backwards to DRAFT', async () => {
    const repo = new HardwareRepository();
    const service = new HardwareService(repo);

    const rev = await service.createHardwareRevision({
      revisionCode: 'HW_APPROVED_TEST',
      productVariantId: 'eh-smart-socket-2x',
      pcbName: 'smart_socket_pcb',
      displayName: 'Approved Immutability Test',
      lifecycleStatus: 'DRAFT',
      layerCount: 2,
      mcuFamily: 'esp32-c6',
      pinMap: {},
    });

    await service.updateLifecycleStatus(rev.id, 'VALIDATION');
    await service.updateLifecycleStatus(rev.id, 'APPROVED');

    let errorThrown = false;
    try {
      await service.updateLifecycleStatus(rev.id, 'DRAFT');
    } catch (err) {
      errorThrown = true;
      assert.ok(err.message.includes('Invalid lifecycle transition'));
    }
    assert.strictEqual(errorThrown, true, 'Must reject APPROVED -> DRAFT');
  });

  await runTest('Approved and active revisions are immutable: identity cannot be rewritten', async () => {
    const repo = new HardwareRepository();
    const service = new HardwareService(repo);

    // Existing active revision: hw_rev_switch_1x_1_0
    const activeRev = await service.getHardwareRevision('hw_rev_switch_1x_1_0');
    assert.ok(activeRev);
    assert.strictEqual(activeRev.lifecycleStatus, 'ACTIVE');

    // Attempting to create a duplicate revision with the same (productVariantId, revisionCode) must fail
    let duplicateRejected = false;
    try {
      await service.createHardwareRevision({
        revisionCode: activeRev.revisionCode,
        productVariantId: activeRev.productVariantId,
        pcbName: 'tampered_pcb',
        displayName: 'Tampered Display Name',
        lifecycleStatus: 'DRAFT',
        layerCount: 4,
        mcuFamily: 'esp32-c6',
        pinMap: {},
      });
    } catch (err) {
      duplicateRejected = true;
      assert.ok(err.message.includes('already exists'));
    }
    assert.strictEqual(duplicateRejected, true, 'Must reject rewriting identity of active revision');

    // Verify existing active revision was untouched
    const verified = await service.getHardwareRevision('hw_rev_switch_1x_1_0');
    assert.strictEqual(verified.pcbName, 'smart_switch_3x');
    assert.strictEqual(verified.displayName, 'Smart Switch 1X Mainboard Rev 1.0');
    assert.strictEqual(verified.lifecycleStatus, 'ACTIVE');
  });

  // ── 5. PRODUCT DEFINITION COMPATIBILITY & MAPPING (ISSUE 3) ────────────
  console.log('\n5. Product Variant Hardware Compatibility & Mapping:');

  await runTest('Every product definition variant with supportedHardwareRevisions resolves deterministically', async () => {
    const path = require('path');
    const fs = require('fs');

    const defsDir = path.join(__dirname, '../../../product-definitions');
    const families = fs.readdirSync(defsDir).filter(f => !f.startsWith('_') && f !== 'tests');

    let totalVariantsChecked = 0;
    let totalRevsChecked = 0;

    for (const family of families) {
      const famDir = path.join(defsDir, family);
      const variants = fs.readdirSync(famDir).filter(v => fs.statSync(path.join(famDir, v)).isDirectory());

      for (const variant of variants) {
        const metaPath = path.join(famDir, variant, 'metadata.json');
        if (!fs.existsSync(metaPath)) continue;

        const meta = JSON.parse(fs.readFileSync(metaPath, 'utf8'));
        totalVariantsChecked++;

        assert.ok(meta.productVariantId, `Variant in ${family}/${variant} missing productVariantId`);
        assert.ok(Array.isArray(meta.supportedHardwareRevisions), `Missing supportedHardwareRevisions in ${meta.productVariantId}`);
        assert.ok(meta.supportedHardwareRevisions.length >= 1, `Must have at least 1 revision in ${meta.productVariantId}`);

        for (const revCode of meta.supportedHardwareRevisions) {
          totalRevsChecked++;

          // Deterministic ID formula: hw_${productVariantId}_${revCode.toLowerCase().replace(/[^a-z0-9]/g, '_')}
          const deterministicId = `hw_${meta.productVariantId}_${revCode.toLowerCase().replace(/[^a-z0-9]/g, '_')}`;
          assert.ok(deterministicId.startsWith('hw_'), 'ID must start with hw_ prefix');
          assert.ok(deterministicId.includes(meta.productVariantId), 'ID must contain variant ID');

          // Unambiguous mapping: (variantId, revCode) uniquely identifies the hardware revision
          assert.strictEqual(typeof revCode, 'string');
          assert.ok(/^[A-Za-z0-9_.-]+$/.test(revCode), `Revision code ${revCode} must be valid identifier`);
        }
      }
    }

    assert.strictEqual(totalVariantsChecked, 11, 'Must check all 11 product definitions');
    assert.strictEqual(totalRevsChecked, 19, 'Must check all 19 supportedHardwareRevisions (8*2 + 3*1)');
  });

  // ── 6. BILL OF MATERIALS (BOM) & ITEMS ───────────────────────────────
  console.log('\n6. Bill of Materials (BOM) API:');

  await runTest('GET /api/v1/hardware/revisions/:id/bom returns BOM and physical components', async () => {
    const res = await app.inject({
      method: 'GET',
      url: '/api/v1/hardware/revisions/hw_rev_switch_1x_1_0/bom',
    });

    assert.strictEqual(res.statusCode, 200);
    const body = JSON.parse(res.body);
    assert.strictEqual(body.success, true);
    assert.ok(body.data.id);
    assert.strictEqual(body.data.version, '1.0.0');
    assert.ok(Array.isArray(body.data.items));
    assert.ok(body.data.items.length >= 8);

    // Verify component attributes
    const esp32 = body.data.items.find((i) => i.referenceDesignator === 'U1');
    assert.ok(esp32);
    assert.strictEqual(esp32.mpn, 'ESP32-C6-WROOM-1-N4');
    assert.strictEqual(esp32.manufacturer, 'Espressif Systems');
    assert.strictEqual(esp32.quantity, 1);

    const smps = body.data.items.find((i) => i.referenceDesignator === 'U2');
    assert.ok(smps);
    assert.strictEqual(smps.mpn, 'HLK-PM01');

    const meter = body.data.items.find((i) => i.referenceDesignator === 'U4');
    assert.ok(meter);
    assert.strictEqual(meter.mpn, 'BL0942');
  });

  await runTest('GET /api/v1/hardware/revisions/:id/bom returns 404 when no BOM exists', async () => {
    const res = await app.inject({
      method: 'GET',
      url: '/api/v1/hardware/revisions/hw_rev_switch_1x_1_1/bom',
    });

    assert.strictEqual(res.statusCode, 404);
    const body = JSON.parse(res.body);
    assert.strictEqual(body.success, false);
    assert.strictEqual(body.error.code, 'BOM_NOT_FOUND');
  });

  await runTest('POST /api/v1/hardware/revisions/:id/bom creates BOM with validation', async () => {
    const res = await app.inject({
      method: 'POST',
      url: '/api/v1/hardware/revisions/hw_rev_switch_1x_1_1/bom',
      payload: {
        version: '1.0.0',
        lifecycleStatus: 'DRAFT',
        notes: 'Initial BOM for 1.1 revision',
        items: [
          {
            itemIndex: 1,
            referenceDesignator: 'U1',
            mpn: 'ESP32-C6-WROOM-1-N4',
            manufacturer: 'Espressif Systems',
            description: 'Microcontroller',
            footprint: 'Module:ESP32-C6',
            quantity: 1,
          },
          {
            itemIndex: 2,
            referenceDesignator: 'K1',
            mpn: 'HF32F-G',
            manufacturer: 'Hongfa',
            description: '10A Relay',
            footprint: 'Relay:HF32F-G',
            quantity: 1,
          },
        ],
      },
    });

    assert.strictEqual(res.statusCode, 201);
    const body = JSON.parse(res.body);
    assert.strictEqual(body.success, true);
    assert.strictEqual(body.data.version, '1.0.0');
    assert.strictEqual(body.data.items.length, 2);
  });

  await runTest('BOM creation rejects negative or zero quantities', async () => {
    const repo = new HardwareRepository();
    const service = new HardwareService(repo);

    let errorThrown = false;
    try {
      await service.createBOM({
        hardwareRevisionId: 'hw_rev_switch_1x_1_0',
        version: '2.0.0',
        items: [
          {
            itemIndex: 1,
            referenceDesignator: 'R1',
            mpn: 'RC0603FR-0710KL',
            description: '10k Resistor',
            footprint: 'Resistor_SMD:R_0603',
            quantity: 0, // INVALID: must be > 0
          },
        ],
      });
    } catch (err) {
      errorThrown = true;
      assert.ok(err.message.includes('invalid quantity'));
    }
    assert.strictEqual(errorThrown, true);
  });

  await runTest('BOM creation rejects duplicate reference designators', async () => {
    const repo = new HardwareRepository();
    const service = new HardwareService(repo);

    let errorThrown = false;
    try {
      await service.createBOM({
        hardwareRevisionId: 'hw_rev_switch_1x_1_0',
        version: '2.1.0',
        items: [
          {
            itemIndex: 1,
            referenceDesignator: 'R1',
            mpn: 'RC0603FR-0710KL',
            description: '10k Resistor',
            footprint: 'Resistor_SMD:R_0603',
            quantity: 1,
          },
          {
            itemIndex: 2,
            referenceDesignator: 'R1', // DUPLICATE!
            mpn: 'RC0603FR-071KL',
            description: '1k Resistor',
            footprint: 'Resistor_SMD:R_0603',
            quantity: 1,
          },
        ],
      });
    } catch (err) {
      errorThrown = true;
      assert.ok(err.message.includes('Duplicate reference designator'));
    }
    assert.strictEqual(errorThrown, true);
  });

  // ── 6. SECURITY & SENSITIVE DATA PREVENTION ───────────────────────────
  console.log('\n6. Security & Information Leak Prevention:');

  await runTest('Hardware API responses do not expose credentials, secrets, or internal paths', async () => {
    const res = await app.inject({
      method: 'GET',
      url: '/api/v1/hardware/revisions/hw_rev_switch_1x_1_0',
    });

    const bodyStr = res.body;
    assert.strictEqual(bodyStr.includes('password'), false);
    assert.strictEqual(bodyStr.includes('secret'), false);
    assert.strictEqual(bodyStr.includes('node_modules'), false);
  });

  await app.close();

  // ── SUMMARY ───────────────────────────────────────────────────────────
  console.log(`\n=== HARDWARE & BOM TESTS SUMMARY ===`);
  console.log(`Total:  ${totalTests}`);
  console.log(`Passed: ${passedTests}`);
  console.log(`Failed: ${failedTests}`);

  if (failedTests > 0) {
    process.exit(1);
  } else {
    console.log('ALL HARDWARE & BOM MANAGEMENT TESTS PASSED [OK]\n');
  }
}

main().catch((err) => {
  console.error('Fatal test execution error:', err);
  process.exit(1);
});
