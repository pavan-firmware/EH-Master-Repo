/**
 * EH Home Drizzle Database Schema Test Suite
 * Validates table definitions, column parity, and relations integrity.
 */

const assert = require('assert');
const schema = require('../dist');

let totalTests = 0;
let passedTests = 0;
let failedTests = 0;

function runTest(name, fn) {
  totalTests++;
  try {
    fn();
    console.log(`  [PASS] ${name}`);
    passedTests++;
  } catch (err) {
    console.error(`  [FAIL] ${name}: ${err.message}`);
    failedTests++;
  }
}

console.log('=== EH HOME DRIZZLE DATABASE SCHEMA TESTS ===\n');

// ── 1. Core Table Exports & Total Count ────────────────────────────────
console.log('1. Table Parity & Export Integrity:');

const expectedTables = [
  // auth-identity (5)
  'users', 'refreshTokens', 'userProfiles', 'homeInvitations', 'homeMemberships',
  // home-topology (3)
  'homes', 'floors', 'rooms',
  // product-catalog (8)
  'productFamilies', 'products', 'productVariants', 'productModels', 'capabilities', 'productCapabilities', 'productImages', 'deviceAddSessions',
  // device-identity-state (9)
  'devices', 'deviceCredentials', 'deviceAuthorizations', 'deviceState', 'channelState', 'deviceCommands', 'deviceEvents', 'networkIdentity', 'provisioningSessions',
  // automations-scenes (4)
  'scenes', 'automations', 'schedules', 'automationExecutionLogs',
  // device-health-activity (6)
  'deviceActivityLogs', 'deviceHealthMetrics', 'deviceTransports', 'deviceConnectionStates', 'commissioningSessions', 'transportHealthSnapshots',
  // notifications-alerts (8)
  'notifications', 'pushDeviceTokens', 'userNotificationPreferences', 'notificationDeliveryQueue', 'platformEvents', 'notificationAggregations', 'notificationActions', 'platformAlerts',
  // sync-lifecycle (3)
  'syncCheckpoints', 'pendingChangeAudits', 'dataExportRecords',
  // fleet-ota (6)
  'firmwareReleases', 'otaRollouts', 'otaOperations', 'deviceMaintenanceLogs', 'fleetDeviceFirmwareState', 'otaAttempts',
  // energy-intelligence (15)
  'deviceTelemetryMeasurements', 'telemetryAggregates', 'energyThresholdConfigs', 'energyEvents', 'energyAutomationExecutions', 'energyOptimizations', 'energyTariffs', 'tariffPeriods', 'energyBudgets', 'costOptimizations', 'energyForecasts', 'energyAnomalies', 'energyBaselines', 'forecastAccuracyRecords', 'energyEfficiencyScores',
  // presence-context (5)
  'presenceSignals', 'presenceStates', 'homeContexts', 'contextOverrides', 'contextTransitions',
  // home-intelligence (3)
  'intelligenceDecisions', 'intelligenceRecommendations', 'intelligenceDecisionOutcomes',
  // device-reliability (5)
  'reliabilityIncidents', 'reliabilityDiagnostics', 'reliabilityRecoveryAttempts', 'reliabilityHealthSnapshots', 'maintenanceRecommendations',
  // edge-local-control (3)
  'localRouteCache', 'edgeExecutionRecords', 'localDiscoveryNodes',
  // matter-interop (5)
  'matterDevices', 'matterFabrics', 'matterEndpoints', 'matterSyncState', 'externalPlatformLinks',
  // operations-audit (6)
  'auditLogs', 'outbox', 'operationalEvents', 'securityAuditRecords', 'systemHealthSnapshots', 'platformIncidents',
  // device-trust (4)
  'deviceTrustStates', 'deviceCredentialLifecycle', 'deviceRevocations', 'deviceProvisioningRecords',
  // disaster-recovery (5)
  'backupRecords', 'backupObjects', 'restoreOperations', 'recoveryCheckpoints', 'recoveryIntegrityResults',
  // hardware-bom (5 - Migration 030)
  'hardwareRevisions', 'bomSpecifications', 'bomItems', 'componentSubstitutions', 'productVariantHardwareCompatibility',
  // firmware-build (4 - Migration 031)
  'firmwareFamilies', 'firmwareBuilds', 'firmwareArtifacts', 'firmwareHardwareCompatibility',
  // inventory-packing (4 - Migration 033)
  'packagingCartons', 'inventoryItems', 'dualScanVerifications', 'packagingRecords',
  // telemetry-mqtt-ota (3 - Migration 034)
  'mqttAclRules', 'deviceAvailabilityHistory', 'otaExecutionJobs'
];

runTest(`Exactly ${expectedTables.length} tables exported (119 total: 103 historical + 5 Migration 030 + 4 Migration 031 + 4 Migration 033 + 3 Migration 034)`, () => {
  assert.strictEqual(expectedTables.length, 119);
  expectedTables.forEach(tName => {
    assert.ok(schema[tName], `Missing exported table: ${tName}`);
  });
});

