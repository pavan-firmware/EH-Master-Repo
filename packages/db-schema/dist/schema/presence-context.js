"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.contextTransitions = exports.contextOverrides = exports.homeContexts = exports.presenceStates = exports.presenceSignals = void 0;
/**
 * EH Home Schema — presence-context
 * Source: PostgreSQL Migrations 001–029
 */
const pg_core_1 = require("drizzle-orm/pg-core");
// --- presence_signals (016_presence_context_intelligence.sql) ---
exports.presenceSignals = (0, pg_core_1.pgTable)('presence_signals', {
    id: (0, pg_core_1.varchar)('id', { length: 64 }).primaryKey(),
    userId: (0, pg_core_1.varchar)('user_id', { length: 64 }).notNull(),
    homeId: (0, pg_core_1.varchar)('home_id', { length: 64 }).notNull(),
    source: (0, pg_core_1.varchar)('source', { length: 32 }).notNull(),
    state: (0, pg_core_1.varchar)('state', { length: 16 }).notNull(),
    confidence: (0, pg_core_1.real)('confidence').notNull(),
    evidenceJson: (0, pg_core_1.text)('evidence_json'),
    observedAt: (0, pg_core_1.timestamp)('observed_at').notNull(),
    expiresAt: (0, pg_core_1.timestamp)('expires_at'),
    createdAt: (0, pg_core_1.timestamp)('created_at').notNull(),
});
// --- presence_states (016_presence_context_intelligence.sql) ---
exports.presenceStates = (0, pg_core_1.pgTable)('presence_states', {
    id: (0, pg_core_1.varchar)('id', { length: 128 }).primaryKey(),
    homeId: (0, pg_core_1.varchar)('home_id', { length: 64 }).notNull(),
    userId: (0, pg_core_1.varchar)('user_id', { length: 64 }).notNull(),
    state: (0, pg_core_1.varchar)('state', { length: 16 }).notNull(),
    confidence: (0, pg_core_1.real)('confidence').notNull(),
    source: (0, pg_core_1.varchar)('source', { length: 32 }).notNull(),
    isStale: (0, pg_core_1.integer)('is_stale').default(0),
    lastObservedAt: (0, pg_core_1.timestamp)('last_observed_at').notNull(),
    expiresAt: (0, pg_core_1.timestamp)('expires_at'),
    updatedAt: (0, pg_core_1.timestamp)('updated_at').notNull(),
});
// --- home_contexts (016_presence_context_intelligence.sql) ---
exports.homeContexts = (0, pg_core_1.pgTable)('home_contexts', {
    homeId: (0, pg_core_1.varchar)('home_id', { length: 64 }).primaryKey(),
    mode: (0, pg_core_1.varchar)('mode', { length: 32 }).notNull(),
    previousMode: (0, pg_core_1.varchar)('previous_mode', { length: 32 }),
    precedenceTier: (0, pg_core_1.varchar)('precedence_tier', { length: 32 }).notNull(),
    activeOverrideId: (0, pg_core_1.varchar)('active_override_id', { length: 64 }),
    isVacation: (0, pg_core_1.integer)('is_vacation').default(0),
    isOccupied: (0, pg_core_1.integer)('is_occupied').default(1),
    confidence: (0, pg_core_1.real)('confidence').notNull(),
    updatedAt: (0, pg_core_1.timestamp)('updated_at').notNull(),
});
// --- context_overrides (016_presence_context_intelligence.sql) ---
exports.contextOverrides = (0, pg_core_1.pgTable)('context_overrides', {
    id: (0, pg_core_1.varchar)('id', { length: 64 }).primaryKey(),
    homeId: (0, pg_core_1.varchar)('home_id', { length: 64 }).notNull(),
    userId: (0, pg_core_1.varchar)('user_id', { length: 64 }).notNull(),
    mode: (0, pg_core_1.varchar)('mode', { length: 32 }).notNull(),
    state: (0, pg_core_1.varchar)('state', { length: 16 }),
    reason: (0, pg_core_1.text)('reason'),
    isActive: (0, pg_core_1.integer)('is_active').default(1),
    createdAt: (0, pg_core_1.timestamp)('created_at').notNull(),
    expiresAt: (0, pg_core_1.timestamp)('expires_at'),
});
// --- context_transitions (016_presence_context_intelligence.sql) ---
exports.contextTransitions = (0, pg_core_1.pgTable)('context_transitions', {
    id: (0, pg_core_1.varchar)('id', { length: 64 }).primaryKey(),
    homeId: (0, pg_core_1.varchar)('home_id', { length: 64 }).notNull(),
    fromMode: (0, pg_core_1.varchar)('from_mode', { length: 32 }).notNull(),
    toMode: (0, pg_core_1.varchar)('to_mode', { length: 32 }).notNull(),
    triggerSource: (0, pg_core_1.varchar)('trigger_source', { length: 64 }).notNull(),
    reason: (0, pg_core_1.text)('reason'),
    evidenceJson: (0, pg_core_1.text)('evidence_json'),
    createdAt: (0, pg_core_1.timestamp)('created_at').notNull(),
});
//# sourceMappingURL=presence-context.js.map