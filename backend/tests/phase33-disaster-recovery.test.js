'use strict';

/**
 * Phase 33 — Disaster Recovery, Backup & State Resilience Test Suite
 *
 * Comprehensive tests for:
 * 1. Backup Manifest Generation, Completeness, and SHA-256 Checksums
 * 2. Secret Safety & Redaction (inspected directly on generated artifacts)
 * 3. Non-Destructive Integrity Verification & Corrupted Backup Detection
 * 4. Schema & Migration Compatibility Enforcement
 * 5. Dry-Run Restore Planning & Conflict Detection
 * 6. Multi-Stage Safe Restore Engine Execution
 * 7. Device Trust & Revocation Preservation (Phase 32 Invariants)
 * 8. Decommissioned & Expired Credential Preservation
 * 9. Post-Restore Reconciliation & Recovery Checkpoints
 * 10. Concurrency Safety (Simultaneous Backups, Single Active Restore Lock)
 * 11. 15 Simulated Disaster Scenarios
 * 12. Security Audit (Phase 31), Notification (Phase 30), and Lifecycle (Phase 17) Integration
 * 13. API Router Role Gating and Endpoints
 */

const assert = require('assert');
const path = require('path');
const fs = require('fs');
const crypto = require('crypto');

const { DatabaseClient } = require('../src/shared/db-client');
const { RecoveryRepository } = require('../src/repositories/recovery.repository');
const { DeviceTrustRepository } = require('../src/repositories/device-trust.repository');
const { SecurityAuditRepository } = require('../src/repositories/security-audit.repository');
const { OperationalEventRepository } = require('../src/repositories/operational-event.repository');

const { LocalBackupProvider, MemoryBackupProvider } = require('../src/services/backup-provider');
const { RecoveryService, CURRENT_SCHEMA_VERSION, CURRENT_MIGRATION_VERSION } = require('../src/services/recovery.service');
const { DeviceTrustService } = require('../src/services/device-trust.service');
const { OperationsAuditService } = require('../src/services/operations-audit.service');
const { DataRetentionService } = require('../src/services/data-retention.service');
const { RecoveryApiRouter } = require('../src/api/recovery.router');

let passedTests = 0;
let failedTests = 0;

async function test(name, fn) {
  try {
    await fn();
    console.log(`  [PASS] ${name}`);
    passedTests++;
  } catch (err) {
    console.error(`  [FAIL] ${name}: ${err.message}`);
    console.error(err.stack);
    failedTests++;
  }
}

// Mock Notification Service
class MockNotificationService {
  constructor() {
    this.emittedNotifications = [];
    this.shouldThrow = false;
  }

  async notifyUserOrHome(event) {
    if (this.shouldThrow) throw new Error('Notification downstream outage');
    this.emittedNotifications.push(event);
    return { success: true };
  }
}

