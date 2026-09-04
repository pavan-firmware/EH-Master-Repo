'use strict';

/**
 * EH Home — Matter Fabric Repository (Phase 29)
 *
 * Manages Multi-Admin fabric bindings for Matter devices.
 * Supports concurrent fabrics (Apple Home, Google Home, Alexa, EH Home, Custom).
 */

class MatterFabricRepository {
  constructor(db) {
    this.db = db;
    this._memoryFabrics = new Map();
  }

  async addFabric({
    id,
    fabricId,
    matterDeviceId,
    fabricIndex,
    fabricName,
    vendorId,
    controllerNodeId = null,
    commissioningState = 'CONNECTED',
    label = null,
    pairedAt = new Date().toISOString()
  }) {
    const existing = await this.findByDeviceAndFabricId(matterDeviceId, fabricId);
    const targetId = id || existing?.id || `fab_${matterDeviceId}_${fabricIndex || Math.floor(Math.random() * 1000)}`;
    const now = new Date().toISOString();

    const record = {
      id: targetId,
      fabric_id: fabricId,
      matter_device_id: matterDeviceId,
      fabric_index: fabricIndex || (existing?.fabricIndex || 1),
      fabric_name: fabricName,
      vendor_id: vendorId,
      controller_node_id: controllerNodeId,
      commissioning_state: commissioningState,
      label,
      paired_at: pairedAt,
      last_synchronized_at: now,
      created_at: existing?.createdAt || now,
      updated_at: now
    };

    this._memoryFabrics.set(targetId, record);

    if (this.db && typeof this.db.insert === 'function') {
      try {
        if (existing) {
          await this.db.update('matter_fabrics', targetId, record);
        } else {
          await this.db.insert('matter_fabrics', targetId, record);
        }
      } catch (err) {}
    }

    return this._mapRow(record);
  }

  async findById(id) {
    if (this.db && typeof this.db.findById === 'function') {
      try {
        const found = await this.db.findById('matter_fabrics', id);
        if (found) return this._mapRow(found);
      } catch (err) {}
    }
    const mem = this._memoryFabrics.get(id);
    return mem ? this._mapRow(mem) : null;
  }

  async findByDeviceAndFabricId(matterDeviceId, fabricId) {
    if (this.db && typeof this.db.find === 'function') {
      try {
        const rows = await this.db.find('matter_fabrics', r => r.matter_device_id === matterDeviceId && r.fabric_id === fabricId);
        if (rows && rows.length > 0) return this._mapRow(rows[0]);
      } catch (err) {}
    }
    for (const r of this._memoryFabrics.values()) {
      if (r.matter_device_id === matterDeviceId && r.fabric_id === fabricId) return this._mapRow(r);
    }
    return null;
  }

  async listByMatterDeviceId(matterDeviceId) {
    if (this.db && typeof this.db.find === 'function') {
      try {
        const rows = await this.db.find('matter_fabrics', r => r.matter_device_id === matterDeviceId && r.commissioning_state !== 'DECOMMISSIONED');
        if (rows) return rows.map(r => this._mapRow(r));
      } catch (err) {}
    }
    const results = [];
    for (const r of this._memoryFabrics.values()) {
      if (r.matter_device_id === matterDeviceId && r.commissioning_state !== 'DECOMMISSIONED') {
        results.push(this._mapRow(r));
      }
    }
    return results;
  }

  async removeFabric(matterDeviceId, fabricId) {
    const existing = await this.findByDeviceAndFabricId(matterDeviceId, fabricId);
    if (!existing) return null;

    const updated = {
      ...existing,
      commissioningState: 'DECOMMISSIONED',
      updatedAt: new Date().toISOString()
    };

    return this.addFabric(updated);
  }

  async clearAllFabricsForDevice(matterDeviceId) {
    const fabrics = await this.listByMatterDeviceId(matterDeviceId);
    const decommissioned = [];
    for (const f of fabrics) {
      const dec = await this.removeFabric(matterDeviceId, f.fabricId);
      if (dec) decommissioned.push(dec);
    }
    return decommissioned;
  }

  _mapRow(row) {
    if (!row) return null;
    return {
      id: row.id,
      fabricId: row.fabric_id || row.fabricId,
      matterDeviceId: row.matter_device_id || row.matterDeviceId,
      fabricIndex: row.fabric_index !== undefined ? row.fabric_index : row.fabricIndex,
      fabricName: row.fabric_name || row.fabricName,
      vendorId: row.vendor_id || row.vendorId,
      controllerNodeId: row.controller_node_id || row.controllerNodeId || null,
      commissioningState: row.commissioning_state || row.commissioningState,
      label: row.label || null,
      pairedAt: row.paired_at || row.pairedAt || null,
      lastSynchronizedAt: row.last_synchronized_at || row.lastSynchronizedAt || null,
      createdAt: row.created_at || row.createdAt,
      updatedAt: row.updated_at || row.updatedAt
    };
  }
}

module.exports = { MatterFabricRepository };
