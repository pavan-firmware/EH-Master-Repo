'use strict';

/**
 * EH Home — Phase 19 Energy Intelligence & Telemetry Test Suite
 */

const assert = require('assert');
const { createApp } = require('../src/app');
const { DatabaseClient } = require('../src/shared/db-client');

let passedTests = 0;
let totalTests = 0;

async function test(name, fn) {
  totalTests++;
  try {
    await fn();
    console.log(`[PASS] ${name}`);
    passedTests++;
  } catch (err) {
    console.error(`[FAIL] ${name}:`, err);
  }
}

async function run() {
  console.log('===============================================================');
  console.log('  EH HOME — PHASE 19 ENERGY INTELLIGENCE TEST SUITE');
  console.log('===============================================================\n');

  const db = new DatabaseClient();
  const app = createApp({ db });
  const {
    userRepo,
    homeRepo,
    roomRepo,
    deviceRepo,
    telemetryRepo,
    aggregateRepo,
    thresholdRepo,
    energyEventRepo,
    deviceStateRepo,
    notificationRepo
  } = app.repositories;

  const { energyService, authService } = app.services;

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
    email: 'energy_owner@example.com',
    passwordHash: 'hash_pw_owner19',
    name: 'Energy Home Owner'
  });

  const memberUser = await userRepo.createUser({
    id: '0194fe23-7a1b-7890-a123-000000000002',
    email: 'energy_member@example.com',
    passwordHash: 'hash_pw_member19',
    name: 'Energy Member'
  });

  const outsiderUser = await userRepo.createUser({
    id: '0194fe23-7a1b-7890-a123-000000000003',
    email: 'energy_outsider@example.com',
    passwordHash: 'hash_pw_outsider19',
    name: 'Energy Outsider'
  });

  const homeA = await homeRepo.createHome({
    id: '0194fe23-7a1b-7890-a123-111111111111',
    owner_id: ownerUser.id,
    name: 'Eco Manor'
  });
  await homeRepo.addMembership({
    home_id: homeA.id,
    user_id: memberUser.id,
    role: 'MEMBER'
  });

  const homeB = await homeRepo.createHome({
    id: '0194fe23-7a1b-7890-a123-222222222222',
    owner_id: outsiderUser.id,
    name: 'Solar Villa'
  });

  const kitchenRoom = await roomRepo.createRoom({
    id: '0194fe23-7a1b-7890-a123-333333333331',
    home_id: homeA.id,
    name: 'Kitchen'
  });

  const livingRoom = await roomRepo.createRoom({
    id: '0194fe23-7a1b-7890-a123-333333333332',
    home_id: homeA.id,
    name: 'Living Room'
  });

  // Setup Devices
  const devKitchenOven = await deviceRepo.createDevice({
    id: '0194fe23-7a1b-7890-a123-444444444441',
    serial_number: 'SN-OVEN-001',
    product_variant_id: 'eh-smart-switch-3x',
    hardware_revision: 'HW_1_0',
    firmware_family: 'esp32-switch-platform',
    firmware_version: '1.0.0'
  });
  await deviceRepo.claimDevice({
    device_id: devKitchenOven.id,
    home_id: homeA.id,
    room_id: kitchenRoom.id,
    custom_name: 'Smart Oven'
  });
  await deviceStateRepo.updateDeviceConnection(devKitchenOven.id, 'ONLINE');

  const devLivingAC = await deviceRepo.createDevice({
    id: '0194fe23-7a1b-7890-a123-444444444442',
    serial_number: 'SN-AC-002',
    product_variant_id: 'eh-smart-switch-3x',
    hardware_revision: 'HW_1_0',
    firmware_family: 'esp32-switch-platform',
    firmware_version: '1.0.0'
  });
  await deviceRepo.claimDevice({
    device_id: devLivingAC.id,
    home_id: homeA.id,
    room_id: livingRoom.id,
    custom_name: 'Living Room AC'
  });
  await deviceStateRepo.updateDeviceConnection(devLivingAC.id, 'ONLINE');

  const devHomeBHeater = await deviceRepo.createDevice({
    id: '0194fe23-7a1b-7890-a123-444444444443',
    serial_number: 'SN-HEAT-003',
    product_variant_id: 'eh-smart-switch-3x',
    hardware_revision: 'HW_1_0',
    firmware_family: 'esp32-switch-platform',
    firmware_version: '1.0.0'
  });
  await deviceRepo.claimDevice({
    device_id: devHomeBHeater.id,
    home_id: homeB.id,
    room_id: null,
    custom_name: 'Guest Heater'
  });
  await deviceStateRepo.updateDeviceConnection(devHomeBHeater.id, 'ONLINE');

  // ---------------------------------------------------------------------------
  // Test 1: Telemetry Ingestion & Fixed-Point Normalization
  // ---------------------------------------------------------------------------
  await test('1. Telemetry Ingestion & Fixed-Point Normalization', async () => {
    const rawTelemetry = {
      deviceId: devKitchenOven.id,
      channelIndex: 1,
      v_mv: 230500, // 230.5V
      i_ma: 8200,   // 8.2A
      p_mw: 1890100, // 1890.1W
      e_tot_wh: 12500, // 12.5 kWh
      e_int_mwh: 2600, // 2.6 Wh
      freq_mhz: 50010, // 50.01 Hz
      pf_x1000: 990, // 0.99
      flags: 0,
      sequenceNumber: 101,
      timestamp: new Date().toISOString()
    };

    const res = await energyService.ingestTelemetry(rawTelemetry);
    assert.strictEqual(res.status, 'INGESTED');
    assert.ok(res.measurementId);

    const latest = await telemetryRepo.getLatestMeasurement(devKitchenOven.id, 1);
    assert.ok(latest);
    assert.strictEqual(latest.v_mv, 230500);
    assert.strictEqual(latest.p_mw, 1890100);
    assert.strictEqual(latest.sequence_number, 101);
  });

  // ---------------------------------------------------------------------------
  // Test 2: Duplicate Detection & Monotonic/Reset Handling
  // ---------------------------------------------------------------------------
  await test('2. Duplicate Detection & Monotonic/Reset Handling', async () => {
    // Attempt duplicate sequence replay
    const duplicate = {
      deviceId: devKitchenOven.id,
      channelIndex: 1,
      v_mv: 230500,
      i_ma: 8200,
      p_mw: 1890100,
      e_tot_wh: 12500,
      freq_mhz: 50010,
      pf_x1000: 990,
      flags: 0,
      sequenceNumber: 101, // already seen
      timestamp: new Date().toISOString()
    };

    const dupRes = await energyService.ingestTelemetry(duplicate);
    assert.strictEqual(dupRes.status, 'DUPLICATE_IGNORED');

    // Ingest counter reset
    const resetTelem = {
      deviceId: devKitchenOven.id,
      channelIndex: 1,
      v_mv: 230400,
      i_ma: 4000,
      p_mw: 920000,
      e_tot_wh: 50, // dropped from 12500 to 50 (reset)
      e_int_mwh: 1200,
      freq_mhz: 50000,
      pf_x1000: 980,
      flags: 1, // COUNTER_RESET
      sequenceNumber: 102,
      timestamp: new Date().toISOString()
    };

    const resetRes = await energyService.ingestTelemetry(resetTelem);
    assert.strictEqual(resetRes.status, 'INGESTED');

    // Verify counter reset event was recorded
    const events = await energyEventRepo.getEventsForHome(homeA.id);
    const resetEvent = events.find(e => e.event_type === 'COUNTER_RESET');
    assert.ok(resetEvent);
    assert.strictEqual(resetEvent.device_id, devKitchenOven.id);
  });

  // ---------------------------------------------------------------------------
  // Test 3: Hourly & Daily Aggregation Engine
  // ---------------------------------------------------------------------------
  await test('3. Hourly & Daily Aggregation Engine', async () => {
    const aggregates = await aggregateRepo.getAggregates(devKitchenOven.id, { bucketType: 'HOUR' });
    assert.ok(aggregates.length > 0);
    const hourBucket = aggregates[0];
    assert.strictEqual(hourBucket.device_id, devKitchenOven.id);
    assert.strictEqual(hourBucket.bucket_type, 'HOUR');
    assert.ok(hourBucket.sample_count >= 2);
    assert.ok(hourBucket.peak_power_w >= 1890.0);
    assert.strictEqual(hourBucket.data_quality, 'GOOD');
  });

  // ---------------------------------------------------------------------------
  // Test 4: Device, Room & Home Analytics Hierarchy
  // ---------------------------------------------------------------------------
  await test('4. Device, Room & Home Analytics Hierarchy', async () => {
    // Ingest for AC in living room
    await energyService.ingestTelemetry({
      deviceId: devLivingAC.id,
      channelIndex: 1,
      v_mv: 230000,
      i_ma: 5000,
      p_mw: 1150000, // 1150W
      e_tot_wh: 3400, // 3.4 kWh
      freq_mhz: 50000,
      pf_x1000: 990,
      flags: 0,
      sequenceNumber: 1,
      timestamp: new Date().toISOString()
    });

    // 1. Device Summary
    const devSummary = await energyService.getDeviceSummary(devLivingAC.id, 'today');
    assert.strictEqual(devSummary.entityType, 'device');
    assert.strictEqual(devSummary.currentPowerW, 1150);
    assert.ok(devSummary.totalEnergyKwh > 0);

    // 2. Room Summary
    const roomSummary = await energyService.getRoomSummary(livingRoom.id, 'today');
    assert.strictEqual(roomSummary.entityType, 'room');
    assert.strictEqual(roomSummary.devicesCount, 1);
    assert.strictEqual(roomSummary.currentPowerW, 1150);

    // 3. Home Summary
    const homeSummary = await energyService.getHomeSummary(homeA.id, 'today');
    assert.strictEqual(homeSummary.entityType, 'home');
    assert.strictEqual(homeSummary.devicesCount, 2);
    assert.strictEqual(homeSummary.roomsCount, 2);
    assert.ok(homeSummary.currentPowerW >= 2000); // Oven (920W) + AC (1150W)
    assert.ok(homeSummary.costEstimate >= 0);
  });

  // ---------------------------------------------------------------------------
  // Test 5: Period Comparisons, Trends & Top Consumers
  // ---------------------------------------------------------------------------
  await test('5. Period Comparisons, Trends & Top Consumers', async () => {
    const trends = await energyService.getHomeTrends(homeA.id, { period: 'week', interval: 'day' });
    assert.strictEqual(trends.homeId, homeA.id);
    assert.ok(Array.isArray(trends.points));

    const topConsumers = await energyService.getTopConsumers(homeA.id, { period: 'today', limit: 5 });
    assert.strictEqual(topConsumers.homeId, homeA.id);
    assert.ok(topConsumers.topDevices.length >= 2);
    assert.ok(topConsumers.topRooms.length >= 2);
    assert.strictEqual(topConsumers.topDevices[0].type, 'device');
    assert.strictEqual(topConsumers.topRooms[0].type, 'room');
  });

  // ---------------------------------------------------------------------------
  // Test 6: Energy Threshold Evaluation, Anomaly Detection & Alerts
  // ---------------------------------------------------------------------------
  await test('6. Energy Threshold Evaluation, Anomaly Detection & Alerts', async () => {
    // Configure home threshold: 2000W high power limit
    await thresholdRepo.upsertThreshold({
      homeId: homeA.id,
      highPowerW: 2000,
      dailyEnergyKwh: 20.0,
      costPerKwh: 0.18,
      currency: 'USD'
    });

    // Ingest power spike: 2500W on Oven
    await energyService.ingestTelemetry({
      deviceId: devKitchenOven.id,
      channelIndex: 1,
      v_mv: 230000,
      i_ma: 10900,
      p_mw: 2507000, // 2507W > 2000W
      e_tot_wh: 14000,
      e_int_mwh: 5000,
      freq_mhz: 50000,
      pf_x1000: 990,
      flags: 0,
      sequenceNumber: 201,
      timestamp: new Date().toISOString()
    });

    // Verify threshold exceeded event was persisted
    const events = await energyEventRepo.getEventsForHome(homeA.id);
    const spikeEvent = events.find(e => e.event_type === 'HIGH_POWER_EXCEEDED');
    assert.ok(spikeEvent);
    assert.ok(spikeEvent.value_recorded >= 2500);

    // Verify Notification was generated
    const notifications = await notificationRepo.findHomeNotifications(homeA.id);
    const energyNotif = notifications.find(n => n.type === 'ENERGY_ALERT');
    assert.ok(energyNotif);
    assert.strictEqual(energyNotif.title, 'High Power Alert');
  });

  // ---------------------------------------------------------------------------
  // Test 7: Multi-Home Isolation & Capability-Based Access Control
  // ---------------------------------------------------------------------------
  await test('7. Multi-Home Isolation & Capability-Based Access Control', async () => {
    // 1. User B (outsider) attempting to view Home A energy summary -> 403 Forbidden
    const outsiderReq = {
      method: 'GET',
      path: `/api/v1/energy/homes/${homeA.id}/summary`
    };
    const denied = await app.services.energyService ? await app.handleRequest : null;

    // Simulate via request handler
    let resCode = 0;
    let resBody = null;
    const fakeRes = {
      writeHead: (code, headers) => { resCode = code; },
      end: (content) => { resBody = JSON.parse(content); }
    };

    // User from Home B trying to access Home A
    await app.handleRequest({
      url: `/api/v1/energy/homes/${homeA.id}/summary`,
      method: 'GET',
      headers: {
        authorization: `Bearer ${authService.signAccessToken(outsiderUser)}`
      },
      on: (ev, cb) => { if (ev === 'end') cb(); }
    }, fakeRes);

    assert.strictEqual(resCode, 403);
    assert.strictEqual(resBody.success, false);

    // 2. Member User trying to mutate energy threshold (requires canManageHome) -> 403
    let mutateCode = 0;
    let mutateBody = null;
    const mutateRes = {
      writeHead: (code) => { mutateCode = code; },
      end: (content) => { mutateBody = JSON.parse(content); }
    };

    await app.handleRequest({
      url: `/api/v1/energy/homes/${homeA.id}/thresholds`,
      method: 'POST',
      headers: {
        authorization: `Bearer ${authService.signAccessToken(memberUser)}`,
        'content-type': 'application/json'
      },
      body: { highPowerW: 3500 },
      on: (ev, cb) => { if (ev === 'end') cb(); }
    }, mutateRes);

    assert.strictEqual(mutateCode, 403);
    assert.strictEqual(mutateBody.success, false);
  });

  // ---------------------------------------------------------------------------
  // Test 8: Data Retention Pruning & Zero Secret Leakage
  // ---------------------------------------------------------------------------
  await test('8. Data Retention Pruning & Zero Secret Leakage', async () => {
    // Insert an old telemetry measurement (45 days old)
    const oldTs = new Date(Date.now() - 45 * 86400 * 1000).toISOString();
    await telemetryRepo.recordMeasurement({
      deviceId: devKitchenOven.id,
      channelIndex: 1,
      v_mv: 230000,
      i_ma: 1000,
      p_mw: 230000,
      e_tot_wh: 100,
      e_int_mwh: 100,
      freq_mhz: 50000,
      pf_x1000: 950,
      flags: 0,
      sequenceNumber: 1,
      timestamp: oldTs
    });

    const cutoffIso = new Date(Date.now() - 30 * 86400 * 1000).toISOString();
    const purgedCount = await telemetryRepo.purgeOlderThan(cutoffIso);
    assert.ok(purgedCount >= 1);

    // Verify aggregates still exist
    const hourAggs = await aggregateRepo.getAggregates(devKitchenOven.id, { bucketType: 'HOUR' });
    assert.ok(hourAggs.length > 0);

    // Verify Zero Secret Leakage in telemetry records & summaries
    const summary = await energyService.getHomeSummary(homeA.id, 'today');
    const summaryJson = JSON.stringify(summary);
    assert.strictEqual(summaryJson.includes('privateKey'), false);
    assert.strictEqual(summaryJson.includes('passwordHash'), false);
    assert.strictEqual(summaryJson.includes('sessionKey'), false);
  });

  console.log('\n===============================================================');
  console.log(`  PHASE 19 TEST SUMMARY: ${passedTests} PASSED, ${totalTests - passedTests} FAILED`);
  console.log('===============================================================\n');

  if (passedTests === totalTests) {
    process.exit(0);
  } else {
    process.exit(1);
  }
}

run().catch(err => {
  console.error('Test execution failed:', err);
  process.exit(1);
});
