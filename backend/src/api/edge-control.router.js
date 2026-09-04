'use strict';

/**
 * EdgeControlApiRouter (Phase 28)
 *
 * REST API Router for Local-First Home Control & Edge Execution.
 * Exposes router endpoints for unified command execution, local status, metrics, and edge scenes.
 */

class EdgeControlApiRouter {
  /**
   * @param {Object} opts
   * @param {Object} opts.routingService        - ExecutionRoutingService
   * @param {Object} opts.localExecutionService - LocalExecutionService
   * @param {Object} opts.localDiscoveryService - LocalDiscoveryService
   * @param {Object} opts.edgeAutomationService - EdgeAutomationService
   * @param {Object} opts.edgeExecutionRepo     - EdgeExecutionRepository
   * @param {Object} opts.localRouteRepo        - LocalRouteCacheRepository
   * @param {Object} [opts.homeAuthService]     - HomeAuthorizationService
   */
  constructor({
    routingService,
    localExecutionService,
    localDiscoveryService,
    edgeAutomationService,
    edgeExecutionRepo,
    localRouteRepo,
    homeAuthService = null
  }) {
    this.routingService = routingService;
    this.localExecutionService = localExecutionService;
    this.localDiscoveryService = localDiscoveryService;
    this.edgeAutomationService = edgeAutomationService;
    this.edgeExecutionRepo = edgeExecutionRepo;
    this.localRouteRepo = localRouteRepo;
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

      // ── 1. Home Local Reachability Status ────────────────────────────────
      m = path.match(/^\/api\/v1\/edge\/homes\/([^/]+)\/local-status$/) || path.match(/^\/api\/v1\/homes\/([^/]+)\/local-status$/);
      if (m && method === 'GET') {
        const homeId = m[1];
        if (this.homeAuthService && userId) {
          await this.homeAuthService.requireMembership(userId, homeId);
        }
        const devices = await this.localDiscoveryService.getLocalDevices(homeId);
        const metrics = await this.edgeExecutionRepo.getMetrics(homeId);
        return ok({
          homeId,
          isLocalNetworkActive: true,
          totalLocalDevices: devices.length,
          localSuccessRate: metrics.localSuccessRate,
          averageLatencyMs: metrics.averageLatencyMs,
          reachableDevices: devices
        });
      }

      // ── 2. List Reachable Local Devices in Home ──────────────────────────
      m = path.match(/^\/api\/v1\/edge\/homes\/([^/]+)\/local-devices$/) || path.match(/^\/api\/v1\/homes\/([^/]+)\/local-devices$/);
      if (m && method === 'GET') {
        const homeId = m[1];
        if (this.homeAuthService && userId) {
          await this.homeAuthService.requireMembership(userId, homeId);
        }
        const devices = await this.localDiscoveryService.getLocalDevices(homeId);
        return ok({ homeId, count: devices.length, devices });
      }

      // ── 3. Trigger Local Network Scan / Discovery ────────────────────────
      m = path.match(/^\/api\/v1\/edge\/homes\/([^/]+)\/local-discovery\/scan$/) || path.match(/^\/api\/v1\/homes\/([^/]+)\/local-discovery\/scan$/);
      if (m && method === 'POST') {
        const homeId = m[1];
        if (this.homeAuthService && userId) {
          await this.homeAuthService.requireMembership(userId, homeId);
        }
        const scanResult = await this.localDiscoveryService.scanLocalNetwork(homeId);
        return ok(scanResult);
      }

      // ── 4. Device Local Connectivity & Route Status ───────────────────────
      m = path.match(/^\/api\/v1\/edge\/devices\/([^/]+)\/local-connectivity$/) || path.match(/^\/api\/v1\/devices\/([^/]+)\/local-connectivity$/);
      if (m && method === 'GET') {
        const deviceId = m[1];
        const route = await this.localRouteRepo.findByDevice(deviceId);
        if (!route) {
          return ok({
            deviceId,
            isReachableLocally: false,
            transportType: 'NONE',
            reachability: 'UNREACHABLE',
            lastContactAt: null
          });
        }
        return ok({
          deviceId: route.deviceId,
          homeId: route.homeId,
          isReachableLocally: route.reachability === 'REACHABLE',
          transportType: route.transportType,
          localEndpoint: route.localEndpoint,
          localIp: route.localIp,
          localPort: route.localPort,
          reachability: route.reachability,
          latencyMs: route.latencyMs,
          isTlsSecured: route.isTlsSecured,
          expiresAt: route.expiresAt,
          lastContactAt: route.lastContactAt
        });
      }

      // ── 5. Unified Command Execution Router ──────────────────────────────
      m = path.match(/^\/api\/v1\/edge\/devices\/([^/]+)\/execute$/) || path.match(/^\/api\/v1\/devices\/([^/]+)\/execute$/);
      if (m && method === 'POST') {
        const deviceId = m[1];
        const context = {
          userId: userId || body.actorUserId || 'system_app',
          homeId: body.homeId || (actorContext && actorContext.homeId) || 'home_main',
          role: (actorContext && actorContext.role) || 'OWNER',
          source: body.source || 'APP_LOCAL'
        };

        const result = await this.localExecutionService.executeCommand(context, {
          commandId: body.commandId,
          deviceId,
          homeId: context.homeId,
          channelIndex: body.channelIndex ?? null,
          action: body.action || 'setPower',
          params: body.params || { value: body.value ?? true },
          idempotencyKey: body.idempotencyKey,
          preferredRoute: body.preferredRoute || 'AUTO'
        });

        const statusCode = result.status === 'CONFIRMED' || result.status === 'DEFERRED' ? 200 : (result.status === 'UNAVAILABLE' ? 503 : 200);
        return ok(result, statusCode);
      }

      // ── 6. Execute Scene Locally on Edge ─────────────────────────────────
      m = path.match(/^\/api\/v1\/edge\/homes\/([^/]+)\/scenes\/([^/]+)\/execute$/) || path.match(/^\/api\/v1\/homes\/([^/]+)\/scenes\/([^/]+)\/execute-edge$/);
      if (m && method === 'POST') {
        const homeId = m[1];
        const sceneId = m[2];
        if (this.homeAuthService && userId) {
          await this.homeAuthService.requireMembership(userId, homeId);
        }
        const result = await this.edgeAutomationService.executeSceneEdge({
          homeId,
          userId: userId || 'system_app',
          sceneId
        });
        return ok(result);
      }

      // ── 7. Evaluate Edge Automations ─────────────────────────────────────
      m = path.match(/^\/api\/v1\/edge\/homes\/([^/]+)\/automations\/evaluate$/) || path.match(/^\/api\/v1\/homes\/([^/]+)\/edge-automations\/evaluate$/);
      if (m && method === 'POST') {
        const homeId = m[1];
        if (this.homeAuthService && userId) {
          await this.homeAuthService.requireMembership(userId, homeId);
        }
        const triggerEvent = body || {};
        const result = await this.edgeAutomationService.evaluateAutomationEdge({ homeId, triggerEvent });
        return ok(result);
      }

      // ── 8. Edge Execution Telemetry & Metrics ─────────────────────────────
      m = path.match(/^\/api\/v1\/edge\/homes\/([^/]+)\/metrics$/) || path.match(/^\/api\/v1\/homes\/([^/]+)\/edge-metrics$/);
      if (m && method === 'GET') {
        const homeId = m[1];
        if (this.homeAuthService && userId) {
          await this.homeAuthService.requireMembership(userId, homeId);
        }
        const metrics = await this.edgeExecutionRepo.getMetrics(homeId);
        return ok({ homeId, ...metrics });
      }

      return err('ROUTE_NOT_FOUND', `Route ${method} ${path} not found on edge controller`, 404);
    } catch (e) {
      return err('INTERNAL_ERROR', e.message, e.statusCode || 500);
    }
  }
}

module.exports = { EdgeControlApiRouter };
