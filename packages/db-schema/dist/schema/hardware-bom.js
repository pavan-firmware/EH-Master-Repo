"use strict";
/**
 * EH Home Schema — hardware-bom
 * Source: PostgreSQL Migration 030 (030_hardware_bom_management.sql)
 * Domain: Hardware & BOM Management (Part 06)
 */
Object.defineProperty(exports, "__esModule", { value: true });
exports.productVariantHardwareCompatibility = exports.componentSubstitutions = exports.bomItems = exports.bomSpecifications = exports.hardwareRevisions = void 0;
const pg_core_1 = require("drizzle-orm/pg-core");
const product_catalog_1 = require("./product-catalog");
// --- hardware_revisions (030_hardware_bom_management.sql) ---
exports.hardwareRevisions = (0, pg_core_1.pgTable)('hardware_revisions', {
    id: (0, pg_core_1.varchar)('id', { length: 64 }).primaryKey(),
    revisionCode: (0, pg_core_1.varchar)('revision_code', { length: 32 }).notNull(),
    productVariantId: (0, pg_core_1.varchar)('product_variant_id', { length: 128 })
        .notNull()
        .references(() => product_catalog_1.productVariants.id),
    pcbName: (0, pg_core_1.varchar)('pcb_name', { length: 128 }).notNull(),
    pcbRevision: (0, pg_core_1.varchar)('pcb_revision', { length: 32 }).notNull().default('v1.0'),
    displayName: (0, pg_core_1.varchar)('display_name', { length: 128 }).notNull(),
    lifecycleStatus: (0, pg_core_1.varchar)('lifecycle_status', { length: 32 }).notNull().default('DRAFT'),
    layerCount: (0, pg_core_1.integer)('layer_count').notNull().default(2),
    mcuFamily: (0, pg_core_1.varchar)('mcu_family', { length: 32 }).notNull().default('esp32-c6'),
    dimensionsMm: (0, pg_core_1.jsonb)('dimensions_mm'),
    pinMap: (0, pg_core_1.jsonb)('pin_map').notNull().default({}),
    schematicAssetUrl: (0, pg_core_1.text)('schematic_asset_url'),
    gerberAssetUrl: (0, pg_core_1.text)('gerber_asset_url'),
    renderAssetUrl: (0, pg_core_1.text)('render_asset_url'),
    designMetadata: (0, pg_core_1.jsonb)('design_metadata').notNull().default({}),
    effectiveAt: (0, pg_core_1.timestamp)('effective_at', { withTimezone: true }),
    deprecatedAt: (0, pg_core_1.timestamp)('deprecated_at', { withTimezone: true }),
    createdAt: (0, pg_core_1.timestamp)('created_at', { withTimezone: true }).notNull().defaultNow(),
    updatedAt: (0, pg_core_1.timestamp)('updated_at', { withTimezone: true }).notNull().defaultNow(),
});
// --- bom_specifications (030_hardware_bom_management.sql) ---
exports.bomSpecifications = (0, pg_core_1.pgTable)('bom_specifications', {
    id: (0, pg_core_1.varchar)('id', { length: 64 }).primaryKey(),
    hardwareRevisionId: (0, pg_core_1.varchar)('hardware_revision_id', { length: 64 })
        .notNull()
        .references(() => exports.hardwareRevisions.id),
    version: (0, pg_core_1.varchar)('version', { length: 32 }).notNull().default('1.0.0'),
    lifecycleStatus: (0, pg_core_1.varchar)('lifecycle_status', { length: 32 }).notNull().default('DRAFT'),
    totalUniqueComponents: (0, pg_core_1.integer)('total_unique_components').notNull().default(0),
    notes: (0, pg_core_1.text)('notes'),
    effectiveDate: (0, pg_core_1.timestamp)('effective_date', { withTimezone: true }),
    createdAt: (0, pg_core_1.timestamp)('created_at', { withTimezone: true }).notNull().defaultNow(),
    updatedAt: (0, pg_core_1.timestamp)('updated_at', { withTimezone: true }).notNull().defaultNow(),
});
// --- bom_items (030_hardware_bom_management.sql) ---
exports.bomItems = (0, pg_core_1.pgTable)('bom_items', {
    id: (0, pg_core_1.varchar)('id', { length: 64 }).primaryKey(),
    bomId: (0, pg_core_1.varchar)('bom_id', { length: 64 })
        .notNull()
        .references(() => exports.bomSpecifications.id, { onDelete: 'cascade' }),
    itemIndex: (0, pg_core_1.integer)('item_index').notNull(),
    referenceDesignator: (0, pg_core_1.varchar)('reference_designator', { length: 64 }).notNull(),
    mpn: (0, pg_core_1.varchar)('mpn', { length: 128 }).notNull(),
    internalPartNumber: (0, pg_core_1.varchar)('internal_part_number', { length: 64 }),
    manufacturer: (0, pg_core_1.varchar)('manufacturer', { length: 128 }),
    description: (0, pg_core_1.text)('description').notNull(),
    componentCategory: (0, pg_core_1.varchar)('component_category', { length: 64 }).notNull().default('OTHER'),
    footprint: (0, pg_core_1.varchar)('footprint', { length: 128 }).notNull(),
    quantity: (0, pg_core_1.integer)('quantity').notNull(),
    unit: (0, pg_core_1.varchar)('unit', { length: 16 }).notNull().default('pcs'),
    isDnf: (0, pg_core_1.boolean)('is_dnf').notNull().default(false),
    vendorPartNumber: (0, pg_core_1.varchar)('vendor_part_number', { length: 128 }),
    unitCostInr: (0, pg_core_1.numeric)('unit_cost_inr', { precision: 10, scale: 4 }),
    createdAt: (0, pg_core_1.timestamp)('created_at', { withTimezone: true }).notNull().defaultNow(),
});
// --- component_substitutions (030_hardware_bom_management.sql) ---
exports.componentSubstitutions = (0, pg_core_1.pgTable)('component_substitutions', {
    id: (0, pg_core_1.varchar)('id', { length: 64 }).primaryKey(),
    bomItemId: (0, pg_core_1.varchar)('bom_item_id', { length: 64 })
        .notNull()
        .references(() => exports.bomItems.id, { onDelete: 'cascade' }),
    substituteMpn: (0, pg_core_1.varchar)('substitute_mpn', { length: 128 }).notNull(),
    substituteManufacturer: (0, pg_core_1.varchar)('substitute_manufacturer', { length: 128 }),
    approvalStatus: (0, pg_core_1.varchar)('approval_status', { length: 32 }).notNull().default('APPROVED'),
    qualificationNotes: (0, pg_core_1.text)('qualification_notes'),
    createdAt: (0, pg_core_1.timestamp)('created_at', { withTimezone: true }).notNull().defaultNow(),
});
// --- product_variant_hardware_compatibility (030_hardware_bom_management.sql) ---
exports.productVariantHardwareCompatibility = (0, pg_core_1.pgTable)('product_variant_hardware_compatibility', {
    id: (0, pg_core_1.varchar)('id', { length: 64 }).primaryKey(),
    productVariantId: (0, pg_core_1.varchar)('product_variant_id', { length: 128 })
        .notNull()
        .references(() => product_catalog_1.productVariants.id, { onDelete: 'cascade' }),
    hardwareRevisionId: (0, pg_core_1.varchar)('hardware_revision_id', { length: 64 })
        .notNull()
        .references(() => exports.hardwareRevisions.id, { onDelete: 'cascade' }),
    isPrimary: (0, pg_core_1.boolean)('is_primary').notNull().default(false),
    compatibilityNotes: (0, pg_core_1.text)('compatibility_notes'),
    verifiedAt: (0, pg_core_1.timestamp)('verified_at', { withTimezone: true }).defaultNow(),
    createdAt: (0, pg_core_1.timestamp)('created_at', { withTimezone: true }).notNull().defaultNow(),
});
//# sourceMappingURL=hardware-bom.js.map