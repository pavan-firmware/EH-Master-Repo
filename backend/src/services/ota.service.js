'use strict';

/**
 * EH Home — Production Device Fleet Management & OTA Lifecycle Service (Phase 18)
 *
 * Layered on existing:
 *   - DeviceCommandService (MQTT / Transport)
 *   - DeviceStateRepository / DeviceHealth (Phase 11)
 *   - HomeAuthorizationService (Phase 16 RBAC)
 *   - RealtimeEventBus & SSE (Phase 7B)
 *   - NotificationService (Phase 15 Alerts)
 */

const crypto = require('crypto');

class OtaService {
  constructor(options = {}) {
    this.firmwareRepo = options.firmwareRepo || null;
    this.operationRepo = options.operationRepo || null;
    this.rolloutRepo = options.rolloutRepo || null;
    this.maintenanceRepo = options.maintenanceRepo || null;
    this.deviceRepo = options.deviceRepo || null;
    this.deviceStateRepo = options.deviceStateRepo || null;
    this.homeRepo = options.homeRepo || null;
    this.roomRepo = options.roomRepo || null;
    this.homeAuthService = options.homeAuthService || null;
    this.commandService = options.commandService || null;
    this.realtimeEventBus = options.realtimeEventBus || null;
    this.notificationService = options.notificationService || null;
    this.productCatalogService = options.productCatalogService || null;
    this.releases = new Map();
  }

  // ---------------------------------------------------------------------------
  // 1. Semver & Compatibility Utilities
  // ---------------------------------------------------------------------------

  semverCompare(v1, v2) {
    if (!v1 || !v2) return 0;
    const p1 = v1.replace(/^v/, '').split('.').map(Number);
    const p2 = v2.replace(/^v/, '').split('.').map(Number);
    for (let i = 0; i < 3; i++) {
      const num1 = p1[i] || 0;
      const num2 = p2[i] || 0;
      if (num1 > num2) return 1;
      if (num1 < num2) return -1;
    }
    return 0;
  }

  // ---------------------------------------------------------------------------
  // 2. Firmware Inventory & Release Management
  // ---------------------------------------------------------------------------

  registerRelease(manifest) {
    if (!manifest.productVariantId || !manifest.version || !manifest.downloadUrl || !manifest.sha256) {
      throw new Error('Invalid OTA manifest: productVariantId, version, downloadUrl, and sha256 are required');
    }

    const releaseId = manifest.id || manifest.releaseId || `rel_${Date.now()}_${Math.random().toString(36).substring(2, 7)}`;
    const fullManifest = {
      ...manifest,
      releaseId,
      id: releaseId,
      status: manifest.status || 'PUBLISHED',
      createdAt: manifest.createdAt || new Date().toISOString()
    };

    this.releases.set(releaseId, fullManifest);
    if (this.firmwareRepo) {
      this.firmwareRepo.createRelease(fullManifest);
    }
    return fullManifest;
  }

  getRelease(releaseId) {
    return this.releases.get(releaseId) || null;
  }

  async listReleases(filters = {}) {
    if (this.firmwareRepo) {
      return this.firmwareRepo.listReleases(filters);
    }
    let list = Array.from(this.releases.values());
    if (filters.productVariantId) {
      list = list.filter(r => (r.productVariantId || r.product_variant_id) === filters.productVariantId);
    }
    if (filters.releaseChannel) {
      list = list.filter(r => (r.releaseChannel || r.release_channel) === filters.releaseChannel);
    }
    return list;
  }

  // ---------------------------------------------------------------------------
  // 3. Compatibility Matrix Evaluation
  // ---------------------------------------------------------------------------

