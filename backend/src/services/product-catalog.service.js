/**
 * EH Home — Backend Product Catalog Service (Phase 3)
 *
 * Responsibilities:
 *  - Load product definitions from product-definitions/
 *  - Validate metadata against product schema
 *  - Resolve product variants
 *  - Resolve capabilities from canonical registry
 *  - Expose product metadata in canonical API format
 *
 * Does NOT:
 *  - Connect to devices
 *  - Implement authentication
 *  - Implement MQTT / Matter / Thread
 */

const fs = require('fs');
const path = require('path');

// Paths relative to this file (backend/src/services/)
const PRODUCT_DEFINITIONS_ROOT = path.join(__dirname, '../../../product-definitions');
const CAPABILITY_REGISTRY_PATH = path.join(__dirname, '../../../packages/contracts/capability/capability-registry.json');

class ProductCatalogService {
  constructor() {
    this._capabilityRegistry = null;
    this._productDefinitions = null;
  }

  // -----------------------------------------------------------------------
  // Capability Registry
  // -----------------------------------------------------------------------

  loadCapabilityRegistry() {
    if (this._capabilityRegistry) return this._capabilityRegistry;
    const raw = fs.readFileSync(CAPABILITY_REGISTRY_PATH, 'utf8');
    this._capabilityRegistry = JSON.parse(raw);
    return this._capabilityRegistry;
  }

  getCapability(capabilityId) {
    const registry = this.loadCapabilityRegistry();
    return registry[capabilityId] || null;
  }

  getAllCapabilities() {
    const registry = this.loadCapabilityRegistry();
    return Object.values(registry);
  }

  resolveCapabilities(capabilityIds) {
    const registry = this.loadCapabilityRegistry();
    const resolved = [];
    const unknown = [];

    for (const id of capabilityIds) {
      if (registry[id]) {
        resolved.push(registry[id]);
      } else {
        unknown.push(id);
      }
    }

    return { resolved, unknown };
  }

  // -----------------------------------------------------------------------
  // Product Definitions Loader
  // -----------------------------------------------------------------------

  loadProductDefinitions() {
    if (this._productDefinitions) return this._productDefinitions;

    const definitions = [];

    // Walk product-definitions/ directory structure
    const families = fs.readdirSync(PRODUCT_DEFINITIONS_ROOT).filter(entry => {
      const entryPath = path.join(PRODUCT_DEFINITIONS_ROOT, entry);
      return fs.statSync(entryPath).isDirectory() && !entry.startsWith('_');
    });

    for (const family of families) {
      const familyPath = path.join(PRODUCT_DEFINITIONS_ROOT, family);
      const variants = fs.readdirSync(familyPath).filter(entry => {
        const entryPath = path.join(familyPath, entry);
        return fs.statSync(entryPath).isDirectory();
      });

      for (const variant of variants) {
        const variantPath = path.join(familyPath, variant);
        const metadataPath = path.join(variantPath, 'metadata.json');
        if (!fs.existsSync(metadataPath)) continue;

        const metadata = JSON.parse(fs.readFileSync(metadataPath, 'utf8'));

        // Load assets if present
        let assets = null;
        const assetsPath = path.join(variantPath, 'assets.json');
        if (fs.existsSync(assetsPath)) {
          assets = JSON.parse(fs.readFileSync(assetsPath, 'utf8'));
        }

        definitions.push({ metadata, assets, family, variant });
      }
    }

    this._productDefinitions = definitions;
    return definitions;
  }

  // -----------------------------------------------------------------------
  // Validation
  // -----------------------------------------------------------------------

  validateProductDefinition(metadata) {
    const errors = [];

    const required = ['schemaVersion', 'productVariantId', 'productFamily', 'displayName',
      'channelCount', 'channels', 'hardwareProfile', 'connectivityProfile',
      'capabilities', 'firmwareFamily', 'supportedHardwareRevisions'];

    for (const field of required) {
      if (metadata[field] === undefined || metadata[field] === null) {
        errors.push(`Missing required field: ${field}`);
      }
    }

    if (metadata.channelCount !== undefined && metadata.channels !== undefined) {
      if (metadata.channels.length !== metadata.channelCount) {
        errors.push(`channels.length (${metadata.channels.length}) does not match channelCount (${metadata.channelCount})`);
      }
    }

    if (metadata.capabilities && Array.isArray(metadata.capabilities)) {
      const registry = this.loadCapabilityRegistry();
      const unknownCaps = metadata.capabilities.filter(c => !registry[c]);
      if (unknownCaps.length > 0) {
        errors.push(`Unknown capabilities: ${unknownCaps.join(', ')}`);
      }
    }

    if (metadata.channels && Array.isArray(metadata.channels)) {
      metadata.channels.forEach((ch, i) => {
        if (ch.channelIndex === undefined) errors.push(`Channel ${i}: missing channelIndex`);
        if (ch.channelIndex < 1) errors.push(`Channel ${i}: channelIndex must be >= 1`);
        if (!ch.capabilities || !Array.isArray(ch.capabilities)) {
          errors.push(`Channel ${i}: missing capabilities array`);
        }
      });
    }

    if (metadata.supportedHardwareRevisions && metadata.supportedHardwareRevisions.length === 0) {
      errors.push('supportedHardwareRevisions cannot be empty');
    }

    return { valid: errors.length === 0, errors };
  }

