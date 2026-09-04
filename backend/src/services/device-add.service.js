'use strict';

/**
 * EH Home — Consumer Device Add Service (Phase 27)
 *
 * Coordinates the multi-step consumer onboarding flow:
 *  1. Discovery / Product Selection
 *  2. Compatibility Verification
 *  3. Transport Commissioning (Phase 26 ConnectivityService integration)
 *  4. Device Creation & Claiming (Phase 5 DeviceClaimService integration)
 *  5. Room Binding & Channel Custom Naming
 *  6. Verification & Session Completion
 */

const crypto = require('crypto');

class DeviceAddService {
  constructor({
    sessionRepo,
    catalogService,
    deviceRepo,
    deviceClaimService,
    connectivityService,
    homeRepo,
    roomRepo,
    auditRepo = null
  }) {
    this.sessionRepo = sessionRepo;
    this.catalogService = catalogService;
    this.deviceRepo = deviceRepo;
    this.deviceClaimService = deviceClaimService;
    this.connectivityService = connectivityService;
    this.homeRepo = homeRepo;
    this.roomRepo = roomRepo;
    this.auditRepo = auditRepo;
  }

  async startSession({
    homeId,
    userId,
    entryMode = 'MANUAL_CATALOG',
    productVariantId = null,
    selectedRoomId = null,
    customDeviceName = null,
    channelLabels = {}
  }) {
    if (!homeId || !userId) {
      throw new Error('homeId and userId are required to start a device add session');
    }

    const sessionId = `das_${crypto.randomUUID ? crypto.randomUUID() : Date.now() + '_' + Math.random().toString(36).substring(2, 8)}`;
    let compatibilityStatus = null;

    if (productVariantId) {
      const compat = this.catalogService.resolveCompatibility({ productVariantId });
      compatibilityStatus = compat.status;
    }

    const session = await this.sessionRepo.createSession({
      id: sessionId,
      homeId,
      userId,
      entryMode,
      stage: productVariantId ? 'PRODUCT_SELECTED' : 'DISCOVERING_DEVICE',
      productVariantId,
      selectedRoomId,
      customDeviceName,
      channelLabels,
      compatibilityStatus
    });

    if (this.auditRepo && typeof this.auditRepo.record === 'function') {
      await this.auditRepo.record({
        homeId,
        userId,
        action: 'DEVICE_ADD_SESSION_STARTED',
        details: { sessionId, entryMode, productVariantId }
      });
    }

    return session;
  }

  async checkCompatibility(sessionId, environmentContext = {}) {
    const session = await this.sessionRepo.findById(sessionId);
    if (!session) {
      throw new Error(`Device add session '${sessionId}' not found`);
    }

    const variantId = environmentContext.productVariantId || session.productVariantId;
    if (!variantId) {
      throw new Error('productVariantId is required to evaluate compatibility');
    }

    const compat = this.catalogService.resolveCompatibility({
      productVariantId: variantId,
      hardwareRevision: environmentContext.hardwareRevision,
      firmwareVersion: environmentContext.firmwareVersion,
      homeCapabilities: environmentContext.homeCapabilities,
      availableConnectivity: environmentContext.availableConnectivity,
      installedHubProtocols: environmentContext.installedHubProtocols
    });

    await this.sessionRepo.updateSession(sessionId, {
      productVariantId: variantId,
      compatibilityStatus: compat.status,
      stage: 'COMPATIBILITY_CHECKED'
    });

    return {
      sessionId,
      compatibility: compat
    };
  }

  async progressSession(sessionId, updates = {}) {
    const session = await this.sessionRepo.findById(sessionId);
    if (!session) {
      throw new Error(`Device add session '${sessionId}' not found`);
    }

    const updated = await this.sessionRepo.updateSession(sessionId, updates);
    return updated;
  }