  checkUpdate({ productVariantId, hardwareRevision, currentVersion, releaseChannel = 'production' }) {
    if (!productVariantId || !currentVersion) {
      throw new Error('productVariantId and currentVersion are required');
    }

    const candidateReleases = Array.from(this.releases.values()).filter(r => {
      const pId = r.productVariantId || r.product_variant_id;
      const chan = r.releaseChannel || r.release_channel || 'production';
      const stat = r.status || 'PUBLISHED';
      return pId === productVariantId && chan === releaseChannel && stat === 'PUBLISHED';
    });

    const compatibleReleases = candidateReleases.filter(r => {
      if (hardwareRevision && r.hardware_revision && r.hardware_revision !== hardwareRevision) return false;
      if (hardwareRevision && r.hardwareRevision && r.hardwareRevision !== hardwareRevision) return false;
      const ver = r.version;
      if (this.semverCompare(ver, currentVersion) <= 0) return false;
      const minVer = r.min_firmware_version || r.minFirmwareVersion;
      if (minVer && this.semverCompare(currentVersion, minVer) < 0) return false;
      return true;
    });

    if (compatibleReleases.length === 0) {
      return { updateAvailable: false, release: null };
    }

    compatibleReleases.sort((a, b) => this.semverCompare(b.version, a.version));
    const bestRelease = compatibleReleases[0];

    return {
      updateAvailable: true,
      release: {
        releaseId: bestRelease.id || bestRelease.releaseId,
        productVariantId: bestRelease.product_variant_id || bestRelease.productVariantId,
        version: bestRelease.version,
        minFirmwareVersion: bestRelease.min_firmware_version || bestRelease.minFirmwareVersion,
        releaseChannel: bestRelease.release_channel || bestRelease.releaseChannel || 'production',
        downloadUrl: bestRelease.download_url || bestRelease.downloadUrl,
        sha256: bestRelease.sha256,
        ed25519Signature: bestRelease.ed25519_signature || bestRelease.ed25519Signature,
        releaseNotes: bestRelease.release_notes || bestRelease.releaseNotes
      }
    };
  }

  async queryUpdate({ deviceId, productVariantId, hardwareRevision, currentVersion, releaseChannel = 'production' }) {
    return this.checkUpdate({ productVariantId, hardwareRevision, currentVersion, releaseChannel });
  }

  // ---------------------------------------------------------------------------
  // 4. Device Fleet Status & Inventory
  // ---------------------------------------------------------------------------

  async getFleetStatus({ homeId, userId }) {
    if (this.homeAuthService && homeId && userId) {
      await this.homeAuthService.requireMembership(userId, homeId);
    }

    let authorizations = [];
    if (this.deviceRepo) {
      if (homeId) {
        authorizations = await this.deviceRepo.getAuthorizationsByHome(homeId);
      } else if (userId && this.homeRepo) {
        const memberships = await this.homeRepo.getMembershipsForUser(userId);
        for (const m of memberships) {
          const auths = await this.deviceRepo.getAuthorizationsByHome(m.home_id);
          authorizations.push(...auths);
        }
      }
    }

    const devices = [];
    let onlineCount = 0;
    let offlineCount = 0;
    let staleCount = 0;
    let degradedCount = 0;
    let otaAvailableCount = 0;
    let otaInProgressCount = 0;
    let otaFailedCount = 0;

    for (const auth of authorizations) {
      const dev = await this.deviceRepo.getDevice(auth.device_id);
      if (!dev) continue;

      let state = null;
      if (this.deviceStateRepo) {
        state = await this.deviceStateRepo.getFullState(auth.device_id);
      }

      const connectionState = state ? state.connectionState : 'OFFLINE';
      if (connectionState === 'ONLINE') onlineCount++;
      else if (connectionState === 'STALE') staleCount++;
      else offlineCount++;

      const currentVer = dev.firmware_version || '1.0.0';
      const updateCheck = await this.checkUpdate({
        productVariantId: dev.product_variant_id,
        hardwareRevision: dev.hardware_revision,
        currentVersion: currentVer
      });

      let activeOp = null;
      if (this.operationRepo) {
        activeOp = await this.operationRepo.findActiveByDeviceId(auth.device_id);
      }

      let otaStatus = null;
      if (activeOp) {
        otaStatus = activeOp.status;
        if (['QUEUED', 'DOWNLOADING', 'VERIFYING', 'INSTALLING', 'REBOOTING', 'CONFIRMING'].includes(activeOp.status)) {
          otaInProgressCount++;
        } else if (['FAILED', 'ROLLED_BACK'].includes(activeOp.status)) {
          otaFailedCount++;
        }
      } else if (updateCheck.updateAvailable) {
        otaAvailableCount++;
        otaStatus = 'AVAILABLE';
      }

      devices.push({
        deviceId: dev.id,
        serialNumber: dev.serial_number,
        productVariantId: dev.product_variant_id,
        hardwareRevision: dev.hardware_revision,
        firmwareFamily: dev.firmware_family,
        firmwareVersion: currentVer,
        customName: auth.custom_name || dev.serial_number,
        homeId: auth.home_id,
        roomId: auth.room_id,
        healthStatus: connectionState === 'ONLINE' ? 'HEALTHY' : (connectionState === 'STALE' ? 'STALE' : 'OFFLINE'),
        connectionState,
        lastSeenAt: state ? state.lastSeenAt : null,
        otaStatus,
        availableUpdate: updateCheck.updateAvailable ? updateCheck.release : null
      });
    }

    return {
      schemaVersion: 1,
      homeId: homeId || null,
      totalDevices: devices.length,
      onlineDevices: onlineCount,
      offlineDevices: offlineCount,
      staleDevices: staleCount,
      degradedDevices: degradedCount,
      otaUpdateAvailableCount: otaAvailableCount,
      otaInProgressCount: otaInProgressCount,
      otaFailedCount: otaFailedCount,
      devices
    };
  }

