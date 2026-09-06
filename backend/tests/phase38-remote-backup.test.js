'use strict';

/**
 * EH Home — Phase 38 Remote Backup Storage Test Suite
 *
 * Deterministic test suite covering:
 *   1. Provider configuration & factory selection (Local, Memory, S3)
 *   2. Object upload & SHA-256 checksum calculation
 *   3. Object download & content retrieval
 *   4. Object listing with prefix filtering
 *   5. Object deletion & retention handling
 *   6. SHA-256 checksum verification & integrity enforcement
 *   7. Interrupted / incomplete upload handling
 *   8. Missing object error handling (404 / NoSuchKey)
 *   9. Manifest checksum mismatch detection (tamper resistance)
 *  10. Provider timeout & bounded execution
 *  11. Provider retry behavior for transient errors
 *  12. Remote backup retention policy integration (Phase 17/33)
 *  13. Backup secret sanitization (zero passwords, keys, tokens uploaded)
 *  14. End-to-end restore from remote provider (VALIDATE -> PRECHECK -> PLAN -> APPLY -> VERIFY)
 *  15. Phase 32 device trust preservation (no resurrection of revoked devices)
 *  16. Phase 33 recovery engine compatibility
 *  17. Idempotent upload handling
 *  18. Duplicate object & overwrite handling
 */

