'use strict';

/**
 * Device Trust & Credential Lifecycle API Router (Phase 32)
 *
 * REST Endpoints:
 * - GET  /api/v1/devices/:deviceId/trust                   (Get device trust state)
 * - POST /api/v1/devices/:deviceId/quarantine              (Enact quarantine)
 * - POST /api/v1/devices/:deviceId/revoke                  (Explicit revocation)
 * - POST /api/v1/devices/:deviceId/restore-trust           (Authorized trust restoration)
 * - POST /api/v1/devices/:deviceId/credentials/rotate      (Safe credential rotation initiation)
 * - POST /api/v1/devices/:deviceId/credentials/confirm-rotation (Confirm credential rotation)
 * - GET  /api/v1/devices/:deviceId/credentials             (Query credential lifecycle ledger)
 * - POST /api/v1/devices/:deviceId/factory-reset-reconcile (Reconcile factory reset - Fix 4)
 * - GET  /api/v1/devices/:deviceId/security-history        (Audit and revocation history)
 * - GET  /api/v1/admin/device-trust/quarantined            (List quarantined devices)
 * - GET  /api/v1/admin/device-trust/revoked                (List revoked devices)
 */

class DeviceTrustApiRouter {
  /**
   * @param {Object} opts
   * @param {Object} opts.deviceTrustService        - DeviceTrustService instance
   * @param {Object} [opts.homeAuthorizationService] - HomeAuthorizationService instance
   * @param {Object} [opts.deviceRepo]               - DeviceRepository instance
   */
  constructor({
    deviceTrustService,
    homeAuthorizationService = null,
    deviceRepo = null
  }) {
    if (!deviceTrustService) {
      throw new Error('deviceTrustService is required for DeviceTrustApiRouter');
    }
    this.deviceTrustService = deviceTrustService;
    this.homeAuth = homeAuthorizationService;
    this.deviceRepo = deviceRepo;
  }

