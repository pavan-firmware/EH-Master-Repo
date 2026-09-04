'use strict';

/**
 * EH Home — External Platform Link Repository (Phase 29)
 *
 * Tracks external smart home platform linkages (Apple Home, Google Home, Alexa, Matter).
 * Provider-neutral domain repository.
 */

class ExternalPlatformLinkRepository {
  constructor(db) {
    this.db = db;
    this._memoryLinks = new Map();
  }

  async upsertLink({
    id,
    homeId,
    deviceId,
    platform,
    status = 'CONNECTED',
    externalIdentifier = null,
    displayName,
    syncStatus = 'SYNCHRONIZED',
    lastErrorMessage = null,
    linkedAt = new Date().toISOString()
  }) {
    const existing = await this.findByDeviceAndPlatform(deviceId, platform);
    const targetId = id || existing?.id || `link_${platform.toLowerCase()}_${deviceId}`;
    const now = new Date().toISOString();

    const record = {
      id: targetId,
      home_id: homeId,
      device_id: deviceId,
      platform,
      status,
      external_identifier: externalIdentifier || existing?.externalIdentifier || null,
      display_name: displayName || existing?.displayName || `${platform} Integration`,
      sync_status: syncStatus,
      last_error_message: lastErrorMessage,
      linked_at: linkedAt,
      last_synced_at: now,
      created_at: existing?.createdAt || now,
      updated_at: now
    };

    this._memoryLinks.set(targetId, record);

    if (this.db && typeof this.db.insert === 'function') {
      try {
        if (existing) {
          await this.db.update('external_platform_links', targetId, record);
        } else {
          await this.db.insert('external_platform_links', targetId, record);
        }
      } catch (err) {}
    }

    return this._mapRow(record);
  }

  async findById(id) {
    if (this.db && typeof this.db.findById === 'function') {
      try {
        const found = await this.db.findById('external_platform_links', id);
        if (found) return this._mapRow(found);
      } catch (err) {}
    }
    const mem = this._memoryLinks.get(id);
    return mem ? this._mapRow(mem) : null;
  }

  async findByDeviceAndPlatform(deviceId, platform) {
    if (this.db && typeof this.db.find === 'function') {
      try {
        const rows = await this.db.find('external_platform_links', r => r.device_id === deviceId && r.platform === platform);
        if (rows && rows.length > 0) return this._mapRow(rows[0]);
      } catch (err) {}
    }
    for (const r of this._memoryLinks.values()) {
      if (r.device_id === deviceId && r.platform === platform) return this._mapRow(r);
    }
    return null;
  }

  async listByDeviceId(deviceId) {
    if (this.db && typeof this.db.find === 'function') {
      try {
        const rows = await this.db.find('external_platform_links', r => r.device_id === deviceId);
        if (rows) return rows.map(r => this._mapRow(r));
      } catch (err) {}
    }
    const results = [];
    for (const r of this._memoryLinks.values()) {
      if (r.device_id === deviceId) results.push(this._mapRow(r));
    }
    return results;
  }

  async listByHomeId(homeId) {
    if (this.db && typeof this.db.find === 'function') {
      try {
        const rows = await this.db.find('external_platform_links', r => r.home_id === homeId);
        if (rows) return rows.map(r => this._mapRow(r));
      } catch (err) {}
    }
    const results = [];
    for (const r of this._memoryLinks.values()) {
      if (r.home_id === homeId) results.push(this._mapRow(r));
    }
    return results;
  }

  async disconnectLink(deviceId, platform) {
    const existing = await this.findByDeviceAndPlatform(deviceId, platform);
    if (!existing) return null;

    const updated = {
      ...existing,
      status: 'DISCONNECTED',
      syncStatus: 'IDLE',
      updatedAt: new Date().toISOString()
    };

    return this.upsertLink(updated);
  }

  async clearAllLinksForDevice(deviceId) {
    const links = await this.listByDeviceId(deviceId);
    const results = [];
    for (const l of links) {
      const disc = await this.disconnectLink(deviceId, l.platform);
      if (disc) results.push(disc);
    }
    return results;
  }

  _mapRow(row) {
    if (!row) return null;
    return {
      id: row.id,
      linkId: row.id,
      homeId: row.home_id || row.homeId,
      deviceId: row.device_id || row.deviceId,
      platform: row.platform,
      status: row.status,
      externalIdentifier: row.external_identifier !== undefined ? row.external_identifier : row.externalIdentifier,
      displayName: row.display_name || row.displayName,
      syncStatus: row.sync_status || row.syncStatus || 'IDLE',
      lastErrorMessage: row.last_error_message !== undefined ? row.last_error_message : row.lastErrorMessage,
      linkedAt: row.linked_at || row.linkedAt || null,
      lastSyncedAt: row.last_synced_at || row.lastSyncedAt || null,
      createdAt: row.created_at || row.createdAt,
      updatedAt: row.updated_at || row.updatedAt
    };
  }
}

module.exports = { ExternalPlatformLinkRepository };
