'use strict';

/**
 * EH Home — Matter Capability Mapping Service (Phase 29)
 *
 * Deterministic, metadata-driven mapping from canonical EH device capabilities
 * to standard Matter clusters and device types.
 *
 * INVARIANTS (Correction 2):
 *   - Only expose Matter clusters and attributes explicitly supported by the product variant.
 *   - Never infer unsupported clusters (e.g. brightness without dimmer support, fan without fan motor).
 *   - Energy telemetry clusters are exposed ONLY when hardware profile has hasEnergyMetering = true.
 */

const STANDARD_MATTER_CLUSTERS = Object.freeze({
  ON_OFF: {
    id: 6, // 0x0006
    name: 'On/Off',
    attributes: ['OnOff', 'GlobalSceneControl', 'OnTime', 'OffWaitTime'],
    commands: ['Off', 'On', 'Toggle']
  },
  LEVEL_CONTROL: {
    id: 8, // 0x0008
    name: 'Level Control',
    attributes: ['CurrentLevel', 'RemainingTime', 'MinLevel', 'MaxLevel', 'OnLevel'],
    commands: ['MoveToLevel', 'Move', 'Step', 'Stop', 'MoveToLevelWithOnOff']
  },
  COLOR_CONTROL: {
    id: 768, // 0x0300
    name: 'Color Control',
    attributes: ['ColorMode', 'ColorTemperatureMireds', 'ColorTempPhysicalMinMireds', 'ColorTempPhysicalMaxMireds'],
    commands: ['MoveToColorTemperature', 'StepColorTemperature']
  },
  FAN_CONTROL: {
    id: 514, // 0x0202
    name: 'Fan Control',
    attributes: ['FanMode', 'FanModeSequence', 'PercentSetting', 'PercentCurrent'],
    commands: ['Step']
  },
  ELECTRICAL_MEASUREMENT: {
    id: 2820, // 0x0B04
    name: 'Electrical Measurement',
    attributes: ['RMSVoltage', 'RMSCurrent', 'ActivePower', 'PowerFactor'],
    commands: []
  },
  ELECTRICAL_ENERGY_MEASUREMENT: {
    id: 2821, // 0x0B05 / Matter 1.3
    name: 'Electrical Energy Measurement',
    attributes: ['CumulativeEnergyImported', 'PeriodicEnergyImported'],
    commands: []
  },
  IDENTIFY: {
    id: 3, // 0x0003
    name: 'Identify',
    attributes: ['IdentifyTime', 'IdentifyType'],
    commands: ['Identify', 'TriggerEffect']
  },
  DESCRIPTOR: {
    id: 29, // 0x001D
    name: 'Descriptor',
    attributes: ['DeviceTypeList', 'ServerList', 'ClientList', 'PartsList'],
    commands: []
  }
});

class MatterCapabilityMappingService {
  constructor({ productCatalogService } = {}) {
    this.productCatalogService = productCatalogService;
  }

  /**
   * Resolves the primary Matter device type based on product family and capabilities.
   *
   * @param {Object} productMetadata Canonical product variant metadata
   * @returns {String} Matter device type enum
   */
  resolveMatterDeviceType(productMetadata) {
    if (!productMetadata) return 'GENERIC_SWITCH';

    const family = (productMetadata.productFamily || '').toLowerCase();
    const capabilities = Array.isArray(productMetadata.capabilities) ? productMetadata.capabilities : [];

    if (family === 'smart_switch') {
      if (capabilities.includes('brightness') || capabilities.includes('dimmer')) {
        return 'DIMMABLE_LIGHT';
      }
      return 'ON_OFF_LIGHT';
    }

    if (family === 'smart_socket') {
      if (capabilities.includes('brightness') || capabilities.includes('dimmer')) {
        return 'DIMMABLE_PLUGIN_UNIT';
      }
      return 'ON_OFF_PLUGIN_UNIT';
    }

    if (family === 'smart_lighting') {
      if (capabilities.includes('cct') || capabilities.includes('color_temperature')) {
        return 'COLOR_TEMPERATURE_LIGHT';
      }
      if (capabilities.includes('color') || capabilities.includes('rgb')) {
        return 'EXTENDED_COLOR_LIGHT';
      }
      if (capabilities.includes('brightness')) {
        return 'DIMMABLE_LIGHT';
      }
      return 'ON_OFF_LIGHT';
    }

    if (family === 'smart_climate' || capabilities.includes('fan_speed')) {
      return 'FAN';
    }

    return 'GENERIC_SWITCH';
  }