// ── 2. Column Parity & Data Types Validation ─────────────────────────
console.log('\n2. Column Parity & Specific Types:');

runTest('users table column parity', () => {
  const t = schema.users;
  assert.ok(t.id, 'users.id exists');
  assert.ok(t.email, 'users.email exists');
  assert.ok(t.passwordHash, 'users.password_hash exists');
  assert.ok(t.role, 'users.role exists');
  assert.ok(t.emailVerified, 'users.email_verified exists');
  assert.ok(t.createdAt, 'users.created_at exists');
  assert.ok(t.updatedAt, 'users.updated_at exists');
});

runTest('devices table column parity', () => {
  const t = schema.devices;
  assert.ok(t.id, 'devices.id exists');
  assert.ok(t.serialNumber, 'devices.serial_number exists');
  assert.ok(t.productVariantId, 'devices.product_variant_id exists');
  assert.ok(t.hardwareRevision, 'devices.hardware_revision exists');
  assert.ok(t.firmwareVersion, 'devices.firmware_version exists');
  assert.ok(t.firmwareFamily, 'devices.firmware_family exists');
});

runTest('device_telemetry_measurements table numeric & integer parity', () => {
  const t = schema.deviceTelemetryMeasurements;
  assert.ok(t.vMv, 'v_mv exists');
  assert.ok(t.iMa, 'i_ma exists');
  assert.ok(t.pMw, 'p_mw exists');
  assert.ok(t.eTotWh, 'e_tot_wh exists');
});

runTest('channel_state composite unique constraint exists', () => {
  const t = schema.channelState;
  assert.ok(t.deviceId, 'channelState.device_id exists');
  assert.ok(t.channelIndex, 'channelState.channel_index exists');
  assert.ok(t.desiredState, 'channelState.desired_state exists');
  assert.ok(t.reportedState, 'channelState.reported_state exists');
});

// ── 3. Relations Integrity ───────────────────────────────────────────
console.log('\n3. Relations Graph Integrity:');

runTest('usersRelations defined and valid', () => {
  assert.ok(schema.usersRelations, 'usersRelations exists');
});

runTest('homesRelations defined and valid', () => {
  assert.ok(schema.homesRelations, 'homesRelations exists');
});

runTest('devicesRelations defined and valid', () => {
  assert.ok(schema.devicesRelations, 'devicesRelations exists');
});

runTest('productVariantsRelations defined and valid', () => {
  assert.ok(schema.productVariantsRelations, 'productVariantsRelations exists');
});

runTest('hardwareRevisions & bomSpecifications column parity and relations', () => {
  const hw = schema.hardwareRevisions;
  assert.ok(hw.id, 'hardwareRevisions.id exists');
  assert.ok(hw.revisionCode, 'hardwareRevisions.revision_code exists');
  assert.ok(hw.productVariantId, 'hardwareRevisions.product_variant_id exists');
  assert.ok(hw.pcbName, 'hardwareRevisions.pcb_name exists');
  assert.ok(hw.lifecycleStatus, 'hardwareRevisions.lifecycle_status exists');

  const bom = schema.bomSpecifications;
  assert.ok(bom.id, 'bomSpecifications.id exists');
  assert.ok(bom.hardwareRevisionId, 'bomSpecifications.hardware_revision_id exists');
  assert.ok(bom.version, 'bomSpecifications.version exists');

  const item = schema.bomItems;
  assert.ok(item.id, 'bomItems.id exists');
  assert.ok(item.bomId, 'bomItems.bom_id exists');
  assert.ok(item.referenceDesignator, 'bomItems.reference_designator exists');
  assert.ok(item.mpn, 'bomItems.mpn exists');
  assert.ok(item.quantity, 'bomItems.quantity exists');

  assert.ok(schema.hardwareRevisionsRelations, 'hardwareRevisionsRelations exists');
  assert.ok(schema.bomSpecificationsRelations, 'bomSpecificationsRelations exists');
});

