const { SchemaValidator } = require('../../packages/contracts/validator');
const path = require('path');

// Phase 6: Import canonical topic builder for MQTT transport mode
// MqttTopicBuilder is used for all topic construction — never hard-code topic strings.
const { MqttTopicBuilder } = require('../../backend/src/shared/mqtt-topic-builder');
const { MockMqttClient } = require('../../backend/src/services/mqtt-device-transport');

class DeviceSimulator {
  constructor(config = {}) {
    this.identity = {
      schemaVersion: 1,
      deviceId: config.deviceId || "0194fe23-7a1b-7890-a123-456789abcdef",
      serialNumber: config.serialNumber || "EH-SW3X-2026W12-00891",
      productVariantId: config.productVariantId || "eh-smart-switch-3x",
      hardwareRevision: config.hardwareRevision || "HW_1_0",
      firmwareFamily: config.firmwareFamily || "esp32c6-switch-platform"
    };

    this.channelCount = config.channelCount || 3;
    this.channels = [];
    for (let i = 1; i <= this.channelCount; i++) {
      this.channels.push({
        schemaVersion: 1,
        channelIndex: i,
        desiredState: { power: false },
        reportedState: { power: false },
        confidence: "CONFIRMED",
        updatedAt: new Date().toISOString()
      });
    }

    this.connectionState = "ONLINE";
    this.sequenceNumber = 1000;
    this.cumulativeEnergyWh = 125000; // 125 kWh
  }

  getIdentity() {
    return { ...this.identity };
  }

  getState() {
    return {
      schemaVersion: 1,
      deviceId: this.identity.deviceId,
      connectionState: this.connectionState,
      channels: this.channels.map(c => ({ ...c })),
      updatedAt: new Date().toISOString()
    };
  }

  handlePhysicalToggle(channelIndex) {
    const ch = this.channels.find(c => c.channelIndex === channelIndex);
    if (!ch) throw new Error(`Channel ${channelIndex} not found`);

    ch.reportedState.power = !ch.reportedState.power;
    ch.desiredState.power = ch.reportedState.power;
    ch.updatedAt = new Date().toISOString();
    this.sequenceNumber++;

    return {
      schemaVersion: 1,
      eventId: "0194fe23-7a1b-7890-a123-456789" + String(this.sequenceNumber).padStart(6, '0'),
      deviceId: this.identity.deviceId,
      channelIndex,
      eventType: "switch.changed",
      source: "PHYSICAL_SWITCH",
      payload: { power: ch.reportedState.power },
      timestamp: new Date().toISOString(),
      sequenceNumber: this.sequenceNumber
    };
  }

  handleCommand(cmd) {
    if (cmd.deviceId !== this.identity.deviceId) {
      return {
        schemaVersion: 1,
        commandId: cmd.commandId,
        deviceId: this.identity.deviceId,
        channelIndex: cmd.channelIndex,
        status: "FAILED",
        failureReason: "Target deviceId mismatch",
        timestamp: new Date().toISOString()
      };
    }

    const ch = this.channels.find(c => c.channelIndex === cmd.channelIndex);
    if (!ch) {
      return {
        schemaVersion: 1,
        commandId: cmd.commandId,
        deviceId: this.identity.deviceId,
        channelIndex: cmd.channelIndex,
        status: "FAILED",
        failureReason: `Channel ${cmd.channelIndex} not found`,
        timestamp: new Date().toISOString()
      };
    }

    if (cmd.action === "setPower" && typeof cmd.params?.value === "boolean") {
      ch.desiredState.power = cmd.params.value;
      ch.reportedState.power = cmd.params.value;
      ch.updatedAt = new Date().toISOString();

      return {
        schemaVersion: 1,
        commandId: cmd.commandId,
        deviceId: this.identity.deviceId,
        channelIndex: cmd.channelIndex,
        status: "APPLIED",
        failureReason: null,
        timestamp: new Date().toISOString()
      };
    }

    return {
      schemaVersion: 1,
      commandId: cmd.commandId,
      deviceId: this.identity.deviceId,
      channelIndex: cmd.channelIndex,
      status: "FAILED",
      failureReason: `Unsupported action ${cmd.action}`,
      timestamp: new Date().toISOString()
    };
  }

  generateTelemetry(channelIndex = 1) {
    this.sequenceNumber++;
    this.cumulativeEnergyWh += 1;

    return {
      schemaVersion: 1,
      deviceId: this.identity.deviceId,
      channelIndex,
      v_mv: 230000 + Math.floor(Math.random() * 2000), // ~230-232 V
      i_ma: 750 + Math.floor(Math.random() * 50),      // ~750-800 mA
      p_mw: 172500 + Math.floor(Math.random() * 5000), // ~172.5 - 177.5 W
      e_tot_wh: this.cumulativeEnergyWh,
      e_int_mwh: 240,
      freq_mhz: 50000,
      pf_x1000: 980,
      flags: 0,
      timestamp: new Date().toISOString(),
      sequenceNumber: this.sequenceNumber
    };
  }

  // ---------------------------------------------------------------------------
  // Phase 6 — MQTT Transport Mode
  //
  // Extends the existing simulator with an MQTT transport adapter.
  // Reuses all existing state, command handling, and physical switch simulation.
  // DOES NOT create a second simulator engine.
  // ---------------------------------------------------------------------------

