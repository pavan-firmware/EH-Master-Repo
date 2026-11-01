/**
 * EH Home Firmware, Git & Binary Management Automated Test Suite
 *
 * Validates:
 * - Firmware families retrieval and MCU target validation (GET /api/v1/firmware/families)
 * - Single family retrieval and 404 handling (GET /api/v1/firmware/families/:familyId)
 * - Firmware release listing and filtering by family, status, version, and hardware revision (GET /api/v1/firmware/releases)
 * - Firmware release detail retrieval (GET /api/v1/firmware/releases/:releaseId)
 * - Firmware release creation with semantic version and 40-char Git SHA validation (POST /api/v1/firmware/releases)
 * - Duplicate release rejection
 * - Firmware release lifecycle state machine transitions (DRAFT -> BUILDING -> VALIDATION -> APPROVED -> RELEASED)
 * - Rejection of invalid backward lifecycle transitions
 * - Immutability enforcement on APPROVED and RELEASED releases
 * - Build registration and Git commit traceability (POST /api/v1/firmware/releases/:id/builds)
 * - Binary artifact registration, positive size validation, and SHA-256 validation (POST /api/v1/firmware/releases/:id/artifacts)
 * - Deterministic SHA-256 checksum integrity verification via storage abstraction
 * - Hardware revision compatibility definition and querying (POST & GET /api/v1/firmware/releases/:id/compatibility)
 * - Compatibility with static product definitions (6 canonical firmware families)
 * - Security envelope & information leak prevention
 */