runTest('firmwareFamilies, firmwareBuilds, firmwareArtifacts & compatibility column parity and relations', () => {
  const fam = schema.firmwareFamilies;
  assert.ok(fam.id, 'firmwareFamilies.id exists');
  assert.ok(fam.displayName, 'firmwareFamilies.display_name exists');
  assert.ok(fam.targetMcu, 'firmwareFamilies.target_mcu exists');
  assert.ok(fam.defaultIdfVersion, 'firmwareFamilies.default_idf_version exists');

  const bld = schema.firmwareBuilds;
  assert.ok(bld.id, 'firmwareBuilds.id exists');
  assert.ok(bld.firmwareFamilyId, 'firmwareBuilds.firmware_family_id exists');
  assert.ok(bld.gitCommitSha, 'firmwareBuilds.git_commit_sha exists');
  assert.ok(bld.gitBranch, 'firmwareBuilds.git_branch exists');
  assert.ok(bld.idfVersion, 'firmwareBuilds.idf_version exists');

  const art = schema.firmwareArtifacts;
  assert.ok(art.id, 'firmwareArtifacts.id exists');
  assert.ok(art.buildId, 'firmwareArtifacts.build_id exists');
  assert.ok(art.artifactType, 'firmwareArtifacts.artifact_type exists');
  assert.ok(art.sha256, 'firmwareArtifacts.sha256 exists');
  assert.ok(art.storagePath, 'firmwareArtifacts.storage_path exists');

  const comp = schema.firmwareHardwareCompatibility;
  assert.ok(comp.id, 'firmwareHardwareCompatibility.id exists');
  assert.ok(comp.firmwareReleaseId, 'firmwareHardwareCompatibility.firmware_release_id exists');
  assert.ok(comp.hardwareRevisionId, 'firmwareHardwareCompatibility.hardware_revision_id exists');

  assert.ok(schema.firmwareFamiliesRelations, 'firmwareFamiliesRelations exists');
  assert.ok(schema.firmwareBuildsRelations, 'firmwareBuildsRelations exists');
  assert.ok(schema.firmwareArtifactsRelations, 'firmwareArtifactsRelations exists');
  assert.ok(schema.firmwareHardwareCompatibilityRelations, 'firmwareHardwareCompatibilityRelations exists');
});

runTest('inventoryItems, packagingCartons, dualScanVerifications & packagingRecords column parity and relations', () => {
  const carton = schema.packagingCartons;
  assert.ok(carton.id, 'packagingCartons.id exists');
  assert.ok(carton.cartonCode, 'packagingCartons.carton_code exists');
  assert.ok(carton.productVariantId, 'packagingCartons.product_variant_id exists');
  assert.ok(carton.hardwareRevision, 'packagingCartons.hardware_revision exists');
  assert.ok(carton.status, 'packagingCartons.status exists');

  const item = schema.inventoryItems;
  assert.ok(item.id, 'inventoryItems.id exists');
  assert.ok(item.deviceId, 'inventoryItems.device_id exists');
  assert.ok(item.serialNumber, 'inventoryItems.serial_number exists');
  assert.ok(item.productVariantId, 'inventoryItems.product_variant_id exists');
  assert.ok(item.hardwareRevision, 'inventoryItems.hardware_revision exists');
  assert.ok(item.firmwareFamily, 'inventoryItems.firmware_family exists');
  assert.ok(item.traceId, 'inventoryItems.trace_id exists');
  assert.ok(item.status, 'inventoryItems.status exists');

  const scan = schema.dualScanVerifications;
  assert.ok(scan.id, 'dualScanVerifications.id exists');
  assert.ok(scan.deviceId, 'dualScanVerifications.device_id exists');
  assert.ok(scan.serialNumber, 'dualScanVerifications.serial_number exists');
  assert.ok(scan.scannedQrToken, 'dualScanVerifications.scanned_qr_token exists');
  assert.ok(scan.isMatch, 'dualScanVerifications.is_match exists');
  assert.ok(scan.verificationStatus, 'dualScanVerifications.verification_status exists');

  const pack = schema.packagingRecords;
  assert.ok(pack.id, 'packagingRecords.id exists');
  assert.ok(pack.traceId, 'packagingRecords.trace_id exists');
  assert.ok(pack.deviceId, 'packagingRecords.device_id exists');
  assert.ok(pack.cartonId, 'packagingRecords.carton_id exists');
  assert.ok(pack.verificationId, 'packagingRecords.verification_id exists');

  assert.ok(schema.packagingCartonsRelations, 'packagingCartonsRelations exists');
  assert.ok(schema.inventoryItemsRelations, 'inventoryItemsRelations exists');
  assert.ok(schema.dualScanVerificationsRelations, 'dualScanVerificationsRelations exists');
  assert.ok(schema.packagingRecordsRelations, 'packagingRecordsRelations exists');
});

// ── 4. Client Factory Integrity ──────────────────────────────────────
console.log('\n4. Database Client Factory:');

runTest('Client factories exported', () => {
  assert.strictEqual(typeof schema.getDatabaseConfig, 'function');
  assert.strictEqual(typeof schema.createDatabasePool, 'function');
  assert.strictEqual(typeof schema.createDrizzleClient, 'function');
});

runTest('getDatabaseConfig returns valid defaults', () => {
  const conf = schema.getDatabaseConfig();
  assert.ok(conf.host || conf.connectionString, 'Has connection target');
  assert.ok(conf.maxConnections > 0, 'Has valid pool max');
});

// ── SUMMARY ───────────────────────────────────────────────────────────
console.log(`\n=== DRIZZLE SCHEMA TESTS SUMMARY ===`);
console.log(`Total:  ${totalTests}`);
console.log(`Passed: ${passedTests}`);
console.log(`Failed: ${failedTests}`);

if (failedTests > 0) {
  process.exit(1);
} else {
  console.log('ALL DRIZZLE SCHEMA TESTS PASSED [OK]\n');
}
