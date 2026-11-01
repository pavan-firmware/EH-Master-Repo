import { z } from 'zod';
export declare const BOMItemSchema: z.ZodObject<{
    itemIndex: z.ZodNumber;
    referenceDesignator: z.ZodString;
    mpn: z.ZodString;
    manufacturer: z.ZodOptional<z.ZodString>;
    description: z.ZodString;
    footprint: z.ZodString;
    quantity: z.ZodDefault<z.ZodNumber>;
    isDnf: z.ZodDefault<z.ZodBoolean>;
    vendorPartNumber: z.ZodOptional<z.ZodString>;
    unitCostInr: z.ZodOptional<z.ZodNumber>;
}, "strip", z.ZodTypeAny, {
    description: string;
    itemIndex: number;
    referenceDesignator: string;
    mpn: string;
    footprint: string;
    quantity: number;
    isDnf: boolean;
    manufacturer?: string | undefined;
    vendorPartNumber?: string | undefined;
    unitCostInr?: number | undefined;
}, {
    description: string;
    itemIndex: number;
    referenceDesignator: string;
    mpn: string;
    footprint: string;
    manufacturer?: string | undefined;
    quantity?: number | undefined;
    isDnf?: boolean | undefined;
    vendorPartNumber?: string | undefined;
    unitCostInr?: number | undefined;
}>;
export type BOMItem = z.infer<typeof BOMItemSchema>;
export declare const BOMSpecificationStatusSchema: z.ZodEnum<["DRAFT", "ACTIVE", "DEPRECATED", "SUPERSEDED"]>;
export type BOMSpecificationStatus = z.infer<typeof BOMSpecificationStatusSchema>;
export declare const BOMSpecificationSchema: z.ZodObject<{
    schemaVersion: z.ZodDefault<z.ZodNumber>;
    bomId: z.ZodString;
    hardwareRevisionCode: z.ZodString;
    version: z.ZodString;
    lifecycleStatus: z.ZodDefault<z.ZodEnum<["DRAFT", "ACTIVE", "DEPRECATED", "SUPERSEDED"]>>;
    items: z.ZodArray<z.ZodObject<{
        itemIndex: z.ZodNumber;
        referenceDesignator: z.ZodString;
        mpn: z.ZodString;
        manufacturer: z.ZodOptional<z.ZodString>;
        description: z.ZodString;
        footprint: z.ZodString;
        quantity: z.ZodDefault<z.ZodNumber>;
        isDnf: z.ZodDefault<z.ZodBoolean>;
        vendorPartNumber: z.ZodOptional<z.ZodString>;
        unitCostInr: z.ZodOptional<z.ZodNumber>;
    }, "strip", z.ZodTypeAny, {
        description: string;
        itemIndex: number;
        referenceDesignator: string;
        mpn: string;
        footprint: string;
        quantity: number;
        isDnf: boolean;
        manufacturer?: string | undefined;
        vendorPartNumber?: string | undefined;
        unitCostInr?: number | undefined;
    }, {
        description: string;
        itemIndex: number;
        referenceDesignator: string;
        mpn: string;
        footprint: string;
        manufacturer?: string | undefined;
        quantity?: number | undefined;
        isDnf?: boolean | undefined;
        vendorPartNumber?: string | undefined;
        unitCostInr?: number | undefined;
    }>, "many">;
    totalUniqueComponents: z.ZodOptional<z.ZodNumber>;
    notes: z.ZodOptional<z.ZodString>;
    effectiveDate: z.ZodOptional<z.ZodString>;
    createdAt: z.ZodString;
}, "strip", z.ZodTypeAny, {
    schemaVersion: number;
    bomId: string;
    hardwareRevisionCode: string;
    version: string;
    lifecycleStatus: "DRAFT" | "DEPRECATED" | "ACTIVE" | "SUPERSEDED";
    items: {
        description: string;
        itemIndex: number;
        referenceDesignator: string;
        mpn: string;
        footprint: string;
        quantity: number;
        isDnf: boolean;
        manufacturer?: string | undefined;
        vendorPartNumber?: string | undefined;
        unitCostInr?: number | undefined;
    }[];
    createdAt: string;
    totalUniqueComponents?: number | undefined;
    notes?: string | undefined;
    effectiveDate?: string | undefined;
}, {
    bomId: string;
    hardwareRevisionCode: string;
    version: string;
    items: {
        description: string;
        itemIndex: number;
        referenceDesignator: string;
        mpn: string;
        footprint: string;
        manufacturer?: string | undefined;
        quantity?: number | undefined;
        isDnf?: boolean | undefined;
        vendorPartNumber?: string | undefined;
        unitCostInr?: number | undefined;
    }[];
    createdAt: string;
    schemaVersion?: number | undefined;
    lifecycleStatus?: "DRAFT" | "DEPRECATED" | "ACTIVE" | "SUPERSEDED" | undefined;
    totalUniqueComponents?: number | undefined;
    notes?: string | undefined;
    effectiveDate?: string | undefined;
}>;
export type BOMSpecification = z.infer<typeof BOMSpecificationSchema>;
export declare const HardwareRevisionStatusSchema: z.ZodEnum<["DRAFT", "VALIDATION", "APPROVED", "ACTIVE", "DEPRECATED", "RETIRED", "PROTOTYPE", "OBSOLETE"]>;
export type HardwareRevisionStatus = z.infer<typeof HardwareRevisionStatusSchema>;
export declare const HardwareRevisionSchema: z.ZodObject<{
    schemaVersion: z.ZodDefault<z.ZodNumber>;
    revisionCode: z.ZodString;
    productVariantId: z.ZodString;
    pcbName: z.ZodString;
    layerCount: z.ZodDefault<z.ZodNumber>;
    dimensionsMm: z.ZodOptional<z.ZodObject<{
        width: z.ZodNumber;
        height: z.ZodNumber;
        thickness: z.ZodDefault<z.ZodNumber>;
    }, "strip", z.ZodTypeAny, {
        width: number;
        height: number;
        thickness: number;
    }, {
        width: number;
        height: number;
        thickness?: number | undefined;
    }>>;
    pinMap: z.ZodRecord<z.ZodString, z.ZodNumber>;
    schematicAssetUrl: z.ZodOptional<z.ZodString>;
    gerberAssetUrl: z.ZodOptional<z.ZodString>;
    renderAssetUrl: z.ZodOptional<z.ZodString>;
    status: z.ZodDefault<z.ZodEnum<["DRAFT", "VALIDATION", "APPROVED", "ACTIVE", "DEPRECATED", "RETIRED", "PROTOTYPE", "OBSOLETE"]>>;
    createdAt: z.ZodString;
}, "strip", z.ZodTypeAny, {
    status: "DRAFT" | "DEPRECATED" | "RETIRED" | "ACTIVE" | "VALIDATION" | "APPROVED" | "PROTOTYPE" | "OBSOLETE";
    schemaVersion: number;
    createdAt: string;
    revisionCode: string;
    productVariantId: string;
    pcbName: string;
    layerCount: number;
    pinMap: Record<string, number>;
    dimensionsMm?: {
        width: number;
        height: number;
        thickness: number;
    } | undefined;
    schematicAssetUrl?: string | undefined;
    gerberAssetUrl?: string | undefined;
    renderAssetUrl?: string | undefined;
}, {
    createdAt: string;
    revisionCode: string;
    productVariantId: string;
    pcbName: string;
    pinMap: Record<string, number>;
    status?: "DRAFT" | "DEPRECATED" | "RETIRED" | "ACTIVE" | "VALIDATION" | "APPROVED" | "PROTOTYPE" | "OBSOLETE" | undefined;
    schemaVersion?: number | undefined;
    layerCount?: number | undefined;
    dimensionsMm?: {
        width: number;
        height: number;
        thickness?: number | undefined;
    } | undefined;
    schematicAssetUrl?: string | undefined;
    gerberAssetUrl?: string | undefined;
    renderAssetUrl?: string | undefined;
}>;
export type HardwareRevision = z.infer<typeof HardwareRevisionSchema>;
export declare const HardwareCompatibilitySchema: z.ZodObject<{
    hardwareRevisionCode: z.ZodString;
    firmwareFamily: z.ZodString;
    minFirmwareVersion: z.ZodString;
    maxFirmwareVersion: z.ZodOptional<z.ZodString>;
    incompatibleFirmwareVersions: z.ZodDefault<z.ZodArray<z.ZodString, "many">>;
    verifiedAt: z.ZodString;
}, "strip", z.ZodTypeAny, {
    firmwareFamily: string;
    hardwareRevisionCode: string;
    minFirmwareVersion: string;
    incompatibleFirmwareVersions: string[];
    verifiedAt: string;
    maxFirmwareVersion?: string | undefined;
}, {
    firmwareFamily: string;
    hardwareRevisionCode: string;
    minFirmwareVersion: string;
    verifiedAt: string;
    maxFirmwareVersion?: string | undefined;
    incompatibleFirmwareVersions?: string[] | undefined;
}>;
export type HardwareCompatibility = z.infer<typeof HardwareCompatibilitySchema>;
//# sourceMappingURL=index.d.ts.map