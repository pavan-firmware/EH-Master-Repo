'use strict';

const url = require('url');

/**
 * EH Home — Context & Presence REST API Router (Phase 23)
 */

class ContextApiRouter {
  /**
   * @param {Object} opts
   * @param {Object} opts.contextService   - ContextService instance
   * @param {Object} opts.homeAuthService  - HomeAuthorizationService instance
   */
  constructor({ contextService, homeAuthService }) {
    this.contextService = contextService;
    this.homeAuth = homeAuthService;
  }

  async handleRequest(req, actorContext) {
    const method = req.method;
    let path = req.path;
    let query = req.query || {};
    const body = req.body || {};

    if (req.url) {
      const parsed = url.parse(req.url, true);
      path = parsed.pathname;
      query = { ...parsed.query, ...query };
    }

    const userId = (actorContext && actorContext.userId) || req.userId || (req.user && req.user.id) || null;

    if (!userId) {
      return { statusCode: 401, body: { success: false, error: 'Unauthorized: missing authentication token' } };
    }

    // 1. GET /api/v1/context/homes/:homeId/presence (Presence Snapshot)
    const matchPresence = path.match(/^\/api\/v1\/context\/homes\/([a-zA-Z0-9_-]+)\/presence$/);
    if (method === 'GET' && matchPresence) {
      const homeId = matchPresence[1];
      const auth = await this.homeAuth.authorizeRequest({ userId, homeId });
      if (!auth.isAuthorized) {
        return { statusCode: auth.statusCode || 403, body: { success: false, error: auth.message || 'Forbidden' } };
      }

      const snapshot = await this.contextService.getPresenceSnapshot(homeId);
      return { statusCode: 200, body: { success: true, data: snapshot } };
    }

    // 2. POST /api/v1/context/homes/:homeId/presence (Submit Presence Signal)
    if (method === 'POST' && matchPresence) {
      const homeId = matchPresence[1];
      const auth = await this.homeAuth.authorizeRequest({ userId, homeId });
      if (!auth.isAuthorized) {
        return { statusCode: auth.statusCode || 403, body: { success: false, error: auth.message || 'Forbidden' } };
      }

      const targetUserId = body.userId || userId;
      const result = await this.contextService.recordPresenceSignal({
        userId: targetUserId,
        homeId,
        source: body.source || 'mobile_app',
        state: body.state || 'HOME',
        confidence: body.confidence !== undefined ? body.confidence : 1.0,
        evidence: body.evidence || {},
        observedAt: body.observedAt || null,
        expiresAt: body.expiresAt || null
      });

      return { statusCode: 201, body: { success: true, data: result } };
    }

    // 3. GET /api/v1/context/homes/:homeId/context (Get Current Home Context)
    const matchContext = path.match(/^\/api\/v1\/context\/homes\/([a-zA-Z0-9_-]+)\/context$/);
    if (method === 'GET' && matchContext) {
      const homeId = matchContext[1];
      const auth = await this.homeAuth.authorizeRequest({ userId, homeId });
      if (!auth.isAuthorized) {
        return { statusCode: auth.statusCode || 403, body: { success: false, error: auth.message || 'Forbidden' } };
      }

      const context = await this.contextService.evaluateHomeContext(homeId);
      return { statusCode: 200, body: { success: true, data: context } };
    }

    // 4. POST /api/v1/context/homes/:homeId/override (Set Manual Override)
    const matchOverride = path.match(/^\/api\/v1\/context\/homes\/([a-zA-Z0-9_-]+)\/override$/);
    if (method === 'POST' && matchOverride) {
      const homeId = matchOverride[1];
      const auth = await this.homeAuth.authorizeRequest({ userId, homeId });
      if (!auth.isAuthorized) {
        return { statusCode: auth.statusCode || 403, body: { success: false, error: auth.message || 'Forbidden' } };
      }

      if (!body.mode) {
        return { statusCode: 400, body: { success: false, error: 'mode is required' } };
      }

      const result = await this.contextService.setContextOverride({
        homeId,
        userId,
        mode: body.mode,
        reason: body.reason || '',
        durationHours: body.durationHours || null
      });

      return { statusCode: 200, body: { success: true, data: result } };
    }

    // 5. DELETE /api/v1/context/homes/:homeId/override (Clear Manual Override)
    if (method === 'DELETE' && matchOverride) {
      const homeId = matchOverride[1];
      const auth = await this.homeAuth.authorizeRequest({ userId, homeId });
      if (!auth.isAuthorized) {
        return { statusCode: auth.statusCode || 403, body: { success: false, error: auth.message || 'Forbidden' } };
      }

      const result = await this.contextService.clearContextOverride(homeId, userId);
      return { statusCode: 200, body: { success: true, data: result } };
    }

    // 6. GET /api/v1/context/homes/:homeId/transitions (Transition History)
    const matchTransitions = path.match(/^\/api\/v1\/context\/homes\/([a-zA-Z0-9_-]+)\/transitions$/);
    if (method === 'GET' && matchTransitions) {
      const homeId = matchTransitions[1];
      const auth = await this.homeAuth.authorizeRequest({ userId, homeId });
      if (!auth.isAuthorized) {
        return { statusCode: auth.statusCode || 403, body: { success: false, error: auth.message || 'Forbidden' } };
      }

      const limit = parseInt(query.limit, 10) || 50;
      const from = query.from || null;
      const transitions = await this.contextService.transitionRepo.getTransitionsByHome(homeId, { limit, from });
      return { statusCode: 200, body: { success: true, data: transitions, count: transitions.length } };
    }

    // 7. GET /api/v1/context/homes/:homeId/signals (Signals History)
    const matchSignals = path.match(/^\/api\/v1\/context\/homes\/([a-zA-Z0-9_-]+)\/signals$/);
    if (method === 'GET' && matchSignals) {
      const homeId = matchSignals[1];
      const auth = await this.homeAuth.authorizeRequest({ userId, homeId });
      if (!auth.isAuthorized) {
        return { statusCode: auth.statusCode || 403, body: { success: false, error: auth.message || 'Forbidden' } };
      }

      const limit = parseInt(query.limit, 10) || 50;
      const targetUserId = query.userId || null;
      const signals = await this.contextService.signalRepo.getSignalsByHome(homeId, { limit, userId: targetUserId });
      return { statusCode: 200, body: { success: true, data: signals, count: signals.length } };
    }

    // 8. POST /api/v1/context/homes/:homeId/mode (Quick Set Mode)
    const matchMode = path.match(/^\/api\/v1\/context\/homes\/([a-zA-Z0-9_-]+)\/mode$/);
    if (method === 'POST' && matchMode) {
      const homeId = matchMode[1];
      const auth = await this.homeAuth.authorizeRequest({ userId, homeId });
      if (!auth.isAuthorized) {
        return { statusCode: auth.statusCode || 403, body: { success: false, error: auth.message || 'Forbidden' } };
      }

      if (!body.mode) {
        return { statusCode: 400, body: { success: false, error: 'mode is required' } };
      }

      const result = await this.contextService.setContextOverride({
        homeId,
        userId,
        mode: body.mode,
        reason: body.reason || 'Quick mode switch',
        durationHours: body.durationHours || null
      });

      return { statusCode: 200, body: { success: true, data: result } };
    }

    // 9. POST /api/v1/context/homes/:homeId/vacation (Set Vacation Mode)
    const matchVacation = path.match(/^\/api\/v1\/context\/homes\/([a-zA-Z0-9_-]+)\/vacation$/);
    if (method === 'POST' && matchVacation) {
      const homeId = matchVacation[1];
      const auth = await this.homeAuth.authorizeRequest({ userId, homeId });
      if (!auth.isAuthorized) {
        return { statusCode: auth.statusCode || 403, body: { success: false, error: auth.message || 'Forbidden' } };
      }

      const result = await this.contextService.setContextOverride({
        homeId,
        userId,
        mode: 'VACATION',
        reason: body.reason || 'Vacation Mode Enabled',
        durationHours: body.durationDays ? body.durationDays * 24 : (body.durationHours || 168)
      });

      return { statusCode: 200, body: { success: true, data: result } };
    }

    return { statusCode: 404, body: { success: false, error: 'Route not found' } };
  }
}

module.exports = { ContextApiRouter };
