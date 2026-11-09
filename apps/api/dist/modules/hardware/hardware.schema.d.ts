/**
 * EH Home Hardware & BOM Domain Schemas
 *
 * Request validation contracts and response schemas for Hardware & BOM Management.
 * Reuses canonical contracts from @eh-home/contracts.
 */
import { z } from 'zod';
export declare const ListHardwareRevisionsQuerySchema: z.ZodObject<{
    productVariantId: z.ZodOptional<z.ZodString>;
    status: z.ZodOptional<z.ZodEnum<["DRAFT", "VALIDATION", "APPROVED", "ACTIVE", "DEPRECATED", "RETIRED", "PROTOTYPE", "OBSOLETE"]>>;
    revisionCode: z.ZodOptional<z.ZodString>;
    mcuFamily: z.ZodOptional<z.ZodString>;
    limit: z.ZodDefault<z.ZodNumber>;
    offset: z.ZodDefault<z.ZodNumber>;
}, "strip", z.ZodTypeAny, {
    limit: number;
    offset: number;
    status?: "DRAFT" | "DEPRECATED" | "RETIRED" | "ACTIVE" | "VALIDATION" | "APPROVED" | "PROTOTYPE" | "OBSOLETE" | undefined;
    productVariantId?: string | undefined;
    revisionCode?: string | undefined;
    mcuFamily?: string | undefined;
}, {
    status?: "DRAFT" | "DEPRECATED" | "RETIRED" | "ACTIVE" | "VALIDATION" | "APPROVED" | "PROTOTYPE" | "OBSOLETE" | undefined;
    limit?: number | undefined;
    offset?: number | undefined;
    productVariantId?: string | undefined;
    revisionCode?: string | undefined;
    mcuFamily?: string | undefined;
}>;
export type ListHardwareRevisionsQuery = z.infer<typeof ListHardwareRevisionsQuerySchema>;
export declare const GetHardwareRevisionParamsSchema: z.ZodObject<{
    hardwareRevisionId: z.ZodString;
}, "strip", z.ZodTypeAny, {
    hardwareRevisionId: string;
}, {
    hardwareRevisionId: string;
}>;
export type GetHardwareRevisionParams = z.infer<typeof GetHardwareRevisionParamsSchema>;
export declare const CreateHardwareRevisionBodySchema: z.ZodObject<{
    id: z.ZodOptional<z.ZodString>;
    revisionCode: z.ZodString;
    productVariantId: z.ZodString;
    pcbName: z.ZodString;
    pcbRevision: z.ZodDefault<z.ZodString>;
    displayName: z.ZodString;
    lifecycleStatus: z.ZodDefault<z.ZodEnum<["DRAFT", "VALIDATION", "APPROVED", "ACTIVE", "DEPRECATED", "RETIRED", "PROTOTYPE", "OBSOLETE"]>>;
    layerCount: z.ZodDefault<z.ZodNumber>;
    mcuFamily: z.ZodDefault<z.ZodString>;
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
    pinMap: z.ZodDefault<z.ZodRecord<z.ZodString, z.ZodNumber>>;
    schematicAssetUrl: z.ZodOptional<z.ZodString>;
    gerberAssetUrl: z.ZodOptional<z.ZodString>;
    renderAssetUrl: z.ZodOptional<z.ZodString>;
    designMetadata: z.ZodDefault<z.ZodRecord<z.ZodString, z.ZodUnknown>>;
}, "strip", z.ZodTypeAny, {
    productVariantId: string;
    displayName: string;
    revisionCode: string;
    mcuFamily: string;
    pcbName: string;
    pcbRevision: string;
    lifecycleStatus: "DRAFT" | "DEPRECATED" | "RETIRED" | "ACTIVE" | "VALIDATION" | "APPROVED" | "PROTOTYPE" | "OBSOLETE";
    layerCount: number;
    pinMap: Record<string, number>;
    designMetadata: Record<string, unknown>;
    id?: string | undefined;
    dimensionsMm?: {
        width: number;
        height: number;
        thickness: number;
    } | undefined;
    schematicAssetUrl?: string | undefined;
    gerberAssetUrl?: string | undefined;
    renderAssetUrl?: string | undefined;
}, {
    productVariantId: string;
    displayName: string;
    revisionCode: string;
    pcbName: string;
    id?: string | undefined;
    mcuFamily?: string | undefined;
    pcbRevision?: string | undefined;
    lifecycleStatus?: "DRAFT" | "DEPRECATED" | "RETIRED" | "ACTIVE" | "VALIDATION" | "APPROVED" | "PROTOTYPE" | "OBSOLETE" | undefined;
    layerCount?: number | undefined;
    dimensionsMm?: {
        width: number;
        height: number;
        thickness?: number | undefined;
    } | undefined;
    pinMap?: Record<string, number> | undefined;
    schematicAssetUrl?: string | undefined;
    gerberAssetUrl?: string | undefined;
    renderAssetUrl?: string | undefined;
    designMetadata?: Record<string, unknown> | undefined;
}>;
export type CreateHardwareRevisionBody = z.infer<typeof CreateHardwareRevisionBodySchema>;
export declare const UpdateHardwareRevisionStatusBodySchema: z.ZodObject<{
    status: z.ZodEnum<["DRAFT", "VALIDATION", "APPROVED", "ACTIVE", "DEPRECATED", "RETIRED", "PROTOTYPE", "OBSOLETE"]>;
    reason: z.ZodOptional<z.ZodString>;
}, "strip", z.ZodTypeAny, {
    status: "DRAFT" | "DEPRECATED" | "RETIRED" | "ACTIVE" | "VALIDATION" | "APPROVED" | "PROTOTYPE" | "OBSOLETE";
    reason?: string | undefined;
}, {
    status: "DRAFT" | "DEPRECATED" | "RETIRED" | "ACTIVE" | "VALIDATION" | "APPROVED" | "PROTOTYPE" | "OBSOLETE";
    reason?: string | undefined;
}>;
export type UpdateHardwareRevisionStatusBody = z.infer<typeof UpdateHardwareRevisionStatusBodySchema>;
export declare const ComponentSubstitutionSchema: z.ZodObject<{
    id: z.ZodString;
    bomItemId: z.ZodString;
    substituteMpn: z.ZodString;
    substituteManufacturer: z.ZodOptional<z.ZodString>;
    approvalStatus: z.ZodDefault<z.ZodEnum<["PENDING", "APPROVED", "REJECTED"]>>;
    qualificationNotes: z.ZodOptional<z.ZodString>;
    createdAt: z.ZodString;
}, "strip", z.ZodTypeAny, {
    createdAt: string;
    id: string;
    bomItemId: string;
    substituteMpn: string;
    approvalStatus: "APPROVED" | "PENDING" | "REJECTED";
    substituteManufacturer?: string | undefined;
    qualificationNotes?: string | undefined;
}, {
    createdAt: string;
    id: string;
    bomItemId: string;
    substituteMpn: string;
    substituteManufacturer?: string | undefined;
    approvalStatus?: "APPROVED" | "PENDING" | "REJECTED" | undefined;
    qualificationNotes?: string | undefined;
}>;
export type ComponentSubstitution = z.infer<typeof ComponentSubstitutionSchema>;
export declare const CreateBOMSpecificationBodySchema: z.ZodObject<{
    id: z.ZodOptional<z.ZodString>;
    hardwareRevisionId: z.ZodString;
    version: z.ZodDefault<z.ZodString>;
    lifecycleStatus: z.ZodDefault<z.ZodEnum<["DRAFT", "ACTIVE", "DEPRECATED", "SUPERSEDED"]>>;
    notes: z.ZodOptional<z.ZodString>;
    effectiveDate: z.ZodOptional<z.ZodString>;
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
}, "strip", z.ZodTypeAny, {
    version: string;
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
    hardwareRevisionId: string;
    lifecycleStatus: "DRAFT" | "DEPRECATED" | "ACTIVE" | "SUPERSEDED";
    id?: string | undefined;
    notes?: string | undefined;
    effectiveDate?: string | undefined;
}, {
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
    hardwareRevisionId: string;
    version?: string | undefined;
    id?: string | undefined;
    lifecycleStatus?: "DRAFT" | "DEPRECATED" | "ACTIVE" | "SUPERSEDED" | undefined;
    notes?: string | undefined;
    effectiveDate?: string | undefined;
}>;
export type CreateBOMSpecificationBody = z.infer<typeof CreateBOMSpecificationBodySchema>;
export declare const HardwareRevisionDetailSchema: z.ZodObject<{
    id: z.ZodString;
    revisionCode: z.ZodString;
    productVariantId: z.ZodString;
    pcbName: z.ZodString;
    pcbRevision: z.ZodString;
    displayName: z.ZodString;
    lifecycleStatus: z.ZodEnum<["DRAFT", "VALIDATION", "APPROVED", "ACTIVE", "DEPRECATED", "RETIRED", "PROTOTYPE", "OBSOLETE"]>;
    layerCount: z.ZodNumber;
    mcuFamily: z.ZodString;
    dimensionsMm: z.ZodOptional<z.ZodNullable<z.ZodRecord<z.ZodString, z.ZodUnknown>>>;
    pinMap: z.ZodRecord<z.ZodString, z.ZodNumber>;
    schematicAssetUrl: z.ZodOptional<z.ZodNullable<z.ZodString>>;
    gerberAssetUrl: z.ZodOptional<z.ZodNullable<z.ZodString>>;
    renderAssetUrl: z.ZodOptional<z.ZodNullable<z.ZodString>>;
    designMetadata: z.ZodRecord<z.ZodString, z.ZodUnknown>;
    effectiveAt: z.ZodOptional<z.ZodNullable<z.ZodString>>;
    deprecatedAt: z.ZodOptional<z.ZodNullable<z.ZodString>>;
    createdAt: z.ZodString;
    updatedAt: z.ZodString;
}, "strip", z.ZodTypeAny, {
    productVariantId: string;
    displayName: string;
    createdAt: string;
    id: string;
    updatedAt: string;
    revisionCode: string;
    mcuFamily: string;
    pcbName: string;
    pcbRevision: string;
    lifecycleStatus: "DRAFT" | "DEPRECATED" | "RETIRED" | "ACTIVE" | "VALIDATION" | "APPROVED" | "PROTOTYPE" | "OBSOLETE";
    layerCount: number;
    pinMap: Record<string, number>;
    designMetadata: Record<string, unknown>;
    dimensionsMm?: Record<string, unknown> | null | undefined;
    schematicAssetUrl?: string | null | undefined;
    gerberAssetUrl?: string | null | undefined;
    renderAssetUrl?: string | null | undefined;
    effectiveAt?: string | null | undefined;
    deprecatedAt?: string | null | undefined;
}, {
    productVariantId: string;
    displayName: string;
    createdAt: string;
    id: string;
    updatedAt: string;
    revisionCode: string;
    mcuFamily: string;
    pcbName: string;
    pcbRevision: string;
    lifecycleStatus: "DRAFT" | "DEPRECATED" | "RETIRED" | "ACTIVE" | "VALIDATION" | "APPROVED" | "PROTOTYPE" | "OBSOLETE";
    layerCount: number;
    pinMap: Record<string, number>;
    designMetadata: Record<string, unknown>;
    dimensionsMm?: Record<string, unknown> | null | undefined;
    schematicAssetUrl?: string | null | undefined;
    gerberAssetUrl?: string | null | undefined;
    renderAssetUrl?: string | null | undefined;
    effectiveAt?: string | null | undefined;
    deprecatedAt?: string | null | undefined;
}>;
export type HardwareRevisionDetail = z.infer<typeof HardwareRevisionDetailSchema>;
export declare const BOMDetailSchema: z.ZodObject<{
    id: z.ZodString;
    hardwareRevisionId: z.ZodString;
    version: z.ZodString;
    lifecycleStatus: z.ZodEnum<["DRAFT", "ACTIVE", "DEPRECATED", "SUPERSEDED"]>;
    totalUniqueComponents: z.ZodNumber;
    notes: z.ZodOptional<z.ZodNullable<z.ZodString>>;
    effectiveDate: z.ZodOptional<z.ZodNullable<z.ZodString>>;
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
    createdAt: z.ZodString;
    updatedAt: z.ZodString;
}, "strip", z.ZodTypeAny, {
    version: string;
    createdAt: string;
    id: string;
    updatedAt: string;
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
    hardwareRevisionId: string;
    lifecycleStatus: "DRAFT" | "DEPRECATED" | "ACTIVE" | "SUPERSEDED";
    totalUniqueComponents: number;
    notes?: string | null | undefined;
    effectiveDate?: string | null | undefined;
}, {
    version: string;
    createdAt: string;
    id: string;
    updatedAt: string;
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
    hardwareRevisionId: string;
    lifecycleStatus: "DRAFT" | "DEPRECATED" | "ACTIVE" | "SUPERSEDED";
    totalUniqueComponents: number;
    notes?: string | null | undefined;
    effectiveDate?: string | null | undefined;
}>;
export type BOMDetail = z.infer<typeof BOMDetailSchema>;
//# sourceMappingURL=hardware.schema.d.ts.map