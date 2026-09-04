'use strict';

const crypto = require('crypto');
const uuidv4 = () => crypto.randomUUID();

/**
 * LocalRouteCacheRepository
 *
 * Manages local LAN/BLE/Thread/Matter routing endpoints for devices with TTL eviction.
 */
class LocalRouteCacheRepository {
  constructor(dbClient) {
    this.db = dbClient;
    this._memoryRoutes = new Map();
  }

  async upsertRoute({
    deviceId,
    homeId,
    transportType,
    localEndpoint,
    localIp = null,
    localPort = null,
    reachability = 'REACHABLE',
    identityFingerprint = null,
    isTlsSecured = true,
    latencyMs = 0.0,
    ttlSeconds = 300
  }) {
    const existing = await this.findByDevice(deviceId);
    const now = new Date();
    const expiresAt = new Date(now.getTime() + ttlSeconds * 1000);
    const id = existing ? existing.id : `lrc_${uuidv4()}`;

    const route = {
      id,
      device_id: deviceId,
      home_id: homeId,
      transport_type: transportType,
      local_endpoint: localEndpoint,
      local_ip: localIp,
      local_port: localPort,
      reachability,
      identity_fingerprint: identityFingerprint,
      is_tls_secured: isTlsSecured ? 1 : 0,
      latency_ms: latencyMs,
      expires_at: expiresAt.toISOString(),
      last_contact_at: now.toISOString(),
      created_at: existing ? existing.createdAt : now.toISOString(),
      updated_at: now.toISOString()
    };

    if (this.db && typeof this.db.query === 'function') {
      try {
        if (existing) {
          await this.db.query(
            `UPDATE local_route_cache 
             SET home_id = $1, transport_type = $2, local_endpoint = $3, local_ip = $4,
                 local_port = $5, reachability = $6, identity_fingerprint = $7,
                 is_tls_secured = $8, latency_ms = $9, expires_at = $10,
                 last_contact_at = $11, updated_at = $12
             WHERE id = $13`,
            [
              homeId, transportType, localEndpoint, localIp, localPort,
              reachability, identityFingerprint, isTlsSecured ? 1 : 0, latencyMs,
              expiresAt.toISOString(), now.toISOString(), now.toISOString(), id
            ]
          );
        } else {
          await this.db.query(
            `INSERT INTO local_route_cache (
               id, device_id, home_id, transport_type, local_endpoint, local_ip,
               local_port, reachability, identity_fingerprint, is_tls_secured,
               latency_ms, expires_at, last_contact_at, created_at, updated_at
             ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15)`,
            [
              id, deviceId, homeId, transportType, localEndpoint, localIp,
              localPort, reachability, identityFingerprint, isTlsSecured ? 1 : 0,
              latencyMs, expiresAt.toISOString(), now.toISOString(),
              now.toISOString(), now.toISOString()
            ]
          );
        }
      } catch (_) {}
    }

    this._memoryRoutes.set(deviceId, route);
    return this._mapRow(route);
  }

  async findById(id) {
    if (this.db && typeof this.db.query === 'function') {
      try {
        const res = await this.db.query('SELECT * FROM local_route_cache WHERE id = $1', [id]);
        if (res.rows && res.rows.length > 0) {
          return this._mapRow(res.rows[0]);
        }
      } catch (_) {}
    }

    for (const r of this._memoryRoutes.values()) {
      if (r.id === id) return this._mapRow(r);
    }
    return null;
  }

  async findByDevice(deviceId) {
    if (this.db && typeof this.db.query === 'function') {
      try {
        const res = await this.db.query(
          'SELECT * FROM local_route_cache WHERE device_id = $1 ORDER BY updated_at DESC LIMIT 1',
          [deviceId]
        );
        if (res.rows && res.rows.length > 0) {
          return this._mapRow(res.rows[0]);
        }
      } catch (_) {}
    }

    const mem = this._memoryRoutes.get(deviceId);
    return mem ? this._mapRow(mem) : null;
  }

  async listByHome(homeId, { includeExpired = false } = {}) {
    if (this.db && typeof this.db.query === 'function') {
      try {
        const now = new Date().toISOString();
        let query = 'SELECT * FROM local_route_cache WHERE home_id = $1';
        const params = [homeId];
        if (!includeExpired) {
          query += ' AND expires_at > $2';
          params.push(now);
        }
        query += ' ORDER BY updated_at DESC';

        const res = await this.db.query(query, params);
        if (res.rows && res.rows.length > 0) {
          return res.rows.map(r => this._mapRow(r));
        }
      } catch (_) {}
    }

    const now = new Date();
    const list = [];
    for (const r of this._memoryRoutes.values()) {
      if (r.home_id === homeId) {
        if (includeExpired || new Date(r.expires_at) > now) {
          list.push(this._mapRow(r));
        }
      }
    }
    return list.sort((a, b) => new Date(b.updatedAt) - new Date(a.updatedAt));
  }

  async updateReachability(deviceId, reachability, latencyMs = null) {
    const existing = await this.findByDevice(deviceId);
    if (!existing) return null;

    const now = new Date().toISOString();
    const updated = {
      ...existing,
      reachability,
      latencyMs: latencyMs !== null ? latencyMs : existing.latencyMs,
      lastContactAt: now,
      updatedAt: now
    };

    const row = {
      id: updated.id,
      device_id: updated.deviceId,
      home_id: updated.homeId,
      transport_type: updated.transportType,
      local_endpoint: updated.localEndpoint,
      local_ip: updated.localIp,
      local_port: updated.localPort,
      reachability: updated.reachability,
      identity_fingerprint: updated.identityFingerprint,
      is_tls_secured: updated.isTlsSecured ? 1 : 0,
      latency_ms: updated.latencyMs,
      expires_at: updated.expiresAt,
      last_contact_at: now,
      created_at: updated.createdAt,
      updated_at: now
    };

    if (this.db && typeof this.db.query === 'function') {
      try {
        await this.db.query(
          `UPDATE local_route_cache SET reachability = $1, latency_ms = $2, last_contact_at = $3, updated_at = $3 WHERE device_id = $4`,
          [reachability, updated.latencyMs, now, deviceId]
        );
      } catch (_) {}
    }

    this._memoryRoutes.set(deviceId, row);
    return this._mapRow(row);
  }

  async deleteByDevice(deviceId) {
    if (this.db && typeof this.db.query === 'function') {
      try {
        await this.db.query('DELETE FROM local_route_cache WHERE device_id = $1', [deviceId]);
      } catch (_) {}
    }
    return this._memoryRoutes.delete(deviceId);
  }

  async pruneExpired(nowIso = new Date().toISOString()) {
    const now = new Date(nowIso);
    let count = 0;
    for (const [devId, r] of this._memoryRoutes.entries()) {
      if (new Date(r.expires_at) <= now) {
        this._memoryRoutes.delete(devId);
        count++;
      }
    }
    return count;
  }

  _mapRow(row) {
    return {
      id: row.id,
      deviceId: row.device_id,
      homeId: row.home_id,
      transportType: row.transport_type,
      localEndpoint: row.local_endpoint,
      localIp: row.local_ip,
      localPort: row.local_port,
      reachability: row.reachability,
      identityFingerprint: row.identity_fingerprint,
      isTlsSecured: Boolean(row.is_tls_secured),
      latencyMs: Number(row.latency_ms || 0),
      expiresAt: row.expires_at,
      lastContactAt: row.last_contact_at,
      createdAt: row.created_at,
      updatedAt: row.updated_at
    };
  }
}

module.exports = { LocalRouteCacheRepository };
