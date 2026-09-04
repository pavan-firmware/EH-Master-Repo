'use strict';

const crypto = require('crypto');
const uuidv4 = () => crypto.randomUUID();

/**
 * LocalDiscoveryNodeRepository
 *
 * Manages trusted LAN discovery nodes and cryptographic device identity mappings.
 */
class LocalDiscoveryNodeRepository {
  constructor(dbClient) {
    this.db = dbClient;
    this._memoryNodes = new Map();
  }

  async upsertNode({
    discoveryId = null,
    deviceId,
    homeId,
    productVariantId = null,
    macAddress,
    ipAddress,
    port,
    transportType,
    protocolVersion = '1.0.0',
    firmwareVersion = null,
    identityFingerprint,
    isTrusted = true,
    ttlSeconds = 300,
    discoveredAt = new Date().toISOString()
  }) {
    const existing = await this.findByDevice(deviceId);
    const id = existing ? existing.id : `ldn_${uuidv4()}`;
    const finalDiscId = discoveryId || (existing ? existing.discoveryId : `disc_${uuidv4()}`);
    const now = new Date().toISOString();

    const row = {
      id,
      discovery_id: finalDiscId,
      device_id: deviceId,
      home_id: homeId,
      product_variant_id: productVariantId,
      mac_address: macAddress,
      ip_address: ipAddress,
      port,
      transport_type: transportType,
      protocol_version: protocolVersion,
      firmware_version: firmwareVersion,
      identity_fingerprint: identityFingerprint,
      is_trusted: isTrusted ? 1 : 0,
      ttl_seconds: ttlSeconds,
      discovered_at: discoveredAt,
      created_at: existing ? existing.createdAt : now,
      updated_at: now
    };

    if (this.db && typeof this.db.query === 'function') {
      try {
        if (existing) {
          await this.db.query(
            `UPDATE local_discovery_nodes
             SET home_id = $1, product_variant_id = $2, mac_address = $3, ip_address = $4,
                 port = $5, transport_type = $6, protocol_version = $7, firmware_version = $8,
                 identity_fingerprint = $9, is_trusted = $10, ttl_seconds = $11,
                 discovered_at = $12, updated_at = $13
             WHERE id = $14`,
            [
              homeId, productVariantId, macAddress, ipAddress, port,
              transportType, protocolVersion, firmwareVersion, identityFingerprint,
              isTrusted ? 1 : 0, ttlSeconds, discoveredAt, now, id
            ]
          );
        } else {
          await this.db.query(
            `INSERT INTO local_discovery_nodes (
               id, discovery_id, device_id, home_id, product_variant_id, mac_address,
               ip_address, port, transport_type, protocol_version, firmware_version,
               identity_fingerprint, is_trusted, ttl_seconds, discovered_at, created_at, updated_at
             ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15, $16, $17)`,
            [
              id, finalDiscId, deviceId, homeId, productVariantId, macAddress,
              ipAddress, port, transportType, protocolVersion, firmwareVersion,
              identityFingerprint, isTrusted ? 1 : 0, ttlSeconds, discoveredAt, now, now
            ]
          );
        }
      } catch (_) {}
    }

    this._memoryNodes.set(deviceId, row);
    return this._mapRow(row);
  }

  async findById(id) {
    if (this.db && typeof this.db.query === 'function') {
      try {
        const res = await this.db.query('SELECT * FROM local_discovery_nodes WHERE id = $1', [id]);
        if (res.rows && res.rows.length > 0) {
          return this._mapRow(res.rows[0]);
        }
      } catch (_) {}
    }
    for (const n of this._memoryNodes.values()) {
      if (n.id === id) return this._mapRow(n);
    }
    return null;
  }

  async findByDevice(deviceId) {
    if (this.db && typeof this.db.query === 'function') {
      try {
        const res = await this.db.query('SELECT * FROM local_discovery_nodes WHERE device_id = $1', [deviceId]);
        if (res.rows && res.rows.length > 0) {
          return this._mapRow(res.rows[0]);
        }
      } catch (_) {}
    }
    const mem = this._memoryNodes.get(deviceId);
    return mem ? this._mapRow(mem) : null;
  }

  async findByDiscoveryId(discoveryId) {
    if (this.db && typeof this.db.query === 'function') {
      try {
        const res = await this.db.query('SELECT * FROM local_discovery_nodes WHERE discovery_id = $1', [discoveryId]);
        if (res.rows && res.rows.length > 0) {
          return this._mapRow(res.rows[0]);
        }
      } catch (_) {}
    }
    for (const n of this._memoryNodes.values()) {
      if (n.discovery_id === discoveryId) return this._mapRow(n);
    }
    return null;
  }

  async listByHome(homeId, { trustedOnly = false } = {}) {
    if (this.db && typeof this.db.query === 'function') {
      try {
        let query = 'SELECT * FROM local_discovery_nodes WHERE home_id = $1';
        const params = [homeId];
        if (trustedOnly) {
          query += ' AND is_trusted = 1';
        }
        query += ' ORDER BY updated_at DESC';

        const res = await this.db.query(query, params);
        if (res.rows && res.rows.length > 0) {
          return res.rows.map(r => this._mapRow(r));
        }
      } catch (_) {}
    }

    const list = [];
    for (const n of this._memoryNodes.values()) {
      if (n.home_id === homeId) {
        if (!trustedOnly || n.is_trusted === 1) {
          list.push(this._mapRow(n));
        }
      }
    }
    return list.sort((a, b) => new Date(b.updatedAt) - new Date(a.updatedAt));
  }

  async deleteByDevice(deviceId) {
    if (this.db && typeof this.db.query === 'function') {
      try {
        await this.db.query('DELETE FROM local_discovery_nodes WHERE device_id = $1', [deviceId]);
      } catch (_) {}
    }
    return this._memoryNodes.delete(deviceId);
  }

  _mapRow(row) {
    return {
      id: row.id,
      discoveryId: row.discovery_id,
      deviceId: row.device_id,
      homeId: row.home_id,
      productVariantId: row.product_variant_id,
      macAddress: row.mac_address,
      ipAddress: row.ip_address,
      port: row.port,
      transportType: row.transport_type,
      protocolVersion: row.protocol_version,
      firmwareVersion: row.firmware_version,
      identityFingerprint: row.identity_fingerprint,
      isTrusted: Boolean(row.is_trusted),
      ttlSeconds: row.ttl_seconds,
      discoveredAt: row.discovered_at,
      createdAt: row.created_at,
      updatedAt: row.updated_at
    };
  }
}

module.exports = { LocalDiscoveryNodeRepository };
