'use strict';

/**
 * EH Home — Production Device Fleet Management & Safe OTA Rollout Engine (Phase 41)
 *
 * Primary Orchestrator for:
 * 1. Controlled, batched, percentage-based OTA rollout campaigns
 * 2. Deterministic cohort selection and concurrency-limited batch dispatching
 * 3. Pre-flight eligibility and operational readiness safety gates
 * 4. Multi-stage health verification lifecycle
 * 5. Automatic pause upon exceeding configured failure thresholds
 * 6. Cryptographically authorized, safe rollbacks to known-good releases
 * 7. Tamper-evident operational/security audit logging and admin notifications
 */

const crypto = require('crypto');
const { OtaRolloutPolicyService, ROLLOUT_STATES } = require('./ota-rollout-policy.service');
const { semverCompare } = require('./ota-eligibility.service');

class OtaRolloutService {
  /**
   * @param {Object} opts
   * @param {Object} opts.rolloutRepo               - OtaRolloutRepository
   * @param {Object} opts.firmwareReleaseService    - FirmwareReleaseService
   * @param {Object} opts.otaEligibilityService     - OtaEligibilityService
   * @param {Object} opts.fleetFirmwareService      - FleetFirmwareService
   * @param {Object} opts.fleetFirmwareRepo         - FleetFirmwareRepository
   * @param {Object} [opts.deviceRepo]              - DeviceRepository
   * @param {Object} [opts.commandService]           - DeviceCommandService (MQTT / Transport)
   * @param {Object} [opts.otaService]               - Existing OtaService (Phase 18)
   * @param {Object} [opts.operationsAuditService]  - OperationsAuditService (Phase 31)
   * @param {Object} [opts.notificationService]     - NotificationService (Phase 30)
   * @param {Object} [opts.realtimeEventBus]        - RealtimeEventBus
   */
  constructor({
    rolloutRepo,
    firmwareReleaseService,
    otaEligibilityService,
    fleetFirmwareService,
    fleetFirmwareRepo,
    deviceRepo = null,
    commandService = null,
    otaService = null,
    operationsAuditService = null,
    notificationService = null,
    realtimeEventBus = null
  }) {
    if (!rolloutRepo) throw new Error('rolloutRepo is required for OtaRolloutService');
    if (!firmwareReleaseService) throw new Error('firmwareReleaseService is required for OtaRolloutService');
    if (!otaEligibilityService) throw new Error('otaEligibilityService is required for OtaRolloutService');
    if (!fleetFirmwareService) throw new Error('fleetFirmwareService is required for OtaRolloutService');

    this.rolloutRepo = rolloutRepo;
    this.releaseService = firmwareReleaseService;
    this.eligibilityService = otaEligibilityService;
    this.fleetFirmwareService = fleetFirmwareService;
    this.fleetFirmwareRepo = fleetFirmwareRepo;
    this.deviceRepo = deviceRepo;
    this.commandService = commandService;
    this.otaService = otaService;
    this.auditService = operationsAuditService;
    this.notificationService = notificationService;
    this.eventBus = realtimeEventBus;

    // Tracking in-flight operations per rollout
    this._dispatchedDeviceIds = new Map(); // rolloutId -> Set of deviceIds
  }

  // ===========================================================================
  // 1. Rollout Creation & Lifecycle
  // ===========================================================================