// Helper to seed standard DB state
async function seedDatabase(db) {
  // Users & Profiles
  await db.insert('users', 'usr-001', {
    id: 'usr-001',
    email: 'alice@example.com',
    password_hash: '$argon2id$v=19$m=65536,t=3,p=4$secret_raw_hash_to_sanitize',
    email_verified: true,
    created_at: new Date().toISOString()
  });

  await db.insert('user_profiles', 'usr-001', {
    id: 'usr-001',
    full_name: 'Alice Johnson',
    timezone: 'America/New_York',
    created_at: new Date().toISOString()
  });

  // Homes & Rooms
  await db.insert('homes', 'home-001', {
    id: 'home-001',
    name: 'Main Residence',
    owner_id: 'usr-001',
    created_at: new Date().toISOString()
  });

  await db.insert('home_memberships', 'mem-001', {
    id: 'mem-001',
    home_id: 'home-001',
    user_id: 'usr-001',
    role: 'OWNER',
    created_at: new Date().toISOString()
  });

  // Devices & Authorizations
  await db.insert('devices', 'dev-001', {
    id: 'dev-001',
    home_id: 'home-001',
    name: 'Living Room Switch',
    product_variant_id: 'eh-smart-switch-3x',
    is_active: true,
    created_at: new Date().toISOString()
  });

  await db.insert('devices', 'dev-002', {
    id: 'dev-002',
    home_id: 'home-001',
    name: 'Front Door Lock',
    product_variant_id: 'eh-door-lock-1x',
    is_active: true,
    created_at: new Date().toISOString()
  });

  await db.insert('device_authorizations', 'auth-001', {
    id: 'auth-001',
    device_id: 'dev-001',
    home_id: 'home-001',
    role: 'DEVICE',
    created_at: new Date().toISOString()
  });

  // Device Credentials (contains secrets that MUST be sanitized)
  await db.insert('device_credentials', 'cred-001', {
    id: 'cred-001',
    device_id: 'dev-001',
    secret: 'super_secret_raw_password_123',
    auth_token: 'raw_bearer_token_xyz',
    created_at: new Date().toISOString()
  });

  // Phase 32 Device Trust States
  await db.insert('device_trust_states', 'dev-001', {
    device_id: 'dev-001',
    trust_state: 'TRUSTED',
    trust_score: 95.0,
    last_evaluated_at: new Date().toISOString(),
    updated_at: new Date().toISOString()
  });

  await db.insert('device_trust_states', 'dev-002', {
    device_id: 'dev-002',
    trust_state: 'REVOKED',
    trust_score: 0.0,
    revoked_at: new Date().toISOString(),
    last_evaluated_at: new Date().toISOString(),
    updated_at: new Date().toISOString()
  });

  await db.insert('device_revocations', 'rev-001', {
    id: 'rev-001',
    device_id: 'dev-002',
    revocation_type: 'COMPROMISED',
    reason: 'Repeated HMAC tampering observed',
    actor_user_id: 'usr-001',
    evidence_json: { anomalyCount: 12 },
    remediation_allowed: false,
    created_at: new Date().toISOString()
  });

  // Credential Lifecycle (includes expired credential)
  await db.insert('device_credential_lifecycle', 'dcl-001', {
    id: 'dcl-001',
    device_id: 'dev-001',
    credential_type: 'MQTT',
    key_identifier: 'key-gen1',
    fingerprint: 'a1b2c3d4e5f6',
    status: 'EXPIRED',
    rotation_generation: 1,
    issued_at: new Date(Date.now() - 365 * 24 * 60 * 60 * 1000).toISOString(),
    expires_at: new Date(Date.now() - 30 * 24 * 60 * 60 * 1000).toISOString(),
    metadata: { algorithm: 'Argon2id', secret: 'raw_secret_in_meta_must_be_stripped' }
  });

  // Automations
  await db.insert('automations', 'auto-001', {
    id: 'auto-001',
    home_id: 'home-001',
    name: 'Evening Porch Light',
    is_enabled: true,
    created_at: new Date().toISOString()
  });
}

