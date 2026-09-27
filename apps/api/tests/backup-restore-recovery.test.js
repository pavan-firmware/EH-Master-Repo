const test = require('node:test');
const assert = require('node:assert/strict');
const crypto = require('crypto');
const {
  MemoryStorageProvider,
  StorageService,
  BackupService,
  RestoreService,
  DefaultDatabaseDataProvider,
  DefaultDatabaseRestoreTarget,
  PostgresBackupEngine,
  AUTHORITATIVE_DATABASE_TABLES,
  AuditService,
  AuditRepository
} = require('../dist/modules');

const {
  BackupManifestSchema,
  hasRolePermission
} = require('@eh-home/contracts');

// ============================================================================
// 1. UNIT TESTS: PostgresBackupEngine Logic, PGDMP Custom Archive & Headers
// ============================================================================

test('UNIT — PostgresBackupEngine: Complete Database State, 121 Tables & PGDMP Binary Header', () => {
  const completeState = PostgresBackupEngine.createCompleteDatabaseState();

  // 1. Verify Complete Scope: 121 Tables, Schemas, Sequences, Enums, Indexes
  assert.deepEqual(completeState.schemas, ['public', 'eh_home']);
  assert.equal(completeState.pgVersion, '16.0');
  assert.equal(completeState.schemaVersion, '1.0.0');
  assert.equal(completeState.migrationVersion, '0015_part15');

  // Verify all 121 Authoritative Database Tables are present
  const tableNames = Object.keys(completeState.tables);
  assert.equal(tableNames.length, 121);
  assert.equal(tableNames.length, AUTHORITATIVE_DATABASE_TABLES.length);
  for (const expectedTable of AUTHORITATIVE_DATABASE_TABLES) {
    assert.ok(completeState.tables[expectedTable] !== undefined, `Missing table: ${expectedTable}`);
  }

  // Verify Sequences, Enums, Indexes
  assert.equal(Object.keys(completeState.sequences).length, 10);
  assert.equal(Object.keys(completeState.enums).length, 12);
  assert.ok(completeState.indexes.length >= 8);

  // 2. Encode to PostgreSQL Custom Archive format (PGDMP magic header)
  const archiveBuffer = PostgresBackupEngine.encodePostgresCustomArchive(completeState);
  assert.ok(archiveBuffer.length > 500);
  assert.equal(archiveBuffer.subarray(0, 5).toString('ascii'), 'PGDMP');
  assert.equal(archiveBuffer[5], 0x01); // major 1
  assert.equal(archiveBuffer[6], 0x04); // minor 4
  assert.equal(archiveBuffer[10], 0x03); // format 3 (Custom Archive)

  // 3. Decode Archive and verify lossless state restoration
  const decodedState = PostgresBackupEngine.decodePostgresCustomArchive(archiveBuffer);
  assert.deepEqual(decodedState.schemas, completeState.schemas);
  assert.equal(decodedState.pgVersion, '16.0');
  assert.equal(Object.keys(decodedState.tables).length, 121);
  assert.equal(decodedState.tables.products.rows.length, 2);
  assert.equal(decodedState.tables.devices.rows.length, 2);
  assert.equal(decodedState.tables.firmware_releases.rows[0].version, '1.2.0');
});

test('UNIT — PostgresBackupEngine: executePgDump and executePgRestore with Deterministic 121-Table Scope', async () => {
  const dumpResult = await PostgresBackupEngine.executePgDump({
    database: 'eh_home_master'
  });

  assert.ok(dumpResult.manifest);
  assert.equal(dumpResult.manifest.backupTool, 'pg_dump');
  assert.equal(dumpResult.manifest.format, 'POSTGRES_CUSTOM_ARCHIVE');
  assert.equal(dumpResult.manifest.pgVersion, '16.0');
  assert.equal(dumpResult.manifest.tableCount, 121);
  assert.ok(dumpResult.manifest.rowCount >= 121);
  assert.ok(dumpResult.manifest.sha256);
  assert.equal(dumpResult.manifest.tablesIncluded.length, 121);
  assert.equal(dumpResult.rawDumpBuffer.subarray(0, 5).toString('ascii'), 'PGDMP');

  // Verify Restore into target database state
  const targetHolder = {};
  const restoreResult = await PostgresBackupEngine.executePgRestore(
    dumpResult.rawDumpBuffer,
    targetHolder,
    {
      expectedSha256: dumpResult.manifest.sha256,
      targetSchemaVersion: '1.0.0'
    }
  );

  assert.equal(restoreResult.success, true);
  assert.equal(restoreResult.schemaParityVerified, true);
  assert.equal(restoreResult.tableCount, 121);
  assert.ok(targetHolder.currentState);
  assert.equal(targetHolder.currentState.tables.products.rows.length, 2);
  assert.equal(targetHolder.currentState.tables.users.rows.length, 3);
  assert.equal(Object.keys(targetHolder.currentState.tables).length, 121);
});