  async createRollout({
    releaseId,
    productScope = null,
    channel = 'production',
    rolloutPercentage = 10,
    batchSize = 5,
    maxConcurrency = 3,
    failureThresholdPercentage = 20,
    failureThresholdCount = 3,
    targetFilters = {},
    actorUserId = null
  }) {
    const release = await this.releaseService.getRelease(releaseId);
    if (!release) {
      throw new Error(`Firmware release '${releaseId}' not found`);
    }
    if (release.status !== 'PUBLISHED') {
      throw new Error(`Cannot create rollout for release '${releaseId}' in status '${release.status}'. Release must be PUBLISHED.`);
    }

    const rolloutId = `rollout_${Date.now()}_${Math.random().toString(36).substring(2, 7)}`;
    const effectiveScope = productScope || release.productVariantId || release.product_variant_id;
    const effectiveChannel = channel || release.releaseChannel || release.release_channel || 'production';

    const rollout = await this.rolloutRepo.createRollout({
      id: rolloutId,
      releaseId,
      productScope: effectiveScope,
      channel: effectiveChannel,
      rolloutState: ROLLOUT_STATES.DRAFT,
      status: 'ACTIVE',
      rolloutPercentage: Math.max(1, Math.min(100, Number(rolloutPercentage))),
      batchSize: Math.max(1, Number(batchSize)),
      maxConcurrency: Math.max(1, Number(maxConcurrency)),
      failureThresholdPercentage: Math.max(1, Number(failureThresholdPercentage)),
      failureThresholdCount: Math.max(1, Number(failureThresholdCount)),
      targetFilters,
      statistics: {
        totalEligible: 0,
        totalTargeted: 0,
        inProgress: 0,
        installed: 0,
        bootVerified: 0,
        healthVerified: 0,
        failed: 0,
        rolledBack: 0
      }
    });

    if (this.auditService) {
      await this.auditService.logOperationalEvent({
        eventType: 'OTA_ROLLOUT_CREATED',
        source: 'ADMIN_API',
        actorUserId,
        resourceType: 'OTA_ROLLOUT',
        resourceId: rolloutId,
        metadata: {
          releaseId,
          productScope: effectiveScope,
          channel: effectiveChannel,
          rolloutPercentage
        }
      });
    }

    return rollout;
  }

  async startRollout(rolloutId, actorUserId = null) {
    const rollout = await this.rolloutRepo.findById(rolloutId);
    if (!rollout) throw new Error(`Rollout '${rolloutId}' not found`);

    OtaRolloutPolicyService.assertValidTransition(rollout.rolloutState, ROLLOUT_STATES.RUNNING, rolloutId);

    const now = new Date().toISOString();
    const updated = await this.rolloutRepo.updateRollout(rolloutId, {
      rolloutState: ROLLOUT_STATES.RUNNING,
      status: 'ACTIVE',
      startedAt: rollout.startedAt || now
    });

    if (this.auditService) {
      await this.auditService.logOperationalEvent({
        eventType: 'OTA_ROLLOUT_STARTED',
        source: 'ADMIN_API',
        actorUserId,
        resourceType: 'OTA_ROLLOUT',
        resourceId: rolloutId,
        metadata: { releaseId: rollout.release_id || rollout.releaseId, percentage: rollout.rolloutPercentage }
      });
    }

    if (this.notificationService) {
      await this.notificationService.createNotification({
        category: 'SYSTEM',
        priority: 'NORMAL',
        type: 'OTA_ROLLOUT_STARTED',
        title: 'Firmware Rollout Started',
        body: `Rollout ${rolloutId} is now RUNNING (${rollout.rolloutPercentage}% cohort)`,
        entityType: 'ota_rollout',
        entityId: rolloutId
      });
    }

    return updated;
  }

  async pauseRollout(rolloutId, reason = 'Operator paused', actorUserId = null) {
    const rollout = await this.rolloutRepo.findById(rolloutId);
    if (!rollout) throw new Error(`Rollout '${rolloutId}' not found`);

    OtaRolloutPolicyService.assertValidTransition(rollout.rolloutState, ROLLOUT_STATES.PAUSED, rolloutId);

    const now = new Date().toISOString();
    const updated = await this.rolloutRepo.updateRollout(rolloutId, {
      rolloutState: ROLLOUT_STATES.PAUSED,
      status: 'PAUSED',
      pausedAt: now
    });

    if (this.auditService) {
      await this.auditService.logOperationalEvent({
        eventType: 'OTA_ROLLOUT_PAUSED',
        source: 'ADMIN_API',
        actorUserId,
        resourceType: 'OTA_ROLLOUT',
        resourceId: rolloutId,
        metadata: { reason }
      });
    }

    if (this.notificationService) {
      await this.notificationService.createNotification({
        category: 'ALERT',
        priority: 'HIGH',
        type: 'OTA_ROLLOUT_PAUSED',
        title: 'Firmware Rollout Paused',
        body: `Rollout ${rolloutId} has been paused: ${reason}`,
        entityType: 'ota_rollout',
        entityId: rolloutId
      });
    }

    return updated;
  }

