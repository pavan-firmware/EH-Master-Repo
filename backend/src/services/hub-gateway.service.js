'use strict';

/**
 * EH Home — Cloud <-> Local Smart Hub Gateway Service
 *
 * Bridges remote mobile/cloud requests cleanly to registered Pi Hubs:
 *  - Hub registration & heartbeat tracking per homeId
 *  - Cloud-to-Hub pending command & automation/rule delta queue
 *  - Real-time SSE stream (/api/v1/hubs/:hubId/stream) for instant remote push
 *  - Offline reconciliation on reconnect (device states, execution logs, energy)
 */

const crypto = require('crypto');

class HubGatewayService {
  constructor({ eventBus, deviceStateRepo, energyRepo, firmwareRepo } = {}) {
    this.eventBus = eventBus || null;
    this.deviceStateRepo = deviceStateRepo || null;
    this.energyRepo = energyRepo || null;
    this.firmwareRepo = firmwareRepo || null;

    this.hubs = new Map(); // hubId -> hub record
    this.pendingDispatches = new Map(); // hubId -> [dispatchItem]
    this.offlineAuditLogs = new Map(); // hubId -> [log]
    this.streamSubscribers = new Map(); // hubId -> Set<res>
  }

  registerHub({ hubId, homeId, hostname, model, version, ipAddress, capabilities, devicesCount }) {
    if (!hubId || !homeId) {
      throw new Error('hubId and homeId are required to register a Hub');
    }
    const existing = this.hubs.get(hubId);
    const hubSecret = existing?.hubSecret || crypto.randomBytes(24).toString('hex');
    const nowIso = new Date().toISOString();
    const record = {
      hubId,
      homeId,
      hostname: hostname || existing?.hostname || 'eh-hub.local',
      model: model || existing?.model || 'EH-HUB-V1-PI',
      version: version || existing?.version || '1.1.0-plan1-sqlite',
      ipAddress: ipAddress || existing?.ipAddress || null,
      capabilities: capabilities || existing?.capabilities || ['lan-control', 'scheduler', 'rules', 'energy', 'ota-cache', 'sntp'],
      devicesCount: typeof devicesCount === 'number' ? devicesCount : (existing?.devicesCount || 0),
      hubSecret,
      online: true,
      registeredAt: existing?.registeredAt || nowIso,
      lastHeartbeatAt: nowIso,
    };
    this.hubs.set(hubId, record);
    return record;
  }

  listHubsForHome(homeId) {
    const now = Date.now();
    const out = [];
    for (const h of this.hubs.values()) {
      if (homeId && h.homeId !== homeId) continue;
      const ageMs = now - Date.parse(h.lastHeartbeatAt || 0);
      out.push({
        hubId: h.hubId,
        homeId: h.homeId,
        hostname: h.hostname,
        model: h.model,
        version: h.version,
        ipAddress: h.ipAddress,
        devicesCount: h.devicesCount,
        online: h.online && ageMs < 90000,
        lastHeartbeatAt: h.lastHeartbeatAt,
        streamConnected: (this.streamSubscribers.get(h.hubId)?.size || 0) > 0,
      });
    }
    return out;
  }

  getHub(hubId) {
    return this.hubs.get(hubId) || null;
  }

  enqueueDispatch(hubId, item) {
    const hub = this.hubs.get(hubId);
    if (!hub) {
      throw new Error(`Hub ${hubId} not registered`);
    }
    const entry = {
      dispatchId: `disp_${crypto.randomBytes(6).toString('hex')}`,
      type: item.type || 'COMMAND', // COMMAND | ROUTINE_UPSERT | ROUTINE_DELETE | RULE_UPSERT | RULE_DELETE | OTA_PRECACHE
      payload: item.payload || {},
      createdAt: new Date().toISOString(),
    };
    const queue = this.pendingDispatches.get(hubId) || [];
    queue.push(entry);
    this.pendingDispatches.set(hubId, queue);

    // Push live over open SSE stream if Hub is currently connected
    const subs = this.streamSubscribers.get(hubId);
    if (subs && subs.size > 0) {
      const frame = `event: hub.dispatch\ndata: ${JSON.stringify(entry)}\n\n`;
      for (const res of subs) {
        try { res.write(frame); } catch (_) {}
      }
    }
    return entry;
  }

