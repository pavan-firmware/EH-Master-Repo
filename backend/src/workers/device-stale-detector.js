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

const DEFAULT_STALE_THRESHOLD_MS = 90_000;  // 90 seconds strict presence TTL
const DEVICE_AVAILABILITY_EVENT = 'device.availability';
const DEVICE_OFFLINE_EVENT = 'device.offline';

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
    this._timer = null;
  }

  start(intervalMs = 15000) {
    if (this._timer) return;
    this._timer = setInterval(() => {
      this.tick().catch(err => {
        console.error('[DeviceStaleDetector] tick error:', err.message);
      });
    }, intervalMs);
    if (this._timer.unref) this._timer.unref();
    console.log(`[DeviceStaleDetector] Started background presence stale detector (every ${intervalMs}ms, threshold ${this.staleThresholdMs}ms)`);
  }

  stop() {
    if (this._timer) {
      clearInterval(this._timer);
      this._timer = null;
    }
  }

  /**
   * Called periodically by WorkerRunner or background timer.
   * Idempotent: re-detecting an already-OFFLINE device is a no-op.
   */
  async tick() {
    const cutoffDate = new Date(Date.now() - this.staleThresholdMs);
    const cutoffIso = cutoffDate.toISOString();
    const tableName = (this.db._tables && this.db._tables.device_states) ? 'device_states' : 'device_state';

    let staleCandidates = [];
    if (this.db._tables) {
      staleCandidates = await this.db.find(tableName, {
        where: {
          connection_state: 'ONLINE',
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

      if (this.eventBus) {
        this.eventBus.publish({
          homeId: homeId || 'global',
          type: DEVICE_AVAILABILITY_EVENT,
          deviceId,
          payload: {
            deviceId,
            homeId,
            status: 'STALE',
            connectionState: 'STALE',
            previousState: deviceState.connection_state,
            reason: 'heartbeat_timeout',
            thresholdMs: this.staleThresholdMs
          }
        });

        this.eventBus.publish({
          homeId: homeId || 'global',
          type: DEVICE_OFFLINE_EVENT,
          deviceId,
          payload: {
            deviceId,
            homeId,
            status: 'OFFLINE',
            reason: 'heartbeat_timeout',
            thresholdMs: this.staleThresholdMs
          }
        });
      }
    } catch (err) {
      console.error(`[DeviceStaleDetector] Failed to mark device ${deviceId} as OFFLINE:`, err.message);
    }
  }
}

module.exports = { DeviceStaleDetector, DEFAULT_STALE_THRESHOLD_MS };
