/**
 * EH Home Schema — home-intelligence
 * Source: PostgreSQL Migrations 001–029
 */
import { boolean, integer, jsonb, numeric, pgTable, text, timestamp, varchar } from 'drizzle-orm/pg-core';

// --- intelligence_decisions (017_smart_home_intelligence.sql) ---
export const intelligenceDecisions = pgTable('intelligence_decisions', {
  id: varchar('id', { length: 64 }).primaryKey(),
  homeId: varchar('home_id', { length: 64 }).notNull(),
  decisionType: varchar('decision_type', { length: 64 }).notNull(),
  priority: varchar('priority', { length: 32 }).notNull(),
  priorityRank: integer('priority_rank').notNull().default(7),
  confidence: varchar('confidence', { length: 16 }).notNull().default('MEDIUM'),
  confidenceScore: numeric('confidence_score', { precision: 5, scale: 4 }).default('0.5000'),
  risk: varchar('risk', { length: 16 }).notNull().default('LOW'),
  evidence: jsonb('evidence').default({}),
  proposedAction: jsonb('proposed_action').default({}),
  expectedEffect: text('expected_effect'),
  isAutoExecutable: boolean('is_auto_executable').default(false),
  safetyResult: jsonb('safety_result').default({}),
  status: varchar('status', { length: 32 }).notNull().default('GENERATED'),
  createdAt: timestamp('created_at', { withTimezone: true }).notNull().defaultNow(),
  expiresAt: timestamp('expires_at', { withTimezone: true }),
});

export type IntelligenceDecisions = typeof intelligenceDecisions.$inferSelect;
export type NewIntelligenceDecisions = typeof intelligenceDecisions.$inferInsert;

// --- intelligence_recommendations (017_smart_home_intelligence.sql) ---
export const intelligenceRecommendations = pgTable('intelligence_recommendations', {
  id: varchar('id', { length: 64 }).primaryKey(),
  homeId: varchar('home_id', { length: 64 }).notNull(),
  recommendationType: varchar('recommendation_type', { length: 64 }).notNull(),
  priority: varchar('priority', { length: 32 }).notNull(),
  priorityRank: integer('priority_rank').notNull().default(7),
  confidence: varchar('confidence', { length: 16 }).notNull().default('MEDIUM'),
  risk: varchar('risk', { length: 16 }).notNull().default('LOW'),
  title: varchar('title', { length: 255 }).notNull(),
  description: text('description'),
  evidence: jsonb('evidence').default({}),
  proposedAction: jsonb('proposed_action').default({}),
  expectedBenefit: text('expected_benefit'),
  isAutoExecutable: boolean('is_auto_executable').default(false),
  status: varchar('status', { length: 32 }).notNull().default('GENERATED'),
  createdAt: timestamp('created_at', { withTimezone: true }).notNull().defaultNow(),
  expiresAt: timestamp('expires_at', { withTimezone: true }),
});

export type IntelligenceRecommendations = typeof intelligenceRecommendations.$inferSelect;
export type NewIntelligenceRecommendations = typeof intelligenceRecommendations.$inferInsert;

// --- intelligence_decision_outcomes (017_smart_home_intelligence.sql) ---
export const intelligenceDecisionOutcomes = pgTable('intelligence_decision_outcomes', {
  id: varchar('id', { length: 64 }).primaryKey(),
  decisionId: varchar('decision_id', { length: 64 }).notNull(),
  homeId: varchar('home_id', { length: 64 }).notNull(),
  status: varchar('status', { length: 32 }).notNull(),
  executedAt: timestamp('executed_at', { withTimezone: true }).notNull().defaultNow(),
  previousState: jsonb('previous_state').default({}),
  newState: jsonb('new_state').default({}),
  expectedBenefit: text('expected_benefit'),
  actualBenefit: text('actual_benefit'),
  feedback: text('feedback'),
  failureReason: text('failure_reason'),
  createdAt: timestamp('created_at', { withTimezone: true }).notNull().defaultNow(),
});

export type IntelligenceDecisionOutcomes = typeof intelligenceDecisionOutcomes.$inferSelect;
export type NewIntelligenceDecisionOutcomes = typeof intelligenceDecisionOutcomes.$inferInsert;
