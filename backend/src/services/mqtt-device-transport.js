'use strict';

/**
 * EH Home — Production Backend MQTT Device Transport (Phase 6)
 *
 * Implements IDeviceTransport interface using the official `mqtt.js` library.
 * Connects to EMQX broker (default: mqtt://localhost:1883 or mqtts://localhost:8883).
 *
 * SECURITY INVARIANTS:
 *   - `rejectUnauthorized: true` IS STRICTLY ENFORCED FOR ALL TLS CONNECTIONS.
 *   - NEVER set `rejectUnauthorized: false` in production transport code.
 *   - Device mTLS authentication requires per-device X.509 client certificate
 *     and private key (cert identity maps to deviceId).
 *
 * Architecture:
 *   DeviceCommandService
 *     │
 *     ▼
 *   MqttDeviceTransport (this module)
 *     │
 *     ▼
 *   mqtt.js (Official Client Library)
 *     │
 *     ▼
 *   EMQX Broker (mTLS Port 8883 / TCP 1883)
 *     │
 *     ▼
 *   ESP32 Device / Simulator
 *
 * getState() is intentionally NOT handled over MQTT request/response:
 * State reads are authoritative from backend DeviceStateRepository.
 * MQTT transport manages: sendCommand(), subscribeEvents(), probeAvailability().
 *
 * QoS & Retain Policy (frozen in mqtt-protocol.md):
 *   commands:          QoS 1, retain false
 *   command-receipts:  QoS 1, retain false
 *   state:             QoS 1, retain false
 *   events:            QoS 1, retain false
 *   telemetry:         QoS 0, retain false
 *   availability:      QoS 1, retain true
 */

const mqtt = require('mqtt');
const { MqttTopicBuilder, MqttTopicParser } = require('../shared/mqtt-topic-builder');

// ---------------------------------------------------------------------------
// In-Process Mock MQTT Client (used ONLY when injected in isolated unit tests)
// ---------------------------------------------------------------------------

class MockMqttClient {
  constructor() {
    this._subscriptions = new Map();
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
      setImmediate(() => handler());
    }
    if (!this._eventHandlers) this._eventHandlers = {};
    if (!this._eventHandlers[event]) this._eventHandlers[event] = [];
    this._eventHandlers[event].push(handler);
  }

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
// MqttDeviceTransport — Production Adapter using mqtt.js
// ---------------------------------------------------------------------------

class MqttDeviceTransport {
  /**
   * @param {Object} opts
   * @param {string}   [opts.brokerUrl='mqtt://127.0.0.1:1883'] - EMQX URL
   * @param {string}   [opts.ca]           - PEM CA certificate for TLS verification
   * @param {string}   [opts.cert]         - PEM client certificate for mTLS
   * @param {string}   [opts.key]          - PEM client private key for mTLS
   * @param {string}   [opts.clientId]     - MQTT client ID (default: backend_service)
   * @param {Object}   [opts.mqttClient]   - Optional injected client (e.g. MockMqttClient for unit tests)
   * @param {Function} [opts.onReceipt]    - callback(CommandReceipt)
   * @param {Function} [opts.onState]      - callback(DeviceState)
   * @param {Function} [opts.onEvent]      - callback(DeviceEvent)
   * @param {Function} [opts.onTelemetry]  - callback(Telemetry|EnergyTelemetry)
   * @param {Function} [opts.onAvailability] - callback(deviceId, 'ONLINE'|'OFFLINE')
   */
  constructor(opts = {}) {
    this._onReceipt      = opts.onReceipt      || null;
    this._onState        = opts.onState        || null;
    this._onEvent        = opts.onEvent        || null;
    this._onTelemetry    = opts.onTelemetry    || null;
    this._onAvailability = opts.onAvailability || null;

    this._ready = false;

    if (opts.mqttClient) {
      // Injected client (unit test mock)
      this._client = opts.mqttClient;
      this._bindClientEvents();
    } else {
      // Official mqtt.js production client connection
      const brokerUrl = opts.brokerUrl || process.env.MQTT_BROKER_URL || 'mqtt://127.0.0.1:1883';
      const connectOpts = {
        clientId: opts.clientId || `backend_service_${Math.floor(Math.random() * 10000)}`,
        clean: true,
        connectTimeout: 10000,
        reconnectPeriod: 2000,
        // SECURITY REQUIREMENT: rejectUnauthorized IS ALWAYS TRUE FOR PRODUCTION TLS
        rejectUnauthorized: true,
      };

      if (opts.ca)   connectOpts.ca   = opts.ca;
      if (opts.cert) connectOpts.cert = opts.cert;
      if (opts.key)  connectOpts.key  = opts.key;

      this._client = mqtt.connect(brokerUrl, connectOpts);
      this._bindClientEvents();
    }
  }

  _bindClientEvents() {
    this._client.on('connect', () => {
      this._ready = true;
      this._setupBackendSubscriptions();
    });

    this._client.on('message', (topic, buf) => {
      this._handleIncomingMessage(topic, buf);
    });

    this._client.on('error', (err) => {
      // Ignore write-after-end errors emitted during socket disconnection/cleanup
      if (!this._ready || (err.message && err.message.includes('write after end'))) {
        return;
      }
      console.error('[MqttDeviceTransport] Client error:', err.message);
    });

    this._client.on('close', () => {
      this._ready = false;
      console.warn('[MqttDeviceTransport] Broker connection closed');
    });
  }

  // ---------------------------------------------------------------------------
  // IDeviceTransport Interface Implementation
  // ---------------------------------------------------------------------------

  /**
   * Publish a command envelope over MQTT.
   * QoS 1, retain false.
   * NOTE: Must only be called AFTER the DB transaction commits.
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
   * Probe device availability state.
   * (Availability is derived from the retained availability topic or heartbeat threshold).
   *
   * @param {string} deviceId
   */
  async probeAvailability(deviceId) {
    return { deviceId, probe: 'availability-check-via-retained-topic' };
  }

  // ---------------------------------------------------------------------------
  // Backend Subscriptions Setup
  // ---------------------------------------------------------------------------

  /**
   * Subscribes to all backend-facing inbound topics using '+' wildcard.
   * Backend subscribes to: command-receipts, state, events, telemetry, availability
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
            console.error(`[MqttDeviceTransport] Failed to subscribe to ${topic}:`, err.message);
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
      const { deviceId, category } = MqttTopicParser.parse(topic);
      parsed = { deviceId, category };
    } catch (err) {
      console.warn(`[MqttDeviceTransport] Dropped message on invalid topic '${topic}': ${err.message}`);
      return;
    }

    let payload;
    try {
      payload = JSON.parse(buf.toString('utf8'));
    } catch (err) {
      // Availability payload may be raw string: "ONLINE" or "OFFLINE"
      if (parsed.category === 'availability') {
        payload = buf.toString('utf8').replace(/^"|"$/g, '');
      } else {
        console.warn(`[MqttDeviceTransport] Dropped malformed JSON on topic '${topic}'`);
        return;
      }
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
        const availStr = typeof payload === 'string' ? payload : (payload.status || 'OFFLINE');
        if (this._onAvailability) this._onAvailability(deviceId, availStr);
        break;
      default:
        break;
    }
  }

  // ---------------------------------------------------------------------------
  // Publish Helper
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

  /** Graceful disconnect */
  disconnect() {
    if (this._client && typeof this._client.end === 'function') {
      this._client.end();
      this._ready = false;
    }
  }

  get isReady() { return this._ready; }
  get mqttClient() { return this._client; }
}

module.exports = { MqttDeviceTransport, MockMqttClient };
