/**
 * EH Home Product Domain Schemas
 *
 * Request validation schemas and response contracts for Product & Design Management.
 * Reuses canonical contracts from @eh-home/contracts.
 */
import { z } from 'zod';
export declare const ListProductsQuerySchema: z.ZodObject<{
    familyId: z.ZodOptional<z.ZodString>;
    status: z.ZodOptional<z.ZodEnum<["DRAFT", "STAGED", "PUBLISHED", "DEPRECATED", "RETIRED"]>>;
    category: z.ZodOptional<z.ZodEnum<["switches", "sockets", "lighting", "climate", "fans", "sensors", "energy", "security", "appliances", "controllers"]>>;
    connectivity: z.ZodOptional<z.ZodEnum<["wifi", "ble", "thread", "matter"]>>;
    capability: z.ZodOptional<z.ZodString>;
    search: z.ZodOptional<z.ZodString>;
    limit: z.ZodDefault<z.ZodNumber>;
    offset: z.ZodDefault<z.ZodNumber>;
}, "strip", z.ZodTypeAny, {
    limit: number;
    offset: number;
    status?: "DRAFT" | "STAGED" | "PUBLISHED" | "DEPRECATED" | "RETIRED" | undefined;
    search?: string | undefined;
    familyId?: string | undefined;
    category?: "switches" | "sockets" | "lighting" | "climate" | "fans" | "sensors" | "energy" | "security" | "appliances" | "controllers" | undefined;
    connectivity?: "wifi" | "ble" | "thread" | "matter" | undefined;
    capability?: string | undefined;
}, {
    status?: "DRAFT" | "STAGED" | "PUBLISHED" | "DEPRECATED" | "RETIRED" | undefined;
    search?: string | undefined;
    familyId?: string | undefined;
    category?: "switches" | "sockets" | "lighting" | "climate" | "fans" | "sensors" | "energy" | "security" | "appliances" | "controllers" | undefined;
    connectivity?: "wifi" | "ble" | "thread" | "matter" | undefined;
    capability?: string | undefined;
    limit?: number | undefined;
    offset?: number | undefined;
}>;
export type ListProductsQuery = z.infer<typeof ListProductsQuerySchema>;
export declare const GetProductParamsSchema: z.ZodObject<{
    productId: z.ZodString;
}, "strip", z.ZodTypeAny, {
    productId: string;
}, {
    productId: string;
}>;
export type GetProductParams = z.infer<typeof GetProductParamsSchema>;
export declare const GetVariantParamsSchema: z.ZodObject<{
    variantId: z.ZodString;
}, "strip", z.ZodTypeAny, {
    variantId: string;
}, {
    variantId: string;
}>;
export type GetVariantParams = z.infer<typeof GetVariantParamsSchema>;
export declare const ProductAssetSchema: z.ZodObject<{
    assetId: z.ZodString;
    productVariantId: z.ZodString;
    kind: z.ZodEnum<["hero", "front", "rear", "installed", "packaging", "technicalDiagram", "diagram", "render", "icon", "thumbnail"]>;
    purpose: z.ZodEnum<["marketing", "technical", "packaging", "catalog", "wiring", "dimensions"]>;
    url: z.ZodString;
    mimeType: z.ZodOptional<z.ZodString>;
    sortOrder: z.ZodDefault<z.ZodNumber>;
    isPublished: z.ZodDefault<z.ZodBoolean>;
}, "strip", z.ZodTypeAny, {
    url: string;
    assetId: string;
    productVariantId: string;
    kind: "hero" | "front" | "rear" | "installed" | "packaging" | "technicalDiagram" | "diagram" | "render" | "icon" | "thumbnail";
    purpose: "packaging" | "marketing" | "technical" | "catalog" | "wiring" | "dimensions";
    sortOrder: number;
    isPublished: boolean;
    mimeType?: string | undefined;
}, {
    url: string;
    assetId: string;
    productVariantId: string;
    kind: "hero" | "front" | "rear" | "installed" | "packaging" | "technicalDiagram" | "diagram" | "render" | "icon" | "thumbnail";
    purpose: "packaging" | "marketing" | "technical" | "catalog" | "wiring" | "dimensions";
    mimeType?: string | undefined;
    sortOrder?: number | undefined;
    isPublished?: boolean | undefined;
}>;
export type ProductAsset = z.infer<typeof ProductAssetSchema>;
export declare const VariantDetailSchema: z.ZodObject<{
    variantId: z.ZodString;
    productId: z.ZodString;
    variantSlug: z.ZodString;
    displayName: z.ZodString;
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
    electricalSpecifications: z.ZodRecord<z.ZodString, z.ZodUnknown>;
    firmwareFamily: z.ZodString;
    supportedHardwareRevisions: z.ZodArray<z.ZodString, "many">;
    assets: z.ZodDefault<z.ZodArray<z.ZodObject<{
        assetId: z.ZodString;
        productVariantId: z.ZodString;
        kind: z.ZodEnum<["hero", "front", "rear", "installed", "packaging", "technicalDiagram", "diagram", "render", "icon", "thumbnail"]>;
        purpose: z.ZodEnum<["marketing", "technical", "packaging", "catalog", "wiring", "dimensions"]>;
        url: z.ZodString;
        mimeType: z.ZodOptional<z.ZodString>;
        sortOrder: z.ZodDefault<z.ZodNumber>;
        isPublished: z.ZodDefault<z.ZodBoolean>;
    }, "strip", z.ZodTypeAny, {
        url: string;
        assetId: string;
        productVariantId: string;
        kind: "hero" | "front" | "rear" | "installed" | "packaging" | "technicalDiagram" | "diagram" | "render" | "icon" | "thumbnail";
        purpose: "packaging" | "marketing" | "technical" | "catalog" | "wiring" | "dimensions";
        sortOrder: number;
        isPublished: boolean;
        mimeType?: string | undefined;
    }, {
        url: string;
        assetId: string;
        productVariantId: string;
        kind: "hero" | "front" | "rear" | "installed" | "packaging" | "technicalDiagram" | "diagram" | "render" | "icon" | "thumbnail";
        purpose: "packaging" | "marketing" | "technical" | "catalog" | "wiring" | "dimensions";
        mimeType?: string | undefined;
        sortOrder?: number | undefined;
        isPublished?: boolean | undefined;
    }>, "many">>;
    createdAt: z.ZodString;
}, "strip", z.ZodTypeAny, {
    productId: string;
    variantId: string;
    variantSlug: string;
    displayName: string;
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
    capabilities: string[];
    electricalSpecifications: Record<string, unknown>;
    firmwareFamily: string;
    supportedHardwareRevisions: string[];
    assets: {
        url: string;
        assetId: string;
        productVariantId: string;
        kind: "hero" | "front" | "rear" | "installed" | "packaging" | "technicalDiagram" | "diagram" | "render" | "icon" | "thumbnail";
        purpose: "packaging" | "marketing" | "technical" | "catalog" | "wiring" | "dimensions";
        sortOrder: number;
        isPublished: boolean;
        mimeType?: string | undefined;
    }[];
    createdAt: string;
}, {
    productId: string;
    variantId: string;
    variantSlug: string;
    displayName: string;
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
    capabilities: string[];
    electricalSpecifications: Record<string, unknown>;
    firmwareFamily: string;
    supportedHardwareRevisions: string[];
    createdAt: string;
    assets?: {
        url: string;
        assetId: string;
        productVariantId: string;
        kind: "hero" | "front" | "rear" | "installed" | "packaging" | "technicalDiagram" | "diagram" | "render" | "icon" | "thumbnail";
        purpose: "packaging" | "marketing" | "technical" | "catalog" | "wiring" | "dimensions";
        mimeType?: string | undefined;
        sortOrder?: number | undefined;
        isPublished?: boolean | undefined;
    }[] | undefined;
}>;
export type VariantDetail = z.infer<typeof VariantDetailSchema>;
export declare const ProductDetailSchema: z.ZodObject<{
    id: z.ZodString;
    familyId: z.ZodString;
    displayName: z.ZodString;
    description: z.ZodOptional<z.ZodNullable<z.ZodString>>;
    schemaVersion: z.ZodDefault<z.ZodNumber>;
    status: z.ZodEnum<["DRAFT", "STAGED", "PUBLISHED", "DEPRECATED", "RETIRED"]>;
    variants: z.ZodArray<z.ZodObject<{
        variantId: z.ZodString;
        productId: z.ZodString;
        variantSlug: z.ZodString;
        displayName: z.ZodString;
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
        electricalSpecifications: z.ZodRecord<z.ZodString, z.ZodUnknown>;
        firmwareFamily: z.ZodString;
        supportedHardwareRevisions: z.ZodArray<z.ZodString, "many">;
        assets: z.ZodDefault<z.ZodArray<z.ZodObject<{
            assetId: z.ZodString;
            productVariantId: z.ZodString;
            kind: z.ZodEnum<["hero", "front", "rear", "installed", "packaging", "technicalDiagram", "diagram", "render", "icon", "thumbnail"]>;
            purpose: z.ZodEnum<["marketing", "technical", "packaging", "catalog", "wiring", "dimensions"]>;
            url: z.ZodString;
            mimeType: z.ZodOptional<z.ZodString>;
            sortOrder: z.ZodDefault<z.ZodNumber>;
            isPublished: z.ZodDefault<z.ZodBoolean>;
        }, "strip", z.ZodTypeAny, {
            url: string;
            assetId: string;
            productVariantId: string;
            kind: "hero" | "front" | "rear" | "installed" | "packaging" | "technicalDiagram" | "diagram" | "render" | "icon" | "thumbnail";
            purpose: "packaging" | "marketing" | "technical" | "catalog" | "wiring" | "dimensions";
            sortOrder: number;
            isPublished: boolean;
            mimeType?: string | undefined;
        }, {
            url: string;
            assetId: string;
            productVariantId: string;
            kind: "hero" | "front" | "rear" | "installed" | "packaging" | "technicalDiagram" | "diagram" | "render" | "icon" | "thumbnail";
            purpose: "packaging" | "marketing" | "technical" | "catalog" | "wiring" | "dimensions";
            mimeType?: string | undefined;
            sortOrder?: number | undefined;
            isPublished?: boolean | undefined;
        }>, "many">>;
        createdAt: z.ZodString;
    }, "strip", z.ZodTypeAny, {
        productId: string;
        variantId: string;
        variantSlug: string;
        displayName: string;
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
        capabilities: string[];
        electricalSpecifications: Record<string, unknown>;
        firmwareFamily: string;
        supportedHardwareRevisions: string[];
        assets: {
            url: string;
            assetId: string;
            productVariantId: string;
            kind: "hero" | "front" | "rear" | "installed" | "packaging" | "technicalDiagram" | "diagram" | "render" | "icon" | "thumbnail";
            purpose: "packaging" | "marketing" | "technical" | "catalog" | "wiring" | "dimensions";
            sortOrder: number;
            isPublished: boolean;
            mimeType?: string | undefined;
        }[];
        createdAt: string;
    }, {
        productId: string;
        variantId: string;
        variantSlug: string;
        displayName: string;
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
        capabilities: string[];
        electricalSpecifications: Record<string, unknown>;
        firmwareFamily: string;
        supportedHardwareRevisions: string[];
        createdAt: string;
        assets?: {
            url: string;
            assetId: string;
            productVariantId: string;
            kind: "hero" | "front" | "rear" | "installed" | "packaging" | "technicalDiagram" | "diagram" | "render" | "icon" | "thumbnail";
            purpose: "packaging" | "marketing" | "technical" | "catalog" | "wiring" | "dimensions";
            mimeType?: string | undefined;
            sortOrder?: number | undefined;
            isPublished?: boolean | undefined;
        }[] | undefined;
    }>, "many">;
    capabilities: z.ZodArray<z.ZodString, "many">;
    createdAt: z.ZodString;
    updatedAt: z.ZodString;
}, "strip", z.ZodTypeAny, {
    status: "DRAFT" | "STAGED" | "PUBLISHED" | "DEPRECATED" | "RETIRED";
    familyId: string;
    displayName: string;
    capabilities: string[];
    createdAt: string;
    id: string;
    schemaVersion: number;
    variants: {
        productId: string;
        variantId: string;
        variantSlug: string;
        displayName: string;
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
        capabilities: string[];
        electricalSpecifications: Record<string, unknown>;
        firmwareFamily: string;
        supportedHardwareRevisions: string[];
        assets: {
            url: string;
            assetId: string;
            productVariantId: string;
            kind: "hero" | "front" | "rear" | "installed" | "packaging" | "technicalDiagram" | "diagram" | "render" | "icon" | "thumbnail";
            purpose: "packaging" | "marketing" | "technical" | "catalog" | "wiring" | "dimensions";
            sortOrder: number;
            isPublished: boolean;
            mimeType?: string | undefined;
        }[];
        createdAt: string;
    }[];
    updatedAt: string;
    description?: string | null | undefined;
}, {
    status: "DRAFT" | "STAGED" | "PUBLISHED" | "DEPRECATED" | "RETIRED";
    familyId: string;
    displayName: string;
    capabilities: string[];
    createdAt: string;
    id: string;
    variants: {
        productId: string;
        variantId: string;
        variantSlug: string;
        displayName: string;
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
        capabilities: string[];
        electricalSpecifications: Record<string, unknown>;
        firmwareFamily: string;
        supportedHardwareRevisions: string[];
        createdAt: string;
        assets?: {
            url: string;
            assetId: string;
            productVariantId: string;
            kind: "hero" | "front" | "rear" | "installed" | "packaging" | "technicalDiagram" | "diagram" | "render" | "icon" | "thumbnail";
            purpose: "packaging" | "marketing" | "technical" | "catalog" | "wiring" | "dimensions";
            mimeType?: string | undefined;
            sortOrder?: number | undefined;
            isPublished?: boolean | undefined;
        }[] | undefined;
    }[];
    updatedAt: string;
    description?: string | null | undefined;
    schemaVersion?: number | undefined;
}>;
export type ProductDetail = z.infer<typeof ProductDetailSchema>;
export declare const ProductSummarySchema: z.ZodObject<{
    id: z.ZodString;
    familyId: z.ZodString;
    displayName: z.ZodString;
    description: z.ZodOptional<z.ZodNullable<z.ZodString>>;
    status: z.ZodEnum<["DRAFT", "STAGED", "PUBLISHED", "DEPRECATED", "RETIRED"]>;
    variantCount: z.ZodNumber;
    variantIds: z.ZodArray<z.ZodString, "many">;
    capabilities: z.ZodArray<z.ZodString, "many">;
    thumbnailUrl: z.ZodOptional<z.ZodNullable<z.ZodString>>;
    createdAt: z.ZodString;
    updatedAt: z.ZodString;
}, "strip", z.ZodTypeAny, {
    status: "DRAFT" | "STAGED" | "PUBLISHED" | "DEPRECATED" | "RETIRED";
    familyId: string;
    displayName: string;
    capabilities: string[];
    createdAt: string;
    id: string;
    updatedAt: string;
    variantCount: number;
    variantIds: string[];
    description?: string | null | undefined;
    thumbnailUrl?: string | null | undefined;
}, {
    status: "DRAFT" | "STAGED" | "PUBLISHED" | "DEPRECATED" | "RETIRED";
    familyId: string;
    displayName: string;
    capabilities: string[];
    createdAt: string;
    id: string;
    updatedAt: string;
    variantCount: number;
    variantIds: string[];
    description?: string | null | undefined;
    thumbnailUrl?: string | null | undefined;
}>;
export type ProductSummary = z.infer<typeof ProductSummarySchema>;
export declare const ImportDefinitionOptionsSchema: z.ZodObject<{
    dryRun: z.ZodDefault<z.ZodBoolean>;
    overwriteExisting: z.ZodDefault<z.ZodBoolean>;
}, "strip", z.ZodTypeAny, {
    dryRun: boolean;
    overwriteExisting: boolean;
}, {
    dryRun?: boolean | undefined;
    overwriteExisting?: boolean | undefined;
}>;
export type ImportDefinitionOptions = z.infer<typeof ImportDefinitionOptionsSchema>;
export declare const CreateProductBodySchema: z.ZodObject<{
    id: z.ZodString;
    familyId: z.ZodString;
    displayName: z.ZodString;
    description: z.ZodOptional<z.ZodString>;
    status: z.ZodDefault<z.ZodEnum<["DRAFT", "STAGED", "PUBLISHED", "DEPRECATED", "RETIRED"]>>;
}, "strip", z.ZodTypeAny, {
    status: "DRAFT" | "STAGED" | "PUBLISHED" | "DEPRECATED" | "RETIRED";
    familyId: string;
    displayName: string;
    id: string;
    description?: string | undefined;
}, {
    familyId: string;
    displayName: string;
    id: string;
    status?: "DRAFT" | "STAGED" | "PUBLISHED" | "DEPRECATED" | "RETIRED" | undefined;
    description?: string | undefined;
}>;
export type CreateProductBody = z.infer<typeof CreateProductBodySchema>;
export declare const UpdateProductBodySchema: z.ZodObject<{
    displayName: z.ZodOptional<z.ZodString>;
    description: z.ZodOptional<z.ZodString>;
    status: z.ZodOptional<z.ZodEnum<["DRAFT", "STAGED", "PUBLISHED", "DEPRECATED", "RETIRED"]>>;
}, "strip", z.ZodTypeAny, {
    status?: "DRAFT" | "STAGED" | "PUBLISHED" | "DEPRECATED" | "RETIRED" | undefined;
    displayName?: string | undefined;
    description?: string | undefined;
}, {
    status?: "DRAFT" | "STAGED" | "PUBLISHED" | "DEPRECATED" | "RETIRED" | undefined;
    displayName?: string | undefined;
    description?: string | undefined;
}>;
export type UpdateProductBody = z.infer<typeof UpdateProductBodySchema>;
export declare const CreateVariantBodySchema: z.ZodObject<{
    id: z.ZodString;
    productId: z.ZodString;
    variantSlug: z.ZodString;
    displayName: z.ZodString;
    channelCount: z.ZodDefault<z.ZodNumber>;
    channels: z.ZodDefault<z.ZodArray<z.ZodAny, "many">>;
    hardwareProfile: z.ZodDefault<z.ZodAny>;
    connectivityProfile: z.ZodDefault<z.ZodAny>;
    capabilities: z.ZodDefault<z.ZodArray<z.ZodString, "many">>;
    electricalSpecifications: z.ZodDefault<z.ZodRecord<z.ZodString, z.ZodUnknown>>;
    firmwareFamily: z.ZodString;
    supportedHardwareRevisions: z.ZodDefault<z.ZodArray<z.ZodString, "many">>;
}, "strip", z.ZodTypeAny, {
    productId: string;
    variantSlug: string;
    displayName: string;
    channelCount: number;
    channels: any[];
    capabilities: string[];
    electricalSpecifications: Record<string, unknown>;
    firmwareFamily: string;
    supportedHardwareRevisions: string[];
    id: string;
    hardwareProfile?: any;
    connectivityProfile?: any;
}, {
    productId: string;
    variantSlug: string;
    displayName: string;
    firmwareFamily: string;
    id: string;
    channelCount?: number | undefined;
    channels?: any[] | undefined;
    hardwareProfile?: any;
    connectivityProfile?: any;
    capabilities?: string[] | undefined;
    electricalSpecifications?: Record<string, unknown> | undefined;
    supportedHardwareRevisions?: string[] | undefined;
}>;
export type CreateVariantBody = z.infer<typeof CreateVariantBodySchema>;
export declare const UpdateVariantBodySchema: z.ZodObject<{
    displayName: z.ZodOptional<z.ZodString>;
    channelCount: z.ZodOptional<z.ZodNumber>;
    channels: z.ZodOptional<z.ZodArray<z.ZodAny, "many">>;
    hardwareProfile: z.ZodOptional<z.ZodAny>;
    connectivityProfile: z.ZodOptional<z.ZodAny>;
    capabilities: z.ZodOptional<z.ZodArray<z.ZodString, "many">>;
    electricalSpecifications: z.ZodOptional<z.ZodRecord<z.ZodString, z.ZodUnknown>>;
    firmwareFamily: z.ZodOptional<z.ZodString>;
    supportedHardwareRevisions: z.ZodOptional<z.ZodArray<z.ZodString, "many">>;
}, "strip", z.ZodTypeAny, {
    displayName?: string | undefined;
    channelCount?: number | undefined;
    channels?: any[] | undefined;
    hardwareProfile?: any;
    connectivityProfile?: any;
    capabilities?: string[] | undefined;
    electricalSpecifications?: Record<string, unknown> | undefined;
    firmwareFamily?: string | undefined;
    supportedHardwareRevisions?: string[] | undefined;
}, {
    displayName?: string | undefined;
    channelCount?: number | undefined;
    channels?: any[] | undefined;
    hardwareProfile?: any;
    connectivityProfile?: any;
    capabilities?: string[] | undefined;
    electricalSpecifications?: Record<string, unknown> | undefined;
    firmwareFamily?: string | undefined;
    supportedHardwareRevisions?: string[] | undefined;
}>;
export type UpdateVariantBody = z.infer<typeof UpdateVariantBodySchema>;
//# sourceMappingURL=product.schema.d.ts.map