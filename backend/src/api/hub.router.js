'use strict';

/**
 * EH Home — Cloud <-> Smart Hub API Router
 */

class HubApiRouter {
  constructor(hubGatewayService) {
    this.gateway = hubGatewayService;
  }

  async handle(method, pathname, body = {}, query = {}, user = null) {
    // GET /api/v1/hubs?homeId=...
    if (method === 'GET' && pathname === '/api/v1/hubs') {
      const hubs = this.gateway.listHubsForHome(query.homeId || null);
      return { status: 200, body: { success: true, hubs } };
    }

    // POST /api/v1/hubs/register
    if (method === 'POST' && pathname === '/api/v1/hubs/register') {
      try {
        const rec = this.gateway.registerHub({
          hubId: body.hubId,
          homeId: body.homeId,
          hostname: body.hostname,
          model: body.model,
          version: body.version,
          ipAddress: body.ipAddress,
          capabilities: body.capabilities,
          devicesCount: body.devicesCount,
        });
        return { status: 200, body: { success: true, hub: rec } };
      } catch (err) {
        return { status: 400, body: { success: false, error: { code: 'BAD_REQUEST', message: err.message } } };
      }
    }

    // POST /api/v1/hubs/:hubId/sync
    const syncMatch = pathname.match(/^\/api\/v1\/hubs\/([^/]+)\/sync$/);
    if (method === 'POST' && syncMatch) {
      const hubId = decodeURIComponent(syncMatch[1]);
      try {
        const result = await this.gateway.reconcileHubSync(hubId, body);
        return { status: 200, body: { success: true, ...result } };
      } catch (err) {
        return { status: 404, body: { success: false, error: { code: 'HUB_NOT_FOUND', message: err.message } } };
      }
    }

    // POST /api/v1/hubs/:hubId/commands (Queue remote command or automation delta to Hub)
    const cmdMatch = pathname.match(/^\/api\/v1\/hubs\/([^/]+)\/commands$/);
    if (method === 'POST' && cmdMatch) {
      const hubId = decodeURIComponent(cmdMatch[1]);
      try {
        const entry = this.gateway.enqueueDispatch(hubId, {
          type: body.type || 'COMMAND',
          payload: body.payload || body,
          actorUserId: user?.id || null,
        });
        return { status: 202, body: { success: true, dispatch: entry } };
      } catch (err) {
        return { status: 404, body: { success: false, error: { code: 'HUB_NOT_FOUND', message: err.message } } };
      }
    }

    // GET /api/v1/hubs/:hubId/logs (Reconciled offline execution logs)
    const logsMatch = pathname.match(/^\/api\/v1\/hubs\/([^/]+)\/logs$/);
    if (method === 'GET' && logsMatch) {
      const hubId = decodeURIComponent(logsMatch[1]);
      const logs = this.gateway.offlineAuditLogs.get(hubId) || [];
      return { status: 200, body: { success: true, logs } };
    }

    return null;
  }

  handleStream(req, res, hubId) {
    res.writeHead(200, {
      'Content-Type': 'text/event-stream',
      'Cache-Control': 'no-cache',
      Connection: 'keep-alive',
      'Access-Control-Allow-Origin': '*',
    });
    res.write(`event: hub.connected\ndata: ${JSON.stringify({ hubId, timestamp: new Date().toISOString() })}\n\n`);
    const unsubscribe = this.gateway.subscribeStream(hubId, res);
    const keepAlive = setInterval(() => {
      try { res.write(': keepalive\n\n'); } catch (_) {}
    }, 20000);
    if (typeof keepAlive.unref === 'function') keepAlive.unref();
    req.on('close', () => {
      clearInterval(keepAlive);
      unsubscribe();
    });
  }
}

module.exports = { HubApiRouter };
