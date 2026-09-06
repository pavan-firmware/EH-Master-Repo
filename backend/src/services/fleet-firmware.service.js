'use strict';

/**
 * EH Home — Fleet Firmware State & Health Verification Service (Phase 41)
 *
 * Implements:
 * 1. Authoritative device firmware state tracking (current/target version, rolloutId, rolloutState)
 * 2. Multi-stage Post-OTA verification pipeline:
 *    PENDING -> REQUESTED -> DOWNLOADING -> INSTALLED -> BOOT_VERIFIED -> HEALTH_VERIFIED (or FAILED)
 * 3. Device health integration via DeviceStateRepository and Telemetry authority
 */

const HEALTH_VERIFICATION_STATES = Object.freeze({
  PENDING: 'PENDING',
  REQUESTED: 'REQUESTED',
  DOWNLOADING: 'DOWNLOADING',
  INSTALLED: 'INSTALLED',
  BOOT_VERIFIED: 'BOOT_VERIFIED',
  HEALTH_VERIFIED: 'HEALTH_VERIFIED',
  FAILED: 'FAILED'
});

class FleetFirmwareService {
  /**
   * @param {Object} opts
   * @param {Object} opts.fleetFirmwareRepo         - FleetFirmwareRepository
   * @param {Object} [opts.deviceRepo]              - DeviceRepository
   * @param {Object} [opts.deviceStateRepo]         - DeviceStateRepository
   * @param {Object} [opts.operationsAuditService]  - OperationsAuditService
   * @param {Object} [opts.notificationService]     - NotificationService
   */
  constructor({
    fleetFirmwareRepo,
    deviceRepo = null,
    deviceStateRepo = null,
    operationsAuditService = null,
    notificationService = null
  }) {
    if (!fleetFirmwareRepo) throw new Error('fleetFirmwareRepo is required for FleetFirmwareService');
    this.fleetFirmwareRepo = fleetFirmwareRepo;
    this.deviceRepo = deviceRepo;
    this.deviceStateRepo = deviceStateRepo;
    this.auditService = operationsAuditService;
    this.notificationService = notificationService;
  }

  // ===========================================================================
  // 1. Device Firmware State Management
  // ===========================================================================

  async recordOtaRequested({ deviceId, productVariantId, currentVersion, targetVersion, rolloutId }) {
    return this.fleetFirmwareRepo.upsertDeviceFirmwareState({
      deviceId,
      productVariantId,
      currentFirmwareVersion: currentVersion,
      targetFirmwareVersion: targetVersion,
      rolloutId,
      rolloutState: 'RUNNING',
      lastOtaResult: 'IN_PROGRESS',
      lastAttemptAt: new Date().toISOString(),
      healthVerificationState: HEALTH_VERIFICATION_STATES.REQUESTED
    });
  }

  async recordOtaDownloading({ deviceId, progressPercent }) {
    const existing = await this.fleetFirmwareRepo.getDeviceFirmwareState(deviceId);
    if (!existing) return null;

    return this.fleetFirmwareRepo.upsertDeviceFirmwareState({
      deviceId,
      productVariantId: existing.product_variant_id || existing.productVariantId,
      currentFirmwareVersion: existing.current_firmware_version || existing.currentFirmwareVersion,
      targetFirmwareVersion: existing.target_firmware_version || existing.targetFirmwareVersion,
      rolloutId: existing.rollout_id || existing.rolloutId,
      rolloutState: existing.rollout_state || existing.rolloutState,
      lastOtaResult: `DOWNLOADING_${progressPercent}%`,
      lastAttemptAt: existing.last_attempt_at || existing.lastAttemptAt,
      healthVerificationState: HEALTH_VERIFICATION_STATES.DOWNLOADING
    });
  }

  async recordOtaInstalled({ deviceId, installedVersion }) {
    const existing = await this.fleetFirmwareRepo.getDeviceFirmwareState(deviceId);
    const productVariantId = existing ? (existing.product_variant_id || existing.productVariantId) : 'unknown';
    const rolloutId = existing ? (existing.rollout_id || existing.rolloutId) : null;

    // Update DeviceRepository canonical firmware version if available
    if (this.deviceRepo && typeof this.deviceRepo.updateDeviceFirmwareVersion === 'function') {
      await this.deviceRepo.updateDeviceFirmwareVersion(deviceId, installedVersion);
    }

    return this.fleetFirmwareRepo.upsertDeviceFirmwareState({
      deviceId,
      productVariantId,
      currentFirmwareVersion: installedVersion,
      targetFirmwareVersion: installedVersion,
      rolloutId,
      rolloutState: 'RUNNING',
      lastOtaResult: 'INSTALLED',
      lastAttemptAt: new Date().toISOString(),
      healthVerificationState: HEALTH_VERIFICATION_STATES.INSTALLED
    });
  }

