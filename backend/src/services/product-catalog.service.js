/**
 * EH Home — Backend Product Catalog Service (Phase 27)
 *
 * Responsibilities:
 *  - Load product definitions from product-definitions/
 *  - In-memory indexing & fast cache for deterministic queries
 *  - Canonical product catalog entry formatting
 *  - Product discovery with category, family, capability, and connectivity filtering
 *  - Deterministic case-insensitive search with stable relevance ranking
 *  - Multi-dimensional compatibility resolver with structured diagnostics
 *  - Device capability resolution and schema validation
 *
 * Does NOT:
 *  - Directly execute device transport logic (delegates to Phase 26 ConnectivityService)
 *  - Expose internal manufacturing secrets or private keys
 */

'use strict';

const fs = require('fs');
const path = require('path');

const PRODUCT_DEFINITIONS_ROOT = path.join(__dirname, '../../../product-definitions');
const CAPABILITY_REGISTRY_PATH = path.join(__dirname, '../../../packages/contracts/capability/capability-registry.json');

const CATEGORY_METADATA = {
  switches: { id: 'switches', displayName: 'Smart Switches', icon: 'switch_access_shortcut_rounded', sortOrder: 1 },
  sockets: { id: 'sockets', displayName: 'Smart Sockets', icon: 'power_rounded', sortOrder: 2 },
  lighting: { id: 'lighting', displayName: 'Smart Lighting', icon: 'lightbulb_rounded', sortOrder: 3 },
  climate: { id: 'climate', displayName: 'Smart Climate', icon: 'thermostat_rounded', sortOrder: 4 },
  fans: { id: 'fans', displayName: 'Smart Fans', icon: 'mode_fan_rounded', sortOrder: 5 },
  sensors: { id: 'sensors', displayName: 'Smart Sensors', icon: 'sensors_rounded', sortOrder: 6 },
  energy: { id: 'energy', displayName: 'Energy Intelligence', icon: 'bolt_rounded', sortOrder: 7 },
  security: { id: 'security', displayName: 'Security & Access', icon: 'shield_rounded', sortOrder: 8 },
  appliances: { id: 'appliances', displayName: 'Appliances', icon: 'kitchen_rounded', sortOrder: 9 },
  controllers: { id: 'controllers', displayName: 'Hubs & Controllers', icon: 'hub_rounded', sortOrder: 10 }
};

const FAMILY_METADATA = {
  smart_switch: {
    id: 'smart_switch',
    slug: 'smart-switch',
    displayName: 'Smart Switches',
    category: 'switches',
    description: 'Modular capacitive and physical relay switchboard platform with real-time energy monitoring',
    icon: 'switch_access_shortcut_rounded',
    sortOrder: 1
  },
  smart_socket: {
    id: 'smart_socket',
    slug: 'smart-socket',
    displayName: 'Smart Sockets',
    category: 'sockets',
    description: 'High-power smart wall sockets with safety shutters and independent channel energy monitoring',
    icon: 'power_rounded',
    sortOrder: 2
  },
  smart_fan: {
    id: 'smart_fan',
    slug: 'smart-fan',
    displayName: 'Smart Ceiling Fans',
    category: 'fans',
    description: 'Capacitive multi-step smart ceiling fan controllers',
    icon: 'mode_fan_rounded',
    sortOrder: 3
  },
  smart_lighting: {
    id: 'smart_lighting',
    slug: 'smart-lighting',
    displayName: 'Smart Lighting',
    category: 'lighting',
    description: 'Tunable white and RGBCW intelligent lighting solutions',
    icon: 'lightbulb_rounded',
    sortOrder: 4
  }
};

