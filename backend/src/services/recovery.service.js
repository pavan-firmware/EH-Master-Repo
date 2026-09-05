'use strict';

/**
 * Disaster Recovery & State Resilience Service (Phase 33)
 *
 * Implements backup creation, non-destructive integrity verification, dry-run restore planning,
 * multi-stage safe restore execution, post-restore reconciliation, and recovery checkpointing.
 *
 * HARD SECURITY & STATE INVARIANTS:
 * 1. ZERO PLAINTEXT SECRETS: Backups NEVER contain plaintext passwords, tokens, or private keys.
 * 2. PHASE 32 IS AUTHORITATIVE: Restore NEVER overrides an existing device revocation, decommissioning,
 *    or expired credential with older backup state.
 * 3. NO CONCURRENT RESTORES: Restore operations are strictly mutually exclusive.
 * 4. DRY-RUN PRE-FLIGHT: Restores require explicit pre-flight planning and authorization.
 * 5. FAULT ISOLATION: Downstream audit and notification failures NEVER fail the recovery operation.
 */

const crypto = require('crypto');
const { LocalBackupProvider } = require('./backup-provider');

const DATA_CLASSIFICATIONS = Object.freeze({
  CRITICAL_STATE: 'CRITICAL_STATE',
  SECURITY_STATE: 'SECURITY_STATE',
  CONFIGURATION_STATE: 'CONFIGURATION_STATE',
  HISTORICAL_STATE: 'HISTORICAL_STATE',
  DERIVED_STATE: 'DERIVED_STATE'
});

const TABLE_CLASSIFICATION_MAP = Object.freeze({
  // Critical Topology & Identity
  users: { classification: 'CRITICAL_STATE', secretHandling: 'EXCLUDED', dependencies: [] },
  user_profiles: { classification: 'CRITICAL_STATE', secretHandling: 'NONE', dependencies: ['users'] },
  homes: { classification: 'CRITICAL_STATE', secretHandling: 'NONE', dependencies: ['users'] },
  floors: { classification: 'CRITICAL_STATE', secretHandling: 'NONE', dependencies: ['homes'] },
  rooms: { classification: 'CRITICAL_STATE', secretHandling: 'NONE', dependencies: ['homes', 'floors'] },
  home_memberships: { classification: 'CRITICAL_STATE', secretHandling: 'NONE', dependencies: ['users', 'homes'] },
  devices: { classification: 'CRITICAL_STATE', secretHandling: 'NONE', dependencies: ['homes'] },
  device_authorizations: { classification: 'CRITICAL_STATE', secretHandling: 'NONE', dependencies: ['devices', 'homes'] },
  
  // Security & Trust State (Phase 32)
  device_trust_states: { classification: 'SECURITY_STATE', secretHandling: 'NONE', dependencies: ['devices'] },
  device_credential_lifecycle: { classification: 'SECURITY_STATE', secretHandling: 'EXCLUDED', dependencies: ['devices'] },
  device_revocations: { classification: 'SECURITY_STATE', secretHandling: 'NONE', dependencies: ['devices'] },
  device_provisioning_records: { classification: 'HISTORICAL_STATE', secretHandling: 'NONE', dependencies: ['devices'] },

  // Integrations & Multi-Protocol (Phase 29, 26)
  matter_fabrics: { classification: 'CRITICAL_STATE', secretHandling: 'EXCLUDED', dependencies: ['homes'] },
  matter_devices: { classification: 'CRITICAL_STATE', secretHandling: 'NONE', dependencies: ['devices', 'matter_fabrics'] },
  matter_endpoints: { classification: 'CRITICAL_STATE', secretHandling: 'NONE', dependencies: ['matter_devices'] },
  external_platform_links: { classification: 'CONFIGURATION_STATE', secretHandling: 'EXCLUDED', dependencies: ['homes'] },

  // Configurations & Rules
  automations: { classification: 'CONFIGURATION_STATE', secretHandling: 'NONE', dependencies: ['homes', 'devices'] },
  scenes: { classification: 'CONFIGURATION_STATE', secretHandling: 'NONE', dependencies: ['homes', 'devices'] },
  schedules: { classification: 'CONFIGURATION_STATE', secretHandling: 'NONE', dependencies: ['homes'] },
  user_notification_preferences: { classification: 'CONFIGURATION_STATE', secretHandling: 'NONE', dependencies: ['users'] },
  energy_tariffs: { classification: 'CONFIGURATION_STATE', secretHandling: 'NONE', dependencies: ['homes'] },
  tariff_periods: { classification: 'CONFIGURATION_STATE', secretHandling: 'NONE', dependencies: ['energy_tariffs'] },
  energy_budgets: { classification: 'CONFIGURATION_STATE', secretHandling: 'NONE', dependencies: ['homes'] },

  // Checkpoints & Audit History
  recovery_checkpoints: { classification: 'HISTORICAL_STATE', secretHandling: 'NONE', dependencies: [] },
  security_audit_records: { classification: 'SECURITY_STATE', secretHandling: 'NONE', dependencies: [] }
});