  /**
   * Generates Matter endpoints with only strictly supported clusters for a product variant.
   *
   * @param {Object} productMetadata Product variant metadata
   * @returns {Array<Object>} List of resolved endpoints
   */
  generateMatterEndpoints(productMetadata) {
    if (!productMetadata) return [];

    const channelCount = productMetadata.channelCount || 1;
    const channels = Array.isArray(productMetadata.channels) ? productMetadata.channels : [];
    const hasEnergyMetering = Boolean(productMetadata.hardwareProfile?.hasEnergyMetering);
    const globalCaps = Array.isArray(productMetadata.capabilities) ? productMetadata.capabilities : [];

    const endpoints = [];

    // Endpoint 0: Root Node / Bridge (Descriptor + Identify)
    endpoints.push({
      endpointNumber: 0,
      deviceType: 'ROOT_NODE',
      channelIndex: 0,
      serverClusters: [
        {
          clusterId: STANDARD_MATTER_CLUSTERS.DESCRIPTOR.id,
          clusterName: STANDARD_MATTER_CLUSTERS.DESCRIPTOR.name,
          supportedAttributes: STANDARD_MATTER_CLUSTERS.DESCRIPTOR.attributes,
          supportedCommands: []
        },
        {
          clusterId: STANDARD_MATTER_CLUSTERS.IDENTIFY.id,
          clusterName: STANDARD_MATTER_CLUSTERS.IDENTIFY.name,
          supportedAttributes: STANDARD_MATTER_CLUSTERS.IDENTIFY.attributes,
          supportedCommands: STANDARD_MATTER_CLUSTERS.IDENTIFY.commands
        }
      ]
    });

    // Endpoints 1..N: Individual channels / switchboards
    for (let i = 1; i <= channelCount; i++) {
      const ch = channels.find(c => c.channelIndex === i) || {};
      const chCaps = Array.isArray(ch.capabilities) ? ch.capabilities : globalCaps;
      const deviceType = this.resolveMatterDeviceType(productMetadata);

      const serverClusters = [
        {
          clusterId: STANDARD_MATTER_CLUSTERS.DESCRIPTOR.id,
          clusterName: STANDARD_MATTER_CLUSTERS.DESCRIPTOR.name,
          supportedAttributes: STANDARD_MATTER_CLUSTERS.DESCRIPTOR.attributes,
          supportedCommands: []
        },
        {
          clusterId: STANDARD_MATTER_CLUSTERS.IDENTIFY.id,
          clusterName: STANDARD_MATTER_CLUSTERS.IDENTIFY.name,
          supportedAttributes: STANDARD_MATTER_CLUSTERS.IDENTIFY.attributes,
          supportedCommands: STANDARD_MATTER_CLUSTERS.IDENTIFY.commands
        }
      ];

      // 1. On/Off Cluster: Supported if switch, relay, or local_switch capability exists
      if (chCaps.includes('switch') || chCaps.includes('relay') || chCaps.includes('local_switch') || globalCaps.includes('switch') || globalCaps.includes('relay')) {
        serverClusters.push({
          clusterId: STANDARD_MATTER_CLUSTERS.ON_OFF.id,
          clusterName: STANDARD_MATTER_CLUSTERS.ON_OFF.name,
          supportedAttributes: ['OnOff'],
          supportedCommands: ['Off', 'On', 'Toggle']
        });
      }

      // 2. Level Control Cluster: ONLY if brightness/dimmer capability exists
      if (chCaps.includes('brightness') || chCaps.includes('dimmer') || globalCaps.includes('brightness')) {
        serverClusters.push({
          clusterId: STANDARD_MATTER_CLUSTERS.LEVEL_CONTROL.id,
          clusterName: STANDARD_MATTER_CLUSTERS.LEVEL_CONTROL.name,
          supportedAttributes: ['CurrentLevel', 'OnLevel'],
          supportedCommands: ['MoveToLevel', 'MoveToLevelWithOnOff']
        });
      }

      // 3. Color Control Cluster: ONLY if CCT / Color capability exists
      if (chCaps.includes('cct') || chCaps.includes('color_temperature') || globalCaps.includes('cct')) {
        serverClusters.push({
          clusterId: STANDARD_MATTER_CLUSTERS.COLOR_CONTROL.id,
          clusterName: STANDARD_MATTER_CLUSTERS.COLOR_CONTROL.name,
          supportedAttributes: ['ColorMode', 'ColorTemperatureMireds'],
          supportedCommands: ['MoveToColorTemperature']
        });
      }

      // 4. Fan Control Cluster: ONLY if fan_speed capability exists
      if (chCaps.includes('fan_speed') || globalCaps.includes('fan_speed')) {
        serverClusters.push({
          clusterId: STANDARD_MATTER_CLUSTERS.FAN_CONTROL.id,
          clusterName: STANDARD_MATTER_CLUSTERS.FAN_CONTROL.name,
          supportedAttributes: ['FanMode', 'PercentSetting', 'PercentCurrent'],
          supportedCommands: ['Step']
        });
      }

      // 5. Electrical Measurement Cluster: ONLY if hardware profile has verified energy metering
      if (hasEnergyMetering && (chCaps.includes('energy') || globalCaps.includes('energy'))) {
        serverClusters.push({
          clusterId: STANDARD_MATTER_CLUSTERS.ELECTRICAL_MEASUREMENT.id,
          clusterName: STANDARD_MATTER_CLUSTERS.ELECTRICAL_MEASUREMENT.name,
          supportedAttributes: ['RMSVoltage', 'RMSCurrent', 'ActivePower'],
          supportedCommands: []
        });
        serverClusters.push({
          clusterId: STANDARD_MATTER_CLUSTERS.ELECTRICAL_ENERGY_MEASUREMENT.id,
          clusterName: STANDARD_MATTER_CLUSTERS.ELECTRICAL_ENERGY_MEASUREMENT.name,
          supportedAttributes: ['CumulativeEnergyImported'],
          supportedCommands: []
        });
      }

      endpoints.push({
        endpointNumber: i,
        deviceType,
        channelIndex: i,
        serverClusters
      });
    }

    return endpoints;
  }