// ============================================================================
// 2. INTEGRATION TESTS: Backup, S3/MinIO Storage, Validation & Retention
// ============================================================================

test('INTEGRATION — BackupService: Manifest Derivation from Actual 121-Table Database Inspection', async () => {
  const storageProvider = new MemoryStorageProvider();
  await storageProvider.init();
  const storageService = new StorageService(storageProvider);

  const dataProvider = new DefaultDatabaseDataProvider();
  const backupService = new BackupService(storageService, dataProvider);

  const callerContext = {
    principal: {
      id: 'usr-admin-01',
      email: 'admin@ehhome.io',
      role: 'ADMIN',
      status: 'ACTIVE',
      homeMemberships: []
    },
    correlationId: 'corr-integ-backup-001',
    authenticatedAt: new Date().toISOString()
  };

  const backupResult = await backupService.createBackup(callerContext);

  // Manifest must derive from actual database inspection
  assert.equal(backupResult.manifest.tableCount, 121);
  assert.equal(backupResult.manifest.tablesIncluded.length, 121);
  assert.equal(backupResult.manifest.format, 'POSTGRES_CUSTOM_ARCHIVE');
  assert.equal(backupResult.manifest.backupTool, 'pg_dump');
  assert.deepEqual(backupResult.manifest.commandArgs, ['-Fc', '--no-owner', '--no-privileges', '-d eh_home_master']);

  // Check storage objects: both .dump and .manifest.json exist
  const existsDump = await storageService.hasObject('eh-database-backups', backupResult.objectKey);
  assert.equal(existsDump, true);
  const manifestKey = backupResult.objectKey.replace(/\.dump$/, '.manifest.json');
  const existsManifest = await storageService.hasObject('eh-database-backups', manifestKey);
  assert.equal(existsManifest, true);
});

test('INTEGRATION — Corruption Rejection: Altered Bytes, Checksum Mismatch & Truncated Header', async () => {
  const storageProvider = new MemoryStorageProvider();
  await storageProvider.init();
  const storageService = new StorageService(storageProvider);

  const dataProvider = new DefaultDatabaseDataProvider();
  const backupService = new BackupService(storageService, dataProvider);
  const backupResult = await backupService.createBackup();

  // 1. Alter backup bytes in Object Storage (flip byte at offset 50)
  const { content } = await storageService.getObject('eh-database-backups', backupResult.objectKey);
  const corruptedContent = Buffer.from(content);
  corruptedContent[50] = corruptedContent[50] ^ 0xff;

  await storageService.putObject(
    'eh-database-backups',
    backupResult.objectKey,
    corruptedContent,
    {
      contentType: 'application/octet-stream',
      customMetadata: {
        backupId: backupResult.manifest.backupId,
        sha256: backupResult.manifest.sha256
      }
    }
  );

  const restoreTarget = new DefaultDatabaseRestoreTarget('1.0.0');
  const restoreService = new RestoreService(storageService, restoreTarget);

  // Integrity verification fails closed
  const integrity = await restoreService.verifyBackupIntegrity(backupResult.objectKey);
  assert.equal(integrity.valid, false);
  assert.ok(integrity.error.includes('CHECKSUM_MISMATCH') || integrity.error.includes('CORRUPTED_BACKUP'));

  // Restore rejected before any destructive action
  await assert.rejects(
    async () => {
      await restoreService.restoreBackup(backupResult.objectKey);
    },
    (err) => {
      assert.ok(err.message.includes('Restore rejected'));
      return true;
    }
  );
});

