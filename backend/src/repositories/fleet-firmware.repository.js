'use strict';

/**
 * EH Home — Fleet Firmware & Safe OTA Rollout Repository (Phase 41)
 *
 * Implements dual-engine persistence:
 * 1. In-Memory testing database support (using db.find, db.insert, db.update, db.findById)
 * 2. PostgreSQL production database support (parameterized queries, zero SQL injection)
 */

class FleetFirmwareRepository {
  constructor(db) {
    if (!db) throw new Error('Database instance is required for FleetFirmwareRepository');
    this.db = db;
    this.isPostgres = !!(db.query && typeof db.query === 'function');
  }

  // ===========================================================================
  // 1. Fleet Device Firmware State
  // ===========================================================================

  async upsertDeviceFirmwareState({
    deviceId,
    productVariantId,
    currentFirmwareVersion,
    targetFirmwareVersion = null,
    rolloutId = null,
    rolloutState = null,
    lastOtaResult = null,
    lastAttemptAt = null,
    failureReason = null,
    healthVerificationState = 'PENDING'
  }) {
    const now = new Date().toISOString();
    const record = {
      device_id: deviceId,
      product_variant_id: productVariantId,
      current_firmware_version: currentFirmwareVersion,
      target_firmware_version: targetFirmwareVersion,
      rollout_id: rolloutId,
      rollout_state: rolloutState,
      last_ota_result: lastOtaResult,
      last_attempt_at: lastAttemptAt,
      failure_reason: failureReason,
      health_verification_state: healthVerificationState,
      updated_at: now
    };

    if (this.isPostgres) {
      const sql = `
        INSERT INTO fleet_device_firmware_state (
          device_id, product_variant_id, current_firmware_version, target_firmware_version,
          rollout_id, rollout_state, last_ota_result, last_attempt_at, failure_reason,
          health_verification_state, updated_at
        ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11)
        ON CONFLICT (device_id) DO UPDATE SET
          product_variant_id = EXCLUDED.product_variant_id,
          current_firmware_version = EXCLUDED.current_firmware_version,
          target_firmware_version = EXCLUDED.target_firmware_version,
          rollout_id = EXCLUDED.rollout_id,
          rollout_state = EXCLUDED.rollout_state,
          last_ota_result = EXCLUDED.last_ota_result,
          last_attempt_at = EXCLUDED.last_attempt_at,
          failure_reason = EXCLUDED.failure_reason,
          health_verification_state = EXCLUDED.health_verification_state,
          updated_at = EXCLUDED.updated_at
        RETURNING *;
      `;
      const res = await this.db.query(sql, [
        deviceId, productVariantId, currentFirmwareVersion, targetFirmwareVersion,
        rolloutId, rolloutState, lastOtaResult, lastAttemptAt, failureReason,
        healthVerificationState, now
      ]);
      return res.rows[0];
    } else {
      const existing = await this.db.findById('fleet_device_firmware_state', deviceId);
      let updated;
      if (existing) {
        updated = await this.db.update('fleet_device_firmware_state', deviceId, record);
      } else {
        updated = await this.db.insert('fleet_device_firmware_state', deviceId, record);
      }
      return this._mapState(updated);
    }
  }

  async getDeviceFirmwareState(deviceId) {
    if (this.isPostgres) {
      const sql = `SELECT * FROM fleet_device_firmware_state WHERE device_id = $1 LIMIT 1;`;
      const res = await this.db.query(sql, [deviceId]);
      return res.rows[0] ? this._mapState(res.rows[0]) : null;
    } else {
      const row = await this.db.findById('fleet_device_firmware_state', deviceId);
      return row ? this._mapState(row) : null;
    }
  }

  async listDeviceFirmwareStates(filters = {}) {
    if (this.isPostgres) {
      let conditions = [];
      let params = [];
      let idx = 1;

      if (filters.productVariantId) {
        conditions.push(`product_variant_id = $${idx++}`);
        params.push(filters.productVariantId);
      }
      if (filters.rolloutId) {
        conditions.push(`rollout_id = $${idx++}`);
        params.push(filters.rolloutId);
      }
      if (filters.healthVerificationState) {
        conditions.push(`health_verification_state = $${idx++}`);
        params.push(filters.healthVerificationState);
      }

      const whereClause = conditions.length > 0 ? `WHERE ${conditions.join(' AND ')}` : '';
      const sql = `SELECT * FROM fleet_device_firmware_state ${whereClause} ORDER BY updated_at DESC;`;
      const res = await this.db.query(sql, params);
      return res.rows.map(r => this._mapState(r));
    } else {
      const rows = await this.db.find('fleet_device_firmware_state', item => {
        if (filters.productVariantId && item.product_variant_id !== filters.productVariantId) return false;
        if (filters.rolloutId && item.rollout_id !== filters.rolloutId) return false;
        if (filters.healthVerificationState && item.health_verification_state !== filters.healthVerificationState) return false;
        return true;
      });
      return rows.map(r => this._mapState(r));
    }
  }

