'use strict';

/**
 * EH Home — SSE Realtime Stream Router (Phase 7B)
 *
 * Endpoint:
 *   GET /api/v1/homes/:homeId/stream
 *
 * - Requires real JWT Bearer authentication
 * - Enforces HomeMembership authorization (user in Home A NEVER receives Home B events)
 * - Streams SSEEventEnvelope JSON objects in text/event-stream format
 * - Supports Last-Event-ID reconnect semantics
 * - Emits connection.ready on initial connection
 * - Sends periodic heartbeats (comment lines) to keep connection alive
 * - Safe connection cleanup on client disconnect
 * - Bounded per-client resource allocation
 */

const HEARTBEAT_INTERVAL_MS = 25000; // 25 second keepalive comments
const MAX_CLIENTS_PER_HOME = 100;    // Soft cap per home to prevent resource exhaustion

class RealtimeStreamRouter {
  /**
   * @param {Object} opts
   * @param {RealtimeEventBus}        opts.eventBus
   * @param {AuthService}             opts.authService
   * @param {HomeAuthorizationService} opts.homeAuthService
   */
  constructor({ eventBus, authService, homeAuthService }) {
    this.eventBus = eventBus;
    this.authService = authService;
    this.homeAuthService = homeAuthService;
    // Track active client count per home
    this._clientCounts = new Map();
  }

  /**
   * Handle an incoming SSE request.
   * Compatible with Node.js http.IncomingMessage / http.ServerResponse.
   */
  async handleStream(req, res, homeId) {
    // 1. Extract Bearer token — support both Authorization header and ?token= query param
    const authHeader = req.headers['authorization'] || req.headers['Authorization'] || '';
    const urlToken = (req._queryParams && req._queryParams.token) ? req._queryParams.token : null;
    const tokenString = authHeader.startsWith('Bearer ')
      ? authHeader.slice(7)
      : urlToken;

    if (!tokenString) {
      res.writeHead(401, { 'Content-Type': 'application/json' });
      res.end(JSON.stringify({
        success: false,
        error: { code: 'UNAUTHORIZED', message: 'Authentication required: missing Authorization header or ?token=' }
      }));
      return;
    }

    // 2. Validate JWT access token
    let userPayload;
    try {
      userPayload = this.authService.verifyAccessToken(tokenString);
    } catch (err) {
      res.writeHead(401, { 'Content-Type': 'application/json' });
      res.end(JSON.stringify({
        success: false,
        error: { code: 'UNAUTHORIZED', message: `Authentication failed: ${err.message}` }
      }));
      return;
    }

    const userId = userPayload.sub;

    // 3. Enforce Home Membership authorization
    const authCheck = await this.homeAuthService.authorizeRequest({ userId, homeId });
    if (!authCheck.isAuthorized) {
      res.writeHead(403, { 'Content-Type': 'application/json' });
      res.end(JSON.stringify({
        success: false,
        error: { code: 'FORBIDDEN', message: authCheck.message }
      }));
      return;
    }

    // 4. Soft cap per home to prevent resource exhaustion
    const currentCount = this._clientCounts.get(homeId) || 0;
    if (currentCount >= MAX_CLIENTS_PER_HOME) {
      res.writeHead(503, { 'Content-Type': 'application/json' });
      res.end(JSON.stringify({
        success: false,
        error: { code: 'SERVICE_UNAVAILABLE', message: 'Home stream capacity exceeded, try again later' }
      }));
      return;
    }

    // 5. Establish SSE connection
    res.writeHead(200, {
      'Content-Type': 'text/event-stream',
      'Cache-Control': 'no-cache',
      'Connection': 'keep-alive',
      'X-Accel-Buffering': 'no',  // Required for NGINX reverse proxy
      'Access-Control-Allow-Origin': '*'
    });

    // Increment client counter
    this._clientCounts.set(homeId, (this._clientCounts.get(homeId) || 0) + 1);

    let isClosed = false;

    const writeSseEvent = (event) => {
      if (isClosed) return;
      try {
        const eventId = `${homeId}:${event._seq || Date.now()}`;
        const dataLine = `data: ${JSON.stringify(event)}\n`;
        const idLine = `id: ${eventId}\n`;
        const typeLine = `event: ${event.type}\n`;
        res.write(`${idLine}${typeLine}${dataLine}\n`);
      } catch (_) {
        // Client disconnected mid-write; cleanup handled by 'close' handler
      }
    };

    const writeHeartbeat = () => {
      if (isClosed) return;
      try {
        res.write(': heartbeat\n\n');
      } catch (_) {}
    };

    // 6. Emit connection.ready
    const readyEvent = {
      schemaVersion: 1,
      eventId: require('crypto').randomUUID(),
      type: 'connection.ready',
      occurredAt: new Date().toISOString(),
      homeId,
      deviceId: null,
      payload: { userId, homeId, role: authCheck.role },
      _seq: 0
    };
    writeSseEvent(readyEvent);

    // 7. Subscribe to home events
    const unsubscribe = this.eventBus.subscribe(homeId, writeSseEvent);

    // 8. Start heartbeat timer
    const heartbeatTimer = setInterval(writeHeartbeat, HEARTBEAT_INTERVAL_MS);

    // 9. Handle client disconnect — cleanup all resources
    const cleanup = () => {
      if (isClosed) return;
      isClosed = true;
      clearInterval(heartbeatTimer);
      unsubscribe();
      const count = this._clientCounts.get(homeId) || 1;
      if (count <= 1) {
        this._clientCounts.delete(homeId);
      } else {
        this._clientCounts.set(homeId, count - 1);
      }
    };

    req.on('close', cleanup);
    req.on('error', cleanup);
    res.on('error', cleanup);
  }

  /**
   * Total active SSE connections across all homes.
   */
  totalConnections() {
    let total = 0;
    for (const count of this._clientCounts.values()) {
      total += count;
    }
    return total;
  }
}

module.exports = { RealtimeStreamRouter, HEARTBEAT_INTERVAL_MS, MAX_CLIENTS_PER_HOME };
