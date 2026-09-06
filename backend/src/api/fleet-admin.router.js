'use strict';

/**
 * EH Home — Admin Fleet Management & Safe OTA Rollout Router (Phase 41)
 *
 * REST Endpoints:
 * - POST /api/v1/admin/firmware/releases
 * - POST /api/v1/admin/firmware/releases/:id/publish
 * - POST /api/v1/admin/firmware/releases/:id/revoke
 * - GET  /api/v1/admin/firmware/releases
 * - GET  /api/v1/admin/firmware/releases/:id
 * - POST /api/v1/admin/ota/rollouts
 * - GET  /api/v1/admin/ota/rollouts
 * - GET  /api/v1/admin/ota/rollouts/:id
 * - POST /api/v1/admin/ota/rollouts/:id/start
 * - POST /api/v1/admin/ota/rollouts/:id/pause
 * - POST /api/v1/admin/ota/rollouts/:id/resume
 * - POST /api/v1/admin/ota/rollouts/:id/cancel
 * - POST /api/v1/admin/ota/rollouts/:id/rollback
 * - POST /api/v1/admin/ota/rollouts/:id/execute-batch
 * - GET  /api/v1/admin/fleet/firmware-state
 * - GET  /api/v1/admin/fleet/firmware-state/:deviceId
 * - GET  /api/v1/admin/ota/attempts
 * - POST /api/v1/admin/ota/health-verify
 */

class FleetAdminApiRouter {
  /**
   * @param {Object} opts
   * @param {Object} opts.firmwareReleaseService - FirmwareReleaseService
   * @param {Object} opts.otaRolloutService      - OtaRolloutService
   * @param {Object} opts.fleetFirmwareService   - FleetFirmwareService
   * @param {Object} opts.fleetFirmwareRepo      - FleetFirmwareRepository
   */
  constructor({
    firmwareReleaseService,
    otaRolloutService,
    fleetFirmwareService,
    fleetFirmwareRepo
  }) {
    this.releaseService = firmwareReleaseService;
    this.rolloutService = otaRolloutService;
    this.fleetFirmwareService = fleetFirmwareService;
    this.fleetFirmwareRepo = fleetFirmwareRepo;
  }

  _requireAdmin(user) {
    if (!user) {
      const err = new Error('Authentication required');
      err.statusCode = 401;
      throw err;
    }
    const role = (user.role || '').toUpperCase();
    const permissions = user.permissions || [];
    const isAdmin = role === 'ADMIN' || role === 'SYSTEM_ADMIN' || permissions.includes('canManageFirmware') || permissions.includes('canManageDevices');

    if (!isAdmin) {
      const err = new Error('Forbidden: Administrative privilege or canManageFirmware permission required');
      err.statusCode = 403;
      throw err;
    }
  }

