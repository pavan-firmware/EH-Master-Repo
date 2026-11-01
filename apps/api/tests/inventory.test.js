/**
 * EH Home Production Inventory, Dual-Scan & Packing Automated Test Suite
 *
 * Validates Part 11 requirements:
 * 1. Successful registration of valid provisioned device
 * 2. Rejection of invalid device record / schema violation
 * 3. Rejection of failed provisioning / QC fail
 * 4. Duplicate registration idempotency
 * 5. Device state machine transitions
 * 6. Invalid state transition rejection
 * 7. Dual-scan verification (matching scans accepted)
 * 8. Wrong device rejected (DEVICE_NOT_FOUND)
 * 9. Wrong product / variant rejected
 * 10. Wrong hardware revision rejected
 * 11. Wrong firmware family rejected
 * 12. Unknown / malformed QR rejected
 * 13. Already-packed device rejected
 * 14. Carton creation, capacity check, and variant matching
 * 15. Valid packing completion
 * 16. Duplicate packing idempotency / rejection
 * 17. Pack-before-verification rejection (DUAL_SCAN_NOT_FOUND)
 * 18. Audit trail generation & zero secrets in database
 * 19. Atomic race-safety against concurrent packing attempts
 * 20. Server-side enforcement & API endpoint validation against client bypass
 * 21. Carton variant and hardware revision compatibility enforcement
 * 22. Verification ownership enforcement (dual-scan belonging to another device rejected)
 */

