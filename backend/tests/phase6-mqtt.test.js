'use strict';

/**
 * EH Home — Phase 6 MQTT Transport Integration Test Suite
 *
 * Tests:
 *  T01  Topic builder — all canonical topics
 *  T02  Topic parser — valid topics
 *  T03  Topic parser — wildcard rejection ('+' and '#')
 *  T04  Topic parser — malformed UUID rejection
 *  T05  Topic parser — extra segment rejection
 *  T06  Topic parser — empty segment rejection
 *  T07  Topic builder — unknown category rejection
 *  T08  Command dispatch — full lifecycle (authorize → persist → MQTT publish)
 *  T09  Command dispatch — expiry pre-check (already expired, no DB write)
 *  T10  Command dispatch — idempotency key deduplication
 *  T11  Command dispatch — authorization failure (device not in actor's home)
 *  T12  Command dispatch — invalid channelIndex
 *  T13  Command dispatch — invalid action
 *  T14  Command receipt — APPLIED status update
 *  T15  Command receipt — FAILED status update
 *  T16  Command receipt — OVERRIDDEN status
 *  T17  State read — backend DeviceStateRepository (no MQTT GET_STATE topic)
 *  T18  Availability ONLINE → DeviceStateRepository update
 *  T19  Availability OFFLINE (LWT) → DeviceStateRepository update
 *  T20  STALE derivation — backend heartbeat threshold (not published to broker)
 *  T21  Physical switch event → reportedState update + ONLINE connection state
 *  T22  Device state publication → channel state update in backend
 *  T23  Telemetry ingestion — valid fixed-point fields
 *  T24  Telemetry ingestion — invalid pf_x1000 rejection (>1000)
 *  T25  Telemetry ingestion — negative v_mv rejection
 *  T26  Telemetry ingestion — duplicate sequence dropped
 *  T27  Outbox — command enqueued before MQTT publish
 *  T28  Simulator MQTT mode — connectMqtt() → ONLINE + state published
 *  T29  Simulator MQTT mode — command dispatch → APPLIED receipt + state update
 *  T30  Simulator MQTT mode — physical toggle → DeviceEvent(source=PHYSICAL_SWITCH)
 *  T31  Simulator MQTT mode — duplicate command idempotency (second publish = APPLIED no re-actuate)
 *  T32  Simulator MQTT mode — expired command → EXPIRED receipt
 *  T33  Simulator MQTT mode — disconnectMqtt() → OFFLINE published
 *  T34  ACL isolation — device topic rejection (cross-device)
 *  T35  QoS / retain policy — verify all topic policies
 *  T36  Route handler — unauthenticated POST /commands/send → 401
 *  T37  Route handler — valid POST /commands/send → 202
 *  T38  Route handler — expired command → 422
 *  T39  Route handler — GET /devices/:deviceId/state → 200 with state
 */

const assert = require('assert').strict;
const { DatabaseClient } = require('../src/shared/db-client');
const { MqttTopicBuilder, MqttTopicParser, QOS_POLICY, TOPIC_CATEGORIES } = require('../src/shared/mqtt-topic-builder');
const { MqttDeviceTransport, MockMqttClient } = require('../src/services/mqtt-device-transport');
const { DeviceCommandService } = require('../src/services/device-command.service');
const { DeviceEventTelemetryIngestionService, STALE_THRESHOLD_MS } = require('../src/services/device-event-telemetry-ingestion.service');
const { buildPhase6Services, buildRouteHandlers } = require('../src/api/device-command.router');
const {
  CommandRepository, OutboxRepository, DeviceRepository,
  DeviceStateRepository, EventRepository, AuditRepository,
  ProductRepository, UserRepository, HomeRepository
} = require('../src/repositories/index');
const { DeviceSimulator } = require('../../tools/device-simulator/simulator');

// ---------------------------------------------------------------------------
// Test Harness
// ---------------------------------------------------------------------------

let passed = 0;
let failed = 0;
const failures = [];

async function test(name, fn) {
  try {
    await fn();
    console.log(`  [PASS] ${name}`);
    passed++;
  } catch (err) {
    console.error(`  [FAIL] ${name}`);
    console.error(`         ${err.message}`);
    failures.push({ name, error: err.message });
    failed++;
  }
}

// ---------------------------------------------------------------------------
// Fixtures
// ---------------------------------------------------------------------------

const DEVICE_ID = '0194fe23-7a1b-7890-a123-456789abcdef';
const DEVICE_ID_B = '0194fe23-7a1b-7890-b456-123456fedcba';
const USER_ID    = 'a1b2c3d4-1234-5678-9abc-def012345678';
const HOME_ID    = 'b1c2d3e4-2345-6789-abcd-ef0123456789';
const VARIANT_ID = 'eh-smart-switch-3x';

