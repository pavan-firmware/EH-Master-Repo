'use strict';

/**
 * EH Home — Matter Commissioning & Multi-Admin Service (Phase 29)
 *
 * Manages Matter commissioning lifecycle, pairing codes, QR payloads,
 * multi-admin fabric sharing, and factory reset reconciliation.
 */

class MatterCommissioningService {
  constructor({
    matterDeviceRepo,
    matterFabricRepo,
    externalPlatformLinkRepo,
    capabilityMappingService,
    deviceRepo
  }) {
    this.matterDeviceRepo = matterDeviceRepo;
    this.matterFabricRepo = matterFabricRepo;
    this.externalPlatformLinkRepo = externalPlatformLinkRepo;
    this.capabilityMappingService = capabilityMappingService;
    this.deviceRepo = deviceRepo;
    this._activeSessions = new Map();
  }

  /**
   * Initializes or fetches Matter device entity for an authorized EH device.
   */
  async ensureMatterDevice(deviceId, homeId, productVariantId = 'eh-smart-switch-1x') {
    let matterDevice = await this.matterDeviceRepo.findByDeviceId(deviceId);
    if (!matterDevice) {
      const mapping = this.capabilityMappingService.resolveMappingForVariant(productVariantId);
      matterDevice = await this.matterDeviceRepo.upsertMatterDevice({
        deviceId,
        homeId,
        matterDeviceType: mapping.matterDeviceType,
        commissioningState: 'NOT_COMMISSIONED',
        subscriptionState: 'NONE',
        setupPasscode: 20202021,
        discriminator: 3840
      });

      // Populate endpoints
      await this.matterDeviceRepo.saveEndpoints(matterDevice.id, mapping.endpoints);
    }
    return matterDevice;
  }

  /**
   * Starts a Matter commissioning session with standard QR and Manual Pairing code.
   */
  async startCommissioningSession(deviceId, homeId, targetFabric = 'APPLE_HOME') {
    const matterDevice = await this.ensureMatterDevice(deviceId, homeId);
    const sessionId = `comm_sess_${Date.now()}_${Math.floor(Math.random() * 1000)}`;
    const expiresAt = new Date(Date.now() + 15 * 60 * 1000).toISOString(); // 15 mins

    const passcode = matterDevice.setupPasscode || 20202021;
    const discriminator = matterDevice.discriminator || 3840;

    // Standard Matter 11-digit manual pairing code simulation:
    // Format: Discriminator + Passcode encoded string
    const manualPairingCode = `34970${passcode.toString().slice(0, 6)}`;
    const qrCodePayload = `MT:Y.K9042C00KA0648G00_${matterDevice.nodeId}`;

    const session = {
      schemaVersion: 1,
      sessionId,
      deviceId,
      homeId,
      stage: 'ADVERTISING',
      targetFabric,
      discriminator,
      setupPasscode: passcode,
      qrCodePayload,
      manualPairingCode,
      errorMessage: null,
      expiresAt,
      createdAt: new Date().toISOString(),
      completedAt: null
    };

    this._activeSessions.set(sessionId, session);

    // Update matter device status
    await this.matterDeviceRepo.updateCommissioningState(deviceId, 'COMMISSIONING');

    return session;
  }