class ProductCatalogService {
  constructor() {
    this._capabilityRegistry = null;
    this._productDefinitions = null;
    this._catalogEntries = null;
    this._entriesByVariantId = new Map();
    this._entriesByProductId = new Map();
    this._entriesBySku = new Map();
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

  resolveCapabilities(capabilityIds = []) {
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
  // Product Definitions Loader & Indexing
  // -----------------------------------------------------------------------

  loadProductDefinitions() {
    if (this._productDefinitions) return this._productDefinitions;

    const definitions = [];

    if (!fs.existsSync(PRODUCT_DEFINITIONS_ROOT)) {
      this._productDefinitions = [];
      return definitions;
    }

    const families = fs.readdirSync(PRODUCT_DEFINITIONS_ROOT).filter(entry => {
      const entryPath = path.join(PRODUCT_DEFINITIONS_ROOT, entry);
      return fs.statSync(entryPath).isDirectory() && !entry.startsWith('_') && entry !== 'tests';
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

        let assets = null;
        const assetsPath = path.join(variantPath, 'assets.json');
        if (fs.existsSync(assetsPath)) {
          assets = JSON.parse(fs.readFileSync(assetsPath, 'utf8'));
        }

        definitions.push({ metadata, assets, family, variant });
      }
    }

    this._productDefinitions = definitions;
    this._buildCatalogIndex(definitions);
    return definitions;
  }

  _buildCatalogIndex(definitions) {
    const entries = [];
    this._entriesByVariantId.clear();
    this._entriesByProductId.clear();
    this._entriesBySku.clear();

    for (const def of definitions) {
      const entry = this._normalizeCatalogEntry(def);
      entries.push(entry);
      this._entriesByVariantId.set(entry.variantId, entry);
      this._entriesBySku.set(entry.sku.toUpperCase(), entry);

      if (!this._entriesByProductId.has(entry.productId)) {
        this._entriesByProductId.set(entry.productId, []);
      }
      this._entriesByProductId.get(entry.productId).push(entry);
    }

    this._catalogEntries = entries;
  }

  _normalizeCatalogEntry(def) {
    const { metadata, assets, family, variant } = def;
    const familyKey = metadata.productFamily || family.replace('-', '_');
    const familyMeta = FAMILY_METADATA[familyKey] || {
      id: familyKey,
      slug: family,
      displayName: metadata.displayName,
      category: 'switches',
      description: ''
    };

    const category = familyMeta.category || 'switches';
    const variantId = metadata.productVariantId || `eh-${family}-${variant}`;
    const channelCount = metadata.channelCount || (metadata.channels ? metadata.channels.length : 1);
    const productId = `eh-${familyMeta.slug || family}`;
    const modelId = `eh-${familyMeta.slug || family}-gen1`;
    const sku = `EH-${familyKey.toUpperCase().replace('SMART_', '')}${variant.toUpperCase()}-001`;

    const connectivityProfile = metadata.connectivityProfile || {};
    const hardwareProfile = metadata.hardwareProfile || {};
    const capabilities = metadata.capabilities || [];

    // Controls
    const controls = (metadata.channels || []).map((ch, idx) => `channel_${ch.channelIndex || idx + 1}`);

    // Telemetry fields derived from capabilities
    const telemetry = [];
    if (capabilities.includes('energy')) telemetry.push('e_tot_wh', 'p_mw');
    if (capabilities.includes('voltage')) telemetry.push('v_mv');
    if (capabilities.includes('current')) telemetry.push('i_ma');
    if (capabilities.includes('power')) telemetry.push('p_mw');

    // Commissioning capabilities derived from connectivity
    const commissioningCapabilities = [];
    if (connectivityProfile.supportsBle) commissioningCapabilities.push('ble_provisioning');
    if (connectivityProfile.supportsWifi) commissioningCapabilities.push('wifi_provisioning');
    if (connectivityProfile.supportsThread) commissioningCapabilities.push('thread_commissioning');
    if (connectivityProfile.supportsMatter) commissioningCapabilities.push('matter_commissioning');

    // Connectivity capabilities
    const connectivityCapabilities = [];
    if (connectivityProfile.supportsWifi) connectivityCapabilities.push('wifi');
    if (connectivityProfile.supportsBle) connectivityCapabilities.push('ble');
    if (connectivityProfile.supportsThread) connectivityCapabilities.push('thread');
    if (connectivityProfile.supportsMatter) connectivityCapabilities.push('matter');

    // Automation capabilities
    const automationCapabilities = ['schedule', 'scene'];
    if (capabilities.includes('energy')) automationCapabilities.push('energy_threshold');
    if (capabilities.includes('local_switch')) automationCapabilities.push('switch_event');

    // Assets normalization
    const images = {
      hero: metadata.images?.hero || `assets/products/${family}_${variant}/hero.png`,
      front: metadata.images?.front || `assets/products/${family}_${variant}/front.png`,
      rear: metadata.images?.rear || `assets/products/${family}_${variant}/rear.png`,
      installed: metadata.images?.installed || `assets/products/${family}_${variant}/installed.png`,
      packaging: metadata.images?.packaging || `assets/products/${family}_${variant}/packaging.png`,
      technicalDiagram: metadata.images?.technicalDiagram || `assets/products/${family}_${variant}/diagram.png`,
      icon: metadata.images?.icon || `assets/icons/${category}.png`,
      thumbnail: metadata.images?.thumbnail || `assets/products/${family}_${variant}/thumb.png`
    };

    return {
      productId,
      productFamilyId: familyMeta.id,
      modelId,
      variantId,
      sku,
      marketingName: metadata.displayName || `EH Smart ${familyMeta.displayName} ${variant.toUpperCase()}`,
      technicalName: `${productId.toUpperCase()}-${variant.toUpperCase()}-${hardwareProfile.mcuFamily || 'ESP32C6'}`.toUpperCase(),
      description: metadata.description || `${familyMeta.displayName} with ${channelCount} channel(s) and energy monitoring`,
      productStatus: metadata.productStatus || 'ACTIVE',
      visibility: metadata.visibility || 'PUBLIC',
      category,
      subcategory: metadata.subcategory || 'in_wall',
      brand: 'EH',
      images,
      icon: familyMeta.icon || 'device_hub_rounded',
      channelCount,
      channels: metadata.channels || [],
      electricalSpecifications: metadata.electricalSpecifications || {
        voltageRange: '90V - 250V AC',
        frequencyHz: '50/60Hz',
        maxCurrentPerChannelAmps: 10.0,
        maxTotalCurrentAmps: 16.0
      },
      capabilities,
      controls,
      telemetry,
      automationCapabilities,
      connectivityCapabilities,
      commissioningCapabilities,
      otaCapabilities: {
        supported: capabilities.includes('ota'),
        dualPartition: true,
        firmwareFamily: metadata.firmwareFamily || 'esp32c6-platform'
      },
      supportedHardwareRevisions: metadata.supportedHardwareRevisions || ['HW_1_0'],
      supportedFirmwareVersions: metadata.supportedFirmwareVersions || ['1.0.0', '1.1.0'],
      matterSupport: Boolean(connectivityProfile.supportsMatter),
      threadSupport: Boolean(connectivityProfile.supportsThread),
      wifiSupport: Boolean(connectivityProfile.supportsWifi),
      bleProvisioningSupport: Boolean(connectivityProfile.supportsBle),
      energyMonitoringSupport: capabilities.includes('energy'),
      localControlSupport: capabilities.includes('local_switch') || capabilities.includes('switch')
    };
  }

  // -----------------------------------------------------------------------
  // Product Discovery Query Engine
  // -----------------------------------------------------------------------

  discoverProducts({
    category = null,
    family = null,
    capability = null,
    connectivity = null,
    status = 'ACTIVE',
    includeAllStatuses = false,
    page = 1,
    limit = 20,
    sort = 'name_asc'
  } = {}) {
    this.loadProductDefinitions();
    let items = [...(this._catalogEntries || [])];

    // Status filter
    if (!includeAllStatuses) {
      if (status) {
        items = items.filter(p => p.productStatus === status);
      } else {
        items = items.filter(p => p.productStatus === 'ACTIVE');
      }
    }

    // Category filter
    if (category) {
      items = items.filter(p => p.category.toLowerCase() === category.toLowerCase());
    }

    // Family filter
    if (family) {
      items = items.filter(p => p.productFamilyId.toLowerCase() === family.toLowerCase());
    }

    // Capability filter
    if (capability) {
      items = items.filter(p => p.capabilities.includes(capability));
    }

    // Connectivity filter
    if (connectivity) {
      const conn = connectivity.toLowerCase();
      items = items.filter(p => {
        if (conn === 'wifi') return p.wifiSupport;
        if (conn === 'ble') return p.bleProvisioningSupport;
        if (conn === 'thread') return p.threadSupport;
        if (conn === 'matter') return p.matterSupport;
        return p.connectivityCapabilities.includes(conn);
      });
    }

    // Stable sorting
    items.sort((a, b) => {
      if (sort === 'name_desc') return b.marketingName.localeCompare(a.marketingName);
      if (sort === 'channels_asc') return a.channelCount - b.channelCount;
      if (sort === 'channels_desc') return b.channelCount - a.channelCount;
      return a.marketingName.localeCompare(b.marketingName);
    });

    const total = items.length;
    const parsedPage = Math.max(1, parseInt(page, 10) || 1);
    const parsedLimit = Math.max(1, Math.min(100, parseInt(limit, 10) || 20));
    const totalPages = Math.ceil(total / parsedLimit);
    const offset = (parsedPage - 1) * parsedLimit;
    const paginatedProducts = items.slice(offset, offset + parsedLimit);

    // Facet counts
    const allActive = (this._catalogEntries || []).filter(p => includeAllStatuses || p.productStatus === 'ACTIVE');
    const categoryCounts = {};
    const familyCounts = {};
    const capSet = new Set();

    allActive.forEach(p => {
      categoryCounts[p.category] = (categoryCounts[p.category] || 0) + 1;
      familyCounts[p.productFamilyId] = (familyCounts[p.productFamilyId] || 0) + 1;
      p.capabilities.forEach(c => capSet.add(c));
    });

    const categories = Object.keys(categoryCounts).map(catId => ({
      id: catId,
      displayName: CATEGORY_METADATA[catId]?.displayName || catId,
      count: categoryCounts[catId]
    })).sort((a, b) => a.id.localeCompare(b.id));

    const families = Object.keys(familyCounts).map(famId => ({
      id: famId,
      displayName: FAMILY_METADATA[famId]?.displayName || famId,
      category: FAMILY_METADATA[famId]?.category || 'switches',
      count: familyCounts[famId]
    })).sort((a, b) => a.id.localeCompare(b.id));

    return {
      products: paginatedProducts,
      total,
      page: parsedPage,
      limit: parsedLimit,
      totalPages,
      categories,
      families,
      availableCapabilities: Array.from(capSet).sort()
    };
  }

  // -----------------------------------------------------------------------
  // Deterministic Search Engine
  // -----------------------------------------------------------------------

  searchProducts({ query = '', category = null, family = null, limit = 20, status = 'ACTIVE' } = {}) {
    this.loadProductDefinitions();
    const cleanQuery = (query || '').trim().toLowerCase();
    let candidateEntries = [...(this._catalogEntries || [])];

    if (status) {
      candidateEntries = candidateEntries.filter(p => p.productStatus === status);
    }
    if (category) {
      candidateEntries = candidateEntries.filter(p => p.category.toLowerCase() === category.toLowerCase());
    }
    if (family) {
      candidateEntries = candidateEntries.filter(p => p.productFamilyId.toLowerCase() === family.toLowerCase());
    }

    if (!cleanQuery) {
      const results = candidateEntries.slice(0, limit).map(p => ({
        product: p,
        matchedFields: ['default'],
        relevanceScore: 1.0
      }));
      return { query: '', results, total: results.length };
    }

    const scored = [];

    for (const product of candidateEntries) {
      let score = 0;
      const matchedFields = [];

      const marketingName = product.marketingName.toLowerCase();
      const technicalName = product.technicalName.toLowerCase();
      const sku = product.sku.toLowerCase();
      const variantId = product.variantId.toLowerCase();
      const familyId = product.productFamilyId.toLowerCase();
      const description = product.description.toLowerCase();

      // Exact SKU match
      if (sku === cleanQuery) {
        score += 1.0;
        matchedFields.push('sku');
      } else if (sku.includes(cleanQuery)) {
        score += 0.8;
        matchedFields.push('sku');
      }

      // Name matches
      if (marketingName === cleanQuery) {
        score += 0.95;
        matchedFields.push('marketingName');
      } else if (marketingName.startsWith(cleanQuery)) {
        score += 0.85;
        matchedFields.push('marketingName');
      } else if (marketingName.includes(cleanQuery)) {
        score += 0.65;
        matchedFields.push('marketingName');
      }

      // Technical name
      if (technicalName.includes(cleanQuery)) {
        score += 0.5;
        matchedFields.push('technicalName');
      }

      // Variant ID
      if (variantId.includes(cleanQuery)) {
        score += 0.5;
        matchedFields.push('variantId');
      }

      // Family match
      if (familyId.includes(cleanQuery)) {
        score += 0.4;
        matchedFields.push('productFamilyId');
      }

      // Description match
      if (description.includes(cleanQuery)) {
        score += 0.3;
        matchedFields.push('description');
      }

      // Capabilities matching
      for (const cap of product.capabilities) {
        if (cap.toLowerCase().includes(cleanQuery)) {
          score += 0.45;
          matchedFields.push(`capability:${cap}`);
          break;
        }
      }

      if (score > 0) {
        scored.push({
          product,
          matchedFields,
          relevanceScore: parseFloat(score.toFixed(3))
        });
      }
    }

    // Sort by relevance score DESC, then marketingName ASC
    scored.sort((a, b) => {
      if (b.relevanceScore !== a.relevanceScore) {
        return b.relevanceScore - a.relevanceScore;
      }
      return a.product.marketingName.localeCompare(b.product.marketingName);
    });

    const parsedLimit = Math.max(1, Math.min(100, parseInt(limit, 10) || 20));
    const results = scored.slice(0, parsedLimit);

    return {
      query,
      results,
      total: scored.length
    };
  }

  // -----------------------------------------------------------------------
  // Product Detail & Variant Resolvers
  // -----------------------------------------------------------------------

  getCategories() {
    return Object.values(CATEGORY_METADATA);
  }

  getFamilies() {
    return Object.values(FAMILY_METADATA);
  }

  getProductById(productId) {
    this.loadProductDefinitions();
    const entries = this._entriesByProductId.get(productId);
    if (!entries || entries.length === 0) return null;
    return {
      productId,
      marketingName: entries[0].marketingName,
      productFamilyId: entries[0].productFamilyId,
      category: entries[0].category,
      variants: entries
    };
  }

  getProductVariant(variantId) {
    const defs = this.loadProductDefinitions();
    return defs.find(d => d.metadata.productVariantId === variantId) || null;
  }

  getCatalogEntryByVariantId(variantId) {
    this.loadProductDefinitions();
    return this._entriesByVariantId.get(variantId) || null;
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
  // Multi-Dimensional Compatibility Resolver
  // -----------------------------------------------------------------------

  resolveCompatibility({
    productVariantId,
    hardwareRevision = null,
    firmwareVersion = null,
    homeCapabilities = {},
    availableConnectivity = {},
    installedHubProtocols = []
  } = {}) {
    this.loadProductDefinitions();
    const entry = this._entriesByVariantId.get(productVariantId);
    const evaluatedAt = new Date().toISOString();

    if (!entry) {
      return {
        status: 'INCOMPATIBLE',
        isCompatible: false,
        reasons: [
          {
            code: 'UNKNOWN_PRODUCT_VARIANT',
            message: `Product variant '${productVariantId}' was not recognized in the canonical catalog.`,
            severity: 'BLOCKING',
            remedy: 'Select a valid product variant from the catalog or update application definitions.'
          }
        ],
        supportedTransports: [],
        recommendedCommissioningTransport: 'NONE',
        unsupportedFeatures: ['all'],
        evaluatedAt
      };
    }

    const reasons = [];
    const unsupportedFeatures = [];
    let isCompatible = true;
    let hasWarnings = false;

    // 1. Hardware Revision Check
    if (hardwareRevision) {
      const isHwSupported = entry.supportedHardwareRevisions.includes(hardwareRevision);
      if (!isHwSupported) {
        isCompatible = false;
        reasons.push({
          code: 'UNSUPPORTED_HARDWARE_REVISION',
          message: `Hardware revision '${hardwareRevision}' is not supported by product definition (Supported: ${entry.supportedHardwareRevisions.join(', ')}).`,
          severity: 'BLOCKING',
          remedy: 'Ensure device hardware matches supported revisions.'
        });
      }
    }

    // 2. Firmware Version Check
    if (firmwareVersion) {
      const minFw = entry.supportedFirmwareVersions[0] || '1.0.0';
      if (this._compareSemver(firmwareVersion, minFw) < 0) {
        hasWarnings = true;
        reasons.push({
          code: 'FIRMWARE_UPDATE_RECOMMENDED',
          message: `Device firmware '${firmwareVersion}' is older than recommended baseline '${minFw}'.`,
          severity: 'WARNING',
          remedy: 'Perform an Over-The-Air (OTA) firmware update after onboarding.'
        });
      }
    }

    // 3. Connectivity & Commissioning Transports Check
    const wifiAvailable = availableConnectivity.wifi !== undefined ? availableConnectivity.wifi : true;
    const bleAvailable = availableConnectivity.ble !== undefined ? availableConnectivity.ble : true;
    const threadAvailable = availableConnectivity.thread !== undefined ? availableConnectivity.thread : false;
    const matterAvailable = availableConnectivity.matter !== undefined ? availableConnectivity.matter : false;

    const supportedTransports = [];
    if (entry.wifiSupport) supportedTransports.push('WIFI_MQTT');
    if (entry.bleProvisioningSupport) supportedTransports.push('BLE');
    if (entry.threadSupport) supportedTransports.push('THREAD');
    if (entry.matterSupport) supportedTransports.push('MATTER');

    let recommendedCommissioningTransport = 'BLE';

    // BLE Check
    if (entry.bleProvisioningSupport) {
      if (bleAvailable) {
        recommendedCommissioningTransport = 'BLE';
        reasons.push({
          code: 'BLE_PROVISIONING_AVAILABLE',
          message: 'Bluetooth Low Energy (BLE) onboarding is fully available.',
          severity: 'INFO',
          remedy: null
        });
      } else {
        hasWarnings = true;
        reasons.push({
          code: 'BLE_UNAVAILABLE',
          message: 'Bluetooth is unavailable or disabled on your client phone.',
          severity: 'WARNING',
          remedy: 'Enable Bluetooth in device settings to perform quick nearby setup.'
        });
      }
    }

    // Wi-Fi Check
    if (entry.wifiSupport) {
      if (wifiAvailable) {
        reasons.push({
          code: 'WIFI_NETWORK_COMPATIBLE',
          message: 'Home 2.4 GHz Wi-Fi network is detected and ready.',
          severity: 'INFO',
          remedy: null
        });
      } else {
        isCompatible = false;
        reasons.push({
          code: 'WIFI_UNAVAILABLE',
          message: 'This device requires an active 2.4 GHz Wi-Fi home network connection.',
          severity: 'BLOCKING',
          remedy: 'Connect your phone to a 2.4 GHz Wi-Fi network before commissioning.'
        });
      }
    }

    // Thread Check
    if (entry.threadSupport) {
      if (threadAvailable || installedHubProtocols.includes('THREAD')) {
        reasons.push({
          code: 'THREAD_BORDER_ROUTER_DETECTED',
          message: 'A compatible Thread Border Router was found in this home.',
          severity: 'INFO',
          remedy: null
        });
      } else {
        unsupportedFeatures.push('thread_mesh');
        hasWarnings = true;
        reasons.push({
          code: 'THREAD_BORDER_ROUTER_MISSING',
          message: 'No Thread Border Router found in this home. Fallback Wi-Fi/BLE will be used.',
          severity: 'WARNING',
          remedy: 'Add an EH Home Border Router to enable low-power Thread mesh networking.'
        });
      }
    }

    // Matter Check
    if (entry.matterSupport) {
      if (matterAvailable || installedHubProtocols.includes('MATTER')) {
        reasons.push({
          code: 'MATTER_FABRIC_COMPATIBLE',
          message: 'Home supports Matter multi-admin fabric commissioning.',
          severity: 'INFO',
          remedy: null
        });
      } else {
        unsupportedFeatures.push('matter_ecosystem_sync');
      }
    }

    let status = 'COMPATIBLE';
    if (!isCompatible) {
      status = 'INCOMPATIBLE';
    } else if (hasWarnings) {
      status = 'PARTIALLY_COMPATIBLE';
    }

    return {
      status,
      isCompatible: status !== 'INCOMPATIBLE',
      reasons,
      supportedTransports,
      recommendedCommissioningTransport,
      unsupportedFeatures,
      evaluatedAt
    };
  }

  _compareSemver(v1, v2) {
    const p1 = (v1 || '0.0.0').split('.').map(n => parseInt(n, 10) || 0);
    const p2 = (v2 || '0.0.0').split('.').map(n => parseInt(n, 10) || 0);
    for (let i = 0; i < 3; i++) {
      if (p1[i] > p2[i]) return 1;
      if (p1[i] < p2[i]) return -1;
    }
    return 0;
  }

  // -----------------------------------------------------------------------
  // Device Capability Resolution (Preserved for backward compatibility)
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
  // Validation
  // -----------------------------------------------------------------------

  validateProductDefinition(metadata) {
    const errors = [];

    const required = [
      'schemaVersion',
      'productVariantId',
      'productFamily',
      'displayName',
      'channelCount',
      'channels',
      'hardwareProfile',
      'connectivityProfile',
      'capabilities',
      'firmwareFamily',
      'supportedHardwareRevisions'
    ];

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
  // API Response Formatters
  // -----------------------------------------------------------------------

  formatProductListResponse() {
    return this.getAllProductVariants();
  }

  formatProductVariantResponse(variantId) {
    const def = this.getProductVariant(variantId);
    if (!def) return null;

    const { resolved } = this.resolveCapabilities(def.metadata.capabilities);
    const catalogEntry = this.getCatalogEntryByVariantId(variantId);

    return {
      ...def.metadata,
      catalogEntry,
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
