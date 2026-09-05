'use strict';

/**
 * Recovery Repository (Phase 33)
 *
 * Provides persistence access for disaster recovery metadata:
 * - backup_records
 * - backup_objects
 * - restore_operations
 * - recovery_checkpoints
 * - recovery_integrity_results
 */

class RecoveryRepository {
  constructor(db) {
    this.db = db;
  }

  // ===========================================================================
  // 1. Backup Records & Objects
  // ===========================================================================

  async createBackupRecord({
    backupId,
    status = 'CREATED',
    scope = 'FULL',
    homeId = null,
    provider = 'LocalBackupProvider',
    location,
    schemaVersionRecorded = 1,
    migrationVersionRecorded = 26,
    objectCount = 0,
    totalBytes = 0,
    manifestChecksum = null,
    errorMessage = null,
    expiresAt = null,
    createdAt = new Date().toISOString()
  }) {
    return this.db.insert('backup_records', backupId, {
      backup_id: backupId,
      status,
      scope,
      home_id: homeId,
      provider,
      location,
      schema_version_recorded: schemaVersionRecorded,
      migration_version_recorded: migrationVersionRecorded,
      object_count: objectCount,
      total_bytes: totalBytes,
      manifest_checksum: manifestChecksum,
      error_message: errorMessage,
      expires_at: expiresAt,
      created_at: createdAt,
      completed_at: null
    });
  }

  async getBackupRecord(backupId) {
    return this.db.findById('backup_records', backupId);
  }

  async listBackupRecords({ limit = 50, offset = 0, status, scope, homeId } = {}) {
    let records = await this.db.find('backup_records', r => {
      if (status && r.status !== status) return false;
      if (scope && r.scope !== scope) return false;
      if (homeId && r.home_id !== homeId) return false;
      return true;
    });

    records.sort((a, b) => new Date(b.created_at).getTime() - new Date(a.created_at).getTime());
    return records.slice(offset, offset + limit);
  }

  async updateBackupRecord(backupId, updates) {
    const existing = await this.getBackupRecord(backupId);
    if (!existing) throw new Error(`Backup record ${backupId} not found`);
    return this.db.update('backup_records', backupId, updates);
  }

  async deleteBackupRecord(backupId) {
    // Delete associated objects & integrity results
    const objects = await this.db.find('backup_objects', o => o.backup_id === backupId);
    for (const obj of objects) {
      await this.db.delete('backup_objects', obj.id);
    }
    const integrity = await this.db.find('recovery_integrity_results', i => i.backup_id === backupId);
    for (const res of integrity) {
      await this.db.delete('recovery_integrity_results', res.id);
    }
    return this.db.delete('backup_records', backupId);
  }

  async saveBackupObjects(backupId, objectsArray) {
    const created = [];
    for (const obj of objectsArray) {
      const id = obj.id || `${backupId}_${obj.objectKey || obj.object_key}`;
      const rec = await this.db.insert('backup_objects', id, {
        backup_id: backupId,
        object_key: obj.objectKey || obj.object_key,
        entity_type: obj.entityType || obj.entity_type,
        record_count: obj.recordCount || obj.record_count || 0,
        byte_size: obj.byteSize || obj.byte_size || 0,
        sha256_checksum: obj.sha256Checksum || obj.sha256_checksum,
        data_classification: obj.dataClassification || obj.data_classification || 'CRITICAL_STATE',
        secret_handling: obj.secretHandling || obj.secret_handling || 'NONE',
        created_at: obj.createdAt || obj.created_at || new Date().toISOString()
      });
      created.push(rec);
    }
    return created;
  }

  async getBackupObjects(backupId) {
    return this.db.find('backup_objects', o => o.backup_id === backupId);
  }

  // ===========================================================================
  // 2. Restore Operations
  // ===========================================================================

  async createRestoreOperation({
    id,
    backupId,
    status = 'PENDING',
    stage = 'VALIDATE',
    targetScope = 'FULL',
    homeId = null,
    initiatedBy,
    dryRun = false,
    planJson = {},
    reconciliationJson = {},
    errorMessage = null,
    createdAt = new Date().toISOString()
  }) {
    return this.db.insert('restore_operations', id, {
      id,
      backup_id: backupId,
      status,
      stage,
      target_scope: targetScope,
      home_id: homeId,
      initiated_by: initiatedBy,
      dry_run: dryRun,
      plan_json: planJson,
      reconciliation_json: reconciliationJson,
      error_message: errorMessage,
      created_at: createdAt,
      completed_at: null
    });
  }