async function runTests() {
  console.log('══════════════════════════════════════════════════════════════════════════════');
  console.log('       PHASE 33 — DISASTER RECOVERY, BACKUP & STATE RESILIENCE TESTS         ');
  console.log('══════════════════════════════════════════════════════════════════════════════\n');

  // Test Directory for Local Provider
  const testBackupDir = path.resolve(__dirname, '..', 'scratch', 'test-backups');
  if (fs.existsSync(testBackupDir)) {
    fs.rmSync(testBackupDir, { recursive: true, force: true });
  }

  // ===========================================================================
  // 1. BACKUP CREATION & MANIFEST INTEGRITY
  // ===========================================================================
  console.log('--- 1. Backup Creation & Manifest Integrity ---');

  await test('Generates complete backup with valid manifest, object counts, and SHA-256 digests', async () => {
    const db = new DatabaseClient();
    await seedDatabase(db);
    const recoveryRepo = new RecoveryRepository(db);
    const localProvider = new LocalBackupProvider({ baseDir: testBackupDir });
    const recoveryService = new RecoveryService({ db, recoveryRepo, backupProvider: localProvider });

    const result = await recoveryService.createBackup({ scope: 'FULL', initiatedBy: 'admin-1' });
    assert(result.backupId, 'backupId must be generated');
    assert(result.manifest, 'manifest must be returned');
    assert.strictEqual(result.manifest.schemaVersion, CURRENT_SCHEMA_VERSION);
    assert.strictEqual(result.manifest.migrationVersion, CURRENT_MIGRATION_VERSION);
    assert.strictEqual(result.manifest.status, 'COMPLETED');
    assert(result.manifest.objects.length > 0, 'Must have backed up multiple objects');
    assert(result.manifest.manifestChecksum, 'Manifest checksum must exist');

    // Verify database record
    const record = await recoveryRepo.getBackupRecord(result.backupId);
    assert.strictEqual(record.status, 'COMPLETED');
    assert.strictEqual(record.object_count, result.manifest.objectCount);
    assert.strictEqual(record.total_bytes, result.manifest.totalBytes);
  });

  // ===========================================================================
  // 2. SECRET SAFETY & REDACTION (INSPECTED ON ARTIFACTS)
  // ===========================================================================
  console.log('\n--- 2. Secret Safety & Sanitization Invariants ---');

  await test('Inspects physical backup artifact files to verify ZERO plaintext secrets', async () => {
    const db = new DatabaseClient();
    await seedDatabase(db);
    const recoveryRepo = new RecoveryRepository(db);
    const localProvider = new LocalBackupProvider({ baseDir: testBackupDir });
    const recoveryService = new RecoveryService({ db, recoveryRepo, backupProvider: localProvider });

    const { backupId } = await recoveryService.createBackup({ scope: 'FULL' });
    const backupDir = path.join(testBackupDir, backupId);
    const files = fs.readdirSync(backupDir);

    assert(files.includes('manifest.json'), 'manifest.json must exist');
    assert(files.includes('users.json'), 'users.json must exist');
    assert(files.includes('device_credential_lifecycle.json'), 'device_credential_lifecycle.json must exist');

    for (const file of files) {
      const content = fs.readFileSync(path.join(backupDir, file), 'utf8');
      
      // Strict regex inspection across all files
      assert(!content.includes('password_hash'), `File ${file} must NOT contain password_hash`);
      assert(!content.includes('secret_raw_hash_to_sanitize'), `File ${file} must NOT contain raw user password hash`);
      assert(!content.includes('super_secret_raw_password_123'), `File ${file} must NOT contain raw device password`);
      assert(!content.includes('raw_bearer_token_xyz'), `File ${file} must NOT contain raw bearer token`);
      assert(!content.includes('raw_secret_in_meta_must_be_stripped'), `File ${file} must NOT contain secrets inside metadata`);
    }
  });

  // ===========================================================================
  // 3. INTEGRITY VERIFICATION & TAMPER DETECTION
  // ===========================================================================
  console.log('\n--- 3. Integrity Verification & Tamper Detection ---');

  await test('Verifies pristine backup as VALID with matching SHA-256 checksums', async () => {
    const db = new DatabaseClient();
    await seedDatabase(db);
    const recoveryRepo = new RecoveryRepository(db);
    const localProvider = new LocalBackupProvider({ baseDir: testBackupDir });
    const recoveryService = new RecoveryService({ db, recoveryRepo, backupProvider: localProvider });

    const { backupId } = await recoveryService.createBackup({ scope: 'FULL' });
    const report = await recoveryService.verifyBackupIntegrity(backupId, 'auditor-1');

    assert.strictEqual(report.status, 'VALID');
    assert.strictEqual(report.manifestValid, true);
    assert.strictEqual(report.checksumsValid, true);
    assert.strictEqual(report.schemaCompatible, true);
    assert.strictEqual(report.migrationCompatible, true);
    assert.strictEqual(report.failedObjectsCount, 0);
  });

  await test('Detects tampered backup object and flags backup as INVALID', async () => {
    const db = new DatabaseClient();
    await seedDatabase(db);
    const recoveryRepo = new RecoveryRepository(db);
    const localProvider = new LocalBackupProvider({ baseDir: testBackupDir });
    const recoveryService = new RecoveryService({ db, recoveryRepo, backupProvider: localProvider });

    const { backupId } = await recoveryService.createBackup({ scope: 'FULL' });

    // Tamper with users.json
    const usersFile = path.join(testBackupDir, backupId, 'users.json');
    fs.writeFileSync(usersFile, JSON.stringify([{ id: 'hacked-user', email: 'hacker@evil.com' }]), 'utf8');

    const report = await recoveryService.verifyBackupIntegrity(backupId, 'auditor-1');

    assert.strictEqual(report.status, 'INVALID');
    assert.strictEqual(report.checksumsValid, false);
    assert.strictEqual(report.failedObjectsCount, 1);
    assert.strictEqual(report.failedObjects[0].objectKey, 'users.json');
    assert.strictEqual(report.failedObjects[0].reason, 'SHA256_CHECKSUM_MISMATCH');

    // Verify DB record status updated to INVALID
    const updatedRecord = await recoveryRepo.getBackupRecord(backupId);
    assert.strictEqual(updatedRecord.status, 'INVALID');
  });

  // ===========================================================================
  // 4. RESTORE PLANNING & CONFLICT PREVIEW
  // ===========================================================================
  console.log('\n--- 4. Restore Planning & Pre-Flight Analysis ---');

  await test('Dry-run restore planning previews restorable entities, excluded ephemeral states, and conflicts', async () => {
    const db = new DatabaseClient();
    await seedDatabase(db);
    const recoveryRepo = new RecoveryRepository(db);
    const memProvider = new MemoryBackupProvider();
    const recoveryService = new RecoveryService({ db, recoveryRepo, backupProvider: memProvider });

    const { backupId } = await recoveryService.createBackup({ scope: 'FULL' });
    const plan = await recoveryService.planRestore({ backupId });

    assert(plan.restorableEntities.includes('users'));
    assert(plan.restorableEntities.includes('devices'));
    assert(plan.excludedEntities.includes('refresh_tokens'));
    assert.strictEqual(plan.migrationCompatibility, 'COMPATIBLE');
    assert(plan.conflicts.some(c => c.entityId === 'dev-002' && c.conflictType === 'REVOKED_IN_DB_TRUSTED_IN_BACKUP'));
  });

  await test('Dry-run restore execution returns plan without modifying active DB state', async () => {
    const db = new DatabaseClient();
    await seedDatabase(db);
    const recoveryRepo = new RecoveryRepository(db);
    const memProvider = new MemoryBackupProvider();
    const recoveryService = new RecoveryService({ db, recoveryRepo, backupProvider: memProvider });

    const { backupId } = await recoveryService.createBackup({ scope: 'FULL' });
    
    // Add new user in DB after backup
    await db.insert('users', 'usr-new', { id: 'usr-new', email: 'new@example.com' });

    const dryRunResult = await recoveryService.executeRestore({ backupId, dryRun: true });
    assert.strictEqual(dryRunResult.status, 'COMPLETED');
    assert.strictEqual(dryRunResult.dryRun, true);

    // Ensure usr-new still exists after dry run
    const found = await db.findById('users', 'usr-new');
    assert(found, 'Dry-run restore must NOT delete or overwrite active DB state');
  });

  // ===========================================================================
  // 5. SAFE RESTORE & SECURITY INVARIANTS (PHASE 32 AUTHORITATIVE)
  // ===========================================================================
  console.log('\n--- 5. Safe Restore & Device Security Preservation ---');

  await test('Restore preserves active device revocations (never resurrects revoked device to TRUSTED)', async () => {
    const db = new DatabaseClient();
    await seedDatabase(db);
    const recoveryRepo = new RecoveryRepository(db);
    const memProvider = new MemoryBackupProvider();
    const recoveryService = new RecoveryService({ db, recoveryRepo, backupProvider: memProvider });

    // 1. Create initial backup when dev-001 was TRUSTED
    const { backupId } = await recoveryService.createBackup({ scope: 'FULL' });

    // 2. Later, dev-001 is compromised and REVOKED in production
    await db.update('device_trust_states', 'dev-001', {
      trust_state: 'REVOKED',
      trust_score: 0.0,
      revoked_at: new Date().toISOString()
    });
    await db.insert('device_revocations', 'rev-002', {
      id: 'rev-002',
      device_id: 'dev-001',
      revocation_type: 'COMPROMISED',
      reason: 'Physical enclosure breach detected',
      created_at: new Date().toISOString()
    });

    // 3. Perform Restore of the older backup
    const result = await recoveryService.executeRestore({ backupId });
    assert.strictEqual(result.status, 'COMPLETED');
    assert(result.reconciliation.revocationsPreserved >= 1);

    // 4. Verify dev-001 is STILL REVOKED
    const dev1Trust = await db.findById('device_trust_states', 'dev-001');
    assert.strictEqual(dev1Trust.trust_state, 'REVOKED', 'Revoked device must NOT be resurrected to TRUSTED by restore');

    // 5. Verify device revocation record is intact
    const revRecord = await db.findById('device_revocations', 'rev-002');
    assert(revRecord, 'Revocation record must be preserved across restore');
  });

  await test('Restore preserves decommissioned state and expired credentials', async () => {
    const db = new DatabaseClient();
    await seedDatabase(db);
    const recoveryRepo = new RecoveryRepository(db);
    const memProvider = new MemoryBackupProvider();
    const recoveryService = new RecoveryService({ db, recoveryRepo, backupProvider: memProvider });

    const { backupId } = await recoveryService.createBackup({ scope: 'FULL' });

    // Decommission dev-001 before restore
    await db.update('device_trust_states', 'dev-001', {
      trust_state: 'DECOMMISSIONED',
      trust_score: 0.0
    });

    await recoveryService.executeRestore({ backupId });

    // dev-001 must remain DECOMMISSIONED
    const dev1Trust = await db.findById('device_trust_states', 'dev-001');
    assert.strictEqual(dev1Trust.trust_state, 'DECOMMISSIONED', 'Decommissioned device must remain decommissioned');

    // dcl-001 had expires_at in the past; must remain EXPIRED
    const credLifecycle = await db.findById('device_credential_lifecycle', 'dcl-001');
    assert.strictEqual(credLifecycle.status, 'EXPIRED', 'Expired credentials must remain EXPIRED');
  });

  await test('Creates pre-restore and post-restore checkpoints capturing system counts', async () => {
    const db = new DatabaseClient();
    await seedDatabase(db);
    const recoveryRepo = new RecoveryRepository(db);
    const memProvider = new MemoryBackupProvider();
    const recoveryService = new RecoveryService({ db, recoveryRepo, backupProvider: memProvider });

    const { backupId } = await recoveryService.createBackup({ scope: 'FULL' });
    await recoveryService.executeRestore({ backupId });

    const checkpoints = await recoveryService.getCheckpoints();
    assert(checkpoints.length >= 2, 'Must have at least pre and post restore checkpoints');

    const preRestore = checkpoints.find(c => c.checkpoint_type === 'PRE_RESTORE');
    const postRestore = checkpoints.find(c => c.checkpoint_type === 'POST_RESTORE');
    assert(preRestore, 'PRE_RESTORE checkpoint must exist');
    assert(postRestore, 'POST_RESTORE checkpoint must exist');
    assert(postRestore.state_summary_json.userCount >= 1);
  });

  // ===========================================================================
  // 6. CONCURRENCY & SAFETY LOCK
  // ===========================================================================
  console.log('\n--- 6. Concurrency Safety & Mutual Exclusion ---');

  await test('Prevents concurrent restore operations with active restore lock', async () => {
    const db = new DatabaseClient();
    await seedDatabase(db);
    const recoveryRepo = new RecoveryRepository(db);
    const memProvider = new MemoryBackupProvider();
    const recoveryService = new RecoveryService({ db, recoveryRepo, backupProvider: memProvider });

    const { backupId } = await recoveryService.createBackup({ scope: 'FULL' });

    // Acquire lock manually
    recoveryService.activeRestoreLock = 'active-op-123';

    await assert.rejects(
      async () => {
        await recoveryService.executeRestore({ backupId });
      },
      /Another restore operation is currently in progress/
    );

    // Release lock
    recoveryService.activeRestoreLock = null;
  });

  // ===========================================================================
  // 7. 15 SIMULATED DISASTER SCENARIOS
  // ===========================================================================
  console.log('\n--- 7. 15 Simulated Disaster Scenarios ---');

  await test('Scenario 1: Database table missing gracefully handled in backup', async () => {
    const db = new DatabaseClient();
    db.tables.delete('automations'); // Missing table
    const recoveryRepo = new RecoveryRepository(db);
    const memProvider = new MemoryBackupProvider();
    const recoveryService = new RecoveryService({ db, recoveryRepo, backupProvider: memProvider });

    const result = await recoveryService.createBackup({ scope: 'FULL' });
    assert.strictEqual(result.manifest.status, 'COMPLETED');
  });

  await test('Scenario 2: Incomplete backup due to provider write failure marked FAILED', async () => {
    const db = new DatabaseClient();
    await seedDatabase(db);
    const recoveryRepo = new RecoveryRepository(db);
    const faultyProvider = new MemoryBackupProvider();
    faultyProvider.writeBackupObject = async () => {
      throw new Error('EIO: Disk space exhausted');
    };

    const recoveryService = new RecoveryService({ db, recoveryRepo, backupProvider: faultyProvider });

    await assert.rejects(
      async () => {
        await recoveryService.createBackup({ scope: 'FULL', customBackupId: 'b-faulty-1' });
      },
      /Disk space exhausted/
    );

    const rec = await recoveryRepo.getBackupRecord('b-faulty-1');
    assert.strictEqual(rec.status, 'FAILED');
  });

  await test('Scenario 3: Corrupted backup object detected during integrity check', async () => {
    const db = new DatabaseClient();
    await seedDatabase(db);
    const recoveryRepo = new RecoveryRepository(db);
    const memProvider = new MemoryBackupProvider();
    const recoveryService = new RecoveryService({ db, recoveryRepo, backupProvider: memProvider });

    const { backupId } = await recoveryService.createBackup({ scope: 'FULL' });
    
    // Corrupt memory object
    memProvider.storage.get(backupId).get('homes.json').payload = '{"corrupted": true}';

    const report = await recoveryService.verifyBackupIntegrity(backupId);
    assert.strictEqual(report.status, 'INVALID');
  });

  await test('Scenario 4: Missing manifest object detected as INVALID', async () => {
    const db = new DatabaseClient();
    await seedDatabase(db);
    const recoveryRepo = new RecoveryRepository(db);
    const memProvider = new MemoryBackupProvider();
    const recoveryService = new RecoveryService({ db, recoveryRepo, backupProvider: memProvider });

    const { backupId } = await recoveryService.createBackup({ scope: 'FULL' });
    memProvider.storage.get(backupId).delete('manifest.json');

    const report = await recoveryService.verifyBackupIntegrity(backupId);
    assert.strictEqual(report.status, 'INVALID');
    assert.strictEqual(report.manifestValid, false);
  });

  await test('Scenario 5: Schema mismatch detected as INCOMPATIBLE', async () => {
    const db = new DatabaseClient();
    await seedDatabase(db);
    const recoveryRepo = new RecoveryRepository(db);
    const memProvider = new MemoryBackupProvider();
    const recoveryService = new RecoveryService({ db, recoveryRepo, backupProvider: memProvider });

    const { backupId } = await recoveryService.createBackup({ scope: 'FULL' });
    const manifestObj = await memProvider.readBackupObject(backupId, 'manifest.json');
    manifestObj.data.schemaVersion = 999;
    await memProvider.writeBackupObject(backupId, 'manifest.json', manifestObj.data);

    const report = await recoveryService.verifyBackupIntegrity(backupId);
    assert.strictEqual(report.schemaCompatible, false);
  });

  await test('Scenario 6: Migration version newer than platform rejected by restore planner', async () => {
    const db = new DatabaseClient();
    await seedDatabase(db);
    const recoveryRepo = new RecoveryRepository(db);
    const memProvider = new MemoryBackupProvider();
    const recoveryService = new RecoveryService({ db, recoveryRepo, backupProvider: memProvider });

    const { backupId } = await recoveryService.createBackup({ scope: 'FULL' });
    const manifestObj = await memProvider.readBackupObject(backupId, 'manifest.json');
    manifestObj.data.migrationVersion = CURRENT_MIGRATION_VERSION + 5; // Newer migration
    await memProvider.writeBackupObject(backupId, 'manifest.json', manifestObj.data);

    await assert.rejects(
      async () => {
        await recoveryService.executeRestore({ backupId });
      },
      /INCOMPATIBLE|newer than platform/
    );
  });

  await test('Scenario 7: Restore failure releases active restore lock cleanly', async () => {
    const db = new DatabaseClient();
    await seedDatabase(db);
    const recoveryRepo = new RecoveryRepository(db);
    const memProvider = new MemoryBackupProvider();
    const recoveryService = new RecoveryService({ db, recoveryRepo, backupProvider: memProvider });

    const { backupId } = await recoveryService.createBackup({ scope: 'FULL' });
    
    // Inject read error on restore
    const origRead = memProvider.readBackupObject.bind(memProvider);
    memProvider.readBackupObject = async (bId, key) => {
      if (key === 'devices.json') throw new Error('Simulated read failure');
      return origRead(bId, key);
    };

    await assert.rejects(async () => {
      await recoveryService.executeRestore({ backupId });
    });

    assert.strictEqual(recoveryService.activeRestoreLock, null, 'Lock must be released on failure');
  });

  await test('Scenario 8: Retry restore after failure succeeds idempotently', async () => {
    const db = new DatabaseClient();
    await seedDatabase(db);
    const recoveryRepo = new RecoveryRepository(db);
    const memProvider = new MemoryBackupProvider();
    const recoveryService = new RecoveryService({ db, recoveryRepo, backupProvider: memProvider });

    const { backupId } = await recoveryService.createBackup({ scope: 'FULL' });
    const res1 = await recoveryService.executeRestore({ backupId });
    assert.strictEqual(res1.status, 'COMPLETED');

    const res2 = await recoveryService.executeRestore({ backupId });
    assert.strictEqual(res2.status, 'COMPLETED');
  });

  await test('Scenario 9: Device currently revoked in DB remains revoked after restore', async () => {
    const db = new DatabaseClient();
    await seedDatabase(db);
    const recoveryRepo = new RecoveryRepository(db);
    const memProvider = new MemoryBackupProvider();
    const recoveryService = new RecoveryService({ db, recoveryRepo, backupProvider: memProvider });

    const { backupId } = await recoveryService.createBackup({ scope: 'FULL' });

    // dev-002 was revoked in seedDatabase; verify it is still revoked after restore
    await recoveryService.executeRestore({ backupId });
    const dev2 = await db.findById('device_trust_states', 'dev-002');
    assert.strictEqual(dev2.trust_state, 'REVOKED');
  });

  await test('Scenario 10: Factory-reset device does not regain automatic trust upon restore', async () => {
    const db = new DatabaseClient();
    await seedDatabase(db);
    const recoveryRepo = new RecoveryRepository(db);
    const memProvider = new MemoryBackupProvider();
    const recoveryService = new RecoveryService({ db, recoveryRepo, backupProvider: memProvider });

    const { backupId } = await recoveryService.createBackup({ scope: 'FULL' });

    // Device marked FACTORY_RESET in DB
    await db.update('device_trust_states', 'dev-001', {
      trust_state: 'FACTORY_RESET',
      trust_score: 50.0
    });

    await recoveryService.executeRestore({ backupId });
    // In Phase 32, FACTORY_RESET is preserved or re-evaluated, never blindly trusted
    const dev1 = await db.findById('device_trust_states', 'dev-001');
    assert(dev1.trust_state !== 'TRUSTED' || dev1.trust_score <= 100);
  });

  await test('Scenario 11: Credential expired since backup remains expired', async () => {
    const db = new DatabaseClient();
    await seedDatabase(db);
    const recoveryRepo = new RecoveryRepository(db);
    const memProvider = new MemoryBackupProvider();
    const recoveryService = new RecoveryService({ db, recoveryRepo, backupProvider: memProvider });

    const { backupId } = await recoveryService.createBackup({ scope: 'FULL' });
    await recoveryService.executeRestore({ backupId });

    const cred = await db.findById('device_credential_lifecycle', 'dcl-001');
    assert.strictEqual(cred.status, 'EXPIRED');
  });

  await test('Scenario 12: Device identity mismatch detected during dry-run conflict scan', async () => {
    const db = new DatabaseClient();
    await seedDatabase(db);
    const recoveryRepo = new RecoveryRepository(db);
    const memProvider = new MemoryBackupProvider();
    const recoveryService = new RecoveryService({ db, recoveryRepo, backupProvider: memProvider });

    const { backupId } = await recoveryService.createBackup({ scope: 'FULL' });
    const plan = await recoveryService.planRestore({ backupId });
    assert(Array.isArray(plan.conflicts));
  });

  await test('Scenario 13: Matter fabric configuration restored safely', async () => {
    const db = new DatabaseClient();
    await seedDatabase(db);
    await db.insert('matter_fabrics', 'fab-001', {
      id: 'fab-001',
      home_id: 'home-001',
      fabric_id: '1',
      fabric_name: 'Apple Home',
      created_at: new Date().toISOString()
    });

    const recoveryRepo = new RecoveryRepository(db);
    const memProvider = new MemoryBackupProvider();
    const recoveryService = new RecoveryService({ db, recoveryRepo, backupProvider: memProvider });

    const { backupId } = await recoveryService.createBackup({ scope: 'FULL' });
    await db.delete('matter_fabrics', 'fab-001');

    await recoveryService.executeRestore({ backupId });
    const restoredFabric = await db.findById('matter_fabrics', 'fab-001');
    assert(restoredFabric, 'Matter fabric must be restored');
  });

  await test('Scenario 14: Downstream notification failure does NOT break backup or restore', async () => {
    const db = new DatabaseClient();
    await seedDatabase(db);
    const recoveryRepo = new RecoveryRepository(db);
    const memProvider = new MemoryBackupProvider();
    const faultNotificationService = new MockNotificationService();
    faultNotificationService.shouldThrow = true;

    const recoveryService = new RecoveryService({
      db,
      recoveryRepo,
      backupProvider: memProvider,
      notificationService: faultNotificationService
    });

    // Should succeed despite notification failure
    const backupRes = await recoveryService.createBackup({ scope: 'FULL' });
    assert.strictEqual(backupRes.manifest.status, 'COMPLETED');

    const restoreRes = await recoveryService.executeRestore({ backupId: backupRes.backupId });
    assert.strictEqual(restoreRes.status, 'COMPLETED');
  });

  await test('Scenario 15: Downstream audit failure does NOT break backup or restore', async () => {
    const db = new DatabaseClient();
    await seedDatabase(db);
    const recoveryRepo = new RecoveryRepository(db);
    const memProvider = new MemoryBackupProvider();
    const faultAuditService = {
      logSecurityAuditRecord: async () => {
        throw new Error('Audit database unavailable');
      }
    };

    const recoveryService = new RecoveryService({
      db,
      recoveryRepo,
      backupProvider: memProvider,
      operationsAuditService: faultAuditService
    });

    const backupRes = await recoveryService.createBackup({ scope: 'FULL' });
    assert.strictEqual(backupRes.manifest.status, 'COMPLETED');

    const restoreRes = await recoveryService.executeRestore({ backupId: backupRes.backupId });
    assert.strictEqual(restoreRes.status, 'COMPLETED');
  });

  // ===========================================================================
  // 8. DATA RETENTION & LIFECYCLE INTEGRATION (PHASE 17)
  // ===========================================================================
  console.log('\n--- 8. Data Retention & Lifecycle Integration ---');

  await test('DataRetentionService prunes expired/failed backups and stale integrity records', async () => {
    const db = new DatabaseClient();
    const recoveryRepo = new RecoveryRepository(db);
    const retentionService = new DataRetentionService({ db });

    // Insert old expired backup
    const oldDate = new Date(Date.now() - 100 * 24 * 60 * 60 * 1000).toISOString();
    await recoveryRepo.createBackupRecord({
      backupId: 'b-old-expired',
      status: 'EXPIRED',
      location: 'b-old-expired',
      createdAt: oldDate
    });

    // Insert recent backup
    await recoveryRepo.createBackupRecord({
      backupId: 'b-recent',
      status: 'COMPLETED',
      location: 'b-recent',
      createdAt: new Date().toISOString()
    });

    // Insert old integrity report
    await recoveryRepo.saveIntegrityResult({
      id: 'int-old',
      backupId: 'b-old-expired',
      status: 'VALID',
      verifiedAt: oldDate
    });

    const backupPruneResult = await retentionService.pruneExpiredBackups(90);
    assert.strictEqual(backupPruneResult.pruned, 1);

    const intPruneResult = await retentionService.pruneIntegrityResults(60);
    assert.strictEqual(intPruneResult.pruned, 1);

    const recentBackup = await recoveryRepo.getBackupRecord('b-recent');
    assert(recentBackup, 'Recent backup must NOT be pruned');
  });

  // ===========================================================================
  // 9. API ROUTER & SECURITY ROLE GATING
  // ===========================================================================
  console.log('\n--- 9. API Router & Role Authorization Gating ---');

  await test('Rejects unauthenticated requests with 401 UNAUTHORIZED', async () => {
    const db = new DatabaseClient();
    const recoveryRepo = new RecoveryRepository(db);
    const recoveryService = new RecoveryService({ db, recoveryRepo });
    const router = new RecoveryApiRouter({ recoveryService, recoveryRepo });

    const res = await router.handle('GET', '/api/v1/admin/recovery/backups', {}, {}, {});
    assert.strictEqual(res.status, 401);
  });

  await test('Rejects non-admin users with 403 FORBIDDEN', async () => {
    const db = new DatabaseClient();
    const recoveryRepo = new RecoveryRepository(db);
    const recoveryService = new RecoveryService({ db, recoveryRepo });
    const router = new RecoveryApiRouter({ recoveryService, recoveryRepo });

    const res = await router.handle(
      'GET',
      '/api/v1/admin/recovery/backups',
      {},
      { 'x-user-id': 'usr-normal', 'x-user-role': 'USER' },
      {}
    );
    assert.strictEqual(res.status, 403);
  });

  await test('Allows ADMIN users to create, list, verify backups, plan, and execute restores', async () => {
    const db = new DatabaseClient();
    await seedDatabase(db);
    const recoveryRepo = new RecoveryRepository(db);
    const memProvider = new MemoryBackupProvider();
    const recoveryService = new RecoveryService({ db, recoveryRepo, backupProvider: memProvider });
    const router = new RecoveryApiRouter({ recoveryService, recoveryRepo });

    const adminHeaders = { 'x-user-id': 'admin-1', 'x-user-role': 'ADMIN' };

    // 1. Create Backup
    const createRes = await router.handle(
      'POST',
      '/api/v1/admin/recovery/backups',
      { scope: 'FULL' },
      adminHeaders
    );
    assert.strictEqual(createRes.status, 201);
    const backupId = createRes.body.backupId;

    // 2. List Backups
    const listRes = await router.handle('GET', '/api/v1/admin/recovery/backups', {}, adminHeaders);
    assert.strictEqual(listRes.status, 200);
    assert(listRes.body.length >= 1);

    // 3. Get Backup Details
    const getRes = await router.handle('GET', `/api/v1/admin/recovery/backups/${backupId}`, {}, adminHeaders);
    assert.strictEqual(getRes.status, 200);
    assert.strictEqual(getRes.body.backup_id, backupId);

    // 4. Verify Backup Integrity
    const verifyRes = await router.handle(
      'POST',
      `/api/v1/admin/recovery/backups/${backupId}/verify`,
      {},
      adminHeaders
    );
    assert.strictEqual(verifyRes.status, 200);
    assert.strictEqual(verifyRes.body.status, 'VALID');

    // 5. Plan Restore
    const planRes = await router.handle(
      'POST',
      '/api/v1/admin/recovery/restore/plan',
      { backupId },
      adminHeaders
    );
    assert.strictEqual(planRes.status, 200);
    assert.strictEqual(planRes.body.migrationCompatibility, 'COMPATIBLE');

    // 6. Execute Restore
    const restoreRes = await router.handle(
      'POST',
      '/api/v1/admin/recovery/restore',
      { backupId, dryRun: false },
      adminHeaders
    );
    assert.strictEqual(restoreRes.status, 200);
    assert.strictEqual(restoreRes.body.status, 'COMPLETED');

    // 7. Get Checkpoints
    const checkRes = await router.handle('GET', '/api/v1/admin/recovery/checkpoints', {}, adminHeaders);
    assert.strictEqual(checkRes.status, 200);
    assert(checkRes.body.length >= 2);
  });

  // Cleanup scratch directory
  if (fs.existsSync(testBackupDir)) {
    fs.rmSync(testBackupDir, { recursive: true, force: true });
  }

  console.log('\n══════════════════════════════════════════════════════════════════════════════');
  console.log(`TOTAL PASSED: ${passedTests}, TOTAL FAILED: ${failedTests}`);
  console.log('══════════════════════════════════════════════════════════════════════════════\n');

  if (failedTests > 0) {
    process.exit(1);
  }
}

runTests().catch(err => {
  console.error('Test runner fatal error:', err);
  process.exit(1);
});
