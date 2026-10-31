"use strict";
/**
 * EH Home Schema — firmware-build
 * Source: PostgreSQL Migration 031 (031_firmware_git_binary_management.sql)
 * Domain: Firmware, Git & Binary Management (Part 07)
 */
Object.defineProperty(exports, "__esModule", { value: true });
exports.firmwareHardwareCompatibility = exports.firmwareArtifacts = exports.firmwareBuilds = exports.firmwareFamilies = void 0;
const pg_core_1 = require("drizzle-orm/pg-core");
const fleet_ota_1 = require("./fleet-ota");
const hardware_bom_1 = require("./hardware-bom");
// --- firmware_families (031_firmware_git_binary_management.sql) ---
exports.firmwareFamilies = (0, pg_core_1.pgTable)('firmware_families', {
    id: (0, pg_core_1.varchar)('id', { length: 64 }).primaryKey(),
    displayName: (0, pg_core_1.varchar)('display_name', { length: 128 }).notNull(),
    targetMcu: (0, pg_core_1.varchar)('target_mcu', { length: 32 }).notNull().default('esp32-c6'),
    defaultIdfVersion: (0, pg_core_1.varchar)('default_idf_version', { length: 32 }).notNull().default('v5.4.1'),
    repositoryUrl: (0, pg_core_1.text)('repository_url'),
    description: (0, pg_core_1.text)('description'),
    createdAt: (0, pg_core_1.timestamp)('created_at', { withTimezone: true }).notNull().defaultNow(),
    updatedAt: (0, pg_core_1.timestamp)('updated_at', { withTimezone: true }).notNull().defaultNow(),
});
// --- firmware_builds (031_firmware_git_binary_management.sql) ---
exports.firmwareBuilds = (0, pg_core_1.pgTable)('firmware_builds', {
    id: (0, pg_core_1.varchar)('id', { length: 64 }).primaryKey(),
    firmwareReleaseId: (0, pg_core_1.text)('firmware_release_id')
        .references(() => fleet_ota_1.firmwareReleases.id),
    firmwareFamilyId: (0, pg_core_1.varchar)('firmware_family_id', { length: 64 })
        .notNull()
        .references(() => exports.firmwareFamilies.id),
    gitCommitSha: (0, pg_core_1.varchar)('git_commit_sha', { length: 40 }).notNull(),
    gitBranch: (0, pg_core_1.varchar)('git_branch', { length: 128 }).notNull().default('main'),
    gitTag: (0, pg_core_1.varchar)('git_tag', { length: 128 }),
    idfVersion: (0, pg_core_1.varchar)('idf_version', { length: 32 }).notNull().default('v5.4.1'),
    buildProfile: (0, pg_core_1.varchar)('build_profile', { length: 32 }).notNull().default('release'),
    toolchainInfo: (0, pg_core_1.jsonb)('toolchain_info').notNull().default({}),
    builtBy: (0, pg_core_1.varchar)('built_by', { length: 128 }),
    builtAt: (0, pg_core_1.timestamp)('built_at', { withTimezone: true }).notNull().defaultNow(),
    createdAt: (0, pg_core_1.timestamp)('created_at', { withTimezone: true }).notNull().defaultNow(),
});
// --- firmware_artifacts (031_firmware_git_binary_management.sql) ---
exports.firmwareArtifacts = (0, pg_core_1.pgTable)('firmware_artifacts', {
    id: (0, pg_core_1.varchar)('id', { length: 64 }).primaryKey(),
    buildId: (0, pg_core_1.varchar)('build_id', { length: 64 })
        .notNull()
        .references(() => exports.firmwareBuilds.id),
    artifactType: (0, pg_core_1.varchar)('artifact_type', { length: 32 }).notNull(),
    fileName: (0, pg_core_1.varchar)('file_name', { length: 255 }).notNull(),
    fileSizeBytes: (0, pg_core_1.integer)('file_size_bytes').notNull(),
    sha256: (0, pg_core_1.varchar)('sha256', { length: 64 }).notNull(),
    storagePath: (0, pg_core_1.text)('storage_path').notNull(),
    downloadUrl: (0, pg_core_1.text)('download_url'),
    signature: (0, pg_core_1.text)('signature'),
    createdAt: (0, pg_core_1.timestamp)('created_at', { withTimezone: true }).notNull().defaultNow(),
});
// --- firmware_hardware_compatibility (031_firmware_git_binary_management.sql) ---
exports.firmwareHardwareCompatibility = (0, pg_core_1.pgTable)('firmware_hardware_compatibility', {
    id: (0, pg_core_1.varchar)('id', { length: 64 }).primaryKey(),
    firmwareReleaseId: (0, pg_core_1.text)('firmware_release_id')
        .notNull()
        .references(() => fleet_ota_1.firmwareReleases.id),
    hardwareRevisionId: (0, pg_core_1.varchar)('hardware_revision_id', { length: 64 })
        .notNull()
        .references(() => hardware_bom_1.hardwareRevisions.id),
    minHardwareRevision: (0, pg_core_1.varchar)('min_hardware_revision', { length: 32 }),
    maxHardwareRevision: (0, pg_core_1.varchar)('max_hardware_revision', { length: 32 }),
    isVerified: (0, pg_core_1.boolean)('is_verified').notNull().default(true),
    verificationNotes: (0, pg_core_1.text)('verification_notes'),
    verifiedAt: (0, pg_core_1.timestamp)('verified_at', { withTimezone: true }).notNull().defaultNow(),
    createdAt: (0, pg_core_1.timestamp)('created_at', { withTimezone: true }).notNull().defaultNow(),
});
//# sourceMappingURL=firmware-build.js.map