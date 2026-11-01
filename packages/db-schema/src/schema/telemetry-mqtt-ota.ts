/**
 * EH Home Schema — telemetry-mqtt-ota
 * Source: PostgreSQL Migration 034_telemetry_mqtt_ota.sql
 */
import { integer, jsonb, pgTable, smallint, text, timestamp, varchar } from 'drizzle-orm/pg-core';
import { devices } from './device-identity-state';

// --- mqtt_acl_rules (034_telemetry_mqtt_ota.sql) ---
export const mqttAclRules = pgTable('mqtt_acl_rules', {
  id: varchar('id', { length: 128 }).primaryKey(),
  clientId: varchar('client_id', { length: 128 }).notNull(),
  username: varchar('username', { length: 128 }),
  permission: varchar('permission', { length: 16 }).notNull().default('allow'),
  action: varchar('action', { length: 16 }).notNull().default('all'),
  topic: varchar('topic', { length: 255 }).notNull(),
  qos: smallint('qos').default(1),
  retain: smallint('retain').default(0),
  createdAt: timestamp('created_at', { withTimezone: true }).notNull().defaultNow(),
  updatedAt: timestamp('updated_at', { withTimezone: true }).notNull().defaultNow(),
});

export type MqttAclRules = typeof mqttAclRules.$inferSelect;
export type NewMqttAclRules = typeof mqttAclRules.$inferInsert;

// --- device_availability_history (034_telemetry_mqtt_ota.sql) ---
export const deviceAvailabilityHistory = pgTable('device_availability_history', {
  id: varchar('id', { length: 128 }).primaryKey(),
  deviceId: varchar('device_id', { length: 128 }).notNull().references(() => devices.id, { onDelete: 'restrict' }),
  status: varchar('status', { length: 32 }).notNull(),
  source: varchar('source', { length: 32 }).notNull().default('MQTT_LWT'),
  recordedAt: timestamp('recorded_at', { withTimezone: true }).notNull().defaultNow(),
  metadata: jsonb('metadata').default({}),
});

export type DeviceAvailabilityHistory = typeof deviceAvailabilityHistory.$inferSelect;
export type NewDeviceAvailabilityHistory = typeof deviceAvailabilityHistory.$inferInsert;

// --- ota_execution_jobs (034_telemetry_mqtt_ota.sql) ---
export const otaExecutionJobs = pgTable('ota_execution_jobs', {
  id: varchar('id', { length: 128 }).primaryKey(),
  deviceId: varchar('device_id', { length: 128 }).notNull().references(() => devices.id, { onDelete: 'restrict' }),
  releaseId: varchar('release_id', { length: 128 }).notNull(),
  rolloutId: varchar('rollout_id', { length: 128 }),
  firmwareFamily: varchar('firmware_family', { length: 64 }).notNull(),
  targetVersion: varchar('target_version', { length: 32 }).notNull(),
  fromVersion: varchar('from_version', { length: 32 }).notNull(),
  status: varchar('status', { length: 32 }).notNull().default('REQUESTED'),
  progressPercent: integer('progress_percent').default(0),
  errorCode: varchar('error_code', { length: 64 }),
  errorMessage: text('error_message'),
  sha256: varchar('sha256', { length: 64 }).notNull(),
  ed25519Signature: varchar('ed25519_signature', { length: 128 }).notNull(),
  createdAt: timestamp('created_at', { withTimezone: true }).notNull().defaultNow(),
  updatedAt: timestamp('updated_at', { withTimezone: true }).notNull().defaultNow(),
  completedAt: timestamp('completed_at', { withTimezone: true }),
});

export type OtaExecutionJobs = typeof otaExecutionJobs.$inferSelect;
export type NewOtaExecutionJobs = typeof otaExecutionJobs.$inferInsert;
