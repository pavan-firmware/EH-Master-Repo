'use strict';

/**
 * EH Home — OTA Firmware Release Router (Phase 8)
 *
 * Lightweight router compatible with native HTTP app.
 *
 * Endpoints:
 * - GET /api/v1/ota/check?productVariantId=...&hardwareRevision=...&currentVersion=...
 * - GET /api/v1/ota/manifests/:releaseId
 * - POST /api/v1/ota/releases (admin/service registration)
 */

class OtaApiRouter {
  constructor({ otaService }) {
    this.otaService = otaService;
  }

  async handle(method, pathname, body = {}, query = {}) {
    // 1. Check for compatible OTA update
    if (pathname === '/api/v1/ota/check' && method === 'GET') {
      const { productVariantId, hardwareRevision, currentVersion } = query;
      if (!productVariantId || !currentVersion) {
        return {
          status: 400,
          body: { error: 'Missing productVariantId or currentVersion parameter' }
        };
      }
      const result = this.otaService.checkUpdate({
        productVariantId,
        hardwareRevision,
        currentVersion
      });
      return { status: 200, body: result };
    }

    // 2. Fetch specific release manifest
    if (pathname.startsWith('/api/v1/ota/manifests/') && method === 'GET') {
      const releaseId = pathname.replace('/api/v1/ota/manifests/', '');
      const release = this.otaService.getRelease(releaseId);
      if (!release) {
        return { status: 404, body: { error: 'Release manifest not found' } };
      }
      return { status: 200, body: release };
    }

    // 3. Register a new signed release
    if (pathname === '/api/v1/ota/releases' && method === 'POST') {
      try {
        const registered = this.otaService.registerRelease(body);
        return { status: 201, body: registered };
      } catch (err) {
        return { status: 400, body: { error: err.message } };
      }
    }

    return {
      status: 404,
      body: { error: `Route ${method} ${pathname} not found` }
    };
  }
}

module.exports = { OtaApiRouter };