const CURRENT_SCHEMA_VERSION = 1;
const CURRENT_MIGRATION_VERSION = 26;
const APP_VERSION = '1.0.0';

class RecoveryService {
  /**
   * @param {Object} opts
   * @param {Object} opts.db                         - DatabaseClient instance
   * @param {Object} opts.recoveryRepo               - RecoveryRepository instance
   * @param {Object} [opts.backupProvider]           - BackupProvider instance (defaults to LocalBackupProvider)
   * @param {Object} [opts.deviceTrustService]       - DeviceTrustService instance (Phase 32)
   * @param {Object} [opts.operationsAuditService]   - OperationsAuditService instance (Phase 31)
   * @param {Object} [opts.notificationService]      - NotificationService instance (Phase 30)
   */
  constructor({
    db,
    recoveryRepo,
    backupProvider = null,
    deviceTrustService = null,
    operationsAuditService = null,
    notificationService = null
  }) {
    if (!db) throw new Error('db client is required for RecoveryService');
    if (!recoveryRepo) throw new Error('recoveryRepo is required for RecoveryService');

    this.db = db;
    this.repo = recoveryRepo;
    this.provider = backupProvider || new LocalBackupProvider();
    this.deviceTrustService = deviceTrustService;
    this.auditService = operationsAuditService;
    this.notificationService = notificationService;

    this.activeRestoreLock = null; // Enforces single active restore operation
  }

  // ===========================================================================
  // 1. Secret Sanitization & Inspection Utilities
  // ===========================================================================

  static sanitizeEntity(entityType, record) {
    if (!record || typeof record !== 'object') return record;
    const sanitized = { ...record };

    switch (entityType) {
      case 'users':
        delete sanitized.password_hash;
        delete sanitized.password;
        break;

      case 'device_credentials':
        delete sanitized.secret;
        delete sanitized.auth_token;
        delete sanitized.private_key;
        delete sanitized.shared_secret;
        break;

      case 'device_credential_lifecycle':
        if (sanitized.metadata && typeof sanitized.metadata === 'object') {
          const cleanMeta = { ...sanitized.metadata };
          delete cleanMeta.secret;
          delete cleanMeta.key;
          delete cleanMeta.rawSecret;
          sanitized.metadata = cleanMeta;
        }
        break;

      case 'matter_fabrics':
        delete sanitized.ipk;
        delete sanitized.private_key;
        break;

      case 'external_platform_links':
        delete sanitized.oauth_token;
        delete sanitized.refresh_token;
        delete sanitized.client_secret;
        break;

      default:
        break;
    }

    return sanitized;
  }

  // ===========================================================================
  // 2. Backup Creation Engine
  // ===========================================================================

