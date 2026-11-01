/**
 * EH Home Schema — device-identity-state
 * Source: PostgreSQL Migrations 001–029
 */
import { bigint, integer, jsonb, pgTable, text, timestamp, unique, varchar } from 'drizzle-orm/pg-core';

// --- devices (001_initial_schema.sql) ---
export const devices = pgTable('devices', {
  id: varchar('id', { length: 128 }).primaryKey(),
  serialNumber: varchar('serial_number', { length: 128 }).notNull().unique(),
  productVariantId: varchar('product_variant_id', { length: 128 }).notNull(),
  hardwareRevision: varchar('hardware_revision', { length: 32 }).notNull(),
  firmwareVersion: varchar('firmware_version', { length: 32 }).notNull().default('1.0.0'),
  firmwareFamily: varchar('firmware_family', { length: 64 }).notNull(),
  createdAt: timestamp('created_at', { withTimezone: true }).notNull().defaultNow(),
  updatedAt: timestamp('updated_at', { withTimezone: true }).notNull().defaultNow(),
});

export type Devices = typeof devices.$inferSelect;
export type NewDevices = typeof devices.$inferInsert;

// --- device_credentials (001_initial_schema.sql) ---
export const deviceCredentials = pgTable('device_credentials', {
  deviceId: varchar('device_id', { length: 128 }).primaryKey(),
  mqttUsername: varchar('mqtt_username', { length: 128 }).notNull().unique(),
  mqttPasswordHash: varchar('mqtt_password_hash', { length: 255 }).notNull(),
  tlsClientCertFingerprint: varchar('tls_client_cert_fingerprint', { length: 64 }),
  localSessionKeyHash: varchar('local_session_key_hash', { length: 255 }).notNull(),
  credentialState: varchar('credential_state', { length: 32 }).notNull(),
  createdAt: timestamp('created_at', { withTimezone: true }).notNull().defaultNow(),
  rotatedAt: timestamp('rotated_at', { withTimezone: true }),
});

export type DeviceCredentials = typeof deviceCredentials.$inferSelect;
export type NewDeviceCredentials = typeof deviceCredentials.$inferInsert;

// --- device_authorizations (001_initial_schema.sql) ---
export const deviceAuthorizations = pgTable('device_authorizations', {
  deviceId: varchar('device_id', { length: 128 }).primaryKey(),
  homeId: varchar('home_id', { length: 128 }).notNull(),
  roomId: varchar('room_id', { length: 128 }),
  customName: varchar('custom_name', { length: 128 }).notNull(),
  channelLabels: jsonb('channel_labels').default({}),
  claimedAt: timestamp('claimed_at', { withTimezone: true }).notNull().defaultNow(),
  claimedByUserId: varchar('claimed_by_user_id', { length: 128 }).notNull(),
});

export type DeviceAuthorizations = typeof deviceAuthorizations.$inferSelect;
export type NewDeviceAuthorizations = typeof deviceAuthorizations.$inferInsert;

// --- device_state (001_initial_schema.sql) ---
export const deviceState = pgTable('device_state', {
  deviceId: varchar('device_id', { length: 128 }).primaryKey(),
  connectionState: varchar('connection_state', { length: 32 }).notNull().default('OFFLINE'),
  lastSeenAt: timestamp('last_seen_at', { withTimezone: true }),
  lastCommandId: varchar('last_command_id', { length: 128 }),
  lastEventId: varchar('last_event_id', { length: 128 }),
  updatedAt: timestamp('updated_at', { withTimezone: true }).notNull().defaultNow(),
});

export type DeviceState = typeof deviceState.$inferSelect;
export type NewDeviceState = typeof deviceState.$inferInsert;

// --- channel_state (001_initial_schema.sql) ---
export const channelState = pgTable('channel_state', {
  id: varchar('id', { length: 255 }).primaryKey(),
  deviceId: varchar('device_id', { length: 128 }).notNull(),
  channelIndex: integer('channel_index').notNull(),
  desiredState: jsonb('desired_state').default({}),
  reportedState: jsonb('reported_state').default({}),
  confidence: varchar('confidence', { length: 32 }).notNull().default('UNKNOWN'),
  updatedAt: timestamp('updated_at', { withTimezone: true }).notNull().defaultNow(),
}, (t) => [
  unique().on(t.deviceId, t.channelIndex),
]);

