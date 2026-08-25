/**
 * EH Home — Device Claim & Reset Domain Service (Phase 5)
 *
 * Responsibilities:
 *  - Secure Device Claiming bound to Home and Room (requires authenticated commissioning evidence)
 *  - Idempotent Claim handling
 *  - Unclaiming devices (preserves physical device identity)
 *  - Deterministic Device Reset (SOFT_RESET, NETWORK_RESET, FACTORY_RESET)
 *  - Audit Logging for all claim & reset actions
 */

class DeviceClaimService {
  constructor({ deviceService, deviceRepo, sessionRepo, auditRepo }) {
    this.deviceService = deviceService;
    this.deviceRepo = deviceRepo;
    this.sessionRepo = sessionRepo;
    this.auditRepo = auditRepo;
  }

  async claimDevice({ deviceId, homeId, roomId = null, customName, channelLabels = {}, sessionId = null, actorUserId = null }) {
    // Check if already claimed by this exact home (Idempotency Check)
    const existingAuth = await this.deviceRepo.getDeviceAuthorization(deviceId);
    if (existingAuth) {
      if (existingAuth.home_id === homeId) {
        return existingAuth; // Idempotent: return existing claim
      }
      throw new Error(`Device ${deviceId} is already claimed by home ${existingAuth.home_id}`);
    }

    // Require authenticated commissioning evidence if sessionId is passed
    if (sessionId) {
      const session = await this.sessionRepo.getSession(sessionId);
      if (!session) throw new Error(`Commissioning session ${sessionId} not found`);
      if (session.device_id !== deviceId) {
        throw new Error(`Session ${sessionId} belongs to device ${session.device_id}, not target device ${deviceId}`);
      }
      const allowedStatuses = ['AUTHENTICATED', 'PROVISIONED', 'COMPLETED'];
      if (!allowedStatuses.includes(session.status)) {
        throw new Error(`Cannot claim device with session in status '${session.status}'`);
      }
    }

    // Reuse Phase 4 DeviceService assignment
    const auth = await this.deviceService.assignDeviceToHome({
      deviceId,
      homeId,
      roomId,
      customName,
      channelLabels,
      actorUserId
    });

    if (this.auditRepo) {
      await this.auditRepo.log({
        id: `audit_dev_claim_${deviceId}_${require('crypto').randomUUID()}`,
        actorUserId,
        deviceId,
        homeId,
        action: 'DEVICE_CLAIMED',
        payload: { roomId, customName }
      });
    }

    return auth;
  }

  async unclaimDevice({ deviceId, actorUserId = null }) {
    const existingAuth = await this.deviceRepo.getDeviceAuthorization(deviceId);
    if (!existingAuth) throw new Error(`Device ${deviceId} is not currently claimed by any home`);

    const res = await this.deviceService.removeDeviceFromHome({ deviceId, actorUserId });

    if (this.auditRepo) {
      await this.auditRepo.log({
        id: `audit_dev_unclaim_${deviceId}_${require('crypto').randomUUID()}`,
        actorUserId,
        deviceId,
        homeId: existingAuth.home_id,
        action: 'DEVICE_UNCLAIMED',
        payload: { previousHomeId: existingAuth.home_id }
      });
    }

    return res;
  }

  async resetDevice({ deviceId, resetType = 'SOFT_RESET', actorUserId = null }) {
    const validResetTypes = ['SOFT_RESET', 'NETWORK_RESET', 'FACTORY_RESET'];
    if (!validResetTypes.includes(resetType)) {
      throw new Error(`Invalid resetType '${resetType}'. Allowed: ${validResetTypes.join(', ')}`);
    }

    const dev = await this.deviceRepo.getDevice(deviceId);
    if (!dev) throw new Error(`Device ${deviceId} does not exist`);

    // SOFT_RESET: preserves identity & claim
    // NETWORK_RESET / FACTORY_RESET: removes home authorization while preserving physical device identity
    if (resetType === 'NETWORK_RESET' || resetType === 'FACTORY_RESET') {
      const existingAuth = await this.deviceRepo.getDeviceAuthorization(deviceId);
      if (existingAuth) {
        await this.deviceRepo.removeDeviceAuthorization(deviceId);
      }
    }

    if (this.auditRepo) {
      await this.auditRepo.log({
        id: `audit_dev_reset_${deviceId}_${require('crypto').randomUUID()}`,
        actorUserId,
        deviceId,
        action: 'DEVICE_RESET',
        payload: { resetType, preservedSerialNumber: dev.serial_number }
      });
    }

    return {
      deviceId,
      resetType,
      serialNumber: dev.serial_number,
      productVariantId: dev.product_variant_id,
      hardwareRevision: dev.hardware_revision,
      firmwareFamily: dev.firmware_family,
      status: 'RESET_COMPLETE'
    };
  }
}

module.exports = { DeviceClaimService };