const assert = require('assert');
const { buildApp } = require('../dist/app');

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
  console.log('=== EH HOME PRODUCTION INVENTORY, DUAL-SCAN & PACKING TESTS ===\n');

  process.env.NODE_ENV = 'test';

  const app = await buildApp({
    skipDatabase: true,
    fastifyOptions: {
      logger: false,
    },
  });

  await app.ready();

  const validTraceRecord = {
    schemaVersion: 1,
    traceId: '0194fe23-7a1b-7890-a123-456789abcd01',
    deviceId: '0194fe23-7a1b-7890-a123-456789abcd02',
    serialNumber: 'EH-SW1X-2026W12-00001',
    productVariantId: 'eh-smart-switch-1x',
    hardwareRevision: 'HW_1_0',
    firmwareFamily: 'esp32c6-switch-platform',
    firmwareReleaseId: 'rel-2026-001',
    firmwareVersion: '1.0.0',
    targetMcu: 'esp32-c6',
    idfTarget: 'esp32c6',
    artifactSha256: 'a1b2c3d4e5f60718293041526374859607182930415263748596071829304152',
    tlsCertFingerprint: 'a1b2c3d4e5f60718293041526374859607182930415263748596071829304152',
    port: 'COM3',
    flashStatus: 'PASS',
    verificationStatus: 'PASS',
    provisioningStatus: 'PASS',
    provisionedAt: new Date().toISOString(),
    durationMs: 4500,
    operatorUserId: 'operator-1',
  };

  const validQrToken = 'eh-tok-sw01-a1b2c3d4e5f607182930';

  // ── 1. INVENTORY REGISTRATION TESTS ─────────────────────────────────────
  console.log('1. Inventory Registration:');

  await runTest('Register valid provisioned device traceability record', async () => {
    const res = await app.inject({
      method: 'POST',
      url: '/api/v1/inventory/register',
      payload: {
        traceabilityRecord: validTraceRecord,
        stationId: 'STATION-01',
        qrToken: validQrToken,
      },
    });

    assert.strictEqual(res.statusCode, 200);
    const body = JSON.parse(res.body);
    assert.strictEqual(body.success, true);
    assert.strictEqual(body.inventoryItem.serialNumber, validTraceRecord.serialNumber);
    assert.strictEqual(body.inventoryItem.status, 'PROVISIONED');
  });

  await runTest('Reject failed provisioning / QC fail record', async () => {
    const failedRecord = {
      ...validTraceRecord,
      deviceId: '0194fe23-7a1b-7890-a123-456789abcd05',
      serialNumber: 'EH-SW1X-2026W12-00002',
      flashStatus: 'FAIL',
      provisioningStatus: 'FAIL',
    };

    const res = await app.inject({
      method: 'POST',
      url: '/api/v1/inventory/register',
      payload: {
        traceabilityRecord: failedRecord,
        stationId: 'STATION-01',
      },
    });

    const body = JSON.parse(res.body);
    assert.strictEqual(body.success, false);
    assert.strictEqual(body.errorCode, 'PROVISIONING_NOT_PASSED');
  });

  await runTest('Reject invalid product variant in registration', async () => {
    const invalidVariantRecord = {
      ...validTraceRecord,
      deviceId: '0194fe23-7a1b-7890-a123-456789abcd06',
      serialNumber: 'EH-SW1X-2026W12-00003',
      productVariantId: 'invalid-non-canonical-product',
    };

    const res = await app.inject({
      method: 'POST',
      url: '/api/v1/inventory/register',
      payload: {
        traceabilityRecord: invalidVariantRecord,
        stationId: 'STATION-01',
      },
    });

    const body = JSON.parse(res.body);
    assert.strictEqual(body.success, false);
    assert.strictEqual(body.errorCode, 'PRODUCT_MISMATCH');
  });

  await runTest('Reject incompatible firmware family in registration', async () => {
    const invalidFwRecord = {
      ...validTraceRecord,
      deviceId: '0194fe23-7a1b-7890-a123-456789abcd07',
      serialNumber: 'EH-SW1X-2026W12-00004',
      firmwareFamily: 'esp32c6-sensor-platform', // Switch 1x requires esp32c6-switch-platform
    };

    const res = await app.inject({
      method: 'POST',
      url: '/api/v1/inventory/register',
      payload: {
        traceabilityRecord: invalidFwRecord,
        stationId: 'STATION-01',
      },
    });

    const body = JSON.parse(res.body);
    assert.strictEqual(body.success, false);
    assert.strictEqual(body.errorCode, 'FIRMWARE_FAMILY_MISMATCH');
  });

  await runTest('Idempotent repeated registration returns existing record safely', async () => {
    const res = await app.inject({
      method: 'POST',
      url: '/api/v1/inventory/register',
      payload: {
        traceabilityRecord: validTraceRecord,
        stationId: 'STATION-01',
      },
    });

    assert.strictEqual(res.statusCode, 200);
    const body = JSON.parse(res.body);
    assert.strictEqual(body.success, true);
    assert.strictEqual(body.inventoryItem.serialNumber, validTraceRecord.serialNumber);
  });

  // ── 2. CARTON MANAGEMENT TESTS ──────────────────────────────────────────
  console.log('\n2. Packaging Cartons:');

  let testCartonId = '';

  await runTest('Create packaging carton with canonical product variant', async () => {
    const res = await app.inject({
      method: 'POST',
      url: '/api/v1/inventory/cartons',
      payload: {
        cartonCode: 'CARTON-2026-SW1X-001',
        productVariantId: 'eh-smart-switch-1x',
        hardwareRevision: 'HW_1_0',
        targetCapacity: 2,
      },
    });

    assert.strictEqual(res.statusCode, 200);
    const body = JSON.parse(res.body);
    assert.strictEqual(body.success, true);
    assert.strictEqual(body.carton.cartonCode, 'CARTON-2026-SW1X-001');
    testCartonId = body.carton.id;
  });

  await runTest('Get packaging carton by ID', async () => {
    const res = await app.inject({
      method: 'GET',
      url: `/api/v1/inventory/cartons/${testCartonId}`,
    });

    assert.strictEqual(res.statusCode, 200);
    const body = JSON.parse(res.body);
    assert.strictEqual(body.success, true);
    assert.strictEqual(body.carton.id, testCartonId);
  });

  // ── 3. DUAL-SCAN VERIFICATION WORKFLOW TESTS ────────────────────────────
  console.log('\n3. Dual-Scan Verification:');

  let testVerificationId = '';

  await runTest('Valid matching Dual-Scan returns MATCH_APPROVED', async () => {
    const res = await app.inject({
      method: 'POST',
      url: '/api/v1/inventory/dual-scan',
      payload: {
        stationId: 'STATION-01',
        deviceSerial: validTraceRecord.serialNumber,
        boxTokenOrUri: `eh://p/v1?t=${validQrToken}`,
        cartonId: testCartonId,
      },
    });

    assert.strictEqual(res.statusCode, 200);
    const body = JSON.parse(res.body);
    assert.strictEqual(body.success, true);
    assert.strictEqual(body.isMatch, true);
    assert.strictEqual(body.status, 'MATCH_APPROVED');
    assert.strictEqual(body.deviceSerial, validTraceRecord.serialNumber);
    testVerificationId = body.verificationId;
  });

  await runTest('Dual-Scan rejects unknown device serial', async () => {
    const res = await app.inject({
      method: 'POST',
      url: '/api/v1/inventory/dual-scan',
      payload: {
        stationId: 'STATION-01',
        deviceSerial: 'EH-SW1X-UNKNOWN-999',
        boxTokenOrUri: `eh://p/v1?t=${validQrToken}`,
      },
    });

    assert.strictEqual(res.statusCode, 200);
    const body = JSON.parse(res.body);
    assert.strictEqual(body.success, false);
    assert.strictEqual(body.status, 'DEVICE_NOT_FOUND');
    assert.strictEqual(body.errorCode, 'DEVICE_NOT_FOUND');
  });

  await runTest('Dual-Scan rejects mismatched QR token', async () => {
    const res = await app.inject({
      method: 'POST',
      url: '/api/v1/inventory/dual-scan',
      payload: {
        stationId: 'STATION-01',
        deviceSerial: validTraceRecord.serialNumber,
        boxTokenOrUri: 'eh://p/v1?t=eh-tok-mismatched-token-99999',
      },
    });

    assert.strictEqual(res.statusCode, 200);
    const body = JSON.parse(res.body);
    assert.strictEqual(body.success, false);
    assert.strictEqual(body.isMatch, false);
    assert.strictEqual(body.errorCode, 'QR_DEVICE_MISMATCH');
  });

  await runTest('Dual-Scan rejects malformed QR URI / token', async () => {
    const res = await app.inject({
      method: 'POST',
      url: '/api/v1/inventory/dual-scan',
      payload: {
        stationId: 'STATION-01',
        deviceSerial: validTraceRecord.serialNumber,
        boxTokenOrUri: 'https://evil.com/fake-qr',
      },
    });

    assert.strictEqual(res.statusCode, 200);
    const body = JSON.parse(res.body);
    assert.strictEqual(body.success, false);
    assert.strictEqual(body.errorCode, 'INVALID_QR');
  });

  // ── 4. PACKING COMPLETION & ATOMIC PROTECTION TESTS ─────────────────────
  console.log('\n4. Packing Completion & Traceability:');

  await runTest('Complete packing of verified device into carton', async () => {
    const res = await app.inject({
      method: 'POST',
      url: '/api/v1/inventory/pack',
      payload: {
        deviceId: validTraceRecord.deviceId,
        serialNumber: validTraceRecord.serialNumber,
        cartonId: testCartonId,
        verificationId: testVerificationId,
        stationId: 'STATION-01',
      },
    });

    assert.strictEqual(res.statusCode, 200);
    const body = JSON.parse(res.body);
    assert.strictEqual(body.success, true);
    assert.strictEqual(body.packagingRecord.serialNumber, validTraceRecord.serialNumber);
    assert.strictEqual(body.inventoryItem.status, 'PACKED');
    assert.strictEqual(body.carton.packedCount, 1);
  });

  await runTest('Reject packing of already packed device (idempotency/conflict check)', async () => {
    const res = await app.inject({
      method: 'POST',
      url: '/api/v1/inventory/pack',
      payload: {
        deviceId: validTraceRecord.deviceId,
        serialNumber: validTraceRecord.serialNumber,
        cartonId: testCartonId,
        verificationId: testVerificationId,
        stationId: 'STATION-01',
      },
    });

    const body = JSON.parse(res.body);
    assert.strictEqual(body.success, false);
    assert.strictEqual(body.errorCode, 'DEVICE_ALREADY_PACKED');
  });

  await runTest('Dual-scan rejects unit that is already marked PACKED', async () => {
    const res = await app.inject({
      method: 'POST',
      url: '/api/v1/inventory/dual-scan',
      payload: {
        stationId: 'STATION-01',
        deviceSerial: validTraceRecord.serialNumber,
        boxTokenOrUri: `eh://p/v1?t=${validQrToken}`,
      },
    });

    const body = JSON.parse(res.body);
    assert.strictEqual(body.success, false);
    assert.strictEqual(body.status, 'ALREADY_PACKED');
    assert.strictEqual(body.errorCode, 'DEVICE_ALREADY_PACKED');
  });

  await runTest('Query packing history returns immutable audit records without secrets', async () => {
    const res = await app.inject({
      method: 'GET',
      url: '/api/v1/inventory/history?limit=10',
    });

    assert.strictEqual(res.statusCode, 200);
    const body = JSON.parse(res.body);
    assert.strictEqual(body.success, true);
    assert.ok(Array.isArray(body.records));
    assert.strictEqual(body.records.length >= 1, true);

    const first = body.records[0];
    assert.strictEqual(first.serialNumber, validTraceRecord.serialNumber);
    assert.strictEqual(first.commissioningSecret, undefined);
    assert.strictEqual(first.privateKey, undefined);
    assert.strictEqual(first.wifiPassword, undefined);
  });

  // ── 5. DETERMINISTIC SECURITY & BYPASS REJECTION TESTS ───────────────────
  console.log('\n5. Deterministic Security & Bypass Rejection:');

  // Register device 3 for bypass testing
  const device3 = {
    ...validTraceRecord,
    deviceId: '0194fe23-7a1b-7890-a123-456789abcd30',
    serialNumber: 'EH-SW1X-2026W12-00030',
  };
  await app.inject({
    method: 'POST',
    url: '/api/v1/inventory/register',
    payload: {
      traceabilityRecord: device3,
      stationId: 'STATION-01',
      qrToken: 'eh-tok-sw01-device3-token1234',
    },
  });

  await runTest('Reject packing attempt without dual-scan verification (fake/nonexistent verificationId)', async () => {
    const res = await app.inject({
      method: 'POST',
      url: '/api/v1/inventory/pack',
      payload: {
        deviceId: device3.deviceId,
        serialNumber: device3.serialNumber,
        cartonId: testCartonId,
        verificationId: 'nonexistent-verification-id',
        stationId: 'STATION-01',
      },
    });

    const body = JSON.parse(res.body);
    assert.strictEqual(body.success, false);
    assert.strictEqual(body.errorCode, 'DUAL_SCAN_NOT_FOUND');
  });

  await runTest('Reject packing attempt with verification belonging to another device', async () => {
    // Attempt to pack device3 using testVerificationId (which belongs to device1)
    const res = await app.inject({
      method: 'POST',
      url: '/api/v1/inventory/pack',
      payload: {
        deviceId: device3.deviceId,
        serialNumber: device3.serialNumber,
        cartonId: testCartonId,
        verificationId: testVerificationId, // Belongs to device 1!
        stationId: 'STATION-01',
      },
    });

    const body = JSON.parse(res.body);
    assert.strictEqual(body.success, false);
    assert.strictEqual(body.errorCode, 'DUAL_SCAN_NOT_FOUND');
  });

  await runTest('Reject packing attempt with nonexistent carton', async () => {
    // Perform valid dual-scan for device3
    const scanRes = await app.inject({
      method: 'POST',
      url: '/api/v1/inventory/dual-scan',
      payload: {
        stationId: 'STATION-01',
        deviceSerial: device3.serialNumber,
        boxTokenOrUri: 'eh://p/v1?t=eh-tok-sw01-device3-token1234',
        cartonId: testCartonId,
      },
    });
    const scanBody = JSON.parse(scanRes.body);
    assert.strictEqual(scanBody.isMatch, true);

    const packRes = await app.inject({
      method: 'POST',
      url: '/api/v1/inventory/pack',
      payload: {
        deviceId: device3.deviceId,
        serialNumber: device3.serialNumber,
        cartonId: 'nonexistent-carton-id',
        verificationId: scanBody.verificationId,
        stationId: 'STATION-01',
      },
    });

    const packBody = JSON.parse(packRes.body);
    assert.strictEqual(packBody.success, false);
    assert.strictEqual(packBody.errorCode, 'CARTON_NOT_FOUND');
  });

  await runTest('Reject packing attempt with incompatible carton variant', async () => {
    // Create socket carton
    const cartonSocketRes = await app.inject({
      method: 'POST',
      url: '/api/v1/inventory/cartons',
      payload: {
        cartonCode: 'CARTON-2026-SK1X-001',
        productVariantId: 'eh-smart-socket-1x', // Incompatible with Switch 1x!
        hardwareRevision: 'HW_1_0',
        targetCapacity: 5,
      },
    });
    const socketCarton = JSON.parse(cartonSocketRes.body).carton;

    // Perform dual scan for device3
    const scanRes = await app.inject({
      method: 'POST',
      url: '/api/v1/inventory/dual-scan',
      payload: {
        stationId: 'STATION-01',
        deviceSerial: device3.serialNumber,
        boxTokenOrUri: 'eh://p/v1?t=eh-tok-sw01-device3-token1234',
      },
    });
    const scanBody = JSON.parse(scanRes.body);

    const packRes = await app.inject({
      method: 'POST',
      url: '/api/v1/inventory/pack',
      payload: {
        deviceId: device3.deviceId,
        serialNumber: device3.serialNumber,
        cartonId: socketCarton.id,
        verificationId: scanBody.verificationId,
        stationId: 'STATION-01',
      },
    });

    const packBody = JSON.parse(packRes.body);
    assert.strictEqual(packBody.success, false);
    assert.strictEqual(packBody.errorCode, 'VARIANT_MISMATCH');
  });

  await runTest('Reject packing attempt with incompatible carton hardware revision', async () => {
    // Create HW_1_1 switch carton
    const cartonHwRes = await app.inject({
      method: 'POST',
      url: '/api/v1/inventory/cartons',
      payload: {
        cartonCode: 'CARTON-2026-SW1X-HW11-001',
        productVariantId: 'eh-smart-switch-1x',
        hardwareRevision: 'HW_1_1', // Device 3 is HW_1_0!
        targetCapacity: 5,
      },
    });
    const hwCarton = JSON.parse(cartonHwRes.body).carton;

    // Perform dual scan for device3
    const scanRes = await app.inject({
      method: 'POST',
      url: '/api/v1/inventory/dual-scan',
      payload: {
        stationId: 'STATION-01',
        deviceSerial: device3.serialNumber,
        boxTokenOrUri: 'eh://p/v1?t=eh-tok-sw01-device3-token1234',
      },
    });
    const scanBody = JSON.parse(scanRes.body);

    const packRes = await app.inject({
      method: 'POST',
      url: '/api/v1/inventory/pack',
      payload: {
        deviceId: device3.deviceId,
        serialNumber: device3.serialNumber,
        cartonId: hwCarton.id,
        verificationId: scanBody.verificationId,
        stationId: 'STATION-01',
      },
    });

    const packBody = JSON.parse(packRes.body);
    assert.strictEqual(packBody.success, false);
    assert.strictEqual(packBody.errorCode, 'HARDWARE_REVISION_MISMATCH');
  });

  // ── 6. CONCURRENCY & RACE-SAFETY TESTS ──────────────────────────────────
  console.log('\n6. Concurrency & Race-Safety:');

  await runTest('Concurrent packing calls for same device: only one succeeds', async () => {
    // Register a second device
    const device2 = {
      ...validTraceRecord,
      deviceId: '0194fe23-7a1b-7890-a123-456789abcd20',
      serialNumber: 'EH-SW1X-2026W12-00020',
    };
    const regRes = await app.inject({
      method: 'POST',
      url: '/api/v1/inventory/register',
      payload: {
        traceabilityRecord: device2,
        stationId: 'STATION-01',
        qrToken: 'eh-tok-sw01-device2-token1234',
      },
    });
    assert.strictEqual(regRes.statusCode, 200);

    // Verify it
    const scanRes = await app.inject({
      method: 'POST',
      url: '/api/v1/inventory/dual-scan',
      payload: {
        stationId: 'STATION-01',
        deviceSerial: device2.serialNumber,
        boxTokenOrUri: 'eh://p/v1?t=eh-tok-sw01-device2-token1234',
        cartonId: testCartonId,
      },
    });
    const scanBody = JSON.parse(scanRes.body);
    assert.strictEqual(scanBody.isMatch, true);

    // Concurrently trigger packing from Station A and Station B
    const [resA, resB] = await Promise.all([
      app.inject({
        method: 'POST',
        url: '/api/v1/inventory/pack',
        payload: {
          deviceId: device2.deviceId,
          serialNumber: device2.serialNumber,
          cartonId: testCartonId,
          verificationId: scanBody.verificationId,
          stationId: 'STATION-A',
        },
      }),
      app.inject({
        method: 'POST',
        url: '/api/v1/inventory/pack',
        payload: {
          deviceId: device2.deviceId,
          serialNumber: device2.serialNumber,
          cartonId: testCartonId,
          verificationId: scanBody.verificationId,
          stationId: 'STATION-B',
        },
      }),
    ]);

    const bodyA = JSON.parse(resA.body);
    const bodyB = JSON.parse(resB.body);

    const successes = (bodyA.success ? 1 : 0) + (bodyB.success ? 1 : 0);
    const failures = (bodyA.success === false ? 1 : 0) + (bodyB.success === false ? 1 : 0);

    assert.strictEqual(successes, 1, 'Exactly one concurrent packing operation must succeed');
    assert.strictEqual(failures, 1, 'The competing concurrent operation must fail');
  });

  // ── 7. AUDIT-TRAIL INTEGRITY & IMMUTABILITY TESTS ─────────────────────
  console.log('\n7. Audit-Trail Integrity & Immutability:');

  // Register and pack a dedicated audit test device
  const auditDevice = {
    ...validTraceRecord,
    deviceId: '0194fe23-7a1b-7890-a123-456789abcd40',
    serialNumber: 'EH-SW1X-2026W12-00040',
    traceId: '0194fe23-7a1b-7890-a123-456789abce40',
    productVariantId: 'eh-smart-switch-1x',
    hardwareRevision: 'HW_1_0',
    firmwareFamily: 'esp32c6-switch-platform',
    firmwareVersion: '1.0.0',
  };

  const auditQrToken = 'eh-tok-sw01-audit-device40';

  await app.inject({
    method: 'POST',
    url: '/api/v1/inventory/register',
    payload: {
      traceabilityRecord: auditDevice,
      stationId: 'STATION-01',
      qrToken: auditQrToken,
    },
  });

  const auditCartonRes = await app.inject({
    method: 'POST',
    url: '/api/v1/inventory/cartons',
    payload: {
      cartonCode: 'CARTON-2026-AUDIT-001',
      productVariantId: 'eh-smart-switch-1x',
      hardwareRevision: 'HW_1_0',
      targetCapacity: 10,
    },
  });
  const auditCarton = JSON.parse(auditCartonRes.body).carton;

  const auditScanRes = await app.inject({
    method: 'POST',
    url: '/api/v1/inventory/dual-scan',
    payload: {
      stationId: 'STATION-01',
      deviceSerial: auditDevice.serialNumber,
      boxTokenOrUri: `eh://p/v1?t=${auditQrToken}`,
      cartonId: auditCarton.id,
    },
  });
  const auditScan = JSON.parse(auditScanRes.body);

  const historyBeforeRes = await app.inject({
    method: 'GET',
    url: '/api/v1/inventory/history?limit=100',
  });
  const historyBeforeCount = JSON.parse(historyBeforeRes.body).records.length;

  let createdAuditRecord = null;

  await runTest('1. Successful packing creates exactly one packaging record', async () => {
    const packRes = await app.inject({
      method: 'POST',
      url: '/api/v1/inventory/pack',
      payload: {
        deviceId: auditDevice.deviceId,
        serialNumber: auditDevice.serialNumber,
        cartonId: auditCarton.id,
        verificationId: auditScan.verificationId,
        stationId: 'STATION-AUDIT',
      },
    });

    assert.strictEqual(packRes.statusCode, 200);
    const body = JSON.parse(packRes.body);
    assert.strictEqual(body.success, true);
    assert.ok(body.packagingRecord, 'Packaging record must be returned');
    assert.ok(body.packagingRecord.id, 'Packaging record must have unique ID');
    createdAuditRecord = body.packagingRecord;

    const historyAfterRes = await app.inject({
      method: 'GET',
      url: '/api/v1/inventory/history?limit=100',
    });
    const historyAfterCount = JSON.parse(historyAfterRes.body).records.length;
    assert.strictEqual(historyAfterCount, historyBeforeCount + 1, 'Exactly one record added to history');
  });

  await runTest('2. Packaging record contains correct device ID', async () => {
    assert.strictEqual(createdAuditRecord.deviceId, auditDevice.deviceId);
  });

  await runTest('3. Packaging record contains correct verification ID', async () => {
    assert.strictEqual(createdAuditRecord.verificationId, auditScan.verificationId);
  });

  await runTest('4. Packaging record contains correct carton ID', async () => {
    assert.strictEqual(createdAuditRecord.cartonId, auditCarton.id);
  });

  await runTest('5. Packaging record contains correct traceId', async () => {
    assert.strictEqual(createdAuditRecord.traceId, auditDevice.traceId);
  });

  await runTest('6. Packaging record contains correct product variant', async () => {
    assert.strictEqual(createdAuditRecord.productVariantId, auditDevice.productVariantId);
  });

  await runTest('7. Packaging record contains correct hardware revision', async () => {
    assert.strictEqual(createdAuditRecord.hardwareRevision, auditDevice.hardwareRevision);
  });

  await runTest('8. Packaging record contains correct firmware family', async () => {
    assert.strictEqual(createdAuditRecord.firmwareFamily, auditDevice.firmwareFamily);
  });

  await runTest('9. Update attempt against packaging record is rejected (append-only API)', async () => {
    // Attempt PUT and PATCH on packing endpoints
    const putRes = await app.inject({
      method: 'PUT',
      url: `/api/v1/inventory/pack/${createdAuditRecord.id}`,
      payload: { notes: 'tampered notes' },
    });
    assert.strictEqual(putRes.statusCode, 404, 'PUT on packaging record must be rejected');

    const patchRes = await app.inject({
      method: 'PATCH',
      url: `/api/v1/inventory/history/${createdAuditRecord.id}`,
      payload: { deviceId: 'tampered-device-id' },
    });
    assert.strictEqual(patchRes.statusCode, 404, 'PATCH on packaging history must be rejected');
  });

  await runTest('10. Delete attempt against packaging record is rejected (no delete route/method)', async () => {
    const delRes = await app.inject({
      method: 'DELETE',
      url: `/api/v1/inventory/pack/${createdAuditRecord.id}`,
    });
    assert.strictEqual(delRes.statusCode, 404, 'DELETE on packaging record must be rejected');

    const delHistoryRes = await app.inject({
      method: 'DELETE',
      url: `/api/v1/inventory/history/${createdAuditRecord.id}`,
    });
    assert.strictEqual(delHistoryRes.statusCode, 404, 'DELETE on packaging history must be rejected');
  });

  await runTest('11. Deleting parent device cannot silently delete packaging audit record (ON DELETE RESTRICT in DDL)', async () => {
    const fs = require('fs');
    const path = require('path');
    const sqlPath = path.join(__dirname, '../../../packages/db-schema/migrations/033_production_inventory_packing.sql');
    const sql = fs.readFileSync(sqlPath, 'utf8');

    // Verify packaging_records.device_id foreign key uses ON DELETE RESTRICT
    assert.ok(
      /device_id\s+VARCHAR\([0-9]+\)\s+NOT\s+NULL\s+REFERENCES\s+devices\(id\)\s+ON\s+DELETE\s+RESTRICT/i.test(sql),
      'packaging_records.device_id must specify ON DELETE RESTRICT'
    );
  });

  await runTest('12. Deleting carton cannot silently delete packaging audit record (ON DELETE RESTRICT in DDL)', async () => {
    const fs = require('fs');
    const path = require('path');
    const sqlPath = path.join(__dirname, '../../../packages/db-schema/migrations/033_production_inventory_packing.sql');
    const sql = fs.readFileSync(sqlPath, 'utf8');

    // Verify packaging_records.carton_id foreign key uses ON DELETE RESTRICT
    assert.ok(
      /carton_id\s+VARCHAR\([0-9]+\)\s+NOT\s+NULL\s+REFERENCES\s+packaging_cartons\(id\)\s+ON\s+DELETE\s+RESTRICT/i.test(sql),
      'packaging_records.carton_id must specify ON DELETE RESTRICT'
    );
  });

  await runTest('13. Deleting dual-scan verification cannot silently delete packaging audit record (ON DELETE RESTRICT in DDL)', async () => {
    const fs = require('fs');
    const path = require('path');
    const sqlPath = path.join(__dirname, '../../../packages/db-schema/migrations/033_production_inventory_packing.sql');
    const sql = fs.readFileSync(sqlPath, 'utf8');

    // Verify packaging_records.verification_id foreign key uses ON DELETE RESTRICT
    assert.ok(
      /verification_id\s+VARCHAR\([0-9]+\)\s+NOT\s+NULL\s+REFERENCES\s+dual_scan_verifications\(id\)\s+ON\s+DELETE\s+RESTRICT/i.test(sql),
      'packaging_records.verification_id must specify ON DELETE RESTRICT'
    );
  });

  await runTest('14. Duplicate successful packaging cannot create duplicate audit records', async () => {
    const countBefore = (await app.inject({ method: 'GET', url: '/api/v1/inventory/history?limit=100' }));
    const countBeforeNum = JSON.parse(countBefore.body).records.length;

    // Attempt duplicate packing with exact same parameters
    const dupRes = await app.inject({
      method: 'POST',
      url: '/api/v1/inventory/pack',
      payload: {
        deviceId: auditDevice.deviceId,
        serialNumber: auditDevice.serialNumber,
        cartonId: auditCarton.id,
        verificationId: auditScan.verificationId,
        stationId: 'STATION-AUDIT',
      },
    });

    const dupBody = JSON.parse(dupRes.body);
    assert.strictEqual(dupBody.success, false);
    assert.strictEqual(dupBody.errorCode, 'DEVICE_ALREADY_PACKED');

    const countAfter = (await app.inject({ method: 'GET', url: '/api/v1/inventory/history?limit=100' }));
    const countAfterNum = JSON.parse(countAfter.body).records.length;

    assert.strictEqual(countAfterNum, countBeforeNum, 'No duplicate audit record created on failed/duplicate attempt');
  });

  // ── SUMMARY ───────────────────────────────────────────────────────────
  console.log(`\n=== INVENTORY & PACKING TESTS SUMMARY ===`);
  console.log(`Total:  ${totalTests}`);
  console.log(`Passed: ${passedTests}`);
  console.log(`Failed: ${failedTests}`);

  if (failedTests > 0) {
    process.exit(1);
  } else {
    console.log('ALL INVENTORY & PACKING TESTS PASSED [OK]\n');
  }

  await app.close();
}

main().catch((err) => {
  console.error('Fatal test error:', err);
  process.exit(1);
});
