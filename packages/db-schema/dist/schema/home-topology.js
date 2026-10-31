"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.rooms = exports.floors = exports.homes = void 0;
/**
 * EH Home Schema — home-topology
 * Source: PostgreSQL Migrations 001–029
 */
const pg_core_1 = require("drizzle-orm/pg-core");
// --- homes (001_initial_schema.sql) ---
exports.homes = (0, pg_core_1.pgTable)('homes', {
    id: (0, pg_core_1.varchar)('id', { length: 128 }).primaryKey(),
    name: (0, pg_core_1.varchar)('name', { length: 128 }).notNull(),
    timezone: (0, pg_core_1.varchar)('timezone', { length: 64 }).notNull().default('UTC'),
    address: (0, pg_core_1.text)('address'),
    ownerId: (0, pg_core_1.varchar)('owner_id', { length: 128 }).notNull(),
    createdAt: (0, pg_core_1.timestamp)('created_at', { withTimezone: true }).notNull().defaultNow(),
    updatedAt: (0, pg_core_1.timestamp)('updated_at', { withTimezone: true }).notNull().defaultNow(),
});
// --- floors (001_initial_schema.sql) ---
exports.floors = (0, pg_core_1.pgTable)('floors', {
    id: (0, pg_core_1.varchar)('id', { length: 128 }).primaryKey(),
    homeId: (0, pg_core_1.varchar)('home_id', { length: 128 }).notNull(),
    name: (0, pg_core_1.varchar)('name', { length: 64 }).notNull(),
    level: (0, pg_core_1.integer)('level').notNull().default(0),
    createdAt: (0, pg_core_1.timestamp)('created_at', { withTimezone: true }).notNull().defaultNow(),
});
// --- rooms (001_initial_schema.sql) ---
exports.rooms = (0, pg_core_1.pgTable)('rooms', {
    id: (0, pg_core_1.varchar)('id', { length: 128 }).primaryKey(),
    homeId: (0, pg_core_1.varchar)('home_id', { length: 128 }).notNull(),
    floorId: (0, pg_core_1.varchar)('floor_id', { length: 128 }),
    name: (0, pg_core_1.varchar)('name', { length: 64 }).notNull(),
    iconKey: (0, pg_core_1.varchar)('icon_key', { length: 64 }).notNull().default('default'),
    sortOrder: (0, pg_core_1.integer)('sort_order').notNull().default(0),
    createdAt: (0, pg_core_1.timestamp)('created_at', { withTimezone: true }).notNull().defaultNow(),
    updatedAt: (0, pg_core_1.timestamp)('updated_at', { withTimezone: true }).notNull().defaultNow(),
});
//# sourceMappingURL=home-topology.js.map