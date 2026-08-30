'use strict';

/**
 * EH Home — Device Management & Observability Service (Phase 11)
 *
 * Responsibilities:
 *   - Device Lifecycle Management: Rename, Move Room, Remove from Home
 *   - Device Health Evaluation: Unified health model (ONLINE, OFFLINE, STALE, DEGRADED, ERROR, UNKNOWN)
 *   - Authoritative Last-Seen Tracking & Diagnostics
 *   - Command Diagnostics & Telemetry Integrity
 *   - Activity & Error Logging with Correlation IDs
 *   - Zero Secret Leakage: Wi-Fi passwords, JWTs, commissioning secrets, and keys are NEVER exposed
 */

const crypto = require('crypto');

const HEALTH_STATUSES = Object.freeze({
  ONLINE: 'ONLINE',
  OFFLINE: 'OFFLINE',
  STALE: 'STALE',
  DEGRADED: 'DEGRADED',
  ERROR: 'ERROR',
  UNKNOWN: 'UNKNOWN'
});

class DeviceManagementService {
  /**
   * @param {Object} opts
   * @param {Object} opts.deviceRepo          - DeviceRepository instance
   * @param {Object} opts.deviceStateRepo     - DeviceStateRepository instance
   * @param {Object} opts.homeRepo            - HomeRepository instance
   * @param {Object} opts.roomRepo            - RoomRepository instance
   * @param {Object} opts.auditRepo           - AuditRepository instance
   * @param {Object} opts.activityLogRepo     - DeviceActivityLogRepository instance
   * @param {Object} opts.healthRepo          - DeviceHealthRepository instance
   * @param {Object} opts.commandRepo         - CommandRepository instance
   * @param {Object} opts.homeAuthService     - HomeAuthorizationService instance
   * @param {Object} opts.realtimeEventBus    - RealtimeEventBus instance (optional)
   * @param {Object} opts.productCatalogService - ProductCatalogService instance
   * @param {Object} opts.otaService          - OtaService instance (optional)
   */
  constructor({
    deviceRepo,
    deviceStateRepo,
    homeRepo,
    roomRepo,
    auditRepo,
    activityLogRepo,
    healthRepo,
    commandRepo,
    homeAuthService,
    realtimeEventBus,
    productCatalogService,
    otaService
  }) {
    this.deviceRepo = deviceRepo;
    this.deviceStateRepo = deviceStateRepo;
    this.homeRepo = homeRepo;
    this.roomRepo = roomRepo;
    this.auditRepo = auditRepo;
    this.activityLogRepo = activityLogRepo;
    this.healthRepo = healthRepo;
    this.commandRepo = commandRepo;
    this.homeAuthService = homeAuthService;
    this.realtimeEventBus = realtimeEventBus;
    this.productCatalogService = productCatalogService;
    this.otaService = otaService;
  }

  // ---------------------------------------------------------------------------
  // 1. Authorization Guard Helper
  // ---------------------------------------------------------------------------

  async _assertAccess(userId, homeId, deviceId = null, allowedRoles = null) {
    if (this.homeAuthService) {
      const auth = await this.homeAuthService.authorizeRequest({
        userId,
        homeId,
        deviceId
      });
      if (!auth.isAuthorized) {
        const err = new Error(auth.message || `User ${userId} not authorized for home ${homeId}`);
        err.statusCode = auth.statusCode || 403;
        throw err;
      }
      return auth;
    }
    return { isAuthorized: true, role: 'OWNER' };
  }

  // ---------------------------------------------------------------------------
  // 2. Device Details & Comprehensive Overview
  // ---------------------------------------------------------------------------