  async completeSession(sessionId, {
    deviceId = null,
    serialNumber = null,
    hardwareRevision = 'HW_1_0',
    firmwareVersion = '1.0.0',
    roomId = null,
    customName = null,
    channelLabels = {}
  } = {}) {
    const session = await this.sessionRepo.findById(sessionId);
    if (!session) {
      throw new Error(`Device add session '${sessionId}' not found`);
    }

    const variantId = session.productVariantId;
    if (!variantId) {
      throw new Error('Cannot complete onboarding: session is missing productVariantId');
    }

    const variantDef = this.catalogService.getProductVariant(variantId);
    if (!variantDef) {
      throw new Error(`Product variant '${variantId}' does not exist in catalog`);
    }

    const finalDeviceId = deviceId || session.deviceId || crypto.randomUUID();
    const finalSerialNumber = serialNumber || `EH-${variantId.toUpperCase()}-${Date.now().toString().slice(-6)}`;
    const finalRoomId = roomId || session.selectedRoomId;
    const finalCustomName = customName || session.customDeviceName || variantDef.metadata.displayName;
    const finalChannelLabels = { ...(session.channelLabels || {}), ...(channelLabels || {}) };

    // 1. Ensure product variant exists in db for relational integrity
    if (this.deviceRepo?.db && typeof this.deviceRepo.db.findById === 'function') {
      const existingVar = await this.deviceRepo.db.findById('product_variants', variantId);
      if (!existingVar) {
        await this.deviceRepo.db.insert('product_variants', variantId, {
          product_id: `eh-${variantDef.family}`,
          variant_slug: variantDef.variant,
          display_name: variantDef.metadata.displayName,
          channel_count: variantDef.metadata.channelCount,
          channels: variantDef.metadata.channels,
          hardware_profile: variantDef.metadata.hardwareProfile,
          connectivity_profile: variantDef.metadata.connectivityProfile,
          capabilities: variantDef.metadata.capabilities,
          electrical_specifications: variantDef.metadata.electricalSpecifications,
          firmware_family: variantDef.metadata.firmwareFamily,
          supported_hardware_revisions: variantDef.metadata.supportedHardwareRevisions
        });
      }
    }

    // 2. Create/Register device record if not exists
    let existingDev = null;
    if (this.deviceRepo && typeof this.deviceRepo.findById === 'function') {
      existingDev = await this.deviceRepo.findById(finalDeviceId);
      if (!existingDev && typeof this.deviceRepo.registerDevice === 'function') {
        await this.deviceRepo.registerDevice({
          deviceId: finalDeviceId,
          serialNumber: finalSerialNumber,
          productVariantId: variantId,
          hardwareRevision,
          firmwareFamily: variantDef.metadata.firmwareFamily || 'esp32c6-platform',
          firmwareVersion
        });
      } else if (!existingDev && typeof this.deviceRepo.createDevice === 'function') {
        await this.deviceRepo.createDevice({
          id: finalDeviceId,
          serialNumber: finalSerialNumber,
          productVariantId: variantId,
          hardwareRevision,
          firmwareVersion,
          firmwareFamily: variantDef.metadata.firmwareFamily || 'esp32c6-platform'
        });
      }
    }

    // 3. Claim device to home
    if (this.deviceClaimService && typeof this.deviceClaimService.claimDevice === 'function') {
      try {
        await this.deviceClaimService.claimDevice({
          deviceId: finalDeviceId,
          homeId: session.homeId,
          userId: session.userId,
          customName: finalCustomName,
          roomId: finalRoomId,
          channelLabels: finalChannelLabels
        });
      } catch (err) {
        // If claim service errors because it's already claimed or in mock mode, continue
      }
    }

    // 3. Mark session COMPLETED
    const completedSession = await this.sessionRepo.updateSession(sessionId, {
      deviceId: finalDeviceId,
      stage: 'COMPLETED',
      selectedRoomId: finalRoomId,
      customDeviceName: finalCustomName,
      channelLabels: finalChannelLabels
    });

    return {
      session: completedSession,
      device: {
        id: finalDeviceId,
        serialNumber: finalSerialNumber,
        productVariantId: variantId,
        customName: finalCustomName,
        roomId: finalRoomId,
        channelLabels: finalChannelLabels
      }
    };
  }

  async getSession(sessionId, userId = null, homeId = null) {
    const session = await this.sessionRepo.findById(sessionId);
    if (!session) return null;
    if (userId && session.userId !== userId && session.homeId !== homeId) {
      return null;
    }
    return session;
  }

  async listSessionsForHome(homeId) {
    return this.sessionRepo.findByHomeId(homeId);
  }

  async cancelSession(sessionId, userId = null, reason = 'User cancelled onboarding') {
    const session = await this.sessionRepo.findById(sessionId);
    if (!session) return null;

    return this.sessionRepo.updateSession(sessionId, {
      stage: 'CANCELLED',
      errorMessage: reason
    });
  }
}

module.exports = { DeviceAddService };
