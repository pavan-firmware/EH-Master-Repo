const { SchemaValidator } = require('../../packages/contracts/validator');
const path = require('path');

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
}

module.exports = { DeviceSimulator };