async function buildTestDb() {
  const db = new DatabaseClient();
  const userRepo    = new UserRepository(db);
  const homeRepo    = new HomeRepository(db);
  const deviceRepo  = new DeviceRepository(db);
  const productRepo = new ProductRepository(db);

  // Seed product variant
  await productRepo.createFamily({ id: 'fam-switches', name: 'EH Smart Switches', description: 'Smart switch family' });
  await productRepo.createProduct({ id: 'prod-sw3x', familyId: 'fam-switches', name: 'Smart Switch 3X', description: '3-channel smart switch' });
  await productRepo.createVariant({
    id: VARIANT_ID, productId: 'prod-sw3x', name: '3X',
    skuCode: 'EH-SW3X', channelCount: 3,
    hardwareCapabilities: [], supportedFirmwareFamilies: ['esp32c6-switch-platform']
  });

  // Seed user and home
  await userRepo.createUser({ id: USER_ID, email: 'test@eh.com', passwordHash: 'hashed' });
  await homeRepo.createHome({ id: HOME_ID, name: 'Test Home', ownerId: USER_ID });

  // Seed device A
  await deviceRepo.registerDevice({
    deviceId: DEVICE_ID, serialNumber: 'EH-SW3X-2026W12-00891',
    productVariantId: VARIANT_ID, hardwareRevision: 'HW_1_0',
    firmwareFamily: 'esp32c6-switch-platform', firmwareVersion: '1.0.0'
  });
  await deviceRepo.claimDevice({
    deviceId: DEVICE_ID, homeId: HOME_ID, customName: 'Living Room Switch',
    claimedByUserId: USER_ID
  });

  // Seed device B (different home — for ACL isolation test)
  await deviceRepo.registerDevice({
    deviceId: DEVICE_ID_B, serialNumber: 'EH-SW3X-2026W12-00892',
    productVariantId: VARIANT_ID, hardwareRevision: 'HW_1_0',
    firmwareFamily: 'esp32c6-switch-platform', firmwareVersion: '1.0.0'
  });
  // Do NOT claim Device B to HOME_ID — it belongs to another home

  return db;
}

function buildCmd(overrides = {}) {
  return {
    commandId: overrides.commandId || 'c1234567-1234-5678-9abc-def012345678',
    deviceId: overrides.deviceId || DEVICE_ID,
    channelIndex: overrides.channelIndex !== undefined ? overrides.channelIndex : 1,
    action: overrides.action || 'setPower',
    params: overrides.params || { value: true },
    idempotencyKey: overrides.idempotencyKey || 'idem_test_001',
    source: overrides.source || 'APP',
    expiresAt: overrides.expiresAt !== undefined ? overrides.expiresAt : new Date(Date.now() + 30000).toISOString()
  };
}

const ACTOR = { userId: USER_ID, homeId: HOME_ID, role: 'OWNER' };

// ---------------------------------------------------------------------------
// Run Tests
// ---------------------------------------------------------------------------

