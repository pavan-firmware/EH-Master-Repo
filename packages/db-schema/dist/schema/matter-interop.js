"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.externalPlatformLinks = exports.matterSyncState = exports.matterEndpoints = exports.matterFabrics = exports.matterDevices = void 0;
/**
 * EH Home Schema — matter-interop
 * Source: PostgreSQL Migrations 001–029
 */
const pg_core_1 = require("drizzle-orm/pg-core");
// --- matter_devices (022_matter_ecosystem_interoperability.sql) ---
exports.matterDevices = (0, pg_core_1.pgTable)('matter_devices', {
    id: (0, pg_core_1.varchar)('id', { length: 64 }).primaryKey(),
    deviceId: (0, pg_core_1.varchar)('device_id', { length: 36 }).notNull().unique(),
    homeId: (0, pg_core_1.varchar)('home_id', { length: 64 }).notNull(),
    nodeId: (0, pg_core_1.varchar)('node_id', { length: 32 }).notNull(),
    vendorId: (0, pg_core_1.integer)('vendor_id').notNull().default(65521),
    productId: (0, pg_core_1.integer)('product_id').notNull(),
    matterDeviceType: (0, pg_core_1.varchar)('matter_device_type', { length: 64 }).notNull(),
    commissioningState: (0, pg_core_1.varchar)('commissioning_state', { length: 32 }).notNull().default('NOT_COMMISSIONED'),
    subscriptionState: (0, pg_core_1.varchar)('subscription_state', { length: 32 }).notNull().default('NONE'),
    softwareVersion: (0, pg_core_1.integer)('software_version').notNull().default(1),
    softwareVersionString: (0, pg_core_1.varchar)('software_version_string', { length: 32 }).notNull().default('1.0.0'),
    hardwareVersion: (0, pg_core_1.integer)('hardware_version').notNull().default(1),
    hardwareVersionString: (0, pg_core_1.varchar)('hardware_version_string', { length: 32 }).notNull().default('revA'),
    discriminator: (0, pg_core_1.integer)('discriminator').notNull().default(3840),
    setupPasscode: (0, pg_core_1.integer)('setup_passcode').notNull(),
    lastSynchronizedAt: (0, pg_core_1.timestamp)('last_synchronized_at', { withTimezone: true }),
    createdAt: (0, pg_core_1.timestamp)('created_at', { withTimezone: true }).notNull().defaultNow(),
    updatedAt: (0, pg_core_1.timestamp)('updated_at', { withTimezone: true }).notNull().defaultNow(),
});
// --- matter_fabrics (022_matter_ecosystem_interoperability.sql) ---
exports.matterFabrics = (0, pg_core_1.pgTable)('matter_fabrics', {
    id: (0, pg_core_1.varchar)('id', { length: 64 }).primaryKey(),
    fabricId: (0, pg_core_1.varchar)('fabric_id', { length: 32 }).notNull(),
    matterDeviceId: (0, pg_core_1.varchar)('matter_device_id', { length: 64 }).notNull(),
    fabricIndex: (0, pg_core_1.integer)('fabric_index').notNull(),
    fabricName: (0, pg_core_1.varchar)('fabric_name', { length: 64 }).notNull(),
    vendorId: (0, pg_core_1.integer)('vendor_id').notNull(),
    controllerNodeId: (0, pg_core_1.varchar)('controller_node_id', { length: 32 }),
    commissioningState: (0, pg_core_1.varchar)('commissioning_state', { length: 32 }).notNull().default('CONNECTED'),
    label: (0, pg_core_1.varchar)('label', { length: 128 }),
    pairedAt: (0, pg_core_1.timestamp)('paired_at', { withTimezone: true }).defaultNow(),
    lastSynchronizedAt: (0, pg_core_1.timestamp)('last_synchronized_at', { withTimezone: true }).defaultNow(),
    createdAt: (0, pg_core_1.timestamp)('created_at', { withTimezone: true }).notNull().defaultNow(),
    updatedAt: (0, pg_core_1.timestamp)('updated_at', { withTimezone: true }).notNull().defaultNow(),
}, (t) => [
    (0, pg_core_1.unique)().on(t.matterDeviceId, t.fabricIndex),
    (0, pg_core_1.unique)().on(t.matterDeviceId, t.fabricId),
]);
// --- matter_endpoints (022_matter_ecosystem_interoperability.sql) ---
exports.matterEndpoints = (0, pg_core_1.pgTable)('matter_endpoints', {
    id: (0, pg_core_1.varchar)('id', { length: 64 }).primaryKey(),
    matterDeviceId: (0, pg_core_1.varchar)('matter_device_id', { length: 64 }).notNull(),
    endpointNumber: (0, pg_core_1.integer)('endpoint_number').notNull(),
    deviceType: (0, pg_core_1.varchar)('device_type', { length: 64 }).notNull(),
    channelIndex: (0, pg_core_1.integer)('channel_index').notNull().default(1),
    serverClusters: (0, pg_core_1.jsonb)('server_clusters').notNull().default([]),
    clientClusters: (0, pg_core_1.jsonb)('client_clusters').default([]),
    createdAt: (0, pg_core_1.timestamp)('created_at', { withTimezone: true }).notNull().defaultNow(),
    updatedAt: (0, pg_core_1.timestamp)('updated_at', { withTimezone: true }).notNull().defaultNow(),
}, (t) => [
    (0, pg_core_1.unique)().on(t.matterDeviceId, t.endpointNumber),
]);
// --- matter_sync_state (022_matter_ecosystem_interoperability.sql) ---
exports.matterSyncState = (0, pg_core_1.pgTable)('matter_sync_state', {
    id: (0, pg_core_1.varchar)('id', { length: 64 }).primaryKey(),
    deviceId: (0, pg_core_1.varchar)('device_id', { length: 36 }).notNull(),
    homeId: (0, pg_core_1.varchar)('home_id', { length: 64 }).notNull(),
    lastEventId: (0, pg_core_1.varchar)('last_event_id', { length: 64 }),
    lastStateVersion: (0, pg_core_1.integer)('last_state_version').notNull().default(1),
    lastSyncedAttributes: (0, pg_core_1.jsonb)('last_synced_attributes').notNull().default({}),
    syncStatus: (0, pg_core_1.varchar)('sync_status', { length: 32 }).notNull().default('SYNCHRONIZED'),
    lastErrorMessage: (0, pg_core_1.text)('last_error_message'),
    lastSyncedAt: (0, pg_core_1.timestamp)('last_synced_at', { withTimezone: true }).notNull().defaultNow(),
    createdAt: (0, pg_core_1.timestamp)('created_at', { withTimezone: true }).notNull().defaultNow(),
    updatedAt: (0, pg_core_1.timestamp)('updated_at', { withTimezone: true }).notNull().defaultNow(),
}, (t) => [
    (0, pg_core_1.unique)().on(t.deviceId),
]);
// --- external_platform_links (022_matter_ecosystem_interoperability.sql) ---
exports.externalPlatformLinks = (0, pg_core_1.pgTable)('external_platform_links', {
    id: (0, pg_core_1.varchar)('id', { length: 64 }).primaryKey(),
    homeId: (0, pg_core_1.varchar)('home_id', { length: 64 }).notNull(),
    deviceId: (0, pg_core_1.varchar)('device_id', { length: 36 }).notNull(),
    platform: (0, pg_core_1.varchar)('platform', { length: 32 }).notNull(),
    status: (0, pg_core_1.varchar)('status', { length: 32 }).notNull().default('NOT_CONNECTED'),
    externalIdentifier: (0, pg_core_1.varchar)('external_identifier', { length: 128 }),
    displayName: (0, pg_core_1.varchar)('display_name', { length: 128 }).notNull(),
    syncStatus: (0, pg_core_1.varchar)('sync_status', { length: 32 }).notNull().default('IDLE'),
    lastErrorMessage: (0, pg_core_1.text)('last_error_message'),
    linkedAt: (0, pg_core_1.timestamp)('linked_at', { withTimezone: true }),
    lastSyncedAt: (0, pg_core_1.timestamp)('last_synced_at', { withTimezone: true }),
    createdAt: (0, pg_core_1.timestamp)('created_at', { withTimezone: true }).notNull().defaultNow(),
    updatedAt: (0, pg_core_1.timestamp)('updated_at', { withTimezone: true }).notNull().defaultNow(),
}, (t) => [
    (0, pg_core_1.unique)().on(t.deviceId, t.platform),
]);
//# sourceMappingURL=matter-interop.js.map