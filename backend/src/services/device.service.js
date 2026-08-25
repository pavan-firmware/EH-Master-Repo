/**
 * EH Home — Device Domain Service (Phase 4)
 *
 * Responsibilities:
 *  - Manage Physical Device Registration & Product Metadata Validation
 *  - Hardware Revision & Firmware Family Compatibility Verification
 *  - Home & Room Authorization / Device Assignment Lifecycle
 *  - Channel Renaming & Custom Configuration Validation
 *  - Resolved Device Summary Generation (integrates Phase 3 Capability Engine)
 *  - Audit logging for all device lifecycle events
 */

const { ProductCatalogService } = require('./product-catalog.service');

class DeviceService {
  constructor({ deviceRepo, deviceStateRepo, homeRepo, roomRepo, auditRepo, productCatalogService }) {
    this.deviceRepo = deviceRepo;
    this.deviceStateRepo = deviceStateRepo;
    this.homeRepo = homeRepo;
    this.roomRepo = roomRepo;
    this.auditRepo = auditRepo;
    this.productCatalogService = productCatalogService || new ProductCatalogService();
  }

  // ---------------------------------------------------------------------------
  // 1. Device Registration & Hardware Compatibility
  // ---------------------------------------------------------------------------

  async registerDevice({ deviceId, serialNumber, productVariantId, hardwareRevision, firmwareFamily, firmwareVersion = '1.0.0', actorUserId = null }) {
    if (!deviceId || !serialNumber || !productVariantId || !hardwareRevision || !firmwareFamily) {
      throw new Error('deviceId, serialNumber, productVariantId, hardwareRevision, and firmwareFamily are required');
    }

    // Validate productVariantId against Product Catalog
    const variantDef = this.productCatalogService.getProductVariant(productVariantId);
    if (!variantDef) {
      throw new Error(`Unknown productVariantId '${productVariantId}'`);
    }

    const { metadata } = variantDef;

    // Validate hardwareRevision compatibility
    if (!metadata.supportedHardwareRevisions.includes(hardwareRevision)) {
      throw new Error(`Hardware revision '${hardwareRevision}' is not supported by product variant '${productVariantId}'. Supported: ${metadata.supportedHardwareRevisions.join(', ')}`);
    }

    // Validate firmwareFamily compatibility
    if (metadata.firmwareFamily !== firmwareFamily) {
      throw new Error(`Firmware family '${firmwareFamily}' is incompatible with product variant '${productVariantId}'. Expected: '${metadata.firmwareFamily}'`);
    }

    // Register physical device identity & initialize device/channel state
    const dev = await this.deviceRepo.registerDevice({
      deviceId,
      serialNumber,
      productVariantId,
      hardwareRevision,
      firmwareFamily,
      firmwareVersion
    });

    if (this.auditRepo) {
      await this.auditRepo.log({
        id: `audit_dev_register_${deviceId}_${require('crypto').randomUUID()}`,
        actorUserId,
        deviceId,
        action: 'DEVICE_REGISTERED',
        payload: { serialNumber, productVariantId, hardwareRevision, firmwareFamily }
      });
    }

    return dev;
  }

  // ---------------------------------------------------------------------------
  // 2. Home Authorization & Room Assignment
  // ---------------------------------------------------------------------------

  async assignDeviceToHome({ deviceId, homeId, roomId = null, customName, channelLabels = {}, actorUserId = null }) {
    const dev = await this.deviceRepo.getDevice(deviceId);
    if (!dev) throw new Error(`Device ${deviceId} does not exist`);

    const home = await this.homeRepo.getHome(homeId);
    if (!home) throw new Error(`Home ${homeId} does not exist`);

    if (roomId) {
      const room = await this.roomRepo.getRoom(roomId);
      if (!room) throw new Error(`Room ${roomId} does not exist`);
      if (room.home_id !== homeId) {
        throw new Error(`Room ${roomId} belongs to home ${room.home_id}, not target home ${homeId}`);
      }
    }

    // Check if already claimed
    const existingAuth = await this.deviceRepo.getDeviceAuthorization(deviceId);
    if (existingAuth) {
      throw new Error(`Device ${deviceId} is already assigned to home ${existingAuth.home_id}`);
    }

    const nameToUse = (customName && customName.trim() !== '')
      ? customName
      : (this.productCatalogService.getProductVariant(dev.product_variant_id)?.metadata.displayName || 'Smart Device');

    const auth = await this.deviceRepo.claimDevice({
      deviceId,
      homeId,
      roomId,
      customName: nameToUse,
      channelLabels,
      claimedByUserId: actorUserId
    });

    if (this.auditRepo) {
      await this.auditRepo.log({
        id: `audit_dev_assign_${deviceId}_${require('crypto').randomUUID()}`,
        actorUserId,
        deviceId,
        homeId,
        action: 'DEVICE_ASSIGNED',
        payload: { roomId, customName: nameToUse }
      });
    }

    return auth;
  }