  async getRestoreOperation(operationId) {
    return this.db.findById('restore_operations', operationId);
  }

  async listRestoreOperations({ limit = 50, offset = 0, status, backupId } = {}) {
    let records = await this.db.find('restore_operations', r => {
      if (status && r.status !== status) return false;
      if (backupId && r.backup_id !== backupId) return false;
      return true;
    });

    records.sort((a, b) => new Date(b.created_at).getTime() - new Date(a.created_at).getTime());
    return records.slice(offset, offset + limit);
  }

  async updateRestoreOperation(operationId, updates) {
    const existing = await this.getRestoreOperation(operationId);
    if (!existing) throw new Error(`Restore operation ${operationId} not found`);
    return this.db.update('restore_operations', operationId, updates);
  }

  // ===========================================================================
  // 3. Recovery Checkpoints
  // ===========================================================================

  async createRecoveryCheckpoint({
    id,
    name,
    checkpointType = 'MANUAL',
    appVersion = '1.0.0',
    schemaVersionRecorded = 1,
    migrationVersionRecorded = 26,
    activeOperationId = null,
    stateSummaryJson = {},
    metadataJson = {},
    createdAt = new Date().toISOString()
  }) {
    return this.db.insert('recovery_checkpoints', id, {
      id,
      name,
      checkpoint_type: checkpointType,
      app_version: appVersion,
      schema_version_recorded: schemaVersionRecorded,
      migration_version_recorded: migrationVersionRecorded,
      active_operation_id: activeOperationId,
      state_summary_json: stateSummaryJson,
      metadata_json: metadataJson,
      created_at: createdAt
    });
  }

  async getRecoveryCheckpoint(checkpointId) {
    return this.db.findById('recovery_checkpoints', checkpointId);
  }

  async listRecoveryCheckpoints({ limit = 50, offset = 0, checkpointType } = {}) {
    let records = await this.db.find('recovery_checkpoints', c => {
      if (checkpointType && c.checkpoint_type !== checkpointType) return false;
      return true;
    });

    records.sort((a, b) => new Date(b.created_at).getTime() - new Date(a.created_at).getTime());
    return records.slice(offset, offset + limit);
  }

  // ===========================================================================
  // 4. Recovery Integrity Results
  // ===========================================================================

  async saveIntegrityResult({
    id,
    backupId,
    status = 'UNKNOWN',
    manifestValid = false,
    checksumsValid = false,
    schemaCompatible = false,
    migrationCompatible = false,
    verifiedObjectsCount = 0,
    failedObjectsCount = 0,
    detailsJson = {},
    verifiedBy = 'SYSTEM',
    verifiedAt = new Date().toISOString()
  }) {
    return this.db.insert('recovery_integrity_results', id, {
      id,
      backup_id: backupId,
      status,
      manifest_valid: manifestValid,
      checksums_valid: checksumsValid,
      schema_compatible: schemaCompatible,
      migration_compatible: migrationCompatible,
      verified_objects_count: verifiedObjectsCount,
      failed_objects_count: failedObjectsCount,
      details_json: detailsJson,
      verified_by: verifiedBy,
      verified_at: verifiedAt
    });
  }

  async getIntegrityResult(verificationId) {
    return this.db.findById('recovery_integrity_results', verificationId);
  }

  async getLatestIntegrityResult(backupId) {
    const results = await this.db.find('recovery_integrity_results', i => i.backup_id === backupId);
    if (results.length === 0) return null;
    results.sort((a, b) => new Date(b.verified_at).getTime() - new Date(a.verified_at).getTime());
    return results[0];
  }

  async listIntegrityResults({ limit = 50, offset = 0, backupId } = {}) {
    let records = await this.db.find('recovery_integrity_results', i => {
      if (backupId && i.backup_id !== backupId) return false;
      return true;
    });

    records.sort((a, b) => new Date(b.verified_at).getTime() - new Date(a.verified_at).getTime());
    return records.slice(offset, offset + limit);
  }
}

module.exports = { RecoveryRepository };
