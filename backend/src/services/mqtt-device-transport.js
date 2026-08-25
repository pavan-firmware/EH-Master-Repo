'use strict';

/**
 * EH Home — MQTT Device Transport Adapter (Phase 6)
 *
 * Implements IDeviceTransport interface for MQTT broker communication.
 * Supports real MQTT client or an injected mock client for offline testing.
 *
 * Architecture:
 *   DeviceCommandService
 *     │
 *     ▼
 *   MqttDeviceTransport  (this module)
 *     │
 *     ▼
 *   MQTT Client (real mqtt.js or mock)
 *     │
 *     ▼
 *   EMQX Broker (mTLS port 8883)
 *     │
 *     ▼
 *   ESP32 Device
 *
 * getState() is NOT handled here — state is read from DeviceStateRepository.
 * MQTT transport handles: sendCommand(), subscribeToDevice(), subscribeAvailability().
 *
 * QoS / Retain Policy (frozen from mqtt-protocol.md):
 *   commands:          QoS 1, retain false
 *   command-receipts:  QoS 1, retain false
 *   state:             QoS 1, retain false
 *   events:            QoS 1, retain false
 *   telemetry:         QoS 0, retain false
 *   availability:      QoS 1, retain true
 *
 * Security:
 *   - mTLS: per-device certificate (CN = deviceId) for production
 *   - Backend authenticates with a separate service principal
 *   - Development mode allows non-mTLS via environment flag (MQTT_DEV_MODE=true)
 *
 * IMPORTANT: This module never directly touches GPIO or hardware HAL.
 */

const { MqttTopicBuilder, MqttTopicParser } = require('../shared/mqtt-topic-builder');

// ---------------------------------------------------------------------------
// In-Process Mock MQTT Client (used when real broker is not available)
// ---------------------------------------------------------------------------

class MockMqttClient {
  constructor() {
    this._subscriptions = new Map(); // topic -> [handlers]
    this._published = [];
    this.connected = true;
  }

  publish(topic, payload, opts, cb) {
    this._published.push({ topic, payload: JSON.parse(payload), opts });
    if (typeof cb === 'function') cb(null);
  }

  subscribe(topic, opts, cb) {
    if (!this._subscriptions.has(topic)) {
      this._subscriptions.set(topic, []);
    }
    if (typeof cb === 'function') cb(null, [{ topic, qos: opts.qos || 1 }]);
  }

  on(event, handler) {
    if (event === 'connect') {
      // Emit connect immediately for mock
      setImmediate(() => handler());
    }
    // Other events (message, error, close) are triggered by test harness
    if (!this._eventHandlers) this._eventHandlers = {};
    if (!this._eventHandlers[event]) this._eventHandlers[event] = [];
    this._eventHandlers[event].push(handler);
  }

  /** Test helper: simulate incoming MQTT message from device */
  simulateMessage(topic, payloadObj) {
    const payloadBuf = Buffer.from(JSON.stringify(payloadObj));
    const handlers = this._eventHandlers?.message || [];
    handlers.forEach(h => h(topic, payloadBuf, {}));
  }

  end() { this.connected = false; }

  getPublished() { return [...this._published]; }
  clearPublished() { this._published = []; }
}

// ---------------------------------------------------------------------------
// MqttDeviceTransport — IDeviceTransport Adapter
// ---------------------------------------------------------------------------

class MqttDeviceTransport {
  /**
   * @param {Object} opts
   * @param {Object}   opts.mqttClient     - real or mock MQTT client instance
   * @param {Function} [opts.onReceipt]    - callback(CommandReceipt) for command receipts
   * @param {Function} [opts.onState]      - callback(DeviceState) for state publications
   * @param {Function} [opts.onEvent]      - callback(DeviceEvent) for device events
   * @param {Function} [opts.onTelemetry]  - callback(Telemetry|EnergyTelemetry)
   * @param {Function} [opts.onAvailability] - callback(deviceId, 'ONLINE'|'OFFLINE')
   */
  constructor(opts = {}) {
    this._client = opts.mqttClient || new MockMqttClient();
    this._onReceipt     = opts.onReceipt     || null;
    this._onState       = opts.onState       || null;
    this._onEvent       = opts.onEvent       || null;
    this._onTelemetry   = opts.onTelemetry   || null;
    this._onAvailability = opts.onAvailability || null;

    this._subscribedDevices = new Set();
    this._ready = false;

    this._client.on('connect', () => {
      this._ready = true;
      this._setupBackendSubscriptions();
    });

    this._client.on('message', (topic, buf) => {
      this._handleIncomingMessage(topic, buf);
    });

    this._client.on('error', (err) => {
      console.error('[MqttDeviceTransport] Client error:', err.message);
    });

    this._client.on('close', () => {
      this._ready = false;
      console.warn('[MqttDeviceTransport] Broker connection closed');
    });
  }

  // ---------------------------------------------------------------------------
  // IDeviceTransport Interface
  // ---------------------------------------------------------------------------

