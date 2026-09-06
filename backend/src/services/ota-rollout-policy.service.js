'use strict';

/**
 * EH Home — OTA Rollout Policy & Execution State Machine Service (Phase 41)
 *
 * Implements:
 * 1. Strict Rollout State Machine with explicit transitions
 * 2. Deterministic cohort selection (stable hashing per device + rollout)
 * 3. Batch progression & concurrency control
 * 4. Automatic failure threshold monitoring & auto-pause
 */

const crypto = require('crypto');

const ROLLOUT_STATES = Object.freeze({
  DRAFT: 'DRAFT',
  SCHEDULED: 'SCHEDULED',
  RUNNING: 'RUNNING',
  PAUSED: 'PAUSED',
  COMPLETED: 'COMPLETED',
  CANCELLED: 'CANCELLED',
  FAILED_THRESHOLD_PAUSED: 'FAILED_THRESHOLD_PAUSED',
  ROLLING_BACK: 'ROLLING_BACK',
  ROLLED_BACK: 'ROLLED_BACK'
});

const LEGAL_TRANSITIONS = {
  [ROLLOUT_STATES.DRAFT]: [ROLLOUT_STATES.SCHEDULED, ROLLOUT_STATES.RUNNING, ROLLOUT_STATES.CANCELLED],
  [ROLLOUT_STATES.SCHEDULED]: [ROLLOUT_STATES.RUNNING, ROLLOUT_STATES.CANCELLED],
  [ROLLOUT_STATES.RUNNING]: [
    ROLLOUT_STATES.PAUSED,
    ROLLOUT_STATES.COMPLETED,
    ROLLOUT_STATES.CANCELLED,
    ROLLOUT_STATES.FAILED_THRESHOLD_PAUSED,
    ROLLOUT_STATES.ROLLING_BACK
  ],
  [ROLLOUT_STATES.PAUSED]: [ROLLOUT_STATES.RUNNING, ROLLOUT_STATES.CANCELLED, ROLLOUT_STATES.ROLLING_BACK],
  [ROLLOUT_STATES.FAILED_THRESHOLD_PAUSED]: [
    ROLLOUT_STATES.PAUSED,
    ROLLOUT_STATES.RUNNING,
    ROLLOUT_STATES.CANCELLED,
    ROLLOUT_STATES.ROLLING_BACK
  ],
  [ROLLOUT_STATES.ROLLING_BACK]: [
    ROLLOUT_STATES.ROLLED_BACK,
    ROLLOUT_STATES.FAILED_THRESHOLD_PAUSED,
    ROLLOUT_STATES.CANCELLED
  ],
  [ROLLOUT_STATES.COMPLETED]: [ROLLOUT_STATES.ROLLING_BACK],
  [ROLLOUT_STATES.CANCELLED]: [],
  [ROLLOUT_STATES.ROLLED_BACK]: []
};

class OtaRolloutPolicyService {
  // ===========================================================================
  // 1. State Machine
  // ===========================================================================

  static isValidTransition(currentState, targetState) {
    const legal = LEGAL_TRANSITIONS[currentState] || [];
    return legal.includes(targetState);
  }

  static assertValidTransition(currentState, targetState, rolloutId = '') {
    if (!OtaRolloutPolicyService.isValidTransition(currentState, targetState)) {
      throw new Error(
        `Illegal rollout state transition for ${rolloutId || 'rollout'}: Cannot transition from '${currentState}' to '${targetState}'. Legal transitions: [${(LEGAL_TRANSITIONS[currentState] || []).join(', ')}]`
      );
    }
  }

  // ===========================================================================
  // 2. Deterministic Cohort Selection
  // ===========================================================================