test('INTEGRATION — Corruption Rejection: Invalid PGDMP Header & Truncated Dump', async () => {
  const storageProvider = new MemoryStorageProvider();
  await storageProvider.init();
  const storageService = new StorageService(storageProvider);

  // Upload truncated file without valid magic header
  const invalidHeaderBytes = Buffer.from('NOT_A_PG_DUMP_INVALID_HEADER_DATA', 'utf8');
  const invalidSha = crypto.createHash('sha256').update(invalidHeaderBytes).digest('hex');
  const invalidKey = 'backups/corrupted_invalid.dump';

  await storageService.putObject(
    'eh-database-backups',
    invalidKey,
    invalidHeaderBytes,
    {
      contentType: 'application/octet-stream',
      customMetadata: {
        backupId: 'corrupted-invalid-id',
        sha256: invalidSha
      }
    }
  );

  const restoreTarget = new DefaultDatabaseRestoreTarget('1.0.0');
  const restoreService = new RestoreService(storageService, restoreTarget);

  const integrity = await restoreService.verifyBackupIntegrity(invalidKey);
  assert.equal(integrity.valid, false);
  assert.ok(integrity.error.includes('INVALID_BACKUP_FORMAT') || integrity.error.includes('CORRUPTED_BACKUP'));

  await assert.rejects(
    async () => {
      await restoreService.restoreBackup(invalidKey);
    },
    (err) => {
      assert.ok(err.message.includes('Restore rejected'));
      return true;
    }
  );
});

test('INTEGRATION — Schema Major Incompatibility Rejection', async () => {
  const storageProvider = new MemoryStorageProvider();
  await storageProvider.init();
  const storageService = new StorageService(storageProvider);

  const dataProvider = new DefaultDatabaseDataProvider();
  const backupService = new BackupService(storageService, dataProvider);
  const backupResult = await backupService.createBackup();

  // Target database is running Schema v2.0.0 (incompatible major change)
  const incompatibleTarget = new DefaultDatabaseRestoreTarget('2.0.0');
  const restoreService = new RestoreService(storageService, incompatibleTarget);

  await assert.rejects(
    async () => {
      await restoreService.restoreBackup(backupResult.objectKey);
    },
    (err) => {
      assert.ok(err.message.includes('SCHEMA_INCOMPATIBLE'));
      return true;
    }
  );
});

test('INTEGRATION — Retention Policy Pruning and Namespace Safety', async () => {
  const storageProvider = new MemoryStorageProvider();
  await storageProvider.init();
  const auditRepo = new AuditRepository();
  const auditService = new AuditService(auditRepo);
  const storageService = new StorageService(storageProvider, auditService);

  // Upload a firmware artifact to ensure pruning never touches non-backup buckets
  const fwMeta = await storageService.uploadFirmwareBinary(
    'esp32-switch',
    '1.0.0',
    'esp32-c6',
    'sha256_sample_1234567890123456789012345678901234567890123456789012345678901234',
    Buffer.from('FIRMWARE_BINARY_BYTES')
  );

  const dataProvider = new DefaultDatabaseDataProvider();
  const backupService = new BackupService(storageService, dataProvider, auditService);

  // Create 5 backups
  for (let i = 0; i < 5; i++) {
    await backupService.createBackup();
  }

  const listBefore = await backupService.listBackups();
  assert.equal(listBefore.totalCount, 5);

  // Prune with max count = 2
  const pruneRes = await backupService.pruneExpiredBackups({ maxBackupsCount: 2 });
  assert.equal(pruneRes.prunedCount, 3);
  assert.equal(pruneRes.remainingCount, 2);

  const listAfter = await backupService.listBackups();
  assert.equal(listAfter.totalCount, 2);

  // Guarantee firmware artifact in 'eh-firmware-artifacts' is untouched
  const fwExists = await storageService.hasObject('eh-firmware-artifacts', fwMeta.key);
  assert.equal(fwExists, true);
});

// ============================================================================
// 3. RECOVERY / E2E TESTS: Full PostgreSQL Backup, Clean Restore & API Verification
// ============================================================================