export type ChannelState = typeof channelState.$inferSelect;
export type NewChannelState = typeof channelState.$inferInsert;

// --- device_commands (001_initial_schema.sql) ---
export const deviceCommands = pgTable('device_commands', {
  id: varchar('id', { length: 128 }).primaryKey(),
  deviceId: varchar('device_id', { length: 128 }).notNull(),
  channelIndex: integer('channel_index').notNull(),
  action: varchar('action', { length: 64 }).notNull(),
  params: jsonb('params').notNull().default({}),
  idempotencyKey: varchar('idempotency_key', { length: 128 }).notNull(),
  source: varchar('source', { length: 32 }).notNull(),
  status: varchar('status', { length: 32 }).notNull().default('CREATED'),
  failureReason: text('failure_reason'),
  createdAt: timestamp('created_at', { withTimezone: true }).notNull().defaultNow(),
  expiresAt: timestamp('expires_at', { withTimezone: true }).notNull(),
  completedAt: timestamp('completed_at', { withTimezone: true }),
});

export type DeviceCommands = typeof deviceCommands.$inferSelect;
export type NewDeviceCommands = typeof deviceCommands.$inferInsert;

// --- device_events (001_initial_schema.sql) ---
export const deviceEvents = pgTable('device_events', {
  id: varchar('id', { length: 128 }).primaryKey(),
  deviceId: varchar('device_id', { length: 128 }).notNull(),
  channelIndex: integer('channel_index').notNull(),
  eventType: varchar('event_type', { length: 64 }).notNull(),
  source: varchar('source', { length: 32 }).notNull(),
  payload: jsonb('payload').notNull().default({}),
  sequenceNumber: bigint('sequence_number', { mode: 'number' }).notNull(),
  timestamp: timestamp('timestamp', { withTimezone: true }).notNull(),
  createdAt: timestamp('created_at', { withTimezone: true }).notNull().defaultNow(),
});

export type DeviceEvents = typeof deviceEvents.$inferSelect;
export type NewDeviceEvents = typeof deviceEvents.$inferInsert;

// --- network_identity (002_capabilities_network_audit_outbox.sql) ---
export const networkIdentity = pgTable('network_identity', {
  deviceId: varchar('device_id', { length: 128 }).primaryKey(),
  wifiMacAddress: varchar('wifi_mac_address', { length: 32 }),
  threadExtendedAddress: varchar('thread_extended_address', { length: 32 }),
  currentIpv4Address: varchar('current_ipv4_address', { length: 45 }),
  currentIpv6Address: varchar('current_ipv6_address', { length: 45 }),
  bleMacAddress: varchar('ble_mac_address', { length: 32 }),
  lastSeenAt: timestamp('last_seen_at', { withTimezone: true }).notNull().defaultNow(),
  updatedAt: timestamp('updated_at', { withTimezone: true }).notNull().defaultNow(),
});

export type NetworkIdentity = typeof networkIdentity.$inferSelect;
export type NewNetworkIdentity = typeof networkIdentity.$inferInsert;

// --- provisioning_sessions (005_create_provisioning_sessions.sql) ---
export const provisioningSessions = pgTable('provisioning_sessions', {
  id: varchar('id', { length: 128 }).primaryKey(),
  deviceId: varchar('device_id', { length: 128 }).notNull(),
  appChallenge: varchar('app_challenge', { length: 256 }),
  deviceChallenge: varchar('device_challenge', { length: 256 }),
  ssid: varchar('ssid', { length: 128 }),
  status: varchar('status', { length: 32 }).notNull().default('CREATED'),
  expiresAt: timestamp('expires_at', { withTimezone: true }).notNull(),
  createdAt: timestamp('created_at', { withTimezone: true }).notNull().defaultNow(),
  updatedAt: timestamp('updated_at', { withTimezone: true }),
  endedAt: timestamp('ended_at', { withTimezone: true }),
});

export type ProvisioningSessions = typeof provisioningSessions.$inferSelect;
export type NewProvisioningSessions = typeof provisioningSessions.$inferInsert;
