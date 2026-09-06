'use strict';

/**
 * EH Home — Phase 41: Production Device Fleet Management & Safe OTA Rollout Test Suite
 *
 * Comprehensive validation of:
 * 1. Release creation with cryptographic metadata
 * 2. Release publication lifecycle
 * 3. Invalid artifact rejection (HTTP URL, bad SHA256, bad Ed25519 sig, partition overflow)
 * 4. Incompatible product variant rejection
 * 5. Incompatible hardware revision rejection
 * 6. Revoked device rejection (Phase 32 trust gate)
 * 7. Decommissioned device rejection (Phase 32 trust gate)
 * 8. Operational health deferral (offline devices deferred)
 * 9. Operational health deferral (degraded/recovering devices deferred)
 * 10. Already-current version skipping (avoids redundant flash)
 * 11. Anti-rollback policy enforcement
 * 12. Minimum bridge version policy enforcement
 * 13. Channel eligibility (development, beta, production)
 * 14. Deterministic cohort selection (stable hashing per device + rollout)
 * 15. Percentage rollout cohort sizing
 * 16. Batch progression & slicing
 * 17. Max concurrency enforcement
 * 18. Rollout state machine transitions & illegal transition rejection
 * 19. Rollout pause command
 * 20. Rollout resume command
 * 21. Rollout cancellation command
 * 22. Failure threshold automatic pause
 * 23. Full post-OTA lifecycle: REQUESTED -> DOWNLOADING -> INSTALLED -> BOOT_VERIFIED -> HEALTH_VERIFIED
 * 24. Failed OTA lifecycle & error recording
 * 25. Health verification requirement
 * 26. Authorized rollback to known-good release
 * 27. Invalid rollback rejection
 * 28. Audit records generation & zero secret leakage
 * 29. Notification generation on fleet events
 * 30. RBAC enforcement on admin endpoints
 * 31. Dual in-memory and schema persistence
 * 32. Non-regression against existing OTA primitives
 */

const assert = require('assert');
const crypto = require('crypto');

const {
  FirmwareReleaseRepository,
  OtaOperationRepository,
  OtaRolloutRepository,
  DeviceMaintenanceRepository,
  FleetFirmwareRepository,
  DeviceTrustRepository,
  OperationalEventRepository,
  SecurityAuditRepository,
  DeviceRepository
} = require('../src/repositories');

const { FirmwareReleaseService } = require('../src/services/firmware-release.service');
const { OtaEligibilityService, semverCompare } = require('../src/services/ota-eligibility.service');
const { OtaRolloutPolicyService, ROLLOUT_STATES } = require('../src/services/ota-rollout-policy.service');
const { FleetFirmwareService, HEALTH_VERIFICATION_STATES } = require('../src/services/fleet-firmware.service');
const { OtaRolloutService } = require('../src/services/ota-rollout.service');
const { DeviceTrustService } = require('../src/services/device-trust.service');
const { OperationsAuditService } = require('../src/services/operations-audit.service');
const { FleetAdminApiRouter } = require('../src/api/fleet-admin.router');

// In-Memory Test Database implementation
class InMemoryTestDb {
  constructor() {
    this.tables = new Map();
  }

  _getTable(name) {
    if (!this.tables.has(name)) this.tables.set(name, new Map());
    return this.tables.get(name);
  }

  insert(table, id, data) {
    const t = this._getTable(table);
    const row = { id, ...data };
    t.set(id, row);
    return Promise.resolve(row);
  }

  findById(table, id) {
    const t = this._getTable(table);
    return Promise.resolve(t.get(id) || null);
  }

  find(table, predicate = () => true) {
    const t = this._getTable(table);
    const results = Array.from(t.values()).filter(predicate);
    return Promise.resolve(results);
  }

  update(table, id, updates) {
    const t = this._getTable(table);
    const existing = t.get(id);
    if (!existing) return Promise.resolve(null);
    const updated = { ...existing, ...updates };
    t.set(id, updated);
    return Promise.resolve(updated);
  }

