/**
 * EH Home Smart Hub — Outbound Cloud <-> Hub Sync & Remote Relay Bridge
 *
 * Uses built-in Node http/https/fs only (zero external npm dependencies).
 * When cloudUrl + homeId are configured on the Hub:
 *  - Registers Hub with Cloud Backend
 *  - Reconciles device states, execution logs & energy telemetry every 30s
 *  - Subscribes to /api/v1/hubs/:hubId/stream (SSE) for instant remote commands,
 *    away-from-home routine/rule toggles, and OTA firmware pre-caching.
 */

const http = require('http');
const https = require('https');
const fs = require('fs');
const path = require('path');

class CloudHubBridge {
  constructor({ storage, firmwareDir, onCommand, onRoutineUpsert, onRoutineDelete, onRuleUpsert, onRuleDelete }) {
    this.storage = storage;
    this.firmwareDir = firmwareDir;
    this.onCommand = onCommand;
    this.onRoutineUpsert = onRoutineUpsert;
    this.onRoutineDelete = onRoutineDelete;
    this.onRuleUpsert = onRuleUpsert;
    this.onRuleDelete = onRuleDelete;
    this.syncTimer = null;
    this.streamReq = null;
    this.status = {
      configured: false,
      connected: false,
      lastSyncAt: null,
      lastError: null,
    };
  }

  getCloudUrl() {
    const fromMeta = this.storage.getMetadata('cloudUrl', '');
    return String(fromMeta || process.env.CLOUD_API_URL || '').trim().replace(/\/+$/, '');
  }

  start() {
    if (this.syncTimer) return;
    const cloudUrl = this.getCloudUrl();
    const homeId = this.storage.getMetadata('homeId', null);
    this.status.configured = Boolean(cloudUrl && homeId);
    if (!this.status.configured) return;

    this.syncNow().catch(() => {});
    this.connectStream();
    this.syncTimer = setInterval(() => {
      this.syncNow().catch(() => {});
    }, 30000);
    if (typeof this.syncTimer.unref === 'function') this.syncTimer.unref();
  }

  stop() {
    if (this.syncTimer) {
      clearInterval(this.syncTimer);
      this.syncTimer = null;
    }
    if (this.streamReq) {
      try { this.streamReq.destroy(); } catch (_) {}
      this.streamReq = null;
    }
  }

  async _httpJson(method, fullUrl, body = null) {
    return new Promise((resolve, reject) => {
      const u = new URL(fullUrl);
      const mod = u.protocol === 'https:' ? https : http;
      const postData = body ? JSON.stringify(body) : null;
      const secret = this.storage.getMetadata('cloudHubSecret', '');
      const req = mod.request({
        hostname: u.hostname,
        port: u.port || (u.protocol === 'https:' ? 443 : 80),
        path: `${u.pathname}${u.search}`,
        method,
        headers: {
          'Content-Type': 'application/json',
          ...(secret ? { Authorization: `Bearer ${secret}` } : {}),
          ...(postData ? { 'Content-Length': Buffer.byteLength(postData) } : {}),
        },
        timeout: 4000,
      }, (res) => {
        let data = '';
        res.on('data', c => data += c);
        res.on('end', () => {
          try {
            resolve({ statusCode: res.statusCode, body: JSON.parse(data || '{}') });
          } catch (_) {
            resolve({ statusCode: res.statusCode, body: {} });
          }
        });
      });
      req.on('timeout', () => { req.destroy(new Error('Cloud bridge timeout')); });
      req.on('error', reject);
      if (postData) req.write(postData);
      req.end();
    });
  }

  async syncNow() {
    const cloudUrl = this.getCloudUrl();
    const homeId = this.storage.getMetadata('homeId', null);
    this.status.configured = Boolean(cloudUrl && homeId);
    if (!this.status.configured) return { skipped: true };

    const hubId = this.storage.getMetadata('hubId', 'eh-hub-pi3b');
    try {
      await this._httpJson('POST', `${cloudUrl}/api/v1/hubs/register`, {
        hubId,
        homeId,
        hostname: this.storage.getMetadata('hostname', 'eh-hub.local'),
        model: this.storage.getMetadata('model', 'EH-HUB-V1-PI'),
        version: this.storage.getMetadata('version', '1.1.0-plan1-sqlite'),
        devicesCount: this.storage.getDevices().length,
      });

      const syncRes = await this._httpJson('POST', `${cloudUrl}/api/v1/hubs/${encodeURIComponent(hubId)}/sync`, {
        devices: this.storage.getDevices(),
        executionLogs: this.storage.getExecutionLogs(50),
      });

      this.status.connected = syncRes.statusCode === 200;
      this.status.lastSyncAt = new Date().toISOString();
      this.status.lastError = syncRes.statusCode === 200 ? null : `HTTP ${syncRes.statusCode}`;

      if (syncRes.body && Array.isArray(syncRes.body.dispatches)) {
        for (const d of syncRes.body.dispatches) {
          this._applyDispatch(d);
        }
      }
      if (syncRes.body && Array.isArray(syncRes.body.otaReleases)) {
        this._saveOtaReleaseManifest(syncRes.body.otaReleases);
      }
      return syncRes.body;
    } catch (err) {
      this.status.connected = false;
      this.status.lastError = err.message;
      return { error: err.message };
    }
  }

  _saveOtaReleaseManifest(releases) {
    if (!this.firmwareDir) return;
    try {
      if (!fs.existsSync(this.firmwareDir)) fs.mkdirSync(this.firmwareDir, { recursive: true });
      fs.writeFileSync(path.join(this.firmwareDir, 'releases.json'), JSON.stringify(releases, null, 2), 'utf8');
    } catch (_) {}
  }

  _applyDispatch(dispatch) {
    if (!dispatch || !dispatch.type) return;
    const p = dispatch.payload || {};
    if (dispatch.type === 'COMMAND' && this.onCommand) this.onCommand(p);
    else if (dispatch.type === 'ROUTINE_UPSERT' && this.onRoutineUpsert) this.onRoutineUpsert(p);
    else if (dispatch.type === 'ROUTINE_DELETE' && this.onRoutineDelete) this.onRoutineDelete(p);
    else if (dispatch.type === 'RULE_UPSERT' && this.onRuleUpsert) this.onRuleUpsert(p);
    else if (dispatch.type === 'RULE_DELETE' && this.onRuleDelete) this.onRuleDelete(p);
  }

  connectStream() {
    const cloudUrl = this.getCloudUrl();
    const hubId = this.storage.getMetadata('hubId', 'eh-hub-pi3b');
    if (!cloudUrl) return;
    try {
      const u = new URL(`${cloudUrl}/api/v1/hubs/${encodeURIComponent(hubId)}/stream`);
      const mod = u.protocol === 'https:' ? https : http;
      this.streamReq = mod.get(u.toString(), (res) => {
        let buf = '';
        res.on('data', (chunk) => {
          buf += chunk.toString('utf8');
          const frames = buf.split('\n\n');
          buf = frames.pop() || '';
          for (const frame of frames) {
            const dataLine = frame.split('\n').find(l => l.startsWith('data:'));
            if (dataLine && frame.includes('hub.dispatch')) {
              try {
                const parsed = JSON.parse(dataLine.slice(5).trim());
                this._applyDispatch(parsed);
              } catch (_) {}
            }
          }
        });
      });
      this.streamReq.on('error', () => {
        this.status.connected = false;
      });
    } catch (_) {}
  }
}

module.exports = { CloudHubBridge };
