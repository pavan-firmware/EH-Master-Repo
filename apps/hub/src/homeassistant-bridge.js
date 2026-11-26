/**
 * Home Assistant Local Discovery & REST/MQTT Bridge
 *
 * Generates standard Home Assistant MQTT Discovery payloads (HA Discovery Protocol)
 * and REST Entity States for all adopted EH Smart switches, sockets, and BL0942 power sensors.
 * Reference: https://www.home-assistant.io/integrations/mqtt/#mqtt-discovery
 */

const net = require('net');

class HomeAssistantBridge {
  constructor(storage, options = {}) {
    this.storage = storage;
    this.discoveryPrefix = options.discoveryPrefix || 'homeassistant';
    this.baseTopic = options.baseTopic || 'eh';
    this.hubHostname = options.hubHostname || 'eh-hub.local';
    this.hubPort = options.hubPort || 4210;
    this.mqttRuntime = {
      connected: false,
      lastSyncAt: null,
      lastError: null,
      publishedCount: 0,
    };
  }

  getMqttConfig() {
    const cfg = this.storage.getMetadata('homeAssistantMqtt', null);
    return cfg && typeof cfg === 'object' ? cfg : {};
  }

  getMqttStatus() {
    const cfg = this.getMqttConfig();
    const host = (cfg.host || '').trim();
    return {
      configured: host.length > 0,
      host: host || null,
      port: Number(cfg.port || 1883),
      username: cfg.username || null,
      discoveryPrefix: cfg.discoveryPrefix || this.discoveryPrefix,
      connected: Boolean(host && this.mqttRuntime.connected),
      lastSyncAt: this.mqttRuntime.lastSyncAt,
      lastError: this.mqttRuntime.lastError,
      publishedCount: this.mqttRuntime.publishedCount,
    };
  }

  _encodeMqttString(str) {
    const buf = Buffer.from(String(str || ''), 'utf8');
    const len = Buffer.alloc(2);
    len.writeUInt16BE(buf.length, 0);
    return Buffer.concat([len, buf]);
  }

  _encodeRemainingLength(len) {
    const out = [];
    let x = len;
    do {
      let byte = x % 128;
      x = Math.floor(x / 128);
      if (x > 0) byte |= 0x80;
      out.push(byte);
    } while (x > 0);
    return Buffer.from(out);
  }

  _buildMqttConnectPacket({ clientId, username, password }) {
    const proto = this._encodeMqttString('MQTT');
    const level = Buffer.from([0x04]); // MQTT 3.1.1
    let flags = 0x02; // Clean session
    if (username) flags |= 0x80;
    if (password) flags |= 0x40;
    const keepAlive = Buffer.alloc(2);
    keepAlive.writeUInt16BE(30, 0);
    const varHeader = Buffer.concat([proto, level, Buffer.from([flags]), keepAlive]);
    const parts = [this._encodeMqttString(clientId)];
    if (username) parts.push(this._encodeMqttString(username));
    if (password) parts.push(this._encodeMqttString(password));
    const payload = Buffer.concat(parts);
    return Buffer.concat([Buffer.from([0x10]), this._encodeRemainingLength(varHeader.length + payload.length), varHeader, payload]);
  }

  _buildMqttPublishPacket(topic, message, retain = true) {
    const headerByte = retain ? 0x31 : 0x30; // QoS 0
    const topicBuf = this._encodeMqttString(topic);
    const msgBuf = Buffer.from(typeof message === 'string' ? message : JSON.stringify(message), 'utf8');
    const body = Buffer.concat([topicBuf, msgBuf]);
    return Buffer.concat([Buffer.from([headerByte]), this._encodeRemainingLength(body.length), body]);
  }