  async createBackup({
    scope = 'FULL',
    homeId = null,
    initiatedBy = 'SYSTEM',
    customBackupId = null,
    expirationDays = 30
  } = {}) {
    const backupId = customBackupId || crypto.randomUUID();
    const createdAt = new Date().toISOString();
    const expiresAt = new Date(Date.now() + expirationDays * 24 * 60 * 60 * 1000).toISOString();

    // 1. Register CREATED record in database
    await this.repo.createBackupRecord({
      backupId,
      status: 'IN_PROGRESS',
      scope,
      homeId,
      provider: this.provider.constructor.name,
      location: backupId,
      schemaVersionRecorded: CURRENT_SCHEMA_VERSION,
      migrationVersionRecorded: CURRENT_MIGRATION_VERSION,
      expiresAt,
      createdAt
    });

    try {
      const objectsManifest = [];
      let totalBytes = 0;
      let totalObjectCount = 0;

      // 2. Identify tables to back up based on scope
      const tableEntries = Object.entries(TABLE_CLASSIFICATION_MAP);

      for (const [tableName, config] of tableEntries) {
        if (scope === 'HOME' && homeId && !['homes', 'floors', 'rooms', 'home_memberships', 'devices', 'automations', 'scenes', 'schedules', 'energy_tariffs'].includes(tableName)) {
          continue;
        }

        let records = [];
        try {
          const tbl = this.db.getTable(tableName);
          records = Array.from(tbl.values());
        } catch (_) {
          // Table might not exist or be empty
          records = [];
        }

        if (scope === 'HOME' && homeId) {
          records = records.filter(r => r.home_id === homeId || r.id === homeId);
        }

        // Apply secret sanitization boundary
        const sanitizedRecords = records.map(r => RecoveryService.sanitizeEntity(tableName, r));

        const objectKey = `${tableName}.json`;
        const writeResult = await this.provider.writeBackupObject(backupId, objectKey, sanitizedRecords);

        objectsManifest.push({
          objectKey,
          entityType: tableName,
          recordCount: sanitizedRecords.length,
          byteSize: writeResult.byteSize,
          sha256Checksum: writeResult.sha256Checksum,
          dataClassification: config.classification,
          secretHandling: config.secretHandling
        });

        totalBytes += writeResult.byteSize;
        totalObjectCount++;
      }

      // 3. Build Backup Manifest
      const manifestData = {
        schemaVersion: CURRENT_SCHEMA_VERSION,
        backupId,
        createdAt,
        completedAt: new Date().toISOString(),
        expiresAt,
        source: 'EH_INTERNAL_RECOVERY_ENGINE',
        appVersion: APP_VERSION,
        migrationVersion: CURRENT_MIGRATION_VERSION,
        status: 'COMPLETED',
        scope,
        homeId,
        objects: objectsManifest,
        totalBytes,
        objectCount: totalObjectCount,
        encryption: {
          enabled: false
        },
        dependencies: Object.keys(TABLE_CLASSIFICATION_MAP),
        metadata: { initiatedBy }
      };

      // Compute manifest checksum
      const manifestChecksum = this.provider.calculateChecksum(manifestData);
      manifestData.manifestChecksum = manifestChecksum;

      // Write manifest object
      await this.provider.writeBackupObject(backupId, 'manifest.json', manifestData);

      // 4. Save metadata records in database
      await this.repo.saveBackupObjects(backupId, objectsManifest);
      await this.repo.updateBackupRecord(backupId, {
        status: 'COMPLETED',
        object_count: totalObjectCount,
        total_bytes: totalBytes,
        manifest_checksum: manifestChecksum,
        completed_at: new Date().toISOString()
      });

      // 5. Downstream Audit & Notification Integration
      await this._logAuditEvent('BACKUP_CREATED', {
        backupId,
        scope,
        totalBytes,
        objectCount: totalObjectCount,
        actorUserId: initiatedBy
      });

      await this._emitNotification('BACKUP_COMPLETED', {
        backupId,
        scope,
        objectCount: totalObjectCount
      });

      return {
        backupId,
        manifest: manifestData
      };
    } catch (err) {
      await this.repo.updateBackupRecord(backupId, {
        status: 'FAILED',
        error_message: err.message,
        completed_at: new Date().toISOString()
      }).catch(() => {});

      await this._logAuditEvent('BACKUP_FAILED', {
        backupId,
        error: err.message,
        actorUserId: initiatedBy
      });

      await this._emitNotification('BACKUP_FAILED', {
        backupId,
        error: err.message
      });

      throw err;
    }
  }

  // ===========================================================================
  // 3. Non-Destructive Integrity Verification Engine
  // ===========================================================================