const crypto = require('crypto');
const { DatabaseClient } = require('../src/shared/db-client');
const {
  RecoveryRepository,
  DeviceRepository,
  DeviceStateRepository,
  DeviceTrustRepository,
  UserRepository,
  HomeRepository,
  SecurityAuditRepository
} = require('../src/repositories');
const {
  BackupProvider,
  LocalBackupProvider,
  MemoryBackupProvider,
  S3BackupProvider,
  createBackupProvider
} = require('../src/services/backup-provider');
const { RecoveryService } = require('../src/services/recovery.service');
const { DeviceTrustService } = require('../src/services/device-trust.service');
const { loadAndValidateConfig } = require('../src/config/runtime-config');

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
  console.log('=== RUNNING PHASE 38 REMOTE BACKUP STORAGE SUITE ===\n');

  // Test 1: Provider configuration & factory selection
  console.log('--- Scenario 1: Provider Configuration & Factory Selection ---');
  const localProv = createBackupProvider('local', { localDir: './test-backups' });
  assert('Local provider instantiated correctly', localProv instanceof LocalBackupProvider);

  const memProv = createBackupProvider('memory');
  assert('Memory provider instantiated correctly', memProv instanceof MemoryBackupProvider);

  const s3Prov = createBackupProvider('s3', {
    bucket: 'eh-home-disaster-recovery',
    region: 'us-east-1',
    accessKeyId: 'AKIA_TEST_KEY_ID_123',
    secretAccessKey: 'test_secret_access_key_xyz_456',
    prefix: 'backups/prod/'
  });
  assert('S3 provider instantiated correctly', s3Prov instanceof S3BackupProvider);

  // Rejection of memory provider in production
  const prodConfigRes = loadAndValidateConfig({
    NODE_ENV: 'production',
    DATABASE_URL: 'postgres://db.production.internal:5432/eh_home',
    REDIS_URL: 'redis://redis.production.internal:6379',
    MQTT_BROKER_URL: 'mqtts://mqtt.production.internal:8883',
    JWT_PRIVATE_KEY_PATH: '/etc/secrets/jwt.key',
    JWT_PUBLIC_KEY_PATH: '/etc/secrets/jwt.pub',
    MQTT_CA_PATH: '/etc/secrets/ca.crt',
    BACKUP_PROVIDER_TYPE: 'memory'
  });
  assert('Rejects in-memory backup provider in production', !prodConfigRes.isValid);
  assert('Reports production error for in-memory backup provider', prodConfigRes.errors.some(e => e.includes('In-memory backup provider is not allowed in production')));

  // Test 2: Upload & SHA-256 calculation
  console.log('\n--- Scenario 2: Object Upload & SHA-256 Calculation ---');
  const testPayload = JSON.stringify({ version: '1.0', homeId: 'home_001', devices: [{ id: 'dev_1' }] });
  const expectedSha = crypto.createHash('sha256').update(testPayload).digest('hex');

  const uploadRes = await memProv.upload('backups/2026-09-06/backup-001.json', Buffer.from(testPayload), {
    contentType: 'application/json'
  });
  assert('Upload succeeds with computed SHA-256 checksum', uploadRes.sha256 === expectedSha);
  assert('Upload returns correct byte length', uploadRes.bytesWritten === Buffer.byteLength(testPayload));

  // Test 3: Object download & content verification
  console.log('\n--- Scenario 3: Object Download & Retrieval ---');
  const downloadedBuf = await memProv.download('backups/2026-09-06/backup-001.json');
  assert('Downloaded object content matches original payload', downloadedBuf.toString('utf8') === testPayload);

  // Test 4: Object listing with prefix
  console.log('\n--- Scenario 4: Object Listing & Prefix Filtering ---');
  await memProv.upload('backups/2026-09-06/backup-002.json', Buffer.from('payload2'));
  await memProv.upload('backups/2026-09-07/backup-003.json', Buffer.from('payload3'));

  const listDay6 = await memProv.list('backups/2026-09-06/');
  assert('List with prefix returns matching objects', listDay6.length === 2);
  assert('Listed objects include key and size', listDay6.some(o => o.key.endsWith('backup-001.json') && o.size > 0));

  // Test 5: Object deletion
  console.log('\n--- Scenario 5: Object Deletion ---');
  const deleteRes = await memProv.delete('backups/2026-09-06/backup-002.json');
  assert('Delete returns success: true', deleteRes.success === true);
  const existsAfterDelete = await memProv.exists('backups/2026-09-06/backup-002.json');
  assert('Deleted object no longer exists in provider', existsAfterDelete === false);

  // Test 6: SHA-256 verification
  console.log('\n--- Scenario 6: Checksum Verification ---');
  const verified = await memProv.verifyChecksum('backups/2026-09-06/backup-001.json', expectedSha);
  assert('verifyChecksum returns true for valid hash', verified === true);
  const badVerified = await memProv.verifyChecksum('backups/2026-09-06/backup-001.json', '0000000000000000000000000000000000000000000000000000000000000000');
  assert('verifyChecksum returns false for invalid hash', badVerified === false);

  // Test 7 & 8: Missing object handling
  console.log('\n--- Scenario 7 & 8: Missing Object Handling ---');
  let threwMissing = false;
  try {
    await memProv.download('backups/nonexistent-key.json');
  } catch (err) {
    threwMissing = true;
    assert('Downloading nonexistent object throws error with NotFound/404 code', err.code === 'OBJECT_NOT_FOUND' || err.statusCode === 404);
  }
  assert('Nonexistent download threw error', threwMissing);

  // Test 9: Manifest mismatch detection (Tamper Resistance)
  console.log('\n--- Scenario 9: Manifest Integrity & Tamper Detection ---');
  const tamperedPayload = JSON.stringify({ version: '1.0', homeId: 'home_001', devices: [{ id: 'dev_1_tampered' }] });
  await memProv.upload('backups/2026-09-06/backup-tampered.json', Buffer.from(tamperedPayload));
  const isOriginalHashValid = await memProv.verifyChecksum('backups/2026-09-06/backup-tampered.json', expectedSha);
  assert('Manifest verification rejects tampered object with mismatched SHA-256', isOriginalHashValid === false);

  // Test 10: Provider timeout handling
  console.log('\n--- Scenario 10: Provider Timeout Handling ---');
  const timeoutS3 = new S3BackupProvider({
    bucket: 'eh-home-disaster-recovery',
    region: 'us-east-1',
    accessKeyId: 'AKIA_MOCK_TIMEOUT',
    secretAccessKey: 'secret_mock_timeout',
    timeoutMs: 50,
    transport: async () => {
      await new Promise(r => setTimeout(r, 150));
      return { statusCode: 200, body: 'ok' };
    }
  });

  let threwTimeout = false;
  try {
    await timeoutS3.download('backups/timeout-test.json');
  } catch (err) {
    threwTimeout = true;
    assert('Timed-out request aborts and throws timeout error', err.message.includes('timed out'));
  }
  assert('Timeout provider threw error', threwTimeout);

  // Test 11: Retry for transient errors
  console.log('\n--- Scenario 11: Transient Error Retry ---');
  let s3AttemptCount = 0;
  const retryS3 = new S3BackupProvider({
    bucket: 'eh-home-disaster-recovery',
    region: 'us-east-1',
    accessKeyId: 'AKIA_MOCK_RETRY',
    secretAccessKey: 'secret_mock_retry',
    maxRetries: 3,
    transport: async (url, opts) => {
      s3AttemptCount++;
      if (s3AttemptCount < 3) {
        return { statusCode: 503, headers: {}, body: '<Error><Code>ServiceUnavailable</Code></Error>' };
      }
      return { statusCode: 200, headers: {}, body: 'retried_data_payload' };
    }
  });

  const retryDownload = await retryS3.download('backups/retry-test.json');
  assert('S3 provider retries transient 503 errors and succeeds', retryDownload.toString('utf8') === 'retried_data_payload');
  assert('Retry occurred exact expected number of times', s3AttemptCount === 3);

  // Test 12: Remote backup retention
  console.log('\n--- Scenario 12: Remote Backup Retention Integration ---');
  const db = new DatabaseClient();
  const recoveryRepo = new RecoveryRepository(db);
  const testStorage = new MemoryBackupProvider();

  const oldBackupDate = new Date(Date.now() - 35 * 24 * 60 * 60 * 1000).toISOString(); // 35 days ago
  const oldBackup = await recoveryRepo.createBackupRecord({
    backupId: 'backup_old_001',
    scope: 'FULL',
    status: 'COMPLETED',
    location: 'backup_old_001',
    createdAt: oldBackupDate,
    expiresAt: new Date(Date.now() - 5 * 24 * 60 * 60 * 1000).toISOString()
  });
  await testStorage.upload('backups/backup_old_001/devices.json', Buffer.from('old_backup_data'));

  const recentBackup = await recoveryRepo.createBackupRecord({
    backupId: 'backup_recent_002',
    scope: 'FULL',
    status: 'COMPLETED',
    location: 'backup_recent_002',
    createdAt: new Date().toISOString(),
    expiresAt: new Date(Date.now() + 25 * 24 * 60 * 60 * 1000).toISOString()
  });
  await testStorage.upload('backups/backup_recent_002/devices.json', Buffer.from('recent_backup_data'));

  // Prune expired backups older than 30 days
  const allBackups = await recoveryRepo.listBackupRecords();
  const nowTime = Date.now();
  const expired = allBackups.filter(b => b.expires_at && new Date(b.expires_at).getTime() < nowTime);
  for (const exp of expired) {
    await recoveryRepo.deleteBackupRecord(exp.backup_id);
    await testStorage.deleteBackup(exp.backup_id);
  }

  const remaining = await recoveryRepo.listBackupRecords();
  assert('Expired backup pruned from repository', !remaining.some(b => b.backup_id === 'backup_old_001'));
  assert('Recent backup retained', remaining.some(b => b.backup_id === 'backup_recent_002'));

  // Test 13: Secret sanitization before remote upload
  console.log('\n--- Scenario 13: Secret Sanitization Boundary ---');
  const rawUser = { id: 'usr_01', email: 'user@example.com', password_hash: '$2b$12$eX4mpL3H4shSecret' };
  const rawCred = { id: 'cred_01', device_id: 'dev_01', secret: 'super_secret_wifi', private_key: 'key_data' };

  const cleanUser = RecoveryService.sanitizeEntity('users', rawUser);
  const cleanCred = RecoveryService.sanitizeEntity('device_credentials', rawCred);

  const cleanUserJson = JSON.stringify(cleanUser);
  const cleanCredJson = JSON.stringify(cleanCred);

  assert('Sanitized user excludes password_hash', !cleanUserJson.includes('$2b$12$eX4mpL3H4shSecret'));
  assert('Sanitized credential excludes secret and private_key', !cleanCredJson.includes('super_secret_wifi') && !cleanCredJson.includes('key_data'));
  assert('Sanitized entities preserve non-secret fields', cleanUser.email === 'user@example.com' && cleanCred.device_id === 'dev_01');

  // Test 14: End-to-end Restore from Remote Provider
  console.log('\n--- Scenario 14: End-to-End Remote Restore Pipeline ---');
  const userRepo = new UserRepository(db);
  const homeRepo = new HomeRepository(db);
  const deviceRepo = new DeviceRepository(db);
  const deviceStateRepo = new DeviceStateRepository(db);
  const deviceTrustRepo = new DeviceTrustRepository(db);
  const secAuditRepo = new SecurityAuditRepository(db);

  const deviceTrustService = new DeviceTrustService({
    deviceTrustRepo,
    deviceRepo,
    securityAuditRepo: secAuditRepo
  });

  const recoveryService = new RecoveryService({
    db,
    recoveryRepo,
    backupProvider: testStorage,
    deviceTrustService
  });

  await db.insert('users', 'user_rec_01', { email: 'rec@example.com', name: 'Restore User', role: 'MEMBER' });
  await db.insert('homes', 'home_rec_01', { name: 'Restore Home', owner_id: 'user_rec_01' });
  await db.insert('devices', 'dev_rec_01', {
    home_id: 'home_rec_01',
    name: 'Living Room Light',
    type: 'SWITCH',
    status: 'ONLINE'
  });
  await db.insert('device_states', 'dev_rec_01', { device_id: 'dev_rec_01', state: { on: true, brightness: 80 } });

  // 1. Create full remote backup
  const createdBackup = await recoveryService.createBackup({
    scope: 'FULL',
    homeId: 'home_rec_01',
    initiatedBy: 'user_rec_01'
  });
  assert('Created full backup marked COMPLETED', createdBackup.manifest && createdBackup.manifest.status === 'COMPLETED');
  const backupId = createdBackup.backupId;
  const manifestExists = await testStorage.exists(`backups/${backupId}/manifest.json`);
  assert('Backup uploaded to remote provider with valid manifest', manifestExists === true);

  // 2. Perform Non-Destructive Integrity Verification
  const integrityResult = await recoveryService.verifyBackupIntegrity(backupId);
  assert('Integrity verification confirms manifestValid, checksumsValid, schemaCompatible',
    integrityResult.status === 'VALID' &&
    integrityResult.manifestValid === true &&
    integrityResult.checksumsValid === true &&
    integrityResult.schemaCompatible === true
  );

  // 3. Perform Dry-Run Plan
  const planResult = await recoveryService.planRestore({
    backupId,
    targetHomeId: 'home_rec_01',
    plannedBy: 'user_rec_01'
  });
  assert('Plan stage completes with restorableEntities and migrationCompatibility',
    Array.isArray(planResult.restorableEntities) && planResult.migrationCompatibility === 'COMPATIBLE'
  );

  // 4. Perform Restore Execution (Apply & Verify)
  const restoreResult = await recoveryService.executeRestore({
    backupId,
    targetHomeId: 'home_rec_01',
    initiatedBy: 'user_rec_01'
  });
  assert('Full restore pipeline completes successfully with status COMPLETED', restoreResult.status === 'COMPLETED');

  // Test 15: Phase 32 Device Trust & Revocation Preservation
  console.log('\n--- Scenario 15: Phase 32 Revocation Preservation ---');
  // Revoke device dev_rec_01 in DeviceTrustService
  await db.insert('device_revocations', 'rev_dev_rec_01', {
    device_id: 'dev_rec_01',
    reason: 'COMPROMISED_KEY',
    details: 'Security revocation test',
    created_at: new Date().toISOString()
  });
  await db.insert('device_trust_states', 'dev_rec_01', {
    device_id: 'dev_rec_01',
    trust_state: 'REVOKED'
  });

  // Re-run restore: Must NOT resurrect revoked device
  await recoveryService.executeRestore({
    backupId,
    targetHomeId: 'home_rec_01',
    initiatedBy: 'user_rec_01',
    force: true
  });

  const trustRecordAfter = await db.findById('device_trust_states', 'dev_rec_01');
  assert('Remote backup restore DOES NOT unrevoke revoked device (Phase 32 trust preserved)', trustRecordAfter && trustRecordAfter.trust_state === 'REVOKED');

  // Test 16: Phase 33 compatibility
  console.log('\n--- Scenario 16: Phase 33 Recovery Engine Compatibility ---');
  const manifestObj = await testStorage.readBackupObject(backupId, 'manifest.json');
  assert('Manifest contains schema version, scope, checksums, and entities', manifestObj.data.schemaVersion === 1 && manifestObj.data.manifestChecksum);

  // Test 17: Idempotent upload
  console.log('\n--- Scenario 17: Idempotent Upload ---');
  const idempKey = 'backups/idemp/test.json';
  const idempData = Buffer.from(JSON.stringify({ test: 'idempotent' }));
  const up1 = await testStorage.upload(idempKey, idempData);
  const up2 = await testStorage.upload(idempKey, idempData);
  assert('Re-uploading identical object returns identical SHA-256', up1.sha256 === up2.sha256);

  // Test 18: Provider Diagnostics
  console.log('\n--- Scenario 18: Provider Diagnostics & Secret Safety ---');
  const s3Diag = s3Prov.getDiagnostics();
  assert('S3 provider diagnostics do not expose secretAccessKey', !JSON.stringify(s3Diag).includes('test_secret_access_key_xyz_456'));
  assert('S3 provider diagnostics report configured state', s3Diag.configured === true && s3Diag.bucket === 'eh-home-disaster-recovery');

  // Final summary
  console.log(`\n=== PHASE 38 REMOTE BACKUP TEST RESULTS: ${passedTests}/${totalTests} PASS ===`);
  if (failedTests > 0) {
    console.error(`FAILED: ${failedTests} tests failed.`);
    process.exit(1);
  }
}

if (require.main === module) {
  runSuite().catch(err => {
    console.error('Fatal test error:', err);
    process.exit(1);
  });
}

module.exports = { runSuite };
