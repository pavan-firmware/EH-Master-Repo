"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.intelligenceDecisionOutcomes = exports.intelligenceRecommendations = exports.intelligenceDecisions = void 0;
/**
 * EH Home Schema — home-intelligence
 * Source: PostgreSQL Migrations 001–029
 */
const pg_core_1 = require("drizzle-orm/pg-core");
// --- intelligence_decisions (017_smart_home_intelligence.sql) ---
exports.intelligenceDecisions = (0, pg_core_1.pgTable)('intelligence_decisions', {
    id: (0, pg_core_1.varchar)('id', { length: 64 }).primaryKey(),
    homeId: (0, pg_core_1.varchar)('home_id', { length: 64 }).notNull(),
    decisionType: (0, pg_core_1.varchar)('decision_type', { length: 64 }).notNull(),
    priority: (0, pg_core_1.varchar)('priority', { length: 32 }).notNull(),
    priorityRank: (0, pg_core_1.integer)('priority_rank').notNull().default(7),
    confidence: (0, pg_core_1.varchar)('confidence', { length: 16 }).notNull().default('MEDIUM'),
    confidenceScore: (0, pg_core_1.numeric)('confidence_score', { precision: 5, scale: 4 }).default('0.5000'),
    risk: (0, pg_core_1.varchar)('risk', { length: 16 }).notNull().default('LOW'),
    evidence: (0, pg_core_1.jsonb)('evidence').default({}),
    proposedAction: (0, pg_core_1.jsonb)('proposed_action').default({}),
    expectedEffect: (0, pg_core_1.text)('expected_effect'),
    isAutoExecutable: (0, pg_core_1.boolean)('is_auto_executable').default(false),
    safetyResult: (0, pg_core_1.jsonb)('safety_result').default({}),
    status: (0, pg_core_1.varchar)('status', { length: 32 }).notNull().default('GENERATED'),
    createdAt: (0, pg_core_1.timestamp)('created_at', { withTimezone: true }).notNull().defaultNow(),
    expiresAt: (0, pg_core_1.timestamp)('expires_at', { withTimezone: true }),
});
// --- intelligence_recommendations (017_smart_home_intelligence.sql) ---
exports.intelligenceRecommendations = (0, pg_core_1.pgTable)('intelligence_recommendations', {
    id: (0, pg_core_1.varchar)('id', { length: 64 }).primaryKey(),
    homeId: (0, pg_core_1.varchar)('home_id', { length: 64 }).notNull(),
    recommendationType: (0, pg_core_1.varchar)('recommendation_type', { length: 64 }).notNull(),
    priority: (0, pg_core_1.varchar)('priority', { length: 32 }).notNull(),
    priorityRank: (0, pg_core_1.integer)('priority_rank').notNull().default(7),
    confidence: (0, pg_core_1.varchar)('confidence', { length: 16 }).notNull().default('MEDIUM'),
    risk: (0, pg_core_1.varchar)('risk', { length: 16 }).notNull().default('LOW'),
    title: (0, pg_core_1.varchar)('title', { length: 255 }).notNull(),
    description: (0, pg_core_1.text)('description'),
    evidence: (0, pg_core_1.jsonb)('evidence').default({}),
    proposedAction: (0, pg_core_1.jsonb)('proposed_action').default({}),
    expectedBenefit: (0, pg_core_1.text)('expected_benefit'),
    isAutoExecutable: (0, pg_core_1.boolean)('is_auto_executable').default(false),
    status: (0, pg_core_1.varchar)('status', { length: 32 }).notNull().default('GENERATED'),
    createdAt: (0, pg_core_1.timestamp)('created_at', { withTimezone: true }).notNull().defaultNow(),
    expiresAt: (0, pg_core_1.timestamp)('expires_at', { withTimezone: true }),
});
// --- intelligence_decision_outcomes (017_smart_home_intelligence.sql) ---
exports.intelligenceDecisionOutcomes = (0, pg_core_1.pgTable)('intelligence_decision_outcomes', {
    id: (0, pg_core_1.varchar)('id', { length: 64 }).primaryKey(),
    decisionId: (0, pg_core_1.varchar)('decision_id', { length: 64 }).notNull(),
    homeId: (0, pg_core_1.varchar)('home_id', { length: 64 }).notNull(),
    status: (0, pg_core_1.varchar)('status', { length: 32 }).notNull(),
    executedAt: (0, pg_core_1.timestamp)('executed_at', { withTimezone: true }).notNull().defaultNow(),
    previousState: (0, pg_core_1.jsonb)('previous_state').default({}),
    newState: (0, pg_core_1.jsonb)('new_state').default({}),
    expectedBenefit: (0, pg_core_1.text)('expected_benefit'),
    actualBenefit: (0, pg_core_1.text)('actual_benefit'),
    feedback: (0, pg_core_1.text)('feedback'),
    failureReason: (0, pg_core_1.text)('failure_reason'),
    createdAt: (0, pg_core_1.timestamp)('created_at', { withTimezone: true }).notNull().defaultNow(),
});
//# sourceMappingURL=home-intelligence.js.map