  async verifyBackupIntegrity(backupId, verifiedBy = 'SYSTEM') {
    const verificationId = crypto.randomUUID();
    const verifiedAt = new Date().toISOString();

    const backupRecord = await this.repo.getBackupRecord(backupId);
    if (!backupRecord) {
      const failedResult = {
        schemaVersion: CURRENT_SCHEMA_VERSION,
        verificationId,
        backupId,
        status: 'UNKNOWN',
        manifestValid: false,
        checksumsValid: false,
        schemaCompatible: false,
        migrationCompatible: false,
        verifiedObjectsCount: 0,
        failedObjectsCount: 0,
        failedObjects: [],
        details: { error: `Backup record ${backupId} not found` },
        verifiedBy,
        verifiedAt
      };
      return failedResult;
    }

    try {
      // 1. Read manifest.json
      const manifestObj = await this.provider.readBackupObject(backupId, 'manifest.json');
      const manifest = manifestObj.data;

      // Validate manifest structure
      const manifestValid = Boolean(
        manifest &&
        manifest.backupId === backupId &&
        manifest.schemaVersion === CURRENT_SCHEMA_VERSION &&
        Array.isArray(manifest.objects)
      );

      // Check migration & schema compatibility
      const migrationCompatible = manifest.migrationVersion <= CURRENT_MIGRATION_VERSION;
      const schemaCompatible = manifest.schemaVersion === CURRENT_SCHEMA_VERSION;

      // 2. Verify all object SHA-256 digests
      let verifiedCount = 0;
      let failedCount = 0;
      const failedObjects = [];

      for (const objMeta of manifest.objects) {
        try {
          const fileObj = await this.provider.readBackupObject(backupId, objMeta.objectKey);
          if (fileObj.sha256Checksum === objMeta.sha256Checksum) {
            verifiedCount++;
          } else {
            failedCount++;
            failedObjects.push({
              objectKey: objMeta.objectKey,
              expectedChecksum: objMeta.sha256Checksum,
              calculatedChecksum: fileObj.sha256Checksum,
              reason: 'SHA256_CHECKSUM_MISMATCH'
            });
          }
        } catch (err) {
          failedCount++;
          failedObjects.push({
            objectKey: objMeta.objectKey,
            expectedChecksum: objMeta.sha256Checksum,
            calculatedChecksum: 'MISSING',
            reason: err.message
          });
        }
      }

      const checksumsValid = failedCount === 0;

      // Determine overall integrity status
      let status = 'VALID';
      if (!manifestValid || !checksumsValid) {
        status = 'INVALID';
      } else if (!schemaCompatible || !migrationCompatible) {
        status = 'INCOMPATIBLE';
      }

      const integrityReport = {
        schemaVersion: CURRENT_SCHEMA_VERSION,
        verificationId,
        backupId,
        status,
        manifestValid,
        checksumsValid,
        schemaCompatible,
        migrationCompatible,
        verifiedObjectsCount: verifiedCount,
        failedObjectsCount: failedCount,
        failedObjects,
        details: {
          manifestChecksum: manifest.manifestChecksum,
          objectsTotal: manifest.objects.length
        },
        verifiedBy,
        verifiedAt
      };

      // Persist verification result
      await this.repo.saveIntegrityResult({
        id: verificationId,
        backupId,
        status,
        manifestValid,
        checksumsValid,
        schemaCompatible,
        migrationCompatible,
        verifiedObjectsCount: verifiedCount,
        failedObjectsCount: failedCount,
        detailsJson: integrityReport.details,
        verifiedBy,
        verifiedAt
      });

      // Update backup record if invalid
      if (status === 'INVALID') {
        await this.repo.updateBackupRecord(backupId, { status: 'INVALID' });
        await this._logAuditEvent('BACKUP_INTEGRITY_FAILED', {
          backupId,
          failedObjects,
          verifiedBy
        });
        await this._emitNotification('BACKUP_INTEGRITY_FAILED', {
          backupId,
          failedCount
        });
      } else {
        await this._logAuditEvent('BACKUP_VERIFIED', {
          backupId,
          status,
          verifiedBy
        });
      }

      return integrityReport;
    } catch (err) {
      const errorReport = {
        schemaVersion: CURRENT_SCHEMA_VERSION,
        verificationId,
        backupId,
        status: 'INVALID',
        manifestValid: false,
        checksumsValid: false,
        schemaCompatible: false,
        migrationCompatible: false,
        verifiedObjectsCount: 0,
        failedObjectsCount: 1,
        failedObjects: [{ objectKey: 'manifest.json', expectedChecksum: '', calculatedChecksum: '', reason: err.message }],
        details: { error: err.message },
        verifiedBy,
        verifiedAt
      };

      await this.repo.saveIntegrityResult({
        id: verificationId,
        backupId,
        status: 'INVALID',
        manifestValid: false,
        checksumsValid: false,
        schemaCompatible: false,
        migrationCompatible: false,
        verifiedObjectsCount: 0,
        failedObjectsCount: 1,
        detailsJson: { error: err.message },
        verifiedBy,
        verifiedAt
      }).catch(() => {});

      return errorReport;
    }
  }

  // ===========================================================================
  // 4. Pre-Flight Dry-Run Restore Planning
  // ===========================================================================

