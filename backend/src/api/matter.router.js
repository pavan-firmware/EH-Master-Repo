'use strict';

/**
 * EH Home — Matter & Multi-Platform Integration API Router (Phase 29)
 *
 * Exposes consumer-relevant endpoints for Matter status, multi-fabric pairing,
 * platform connections, and command execution.
 */

class MatterApiRouter {
  constructor({
    matterIntegrationService,
    matterCommissioningService,
    matterStateSyncService,
    matterCapabilityMappingService,
    homeAuthService
  }) {
    this.matterIntegrationService = matterIntegrationService;
    this.matterCommissioningService = matterCommissioningService;
    this.matterStateSyncService = matterStateSyncService;
    this.matterCapabilityMappingService = matterCapabilityMappingService;
    this.homeAuthService = homeAuthService;
  }

  async handleRequest(method, path, body = {}, headers = {}) {
    const actorContext = {
      userId: headers['x-user-id'] || 'usr_owner_01',
      homeId: headers['x-home-id'] || 'home_main',
      role: headers['x-user-role'] || 'OWNER'
    };

    try {
      // 1. GET /api/v1/matter/certification
      if (method === 'GET' && path === '/api/v1/matter/certification') {
        const cert = this.matterIntegrationService.getCertificationOverview();
        return { statusCode: 200, body: { success: true, data: cert } };
      }

      // 2. GET /api/v1/devices/:deviceId/matter
      const deviceMatterMatch = path.match(/^\/api\/v1\/devices\/([^\/]+)\/matter$/);
      if (method === 'GET' && deviceMatterMatch) {
        const deviceId = deviceMatterMatch[1];
        const data = await this.matterIntegrationService.getDeviceMatterDetails(actorContext, deviceId);
        return { statusCode: 200, body: { success: true, data } };
      }

      // 3. GET /api/v1/devices/:deviceId/matter/fabrics
      const deviceFabricsMatch = path.match(/^\/api\/v1\/devices\/([^\/]+)\/matter\/fabrics$/);
      if (method === 'GET' && deviceFabricsMatch) {
        const deviceId = deviceFabricsMatch[1];
        const details = await this.matterIntegrationService.getDeviceMatterDetails(actorContext, deviceId);
        return { statusCode: 200, body: { success: true, data: details.fabrics || [] } };
      }

      // 4. POST /api/v1/devices/:deviceId/matter/commission
      const commissionMatch = path.match(/^\/api\/v1\/devices\/([^\/]+)\/matter\/commission$/);
      if (method === 'POST' && commissionMatch) {
        const deviceId = commissionMatch[1];
        const { targetFabric = 'APPLE_HOME', complete = false, sessionId, fabricId, label } = body;

        if (complete && sessionId) {
          const res = await this.matterCommissioningService.completeCommissioning(sessionId, { fabricId, fabricName: targetFabric, label });
          return { statusCode: 200, body: { success: true, data: res } };
        }

        const session = await this.matterCommissioningService.startCommissioningSession(deviceId, actorContext.homeId, targetFabric);
        return { statusCode: 200, body: { success: true, data: session } };
      }

      // 5. POST /api/v1/devices/:deviceId/matter/decommission
      const decommissionMatch = path.match(/^\/api\/v1\/devices\/([^\/]+)\/matter\/decommission$/);
      if (method === 'POST' && decommissionMatch) {
        const deviceId = decommissionMatch[1];
        const { fabricId } = body;
        const res = await this.matterCommissioningService.decommissionFabric(deviceId, fabricId);
        return { statusCode: 200, body: { success: true, data: res } };
      }

      // 6. POST /api/v1/devices/:deviceId/matter/command
      const commandMatch = path.match(/^\/api\/v1\/devices\/([^\/]+)\/matter\/command$/);
      if (method === 'POST' && commandMatch) {
        const deviceId = commandMatch[1];
        const res = await this.matterStateSyncService.handleInboundMatterCommand(actorContext, {
          ...body,
          deviceId,
          homeId: body.homeId || actorContext.homeId
        });
        return { statusCode: 200, body: { success: true, data: res } };
      }

      // 7. GET /api/v1/devices/:deviceId/integrations
      const deviceIntegrationsMatch = path.match(/^\/api\/v1\/devices\/([^\/]+)\/integrations$/);
      if (method === 'GET' && deviceIntegrationsMatch) {
        const deviceId = deviceIntegrationsMatch[1];
        const details = await this.matterIntegrationService.getDeviceMatterDetails(actorContext, deviceId);
        return { statusCode: 200, body: { success: true, data: details.externalLinks || [] } };
      }

      // 8. POST /api/v1/devices/:deviceId/integrations/:platform/connect
      const connectMatch = path.match(/^\/api\/v1\/devices\/([^\/]+)\/integrations\/([^\/]+)\/connect$/);
      if (method === 'POST' && connectMatch) {
        const deviceId = connectMatch[1];
        const platform = connectMatch[2];
        const res = await this.matterIntegrationService.connectPlatform(actorContext, deviceId, platform, body);
        return { statusCode: 200, body: { success: true, data: res } };
      }

      // 9. POST /api/v1/devices/:deviceId/integrations/:platform/disconnect
      const disconnectMatch = path.match(/^\/api\/v1\/devices\/([^\/]+)\/integrations\/([^\/]+)\/disconnect$/);
      if (method === 'POST' && disconnectMatch) {
        const deviceId = disconnectMatch[1];
        const platform = disconnectMatch[2];
        const res = await this.matterIntegrationService.disconnectPlatform(actorContext, deviceId, platform);
        return { statusCode: 200, body: { success: true, data: res } };
      }

      // 10. GET /api/v1/homes/:homeId/integrations
      const homeIntegrationsMatch = path.match(/^\/api\/v1\/homes\/([^\/]+)\/integrations$/);
      if (method === 'GET' && homeIntegrationsMatch) {
        const homeId = homeIntegrationsMatch[1];
        const res = await this.matterIntegrationService.getHomeIntegrations(actorContext, homeId);
        return { statusCode: 200, body: { success: true, data: res } };
      }

      return {
        statusCode: 404,
        body: { success: false, error: `Route not found: ${method} ${path}` }
      };
    } catch (err) {
      return {
        statusCode: 400,
        body: { success: false, error: err.message }
      };
    }
  }
}

module.exports = { MatterApiRouter };