  /**
   * Deterministically select a cohort of devices for a rollout percentage.
   *
   * Uses SHA-256 hash modulo 100 for true deterministic, pseudo-random cohort distribution
   * that guarantees the same devices are selected for the same rollout ID and percentage.
   *
   * @param {Array<Object>} devices - Array of eligible device records
   * @param {number} percentage     - Rollout percentage (1 to 100)
   * @param {string} rolloutId      - Unique rollout identifier
   * @returns {Array<Object>} Selected subset of devices
   */
  static selectCohort(devices = [], percentage = 100, rolloutId = 'default') {
    if (!Array.isArray(devices) || devices.length === 0) return [];
    if (percentage >= 100) return [...devices];
    if (percentage <= 0) return [];

    // Sort devices deterministically by deviceId first
    const sorted = [...devices].sort((a, b) => {
      const idA = a.id || a.deviceId || '';
      const idB = b.id || b.deviceId || '';
      return idA.localeCompare(idB);
    });

    return sorted.filter(dev => {
      const id = dev.id || dev.deviceId;
      const hash = crypto.createHash('sha256').update(`${rolloutId}:${id}`).digest('hex');
      const bucket = parseInt(hash.substring(0, 4), 16) % 100;
      return bucket < percentage;
    });
  }

  // ===========================================================================
  // 3. Batch Progression & Concurrency Limits
  // ===========================================================================

  /**
   * Determine the next batch of devices to dispatch given concurrency limits.
   *
   * @param {Object} params
   * @param {Array<Object>} params.targetedDevices   - All targeted devices in cohort
   * @param {Set<string>|Array<string>} params.dispatchedIds - IDs of devices already dispatched
   * @param {number} params.batchSize                - Max batch size
   * @param {number} params.maxConcurrency           - Max active operations
   * @param {number} params.activeCount              - Currently active operations
   * @returns {Array<Object>} Devices to dispatch in this execution cycle
   */
  static getNextBatch({
    targetedDevices = [],
    dispatchedIds = new Set(),
    batchSize = 5,
    maxConcurrency = 3,
    activeCount = 0
  }) {
    const dispatchedSet = dispatchedIds instanceof Set ? dispatchedIds : new Set(dispatchedIds);
    const pendingDevices = targetedDevices.filter(d => !dispatchedSet.has(d.id || d.deviceId));

    const availableSlots = Math.max(0, maxConcurrency - activeCount);
    const countToTake = Math.min(batchSize, availableSlots, pendingDevices.length);

    return pendingDevices.slice(0, countToTake);
  }

  // ===========================================================================
  // 4. Failure Threshold Evaluation
  // ===========================================================================

  /**
   * Evaluate whether a rollout has exceeded failure limits and must auto-pause.
   *
   * @param {Object} rollout - Rollout config
   * @param {Object} stats   - Current statistics
   * @returns {{ shouldPause: boolean, reason: string|null, failureRate: number }}
   */
  static evaluateFailureThreshold(rollout, stats = {}) {
    const thresholdPercentage = Number(rollout.failureThresholdPercentage || rollout.failure_threshold_percentage || 20);
    const thresholdCount = Number(rollout.failureThresholdCount || rollout.failure_threshold_count || 3);

    const failed = Number(stats.failed || 0);
    const installed = Number(stats.installed || 0);
    const healthVerified = Number(stats.healthVerified || 0);
    const totalAttempted = failed + installed + healthVerified;

    if (totalAttempted === 0) {
      return { shouldPause: false, reason: null, failureRate: 0 };
    }

    const failureRate = (failed / totalAttempted) * 100;

    if (failed >= thresholdCount && failureRate >= thresholdPercentage) {
      return {
        shouldPause: true,
        reason: `Failure threshold exceeded: ${failed} failed out of ${totalAttempted} attempted (${failureRate.toFixed(1)}% >= ${thresholdPercentage}%, count ${failed} >= ${thresholdCount})`,
        failureRate
      };
    }

    return { shouldPause: false, reason: null, failureRate };
  }
}

module.exports = {
  OtaRolloutPolicyService,
  ROLLOUT_STATES,
  LEGAL_TRANSITIONS
};