  async planRestore({
    backupId,
    targetScope = 'FULL',
    homeId = null,
    initiatedBy = 'ADMIN'
  }) {
    // 1. Verify backup integrity first
    const integrity = await this.verifyBackupIntegrity(backupId, initiatedBy);
    if (integrity.status !== 'VALID') {
      throw new Error(`Cannot plan restore: Backup integrity is ${integrity.status} (failedObjects: ${integrity.failedObjectsCount})`);
    }

    const manifestObj = await this.provider.readBackupObject(backupId, 'manifest.json');
    const manifest = manifestObj.data;

    const restorableEntities = [];
    const excludedEntities = ['refresh_tokens', 'presence_signals', 'commissioning_sessions', 'device_transports'];
    const conflicts = [];

    // 2. Identify restorable tables
    for (const obj of manifest.objects) {
      restorableEntities.push(obj.entityType);
    }

    // 3. Conflict Detection against current live database state
    try {
      // Check device trust conflicts
      if (this.db.tables.has('device_revocations')) {
        const liveRevocations = Array.from(this.db.getTable('device_revocations').values());
        for (const rev of liveRevocations) {
          conflicts.push({
            entityType: 'device',
            entityId: rev.device_id,
            conflictType: 'REVOKED_IN_DB_TRUSTED_IN_BACKUP',
            resolution: 'PRESERVE_REVOCATION'
          });
        }
      }

      // Check decommissioned devices
      if (this.db.tables.has('device_trust_states')) {
        const liveTrust = Array.from(this.db.getTable('device_trust_states').values());
        for (const tr of liveTrust) {
          if (tr.trust_state === 'DECOMMISSIONED') {
            conflicts.push({
              entityType: 'device',
              entityId: tr.device_id,
              conflictType: 'DECOMMISSIONED_IN_DB',
              resolution: 'PRESERVE_DECOMMISSIONED'
            });
          }
        }
      }
    } catch (_) {
      // ignore
    }

    const migrationCompatibility = manifest.migrationVersion <= CURRENT_MIGRATION_VERSION
      ? 'COMPATIBLE'
      : 'INCOMPATIBLE';

    const plan = {
      restorableEntities,
      excludedEntities,
      conflicts,
      migrationCompatibility
    };

    return plan;
  }

  // ===========================================================================
  // 5. Multi-Stage Safe Restore Engine
  // ===========================================================================