  async resumeRollout(rolloutId, actorUserId = null) {
    const rollout = await this.rolloutRepo.findById(rolloutId);
    if (!rollout) throw new Error(`Rollout '${rolloutId}' not found`);

    OtaRolloutPolicyService.assertValidTransition(rollout.rolloutState, ROLLOUT_STATES.RUNNING, rolloutId);

    const updated = await this.rolloutRepo.updateRollout(rolloutId, {
      rolloutState: ROLLOUT_STATES.RUNNING,
      status: 'ACTIVE'
    });

    if (this.auditService) {
      await this.auditService.logOperationalEvent({
        eventType: 'OTA_ROLLOUT_RESUMED',
        source: 'ADMIN_API',
        actorUserId,
        resourceType: 'OTA_ROLLOUT',
        resourceId: rolloutId,
        metadata: {}
      });
    }

    return updated;
  }

  async cancelRollout(rolloutId, reason = 'Operator cancelled', actorUserId = null) {
    const rollout = await this.rolloutRepo.findById(rolloutId);
    if (!rollout) throw new Error(`Rollout '${rolloutId}' not found`);

    OtaRolloutPolicyService.assertValidTransition(rollout.rolloutState, ROLLOUT_STATES.CANCELLED, rolloutId);

    const now = new Date().toISOString();
    const updated = await this.rolloutRepo.updateRollout(rolloutId, {
      rolloutState: ROLLOUT_STATES.CANCELLED,
      status: 'CANCELLED',
      completedAt: now
    });

    if (this.auditService) {
      await this.auditService.logOperationalEvent({
        eventType: 'OTA_ROLLOUT_CANCELLED',
        source: 'ADMIN_API',
        actorUserId,
        resourceType: 'OTA_ROLLOUT',
        resourceId: rolloutId,
        metadata: { reason }
      });
    }

    return updated;
  }

  // ===========================================================================
  // 2. Controlled Batch Execution
  // ===========================================================================