  async publishDiscoveryViaMqtt(manifest) {
    const cfg = this.getMqttConfig();
    const host = (cfg.host || '').trim();
    const port = Number(cfg.port || 1883);
    if (!host) {
      this.mqttRuntime.connected = false;
      this.mqttRuntime.lastError = null;
      return { mqttPublished: false, reason: 'MQTT_NOT_CONFIGURED', publishedCount: 0 };
    }

    return new Promise((resolve) => {
      const socket = new net.Socket();
      let settled = false;
      const done = (result) => {
        if (settled) return;
        settled = true;
        try { socket.destroy(); } catch (_) {}
        resolve(result);
      };
      socket.setTimeout(2500);
      socket.on('timeout', () => {
        this.mqttRuntime.connected = false;
        this.mqttRuntime.lastError = `Connection timeout to ${host}:${port}`;
        done({ mqttPublished: false, reason: this.mqttRuntime.lastError, publishedCount: 0 });
      });
      socket.on('error', (err) => {
        this.mqttRuntime.connected = false;
        this.mqttRuntime.lastError = err.message;
        done({ mqttPublished: false, reason: err.message, publishedCount: 0 });
      });
      socket.connect(port, host, () => {
        const connectPkt = this._buildMqttConnectPacket({
          clientId: `eh-hub-${Date.now().toString(36)}`,
          username: cfg.username || '',
          password: cfg.password || '',
        });
        socket.write(connectPkt);
      });
      socket.once('data', (chunk) => {
        // CONNACK: type 0x20, return code chunk[3] == 0
        if (chunk.length >= 4 && chunk[0] === 0x20 && chunk[3] === 0) {
          let count = 0;
          for (const entity of manifest.entities) {
            if (entity.topic) {
              const payloadCopy = { ...entity };
              delete payloadCopy.topic;
              delete payloadCopy.component;
              delete payloadCopy.rest_endpoint;
              socket.write(this._buildMqttPublishPacket(entity.topic, payloadCopy, true));
              count++;
            }
          }
          // Publish live availability & channel states
          for (const dev of this.storage.getDevices()) {
            socket.write(this._buildMqttPublishPacket(`${this.baseTopic}/${dev.id}/availability`, dev.online !== false ? 'online' : 'offline', true));
            const channels = dev.channels || {};
            for (let ch = 1; ch <= (dev.channelCount || 3); ch++) {
              socket.write(this._buildMqttPublishPacket(`${this.baseTopic}/${dev.id}/state/ch${ch}`, channels[ch] ? 'ON' : 'OFF', true));
            }
          }
          socket.write(Buffer.from([0xE0, 0x00])); // DISCONNECT
          this.mqttRuntime.connected = true;
          this.mqttRuntime.lastSyncAt = new Date().toISOString();
          this.mqttRuntime.lastError = null;
          this.mqttRuntime.publishedCount = count;
          done({ mqttPublished: true, publishedCount: count });
        } else {
          const code = chunk.length >= 4 ? chunk[3] : -1;
          this.mqttRuntime.connected = false;
          this.mqttRuntime.lastError = `MQTT CONNACK rejected (code ${code})`;
          done({ mqttPublished: false, reason: this.mqttRuntime.lastError, publishedCount: 0 });
        }
      });
    });
  }

