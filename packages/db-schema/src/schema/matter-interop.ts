/**
 * EH Home Schema — matter-interop
 * Source: PostgreSQL Migrations 001–029
 */
import { integer, jsonb, pgTable, text, timestamp, unique, varchar } from 'drizzle-orm/pg-core';

// --- matter_devices (022_matter_ecosystem_interoperability.sql) ---
export const matterDevices = pgTable('matter_devices', {
  id: varchar('id', { length: 64 }).primaryKey(),
  deviceId: varchar('device_id', { length: 36 }).notNull().unique(),
  homeId: varchar('home_id', { length: 64 }).notNull(),
  nodeId: varchar('node_id', { length: 32 }).notNull(),
  vendorId: integer('vendor_id').notNull().default(65521),
  productId: integer('product_id').notNull(),
  matterDeviceType: varchar('matter_device_type', { length: 64 }).notNull(),
  commissioningState: varchar('commissioning_state', { length: 32 }).notNull().default('NOT_COMMISSIONED'),
  subscriptionState: varchar('subscription_state', { length: 32 }).notNull().default('NONE'),
  softwareVersion: integer('software_version').notNull().default(1),
  softwareVersionString: varchar('software_version_string', { length: 32 }).notNull().default('1.0.0'),
  hardwareVersion: integer('hardware_version').notNull().default(1),
  hardwareVersionString: varchar('hardware_version_string', { length: 32 }).notNull().default('revA'),
  discriminator: integer('discriminator').notNull().default(3840),
  setupPasscode: integer('setup_passcode').notNull(),
  lastSynchronizedAt: timestamp('last_synchronized_at', { withTimezone: true }),
  createdAt: timestamp('created_at', { withTimezone: true }).notNull().defaultNow(),
  updatedAt: timestamp('updated_at', { withTimezone: true }).notNull().defaultNow(),
});

export type MatterDevices = typeof matterDevices.$inferSelect;
export type NewMatterDevices = typeof matterDevices.$inferInsert;

// --- matter_fabrics (022_matter_ecosystem_interoperability.sql) ---
export const matterFabrics = pgTable('matter_fabrics', {
  id: varchar('id', { length: 64 }).primaryKey(),
  fabricId: varchar('fabric_id', { length: 32 }).notNull(),
  matterDeviceId: varchar('matter_device_id', { length: 64 }).notNull(),
  fabricIndex: integer('fabric_index').notNull(),
  fabricName: varchar('fabric_name', { length: 64 }).notNull(),
  vendorId: integer('vendor_id').notNull(),
  controllerNodeId: varchar('controller_node_id', { length: 32 }),
  commissioningState: varchar('commissioning_state', { length: 32 }).notNull().default('CONNECTED'),
  label: varchar('label', { length: 128 }),
  pairedAt: timestamp('paired_at', { withTimezone: true }).defaultNow(),
  lastSynchronizedAt: timestamp('last_synchronized_at', { withTimezone: true }).defaultNow(),
  createdAt: timestamp('created_at', { withTimezone: true }).notNull().defaultNow(),
  updatedAt: timestamp('updated_at', { withTimezone: true }).notNull().defaultNow(),
}, (t) => [
  unique().on(t.matterDeviceId, t.fabricIndex),
  unique().on(t.matterDeviceId, t.fabricId),
]);

export type MatterFabrics = typeof matterFabrics.$inferSelect;
export type NewMatterFabrics = typeof matterFabrics.$inferInsert;

// --- matter_endpoints (022_matter_ecosystem_interoperability.sql) ---
export const matterEndpoints = pgTable('matter_endpoints', {
  id: varchar('id', { length: 64 }).primaryKey(),
  matterDeviceId: varchar('matter_device_id', { length: 64 }).notNull(),
  endpointNumber: integer('endpoint_number').notNull(),
  deviceType: varchar('device_type', { length: 64 }).notNull(),
  channelIndex: integer('channel_index').notNull().default(1),
  serverClusters: jsonb('server_clusters').notNull().default([]),
  clientClusters: jsonb('client_clusters').default([]),
  createdAt: timestamp('created_at', { withTimezone: true }).notNull().defaultNow(),
  updatedAt: timestamp('updated_at', { withTimezone: true }).notNull().defaultNow(),
}, (t) => [
  unique().on(t.matterDeviceId, t.endpointNumber),
]);

export type MatterEndpoints = typeof matterEndpoints.$inferSelect;
export type NewMatterEndpoints = typeof matterEndpoints.$inferInsert;

// --- matter_sync_state (022_matter_ecosystem_interoperability.sql) ---
export const matterSyncState = pgTable('matter_sync_state', {
  id: varchar('id', { length: 64 }).primaryKey(),
  deviceId: varchar('device_id', { length: 36 }).notNull(),
  homeId: varchar('home_id', { length: 64 }).notNull(),
  lastEventId: varchar('last_event_id', { length: 64 }),
  lastStateVersion: integer('last_state_version').notNull().default(1),
  lastSyncedAttributes: jsonb('last_synced_attributes').notNull().default({}),
  syncStatus: varchar('sync_status', { length: 32 }).notNull().default('SYNCHRONIZED'),
  lastErrorMessage: text('last_error_message'),
  lastSyncedAt: timestamp('last_synced_at', { withTimezone: true }).notNull().defaultNow(),
  createdAt: timestamp('created_at', { withTimezone: true }).notNull().defaultNow(),
  updatedAt: timestamp('updated_at', { withTimezone: true }).notNull().defaultNow(),
}, (t) => [
  unique().on(t.deviceId),
]);

export type MatterSyncState = typeof matterSyncState.$inferSelect;
export type NewMatterSyncState = typeof matterSyncState.$inferInsert;

// --- external_platform_links (022_matter_ecosystem_interoperability.sql) ---
export const externalPlatformLinks = pgTable('external_platform_links', {
  id: varchar('id', { length: 64 }).primaryKey(),
  homeId: varchar('home_id', { length: 64 }).notNull(),
  deviceId: varchar('device_id', { length: 36 }).notNull(),
  platform: varchar('platform', { length: 32 }).notNull(),
  status: varchar('status', { length: 32 }).notNull().default('NOT_CONNECTED'),
  externalIdentifier: varchar('external_identifier', { length: 128 }),
  displayName: varchar('display_name', { length: 128 }).notNull(),
  syncStatus: varchar('sync_status', { length: 32 }).notNull().default('IDLE'),
  lastErrorMessage: text('last_error_message'),
  linkedAt: timestamp('linked_at', { withTimezone: true }),
  lastSyncedAt: timestamp('last_synced_at', { withTimezone: true }),
  createdAt: timestamp('created_at', { withTimezone: true }).notNull().defaultNow(),
  updatedAt: timestamp('updated_at', { withTimezone: true }).notNull().defaultNow(),
}, (t) => [
  unique().on(t.deviceId, t.platform),
]);

export type ExternalPlatformLinks = typeof externalPlatformLinks.$inferSelect;
export type NewExternalPlatformLinks = typeof externalPlatformLinks.$inferInsert;