  async handle(method, pathname, body = {}, query = {}, user = null) {
    try {
      // 1. Create Firmware Release
      if (pathname === '/api/v1/admin/firmware/releases' && method === 'POST') {
        this._requireAdmin(user);
        const release = await this.releaseService.createRelease(body, user ? user.id : null);
        return { status: 201, body: { success: true, data: release } };
      }

      // 2. Publish Firmware Release
      if (pathname.startsWith('/api/v1/admin/firmware/releases/') && pathname.endsWith('/publish') && method === 'POST') {
        this._requireAdmin(user);
        const releaseId = pathname.replace('/api/v1/admin/firmware/releases/', '').replace('/publish', '');
        const published = await this.releaseService.publishRelease(releaseId, user ? user.id : null);
        return { status: 200, body: { success: true, data: published } };
      }

      // 3. Revoke Firmware Release
      if (pathname.startsWith('/api/v1/admin/firmware/releases/') && pathname.endsWith('/revoke') && method === 'POST') {
        this._requireAdmin(user);
        const releaseId = pathname.replace('/api/v1/admin/firmware/releases/', '').replace('/revoke', '');
        const revoked = await this.releaseService.revokeRelease(releaseId, body.reason, user ? user.id : null);
        return { status: 200, body: { success: true, data: revoked } };
      }

      // 4. List Firmware Releases
      if (pathname === '/api/v1/admin/firmware/releases' && method === 'GET') {
        this._requireAdmin(user);
        const releases = await this.releaseService.listReleases(query);
        return { status: 200, body: { success: true, data: releases } };
      }

      // 5. Get Firmware Release Details
      if (pathname.startsWith('/api/v1/admin/firmware/releases/') && method === 'GET') {
        this._requireAdmin(user);
        const releaseId = pathname.replace('/api/v1/admin/firmware/releases/', '');
        const release = await this.releaseService.getRelease(releaseId);
        if (!release) return { status: 404, body: { success: false, error: 'Firmware release not found' } };
        return { status: 200, body: { success: true, data: release } };
      }

      // 6. Create Rollout Campaign
      if (pathname === '/api/v1/admin/ota/rollouts' && method === 'POST') {
        this._requireAdmin(user);
        const rollout = await this.rolloutService.createRollout({
          ...body,
          actorUserId: user ? user.id : null
        });
        return { status: 201, body: { success: true, data: rollout } };
      }

      // 7. List Rollout Campaigns
      if (pathname === '/api/v1/admin/ota/rollouts' && method === 'GET') {
        this._requireAdmin(user);
        const rollouts = await this.rolloutService.listRollouts(query);
        return { status: 200, body: { success: true, data: rollouts } };
      }

      // 8. Get Rollout Campaign Details
      if (pathname.startsWith('/api/v1/admin/ota/rollouts/') && method === 'GET') {
        this._requireAdmin(user);
        const rolloutId = pathname.replace('/api/v1/admin/ota/rollouts/', '');
        const rollout = await this.rolloutService.getRollout(rolloutId);
        if (!rollout) return { status: 404, body: { success: false, error: 'OTA rollout not found' } };
        return { status: 200, body: { success: true, data: rollout } };
      }

      // 9. Start Rollout
      if (pathname.startsWith('/api/v1/admin/ota/rollouts/') && pathname.endsWith('/start') && method === 'POST') {
        this._requireAdmin(user);
        const rolloutId = pathname.replace('/api/v1/admin/ota/rollouts/', '').replace('/start', '');
        const started = await this.rolloutService.startRollout(rolloutId, user ? user.id : null);
        return { status: 200, body: { success: true, data: started } };
      }

      // 10. Pause Rollout
      if (pathname.startsWith('/api/v1/admin/ota/rollouts/') && pathname.endsWith('/pause') && method === 'POST') {
        this._requireAdmin(user);
        const rolloutId = pathname.replace('/api/v1/admin/ota/rollouts/', '').replace('/pause', '');
        const paused = await this.rolloutService.pauseRollout(rolloutId, body.reason, user ? user.id : null);
        return { status: 200, body: { success: true, data: paused } };
      }

      // 11. Resume Rollout
      if (pathname.startsWith('/api/v1/admin/ota/rollouts/') && pathname.endsWith('/resume') && method === 'POST') {
        this._requireAdmin(user);
        const rolloutId = pathname.replace('/api/v1/admin/ota/rollouts/', '').replace('/resume', '');
        const resumed = await this.rolloutService.resumeRollout(rolloutId, user ? user.id : null);
        return { status: 200, body: { success: true, data: resumed } };
      }

      // 12. Cancel Rollout
      if (pathname.startsWith('/api/v1/admin/ota/rollouts/') && pathname.endsWith('/cancel') && method === 'POST') {
        this._requireAdmin(user);
        const rolloutId = pathname.replace('/api/v1/admin/ota/rollouts/', '').replace('/cancel', '');
        const cancelled = await this.rolloutService.cancelRollout(rolloutId, body.reason, user ? user.id : null);
        return { status: 200, body: { success: true, data: cancelled } };
      }

      // 13. Initiate Rollback
      if (pathname.startsWith('/api/v1/admin/ota/rollouts/') && pathname.endsWith('/rollback') && method === 'POST') {
        this._requireAdmin(user);
        const rolloutId = pathname.replace('/api/v1/admin/ota/rollouts/', '').replace('/rollback', '');
        const rollbackResult = await this.rolloutService.initiateRollback({
          rolloutId,
          targetReleaseId: body.targetReleaseId,
          reason: body.reason,
          actorUserId: user ? user.id : null
        });
        return { status: 200, body: { success: true, data: rollbackResult } };
      }

      // 14. Execute Next Batch
      if (pathname.startsWith('/api/v1/admin/ota/rollouts/') && pathname.endsWith('/execute-batch') && method === 'POST') {
        this._requireAdmin(user);
        const rolloutId = pathname.replace('/api/v1/admin/ota/rollouts/', '').replace('/execute-batch', '');
        const batchResult = await this.rolloutService.executeBatch(rolloutId, {
          candidateDevices: body.candidateDevices,
          actorUserId: user ? user.id : null
        });
        return { status: 200, body: { success: true, data: batchResult } };
      }

      // 15. List Fleet Firmware States
      if (pathname === '/api/v1/admin/fleet/firmware-state' && method === 'GET') {
        this._requireAdmin(user);
        const states = await this.fleetFirmwareService.listFleetFirmwareStates(query);
        return { status: 200, body: { success: true, data: states } };
      }

      // 16. Get Single Device Firmware State
      if (pathname.startsWith('/api/v1/admin/fleet/firmware-state/') && method === 'GET') {
        this._requireAdmin(user);
        const deviceId = pathname.replace('/api/v1/admin/fleet/firmware-state/', '');
        const state = await this.fleetFirmwareService.getDeviceFirmwareState(deviceId);
        if (!state) return { status: 404, body: { success: false, error: 'Device firmware state not found' } };
        return { status: 200, body: { success: true, data: state } };
      }

      // 17. List OTA Attempts
      if (pathname === '/api/v1/admin/ota/attempts' && method === 'GET') {
        this._requireAdmin(user);
        const attempts = await this.fleetFirmwareRepo.listAttempts(query);
        return { status: 200, body: { success: true, data: attempts } };
      }

      // 18. Post-OTA Health Verification
      if (pathname === '/api/v1/admin/ota/health-verify' && method === 'POST') {
        this._requireAdmin(user);
        const { deviceId, rolloutId, attemptId } = body;
        if (!deviceId) return { status: 400, body: { success: false, error: 'deviceId is required' } };
        const result = await this.rolloutService.handleDeviceHealthVerified({ deviceId, rolloutId, attemptId });
        return { status: 200, body: { success: true, data: result } };
      }

      return {
        status: 404,
        body: { success: false, error: `Fleet Admin Route ${method} ${pathname} not found` }
      };
    } catch (err) {
      const status = err.statusCode || 400;
      return { status, body: { success: false, error: err.message } };
    }
  }
}

module.exports = { FleetAdminApiRouter };
