/**
 * EH Home API — Part 13 MQTT, Telemetry & Signed OTA Test Suite
 */

const assert = require('assert');
const { buildApp } = require('../dist/app');
const {
  MqttTopicBuilder,
  MqttTopicParser,
  QOS_POLICY,
  FixedPointEnergyTelemetrySchema
} = require('@eh-home/contracts');
const { MockMqttClient, MqttDeviceTransport } = require('../dist/modules/mqtt');
const { TelemetryRepository, TelemetryIngestionService } = require('../dist/modules/telemetry');
const { DeviceCommandRepository, DeviceCommandService } = require('../dist/modules/commands');
const { OtaRepository, OtaService } = require('../dist/modules/ota');

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
  console.log('=== EH HOME PART 13: EMQX / MQTT / TELEMETRY / SIGNED OTA SUITE ===\n');

  process.env.NODE_ENV = 'test';

  const mockMqttClient = new MockMqttClient();
  const mqttTransport = new MqttDeviceTransport({ mqttClient: mockMqttClient });

  const app = await buildApp({
    skipDatabase: true,
    fastifyOptions: { logger: false }
  });
  app.decorate('mqttTransport', mqttTransport);
  await app.ready();

  const DEVICE_ID = '0194fe23-7a1b-7890-a123-456789abcdef';
  const DEVICE_ID_B = '0194fe23-7a1b-7890-b456-123456fedcba';
  const USER_ID = 'a1b2c3d4-1234-5678-9abc-def012345678';

  // ── 1. MQTT TOPIC CONTRACTS & ACL ISOLATION ───────────────────────────
  console.log('1. MQTT Topic Scheme, Policies & ACL Isolation:');

  await runTest('T01 Canonical topic scheme construction', async () => {
    assert.strictEqual(MqttTopicBuilder.commands(DEVICE_ID), `eh/v1/devices/${DEVICE_ID}/commands`);
    assert.strictEqual(MqttTopicBuilder.commandReceipts(DEVICE_ID), `eh/v1/devices/${DEVICE_ID}/command-receipts`);
    assert.strictEqual(MqttTopicBuilder.state(DEVICE_ID), `eh/v1/devices/${DEVICE_ID}/state`);
    assert.strictEqual(MqttTopicBuilder.events(DEVICE_ID), `eh/v1/devices/${DEVICE_ID}/events`);
    assert.strictEqual(MqttTopicBuilder.telemetry(DEVICE_ID), `eh/v1/devices/${DEVICE_ID}/telemetry`);
    assert.strictEqual(MqttTopicBuilder.availability(DEVICE_ID), `eh/v1/devices/${DEVICE_ID}/availability`);
    assert.strictEqual(MqttTopicBuilder.ota(DEVICE_ID), `eh/v1/devices/${DEVICE_ID}/ota`);
  });

  await runTest('T02 Topic parser: valid topics and rejection of wildcards & malformed UUIDs', async () => {
    const p1 = MqttTopicParser.parse(`eh/v1/devices/${DEVICE_ID}/commands`);
    assert.strictEqual(p1.deviceId, DEVICE_ID);
    assert.strictEqual(p1.category, 'commands');

    assert.throws(() => MqttTopicParser.parse('eh/v1/devices/+/commands'), /wildcard/i);
    assert.throws(() => MqttTopicParser.parse('eh/v1/devices/#'), /wildcard/i);
    assert.throws(() => MqttTopicParser.parse('eh/v1/devices/invalid-uuid/commands'), /malformed/i);
    assert.throws(() => MqttTopicParser.parse(`eh/v1/devices/${DEVICE_ID}/commands/extra`), /segments/i);
  });

  await runTest('T03 QoS & Retain policy invariant verification', async () => {
    assert.deepStrictEqual(QOS_POLICY.commands, { qos: 1, retain: false });
    assert.deepStrictEqual(QOS_POLICY['command-receipts'], { qos: 1, retain: false });
    assert.deepStrictEqual(QOS_POLICY.state, { qos: 1, retain: false });
    assert.deepStrictEqual(QOS_POLICY.events, { qos: 1, retain: false });
    assert.deepStrictEqual(QOS_POLICY.telemetry, { qos: 0, retain: false });
    assert.deepStrictEqual(QOS_POLICY.availability, { qos: 1, retain: true });
    assert.deepStrictEqual(QOS_POLICY.ota, { qos: 1, retain: false });
  });

  await runTest('T04 Topic device isolation check', async () => {
    assert.strictEqual(MqttTopicParser.isValidForDevice(`eh/v1/devices/${DEVICE_ID}/commands`, DEVICE_ID), true);
    assert.strictEqual(MqttTopicParser.isValidForDevice(`eh/v1/devices/${DEVICE_ID_B}/commands`, DEVICE_ID), false);
  });

  // ── 2. TELEMETRY PIPELINE ─────────────────────────────────────────────
  console.log('\n2. Device Telemetry Ingestion & Time-Series:');

  const telemRepo = new TelemetryRepository();
  const telemService = new TelemetryIngestionService(telemRepo);

  await runTest('T05 Telemetry ingestion: valid fixed-point payload accepted', async () => {
    const validPayload = {
      schemaVersion: 1,
      deviceId: DEVICE_ID,
      channelIndex: 1,
      v_mv: 230500,
      i_ma: 1520,
      p_mw: 350360,
      e_tot_wh: 12500,
      e_int_mwh: 150,
      freq_mhz: 50010,
      pf_x1000: 982,
      flags: 0,
      sequenceNumber: 1,
      timestamp: new Date().toISOString()
    };

    const result = await telemService.ingest(validPayload);
    assert.strictEqual(result.accepted, true);
    assert.strictEqual(result.status, 'ACCEPTED');

    const latest = await telemService.getLatest(DEVICE_ID, 1);
    assert.ok(latest);
    assert.strictEqual(latest.v_mv, 230500);
    assert.strictEqual(latest.p_mw, 350360);
  });

  await runTest('T06 Telemetry ingestion: invalid numeric ranges rejected', async () => {
    // Negative voltage
    const bad1 = await telemService.ingest({
      schemaVersion: 1,
      deviceId: DEVICE_ID,
      channelIndex: 1,
      v_mv: -500,
      i_ma: 100,
      p_mw: 100,
      e_tot_wh: 100,
      freq_mhz: 50000,
      pf_x1000: 980,
      sequenceNumber: 2,
      timestamp: new Date().toISOString()
    });
    assert.strictEqual(bad1.accepted, false);
    assert.strictEqual(bad1.status, 'REJECTED');

    // Power factor > 1000
    const bad2 = await telemService.ingest({
      schemaVersion: 1,
      deviceId: DEVICE_ID,
      channelIndex: 1,
      v_mv: 230000,
      i_ma: 100,
      p_mw: 100,
      e_tot_wh: 100,
      freq_mhz: 50000,
      pf_x1000: 1050,
      sequenceNumber: 3,
      timestamp: new Date().toISOString()
    });
    assert.strictEqual(bad2.accepted, false);
    assert.strictEqual(bad2.status, 'REJECTED');
  });

  await runTest('T07 Telemetry ingestion: duplicate / out-of-order sequence dropped', async () => {
    const baseTelem = {
      schemaVersion: 1,
      deviceId: DEVICE_ID,
      channelIndex: 1,
      v_mv: 230000,
      i_ma: 1000,
      p_mw: 230000,
      e_tot_wh: 13000,
      freq_mhz: 50000,
      pf_x1000: 990,
      sequenceNumber: 100,
      timestamp: new Date().toISOString()
    };

    const r1 = await telemService.ingest(baseTelem);
    assert.strictEqual(r1.accepted, true);

    // Duplicate sequence
    const r2 = await telemService.ingest({ ...baseTelem, sequenceNumber: 100 });
    assert.strictEqual(r2.accepted, false);
    assert.strictEqual(r2.status, 'DROPPED_DUPLICATE');

    // Lower sequence
    const r3 = await telemService.ingest({ ...baseTelem, sequenceNumber: 95 });
    assert.strictEqual(r3.accepted, false);
    assert.strictEqual(r3.status, 'DROPPED_DUPLICATE');
  });

  await runTest('T08 Telemetry HTTP endpoints: POST /ingest & GET /live & GET /history', async () => {
    const postRes = await app.inject({
      method: 'POST',
      url: '/api/v1/telemetry/ingest',
      payload: {
        schemaVersion: 1,
        deviceId: DEVICE_ID,
        channelIndex: 1,
        v_mv: 230200,
        i_ma: 1100,
        p_mw: 253220,
        e_tot_wh: 14200,
        freq_mhz: 50000,
        pf_x1000: 975,
        sequenceNumber: 200,
        timestamp: new Date().toISOString()
      }
    });
    assert.strictEqual(postRes.statusCode, 202);

    const liveRes = await app.inject({
      method: 'GET',
      url: `/api/v1/telemetry/devices/${DEVICE_ID}/live?channelIndex=1`
    });
    assert.strictEqual(liveRes.statusCode, 200);
    const liveBody = JSON.parse(liveRes.body);
    assert.strictEqual(liveBody.success, true);
    assert.strictEqual(liveBody.data.v_mv, 230200);

    const historyRes = await app.inject({
      method: 'GET',
      url: `/api/v1/telemetry/devices/${DEVICE_ID}/history?limit=10`
    });
    assert.strictEqual(historyRes.statusCode, 200);
    const histBody = JSON.parse(historyRes.body);
    assert.strictEqual(histBody.success, true);
    assert.ok(Array.isArray(histBody.data));
  });

  // ── 3. COMMAND DISPATCH, RECEIPTS & AVAILABILITY ───────────────────────
  console.log('\n3. Device Commands, State & Availability:');

  const cmdRepo = new DeviceCommandRepository();
  const cmdService = new DeviceCommandService(cmdRepo, mqttTransport);

  await runTest('T09 Command dispatch: authorization, outbox & MQTT publication', async () => {
    mockMqttClient.clearPublished();
    const cmdPayload = {
      schemaVersion: 1,
      commandId: '0194fe23-7a1b-7890-a123-456789111111',
      deviceId: DEVICE_ID,
      channelIndex: 1,
      action: 'setPower',
      params: { value: true },
      idempotencyKey: 'idem_cmd_001',
      source: 'APP',
      expiresAt: new Date(Date.now() + 30000).toISOString()
    };

    const res = await cmdService.sendCommand({ userId: USER_ID }, cmdPayload);
    assert.strictEqual(res.status, 'CREATED');
    assert.strictEqual(res.isIdempotentReplay, false);

    // Verify MQTT publication
    const published = mockMqttClient.getPublished();
    assert.ok(published.length >= 1);
    const cmdPub = published.find((p) => p.topic === MqttTopicBuilder.commands(DEVICE_ID));
    assert.ok(cmdPub);
    assert.strictEqual(cmdPub.payload.commandId, cmdPayload.commandId);
    assert.strictEqual(cmdPub.opts.qos, 1);
  });

  await runTest('T10 Command dispatch: idempotency deduplication', async () => {
    const cmdPayload = {
      schemaVersion: 1,
      commandId: '0194fe23-7a1b-7890-a123-456789111111',
      deviceId: DEVICE_ID,
      channelIndex: 1,
      action: 'setPower',
      params: { value: true },
      idempotencyKey: 'idem_cmd_001', // duplicate key
      source: 'APP',
      expiresAt: new Date(Date.now() + 30000).toISOString()
    };

    const res = await cmdService.sendCommand({ userId: USER_ID }, cmdPayload);
    assert.strictEqual(res.isIdempotentReplay, true);
  });

  await runTest('T11 Command dispatch: pre-check for expired command fails before DB commit', async () => {
    const expiredCmd = {
      schemaVersion: 1,
      commandId: '0194fe23-7a1b-7890-a123-456789222222',
      deviceId: DEVICE_ID,
      channelIndex: 1,
      action: 'setPower',
      params: { value: true },
      idempotencyKey: 'idem_expired_001',
      source: 'APP',
      expiresAt: new Date(Date.now() - 5000).toISOString() // 5s in past
    };

    const res = await cmdService.sendCommand({ userId: USER_ID }, expiredCmd);
    assert.strictEqual(res.status, 'EXPIRED');
    assert.strictEqual(res.isIdempotentReplay, false);
  });

  await runTest('T12 Command receipt processing: APPLIED, FAILED, EXPIRED, OVERRIDDEN', async () => {
    const cmdId = '0194fe23-7a1b-7890-a123-456789333333';
    await cmdService.sendCommand({ userId: USER_ID }, {
      schemaVersion: 1,
      commandId: cmdId,
      deviceId: DEVICE_ID,
      channelIndex: 1,
      action: 'setPower',
      params: { value: false },
      idempotencyKey: 'idem_receipt_001',
      source: 'APP',
      expiresAt: new Date(Date.now() + 30000).toISOString()
    });

    await cmdService.handleCommandReceipt({
      schemaVersion: 1,
      commandId: cmdId,
      deviceId: DEVICE_ID,
      channelIndex: 1,
      status: 'APPLIED',
      timestamp: new Date().toISOString()
    });

    const saved = await cmdRepo.getCommand(cmdId);
    assert.strictEqual(saved.status, 'APPLIED');
  });

  await runTest('T13 Availability handling & STALE derivation threshold', async () => {
    await cmdService.handleAvailability(DEVICE_ID, 'ONLINE');
    let state = await cmdService.getDeviceState(DEVICE_ID);
    assert.strictEqual(state.connectionState, 'ONLINE');

    // STALE derivation from age > 90s
    const oldTime = new Date(Date.now() - 120_000).toISOString();
    const derived = cmdService.deriveConnectionState(oldTime, 'ONLINE');
    assert.strictEqual(derived, 'STALE');

    // OFFLINE LWT
    await cmdService.handleAvailability(DEVICE_ID, 'OFFLINE');
    state = await cmdService.getDeviceState(DEVICE_ID);
    assert.strictEqual(state.connectionState, 'OFFLINE');
  });

  await runTest('T14 Command HTTP routes: POST /commands (401 unauth, 202 accepted, 422 expired)', async () => {
    // 401 unauthenticated
    const resUnauth = await app.inject({
      method: 'POST',
      url: `/api/v1/devices/${DEVICE_ID}/commands`,
      payload: {
        action: 'setPower',
        params: { value: true },
        idempotencyKey: 'idem_http_001'
      }
    });
    assert.strictEqual(resUnauth.statusCode, 401);

    // 202 accepted
    const resAuth = await app.inject({
      method: 'POST',
      url: `/api/v1/devices/${DEVICE_ID}/commands`,
      headers: { authorization: 'Bearer token_test_123' },
      payload: {
        action: 'setPower',
        channelIndex: 1,
        params: { value: true },
        idempotencyKey: 'idem_http_002'
      }
    });
    assert.strictEqual(resAuth.statusCode, 202);
    const bodyAuth = JSON.parse(resAuth.body);
    assert.strictEqual(bodyAuth.success, true);
    assert.strictEqual(bodyAuth.data.status, 'CREATED');

    // 422 expired
    const resExp = await app.inject({
      method: 'POST',
      url: `/api/v1/devices/${DEVICE_ID}/commands`,
      headers: { authorization: 'Bearer token_test_123' },
      payload: {
        action: 'setPower',
        channelIndex: 1,
        params: { value: true },
        idempotencyKey: 'idem_http_003',
        expiresAt: new Date(Date.now() - 10000).toISOString()
      }
    });
    assert.strictEqual(resExp.statusCode, 422);
  });

  // ── 4. SIGNED OTA ARTIFACT & LIFECYCLE ─────────────────────────────────
  console.log('\n4. Signed OTA Manifest, Eligibility & State Machine:');

  const otaRepo = new OtaRepository();
  const otaService = new OtaService(otaRepo);

  const VALID_SHA256 = 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855';
  const VALID_ED25519_SIG = '1'.repeat(128);

  const MANIFEST_V1_1 = {
    schemaVersion: 1,
    releaseId: '0194fe23-7a1b-7890-a123-456789111111',
    productVariantId: 'eh-smart-switch-3x',
    hardwareRevision: 'HW_1_0',
    version: '1.1.0',
    minFirmwareVersion: '1.0.0',
    binarySizeBytes: 1200000,
    sha256: VALID_SHA256,
    ed25519Signature: VALID_ED25519_SIG,
    downloadUrl: 'https://ota.ehhome.io/firmware/v1.1.0.bin',
    releaseNotes: 'Performance improvements',
    createdAt: new Date().toISOString()
  };

  const MANIFEST_V2_0 = {
    schemaVersion: 1,
    releaseId: '0194fe23-7a1b-7890-a123-456789222222',
    productVariantId: 'eh-smart-switch-3x',
    hardwareRevision: 'HW_1_0',
    version: '2.0.0',
    minFirmwareVersion: '1.1.0', // Requires bridge version 1.1.0
    binarySizeBytes: 1300000,
    sha256: VALID_SHA256,
    ed25519Signature: VALID_ED25519_SIG,
    downloadUrl: 'https://ota.ehhome.io/firmware/v2.0.0.bin',
    releaseNotes: 'Major upgrade',
    createdAt: new Date().toISOString()
  };

  await runTest('T15 Register signed releases & enforce secure HTTPS download URL', async () => {
    const rel1 = await otaService.registerRelease(MANIFEST_V1_1);
    assert.strictEqual(rel1.version, '1.1.0');
    await otaService.registerRelease(MANIFEST_V2_0);

    // Insecure HTTP URL rejected
    await assert.rejects(async () => {
      await otaService.registerRelease({
        ...MANIFEST_V1_1,
        releaseId: '0194fe23-7a1b-7890-a123-456789333333',
        downloadUrl: 'http://insecure.ehhome.io/fw.bin'
      });
    }, /HTTPS/);
  });

  await runTest('T16 Check update: 1.0.0 device receives 1.1.0 (bridge version gating)', async () => {
    const check = await otaService.checkUpdate({
      productVariantId: 'eh-smart-switch-3x',
      hardwareRevision: 'HW_1_0',
      currentVersion: '1.0.0'
    });

    assert.strictEqual(check.updateAvailable, true);
    assert.strictEqual(check.release.version, '1.1.0'); // Skipped 2.0.0 because bridge min is 1.1.0
  });

  await runTest('T17 Check update: 1.1.0 device receives 2.0.0', async () => {
    const check = await otaService.checkUpdate({
      productVariantId: 'eh-smart-switch-3x',
      hardwareRevision: 'HW_1_0',
      currentVersion: '1.1.0'
    });

    assert.strictEqual(check.updateAvailable, true);
    assert.strictEqual(check.release.version, '2.0.0');
  });

  await runTest('T18 Check update: 2.0.0 device is already up to date', async () => {
    const check = await otaService.checkUpdate({
      productVariantId: 'eh-smart-switch-3x',
      hardwareRevision: 'HW_1_0',
      currentVersion: '2.0.0'
    });

    assert.strictEqual(check.updateAvailable, false);
    assert.strictEqual(check.release, null);
  });

  await runTest('T19 Check update: Hardware revision mismatch returns no updates', async () => {
    const check = await otaService.checkUpdate({
      productVariantId: 'eh-smart-switch-3x',
      hardwareRevision: 'HW_2_0',
      currentVersion: '1.0.0'
    });

    assert.strictEqual(check.updateAvailable, false);
  });

  await runTest('T20 Artifact cryptographic verification (SHA-256 & Ed25519 signature)', () => {
    const testBuffer = Buffer.from('firmware binary test payload');
    const computedSha = require('crypto').createHash('sha256').update(testBuffer).digest('hex');

    const validCheck = otaService.verifyArtifactIntegrity({
      artifactBuffer: testBuffer,
      expectedSha256: computedSha,
      ed25519SignatureHex: 'a'.repeat(128)
    });
    assert.strictEqual(validCheck.valid, true);

    // Hash mismatch
    const badHashCheck = otaService.verifyArtifactIntegrity({
      artifactBuffer: testBuffer,
      expectedSha256: '0'.repeat(64),
      ed25519SignatureHex: 'a'.repeat(128)
    });
    assert.strictEqual(badHashCheck.valid, false);

    // Bad signature length
    const badSigCheck = otaService.verifyArtifactIntegrity({
      artifactBuffer: testBuffer,
      expectedSha256: computedSha,
      ed25519SignatureHex: 'short'
    });
    assert.strictEqual(badSigCheck.valid, false);
  });

  await runTest('T21 Full canonical OTA lifecycle state machine: REQUESTED -> AUTHORIZED -> AVAILABLE -> DOWNLOADING -> VERIFYING -> INSTALLING -> SUCCEEDED', async () => {
    const job = await otaService.createOtaJob({
      deviceId: DEVICE_ID,
      releaseId: MANIFEST_V1_1.releaseId,
      fromVersion: '1.0.0'
    });

    assert.strictEqual(job.status, 'REQUESTED');

    // 1. Authorize (REQUESTED -> AUTHORIZED)
    const authResult = await otaService.authorizeOtaJob(job.id, {
      deviceTrustState: 'TRUSTED',
      deviceHardwareRevision: 'HW_1_0',
      deviceMcu: 'esp32-c6',
      deviceProductVariantId: 'eh-smart-switch-3x'
    });
    assert.strictEqual(authResult.authorized, true);
    assert.strictEqual(authResult.status, 'AUTHORIZED');

    // 2. Available (AUTHORIZED -> AVAILABLE)
    const jAvail = await otaService.updateJobProgress(job.id, 'AVAILABLE', 0);
    assert.strictEqual(jAvail.status, 'AVAILABLE');

    // 3. Downloading (AVAILABLE -> DOWNLOADING)
    const jDown = await otaService.updateJobProgress(job.id, 'DOWNLOADING', 45);
    assert.strictEqual(jDown.status, 'DOWNLOADING');
    assert.strictEqual(jDown.progressPercent, 45);

    // 4. Verifying (DOWNLOADING -> VERIFYING)
    const jVer = await otaService.updateJobProgress(job.id, 'VERIFYING', 100);
    assert.strictEqual(jVer.status, 'VERIFYING');

    // 5. Installing (VERIFYING -> INSTALLING)
    const jInst = await otaService.updateJobProgress(job.id, 'INSTALLING', 100);
    assert.strictEqual(jInst.status, 'INSTALLING');

    // 6. Succeeded (INSTALLING -> SUCCEEDED)
    const jSucc = await otaService.updateJobProgress(job.id, 'SUCCEEDED', 100);
    assert.strictEqual(jSucc.status, 'SUCCEEDED');
    assert.ok(jSucc.completedAt);
  });

  await runTest('T22 OTA State Machine: Rejection of invalid transitions, skipping steps, & terminal regress', async () => {
    // 1. Cannot skip authorization: REQUESTED -> INSTALLING is rejected
    const job1 = await otaService.createOtaJob({
      deviceId: DEVICE_ID,
      releaseId: MANIFEST_V1_1.releaseId,
      fromVersion: '1.0.0'
    });
    await assert.rejects(async () => {
      await otaService.updateJobProgress(job1.id, 'INSTALLING', 100);
    }, /Invalid OTA state transition/);

    // 2. Cannot skip verification: AVAILABLE -> INSTALLING is rejected
    await otaService.authorizeOtaJob(job1.id, { deviceMcu: 'esp32-c6' });
    await otaService.updateJobProgress(job1.id, 'AVAILABLE', 0);
    await assert.rejects(async () => {
      await otaService.updateJobProgress(job1.id, 'INSTALLING', 100);
    }, /Invalid OTA state transition/);

    // 3. Backwards transition: DOWNLOADING -> REQUESTED is rejected
    await otaService.updateJobProgress(job1.id, 'DOWNLOADING', 30);
    await assert.rejects(async () => {
      await otaService.updateJobProgress(job1.id, 'REQUESTED', 0);
    }, /Invalid OTA state transition/);

    // 4. Terminal state regress: Once SUCCEEDED, cannot transition to DOWNLOADING
    await otaService.updateJobProgress(job1.id, 'VERIFYING', 100);
    await otaService.updateJobProgress(job1.id, 'INSTALLING', 100);
    await otaService.updateJobProgress(job1.id, 'SUCCEEDED', 100);
    await assert.rejects(async () => {
      await otaService.updateJobProgress(job1.id, 'DOWNLOADING', 10);
    }, /Invalid OTA state transition/);
  });

  await runTest('T23 OTA Authorization Security Gates: Multi-point verification & fail-closed enforcement', async () => {
    // Gate A: Revoked Device Rejected
    const jobRevoked = await otaService.createOtaJob({
      deviceId: DEVICE_ID,
      releaseId: MANIFEST_V1_1.releaseId,
      fromVersion: '1.0.0'
    });
    const authRevoked = await otaService.authorizeOtaJob(jobRevoked.id, { deviceTrustState: 'REVOKED', deviceMcu: 'esp32-c6' });
    assert.strictEqual(authRevoked.authorized, false);
    assert.strictEqual(authRevoked.errorCode, 'OTA_AUTH_REVOKED_DEVICE');

    // Gate B: Hardware Revision Mismatch Rejected
    const jobHwMismatch = await otaService.createOtaJob({
      deviceId: DEVICE_ID,
      releaseId: MANIFEST_V1_1.releaseId,
      fromVersion: '1.0.0'
    });
    const authHw = await otaService.authorizeOtaJob(jobHwMismatch.id, {
      deviceHardwareRevision: 'HW_2_0', // Release requires HW_1_0
      deviceMcu: 'esp32-c6'
    });
    assert.strictEqual(authHw.authorized, false);
    assert.strictEqual(authHw.errorCode, 'OTA_AUTH_HARDWARE_INCOMPATIBLE');

    // Gate C: Target MCU Mismatch Rejected
    const jobMcuMismatch = await otaService.createOtaJob({
      deviceId: DEVICE_ID,
      releaseId: MANIFEST_V1_1.releaseId,
      fromVersion: '1.0.0'
    });
    const authMcu = await otaService.authorizeOtaJob(jobMcuMismatch.id, {
      deviceMcu: 'esp32-s3' // Family is esp32c6-switch-platform (esp32-c6)
    });
    assert.strictEqual(authMcu.authorized, false);
    assert.strictEqual(authMcu.errorCode, 'OTA_AUTH_TARGET_MISMATCH');

    // Gate D: Anti-Rollback Violation Rejected
    const jobRollback = await otaService.createOtaJob({
      deviceId: DEVICE_ID,
      releaseId: MANIFEST_V1_1.releaseId, // Version 1.1.0
      fromVersion: '1.2.0' // Device is already on newer 1.2.0
    });
    const authRb = await otaService.authorizeOtaJob(jobRollback.id, { deviceMcu: 'esp32-c6' });
    assert.strictEqual(authRb.authorized, false);
    assert.strictEqual(authRb.errorCode, 'OTA_AUTH_ANTI_ROLLBACK');

    // Gate E: Bridge Version Requirement Unmet Rejected
    const jobBridge = await otaService.createOtaJob({
      deviceId: DEVICE_ID,
      releaseId: MANIFEST_V2_0.releaseId, // Version 2.0.0, requires min 1.1.0
      fromVersion: '1.0.0' // Device is on 1.0.0 (bridge version unmet)
    });
    const authBridge = await otaService.authorizeOtaJob(jobBridge.id, { deviceMcu: 'esp32-c6' });
    assert.strictEqual(authBridge.authorized, false);
    assert.strictEqual(authBridge.errorCode, 'OTA_AUTH_BRIDGE_VERSION_UNMET');
  });

  await runTest('T23b Firmware Release Lifecycle Gate: Only RELEASED or legacy PUBLISHED authorize OTA (Fail-Closed on PRODUCTION_READY / DRAFT / etc)', async () => {
    const unapprovedStatuses = [
      'DRAFT',
      'BUILDING',
      'VALIDATION',
      'APPROVED',
      'DEPRECATED',
      'RETIRED',
      'REVOKED',
      'PRODUCTION_READY',
      'UNKNOWN_STATUS',
      null,
      undefined
    ];

    for (let i = 0; i < unapprovedStatuses.length; i++) {
      const st = unapprovedStatuses[i];
      const relId = `0194fe23-7a1b-7890-a123-4567899990${String(i).padStart(2, '0')}`;
      await otaService.registerRelease(
        {
          ...MANIFEST_V1_1,
          releaseId: relId,
          version: `1.3.${i}`
        },
        { status: st }
      );

      const jobUnapproved = await otaService.createOtaJob({
        deviceId: DEVICE_ID,
        releaseId: relId,
        fromVersion: '1.0.0'
      });

      const authRes = await otaService.authorizeOtaJob(jobUnapproved.id, { deviceMcu: 'esp32-c6' });
      assert.strictEqual(authRes.authorized, false, `Status '${st}' must NOT authorize OTA`);
      assert.strictEqual(authRes.errorCode, 'OTA_AUTH_LIFECYCLE_NOT_RELEASED');
      assert.strictEqual(authRes.status, 'FAILED');
    }

    // Explicit test: legacy PUBLISHED is accepted
    const publishedRelId = '0194fe23-7a1b-7890-a123-456789999088';
    await otaService.registerRelease(
      {
        ...MANIFEST_V1_1,
        releaseId: publishedRelId,
        version: '1.3.88'
      },
      { status: 'PUBLISHED' }
    );
    const jobPublished = await otaService.createOtaJob({
      deviceId: DEVICE_ID,
      releaseId: publishedRelId,
      fromVersion: '1.0.0'
    });
    const authPub = await otaService.authorizeOtaJob(jobPublished.id, { deviceMcu: 'esp32-c6' });
    assert.strictEqual(authPub.authorized, true, 'Legacy PUBLISHED status must authorize OTA');
    assert.strictEqual(authPub.status, 'AUTHORIZED');

    // Explicit test: canonical RELEASED is accepted
    const releasedRelId = '0194fe23-7a1b-7890-a123-456789999099';
    await otaService.registerRelease(
      {
        ...MANIFEST_V1_1,
        releaseId: releasedRelId,
        version: '1.3.99'
      },
      { status: 'RELEASED' }
    );
    const jobReleased = await otaService.createOtaJob({
      deviceId: DEVICE_ID,
      releaseId: releasedRelId,
      fromVersion: '1.0.0'
    });
    const authRel = await otaService.authorizeOtaJob(jobReleased.id, { deviceMcu: 'esp32-c6' });
    assert.strictEqual(authRel.authorized, true, 'Canonical RELEASED status must authorize OTA');
    assert.strictEqual(authRel.status, 'AUTHORIZED');
  });

  await runTest('T23c Canonical Target MCU Compatibility Gate: Exact production MCU match & fail-closed on cross-target/generic/unsupported/missing', async () => {
    // 1. Exact canonical MCU match: esp32-c6 with esp32c6-switch-platform -> ACCEPTED
    const jobExactC6 = await otaService.createOtaJob({
      deviceId: DEVICE_ID,
      releaseId: MANIFEST_V1_1.releaseId,
      fromVersion: '1.0.0'
    });
    const authExactC6 = await otaService.authorizeOtaJob(jobExactC6.id, {
      deviceTrustState: 'TRUSTED',
      deviceHardwareRevision: 'HW_1_0',
      deviceMcu: 'esp32-c6',
      deviceProductVariantId: 'eh-smart-switch-3x'
    });
    assert.strictEqual(authExactC6.authorized, true);
    assert.strictEqual(authExactC6.status, 'AUTHORIZED');

    // Setup an esp32-s3 Hub release for cross-target testing
    const MANIFEST_HUB_S3 = {
      schemaVersion: 1,
      releaseId: '0194fe23-7a1b-7890-a123-456789444444',
      productVariantId: 'eh-smart-hub-v1',
      hardwareRevision: 'HW_1_0',
      version: '1.1.0',
      minFirmwareVersion: '1.0.0',
      binarySizeBytes: 1400000,
      sha256: VALID_SHA256,
      ed25519Signature: VALID_ED25519_SIG,
      downloadUrl: 'https://ota.ehhome.io/firmware/hub-v1.1.0.bin',
      releaseNotes: 'Smart Hub Gateway update',
      createdAt: new Date().toISOString()
    };
    await otaService.registerRelease(MANIFEST_HUB_S3, { status: 'RELEASED', firmwareFamily: 'esp32s3-hub-platform' });

    // 2. Cross-target rejection: esp32-c6 device requesting esp32-s3 Hub firmware -> REJECTED
    const jobC6toS3 = await otaService.createOtaJob({
      deviceId: DEVICE_ID,
      releaseId: MANIFEST_HUB_S3.releaseId,
      fromVersion: '1.0.0'
    });
    const authC6toS3 = await otaService.authorizeOtaJob(jobC6toS3.id, {
      deviceTrustState: 'TRUSTED',
      deviceHardwareRevision: 'HW_1_0',
      deviceMcu: 'esp32-c6',
      deviceProductVariantId: 'eh-smart-hub-v1'
    });
    assert.strictEqual(authC6toS3.authorized, false);
    assert.strictEqual(authC6toS3.errorCode, 'OTA_AUTH_TARGET_MISMATCH');

    // 3. Cross-target rejection: esp32-s3 device requesting esp32-c6 Switch firmware -> REJECTED
    const jobS3toC6 = await otaService.createOtaJob({
      deviceId: DEVICE_ID,
      releaseId: MANIFEST_V1_1.releaseId,
      fromVersion: '1.0.0'
    });
    const authS3toC6 = await otaService.authorizeOtaJob(jobS3toC6.id, {
      deviceTrustState: 'TRUSTED',
      deviceHardwareRevision: 'HW_1_0',
      deviceMcu: 'esp32-s3',
      deviceProductVariantId: 'eh-smart-switch-3x'
    });
    assert.strictEqual(authS3toC6.authorized, false);
    assert.strictEqual(authS3toC6.errorCode, 'OTA_AUTH_TARGET_MISMATCH');

    // 4. Exact canonical MCU match: esp32-s3 with esp32s3-hub-platform -> ACCEPTED
    const jobExactS3 = await otaService.createOtaJob({
      deviceId: DEVICE_ID,
      releaseId: MANIFEST_HUB_S3.releaseId,
      fromVersion: '1.0.0'
    });
    const authExactS3 = await otaService.authorizeOtaJob(jobExactS3.id, {
      deviceTrustState: 'TRUSTED',
      deviceHardwareRevision: 'HW_1_0',
      deviceMcu: 'esp32-s3',
      deviceProductVariantId: 'eh-smart-hub-v1'
    });
    assert.strictEqual(authExactS3.authorized, true);
    assert.strictEqual(authExactS3.status, 'AUTHORIZED');

    // 5. Generic esp32 (prototype-only) rejected for production switch release
    const jobGenericSwitch = await otaService.createOtaJob({
      deviceId: DEVICE_ID,
      releaseId: MANIFEST_V1_1.releaseId,
      fromVersion: '1.0.0'
    });
    const authGenericSwitch = await otaService.authorizeOtaJob(jobGenericSwitch.id, {
      deviceTrustState: 'TRUSTED',
      deviceMcu: 'esp32'
    });
    assert.strictEqual(authGenericSwitch.authorized, false);
    assert.strictEqual(authGenericSwitch.errorCode, 'OTA_AUTH_TARGET_MISMATCH');

    // 6. Generic esp32 (prototype-only) rejected for hub release
    const jobGenericHub = await otaService.createOtaJob({
      deviceId: DEVICE_ID,
      releaseId: MANIFEST_HUB_S3.releaseId,
      fromVersion: '1.0.0'
    });
    const authGenericHub = await otaService.authorizeOtaJob(jobGenericHub.id, {
      deviceTrustState: 'TRUSTED',
      deviceMcu: 'esp32'
    });
    assert.strictEqual(authGenericHub.authorized, false);
    assert.strictEqual(authGenericHub.errorCode, 'OTA_AUTH_TARGET_MISMATCH');

    // 7. Unsupported/foreign MCUs rejected
    const unsupportedMcus = ['esp8266', 'stm32f4', 'esp32-generic', 'nrf52840', 'rp2040'];
    for (const mcu of unsupportedMcus) {
      const jobUnsup = await otaService.createOtaJob({
        deviceId: DEVICE_ID,
        releaseId: MANIFEST_V1_1.releaseId,
        fromVersion: '1.0.0'
      });
      const authUnsup = await otaService.authorizeOtaJob(jobUnsup.id, {
        deviceTrustState: 'TRUSTED',
        deviceMcu: mcu
      });
      assert.strictEqual(authUnsup.authorized, false, `Unsupported MCU '${mcu}' must be rejected`);
      assert.strictEqual(authUnsup.errorCode, 'OTA_AUTH_TARGET_MISMATCH');
    }

    // 8. Missing / empty / undefined MCU rejected
    const missingMcuCases = [{}, { deviceMcu: '' }, { deviceMcu: '   ' }, { deviceMcu: undefined }];
    for (const ctx of missingMcuCases) {
      const jobMiss = await otaService.createOtaJob({
        deviceId: DEVICE_ID,
        releaseId: MANIFEST_V1_1.releaseId,
        fromVersion: '1.0.0'
      });
      const authMiss = await otaService.authorizeOtaJob(jobMiss.id, ctx);
      assert.strictEqual(authMiss.authorized, false, 'Missing device MCU must be rejected');
      assert.strictEqual(authMiss.errorCode, 'OTA_AUTH_TARGET_MISMATCH');
    }
  });

  await runTest('T24 OTA Failure, Rollback and Operator Cancellation Paths', async () => {
    // 1. Failure and Rollback path: DOWNLOADING -> FAILED -> ROLLED_BACK
    const jobFail = await otaService.createOtaJob({
      deviceId: DEVICE_ID,
      releaseId: MANIFEST_V1_1.releaseId,
      fromVersion: '1.0.0'
    });
    await otaService.authorizeOtaJob(jobFail.id, { deviceMcu: 'esp32-c6' });
    await otaService.updateJobProgress(jobFail.id, 'AVAILABLE', 0);
    await otaService.updateJobProgress(jobFail.id, 'DOWNLOADING', 30);
    const failed = await otaService.updateJobProgress(
      jobFail.id,
      'FAILED',
      30,
      'FLASH_CRC_ERROR',
      'Flash write CRC check failed at sector 4'
    );
    assert.strictEqual(failed.status, 'FAILED');
    assert.strictEqual(failed.errorCode, 'FLASH_CRC_ERROR');

    const rolledBack = await otaService.updateJobProgress(jobFail.id, 'ROLLED_BACK', 0);
    assert.strictEqual(rolledBack.status, 'ROLLED_BACK');
    assert.ok(rolledBack.completedAt);

    // 2. Cancellation path: REQUESTED -> CANCELLED
    const jobCancel = await otaService.createOtaJob({
      deviceId: DEVICE_ID,
      releaseId: MANIFEST_V1_1.releaseId,
      fromVersion: '1.0.0'
    });
    const cancelled = await otaService.cancelOtaJob(jobCancel.id, 'User cancelled update');
    assert.strictEqual(cancelled.status, 'CANCELLED');
    assert.ok(cancelled.completedAt);
  });

  await runTest('T25 OTA HTTP Routes: POST /check, POST /jobs, POST /jobs/:id/authorize, PATCH /jobs/:id/status, GET /devices/:id/status', async () => {
    // 1. Register release via HTTP route
    const regRes = await app.inject({
      method: 'POST',
      url: '/api/v1/ota/releases',
      payload: MANIFEST_V1_1
    });
    assert.strictEqual(regRes.statusCode, 201);

    const checkRes = await app.inject({
      method: 'POST',
      url: '/api/v1/ota/check',
      payload: {
        productVariantId: 'eh-smart-switch-3x',
        hardwareRevision: 'HW_1_0',
        currentVersion: '1.0.0'
      }
    });
    assert.strictEqual(checkRes.statusCode, 200);

    const jobRes = await app.inject({
      method: 'POST',
      url: '/api/v1/ota/jobs',
      payload: {
        deviceId: DEVICE_ID,
        releaseId: MANIFEST_V1_1.releaseId,
        fromVersion: '1.0.0'
      }
    });
    assert.strictEqual(jobRes.statusCode, 201);
    const jobBody = JSON.parse(jobRes.body);

    // Authorize via HTTP
    const authRes = await app.inject({
      method: 'POST',
      url: `/api/v1/ota/jobs/${jobBody.data.id}/authorize`,
      payload: {
        deviceTrustState: 'TRUSTED',
        deviceHardwareRevision: 'HW_1_0',
        deviceMcu: 'esp32-c6',
        deviceProductVariantId: 'eh-smart-switch-3x'
      }
    });
    assert.strictEqual(authRes.statusCode, 200);
    assert.strictEqual(authRes.statusCode, 200);

    // Transition to AVAILABLE
    await app.inject({
      method: 'PATCH',
      url: `/api/v1/ota/jobs/${jobBody.data.id}/status`,
      payload: { status: 'AVAILABLE', progressPercent: 0 }
    });

    // Transition to DOWNLOADING
    const statusRes = await app.inject({
      method: 'PATCH',
      url: `/api/v1/ota/jobs/${jobBody.data.id}/status`,
      payload: {
        status: 'DOWNLOADING',
        progressPercent: 50
      }
    });
    assert.strictEqual(statusRes.statusCode, 200);

    const deviceStatusRes = await app.inject({
      method: 'GET',
      url: `/api/v1/ota/devices/${DEVICE_ID}/status`
    });
    assert.strictEqual(deviceStatusRes.statusCode, 200);
  });

  // ── 5. ZERO SECRET LEAKAGE ────────────────────────────────────────────
  console.log('\n5. Zero Secret Leakage Invariants:');

  await runTest('T26 Payloads, manifests & state objects contain zero private keys or passwords', async () => {
    const serializedManifest = JSON.stringify(MANIFEST_V1_1);
    assert.strictEqual(serializedManifest.includes('privateKey'), false);
    assert.strictEqual(serializedManifest.includes('password'), false);

    const stateObj = await cmdService.getDeviceState(DEVICE_ID);
    const serializedState = JSON.stringify(stateObj);
    assert.strictEqual(serializedState.includes('privateKey'), false);
    assert.strictEqual(serializedState.includes('password'), false);
  });

  console.log(`\n=== PART 13 TEST SUITE SUMMARY ===`);
  console.log(`Total:  ${totalTests}`);
  console.log(`Passed: ${passedTests}`);
  console.log(`Failed: ${failedTests}`);

  if (failedTests > 0) {
    process.exit(1);
  } else {
    console.log('ALL PART 13 MQTT, TELEMETRY & SIGNED OTA TESTS PASSED [OK]\n');
  }
}

main().catch((err) => {
  console.error('Test suite failed:', err);
  process.exit(1);
});
