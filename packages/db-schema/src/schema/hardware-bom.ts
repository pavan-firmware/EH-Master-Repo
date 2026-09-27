/**
 * EH Home Schema — hardware-bom
 * Source: PostgreSQL Migration 030 (030_hardware_bom_management.sql)
 * Domain: Hardware & BOM Management (Part 06)
 */

import { boolean, integer, jsonb, numeric, pgTable, text, timestamp, varchar } from 'drizzle-orm/pg-core';
import { productVariants } from './product-catalog';

// --- hardware_revisions (030_hardware_bom_management.sql) ---
export const hardwareRevisions = pgTable('hardware_revisions', {
  id: varchar('id', { length: 64 }).primaryKey(),
  revisionCode: varchar('revision_code', { length: 32 }).notNull(),
  productVariantId: varchar('product_variant_id', { length: 128 })
    .notNull()
    .references(() => productVariants.id),
  pcbName: varchar('pcb_name', { length: 128 }).notNull(),
  pcbRevision: varchar('pcb_revision', { length: 32 }).notNull().default('v1.0'),
  displayName: varchar('display_name', { length: 128 }).notNull(),
  lifecycleStatus: varchar('lifecycle_status', { length: 32 }).notNull().default('DRAFT'),
  layerCount: integer('layer_count').notNull().default(2),
  mcuFamily: varchar('mcu_family', { length: 32 }).notNull().default('esp32-c6'),
  dimensionsMm: jsonb('dimensions_mm'),
  pinMap: jsonb('pin_map').notNull().default({}),
  schematicAssetUrl: text('schematic_asset_url'),
  gerberAssetUrl: text('gerber_asset_url'),
  renderAssetUrl: text('render_asset_url'),
  designMetadata: jsonb('design_metadata').notNull().default({}),
  effectiveAt: timestamp('effective_at', { withTimezone: true }),
  deprecatedAt: timestamp('deprecated_at', { withTimezone: true }),
  createdAt: timestamp('created_at', { withTimezone: true }).notNull().defaultNow(),
  updatedAt: timestamp('updated_at', { withTimezone: true }).notNull().defaultNow(),
});

export type HardwareRevisions = typeof hardwareRevisions.$inferSelect;
export type NewHardwareRevisions = typeof hardwareRevisions.$inferInsert;

// --- bom_specifications (030_hardware_bom_management.sql) ---
export const bomSpecifications = pgTable('bom_specifications', {
  id: varchar('id', { length: 64 }).primaryKey(),
  hardwareRevisionId: varchar('hardware_revision_id', { length: 64 })
    .notNull()
    .references(() => hardwareRevisions.id),
  version: varchar('version', { length: 32 }).notNull().default('1.0.0'),
  lifecycleStatus: varchar('lifecycle_status', { length: 32 }).notNull().default('DRAFT'),
  totalUniqueComponents: integer('total_unique_components').notNull().default(0),
  notes: text('notes'),
  effectiveDate: timestamp('effective_date', { withTimezone: true }),
  createdAt: timestamp('created_at', { withTimezone: true }).notNull().defaultNow(),
  updatedAt: timestamp('updated_at', { withTimezone: true }).notNull().defaultNow(),
});

export type BomSpecifications = typeof bomSpecifications.$inferSelect;
export type NewBomSpecifications = typeof bomSpecifications.$inferInsert;

// --- bom_items (030_hardware_bom_management.sql) ---
export const bomItems = pgTable('bom_items', {
  id: varchar('id', { length: 64 }).primaryKey(),
  bomId: varchar('bom_id', { length: 64 })
    .notNull()
    .references(() => bomSpecifications.id, { onDelete: 'cascade' }),
  itemIndex: integer('item_index').notNull(),
  referenceDesignator: varchar('reference_designator', { length: 64 }).notNull(),
  mpn: varchar('mpn', { length: 128 }).notNull(),
  internalPartNumber: varchar('internal_part_number', { length: 64 }),
  manufacturer: varchar('manufacturer', { length: 128 }),
  description: text('description').notNull(),
  componentCategory: varchar('component_category', { length: 64 }).notNull().default('OTHER'),
  footprint: varchar('footprint', { length: 128 }).notNull(),
  quantity: integer('quantity').notNull(),
  unit: varchar('unit', { length: 16 }).notNull().default('pcs'),
  isDnf: boolean('is_dnf').notNull().default(false),
  vendorPartNumber: varchar('vendor_part_number', { length: 128 }),
  unitCostInr: numeric('unit_cost_inr', { precision: 10, scale: 4 }),
  createdAt: timestamp('created_at', { withTimezone: true }).notNull().defaultNow(),
});

export type BomItems = typeof bomItems.$inferSelect;
export type NewBomItems = typeof bomItems.$inferInsert;

// --- component_substitutions (030_hardware_bom_management.sql) ---
export const componentSubstitutions = pgTable('component_substitutions', {
  id: varchar('id', { length: 64 }).primaryKey(),
  bomItemId: varchar('bom_item_id', { length: 64 })
    .notNull()
    .references(() => bomItems.id, { onDelete: 'cascade' }),
  substituteMpn: varchar('substitute_mpn', { length: 128 }).notNull(),
  substituteManufacturer: varchar('substitute_manufacturer', { length: 128 }),
  approvalStatus: varchar('approval_status', { length: 32 }).notNull().default('APPROVED'),
  qualificationNotes: text('qualification_notes'),
  createdAt: timestamp('created_at', { withTimezone: true }).notNull().defaultNow(),
});

export type ComponentSubstitutions = typeof componentSubstitutions.$inferSelect;
export type NewComponentSubstitutions = typeof componentSubstitutions.$inferInsert;

// --- product_variant_hardware_compatibility (030_hardware_bom_management.sql) ---
export const productVariantHardwareCompatibility = pgTable('product_variant_hardware_compatibility', {
  id: varchar('id', { length: 64 }).primaryKey(),
  productVariantId: varchar('product_variant_id', { length: 128 })
    .notNull()
    .references(() => productVariants.id, { onDelete: 'cascade' }),
  hardwareRevisionId: varchar('hardware_revision_id', { length: 64 })
    .notNull()
    .references(() => hardwareRevisions.id, { onDelete: 'cascade' }),
  isPrimary: boolean('is_primary').notNull().default(false),
  compatibilityNotes: text('compatibility_notes'),
  verifiedAt: timestamp('verified_at', { withTimezone: true }).defaultNow(),
  createdAt: timestamp('created_at', { withTimezone: true }).notNull().defaultNow(),
});

export type ProductVariantHardwareCompatibility = typeof productVariantHardwareCompatibility.$inferSelect;
export type NewProductVariantHardwareCompatibility = typeof productVariantHardwareCompatibility.$inferInsert;