  async handle(method, rawPath, body = {}, headers = {}, params = {}) {
    const userId = params.userId || headers['x-user-id'] || null;
    const userRole = headers['x-user-role'] || params.userRole || null;
    const isAdmin = userRole === 'ADMIN' || userRole === 'SUPERADMIN' || headers['x-admin-role'] === 'true';

    // Normalize path
    const path = (rawPath.length > 1 && rawPath.endsWith('/')) ? rawPath.slice(0, -1) : rawPath;

    try {
      // 1. Admin endpoints
      if (path === '/api/v1/admin/device-trust/quarantined' || path === '/admin/device-trust/quarantined') {
        if (!isAdmin) return { status: 403, body: { error: 'FORBIDDEN', message: 'Admin role required' } };
        const quarantined = await this.deviceTrustService.deviceTrustRepo.listQuarantinedDevices();
        return { status: 200, body: { quarantined, count: quarantined.length } };
      }

      if (path === '/api/v1/admin/device-trust/revoked' || path === '/admin/device-trust/revoked') {
        if (!isAdmin) return { status: 403, body: { error: 'FORBIDDEN', message: 'Admin role required' } };
        const revoked = await this.deviceTrustService.deviceTrustRepo.listRevokedDevices();
        return { status: 200, body: { revoked, count: revoked.length } };
      }

      // 2. Device-specific route matching
      // Pattern: /api/v1/devices/:deviceId/(trust|quarantine|revoke|restore-trust|credentials|credentials/rotate|credentials/confirm-rotation|factory-reset-reconcile|security-history)
      const deviceRouteMatch = path.match(/^\/api\/v1\/devices\/([0-9a-fA-F-]+)(.*)$/) || path.match(/^\/devices\/([0-9a-fA-F-]+)(.*)$/);
      if (!deviceRouteMatch) {
        return { status: 404, body: { error: 'NOT_FOUND', message: `Route ${method} ${path} not found` } };
      }

      const deviceId = deviceRouteMatch[1];
      const subPath = deviceRouteMatch[2] || '';

      // Check authorization to device's home if homeAuth is available
      if (this.homeAuth && this.deviceRepo && userId && !isAdmin) {
        const auth = await this.deviceRepo.getDeviceAuthorization(deviceId);
        if (auth) {
          const authCheck = await this.homeAuth.authorizeRequest({ userId, homeId: auth.home_id });
          if (!authCheck.isAuthorized) {
            return { status: 403, body: { error: 'FORBIDDEN', message: 'Unauthorized for this device' } };
          }
        }
      }

      // Route: GET /devices/:deviceId/trust
      if (method === 'GET' && subPath === '/trust') {
        const trustState = await this.deviceTrustService.getDeviceTrustState(deviceId);
        return { status: 200, body: trustState };
      }

      // Route: POST /devices/:deviceId/quarantine
      if (method === 'POST' && subPath === '/quarantine') {
        const { reason, evidence } = body;
        if (!reason) return { status: 400, body: { error: 'BAD_REQUEST', message: 'reason is required' } };
        const updated = await this.deviceTrustService.quarantineDevice(deviceId, {
          reason,
          actorUserId: userId,
          evidence
        });
        return { status: 200, body: updated };
      }

      // Route: POST /devices/:deviceId/revoke
      if (method === 'POST' && subPath === '/revoke') {
        const { revocationType, reason, evidence, remediationAllowed } = body;
        if (!reason) return { status: 400, body: { error: 'BAD_REQUEST', message: 'reason is required' } };
        const revocation = await this.deviceTrustService.revokeDevice(deviceId, {
          revocationType: revocationType || 'COMPROMISED',
          reason,
          actorUserId: userId,
          evidence,
          remediationAllowed: !!remediationAllowed
        });
        return { status: 200, body: revocation };
      }

      // Route: POST /devices/:deviceId/restore-trust
      if (method === 'POST' && subPath === '/restore-trust') {
        const { reason, attestationVerified, targetState } = body;
        if (!reason) return { status: 400, body: { error: 'BAD_REQUEST', message: 'reason is required' } };
        const restored = await this.deviceTrustService.restoreTrust(deviceId, {
          reason,
          actorUserId: userId,
          attestationVerified: !!attestationVerified,
          targetState: targetState || 'TRUSTED'
        });
        return { status: 200, body: restored };
      }

      // Route: POST /devices/:deviceId/credentials/rotate
      if (method === 'POST' && subPath === '/credentials/rotate') {
        const { credentialType = 'MQTT', keyIdentifier, fingerprint, metadata } = body;
        if (!keyIdentifier) {
          return { status: 400, body: { error: 'BAD_REQUEST', message: 'keyIdentifier is required' } };
        }
        const result = await this.deviceTrustService.initiateCredentialRotation(deviceId, {
          credentialType,
          keyIdentifier,
          fingerprint,
          metadata
        });
        return { status: 200, body: result };
      }

      // Route: POST /devices/:deviceId/credentials/confirm-rotation
      if (method === 'POST' && subPath === '/credentials/confirm-rotation') {
        const { rotationId, confirmationEvidence, newMqttPasswordHash, newLocalSessionKeyHash, tlsClientCertFingerprint } = body;
        if (!rotationId) {
          return { status: 400, body: { error: 'BAD_REQUEST', message: 'rotationId is required' } };
        }
        const confirmed = await this.deviceTrustService.confirmCredentialRotation(deviceId, {
          rotationId,
          confirmationEvidence,
          newMqttPasswordHash,
          newLocalSessionKeyHash,
          tlsClientCertFingerprint
        });
        return { status: 200, body: confirmed };
      }

      // Route: GET /devices/:deviceId/credentials
      if (method === 'GET' && subPath === '/credentials') {
        const authoritative = await this.deviceTrustService.deviceTrustRepo.getAuthoritativeCredential(deviceId);
        const lifecycleLedger = await this.deviceTrustService.deviceTrustRepo.listLifecycleRecords(deviceId);

        // Sanitize: do not return password hashes or local session key secrets to clients
        const safeAuthoritative = authoritative ? {
          deviceId: authoritative.device_id,
          mqttUsername: authoritative.mqtt_username,
          tlsClientCertFingerprint: authoritative.tls_client_cert_fingerprint,
          credentialState: authoritative.credential_state,
          createdAt: authoritative.created_at,
          rotatedAt: authoritative.rotated_at
        } : null;

        return {
          status: 200,
          body: {
            authoritativeCredential: safeAuthoritative,
            lifecycleLedger
          }
        };
      }

      // Route: POST /devices/:deviceId/factory-reset-reconcile
      if (method === 'POST' && subPath === '/factory-reset-reconcile') {
        const result = await this.deviceTrustService.reconcileFactoryReset(deviceId, {
          actorUserId: userId,
          evidence: body.evidence || {}
        });
        return { status: 200, body: result };
      }

      // Route: GET /devices/:deviceId/security-history
      if (method === 'GET' && subPath === '/security-history') {
        const revocations = await this.deviceTrustService.deviceTrustRepo.getRevocations(deviceId);
        const lifecycleRecords = await this.deviceTrustService.deviceTrustRepo.listLifecycleRecords(deviceId);
        const trustState = await this.deviceTrustService.getDeviceTrustState(deviceId);
        return {
          status: 200,
          body: {
            deviceId,
            trustState,
            revocations,
            lifecycleRecords
          }
        };
      }

      return { status: 404, body: { error: 'NOT_FOUND', message: `Unknown action for device ${deviceId}: ${subPath}` } };
    } catch (err) {
      return {
        status: 400,
        body: { error: 'REQUEST_FAILED', message: err.message }
      };
    }
  }
}

module.exports = { DeviceTrustApiRouter };
