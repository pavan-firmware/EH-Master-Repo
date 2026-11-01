"use strict";
/**
 * EH Home Product Static Definition Adapter
 *
 * Deterministic mapper between static product-definitions/*.json files
 * and canonical database / API domain models.
 * Preserves 100% semantic compatibility without altering existing static definitions.
 */
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
      desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
    Object.defineProperty(o, "default", { enumerable: true, value: v });
}) : function(o, v) {
    o["default"] = v;
});
var __importStar = (this && this.__importStar) || (function () {
    var ownKeys = function(o) {
        ownKeys = Object.getOwnPropertyNames || function (o) {
            var ar = [];
            for (var k in o) if (Object.prototype.hasOwnProperty.call(o, k)) ar[ar.length] = k;
            return ar;
        };
        return ownKeys(o);
    };
    return function (mod) {
        if (mod && mod.__esModule) return mod;
        var result = {};
        if (mod != null) for (var k = ownKeys(mod), i = 0; i < k.length; i++) if (k[i] !== "default") __createBinding(result, mod, k[i]);
        __setModuleDefault(result, mod);
        return result;
    };
})();
Object.defineProperty(exports, "__esModule", { value: true });
exports.normalizeFamily = normalizeFamily;
exports.deriveProductAndVariantSlugs = deriveProductAndVariantSlugs;
exports.mapStaticDefinitionToCanonical = mapStaticDefinitionToCanonical;
exports.findProductDefinitionsDir = findProductDefinitionsDir;
exports.loadAllStaticProductDefinitions = loadAllStaticProductDefinitions;
const fs = __importStar(require("fs"));
const path = __importStar(require("path"));
/**
 * Normalizes family slugs and produces standard display names.
 */
function normalizeFamily(rawFamily) {
    const normalizedSlug = rawFamily.toLowerCase().replace(/_/g, '-');
    const familyId = rawFamily.toLowerCase().replace(/-/g, '_');
    const familyNames = {
        smart_switch: 'Smart Switch',
        smart_socket: 'Smart Socket',
        smart_fan: 'Smart Fan',
        smart_light: 'Smart Light',
        smart_lighting: 'Smart Light',
        smart_hub: 'Smart Hub',
        smart_controller: 'Smart Controller',
        sensor_node: 'Sensor Node',
        smart_sensor: 'Smart Sensor',
        smart_climate: 'Smart Climate',
    };
    const displayName = familyNames[familyId] || familyId.replace(/_/g, ' ').replace(/\b\w/g, (c) => c.toUpperCase());
    return { familyId, slug: normalizedSlug, displayName };
}
/**
 * Deterministically splits a variantId into a base productId and variantSlug.
 * Examples:
 *   "eh-smart-switch-1x" -> { productId: "eh-smart-switch", variantSlug: "1x" }
 *   "eh-sensor-node-v1"   -> { productId: "eh-sensor-node", variantSlug: "v1" }
 *   "eh-smart-light-cct"  -> { productId: "eh-smart-light", variantSlug: "cct" }
 */
function deriveProductAndVariantSlugs(productVariantId) {
    const match = productVariantId.match(/^(eh-[a-z0-9-]+)-(1x|2x|3x|4x|v\d+|cct|rgb|rgbw)$/i);
    if (match && match[1] && match[2]) {
        return {
            productId: match[1].toLowerCase(),
            variantSlug: match[2].toLowerCase(),
        };
    }
    // Fallback: split at last hyphen
    const lastHyphen = productVariantId.lastIndexOf('-');
    if (lastHyphen > 0) {
        return {
            productId: productVariantId.substring(0, lastHyphen).toLowerCase(),
            variantSlug: productVariantId.substring(lastHyphen + 1).toLowerCase(),
        };
    }
    return {
        productId: productVariantId.toLowerCase(),
        variantSlug: 'default',
    };
}
/**
 * Deterministically maps static metadata.json + assets.json into canonical domain entities.
 */