  async executeRestore({
    backupId,
    targetScope = 'FULL',
    homeId = null,
    initiatedBy = 'ADMIN',
    dryRun = false,
    customOperationId = null
  }) {
    // Enforce mutual exclusion: only 1 restore operation at a time
    if (this.activeRestoreLock) {
      throw new Error(`Another restore operation is currently in progress: ${this.activeRestoreLock}`);
    }

    const operationId = customOperationId || crypto.randomUUID();
    this.activeRestoreLock = operationId;

    const createdAt = new Date().toISOString();

    // 1. STAGE: VALIDATE & PRECHECK
    let plan;
    try {
      plan = await this.planRestore({ backupId, targetScope, homeId, initiatedBy });
    } catch (err) {
      this.activeRestoreLock = null;
      throw err;
    }

    if (plan.migrationCompatibility === 'INCOMPATIBLE') {
      this.activeRestoreLock = null;
      throw new Error('Restore rejected: Backup migration version is newer than platform migration version');
    }

    // Register restore operation record
    await this.repo.createRestoreOperation({
      id: operationId,
      backupId,
      status: dryRun ? 'COMPLETED' : 'IN_PROGRESS',
      stage: dryRun ? 'PLAN' : 'APPLY',
      targetScope,
      homeId,
      initiatedBy,
      dryRun,
      planJson: plan,
      reconciliationJson: {},
      createdAt
    });

    if (dryRun) {
      this.activeRestoreLock = null;
      return {
        operationId,
        status: 'COMPLETED',
        dryRun: true,
        plan
      };
    }

    try {
      // 2. Create Pre-Restore Recovery Checkpoint
      await this.createCheckpoint({
        name: `pre_restore_${Date.now()}`,
        checkpointType: 'PRE_RESTORE',
        activeOperationId: operationId,
        metadata: { backupId, targetScope, initiatedBy }
      });

      // Capture currently active revocations and decommissioned devices before restore
      const liveRevocations = new Map();
      if (this.db.tables.has('device_revocations')) {
        for (const r of this.db.getTable('device_revocations').values()) {
          liveRevocations.set(r.device_id, r);
        }
      }

      const liveDecommissioned = new Set();
      if (this.db.tables.has('device_trust_states')) {
        for (const t of this.db.getTable('device_trust_states').values()) {
          if (t.trust_state === 'DECOMMISSIONED') {
            liveDecommissioned.add(t.device_id);
          }
        }
      }

      // 3. STAGE: APPLY — Restore objects in strict dependency order
      const manifestObj = await this.provider.readBackupObject(backupId, 'manifest.json');
      const manifest = manifestObj.data;

      // Dependency ordering
      const orderedTables = [
        'users', 'user_profiles', 'homes', 'floors', 'rooms', 'home_memberships',
        'devices', 'device_authorizations', 'device_trust_states', 'device_credential_lifecycle',
        'device_revocations', 'device_provisioning_records', 'matter_fabrics', 'matter_devices',
        'matter_endpoints', 'external_platform_links', 'automations', 'scenes', 'schedules',
        'user_notification_preferences', 'energy_tariffs', 'tariff_periods', 'energy_budgets',
        'recovery_checkpoints', 'security_audit_records'
      ];

      for (const tableName of orderedTables) {
        const objMeta = manifest.objects.find(o => o.entityType === tableName);
        if (!objMeta) continue;

        const fileObj = await this.provider.readBackupObject(backupId, objMeta.objectKey);
        const records = fileObj.data;

        if (!this.db.tables.has(tableName)) {
          this.db.tables.set(tableName, new Map());
        }

        const tbl = this.db.getTable(tableName);

        // Apply records
        for (const record of records) {
          const recId = record.id || record.device_id || record.backup_id || record.checkpoint_id;
          if (!recId) continue;

          // SPECIAL SECURITY INVARIANTS:
          // Invariant 1: Revocations Preservation
          if (tableName === 'device_trust_states' && liveRevocations.has(recId)) {
            // Keep revoked state
            const revInfo = liveRevocations.get(recId);
            record.trust_state = 'REVOKED';
            record.revoked_at = revInfo.created_at || new Date().toISOString();
          }

          // Invariant 2: Decommissioned Preservation
          if (tableName === 'device_trust_states' && liveDecommissioned.has(recId)) {
            record.trust_state = 'DECOMMISSIONED';
          }

          // Invariant 3: Expired Credential Preservation
          if (tableName === 'device_credential_lifecycle' && record.expires_at) {
            if (new Date(record.expires_at).getTime() < Date.now()) {
              record.status = 'EXPIRED';
            }
          }

          tbl.set(recId, record);
        }
      }

      // Re-insert live revocations to guarantee no loss
      if (this.db.tables.has('device_revocations')) {
        const revTbl = this.db.getTable('device_revocations');
        for (const [devId, revRec] of liveRevocations.entries()) {
          revTbl.set(revRec.id || devId, revRec);
        }
      }

      // 4. STAGE: VERIFY & RECONCILE
      const reconciliation = {
        status: 'CONSISTENT',
        revocationsPreserved: liveRevocations.size,
        decommissionedPreserved: liveDecommissioned.size,
        expiredCredentialsPreserved: 0,
        trustReEvaluatedCount: 0,
        devicesRequiringRecommissioning: [],
        warnings: []
      };

      // Count preserved expired credentials & re-evaluate device trust
      if (this.db.tables.has('device_credential_lifecycle')) {
        const creds = Array.from(this.db.getTable('device_credential_lifecycle').values());
        reconciliation.expiredCredentialsPreserved = creds.filter(c => c.status === 'EXPIRED').length;
      }

      if (this.db.tables.has('devices')) {
        const devices = Array.from(this.db.getTable('devices').values());
        for (const dev of devices) {
          if (this.deviceTrustService) {
            try {
              await this.deviceTrustService.evaluateTrustState(dev.id);
              reconciliation.trustReEvaluatedCount++;
            } catch (_) {
              reconciliation.warnings.push(`Device ${dev.id} trust re-evaluation deferred`);
            }
          }
        }
      }

      if (reconciliation.warnings.length > 0) {
        reconciliation.status = 'PARTIALLY_RECONCILED';
      }

      // 5. STAGE: COMPLETE
      await this.repo.updateRestoreOperation(operationId, {
        status: 'COMPLETED',
        stage: 'COMPLETE',
        reconciliation_json: reconciliation,
        completed_at: new Date().toISOString()
      });

      // Post-Restore Checkpoint
      await this.createCheckpoint({
        name: `post_restore_${Date.now()}`,
        checkpointType: 'POST_RESTORE',
        activeOperationId: operationId,
        metadata: { backupId, targetScope, initiatedBy }
      });

      // Audit & Notification
      await this._logAuditEvent('RESTORE_COMPLETED', {
        operationId,
        backupId,
        reconciliation,
        actorUserId: initiatedBy
      });

      await this._emitNotification('RESTORE_COMPLETED', {
        operationId,
        backupId,
        reconciliationStatus: reconciliation.status
      });

      this.activeRestoreLock = null;

      return {
        operationId,
        backupId,
        status: 'COMPLETED',
        stage: 'COMPLETE',
        plan,
        reconciliation
      };
    } catch (err) {
      await this.repo.updateRestoreOperation(operationId, {
        status: 'FAILED',
        stage: 'FAILED',
        error_message: err.message,
        completed_at: new Date().toISOString()
      }).catch(() => {});

      await this._logAuditEvent('RESTORE_FAILED', {
        operationId,
        backupId,
        error: err.message,
        actorUserId: initiatedBy
      });

      await this._emitNotification('RESTORE_FAILED', {
        operationId,
        backupId,
        error: err.message
      });

      this.activeRestoreLock = null;
      throw err;
    }
  }

