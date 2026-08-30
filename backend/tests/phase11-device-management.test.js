'use strict';

/**
 * EH Home — Phase 11 Backend Device Management & Observability Test Suite
 *
 * Tests:
 *   1. Device Details Retrieval with Authoritative Health, Last Seen & Capabilities (Zero Secrets)
 *   2. Device Renaming with Validation, Persistence & Realtime Event Emission
 *   3. Device Room Movement with Cross-Home Access Denial
 *   4. Device Removal from Home (Unclaim) with Factory Identity Preservation
 *   5. Health & Reliability Calculations (ONLINE, OFFLINE, STALE, DEGRADED)
 *   6. Activity Logging, Correlation IDs & Diagnostics Visibility
 *   7. Observability /health, /health/liveness, /health/readiness & /health/diagnostics
 */

const assert = require('assert').strict;
const { DatabaseClient } = require('../src/shared/db-client');
const {
  UserRepository,
  HomeRepository,
  RoomRepository,
  DeviceRepository,
  DeviceStateRepository,
  CommandRepository,
  EventRepository,
  AuditRepository,
  OutboxRepository,
  DeviceActivityLogRepository,
  DeviceHealthRepository
} = require('../src/repositories');
const { DeviceManagementService, HEALTH_STATUSES } = require('../src/services/device-management.service');
const { HomeAuthorizationService } = require('../src/shared/home-authorization');
const { ProductCatalogService } = require('../src/services/product-catalog.service');
const { createApp } = require('../src/app');

let totalTests = 0;
let passedTests = 0;

async function test(name, fn) {
  totalTests++;
  try {
    await fn();
    console.log(`[PASS] ${name}`);
    passedTests++;
  } catch (err) {
    console.error(`[FAIL] ${name}: ${err.message}`);
    if (err.stack) console.error(err.stack);
  }
}

async function setupTestContext() {
  const db = new DatabaseClient();

  const userRepo = new UserRepository(db);
  const homeRepo = new HomeRepository(db);
  const roomRepo = new RoomRepository(db);
  const deviceRepo = new DeviceRepository(db);
  const deviceStateRepo = new DeviceStateRepository(db);
  const commandRepo = new CommandRepository(db);
  const auditRepo = new AuditRepository(db);
  const activityLogRepo = new DeviceActivityLogRepository(db);
  const healthRepo = new DeviceHealthRepository(db);

  const homeAuthService = new HomeAuthorizationService({ homeRepo, deviceRepo, roomRepo });
  const catalogService = new ProductCatalogService();

  const publishedEvents = [];
  const realtimeEventBus = {
    publish: (evt) => publishedEvents.push(evt)
  };

  const deviceManagementService = new DeviceManagementService({
    deviceRepo,
    deviceStateRepo,
    homeRepo,
    roomRepo,
    auditRepo,
    activityLogRepo,
    healthRepo,
    commandRepo,
    homeAuthService,
    realtimeEventBus,
    productCatalogService: catalogService
  });

  // Seed user, home, room, device
  const user = await userRepo.createUser({
    id: 'usr_test_phase11',
    email: 'phase11@test.com',
    passwordHash: 'hashed_pw_123'
  });

  const home = await homeRepo.createHome({
    id: 'home_test_phase11',
    name: 'Phase 11 Villa',
    ownerId: user.id
  });

  const room = await roomRepo.createRoom({
    id: 'room_living_11',
    homeId: home.id,
    name: 'Living Room'
  });

  const roomBedroom = await roomRepo.createRoom({
    id: 'room_bedroom_11',
    homeId: home.id,
    name: 'Master Bedroom'
  });

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

  const deviceId = '4444688e-989d-458e-820e-ac62a99ed8e1';
  await deviceRepo.registerDevice({
    deviceId,
    serialNumber: 'EH-SW3X-2026W12-00001',
    productVariantId: 'eh-smart-switch-3x',
    hardwareRevision: 'HW_1_0',
    firmwareFamily: 'esp32c6-switch-platform',
    firmwareVersion: '1.2.0'
  });

  await db.insert('device_authorizations', deviceId, {
    device_id: deviceId,
    home_id: home.id,
    room_id: room.id,
    custom_name: 'Living Room Main Switch',
    claimed_by_user_id: user.id
  });

  await db.update('device_state', deviceId, {
    connection_state: 'ONLINE',
    last_seen_at: new Date().toISOString()
  });

  return {
    db,
    user,
    home,
    room,
    roomBedroom,
    deviceId,
    deviceManagementService,
    publishedEvents,
    activityLogRepo,
    healthRepo
  };
}

