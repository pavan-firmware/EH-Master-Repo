/**
 * EH Home Schema — home-topology
 * Source: PostgreSQL Migrations 001–029
 */
import { integer, pgTable, text, timestamp, varchar } from 'drizzle-orm/pg-core';

// --- homes (001_initial_schema.sql) ---
export const homes = pgTable('homes', {
  id: varchar('id', { length: 128 }).primaryKey(),
  name: varchar('name', { length: 128 }).notNull(),
  timezone: varchar('timezone', { length: 64 }).notNull().default('UTC'),
  address: text('address'),
  ownerId: varchar('owner_id', { length: 128 }).notNull(),
  createdAt: timestamp('created_at', { withTimezone: true }).notNull().defaultNow(),
  updatedAt: timestamp('updated_at', { withTimezone: true }).notNull().defaultNow(),
});

export type Homes = typeof homes.$inferSelect;
export type NewHomes = typeof homes.$inferInsert;

// --- floors (001_initial_schema.sql) ---
export const floors = pgTable('floors', {
  id: varchar('id', { length: 128 }).primaryKey(),
  homeId: varchar('home_id', { length: 128 }).notNull(),
  name: varchar('name', { length: 64 }).notNull(),
  level: integer('level').notNull().default(0),
  createdAt: timestamp('created_at', { withTimezone: true }).notNull().defaultNow(),
});

export type Floors = typeof floors.$inferSelect;
export type NewFloors = typeof floors.$inferInsert;

// --- rooms (001_initial_schema.sql) ---
export const rooms = pgTable('rooms', {
  id: varchar('id', { length: 128 }).primaryKey(),
  homeId: varchar('home_id', { length: 128 }).notNull(),
  floorId: varchar('floor_id', { length: 128 }),
  name: varchar('name', { length: 64 }).notNull(),
  iconKey: varchar('icon_key', { length: 64 }).notNull().default('default'),
  sortOrder: integer('sort_order').notNull().default(0),
  createdAt: timestamp('created_at', { withTimezone: true }).notNull().defaultNow(),
  updatedAt: timestamp('updated_at', { withTimezone: true }).notNull().defaultNow(),
});

export type Rooms = typeof rooms.$inferSelect;
export type NewRooms = typeof rooms.$inferInsert;
