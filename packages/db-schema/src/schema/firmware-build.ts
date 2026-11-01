/**
 * EH Home Schema — firmware-build
 * Source: PostgreSQL Migration 031 (031_firmware_git_binary_management.sql)
 * Domain: Firmware, Git & Binary Management (Part 07)
 */

import { boolean, integer, jsonb, pgTable, text, timestamp, varchar } from 'drizzle-orm/pg-core';
import { firmwareReleases } from './fleet-ota';
import { hardwareRevisions } from './hardware-bom';

// --- firmware_families (031_firmware_git_binary_management.sql) ---
export const firmwareFamilies = pgTable('firmware_families', {
  id: varchar('id', { length: 64 }).primaryKey(),
  displayName: varchar('display_name', { length: 128 }).notNull(),
  targetMcu: varchar('target_mcu', { length: 32 }).notNull().default('esp32-c6'),
  defaultIdfVersion: varchar('default_idf_version', { length: 32 }).notNull().default('v5.4.1'),
  repositoryUrl: text('repository_url'),
  description: text('description'),
  createdAt: timestamp('created_at', { withTimezone: true }).notNull().defaultNow(),
  updatedAt: timestamp('updated_at', { withTimezone: true }).notNull().defaultNow(),
});

export type FirmwareFamilies = typeof firmwareFamilies.$inferSelect;
export type NewFirmwareFamilies = typeof firmwareFamilies.$inferInsert;

// --- firmware_builds (031_firmware_git_binary_management.sql) ---
export const firmwareBuilds = pgTable('firmware_builds', {
  id: varchar('id', { length: 64 }).primaryKey(),
  firmwareReleaseId: text('firmware_release_id')
    .references(() => firmwareReleases.id),
  firmwareFamilyId: varchar('firmware_family_id', { length: 64 })
    .notNull()
    .references(() => firmwareFamilies.id),
  gitCommitSha: varchar('git_commit_sha', { length: 40 }).notNull(),
  gitBranch: varchar('git_branch', { length: 128 }).notNull().default('main'),
  gitTag: varchar('git_tag', { length: 128 }),
  idfVersion: varchar('idf_version', { length: 32 }).notNull().default('v5.4.1'),
  buildProfile: varchar('build_profile', { length: 32 }).notNull().default('release'),
  toolchainInfo: jsonb('toolchain_info').notNull().default({}),
  builtBy: varchar('built_by', { length: 128 }),
  builtAt: timestamp('built_at', { withTimezone: true }).notNull().defaultNow(),
  createdAt: timestamp('created_at', { withTimezone: true }).notNull().defaultNow(),
});

export type FirmwareBuilds = typeof firmwareBuilds.$inferSelect;
export type NewFirmwareBuilds = typeof firmwareBuilds.$inferInsert;

// --- firmware_artifacts (031_firmware_git_binary_management.sql) ---
export const firmwareArtifacts = pgTable('firmware_artifacts', {
  id: varchar('id', { length: 64 }).primaryKey(),
  buildId: varchar('build_id', { length: 64 })
    .notNull()
    .references(() => firmwareBuilds.id),
  artifactType: varchar('artifact_type', { length: 32 }).notNull(),
  fileName: varchar('file_name', { length: 255 }).notNull(),
  fileSizeBytes: integer('file_size_bytes').notNull(),
  sha256: varchar('sha256', { length: 64 }).notNull(),
  storagePath: text('storage_path').notNull(),
  downloadUrl: text('download_url'),
  signature: text('signature'),
  createdAt: timestamp('created_at', { withTimezone: true }).notNull().defaultNow(),
});

export type FirmwareArtifacts = typeof firmwareArtifacts.$inferSelect;
export type NewFirmwareArtifacts = typeof firmwareArtifacts.$inferInsert;

// --- firmware_hardware_compatibility (031_firmware_git_binary_management.sql) ---
export const firmwareHardwareCompatibility = pgTable('firmware_hardware_compatibility', {
  id: varchar('id', { length: 64 }).primaryKey(),
  firmwareReleaseId: text('firmware_release_id')
    .notNull()
    .references(() => firmwareReleases.id),
  hardwareRevisionId: varchar('hardware_revision_id', { length: 64 })
    .notNull()
    .references(() => hardwareRevisions.id),
  minHardwareRevision: varchar('min_hardware_revision', { length: 32 }),
  maxHardwareRevision: varchar('max_hardware_revision', { length: 32 }),
  isVerified: boolean('is_verified').notNull().default(true),
  verificationNotes: text('verification_notes'),
  verifiedAt: timestamp('verified_at', { withTimezone: true }).notNull().defaultNow(),
  createdAt: timestamp('created_at', { withTimezone: true }).notNull().defaultNow(),
});

export type FirmwareHardwareCompatibility = typeof firmwareHardwareCompatibility.$inferSelect;
export type NewFirmwareHardwareCompatibility = typeof firmwareHardwareCompatibility.$inferInsert;
