/**
 * Device Trust Repository
 *
 * Provides persistence and querying for device trust states, credential lifecycle ledger,
 * explicit revocations, and provisioning records.
 *
 * CRITICAL INVARIANT:
 * - `device_credentials` remains the authoritative store for currently usable device communication credentials.
 * - `device_credential_lifecycle` is a historical lifecycle/rotation ledger only.
 *   It MUST NOT become a second source of truth for whether a credential is currently valid.
 * - `device_credential_lifecycle.metadata` MUST NOT contain raw secrets (enforced with AuditRedactionService).
 */

const { AuditRedactionService } = require('../services/audit-redaction.service');

class DeviceTrustRepository {
  constructor(db) {
    this.db = db;
  }

  // ==========================================
  // 1. Authoritative Device Credentials
  // ==========================================

  async getAuthoritativeCredential(deviceId) {
    return await this.db.findById('device_credentials', deviceId);
  }

  async upsertAuthoritativeCredential(deviceId, data) {
    const existing = await this.db.findById('device_credentials', deviceId);
    if (existing) {
      return await this.db.update('device_credentials', deviceId, {
        ...data,
        updated_at: new Date().toISOString()
      });
    }
    return await this.db.insert('device_credentials', deviceId, {
      device_id: deviceId,
      ...data,
      created_at: data.created_at || new Date().toISOString()
    });
  }

  async updateAuthoritativeCredentialState(deviceId, credentialState) {
    const existing = await this.db.findById('device_credentials', deviceId);
    if (!existing) {
      return null;
    }
    return await this.db.update('device_credentials', deviceId, {
      credential_state: credentialState,
      updated_at: new Date().toISOString()
    });
  }

  // ==========================================
  // 2. Device Trust States
  // ==========================================

  async getTrustState(deviceId) {
    return await this.db.findById('device_trust_states', deviceId);
  }

  async upsertTrustState({
    deviceId,
    trustState = 'PROVISIONED',
    trustScore = 100.0,
    reasoningJson = {},
    quarantinedAt = null,
    revokedAt = null,
    lastEvaluatedAt = new Date().toISOString()
  }) {
    const existing = await this.db.findById('device_trust_states', deviceId);
    const now = new Date().toISOString();

    const payload = {
      device_id: deviceId,
      trust_state: trustState,
      trust_score: Math.max(0, Math.min(100, Number(trustScore))),
      reasoning_json: reasoningJson,
      quarantined_at: quarantinedAt,
      revoked_at: revokedAt,
      last_evaluated_at: lastEvaluatedAt,
      updated_at: now
    };

    if (existing) {
      return await this.db.update('device_trust_states', deviceId, payload);
    }
    return await this.db.insert('device_trust_states', deviceId, payload);
  }

  async listQuarantinedDevices() {
    return await this.db.find('device_trust_states', r => r.trust_state === 'QUARANTINED');
  }

  async listRevokedDevices() {
    return await this.db.find('device_trust_states', r => r.trust_state === 'REVOKED' || r.trust_state === 'DECOMMISSIONED');
  }

  // ==========================================
  // 3. Device Credential Lifecycle Ledger
  // ==========================================

  async getLifecycleRecordById(id) {
    return await this.db.findById('device_credential_lifecycle', id);
  }

  async listLifecycleRecords(deviceId, credentialType = null) {
    return await this.db.find('device_credential_lifecycle', r => {
      if (r.device_id !== deviceId) return false;
      if (credentialType && r.credential_type !== credentialType) return false;
      return true;
    });
  }

  async getActiveOrPendingLifecycleRecord(deviceId, credentialType) {
    const records = await this.listLifecycleRecords(deviceId, credentialType);
    return records.find(r => r.status === 'ROTATION_PENDING') || null;
  }

  async getNextGenerationNumber(deviceId, credentialType) {
    const records = await this.listLifecycleRecords(deviceId, credentialType);
    if (!records.length) return 1;
    const maxGen = Math.max(...records.map(r => r.rotation_generation || 1));
    return maxGen + 1;
  }

  async createLifecycleRecord({
    id,
    deviceId,
    credentialType,
    keyIdentifier,
    fingerprint = null,
    status = 'ROTATION_PENDING',
    rotationGeneration = 1,
    issuedAt = new Date().toISOString(),
    expiresAt = null,
    rotatedAt = null,
    revokedAt = null,
    metadata = {}
  }) {
    // Defense-in-depth: Redact sensitive secrets from metadata before persisting
    const { sanitized: cleanMetadata } = AuditRedactionService.redact(metadata);

    const record = {
      device_id: deviceId,
      credential_type: credentialType,
      key_identifier: keyIdentifier,
      fingerprint,
      status,
      rotation_generation: rotationGeneration,
      issued_at: issuedAt,
      expires_at: expiresAt,
      rotated_at: rotatedAt,
      revoked_at: revokedAt,
      metadata: cleanMetadata
    };

    return await this.db.insert('device_credential_lifecycle', id, record);
  }

  async updateLifecycleRecord(id, updates) {
    const cleanUpdates = { ...updates };
    if (cleanUpdates.metadata) {
      const { sanitized } = AuditRedactionService.redact(cleanUpdates.metadata);
      cleanUpdates.metadata = sanitized;
    }
    return await this.db.update('device_credential_lifecycle', id, cleanUpdates);
  }

  // ==========================================
  // 4. Device Revocation Ledger
  // ==========================================

  async createRevocation({
    id,
    deviceId,
    revocationType,
    reason,
    actorUserId = null,
    evidenceJson = {},
    remediationAllowed = false,
    createdAt = new Date().toISOString()
  }) {
    const record = {
      device_id: deviceId,
      revocation_type: revocationType,
      reason,
      actor_user_id: actorUserId,
      evidence_json: evidenceJson,
      remediation_allowed: !!remediationAllowed,
      created_at: createdAt
    };
    return await this.db.insert('device_revocations', id, record);
  }

  async getRevocations(deviceId) {
    return await this.db.find('device_revocations', r => r.device_id === deviceId);
  }

  async getLatestRevocation(deviceId) {
    const list = await this.getRevocations(deviceId);
    if (!list.length) return null;
    return list.sort((a, b) => new Date(b.created_at).getTime() - new Date(a.created_at).getTime())[0];
  }

  // ==========================================
  // 5. Device Provisioning Records
  // ==========================================

  async createProvisioningRecord({
    id,
    deviceId,
    stage,
    authority,
    evidenceJson = {},
    completedAt = null,
    createdAt = new Date().toISOString()
  }) {
    const record = {
      device_id: deviceId,
      stage,
      authority,
      evidence_json: evidenceJson,
      completed_at: completedAt,
      created_at: createdAt
    };
    return await this.db.insert('device_provisioning_records', id, record);
  }

  async getProvisioningRecords(deviceId) {
    return await this.db.find('device_provisioning_records', r => r.device_id === deviceId);
  }
}

module.exports = { DeviceTrustRepository };
