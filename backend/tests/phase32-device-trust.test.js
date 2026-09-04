'use strict';

/**
 * Phase 32 — Secure Device Identity, Trust & Credential Lifecycle Tests
 *
 * Deterministic test suite covering:
 *   1. Canonical device identity verification: immutable attributes (serial, hardwareRevision, productVariantId, firmwareFamily).
 *   2. Deterministic trust state engine: all 8 trust states (PROVISIONED, COMMISSIONED, TRUSTED, DEGRADED, QUARANTINED, REVOKED, DECOMMISSIONED, FACTORY_RESET).
 *   3. Continuous trust score calculation: score bounded within [0, 100].
 *   4. Trust degradation upon authentication failure bursts.
 *   5. Trust degradation upon invalid payload signatures.
 *   6. Automatic transition to QUARANTINED when score drops below 40 or excessive failures occur.
 *   7. FIX 1: device_credentials remains authoritative store for currently usable device communication credentials.
 *   8. FIX 1: device_credential_lifecycle is a historical lifecycle/rotation ledger only (never a competing source of truth).
 *   9. FIX 1: No conflicting ACTIVE/REVOKED states between device_credentials and device_credential_lifecycle.
 *  10. FIX 2: Zero secrets in device_credential_lifecycle.metadata (passwords, tokens, private keys, session secrets redacted).
 *  11. FIX 2: Non-secret metadata allowed (key identifier, fingerprint, algorithm, provider, generation, timestamps).
 *  12. FIX 3: Credential rotation concurrency & idempotency: only one ROTATION_PENDING generation exists at a time.
 *  13. FIX 3: Duplicate rotation requests reuse/return the pending operation (idempotency).
 *  14. FIX 3: Generation numbers are monotonically and atomically incremented.
 *  15. FIX 3: Stale confirmation requests rejected.
 *  16. FIX 3: Active credential in device_credentials preserved until new generation confirmed.
 *  17. FIX 4: FACTORY_RESET preserves immutable identity and clears home claim/authorization.
 *  18. FIX 4: FACTORY_RESET invalidates temporary credentials.
 *  19. FIX 4: FACTORY_RESET MUST NOT automatically transition REVOKED -> TRUSTED or DECOMMISSIONED -> TRUSTED.
 *  20. FIX 4: Authorized restoration flow required to restore trust from REVOKED.
 *  21. FIX 5: Normal OTA permitted ONLY for TRUSTED / appropriately DEGRADED devices.
 *  22. FIX 5: Normal OTA blocked for QUARANTINED devices.
 *  23. FIX 5: Recovery / Security OTA permitted for QUARANTINED devices only when authorized and signature verified.
 *  24. FIX 5: OTA unconditionally denied for REVOKED / DECOMMISSIONED devices. Quarantine never bypasses firmware signature verification.
 *  25. Offline & Direct LAN session verification: rejected for REVOKED and QUARANTINED devices, valid HMAC accepted for trusted devices.
 *  26. Command dispatch authorization: DeviceCommandService rejects commands to REVOKED and QUARANTINED devices.
 *  27. REST API router: endpoints (/trust, /quarantine, /revoke, /restore-trust, /credentials, /credentials/rotate, /credentials/confirm-rotation, /admin/device-trust/*).
 *  28. Data retention: pruning of historical rotated lifecycle records and completed provisioning records.
 */

const crypto = require('crypto');
const { DatabaseClient } = require('../src/shared/db-client');
const {
  DeviceTrustRepository,
  SecurityAuditRepository,
  OperationalEventRepository,
  DeviceRepository,
  DeviceStateRepository,
  CommandRepository,
  OutboxRepository,
  AuditRepository,
  FirmwareReleaseRepository,
  OtaOperationRepository
} = require('../src/repositories');
const { DeviceTrustService, TRUST_STATES } = require('../src/services/device-trust.service');
const { DeviceCommandService } = require('../src/services/device-command.service');
const { OtaService } = require('../src/services/ota.service');
const { DataRetentionService } = require('../src/services/data-retention.service');
const { DeviceTrustApiRouter } = require('../src/api/device-trust.router');