  // ---------------------------------------------------------------------------
  // 5. OTA Lifecycle Operations
  // ---------------------------------------------------------------------------

  async initiateOta({ deviceId, releaseId, homeId, userId }) {
    if (this.homeAuthService) {
      await this.homeAuthService.requireMembership(userId, homeId, null, 'canManageDevices');
    }

    const dev = await this.deviceRepo.getDevice(deviceId);
    if (!dev) throw new Error(`Device ${deviceId} not found`);

    const auth = await this.deviceRepo.getDeviceAuthorization(deviceId);
    if (!auth || auth.home_id !== homeId) {
      throw new Error(`Device ${deviceId} is not assigned to home ${homeId}`);
    }

    const release = await this.getRelease(releaseId);
    if (!release) throw new Error(`Firmware release ${releaseId} not found`);

    // Verify compatibility
    if (release.product_variant_id && release.product_variant_id !== dev.product_variant_id) {
      throw new Error(`Incompatible product variant: Release is for ${release.product_variant_id}, device is ${dev.product_variant_id}`);
    }
    if (release.hardware_revision && dev.hardware_revision && release.hardware_revision !== dev.hardware_revision) {
      throw new Error(`Incompatible hardware revision: Release is for ${release.hardware_revision}, device is ${dev.hardware_revision}`);
    }

    const currentVersion = dev.firmware_version || '1.0.0';
    const targetVersion = release.version;

    // Check minimum bridge version
    const minVer = release.min_firmware_version || release.minFirmwareVersion;
    if (minVer && this.semverCompare(currentVersion, minVer) < 0) {
      throw new Error(`Cannot upgrade to ${targetVersion}: Device is at ${currentVersion}, minimum required is ${minVer}`);
    }

    // Check active operation
    if (this.operationRepo) {
      const active = await this.operationRepo.findActiveByDeviceId(deviceId);
      if (active) {
        throw new Error(`Device ${deviceId} already has an active OTA operation ${active.id} in status ${active.status}`);
      }
    }

    const opId = `ota_op_${Date.now()}_${Math.random().toString(36).substring(2, 7)}`;
    let operation = null;

    if (this.operationRepo) {
      operation = await this.operationRepo.createOperation({
        id: opId,
        deviceId,
        homeId,
        releaseId,
        fromVersion: currentVersion,
        targetVersion,
        status: 'DOWNLOADING',
        progressPercent: 5,
        initiatedByUserId: userId
      });
    }

    // Dispatch OTA command via existing DeviceCommandService
    if (this.commandService) {
      await this.commandService.sendCommand(
        { userId, homeId },
        {
          commandId: crypto.randomUUID(),
          deviceId,
          channelIndex: 1,
          action: 'otaUpdate',
          params: {
            operationId: opId,
            releaseId,
            version: targetVersion,
            downloadUrl: release.download_url || release.downloadUrl,
            sha256: release.sha256,
            ed25519Signature: release.ed25519_signature || release.ed25519Signature
          },
          idempotencyKey: opId,
          source: 'APP'
        }
      );
    }

    // Maintenance log
    if (this.maintenanceRepo) {
      await this.maintenanceRepo.logMaintenance({
        deviceId,
        homeId,
        operationType: 'FIRMWARE_UPGRADE',
        releaseId,
        fromVersion: currentVersion,
        toVersion: targetVersion,
        status: 'IN_PROGRESS',
        details: { operationId: opId, initiatedBy: userId }
      });
    }

    // Realtime event
    if (this.realtimeEventBus) {
      this.realtimeEventBus.publish({
        type: 'ota.started',
        homeId,
        deviceId,
        payload: { operationId: opId, releaseId, fromVersion: currentVersion, targetVersion }
      });
    }

    // Notification
    if (this.notificationService) {
      await this.notificationService.createNotification({
        homeId,
        category: 'SYSTEM',
        priority: 'NORMAL',
        type: 'OTA_STARTED',
        title: 'Firmware Update Started',
        body: `Updating ${auth.custom_name || dev.serial_number} to v${targetVersion}`,
        entityType: 'device',
        entityId: deviceId
      });
    }

    return operation || { id: opId, deviceId, homeId, releaseId, status: 'DOWNLOADING', targetVersion };
  }

