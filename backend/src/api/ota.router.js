'use strict';

/**
 * EH Home — Device Fleet Management & OTA Router (Phase 18)
 *
 * REST Endpoints:
 * - GET  /api/v1/ota/check?productVariantId=...&hardwareRevision=...&currentVersion=...
 * - GET  /api/v1/ota/manifests/:releaseId
 * - GET  /api/v1/ota/releases
 * - POST /api/v1/ota/releases
 * - GET  /api/v1/fleet/status?homeId=...
 * - POST /api/v1/ota/operations
 * - GET  /api/v1/ota/maintenance?homeId=...&deviceId=...
 * - POST /api/v1/ota/telemetry/progress
 * - POST /api/v1/ota/telemetry/success
 * - POST /api/v1/ota/telemetry/failure
 */

class OtaApiRouter {
  constructor({ otaService }) {
    this.otaService = otaService;
  }

  async handle(method, pathname, body = {}, query = {}, user = null) {
    try {
      // 1. Check for compatible OTA update
      if (pathname === '/api/v1/ota/check' && method === 'GET') {
        const { productVariantId, hardwareRevision, currentVersion, releaseChannel } = query;
        if (!productVariantId || !currentVersion) {
          return {
            status: 400,
            body: { success: false, error: 'Missing productVariantId or currentVersion parameter' }
          };
        }
        const result = await this.otaService.checkUpdate({
          productVariantId,
          hardwareRevision,
          currentVersion,
          releaseChannel: releaseChannel || 'production'
        });
        return { status: 200, body: { success: true, data: result } };
      }

      // 2. Fetch specific release manifest
      if (pathname.startsWith('/api/v1/ota/manifests/') && method === 'GET') {
        const releaseId = pathname.replace('/api/v1/ota/manifests/', '');
        const release = await this.otaService.getRelease(releaseId);
        if (!release) {
          return { status: 404, body: { success: false, error: 'Release manifest not found' } };
        }
        return { status: 200, body: { success: true, data: release } };
      }

      // 3. List Releases
      if (pathname === '/api/v1/ota/releases' && method === 'GET') {
        const releases = await this.otaService.listReleases(query);
        return { status: 200, body: { success: true, data: releases } };
      }

      // 4. Register a new signed release
      if (pathname === '/api/v1/ota/releases' && method === 'POST') {
        const registered = await this.otaService.registerRelease(body);
        return { status: 201, body: { success: true, data: registered } };
      }

      // 5. Fleet Status
      if (pathname === '/api/v1/fleet/status' && method === 'GET') {
        const homeId = query.homeId || null;
        const userId = user ? user.id : null;
        const status = await this.otaService.getFleetStatus({ homeId, userId });
        return { status: 200, body: { success: true, data: status } };
      }

      // 6. Initiate OTA Operation
      if (pathname === '/api/v1/ota/operations' && method === 'POST') {
        const { deviceId, releaseId, homeId } = body;
        if (!deviceId || !releaseId || !homeId) {
          return {
            status: 400,
            body: { success: false, error: 'deviceId, releaseId, and homeId are required' }
          };
        }
        const userId = user ? user.id : null;
        const op = await this.otaService.initiateOta({ deviceId, releaseId, homeId, userId });
        return { status: 201, body: { success: true, data: op } };
      }

      // 7. Maintenance History
      if (pathname === '/api/v1/ota/maintenance' && method === 'GET') {
        const { homeId, deviceId } = query;
        const userId = user ? user.id : null;
        const history = await this.otaService.getMaintenanceHistory({ homeId, deviceId, userId });
        return { status: 200, body: { success: true, data: history } };
      }

      // 8. Ingest Device Progress Telemetry
      if (pathname === '/api/v1/ota/telemetry/progress' && method === 'POST') {
        const { deviceId, operationId, progressPercent, stage } = body;
        await this.otaService.handleOtaProgress({ deviceId, operationId, progressPercent, stage });
        return { status: 200, body: { success: true } };
      }

      // 9. Ingest Device Success Confirmation
      if (pathname === '/api/v1/ota/telemetry/success' && method === 'POST') {
        const { deviceId, operationId, installedVersion } = body;
        await this.otaService.handleOtaSuccess({ deviceId, operationId, installedVersion });
        return { status: 200, body: { success: true } };
      }

      // 10. Ingest Device Failure / Rollback Confirmation
      if (pathname === '/api/v1/ota/telemetry/failure' && method === 'POST') {
        const { deviceId, operationId, errorCode, errorMessage, isRollback } = body;
        await this.otaService.handleOtaFailure({ deviceId, operationId, errorCode, errorMessage, isRollback });
        return { status: 200, body: { success: true } };
      }

      return {
        status: 404,
        body: { success: false, error: `Route ${method} ${pathname} not found` }
      };
    } catch (err) {
      const status = err.statusCode || 400;
      return { status, body: { success: false, error: err.message } };
    }
  }
}

module.exports = { OtaApiRouter };
