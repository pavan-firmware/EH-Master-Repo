'use strict';

/**
 * EH Home — Redis State Cache & Anti-Spam Delta Filter Service
 *
 * Keeps hot device states cached in Redis (or in-memory fallback) for instant reads
 * and filters out redundant, no-op state reports from physical switches/sensors.
 */

const { createRedisClient } = require('../shared/redis-client');

class RedisStateCacheService {
  constructor(opts = {}) {
    this.redis = opts.redisClient || createRedisClient();
    this.keyPrefix = opts.keyPrefix || 'device';
    this.defaultTtlSec = opts.defaultTtlSec || 90; // Strict 90 seconds presence TTL
  }

  _deviceKey(deviceId) {
    return `${this.keyPrefix}:${deviceId}:state`;
  }

  /**
   * Determine whether the incoming state differs significantly from the cached state.
   * Filters out zero-delta duplicates to eliminate database spam and UI thrashing.
   *
   * @param {string} deviceId
   * @param {Object} incomingState - { channels: [ { channelIndex, power } ], online, powerW, voltageV }
   * @returns {Promise<boolean>} - true if state changed, false if duplicate chatter
   */
  async isDelta(deviceId, incomingState) {
    if (!deviceId || !incomingState) return true;

    try {
      const cachedRaw = await this.redis.hgetall(this._deviceKey(deviceId));
      if (!cachedRaw || Object.keys(cachedRaw).length === 0) {
        return true; // No cached state exists yet -> consider it a delta
      }

      // Check online / connectivity status change
      if (incomingState.online !== undefined) {
        const cachedOnline = cachedRaw.online === 'true';
        if (Boolean(incomingState.online) !== cachedOnline) {
          return true;
        }
      }

      // Check relay channel states
      if (Array.isArray(incomingState.channels)) {
        for (const ch of incomingState.channels) {
          const chKey = `ch_${ch.channelIndex}_power`;
          const cachedPower = cachedRaw[chKey] === 'true';
          const incomingPower = Boolean(ch.power ?? ch.value ?? ch.enabled);
          if (cachedRaw[chKey] === undefined || incomingPower !== cachedPower) {
            return true;
          }
        }
      }

      // Check single channel power if passed directly
      if (incomingState.channelIndex !== undefined && incomingState.power !== undefined) {
        const chKey = `ch_${incomingState.channelIndex}_power`;
        const cachedPower = cachedRaw[chKey] === 'true';
        if (cachedRaw[chKey] === undefined || Boolean(incomingState.power) !== cachedPower) {
          return true;
        }
      }

      // Energy telemetry deadband check (> 1.5 Watts or > 5% change)
      if (incomingState.instantaneous_power_w !== undefined) {
        const cachedWatts = parseFloat(cachedRaw.power_w || '0');
        const incomingWatts = parseFloat(incomingState.instantaneous_power_w);
        const wattDiff = Math.abs(incomingWatts - cachedWatts);
        if (wattDiff > 1.5 && (wattDiff / Math.max(cachedWatts, 1.0)) > 0.05) {
          return true;
        }
      }

      // Net state has not changed (zero delta)
      return false;
    } catch (err) {
      // On cache error, fail open
      return true;
    }
  }

  /**
   * Commit the latest confirmed state to Redis cache with TTL.
   */
  async updateDeviceState(deviceId, state) {
    if (!deviceId || !state) return;

    try {
      const payload = {
        updated_at: new Date().toISOString()
      };

      if (state.online !== undefined) {
        payload.online = String(Boolean(state.online));
      }

      if (Array.isArray(state.channels)) {
        for (const ch of state.channels) {
          payload[`ch_${ch.channelIndex}_power`] = String(Boolean(ch.power ?? ch.value ?? ch.enabled));
        }
      }

      if (state.channelIndex !== undefined && state.power !== undefined) {
        payload[`ch_${state.channelIndex}_power`] = String(Boolean(state.power));
      }

      if (state.instantaneous_power_w !== undefined) {
        payload.power_w = String(state.instantaneous_power_w);
      }

      if (state.voltage_rms_v !== undefined) {
        payload.voltage_v = String(state.voltage_rms_v);
      }

      if (state.current_rms_a !== undefined) {
        payload.current_a = String(state.current_rms_a);
      }

      const key = this._deviceKey(deviceId);
      await this.redis.hset(key, payload);
      await this.redis.expire(key, this.defaultTtlSec);
    } catch (_) {}
  }

  /**
   * Retrieve cached state representation for cold-starting API clients.
   */
  async getDeviceState(deviceId) {
    if (!deviceId) return null;

    try {
      const raw = await this.redis.hgetall(this._deviceKey(deviceId));
      if (!raw || Object.keys(raw).length === 0) return null;

      // Strict TTL & freshness verification
      const updatedAtMs = raw.updated_at ? new Date(raw.updated_at).getTime() : 0;
      const isFresh = Boolean(updatedAtMs && (Date.now() - updatedAtMs) <= (this.defaultTtlSec * 1000));
      const isOnline = Boolean(isFresh && raw.online === 'true');

      const channels = [];
      for (let i = 1; i <= 16; i++) {
        const key = `ch_${i}_power`;
        if (raw[key] !== undefined) {
          channels.push({
            channelIndex: i,
            power: raw[key] === 'true'
          });
        }
      }

      return {
        deviceId,
        online: isOnline,
        connectionState: isOnline ? 'ONLINE' : 'OFFLINE',
        channels,
        powerW: raw.power_w ? parseFloat(raw.power_w) : undefined,
        voltageV: raw.voltage_v ? parseFloat(raw.voltage_v) : undefined,
        currentA: raw.current_a ? parseFloat(raw.current_a) : undefined,
        updatedAt: raw.updated_at || null,
        lastSeenAt: raw.updated_at || null
      };
    } catch (_) {
      return null;
    }
  }

  async clearDeviceState(deviceId) {
    if (!deviceId) return;
    try {
      await this.redis.del(this._deviceKey(deviceId));
    } catch (_) {}
  }

  async clearAll() {
    try {
      if (typeof this.redis.clearAll === 'function') {
        await this.redis.clearAll();
      }
    } catch (_) {}
  }
}

module.exports = {
  RedisStateCacheService
};