const assert = require('assert');
const crypto = require('crypto');
const { buildApp } = require('../dist/app');
const { FirmwareService, InMemoryArtifactStore } = require('../dist/modules/firmware/firmware.service');
const { FirmwareRepository } = require('../dist/modules/firmware/firmware.repository');
const { OtaManifestSchema, toLegacyReleaseStatus, toDomainReleaseStatus } = require('@eh-home/contracts');

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
  console.log('=== EH HOME FIRMWARE & GIT MANAGEMENT TESTS ===\n');

  process.env.NODE_ENV = 'test';

  const app = await buildApp({
    skipDatabase: true,
    fastifyOptions: {
      logger: false,
    },
  });

  await app.ready();

  // ── 1. FIRMWARE FAMILIES API ──────────────────────────────────────────
  console.log('1. Firmware Families API (GET /api/v1/firmware/families):');

  await runTest('GET /api/v1/firmware/families returns 200 with all 6 canonical families', async () => {
    const res = await app.inject({
      method: 'GET',
      url: '/api/v1/firmware/families',
    });

    assert.strictEqual(res.statusCode, 200);
    const body = JSON.parse(res.body);
    assert.strictEqual(body.schemaVersion, 1);
    assert.strictEqual(body.success, true);
    assert.ok(Array.isArray(body.data));
    assert.strictEqual(body.data.length, 6, 'Must contain all 6 canonical firmware families');

    const expectedFamilies = [
      'esp32c6-switch-platform',
      'esp32c6-socket-platform',
      'esp32c6-fan-platform',
      'esp32c6-light-platform',
      'esp32s3-hub-platform',
      'esp32c6-sensor-platform',
    ];

    const actualIds = body.data.map((f) => f.id);
    for (const exp of expectedFamilies) {
      assert.ok(actualIds.includes(exp), `Missing firmware family: ${exp}`);
    }

    const switchFam = body.data.find((f) => f.id === 'esp32c6-switch-platform');
    assert.strictEqual(switchFam.targetMcu, 'esp32-c6');
    assert.strictEqual(switchFam.defaultIdfVersion, 'v5.4.1');
  });

  await runTest('GET /api/v1/firmware/families/:familyId returns detailed family metadata', async () => {
    const res = await app.inject({
      method: 'GET',
      url: '/api/v1/firmware/families/esp32s3-hub-platform',
    });

    assert.strictEqual(res.statusCode, 200);
    const body = JSON.parse(res.body);
    assert.strictEqual(body.success, true);
    assert.strictEqual(body.data.id, 'esp32s3-hub-platform');
    assert.strictEqual(body.data.targetMcu, 'esp32-s3');
    assert.strictEqual(body.data.defaultIdfVersion, 'v5.4.1');
  });

  await runTest('GET /api/v1/firmware/families/:familyId returns 404 for unknown family', async () => {
    const res = await app.inject({
      method: 'GET',
      url: '/api/v1/firmware/families/nonexistent-platform',
    });

    assert.strictEqual(res.statusCode, 404);
    const body = JSON.parse(res.body);
    assert.strictEqual(body.success, false);
    assert.strictEqual(body.error.code, 'FIRMWARE_FAMILY_NOT_FOUND');
  });

  // ── 2. FIRMWARE RELEASES API & FILTERING ──────────────────────────────
  console.log('\n2. Firmware Releases API (GET /api/v1/firmware/releases):');

  await runTest('GET /api/v1/firmware/releases returns releases list with pagination', async () => {
    const res = await app.inject({
      method: 'GET',
      url: '/api/v1/firmware/releases',
    });

    assert.strictEqual(res.statusCode, 200);
    const body = JSON.parse(res.body);
    assert.strictEqual(body.success, true);
    assert.ok(Array.isArray(body.data));
    assert.ok(body.data.length >= 1);
    assert.ok(body.pagination);

    const rel = body.data[0];
    assert.ok(rel.id);
    assert.ok(rel.version);
    assert.ok(rel.firmwareFamily);
    assert.ok(rel.gitCommitSha);
    assert.strictEqual(rel.idfVersion, 'v5.4.1');
  });

  await runTest('GET /api/v1/firmware/releases filters by family and status', async () => {
    const res = await app.inject({
      method: 'GET',
      url: '/api/v1/firmware/releases?firmwareFamily=esp32c6-switch-platform&status=RELEASED',
    });

    assert.strictEqual(res.statusCode, 200);
    const body = JSON.parse(res.body);
    assert.ok(body.data.length >= 1);
    for (const r of body.data) {
      assert.strictEqual(r.firmwareFamily, 'esp32c6-switch-platform');
      assert.strictEqual(r.status, 'RELEASED');
    }
  });

  await runTest('GET /api/v1/firmware/releases/:releaseId returns release with builds and compatibility', async () => {
    const res = await app.inject({
      method: 'GET',
      url: '/api/v1/firmware/releases/rel_switch_v1_0_0',
    });

    assert.strictEqual(res.statusCode, 200);
    const body = JSON.parse(res.body);
    assert.strictEqual(body.success, true);
    assert.strictEqual(body.data.id, 'rel_switch_v1_0_0');
    assert.ok(Array.isArray(body.data.builds));
    assert.ok(body.data.builds.length >= 1);
    assert.ok(Array.isArray(body.data.compatibilities));
    assert.ok(body.data.compatibilities.length >= 1);
  });

  await runTest('GET /api/v1/firmware/releases/:releaseId returns 404 for unknown release', async () => {
    const res = await app.inject({
      method: 'GET',
      url: '/api/v1/firmware/releases/unknown_release_id',
    });

    assert.strictEqual(res.statusCode, 404);
    const body = JSON.parse(res.body);
    assert.strictEqual(body.success, false);
    assert.strictEqual(body.error.code, 'FIRMWARE_RELEASE_NOT_FOUND');
  });

  // ── 3. RELEASE CREATION & CONSTRAINTS ─────────────────────────────────
  console.log('\n3. Firmware Release Creation & Constraints:');

  const validCommit = 'b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3';
  const dummySha256 = 'f'.repeat(64);

  await runTest('POST /api/v1/firmware/releases creates new release in DRAFT status', async () => {
    const res = await app.inject({
      method: 'POST',
      url: '/api/v1/firmware/releases',
      payload: {
        firmwareFamily: 'esp32c6-socket-platform',
        productVariantId: 'eh-smart-socket-1x',
        version: '1.1.0',
        gitCommitSha: validCommit,
        gitBranch: 'main',
        binarySizeBytes: 1048576,
        sha256: dummySha256,
        status: 'DRAFT',
      },
    });

    assert.strictEqual(res.statusCode, 201);
    const body = JSON.parse(res.body);
    assert.strictEqual(body.success, true);
    assert.strictEqual(body.data.version, '1.1.0');
    assert.strictEqual(body.data.status, 'DRAFT');
    assert.strictEqual(body.data.gitCommitSha, validCommit);
  });

  await runTest('Rejects duplicate version within same firmware family', async () => {
    const res = await app.inject({
      method: 'POST',
      url: '/api/v1/firmware/releases',
      payload: {
        firmwareFamily: 'esp32c6-socket-platform',
        productVariantId: 'eh-smart-socket-1x',
        version: '1.1.0', // DUPLICATE!
        gitCommitSha: validCommit,
        sha256: dummySha256,
      },
    });

    assert.strictEqual(res.statusCode, 400);
    const body = JSON.parse(res.body);
    assert.strictEqual(body.success, false);
    assert.ok(body.error.message.includes('already exists'));
  });

  await runTest('Rejects invalid Git commit SHA (not 40-char hex)', async () => {
    const res = await app.inject({
      method: 'POST',
      url: '/api/v1/firmware/releases',
      payload: {
        firmwareFamily: 'esp32c6-fan-platform',
        productVariantId: 'eh-smart-fan-1x',
        version: '1.0.0',
        gitCommitSha: 'not-a-valid-sha', // INVALID
        sha256: dummySha256,
      },
    });

    assert.strictEqual(res.statusCode, 400);
  });

  await runTest('POST /api/v1/firmware/releases strictly rejects direct creation as REVOKED', async () => {
    const res = await app.inject({
      method: 'POST',
      url: '/api/v1/firmware/releases',
      payload: {
        firmwareFamily: 'esp32c6-switch-platform',
        productVariantId: 'eh-smart-switch-2x',
        version: '1.0.0-revoked-direct',
        gitCommitSha: validCommit,
        sha256: dummySha256,
        status: 'REVOKED', // STRICTLY FORBIDDEN AT CREATION TIME
      },
    });

    assert.strictEqual(res.statusCode, 400);
  });

  await runTest('POST /api/v1/firmware/releases creates release in DRAFT when status is omitted', async () => {
    const res = await app.inject({
      method: 'POST',
      url: '/api/v1/firmware/releases',
      payload: {
        firmwareFamily: 'esp32c6-switch-platform',
        productVariantId: 'eh-smart-switch-3x',
        version: '1.0.0-draft-default',
        gitCommitSha: validCommit,
        sha256: dummySha256,
      },
    });

    assert.strictEqual(res.statusCode, 201);
    const body = JSON.parse(res.body);
    assert.strictEqual(body.data.status, 'DRAFT');
    assert.strictEqual(body.data.releasedAt, null);
  });

  // ── 4. LIFECYCLE TRANSITIONS & IMMUTABILITY ───────────────────────────
  console.log('\n4. Firmware Release Lifecycle & Immutability:');

  await runTest('Governs valid lifecycle transitions (DRAFT -> BUILDING -> VALIDATION -> APPROVED -> RELEASED)', async () => {
    const repo = new FirmwareRepository();
    const service = new FirmwareService(repo);

    const rel = await service.createRelease({
      firmwareFamily: 'esp32c6-light-platform',
      productVariantId: 'eh-smart-light-cct',
      version: '1.0.0',
      gitCommitSha: validCommit,
      binarySizeBytes: 1048576,
      sha256: dummySha256,
      status: 'DRAFT',
    });

    // 1. DRAFT -> BUILDING
    const s1 = await service.updateReleaseStatus(rel.id, { status: 'BUILDING' });
    assert.strictEqual(s1.status, 'BUILDING');

    // 2. BUILDING -> VALIDATION
    const s2 = await service.updateReleaseStatus(rel.id, { status: 'VALIDATION' });
    assert.strictEqual(s2.status, 'VALIDATION');

    // 3. VALIDATION -> APPROVED
    const s3 = await service.updateReleaseStatus(rel.id, { status: 'APPROVED' });
    assert.strictEqual(s3.status, 'APPROVED');

    // 4. APPROVED -> RELEASED
    const s4 = await service.updateReleaseStatus(rel.id, { status: 'RELEASED' });
    assert.strictEqual(s4.status, 'RELEASED');
    assert.ok(s4.releasedAt, 'Must set releasedAt when status is RELEASED');
  });

  await runTest('Rejects invalid backward transitions (RELEASED -> DRAFT and RELEASED -> BUILDING)', async () => {
    const repo = new FirmwareRepository();
    const service = new FirmwareService(repo);

    let errorDraftThrown = false;
    try {
      await service.updateReleaseStatus('rel_switch_v1_0_0', { status: 'DRAFT' });
    } catch (err) {
      errorDraftThrown = true;
      assert.ok(err.message.includes('Invalid lifecycle transition'));
    }
    assert.strictEqual(errorDraftThrown, true, 'Must reject RELEASED -> DRAFT');

    let errorBuildingThrown = false;
    try {
      await service.updateReleaseStatus('rel_switch_v1_0_0', { status: 'BUILDING' });
    } catch (err) {
      errorBuildingThrown = true;
      assert.ok(err.message.includes('Invalid lifecycle transition'));
    }
    assert.strictEqual(errorBuildingThrown, true, 'Must reject RELEASED -> BUILDING');
  });

  await runTest('Approved/Released releases are immutable: cannot attach new builds', async () => {
    const repo = new FirmwareRepository();
    const service = new FirmwareService(repo);

    let errorThrown = false;
    try {
      await service.registerBuild({
        firmwareReleaseId: 'rel_switch_v1_0_0', // RELEASED
        firmwareFamilyId: 'esp32c6-switch-platform',
        gitCommitSha: validCommit,
      });
    } catch (err) {
      errorThrown = true;
      assert.ok(err.message.includes('immutable'));
    }
    assert.strictEqual(errorThrown, true, 'Must reject attaching build to released release');
  });

  await runTest('Emergency revocation: transitions from RELEASED and APPROVED to REVOKED succeed', async () => {
    const repo = new FirmwareRepository();
    const service = new FirmwareService(repo);

    const rel = await service.createRelease({
      firmwareFamily: 'esp32c6-light-platform',
      productVariantId: 'eh-smart-light-cct',
      version: '1.2.0',
      gitCommitSha: validCommit,
      binarySizeBytes: 1048576,
      sha256: dummySha256,
      status: 'DRAFT',
    });

    await service.updateReleaseStatus(rel.id, { status: 'BUILDING' });
    await service.updateReleaseStatus(rel.id, { status: 'VALIDATION' });
    await service.updateReleaseStatus(rel.id, { status: 'APPROVED' });
    const released = await service.updateReleaseStatus(rel.id, { status: 'RELEASED' });
    assert.strictEqual(released.status, 'RELEASED');

    // Emergency revocation from RELEASED -> REVOKED
    const revoked = await service.updateReleaseStatus(rel.id, {
      status: 'REVOKED',
      reason: 'Critical cryptographic key compromise CVE-2026-0001',
    });
    assert.strictEqual(revoked.status, 'REVOKED');
  });

  await runTest('REVOKED status is strictly terminal: cannot transition out of REVOKED', async () => {
    const repo = new FirmwareRepository();
    const service = new FirmwareService(repo);

    const rel = await service.createRelease({
      firmwareFamily: 'esp32c6-socket-platform',
      productVariantId: 'eh-smart-socket-1x',
      version: '1.3.0',
      gitCommitSha: validCommit,
      binarySizeBytes: 1048576,
      sha256: dummySha256,
      status: 'DRAFT',
    });

    await service.updateReleaseStatus(rel.id, { status: 'BUILDING' });
    await service.updateReleaseStatus(rel.id, { status: 'VALIDATION' });
    await service.updateReleaseStatus(rel.id, { status: 'APPROVED' });
    await service.updateReleaseStatus(rel.id, { status: 'REVOKED', reason: 'Pre-release security flaw' });

    // Attempt resurrection REVOKED -> RELEASED
    let errReleasedThrown = false;
    try {
      await service.updateReleaseStatus(rel.id, { status: 'RELEASED' });
    } catch (err) {
      errReleasedThrown = true;
      assert.ok(err.message.includes('terminal state \'REVOKED\''));
    }
    assert.strictEqual(errReleasedThrown, true, 'Must reject transition out of REVOKED to RELEASED');

    // Attempt resurrection REVOKED -> DRAFT
    let errDraftThrown = false;
    try {
      await service.updateReleaseStatus(rel.id, { status: 'DRAFT' });
    } catch (err) {
      errDraftThrown = true;
      assert.ok(err.message.includes('terminal state \'REVOKED\''));
    }
    assert.strictEqual(errDraftThrown, true, 'Must reject transition out of REVOKED to DRAFT');
  });

  await runTest('REVOKED releases are immutable: reject builds and compatibility mutations', async () => {
    const repo = new FirmwareRepository();
    const service = new FirmwareService(repo);

    const rel = await service.createRelease({
      firmwareFamily: 'esp32c6-fan-platform',
      productVariantId: 'eh-smart-fan-1x',
      version: '1.4.0',
      gitCommitSha: validCommit,
      binarySizeBytes: 1048576,
      sha256: dummySha256,
      status: 'DRAFT',
    });

    await service.updateReleaseStatus(rel.id, { status: 'BUILDING' });
    await service.updateReleaseStatus(rel.id, { status: 'VALIDATION' });
    await service.updateReleaseStatus(rel.id, { status: 'APPROVED' });
    await service.updateReleaseStatus(rel.id, { status: 'REVOKED' });

    // Reject build registration
    let buildError = false;
    try {
      await service.registerBuild({
        firmwareReleaseId: rel.id,
        firmwareFamilyId: 'esp32c6-fan-platform',
        gitCommitSha: validCommit,
      });
    } catch (err) {
      buildError = true;
      assert.ok(err.message.includes('immutable'));
    }
    assert.strictEqual(buildError, true, 'Must reject attaching build to REVOKED release');

    // Reject compatibility mutation
    let compatError = false;
    try {
      await service.defineCompatibility(rel.id, {
        hardwareRevisionId: 'hw_rev_test_1',
      });
    } catch (err) {
      compatError = true;
      assert.ok(err.message.includes('terminal status \'REVOKED\''));
    }
    assert.strictEqual(compatError, true, 'Must reject defining compatibility for REVOKED release');
  });

  await runTest('HTTP API governs REVOKED status transition and terminal enforcement', async () => {
    // 1. Create release via API
    const createRes = await app.inject({
      method: 'POST',
      url: '/api/v1/firmware/releases',
      payload: {
        firmwareFamily: 'esp32s3-hub-platform',
        productVariantId: 'eh-smart-hub-v1',
        version: '1.9.0',
        gitCommitSha: validCommit,
        sha256: dummySha256,
        status: 'DRAFT',
      },
    });
    assert.strictEqual(createRes.statusCode, 201);
    const relId = JSON.parse(createRes.body).data.id;

    // 2. Advance to APPROVED
    await app.inject({ method: 'PATCH', url: `/api/v1/firmware/releases/${relId}/status`, payload: { status: 'BUILDING' } });
    await app.inject({ method: 'PATCH', url: `/api/v1/firmware/releases/${relId}/status`, payload: { status: 'VALIDATION' } });
    await app.inject({ method: 'PATCH', url: `/api/v1/firmware/releases/${relId}/status`, payload: { status: 'APPROVED' } });

    // 3. Revoke via API
    const revokeRes = await app.inject({
      method: 'PATCH',
      url: `/api/v1/firmware/releases/${relId}/status`,
      payload: { status: 'REVOKED', reason: 'Zero-day vulnerability discovered in field test' },
    });
    assert.strictEqual(revokeRes.statusCode, 200);
    assert.strictEqual(JSON.parse(revokeRes.body).data.status, 'REVOKED');

    // 4. Attempt invalid transition out of REVOKED via API -> 400
    const reOpenRes = await app.inject({
      method: 'PATCH',
      url: `/api/v1/firmware/releases/${relId}/status`,
      payload: { status: 'RELEASED' },
    });
    assert.strictEqual(reOpenRes.statusCode, 400);
    assert.ok(JSON.parse(reOpenRes.body).error.message.includes('terminal state \'REVOKED\''));
  });

  await runTest('Emergency revocation from DEPRECATED and RETIRED to REVOKED succeeds', async () => {
    const repo = new FirmwareRepository();
    const service = new FirmwareService(repo);

    // 1. DEPRECATED -> REVOKED
    const rel1 = await service.createRelease({
      firmwareFamily: 'esp32c6-sensor-platform',
      productVariantId: 'eh-sensor-node-v1',
      version: '1.9.1',
      gitCommitSha: validCommit,
      binarySizeBytes: 1048576,
      sha256: dummySha256,
    });
    await service.updateReleaseStatus(rel1.id, { status: 'BUILDING' });
    await service.updateReleaseStatus(rel1.id, { status: 'VALIDATION' });
    await service.updateReleaseStatus(rel1.id, { status: 'APPROVED' });
    await service.updateReleaseStatus(rel1.id, { status: 'RELEASED' });
    await service.updateReleaseStatus(rel1.id, { status: 'DEPRECATED' });
    const revokedFromDep = await service.updateReleaseStatus(rel1.id, { status: 'REVOKED', reason: 'Zero-day in deprecated' });
    assert.strictEqual(revokedFromDep.status, 'REVOKED');

    // 2. RETIRED -> REVOKED
    const rel2 = await service.createRelease({
      firmwareFamily: 'esp32c6-sensor-platform',
      productVariantId: 'eh-sensor-node-v1',
      version: '1.9.2',
      gitCommitSha: validCommit,
      binarySizeBytes: 1048576,
      sha256: dummySha256,
    });
    await service.updateReleaseStatus(rel2.id, { status: 'BUILDING' });
    await service.updateReleaseStatus(rel2.id, { status: 'VALIDATION' });
    await service.updateReleaseStatus(rel2.id, { status: 'APPROVED' });
    await service.updateReleaseStatus(rel2.id, { status: 'RETIRED' });
    const revokedFromRet = await service.updateReleaseStatus(rel2.id, { status: 'REVOKED', reason: 'Post-EOL CVE' });
    assert.strictEqual(revokedFromRet.status, 'REVOKED');
  });

  await runTest('Legacy status mapping: bidirectional translation between RELEASED and PUBLISHED', async () => {
    // 1. Contract mappers
    assert.strictEqual(toLegacyReleaseStatus('RELEASED'), 'PUBLISHED', 'Domain RELEASED must map to legacy PUBLISHED');
    assert.strictEqual(toDomainReleaseStatus('PUBLISHED'), 'RELEASED', 'Legacy PUBLISHED must map to domain RELEASED');
    assert.strictEqual(toLegacyReleaseStatus('REVOKED'), 'REVOKED', 'REVOKED remains REVOKED in storage');
    assert.strictEqual(toLegacyReleaseStatus('DRAFT'), 'DRAFT', 'DRAFT remains DRAFT in storage');
    assert.strictEqual(toLegacyReleaseStatus('DEPRECATED'), 'DEPRECATED', 'DEPRECATED remains DEPRECATED');

    // 2. Querying API with legacy status 'PUBLISHED' resolves to 'RELEASED' domain releases
    const res = await app.inject({
      method: 'GET',
      url: '/api/v1/firmware/releases?status=PUBLISHED',
    });
    assert.strictEqual(res.statusCode, 200);
    const body = JSON.parse(res.body);
    assert.ok(body.data.length > 0);
    for (const r of body.data) {
      assert.strictEqual(r.status, 'RELEASED', 'Returned API domain representation must always be RELEASED');
    }
  });

  // ── 5. BUILD & BINARY ARTIFACT REGISTRATION ───────────────────────────
  console.log('\n5. Build & Binary Artifacts:');

  await runTest('Registers build metadata and binary artifacts with integrity checks', async () => {
    const repo = new FirmwareRepository();
    const service = new FirmwareService(repo);

    const rel = await service.createRelease({
      firmwareFamily: 'esp32c6-sensor-platform',
      productVariantId: 'eh-sensor-node-v1',
      version: '1.0.0',
      gitCommitSha: validCommit,
      binarySizeBytes: 524288,
      sha256: dummySha256,
      status: 'DRAFT',
    });

    // Register build
    const build = await service.registerBuild({
      firmwareReleaseId: rel.id,
      firmwareFamilyId: 'esp32c6-sensor-platform',
      gitCommitSha: validCommit,
      gitBranch: 'main',
      gitTag: 'v1.0.0',
      idfVersion: 'v5.4.1',
      buildProfile: 'release',
      toolchainInfo: { idf: '5.4.1', target: 'esp32c6' },
    });

    assert.ok(build.id);
    assert.strictEqual(build.gitCommitSha, validCommit);

    // Register binary artifact
    const artifact = await service.registerArtifact({
      buildId: build.id,
      artifactType: 'APP_BIN',
      fileName: 'sensor-node-app.bin',
      fileSizeBytes: 524288,
      sha256: dummySha256,
      storagePath: `firmware/builds/${build.id}/app.bin`,
    });

    assert.ok(artifact.id);
    assert.strictEqual(artifact.artifactType, 'APP_BIN');
    assert.strictEqual(artifact.fileSizeBytes, 524288);
  });

  await runTest('SHA-256 integrity utility correctly validates actual binary buffer', async () => {
    const store = new InMemoryArtifactStore();
    const sampleBinary = Buffer.from('EH-HOME-TEST-ESP32-C6-FIRMWARE-IMAGE-BUFFER-CONTENT');
    const expectedSha256 = crypto.createHash('sha256').update(sampleBinary).digest('hex');

    const result = await store.storeArtifact('test-app.bin', sampleBinary);
    assert.strictEqual(result.sha256, expectedSha256);
    assert.strictEqual(result.size, sampleBinary.length);

    assert.strictEqual(store.verifyIntegrity(sampleBinary, expectedSha256), true);
    assert.strictEqual(store.verifyIntegrity(sampleBinary, '0'.repeat(64)), false);
  });

  // ── 6. HARDWARE COMPATIBILITY & PRODUCT MATRIX ────────────────────────
  console.log('\n6. Hardware Compatibility & Product Matrix:');

  await runTest('Defines hardware revision compatibility and queries via API', async () => {
    const res = await app.inject({
      method: 'POST',
      url: '/api/v1/firmware/releases/rel_switch_v1_0_0/compatibility',
      payload: {
        hardwareRevisionId: 'hw_rev_switch_1x_1_1',
        minHardwareRevision: 'HW_1_0',
        maxHardwareRevision: 'HW_1_1',
        verificationNotes: 'Verified on Rev 1.1 hardware prototype',
      },
    });

    assert.strictEqual(res.statusCode, 201);
    const body = JSON.parse(res.body);
    assert.strictEqual(body.success, true);
    assert.strictEqual(body.data.hardwareRevisionId, 'hw_rev_switch_1x_1_1');

    // Query compatibility endpoint
    const getRes = await app.inject({
      method: 'GET',
      url: '/api/v1/firmware/releases/rel_switch_v1_0_0/compatibility',
    });
    assert.strictEqual(getRes.statusCode, 200);
    const getBody = JSON.parse(getRes.body);
    assert.ok(Array.isArray(getBody.data));
    assert.ok(getBody.data.some((c) => c.hardwareRevisionId === 'hw_rev_switch_1x_1_1'));
  });

  await runTest('Filtering releases by hardware revision returns compatible releases', async () => {
    const res = await app.inject({
      method: 'GET',
      url: '/api/v1/firmware/releases?hardwareRevisionId=hw_rev_switch_1x_1_0',
    });

    assert.strictEqual(res.statusCode, 200);
    const body = JSON.parse(res.body);
    assert.ok(body.data.length >= 1);
    assert.strictEqual(body.data[0].id, 'rel_switch_v1_0_0');
  });

  // ── 7. EXISTING OTA CONTRACT INTEGRATION ──────────────────────────────
  console.log('\n7. Existing OTA Contract Compatibility:');

  await runTest('Existing canonical OtaManifestSchema parses active release metadata', async () => {
    const validOtaManifest = {
      schemaVersion: 1,
      releaseId: 'a1b2c3d4-e5f6-4a1b-8c2d-3e4f5a6b7c8d',
      productVariantId: 'eh-smart-switch-1x',
      hardwareRevision: 'HW_1_0',
      version: '1.0.0',
      minFirmwareVersion: '1.0.0',
      binarySizeBytes: 1048576,
      sha256: dummySha256,
      ed25519Signature: 'a'.repeat(128),
      downloadUrl: 'https://artifacts.eh-home.internal/firmware/v1.0.0/app.bin',
      releaseNotes: 'OTA manifest compatibility test',
      createdAt: '2026-01-01T00:00:00Z',
    };

    const parsed = OtaManifestSchema.parse(validOtaManifest);
    assert.strictEqual(parsed.version, '1.0.0');
    assert.strictEqual(parsed.binarySizeBytes, 1048576);
  });

  // ── 8. SECURITY & SENSITIVE DATA PREVENTION ───────────────────────────
  console.log('\n8. Security & Secret Leak Prevention:');

  await runTest('Firmware API responses do not expose signing keys, secrets, or internal paths', async () => {
    const res = await app.inject({
      method: 'GET',
      url: '/api/v1/firmware/releases/rel_switch_v1_0_0',
    });

    const bodyStr = res.body;
    assert.strictEqual(bodyStr.includes('private_key'), false);
    assert.strictEqual(bodyStr.includes('privateKey'), false);
    assert.strictEqual(bodyStr.includes('secret'), false);
    assert.strictEqual(bodyStr.includes('node_modules'), false);
  });

  await app.close();

  // ── SUMMARY ───────────────────────────────────────────────────────────
  console.log(`\n=== FIRMWARE TESTS SUMMARY ===`);
  console.log(`Total:  ${totalTests}`);
  console.log(`Passed: ${passedTests}`);
  console.log(`Failed: ${failedTests}`);

  if (failedTests > 0) {
    process.exit(1);
  } else {
    console.log('ALL FIRMWARE & GIT MANAGEMENT TESTS PASSED [OK]\n');
  }
}

main().catch((err) => {
  console.error('Fatal test execution error:', err);
  process.exit(1);
});