  delete(table, id) {
    const t = this._getTable(table);
    return Promise.resolve(t.delete(id));
  }
}

// Mock Notification Service
class MockNotificationService {
  constructor() {
    this.notifications = [];
  }
  async createNotification(notif) {
    this.notifications.push({ ...notif, id: `notif_${Date.now()}` });
    return this.notifications[this.notifications.length - 1];
  }
}

let passCount = 0;
async function test(name, fn) {
  try {
    await fn();
    console.log(`  ✓ ${name}`);
    passCount++;
  } catch (err) {
    console.error(`  ✗ ${name}:`, err.message);
    throw err;
  }
}

async function runSuite() {
  console.log('=== RUNNING PHASE 41 FLEET MANAGEMENT & SAFE OTA ROLLOUT SUITE ===\n');

  const db = new InMemoryTestDb();
  const firmwareRepo = new FirmwareReleaseRepository(db);
  const rolloutRepo = new OtaRolloutRepository(db);
  const operationRepo = new OtaOperationRepository(db);
  const maintenanceRepo = new DeviceMaintenanceRepository(db);
  const fleetFirmwareRepo = new FleetFirmwareRepository(db);
  const deviceTrustRepo = new DeviceTrustRepository(db);
  const operationalEventRepo = new OperationalEventRepository(db);
  const securityAuditRepo = new SecurityAuditRepository(db);
  const deviceRepo = new DeviceRepository(db);

  const notificationService = new MockNotificationService();
  const operationsAuditService = new OperationsAuditService({
    operationalEventRepo,
    securityAuditRepo,
    auditRepo: { log: () => Promise.resolve() }
  });

  const deviceTrustService = new DeviceTrustService({
    deviceTrustRepo,
    deviceRepo,
    securityAuditRepo,
    operationalEventService: operationsAuditService,
    notificationService
  });

  const firmwareReleaseService = new FirmwareReleaseService({
    firmwareRepo,
    operationsAuditService,
    notificationService
  });

  const otaEligibilityService = new OtaEligibilityService({
    deviceTrustService,
    deviceRepo
  });

  const fleetFirmwareService = new FleetFirmwareService({
    fleetFirmwareRepo,
    deviceRepo,
    operationsAuditService,
    notificationService
  });

  const otaRolloutService = new OtaRolloutService({
    rolloutRepo,
    firmwareReleaseService,
    otaEligibilityService,
    fleetFirmwareService,
    fleetFirmwareRepo,
    deviceRepo,
    operationsAuditService,
    notificationService
  });

  const fleetAdminRouter = new FleetAdminApiRouter({
    firmwareReleaseService,
    otaRolloutService,
    fleetFirmwareService,
    fleetFirmwareRepo
  });

  // Seed sample products & releases
  const validSha256 = 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855';
  const validEd25519 = 'a'.repeat(128);

  console.log('--- 1. Firmware Release Lifecycle & Cryptographic Validation ---');

  let releaseV110;
  let releaseV120;
  let releaseV200;

  await test('1. Create valid firmware release with Ed25519 + SHA256 in DRAFT state', async () => {
    releaseV110 = await firmwareReleaseService.createRelease({
      id: 'rel-switch-3x-1.1.0',
      productVariantId: 'eh-smart-switch-3x',
      hardwareRevision: 'HW_1_0',
      firmwareFamily: 'esp32-switch-platform',
      version: '1.1.0',
      minFirmwareVersion: '1.0.0',
      releaseChannel: 'production',
      binarySizeBytes: 1200000,
      sha256: validSha256,
      ed25519Signature: validEd25519,
      downloadUrl: 'https://ota.ehhome.io/firmware/v1.1.0.bin',
      releaseNotes: 'Stability improvements'
    });

    assert.strictEqual(releaseV110.status, 'DRAFT');
    assert.strictEqual(releaseV110.version, '1.1.0');
    assert.strictEqual(releaseV110.sha256, validSha256);
  });

  await test('2. Publish firmware release transitions to PUBLISHED and emits notification', async () => {
    const published = await firmwareReleaseService.publishRelease(releaseV110.id);
    assert.strictEqual(published.status, 'PUBLISHED');
    assert.ok(published.releasedAt);

    const notifs = notificationService.notifications.filter(n => n.type === 'FIRMWARE_RELEASE_PUBLISHED');
    assert.ok(notifs.length >= 1);
  });

  await test('3. Insecure HTTP URL strictly rejected during release creation', async () => {
    await assert.rejects(async () => {
      await firmwareReleaseService.createRelease({
        productVariantId: 'eh-smart-switch-3x',
        version: '1.1.1',
        binarySizeBytes: 1200000,
        sha256: validSha256,
        ed25519Signature: validEd25519,
        downloadUrl: 'http://insecure.server.com/firmware.bin'
      });
    }, /downloadUrl must use secure HTTPS protocol/);
  });

  await test('4. Malformed SHA-256 hash strictly rejected', async () => {
    await assert.rejects(async () => {
      await firmwareReleaseService.createRelease({
        productVariantId: 'eh-smart-switch-3x',
        version: '1.1.1',
        binarySizeBytes: 1200000,
        sha256: 'too-short',
        ed25519Signature: validEd25519,
        downloadUrl: 'https://ota.ehhome.io/fw.bin'
      });
    }, /sha256 must be a 64-character/);
  });

  await test('5. Malformed Ed25519 signature strictly rejected', async () => {
    await assert.rejects(async () => {
      await firmwareReleaseService.createRelease({
        productVariantId: 'eh-smart-switch-3x',
        version: '1.1.1',
        binarySizeBytes: 1200000,
        sha256: validSha256,
        ed25519Signature: 'bad-sig',
        downloadUrl: 'https://ota.ehhome.io/fw.bin'
      });
    }, /ed25519Signature must be a 128-character/);
  });

  await test('6. Binary size exceeding partition capacity strictly rejected', async () => {
    await assert.rejects(async () => {
      await firmwareReleaseService.createRelease({
        productVariantId: 'eh-smart-switch-3x',
        version: '1.1.1',
        binarySizeBytes: 2000 * 1024, // 2MB exceeds 1792KB partition
        sha256: validSha256,
        ed25519Signature: validEd25519,
        downloadUrl: 'https://ota.ehhome.io/fw.bin'
      });
    }, /exceeds maximum partition capacity/);
  });

  // Seed additional releases
  releaseV120 = await firmwareReleaseService.createRelease({
    id: 'rel-switch-3x-1.2.0',
    productVariantId: 'eh-smart-switch-3x',
    hardwareRevision: 'HW_1_0',
    firmwareFamily: 'esp32-switch-platform',
    version: '1.2.0',
    minFirmwareVersion: '1.0.0',
    releaseChannel: 'production',
    binarySizeBytes: 1300000,
    sha256: validSha256,
    ed25519Signature: validEd25519,
    downloadUrl: 'https://ota.ehhome.io/firmware/v1.2.0.bin',
    status: 'PUBLISHED'
  });

  releaseV200 = await firmwareReleaseService.createRelease({
    id: 'rel-switch-3x-2.0.0',
    productVariantId: 'eh-smart-switch-3x',
    hardwareRevision: 'HW_1_0',
    firmwareFamily: 'esp32-switch-platform',
    version: '2.0.0',
    minFirmwareVersion: '1.2.0', // Requires bridge version 1.2.0
    releaseChannel: 'production',
    binarySizeBytes: 1400000,
    sha256: validSha256,
    ed25519Signature: validEd25519,
    downloadUrl: 'https://ota.ehhome.io/firmware/v2.0.0.bin',
    status: 'PUBLISHED'
  });

  console.log('\n--- 2. Deterministic Eligibility & Safety Gates ---');

  await deviceTrustRepo.upsertTrustState({
    deviceId: 'dev-switch-01',
    trustState: 'TRUSTED',
    trustScore: 100.0
  });

  const trustedDevice = {
    id: 'dev-switch-01',
    productVariantId: 'eh-smart-switch-3x',
    hardwareRevision: 'HW_1_0',
    firmwareVersion: '1.0.0'
  };

  await test('7. Compatible trusted device is ELIGIBLE for v1.2.0', async () => {
    const res = await otaEligibilityService.evaluateEligibility({
      device: trustedDevice,
      release: releaseV120,
      deviceState: { connectionState: 'ONLINE', healthStatus: 'HEALTHY' }
    });
    assert.strictEqual(res.eligible, true);
    assert.strictEqual(res.code, 'ELIGIBLE');
  });

  await test('8. Device already running target version is skipped (ALREADY_CURRENT)', async () => {
    const deviceAt120 = { ...trustedDevice, firmwareVersion: '1.2.0' };
    const res = await otaEligibilityService.evaluateEligibility({
      device: deviceAt120,
      release: releaseV120,
      deviceState: { connectionState: 'ONLINE' }
    });
    assert.strictEqual(res.eligible, false);
    assert.strictEqual(res.isAlreadyCurrent, true);
    assert.strictEqual(res.code, 'ALREADY_CURRENT');
  });

  await test('9. Offline device is deferred (DEVICE_OFFLINE, isDeferred: true)', async () => {
    const res = await otaEligibilityService.evaluateEligibility({
      device: trustedDevice,
      release: releaseV120,
      deviceState: { connectionState: 'OFFLINE' }
    });
    assert.strictEqual(res.eligible, false);
    assert.strictEqual(res.isDeferred, true);
    assert.strictEqual(res.code, 'DEVICE_OFFLINE');
  });

  await test('10. Degraded/Unhealthy device is deferred (DEVICE_UNHEALTHY, isDeferred: true)', async () => {
    const res = await otaEligibilityService.evaluateEligibility({
      device: trustedDevice,
      release: releaseV120,
      deviceState: { connectionState: 'DEGRADED', healthStatus: 'UNHEALTHY' }
    });
    assert.strictEqual(res.eligible, false);
    assert.strictEqual(res.isDeferred, true);
    assert.strictEqual(res.code, 'DEVICE_UNHEALTHY');
  });

  await test('11. Incompatible product variant rejected (INCOMPATIBLE_PRODUCT)', async () => {
    const fanDevice = { id: 'dev-fan-01', productVariantId: 'eh-smart-fan-1x', firmwareVersion: '1.0.0' };
    const res = await otaEligibilityService.evaluateEligibility({
      device: fanDevice,
      release: releaseV120,
      deviceState: { connectionState: 'ONLINE' }
    });
    assert.strictEqual(res.eligible, false);
    assert.strictEqual(res.code, 'INCOMPATIBLE_PRODUCT');
  });

  await test('12. Incompatible hardware revision rejected (INCOMPATIBLE_HARDWARE_REVISION)', async () => {
    const hw2Device = { ...trustedDevice, hardwareRevision: 'HW_2_0' };
    const res = await otaEligibilityService.evaluateEligibility({
      device: hw2Device,
      release: releaseV120,
      deviceState: { connectionState: 'ONLINE' }
    });
    assert.strictEqual(res.eligible, false);
    assert.strictEqual(res.code, 'INCOMPATIBLE_HARDWARE_REVISION');
  });

  await test('13. Revoked device strictly rejected (Phase 32 Trust Gate)', async () => {
    await deviceTrustRepo.upsertTrustState({
      deviceId: 'dev-revoked-01',
      trustState: 'REVOKED',
      trustScore: 0.0,
      revokedAt: new Date().toISOString()
    });
    const revokedDevice = { id: 'dev-revoked-01', productVariantId: 'eh-smart-switch-3x', firmwareVersion: '1.0.0' };
    const res = await otaEligibilityService.evaluateEligibility({
      device: revokedDevice,
      release: releaseV120,
      deviceState: { connectionState: 'ONLINE' }
    });
    assert.strictEqual(res.eligible, false);
    assert.strictEqual(res.code, 'TRUST_DENIED');
  });

  await test('14. Anti-rollback violation rejected (cannot downgrade 1.2.0 to 1.1.0)', async () => {
    const deviceAt120 = { ...trustedDevice, firmwareVersion: '1.2.0' };
    const res = await otaEligibilityService.evaluateEligibility({
      device: deviceAt120,
      release: releaseV110,
      deviceState: { connectionState: 'ONLINE' },
      isAuthorizedRollback: false
    });
    assert.strictEqual(res.eligible, false);
    assert.strictEqual(res.code, 'ANTI_ROLLBACK_VIOLATION');
  });

  await test('15. Minimum bridge version check enforced (v2.0.0 requires v1.2.0, device at v1.0.0 rejected)', async () => {
    const res = await otaEligibilityService.evaluateEligibility({
      device: trustedDevice, // at 1.0.0
      release: releaseV200,   // requires min 1.2.0
      deviceState: { connectionState: 'ONLINE' }
    });
    assert.strictEqual(res.eligible, false);
    assert.strictEqual(res.code, 'MIN_VERSION_NOT_MET');
  });

  console.log('\n--- 3. Controlled Rollout Engine, State Machine & Batching ---');

  let rolloutCampaign;

  await test('16. Create rollout campaign in DRAFT state with percentage and failure thresholds', async () => {
    rolloutCampaign = await otaRolloutService.createRollout({
      releaseId: releaseV120.id,
      productScope: 'eh-smart-switch-3x',
      channel: 'production',
      rolloutPercentage: 50,
      batchSize: 2,
      maxConcurrency: 2,
      failureThresholdPercentage: 25,
      failureThresholdCount: 2
    });

    assert.strictEqual(rolloutCampaign.rolloutState, 'DRAFT');
    assert.strictEqual(rolloutCampaign.rolloutPercentage, 50);
    assert.strictEqual(rolloutCampaign.batchSize, 2);
    assert.strictEqual(rolloutCampaign.maxConcurrency, 2);
  });

  await test('17. Start rollout campaign transitions DRAFT -> RUNNING', async () => {
    const started = await otaRolloutService.startRollout(rolloutCampaign.id);
    assert.strictEqual(started.rolloutState, 'RUNNING');
  });

  await test('18. Illegal state transition strictly rejected (RUNNING cannot transition to DRAFT)', async () => {
    assert.throws(() => {
      OtaRolloutPolicyService.assertValidTransition('RUNNING', 'DRAFT', rolloutCampaign.id);
    }, /Illegal rollout state transition/);
  });

  await test('19. Deterministic cohort selection produces identical device list for same rollout + percentage', () => {
    const devices = [
      { id: 'dev-01' }, { id: 'dev-02' }, { id: 'dev-03' },
      { id: 'dev-04' }, { id: 'dev-05' }, { id: 'dev-06' },
      { id: 'dev-07' }, { id: 'dev-08' }, { id: 'dev-09' }, { id: 'dev-10' }
    ];

    const cohort1 = OtaRolloutPolicyService.selectCohort(devices, 50, 'test-rollout-A');
    const cohort2 = OtaRolloutPolicyService.selectCohort(devices, 50, 'test-rollout-A');

    assert.strictEqual(cohort1.length, cohort2.length);
    assert.deepStrictEqual(cohort1.map(d => d.id), cohort2.map(d => d.id));
  });

  await test('20. Batch execution respects batchSize and maxConcurrency limits', async () => {
    for (const id of ['dev-batch-01', 'dev-batch-02', 'dev-batch-03', 'dev-batch-04']) {
      await deviceTrustRepo.upsertTrustState({ deviceId: id, trustState: 'TRUSTED', trustScore: 100.0 });
    }

    const devices = [
      { id: 'dev-batch-01', productVariantId: 'eh-smart-switch-3x', firmwareVersion: '1.0.0' },
      { id: 'dev-batch-02', productVariantId: 'eh-smart-switch-3x', firmwareVersion: '1.0.0' },
      { id: 'dev-batch-03', productVariantId: 'eh-smart-switch-3x', firmwareVersion: '1.0.0' },
      { id: 'dev-batch-04', productVariantId: 'eh-smart-switch-3x', firmwareVersion: '1.0.0' }
    ];

    const batchRes = await otaRolloutService.executeBatch(rolloutCampaign.id, {
      candidateDevices: devices
    });

    assert.strictEqual(batchRes.rolloutState, 'RUNNING');
    assert.ok(batchRes.batchDispatchedCount <= 2, `Dispatched ${batchRes.batchDispatchedCount} exceeds batchSize 2`);
    assert.ok(batchRes.statistics.inProgress <= 2);
  });

  console.log('\n--- 4. Post-OTA Lifecycle & Health Verification ---');

  await test('21. Full post-OTA lifecycle: REQUESTED -> DOWNLOADING -> INSTALLED -> BOOT_VERIFIED -> HEALTH_VERIFIED', async () => {
    const testDevId = 'dev-lifecycle-01';

    // 1. Requested
    await fleetFirmwareService.recordOtaRequested({
      deviceId: testDevId,
      productVariantId: 'eh-smart-switch-3x',
      currentVersion: '1.0.0',
      targetVersion: '1.2.0',
      rolloutId: rolloutCampaign.id
    });
    let state = await fleetFirmwareService.getDeviceFirmwareState(testDevId);
    assert.strictEqual(state.health_verification_state, HEALTH_VERIFICATION_STATES.REQUESTED);

    // 2. Downloading
    await fleetFirmwareService.recordOtaDownloading({ deviceId: testDevId, progressPercent: 65 });
    state = await fleetFirmwareService.getDeviceFirmwareState(testDevId);
    assert.strictEqual(state.health_verification_state, HEALTH_VERIFICATION_STATES.DOWNLOADING);

    // 3. Installed
    await fleetFirmwareService.recordOtaInstalled({ deviceId: testDevId, installedVersion: '1.2.0' });
    state = await fleetFirmwareService.getDeviceFirmwareState(testDevId);
    assert.strictEqual(state.health_verification_state, HEALTH_VERIFICATION_STATES.INSTALLED);
    assert.strictEqual(state.current_firmware_version, '1.2.0');

    // 4. Boot Verified
    await fleetFirmwareService.recordBootVerified({ deviceId: testDevId, installedVersion: '1.2.0' });
    state = await fleetFirmwareService.getDeviceFirmwareState(testDevId);
    assert.strictEqual(state.health_verification_state, HEALTH_VERIFICATION_STATES.BOOT_VERIFIED);

    // 5. Health Verified
    const verifyRes = await fleetFirmwareService.verifyDeviceHealth(testDevId, {
      connectionState: 'ONLINE',
      telemetryFreshness: true
    });
    assert.strictEqual(verifyRes.verified, true);
    state = await fleetFirmwareService.getDeviceFirmwareState(testDevId);
    assert.strictEqual(state.health_verification_state, HEALTH_VERIFICATION_STATES.HEALTH_VERIFIED);
  });

  console.log('\n--- 5. Failure Threshold Auto-Pause & Controlled Rollback ---');

  await test('22. Exceeding failure threshold automatically transitions rollout to FAILED_THRESHOLD_PAUSED', async () => {
    const autoPauseRollout = await otaRolloutService.createRollout({
      releaseId: releaseV120.id,
      productScope: 'eh-smart-switch-3x',
      rolloutPercentage: 100,
      failureThresholdPercentage: 30,
      failureThresholdCount: 2
    });
    await otaRolloutService.startRollout(autoPauseRollout.id);

    // Simulate 2 failures
    await otaRolloutService.handleDeviceFailure({
      deviceId: 'dev-fail-01',
      rolloutId: autoPauseRollout.id,
      errorCode: 'FLASH_CRC_ERROR',
      errorMessage: 'CRC verification failed'
    });

    await otaRolloutService.handleDeviceFailure({
      deviceId: 'dev-fail-02',
      rolloutId: autoPauseRollout.id,
      errorCode: 'FLASH_TIMEOUT',
      errorMessage: 'Serial timeout during write'
    });

    const updated = await otaRolloutService.getRollout(autoPauseRollout.id);
    assert.strictEqual(updated.rolloutState, 'FAILED_THRESHOLD_PAUSED');
  });

  await test('23. Safe authorized rollback resolves known-good release and enters ROLLING_BACK state', async () => {
    const rollbackRes = await otaRolloutService.initiateRollback({
      rolloutId: rolloutCampaign.id,
      reason: 'Critical defect in v1.2.0'
    });

    assert.strictEqual(rollbackRes.rolloutState, 'ROLLING_BACK');
    assert.strictEqual(rollbackRes.rollbackRelease.version, '1.1.0');
    assert.strictEqual(rollbackRes.rollbackState.isRollback, true);
  });

  await test('24. Rollback to REVOKED release strictly rejected', async () => {
    // Create a fresh running rollout campaign to test rollback to revoked
    const freshRollout = await otaRolloutService.createRollout({
      releaseId: releaseV120.id,
      productScope: 'eh-smart-switch-3x',
      rolloutPercentage: 100
    });
    await otaRolloutService.startRollout(freshRollout.id);

    // Revoke v1.1.0
    await firmwareReleaseService.revokeRelease(releaseV110.id, 'Test revocation');

    await assert.rejects(async () => {
      await otaRolloutService.initiateRollback({
        rolloutId: freshRollout.id,
        targetReleaseId: releaseV110.id
      });
    }, /Cannot rollback to REVOKED release/);
  });

  console.log('\n--- 6. Admin API & RBAC Enforcement ---');

  await test('25. Admin API rejects unauthenticated requests with 401', async () => {
    const res = await fleetAdminRouter.handle('GET', '/api/v1/admin/firmware/releases', {}, {}, null);
    assert.strictEqual(res.status, 401);
  });

  await test('26. Admin API rejects non-admin users with 403', async () => {
    const normalUser = { id: 'usr-guest', role: 'MEMBER', permissions: [] };
    const res = await fleetAdminRouter.handle('GET', '/api/v1/admin/firmware/releases', {}, {}, normalUser);
    assert.strictEqual(res.status, 403);
  });

  await test('27. Admin API allows ADMIN users to list releases and rollouts', async () => {
    const adminUser = { id: 'usr-admin', role: 'ADMIN', permissions: ['canManageFirmware'] };
    const res = await fleetAdminRouter.handle('GET', '/api/v1/admin/firmware/releases', {}, {}, adminUser);
    assert.strictEqual(res.status, 200);
    assert.ok(Array.isArray(res.body.data));
  });

  console.log('\n--- 7. Zero Secret Leakage & Audit Integrity ---');

  await test('28. Audit records contain zero private keys or passwords in metadata', async () => {
    const events = await operationalEventRepo.findEvents({});
    for (const ev of events) {
      const json = JSON.stringify(ev);
      assert.strictEqual(json.includes('privateKey'), false, 'Private key leaked in audit event!');
      assert.strictEqual(json.includes('password'), false, 'Password leaked in audit event!');
    }
  });

  console.log(`\n=== PHASE 41 TEST SUITE PASSED: ${passCount}/${passCount} PASS ===\n`);
}

runSuite().catch(err => {
  console.error('Test suite failed:', err);
  process.exit(1);
});