  /**
   * Execute next batch for an active rollout.
   * STRICT GUARD: NEVER bypasses eligibility, rollout state, concurrency, batching,
   * health verification, audit, or failure-threshold policy.
   */
  async executeBatch(rolloutId, { candidateDevices = null, actorUserId = null } = {}) {
    const rollout = await this.rolloutRepo.findById(rolloutId);
    if (!rollout) throw new Error(`Rollout '${rolloutId}' not found`);

    if (rollout.rolloutState !== ROLLOUT_STATES.RUNNING && rollout.rolloutState !== ROLLOUT_STATES.ROLLING_BACK) {
      throw new Error(`Cannot execute batch for rollout '${rolloutId}' in state '${rollout.rolloutState}'. Rollout must be RUNNING or ROLLING_BACK.`);
    }

    const release = await this.releaseService.getRelease(rollout.release_id || rollout.releaseId);
    if (!release) throw new Error(`Release '${rollout.release_id || rollout.releaseId}' not found`);

    // 1. Fetch candidate devices if not provided
    let pool = candidateDevices;
    if (!pool && this.deviceRepo) {
      pool = await this.deviceRepo.findDevices();
    }
    if (!pool || !Array.isArray(pool)) pool = [];

    // Filter candidate pool by product scope
    const productScope = rollout.productScope || rollout.product_scope;
    if (productScope) {
      pool = pool.filter(d => (d.product_variant_id || d.productVariantId) === productScope);
    }

    // 2. Evaluate eligibility for all candidate devices
    const eligibleDevices = [];
    const isRollback = rollout.rolloutState === ROLLOUT_STATES.ROLLING_BACK || (rollout.rollbackState && rollout.rollbackState.isRollback);

    for (const dev of pool) {
      const eligibility = await this.eligibilityService.evaluateEligibility({
        device: dev,
        release,
        rollout,
        isAuthorizedRollback: isRollback
      });

      if (eligibility.eligible) {
        eligibleDevices.push(dev);
      }
    }

    // 3. Deterministic cohort selection based on rollout percentage
    const percentage = rollout.rolloutPercentage || rollout.rollout_percentage || 100;
    const cohort = OtaRolloutPolicyService.selectCohort(eligibleDevices, percentage, rolloutId);

    // 4. Batch slicing & concurrency management
    if (!this._dispatchedDeviceIds.has(rolloutId)) {
      this._dispatchedDeviceIds.set(rolloutId, new Set());
    }
    const dispatchedSet = this._dispatchedDeviceIds.get(rolloutId);

    const batchSize = rollout.batchSize || rollout.batch_size || 5;
    const maxConcurrency = rollout.maxConcurrency || rollout.max_concurrency || 3;
    const activeCount = rollout.statistics ? (rollout.statistics.inProgress || 0) : 0;

    const batch = OtaRolloutPolicyService.getNextBatch({
      targetedDevices: cohort,
      dispatchedIds: dispatchedSet,
      batchSize,
      maxConcurrency,
      activeCount
    });

    const dispatchedResults = [];

    // 5. Dispatch OTA commands for batch
    for (const dev of batch) {
      const devId = dev.id || dev.deviceId;
      dispatchedSet.add(devId);

      const fromVer = dev.firmware_version || dev.firmwareVersion || '1.0.0';
      const targetVer = release.version;

      // Record in FleetFirmwareService
      await this.fleetFirmwareService.recordOtaRequested({
        deviceId: devId,
        productVariantId: dev.product_variant_id || dev.productVariantId,
        currentVersion: fromVer,
        targetVersion: targetVer,
        rolloutId
      });

      // Record OTA Attempt
      let attempt = null;
      if (this.fleetFirmwareRepo && typeof this.fleetFirmwareRepo.recordAttempt === 'function') {
        attempt = await this.fleetFirmwareRepo.recordAttempt({
          deviceId: devId,
          rolloutId,
          requestedVersion: targetVer,
          outcome: 'IN_PROGRESS',
          auditMetadata: { fromVersion: fromVer, targetVersion: targetVer, rolloutId }
        });
      }

      // Dispatch command via existing OtaService / CommandService if available
      if (this.otaService && typeof this.otaService.initiateOta === 'function') {
        try {
          const auth = this.deviceRepo ? await this.deviceRepo.getDeviceAuthorization(devId) : null;
          const homeId = auth ? auth.home_id : (dev.home_id || dev.homeId || 'default-home');
          await this.otaService.initiateOta({
            deviceId: devId,
            releaseId: release.id || release.releaseId,
            homeId,
            userId: actorUserId,
            isRecoveryOta: isRollback
          });
        } catch (err) {
          // Log dispatch failure and record failed attempt
          if (attempt && this.fleetFirmwareRepo) {
            await this.fleetFirmwareRepo.updateAttempt(attempt.id, {
              outcome: 'FAILED',
              reason: err.message,
              completedAt: new Date().toISOString()
            });
          }
          await this.fleetFirmwareService.recordOtaFailure({
            deviceId: devId,
            errorCode: 'DISPATCH_ERROR',
            errorMessage: err.message,
            isRollback
          });
        }
      }

      dispatchedResults.push({
        deviceId: devId,
        fromVersion: fromVer,
        targetVersion: targetVer,
        attemptId: attempt ? attempt.id : null,
        status: 'DISPATCHED'
      });
    }

    // 6. Update rollout stats
    const stats = rollout.statistics || {
      totalEligible: 0,
      totalTargeted: 0,
      inProgress: 0,
      installed: 0,
      bootVerified: 0,
      healthVerified: 0,
      failed: 0,
      rolledBack: 0
    };

    stats.totalEligible = eligibleDevices.length;
    stats.totalTargeted = cohort.length;
    stats.inProgress = (stats.inProgress || 0) + dispatchedResults.length;

    await this.rolloutRepo.updateRollout(rolloutId, { statistics: stats });

    if (this.auditService && dispatchedResults.length > 0) {
      await this.auditService.logOperationalEvent({
        eventType: 'OTA_BATCH_DISPATCHED',
        source: 'OTA_ROLLOUT_ENGINE',
        actorUserId,
        resourceType: 'OTA_ROLLOUT',
        resourceId: rolloutId,
        metadata: {
          batchCount: dispatchedResults.length,
          dispatchedDevices: dispatchedResults.map(r => r.deviceId)
        }
      });
    }

    return {
      rolloutId,
      rolloutState: rollout.rolloutState,
      totalEligible: eligibleDevices.length,
      totalTargeted: cohort.length,
      batchDispatchedCount: dispatchedResults.length,
      dispatched: dispatchedResults,
      statistics: stats
    };
  }