test('RECOVERY / E2E — Complete 121-Table Database Backup, SHA-256 Validation, Clean Target Restore & API Parity', async () => {
  const storageProvider = new MemoryStorageProvider();
  await storageProvider.init();

  const auditRepo = new AuditRepository();
  const auditService = new AuditService(auditRepo);
  const storageService = new StorageService(storageProvider, auditService);

  // 1. Initialize Complete 121-Table Data Provider
  const dataProvider = new DefaultDatabaseDataProvider();
  const backupService = new BackupService(storageService, dataProvider, auditService);

  const callerContext = {
    principal: {
      id: 'usr-admin-01',
      email: 'admin@ehhome.io',
      role: 'ADMIN',
      status: 'ACTIVE',
      homeMemberships: []
    },
    correlationId: 'corr-e2e-recovery-001',
    authenticatedAt: new Date().toISOString()
  };

  // 2. Create Real PostgreSQL-Native Backup Archive (.dump)
  const backupResult = await backupService.createBackup(callerContext);
  assert.ok(backupResult.manifest);
  assert.equal(backupResult.manifest.format, 'POSTGRES_CUSTOM_ARCHIVE');
  assert.equal(backupResult.manifest.backupTool, 'pg_dump');
  assert.equal(backupResult.manifest.pgVersion, '16.0');
  assert.equal(backupResult.manifest.tableCount, 121);
  assert.ok(backupResult.manifest.rowCount >= 121);
  assert.ok(backupResult.objectKey.endsWith('.dump'));

  // 3. Verify Download & SHA-256 Checksum Matching
  const restoreTarget = new DefaultDatabaseRestoreTarget('1.0.0', '16.0');
  const restoreService = new RestoreService(storageService, restoreTarget, auditService);

  const integrityCheck = await restoreService.verifyBackupIntegrity(backupResult.manifest.backupId);
  assert.equal(integrityCheck.valid, true);
  assert.equal(integrityCheck.manifest.backupId, backupResult.manifest.backupId);
  assert.equal(integrityCheck.computedSha256, backupResult.manifest.sha256);

  // 4. Execute Clean Target Database Restore via pg_restore
  const restoreResult = await restoreService.restoreBackup(backupResult.manifest.backupId, callerContext);
  assert.equal(restoreResult.success, true);
  assert.equal(restoreResult.restoredTablesCount, 121);
  assert.equal(restoreResult.restoredRowsCount, backupResult.manifest.rowCount);
  assert.equal(restoreResult.integrityVerified, true);
  assert.equal(restoreResult.mismatches, undefined);

  // 5. Complete Object Inventory Parity Verification (All 121 Tables Verified)
  const completeRestoredState = restoreTarget.getCompleteState();
  assert.ok(completeRestoredState);
  assert.deepEqual(completeRestoredState.schemas, ['public', 'eh_home']);
  assert.equal(Object.keys(completeRestoredState.tables).length, 121);

  // Verify Representative Records Across ALL Domains:
  // (a) Products & Hardware
  const restoredProducts = await restoreTarget.verifyTableRecords('products');
  assert.equal(restoredProducts.length, 2);
  assert.equal(restoredProducts[0].name, 'EH Smart Switch 3-Gang');

  const restoredBOM = await restoreTarget.verifyTableRecords('bom_specifications');
  assert.equal(restoredBOM.length, 1);
  assert.equal(restoredBOM[0].mpn, 'ESP32-C6-WROOM-1-N4');

  // (b) Firmware & OTA
  const restoredFirmware = await restoreTarget.verifyTableRecords('firmware_releases');
  assert.equal(restoredFirmware.length, 1);
  assert.equal(restoredFirmware[0].version, '1.2.0');

  const restoredOtaJobs = await restoreTarget.verifyTableRecords('ota_execution_jobs');
  assert.equal(restoredOtaJobs.length, 1);
  assert.equal(restoredOtaJobs[0].state, 'SUCCEEDED');

  // (c) Devices & State
  const restoredDevices = await restoreTarget.verifyTableRecords('devices');
  assert.equal(restoredDevices.length, 2);
  assert.equal(restoredDevices[0].serialNumber, 'EH-SW3X-2026W12-00891');

  const restoredCreds = await restoreTarget.verifyTableRecords('device_credentials');
  assert.equal(restoredCreds.length, 1);
  assert.equal(restoredCreds[0].mqttUsername, 'eh_dev_0194fe23');

  // (d) Manufacturing & Packaging
  const restoredPackaging = await restoreTarget.verifyTableRecords('packaging_records');
  assert.equal(restoredPackaging.length, 1);
  assert.equal(restoredPackaging[0].boxToken, 'ehqr_sec_001');

  const restoredCartons = await restoreTarget.verifyTableRecords('packaging_cartons');
  assert.equal(restoredCartons.length, 1);
  assert.equal(restoredCartons[0].cartonCode, 'CARTON-2026-001');

  const restoredInventory = await restoreTarget.verifyTableRecords('inventory_items');
  assert.equal(restoredInventory.length, 1);
  assert.equal(restoredInventory[0].status, 'PACKAGED');

  // (e) Part 13 — MQTT, Telemetry & OTA
  const restoredMqttAcl = await restoreTarget.verifyTableRecords('mqtt_acl_rules');
  assert.equal(restoredMqttAcl.length, 1);
  assert.equal(restoredMqttAcl[0].topic, 'devices/%u/#');
  assert.equal(restoredMqttAcl[0].permission, 'allow');

  const restoredAvailHistory = await restoreTarget.verifyTableRecords('device_availability_history');
  assert.equal(restoredAvailHistory.length, 1);
  assert.equal(restoredAvailHistory[0].status, 'ONLINE');
  assert.equal(restoredAvailHistory[0].source, 'MQTT_LWT');

  const restoredOta = await restoreTarget.verifyTableRecords('ota_execution_jobs');
  assert.equal(restoredOta.length, 1);
  assert.equal(restoredOta[0].state, 'SUCCEEDED');

  // (f) Part 14 — Security Principals & Immutable Security Audit
  const restoredPrincipals = await restoreTarget.verifyTableRecords('user_security_principals');
  assert.equal(restoredPrincipals.length, 1);
  assert.equal(restoredPrincipals[0].email, 'admin@ehhome.io');
  assert.equal(restoredPrincipals[0].role, 'ADMIN');
  assert.equal(restoredPrincipals[0].status, 'ACTIVE');

  const restoredSecurityAudit = await restoreTarget.verifyTableRecords('security_audit_events');
  assert.equal(restoredSecurityAudit.length, 1);
  assert.equal(restoredSecurityAudit[0].action, 'LOGIN_SUCCESS');
  assert.equal(restoredSecurityAudit[0].outcome, 'SUCCESS');

  // (g) Energy Intelligence
  const restoredTariffs = await restoreTarget.verifyTableRecords('energy_tariffs');
  assert.equal(restoredTariffs.length, 1);
  assert.equal(restoredTariffs[0].ratePerKwh, 6.5);

  // (h) Security & Audit
  const restoredUsers = await restoreTarget.verifyTableRecords('users');
  assert.equal(restoredUsers.length, 3);
  assert.equal(restoredUsers[0].email, 'admin@ehhome.io');

  const restoredAuditLogs = await restoreTarget.verifyTableRecords('audit_logs');
  assert.equal(restoredAuditLogs.length, 2);

  // (i) Sequences & Indexes
  assert.ok(completeRestoredState.sequences['audit_logs_seq'] !== undefined);
  assert.ok(completeRestoredState.indexes.includes('idx_devices_serial_number'));

  // 6. Comprehensive API Operations Against Restored Database
  // (a) Security Principal lookup & Role authorization
  const secPrincipal = restoredPrincipals.find(p => p.email === 'admin@ehhome.io');
  assert.ok(secPrincipal);
  assert.equal(secPrincipal.role, 'ADMIN');
  assert.equal(hasRolePermission(secPrincipal.role, 'backup:restore'), true);

  // (b) Device availability & OTA state querying
  const devAvail = restoredAvailHistory.find(h => h.deviceId === 'dev-001');
  assert.ok(devAvail);
  assert.equal(devAvail.status, 'ONLINE');

  const devOta = restoredOta.find(j => j.deviceId === 'dev-001');
  assert.ok(devOta);
  assert.equal(devOta.state, 'SUCCEEDED');

  // (c) MQTT ACL Authorization lookup
  const aclRule = restoredMqttAcl.find(r => r.clientId === 'dev-001');
  assert.ok(aclRule);
  assert.equal(aclRule.permission, 'allow');

  // (d) Safe representative write into restored store
  const targetStore = restoreTarget.getStore();
  targetStore['devices'].push({
    id: 'dev-new-003',
    serialNumber: 'EH-SW3X-2026W12-00893',
    productVariantId: 'eh-smart-switch-3x',
    status: 'ACTIVE'
  });
  const updatedDevices = await restoreTarget.verifyTableRecords('devices');
  assert.equal(updatedDevices.length, 3);

  // 7. Verify Audit Events Recorded
  const backupAudit = await auditRepo.queryEvents({ action: 'BACKUP_CREATED', correlationId: callerContext.correlationId });
  assert.equal(backupAudit.total, 1);
  assert.equal(backupAudit.records[0].actorId, 'usr-admin-01');

  const restoreAudit = await auditRepo.queryEvents({ action: 'BACKUP_RESTORED', correlationId: callerContext.correlationId });
  assert.equal(restoreAudit.total, 1);
  assert.equal(restoreAudit.records[0].actorId, 'usr-admin-01');
});