  async getDeviceDetails({ homeId, deviceId, userId }) {
    await this._assertAccess(userId, homeId, deviceId);

    const dev = await this.deviceRepo.getDevice(deviceId);
    if (!dev) {
      const err = new Error(`Device ${deviceId} not found`);
      err.statusCode = 404;
      throw err;
    }

    const auth = await this.deviceRepo.getDeviceAuthorization(deviceId);
    if (!auth || auth.home_id !== homeId) {
      const err = new Error(`Device ${deviceId} is not assigned to home ${homeId}`);
      err.statusCode = 404;
      throw err;
    }

    const fullState = await this.deviceStateRepo.getFullState(deviceId);
    const health = await this.calculateDeviceHealth(deviceId, fullState);

    let roomName = null;
    let floorId = null;
    if (auth.room_id) {
      const room = await this.roomRepo.getRoom(auth.room_id);
      if (room) {
        roomName = room.name;
        floorId = room.floor_id;
      }
    }

    let otaInfo = null;
    if (this.otaService) {
      try {
        const availableUpdate = await this.otaService.queryUpdate({
          deviceId,
          productVariantId: dev.product_variant_id,
          hardwareRevision: dev.hardware_revision,
          currentVersion: dev.firmware_version || '1.0.0'
        });
        otaInfo = {
          currentVersion: dev.firmware_version || '1.0.0',
          updateAvailable: availableUpdate.updateAvailable,
          latestVersion: availableUpdate.manifest?.targetFirmwareVersion || dev.firmware_version || '1.0.0'
        };
      } catch (_) {
        otaInfo = { currentVersion: dev.firmware_version || '1.0.0', updateAvailable: false };
      }
    } else {
      otaInfo = { currentVersion: dev.firmware_version || '1.0.0', updateAvailable: false };
    }

    const resolvedCaps = this.productCatalogService
      ? this.productCatalogService.resolveDeviceCapabilities({
          productVariantId: dev.product_variant_id,
          deviceId,
          channelLabels: auth.channel_labels || {},
          deviceState: fullState
        })
      : {
          displayName: auth.custom_name || dev.display_name || 'Smart Device',
          channels: [],
          capabilities: []
        };

    return {
      deviceId: dev.id,
      serialNumber: dev.serial_number,
      productVariantId: dev.product_variant_id,
      hardwareRevision: dev.hardware_revision,
      firmwareFamily: dev.firmware_family,
      firmwareVersion: dev.firmware_version,
      homeId: auth.home_id,
      roomId: auth.room_id,
      roomName,
      floorId,
      displayName: auth.custom_name || dev.display_name || resolvedCaps.displayName,
      connectionState: fullState ? fullState.connectionState : 'OFFLINE',
      lastSeenAt: fullState ? fullState.lastSeenAt : null,
      health,
      ota: otaInfo,
      channels: resolvedCaps.channels,
      capabilities: resolvedCaps.capabilities,
      claimedAt: auth.claimed_at,
      updatedAt: auth.updated_at
    };
  }

  // ---------------------------------------------------------------------------
  // 3. Rename Device
  // ---------------------------------------------------------------------------

  async renameDevice({ homeId, deviceId, newName, userId, correlationId = null }) {
    await this._assertAccess(userId, homeId, deviceId);

    if (!newName || typeof newName !== 'string' || newName.trim() === '') {
      const err = new Error('Device name cannot be empty');
      err.statusCode = 400;
      throw err;
    }

    const trimmedName = newName.trim();
    if (trimmedName.length > 64) {
      const err = new Error('Device name must be 64 characters or fewer');
      err.statusCode = 400;
      throw err;
    }

    const auth = await this.deviceRepo.getDeviceAuthorization(deviceId);
    if (!auth || auth.home_id !== homeId) {
      const err = new Error(`Device ${deviceId} is not assigned to home ${homeId}`);
      err.statusCode = 404;
      throw err;
    }

    const oldName = auth.custom_name;
    const updated = await this.deviceRepo.updateDeviceAuthorization(deviceId, {
      customName: trimmedName
    });

    if (this.activityLogRepo) {
      await this.activityLogRepo.createLog({
        id: `act_${crypto.randomUUID()}`,
        homeId,
        deviceId,
        eventType: 'device_renamed',
        severity: 'info',
        message: `Device renamed from "${oldName}" to "${trimmedName}"`,
        correlationId: correlationId || `rename_${deviceId}_${Date.now()}`,
        details: { oldName, newName: trimmedName, renamedBy: userId }
      });
    }

    if (this.realtimeEventBus) {
      this.realtimeEventBus.publish({
        homeId,
        type: 'device.updated',
        deviceId,
        payload: {
          deviceId,
          homeId,
          displayName: trimmedName,
          action: 'renamed',
          updatedAt: new Date().toISOString()
        }
      });
    }

    return {
      success: true,
      deviceId,
      displayName: trimmedName,
      previousName: oldName
    };
  }

  // ---------------------------------------------------------------------------
  // 4. Move Device to Another Room
  // ---------------------------------------------------------------------------

