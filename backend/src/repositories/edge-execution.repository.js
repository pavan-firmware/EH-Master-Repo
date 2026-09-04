'use strict';

const crypto = require('crypto');
const uuidv4 = () => crypto.randomUUID();

/**
 * EdgeExecutionRepository
 *
 * Persists and queries edge command execution records, route choices, and latencies.
 */
class EdgeExecutionRepository {
  constructor(dbClient) {
    this.db = dbClient;
    this._memoryRecords = new Map();
  }

  async createRecord({
    commandId,
    deviceId,
    homeId,
    channelIndex = null,
    action,
    routeMode,
    transportUsed,
    status = 'PENDING',
    isConfirmedByDevice = false,
    confirmedState = null,
    latencyMs = 0.0,
    errorMessage = null,
    idempotencyKey = null,
    actorUserId = null,
    actorSource = 'APP_LOCAL',
    queuedForCloudSync = false,
    executedAt = new Date().toISOString()
  }) {
    const id = `eer_${uuidv4()}`;
    const confirmedStateJson = confirmedState ? (typeof confirmedState === 'string' ? confirmedState : JSON.stringify(confirmedState)) : null;

    const row = {
      id,
      command_id: commandId,
      device_id: deviceId,
      home_id: homeId,
      channel_index: channelIndex,
      action,
      route_mode: routeMode,
      transport_used: transportUsed,
      status,
      is_confirmed_by_device: isConfirmedByDevice ? 1 : 0,
      confirmed_state: confirmedStateJson,
      latency_ms: latencyMs,
      error_message: errorMessage,
      idempotency_key: idempotencyKey,
      actor_user_id: actorUserId,
      actor_source: actorSource,
      queued_for_cloud_sync: queuedForCloudSync ? 1 : 0,
      executed_at: executedAt,
      created_at: new Date().toISOString()
    };

    if (this.db && typeof this.db.query === 'function') {
      try {
        await this.db.query(
          `INSERT INTO edge_execution_records (
             id, command_id, device_id, home_id, channel_index, action,
             route_mode, transport_used, status, is_confirmed_by_device,
             confirmed_state, latency_ms, error_message, idempotency_key,
             actor_user_id, actor_source, queued_for_cloud_sync, executed_at, created_at
           ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15, $16, $17, $18, $19)`,
          [
            id, commandId, deviceId, homeId, channelIndex, action,
            routeMode, transportUsed, status, isConfirmedByDevice ? 1 : 0,
            confirmedStateJson, latencyMs, errorMessage, idempotencyKey,
            actorUserId, actorSource, queuedForCloudSync ? 1 : 0,
            executedAt, row.created_at
          ]
        );
      } catch (_) {}
    }

    this._memoryRecords.set(id, row);
    return this._mapRow(row);
  }

  async findById(id) {
    if (this.db && typeof this.db.query === 'function') {
      try {
        const res = await this.db.query('SELECT * FROM edge_execution_records WHERE id = $1', [id]);
        if (res.rows && res.rows.length > 0) {
          return this._mapRow(res.rows[0]);
        }
      } catch (_) {}
    }
    const mem = this._memoryRecords.get(id);
    return mem ? this._mapRow(mem) : null;
  }

  async findByCommandId(commandId) {
    if (this.db && typeof this.db.query === 'function') {
      try {
        const res = await this.db.query('SELECT * FROM edge_execution_records WHERE command_id = $1', [commandId]);
        if (res.rows && res.rows.length > 0) {
          return this._mapRow(res.rows[0]);
        }
      } catch (_) {}
    }

    for (const r of this._memoryRecords.values()) {
      if (r.command_id === commandId) return this._mapRow(r);
    }
    return null;
  }

  async findByIdempotencyKey(idempotencyKey) {
    if (!idempotencyKey) return null;
    if (this.db && typeof this.db.query === 'function') {
      try {
        const res = await this.db.query('SELECT * FROM edge_execution_records WHERE idempotency_key = $1', [idempotencyKey]);
        if (res.rows && res.rows.length > 0) {
          return this._mapRow(res.rows[0]);
        }
      } catch (_) {}
    }

    for (const r of this._memoryRecords.values()) {
      if (r.idempotency_key === idempotencyKey) return this._mapRow(r);
    }
    return null;
  }

