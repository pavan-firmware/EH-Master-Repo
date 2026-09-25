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

const DEFAULT_STALE_THRESHOLD_MS = 900_000;  // 15 minutes (idle devices with active MQTT session stay online)
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
    const cutoffDate = new Date(Date.now() - this.staleThresholdMs);
    const cutoffIso = cutoffDate.toISOString();
    const tableName = (this.db._tables && this.db._tables.device_states) ? 'device_states' : 'device_state';

    let staleCandidates = [];
    if (this.db._tables) {
      staleCandidates = await this.db.find(tableName, {
        where: {
          connection_state_not: 'STALE',
          last_seen_at_lt: cutoffIso
        }
      });
    } else {
      staleCandidates = await this.db.find(tableName, ds => {
        if (!ds || ds.connection_state === 'STALE' || ds.connection_state === 'OFFLINE') return false;
        if (!ds.last_seen_at) return true;
        return new Date(ds.last_seen_at) < cutoffDate;
      });
    }

    for (const deviceState of staleCandidates) {
      await this._markStale(deviceState, tableName);
    }
  }

  async _markStale(deviceState, tableName = 'device_state') {
    const recordId = deviceState.id || deviceState.device_id;
    const deviceId = deviceState.device_id || deviceState.id;
    const homeId = deviceState.home_id || deviceState.homeId;
    try {
      await this.db.update(tableName, recordId, {
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