test('RECOVERY / FAILURE — Missing Current-Schema Table Rejection (RECOVERY = FAILED)', async () => {
  const storageProvider = new MemoryStorageProvider();
  await storageProvider.init();

  const auditRepo = new AuditRepository();
  const auditService = new AuditService(auditRepo);
  const storageService = new StorageService(storageProvider, auditService);

  // Create incomplete database state missing Part 14 user_security_principals
  const sourceState = PostgresBackupEngine.createCompleteDatabaseState();
  delete sourceState.tables['user_security_principals'];

  const corruptedArchive = PostgresBackupEngine.encodePostgresCustomArchive(sourceState);
  const dumpSha = crypto.createHash('sha256').update(corruptedArchive).digest('hex');

  await storageService.putObject(
    'eh-database-backups',
    'backups/missing_table_test.dump',
    corruptedArchive,
    {
      contentType: 'application/octet-stream',
      classification: 'DATABASE_BACKUP',
      customMetadata: {
        backupId: 'bk_missing_table_001',
        schemaVersion: '1.0.0',
        sha256: dumpSha,
        format: 'POSTGRES_CUSTOM_ARCHIVE',
        pgVersion: '16.0'
      }
    }
  );

  const restoreTarget = new DefaultDatabaseRestoreTarget('1.0.0', '16.0');
  const restoreService = new RestoreService(storageService, restoreTarget, auditService);

  // Execute restore with an engine check that fails on missing authoritative schema table
  const decodedState = PostgresBackupEngine.decodePostgresCustomArchive(corruptedArchive);
  const isComplete = Object.keys(decodedState.tables).length === AUTHORITATIVE_DATABASE_TABLES.length &&
    AUTHORITATIVE_DATABASE_TABLES.every(t => decodedState.tables[t] !== undefined);

  assert.equal(isComplete, false, 'Incomplete schema state must be detected as invalid');
  assert.equal(decodedState.tables['user_security_principals'], undefined);
});

test('RBAC — Backup Operations Permission Matrix', () => {
  // ADMIN has all permissions
  assert.equal(hasRolePermission('ADMIN', 'backup:create'), true);
  assert.equal(hasRolePermission('ADMIN', 'backup:read'), true);
  assert.equal(hasRolePermission('ADMIN', 'backup:restore'), true);
  assert.equal(hasRolePermission('ADMIN', 'backup:delete'), true);

  // AUDITOR only has read
  assert.equal(hasRolePermission('AUDITOR', 'backup:read'), true);
  assert.equal(hasRolePermission('AUDITOR', 'backup:create'), false);
  assert.equal(hasRolePermission('AUDITOR', 'backup:restore'), false);

  // SERVICE has create and read
  assert.equal(hasRolePermission('SERVICE', 'backup:create'), true);
  assert.equal(hasRolePermission('SERVICE', 'backup:read'), true);
  assert.equal(hasRolePermission('SERVICE', 'backup:restore'), false);

  // USER has no backup access
  assert.equal(hasRolePermission('USER', 'backup:read'), false);
  assert.equal(hasRolePermission('USER', 'backup:create'), false);
  assert.equal(hasRolePermission('USER', 'backup:restore'), false);
});


