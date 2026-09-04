'use strict';

/**
 * EH Home — Matter Device Repository (Phase 29)
 *
 * Manages Matter device mappings referencing canonical EH devices,
 * endpoints, and Matter node IDs. Supports in-memory test client and SQL fallback.
 */

class MatterDeviceRepository {
  constructor(db) {
    this.db = db;
    this._memoryDevices = new Map();
    this._memoryEndpoints = new Map();
  }

  async upsertMatterDevice({
    id,
    deviceId,
    homeId,
    nodeId,
    vendorId = 65521,
    productId,
    matterDeviceType,
    commissioningState = 'NOT_COMMISSIONED',
    subscriptionState = 'NONE',
    softwareVersion = 1,
    softwareVersionString = '1.0.0',
    hardwareVersion = 1,
    hardwareVersionString = 'revA',
    discriminator = 3840,
    setupPasscode = 20202021,
    lastSynchronizedAt = null
  }) {
    const existing = await this.findByDeviceId(deviceId);
    const targetId = id || existing?.id || `mat_${deviceId}`;
    const now = new Date().toISOString();

    const record = {
      id: targetId,
      device_id: deviceId,
      home_id: homeId,
      node_id: nodeId || existing?.nodeId || `0x${Math.floor(Math.random() * 0xFFFFFFFFFFFFFFFF).toString(16).padStart(16, '0')}`,
      vendor_id: vendorId,
      product_id: productId || 32768,
      matter_device_type: matterDeviceType,
      commissioning_state: commissioningState,
      subscription_state: subscriptionState,
      software_version: softwareVersion,
      software_version_string: softwareVersionString,
      hardware_version: hardwareVersion,
      hardware_version_string: hardwareVersionString,
      discriminator,
      setup_passcode: setupPasscode,
      last_synchronized_at: lastSynchronizedAt,
      created_at: existing?.createdAt || now,
      updated_at: now
    };

    this._memoryDevices.set(targetId, record);

    if (this.db && typeof this.db.insert === 'function') {
      try {
        if (existing) {
          await this.db.update('matter_devices', targetId, record);
        } else {
          await this.db.insert('matter_devices', targetId, record);
        }
      } catch (err) {
        // Fallback to memory
      }
    }

    return this._mapRow(record);
  }

  async findById(id) {
    if (this.db && typeof this.db.findById === 'function') {
      try {
        const found = await this.db.findById('matter_devices', id);
        if (found) return this._mapRow(found);
      } catch (err) {}
    }
    const mem = this._memoryDevices.get(id);
    return mem ? this._mapRow(mem) : null;
  }

  async findByDeviceId(deviceId) {
    if (this.db && typeof this.db.find === 'function') {
      try {
        const rows = await this.db.find('matter_devices', r => r.device_id === deviceId);
        if (rows && rows.length > 0) return this._mapRow(rows[0]);
      } catch (err) {}
    }
    for (const r of this._memoryDevices.values()) {
      if (r.device_id === deviceId) return this._mapRow(r);
    }
    return null;
  }

  async listByHomeId(homeId) {
    if (this.db && typeof this.db.find === 'function') {
      try {
        const rows = await this.db.find('matter_devices', r => r.home_id === homeId);
        if (rows) return rows.map(r => this._mapRow(r));
      } catch (err) {}
    }
    const results = [];
    for (const r of this._memoryDevices.values()) {
      if (r.home_id === homeId) results.push(this._mapRow(r));
    }
    return results;
  }

  async updateCommissioningState(deviceId, commissioningState, subscriptionState = null) {
    const existing = await this.findByDeviceId(deviceId);
    if (!existing) return null;

    const updates = {
      commissioningState,
      ...(subscriptionState ? { subscriptionState } : {}),
      lastSynchronizedAt: new Date().toISOString()
    };

    return this.upsertMatterDevice({
      ...existing,
      ...updates
    });
  }