  async recordBootVerified({ deviceId, installedVersion }) {
    const existing = await this.fleetFirmwareRepo.getDeviceFirmwareState(deviceId);
    if (!existing) return null;

    return this.fleetFirmwareRepo.upsertDeviceFirmwareState({
      deviceId,
      productVariantId: existing.product_variant_id || existing.productVariantId,
      currentFirmwareVersion: installedVersion || existing.current_firmware_version || existing.currentFirmwareVersion,
      targetFirmwareVersion: existing.target_firmware_version || existing.targetFirmwareVersion,
      rolloutId: existing.rollout_id || existing.rolloutId,
      rolloutState: existing.rollout_state || existing.rolloutState,
      lastOtaResult: 'BOOT_VERIFIED',
      lastAttemptAt: existing.last_attempt_at || existing.lastAttemptAt,
      healthVerificationState: HEALTH_VERIFICATION_STATES.BOOT_VERIFIED
    });
  }

  async verifyDeviceHealth(deviceId, { telemetryFreshness = true, connectionState = 'ONLINE' } = {}) {
    let state = null;
    if (this.deviceStateRepo) {
      state = await this.deviceStateRepo.getFullState(deviceId);
    }

    const conn = state ? (state.connectionState || 'OFFLINE') : connectionState;
    const isHealthy = conn === 'ONLINE' && telemetryFreshness;

    if (!isHealthy) {
      return {
        verified: false,
        state: HEALTH_VERIFICATION_STATES.BOOT_VERIFIED,
        reason: `Device ${deviceId} connection is ${conn} or telemetry is not fresh`
      };
    }

    const existing = await this.fleetFirmwareRepo.getDeviceFirmwareState(deviceId);
    if (existing) {
      await this.fleetFirmwareRepo.upsertDeviceFirmwareState({
        deviceId,
        productVariantId: existing.product_variant_id || existing.productVariantId,
        currentFirmwareVersion: existing.current_firmware_version || existing.currentFirmwareVersion,
        targetFirmwareVersion: existing.target_firmware_version || existing.targetFirmwareVersion,
        rolloutId: existing.rollout_id || existing.rolloutId,
        rolloutState: 'COMPLETED',
        lastOtaResult: 'HEALTH_VERIFIED',
        lastAttemptAt: existing.last_attempt_at || existing.lastAttemptAt,
        healthVerificationState: HEALTH_VERIFICATION_STATES.HEALTH_VERIFIED
      });
    }

    return { verified: true, state: HEALTH_VERIFICATION_STATES.HEALTH_VERIFIED };
  }

  async recordOtaFailure({ deviceId, errorCode, errorMessage, isRollback = false }) {
    const existing = await this.fleetFirmwareRepo.getDeviceFirmwareState(deviceId);
    const productVariantId = existing ? (existing.product_variant_id || existing.productVariantId) : 'unknown';
    const currentVersion = existing ? (existing.current_firmware_version || existing.currentFirmwareVersion) : '1.0.0';
    const rolloutId = existing ? (existing.rollout_id || existing.rolloutId) : null;

    return this.fleetFirmwareRepo.upsertDeviceFirmwareState({
      deviceId,
      productVariantId,
      currentFirmwareVersion: currentVersion,
      targetFirmwareVersion: existing ? (existing.target_firmware_version || existing.targetFirmwareVersion) : null,
      rolloutId,
      rolloutState: isRollback ? 'ROLLED_BACK' : 'FAILED',
      lastOtaResult: isRollback ? 'ROLLED_BACK' : 'FAILED',
      lastAttemptAt: new Date().toISOString(),
      failureReason: errorMessage || errorCode || 'Unknown error',
      healthVerificationState: HEALTH_VERIFICATION_STATES.FAILED
    });
  }

  async getDeviceFirmwareState(deviceId) {
    return this.fleetFirmwareRepo.getDeviceFirmwareState(deviceId);
  }

  async listFleetFirmwareStates(filters = {}) {
    return this.fleetFirmwareRepo.listDeviceFirmwareStates(filters);
  }
}

module.exports = { FleetFirmwareService, HEALTH_VERIFICATION_STATES };