  async handleOtaProgress({ deviceId, operationId, progressPercent, stage }) {
    if (this.operationRepo && operationId) {
      await this.operationRepo.updateProgress(operationId, {
        status: stage || 'INSTALLING',
        progressPercent: progressPercent || 50
      });
    }

    if (this.realtimeEventBus) {
      const auth = this.deviceRepo ? await this.deviceRepo.getDeviceAuthorization(deviceId) : null;
      this.realtimeEventBus.publish({
        type: 'ota.progress',
        homeId: auth ? auth.home_id : null,
        deviceId,
        payload: { operationId, progressPercent, stage }
      });
    }
  }

  async handleOtaSuccess({ deviceId, operationId, installedVersion }) {
    const auth = this.deviceRepo ? await this.deviceRepo.getDeviceAuthorization(deviceId) : null;
    const homeId = auth ? auth.home_id : null;

    if (this.operationRepo && operationId) {
      await this.operationRepo.updateProgress(operationId, {
        status: 'SUCCESS',
        progressPercent: 100,
        completedAt: new Date().toISOString()
      });
    }

    if (this.deviceRepo && installedVersion) {
      await this.deviceRepo.updateDeviceFirmwareVersion(deviceId, installedVersion);
    }

    if (this.maintenanceRepo && homeId) {
      await this.maintenanceRepo.logMaintenance({
        deviceId,
        homeId,
        operationType: 'FIRMWARE_UPGRADE',
        toVersion: installedVersion,
        status: 'SUCCESS',
        details: { operationId }
      });
    }

    if (this.realtimeEventBus) {
      this.realtimeEventBus.publish({
        type: 'ota.success',
        homeId,
        deviceId,
        payload: { operationId, installedVersion }
      });
    }

    if (this.notificationService && homeId) {
      await this.notificationService.createNotification({
        homeId,
        category: 'SYSTEM',
        priority: 'NORMAL',
        type: 'OTA_SUCCESS',
        title: 'Firmware Update Succeeded',
        body: `Device ${deviceId} successfully updated to v${installedVersion}`,
        entityType: 'device',
        entityId: deviceId
      });
    }
  }

  async handleOtaFailure({ deviceId, operationId, errorCode, errorMessage, isRollback = false }) {
    const auth = this.deviceRepo ? await this.deviceRepo.getDeviceAuthorization(deviceId) : null;
    const homeId = auth ? auth.home_id : null;
    const status = isRollback ? 'ROLLED_BACK' : 'FAILED';

    if (this.operationRepo && operationId) {
      await this.operationRepo.updateProgress(operationId, {
        status,
        errorCode,
        errorMessage,
        completedAt: new Date().toISOString()
      });
    }

    if (this.maintenanceRepo && homeId) {
      await this.maintenanceRepo.logMaintenance({
        deviceId,
        homeId,
        operationType: isRollback ? 'FIRMWARE_ROLLBACK' : 'FIRMWARE_UPGRADE',
        status,
        details: { operationId, errorCode, errorMessage }
      });
    }

    if (this.realtimeEventBus) {
      this.realtimeEventBus.publish({
        type: isRollback ? 'ota.rolled_back' : 'ota.failed',
        homeId,
        deviceId,
        payload: { operationId, errorCode, errorMessage, status }
      });
    }

    if (this.notificationService && homeId) {
      await this.notificationService.createNotification({
        homeId,
        category: 'ALERT',
        priority: 'HIGH',
        type: isRollback ? 'OTA_ROLLED_BACK' : 'OTA_FAILED',
        title: isRollback ? 'Firmware Rollback Detected' : 'Firmware Update Failed',
        body: `Device ${deviceId} update failed: ${errorMessage || errorCode || 'Unknown error'}`,
        entityType: 'device',
        entityId: deviceId
      });
    }
  }

  // ---------------------------------------------------------------------------
  // 6. Maintenance Logs & History
  // ---------------------------------------------------------------------------

  async getMaintenanceHistory({ deviceId, homeId, userId }) {
    if (this.homeAuthService && homeId && userId) {
      await this.homeAuthService.requireMembership(userId, homeId);
    }

    if (deviceId && this.maintenanceRepo) {
      return this.maintenanceRepo.findByDeviceId(deviceId);
    }
    if (homeId && this.maintenanceRepo) {
      return this.maintenanceRepo.findByHomeId(homeId);
    }
    return [];
  }
}

module.exports = { OtaService };