  async moveDevice({ homeId, deviceId, newRoomId, userId, correlationId = null }) {
    await this._assertAccess(userId, homeId, deviceId);

    const auth = await this.deviceRepo.getDeviceAuthorization(deviceId);
    if (!auth || auth.home_id !== homeId) {
      const err = new Error(`Device ${deviceId} is not assigned to home ${homeId}`);
      err.statusCode = 404;
      throw err;
    }

    let targetRoomName = null;
    if (newRoomId) {
      const targetRoom = await this.roomRepo.getRoom(newRoomId);
      if (!targetRoom) {
        const err = new Error(`Room ${newRoomId} does not exist`);
        err.statusCode = 404;
        throw err;
      }
      if (targetRoom.home_id !== homeId) {
        const err = new Error(`Target room ${newRoomId} does not belong to home ${homeId}`);
        err.statusCode = 400;
        throw err;
      }
      targetRoomName = targetRoom.name;
    }

    const oldRoomId = auth.room_id;
    await this.deviceRepo.updateDeviceAuthorization(deviceId, {
      roomId: newRoomId || null
    });

    if (this.activityLogRepo) {
      await this.activityLogRepo.createLog({
        id: `act_${crypto.randomUUID()}`,
        homeId,
        deviceId,
        eventType: 'device_moved',
        severity: 'info',
        message: targetRoomName ? `Device moved to room "${targetRoomName}"` : 'Device unassigned from room',
        correlationId: correlationId || `move_${deviceId}_${Date.now()}`,
        details: { oldRoomId, newRoomId, targetRoomName, movedBy: userId }
      });
    }

    if (this.realtimeEventBus) {
      this.realtimeEventBus.publish({
        homeId,
        type: 'device.updated',
        deviceId,
        payload: {
          deviceId,
          homeId,
          roomId: newRoomId,
          roomName: targetRoomName,
          action: 'moved',
          updatedAt: new Date().toISOString()
        }
      });
    }

    return {
      success: true,
      deviceId,
      roomId: newRoomId,
      roomName: targetRoomName,
      previousRoomId: oldRoomId
    };
  }

  // ---------------------------------------------------------------------------
  // 5. Remove Device from Home (Unclaim)
  // ---------------------------------------------------------------------------

  async removeDeviceFromHome({ homeId, deviceId, userId, correlationId = null }) {
    await this._assertAccess(userId, homeId, deviceId);

    const auth = await this.deviceRepo.getDeviceAuthorization(deviceId);
    if (!auth || auth.home_id !== homeId) {
      const err = new Error(`Device ${deviceId} is not assigned to home ${homeId}`);
      err.statusCode = 404;
      throw err;
    }

    // Unclaim authorization in DB
    await this.deviceRepo.removeDeviceAuthorization(deviceId);

    // Update connection state to OFFLINE
    try {
      await this.deviceStateRepo.updateDeviceConnection(deviceId, 'OFFLINE');
    } catch (_) {}

    if (this.activityLogRepo) {
      await this.activityLogRepo.createLog({
        id: `act_${crypto.randomUUID()}`,
        homeId,
        deviceId,
        eventType: 'device_removed',
        severity: 'warn',
        message: `Device removed from home by user ${userId}`,
        correlationId: correlationId || `remove_${deviceId}_${Date.now()}`,
        details: { removedBy: userId, previousHomeId: homeId }
      });
    }

    if (this.realtimeEventBus) {
      this.realtimeEventBus.publish({
        homeId,
        type: 'device.removed',
        deviceId,
        payload: {
          deviceId,
          homeId,
          action: 'removed',
          removedAt: new Date().toISOString()
        }
      });
    }

    return {
      success: true,
      deviceId,
      homeId,
      message: 'Device successfully removed from home'
    };
  }

  // ---------------------------------------------------------------------------
  // 6. Unified Health Calculation
  // ---------------------------------------------------------------------------

