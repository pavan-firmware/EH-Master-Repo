/**
 * EH Home Product Static Definition Adapter
 *
 * Deterministic mapper between static product-definitions/*.json files
 * and canonical database / API domain models.
 * Preserves 100% semantic compatibility without altering existing static definitions.
 */
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
export declare function normalizeFamily(rawFamily: string): {
    familyId: string;
    slug: string;
    displayName: string;
};
/**
 * Deterministically splits a variantId into a base productId and variantSlug.
 * Examples:
 *   "eh-smart-switch-1x" -> { productId: "eh-smart-switch", variantSlug: "1x" }
 *   "eh-sensor-node-v1"   -> { productId: "eh-sensor-node", variantSlug: "v1" }
 *   "eh-smart-light-cct"  -> { productId: "eh-smart-light", variantSlug: "cct" }
 */
export declare function deriveProductAndVariantSlugs(productVariantId: string): {
    productId: string;
    variantSlug: string;
};
/**
 * Deterministically maps static metadata.json + assets.json into canonical domain entities.
 */
export declare function mapStaticDefinitionToCanonical(metadata: any, assetsJson?: any): CanonicalMappedProductDefinition;
/**
 * Locates the canonical product-definitions directory across monorepo layouts.
 */
export declare function findProductDefinitionsDir(baseDir?: string): string;
/**
 * Discovers and maps all 11 product definitions from the filesystem.
 */
export declare function loadAllStaticProductDefinitions(baseDir?: string): CanonicalMappedProductDefinition[];
//# sourceMappingURL=product.adapter.d.ts.map