  // ===========================================================================
  // 3. Telemetry Handlers & Failure Threshold Auto-Pause
  // ===========================================================================

  async handleDeviceProgress({ deviceId, rolloutId, progressPercent, stage }) {
    await this.fleetFirmwareService.recordOtaDownloading({ deviceId, progressPercent });
  }

  async handleDeviceInstalled({ deviceId, rolloutId, installedVersion }) {
    await this.fleetFirmwareService.recordOtaInstalled({ deviceId, installedVersion });

    if (rolloutId) {
      const rollout = await this.rolloutRepo.findById(rolloutId);
      if (rollout && rollout.statistics) {
        const stats = { ...rollout.statistics };
        stats.inProgress = Math.max(0, (stats.inProgress || 1) - 1);
        stats.installed = (stats.installed || 0) + 1;
        await this.rolloutRepo.updateRollout(rolloutId, { statistics: stats });
      }
    }
  }

  async handleDeviceBootVerified({ deviceId, rolloutId, installedVersion }) {
    await this.fleetFirmwareService.recordBootVerified({ deviceId, installedVersion });

    if (rolloutId) {
      const rollout = await this.rolloutRepo.findById(rolloutId);
      if (rollout && rollout.statistics) {
        const stats = { ...rollout.statistics };
        stats.bootVerified = (stats.bootVerified || 0) + 1;
        await this.rolloutRepo.updateRollout(rolloutId, { statistics: stats });
      }
    }
  }

  async handleDeviceHealthVerified({ deviceId, rolloutId, attemptId = null }) {
    const res = await this.fleetFirmwareService.verifyDeviceHealth(deviceId);
    if (!res.verified) return res;

    if (attemptId && this.fleetFirmwareRepo) {
      await this.fleetFirmwareRepo.updateAttempt(attemptId, {
        outcome: 'HEALTH_VERIFIED',
        completedAt: new Date().toISOString()
      });
    }

    if (rolloutId) {
      const rollout = await this.rolloutRepo.findById(rolloutId);
      if (rollout && rollout.statistics) {
        const stats = { ...rollout.statistics };
        stats.healthVerified = (stats.healthVerified || 0) + 1;

        // Check completion condition
        if (stats.healthVerified >= stats.totalTargeted && stats.totalTargeted > 0) {
          await this.rolloutRepo.updateRollout(rolloutId, {
            rolloutState: ROLLOUT_STATES.COMPLETED,
            status: 'COMPLETED',
            statistics: stats,
            completedAt: new Date().toISOString()
          });

          if (this.notificationService) {
            await this.notificationService.createNotification({
              category: 'SYSTEM',
              priority: 'NORMAL',
              type: 'OTA_ROLLOUT_COMPLETED',
              title: 'Firmware Rollout Completed',
              body: `Rollout ${rolloutId} completed successfully across all targeted devices`,
              entityType: 'ota_rollout',
              entityId: rolloutId
            });
          }
        } else {
          await this.rolloutRepo.updateRollout(rolloutId, { statistics: stats });
        }
      }
    }

    return res;
  }

