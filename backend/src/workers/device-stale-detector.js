'use strict';

/**
 * EH Home — Device STALE Heartbeat Detector (Phase 7B)
 *
 * Responsibilities:
 * - Scan devices for lastSeenAt older than STALE_THRESHOLD_MS
 * - Transition device connection state to STALE (backend-only; never MQTT)
 * - Emit device.availability realtime event for each newly STALE device
 *
 * Contract:
 * - Does NOT send MQTT LWT or MQTT state
 * - Does NOT modify channel states
 * - Interval and threshold are configurable
 * - tick() is idempotent (safe to call repeatedly)
 * - Dependency-injected for testability
 */

const DEFAULT_STALE_THRESHOLD_MS = 45_000;  // 45 seconds
const DEVICE_AVAILABILITY_EVENT = 'device.availability';

class DeviceStaleDetector {
  /**
   * @param {Object} opts
   * @param {Object}           opts.db              DbClient instance (find, update)
   * @param {RealtimeEventBus} opts.eventBus
   * @param {number}           [opts.staleThresholdMs]
   */
  constructor({ db, eventBus, staleThresholdMs = DEFAULT_STALE_THRESHOLD_MS }) {
    this.db = db;
    this.eventBus = eventBus;
    this.staleThresholdMs = staleThresholdMs;
  }

  /**
   * Called periodically by WorkerRunner.
   * Idempotent: re-detecting an already-STALE device is a no-op.
   */
  async tick() {
    const cutoff = new Date(Date.now() - this.staleThresholdMs).toISOString();

    // Find devices that were ONLINE/OFFLINE but have not been seen since cutoff
    const staleCandidates = await this.db.find('device_states', {
      where: {
        connection_state_not: 'STALE',
        last_seen_at_lt: cutoff
      }
    });

    for (const deviceState of staleCandidates) {
      await this._markStale(deviceState);
    }
  }

  async _markStale(deviceState) {
    const { id: recordId, device_id: deviceId, home_id: homeId } = deviceState;
    try {
      await this.db.update('device_states', recordId, {
        connection_state: 'STALE',
        updated_at: new Date().toISOString()
      });

      this.eventBus.publish({
        homeId,
        type: DEVICE_AVAILABILITY_EVENT,
        deviceId,
        payload: {
          deviceId,
          homeId,
          connectionState: 'STALE',
          previousState: deviceState.connection_state,
          reason: 'heartbeat_timeout',
          thresholdMs: this.staleThresholdMs
        }
      });
    } catch (err) {
      console.error(`[DeviceStaleDetector] Failed to mark device ${deviceId} as STALE:`, err.message);
    }
  }
}

module.exports = { DeviceStaleDetector, DEFAULT_STALE_THRESHOLD_MS };
