'use strict';

/**
 * EH Home — Phase 25 Reliability API Router
 *
 * 10 REST Endpoints:
 *   GET  /api/v1/reliability/homes/:homeId/fleet          — Fleet health summary
 *   GET  /api/v1/reliability/homes/:homeId/incidents      — All active incidents for home
 *   GET  /api/v1/reliability/devices/:deviceId/health     — Device health snapshot
 *   GET  /api/v1/reliability/devices/:deviceId/incidents  — Device incident history
 *   GET  /api/v1/reliability/incidents/:incidentId        — Single incident detail
 *   POST /api/v1/reliability/incidents/:incidentId/diagnose   — Diagnose an incident
 *   POST /api/v1/reliability/incidents/:incidentId/recover    — Initiate recovery
 *   POST /api/v1/reliability/recovery/:attemptId/verify       — Verify recovery outcome
 *   GET  /api/v1/reliability/devices/:deviceId/recovery-history — Recovery audit trail
 *   GET  /api/v1/reliability/homes/:homeId/maintenance    — Maintenance recommendations
 */

class ReliabilityApiRouter {
  constructor({ reliabilityService, homeAuthService }) {
    this.svc = reliabilityService;
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
      // ── Fleet Health ──────────────────────────────────────────────────────
      let m;

      m = path.match(/^\/api\/v1\/reliability\/homes\/([^/]+)\/fleet$/);
      if (m && method === 'GET') {
        const homeId = m[1];
        await this._authorizeHome(userId, homeId);
        const summary = await this.svc.getFleetHealth(homeId);
        return ok(summary);
      }

      // ── Active Incidents for Home ─────────────────────────────────────────
      m = path.match(/^\/api\/v1\/reliability\/homes\/([^/]+)\/incidents$/);
      if (m && method === 'GET') {
        const homeId = m[1];
        await this._authorizeHome(userId, homeId);
        const incidents = await this.svc.incidentRepo.findActiveForHome(homeId);
        return ok(incidents);
      }

      // ── Maintenance Recommendations for Home ──────────────────────────────
      m = path.match(/^\/api\/v1\/reliability\/homes\/([^/]+)\/maintenance$/);
      if (m && method === 'GET') {
        const homeId = m[1];
        await this._authorizeHome(userId, homeId);
        const recs = await this.svc.getMaintenanceRecommendationsForHome(homeId, { status: query.status });
        return ok(recs);
      }

      // ── Device Health Snapshot ────────────────────────────────────────────
      m = path.match(/^\/api\/v1\/reliability\/devices\/([^/]+)\/health$/);
      if (m && method === 'GET') {
        const deviceId = m[1];
        const homeId = await this._homeIdForDevice(deviceId);
        await this._authorizeHome(userId, homeId);
        const snapshot = await this.svc.snapshotDeviceHealth(deviceId, homeId);
        return ok(snapshot);
      }

      // ── Device Incident History ───────────────────────────────────────────
      m = path.match(/^\/api\/v1\/reliability\/devices\/([^/]+)\/incidents$/);
      if (m && method === 'GET') {
        const deviceId = m[1];
        const homeId = await this._homeIdForDevice(deviceId);
        await this._authorizeHome(userId, homeId);
        const incidents = await this.svc.getIncidentsForDevice(deviceId, {
          status: query.status,
          limit: parseInt(query.limit) || 20
        });
        return ok(incidents);
      }

      // ── Device Recovery History ───────────────────────────────────────────
      m = path.match(/^\/api\/v1\/reliability\/devices\/([^/]+)\/recovery-history$/);
      if (m && method === 'GET') {
        const deviceId = m[1];
        const homeId = await this._homeIdForDevice(deviceId);
        await this._authorizeHome(userId, homeId);
        const history = await this.svc.getRecoveryHistoryForDevice(deviceId, {
          limit: parseInt(query.limit) || 20
        });
        return ok(history);
      }

      // ── Single Incident ───────────────────────────────────────────────────
      m = path.match(/^\/api\/v1\/reliability\/incidents\/([^/]+)$/);
      if (m && method === 'GET') {
        const incidentId = m[1];
        const incident = await this.svc.incidentRepo.findById(incidentId);
        if (!incident) return err('NOT_FOUND', 'Incident not found', 404);
        await this._authorizeHome(userId, incident.home_id);
        return ok(incident);
      }

      // ── Diagnose Incident ─────────────────────────────────────────────────
      m = path.match(/^\/api\/v1\/reliability\/incidents\/([^/]+)\/diagnose$/);
      if (m && method === 'POST') {
        const incidentId = m[1];
        const incident = await this.svc.incidentRepo.findById(incidentId);
        if (!incident) return err('NOT_FOUND', 'Incident not found', 404);
        await this._authorizeHome(userId, incident.home_id);
        const diagnosis = await this.svc.diagnoseIncident(incidentId);
        return ok(diagnosis, 201);
      }

      // ── Initiate Recovery ─────────────────────────────────────────────────
      m = path.match(/^\/api\/v1\/reliability\/incidents\/([^/]+)\/recover$/);
      if (m && method === 'POST') {
        const incidentId = m[1];
        const incident = await this.svc.incidentRepo.findById(incidentId);
        if (!incident) return err('NOT_FOUND', 'Incident not found', 404);
        await this._authorizeHome(userId, incident.home_id);
        const { actionType } = body;
        if (!actionType) return err('VALIDATION_ERROR', 'actionType is required');
        const result = await this.svc.initiateRecovery(incidentId, actionType, actorContext);
        return ok(result, 201);
      }

      // ── Verify Recovery ───────────────────────────────────────────────────
      m = path.match(/^\/api\/v1\/reliability\/recovery\/([^/]+)\/verify$/);
      if (m && method === 'POST') {
        const attemptId = m[1];
        const attempt = await this.svc.recoveryRepo.findById(attemptId);
        if (!attempt) return err('NOT_FOUND', 'Recovery attempt not found', 404);
        await this._authorizeHome(userId, attempt.home_id);
        const result = await this.svc.verifyRecovery(attemptId);
        return ok(result);
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
    const device = this.svc.deviceRepo ? await this.svc.deviceRepo.findById(deviceId) : null;
    if (!device) throw Object.assign(new Error('Device not found'), { statusCode: 404 });
    return device.home_id || device.homeId;
  }
}

module.exports = { ReliabilityApiRouter };
