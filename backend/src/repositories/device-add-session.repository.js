'use strict';

/**
 * EH Home — Device Add Session Repository (Phase 27)
 */

class DeviceAddSessionRepository {
  constructor(db) {
    this.db = db;
    this._memorySessions = new Map();
  }

  async createSession({
    id,
    homeId,
    userId,
    entryMode,
    stage = 'PRODUCT_SELECTED',
    productVariantId = null,
    deviceId = null,
    commissioningSessionId = null,
    selectedRoomId = null,
    customDeviceName = null,
    channelLabels = {},
    compatibilityStatus = null,
    errorMessage = null,
    createdAt = new Date().toISOString(),
    updatedAt = new Date().toISOString()
  }) {
    const session = {
      id,
      home_id: homeId,
      user_id: userId,
      entry_mode: entryMode,
      stage,
      product_variant_id: productVariantId,
      device_id: deviceId,
      commissioning_session_id: commissioningSessionId,
      selected_room_id: selectedRoomId,
      custom_device_name: customDeviceName,
      channel_labels: typeof channelLabels === 'string' ? channelLabels : JSON.stringify(channelLabels || {}),
      compatibility_status: compatibilityStatus,
      error_message: errorMessage,
      created_at: createdAt,
      updated_at: updatedAt,
      completed_at: null
    };

    this._memorySessions.set(id, session);
    if (this.db && typeof this.db.insert === 'function') {
      try {
        await this.db.insert('device_add_sessions', id, session);
      } catch (err) {
        // Ignore if exists or mock
      }
    } else if (this.db && typeof this.db.query === 'function') {
      try {
        await this.db.query(
          `INSERT INTO device_add_sessions (
            id, home_id, user_id, entry_mode, stage, product_variant_id,
            device_id, commissioning_session_id, selected_room_id,
            custom_device_name, channel_labels, compatibility_status,
            error_message, created_at, updated_at, completed_at
          ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15, $16)`,
          [
            session.id, session.home_id, session.user_id, session.entry_mode,
            session.stage, session.product_variant_id, session.device_id,
            session.commissioning_session_id, session.selected_room_id,
            session.custom_device_name, session.channel_labels,
            session.compatibility_status, session.error_message,
            session.created_at, session.updated_at, session.completed_at
          ]
        );
      } catch (err) {
        // Fallback
      }
    }

    return this._mapRow(session);
  }

  async findById(sessionId) {
    if (this.db && typeof this.db.findById === 'function') {
      try {
        const found = await this.db.findById('device_add_sessions', sessionId);
        if (found) return this._mapRow(found);
      } catch (err) {
        // Fallback
      }
    } else if (this.db && typeof this.db.query === 'function') {
      try {
        const res = await this.db.query(
          'SELECT * FROM device_add_sessions WHERE id = $1',
          [sessionId]
        );
        if (res.rows && res.rows.length > 0) {
          return this._mapRow(res.rows[0]);
        }
      } catch (err) {
        // Fallback to memory
      }
    }
    const mem = this._memorySessions.get(sessionId);
    return mem ? this._mapRow(mem) : null;
  }

  async findByHomeId(homeId, limit = 20) {
    if (this.db && typeof this.db.query === 'function') {
      try {
        const res = await this.db.query(
          'SELECT * FROM device_add_sessions WHERE home_id = $1 ORDER BY updated_at DESC LIMIT $2',
          [homeId, limit]
        );
        if (res.rows) {
          return res.rows.map(r => this._mapRow(r));
        }
      } catch (err) {
        // Fallback
      }
    }
    const results = [];
    for (const s of this._memorySessions.values()) {
      if (s.home_id === homeId) {
        results.push(this._mapRow(s));
      }
    }
    return results.sort((a, b) => new Date(b.updatedAt) - new Date(a.updatedAt)).slice(0, limit);
  }

  async updateSession(sessionId, updates = {}) {
    const existing = await this.findById(sessionId);
    if (!existing) return null;

    const now = new Date().toISOString();
    const updated = {
      ...existing,
      ...updates,
      updatedAt: now,
      completedAt: updates.stage === 'COMPLETED' || updates.stage === 'CANCELLED' || updates.stage === 'FAILED'
        ? (existing.completedAt || now)
        : existing.completedAt
    };

    const row = {
      id: updated.sessionId,
      home_id: updated.homeId,
      user_id: updated.userId,
      entry_mode: updated.entryMode,
      stage: updated.stage,
      product_variant_id: updated.productVariantId,
      device_id: updated.deviceId,
      commissioning_session_id: updated.commissioningSessionId,
      selected_room_id: updated.selectedRoomId,
      custom_device_name: updated.customDeviceName,
      channel_labels: typeof updated.channelLabels === 'string'
        ? updated.channelLabels
        : JSON.stringify(updated.channelLabels || {}),
      compatibility_status: updated.compatibilityStatus,
      error_message: updated.errorMessage,
      created_at: updated.createdAt,
      updated_at: updated.updatedAt,
      completed_at: updated.completedAt
    };

    if (this.db && typeof this.db.query === 'function') {
      try {
        await this.db.query(
          `UPDATE device_add_sessions SET
            stage = $2,
            product_variant_id = $3,
            device_id = $4,
            commissioning_session_id = $5,
            selected_room_id = $6,
            custom_device_name = $7,
            channel_labels = $8,
            compatibility_status = $9,
            error_message = $10,
            updated_at = $11,
            completed_at = $12
          WHERE id = $1`,
          [
            sessionId, row.stage, row.product_variant_id, row.device_id,
            row.commissioning_session_id, row.selected_room_id,
            row.custom_device_name, row.channel_labels,
            row.compatibility_status, row.error_message,
            row.updated_at, row.completed_at
          ]
        );
      } catch (err) {
        this._memorySessions.set(sessionId, row);
      }
    } else {
      this._memorySessions.set(sessionId, row);
    }

    return updated;
  }

  _mapRow(row) {
    if (!row) return null;
    let channelLabels = {};
    if (typeof row.channel_labels === 'string') {
      try {
        channelLabels = JSON.parse(row.channel_labels);
      } catch (e) {
        channelLabels = {};
      }
    } else if (typeof row.channel_labels === 'object' && row.channel_labels !== null) {
      channelLabels = row.channel_labels;
    } else if (typeof row.channelLabels === 'object' && row.channelLabels !== null) {
      channelLabels = row.channelLabels;
    }

    return {
      sessionId: row.id || row.sessionId,
      homeId: row.home_id || row.homeId,
      userId: row.user_id || row.userId,
      entryMode: row.entry_mode || row.entryMode,
      stage: row.stage,
      productVariantId: row.product_variant_id !== undefined ? row.product_variant_id : row.productVariantId,
      deviceId: row.device_id !== undefined ? row.device_id : row.deviceId,
      commissioningSessionId: row.commissioning_session_id !== undefined ? row.commissioning_session_id : row.commissioningSessionId,
      selectedRoomId: row.selected_room_id !== undefined ? row.selected_room_id : row.selectedRoomId,
      customDeviceName: row.custom_device_name !== undefined ? row.custom_device_name : row.customDeviceName,
      channelLabels,
      compatibilityStatus: row.compatibility_status !== undefined ? row.compatibility_status : row.compatibilityStatus,
      errorMessage: row.error_message !== undefined ? row.error_message : row.errorMessage,
      createdAt: row.created_at || row.createdAt,
      updatedAt: row.updated_at || row.updatedAt,
      completedAt: row.completed_at !== undefined ? row.completed_at : row.completedAt
    };
  }
}

module.exports = { DeviceAddSessionRepository };
