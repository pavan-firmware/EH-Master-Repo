/**
 * EH Home Schema — fleet-ota
 * Source: PostgreSQL Migrations 001–029
 */
import { integer, pgTable, text } from 'drizzle-orm/pg-core';

// --- firmware_releases (011_device_fleet_ota.sql) ---
export const firmwareReleases = pgTable('firmware_releases', {
  id: text('id').primaryKey(),
  productVariantId: text('product_variant_id').notNull(),
  hardwareRevision: text('hardware_revision'),
  firmwareFamily: text('firmware_family').notNull(),
  version: text('version').notNull(),
  minFirmwareVersion: text('min_firmware_version'),
  releaseChannel: text('release_channel').notNull().default('production'),
  binarySizeBytes: integer('binary_size_bytes').notNull(),
  sha256: text('sha256').notNull(),
  ed25519Signature: text('ed25519_signature').notNull(),
  downloadUrl: text('download_url').notNull(),
  releaseNotes: text('release_notes'),
  status: text('status').notNull().default('PUBLISHED'),
  createdAt: text('created_at').notNull(),
  releasedAt: text('released_at'),
});

export type FirmwareReleases = typeof firmwareReleases.$inferSelect;
export type NewFirmwareReleases = typeof firmwareReleases.$inferInsert;

// --- ota_rollouts (011_device_fleet_ota.sql) ---
export const otaRollouts = pgTable('ota_rollouts', {
  id: text('id').primaryKey(),
  releaseId: text('release_id').notNull(),
  homeId: text('home_id'),
  rolloutStage: text('rollout_stage').notNull().default('CANARY'),
  status: text('status').notNull().default('ACTIVE'),
  targetFiltersJson: text('target_filters_json'),
  createdAt: text('created_at').notNull(),
  updatedAt: text('updated_at').notNull(),
});

export type OtaRollouts = typeof otaRollouts.$inferSelect;
export type NewOtaRollouts = typeof otaRollouts.$inferInsert;

// --- ota_operations (011_device_fleet_ota.sql) ---
export const otaOperations = pgTable('ota_operations', {
  id: text('id').primaryKey(),
  deviceId: text('device_id').notNull(),
  homeId: text('home_id').notNull(),
  releaseId: text('release_id').notNull(),
  rolloutId: text('rollout_id'),
  fromVersion: text('from_version').notNull(),
  targetVersion: text('target_version').notNull(),
  status: text('status').notNull().default('QUEUED'),
  progressPercent: integer('progress_percent').default(0),
  errorCode: text('error_code'),
  errorMessage: text('error_message'),
  initiatedByUserId: text('initiated_by_user_id'),
  startedAt: text('started_at').notNull(),
  completedAt: text('completed_at'),
  updatedAt: text('updated_at').notNull(),
});

export type OtaOperations = typeof otaOperations.$inferSelect;
export type NewOtaOperations = typeof otaOperations.$inferInsert;

// --- device_maintenance_logs (011_device_fleet_ota.sql) ---
export const deviceMaintenanceLogs = pgTable('device_maintenance_logs', {
  id: text('id').primaryKey(),
  deviceId: text('device_id').notNull(),
  homeId: text('home_id').notNull(),
  operationType: text('operation_type').notNull(),
  releaseId: text('release_id'),
  fromVersion: text('from_version'),
  toVersion: text('to_version'),
  status: text('status').notNull(),
  detailsJson: text('details_json'),
  createdAt: text('created_at').notNull(),
});

export type DeviceMaintenanceLogs = typeof deviceMaintenanceLogs.$inferSelect;
export type NewDeviceMaintenanceLogs = typeof deviceMaintenanceLogs.$inferInsert;

// --- fleet_device_firmware_state (028_fleet_management_and_ota_rollout.sql) ---
export const fleetDeviceFirmwareState = pgTable('fleet_device_firmware_state', {
  deviceId: text('device_id').primaryKey(),
  productVariantId: text('product_variant_id').notNull(),
  currentFirmwareVersion: text('current_firmware_version').notNull(),
  targetFirmwareVersion: text('target_firmware_version'),
  rolloutId: text('rollout_id'),
  rolloutState: text('rollout_state'),
  lastOtaResult: text('last_ota_result'),
  lastAttemptAt: text('last_attempt_at'),
  failureReason: text('failure_reason'),
  healthVerificationState: text('health_verification_state').notNull().default('PENDING'),
  updatedAt: text('updated_at').notNull(),
});

export type FleetDeviceFirmwareState = typeof fleetDeviceFirmwareState.$inferSelect;
export type NewFleetDeviceFirmwareState = typeof fleetDeviceFirmwareState.$inferInsert;

// --- ota_attempts (028_fleet_management_and_ota_rollout.sql) ---
export const otaAttempts = pgTable('ota_attempts', {
  id: text('id').primaryKey(),
  deviceId: text('device_id').notNull(),
  rolloutId: text('rollout_id').notNull(),
  requestedVersion: text('requested_version').notNull(),
  outcome: text('outcome').notNull(),
  reason: text('reason'),
  startedAt: text('started_at').notNull(),
  completedAt: text('completed_at'),
  auditMetadataJson: text('audit_metadata_json'),
  createdAt: text('created_at').notNull(),
});

export type OtaAttempts = typeof otaAttempts.$inferSelect;
export type NewOtaAttempts = typeof otaAttempts.$inferInsert;