  async handleDeviceFailure({ deviceId, rolloutId, attemptId = null, errorCode, errorMessage, isRollback = false }) {
    await this.fleetFirmwareService.recordOtaFailure({ deviceId, errorCode, errorMessage, isRollback });

    if (attemptId && this.fleetFirmwareRepo) {
      await this.fleetFirmwareRepo.updateAttempt(attemptId, {
        outcome: isRollback ? 'ROLLED_BACK' : 'FAILED',
        reason: errorMessage || errorCode,
        completedAt: new Date().toISOString()
      });
    }

    if (rolloutId) {
      const rollout = await this.rolloutRepo.findById(rolloutId);
      if (rollout && rollout.statistics) {
        const stats = { ...rollout.statistics };
        stats.inProgress = Math.max(0, (stats.inProgress || 1) - 1);
        if (isRollback) {
          stats.rolledBack = (stats.rolledBack || 0) + 1;
        } else {
          stats.failed = (stats.failed || 0) + 1;
        }

        // Evaluate failure threshold auto-pause
        const failureEval = OtaRolloutPolicyService.evaluateFailureThreshold(rollout, stats);
        if (failureEval.shouldPause && rollout.rolloutState === ROLLOUT_STATES.RUNNING) {
          await this.rolloutRepo.updateRollout(rolloutId, {
            rolloutState: ROLLOUT_STATES.FAILED_THRESHOLD_PAUSED,
            status: 'PAUSED',
            statistics: stats,
            pausedAt: new Date().toISOString()
          });

          if (this.auditService) {
            await this.auditService.logSecurityAuditRecord({
              action: 'OTA_ROLLOUT_FAILURE_THRESHOLD_EXCEEDED',
              resourceType: 'OTA_ROLLOUT',
              resourceId: rolloutId,
              outcome: 'AUTO_PAUSED',
              payload: { reason: failureEval.reason, failureRate: failureEval.failureRate, stats }
            });
          }

          if (this.notificationService) {
            await this.notificationService.createNotification({
              category: 'ALERT',
              priority: 'URGENT',
              type: 'OTA_FAILURE_THRESHOLD_EXCEEDED',
              title: 'Firmware Rollout Auto-Paused: High Failure Rate',
              body: `Rollout ${rolloutId} automatically paused: ${failureEval.reason}`,
              entityType: 'ota_rollout',
              entityId: rolloutId
            });
          }
        } else {
          await this.rolloutRepo.updateRollout(rolloutId, { statistics: stats });
        }
      }
    }
  }

  // ===========================================================================
  // 4. Safe Authorized Rollback
  // ===========================================================================

