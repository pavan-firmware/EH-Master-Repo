/**
 * Home Assistant Local Discovery & REST/MQTT Bridge
 *
 * Generates standard Home Assistant MQTT Discovery payloads (HA Discovery Protocol)
 * and REST Entity States for all adopted EH Smart switches, sockets, and BL0942 power sensors.
 * Reference: https://www.home-assistant.io/integrations/mqtt/#mqtt-discovery
 */

class HomeAssistantBridge {
  constructor(storage, options = {}) {
    this.storage = storage;
    this.discoveryPrefix = options.discoveryPrefix || 'homeassistant';
    this.baseTopic = options.baseTopic || 'eh';
    this.hubHostname = options.hubHostname || 'eh-hub.local';
    this.hubPort = options.hubPort || 4210;
  }

  /**
   * Generates complete Home Assistant Discovery payloads for all registered devices
   */
  generateDiscoveryManifest() {
    const devices = this.storage.getDevices();
    const manifest = {
      status: 'ok',
      prefix: this.discoveryPrefix,
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
      const channelCount = dev.channelCount || 3;
      const devName = dev.name || `EH Switch (${dev.id.slice(-4)})`;
      const devModel = dev.model || `EH-SW-${channelCount}X`;

      const haDevice = {
        identifiers: [dev.id],
        name: devName,
        model: devModel,
        manufacturer: 'EH Home',
        sw_version: '2.1.0',
        configuration_url: dev.ipAddress ? `http://${dev.ipAddress}` : `http://${this.hubHostname}:${this.hubPort}`,
      };

      // 1. Switch Entities (one per channel)
      for (let ch = 1; ch <= channelCount; ch++) {
        const uniqueId = `${dev.id}_ch${ch}`;
        const objectId = `switch_${dev.id.slice(-6).replace(/-/g, '_')}_ch${ch}`;
        const chName = `${devName} Channel ${ch}`;

        const switchConfig = {
          topic: `${this.discoveryPrefix}/switch/${dev.id}/${objectId}/config`,
          component: 'switch',
          unique_id: uniqueId,
          object_id: objectId,
          name: chName,
          command_topic: `${this.baseTopic}/${dev.id}/cmd/ch${ch}/power`,
          state_topic: `${this.baseTopic}/${dev.id}/state/ch${ch}`,
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
        };
        manifest.entities.push(switchConfig);

        // 2. Power Meter Sensor (BL0942) per channel
        const powerConfig = {
          topic: `${this.discoveryPrefix}/sensor/${dev.id}/power_ch${ch}/config`,
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
        };
        manifest.entities.push(powerConfig);

        // 3. Energy Meter Sensor (BL0942 kWh) per channel
        const energyConfig = {
          topic: `${this.discoveryPrefix}/sensor/${dev.id}/energy_ch${ch}/config`,
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
        };
        manifest.entities.push(energyConfig);
      }

      // 4. Connectivity Binary Sensor (Online/Offline)
      manifest.entities.push({
        topic: `${this.discoveryPrefix}/binary_sensor/${dev.id}/connectivity/config`,
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
