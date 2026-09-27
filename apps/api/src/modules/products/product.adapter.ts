/**
 * EH Home Product Static Definition Adapter
 *
 * Deterministic mapper between static product-definitions/*.json files
 * and canonical database / API domain models.
 * Preserves 100% semantic compatibility without altering existing static definitions.
 */

import * as fs from 'fs';
import * as path from 'path';
import { ProductAsset } from './product.schema';

export interface MappedProductFamily {
  id: string;
  slug: string;
  displayName: string;
  description: string;
}

export interface MappedProduct {
  id: string;
  familyId: string;
  displayName: string;
  description: string;
  schemaVersion: number;
  status: 'DRAFT' | 'STAGED' | 'PUBLISHED' | 'DEPRECATED' | 'RETIRED';
}

export interface MappedProductVariant {
  id: string;
  productId: string;
  variantSlug: string;
  displayName: string;
  channelCount: number;
  channels: any[];
  hardwareProfile: any;
  connectivityProfile: any;
  capabilities: string[];
  electricalSpecifications: Record<string, any>;
  firmwareFamily: string;
  supportedHardwareRevisions: string[];
}

export interface MappedProductCapability {
  productVariantId: string;
  capabilityId: string;
  channelIndex: number | null;
  config: Record<string, any>;
}

export interface CanonicalMappedProductDefinition {
  family: MappedProductFamily;
  product: MappedProduct;
  variant: MappedProductVariant;
  assets: ProductAsset[];
  capabilities: MappedProductCapability[];
}

/**
 * Normalizes family slugs and produces standard display names.
 */
export function normalizeFamily(rawFamily: string): { familyId: string; slug: string; displayName: string } {
  const normalizedSlug = rawFamily.toLowerCase().replace(/_/g, '-');
  const familyId = rawFamily.toLowerCase().replace(/-/g, '_');

  const familyNames: Record<string, string> = {
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
export function deriveProductAndVariantSlugs(productVariantId: string): { productId: string; variantSlug: string } {
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
export function mapStaticDefinitionToCanonical(
  metadata: any,
  assetsJson?: any
): CanonicalMappedProductDefinition {
  if (!metadata || !metadata.productVariantId) {
    throw new Error('Invalid product definition: missing productVariantId');
  }

  const { familyId, slug: familySlug, displayName: familyDisplayName } = normalizeFamily(
    metadata.productFamily || 'generic'
  );
  const { productId, variantSlug } = deriveProductAndVariantSlugs(metadata.productVariantId);

  // Derive base product display name (e.g. "EH Smart Switch" from "EH Smart Switch 1X")
  const productDisplayName = metadata.displayName
    ? metadata.displayName.replace(/\s+(1X|2X|3X|4X|v1|CCT)$/i, '').trim()
    : productId.replace(/-/g, ' ').toUpperCase();

  const family: MappedProductFamily = {
    id: familyId,
    slug: familySlug,
    displayName: familyDisplayName,
    description: `EH Home ${familyDisplayName} Product Family`,
  };

  const product: MappedProduct = {
    id: productId,
    familyId,
    displayName: productDisplayName,
    description: `EH Home ${productDisplayName}`,
    schemaVersion: metadata.schemaVersion || 1,
    status: 'PUBLISHED',
  };

  const variant: MappedProductVariant = {
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
  const assets: ProductAsset[] = [];
  let sortOrder = 0;

  if (metadata.images && typeof metadata.images === 'object') {
    for (const [kind, url] of Object.entries(metadata.images)) {
      if (typeof url === 'string') {
        const validKind = (['hero', 'front', 'rear', 'installed', 'packaging', 'thumbnail', 'icon'].includes(kind)
          ? kind
          : 'render') as ProductAsset['kind'];
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
  const capabilities: MappedProductCapability[] = [];
  const variantCapabilities: string[] = metadata.capabilities || [];

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
export function findProductDefinitionsDir(baseDir?: string): string {
  if (baseDir && fs.existsSync(baseDir)) return baseDir;

  let current = process.cwd();
  for (let i = 0; i < 5; i++) {
    const candidate = path.join(current, 'product-definitions');
    if (fs.existsSync(candidate) && fs.statSync(candidate).isDirectory()) {
      return candidate;
    }
    const parent = path.dirname(current);
    if (parent === current) break;
    current = parent;
  }

  const fromDirname = path.resolve(__dirname, '../../../../product-definitions');
  if (fs.existsSync(fromDirname)) return fromDirname;

  return path.resolve(process.cwd(), 'product-definitions');
}

/**
 * Discovers and maps all 11 product definitions from the filesystem.
 */
export function loadAllStaticProductDefinitions(baseDir?: string): CanonicalMappedProductDefinition[] {
  const root = findProductDefinitionsDir(baseDir);
  if (!fs.existsSync(root)) {
    return [];
  }

  const results: CanonicalMappedProductDefinition[] = [];
  const entries = fs.readdirSync(root, { withFileTypes: true });

  for (const entry of entries) {
    if (!entry.isDirectory() || entry.name.startsWith('_') || entry.name === 'tests' || entry.name === 'node_modules') {
      continue;
    }

    const familyDir = path.join(root, entry.name);
    const variantDirs = fs.readdirSync(familyDir, { withFileTypes: true });

    for (const vDir of variantDirs) {
      if (!vDir.isDirectory()) continue;
      const vPath = path.join(familyDir, vDir.name);
      const metaPath = path.join(vPath, 'metadata.json');
      const assetPath = path.join(vPath, 'assets.json');

      if (fs.existsSync(metaPath)) {
        try {
          const meta = JSON.parse(fs.readFileSync(metaPath, 'utf8'));
          const assets = fs.existsSync(assetPath) ? JSON.parse(fs.readFileSync(assetPath, 'utf8')) : undefined;
          results.push(mapStaticDefinitionToCanonical(meta, assets));
        } catch {
          // ignore corrupted/test files
        }
      }
    }
  }

  return results;
}
