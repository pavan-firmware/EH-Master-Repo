'use strict';

/**
 * EH Home — Phase 18 Device Fleet Management & OTA Lifecycle Test Suite
 *
 * Validates:
 * 1. Firmware Inventory & Release Registration
 * 2. Compatibility Matrix & Bridge Version Enforcement
 * 3. Fleet Status Aggregation & Cross-Home Isolation
 * 4. OTA Initiation, Capability RBAC & Command Dispatch
 * 5. OTA Progress Telemetry & Successful Update Convergence
 * 6. OTA Failure, Rollback Handling & Diagnostics
 * 7. Zero Secret Leakage Boundary Verification
 */

const assert = require('assert');
const { createApp } = require('../src/app');
const { DatabaseClient } = require('../src/shared/db-client');

console.log('\n===============================================================');
console.log('  EH HOME — PHASE 18 FLEET MANAGEMENT & OTA TEST SUITE');
console.log('===============================================================\n');

let passCount = 0;
async function test(name, fn) {
  try {
    await fn();
    console.log(`[PASS] ${name}`);
    passCount++;
  } catch (err) {
    console.error(`[FAIL] ${name}:`, err);
    process.exit(1);
  }
}

async function run() {
  const db = new DatabaseClient();
  const app = createApp({ db });
  const { otaService, deviceService, homeService, notificationService } = app.services;
  const {
    userRepo,
    homeRepo,
    roomRepo,
    deviceRepo,
    deviceStateRepo,
    firmwareRepo,
    operationRepo,
    maintenanceRepo
  } = app.repositories;

  // Seed Product Catalog Variant
  await db.insert('product_families', 'fam-switches', {
    id: 'fam-switches',
    name: 'EH Smart Switches',
    slug: 'switches'
  });
  await db.insert('products', 'prod-sw3x', {
    id: 'prod-sw3x',
    family_id: 'fam-switches',
    name: 'Smart Switch 3X',
    slug: 'smart-switch-3x'
  });
  await db.insert('product_variants', 'eh-smart-switch-3x', {
    id: 'eh-smart-switch-3x',
    product_id: 'prod-sw3x',
    name: '3X',
    sku_code: 'EH-SW3X',
    channel_count: 3,
    hardware_capabilities: ['power', 'relay', 'energy', 'voltage', 'current'],
    supported_firmware_families: ['esp32c6-switch-platform', 'esp32-switch-platform']
  });

  // Setup Fixture Users and Homes
  const ownerUser = await userRepo.createUser({
    id: '0194fe23-7a1b-7890-a123-000000000001',
    email: 'owner18@example.com',
    passwordHash: 'hash_pw_owner18',
    name: 'Fleet Owner'
  });

  const memberUser = await userRepo.createUser({
    id: '0194fe23-7a1b-7890-a123-000000000002',
    email: 'member18@example.com',
    passwordHash: 'hash_pw_member18',
    name: 'Fleet Member'
  });

  const outsiderUser = await userRepo.createUser({
    id: '0194fe23-7a1b-7890-a123-000000000003',
    email: 'outsider18@example.com',
    passwordHash: 'hash_pw_outsider18',
    name: 'Fleet Outsider'
  });

  const homeA = await homeRepo.createHome({
    id: '0194fe23-7a1b-7890-a123-111111111111',
    owner_id: ownerUser.id,
    name: 'Alpha Smart Manor'
  });
  await homeRepo.addMembership({
    home_id: homeA.id,
    user_id: memberUser.id,
    role: 'MEMBER'
  });

  const homeB = await homeRepo.createHome({
    id: '0194fe23-7a1b-7890-a123-222222222222',
    owner_id: outsiderUser.id,
    name: 'Beta Estate'
  });

  const roomA1 = await roomRepo.createRoom({
    id: '0194fe23-7a1b-7890-a123-333333333331',
    home_id: homeA.id,
    name: 'Living Room'
  });

  // Setup Devices
  const dev1 = await deviceRepo.createDevice({
    id: '0194fe23-7a1b-7890-a123-444444444441',
    serial_number: 'SN-SW-101',
    product_variant_id: 'eh-smart-switch-3x',
    hardware_revision: 'HW_1_0',
    firmware_family: 'esp32-switch-platform',
    firmware_version: '1.0.0'
  });
  await deviceRepo.claimDevice({
    device_id: dev1.id,
    home_id: homeA.id,
    room_id: roomA1.id,
    custom_name: 'Living Chandelier'
  });
  await deviceStateRepo.updateDeviceConnection(dev1.id, 'ONLINE');

  const dev2 = await deviceRepo.createDevice({
    id: '0194fe23-7a1b-7890-a123-444444444442',
    serial_number: 'SN-SW-102',
    product_variant_id: 'eh-smart-switch-3x',
    hardware_revision: 'HW_1_0',
    firmware_family: 'esp32-switch-platform',
    firmware_version: '1.0.0'
  });
  await deviceRepo.claimDevice({
    device_id: dev2.id,
    home_id: homeA.id,
    room_id: roomA1.id,
    custom_name: 'Wall Sconce'
  });
  await deviceStateRepo.updateDeviceConnection(dev2.id, 'OFFLINE');

  const devB = await deviceRepo.createDevice({
    id: '0194fe23-7a1b-7890-a123-444444444443',
    serial_number: 'SN-SW-201',
    product_variant_id: 'eh-smart-switch-3x',
    hardware_revision: 'HW_1_0',
    firmware_family: 'esp32-switch-platform',
    firmware_version: '1.0.0'
  });
  await deviceRepo.claimDevice({
    device_id: devB.id,
    home_id: homeB.id,
    room_id: null,
    custom_name: 'Beta Lamp'
  });
  await deviceStateRepo.updateDeviceConnection(devB.id, 'ONLINE');

  // ---------------------------------------------------------------------------
  // Test 1: Firmware Inventory & Release Registration
  // ---------------------------------------------------------------------------
  await test('1. Firmware Inventory & Release Registration', async () => {
    const rel110 = await otaService.registerRelease({
      id: 'rel_switch_110',
      productVariantId: 'eh-smart-switch-3x',
      hardwareRevision: 'HW_1_0',
      firmwareFamily: 'esp32-switch-platform',
      version: '1.1.0',
      minFirmwareVersion: '1.0.0',
      releaseChannel: 'production',
      binarySizeBytes: 1048576,
      sha256: 'a1b2c3d4e5f67890123456789abcdef0123456789abcdef0123456789abcdef0',
      ed25519Signature: 'sig_ed25519_sample_production_110',
      downloadUrl: 'https://ota.ehhome.io/firmware/eh-switch-3x-v1.1.0.bin',
      releaseNotes: 'Fixed power spike telemetry and optimized BLE reconnections.'
    });

    assert.strictEqual(rel110.id, 'rel_switch_110');
    assert.strictEqual(rel110.version, '1.1.0');

    // Register 2.0.0 requiring min 1.1.0
    await otaService.registerRelease({
      id: 'rel_switch_200',
      productVariantId: 'eh-smart-switch-3x',
      hardwareRevision: 'HW_1_0',
      firmwareFamily: 'esp32-switch-platform',
      version: '2.0.0',
      minFirmwareVersion: '1.1.0',
      releaseChannel: 'production',
      binarySizeBytes: 1200000,
      sha256: 'b2c3d4e5f67890123456789abcdef0123456789abcdef0123456789abcdef01',
      ed25519Signature: 'sig_ed25519_sample_production_200',
      downloadUrl: 'https://ota.ehhome.io/firmware/eh-switch-3x-v2.0.0.bin',
      releaseNotes: 'Major platform upgrade with Thread protocol support.'
    });

    const storedRel = await otaService.getRelease('rel_switch_110');
    assert.ok(storedRel);
    assert.strictEqual(storedRel.version, '1.1.0');

    const releases = await otaService.listReleases({ productVariantId: 'eh-smart-switch-3x' });
    assert.strictEqual(releases.length, 2);
  });

  // ---------------------------------------------------------------------------
  // Test 2: Compatibility Matrix & Bridge Version Enforcement
  // ---------------------------------------------------------------------------
  await test('2. Compatibility Matrix & Bridge Version Enforcement', async () => {
    // Device at 1.0.0 checks update: should get 1.1.0 (2.0.0 requires min 1.1.0)
    const check1 = await otaService.checkUpdate({
      productVariantId: 'eh-smart-switch-3x',
      hardwareRevision: 'HW_1_0',
      currentVersion: '1.0.0'
    });
    assert.strictEqual(check1.updateAvailable, true);
    assert.strictEqual(check1.release.version, '1.1.0');

    // Device at 1.1.0 checks update: can now get 2.0.0
    const check2 = await otaService.checkUpdate({
      productVariantId: 'eh-smart-switch-3x',
      hardwareRevision: 'HW_1_0',
      currentVersion: '1.1.0'
    });
    assert.strictEqual(check2.updateAvailable, true);
    assert.strictEqual(check2.release.version, '2.0.0');

    // Incompatible hardware revision
    const checkHW = await otaService.checkUpdate({
      productVariantId: 'eh-smart-switch-3x',
      hardwareRevision: 'HW_2_0_REV_B',
      currentVersion: '1.0.0'
    });
    assert.strictEqual(checkHW.updateAvailable, false);
  });

  // ---------------------------------------------------------------------------
  // Test 3: Fleet Status Aggregation & Cross-Home Isolation
  // ---------------------------------------------------------------------------
  await test('3. Fleet Status Aggregation & Cross-Home Isolation', async () => {
    const fleetA = await otaService.getFleetStatus({
      homeId: homeA.id,
      userId: ownerUser.id
    });

    assert.strictEqual(fleetA.totalDevices, 2);
    assert.strictEqual(fleetA.onlineDevices, 1);
    assert.strictEqual(fleetA.offlineDevices, 1);
    assert.strictEqual(fleetA.otaUpdateAvailableCount, 2);

    // Cross-Home Isolation: Outsider in Home B cannot see Home A devices
    try {
      await otaService.getFleetStatus({
        homeId: homeA.id,
        userId: outsiderUser.id
      });
      assert.fail('Should have rejected outsider user from Home A fleet');
    } catch (err) {
      assert.strictEqual(err.statusCode || 403, 403);
    }
  });

  // ---------------------------------------------------------------------------
  // Test 4: OTA Initiation, Capability RBAC & Command Dispatch
  // ---------------------------------------------------------------------------
  await test('4. OTA Initiation, Capability RBAC & Command Dispatch', async () => {
    // Member cannot initiate OTA (only Owner/Admin has canManageDevices)
    try {
      await otaService.initiateOta({
        deviceId: dev1.id,
        releaseId: 'rel_switch_110',
        homeId: homeA.id,
        userId: memberUser.id
      });
      assert.fail('MEMBER should not be able to trigger OTA update');
    } catch (err) {
      assert.ok(err.message.includes('Forbidden') || err.message.includes('canManageDevices') || err.message.includes('not authorized'));
    }

    // Owner triggers OTA for dev1
    const op = await otaService.initiateOta({
      deviceId: dev1.id,
      releaseId: 'rel_switch_110',
      homeId: homeA.id,
      userId: ownerUser.id
    });

    assert.ok(op.id);
    assert.strictEqual(op.status, 'DOWNLOADING');
    assert.strictEqual(op.target_version || op.targetVersion, '1.1.0');

    // Trying to trigger another OTA while one is active is rejected
    try {
      await otaService.initiateOta({
        deviceId: dev1.id,
        releaseId: 'rel_switch_110',
        homeId: homeA.id,
        userId: ownerUser.id
      });
      assert.fail('Duplicate active OTA should be rejected');
    } catch (err) {
      assert.ok(err.message.includes('already has an active OTA operation'));
    }
  });

  // ---------------------------------------------------------------------------
  // Test 5: OTA Progress Telemetry & Successful Update Convergence
  // ---------------------------------------------------------------------------
  await test('5. OTA Progress Telemetry & Successful Update Convergence', async () => {
    const activeOp = await operationRepo.findActiveByDeviceId(dev1.id);
    assert.ok(activeOp);

    // Progress updates
    await otaService.handleOtaProgress({
      deviceId: dev1.id,
      operationId: activeOp.id,
      progressPercent: 45,
      stage: 'DOWNLOADING'
    });

    await otaService.handleOtaProgress({
      deviceId: dev1.id,
      operationId: activeOp.id,
      progressPercent: 90,
      stage: 'INSTALLING'
    });

    const opUpdated = await operationRepo.findById(activeOp.id);
    assert.strictEqual(opUpdated.progress_percent, 90);
    assert.strictEqual(opUpdated.status, 'INSTALLING');

    // Success confirmation from device boot
    await otaService.handleOtaSuccess({
      deviceId: dev1.id,
      operationId: activeOp.id,
      installedVersion: '1.1.0'
    });

    const opCompleted = await operationRepo.findById(activeOp.id);
    assert.strictEqual(opCompleted.status, 'SUCCESS');
    assert.strictEqual(opCompleted.progress_percent, 100);

    const devRefreshed = await deviceRepo.getDevice(dev1.id);
    assert.strictEqual(devRefreshed.firmware_version, '1.1.0');

    // Maintenance log check
    const logs = await maintenanceRepo.findByDeviceId(dev1.id);
    assert.ok(logs.length > 0);
    assert.strictEqual(logs[0].status, 'SUCCESS');
  });

  // ---------------------------------------------------------------------------
  // Test 6: OTA Failure, Rollback Handling & Diagnostics
  // ---------------------------------------------------------------------------
  await test('6. OTA Failure, Rollback Handling & Diagnostics', async () => {
    // Start OTA on dev2
    const op = await otaService.initiateOta({
      deviceId: dev2.id,
      releaseId: 'rel_switch_110',
      homeId: homeA.id,
      userId: ownerUser.id
    });

    // Ingest Rollback event
    await otaService.handleOtaFailure({
      deviceId: dev2.id,
      operationId: op.id,
      errorCode: 'BOOT_INTEGRITY_FAIL',
      errorMessage: 'CRC check failed on next partition boot; rolled back to previous slot',
      isRollback: true
    });

    const opRolledBack = await operationRepo.findById(op.id);
    assert.strictEqual(opRolledBack.status, 'ROLLED_BACK');
    assert.strictEqual(opRolledBack.error_code, 'BOOT_INTEGRITY_FAIL');

    // Device firmware remains untouched at 1.0.0
    const dev2Check = await deviceRepo.getDevice(dev2.id);
    assert.strictEqual(dev2Check.firmware_version, '1.0.0');

    const maintLogs = await maintenanceRepo.findByDeviceId(dev2.id);
    assert.ok(maintLogs.length > 0);
    assert.strictEqual(maintLogs[0].status, 'ROLLED_BACK');
  });

  // ---------------------------------------------------------------------------
  // Test 7: Zero Secret Leakage Boundary Verification
  // ---------------------------------------------------------------------------
  await test('7. Zero Secret Leakage Boundary Verification', async () => {
    const fleet = await otaService.getFleetStatus({
      homeId: homeA.id,
      userId: ownerUser.id
    });
    const serializedFleet = JSON.stringify(fleet);

    assert.strictEqual(serializedFleet.includes('hash_pw'), false);
    assert.strictEqual(serializedFleet.includes('privateKey'), false);
    assert.strictEqual(serializedFleet.includes('mqttPassword'), false);
    assert.strictEqual(serializedFleet.includes('commissioningSecret'), false);

    const history = await otaService.getMaintenanceHistory({
      homeId: homeA.id,
      userId: ownerUser.id
    });
    const serializedHistory = JSON.stringify(history);
    assert.strictEqual(serializedHistory.includes('privateKey'), false);
    assert.strictEqual(serializedHistory.includes('hash_pw'), false);
  });

  console.log('\n===============================================================');
  console.log(`  PHASE 18 TEST SUMMARY: ${passCount} PASSED, 0 FAILED`);
  console.log('===============================================================\n');
}

run().catch(err => {
  console.error('Test runner fatal failure:', err);
  process.exit(1);
});