  async moveDeviceToRoom({ deviceId, newRoomId, actorUserId = null }) {
    const auth = await this.deviceRepo.getDeviceAuthorization(deviceId);
    if (!auth) throw new Error(`Device ${deviceId} is not assigned to any home`);

    if (newRoomId) {
      const room = await this.roomRepo.getRoom(newRoomId);
      if (!room) throw new Error(`Room ${newRoomId} does not exist`);
      if (room.home_id !== auth.home_id) {
        throw new Error(`Cannot move device ${deviceId}: target room ${newRoomId} belongs to home ${room.home_id}, but device is in home ${auth.home_id}`);
      }
    }

    const updated = await this.deviceRepo.updateDeviceAuthorization(deviceId, { roomId: newRoomId });

    if (this.auditRepo) {
      await this.auditRepo.log({
        id: `audit_dev_move_room_${deviceId}_${require('crypto').randomUUID()}`,
        actorUserId,
        deviceId,
        homeId: auth.home_id,
        action: 'DEVICE_MOVED_ROOM',
        payload: { oldRoomId: auth.room_id, newRoomId }
      });
    }

    return updated;
  }

  async moveDeviceToHome({ deviceId, newHomeId, newRoomId = null, actorUserId = null }) {
    const auth = await this.deviceRepo.getDeviceAuthorization(deviceId);
    if (!auth) throw new Error(`Device ${deviceId} is not assigned to any home`);

    const targetHome = await this.homeRepo.getHome(newHomeId);
    if (!targetHome) throw new Error(`Home ${newHomeId} does not exist`);

    if (newRoomId) {
      const room = await this.roomRepo.getRoom(newRoomId);
      if (!room) throw new Error(`Room ${newRoomId} does not exist`);
      if (room.home_id !== newHomeId) {
        throw new Error(`Room ${newRoomId} belongs to home ${room.home_id}, not target home ${newHomeId}`);
      }
    }

    const updated = await this.deviceRepo.updateDeviceAuthorization(deviceId, { homeId: newHomeId, roomId: newRoomId });

    if (this.auditRepo) {
      await this.auditRepo.log({
        id: `audit_dev_move_home_${deviceId}_${require('crypto').randomUUID()}`,
        actorUserId,
        deviceId,
        homeId: newHomeId,
        action: 'DEVICE_MOVED_HOME',
        payload: { oldHomeId: auth.home_id, newHomeId, newRoomId }
      });
    }

    return updated;
  }

  async removeDeviceFromHome({ deviceId, actorUserId = null }) {
    const auth = await this.deviceRepo.getDeviceAuthorization(deviceId);
    if (!auth) throw new Error(`Device ${deviceId} is not assigned to any home`);

    // Remove authorization while preserving physical device identity
    const res = await this.deviceRepo.removeDeviceAuthorization(deviceId);

    if (this.auditRepo) {
      await this.auditRepo.log({
        id: `audit_dev_remove_${deviceId}_${require('crypto').randomUUID()}`,
        actorUserId,
        deviceId,
        homeId: auth.home_id,
        action: 'DEVICE_REMOVED_FROM_HOME',
        payload: { previousHomeId: auth.home_id }
      });
    }

    return res;
  }

  // ---------------------------------------------------------------------------
  // 3. Channel Configuration & Naming
  // ---------------------------------------------------------------------------

  async renameChannel({ deviceId, channelIndex, newName, actorUserId = null }) {
    const dev = await this.deviceRepo.getDevice(deviceId);
    if (!dev) throw new Error(`Device ${deviceId} does not exist`);

    const variantDef = this.productCatalogService.getProductVariant(dev.product_variant_id);
    if (!variantDef) throw new Error(`Product variant ${dev.product_variant_id} does not exist`);

    const channelCount = variantDef.metadata.channelCount;
    if (channelIndex < 1 || channelIndex > channelCount) {
      throw new Error(`Channel index ${channelIndex} is out of bounds for product variant '${dev.product_variant_id}' (max ${channelCount})`);
    }

    const auth = await this.deviceRepo.getDeviceAuthorization(deviceId);
    if (!auth) throw new Error(`Device ${deviceId} is not assigned to any home`);

    const currentLabels = auth.channel_labels || {};
    const updatedLabels = { ...currentLabels, [String(channelIndex)]: newName };

    const updated = await this.deviceRepo.updateDeviceAuthorization(deviceId, { channelLabels: updatedLabels });

    if (this.auditRepo) {
      await this.auditRepo.log({
        id: `audit_ch_rename_${deviceId}_${channelIndex}_${require('crypto').randomUUID()}`,
        actorUserId,
        deviceId,
        homeId: auth.home_id,
        action: 'CHANNEL_RENAMED',
        payload: { channelIndex, newName }
      });
    }

    return updated;
  }