  // -------------------------------------------------------------------------
  // Matter Endpoints
  // -------------------------------------------------------------------------

  async saveEndpoints(matterDeviceId, endpoints = []) {
    const results = [];
    for (const ep of endpoints) {
      const epId = ep.id || `${matterDeviceId}_ep_${ep.endpointNumber}`;
      const row = {
        id: epId,
        matter_device_id: matterDeviceId,
        endpoint_number: ep.endpointNumber,
        device_type: ep.deviceType,
        channel_index: ep.channelIndex || 1,
        server_clusters: typeof ep.serverClusters === 'string' ? ep.serverClusters : JSON.stringify(ep.serverClusters || []),
        client_clusters: typeof ep.clientClusters === 'string' ? ep.clientClusters : JSON.stringify(ep.clientClusters || []),
        created_at: new Date().toISOString(),
        updated_at: new Date().toISOString()
      };

      this._memoryEndpoints.set(epId, row);
      if (this.db && typeof this.db.insert === 'function') {
        try {
          await this.db.insert('matter_endpoints', epId, row);
        } catch (err) {}
      }
      results.push(this._mapEndpoint(row));
    }
    return results;
  }

  async getEndpoints(matterDeviceId) {
    if (this.db && typeof this.db.find === 'function') {
      try {
        const rows = await this.db.find('matter_endpoints', r => r.matter_device_id === matterDeviceId);
        if (rows && rows.length > 0) return rows.map(r => this._mapEndpoint(r));
      } catch (err) {}
    }
    const results = [];
    for (const r of this._memoryEndpoints.values()) {
      if (r.matter_device_id === matterDeviceId) results.push(this._mapEndpoint(r));
    }
    return results;
  }

  _mapRow(row) {
    if (!row) return null;
    return {
      id: row.id,
      matterDeviceId: row.id,
      deviceId: row.device_id || row.deviceId,
      homeId: row.home_id || row.homeId,
      nodeId: row.node_id || row.nodeId,
      vendorId: row.vendor_id || row.vendorId || 65521,
      productId: row.product_id || row.productId,
      matterDeviceType: row.matter_device_type || row.matterDeviceType,
      commissioningState: row.commissioning_state || row.commissioningState,
      subscriptionState: row.subscription_state || row.subscriptionState || 'NONE',
      softwareVersion: row.software_version || row.softwareVersion || 1,
      softwareVersionString: row.software_version_string || row.softwareVersionString || '1.0.0',
      hardwareVersion: row.hardware_version || row.hardwareVersion || 1,
      hardwareVersionString: row.hardware_version_string || row.hardwareVersionString || 'revA',
      discriminator: row.discriminator !== undefined ? row.discriminator : 3840,
      setupPasscode: row.setup_passcode || row.setupPasscode,
      lastSynchronizedAt: row.last_synchronized_at || row.lastSynchronizedAt || null,
      createdAt: row.created_at || row.createdAt,
      updatedAt: row.updated_at || row.updatedAt
    };
  }

  _mapEndpoint(row) {
    if (!row) return null;
    let serverClusters = [];
    let clientClusters = [];
    try {
      serverClusters = typeof row.server_clusters === 'string' ? JSON.parse(row.server_clusters) : (row.server_clusters || []);
    } catch (e) {}
    try {
      clientClusters = typeof row.client_clusters === 'string' ? JSON.parse(row.client_clusters) : (row.client_clusters || []);
    } catch (e) {}

    return {
      id: row.id,
      matterDeviceId: row.matter_device_id || row.matterDeviceId,
      endpointNumber: row.endpoint_number !== undefined ? row.endpoint_number : row.endpointNumber,
      deviceType: row.device_type || row.deviceType,
      channelIndex: row.channel_index !== undefined ? row.channel_index : row.channelIndex,
      serverClusters,
      clientClusters
    };
  }
}

module.exports = { MatterDeviceRepository };
