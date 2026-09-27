/**
 * EH Home Schema — automations-scenes
 * Source: PostgreSQL Migrations 001–029
 */
import { boolean, integer, jsonb, pgTable, text, timestamp, varchar } from 'drizzle-orm/pg-core';

// --- scenes (006_automations_scenes_schedules.sql) ---
export const scenes = pgTable('scenes', {
  id: varchar('id', { length: 64 }).primaryKey(),
  homeId: varchar('home_id', { length: 64 }).notNull(),
  name: varchar('name', { length: 128 }).notNull(),
  description: text('description'),
  icon: varchar('icon', { length: 64 }).default('scene_default'),
  isActive: boolean('is_active').default(false),
  actions: jsonb('actions').notNull().default([]),
  createdAt: timestamp('created_at', { withTimezone: true }).defaultNow(),
  updatedAt: timestamp('updated_at', { withTimezone: true }).defaultNow(),
});

export type Scenes = typeof scenes.$inferSelect;
export type NewScenes = typeof scenes.$inferInsert;

// --- automations (006_automations_scenes_schedules.sql) ---
export const automations = pgTable('automations', {
  id: varchar('id', { length: 64 }).primaryKey(),
  homeId: varchar('home_id', { length: 64 }).notNull(),
  name: varchar('name', { length: 128 }).notNull(),
  description: text('description'),
  isEnabled: boolean('is_enabled').default(true),
  triggerType: varchar('trigger_type', { length: 32 }).notNull(),
  triggerConfig: jsonb('trigger_config').notNull().default({}),
  conditions: jsonb('conditions').notNull().default([]),
  actions: jsonb('actions').notNull().default([]),
  timezone: varchar('timezone', { length: 64 }).default('UTC'),
  createdAt: timestamp('created_at', { withTimezone: true }).defaultNow(),
  updatedAt: timestamp('updated_at', { withTimezone: true }).defaultNow(),
});

export type Automations = typeof automations.$inferSelect;
export type NewAutomations = typeof automations.$inferInsert;

// --- schedules (006_automations_scenes_schedules.sql) ---
export const schedules = pgTable('schedules', {
  id: varchar('id', { length: 64 }).primaryKey(),
  homeId: varchar('home_id', { length: 64 }).notNull(),
  automationId: varchar('automation_id', { length: 64 }),
  sceneId: varchar('scene_id', { length: 64 }),
  name: varchar('name', { length: 128 }).notNull(),
  scheduleType: varchar('schedule_type', { length: 32 }).notNull(),
  cronExpression: varchar('cron_expression', { length: 64 }),
  timeOfDay: varchar('time_of_day', { length: 8 }),
  daysOfWeek: jsonb('days_of_week').default([]),
  timezone: varchar('timezone', { length: 64 }).default('UTC'),
  isEnabled: boolean('is_enabled').default(true),
  nextRunAt: timestamp('next_run_at', { withTimezone: true }),
  lastRunAt: timestamp('last_run_at', { withTimezone: true }),
  createdAt: timestamp('created_at', { withTimezone: true }).defaultNow(),
  updatedAt: timestamp('updated_at', { withTimezone: true }).defaultNow(),
});

export type Schedules = typeof schedules.$inferSelect;
export type NewSchedules = typeof schedules.$inferInsert;

// --- automation_execution_logs (006_automations_scenes_schedules.sql) ---
export const automationExecutionLogs = pgTable('automation_execution_logs', {
  id: varchar('id', { length: 64 }).primaryKey(),
  homeId: varchar('home_id', { length: 64 }).notNull(),
  automationId: varchar('automation_id', { length: 64 }),
  sceneId: varchar('scene_id', { length: 64 }),
  scheduleId: varchar('schedule_id', { length: 64 }),
  triggerSource: varchar('trigger_source', { length: 64 }).notNull(),
  status: varchar('status', { length: 32 }).notNull(),
  executionIdentity: varchar('execution_identity', { length: 128 }).notNull(),
  targetResults: jsonb('target_results').notNull().default([]),
  errorMessage: text('error_message'),
  durationMs: integer('duration_ms').default(0),
  executedAt: timestamp('executed_at', { withTimezone: true }).defaultNow(),
});

export type AutomationExecutionLogs = typeof automationExecutionLogs.$inferSelect;
export type NewAutomationExecutionLogs = typeof automationExecutionLogs.$inferInsert;
