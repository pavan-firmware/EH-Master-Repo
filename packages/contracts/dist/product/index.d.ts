import { z } from 'zod';
export declare const ProductStatusSchema: z.ZodEnum<["DRAFT", "STAGED", "PUBLISHED", "DEPRECATED", "RETIRED"]>;
export type ProductStatus = z.infer<typeof ProductStatusSchema>;
export declare const ProductCategorySchema: z.ZodEnum<["switches", "sockets", "lighting", "climate", "fans", "sensors", "energy", "security", "appliances", "controllers"]>;
export type ProductCategory = z.infer<typeof ProductCategorySchema>;
export declare const ChannelDefSchema: z.ZodObject<{
    channelIndex: z.ZodNumber;
    defaultLabel: z.ZodString;
    capabilities: z.ZodArray<z.ZodString, "many">;
    config: z.ZodOptional<z.ZodRecord<z.ZodString, z.ZodUnknown>>;
}, "strip", z.ZodTypeAny, {
    channelIndex: number;
    defaultLabel: string;
    capabilities: string[];
    config?: Record<string, unknown> | undefined;
}, {
    channelIndex: number;
    defaultLabel: string;
    capabilities: string[];
    config?: Record<string, unknown> | undefined;
}>;
export type ChannelDef = z.infer<typeof ChannelDefSchema>;
export declare const HardwareProfileSchema: z.ZodObject<{
    schemaVersion: z.ZodDefault<z.ZodNumber>;
    mcuFamily: z.ZodEnum<["esp32", "esp32-c3", "esp32-c6", "esp32-s3", "esp32-wroom", "custom"]>;
    flashSizeBytes: z.ZodNumber;
    psramSizeBytes: z.ZodOptional<z.ZodNullable<z.ZodNumber>>;
    hasEnergyMetering: z.ZodBoolean;
    energyMeterChip: z.ZodOptional<z.ZodNullable<z.ZodString>>;
    maxRelayAmpsPerChannel: z.ZodOptional<z.ZodNumber>;
    maxTotalAmps: z.ZodOptional<z.ZodNumber>;
    gpioMap: z.ZodDefault<z.ZodRecord<z.ZodString, z.ZodNumber>>;
}, "strip", z.ZodTypeAny, {
    schemaVersion: number;
    mcuFamily: "custom" | "esp32" | "esp32-c3" | "esp32-c6" | "esp32-s3" | "esp32-wroom";
    flashSizeBytes: number;
    hasEnergyMetering: boolean;
    gpioMap: Record<string, number>;
    psramSizeBytes?: number | null | undefined;
    energyMeterChip?: string | null | undefined;
    maxRelayAmpsPerChannel?: number | undefined;
    maxTotalAmps?: number | undefined;
}, {
    mcuFamily: "custom" | "esp32" | "esp32-c3" | "esp32-c6" | "esp32-s3" | "esp32-wroom";
    flashSizeBytes: number;
    hasEnergyMetering: boolean;
    schemaVersion?: number | undefined;
    psramSizeBytes?: number | null | undefined;
    energyMeterChip?: string | null | undefined;
    maxRelayAmpsPerChannel?: number | undefined;
    maxTotalAmps?: number | undefined;
    gpioMap?: Record<string, number> | undefined;
}>;
export type HardwareProfile = z.infer<typeof HardwareProfileSchema>;
export declare const ConnectivityProfileSchema: z.ZodObject<{
    schemaVersion: z.ZodDefault<z.ZodNumber>;
    supportsWifi: z.ZodBoolean;
    wifiStandards: z.ZodDefault<z.ZodArray<z.ZodString, "many">>;
    supportsBle: z.ZodBoolean;
    bleVersion: z.ZodOptional<z.ZodNullable<z.ZodString>>;
    supportsThread: z.ZodDefault<z.ZodBoolean>;
    threadVersion: z.ZodOptional<z.ZodNullable<z.ZodString>>;
    supportsMatter: z.ZodDefault<z.ZodBoolean>;
    matterDeviceType: z.ZodOptional<z.ZodNullable<z.ZodString>>;
}, "strip", z.ZodTypeAny, {
    schemaVersion: number;
    supportsWifi: boolean;
    wifiStandards: string[];
    supportsBle: boolean;
    supportsThread: boolean;
    supportsMatter: boolean;
    bleVersion?: string | null | undefined;
    threadVersion?: string | null | undefined;
    matterDeviceType?: string | null | undefined;
}, {
    supportsWifi: boolean;
    supportsBle: boolean;
    schemaVersion?: number | undefined;
    wifiStandards?: string[] | undefined;
    bleVersion?: string | null | undefined;
    supportsThread?: boolean | undefined;
    threadVersion?: string | null | undefined;
    supportsMatter?: boolean | undefined;
    matterDeviceType?: string | null | undefined;
}>;
export type ConnectivityProfile = z.infer<typeof ConnectivityProfileSchema>;
export declare const ProductVariantSchema: z.ZodObject<{
    variantId: z.ZodString;
    modelId: z.ZodString;
    sku: z.ZodString;
    marketingName: z.ZodString;
    technicalName: z.ZodString;
    channelCount: z.ZodNumber;
    channels: z.ZodArray<z.ZodObject<{
        channelIndex: z.ZodNumber;
        defaultLabel: z.ZodString;
        capabilities: z.ZodArray<z.ZodString, "many">;
        config: z.ZodOptional<z.ZodRecord<z.ZodString, z.ZodUnknown>>;
    }, "strip", z.ZodTypeAny, {
        channelIndex: number;
        defaultLabel: string;
        capabilities: string[];
        config?: Record<string, unknown> | undefined;
    }, {
        channelIndex: number;
        defaultLabel: string;
        capabilities: string[];
        config?: Record<string, unknown> | undefined;
    }>, "many">;
    hardwareProfile: z.ZodObject<{
        schemaVersion: z.ZodDefault<z.ZodNumber>;
        mcuFamily: z.ZodEnum<["esp32", "esp32-c3", "esp32-c6", "esp32-s3", "esp32-wroom", "custom"]>;
        flashSizeBytes: z.ZodNumber;
        psramSizeBytes: z.ZodOptional<z.ZodNullable<z.ZodNumber>>;
        hasEnergyMetering: z.ZodBoolean;
        energyMeterChip: z.ZodOptional<z.ZodNullable<z.ZodString>>;
        maxRelayAmpsPerChannel: z.ZodOptional<z.ZodNumber>;
        maxTotalAmps: z.ZodOptional<z.ZodNumber>;
        gpioMap: z.ZodDefault<z.ZodRecord<z.ZodString, z.ZodNumber>>;
    }, "strip", z.ZodTypeAny, {
        schemaVersion: number;
        mcuFamily: "custom" | "esp32" | "esp32-c3" | "esp32-c6" | "esp32-s3" | "esp32-wroom";
        flashSizeBytes: number;
        hasEnergyMetering: boolean;
        gpioMap: Record<string, number>;
        psramSizeBytes?: number | null | undefined;
        energyMeterChip?: string | null | undefined;
        maxRelayAmpsPerChannel?: number | undefined;
        maxTotalAmps?: number | undefined;
    }, {
        mcuFamily: "custom" | "esp32" | "esp32-c3" | "esp32-c6" | "esp32-s3" | "esp32-wroom";
        flashSizeBytes: number;
        hasEnergyMetering: boolean;
        schemaVersion?: number | undefined;
        psramSizeBytes?: number | null | undefined;
        energyMeterChip?: string | null | undefined;
        maxRelayAmpsPerChannel?: number | undefined;
        maxTotalAmps?: number | undefined;
        gpioMap?: Record<string, number> | undefined;
    }>;
    connectivityProfile: z.ZodObject<{
        schemaVersion: z.ZodDefault<z.ZodNumber>;
        supportsWifi: z.ZodBoolean;
        wifiStandards: z.ZodDefault<z.ZodArray<z.ZodString, "many">>;
        supportsBle: z.ZodBoolean;
        bleVersion: z.ZodOptional<z.ZodNullable<z.ZodString>>;
        supportsThread: z.ZodDefault<z.ZodBoolean>;
        threadVersion: z.ZodOptional<z.ZodNullable<z.ZodString>>;
        supportsMatter: z.ZodDefault<z.ZodBoolean>;
        matterDeviceType: z.ZodOptional<z.ZodNullable<z.ZodString>>;
    }, "strip", z.ZodTypeAny, {
        schemaVersion: number;
        supportsWifi: boolean;
        wifiStandards: string[];
        supportsBle: boolean;
        supportsThread: boolean;
        supportsMatter: boolean;
        bleVersion?: string | null | undefined;
        threadVersion?: string | null | undefined;
        matterDeviceType?: string | null | undefined;
    }, {
        supportsWifi: boolean;
        supportsBle: boolean;
        schemaVersion?: number | undefined;
        wifiStandards?: string[] | undefined;
        bleVersion?: string | null | undefined;
        supportsThread?: boolean | undefined;
        threadVersion?: string | null | undefined;
        supportsMatter?: boolean | undefined;
        matterDeviceType?: string | null | undefined;
    }>;
    capabilities: z.ZodArray<z.ZodString, "many">;
    electricalSpecifications: z.ZodDefault<z.ZodRecord<z.ZodString, z.ZodUnknown>>;
    firmwareFamily: z.ZodString;
    supportedHardwareRevisions: z.ZodArray<z.ZodString, "many">;
}, "strip", z.ZodTypeAny, {
    capabilities: string[];
    variantId: string;
    modelId: string;
    sku: string;
    marketingName: string;
    technicalName: string;
    channelCount: number;
    channels: {
        channelIndex: number;
        defaultLabel: string;
        capabilities: string[];
        config?: Record<string, unknown> | undefined;
    }[];
    hardwareProfile: {
        schemaVersion: number;
        mcuFamily: "custom" | "esp32" | "esp32-c3" | "esp32-c6" | "esp32-s3" | "esp32-wroom";
        flashSizeBytes: number;
        hasEnergyMetering: boolean;
        gpioMap: Record<string, number>;
        psramSizeBytes?: number | null | undefined;
        energyMeterChip?: string | null | undefined;
        maxRelayAmpsPerChannel?: number | undefined;
        maxTotalAmps?: number | undefined;
    };
    connectivityProfile: {
        schemaVersion: number;
        supportsWifi: boolean;
        wifiStandards: string[];
        supportsBle: boolean;
        supportsThread: boolean;
        supportsMatter: boolean;
        bleVersion?: string | null | undefined;
        threadVersion?: string | null | undefined;
        matterDeviceType?: string | null | undefined;
    };
    electricalSpecifications: Record<string, unknown>;
    firmwareFamily: string;
    supportedHardwareRevisions: string[];
}, {
    capabilities: string[];
    variantId: string;
    modelId: string;
    sku: string;
    marketingName: string;
    technicalName: string;
    channelCount: number;
    channels: {
        channelIndex: number;
        defaultLabel: string;
        capabilities: string[];
        config?: Record<string, unknown> | undefined;
    }[];
    hardwareProfile: {
        mcuFamily: "custom" | "esp32" | "esp32-c3" | "esp32-c6" | "esp32-s3" | "esp32-wroom";
        flashSizeBytes: number;
        hasEnergyMetering: boolean;
        schemaVersion?: number | undefined;
        psramSizeBytes?: number | null | undefined;
        energyMeterChip?: string | null | undefined;
        maxRelayAmpsPerChannel?: number | undefined;
        maxTotalAmps?: number | undefined;
        gpioMap?: Record<string, number> | undefined;
    };
    connectivityProfile: {
        supportsWifi: boolean;
        supportsBle: boolean;
        schemaVersion?: number | undefined;
        wifiStandards?: string[] | undefined;
        bleVersion?: string | null | undefined;
        supportsThread?: boolean | undefined;
        threadVersion?: string | null | undefined;
        supportsMatter?: boolean | undefined;
        matterDeviceType?: string | null | undefined;
    };
    firmwareFamily: string;
    supportedHardwareRevisions: string[];
    electricalSpecifications?: Record<string, unknown> | undefined;
}>;
export type ProductVariant = z.infer<typeof ProductVariantSchema>;
export declare const ProductMasterSchema: z.ZodObject<{
    productId: z.ZodString;
    slug: z.ZodString;
    displayName: z.ZodString;
    category: z.ZodEnum<["switches", "sockets", "lighting", "climate", "fans", "sensors", "energy", "security", "appliances", "controllers"]>;
    description: z.ZodDefault<z.ZodString>;
    status: z.ZodDefault<z.ZodEnum<["DRAFT", "STAGED", "PUBLISHED", "DEPRECATED", "RETIRED"]>>;
    variants: z.ZodDefault<z.ZodArray<z.ZodObject<{
        variantId: z.ZodString;
        modelId: z.ZodString;
        sku: z.ZodString;
        marketingName: z.ZodString;
        technicalName: z.ZodString;
        channelCount: z.ZodNumber;
        channels: z.ZodArray<z.ZodObject<{
            channelIndex: z.ZodNumber;
            defaultLabel: z.ZodString;
            capabilities: z.ZodArray<z.ZodString, "many">;
            config: z.ZodOptional<z.ZodRecord<z.ZodString, z.ZodUnknown>>;
        }, "strip", z.ZodTypeAny, {
            channelIndex: number;
            defaultLabel: string;
            capabilities: string[];
            config?: Record<string, unknown> | undefined;
        }, {
            channelIndex: number;
            defaultLabel: string;
            capabilities: string[];
            config?: Record<string, unknown> | undefined;
        }>, "many">;
        hardwareProfile: z.ZodObject<{
            schemaVersion: z.ZodDefault<z.ZodNumber>;
            mcuFamily: z.ZodEnum<["esp32", "esp32-c3", "esp32-c6", "esp32-s3", "esp32-wroom", "custom"]>;
            flashSizeBytes: z.ZodNumber;
            psramSizeBytes: z.ZodOptional<z.ZodNullable<z.ZodNumber>>;
            hasEnergyMetering: z.ZodBoolean;
            energyMeterChip: z.ZodOptional<z.ZodNullable<z.ZodString>>;
            maxRelayAmpsPerChannel: z.ZodOptional<z.ZodNumber>;
            maxTotalAmps: z.ZodOptional<z.ZodNumber>;
            gpioMap: z.ZodDefault<z.ZodRecord<z.ZodString, z.ZodNumber>>;
        }, "strip", z.ZodTypeAny, {
            schemaVersion: number;
            mcuFamily: "custom" | "esp32" | "esp32-c3" | "esp32-c6" | "esp32-s3" | "esp32-wroom";
            flashSizeBytes: number;
            hasEnergyMetering: boolean;
            gpioMap: Record<string, number>;
            psramSizeBytes?: number | null | undefined;
            energyMeterChip?: string | null | undefined;
            maxRelayAmpsPerChannel?: number | undefined;
            maxTotalAmps?: number | undefined;
        }, {
            mcuFamily: "custom" | "esp32" | "esp32-c3" | "esp32-c6" | "esp32-s3" | "esp32-wroom";
            flashSizeBytes: number;
            hasEnergyMetering: boolean;
            schemaVersion?: number | undefined;
            psramSizeBytes?: number | null | undefined;
            energyMeterChip?: string | null | undefined;
            maxRelayAmpsPerChannel?: number | undefined;
            maxTotalAmps?: number | undefined;
            gpioMap?: Record<string, number> | undefined;
        }>;
        connectivityProfile: z.ZodObject<{
            schemaVersion: z.ZodDefault<z.ZodNumber>;
            supportsWifi: z.ZodBoolean;
            wifiStandards: z.ZodDefault<z.ZodArray<z.ZodString, "many">>;
            supportsBle: z.ZodBoolean;
            bleVersion: z.ZodOptional<z.ZodNullable<z.ZodString>>;
            supportsThread: z.ZodDefault<z.ZodBoolean>;
            threadVersion: z.ZodOptional<z.ZodNullable<z.ZodString>>;
            supportsMatter: z.ZodDefault<z.ZodBoolean>;
            matterDeviceType: z.ZodOptional<z.ZodNullable<z.ZodString>>;
        }, "strip", z.ZodTypeAny, {
            schemaVersion: number;
            supportsWifi: boolean;
            wifiStandards: string[];
            supportsBle: boolean;
            supportsThread: boolean;
            supportsMatter: boolean;
            bleVersion?: string | null | undefined;
            threadVersion?: string | null | undefined;
            matterDeviceType?: string | null | undefined;
        }, {
            supportsWifi: boolean;
            supportsBle: boolean;
            schemaVersion?: number | undefined;
            wifiStandards?: string[] | undefined;
            bleVersion?: string | null | undefined;
            supportsThread?: boolean | undefined;
            threadVersion?: string | null | undefined;
            supportsMatter?: boolean | undefined;
            matterDeviceType?: string | null | undefined;
        }>;
        capabilities: z.ZodArray<z.ZodString, "many">;
        electricalSpecifications: z.ZodDefault<z.ZodRecord<z.ZodString, z.ZodUnknown>>;
        firmwareFamily: z.ZodString;
        supportedHardwareRevisions: z.ZodArray<z.ZodString, "many">;
    }, "strip", z.ZodTypeAny, {
        capabilities: string[];
        variantId: string;
        modelId: string;
        sku: string;
        marketingName: string;
        technicalName: string;
        channelCount: number;
        channels: {
            channelIndex: number;
            defaultLabel: string;
            capabilities: string[];
            config?: Record<string, unknown> | undefined;
        }[];
        hardwareProfile: {
            schemaVersion: number;
            mcuFamily: "custom" | "esp32" | "esp32-c3" | "esp32-c6" | "esp32-s3" | "esp32-wroom";
            flashSizeBytes: number;
            hasEnergyMetering: boolean;
            gpioMap: Record<string, number>;
            psramSizeBytes?: number | null | undefined;
            energyMeterChip?: string | null | undefined;
            maxRelayAmpsPerChannel?: number | undefined;
            maxTotalAmps?: number | undefined;
        };
        connectivityProfile: {
            schemaVersion: number;
            supportsWifi: boolean;
            wifiStandards: string[];
            supportsBle: boolean;
            supportsThread: boolean;
            supportsMatter: boolean;
            bleVersion?: string | null | undefined;
            threadVersion?: string | null | undefined;
            matterDeviceType?: string | null | undefined;
        };
        electricalSpecifications: Record<string, unknown>;
        firmwareFamily: string;
        supportedHardwareRevisions: string[];
    }, {
        capabilities: string[];
        variantId: string;
        modelId: string;
        sku: string;
        marketingName: string;
        technicalName: string;
        channelCount: number;
        channels: {
            channelIndex: number;
            defaultLabel: string;
            capabilities: string[];
            config?: Record<string, unknown> | undefined;
        }[];
        hardwareProfile: {
            mcuFamily: "custom" | "esp32" | "esp32-c3" | "esp32-c6" | "esp32-s3" | "esp32-wroom";
            flashSizeBytes: number;
            hasEnergyMetering: boolean;
            schemaVersion?: number | undefined;
            psramSizeBytes?: number | null | undefined;
            energyMeterChip?: string | null | undefined;
            maxRelayAmpsPerChannel?: number | undefined;
            maxTotalAmps?: number | undefined;
            gpioMap?: Record<string, number> | undefined;
        };
        connectivityProfile: {
            supportsWifi: boolean;
            supportsBle: boolean;
            schemaVersion?: number | undefined;
            wifiStandards?: string[] | undefined;
            bleVersion?: string | null | undefined;
            supportsThread?: boolean | undefined;
            threadVersion?: string | null | undefined;
            supportsMatter?: boolean | undefined;
            matterDeviceType?: string | null | undefined;
        };
        firmwareFamily: string;
        supportedHardwareRevisions: string[];
        electricalSpecifications?: Record<string, unknown> | undefined;
    }>, "many">>;
    metadata: z.ZodDefault<z.ZodRecord<z.ZodString, z.ZodUnknown>>;
}, "strip", z.ZodTypeAny, {
    status: "DRAFT" | "STAGED" | "PUBLISHED" | "DEPRECATED" | "RETIRED";
    productId: string;
    slug: string;
    displayName: string;
    category: "switches" | "sockets" | "lighting" | "climate" | "fans" | "sensors" | "energy" | "security" | "appliances" | "controllers";
    description: string;
    variants: {
        capabilities: string[];
        variantId: string;
        modelId: string;
        sku: string;
        marketingName: string;
        technicalName: string;
        channelCount: number;
        channels: {
            channelIndex: number;
            defaultLabel: string;
            capabilities: string[];
            config?: Record<string, unknown> | undefined;
        }[];
        hardwareProfile: {
            schemaVersion: number;
            mcuFamily: "custom" | "esp32" | "esp32-c3" | "esp32-c6" | "esp32-s3" | "esp32-wroom";
            flashSizeBytes: number;
            hasEnergyMetering: boolean;
            gpioMap: Record<string, number>;
            psramSizeBytes?: number | null | undefined;
            energyMeterChip?: string | null | undefined;
            maxRelayAmpsPerChannel?: number | undefined;
            maxTotalAmps?: number | undefined;
        };
        connectivityProfile: {
            schemaVersion: number;
            supportsWifi: boolean;
            wifiStandards: string[];
            supportsBle: boolean;
            supportsThread: boolean;
            supportsMatter: boolean;
            bleVersion?: string | null | undefined;
            threadVersion?: string | null | undefined;
            matterDeviceType?: string | null | undefined;
        };
        electricalSpecifications: Record<string, unknown>;
        firmwareFamily: string;
        supportedHardwareRevisions: string[];
    }[];
    metadata: Record<string, unknown>;
}, {
    productId: string;
    slug: string;
    displayName: string;
    category: "switches" | "sockets" | "lighting" | "climate" | "fans" | "sensors" | "energy" | "security" | "appliances" | "controllers";
    status?: "DRAFT" | "STAGED" | "PUBLISHED" | "DEPRECATED" | "RETIRED" | undefined;
    description?: string | undefined;
    variants?: {
        capabilities: string[];
        variantId: string;
        modelId: string;
        sku: string;
        marketingName: string;
        technicalName: string;
        channelCount: number;
        channels: {
            channelIndex: number;
            defaultLabel: string;
            capabilities: string[];
            config?: Record<string, unknown> | undefined;
        }[];
        hardwareProfile: {
            mcuFamily: "custom" | "esp32" | "esp32-c3" | "esp32-c6" | "esp32-s3" | "esp32-wroom";
            flashSizeBytes: number;
            hasEnergyMetering: boolean;
            schemaVersion?: number | undefined;
            psramSizeBytes?: number | null | undefined;
            energyMeterChip?: string | null | undefined;
            maxRelayAmpsPerChannel?: number | undefined;
            maxTotalAmps?: number | undefined;
            gpioMap?: Record<string, number> | undefined;
        };
        connectivityProfile: {
            supportsWifi: boolean;
            supportsBle: boolean;
            schemaVersion?: number | undefined;
            wifiStandards?: string[] | undefined;
            bleVersion?: string | null | undefined;
            supportsThread?: boolean | undefined;
            threadVersion?: string | null | undefined;
            supportsMatter?: boolean | undefined;
            matterDeviceType?: string | null | undefined;
        };
        firmwareFamily: string;
        supportedHardwareRevisions: string[];
        electricalSpecifications?: Record<string, unknown> | undefined;
    }[] | undefined;
    metadata?: Record<string, unknown> | undefined;
}>;
export type ProductMaster = z.infer<typeof ProductMasterSchema>;
export declare const ProductCatalogEntrySchema: z.ZodObject<{
    id: z.ZodString;
    name: z.ZodString;
    category: z.ZodEnum<["switches", "sockets", "lighting", "climate", "fans", "sensors", "energy", "security", "appliances", "controllers"]>;
    categoryDisplayName: z.ZodString;
    family: z.ZodString;
    familyDisplayName: z.ZodString;
    description: z.ZodDefault<z.ZodString>;
    channelCount: z.ZodNumber;
    capabilities: z.ZodArray<z.ZodString, "many">;
    supportedTransports: z.ZodArray<z.ZodString, "many">;
    firmwareFamily: z.ZodString;
    assets: z.ZodObject<{
        diagrams: z.ZodDefault<z.ZodRecord<z.ZodString, z.ZodString>>;
        renders: z.ZodDefault<z.ZodRecord<z.ZodString, z.ZodString>>;
    }, "strip", z.ZodTypeAny, {
        diagrams: Record<string, string>;
        renders: Record<string, string>;
    }, {
        diagrams?: Record<string, string> | undefined;
        renders?: Record<string, string> | undefined;
    }>;
    isAvailable: z.ZodDefault<z.ZodBoolean>;
}, "strip", z.ZodTypeAny, {
    capabilities: string[];
    channelCount: number;
    firmwareFamily: string;
    category: "switches" | "sockets" | "lighting" | "climate" | "fans" | "sensors" | "energy" | "security" | "appliances" | "controllers";
    description: string;
    id: string;
    name: string;
    categoryDisplayName: string;
    family: string;
    familyDisplayName: string;
    supportedTransports: string[];
    assets: {
        diagrams: Record<string, string>;
        renders: Record<string, string>;
    };
    isAvailable: boolean;
}, {
    capabilities: string[];
    channelCount: number;
    firmwareFamily: string;
    category: "switches" | "sockets" | "lighting" | "climate" | "fans" | "sensors" | "energy" | "security" | "appliances" | "controllers";
    id: string;
    name: string;
    categoryDisplayName: string;
    family: string;
    familyDisplayName: string;
    supportedTransports: string[];
    assets: {
        diagrams?: Record<string, string> | undefined;
        renders?: Record<string, string> | undefined;
    };
    description?: string | undefined;
    isAvailable?: boolean | undefined;
}>;
export type ProductCatalogEntry = z.infer<typeof ProductCatalogEntrySchema>;
export interface CanonicalProductDefinition {
    variantId: string;
    displayName: string;
    category: ProductCategory;
    firmwareFamily: string;
    supportedHardwareRevisions: readonly string[];
}
export declare const CANONICAL_PRODUCT_DEFINITIONS: readonly CanonicalProductDefinition[];
export declare const CANONICAL_APPROVED_VARIANTS: ReadonlySet<string>;
export declare const PRODUCT_VARIANT_NAMES: Record<string, string>;
export declare const CANONICAL_HARDWARE_REVISIONS: ReadonlySet<string>;
/**
 * Checks if a compound productVariantId + hardwareRevision is canonically supported.
 */
export declare function isCanonicalProductHardwareSupported(productVariantId: string, hardwareRevision: string): boolean;
/**
 * Resolves the authoritative hardware description for a compound productVariantId + hardwareRevision.
 * Returns undefined if the product variant is unknown or if the revision is not supported for that variant.
 */
export declare function getHardwareRevisionDescription(productVariantId: string, hardwareRevision: string): string | undefined;
/**
 * Resolves the CanonicalProductDefinition by variant ID.
 */
export declare function getCanonicalProductDefinition(productVariantId: string): CanonicalProductDefinition | undefined;
//# sourceMappingURL=index.d.ts.map