  async updateChannelConfiguration({ deviceId, channelIndex, configuration, actorUserId = null }) {
    const dev = await this.deviceRepo.getDevice(deviceId);
    if (!dev) throw new Error(`Device ${deviceId} does not exist`);

    const variantDef = this.productCatalogService.getProductVariant(dev.product_variant_id);
    if (!variantDef) throw new Error(`Product variant ${dev.product_variant_id} does not exist`);

    const channelCount = variantDef.metadata.channelCount;
    if (channelIndex < 1 || channelIndex > channelCount) {
      throw new Error(`Channel index ${channelIndex} is out of bounds (max ${channelCount})`);
    }

    // Validate that user is not attempting to enable hardware capabilities that the product variant does not support
    if (configuration && configuration.requestedCapabilities) {
      const unsupported = configuration.requestedCapabilities.filter(c => !variantDef.metadata.capabilities.includes(c));
      if (unsupported.length > 0) {
        throw new Error(`Cannot enable unsupported hardware capabilities: ${unsupported.join(', ')}`);
      }
    }

    const auth = await this.deviceRepo.getDeviceAuthorization(deviceId);
    if (!auth) throw new Error(`Device ${deviceId} is not assigned to any home`);

    const currentConfigs = auth.channel_configs || {};
    const updatedConfigs = { ...currentConfigs, [String(channelIndex)]: configuration };

    const updated = await this.deviceRepo.updateDeviceAuthorization(deviceId, { channelConfigs: updatedConfigs });

    if (this.auditRepo) {
      await this.auditRepo.log({
        id: `audit_ch_config_${deviceId}_${channelIndex}_${require('crypto').randomUUID()}`,
        actorUserId,
        deviceId,
        homeId: auth.home_id,
        action: 'CHANNEL_CONFIG_UPDATED',
        payload: { channelIndex, configuration }
      });
    }

    return updated;
  }

  // ---------------------------------------------------------------------------
  // 4. Resolved Device Summary Generation (Canonical Domain Response)
  // ---------------------------------------------------------------------------

  async getResolvedDeviceSummary(deviceId) {
    const dev = await this.deviceRepo.getDevice(deviceId);
    if (!dev) return null;

    const auth = await this.deviceRepo.getDeviceAuthorization(deviceId);
    const fullState = await this.deviceStateRepo.getFullState(deviceId);

    let roomName = null;
    let floorId = null;
    if (auth && auth.room_id) {
      const room = await this.roomRepo.getRoom(auth.room_id);
      if (room) {
        roomName = room.name;
        floorId = room.floor_id;
      }
    }

    // Integrate Phase 3 capability resolution
    const resolvedCaps = this.productCatalogService.resolveDeviceCapabilities({
      productVariantId: dev.product_variant_id,
      deviceId,
      channelLabels: auth ? (auth.channel_labels || {}) : {},
      deviceState: fullState
    });

    return {
      deviceId: dev.id,
      serialNumber: dev.serial_number,
      productVariantId: dev.product_variant_id,
      hardwareRevision: dev.hardware_revision,
      firmwareFamily: dev.firmware_family,
      firmwareVersion: dev.firmware_version,
      homeId: auth ? auth.home_id : null,
      floorId,
      roomId: auth ? auth.room_id : null,
      roomName,
      displayName: auth ? auth.custom_name : resolvedCaps.displayName,
      connectionState: fullState ? fullState.connectionState : 'OFFLINE',
      channels: resolvedCaps.channels,
      capabilities: resolvedCaps.capabilities,
      capabilityUiHints: resolvedCaps.capabilityUiHints,
      hasEnergyMonitoring: resolvedCaps.hasEnergyMonitoring,
      hasFanSpeed: resolvedCaps.hasFanSpeed,
      hasBrightness: resolvedCaps.hasBrightness,
      hasCCT: resolvedCaps.hasCCT,
      claimedAt: auth ? auth.claimed_at : null
    };
  }

  async getDevicesSummaryForHome(homeId) {
    const authorizations = await this.deviceRepo.getAuthorizationsByHome(homeId);
    const summaries = [];
    for (const auth of authorizations) {
      const summary = await this.getResolvedDeviceSummary(auth.device_id);
      if (summary) {
        summaries.push(summary);
      }
    }
    return summaries;
  }
}

module.exports = { DeviceService };
