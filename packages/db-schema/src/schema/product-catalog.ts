/**
 * EH Home Schema — product-catalog
 * Source: PostgreSQL Migrations 001–029
 */
import { integer, jsonb, pgTable, primaryKey, text, timestamp, varchar } from 'drizzle-orm/pg-core';

// --- product_families (001_initial_schema.sql) ---
export const productFamilies = pgTable('product_families', {
  id: varchar('id', { length: 128 }).primaryKey(),
  slug: varchar('slug', { length: 64 }).notNull().unique(),
  displayName: varchar('display_name', { length: 128 }).notNull(),
  description: text('description'),
  createdAt: timestamp('created_at', { withTimezone: true }).notNull().defaultNow(),
});

export type ProductFamilies = typeof productFamilies.$inferSelect;
export type NewProductFamilies = typeof productFamilies.$inferInsert;

// --- products (001_initial_schema.sql) ---
export const products = pgTable('products', {
  id: varchar('id', { length: 128 }).primaryKey(),
  familyId: varchar('family_id', { length: 128 }).notNull(),
  displayName: varchar('display_name', { length: 128 }).notNull(),
  description: text('description'),
  schemaVersion: integer('schema_version').notNull().default(1),
  status: varchar('status', { length: 32 }).notNull().default('PUBLISHED'),
  createdAt: timestamp('created_at', { withTimezone: true }).notNull().defaultNow(),
  updatedAt: timestamp('updated_at', { withTimezone: true }).notNull().defaultNow(),
});

export type Products = typeof products.$inferSelect;
export type NewProducts = typeof products.$inferInsert;

// --- product_variants (001_initial_schema.sql) ---
export const productVariants = pgTable('product_variants', {
  id: varchar('id', { length: 128 }).primaryKey(),
  productId: varchar('product_id', { length: 128 }).notNull(),
  variantSlug: varchar('variant_slug', { length: 64 }).notNull(),
  displayName: varchar('display_name', { length: 128 }).notNull(),
  channelCount: integer('channel_count').notNull().default(1),
  channels: jsonb('channels').notNull(),
  hardwareProfile: jsonb('hardware_profile').notNull(),
  connectivityProfile: jsonb('connectivity_profile').notNull(),
  capabilities: jsonb('capabilities').notNull(),
  electricalSpecifications: jsonb('electrical_specifications').notNull(),
  firmwareFamily: varchar('firmware_family', { length: 64 }).notNull(),
  supportedHardwareRevisions: jsonb('supported_hardware_revisions').notNull(),
  createdAt: timestamp('created_at', { withTimezone: true }).notNull().defaultNow(),
});

export type ProductVariants = typeof productVariants.$inferSelect;
export type NewProductVariants = typeof productVariants.$inferInsert;

// --- product_models (020_product_discovery_catalog.sql) ---
export const productModels = pgTable('product_models', {
  id: varchar('id', { length: 64 }).primaryKey(),
  familyId: varchar('family_id', { length: 64 }).notNull(),
  marketingName: varchar('marketing_name', { length: 128 }).notNull(),
  technicalName: varchar('technical_name', { length: 128 }).notNull(),
  description: text('description'),
  generation: integer('generation').notNull().default(1),
  brand: varchar('brand', { length: 64 }).notNull().default('EH'),
  createdAt: timestamp('created_at', { withTimezone: true }).notNull().defaultNow(),
});

export type ProductModels = typeof productModels.$inferSelect;
export type NewProductModels = typeof productModels.$inferInsert;

// --- capabilities (002_capabilities_network_audit_outbox.sql) ---
export const capabilities = pgTable('capabilities', {
  capabilityId: varchar('capability_id', { length: 64 }).primaryKey(),
  version: integer('version').notNull().default(1),
  displayName: varchar('display_name', { length: 128 }).notNull(),
  description: text('description'),
  properties: jsonb('properties').notNull().default({}),
  commands: jsonb('commands').notNull().default([]),
  events: jsonb('events').notNull().default([]),
  telemetryFields: jsonb('telemetry_fields').notNull().default([]),
  uiComponentHint: varchar('ui_component_hint', { length: 64 }).notNull(),
  automationTriggers: jsonb('automation_triggers').notNull().default([]),
  automationActions: jsonb('automation_actions').notNull().default([]),
  createdAt: timestamp('created_at', { withTimezone: true }).notNull().defaultNow(),
  updatedAt: timestamp('updated_at', { withTimezone: true }).notNull().defaultNow(),
});

export type Capabilities = typeof capabilities.$inferSelect;
export type NewCapabilities = typeof capabilities.$inferInsert;

// --- product_capabilities (002_capabilities_network_audit_outbox.sql) ---
export const productCapabilities = pgTable('product_capabilities', {
  productVariantId: varchar('product_variant_id', { length: 128 }).notNull(),
  capabilityId: varchar('capability_id', { length: 64 }).notNull(),
  channelIndex: integer('channel_index'),
  config: jsonb('config').default({}),
}, (t) => [
  primaryKey({ columns: [t.productVariantId, t.capabilityId, t.channelIndex] }),
]);

export type ProductCapabilities = typeof productCapabilities.$inferSelect;
export type NewProductCapabilities = typeof productCapabilities.$inferInsert;

// --- product_images (002_capabilities_network_audit_outbox.sql) ---
export const productImages = pgTable('product_images', {
  id: varchar('id', { length: 128 }).primaryKey(),
  productVariantId: varchar('product_variant_id', { length: 128 }).notNull(),
  kind: varchar('kind', { length: 32 }).notNull(),
  url: text('url').notNull(),
  sortOrder: integer('sort_order').notNull().default(0),
  createdAt: timestamp('created_at', { withTimezone: true }).notNull().defaultNow(),
});

export type ProductImages = typeof productImages.$inferSelect;
export type NewProductImages = typeof productImages.$inferInsert;

// --- device_add_sessions (020_product_discovery_catalog.sql) ---
export const deviceAddSessions = pgTable('device_add_sessions', {
  id: varchar('id', { length: 64 }).primaryKey(),
  homeId: varchar('home_id', { length: 64 }).notNull(),
  userId: varchar('user_id', { length: 64 }).notNull(),
  entryMode: varchar('entry_mode', { length: 32 }).notNull(),
  stage: varchar('stage', { length: 32 }).notNull(),
  productVariantId: varchar('product_variant_id', { length: 64 }),
  deviceId: varchar('device_id', { length: 64 }),
  commissioningSessionId: varchar('commissioning_session_id', { length: 64 }),
  selectedRoomId: varchar('selected_room_id', { length: 64 }),
  customDeviceName: varchar('custom_device_name', { length: 128 }),
  channelLabels: jsonb('channel_labels').default({}),
  compatibilityStatus: varchar('compatibility_status', { length: 32 }),
  errorMessage: text('error_message'),
  createdAt: timestamp('created_at', { withTimezone: true }).notNull().defaultNow(),
  updatedAt: timestamp('updated_at', { withTimezone: true }).notNull().defaultNow(),
  completedAt: timestamp('completed_at', { withTimezone: true }),
});

export type DeviceAddSessions = typeof deviceAddSessions.$inferSelect;
export type NewDeviceAddSessions = typeof deviceAddSessions.$inferInsert;