  async updateStatus(id, {
    status,
    isConfirmedByDevice = false,
    confirmedState = null,
    latencyMs = null,
    errorMessage = null,
    queuedForCloudSync = null
  }) {
    const existing = await this.findById(id);
    if (!existing) return null;

    const row = this._memoryRecords.get(id) || {
      id: existing.id,
      command_id: existing.commandId,
      device_id: existing.deviceId,
      home_id: existing.homeId,
      channel_index: existing.channelIndex,
      action: existing.action,
      route_mode: existing.routeMode,
      transport_used: existing.transportUsed,
      status: existing.status,
      is_confirmed_by_device: existing.isConfirmedByDevice ? 1 : 0,
      confirmed_state: JSON.stringify(existing.confirmedState || {}),
      latency_ms: existing.latencyMs,
      error_message: existing.errorMessage,
      idempotency_key: existing.idempotencyKey,
      actor_user_id: existing.actorUserId,
      actor_source: existing.actorSource,
      queued_for_cloud_sync: existing.queuedForCloudSync ? 1 : 0,
      executed_at: existing.executedAt,
      created_at: existing.createdAt
    };

    row.status = status;
    row.is_confirmed_by_device = isConfirmedByDevice ? 1 : 0;
    if (confirmedState !== null) row.confirmed_state = JSON.stringify(confirmedState);
    if (latencyMs !== null) row.latency_ms = latencyMs;
    if (errorMessage !== null) row.error_message = errorMessage;
    if (queuedForCloudSync !== null) row.queued_for_cloud_sync = queuedForCloudSync ? 1 : 0;

    if (this.db && typeof this.db.query === 'function') {
      try {
        await this.db.query(
          `UPDATE edge_execution_records
           SET status = $1, is_confirmed_by_device = $2, confirmed_state = $3,
               latency_ms = $4, error_message = $5, queued_for_cloud_sync = $6
           WHERE id = $7`,
          [
            status, isConfirmedByDevice ? 1 : 0, row.confirmed_state,
            row.latency_ms, row.error_message, row.queued_for_cloud_sync, id
          ]
        );
      } catch (_) {}
    }

    this._memoryRecords.set(id, row);
    return this._mapRow(row);
  }

  async listByHome(homeId, { limit = 50 } = {}) {
    if (this.db && typeof this.db.query === 'function') {
      try {
        const res = await this.db.query(
          'SELECT * FROM edge_execution_records WHERE home_id = $1 ORDER BY executed_at DESC LIMIT $2',
          [homeId, limit]
        );
        if (res.rows && res.rows.length > 0) {
          return res.rows.map(r => this._mapRow(r));
        }
      } catch (_) {}
    }

    const list = [];
    for (const r of this._memoryRecords.values()) {
      if (r.home_id === homeId) list.push(this._mapRow(r));
    }
    return list.sort((a, b) => new Date(b.executedAt) - new Date(a.executedAt)).slice(0, limit);
  }

  async listByDevice(deviceId, { limit = 50 } = {}) {
    if (this.db && typeof this.db.query === 'function') {
      try {
        const res = await this.db.query(
          'SELECT * FROM edge_execution_records WHERE device_id = $1 ORDER BY executed_at DESC LIMIT $2',
          [deviceId, limit]
        );
        if (res.rows && res.rows.length > 0) {
          return res.rows.map(r => this._mapRow(r));
        }
      } catch (_) {}
    }

    const list = [];
    for (const r of this._memoryRecords.values()) {
      if (r.device_id === deviceId) list.push(this._mapRow(r));
    }
    return list.sort((a, b) => new Date(b.executedAt) - new Date(a.executedAt)).slice(0, limit);
  }

  async getMetrics(homeId) {
    const records = await this.listByHome(homeId, { limit: 200 });
    const total = records.length;
    if (total === 0) {
      return {
        totalExecutions: 0,
        localSuccessRate: 1.0,
        averageLatencyMs: 0.0,
        localCount: 0,
        cloudCount: 0,
        fallbackCount: 0,
        confirmedCount: 0,
        failedCount: 0
      };
    }

    let localCount = 0;
    let cloudCount = 0;
    let fallbackCount = 0;
    let confirmedCount = 0;
    let failedCount = 0;
    let totalLatency = 0;

    for (const r of records) {
      if (r.routeMode === 'LOCAL') localCount++;
      if (r.routeMode === 'CLOUD') cloudCount++;
      if (r.status === 'CONFIRMED') confirmedCount++;
      if (r.status === 'FAILED') failedCount++;
      if (r.queuedForCloudSync) fallbackCount++;
      totalLatency += r.latencyMs || 0;
    }

    return {
      totalExecutions: total,
      localSuccessRate: total > 0 ? Number((confirmedCount / total).toFixed(4)) : 1.0,
      averageLatencyMs: total > 0 ? Number((totalLatency / total).toFixed(2)) : 0.0,
      localCount,
      cloudCount,
      fallbackCount,
      confirmedCount,
      failedCount
    };
  }

  _mapRow(row) {
    let confirmedState = null;
    if (row.confirmed_state) {
      try {
        confirmedState = typeof row.confirmed_state === 'string' ? JSON.parse(row.confirmed_state) : row.confirmed_state;
      } catch (_) {
        confirmedState = {};
      }
    }

    return {
      id: row.id,
      commandId: row.command_id,
      deviceId: row.device_id,
      homeId: row.home_id,
      channelIndex: row.channel_index,
      action: row.action,
      routeMode: row.route_mode,
      transportUsed: row.transport_used,
      status: row.status,
      isConfirmedByDevice: Boolean(row.is_confirmed_by_device),
      confirmedState,
      latencyMs: Number(row.latency_ms || 0),
      errorMessage: row.error_message,
      idempotencyKey: row.idempotency_key,
      actorUserId: row.actor_user_id,
      actorSource: row.actor_source,
      queuedForCloudSync: Boolean(row.queued_for_cloud_sync),
      executedAt: row.executed_at,
      createdAt: row.created_at
    };
  }
}

module.exports = { EdgeExecutionRepository };
