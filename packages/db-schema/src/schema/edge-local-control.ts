/**
 * EH Home Schema — edge-local-control
 * Source: PostgreSQL Migrations 001–029
 */
import { boolean, integer, pgTable, real, text, timestamp, varchar } from 'drizzle-orm/pg-core';

// --- local_route_cache (021_local_first_edge_control.sql) ---
export const localRouteCache = pgTable('local_route_cache', {
  id: varchar('id', { length: 64 }).primaryKey(),
  deviceId: varchar('device_id', { length: 64 }).notNull(),
  homeId: varchar('home_id', { length: 64 }).notNull(),
  transportType: varchar('transport_type', { length: 32 }).notNull(),
  localEndpoint: varchar('local_endpoint', { length: 255 }).notNull(),
  localIp: varchar('local_ip', { length: 64 }),
  localPort: integer('local_port'),
  reachability: varchar('reachability', { length: 32 }).notNull().default('REACHABLE'),
  identityFingerprint: varchar('identity_fingerprint', { length: 128 }),
  isTlsSecured: boolean('is_tls_secured').default(true),
  latencyMs: real('latency_ms').default(0.0),
  expiresAt: timestamp('expires_at').notNull(),
  lastContactAt: timestamp('last_contact_at').notNull(),
  createdAt: timestamp('created_at').defaultNow(),
  updatedAt: timestamp('updated_at').defaultNow(),
});

export type LocalRouteCache = typeof localRouteCache.$inferSelect;
export type NewLocalRouteCache = typeof localRouteCache.$inferInsert;

// --- edge_execution_records (021_local_first_edge_control.sql) ---
export const edgeExecutionRecords = pgTable('edge_execution_records', {
  id: varchar('id', { length: 64 }).primaryKey(),
  commandId: varchar('command_id', { length: 64 }).notNull(),
  deviceId: varchar('device_id', { length: 64 }).notNull(),
  homeId: varchar('home_id', { length: 64 }).notNull(),
  channelIndex: integer('channel_index'),
  action: varchar('action', { length: 64 }).notNull(),
  routeMode: varchar('route_mode', { length: 32 }).notNull(),
  transportUsed: varchar('transport_used', { length: 32 }).notNull(),
  status: varchar('status', { length: 32 }).notNull(),
  isConfirmedByDevice: boolean('is_confirmed_by_device').notNull().default(false),
  confirmedState: text('confirmed_state'),
  latencyMs: real('latency_ms').default(0.0),
  errorMessage: text('error_message'),
  idempotencyKey: varchar('idempotency_key', { length: 128 }),
  actorUserId: varchar('actor_user_id', { length: 64 }),
  actorSource: varchar('actor_source', { length: 32 }),
  queuedForCloudSync: boolean('queued_for_cloud_sync').default(false),
  executedAt: timestamp('executed_at').notNull(),
  createdAt: timestamp('created_at').defaultNow(),
});

export type EdgeExecutionRecords = typeof edgeExecutionRecords.$inferSelect;
export type NewEdgeExecutionRecords = typeof edgeExecutionRecords.$inferInsert;

// --- local_discovery_nodes (021_local_first_edge_control.sql) ---
export const localDiscoveryNodes = pgTable('local_discovery_nodes', {
  id: varchar('id', { length: 64 }).primaryKey(),
  discoveryId: varchar('discovery_id', { length: 64 }).notNull().unique(),
  deviceId: varchar('device_id', { length: 64 }).notNull(),
  homeId: varchar('home_id', { length: 64 }).notNull(),
  productVariantId: varchar('product_variant_id', { length: 64 }),
  macAddress: varchar('mac_address', { length: 64 }).notNull(),
  ipAddress: varchar('ip_address', { length: 64 }).notNull(),
  port: integer('port').notNull(),
  transportType: varchar('transport_type', { length: 32 }).notNull(),
  protocolVersion: varchar('protocol_version', { length: 32 }),
  firmwareVersion: varchar('firmware_version', { length: 32 }),
  identityFingerprint: varchar('identity_fingerprint', { length: 128 }).notNull(),
  isTrusted: boolean('is_trusted').notNull().default(true),
  ttlSeconds: integer('ttl_seconds').default(300),
  discoveredAt: timestamp('discovered_at').notNull(),
  createdAt: timestamp('created_at').defaultNow(),
  updatedAt: timestamp('updated_at').defaultNow(),
});

export type LocalDiscoveryNodes = typeof localDiscoveryNodes.$inferSelect;
export type NewLocalDiscoveryNodes = typeof localDiscoveryNodes.$inferInsert;