  /**
   * Initiate a safe authorized rollback for a compromised or unhealthy rollout.
   *
   * ROLLBACK INVARIANT (Mandatory Addition 4):
   * Rollback is strictly NOT a generic downgrade.
   * The rollback target must be explicitly authorized, cryptographically signed and verified,
   * compatible with the product, trusted/valid, permitted by firmware security policy,
   * not revoked, and known-good according to release policy.
   */
  async initiateRollback({ rolloutId, targetReleaseId = null, reason = 'Operator initiated rollback', actorUserId = null }) {
    const rollout = await this.rolloutRepo.findById(rolloutId);
    if (!rollout) throw new Error(`Rollout '${rolloutId}' not found`);

    OtaRolloutPolicyService.assertValidTransition(rollout.rolloutState, ROLLOUT_STATES.ROLLING_BACK, rolloutId);

    const productScope = rollout.productScope || rollout.product_scope;
    const channel = rollout.channel || 'production';

    // Resolve authorized rollback release
    let rollbackRelease = null;
    if (targetReleaseId) {
      rollbackRelease = await this.releaseService.getRelease(targetReleaseId);
      if (!rollbackRelease) {
        throw new Error(`Specified rollback release '${targetReleaseId}' not found`);
      }
    } else {
      // Find previous known-good published release for product and channel (with version < target release version)
      const currentRelease = await this.releaseService.getRelease(rollout.release_id || rollout.releaseId);
      const currentVer = currentRelease ? currentRelease.version : '999.0.0';
      const releases = await this.releaseService.listReleases({ productVariantId: productScope, releaseChannel: channel });
      const published = releases.filter(r => {
        const isPub = r.status === 'PUBLISHED';
        const notSame = r.id !== (rollout.release_id || rollout.releaseId);
        const isLower = semverCompare(r.version, currentVer) < 0;
        return isPub && notSame && isLower;
      });
      published.sort((a, b) => semverCompare(b.version, a.version));
      rollbackRelease = published[0] || null;
    }

    if (!rollbackRelease) {
      throw new Error(`No authorized, known-good rollback release available for product '${productScope}' on channel '${channel}'`);
    }

    // Verify rollback release integrity & security policy
    const val = this.releaseService.validateArtifact(rollbackRelease);
    if (!val.valid) {
      throw new Error(`Rollback target '${rollbackRelease.id}' failed cryptographic/artifact validation: ${val.error}`);
    }
    if (rollbackRelease.status === 'REVOKED') {
      throw new Error(`Cannot rollback to REVOKED release '${rollbackRelease.id}'`);
    }

    const rollbackState = {
      isRollback: true,
      sourceRolloutId: rolloutId,
      targetReleaseId: rollbackRelease.id || rollbackRelease.releaseId,
      targetVersion: rollbackRelease.version,
      reason,
      initiatedBy: actorUserId,
      initiatedAt: new Date().toISOString()
    };

    const updated = await this.rolloutRepo.updateRollout(rolloutId, {
      rolloutState: ROLLOUT_STATES.ROLLING_BACK,
      status: 'ROLLING_BACK',
      rollbackState
    });

    if (this.auditService) {
      await this.auditService.logSecurityAuditRecord({
        actorUserId,
        action: 'OTA_ROLLBACK_INITIATED',
        resourceType: 'OTA_ROLLOUT',
        resourceId: rolloutId,
        outcome: 'SUCCESS',
        payload: {
          sourceRolloutId: rolloutId,
          targetReleaseId: rollbackRelease.id || rollbackRelease.releaseId,
          targetVersion: rollbackRelease.version,
          reason
        }
      });
    }

    if (this.notificationService) {
      await this.notificationService.createNotification({
        category: 'ALERT',
        priority: 'HIGH',
        type: 'OTA_ROLLBACK_INITIATED',
        title: 'Firmware Rollback Initiated',
        body: `Rollout ${rolloutId} rolling back to v${rollbackRelease.version}: ${reason}`,
        entityType: 'ota_rollout',
        entityId: rolloutId
      });
    }

    return {
      rolloutId,
      rolloutState: ROLLOUT_STATES.ROLLING_BACK,
      rollbackRelease,
      rollbackState
    };
  }

  async getRollout(rolloutId) {
    return this.rolloutRepo.findById(rolloutId);
  }

  async listRollouts(filters = {}) {
    return this.rolloutRepo.listRollouts(filters);
  }
}

module.exports = { OtaRolloutService };
