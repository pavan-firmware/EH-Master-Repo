'use strict';

/**
 * EH Home — Phase 26 Multi-Protocol Connectivity API Router
 *
 * REST Endpoints:
 *   GET  /api/v1/connectivity/homes/:homeId/devices         — Fleet connectivity status
 *   GET  /api/v1/connectivity/devices/:deviceId             — Device connection snapshot
 *   GET  /api/v1/connectivity/devices/:deviceId/transports  — Device transport list
 *   GET  /api/v1/connectivity/devices/:deviceId/health      — Transport health snapshot
 *   GET  /api/v1/connectivity/devices/:deviceId/commissioning — Device commissioning history
 *   POST /api/v1/connectivity/devices/:deviceId/reconnect   — Trigger device reconnect
 *   POST /api/v1/connectivity/devices/:deviceId/select-transport — Manual transport selection
 *   GET  /api/v1/connectivity/discovery                     — Protocol-neutral discovery scan
 *   POST /api/v1/connectivity/commissioning/start           — Start commissioning session
 *   POST /api/v1/connectivity/commissioning/cancel          — Cancel commissioning session
 */

class ConnectivityApiRouter {
  constructor({ connectivityService, homeAuthService }) {
    this.svc = connectivityService;
    this.homeAuthService = homeAuthService;
  }

