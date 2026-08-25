/**
 * EH Home — Phase 5 Provisioning & Claim API Router
 * Endpoints for secure commissioning, Wi-Fi provisioning, device registration, device claiming, and device reset.
 */

class ProvisioningClaimApiRouter {
  constructor({ provisioningService, deviceClaimService }) {
    this.provisioningService = provisioningService;
    this.deviceClaimService = deviceClaimService;
  }

  async handle(method, path, body = {}, params = {}) {
    try {
      // 1. Commissioning Session Creation
      if (method === 'POST' && path === '/api/v1/provisioning/sessions') {
        const session = await this.provisioningService.createCommissioningSession(body);
        return { status: 201, body: { data: session } };
      }

      // 2. Authenticate Session
      if (method === 'POST' && path.startsWith('/api/v1/provisioning/sessions/') && path.endsWith('/authenticate')) {
        const sessionId = path.replace('/api/v1/provisioning/sessions/', '').replace('/authenticate', '');
        const authResult = await this.provisioningService.authenticateSession({ ...body, sessionId });
        return { status: 200, body: { data: authResult } };
      }

      // 3. Provision Wi-Fi Credentials
      if (method === 'POST' && path.startsWith('/api/v1/provisioning/sessions/') && path.endsWith('/wifi')) {
        const sessionId = path.replace('/api/v1/provisioning/sessions/', '').replace('/wifi', '');
        const wifiResult = await this.provisioningService.provisionWifiCredentials({ ...body, sessionId });
        return { status: 200, body: { data: wifiResult } };
      }

      // 4. Complete Registration
      if (method === 'POST' && path.startsWith('/api/v1/provisioning/sessions/') && path.endsWith('/complete')) {
        const sessionId = path.replace('/api/v1/provisioning/sessions/', '').replace('/complete', '');
        const compResult = await this.provisioningService.completeRegistration({ sessionId });
        return { status: 200, body: { data: compResult } };
      }

      // 5. Claim Device
      if (method === 'POST' && path.startsWith('/api/v1/devices/') && path.endsWith('/claim')) {
        const deviceId = path.replace('/api/v1/devices/', '').replace('/claim', '');
        const claimResult = await this.deviceClaimService.claimDevice({ ...body, deviceId });
        return { status: 200, body: { data: claimResult } };
      }

      // 6. Unclaim Device
      if (method === 'POST' && path.startsWith('/api/v1/devices/') && path.endsWith('/unclaim')) {
        const deviceId = path.replace('/api/v1/devices/', '').replace('/unclaim', '');
        const unclaimResult = await this.deviceClaimService.unclaimDevice({ ...body, deviceId });
        return { status: 200, body: { data: unclaimResult } };
      }

      // 7. Reset Device
      if (method === 'POST' && path.startsWith('/api/v1/devices/') && path.endsWith('/reset')) {
        const deviceId = path.replace('/api/v1/devices/', '').replace('/reset', '');
        const resetResult = await this.deviceClaimService.resetDevice({ ...body, deviceId });
        return { status: 200, body: { data: resetResult } };
      }

      return { status: 404, body: { error: 'Not Found', path } };
    } catch (err) {
      return { status: 400, body: { error: err.message } };
    }
  }
}

module.exports = { ProvisioningClaimApiRouter };
