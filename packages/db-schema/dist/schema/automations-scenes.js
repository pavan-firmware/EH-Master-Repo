"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.automationExecutionLogs = exports.schedules = exports.automations = exports.scenes = void 0;
/**
 * EH Home Schema — automations-scenes
 * Source: PostgreSQL Migrations 001–029
 */
const pg_core_1 = require("drizzle-orm/pg-core");
// --- scenes (006_automations_scenes_schedules.sql) ---
exports.scenes = (0, pg_core_1.pgTable)('scenes', {
    id: (0, pg_core_1.varchar)('id', { length: 64 }).primaryKey(),
    homeId: (0, pg_core_1.varchar)('home_id', { length: 64 }).notNull(),
    name: (0, pg_core_1.varchar)('name', { length: 128 }).notNull(),
    description: (0, pg_core_1.text)('description'),
    icon: (0, pg_core_1.varchar)('icon', { length: 64 }).default('scene_default'),
    isActive: (0, pg_core_1.boolean)('is_active').default(false),
    actions: (0, pg_core_1.jsonb)('actions').notNull().default([]),
    createdAt: (0, pg_core_1.timestamp)('created_at', { withTimezone: true }).defaultNow(),
    updatedAt: (0, pg_core_1.timestamp)('updated_at', { withTimezone: true }).defaultNow(),
});
// --- automations (006_automations_scenes_schedules.sql) ---
exports.automations = (0, pg_core_1.pgTable)('automations', {
    id: (0, pg_core_1.varchar)('id', { length: 64 }).primaryKey(),
    homeId: (0, pg_core_1.varchar)('home_id', { length: 64 }).notNull(),
    name: (0, pg_core_1.varchar)('name', { length: 128 }).notNull(),
    description: (0, pg_core_1.text)('description'),
    isEnabled: (0, pg_core_1.boolean)('is_enabled').default(true),
    triggerType: (0, pg_core_1.varchar)('trigger_type', { length: 32 }).notNull(),
    triggerConfig: (0, pg_core_1.jsonb)('trigger_config').notNull().default({}),
    conditions: (0, pg_core_1.jsonb)('conditions').notNull().default([]),
    actions: (0, pg_core_1.jsonb)('actions').notNull().default([]),
    timezone: (0, pg_core_1.varchar)('timezone', { length: 64 }).default('UTC'),
    createdAt: (0, pg_core_1.timestamp)('created_at', { withTimezone: true }).defaultNow(),
    updatedAt: (0, pg_core_1.timestamp)('updated_at', { withTimezone: true }).defaultNow(),
});
// --- schedules (006_automations_scenes_schedules.sql) ---
exports.schedules = (0, pg_core_1.pgTable)('schedules', {
    id: (0, pg_core_1.varchar)('id', { length: 64 }).primaryKey(),
    homeId: (0, pg_core_1.varchar)('home_id', { length: 64 }).notNull(),
    automationId: (0, pg_core_1.varchar)('automation_id', { length: 64 }),
    sceneId: (0, pg_core_1.varchar)('scene_id', { length: 64 }),
    name: (0, pg_core_1.varchar)('name', { length: 128 }).notNull(),
    scheduleType: (0, pg_core_1.varchar)('schedule_type', { length: 32 }).notNull(),
    cronExpression: (0, pg_core_1.varchar)('cron_expression', { length: 64 }),
    timeOfDay: (0, pg_core_1.varchar)('time_of_day', { length: 8 }),
    daysOfWeek: (0, pg_core_1.jsonb)('days_of_week').default([]),
    timezone: (0, pg_core_1.varchar)('timezone', { length: 64 }).default('UTC'),
    isEnabled: (0, pg_core_1.boolean)('is_enabled').default(true),
    nextRunAt: (0, pg_core_1.timestamp)('next_run_at', { withTimezone: true }),
    lastRunAt: (0, pg_core_1.timestamp)('last_run_at', { withTimezone: true }),
    createdAt: (0, pg_core_1.timestamp)('created_at', { withTimezone: true }).defaultNow(),
    updatedAt: (0, pg_core_1.timestamp)('updated_at', { withTimezone: true }).defaultNow(),
});
// --- automation_execution_logs (006_automations_scenes_schedules.sql) ---
exports.automationExecutionLogs = (0, pg_core_1.pgTable)('automation_execution_logs', {
    id: (0, pg_core_1.varchar)('id', { length: 64 }).primaryKey(),
    homeId: (0, pg_core_1.varchar)('home_id', { length: 64 }).notNull(),
    automationId: (0, pg_core_1.varchar)('automation_id', { length: 64 }),
    sceneId: (0, pg_core_1.varchar)('scene_id', { length: 64 }),
    scheduleId: (0, pg_core_1.varchar)('schedule_id', { length: 64 }),
    triggerSource: (0, pg_core_1.varchar)('trigger_source', { length: 64 }).notNull(),
    status: (0, pg_core_1.varchar)('status', { length: 32 }).notNull(),
    executionIdentity: (0, pg_core_1.varchar)('execution_identity', { length: 128 }).notNull(),
    targetResults: (0, pg_core_1.jsonb)('target_results').notNull().default([]),
    errorMessage: (0, pg_core_1.text)('error_message'),
    durationMs: (0, pg_core_1.integer)('duration_ms').default(0),
    executedAt: (0, pg_core_1.timestamp)('executed_at', { withTimezone: true }).defaultNow(),
});
//# sourceMappingURL=automations-scenes.js.map