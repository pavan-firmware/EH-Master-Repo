'use strict';

/**
 * EH Home — Device Management & Observability REST Router (Phase 11)
 *
 * Exposes authenticated endpoints for:
 *   - Device details, health, activity, and diagnostics
 *   - Device lifecycle operations: rename, move room, remove from home
 *   - Production Observability: /health, /health/liveness, /health/readiness, /health/diagnostics
 */

class DeviceManagementApiRouter {
  /**
   * @param {Object} opts
   * @param {DeviceManagementService} opts.deviceManagementService
   * @param {Object} [opts.db]
   * @param {Object} [opts.mqttTransport]
   * @param {Object} [opts.workers]
   */
  constructor({ deviceManagementService, db, mqttTransport, workers = {} }) {
    this.deviceManagementService = deviceManagementService;
    this.db = db;
    this.mqttTransport = mqttTransport;
    this.workers = workers;
  }

  async handle(method, pathname, body = {}, headers = {}, query = {}) {
    const correlationId = headers['x-correlation-id'] || headers['x-request-id'] || `req_${Date.now()}`;
    const userId = query.userId || headers['x-user-id'] || 'system';

    // -------------------------------------------------------------------------
    // 1. Observability Health Checks
    // -------------------------------------------------------------------------
    if (method === 'GET' && pathname === '/api/v1/health/liveness') {
      return {
        status: 200,
        body: {
          status: 'UP',
          timestamp: new Date().toISOString(),
          uptime: process.uptime()
        }
      };
    }

    if (method === 'GET' && pathname === '/api/v1/health/readiness') {
      const isDbReady = this.db ? true : false;
      return {
        status: isDbReady ? 200 : 503,
        body: {
          status: isDbReady ? 'READY' : 'NOT_READY',
          timestamp: new Date().toISOString(),
          checks: {
            database: isDbReady ? 'CONNECTED' : 'DISCONNECTED'
          }
        }
      };
    }

    if (method === 'GET' && (pathname === '/api/v1/health' || pathname === '/api/v1/health/diagnostics')) {
      const isDbReady = this.db ? true : false;
      const isMqttConnected = this.mqttTransport ? (this.mqttTransport.isConnected || false) : false;

      return {
        status: 200,
        body: {
          status: 'HEALTHY',
          service: 'eh-home-backend',
          version: '1.1.0',
          timestamp: new Date().toISOString(),
          uptime: process.uptime(),
          dependencies: {
            database: { status: isDbReady ? 'UP' : 'DOWN' },
            mqttBroker: { status: isMqttConnected ? 'UP' : 'STANDBY' },
            workers: {
              automationScheduler: { status: this.workers.scheduler ? 'RUNNING' : 'INACTIVE' },
              staleDetector: { status: this.workers.staleDetector ? 'RUNNING' : 'INACTIVE' },
              outboxRetry: { status: this.workers.outbox ? 'RUNNING' : 'INACTIVE' }
            }
          }
        }
      };
    }

    // -------------------------------------------------------------------------
    // 2. Homes Scoped Device Management Routes (/api/v1/homes/:homeId/devices/...)
    // -------------------------------------------------------------------------
    const homeDeviceMatch = pathname.match(/^\/api\/v1\/homes\/([^\/]+)\/devices\/([^\/]+)(?:\/([^\/]+))?$/);
    if (homeDeviceMatch) {
      const homeId = homeDeviceMatch[1];
      const deviceId = homeDeviceMatch[2];
      const subAction = homeDeviceMatch[3]; // details, health, diagnostics, activity, rename, move, or null

      try {
        // GET /api/v1/homes/:homeId/devices/:deviceId/details
        // or GET /api/v1/homes/:homeId/devices/:deviceId
        if (method === 'GET' && (!subAction || subAction === 'details')) {
          const details = await this.deviceManagementService.getDeviceDetails({
            homeId,
            deviceId,
            userId
          });
          return { status: 200, body: { success: true, data: details } };
        }

        // GET /api/v1/homes/:homeId/devices/:deviceId/health
        if (method === 'GET' && subAction === 'health') {
          const details = await this.deviceManagementService.getDeviceDetails({
            homeId,
            deviceId,
            userId
          });
          return { status: 200, body: { success: true, data: details.health } };
        }

        // GET /api/v1/homes/:homeId/devices/:deviceId/diagnostics
        if (method === 'GET' && subAction === 'diagnostics') {
          const diag = await this.deviceManagementService.getDeviceDiagnostics({
            homeId,
            deviceId,
            userId
          });
          return { status: 200, body: { success: true, data: diag } };
        }

        // GET /api/v1/homes/:homeId/devices/:deviceId/activity
        if (method === 'GET' && subAction === 'activity') {
          const limit = parseInt(query.limit, 10) || 50;
          const eventType = query.eventType || null;
          const history = await this.deviceManagementService.getDeviceActivityHistory({
            homeId,
            deviceId,
            userId,
            limit,
            eventType
          });
          return { status: 200, body: { success: true, ...history } };
        }

        // PATCH /api/v1/homes/:homeId/devices/:deviceId/rename
        if (method === 'PATCH' && subAction === 'rename') {
          const newName = body.name || body.customName || body.displayName;
          const result = await this.deviceManagementService.renameDevice({
            homeId,
            deviceId,
            newName,
            userId,
            correlationId
          });
          return { status: 200, body: { success: true, data: result } };
        }

        // PATCH /api/v1/homes/:homeId/devices/:deviceId/move
        if (method === 'PATCH' && subAction === 'move') {
          const newRoomId = body.roomId || body.newRoomId;
          const result = await this.deviceManagementService.moveDevice({
            homeId,
            deviceId,
            newRoomId,
            userId,
            correlationId
          });
          return { status: 200, body: { success: true, data: result } };
        }

        // DELETE /api/v1/homes/:homeId/devices/:deviceId
        if (method === 'DELETE' && !subAction) {
          const result = await this.deviceManagementService.removeDeviceFromHome({
            homeId,
            deviceId,
            userId,
            correlationId
          });
          return { status: 200, body: { success: true, data: result } };
        }
      } catch (err) {
        const statusCode = err.statusCode || 400;
        return {
          status: statusCode,
          body: {
            success: false,
            error: { code: statusCode === 403 ? 'FORBIDDEN' : statusCode === 404 ? 'NOT_FOUND' : 'BAD_REQUEST', message: err.message },
            timestamp: new Date().toISOString()
          }
        };
      }
    }

    return null;
  }
}

module.exports = { DeviceManagementApiRouter };