  /**
   * Generates complete Home Assistant Discovery payloads for all registered devices
   */
  generateDiscoveryManifest() {
    const cfg = this.getMqttConfig();
    const prefix = cfg.discoveryPrefix || this.discoveryPrefix;
    const devices = this.storage.getDevices();
    const manifest = {
      status: 'ok',
      prefix,
      generatedAt: new Date().toISOString(),
      hub: {
        id: this.storage.getMetadata('hubId', 'eh-hub-pi3b'),
        name: 'EH Home Smart Hub Gateway',
        model: this.storage.getMetadata('model', 'EH-HUB-V1-PI (Raspberry Pi 3B+ Platform)'),
        version: this.storage.getMetadata('version', '1.1.0-plan1-sqlite'),
        configurationUrl: `http://${this.hubHostname}:${this.hubPort}`,
      },
      entitiesCount: 0,
      entities: [],
    };

    for (const dev of devices) {
      const category = (dev.category || 'switches').toLowerCase();
      const channelCount = dev.channelCount || (category === 'sockets' ? 2 : 3);
      const devName = dev.name || `EH Device (${dev.id.slice(-4)})`;
      const devModel = dev.model || `EH-SW-${channelCount}X`;

      const haDevice = {
        identifiers: [dev.id],
        name: devName,
        model: devModel,
        manufacturer: 'EH Home',
        sw_version: dev.firmwareVersion || '1.0.0',
        configuration_url: dev.ipAddress ? `http://${dev.ipAddress}` : `http://${this.hubHostname}:${this.hubPort}`,
      };

      if (category === 'sensors') {
        const telemetry = dev.telemetry || {};
        const sensorMetrics = [
          { key: 'temperature', name: 'Temperature', unit: '°C', cls: 'temperature' },
          { key: 'humidity', name: 'Humidity', unit: '%', cls: 'humidity' },
          { key: 'battery', name: 'Battery', unit: '%', cls: 'battery' },
        ];
        for (const metric of sensorMetrics) {
          if (telemetry[metric.key] !== undefined || Object.keys(telemetry).length === 0) {
            manifest.entities.push({
              topic: `${prefix}/sensor/${dev.id}/${metric.key}/config`,
              component: 'sensor',
              unique_id: `${dev.id}_${metric.key}`,
              object_id: `${metric.key}_${dev.id.slice(-6).replace(/-/g, '_')}`,
              name: `${devName} ${metric.name}`,
              state_topic: `${this.baseTopic}/${dev.id}/telemetry`,
              unit_of_measurement: metric.unit,
              device_class: metric.cls,
              value_template: `{{ value_json.${metric.key} | default(0) }}`,
              device: haDevice,
            });
          }
        }
      } else {
        const haComponent = category === 'fans' ? 'fan' : (category === 'lighting' ? 'light' : 'switch');
        for (let ch = 1; ch <= channelCount; ch++) {
          const uniqueId = `${dev.id}_ch${ch}`;
          const objectId = `${haComponent}_${dev.id.slice(-6).replace(/-/g, '_')}_ch${ch}`;
          const chName = `${devName} Channel ${ch}`;

          manifest.entities.push({
            topic: `${prefix}/${haComponent}/${dev.id}/${objectId}/config`,
            component: haComponent,
            unique_id: uniqueId,
            object_id: objectId,
            name: chName,
            command_topic: `${this.baseTopic}/${dev.id}/cmd/ch${ch}/power`,
            state_topic: `${this.baseTopic}/${dev.id}/state/ch${ch}`,
            availability_topic: `${this.baseTopic}/${dev.id}/availability`,
            payload_on: 'ON',
            payload_off: 'OFF',
            state_on: 'ON',
            state_off: 'OFF',
            optimistic: false,
            qos: 1,
            retain: true,
            device: haDevice,
            rest_endpoint: {
              method: 'POST',
              url: `http://${this.hubHostname}:${this.hubPort}/api/v1/control`,
              body: { deviceId: dev.id, channel: ch, state: true }
            }
          });

          const isEnergyCapable = dev.capabilities?.energyMonitoring !== false;
          if (isEnergyCapable) {
            manifest.entities.push({
              topic: `${prefix}/sensor/${dev.id}/power_ch${ch}/config`,
              component: 'sensor',
              unique_id: `${dev.id}_ch${ch}_power`,
              object_id: `power_${dev.id.slice(-6).replace(/-/g, '_')}_ch${ch}`,
              name: `${devName} Ch${ch} Power`,
              state_topic: `${this.baseTopic}/${dev.id}/telemetry/ch${ch}`,
              unit_of_measurement: 'W',
              device_class: 'power',
              state_class: 'measurement',
              value_template: '{{ value_json.powerW | default(0) }}',
              device: haDevice,
            });
            manifest.entities.push({
              topic: `${prefix}/sensor/${dev.id}/energy_ch${ch}/config`,
              component: 'sensor',
              unique_id: `${dev.id}_ch${ch}_energy`,
              object_id: `energy_${dev.id.slice(-6).replace(/-/g, '_')}_ch${ch}`,
              name: `${devName} Ch${ch} Energy`,
              state_topic: `${this.baseTopic}/${dev.id}/telemetry/ch${ch}`,
              unit_of_measurement: 'kWh',
              device_class: 'energy',
              state_class: 'total_increasing',
              value_template: '{{ value_json.energyKwh | default(0) }}',
              device: haDevice,
            });
          }
        }
      }

      // Connectivity Binary Sensor (Online/Offline)
      manifest.entities.push({
        topic: `${prefix}/binary_sensor/${dev.id}/connectivity/config`,
        component: 'binary_sensor',
        unique_id: `${dev.id}_connectivity`,
        object_id: `connectivity_${dev.id.slice(-6).replace(/-/g, '_')}`,
        name: `${devName} Connectivity`,
        state_topic: `${this.baseTopic}/${dev.id}/availability`,
        payload_on: 'online',
        payload_off: 'offline',
        device_class: 'connectivity',
        device: haDevice,
      });
    }

    manifest.entitiesCount = manifest.entities.length;
    return manifest;
  }

  /**
   * Generates REST-friendly entity state dump for Home Assistant REST integration
   */
  getRestEntities() {
    const devices = this.storage.getDevices();
    const result = [];

    for (const dev of devices) {
      const channelCount = dev.channelCount || 3;
      const channels = dev.channels || {};

      for (let ch = 1; ch <= channelCount; ch++) {
        const powerState = Boolean(channels[ch]);
        const energy = this.storage.getLatestEnergySample(dev.id, ch);

        result.push({
          entity_id: `switch.eh_${dev.id.replace(/-/g, '_')}_ch${ch}`,
          state: powerState ? 'on' : 'off',
          attributes: {
            friendly_name: `${dev.name || 'EH Switch'} Ch${ch}`,
            device_id: dev.id,
            channel: ch,
            ip_address: dev.ipAddress,
            power_w: energy?.powerW || 0,
            voltage_v: energy?.voltageV || 230,
            current_a: energy?.currentA || 0,
            last_seen: dev.lastSeenAt || new Date().toISOString(),
          }
        });
      }
    }
    return result;
  }
}

module.exports = HomeAssistantBridge;
