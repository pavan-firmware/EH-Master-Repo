"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.otaAttempts = exports.fleetDeviceFirmwareState = exports.deviceMaintenanceLogs = exports.otaOperations = exports.otaRollouts = exports.firmwareReleases = void 0;
/**
 * EH Home Schema — fleet-ota
 * Source: PostgreSQL Migrations 001–029
 */
const pg_core_1 = require("drizzle-orm/pg-core");
// --- firmware_releases (011_device_fleet_ota.sql) ---
exports.firmwareReleases = (0, pg_core_1.pgTable)('firmware_releases', {
    id: (0, pg_core_1.text)('id').primaryKey(),
    productVariantId: (0, pg_core_1.text)('product_variant_id').notNull(),
    hardwareRevision: (0, pg_core_1.text)('hardware_revision'),
    firmwareFamily: (0, pg_core_1.text)('firmware_family').notNull(),
    version: (0, pg_core_1.text)('version').notNull(),
    minFirmwareVersion: (0, pg_core_1.text)('min_firmware_version'),
    releaseChannel: (0, pg_core_1.text)('release_channel').notNull().default('production'),
    binarySizeBytes: (0, pg_core_1.integer)('binary_size_bytes').notNull(),
    sha256: (0, pg_core_1.text)('sha256').notNull(),
    ed25519Signature: (0, pg_core_1.text)('ed25519_signature').notNull(),
    downloadUrl: (0, pg_core_1.text)('download_url').notNull(),
    releaseNotes: (0, pg_core_1.text)('release_notes'),
    status: (0, pg_core_1.text)('status').notNull().default('PUBLISHED'),
    createdAt: (0, pg_core_1.text)('created_at').notNull(),
    releasedAt: (0, pg_core_1.text)('released_at'),
});
// --- ota_rollouts (011_device_fleet_ota.sql) ---
exports.otaRollouts = (0, pg_core_1.pgTable)('ota_rollouts', {
    id: (0, pg_core_1.text)('id').primaryKey(),
    releaseId: (0, pg_core_1.text)('release_id').notNull(),
    homeId: (0, pg_core_1.text)('home_id'),
    rolloutStage: (0, pg_core_1.text)('rollout_stage').notNull().default('CANARY'),
    status: (0, pg_core_1.text)('status').notNull().default('ACTIVE'),
    targetFiltersJson: (0, pg_core_1.text)('target_filters_json'),
    createdAt: (0, pg_core_1.text)('created_at').notNull(),
    updatedAt: (0, pg_core_1.text)('updated_at').notNull(),
});
// --- ota_operations (011_device_fleet_ota.sql) ---
exports.otaOperations = (0, pg_core_1.pgTable)('ota_operations', {
    id: (0, pg_core_1.text)('id').primaryKey(),
    deviceId: (0, pg_core_1.text)('device_id').notNull(),
    homeId: (0, pg_core_1.text)('home_id').notNull(),
    releaseId: (0, pg_core_1.text)('release_id').notNull(),
    rolloutId: (0, pg_core_1.text)('rollout_id'),
    fromVersion: (0, pg_core_1.text)('from_version').notNull(),
    targetVersion: (0, pg_core_1.text)('target_version').notNull(),
    status: (0, pg_core_1.text)('status').notNull().default('QUEUED'),
    progressPercent: (0, pg_core_1.integer)('progress_percent').default(0),
    errorCode: (0, pg_core_1.text)('error_code'),
    errorMessage: (0, pg_core_1.text)('error_message'),
    initiatedByUserId: (0, pg_core_1.text)('initiated_by_user_id'),
    startedAt: (0, pg_core_1.text)('started_at').notNull(),
    completedAt: (0, pg_core_1.text)('completed_at'),
    updatedAt: (0, pg_core_1.text)('updated_at').notNull(),
});
// --- device_maintenance_logs (011_device_fleet_ota.sql) ---
exports.deviceMaintenanceLogs = (0, pg_core_1.pgTable)('device_maintenance_logs', {
    id: (0, pg_core_1.text)('id').primaryKey(),
    deviceId: (0, pg_core_1.text)('device_id').notNull(),
    homeId: (0, pg_core_1.text)('home_id').notNull(),
    operationType: (0, pg_core_1.text)('operation_type').notNull(),
    releaseId: (0, pg_core_1.text)('release_id'),
    fromVersion: (0, pg_core_1.text)('from_version'),
    toVersion: (0, pg_core_1.text)('to_version'),
    status: (0, pg_core_1.text)('status').notNull(),
    detailsJson: (0, pg_core_1.text)('details_json'),
    createdAt: (0, pg_core_1.text)('created_at').notNull(),
});
// --- fleet_device_firmware_state (028_fleet_management_and_ota_rollout.sql) ---
exports.fleetDeviceFirmwareState = (0, pg_core_1.pgTable)('fleet_device_firmware_state', {
    deviceId: (0, pg_core_1.text)('device_id').primaryKey(),
    productVariantId: (0, pg_core_1.text)('product_variant_id').notNull(),
    currentFirmwareVersion: (0, pg_core_1.text)('current_firmware_version').notNull(),
    targetFirmwareVersion: (0, pg_core_1.text)('target_firmware_version'),
    rolloutId: (0, pg_core_1.text)('rollout_id'),
    rolloutState: (0, pg_core_1.text)('rollout_state'),
    lastOtaResult: (0, pg_core_1.text)('last_ota_result'),
    lastAttemptAt: (0, pg_core_1.text)('last_attempt_at'),
    failureReason: (0, pg_core_1.text)('failure_reason'),
    healthVerificationState: (0, pg_core_1.text)('health_verification_state').notNull().default('PENDING'),
    updatedAt: (0, pg_core_1.text)('updated_at').notNull(),
});
// --- ota_attempts (028_fleet_management_and_ota_rollout.sql) ---
exports.otaAttempts = (0, pg_core_1.pgTable)('ota_attempts', {
    id: (0, pg_core_1.text)('id').primaryKey(),
    deviceId: (0, pg_core_1.text)('device_id').notNull(),
    rolloutId: (0, pg_core_1.text)('rollout_id').notNull(),
    requestedVersion: (0, pg_core_1.text)('requested_version').notNull(),
    outcome: (0, pg_core_1.text)('outcome').notNull(),
    reason: (0, pg_core_1.text)('reason'),
    startedAt: (0, pg_core_1.text)('started_at').notNull(),
    completedAt: (0, pg_core_1.text)('completed_at'),
    auditMetadataJson: (0, pg_core_1.text)('audit_metadata_json'),
    createdAt: (0, pg_core_1.text)('created_at').notNull(),
});
//# sourceMappingURL=fleet-ota.js.map