function mapStaticDefinitionToCanonical(metadata, assetsJson) {
    if (!metadata || !metadata.productVariantId) {
        throw new Error('Invalid product definition: missing productVariantId');
    }
    const { familyId, slug: familySlug, displayName: familyDisplayName } = normalizeFamily(metadata.productFamily || 'generic');
    const { productId, variantSlug } = deriveProductAndVariantSlugs(metadata.productVariantId);
    // Derive base product display name (e.g. "EH Smart Switch" from "EH Smart Switch 1X")
    const productDisplayName = metadata.displayName
        ? metadata.displayName.replace(/\s+(1X|2X|3X|4X|v1|CCT)$/i, '').trim()
        : productId.replace(/-/g, ' ').toUpperCase();
    const family = {
        id: familyId,
        slug: familySlug,
        displayName: familyDisplayName,
        description: `EH Home ${familyDisplayName} Product Family`,
    };
    const product = {
        id: productId,
        familyId,
        displayName: productDisplayName,
        description: `EH Home ${productDisplayName}`,
        schemaVersion: metadata.schemaVersion || 1,
        status: 'PUBLISHED',
    };
    const variant = {
        id: metadata.productVariantId,
        productId,
        variantSlug,
        displayName: metadata.displayName || metadata.productVariantId,
        channelCount: metadata.channelCount || 1,
        channels: metadata.channels || [],
        hardwareProfile: metadata.hardwareProfile || {},
        connectivityProfile: metadata.connectivityProfile || {},
        capabilities: metadata.capabilities || [],
        electricalSpecifications: metadata.electricalSpecifications || {},
        firmwareFamily: metadata.firmwareFamily || 'generic-firmware',
        supportedHardwareRevisions: metadata.supportedHardwareRevisions || ['HW_1_0'],
    };
    // Map Assets
    const assets = [];
    let sortOrder = 0;
    if (metadata.images && typeof metadata.images === 'object') {
        for (const [kind, url] of Object.entries(metadata.images)) {
            if (typeof url === 'string') {
                const validKind = (['hero', 'front', 'rear', 'installed', 'packaging', 'thumbnail', 'icon'].includes(kind)
                    ? kind
                    : 'render');
                assets.push({
                    assetId: `${variant.id}-img-${kind}`,
                    productVariantId: variant.id,
                    kind: validKind,
                    purpose: kind === 'thumbnail' ? 'catalog' : 'marketing',
                    url,
                    mimeType: url.endsWith('.png') ? 'image/png' : url.endsWith('.svg') ? 'image/svg+xml' : 'image/jpeg',
                    sortOrder: sortOrder++,
                    isPublished: true,
                });
            }
        }
    }
    if (assetsJson && assetsJson.assets) {
        if (assetsJson.assets.diagrams) {
            for (const [diagKey, url] of Object.entries(assetsJson.assets.diagrams)) {
                if (typeof url === 'string') {
                    assets.push({
                        assetId: `${variant.id}-diag-${diagKey}`,
                        productVariantId: variant.id,
                        kind: 'diagram',
                        purpose: diagKey === 'wiring' ? 'wiring' : 'dimensions',
                        url,
                        mimeType: 'image/svg+xml',
                        sortOrder: sortOrder++,
                        isPublished: true,
                    });
                }
            }
        }
        if (assetsJson.assets.renders) {
            for (const [renderKey, url] of Object.entries(assetsJson.assets.renders)) {
                if (typeof url === 'string') {
                    assets.push({
                        assetId: `${variant.id}-render-${renderKey}`,
                        productVariantId: variant.id,
                        kind: 'render',
                        purpose: 'marketing',
                        url,
                        mimeType: 'image/png',
                        sortOrder: sortOrder++,
                        isPublished: true,
                    });
                }
            }
        }
    }
    // Map Capabilities
    const capabilities = [];
    const variantCapabilities = metadata.capabilities || [];
    for (const capId of variantCapabilities) {
        capabilities.push({
            productVariantId: variant.id,
            capabilityId: capId,
            channelIndex: null,
            config: {},
        });
    }
    // Also include per-channel capabilities if present
    if (Array.isArray(metadata.channels)) {
        for (const ch of metadata.channels) {
            if (Array.isArray(ch.capabilities)) {
                for (const capId of ch.capabilities) {
                    capabilities.push({
                        productVariantId: variant.id,
                        capabilityId: capId,
                        channelIndex: ch.channelIndex ?? null,
                        config: ch.config || {},
                    });
                }
            }
        }
    }
    return { family, product, variant, assets, capabilities };
}
/**
 * Locates the canonical product-definitions directory across monorepo layouts.
 */
function findProductDefinitionsDir(baseDir) {
    if (baseDir && fs.existsSync(baseDir))
        return baseDir;
    let current = process.cwd();
    for (let i = 0; i < 5; i++) {
        const candidate = path.join(current, 'product-definitions');
        if (fs.existsSync(candidate) && fs.statSync(candidate).isDirectory()) {
            return candidate;
        }
        const parent = path.dirname(current);
        if (parent === current)
            break;
        current = parent;
    }
    const fromDirname = path.resolve(__dirname, '../../../../product-definitions');
    if (fs.existsSync(fromDirname))
        return fromDirname;
    return path.resolve(process.cwd(), 'product-definitions');
}
/**
 * Discovers and maps all 11 product definitions from the filesystem.
 */
function loadAllStaticProductDefinitions(baseDir) {
    const root = findProductDefinitionsDir(baseDir);
    if (!fs.existsSync(root)) {
        return [];
    }
    const results = [];
    const entries = fs.readdirSync(root, { withFileTypes: true });
    for (const entry of entries) {
        if (!entry.isDirectory() || entry.name.startsWith('_') || entry.name === 'tests' || entry.name === 'node_modules') {
            continue;
        }
        const familyDir = path.join(root, entry.name);
        const variantDirs = fs.readdirSync(familyDir, { withFileTypes: true });
        for (const vDir of variantDirs) {
            if (!vDir.isDirectory())
                continue;
            const vPath = path.join(familyDir, vDir.name);
            const metaPath = path.join(vPath, 'metadata.json');
            const assetPath = path.join(vPath, 'assets.json');
            if (fs.existsSync(metaPath)) {
                try {
                    const meta = JSON.parse(fs.readFileSync(metaPath, 'utf8'));
                    const assets = fs.existsSync(assetPath) ? JSON.parse(fs.readFileSync(assetPath, 'utf8')) : undefined;
                    results.push(mapStaticDefinitionToCanonical(meta, assets));
                }
                catch {
                    // ignore corrupted/test files
                }
            }
        }
    }
    return results;
}
//# sourceMappingURL=product.adapter.js.map