  async calculateDeviceHealth(deviceId, fullState = null) {
    const state = fullState || (await this.deviceStateRepo.getFullState(deviceId));
    if (!state) {
      return {
        status: HEALTH_STATUSES.UNKNOWN,
        connectionState: 'OFFLINE',
        lastSeenAt: null,
        uptimeSeconds: 0,
        successRate: 1.0,
        degradationReason: 'Device state not found'
      };
    }

    let metrics = null;
    if (this.healthRepo) {
      metrics = await this.healthRepo.findByDeviceId(deviceId);
    }

    const lastSeenMs = state.lastSeenAt ? new Date(state.lastSeenAt).getTime() : 0;
    const now = Date.now();
    const ageSeconds = lastSeenMs > 0 ? Math.floor((now - lastSeenMs) / 1000) : null;

    let status = HEALTH_STATUSES.UNKNOWN;
    let degradationReason = null;

    if (state.connectionState === 'OFFLINE') {
      status = HEALTH_STATUSES.OFFLINE;
    } else if (state.connectionState === 'STALE' || (ageSeconds && ageSeconds > 90)) {
      status = HEALTH_STATUSES.STALE;
      degradationReason = `No heartbeat received for ${ageSeconds}s`;
    } else if (state.connectionState === 'ONLINE') {
      const totalCmds = (metrics?.command_success_count || 0) + (metrics?.command_failure_count || 0);
      const failCount = metrics?.command_failure_count || 0;
      if (totalCmds >= 5 && failCount / totalCmds > 0.3) {
        status = HEALTH_STATUSES.DEGRADED;
        degradationReason = `High command failure rate (${failCount}/${totalCmds})`;
      } else {
        status = HEALTH_STATUSES.ONLINE;
      }
    }

    return {
      status,
      connectionState: state.connectionState,
      lastSeenAt: state.lastSeenAt,
      ageSeconds,
      rssi: metrics?.rssi ?? null,
      ipAddress: metrics?.ip_address ?? null,
      commandSuccessCount: metrics?.command_success_count ?? 0,
      commandFailureCount: metrics?.command_failure_count ?? 0,
      lastErrorMessage: metrics?.last_error_message ?? null,
      lastErrorAt: metrics?.last_error_at ?? null,
      degradationReason
    };
  }

  // ---------------------------------------------------------------------------
  // 7. Device Activity History
  // ---------------------------------------------------------------------------

  async getDeviceActivityHistory({ homeId, deviceId, userId, limit = 50, eventType = null }) {
    await this._assertAccess(userId, homeId, deviceId);

    if (!this.activityLogRepo) {
      return { data: [], total: 0 };
    }

    const logs = await this.activityLogRepo.findByDeviceId(deviceId, limit, eventType);
    return {
      data: logs,
      total: logs.length
    };
  }

  // ---------------------------------------------------------------------------
  // 8. Device Technical Diagnostics (Zero Secrets)
  // ---------------------------------------------------------------------------

  async getDeviceDiagnostics({ homeId, deviceId, userId }) {
    await this._assertAccess(userId, homeId, deviceId);

    const dev = await this.deviceRepo.getDevice(deviceId);
    if (!dev) {
      const err = new Error(`Device ${deviceId} not found`);
      err.statusCode = 404;
      throw err;
    }

    const fullState = await this.deviceStateRepo.getFullState(deviceId);
    const health = await this.calculateDeviceHealth(deviceId, fullState);

    // Get recent commands for command diagnostics
    let recentCommands = [];
    if (this.commandRepo && this.commandRepo.getCommandsByDevice) {
      recentCommands = await this.commandRepo.getCommandsByDevice(deviceId, 10);
    }

    return {
      deviceId: dev.id,
      serialNumber: dev.serial_number,
      productVariantId: dev.product_variant_id,
      hardwareRevision: dev.hardware_revision,
      firmwareFamily: dev.firmware_family,
      firmwareVersion: dev.firmware_version,
      health,
      channelCount: fullState?.channels?.length || 0,
      channelsState: fullState?.channels || [],
      commandDiagnostics: {
        totalExecuted: health.commandSuccessCount + health.commandFailureCount,
        successCount: health.commandSuccessCount,
        failureCount: health.commandFailureCount,
        lastCommandStatus: recentCommands[0]?.status || null,
        lastCommandAt: recentCommands[0]?.created_at || null
      },
      network: {
        connectionState: fullState?.connectionState || 'OFFLINE',
        lastSeenAt: fullState?.lastSeenAt || null,
        rssi: health.rssi,
        ipAddress: health.ipAddress,
        protocol: 'MQTT/TLS (mTLS)',
        port: 8883
      }
    };
  }
}

module.exports = { DeviceManagementService, HEALTH_STATUSES };