  /**
   * Connect simulator to an MQTT client (real or mock).
   * Sets up subscriptions and publishes ONLINE availability.
   *
   * @param {Object} [mqttClient]  - Optional mqtt.js-compatible client. If not provided,
   *                                 uses internal MockMqttClient for testing.
   */
  connectMqtt(mqttClient) {
    this._mqttClient = mqttClient || new MockMqttClient();
    const deviceId = this.identity.deviceId;

    // Subscribe to commands topic
    const cmdTopic = MqttTopicBuilder.commands(deviceId);
    this._mqttClient.subscribe(cmdTopic, { qos: 1 }, (err) => {
      if (err) {
        console.error('[Simulator] Failed to subscribe to commands:', err.message);
        return;
      }
      console.log(`[Simulator] Subscribed to ${cmdTopic}`);

      // Publish retained ONLINE availability
      const availTopic = MqttTopicBuilder.availability(deviceId);
      this._mqttClient.publish(availTopic, '"ONLINE"',
        { qos: 1, retain: true }, () => {
          console.log('[Simulator] Published ONLINE availability');
        });

      // Publish initial state
      this._publishState();
    });

    // Register message handler
    this._mqttClient.on('message', (topic, buf) => {
      this._processMqttMessage(topic, buf);
    });

    this.connectionState = 'ONLINE';
    return this;
  }

  /**
   * Gracefully disconnect the simulator MQTT client.
   * Publishes OFFLINE (retained) before disconnecting.
   */
  disconnectMqtt() {
    if (!this._mqttClient) return;
    const deviceId = this.identity.deviceId;
    const availTopic = MqttTopicBuilder.availability(deviceId);
    this._mqttClient.publish(availTopic, '"OFFLINE"',
      { qos: 1, retain: true }, () => {
        this._mqttClient.end();
        this.connectionState = 'OFFLINE';
        console.log('[Simulator] Disconnected gracefully — OFFLINE published');
      });
  }

  /**
   * Simulate a physical wall switch toggle over MQTT.
   * Publishes DeviceEvent(source=PHYSICAL_SWITCH) and updated state.
   *
   * @param {number} channelIndex - Channel to toggle (1-based)
   */
  physicalToggleMqtt(channelIndex) {
    const evt = this.handlePhysicalToggle(channelIndex); // Reuse existing logic
    if (!this._mqttClient) return evt;

    const deviceId = this.identity.deviceId;

    // Publish event
    const eventTopic = MqttTopicBuilder.events(deviceId);
    this._mqttClient.publish(eventTopic, JSON.stringify(evt), { qos: 1, retain: false }, () => {});

    // Publish updated state
    this._publishState();

    return evt;
  }

  /**
   * Publish current device state to MQTT state topic.
   * @private
   */
  _publishState() {
    if (!this._mqttClient) return;
    const stateTopic = MqttTopicBuilder.state(this.identity.deviceId);
    const statePayload = this.getState();
    this._mqttClient.publish(stateTopic, JSON.stringify(statePayload), { qos: 1, retain: false }, () => {});
  }

  /**
   * Process an incoming MQTT message from the command topic.
   * Validates, handles idempotency (by commandId tracking), publishes receipt.
   * @private
   */
  _processMqttMessage(topic, buf) {
    const deviceId = this.identity.deviceId;
    const expectedTopic = MqttTopicBuilder.commands(deviceId);
    if (topic !== expectedTopic) return; // ACL: ignore other device topics

    let cmd;
    try {
      cmd = JSON.parse(buf.toString('utf8'));
    } catch (_) {
      console.warn('[Simulator] Malformed command payload — dropped');
      return;
    }

    // Expiry check
    if (cmd.expiresAt && new Date(cmd.expiresAt) <= new Date()) {
      this._publishReceipt({
        schemaVersion: 1,
        commandId: cmd.commandId,
        deviceId,
        channelIndex: cmd.channelIndex,
        status: 'EXPIRED',
        failureReason: 'Command expired before delivery',
        timestamp: new Date().toISOString()
      });
      return;
    }

    // Idempotency check (in-memory dedup by commandId for simulator)
    if (!this._seenCommands) this._seenCommands = new Set();
    const idemKey = `${deviceId}:${cmd.idempotencyKey || cmd.commandId}`;
    if (this._seenCommands.has(idemKey)) {
      // Duplicate: return deterministic APPLIED without re-actuating
      this._publishReceipt({
        schemaVersion: 1,
        commandId: cmd.commandId,
        deviceId,
        channelIndex: cmd.channelIndex,
        status: 'APPLIED',
        failureReason: null,
        timestamp: new Date().toISOString()
      });
      return;
    }

    // Process command using existing handleCommand logic
    const receipt = this.handleCommand(cmd);
    this._seenCommands.add(idemKey);

    this._publishReceipt({
      ...receipt,
      schemaVersion: 1,
      deviceId
    });

    // If applied, publish updated state
    if (receipt.status === 'APPLIED') {
      this._publishState();
    }
  }

  /** @private */
  _publishReceipt(receipt) {
    if (!this._mqttClient) return;
    const receiptTopic = MqttTopicBuilder.commandReceipts(this.identity.deviceId);
    this._mqttClient.publish(receiptTopic, JSON.stringify(receipt), { qos: 1, retain: false }, () => {});
  }
}

module.exports = { DeviceSimulator };