  /**
   * Evaluates compatibility and maps capabilities for an EH device variant.
   *
   * @param {String} productVariantId
   * @returns {Object} Capability mapping report
   */
  resolveMappingForVariant(productVariantId) {
    let metadata = null;
    if (this.productCatalogService && typeof this.productCatalogService.getProductVariant === 'function') {
      const def = this.productCatalogService.getProductVariant(productVariantId);
      metadata = def?.metadata || null;
    }

    if (!metadata) {
      // Fallback default structure for basic switchboards
      metadata = {
        productVariantId,
        productFamily: 'smart_switch',
        channelCount: 1,
        capabilities: ['switch', 'relay', 'local_switch'],
        hardwareProfile: { hasEnergyMetering: false }
      };
    }

    const deviceType = this.resolveMatterDeviceType(metadata);
    const endpoints = this.generateMatterEndpoints(metadata);
    const hasEnergyMetering = Boolean(metadata.hardwareProfile?.hasEnergyMetering);

    return {
      productVariantId,
      matterDeviceType: deviceType,
      isMatterCapable: true,
      hasEnergyMetering,
      endpoints,
      supportedClusters: endpoints.flatMap(ep => ep.serverClusters.map(sc => sc.clusterName)).filter((v, idx, arr) => arr.indexOf(v) === idx)
    };
  }
}

module.exports = {
  MatterCapabilityMappingService,
  STANDARD_MATTER_CLUSTERS
};