  // -----------------------------------------------------------------------
  // Product Resolution
  // -----------------------------------------------------------------------

  getProductVariant(variantId) {
    const defs = this.loadProductDefinitions();
    return defs.find(d => d.metadata.productVariantId === variantId) || null;
  }

  getAllProductVariants() {
    return this.loadProductDefinitions().map(d => ({
      productVariantId: d.metadata.productVariantId,
      productFamily: d.metadata.productFamily,
      displayName: d.metadata.displayName,
      channelCount: d.metadata.channelCount,
      capabilities: d.metadata.capabilities,
      firmwareFamily: d.metadata.firmwareFamily,
      supportedHardwareRevisions: d.metadata.supportedHardwareRevisions
    }));
  }

  // -----------------------------------------------------------------------
  // Capability Resolution for a Device
  // -----------------------------------------------------------------------

  resolveDeviceCapabilities({ productVariantId, deviceId, channelLabels = {}, deviceState = null }) {
    const def = this.getProductVariant(productVariantId);
    if (!def) {
      return { error: `Product variant '${productVariantId}' not found` };
    }

    const { metadata } = def;
    const { resolved: resolvedCaps, unknown } = this.resolveCapabilities(metadata.capabilities);

    const channels = metadata.channels.map(ch => ({
      channelIndex: ch.channelIndex,
      defaultLabel: ch.defaultLabel || `Channel ${ch.channelIndex}`,
      customLabel: channelLabels[String(ch.channelIndex)] || null,
      displayName: channelLabels[String(ch.channelIndex)] || ch.defaultLabel || `Channel ${ch.channelIndex}`,
      capabilities: ch.capabilities,
      resolvedCapabilities: ch.capabilities.map(capId => this.getCapability(capId)).filter(Boolean),
      state: deviceState?.channels?.find(s => s.channelIndex === ch.channelIndex) || null
    }));

    // Build UI hint map from resolved capabilities
    const capabilityUiHints = {};
    resolvedCaps.forEach(cap => {
      capabilityUiHints[cap.capabilityId] = cap.uiComponentHint;
    });

    return {
      deviceId: deviceId || null,
      productVariantId,
      displayName: metadata.displayName,
      channelCount: metadata.channelCount,
      capabilities: resolvedCaps.map(c => c.capabilityId),
      capabilityDetails: resolvedCaps,
      capabilityUiHints,
      channels,
      hardwareProfile: metadata.hardwareProfile,
      connectivityProfile: metadata.connectivityProfile,
      firmwareFamily: metadata.firmwareFamily,
      hasEnergyMonitoring: metadata.capabilities.includes('energy'),
      hasFanSpeed: metadata.capabilities.includes('fan_speed'),
      hasBrightness: metadata.capabilities.includes('brightness'),
      hasCCT: metadata.capabilities.includes('cct'),
      hasOTA: metadata.capabilities.includes('ota'),
      hasAutomation: metadata.capabilities.includes('automation'),
      unknownCapabilities: unknown
    };
  }

  // -----------------------------------------------------------------------
  // API Response Formatters
  // -----------------------------------------------------------------------

  formatProductListResponse() {
    return this.getAllProductVariants();
  }

  formatProductVariantResponse(variantId) {
    const def = this.getProductVariant(variantId);
    if (!def) return null;

    const { resolved } = this.resolveCapabilities(def.metadata.capabilities);
    return {
      ...def.metadata,
      resolvedCapabilities: resolved,
      assets: def.assets
    };
  }

  formatCapabilityListResponse() {
    return this.getAllCapabilities();
  }

  formatCapabilityResponse(capabilityId) {
    return this.getCapability(capabilityId);
  }
}

module.exports = { ProductCatalogService };