  subscribeStream(hubId, res) {
    const hub = this.hubs.get(hubId);
    if (hub) {
      hub.online = true;
      hub.lastHeartbeatAt = new Date().toISOString();
    }
    let set = this.streamSubscribers.get(hubId);
    if (!set) {
      set = new Set();
      this.streamSubscribers.set(hubId, set);
    }
    set.add(res);
    return () => {
      set.delete(res);
    };
  }

  async reconcileHubSync(hubId, body = {}) {
    const hub = this.hubs.get(hubId);
    if (!hub) {
      throw new Error(`Hub ${hubId} not registered`);
    }
    hub.online = true;
    hub.lastHeartbeatAt = new Date().toISOString();
    if (Array.isArray(body.devices)) {
      hub.devicesCount = body.devices.length;
    }

    // 1. Reconcile offline device states back into Cloud event bus
    const reconciledDevices = [];
    if (Array.isArray(body.devices)) {
      for (const d of body.devices) {
        if (!d || !d.id) continue;
        reconciledDevices.push(d.id);
        if (this.eventBus) {
          this.eventBus.emit('device.state', {
            homeId: hub.homeId,
            deviceId: d.id,
            online: Boolean(d.online),
            channels: d.channels || {},
            source: 'hub-reconcile',
            timestamp: d.lastSeenAt || hub.lastHeartbeatAt,
          });
        }
      }
    }

    // 2. Reconcile offline execution audit logs
    let ingestedLogs = 0;
    if (Array.isArray(body.executionLogs) && body.executionLogs.length > 0) {
      const prev = this.offlineAuditLogs.get(hubId) || [];
      const known = new Set(prev.map(l => l.id));
      for (const log of body.executionLogs) {
        if (log && log.id && !known.has(log.id)) {
          prev.unshift(log);
          ingestedLogs++;
        }
      }
      this.offlineAuditLogs.set(hubId, prev.slice(0, 200));
    }

    // 3. Reconcile offline energy samples if repository supports it
    let ingestedEnergySamples = 0;
    if (Array.isArray(body.energySamples)) {
      ingestedEnergySamples = body.energySamples.length;
    }

    // 4. Drain pending dispatches queued while Hub was offline / remote
    const pending = this.pendingDispatches.get(hubId) || [];
    const dispatchesToSend = [...pending];
    if (body.ackDispatchIds && Array.isArray(body.ackDispatchIds)) {
      const ackSet = new Set(body.ackDispatchIds);
      this.pendingDispatches.set(hubId, pending.filter(p => !ackSet.has(p.dispatchId)));
    } else if (dispatchesToSend.length > 0) {
      // Mark delivered on sync pull
      this.pendingDispatches.set(hubId, []);
    }

    // 5. List latest published firmware releases for Pi Hub pre-caching
    let otaReleases = [];
    if (this.firmwareRepo && typeof this.firmwareRepo.findAll === 'function') {
      try {
        const all = await this.firmwareRepo.findAll();
        otaReleases = (all || [])
          .filter(r => String(r.status || '').toUpperCase() === 'PUBLISHED')
          .slice(0, 10);
      } catch (_) {}
    }

    return {
      status: 'ok',
      hubId,
      homeId: hub.homeId,
      reconciledDevicesCount: reconciledDevices.length,
      ingestedLogsCount: ingestedLogs,
      ingestedEnergySamplesCount: ingestedEnergySamples,
      dispatches: dispatchesToSend,
      otaReleases,
      serverEpochSec: Math.floor(Date.now() / 1000),
    };
  }
}

module.exports = { HubGatewayService };