  async handleRequest({ method, path, query = {}, body = {} }, actorContext = {}) {
    const ok = (data, statusCode = 200) => ({
      statusCode,
      body: { success: true, data, timestamp: new Date().toISOString() }
    });
    const err = (code, message, statusCode = 400) => ({
      statusCode,
      body: { success: false, error: { code, message }, timestamp: new Date().toISOString() }
    });

    const userId = actorContext && actorContext.userId;

    try {
      let m;

      // ── 1. Fleet Connectivity for Home ────────────────────────────────────
      m = path.match(/^\/api\/v1\/connectivity\/homes\/([^/]+)\/devices$/);
      if (m && method === 'GET') {
        const homeId = m[1];
        await this._authorizeHome(userId, homeId);
        const fleet = await this.svc.getHomeFleetConnectivity(homeId);
        return ok(fleet);
      }

      // ── 2. Device Transports List ─────────────────────────────────────────
      m = path.match(/^\/api\/v1\/connectivity\/devices\/([^/]+)\/transports$/);
      if (m && method === 'GET') {
        const deviceId = m[1];
        const homeId = await this._homeIdForDevice(deviceId);
        await this._authorizeHome(userId, homeId);
        const transports = this.svc.transportRepo
          ? await this.svc.transportRepo.findByDevice(deviceId)
          : [];
        return ok(transports);
      }

      // ── 3. Device Transport Health ────────────────────────────────────────
      m = path.match(/^\/api\/v1\/connectivity\/devices\/([^/]+)\/health$/);
      if (m && method === 'GET') {
        const deviceId = m[1];
        const homeId = await this._homeIdForDevice(deviceId);
        await this._authorizeHome(userId, homeId);
        const snapshot = await this.svc.getDeviceConnectionSnapshot(deviceId, homeId);
        return ok(snapshot.transportHealth);
      }

      // ── 4. Device Commissioning History ───────────────────────────────────
      m = path.match(/^\/api\/v1\/connectivity\/devices\/([^/]+)\/commissioning$/);
      if (m && method === 'GET') {
        const deviceId = m[1];
        const homeId = await this._homeIdForDevice(deviceId);
        await this._authorizeHome(userId, homeId);
        const sessions = this.svc.commissioningRepo
          ? await this.svc.commissioningRepo.findByDevice(deviceId)
          : [];
        return ok(sessions);
      }

      // ── 5. Trigger Reconnect ──────────────────────────────────────────────
      m = path.match(/^\/api\/v1\/connectivity\/devices\/([^/]+)\/reconnect$/);
      if (m && method === 'POST') {
        const deviceId = m[1];
        const homeId = await this._homeIdForDevice(deviceId);
        await this._authorizeHome(userId, homeId);
        const transportType = body.transportType || 'WIFI_MQTT';
        const result = await this.svc.updateConnectionState(deviceId, homeId, transportType, 'RECONNECTING');
        return ok(result);
      }

      // ── 6. Select Transport ───────────────────────────────────────────────
      m = path.match(/^\/api\/v1\/connectivity\/devices\/([^/]+)\/select-transport$/);
      if (m && method === 'POST') {
        const deviceId = m[1];
        const homeId = await this._homeIdForDevice(deviceId);
        await this._authorizeHome(userId, homeId);
        const { transportType } = body;
        if (!transportType) return err('VALIDATION_ERROR', 'transportType is required');
        const result = await this.svc.updateConnectionState(deviceId, homeId, transportType, 'CONNECTED');
        return ok(result);
      }

      // ── 7. Single Device Connection Snapshot ──────────────────────────────
      m = path.match(/^\/api\/v1\/connectivity\/devices\/([^/]+)$/);
      if (m && method === 'GET') {
        const deviceId = m[1];
        const homeId = await this._homeIdForDevice(deviceId);
        await this._authorizeHome(userId, homeId);
        const snapshot = await this.svc.getDeviceConnectionSnapshot(deviceId, homeId);
        return ok(snapshot);
      }

      // ── 8. Protocol-Neutral Discovery ─────────────────────────────────────
      if (path === '/api/v1/connectivity/discovery' && method === 'GET') {
        const results = await this.svc.discoverDevices(query.protocol);
        return ok(results);
      }

      // ── 9. Start Commissioning ────────────────────────────────────────────
      if (path === '/api/v1/connectivity/commissioning/start' && method === 'POST') {
        const { homeId, deviceId, transportType, authMethod } = body;
        if (!homeId || !deviceId || !transportType) {
          return err('VALIDATION_ERROR', 'homeId, deviceId, and transportType are required');
        }
        await this._authorizeHome(userId, homeId);
        const session = await this.svc.startCommissioning(homeId, deviceId, transportType, authMethod);
        return ok(session, 201);
      }

      // ── 10. Cancel Commissioning ──────────────────────────────────────────
      if (path === '/api/v1/connectivity/commissioning/cancel' && method === 'POST') {
        const { sessionId, errorDetails } = body;
        if (!sessionId) return err('VALIDATION_ERROR', 'sessionId is required');
        const session = this.svc.commissioningRepo ? await this.svc.commissioningRepo.findById(sessionId) : null;
        if (!session) return err('NOT_FOUND', 'Commissioning session not found', 404);
        await this._authorizeHome(userId, session.home_id);
        const updated = await this.svc.updateCommissioningStage(sessionId, 'CANCELLED', errorDetails);
        return ok(updated);
      }

      return err('NOT_FOUND', `Route ${method} ${path} not found`, 404);
    } catch (e) {
      if (e.statusCode === 403) return err('FORBIDDEN', e.message, 403);
      if (e.statusCode === 404) return err('NOT_FOUND', e.message, 404);
      if (e.statusCode === 409) return err('CONFLICT', e.message, 409);
      if (e.statusCode === 429) return err('RATE_LIMITED', e.message, 429);
      return err('INTERNAL_ERROR', e.message || 'Internal server error', 500);
    }
  }

  async _authorizeHome(userId, homeId) {
    if (!userId || !homeId) return;
    const result = await this.homeAuthService.authorizeRequest({ userId, homeId });
    if (!result.isAuthorized) {
      const e = new Error(result.message || 'Forbidden');
      e.statusCode = 403;
      throw e;
    }
  }

  async _homeIdForDevice(deviceId) {
    if (this.svc.deviceRepo) {
      try {
        const device = await this.svc.deviceRepo.findById(deviceId);
        if (device) return device.home_id || device.homeId;
      } catch (_) {}
    }
    if (this.svc.connectionStateRepo) {
      try {
        const state = await this.svc.connectionStateRepo.findByDeviceId(deviceId);
        if (state) return state.home_id;
      } catch (_) {}
    }
    if (this.svc.transportRepo) {
      try {
        const transports = await this.svc.transportRepo.findByDevice(deviceId);
        if (transports && transports.length > 0) return transports[0].home_id;
      } catch (_) {}
    }
    return 'home_default';
  }
}

module.exports = { ConnectivityApiRouter };