  // ===========================================================================
  // 6. Recovery Checkpoints
  // ===========================================================================

  async createCheckpoint({
    name,
    checkpointType = 'MANUAL',
    activeOperationId = null,
    metadata = {}
  }) {
    const checkpointId = crypto.randomUUID();
    const createdAt = new Date().toISOString();

    const stateSummary = {
      userCount: this.db.tables.has('users') ? this.db.getTable('users').size : 0,
      homeCount: this.db.tables.has('homes') ? this.db.getTable('homes').size : 0,
      deviceCount: this.db.tables.has('devices') ? this.db.getTable('devices').size : 0,
      revokedDeviceCount: this.db.tables.has('device_revocations') ? this.db.getTable('device_revocations').size : 0,
      automationCount: this.db.tables.has('automations') ? this.db.getTable('automations').size : 0
    };

    const record = await this.repo.createRecoveryCheckpoint({
      id: checkpointId,
      name,
      checkpointType,
      appVersion: APP_VERSION,
      schemaVersionRecorded: CURRENT_SCHEMA_VERSION,
      migrationVersionRecorded: CURRENT_MIGRATION_VERSION,
      activeOperationId,
      stateSummaryJson: stateSummary,
      metadataJson: metadata,
      createdAt
    });

    await this._logAuditEvent('CHECKPOINT_CREATED', {
      checkpointId,
      name,
      checkpointType
    });

    return record;
  }

  async getCheckpoints(filter = {}) {
    return this.repo.listRecoveryCheckpoints(filter);
  }

  // ===========================================================================
  // 7. Internal Downstream Audit & Notification Wrappers
  // ===========================================================================

  async _logAuditEvent(action, details) {
    if (!this.auditService) return;
    try {
      await this.auditService.logSecurityAuditRecord({
        action,
        resourceType: 'DISASTER_RECOVERY',
        resourceId: details.backupId || details.operationId || details.checkpointId || null,
        actorUserId: details.actorUserId || 'SYSTEM',
        payload: details,
        metadata: { engine: 'EH_RECOVERY_ENGINE' }
      });
    } catch (_) {
      // Downstream isolation: never fail core recovery
    }
  }

  async _emitNotification(eventType, data) {
    if (!this.notificationService) return;
    try {
      await this.notificationService.notifyUserOrHome({
        type: eventType,
        source: 'DISASTER_RECOVERY',
        severity: eventType.includes('FAILED') ? 'CRITICAL' : 'INFO',
        title: `Disaster Recovery: ${eventType}`,
        message: `Recovery event ${eventType} occurred with ID ${data.backupId || data.operationId || ''}`,
        payload: data
      });
    } catch (_) {
      // Downstream isolation: never fail core recovery
    }
  }
}

module.exports = {
  RecoveryService,
  DATA_CLASSIFICATIONS,
  TABLE_CLASSIFICATION_MAP,
  CURRENT_SCHEMA_VERSION,
  CURRENT_MIGRATION_VERSION
};
