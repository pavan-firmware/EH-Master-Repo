'use strict';

const url = require('url');

/**
 * EH Home — Phase 24 Unified Home Intelligence & Decision REST API Router
 */

class IntelligenceApiRouter {
  /**
   * @param {Object} opts
   * @param {Object} opts.intelligenceService - IntelligenceService instance
   * @param {Object} opts.homeAuthService     - HomeAuthorizationService instance
   */
  constructor({ intelligenceService, homeAuthService }) {
    this.intelService = intelligenceService;
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

    // 1. GET /api/v1/intelligence/homes/:homeId/summary
    const matchSummary = path.match(/^\/api\/v1\/intelligence\/homes\/([a-zA-Z0-9_-]+)\/summary$/);
    if (method === 'GET' && matchSummary) {
      const homeId = matchSummary[1];
      const auth = await this.homeAuth.authorizeRequest({ userId, homeId });
      if (!auth.isAuthorized) {
        return { statusCode: auth.statusCode || 403, body: { success: false, error: auth.message || 'Forbidden' } };
      }

      const summary = await this.intelService.getIntelligenceSummary(homeId);
      return { statusCode: 200, body: { success: true, data: summary } };
    }

    // 2. GET /api/v1/intelligence/homes/:homeId/recommendations
    const matchRecs = path.match(/^\/api\/v1\/intelligence\/homes\/([a-zA-Z0-9_-]+)\/recommendations$/);
    if (method === 'GET' && matchRecs) {
      const homeId = matchRecs[1];
      const auth = await this.homeAuth.authorizeRequest({ userId, homeId });
      if (!auth.isAuthorized) {
        return { statusCode: auth.statusCode || 403, body: { success: false, error: auth.message || 'Forbidden' } };
      }

      const limit = parseInt(query.limit, 10) || 50;
      const status = query.status || null;
      const type = query.type || null;
      const recs = await this.intelService.recommendationRepo.getRecommendationsByHome(homeId, { limit, status, type });
      return { statusCode: 200, body: { success: true, data: recs, count: recs.length } };
    }

    // 3. GET /api/v1/intelligence/homes/:homeId/decisions
    const matchDecisions = path.match(/^\/api\/v1\/intelligence\/homes\/([a-zA-Z0-9_-]+)\/decisions$/);
    if (method === 'GET' && matchDecisions) {
      const homeId = matchDecisions[1];
      const auth = await this.homeAuth.authorizeRequest({ userId, homeId });
      if (!auth.isAuthorized) {
        return { statusCode: auth.statusCode || 403, body: { success: false, error: auth.message || 'Forbidden' } };
      }

      const limit = parseInt(query.limit, 10) || 50;
      const status = query.status || null;
      const priority = query.priority || null;
      const decs = await this.intelService.decisionRepo.getDecisionsByHome(homeId, { limit, status, priority });
      return { statusCode: 200, body: { success: true, data: decs, count: decs.length } };
    }

    // 4. GET /api/v1/intelligence/homes/:homeId/decisions/:id
    const matchDecisionDetail = path.match(/^\/api\/v1\/intelligence\/homes\/([a-zA-Z0-9_-]+)\/decisions\/([a-zA-Z0-9_-]+)$/);
    if (method === 'GET' && matchDecisionDetail) {
      const homeId = matchDecisionDetail[1];
      const decisionId = matchDecisionDetail[2];
      const auth = await this.homeAuth.authorizeRequest({ userId, homeId });
      if (!auth.isAuthorized) {
        return { statusCode: auth.statusCode || 403, body: { success: false, error: auth.message || 'Forbidden' } };
      }

      const dec = await this.intelService.decisionRepo.getDecisionById(decisionId);
      if (!dec || dec.home_id !== homeId) {
        return { statusCode: 404, body: { success: false, error: 'Decision not found' } };
      }

      const outcome = await this.intelService.outcomeRepo.getOutcomeByDecisionId(decisionId);
      return { statusCode: 200, body: { success: true, data: { decision: dec, outcome } } };
    }

    // 5. POST /api/v1/intelligence/homes/:homeId/recommendations/:id/accept
    const matchAcceptRec = path.match(/^\/api\/v1\/intelligence\/homes\/([a-zA-Z0-9_-]+)\/recommendations\/([a-zA-Z0-9_-]+)\/accept$/);
    if (method === 'POST' && matchAcceptRec) {
      const homeId = matchAcceptRec[1];
      const recId = matchAcceptRec[2];
      const auth = await this.homeAuth.authorizeRequest({ userId, homeId });
      if (!auth.isAuthorized) {
        return { statusCode: auth.statusCode || 403, body: { success: false, error: auth.message || 'Forbidden' } };
      }

      try {
        const result = await this.intelService.acceptRecommendation(homeId, recId, { userId });
        return { statusCode: 200, body: { success: true, data: result } };
      } catch (err) {
        return { statusCode: 400, body: { success: false, error: err.message } };
      }
    }

    // 6. POST /api/v1/intelligence/homes/:homeId/recommendations/:id/reject
    const matchRejectRec = path.match(/^\/api\/v1\/intelligence\/homes\/([a-zA-Z0-9_-]+)\/recommendations\/([a-zA-Z0-9_-]+)\/reject$/);
    if (method === 'POST' && matchRejectRec) {
      const homeId = matchRejectRec[1];
      const recId = matchRejectRec[2];
      const auth = await this.homeAuth.authorizeRequest({ userId, homeId });
      if (!auth.isAuthorized) {
        return { statusCode: auth.statusCode || 403, body: { success: false, error: auth.message || 'Forbidden' } };
      }

      try {
        const result = await this.intelService.rejectRecommendation(homeId, recId, body.reason || '', { userId });
        return { statusCode: 200, body: { success: true, data: result } };
      } catch (err) {
        return { statusCode: 400, body: { success: false, error: err.message } };
      }
    }

    // 7. POST /api/v1/intelligence/homes/:homeId/decisions/:id/execute
    const matchExecuteDec = path.match(/^\/api\/v1\/intelligence\/homes\/([a-zA-Z0-9_-]+)\/decisions\/([a-zA-Z0-9_-]+)\/execute$/);
    if (method === 'POST' && matchExecuteDec) {
      const homeId = matchExecuteDec[1];
      const decId = matchExecuteDec[2];
      const auth = await this.homeAuth.authorizeRequest({ userId, homeId });
      if (!auth.isAuthorized) {
        return { statusCode: auth.statusCode || 403, body: { success: false, error: auth.message || 'Forbidden' } };
      }

      try {
        const result = await this.intelService.executeDecision(homeId, decId, { userId });
        return { statusCode: 200, body: { success: true, data: result } };
      } catch (err) {
        return { statusCode: 400, body: { success: false, error: err.message } };
      }
    }

    // 8. POST /api/v1/intelligence/homes/:homeId/evaluate
    const matchEvaluate = path.match(/^\/api\/v1\/intelligence\/homes\/([a-zA-Z0-9_-]+)\/evaluate$/);
    if (method === 'POST' && matchEvaluate) {
      const homeId = matchEvaluate[1];
      const auth = await this.homeAuth.authorizeRequest({ userId, homeId });
      if (!auth.isAuthorized) {
        return { statusCode: auth.statusCode || 403, body: { success: false, error: auth.message || 'Forbidden' } };
      }

      const result = await this.intelService.evaluateDecisions(homeId);
      return { statusCode: 200, body: { success: true, data: result } };
    }

    // 9. POST /api/v1/intelligence/homes/:homeId/auto-execute
    const matchAutoExecute = path.match(/^\/api\/v1\/intelligence\/homes\/([a-zA-Z0-9_-]+)\/auto-execute$/);
    if (method === 'POST' && matchAutoExecute) {
      const homeId = matchAutoExecute[1];
      const auth = await this.homeAuth.authorizeRequest({ userId, homeId });
      if (!auth.isAuthorized) {
        return { statusCode: auth.statusCode || 403, body: { success: false, error: auth.message || 'Forbidden' } };
      }

      const result = await this.intelService.autoExecuteSafeDecisions(homeId, { userId });
      return { statusCode: 200, body: { success: true, data: result } };
    }

    // 10. GET /api/v1/intelligence/homes/:homeId/history
    const matchHistory = path.match(/^\/api\/v1\/intelligence\/homes\/([a-zA-Z0-9_-]+)\/history$/);
    if (method === 'GET' && matchHistory) {
      const homeId = matchHistory[1];
      const auth = await this.homeAuth.authorizeRequest({ userId, homeId });
      if (!auth.isAuthorized) {
        return { statusCode: auth.statusCode || 403, body: { success: false, error: auth.message || 'Forbidden' } };
      }

      const limit = parseInt(query.limit, 10) || 50;
      const outcomes = await this.intelService.outcomeRepo.getOutcomesByHome(homeId, { limit });
      return { statusCode: 200, body: { success: true, data: outcomes, count: outcomes.length } };
    }

    return { statusCode: 404, body: { success: false, error: 'Route not found' } };
  }
}

module.exports = { IntelligenceApiRouter };