(async () => {
  console.log('=== RUNNING PHASE 11 DEVICE MANAGEMENT & OBSERVABILITY TESTS ===\n');

  // Test 1: Device Details Retrieval
  await test('1. Device Details Retrieval with Authoritative Health, Last Seen & Capabilities (Zero Secrets)', async () => {
    const ctx = await setupTestContext();
    const details = await ctx.deviceManagementService.getDeviceDetails({
      homeId: ctx.home.id,
      deviceId: ctx.deviceId,
      userId: ctx.user.id
    });

    assert.equal(details.deviceId, ctx.deviceId);
    assert.equal(details.displayName, 'Living Room Main Switch');
    assert.equal(details.serialNumber, 'EH-SW3X-2026W12-00001');
    assert.equal(details.connectionState, 'ONLINE');
    assert.equal(details.health.status, 'ONLINE');
    assert.equal(details.roomName, 'Living Room');
    assert.equal(details.channels.length, 3);
    assert.equal(details.capabilities.includes('power'), true);

    // Verify ZERO secret leakage
    const serialized = JSON.stringify(details);
    assert.equal(serialized.includes('password'), false);
    assert.equal(serialized.includes('secret'), false);
    assert.equal(serialized.includes('privateKey'), false);
  });

  // Test 2: Device Renaming
  await test('2. Device Renaming with Validation, Persistence & Realtime Event Emission', async () => {
    const ctx = await setupTestContext();

    // Invalid name fails
    await assert.rejects(
      async () => {
        await ctx.deviceManagementService.renameDevice({
          homeId: ctx.home.id,
          deviceId: ctx.deviceId,
          newName: '',
          userId: ctx.user.id
        });
      },
      /cannot be empty/
    );

    // Valid rename succeeds
    const result = await ctx.deviceManagementService.renameDevice({
      homeId: ctx.home.id,
      deviceId: ctx.deviceId,
      newName: 'Front Living Room Switch',
      userId: ctx.user.id
    });

    assert.equal(result.success, true);
    assert.equal(result.displayName, 'Front Living Room Switch');

    // Details reflection
    const updated = await ctx.deviceManagementService.getDeviceDetails({
      homeId: ctx.home.id,
      deviceId: ctx.deviceId,
      userId: ctx.user.id
    });
    assert.equal(updated.displayName, 'Front Living Room Switch');

    // Realtime event emitted
    assert.equal(ctx.publishedEvents.length, 1);
    assert.equal(ctx.publishedEvents[0].type, 'device.updated');
    assert.equal(ctx.publishedEvents[0].payload.displayName, 'Front Living Room Switch');
  });

  // Test 3: Device Room Movement with Cross-Home Access Denial
  await test('3. Device Room Movement with Cross-Home Access Denial', async () => {
    const ctx = await setupTestContext();

    // Unauthorized user denied
    await assert.rejects(
      async () => {
        await ctx.deviceManagementService.moveDevice({
          homeId: ctx.home.id,
          deviceId: ctx.deviceId,
          newRoomId: ctx.roomBedroom.id,
          userId: 'usr_unauthorized_attacker'
        });
      },
      /not a member of home|not authorized/
    );

    // Valid move succeeds
    const result = await ctx.deviceManagementService.moveDevice({
      homeId: ctx.home.id,
      deviceId: ctx.deviceId,
      newRoomId: ctx.roomBedroom.id,
      userId: ctx.user.id
    });

    assert.equal(result.success, true);
    assert.equal(result.roomId, ctx.roomBedroom.id);
    assert.equal(result.roomName, 'Master Bedroom');

    const updated = await ctx.deviceManagementService.getDeviceDetails({
      homeId: ctx.home.id,
      deviceId: ctx.deviceId,
      userId: ctx.user.id
    });
    assert.equal(updated.roomId, ctx.roomBedroom.id);
    assert.equal(updated.roomName, 'Master Bedroom');
  });

  // Test 4: Device Removal / Unclaim
  await test('4. Device Removal from Home (Unclaim) with Factory Identity Preservation', async () => {
    const ctx = await setupTestContext();

    const result = await ctx.deviceManagementService.removeDeviceFromHome({
      homeId: ctx.home.id,
      deviceId: ctx.deviceId,
      userId: ctx.user.id
    });

    assert.equal(result.success, true);

    // Device is no longer accessible via Home
    await assert.rejects(
      async () => {
        await ctx.deviceManagementService.getDeviceDetails({
          homeId: ctx.home.id,
          deviceId: ctx.deviceId,
          userId: ctx.user.id
        });
      },
      /not assigned/
    );

    // Physical factory registration identity is PRESERVED
    const physicalDev = await ctx.db.findById('devices', ctx.deviceId);
    assert.ok(physicalDev, 'Physical factory identity must not be deleted');
    assert.equal(physicalDev.serial_number, 'EH-SW3X-2026W12-00001');
  });

  // Test 5: Unified Health Calculations
  await test('5. Health & Reliability Calculations (ONLINE, OFFLINE, STALE, DEGRADED)', async () => {
    const ctx = await setupTestContext();

    // 1. ONLINE
    let health = await ctx.deviceManagementService.calculateDeviceHealth(ctx.deviceId);
    assert.equal(health.status, HEALTH_STATUSES.ONLINE);

    // 2. STALE (stale heartbeat)
    const oldTimestamp = new Date(Date.now() - 120_000).toISOString();
    await ctx.db.update('device_state', ctx.deviceId, {
      connection_state: 'STALE',
      last_seen_at: oldTimestamp
    });
    health = await ctx.deviceManagementService.calculateDeviceHealth(ctx.deviceId);
    assert.equal(health.status, HEALTH_STATUSES.STALE);

    // 3. OFFLINE
    await ctx.db.update('device_state', ctx.deviceId, {
      connection_state: 'OFFLINE'
    });
    health = await ctx.deviceManagementService.calculateDeviceHealth(ctx.deviceId);
    assert.equal(health.status, HEALTH_STATUSES.OFFLINE);

    // 4. DEGRADED (high command failure rate)
    await ctx.db.update('device_state', ctx.deviceId, {
      connection_state: 'ONLINE',
      last_seen_at: new Date().toISOString()
    });
    await ctx.healthRepo.upsertMetrics({
      deviceId: ctx.deviceId,
      homeId: ctx.home.id,
      healthStatus: 'ONLINE',
      commandSuccessCount: 3,
      commandFailureCount: 7
    });
    health = await ctx.deviceManagementService.calculateDeviceHealth(ctx.deviceId);
    assert.equal(health.status, HEALTH_STATUSES.DEGRADED);
    assert.ok(health.degradationReason.includes('High command failure rate'));
  });

  // Test 6: Activity Logging & Diagnostics
  await test('6. Activity Logging, Correlation IDs & Diagnostics Visibility', async () => {
    const ctx = await setupTestContext();

    await ctx.activityLogRepo.createLog({
      id: 'act_test_log_1',
      homeId: ctx.home.id,
      deviceId: ctx.deviceId,
      eventType: 'state_changed',
      severity: 'info',
      message: 'Switch channel 1 toggled to ON',
      correlationId: 'corr_test_123',
      details: { channel: 1, state: true }
    });

    const history = await ctx.deviceManagementService.getDeviceActivityHistory({
      homeId: ctx.home.id,
      deviceId: ctx.deviceId,
      userId: ctx.user.id
    });

    assert.equal(history.total >= 1, true);
    assert.equal(history.data[0].correlation_id, 'corr_test_123');

    const diag = await ctx.deviceManagementService.getDeviceDiagnostics({
      homeId: ctx.home.id,
      deviceId: ctx.deviceId,
      userId: ctx.user.id
    });

    assert.equal(diag.deviceId, ctx.deviceId);
    assert.equal(diag.network.protocol, 'MQTT/TLS (mTLS)');
    assert.equal(diag.network.port, 8883);
  });

  // Test 7: Observability Health Endpoints
  await test('7. Observability /health, /health/liveness, /health/readiness & /health/diagnostics', async () => {
    const ctx = await setupTestContext();
    const app = createApp({ db: ctx.db });

    function makeRequest(path, method = 'GET') {
      return new Promise((resolve) => {
        const req = {
          url: path,
          method,
          headers: {},
          socket: { remoteAddress: '127.0.0.1' },
          on: (event, handler) => { if (event === 'end') handler(); }
        };
        const res = {
          headers: {},
          writeHead: (status, headers) => { res.statusCode = status; res.headers = headers; },
          end: (payload) => { resolve({ status: res.statusCode, body: JSON.parse(payload) }); }
        };
        app.handleRequest(req, res);
      });
    }

    const liveness = await makeRequest('/api/v1/health/liveness');
    assert.equal(liveness.status, 200);
    assert.equal(liveness.body.status, 'UP');

    const readiness = await makeRequest('/api/v1/health/readiness');
    assert.equal(readiness.status, 200);
    assert.equal(readiness.body.status, 'READY');

    const diagnostics = await makeRequest('/api/v1/health/diagnostics');
    assert.equal(diagnostics.status, 200);
    assert.equal(diagnostics.body.status, 'HEALTHY');
    assert.equal(diagnostics.body.dependencies.database.status, 'UP');
  });

  console.log('\n===============================================================');
  console.log(`  PHASE 11 TEST SUMMARY: ${passedTests} PASSED, ${totalTests - passedTests} FAILED`);
  console.log('===============================================================\n');

  if (passedTests === totalTests) {
    process.exit(0);
  } else {
    process.exit(1);
  }
})();
