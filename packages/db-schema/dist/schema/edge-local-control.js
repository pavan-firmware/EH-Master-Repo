"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.localDiscoveryNodes = exports.edgeExecutionRecords = exports.localRouteCache = void 0;
/**
 * EH Home Schema — edge-local-control
 * Source: PostgreSQL Migrations 001–029
 */
const pg_core_1 = require("drizzle-orm/pg-core");
// --- local_route_cache (021_local_first_edge_control.sql) ---
exports.localRouteCache = (0, pg_core_1.pgTable)('local_route_cache', {
    id: (0, pg_core_1.varchar)('id', { length: 64 }).primaryKey(),
    deviceId: (0, pg_core_1.varchar)('device_id', { length: 64 }).notNull(),
    homeId: (0, pg_core_1.varchar)('home_id', { length: 64 }).notNull(),
    transportType: (0, pg_core_1.varchar)('transport_type', { length: 32 }).notNull(),
    localEndpoint: (0, pg_core_1.varchar)('local_endpoint', { length: 255 }).notNull(),
    localIp: (0, pg_core_1.varchar)('local_ip', { length: 64 }),
    localPort: (0, pg_core_1.integer)('local_port'),
    reachability: (0, pg_core_1.varchar)('reachability', { length: 32 }).notNull().default('REACHABLE'),
    identityFingerprint: (0, pg_core_1.varchar)('identity_fingerprint', { length: 128 }),
    isTlsSecured: (0, pg_core_1.boolean)('is_tls_secured').default(true),
    latencyMs: (0, pg_core_1.real)('latency_ms').default(0.0),
    expiresAt: (0, pg_core_1.timestamp)('expires_at').notNull(),
    lastContactAt: (0, pg_core_1.timestamp)('last_contact_at').notNull(),
    createdAt: (0, pg_core_1.timestamp)('created_at').defaultNow(),
    updatedAt: (0, pg_core_1.timestamp)('updated_at').defaultNow(),
});
// --- edge_execution_records (021_local_first_edge_control.sql) ---
exports.edgeExecutionRecords = (0, pg_core_1.pgTable)('edge_execution_records', {
    id: (0, pg_core_1.varchar)('id', { length: 64 }).primaryKey(),
    commandId: (0, pg_core_1.varchar)('command_id', { length: 64 }).notNull(),
    deviceId: (0, pg_core_1.varchar)('device_id', { length: 64 }).notNull(),
    homeId: (0, pg_core_1.varchar)('home_id', { length: 64 }).notNull(),
    channelIndex: (0, pg_core_1.integer)('channel_index'),
    action: (0, pg_core_1.varchar)('action', { length: 64 }).notNull(),
    routeMode: (0, pg_core_1.varchar)('route_mode', { length: 32 }).notNull(),
    transportUsed: (0, pg_core_1.varchar)('transport_used', { length: 32 }).notNull(),
    status: (0, pg_core_1.varchar)('status', { length: 32 }).notNull(),
    isConfirmedByDevice: (0, pg_core_1.boolean)('is_confirmed_by_device').notNull().default(false),
    confirmedState: (0, pg_core_1.text)('confirmed_state'),
    latencyMs: (0, pg_core_1.real)('latency_ms').default(0.0),
    errorMessage: (0, pg_core_1.text)('error_message'),
    idempotencyKey: (0, pg_core_1.varchar)('idempotency_key', { length: 128 }),
    actorUserId: (0, pg_core_1.varchar)('actor_user_id', { length: 64 }),
    actorSource: (0, pg_core_1.varchar)('actor_source', { length: 32 }),
    queuedForCloudSync: (0, pg_core_1.boolean)('queued_for_cloud_sync').default(false),
    executedAt: (0, pg_core_1.timestamp)('executed_at').notNull(),
    createdAt: (0, pg_core_1.timestamp)('created_at').defaultNow(),
});
// --- local_discovery_nodes (021_local_first_edge_control.sql) ---
exports.localDiscoveryNodes = (0, pg_core_1.pgTable)('local_discovery_nodes', {
    id: (0, pg_core_1.varchar)('id', { length: 64 }).primaryKey(),
    discoveryId: (0, pg_core_1.varchar)('discovery_id', { length: 64 }).notNull().unique(),
    deviceId: (0, pg_core_1.varchar)('device_id', { length: 64 }).notNull(),
    homeId: (0, pg_core_1.varchar)('home_id', { length: 64 }).notNull(),
    productVariantId: (0, pg_core_1.varchar)('product_variant_id', { length: 64 }),
    macAddress: (0, pg_core_1.varchar)('mac_address', { length: 64 }).notNull(),
    ipAddress: (0, pg_core_1.varchar)('ip_address', { length: 64 }).notNull(),
    port: (0, pg_core_1.integer)('port').notNull(),
    transportType: (0, pg_core_1.varchar)('transport_type', { length: 32 }).notNull(),
    protocolVersion: (0, pg_core_1.varchar)('protocol_version', { length: 32 }),
    firmwareVersion: (0, pg_core_1.varchar)('firmware_version', { length: 32 }),
    identityFingerprint: (0, pg_core_1.varchar)('identity_fingerprint', { length: 128 }).notNull(),
    isTrusted: (0, pg_core_1.boolean)('is_trusted').notNull().default(true),
    ttlSeconds: (0, pg_core_1.integer)('ttl_seconds').default(300),
    discoveredAt: (0, pg_core_1.timestamp)('discovered_at').notNull(),
    createdAt: (0, pg_core_1.timestamp)('created_at').defaultNow(),
    updatedAt: (0, pg_core_1.timestamp)('updated_at').defaultNow(),
});
//# sourceMappingURL=edge-local-control.js.map