  _mapState(r) {
    if (!r) return null;
    return {
      ...r,
      deviceId: r.device_id || r.deviceId,
      productVariantId: r.product_variant_id || r.productVariantId,
      currentFirmwareVersion: r.current_firmware_version || r.currentFirmwareVersion,
      targetFirmwareVersion: r.target_firmware_version || r.targetFirmwareVersion,
      rolloutId: r.rollout_id || r.rolloutId,
      rolloutState: r.rollout_state || r.rolloutState,
      lastOtaResult: r.last_ota_result || r.lastOtaResult,
      lastAttemptAt: r.last_attempt_at || r.lastAttemptAt,
      failureReason: r.failure_reason || r.failureReason,
      healthVerificationState: r.health_verification_state || r.healthVerificationState || 'PENDING'
    };
  }

  // ===========================================================================
  // 2. OTA Attempts
  // ===========================================================================

  async recordAttempt({
    id,
    deviceId,
    rolloutId,
    requestedVersion,
    outcome = 'IN_PROGRESS',
    reason = null,
    startedAt = null,
    completedAt = null,
    auditMetadata = {}
  }) {
    const attemptId = id || `att_${Date.now()}_${Math.random().toString(36).substring(2, 7)}`;
    const now = new Date().toISOString();
    const record = {
      id: attemptId,
      device_id: deviceId,
      rollout_id: rolloutId,
      requested_version: requestedVersion,
      outcome,
      reason,
      started_at: startedAt || now,
      completed_at: completedAt,
      audit_metadata_json: JSON.stringify(auditMetadata),
      created_at: now
    };

    if (this.isPostgres) {
      const sql = `
        INSERT INTO ota_attempts (
          id, device_id, rollout_id, requested_version, outcome, reason,
          started_at, completed_at, audit_metadata_json, created_at
        ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)
        RETURNING *;
      `;
      const res = await this.db.query(sql, [
        attemptId, deviceId, rolloutId, requestedVersion, outcome, reason,
        record.started_at, completedAt, record.audit_metadata_json, now
      ]);
      return res.rows[0];
    } else {
      return this.db.insert('ota_attempts', attemptId, record);
    }
  }

  async updateAttempt(id, updates = {}) {
    if (this.isPostgres) {
      let setClauses = [];
      let params = [];
      let idx = 1;

      if (updates.outcome !== undefined) {
        setClauses.push(`outcome = $${idx++}`);
        params.push(updates.outcome);
      }
      if (updates.reason !== undefined) {
        setClauses.push(`reason = $${idx++}`);
        params.push(updates.reason);
      }
      if (updates.completedAt !== undefined) {
        setClauses.push(`completed_at = $${idx++}`);
        params.push(updates.completedAt);
      }
      if (updates.auditMetadata !== undefined) {
        setClauses.push(`audit_metadata_json = $${idx++}`);
        params.push(JSON.stringify(updates.auditMetadata));
      }

      if (setClauses.length === 0) return this.getAttempt(id);
      params.push(id);
      const sql = `UPDATE ota_attempts SET ${setClauses.join(', ')} WHERE id = $${idx} RETURNING *;`;
      const res = await this.db.query(sql, params);
      return res.rows[0] || null;
    } else {
      const cleanUpdates = {};
      if (updates.outcome !== undefined) cleanUpdates.outcome = updates.outcome;
      if (updates.reason !== undefined) cleanUpdates.reason = updates.reason;
      if (updates.completedAt !== undefined) cleanUpdates.completed_at = updates.completedAt;
      if (updates.auditMetadata !== undefined) cleanUpdates.audit_metadata_json = JSON.stringify(updates.auditMetadata);
      return this.db.update('ota_attempts', id, cleanUpdates);
    }
  }

  async getAttempt(id) {
    if (this.isPostgres) {
      const sql = `SELECT * FROM ota_attempts WHERE id = $1 LIMIT 1;`;
      const res = await this.db.query(sql, [id]);
      return res.rows[0] || null;
    } else {
      return this.db.findById('ota_attempts', id);
    }
  }

  async listAttempts(filters = {}) {
    if (this.isPostgres) {
      let conditions = [];
      let params = [];
      let idx = 1;

      if (filters.rolloutId) {
        conditions.push(`rollout_id = $${idx++}`);
        params.push(filters.rolloutId);
      }
      if (filters.deviceId) {
        conditions.push(`device_id = $${idx++}`);
        params.push(filters.deviceId);
      }
      if (filters.outcome) {
        conditions.push(`outcome = $${idx++}`);
        params.push(filters.outcome);
      }

      const whereClause = conditions.length > 0 ? `WHERE ${conditions.join(' AND ')}` : '';
      const sql = `SELECT * FROM ota_attempts ${whereClause} ORDER BY created_at DESC;`;
      const res = await this.db.query(sql, params);
      return res.rows;
    } else {
      return this.db.find('ota_attempts', item => {
        if (filters.rolloutId && item.rollout_id !== filters.rolloutId) return false;
        if (filters.deviceId && item.device_id !== filters.deviceId) return false;
        if (filters.outcome && item.outcome !== filters.outcome) return false;
        return true;
      });
    }
  }
}

module.exports = { FleetFirmwareRepository };