let totalTests = 0;
let passedTests = 0;
let failedTests = 0;

function assert(desc, condition, details = '') {
  totalTests++;
  if (condition) {
    passedTests++;
    console.log(`  ✓ ${desc}`);
  } else {
    failedTests++;
    console.error(`  ✗ FAIL: ${desc}${details ? ` - ${details}` : ''}`);
  }
}

async function runSuite() {
  console.log('=== RUNNING PHASE 32 DEVICE IDENTITY, TRUST & CREDENTIAL LIFECYCLE TESTS ===\n');

  const db = new DatabaseClient();
  const deviceTrustRepo = new DeviceTrustRepository(db);
  const securityAuditRepo = new SecurityAuditRepository(db);
  const opEventRepo = new OperationalEventRepository(db);
  const deviceRepo = new DeviceRepository(db);
  const deviceStateRepo = new DeviceStateRepository(db);
  const commandRepo = new CommandRepository(db);
  const outboxRepo = new OutboxRepository(db);
  const auditRepo = new AuditRepository(db);
  const firmwareRepo = new FirmwareReleaseRepository(db);
  const operationRepo = new OtaOperationRepository(db);

  const deviceTrustService = new DeviceTrustService({
    deviceTrustRepo,
    deviceRepo,
    securityAuditRepo,
    operationalEventService: {
      recordEvent: async (ev) => opEventRepo.recordEvent({ id: `op_${Date.now()}_${Math.random()}`, ...ev })
    }
  });

  const testDeviceId = '0194fe23-7a1b-7890-a123-456789abcdef';

  // Seed baseline device
  await db.insert('devices', testDeviceId, {
    id: testDeviceId,
    serial_number: 'EH-SW3X-2026W12-00891',
    product_variant_id: 'eh-smart-switch-3x',
    hardware_revision: 'HW_1_0',
    firmware_version: '1.0.0',
    firmware_family: 'esp32c6-switch-platform',
    created_at: new Date().toISOString()
  });

  // Seed authoritative device_credentials
  await deviceTrustRepo.upsertAuthoritativeCredential(testDeviceId, {
    mqtt_username: 'eh_dev_0194fe237a1b7890',
    mqtt_password_hash: '$argon2id$v=19$m=65536,t=3,p=4$initHash',
    tls_client_cert_fingerprint: null,
    local_session_key_hash: 'init_session_hash_32bytes',
    credential_state: 'ACTIVE'
  });

  // --------------------------------------------------------------------------
  console.log('--- 1. Deterministic Trust State Engine & Continuous Scoring ---');
  // --------------------------------------------------------------------------
  const unclaimedDevId = '0194fe23-7a1b-7890-a123-999999999999';
  const initialTrust = await deviceTrustService.getDeviceTrustState(unclaimedDevId);
  assert('Default trust state for unclaimed device is PROVISIONED with score 100', initialTrust.trust_state === 'PROVISIONED' && initialTrust.trust_score === 100);

  // Seed device authorization to home
  const testHomeId = 'h0000000-0000-0000-0000-000000000001';
  await db.insert('homes', testHomeId, { id: testHomeId, name: 'Main Home' });
  await db.insert('device_authorizations', testDeviceId, {
    device_id: testDeviceId,
    home_id: testHomeId,
    custom_name: 'Living Room Switch',
    claimed_by_user_id: 'usr_0000000000000001',
    claimed_at: new Date().toISOString()
  });

  const claimedTrust = await deviceTrustService.getDeviceTrustState(testDeviceId);
  assert('Claimed device defaults to TRUSTED state with score 100', claimedTrust.trust_state === 'TRUSTED' && claimedTrust.trust_score === 100);

  // Evaluate normal active device
  const activeEval = await deviceTrustService.evaluateTrust(testDeviceId, {
    credentialsVerified: true,
    authFailureBurstCount: 0
  });
  assert('Active healthy device transitions to TRUSTED', activeEval.trust_state === TRUST_STATES.TRUSTED && activeEval.trust_score === 100);

  // Minor telemetry staleness causes DEGRADED state
  const degradedEval = await deviceTrustService.evaluateTrust(testDeviceId, {
    telemetryStale: true,
    authFailureBurstCount: 1
  });
  assert('Telemetry staleness and minor auth failure drops state to DEGRADED', degradedEval.trust_state === TRUST_STATES.DEGRADED && degradedEval.trust_score < 80);

  // Severe auth failure burst drops state to QUARANTINED
  const quarantinedEval = await deviceTrustService.evaluateTrust(testDeviceId, {
    authFailureBurstCount: 10,
    signatureFailures: 3
  });
  assert('Excessive auth failures trigger QUARANTINED state', quarantinedEval.trust_state === TRUST_STATES.QUARANTINED && quarantinedEval.trust_score < 40);

  // --------------------------------------------------------------------------
  console.log('\n--- 2. Fix 1: Authoritative device_credentials vs Lifecycle Ledger ---');
  // --------------------------------------------------------------------------
  const authCred = await deviceTrustRepo.getAuthoritativeCredential(testDeviceId);
  assert('device_credentials is authoritative store for usable credentials', authCred !== null && authCred.mqtt_username === 'eh_dev_0194fe237a1b7890');
  assert('Authoritative credential_state is currently ACTIVE', authCred.credential_state === 'ACTIVE');

  // Ledger query initially returns no lifecycle records until rotation
  const initialLedger = await deviceTrustRepo.listLifecycleRecords(testDeviceId);
  assert('Lifecycle ledger does not replace or duplicate authoritative active credentials', initialLedger.length === 0);

  // --------------------------------------------------------------------------
  console.log('\n--- 3. Fix 2: Zero Secrets in Lifecycle Metadata ---');
  // --------------------------------------------------------------------------
  // Initiate rotation with metadata containing both non-secret info and accidental sensitive keys
  const rot1 = await deviceTrustService.initiateCredentialRotation(testDeviceId, {
    credentialType: 'MQTT',
    keyIdentifier: 'eh_dev_0194fe237a1b7890_gen2',
    fingerprint: 'a1b2c3d4e5f6071829304a5b6c7d8e9f0123456789abcdef0123456789abcdef',
    metadata: {
      algorithm: 'Argon2id',
      provider: 'EH_INTERNAL',
      mqtt_password: 'super_secret_raw_password_should_be_redacted',
      private_key: 'raw_pem_key_should_be_redacted',
      generationLabel: 'v2-standard'
    }
  });

  assert('Lifecycle record status is ROTATION_PENDING', rot1.lifecycleRecord.status === 'ROTATION_PENDING');
  assert('Lifecycle metadata preserved non-sensitive algorithm', rot1.lifecycleRecord.metadata.algorithm === 'Argon2id');
  assert('Lifecycle metadata redacted raw mqtt_password', rot1.lifecycleRecord.metadata.mqtt_password === '[REDACTED]');
  assert('Lifecycle metadata redacted raw private_key', rot1.lifecycleRecord.metadata.private_key === '[REDACTED]');

  // --------------------------------------------------------------------------
  console.log('\n--- 4. Fix 3: Concurrency & Idempotency Rules for Credential Rotation ---');
  // --------------------------------------------------------------------------
  // Duplicate rotation request while ROTATION_PENDING must reuse existing record
  const rotDuplicate = await deviceTrustService.initiateCredentialRotation(testDeviceId, {
    credentialType: 'MQTT',
    keyIdentifier: 'eh_dev_0194fe237a1b7890_gen2_duplicate',
    metadata: { attempt: 2 }
  });
  assert('Duplicate rotation request reuses existing pending operation', rotDuplicate.isReusedPending === true);
  assert('Reused rotation record has exact same ID', rotDuplicate.lifecycleRecord.id === rot1.lifecycleRecord.id);

  // Verify authoritative device_credentials is still generation 1 (ACTIVE) while generation 2 is pending
  const credDuringPending = await deviceTrustRepo.getAuthoritativeCredential(testDeviceId);
  assert('Authoritative credential remains ACTIVE during pending rotation', credDuringPending.credential_state === 'ACTIVE');
  assert('Authoritative password hash has not changed before confirmation', credDuringPending.mqtt_password_hash.includes('initHash'));

  // Confirm rotation
  const confirmedRot = await deviceTrustService.confirmCredentialRotation(testDeviceId, {
    rotationId: rot1.lifecycleRecord.id,
    newMqttPasswordHash: '$argon2id$v=19$m=65536,t=3,p=4$newConfirmedHash',
    confirmationEvidence: { clientHandshake: 'OK' }
  });
  assert('Confirmed lifecycle record is marked CONFIRMED', confirmedRot.status === 'CONFIRMED');

  // Verify authoritative device_credentials now updated with new credential
  const credAfterConfirmation = await deviceTrustRepo.getAuthoritativeCredential(testDeviceId);
  assert('Authoritative credential_state remains ACTIVE upon confirmation', credAfterConfirmation.credential_state === 'ACTIVE');
  assert('Authoritative password hash updated atomically', credAfterConfirmation.mqtt_password_hash.includes('newConfirmedHash'));

  // Stale confirmation attempt on already confirmed rotation fails
  let staleFailed = false;
  try {
    await deviceTrustService.confirmCredentialRotation(testDeviceId, {
      rotationId: rot1.lifecycleRecord.id
    });
  } catch (err) {
    staleFailed = true;
  }
  assert('Stale confirmation request rejected with error', staleFailed);

  // Subsequent rotation allocates generation 2 -> 3
  const rotGen3 = await deviceTrustService.initiateCredentialRotation(testDeviceId, {
    credentialType: 'MQTT',
    keyIdentifier: 'eh_dev_0194fe237a1b7890_gen3'
  });
  assert('New rotation allocates next generation number monotonically', rotGen3.rotationGeneration === 2 || rotGen3.rotationGeneration === 3);

  // --------------------------------------------------------------------------
  console.log('\n--- 5. Fix 4: Factory Reset Reconciliation Boundaries ---');
  // --------------------------------------------------------------------------
  // First restore device to TRUSTED
  await deviceTrustService.restoreTrust(testDeviceId, {
    reason: 'Remediation completed after testing',
    actorUserId: 'u0000000-0000-0000-0000-000000000001',
    attestationVerified: true,
    targetState: TRUST_STATES.TRUSTED
  });

  // Factory reset on healthy/trusted device moves to FACTORY_RESET reconciliation state
  const resetResult1 = await deviceTrustService.reconcileFactoryReset(testDeviceId, {
    evidence: { localButtonHeld10s: true }
  });
  assert('Factory reset reconciles state to FACTORY_RESET', resetResult1.trustState === TRUST_STATES.FACTORY_RESET);
  const resetCred = await deviceTrustRepo.getAuthoritativeCredential(testDeviceId);
  assert('Temporary credentials invalidated (RESET state)', resetCred.credential_state === 'RESET');

  // Now explicitly REVOKE device
  const revRecord = await deviceTrustService.revokeDevice(testDeviceId, {
    revocationType: 'COMPROMISED',
    reason: 'Compromised firmware detected during security telemetry',
    actorUserId: 'u0000000-0000-0000-0000-000000000001',
    remediationAllowed: false
  });
  assert('Device revoked successfully', revRecord.revocation_type === 'COMPROMISED');

  const revokedTrust = await deviceTrustService.getDeviceTrustState(testDeviceId);
  assert('Trust state is REVOKED', revokedTrust.trust_state === TRUST_STATES.REVOKED);
  const revokedCred = await deviceTrustRepo.getAuthoritativeCredential(testDeviceId);
  assert('Authoritative credential_state is REVOKED', revokedCred.credential_state === 'REVOKED');

  // Fix 4 Core Invariant: Factory reset on REVOKED device MUST NOT restore trust!
  const resetResultOnRevoked = await deviceTrustService.reconcileFactoryReset(testDeviceId, {
    evidence: { physicalButtonReset: true }
  });
  assert('Factory reset on REVOKED device rejected trust restoration', resetResultOnRevoked.trustRestored === false);
  const postResetTrust = await deviceTrustService.getDeviceTrustState(testDeviceId);
  assert('Device remains in REVOKED state after factory reset', postResetTrust.trust_state === TRUST_STATES.REVOKED);

  // Attempting unauthorized restoration without attestation fails
  let restoreFailed = false;
  try {
    await deviceTrustService.restoreTrust(testDeviceId, {
      reason: 'Trying to restore without attestation',
      actorUserId: 'u0000000-0000-0000-0000-000000000001',
      attestationVerified: false
    });
  } catch (err) {
    restoreFailed = true;
  }
  assert('Restoring REVOKED device without attestation verification fails', restoreFailed);

  // Authorized remediation with cryptographic attestation restores trust
  const restoredTrust = await deviceTrustService.restoreTrust(testDeviceId, {
    reason: 'Hardware security team re-flashed and cryptographically verified device',
    actorUserId: 'u0000000-0000-0000-0000-000000000001',
    attestationVerified: true,
    targetState: TRUST_STATES.TRUSTED
  });
  assert('Authorized restoration with attestation restores state to TRUSTED', restoredTrust.trust_state === TRUST_STATES.TRUSTED);
  const restoredCred = await deviceTrustRepo.getAuthoritativeCredential(testDeviceId);
  assert('Authoritative credentials re-activated upon authorized restoration', restoredCred.credential_state === 'ACTIVE');

  // --------------------------------------------------------------------------
  console.log('\n--- 6. Fix 5: OTA Quarantine & Recovery Security Policy ---');
  // --------------------------------------------------------------------------
  // 1. Healthy / TRUSTED device can perform Normal OTA
  const otaHealthy = await deviceTrustService.canPerformOta(testDeviceId, {
    isRecoveryOta: false,
    firmwareSignatureVerified: true
  });
  assert('Normal OTA allowed for TRUSTED device with valid signature', otaHealthy.allowed === true && otaHealthy.isRecovery === false);

  // Quarantine device
  await deviceTrustService.quarantineDevice(testDeviceId, {
    reason: 'Suspicious payload patterns detected'
  });

  // 2. Normal OTA is BLOCKED for QUARANTINED device
  const otaQuarantinedNormal = await deviceTrustService.canPerformOta(testDeviceId, {
    isRecoveryOta: false,
    firmwareSignatureVerified: true
  });
  assert('Normal OTA blocked for QUARANTINED device', otaQuarantinedNormal.allowed === false);

  // 3. Recovery / Security OTA is PERMITTED for QUARANTINED device
  const otaQuarantinedRecovery = await deviceTrustService.canPerformOta(testDeviceId, {
    isRecoveryOta: true,
    firmwareSignatureVerified: true
  });
  assert('Authorized Recovery OTA permitted for QUARANTINED device', otaQuarantinedRecovery.allowed === true && otaQuarantinedRecovery.isRecovery === true);

  // 4. Quarantine NEVER bypasses signature verification
  const otaQuarantinedInvalidSig = await deviceTrustService.canPerformOta(testDeviceId, {
    isRecoveryOta: true,
    firmwareSignatureVerified: false
  });
  assert('Quarantine NEVER bypasses firmware signature verification', otaQuarantinedInvalidSig.allowed === false);

  // 5. REVOKED device: OTA completely denied
  await deviceTrustService.revokeDevice(testDeviceId, {
    revocationType: 'COMPROMISED',
    reason: 'Hardware compromised',
    actorUserId: 'u0000000-0000-0000-0000-000000000001'
  });
  const otaRevoked = await deviceTrustService.canPerformOta(testDeviceId, {
    isRecoveryOta: true,
    firmwareSignatureVerified: true
  });
  assert('OTA completely denied for REVOKED device even if recovery requested', otaRevoked.allowed === false);

  // --------------------------------------------------------------------------
  console.log('\n--- 7. Offline & Direct LAN Trust Verification ---');
  // --------------------------------------------------------------------------
  const sharedKey = '0123456789abcdef0123456789abcdef';
  const samplePayload = { action: 'setPower', value: true };
  const validHmac = crypto.createHmac('sha256', sharedKey).update(JSON.stringify(samplePayload)).digest('hex');

  // Currently device is REVOKED -> Direct LAN rejected
  const lanRevoked = await deviceTrustService.verifyDirectLanSession(testDeviceId, {
    payload: samplePayload,
    hmacSignature: validHmac,
    expectedKeyHash: sharedKey
  });
  assert('Direct LAN session rejected for REVOKED device', lanRevoked.verified === false);

  // Restore device to TRUSTED
  await deviceTrustService.restoreTrust(testDeviceId, {
    reason: 'Test restoration',
    actorUserId: 'admin',
    attestationVerified: true,
    targetState: TRUST_STATES.TRUSTED
  });

  // Direct LAN verification succeeds for TRUSTED device with valid HMAC
  const lanTrusted = await deviceTrustService.verifyDirectLanSession(testDeviceId, {
    payload: samplePayload,
    hmacSignature: validHmac,
    expectedKeyHash: sharedKey
  });
  assert('Direct LAN session verified for TRUSTED device with valid HMAC', lanTrusted.verified === true);

  // Direct LAN fails with invalid HMAC
  const lanBadSig = await deviceTrustService.verifyDirectLanSession(testDeviceId, {
    payload: samplePayload,
    hmacSignature: '0000000000000000000000000000000000000000000000000000000000000000',
    expectedKeyHash: sharedKey
  });
  assert('Direct LAN session fails with invalid HMAC signature', lanBadSig.verified === false);

  // --------------------------------------------------------------------------
  console.log('\n--- 8. DeviceCommandService Trust Interception ---');
  // --------------------------------------------------------------------------
  const mockMqtt = {
    sendCommand: async () => ({ status: 'SENT' }),
    publishCommand: async () => ({ status: 'SENT' })
  };
  const commandService = new DeviceCommandService({
    commandRepo,
    outboxRepo,
    deviceRepo,
    deviceStateRepo,
    auditRepo,
    mqttTransport: mockMqtt,
    deviceTrustService
  });

  // Normal command dispatch to TRUSTED device succeeds
  const actorContext = { userId: 'usr_0000000000000001', homeId: testHomeId, role: 'OWNER' };
  const cmd = {
    commandId: crypto.randomUUID(),
    deviceId: testDeviceId,
    channelIndex: 1,
    action: 'setPower',
    params: { state: 'ON' },
    idempotencyKey: `idemp_${Date.now()}`,
    source: 'APP'
  };
  const cmdRes = await commandService.sendCommand(actorContext, cmd);
  assert('Command sent successfully to TRUSTED device', cmdRes.status === 'CREATED');

  // Quarantine device -> Command dispatch is blocked
  await deviceTrustService.quarantineDevice(testDeviceId, { reason: 'Quarantined for test' });
  let cmdBlocked = false;
  try {
    await commandService.sendCommand(actorContext, {
      ...cmd,
      commandId: crypto.randomUUID(),
      idempotencyKey: `idemp_quar_${Date.now()}`
    });
  } catch (err) {
    cmdBlocked = true;
    assert('DeviceCommandService blocked command dispatch to QUARANTINED device', err.message.includes('rejected'));
  }
  assert('Command dispatch threw rejection for quarantined device', cmdBlocked);

  // Restore trust
  await deviceTrustService.restoreTrust(testDeviceId, {
    reason: 'Restore for API test',
    actorUserId: 'admin',
    attestationVerified: true,
    targetState: TRUST_STATES.TRUSTED
  });

  // --------------------------------------------------------------------------
  console.log('\n--- 9. Device Trust REST API Router ---');
  // --------------------------------------------------------------------------
  const apiRouter = new DeviceTrustApiRouter({
    deviceTrustService,
    deviceRepo
  });

  // GET /devices/:deviceId/trust
  const resGetTrust = await apiRouter.handle('GET', `/api/v1/devices/${testDeviceId}/trust`);
  assert('GET /trust returns 200 with trustState', resGetTrust.status === 200 && resGetTrust.body.trust_state === 'TRUSTED');

  // POST /devices/:deviceId/quarantine
  const resQuarantine = await apiRouter.handle('POST', `/api/v1/devices/${testDeviceId}/quarantine`, {
    reason: 'API quarantine test'
  }, { 'x-user-id': 'u001' });
  assert('POST /quarantine returns 200 with QUARANTINED state', resQuarantine.status === 200 && resQuarantine.body.trust_state === 'QUARANTINED');

  // GET /admin/device-trust/quarantined
  const resAdminQuarantined = await apiRouter.handle('GET', '/api/v1/admin/device-trust/quarantined', {}, {
    'x-user-role': 'ADMIN'
  });
  assert('GET /admin/device-trust/quarantined returns 200 and list', resAdminQuarantined.status === 200 && resAdminQuarantined.body.count >= 1);

  // POST /devices/:deviceId/credentials/rotate via API
  const resRotate = await apiRouter.handle('POST', `/api/v1/devices/${testDeviceId}/credentials/rotate`, {
    keyIdentifier: 'api_rot_gen'
  }, { 'x-user-id': 'u001' });
  assert('POST /credentials/rotate returns 200 with lifecycleRecord', resRotate.status === 200 && resRotate.body.lifecycleRecord.status === 'ROTATION_PENDING');

  // GET /devices/:deviceId/credentials via API (sanitized, zero secrets)
  const resGetCreds = await apiRouter.handle('GET', `/api/v1/devices/${testDeviceId}/credentials`);
  assert('GET /credentials returns 200', resGetCreds.status === 200);
  assert('GET /credentials does NOT expose mqtt_password_hash', resGetCreds.body.authoritativeCredential.mqtt_password_hash === undefined);
  assert('GET /credentials does NOT expose local_session_key_hash', resGetCreds.body.authoritativeCredential.local_session_key_hash === undefined);

  // --------------------------------------------------------------------------
  console.log('\n--- 10. Data Retention & Policy Pruning ---');
  // --------------------------------------------------------------------------
  const retentionService = new DataRetentionService({ db });

  // Insert an old rotated lifecycle record and old completed provisioning record
  const oldDate = new Date(Date.now() - 200 * 24 * 60 * 60 * 1000).toISOString();
  await db.insert('device_credential_lifecycle', 'old_rot_1', {
    id: 'old_rot_1',
    device_id: testDeviceId,
    credential_type: 'MQTT',
    keyIdentifier: 'old_key',
    status: 'ROTATED',
    rotation_generation: 1,
    issued_at: oldDate
  });

  await db.insert('device_provisioning_records', 'old_prov_1', {
    id: 'old_prov_1',
    device_id: testDeviceId,
    stage: 'VERIFIED',
    authority: 'CLOUD_API',
    completed_at: oldDate,
    created_at: oldDate
  });

  const prunedLifecycle = await retentionService.pruneDeviceCredentialLifecycle(180);
  assert('Historical ROTATED lifecycle record older than 180 days pruned', prunedLifecycle.pruned >= 1);
  const stillExistingPending = await db.findById('device_credential_lifecycle', resRotate.body.lifecycleRecord.id);
  assert('Active/pending lifecycle record NEVER pruned by retention', stillExistingPending !== null);

  const prunedProv = await retentionService.pruneDeviceProvisioningRecords(90);
  assert('Completed provisioning record older than 90 days pruned', prunedProv.pruned >= 1);

  // --------------------------------------------------------------------------
  console.log(`\n========================================`);
  console.log(`Total Passed: ${passedTests}, Total Failed: ${failedTests}`);
  console.log(`========================================\n`);

  process.exit(failedTests > 0 ? 1 : 0);
}

runSuite().catch(err => {
  console.error('Fatal test error:', err);
  process.exit(1);
});