  /**
   * Completes a commissioning step and binds the new Matter Fabric.
   */
  async completeCommissioning(sessionId, { fabricId, fabricName, controllerNodeId = null, label = null } = {}) {
    const session = this._activeSessions.get(sessionId);
    if (!session) {
      throw new Error(`Commissioning session '${sessionId}' not found or expired`);
    }

    const matterDevice = await this.matterDeviceRepo.findByDeviceId(session.deviceId);
    if (!matterDevice) {
      throw new Error(`Matter device for session '${sessionId}' not found`);
    }

    const targetFabricName = fabricName || session.targetFabric || 'APPLE_HOME';
    const assignedFabricId = fabricId || `0x${Math.floor(Math.random() * 0xFFFFFFFFFFFFFFFF).toString(16).padStart(16, '0')}`;

    // Get current fabrics to determine next fabric index
    const existingFabrics = await this.matterFabricRepo.listByMatterDeviceId(matterDevice.id);
    const nextIndex = existingFabrics.length + 1;

    // 1. Add fabric binding
    const fabric = await this.matterFabricRepo.addFabric({
      fabricId: assignedFabricId,
      matterDeviceId: matterDevice.id,
      fabricIndex: nextIndex,
      fabricName: targetFabricName,
      vendorId: targetFabricName === 'APPLE_HOME' ? 4937 : (targetFabricName === 'GOOGLE_HOME' ? 24582 : 65521),
      controllerNodeId: controllerNodeId || `0x${Math.floor(Math.random() * 0xFFFFFFFFFFFFFFFF).toString(16).padStart(16, '0')}`,
      commissioningState: 'CONNECTED',
      label: label || `${targetFabricName} Controller`
    });

    // 2. Link provider-neutral platform
    if (this.externalPlatformLinkRepo) {
      await this.externalPlatformLinkRepo.upsertLink({
        homeId: session.homeId,
        deviceId: session.deviceId,
        platform: targetFabricName === 'AMAZON_ALEXA' ? 'AMAZON_ALEXA' : targetFabricName,
        status: 'CONNECTED',
        displayName: `${targetFabricName} Ecosystem`,
        syncStatus: 'SYNCHRONIZED'
      });
    }

    // 3. Mark device COMMISSIONED / CONNECTED
    await this.matterDeviceRepo.updateCommissioningState(session.deviceId, 'COMMISSIONED', 'ACTIVE');

    session.stage = 'COMPLETED';
    session.completedAt = new Date().toISOString();

    return {
      session,
      fabric,
      matterDevice: await this.matterDeviceRepo.findByDeviceId(session.deviceId)
    };
  }

  /**
   * Decommissions / removes a specific fabric (Multi-Admin removal).
   */
  async decommissionFabric(deviceId, fabricId) {
    const matterDevice = await this.matterDeviceRepo.findByDeviceId(deviceId);
    if (!matterDevice) throw new Error(`Matter device ${deviceId} not found`);

    const fabric = await this.matterFabricRepo.findByDeviceAndFabricId(matterDevice.id, fabricId);
    if (!fabric) throw new Error(`Fabric ${fabricId} not found on device ${deviceId}`);

    await this.matterFabricRepo.removeFabric(matterDevice.id, fabricId);

    // Update external link
    if (this.externalPlatformLinkRepo) {
      await this.externalPlatformLinkRepo.disconnectLink(deviceId, fabric.fabricName);
    }

    // Check remaining active fabrics
    const remaining = await this.matterFabricRepo.listByMatterDeviceId(matterDevice.id);
    if (remaining.length === 0) {
      await this.matterDeviceRepo.updateCommissioningState(deviceId, 'NOT_COMMISSIONED', 'NONE');
    }

    return { success: true, fabricId, remainingFabrics: remaining.length };
  }

  /**
   * Reconciles Matter state during Device Factory Reset (Correction 8).
   * Ensures all fabrics are decommissioned and external platform links are disconnected.
   */
  async reconcileFactoryReset(deviceId) {
    const matterDevice = await this.matterDeviceRepo.findByDeviceId(deviceId);
    if (matterDevice) {
      await this.matterFabricRepo.clearAllFabricsForDevice(matterDevice.id);
      await this.matterDeviceRepo.updateCommissioningState(deviceId, 'NOT_COMMISSIONED', 'NONE');
    }

    if (this.externalPlatformLinkRepo) {
      await this.externalPlatformLinkRepo.clearAllLinksForDevice(deviceId);
    }

    return {
      success: true,
      deviceId,
      matterReconciled: true,
      fabricsCleared: true,
      linksDisconnected: true
    };
  }
}

module.exports = { MatterCommissioningService };