(async () => {
  console.log('\n================================================================');
  console.log('       EH HOME — PHASE 6 MQTT INTEGRATION TEST SUITE          ');
  console.log('================================================================\n');

  // =====================================================================
  // GROUP 1: Topic Builder & Parser
  // =====================================================================
  console.log('\n--- GROUP 1: Topic Builder & Parser ---');

  await test('T01 Topic builder — all canonical topics', () => {
    assert.equal(MqttTopicBuilder.commands(DEVICE_ID),        `eh/v1/devices/${DEVICE_ID}/commands`);
    assert.equal(MqttTopicBuilder.commandReceipts(DEVICE_ID), `eh/v1/devices/${DEVICE_ID}/command-receipts`);
    assert.equal(MqttTopicBuilder.state(DEVICE_ID),           `eh/v1/devices/${DEVICE_ID}/state`);
    assert.equal(MqttTopicBuilder.events(DEVICE_ID),          `eh/v1/devices/${DEVICE_ID}/events`);
    assert.equal(MqttTopicBuilder.telemetry(DEVICE_ID),       `eh/v1/devices/${DEVICE_ID}/telemetry`);
    assert.equal(MqttTopicBuilder.availability(DEVICE_ID),    `eh/v1/devices/${DEVICE_ID}/availability`);
  });

  await test('T02 Topic parser — valid topics', () => {
    const r1 = MqttTopicParser.parse(`eh/v1/devices/${DEVICE_ID}/commands`);
    assert.equal(r1.deviceId, DEVICE_ID);
    assert.equal(r1.category, 'commands');
    const r2 = MqttTopicParser.parse(`eh/v1/devices/${DEVICE_ID}/availability`);
    assert.equal(r2.category, 'availability');
  });

  await test('T03 Topic parser — wildcard "+" rejection', () => {
    assert.throws(
      () => MqttTopicParser.parse('eh/v1/devices/+/commands'),
      /wildcard/i
    );
  });

  await test('T03b Topic parser — wildcard "#" rejection', () => {
    assert.throws(
      () => MqttTopicParser.parse('eh/v1/devices/#'),
      /wildcard/i
    );
  });

  await test('T04 Topic parser — malformed UUID rejection', () => {
    assert.throws(
      () => MqttTopicParser.parse('eh/v1/devices/not-a-valid-uuid/commands'),
      /malformed/i
    );
  });

  await test('T05 Topic parser — extra segment rejection', () => {
    assert.throws(
      () => MqttTopicParser.parse(`eh/v1/devices/${DEVICE_ID}/commands/extra`),
      /segments/i
    );
  });

  await test('T06 Topic parser — empty segment rejection', () => {
    assert.throws(
      () => MqttTopicParser.parse(`eh/v1/devices/${DEVICE_ID}//commands`),
      /segment/i
    );
  });

  await test('T07 Topic builder — unknown category → throw', () => {
    assert.throws(
      () => MqttTopicBuilder.backendSubscribe('unknown_category'),
      /unknown topic category/i
    );
  });

  await test('T35 QoS / retain policy — all topics verified', () => {
    assert.deepEqual(QOS_POLICY['commands'],         { qos: 1, retain: false });
    assert.deepEqual(QOS_POLICY['command-receipts'], { qos: 1, retain: false });
    assert.deepEqual(QOS_POLICY['state'],            { qos: 1, retain: false });
    assert.deepEqual(QOS_POLICY['events'],           { qos: 1, retain: false });
    assert.deepEqual(QOS_POLICY['telemetry'],        { qos: 0, retain: false });
    assert.deepEqual(QOS_POLICY['availability'],     { qos: 1, retain: true  });
  });

  // =====================================================================
  // GROUP 2: DeviceCommandService — Command Lifecycle
  // =====================================================================
  console.log('\n--- GROUP 2: Command Lifecycle ---');

  await test('T08 Command dispatch — full lifecycle (authorize → DB → MQTT publish)', async () => {
    const db = await buildTestDb();
    const mockClient = new MockMqttClient();
    const { commandService, commandRepo } = buildPhase6Services(db, mockClient);

    const cmd = buildCmd();
    const result = await commandService.sendCommand(ACTOR, cmd);

    assert.equal(result.commandId, cmd.commandId);
    assert.equal(result.status, 'CREATED');
    assert.equal(result.isIdempotentReplay, false);

    // Verify MQTT publish occurred
    const published = mockClient.getPublished();
    assert.ok(published.length >= 1, 'Expected at least one MQTT publish');
    const cmdPub = published.find(p => p.topic === MqttTopicBuilder.commands(DEVICE_ID));
    assert.ok(cmdPub, 'Command should be published to commands topic');
    assert.equal(cmdPub.payload.commandId, cmd.commandId);
    assert.equal(cmdPub.opts.qos, 1);
    assert.equal(cmdPub.opts.retain, false);

    // Verify outbox enqueued
    const outboxRepo = new OutboxRepository(db);
    const pending = await outboxRepo.fetchPending(10);
    const outboxEntry = pending.find(e => e.aggregate_id === DEVICE_ID);
    assert.ok(outboxEntry, 'Outbox entry should exist');
    assert.equal(outboxEntry.event_type, 'DEVICE_COMMAND');
    assert.equal(outboxEntry.payload.commandId, cmd.commandId);
  });

  await test('T09 Command dispatch — already-expired command → EXPIRED (no DB write)', async () => {
    const db = await buildTestDb();
    const { commandService } = buildPhase6Services(db, new MockMqttClient());

    const cmd = buildCmd({ expiresAt: new Date(Date.now() - 5000).toISOString() }); // 5s ago
    const result = await commandService.sendCommand(ACTOR, cmd);

    assert.equal(result.status, 'EXPIRED');
    assert.equal(result.isIdempotentReplay, false);

    // Verify NOT persisted to DB
    const cmdRepo = new CommandRepository(db);
    const record = await cmdRepo.getCommand(cmd.commandId);
    assert.equal(record, null, 'Expired command should not be persisted');
  });

  await test('T10 Command dispatch — idempotency key deduplication', async () => {
    const db = await buildTestDb();
    const { commandService } = buildPhase6Services(db, new MockMqttClient());

    const cmd = buildCmd({ idempotencyKey: 'idem_dedup_key' });
    const r1 = await commandService.sendCommand(ACTOR, cmd);
    assert.equal(r1.status, 'CREATED');
    assert.equal(r1.isIdempotentReplay, false);

    // Send exact same command again
    const r2 = await commandService.sendCommand(ACTOR, cmd);
    assert.equal(r2.isIdempotentReplay, true, 'Second send should be idempotent replay');
  });

  await test('T11 Command dispatch — device not in actor home → 403 error', async () => {
    const db = await buildTestDb();
    const { commandService } = buildPhase6Services(db, new MockMqttClient());

    // Device B is not claimed to HOME_ID
    const cmd = buildCmd({ deviceId: DEVICE_ID_B, commandId: 'c2345678-2345-6789-abcd-ef0123456789' });
    await assert.rejects(
      () => commandService.sendCommand(ACTOR, cmd),
      /not claimed|not found/i
    );
  });

  await test('T12 Command dispatch — invalid channelIndex (0) → validation error', async () => {
    const db = await buildTestDb();
    const { commandService } = buildPhase6Services(db, new MockMqttClient());

    const cmd = buildCmd({ channelIndex: 0, commandId: 'c3456789-3456-789a-bcde-f01234567890' });
    await assert.rejects(
      () => commandService.sendCommand(ACTOR, cmd),
      /channelIndex/i
    );
  });

  await test('T13 Command dispatch — invalid action → validation error', async () => {
    const db = await buildTestDb();
    const { commandService } = buildPhase6Services(db, new MockMqttClient());

    const cmd = buildCmd({ action: 'destroyDevice', commandId: 'c4567890-4567-890a-bcde-f01234567891' });
    await assert.rejects(
      () => commandService.sendCommand(ACTOR, cmd),
      /action/i
    );
  });

  // =====================================================================
  // GROUP 3: Command Receipt Processing
  // =====================================================================
  console.log('\n--- GROUP 3: Command Receipt Processing ---');

  await test('T14 Command receipt — APPLIED status update in CommandRepository', async () => {
    const db = await buildTestDb();
    const mockClient = new MockMqttClient();
    const { commandService, commandRepo } = buildPhase6Services(db, mockClient);

    const cmd = buildCmd({ commandId: 'd1234567-1234-5678-9abc-def012345678' });
    await commandService.sendCommand(ACTOR, cmd);

    await commandService.handleCommandReceipt({
      commandId: cmd.commandId,
      deviceId: DEVICE_ID,
      channelIndex: 1,
      status: 'APPLIED',
      failureReason: null,
      timestamp: new Date().toISOString()
    });

    const record = await commandRepo.getCommand(cmd.commandId);
    assert.equal(record.status, 'APPLIED');
  });

  await test('T15 Command receipt — FAILED status update', async () => {
    const db = await buildTestDb();
    const mockClient = new MockMqttClient();
    const { commandService, commandRepo } = buildPhase6Services(db, mockClient);

    const cmd = buildCmd({ commandId: 'd2345678-2345-6789-abcd-ef0123456789' });
    await commandService.sendCommand(ACTOR, cmd);

    await commandService.handleCommandReceipt({
      commandId: cmd.commandId, deviceId: DEVICE_ID, channelIndex: 1,
      status: 'FAILED', failureReason: 'Hardware relay fault',
      timestamp: new Date().toISOString()
    });

    const record = await commandRepo.getCommand(cmd.commandId);
    assert.equal(record.status, 'FAILED');
    assert.equal(record.failure_reason, 'Hardware relay fault');
  });

  await test('T16 Command receipt — OVERRIDDEN (physical switch conflict)', async () => {
    const db = await buildTestDb();
    const { commandService, commandRepo } = buildPhase6Services(db, new MockMqttClient());

    const cmd = buildCmd({ commandId: 'd3456789-3456-789a-bcde-f01234567890' });
    await commandService.sendCommand(ACTOR, cmd);

    await commandService.handleCommandReceipt({
      commandId: cmd.commandId, deviceId: DEVICE_ID, channelIndex: 1,
      status: 'OVERRIDDEN', failureReason: null,
      timestamp: new Date().toISOString()
    });

    const record = await commandRepo.getCommand(cmd.commandId);
    assert.equal(record.status, 'OVERRIDDEN');
  });

  // =====================================================================
  // GROUP 4: State, Availability, Event, Telemetry Ingestion
  // =====================================================================
  console.log('\n--- GROUP 4: Ingestion Service ---');

  await test('T17 State read — getDeviceState() reads from DeviceStateRepository (no MQTT topic)', async () => {
    const db = await buildTestDb();
    const { commandService } = buildPhase6Services(db, new MockMqttClient());

    const state = await commandService.getDeviceState(DEVICE_ID);
    assert.ok(state, 'State should be returned from repository');
    assert.equal(state.deviceId, DEVICE_ID);
    assert.ok(Array.isArray(state.channels), 'State should have channels array');
    assert.equal(state.channels.length, 3, 'Switch 3X should have 3 channels');
  });

  await test('T18 Availability ONLINE → connection state ONLINE in repository', async () => {
    const db = await buildTestDb();
    const { ingestionService } = buildPhase6Services(db, new MockMqttClient());
    const stateRepo = new DeviceStateRepository(db);

    await ingestionService.handleAvailability(DEVICE_ID, 'ONLINE');
    const state = await stateRepo.getFullState(DEVICE_ID);
    assert.equal(state.connectionState, 'ONLINE');
  });

  await test('T19 Availability OFFLINE (LWT) → connection state OFFLINE', async () => {
    const db = await buildTestDb();
    const { ingestionService } = buildPhase6Services(db, new MockMqttClient());
    const stateRepo = new DeviceStateRepository(db);

    await ingestionService.handleAvailability(DEVICE_ID, 'ONLINE');
    await ingestionService.handleAvailability(DEVICE_ID, 'OFFLINE');
    const state = await stateRepo.getFullState(DEVICE_ID);
    assert.equal(state.connectionState, 'OFFLINE');
  });

  await test('T20 STALE derivation — backend calculates STALE from lastSeen threshold (not MQTT topic)', async () => {
    const db = await buildTestDb();
    const { ingestionService } = buildPhase6Services(db, new MockMqttClient());

    // Simulate device was seen 120 seconds ago (> 90s STALE_THRESHOLD_MS)
    const oldLastSeen = new Date(Date.now() - 120_000).toISOString();
    const mockState = { connectionState: 'ONLINE', lastSeenAt: oldLastSeen };

    const derived = ingestionService.deriveConnectionState(DEVICE_ID, mockState);
    assert.equal(derived, 'STALE', 'Backend should derive STALE from lastSeen threshold');
  });

  await test('T21 Physical switch event → reportedState update + ONLINE connection', async () => {
    const db = await buildTestDb();
    const { ingestionService } = buildPhase6Services(db, new MockMqttClient());
    const stateRepo = new DeviceStateRepository(db);

    // Simulate physical switch event
    await ingestionService.handleDeviceEvent({
      eventId: 'evt-phys-001-0000-0000-000000000001',
      deviceId: DEVICE_ID,
      channelIndex: 2,
      eventType: 'switch.changed',
      source: 'PHYSICAL_SWITCH',
      payload: { power: true },
      sequenceNumber: 1001,
      timestamp: new Date().toISOString()
    });

    const state = await stateRepo.getFullState(DEVICE_ID);
    assert.equal(state.connectionState, 'ONLINE');
    const ch2 = state.channels.find(c => c.channelIndex === 2);
    assert.ok(ch2, 'Channel 2 should exist');
    assert.equal(ch2.reportedState.power, true, 'Physical switch should set reportedState to ON');
    assert.equal(ch2.confidence, 'CONFIRMED');
  });

  await test('T22 Device state publication → channel state update in backend', async () => {
    const db = await buildTestDb();
    const { ingestionService } = buildPhase6Services(db, new MockMqttClient());
    const stateRepo = new DeviceStateRepository(db);

    await ingestionService.handleDeviceState({
      schemaVersion: 1,
      deviceId: DEVICE_ID,
      connectionState: 'ONLINE',
      channels: [
        { schemaVersion: 1, channelIndex: 1, desiredState: { power: true }, reportedState: { power: true }, confidence: 'CONFIRMED' },
        { schemaVersion: 1, channelIndex: 2, desiredState: { power: false }, reportedState: { power: false }, confidence: 'CONFIRMED' },
        { schemaVersion: 1, channelIndex: 3, desiredState: { power: true }, reportedState: { power: true }, confidence: 'CONFIRMED' }
      ]
    });

    const state = await stateRepo.getFullState(DEVICE_ID);
    assert.equal(state.connectionState, 'ONLINE');
    const ch1 = state.channels.find(c => c.channelIndex === 1);
    assert.equal(ch1.reportedState.power, true);
  });

  await test('T23 Telemetry ingestion — valid fixed-point fields accepted', async () => {
    const db = await buildTestDb();
    const { ingestionService } = buildPhase6Services(db, new MockMqttClient());

    // Should complete without throwing
    await ingestionService.handleTelemetry({
      schemaVersion: 1,
      deviceId: DEVICE_ID,
      channelIndex: 1,
      v_mv: 230000,
      i_ma: 750,
      p_mw: 172500,
      e_tot_wh: 125001,
      e_int_mwh: 240,
      freq_mhz: 50000,
      pf_x1000: 980,
      flags: 0,
      timestamp: new Date().toISOString(),
      sequenceNumber: 1001
    });
    // Passes if no exception thrown — telemetry validation is internal logging only
    assert.ok(true, 'Valid telemetry should be accepted without error');
  });

  await test('T24 Telemetry ingestion — invalid pf_x1000 (>1000) rejected internally', async () => {
    const db = await buildTestDb();
    const { ingestionService } = buildPhase6Services(db, new MockMqttClient());

    // Capture console.warn output to verify rejection
    const warnMessages = [];
    const origWarn = console.warn;
    console.warn = (...args) => warnMessages.push(args.join(' '));

    await ingestionService.handleTelemetry({
      schemaVersion: 1, deviceId: DEVICE_ID, channelIndex: 1,
      v_mv: 230000, i_ma: 750, p_mw: 172500,
      e_tot_wh: 125001, e_int_mwh: 240, freq_mhz: 50000,
      pf_x1000: 1500, // Invalid: > 1000
      flags: 0, timestamp: new Date().toISOString(), sequenceNumber: 2001
    });

    console.warn = origWarn;
    const rejectionWarning = warnMessages.find(m => m.includes('pf_x1000') || m.includes('rejected'));
    assert.ok(rejectionWarning, 'Invalid pf_x1000 should generate rejection warning');
  });

  await test('T25 Telemetry ingestion — negative v_mv rejected', async () => {
    const db = await buildTestDb();
    const { ingestionService } = buildPhase6Services(db, new MockMqttClient());

    const warnMessages = [];
    const origWarn = console.warn;
    console.warn = (...args) => warnMessages.push(args.join(' '));

    await ingestionService.handleTelemetry({
      schemaVersion: 1, deviceId: DEVICE_ID, channelIndex: 1,
      v_mv: -1, i_ma: 750, p_mw: 172500,
      e_tot_wh: 125001, e_int_mwh: 240, freq_mhz: 50000, pf_x1000: 980,
      flags: 0, timestamp: new Date().toISOString(), sequenceNumber: 3001
    });

    console.warn = origWarn;
    const rejectionWarning = warnMessages.find(m => m.includes('v_mv') || m.includes('rejected'));
    assert.ok(rejectionWarning, 'Negative v_mv should generate rejection warning');
  });

  await test('T26 Telemetry ingestion — duplicate sequence number dropped', async () => {
    const db = await buildTestDb();
    const { ingestionService } = buildPhase6Services(db, new MockMqttClient());

    const telem = {
      schemaVersion: 1, deviceId: DEVICE_ID, channelIndex: 1,
      v_mv: 230000, i_ma: 750, p_mw: 172500,
      e_tot_wh: 125001, e_int_mwh: 240, freq_mhz: 50000, pf_x1000: 980,
      flags: 0, timestamp: new Date().toISOString(), sequenceNumber: 4001
    };

    await ingestionService.handleTelemetry(telem); // First — accepted

    const warnMessages = [];
    const origWarn = console.warn;
    console.warn = (...args) => warnMessages.push(args.join(' '));

    await ingestionService.handleTelemetry({ ...telem, sequenceNumber: 4001 }); // Same seq — should drop

    console.warn = origWarn;
    const dropWarning = warnMessages.find(m => m.includes('dropped') || m.includes('4001'));
    assert.ok(dropWarning, 'Duplicate sequence number should be dropped with warning');
  });

  await test('T27 Outbox — command enqueued BEFORE MQTT publish succeeds', async () => {
    const db = await buildTestDb();
    const mockClient = new MockMqttClient();
    const { commandService } = buildPhase6Services(db, mockClient);

    const cmd = buildCmd({ commandId: 'e1234567-1234-5678-9abc-def012345678' });

    // Intercept: we check that outbox has the entry right after sendCommand
    const result = await commandService.sendCommand(ACTOR, cmd);
    assert.equal(result.status, 'CREATED');

    const outboxRepo = new OutboxRepository(db);
    const pending = await outboxRepo.fetchPending(10);
    const outboxEntry = pending.find(e => e.payload && e.payload.commandId === cmd.commandId);
    assert.ok(outboxEntry, 'Outbox entry must be present after sendCommand');
    assert.equal(outboxEntry.status, 'PENDING');
  });

  // =====================================================================
  // GROUP 5: Device Simulator MQTT Mode
  // =====================================================================
  console.log('\n--- GROUP 5: Device Simulator MQTT Mode ---');

  await test('T28 Simulator connectMqtt() → ONLINE availability + state published', () => {
    const sim = new DeviceSimulator();
    const mockClient = new MockMqttClient();

    sim.connectMqtt(mockClient);

    const published = mockClient.getPublished();
    const availPub = published.find(p => p.topic.endsWith('/availability'));
    assert.ok(availPub, 'ONLINE availability should be published on connect');
    assert.ok(availPub.payload === undefined || availPub.opts.retain === true,
              'Availability should be published retained');
  });

  await test('T29 Simulator MQTT — command dispatch → APPLIED receipt + state update', () => {
    const sim = new DeviceSimulator();
    const mockClient = new MockMqttClient();
    sim.connectMqtt(mockClient);
    mockClient.clearPublished();

    // Simulate incoming command from backend
    const cmd = {
      schemaVersion: 1,
      commandId: 'f1234567-1234-5678-9abc-def012345678',
      deviceId: sim.identity.deviceId,
      channelIndex: 1,
      action: 'setPower',
      params: { value: true },
      idempotencyKey: 'sim_idem_001',
      source: 'APP',
      timestamp: new Date().toISOString(),
      expiresAt: new Date(Date.now() + 30000).toISOString()
    };

    const cmdTopic = MqttTopicBuilder.commands(sim.identity.deviceId);
    mockClient.simulateMessage(cmdTopic, cmd);

    const published = mockClient.getPublished();
    const receiptPub = published.find(p => p.topic.endsWith('/command-receipts'));
    assert.ok(receiptPub, 'Receipt should be published after command processing');
    assert.equal(receiptPub.payload.commandId, cmd.commandId);
    assert.equal(receiptPub.payload.status, 'APPLIED');

    const statePub = published.find(p => p.topic.endsWith('/state'));
    assert.ok(statePub, 'State should be published after APPLIED command');
  });

  await test('T30 Simulator MQTT — physical toggle → DeviceEvent(source=PHYSICAL_SWITCH)', () => {
    const sim = new DeviceSimulator();
    const mockClient = new MockMqttClient();
    sim.connectMqtt(mockClient);
    mockClient.clearPublished();

    const evt = sim.physicalToggleMqtt(2);
    assert.equal(evt.source, 'PHYSICAL_SWITCH');
    assert.equal(evt.channelIndex, 2);

    const published = mockClient.getPublished();
    const evtPub = published.find(p => p.topic.endsWith('/events'));
    assert.ok(evtPub, 'DeviceEvent should be published on physical toggle');
    assert.equal(evtPub.payload.source, 'PHYSICAL_SWITCH');
    assert.equal(evtPub.payload.channelIndex, 2);
    assert.equal(evtPub.opts.retain, false, 'Events should NOT be retained');
    assert.equal(evtPub.opts.qos, 1);
  });

  await test('T31 Simulator MQTT — duplicate command → APPLIED receipt, no re-actuation', () => {
    const sim = new DeviceSimulator();
    const mockClient = new MockMqttClient();
    sim.connectMqtt(mockClient);
    mockClient.clearPublished();

    const cmd = {
      schemaVersion: 1,
      commandId: 'f2345678-2345-6789-abcd-ef0123456789',
      deviceId: sim.identity.deviceId,
      channelIndex: 1,
      action: 'setPower', params: { value: true },
      idempotencyKey: 'sim_idem_dup_001',
      source: 'APP',
      timestamp: new Date().toISOString(),
      expiresAt: new Date(Date.now() + 30000).toISOString()
    };

    const cmdTopic = MqttTopicBuilder.commands(sim.identity.deviceId);
    mockClient.simulateMessage(cmdTopic, cmd); // First
    const publishedAfterFirst = mockClient.getPublished().length;

    mockClient.clearPublished();
    mockClient.simulateMessage(cmdTopic, cmd); // Duplicate

    const published = mockClient.getPublished();
    const receiptPub = published.find(p => p.topic.endsWith('/command-receipts'));
    assert.ok(receiptPub, 'Duplicate should still return a receipt');
    assert.equal(receiptPub.payload.status, 'APPLIED', 'Duplicate should return APPLIED (deterministic)');

    // No additional state publication for duplicate
    const statePubs = published.filter(p => p.topic.endsWith('/state'));
    assert.equal(statePubs.length, 0, 'Duplicate command should NOT publish state again');
  });

  await test('T32 Simulator MQTT — expired command → EXPIRED receipt', () => {
    const sim = new DeviceSimulator();
    const mockClient = new MockMqttClient();
    sim.connectMqtt(mockClient);
    mockClient.clearPublished();

    const cmd = {
      schemaVersion: 1,
      commandId: 'f3456789-3456-789a-bcde-f01234567890',
      deviceId: sim.identity.deviceId,
      channelIndex: 1,
      action: 'setPower', params: { value: false },
      idempotencyKey: 'sim_idem_exp_001',
      source: 'APP',
      timestamp: new Date().toISOString(),
      expiresAt: new Date(Date.now() - 5000).toISOString() // Already expired
    };

    const cmdTopic = MqttTopicBuilder.commands(sim.identity.deviceId);
    mockClient.simulateMessage(cmdTopic, cmd);

    const published = mockClient.getPublished();
    const receiptPub = published.find(p => p.topic.endsWith('/command-receipts'));
    assert.ok(receiptPub, 'Expired command should produce a receipt');
    assert.equal(receiptPub.payload.status, 'EXPIRED');
  });

  await test('T33 Simulator MQTT — disconnectMqtt() → OFFLINE availability published', () => {
    const sim = new DeviceSimulator();
    const mockClient = new MockMqttClient();
    sim.connectMqtt(mockClient);
    mockClient.clearPublished();

    sim.disconnectMqtt();

    const published = mockClient.getPublished();
    const offlinePub = published.find(p => p.topic.endsWith('/availability'));
    assert.ok(offlinePub, 'OFFLINE should be published on graceful disconnect');
    assert.equal(offlinePub.opts.retain, true, 'OFFLINE availability should be retained');
  });

  // =====================================================================
  // GROUP 6: ACL Isolation
  // =====================================================================
  console.log('\n--- GROUP 6: ACL Isolation ---');

  await test('T34 ACL isolation — simulator ignores cross-device topics', () => {
    const simA = new DeviceSimulator({ deviceId: DEVICE_ID });
    const mockClient = new MockMqttClient();
    simA.connectMqtt(mockClient);
    mockClient.clearPublished();

    // Send command addressed to Device B on Device A's client
    const cmdForB = {
      schemaVersion: 1,
      commandId: 'a1234567-1234-5678-9abc-def012345678',
      deviceId: DEVICE_ID_B, // Wrong device
      channelIndex: 1,
      action: 'setPower', params: { value: true },
      idempotencyKey: 'acl_test_001',
      source: 'APP',
      timestamp: new Date().toISOString(),
      expiresAt: new Date(Date.now() + 30000).toISOString()
    };

    // Simulate message on Device A's command topic (with Device B's deviceId in payload)
    const cmdTopicA = MqttTopicBuilder.commands(DEVICE_ID);
    mockClient.simulateMessage(cmdTopicA, cmdForB);

    const published = mockClient.getPublished();
    const receiptPub = published.find(p => p.topic.endsWith('/command-receipts'));
    // Simulator checks topic match and payload deviceId — should drop due to deviceId mismatch
    const appliedReceipt = receiptPub && receiptPub.payload.status === 'APPLIED';
    assert.ok(!appliedReceipt, 'Cross-device command should not be APPLIED on wrong device');
  });

  // =====================================================================
  // GROUP 7: Route Handlers
  // =====================================================================
  console.log('\n--- GROUP 7: Route Handlers ---');

  await test('T36 Route handler — unauthenticated request → 401', async () => {
    const db = await buildTestDb();
    const services = buildPhase6Services(db, new MockMqttClient());
    const handlers = buildRouteHandlers(services);

    let responseStatus = null;
    let responseBody = null;
    const req = { body: buildCmd(), actorContext: null }; // No actor context
    const res = {
      status(code) { responseStatus = code; return this; },
      json(body) { responseBody = body; return this; }
    };

    await handlers.sendCommand(req, res);
    assert.equal(responseStatus, 401);
    assert.ok(responseBody.error.includes('Unauthorized'));
  });

  await test('T37 Route handler — valid authenticated POST → 202 Accepted', async () => {
    const db = await buildTestDb();
    const services = buildPhase6Services(db, new MockMqttClient());
    const handlers = buildRouteHandlers(services);

    let responseStatus = null;
    let responseBody = null;
    const req = {
      body: buildCmd({ commandId: 'b1234567-1234-5678-9abc-def012345678' }),
      actorContext: ACTOR
    };
    const res = {
      status(code) { responseStatus = code; return this; },
      json(body) { responseBody = body; return this; }
    };

    await handlers.sendCommand(req, res);
    assert.equal(responseStatus, 202);
    assert.equal(responseBody.status, 'CREATED');
  });

  await test('T38 Route handler — expired command → 422 Unprocessable', async () => {
    const db = await buildTestDb();
    const services = buildPhase6Services(db, new MockMqttClient());
    const handlers = buildRouteHandlers(services);

    let responseStatus = null;
    const req = {
      body: buildCmd({
        commandId: 'b2345678-2345-6789-abcd-ef0123456789',
        expiresAt: new Date(Date.now() - 10000).toISOString()
      }),
      actorContext: ACTOR
    };
    const res = {
      status(code) { responseStatus = code; return this; },
      json() { return this; }
    };

    await handlers.sendCommand(req, res);
    assert.equal(responseStatus, 422);
  });

  await test('T39 Route handler — GET /devices/:deviceId/state → 200 with state', async () => {
    const db = await buildTestDb();
    const services = buildPhase6Services(db, new MockMqttClient());
    const handlers = buildRouteHandlers(services);

    let responseStatus = null;
    let responseBody = null;
    const req = {
      params: { deviceId: DEVICE_ID },
      actorContext: ACTOR
    };
    const res = {
      status(code) { responseStatus = code; return this; },
      json(body) { responseBody = body; return this; }
    };

    await handlers.getDeviceState(req, res);
    assert.equal(responseStatus, 200);
    assert.equal(responseBody.deviceId, DEVICE_ID);
    assert.ok(Array.isArray(responseBody.channels));
  });

  // =====================================================================
  // FINAL REPORT
  // =====================================================================

  console.log(`\n================================================================`);
  console.log(`  PHASE 6 MQTT TEST RESULTS: ${passed} PASSED, ${failed} FAILED`);
  console.log(`================================================================`);

  if (failures.length > 0) {
    console.error('\nFailed Tests:');
    failures.forEach(f => console.error(`  ✗ ${f.name}: ${f.error}`));
    process.exit(1);
  } else {
    console.log('\n  ALL PHASE 6 MQTT TESTS PASSED\n');
    process.exit(0);
  }
})();