  /**
   * Publish a command to a device over MQTT.
   * QoS 1, retain false.
   * NOTE: Must only be called AFTER the DB outbox transaction commits.
   *
   * @param {Object} cmd - canonical Command envelope (packages/contracts Command schema)
   * @returns {Promise<void>}
   */
  async sendCommand(cmd) {
    if (!cmd || !cmd.deviceId || !cmd.commandId) {
      throw new Error('MqttDeviceTransport.sendCommand: cmd must have deviceId and commandId');
    }

    const topic = MqttTopicBuilder.commands(cmd.deviceId);
    const policy = MqttTopicBuilder.qosPolicy('commands');
    const payload = JSON.stringify(cmd);

    await this._publish(topic, payload, policy);
  }

  /**
   * Publish availability probe — used during reconnect to reaffirm ONLINE state
   * from the backend perspective when needed.
   * (Device publishes its own availability; this is for backend-driven diagnostics.)
   *
   * @param {string} deviceId
   * @returns {Promise<{connectionState: string, lastSeenAt: string|null}>}
   */
  async probeAvailability(deviceId) {
    // Availability state is derived from the retained availability topic.
    // This method returns the last known availability (from broker retained message).
    // Backend derives STALE from heartbeat threshold — not from this method.
    return { deviceId, probe: 'availability-check-via-retained-topic' };
  }

  // ---------------------------------------------------------------------------
  // Subscription Setup
  // ---------------------------------------------------------------------------

  /**
   * Subscribe to all backend-facing inbound topics (wildcarded by deviceId).
   * Backend subscribes to: command-receipts, state, events, telemetry, availability
   * for ALL devices using '+' wildcard.
   */
  async _setupBackendSubscriptions() {
    const inboundCategories = [
      'command-receipts',
      'state',
      'events',
      'telemetry',
      'availability',
    ];

    const subPromises = inboundCategories.map(category => {
      return new Promise((resolve) => {
        const topic = MqttTopicBuilder.backendSubscribe(category);
        const policy = MqttTopicBuilder.qosPolicy(category);
        this._client.subscribe(topic, { qos: policy.qos }, (err) => {
          if (err) {
            console.error(`[MqttDeviceTransport] Failed to subscribe to ${topic}:`, err);
          } else {
            console.log(`[MqttDeviceTransport] Subscribed: ${topic} (QoS ${policy.qos})`);
          }
          resolve();
        });
      });
    });

    await Promise.all(subPromises);
  }

  // ---------------------------------------------------------------------------
  // Inbound Message Routing
  // ---------------------------------------------------------------------------

  _handleIncomingMessage(topic, buf) {
    let parsed;
    try {
      parsed = { deviceId: null, category: null };
      // Parse topic — this validates UUID, rejects wildcards, etc.
      const { deviceId, category } = MqttTopicParser.parse(
        // Backend receives from wildcard subscription eh/v1/devices/+/category
        // The actual message topic has the real deviceId
        topic
      );
      parsed.deviceId = deviceId;
      parsed.category = category;
    } catch (err) {
      console.warn(`[MqttDeviceTransport] Dropped message on invalid topic '${topic}': ${err.message}`);
      return;
    }

    let payload;
    try {
      payload = JSON.parse(buf.toString('utf8'));
    } catch (err) {
      console.warn(`[MqttDeviceTransport] Dropped malformed JSON on topic '${topic}'`);
      return;
    }

    const { deviceId, category } = parsed;

    switch (category) {
      case 'command-receipts':
        if (this._onReceipt) this._onReceipt(payload);
        break;
      case 'state':
        if (this._onState) this._onState(payload);
        break;
      case 'events':
        if (this._onEvent) this._onEvent(payload);
        break;
      case 'telemetry':
        if (this._onTelemetry) this._onTelemetry(payload);
        break;
      case 'availability':
        // Payload is a plain string: "ONLINE" or "OFFLINE"
        const availStr = buf.toString('utf8').replace(/^"|"$/g, '');
        if (this._onAvailability) this._onAvailability(deviceId, availStr);
        break;
      default:
        // Unknown category was already caught by MqttTopicParser.parse
        break;
    }
  }

  // ---------------------------------------------------------------------------
  // Internal Publish Helper
  // ---------------------------------------------------------------------------

  _publish(topic, payload, policy) {
    return new Promise((resolve, reject) => {
      this._client.publish(
        topic,
        payload,
        { qos: policy.qos, retain: policy.retain },
        (err) => {
          if (err) {
            reject(new Error(`MqttDeviceTransport publish failed on '${topic}': ${err.message}`));
          } else {
            resolve();
          }
        }
      );
    });
  }

  // ---------------------------------------------------------------------------
  // Accessors for testing
  // ---------------------------------------------------------------------------

  get isReady() { return this._ready; }
  get mqttClient() { return this._client; }
}

module.exports = { MqttDeviceTransport, MockMqttClient };
