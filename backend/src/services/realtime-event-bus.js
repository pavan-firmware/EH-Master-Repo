'use strict';

/**
 * EH Home — Realtime Event Bus (Phase 7B)
 *
 * Transport-neutral in-process pub/sub event fan-out.
 *
 * - Listeners register by homeId
 * - Events are emitted ONLY after authoritative DB commit
 * - No MQTT knowledge here
 * - No SSE-specific knowledge here
 * - Supports safe add/remove of listeners during iteration
 */

const crypto = require('crypto');

class RealtimeEventBus {
  constructor() {
    // Map<homeId, Set<Function>>
    this._listeners = new Map();
    // Monotonic sequence per homeId
    this._sequences = new Map();
  }

  /**
   * Subscribe a listener for all events belonging to a specific home.
   * @param {string} homeId
   * @param {Function} listener - function(event: SSEEventEnvelope) => void
   * @returns {Function} unsubscribe function
   */
  subscribe(homeId, listener) {
    if (!homeId || typeof listener !== 'function') {
      throw new Error('homeId and listener function are required');
    }
    if (!this._listeners.has(homeId)) {
      this._listeners.set(homeId, new Set());
    }
    this._listeners.get(homeId).add(listener);

    return () => this.unsubscribe(homeId, listener);
  }

  /**
   * Remove a specific listener from a home subscription.
   */
  unsubscribe(homeId, listener) {
    const listeners = this._listeners.get(homeId);
    if (listeners) {
      listeners.delete(listener);
      if (listeners.size === 0) {
        this._listeners.delete(homeId);
      }
    }
  }

  /**
   * Publish a domain event to all subscribers of a home.
   * @param {Object} opts
   * @param {string}  opts.homeId
   * @param {string}  opts.type         - SSEEventType
   * @param {string}  [opts.deviceId]
   * @param {Object}  opts.payload
   * @returns {Object} the SSEEventEnvelope that was emitted
   */
  publish({ homeId, type, deviceId = null, payload }) {
    if (!homeId || !type || payload === undefined) {
      throw new Error('homeId, type, and payload are required to publish an event');
    }

    const seq = (this._sequences.get(homeId) || 0) + 1;
    this._sequences.set(homeId, seq);

    const event = {
      schemaVersion: 1,
      eventId: crypto.randomUUID(),
      type,
      occurredAt: new Date().toISOString(),
      homeId,
      deviceId: deviceId || null,
      payload,
      _seq: seq  // Internal monotonic sequence for Last-Event-ID
    };

    const listeners = this._listeners.get(homeId);
    if (listeners && listeners.size > 0) {
      // Snapshot to avoid mutation issues during iteration
      const snapshot = [...listeners];
      for (const listener of snapshot) {
        try {
          listener(event);
        } catch (err) {
          // Individual listener errors must not break fan-out
          console.error(`[RealtimeEventBus] Listener error for home ${homeId}:`, err.message);
        }
      }
    }

    return event;
  }

  /**
   * Count how many active subscribers are listening for a homeId.
   */
  subscriberCount(homeId) {
    return this._listeners.get(homeId)?.size || 0;
  }

  /**
   * Remove all listeners for all homes (for clean shutdown/test teardown).
   */
  clear() {
    this._listeners.clear();
    this._sequences.clear();
  }
}

module.exports = { RealtimeEventBus };
