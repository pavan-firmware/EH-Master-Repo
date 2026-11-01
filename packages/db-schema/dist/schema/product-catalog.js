"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.deviceAddSessions = exports.productImages = exports.productCapabilities = exports.capabilities = exports.productModels = exports.productVariants = exports.products = exports.productFamilies = void 0;
/**
 * EH Home Schema — product-catalog
 * Source: PostgreSQL Migrations 001–029
 */
const pg_core_1 = require("drizzle-orm/pg-core");
// --- product_families (001_initial_schema.sql) ---
exports.productFamilies = (0, pg_core_1.pgTable)('product_families', {
    id: (0, pg_core_1.varchar)('id', { length: 128 }).primaryKey(),
    slug: (0, pg_core_1.varchar)('slug', { length: 64 }).notNull().unique(),
    displayName: (0, pg_core_1.varchar)('display_name', { length: 128 }).notNull(),
    description: (0, pg_core_1.text)('description'),
    createdAt: (0, pg_core_1.timestamp)('created_at', { withTimezone: true }).notNull().defaultNow(),
});
// --- products (001_initial_schema.sql) ---
exports.products = (0, pg_core_1.pgTable)('products', {
    id: (0, pg_core_1.varchar)('id', { length: 128 }).primaryKey(),
    familyId: (0, pg_core_1.varchar)('family_id', { length: 128 }).notNull(),
    displayName: (0, pg_core_1.varchar)('display_name', { length: 128 }).notNull(),
    description: (0, pg_core_1.text)('description'),
    schemaVersion: (0, pg_core_1.integer)('schema_version').notNull().default(1),
    status: (0, pg_core_1.varchar)('status', { length: 32 }).notNull().default('PUBLISHED'),
    createdAt: (0, pg_core_1.timestamp)('created_at', { withTimezone: true }).notNull().defaultNow(),
    updatedAt: (0, pg_core_1.timestamp)('updated_at', { withTimezone: true }).notNull().defaultNow(),
});
// --- product_variants (001_initial_schema.sql) ---
exports.productVariants = (0, pg_core_1.pgTable)('product_variants', {
    id: (0, pg_core_1.varchar)('id', { length: 128 }).primaryKey(),
    productId: (0, pg_core_1.varchar)('product_id', { length: 128 }).notNull(),
    variantSlug: (0, pg_core_1.varchar)('variant_slug', { length: 64 }).notNull(),
    displayName: (0, pg_core_1.varchar)('display_name', { length: 128 }).notNull(),
    channelCount: (0, pg_core_1.integer)('channel_count').notNull().default(1),
    channels: (0, pg_core_1.jsonb)('channels').notNull(),
    hardwareProfile: (0, pg_core_1.jsonb)('hardware_profile').notNull(),
    connectivityProfile: (0, pg_core_1.jsonb)('connectivity_profile').notNull(),
    capabilities: (0, pg_core_1.jsonb)('capabilities').notNull(),
    electricalSpecifications: (0, pg_core_1.jsonb)('electrical_specifications').notNull(),
    firmwareFamily: (0, pg_core_1.varchar)('firmware_family', { length: 64 }).notNull(),
    supportedHardwareRevisions: (0, pg_core_1.jsonb)('supported_hardware_revisions').notNull(),
    createdAt: (0, pg_core_1.timestamp)('created_at', { withTimezone: true }).notNull().defaultNow(),
});
// --- product_models (020_product_discovery_catalog.sql) ---
exports.productModels = (0, pg_core_1.pgTable)('product_models', {
    id: (0, pg_core_1.varchar)('id', { length: 64 }).primaryKey(),
    familyId: (0, pg_core_1.varchar)('family_id', { length: 64 }).notNull(),
    marketingName: (0, pg_core_1.varchar)('marketing_name', { length: 128 }).notNull(),
    technicalName: (0, pg_core_1.varchar)('technical_name', { length: 128 }).notNull(),
    description: (0, pg_core_1.text)('description'),
    generation: (0, pg_core_1.integer)('generation').notNull().default(1),
    brand: (0, pg_core_1.varchar)('brand', { length: 64 }).notNull().default('EH'),
    createdAt: (0, pg_core_1.timestamp)('created_at', { withTimezone: true }).notNull().defaultNow(),
});
// --- capabilities (002_capabilities_network_audit_outbox.sql) ---
exports.capabilities = (0, pg_core_1.pgTable)('capabilities', {
    capabilityId: (0, pg_core_1.varchar)('capability_id', { length: 64 }).primaryKey(),
    version: (0, pg_core_1.integer)('version').notNull().default(1),
    displayName: (0, pg_core_1.varchar)('display_name', { length: 128 }).notNull(),
    description: (0, pg_core_1.text)('description'),
    properties: (0, pg_core_1.jsonb)('properties').notNull().default({}),
    commands: (0, pg_core_1.jsonb)('commands').notNull().default([]),
    events: (0, pg_core_1.jsonb)('events').notNull().default([]),
    telemetryFields: (0, pg_core_1.jsonb)('telemetry_fields').notNull().default([]),
    uiComponentHint: (0, pg_core_1.varchar)('ui_component_hint', { length: 64 }).notNull(),
    automationTriggers: (0, pg_core_1.jsonb)('automation_triggers').notNull().default([]),
    automationActions: (0, pg_core_1.jsonb)('automation_actions').notNull().default([]),
    createdAt: (0, pg_core_1.timestamp)('created_at', { withTimezone: true }).notNull().defaultNow(),
    updatedAt: (0, pg_core_1.timestamp)('updated_at', { withTimezone: true }).notNull().defaultNow(),
});
// --- product_capabilities (002_capabilities_network_audit_outbox.sql) ---
exports.productCapabilities = (0, pg_core_1.pgTable)('product_capabilities', {
    productVariantId: (0, pg_core_1.varchar)('product_variant_id', { length: 128 }).notNull(),
    capabilityId: (0, pg_core_1.varchar)('capability_id', { length: 64 }).notNull(),
    channelIndex: (0, pg_core_1.integer)('channel_index'),
    config: (0, pg_core_1.jsonb)('config').default({}),
}, (t) => [
    (0, pg_core_1.primaryKey)({ columns: [t.productVariantId, t.capabilityId, t.channelIndex] }),
]);
// --- product_images (002_capabilities_network_audit_outbox.sql) ---
exports.productImages = (0, pg_core_1.pgTable)('product_images', {
    id: (0, pg_core_1.varchar)('id', { length: 128 }).primaryKey(),
    productVariantId: (0, pg_core_1.varchar)('product_variant_id', { length: 128 }).notNull(),
    kind: (0, pg_core_1.varchar)('kind', { length: 32 }).notNull(),
    url: (0, pg_core_1.text)('url').notNull(),
    sortOrder: (0, pg_core_1.integer)('sort_order').notNull().default(0),
    createdAt: (0, pg_core_1.timestamp)('created_at', { withTimezone: true }).notNull().defaultNow(),
});
// --- device_add_sessions (020_product_discovery_catalog.sql) ---
exports.deviceAddSessions = (0, pg_core_1.pgTable)('device_add_sessions', {
    id: (0, pg_core_1.varchar)('id', { length: 64 }).primaryKey(),
    homeId: (0, pg_core_1.varchar)('home_id', { length: 64 }).notNull(),
    userId: (0, pg_core_1.varchar)('user_id', { length: 64 }).notNull(),
    entryMode: (0, pg_core_1.varchar)('entry_mode', { length: 32 }).notNull(),
    stage: (0, pg_core_1.varchar)('stage', { length: 32 }).notNull(),
    productVariantId: (0, pg_core_1.varchar)('product_variant_id', { length: 64 }),
    deviceId: (0, pg_core_1.varchar)('device_id', { length: 64 }),
    commissioningSessionId: (0, pg_core_1.varchar)('commissioning_session_id', { length: 64 }),
    selectedRoomId: (0, pg_core_1.varchar)('selected_room_id', { length: 64 }),
    customDeviceName: (0, pg_core_1.varchar)('custom_device_name', { length: 128 }),
    channelLabels: (0, pg_core_1.jsonb)('channel_labels').default({}),
    compatibilityStatus: (0, pg_core_1.varchar)('compatibility_status', { length: 32 }),
    errorMessage: (0, pg_core_1.text)('error_message'),
    createdAt: (0, pg_core_1.timestamp)('created_at', { withTimezone: true }).notNull().defaultNow(),
    updatedAt: (0, pg_core_1.timestamp)('updated_at', { withTimezone: true }).notNull().defaultNow(),
    completedAt: (0, pg_core_1.timestamp)('completed_at', { withTimezone: true }),
});
//# sourceMappingURL=product-catalog.js.map