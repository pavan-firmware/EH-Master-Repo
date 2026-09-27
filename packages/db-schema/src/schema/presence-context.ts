/**
 * EH Home Schema — presence-context
 * Source: PostgreSQL Migrations 001–029
 */
import { integer, pgTable, real, text, timestamp, varchar } from 'drizzle-orm/pg-core';

// --- presence_signals (016_presence_context_intelligence.sql) ---
export const presenceSignals = pgTable('presence_signals', {
  id: varchar('id', { length: 64 }).primaryKey(),
  userId: varchar('user_id', { length: 64 }).notNull(),
  homeId: varchar('home_id', { length: 64 }).notNull(),
  source: varchar('source', { length: 32 }).notNull(),
  state: varchar('state', { length: 16 }).notNull(),
  confidence: real('confidence').notNull(),
  evidenceJson: text('evidence_json'),
  observedAt: timestamp('observed_at').notNull(),
  expiresAt: timestamp('expires_at'),
  createdAt: timestamp('created_at').notNull(),
});

export type PresenceSignals = typeof presenceSignals.$inferSelect;
export type NewPresenceSignals = typeof presenceSignals.$inferInsert;

// --- presence_states (016_presence_context_intelligence.sql) ---
export const presenceStates = pgTable('presence_states', {
  id: varchar('id', { length: 128 }).primaryKey(),
  homeId: varchar('home_id', { length: 64 }).notNull(),
  userId: varchar('user_id', { length: 64 }).notNull(),
  state: varchar('state', { length: 16 }).notNull(),
  confidence: real('confidence').notNull(),
  source: varchar('source', { length: 32 }).notNull(),
  isStale: integer('is_stale').default(0),
  lastObservedAt: timestamp('last_observed_at').notNull(),
  expiresAt: timestamp('expires_at'),
  updatedAt: timestamp('updated_at').notNull(),
});

export type PresenceStates = typeof presenceStates.$inferSelect;
export type NewPresenceStates = typeof presenceStates.$inferInsert;

// --- home_contexts (016_presence_context_intelligence.sql) ---
export const homeContexts = pgTable('home_contexts', {
  homeId: varchar('home_id', { length: 64 }).primaryKey(),
  mode: varchar('mode', { length: 32 }).notNull(),
  previousMode: varchar('previous_mode', { length: 32 }),
  precedenceTier: varchar('precedence_tier', { length: 32 }).notNull(),
  activeOverrideId: varchar('active_override_id', { length: 64 }),
  isVacation: integer('is_vacation').default(0),
  isOccupied: integer('is_occupied').default(1),
  confidence: real('confidence').notNull(),
  updatedAt: timestamp('updated_at').notNull(),
});

export type HomeContexts = typeof homeContexts.$inferSelect;
export type NewHomeContexts = typeof homeContexts.$inferInsert;

// --- context_overrides (016_presence_context_intelligence.sql) ---
export const contextOverrides = pgTable('context_overrides', {
  id: varchar('id', { length: 64 }).primaryKey(),
  homeId: varchar('home_id', { length: 64 }).notNull(),
  userId: varchar('user_id', { length: 64 }).notNull(),
  mode: varchar('mode', { length: 32 }).notNull(),
  state: varchar('state', { length: 16 }),
  reason: text('reason'),
  isActive: integer('is_active').default(1),
  createdAt: timestamp('created_at').notNull(),
  expiresAt: timestamp('expires_at'),
});

export type ContextOverrides = typeof contextOverrides.$inferSelect;
export type NewContextOverrides = typeof contextOverrides.$inferInsert;

// --- context_transitions (016_presence_context_intelligence.sql) ---
export const contextTransitions = pgTable('context_transitions', {
  id: varchar('id', { length: 64 }).primaryKey(),
  homeId: varchar('home_id', { length: 64 }).notNull(),
  fromMode: varchar('from_mode', { length: 32 }).notNull(),
  toMode: varchar('to_mode', { length: 32 }).notNull(),
  triggerSource: varchar('trigger_source', { length: 64 }).notNull(),
  reason: text('reason'),
  evidenceJson: text('evidence_json'),
  createdAt: timestamp('created_at').notNull(),
});

export type ContextTransitions = typeof contextTransitions.$inferSelect;
export type NewContextTransitions = typeof contextTransitions.$inferInsert;
