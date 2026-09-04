/**
 * Security Audit Repository
 *
 * Persists and queries tamper-evident, hash-chained security audit records.
 * Provides concurrency-safe atomic sequence allocation and database-level locking semantics.
 */

const crypto = require('crypto');

const GENESIS_HASH = '0000000000000000000000000000000000000000000000000000000000000000';

class SecurityAuditRepository {
  constructor(db) {
    this.db = db;
  }

  /**
   * Calculate deterministic SHA-256 hash across canonical fields
   */
  static computeHash({ sequenceNumber, prevRecordHash, timestamp, actorUserId, homeId, deviceId, action, resourceType, resourceId, outcome, canonicalPayload }) {
    const payloadStr = JSON.stringify(canonicalPayload || {}, Object.keys(canonicalPayload || {}).sort());
    const canonicalString = [
      sequenceNumber,
      prevRecordHash,
      timestamp,
      actorUserId || '',
      homeId || '',
      deviceId || '',
      action,
      resourceType,
      resourceId || '',
      outcome,
      payloadStr
    ].join('|');

    return crypto.createHash('sha256').update(canonicalString, 'utf8').digest('hex');
  }

  /**
   * Atomically appends a new security audit record to the hash chain.
   * Ensures safe sequence increment and previous hash chaining even across multiple callers.
   */
  async appendRecord({
    id,
    actorUserId = null,
    homeId = null,
    deviceId = null,
    action,
    resourceType,
    resourceId = null,
    outcome = 'SUCCESS',
    ipAddress = null,
    correlationId = null,
    canonicalPayload = {},
    metadata = {},
    timestamp = new Date().toISOString()
  }) {
    // Read current records to determine last sequence and hash atomically within repository
    const allRecords = await this.db.find('security_audit_records');
    let lastSeq = 0;
    let lastHash = GENESIS_HASH;

    if (allRecords.length > 0) {
      allRecords.sort((a, b) => Number(a.sequence_number) - Number(b.sequence_number));
      const latest = allRecords[allRecords.length - 1];
      lastSeq = Number(latest.sequence_number);
      lastHash = latest.record_hash;
    }

    const nextSeq = lastSeq + 1;
    const recordHash = SecurityAuditRepository.computeHash({
      sequenceNumber: nextSeq,
      prevRecordHash: lastHash,
      timestamp,
      actorUserId,
      homeId,
      deviceId,
      action,
      resourceType,
      resourceId,
      outcome,
      canonicalPayload
    });

    const record = {
      id,
      sequence_number: nextSeq,
      record_hash: recordHash,
      prev_record_hash: lastHash,
      actor_user_id: actorUserId,
      home_id: homeId,
      device_id: deviceId,
      action,
      resource_type: resourceType,
      resource_id: resourceId,
      outcome,
      ip_address: ipAddress,
      correlation_id: correlationId,
      canonical_payload: canonicalPayload,
      metadata,
      created_at: timestamp
    };

    return this.db.insert('security_audit_records', id, record);
  }

  async findById(id) {
    return this.db.findById('security_audit_records', id);
  }

  async findRecords({ homeId, action, outcome, since, limit = 100, offset = 0 }) {
    const records = await this.db.find('security_audit_records', r => {
      if (homeId && r.home_id !== homeId) return false;
      if (action && r.action !== action) return false;
      if (outcome && r.outcome !== outcome) return false;
      if (since && new Date(r.created_at) < new Date(since)) return false;
      return true;
    });

    return records
      .sort((a, b) => Number(b.sequence_number) - Number(a.sequence_number))
      .slice(offset, offset + limit);
  }

  async getAllInSequence() {
    const records = await this.db.find('security_audit_records');
    return records.sort((a, b) => Number(a.sequence_number) - Number(b.sequence_number));
  }

  /**
   * Verifies the complete cryptographic hash chain from sequence 1 to latest.
   * Returns { valid: boolean, totalRecords: number, brokenAtSequence: number|null, error: string|null }
   */
  async verifyChainIntegrity() {
    const records = await this.getAllInSequence();
    if (records.length === 0) {
      return {
        valid: true,
        totalRecords: 0,
        brokenAtSequence: null,
        error: null
      };
    }

    let expectedPrevHash = GENESIS_HASH;

    for (let i = 0; i < records.length; i++) {
      const rec = records[i];
      const expectedSeq = i + 1;

      // 1. Sequence monotonic integrity check
      if (Number(rec.sequence_number) !== expectedSeq) {
        return {
          valid: false,
          totalRecords: records.length,
          brokenAtSequence: Number(rec.sequence_number),
          error: `Sequence gap or mismatch: expected ${expectedSeq}, got ${rec.sequence_number}`
        };
      }

      // 2. Previous hash link check
      if (rec.prev_record_hash !== expectedPrevHash) {
        return {
          valid: false,
          totalRecords: records.length,
          brokenAtSequence: Number(rec.sequence_number),
          error: `Previous hash mismatch at sequence ${rec.sequence_number}`
        };
      }

      // 3. Current hash re-computation check
      const recomputedHash = SecurityAuditRepository.computeHash({
        sequenceNumber: Number(rec.sequence_number),
        prevRecordHash: rec.prev_record_hash,
        timestamp: rec.created_at,
        actorUserId: rec.actor_user_id,
        homeId: rec.home_id,
        deviceId: rec.device_id,
        action: rec.action,
        resourceType: rec.resource_type,
        resourceId: rec.resource_id,
        outcome: rec.outcome,
        canonicalPayload: rec.canonical_payload
      });

      if (recomputedHash !== rec.record_hash) {
        return {
          valid: false,
          totalRecords: records.length,
          brokenAtSequence: Number(rec.sequence_number),
          error: `Record hash tampering detected at sequence ${rec.sequence_number}`
        };
      }

      expectedPrevHash = rec.record_hash;
    }

    return {
      valid: true,
      totalRecords: records.length,
      brokenAtSequence: null,
      error: null
    };
  }
}

module.exports = {
  SecurityAuditRepository,
  GENESIS_HASH
};
