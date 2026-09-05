'use strict';

/**
 * EH Home — Authoritative Release & Runtime Metadata (Phase 34)
 *
 * Single authoritative source for platform versioning, migration level,
 * schema compatibility, and deployment metadata.
 */

const METADATA = {
  schemaVersion: 1,
  appName: 'EH Home',
  service: 'eh-home-backend',
  appVersion: '1.0.0',
  backendVersion: '1.0.0',
  flutterAppVersion: '0.1.0+1',
  schemaVersionNumber: 26,
  latestMigration: '026_disaster_recovery_state_resilience',
  totalTables: 98,
  nodeVersion: process.version,
  platform: process.platform,
  arch: process.arch
};

/**
 * Get full release metadata snapshot with dynamic runtime context
 *
 * @param {Object} [overrides={}]
 * @returns {Object}
 */
function getReleaseMetadata(overrides = {}) {
  const env = overrides.environment || process.env.NODE_ENV || 'development';
  const gitCommit = overrides.gitCommit || process.env.GIT_COMMIT_SHA || 'd49d3e3d5aa858197113650b2597afb0e6a07ad0';
  const buildTimestamp = overrides.buildTimestamp || process.env.BUILD_TIMESTAMP || '2026-09-05T12:00:00.000Z';

  return {
    schemaVersion: METADATA.schemaVersion,
    appName: METADATA.appName,
    service: METADATA.service,
    appVersion: METADATA.appVersion,
    backendVersion: METADATA.backendVersion,
    flutterAppVersion: METADATA.flutterAppVersion,
    schemaVersionNumber: METADATA.schemaVersionNumber,
    latestMigration: METADATA.latestMigration,
    totalTables: METADATA.totalTables,
    gitCommit,
    buildTimestamp,
    environment: env,
    nodeVersion: METADATA.nodeVersion,
    platform: METADATA.platform,
    arch: METADATA.arch
  };
}

module.exports = {
  METADATA,
  getReleaseMetadata
};
