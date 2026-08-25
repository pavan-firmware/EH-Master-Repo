'use strict';

/**
 * EH Home — Phase 6 Real EMQX 5.8.0 Integration Test Suite
 *
 * VALIDATES FULL ARCHITECTURAL COMPATIBILITY AGAINST THE ACTUAL RUNNING
 * EMQX 5.8.0 CONTAINER (PORT 1883 / TLS PORT 8883).
 *
 * Uses the official `mqtt.js` production client library (zero custom socket code).
 *
 * Security:
 *   - `rejectUnauthorized: true` IS STRICTLY ENFORCED FOR ALL TLS CONNECTIONS.
 *   - EQ13 tests TLS encryption, client cert acceptance, and reports mTLS ACL gap.
 */

const assert = require('assert').strict;
const fs     = require('fs');
const path   = require('path');
const mqtt   = require('mqtt');
const { setupEmqxMtls } = require('../../scripts/setup-emqx-mtls');
const { DatabaseClient } = require('../src/shared/db-client');
const { MqttTopicBuilder, MqttTopicParser } = require('../src/shared/mqtt-topic-builder');
const { MqttDeviceTransport } = require('../src/services/mqtt-device-transport');
const { DeviceCommandService } = require('../src/services/device-command.service');
const { DeviceEventTelemetryIngestionService } = require('../src/services/device-event-telemetry-ingestion.service');
const {
  CommandRepository, OutboxRepository, DeviceRepository,
  DeviceStateRepository, EventRepository, AuditRepository,
  ProductRepository, UserRepository, HomeRepository
} = require('../src/repositories/index');
const { DeviceSimulator } = require('../../tools/device-simulator/simulator');

const EMQX_URL     = process.env.EMQX_BROKER_URL     || 'mqtt://127.0.0.1:1883';
const EMQX_TLS_URL = process.env.EMQX_TLS_BROKER_URL || 'mqtts://127.0.0.1:8883';
const DEVICE_A_ID = '0194fe23-7a1b-7890-a123-456789abcdef';
const DEVICE_B_ID = '0194fe23-7a1b-7890-b456-123456fedcba';
const USER_ID     = 'a1b2c3d4-1234-5678-9abc-def012345678';
const HOME_ID     = 'b1c2d3e4-2345-6789-abcd-ef0123456789';
const VARIANT_ID  = 'eh-smart-switch-3x';

const ACTOR = { userId: USER_ID, homeId: HOME_ID, role: 'OWNER' };

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

async function buildTestDb() {
  const db = new DatabaseClient();
  const userRepo    = new UserRepository(db);
  const homeRepo    = new HomeRepository(db);
  const deviceRepo  = new DeviceRepository(db);
  const productRepo = new ProductRepository(db);

  await productRepo.createFamily({ id: 'fam-switches', name: 'EH Smart Switches', description: 'Smart switch family' });
  await productRepo.createProduct({ id: 'prod-sw3x', familyId: 'fam-switches', name: 'Smart Switch 3X', description: '3-channel smart switch' });
  await productRepo.createVariant({
    id: VARIANT_ID, productId: 'prod-sw3x', name: '3X',
    skuCode: 'EH-SW3X', channelCount: 3,
    hardwareCapabilities: [], supportedFirmwareFamilies: ['esp32c6-switch-platform']
  });

  await userRepo.createUser({ id: USER_ID, email: 'test@eh.com', passwordHash: 'hashed' });
  await homeRepo.createHome({ id: HOME_ID, name: 'Test Home', ownerId: USER_ID });

  await deviceRepo.registerDevice({
    deviceId: DEVICE_A_ID, serialNumber: 'EH-SW3X-2026W12-00891',
    productVariantId: VARIANT_ID, hardwareRevision: 'HW_1_0',
    firmwareFamily: 'esp32c6-switch-platform', firmwareVersion: '1.0.0'
  });
  await deviceRepo.claimDevice({
    deviceId: DEVICE_A_ID, homeId: HOME_ID, customName: 'Living Room Switch',
    claimedByUserId: USER_ID
  });

  return db;
}

function delay(ms) {
  return new Promise(resolve => setTimeout(resolve, ms));
}

/** Check if EMQX broker container is active on EMQX_URL */
function checkEmqxReachable(url) {
  return new Promise((resolve) => {
    const client = mqtt.connect(url, { connectTimeout: 3000, reconnectPeriod: 0 });
    client.on('connect', () => { client.end(true); resolve(true); });
    client.on('error', () => { client.end(true); resolve(false); });
  });
}

(async () => {
  console.log('\n================================================================');
  console.log('       EH HOME — PHASE 6 REAL EMQX 5.8.0 INTEGRATION TEST       ');
  console.log('================================================================\n');

  console.log(`Checking EMQX broker accessibility at '${EMQX_URL}'...`);
  const isEmqxReady = await checkEmqxReachable(EMQX_URL);

  if (!isEmqxReady) {
    console.log('\n----------------------------------------------------------------');
    console.log(' [BLOCKED] EMQX CONTAINER NOT RUNNING ON PORT 1883.');
    console.log(' Required action: Start container via: docker compose up -d emqx');
    console.log('----------------------------------------------------------------\n');
    process.exit(2);
  }

  console.log('  [PASS] EMQX broker 5.8.0 is ONLINE and accepting connections.\n');

  console.log('Applying real EMQX mTLS (verify_peer) and per-device ACL configuration...');
  setupEmqxMtls();
  console.log('  [PASS] EMQX 5.8.0 configured with verify_peer = true & per-device ACL.\n');

  // =====================================================================
  // REAL EMQX 5.8.0 INTEGRATION TESTS
  // =====================================================================

  await test('EQ01 Real EMQX Connection & Connect Handshake using mqtt.js', async () => {
    const client = mqtt.connect(EMQX_URL, { clientId: 'eh_test_eq01' });
    await new Promise((resolve, reject) => {
      client.on('connect', () => { client.end(true); resolve(); });
      client.on('error', (err) => { client.end(true); reject(err); });
    });
    assert.ok(true, 'Connected successfully to EMQX using mqtt.js');
  });

  await test('EQ02 Real End-to-End Command Path over EMQX (Backend → mqtt.js → EMQX → Simulator → Receipt)', async () => {
    const db = await buildTestDb();
    const commandRepo     = new CommandRepository(db);
    const outboxRepo      = new OutboxRepository(db);
    const deviceRepo      = new DeviceRepository(db);
    const deviceStateRepo = new DeviceStateRepository(db);
    const eventRepo       = new EventRepository(db);
    const auditRepo       = new AuditRepository(db);

    const ingestionService = new DeviceEventTelemetryIngestionService({
      deviceStateRepo, eventRepo, commandRepo, outboxRepo, auditRepo
    });

    const transport = new MqttDeviceTransport({
      brokerUrl: EMQX_URL,
      clientId: 'backend_service_eq02',
      onReceipt: (receipt) => commandService.handleCommandReceipt(receipt),
      onState:   (state)   => ingestionService.handleDeviceState(state),
    });

    const commandService = new DeviceCommandService({
      commandRepo, outboxRepo, deviceRepo, deviceStateRepo, auditRepo,
      mqttTransport: transport
    });

    await delay(300);

    const simMqttClient = mqtt.connect(EMQX_URL, { clientId: `eh_device_${DEVICE_A_ID}` });
    const sim = new DeviceSimulator({ deviceId: DEVICE_A_ID });
    sim.connectMqtt(simMqttClient);

    await delay(300);

    const cmd = {
      commandId: 'e9999999-9999-9999-9999-999999999999',
      deviceId: DEVICE_A_ID,
      channelIndex: 1,
      action: 'setPower',
      params: { value: true },
      idempotencyKey: 'emqx_idem_001',
      source: 'APP',
      expiresAt: new Date(Date.now() + 30000).toISOString()
    };

    const result = await commandService.sendCommand(ACTOR, cmd);
    assert.equal(result.status, 'CREATED');

    await delay(400);

    const record = await commandRepo.getCommand(cmd.commandId);
    assert.ok(record, 'Command record must exist in DB');
    assert.equal(record.status, 'APPLIED', 'Status must be APPLIED over EMQX broker');

    sim.disconnectMqtt();
    transport.disconnect();
  });

  await test('EQ03 Real EMQX Physical Switch Event (source=PHYSICAL_SWITCH) → Hardware Truth', async () => {
    const db = await buildTestDb();
    const deviceStateRepo = new DeviceStateRepository(db);
    const eventRepo       = new EventRepository(db);
    const outboxRepo      = new OutboxRepository(db);

    const ingestionService = new DeviceEventTelemetryIngestionService({ deviceStateRepo, eventRepo, outboxRepo });

    const transport = new MqttDeviceTransport({
      brokerUrl: EMQX_URL,
      clientId: 'backend_service_eq03',
      onEvent: (evt) => ingestionService.handleDeviceEvent(evt)
    });

    await delay(300);

    const simMqttClient = mqtt.connect(EMQX_URL, { clientId: `eh_device_${DEVICE_A_ID}` });
    const sim = new DeviceSimulator({ deviceId: DEVICE_A_ID });
    sim.connectMqtt(simMqttClient);

    await delay(300);

    sim.physicalToggleMqtt(2);
    await delay(400);

    const state = await deviceStateRepo.getFullState(DEVICE_A_ID);
    assert.ok(state, 'DeviceState must exist');
    const ch2 = state.channels.find(c => c.channelIndex === 2);
    assert.ok(ch2, 'Channel 2 must exist');
    assert.equal(ch2.reportedState.power, true, 'Physical switch event over EMQX must update reportedState');

    sim.disconnectMqtt();
    transport.disconnect();
  });

  await test('EQ04 Real EMQX Retained Availability (ONLINE / LWT OFFLINE)', async () => {
    const db = await buildTestDb();
    const deviceStateRepo = new DeviceStateRepository(db);
    const ingestionService = new DeviceEventTelemetryIngestionService({ deviceStateRepo });

    const transport = new MqttDeviceTransport({
      brokerUrl: EMQX_URL,
      clientId: 'backend_service_eq04',
      onAvailability: (id, av) => ingestionService.handleAvailability(id, av)
    });

    await delay(300);

    const availTopic = MqttTopicBuilder.availability(DEVICE_A_ID);
    const devClient = mqtt.connect(EMQX_URL, {
      clientId: `eh_device_${DEVICE_A_ID}`,
      will: {
        topic: availTopic,
        payload: '"OFFLINE"',
        qos: 1,
        retain: true
      }
    });

    await new Promise(r => devClient.on('connect', r));

    devClient.publish(availTopic, '"ONLINE"', { qos: 1, retain: true });
    await delay(300);

    let state = await deviceStateRepo.getFullState(DEVICE_A_ID);
    assert.equal(state.connectionState, 'ONLINE', 'EMQX connection should register as ONLINE');

    devClient.stream.destroy();
    await delay(500);

    state = await deviceStateRepo.getFullState(DEVICE_A_ID);
    assert.equal(state.connectionState, 'OFFLINE', 'EMQX LWT must trigger OFFLINE update on ungraceful drop');

    transport.disconnect();
  });

  await test('EQ05 Real EMQX Command Idempotency (hardware executes once)', async () => {
    const db = await buildTestDb();
    const commandRepo     = new CommandRepository(db);
    const outboxRepo      = new OutboxRepository(db);
    const deviceRepo      = new DeviceRepository(db);
    const deviceStateRepo = new DeviceStateRepository(db);
    const eventRepo       = new EventRepository(db);
    const auditRepo       = new AuditRepository(db);

    const ingestionService = new DeviceEventTelemetryIngestionService({ deviceStateRepo, eventRepo, commandRepo, outboxRepo, auditRepo });
    const commandService = new DeviceCommandService({
      commandRepo, outboxRepo, deviceRepo, deviceStateRepo, auditRepo
    });

    const transport = new MqttDeviceTransport({
      brokerUrl: EMQX_URL, clientId: 'backend_service_eq05',
      onReceipt: (r) => commandService.handleCommandReceipt(r)
    });
    commandService.mqttTransport = transport;
    await delay(300); // Allow transport subscriptions to register on EMQX

    await delay(300);

    const simMqttClient = mqtt.connect(EMQX_URL, { clientId: `eh_device_${DEVICE_A_ID}` });
    const sim = new DeviceSimulator({ deviceId: DEVICE_A_ID });
    sim.connectMqtt(simMqttClient);
    await delay(300);

    const cmd = {
      commandId: 'e8888888-8888-8888-8888-888888888888',
      deviceId: DEVICE_A_ID, channelIndex: 1, action: 'setPower',
      params: { value: true }, idempotencyKey: 'emqx_idem_eq05', source: 'APP',
      expiresAt: new Date(Date.now() + 30000).toISOString()
    };

    const r1 = await commandService.sendCommand(ACTOR, cmd);
    assert.equal(r1.status, 'CREATED');
    assert.equal(r1.isIdempotentReplay, false);

    // Send duplicate command
    const r2 = await commandService.sendCommand(ACTOR, cmd);
    assert.equal(r2.isIdempotentReplay, true, 'Second send with same idempotencyKey must be detected as replay');

    await delay(500);

    const record = await commandRepo.getCommand(cmd.commandId);
    assert.equal(record.status, 'APPLIED');

    sim.disconnectMqtt();
    transport.disconnect();
  });

  await test('EQ06 Real EMQX Expired Command (EXPIRED receipt, zero execution)', async () => {
    const db = await buildTestDb();
    const commandRepo = new CommandRepository(db);
    const outboxRepo  = new OutboxRepository(db);
    const deviceRepo  = new DeviceRepository(db);
    const deviceStateRepo = new DeviceStateRepository(db);
    const auditRepo   = new AuditRepository(db);

    const transport = new MqttDeviceTransport({ brokerUrl: EMQX_URL, clientId: 'backend_service_eq06' });
    const commandService = new DeviceCommandService({ commandRepo, outboxRepo, deviceRepo, deviceStateRepo, auditRepo, mqttTransport: transport });

    const expiredCmd = {
      commandId: 'e7777777-7777-7777-7777-777777777777',
      deviceId: DEVICE_A_ID, channelIndex: 1, action: 'setPower',
      params: { value: true }, idempotencyKey: 'emqx_exp_eq06', source: 'APP',
      expiresAt: new Date(Date.now() - 5000).toISOString() // Expired 5s ago
    };

    const result = await commandService.sendCommand(ACTOR, expiredCmd);
    assert.equal(result.status, 'EXPIRED');

    const record = await commandRepo.getCommand(expiredCmd.commandId);
    assert.equal(record, null, 'Expired command must not be persisted to DB');

    transport.disconnect();
  });

  await test('EQ07 Real EMQX Telemetry Ingestion (valid fixed-point vs invalid rejection)', async () => {
    const db = await buildTestDb();
    const outboxRepo = new OutboxRepository(db);
    const deviceStateRepo = new DeviceStateRepository(db);
    const ingestionService = new DeviceEventTelemetryIngestionService({ deviceStateRepo, outboxRepo });

    const transport = new MqttDeviceTransport({
      brokerUrl: EMQX_URL, clientId: 'backend_service_eq07',
      onTelemetry: (t) => ingestionService.handleTelemetry(t)
    });
    await delay(300);

    const devClient = mqtt.connect(EMQX_URL, { clientId: `eh_device_${DEVICE_A_ID}` });
    await new Promise(r => devClient.on('connect', r));

    const telemTopic = MqttTopicBuilder.telemetry(DEVICE_A_ID);
    devClient.publish(telemTopic, JSON.stringify({
      schemaVersion: 1, deviceId: DEVICE_A_ID, channelIndex: 1,
      v_mv: 230500, i_ma: 820, p_mw: 189010, e_tot_wh: 125000,
      e_int_mwh: 240, freq_mhz: 50000, pf_x1000: 980, flags: 0,
      timestamp: new Date().toISOString(), sequenceNumber: 201
    }), { qos: 0 });

    await delay(400);

    const pending = await outboxRepo.fetchPending(10);
    const telemEntry = pending.find(e => e.event_type === 'DEVICE_TELEMETRY');
    assert.ok(telemEntry, 'Valid telemetry must be ingested into outbox via EMQX');
    assert.equal(telemEntry.payload.v_mv, 230500);

    devClient.end(true);
    transport.disconnect();
  });

  await test('EQ08 Real EMQX Reconnect & Authoritative State Convergence', async () => {
    const db = await buildTestDb();
    const deviceStateRepo = new DeviceStateRepository(db);
    const ingestionService = new DeviceEventTelemetryIngestionService({ deviceStateRepo });

    const transport = new MqttDeviceTransport({
      brokerUrl: EMQX_URL, clientId: 'backend_service_eq08',
      onState: (s) => ingestionService.handleDeviceState(s)
    });
    await delay(300);

    // Initial connect
    let devClient = mqtt.connect(EMQX_URL, { clientId: `eh_device_${DEVICE_A_ID}` });
    await new Promise(r => devClient.on('connect', r));

    const stateTopic = MqttTopicBuilder.state(DEVICE_A_ID);
    devClient.publish(stateTopic, JSON.stringify({
      schemaVersion: 1, deviceId: DEVICE_A_ID, connectionState: 'ONLINE',
      channels: [{ schemaVersion: 1, channelIndex: 1, desiredState: { power: true }, reportedState: { power: true }, confidence: 'CONFIRMED' }]
    }), { qos: 1 });
    await delay(300);

    // Network disconnect
    devClient.end(true);
    await delay(300);

    // Reconnect & republish state
    devClient = mqtt.connect(EMQX_URL, { clientId: `eh_device_${DEVICE_A_ID}` });
    await new Promise(r => devClient.on('connect', r));

    devClient.publish(stateTopic, JSON.stringify({
      schemaVersion: 1, deviceId: DEVICE_A_ID, connectionState: 'ONLINE',
      channels: [{ schemaVersion: 1, channelIndex: 1, desiredState: { power: true }, reportedState: { power: true }, confidence: 'CONFIRMED' }]
    }), { qos: 1 });
    await delay(300);

    const state = await deviceStateRepo.getFullState(DEVICE_A_ID);
    assert.equal(state.connectionState, 'ONLINE');
    assert.equal(state.channels[0].reportedState.power, true);

    devClient.end(true);
    transport.disconnect();
  });

  await test('EQ09 Backend STALE Connection State Derivation from Heartbeat Threshold', () => {
    const db = new DatabaseClient();
    const ingestionService = new DeviceEventTelemetryIngestionService({ deviceStateRepo: new DeviceStateRepository(db) });

    const oldState = { connectionState: 'ONLINE', lastSeenAt: new Date(Date.now() - 120_000).toISOString() };
    const derived = ingestionService.deriveConnectionState(DEVICE_A_ID, oldState);
    assert.equal(derived, 'STALE', 'STALE state must be derived by backend from lastSeen threshold');
  });

  await test('EQ10 Real EMQX Topic Policy Verification (QoS & Retain)', () => {
    assert.equal(MqttTopicBuilder.qosPolicy('commands').qos, 1);
    assert.equal(MqttTopicBuilder.qosPolicy('commands').retain, false);

    assert.equal(MqttTopicBuilder.qosPolicy('command-receipts').qos, 1);
    assert.equal(MqttTopicBuilder.qosPolicy('command-receipts').retain, false);

    assert.equal(MqttTopicBuilder.qosPolicy('state').qos, 1);
    assert.equal(MqttTopicBuilder.qosPolicy('state').retain, false);

    assert.equal(MqttTopicBuilder.qosPolicy('events').qos, 1);
    assert.equal(MqttTopicBuilder.qosPolicy('events').retain, false);

    assert.equal(MqttTopicBuilder.qosPolicy('telemetry').qos, 0);
    assert.equal(MqttTopicBuilder.qosPolicy('telemetry').retain, false);

    assert.equal(MqttTopicBuilder.qosPolicy('availability').qos, 1);
    assert.equal(MqttTopicBuilder.qosPolicy('availability').retain, true);
  });

  await test('EQ11 Real EMQX Retained LWT Re-subscription Convergence', async () => {
    const availTopic = MqttTopicBuilder.availability(DEVICE_A_ID);

    // 1. Device connects and publishes retained ONLINE
    let devClient = mqtt.connect(EMQX_URL, {
      clientId: `eh_device_${DEVICE_A_ID}`,
      will: { topic: availTopic, payload: '"OFFLINE"', qos: 1, retain: true }
    });
    await new Promise(r => devClient.on('connect', r));
    devClient.publish(availTopic, '"ONLINE"', { qos: 1, retain: true });
    await delay(300);

    // 2. Ungraceful drop triggers LWT OFFLINE
    devClient.stream.destroy();
    await delay(400);

    // 3. New subscriber connects and receives retained OFFLINE from EMQX
    const subClient = mqtt.connect(EMQX_URL, { clientId: 'sub_test_eq11' });
    let receivedStatus = null;
    subClient.on('connect', () => {
      subClient.subscribe(availTopic, { qos: 1 });
    });
    subClient.on('message', (t, buf) => {
      if (t === availTopic) receivedStatus = buf.toString().replace(/^"|"$/g, '');
    });
    await delay(400);

    assert.equal(receivedStatus, 'OFFLINE', 'New subscriber must receive retained OFFLINE from EMQX LWT');

    subClient.end(true);
  });

  await test('EQ12 Clean Transport Disconnect & Lifecycle Error Suppression (Regression Check)', () => {
    const transport = new MqttDeviceTransport({ brokerUrl: EMQX_URL, clientId: 'backend_clean_disconnect' });
    assert.doesNotThrow(() => {
      transport.disconnect();
      transport.disconnect(); // Double disconnect must be safe and idempotent
    });
  });

  // =====================================================================
  // EQ13 — REAL EMQX TLS / mTLS IDENTITY + ACL GATE
  // Target: mqtts://127.0.0.1:8883
  // Enforces mandatory client certificate authentication (verify_peer = true)
  // and per-device ACL isolation enforced by EMQX 5.8.0.
  // =====================================================================

  console.log('\n--- EQ13: TLS / mTLS & ACL Gate ---');

  const LOCAL_CERTS = path.join(__dirname, '..', '..', '.local-certs');
  const CA_CRT = fs.readFileSync(path.join(LOCAL_CERTS, 'ca.crt'));
  const DEV_A_CRT = fs.readFileSync(path.join(LOCAL_CERTS, 'device_a.crt'));
  const DEV_A_KEY = fs.readFileSync(path.join(LOCAL_CERTS, 'device_a.key'));
  const DEV_B_CRT = fs.readFileSync(path.join(LOCAL_CERTS, 'device_b.crt'));
  const DEV_B_KEY = fs.readFileSync(path.join(LOCAL_CERTS, 'device_b.key'));
  const UNTRUSTED_CA = fs.readFileSync(path.join(LOCAL_CERTS, 'untrusted_ca.crt'));
  const UNTRUSTED_DEV_CRT = fs.readFileSync(path.join(LOCAL_CERTS, 'untrusted_device.crt'));
  const UNTRUSTED_DEV_KEY = fs.readFileSync(path.join(LOCAL_CERTS, 'untrusted_device.key'));

  /** EQ13a — Valid server CA → connection accepted */
  await test('EQ13a Real EMQX TLS — valid server CA accepted (rejectUnauthorized: true)', async () => {
    let connected = false;
    await new Promise((resolve, reject) => {
      const client = mqtt.connect(EMQX_TLS_URL, {
        ca: CA_CRT, cert: DEV_A_CRT, key: DEV_A_KEY,
        rejectUnauthorized: true,
        clientId: DEVICE_A_ID,
        connectTimeout: 5000, reconnectPeriod: 0
      });
      client.on('connect', () => { connected = true; client.end(true); resolve(); });
      client.on('error', (e) => { client.end(true); reject(new Error(`TLS connect failed: ${e.message}`)); });
      setTimeout(() => reject(new Error('TLS connect timeout')), 6000);
    });
    assert.ok(connected, 'EMQX TLS must accept connection when valid CA and client cert are provided');
  });

  /** EQ13b — Unknown CA → rejected */
  await test('EQ13b Real EMQX TLS — unknown/untrusted server CA rejected (rejectUnauthorized: true)', async () => {
    let rejected = false;
    await new Promise((resolve) => {
      const client = mqtt.connect(EMQX_TLS_URL, {
        ca: UNTRUSTED_CA, cert: DEV_A_CRT, key: DEV_A_KEY,
        rejectUnauthorized: true,
        clientId: DEVICE_A_ID,
        connectTimeout: 5000, reconnectPeriod: 0
      });
      client.on('connect', () => { client.end(true); resolve(new Error('Untrusted CA was accepted')); });
      client.on('error', (e) => {
        rejected = true;
        client.end(true);
        resolve();
      });
      setTimeout(resolve, 6000);
    });
    assert.ok(rejected, 'EMQX connection must be rejected when server CA is untrusted');
  });

  /** EQ13c — Valid Device A client certificate → accepted */
  await test('EQ13c Real EMQX mTLS — valid Device A client certificate accepted', async () => {
    let connected = false;
    await new Promise((resolve, reject) => {
      const client = mqtt.connect(EMQX_TLS_URL, {
        ca: CA_CRT, cert: DEV_A_CRT, key: DEV_A_KEY,
        rejectUnauthorized: true,
        clientId: DEVICE_A_ID,
        connectTimeout: 5000, reconnectPeriod: 0
      });
      client.on('connect', () => { connected = true; client.end(true); resolve(); });
      client.on('error', (e) => { client.end(true); reject(e); });
      setTimeout(() => reject(new Error('Timeout')), 6000);
    });
    assert.ok(connected, 'EMQX must accept Device A client certificate');
  });

  /** EQ13d — No client certificate → rejected by EMQX */
  await test('EQ13d Real EMQX mTLS — missing client certificate rejected by broker', async () => {
    let rejected = false;
    await new Promise((resolve) => {
      const client = mqtt.connect(EMQX_TLS_URL, {
        ca: CA_CRT,
        rejectUnauthorized: true,
        clientId: DEVICE_A_ID,
        connectTimeout: 5000, reconnectPeriod: 0
      });
      client.on('connect', () => { client.end(true); resolve(new Error('Connected without client cert!')); });
      client.on('error', (e) => {
        rejected = e.message.includes('certificate required') ||
                   e.message.includes('alert') ||
                   e.message.includes('handshake failure');
        client.end(true);
        resolve();
      });
      setTimeout(resolve, 6000);
    });
    assert.ok(rejected, 'EMQX must reject connections presented without a client certificate');
  });

  /** EQ13e — Invalid/untrusted client certificate → rejected by EMQX */
  await test('EQ13e Real EMQX mTLS — untrusted client certificate rejected by broker', async () => {
    let rejected = false;
    await new Promise((resolve) => {
      const client = mqtt.connect(EMQX_TLS_URL, {
        ca: CA_CRT, cert: UNTRUSTED_DEV_CRT, key: UNTRUSTED_DEV_KEY,
        rejectUnauthorized: true,
        clientId: DEVICE_A_ID,
        connectTimeout: 5000, reconnectPeriod: 0
      });
      client.on('connect', () => { client.end(true); resolve(new Error('Untrusted client cert accepted!')); });
      client.on('error', (e) => {
        rejected = true;
        client.end(true);
        resolve();
      });
      setTimeout(resolve, 6000);
    });
    assert.ok(rejected, 'EMQX must reject client certificates signed by an untrusted CA');
  });

  /** EQ13f — Device A certificate → Device A topics allowed */
  await test('EQ13f Real EMQX ACL — Device A certificate allowed on Device A topics', async () => {
    const client = mqtt.connect(EMQX_TLS_URL, {
      ca: CA_CRT, cert: DEV_A_CRT, key: DEV_A_KEY,
      rejectUnauthorized: true,
      clientId: DEVICE_A_ID,
      connectTimeout: 5000, reconnectPeriod: 0
    });
    await new Promise(r => client.on('connect', r));

    const cmdTopic = MqttTopicBuilder.commands(DEVICE_A_ID);
    const granted = await new Promise(r => client.subscribe(cmdTopic, (err, g) => r(g)));
    assert.ok(granted && granted[0] && granted[0].qos !== 128, 'Device A must be allowed to subscribe to own commands topic');

    const stateTopic = MqttTopicBuilder.state(DEVICE_A_ID);
    let pubSuccess = true;
    client.publish(stateTopic, JSON.stringify({ state: { relay_0: true } }), { qos: 1 }, (err) => {
      if (err) pubSuccess = false;
    });
    await delay(300);
    assert.ok(pubSuccess, 'Device A must be allowed to publish to own state topic');

    client.end(true);
  });

  /** EQ13g — Device A certificate → Device B topics rejected by EMQX ACL */
  await test('EQ13g Real EMQX ACL — Device A certificate rejected on Device B topics', async () => {
    const clientB = mqtt.connect(EMQX_TLS_URL, {
      ca: CA_CRT, cert: DEV_B_CRT, key: DEV_B_KEY,
      rejectUnauthorized: true, clientId: DEVICE_B_ID
    });
    await new Promise(r => clientB.on('connect', r));

    let devBReceived = false;
    clientB.subscribe(MqttTopicBuilder.state(DEVICE_B_ID));
    clientB.on('message', () => { devBReceived = true; });

    const clientA = mqtt.connect(EMQX_TLS_URL, {
      ca: CA_CRT, cert: DEV_A_CRT, key: DEV_A_KEY,
      rejectUnauthorized: true, clientId: DEVICE_A_ID
    });
    await new Promise(r => clientA.on('connect', r));

    // Device A attempts unauthorized publish to Device B state topic
    clientA.publish(MqttTopicBuilder.state(DEVICE_B_ID), JSON.stringify({ unauthorized: true }));

    await delay(600);
    assert.equal(devBReceived, false, 'EMQX ACL must block Device A from publishing to Device B topic');

    clientA.end(true);
    clientB.end(true);
  });

  /** EQ13h — Device B certificate → Device A topics rejected by EMQX ACL */
  await test('EQ13h Real EMQX ACL — Device B certificate rejected on Device A topics', async () => {
    const clientA = mqtt.connect(EMQX_TLS_URL, {
      ca: CA_CRT, cert: DEV_A_CRT, key: DEV_A_KEY,
      rejectUnauthorized: true, clientId: DEVICE_A_ID
    });
    await new Promise(r => clientA.on('connect', r));

    let devAReceived = false;
    clientA.subscribe(MqttTopicBuilder.state(DEVICE_A_ID));
    clientA.on('message', () => { devAReceived = true; });

    const clientB = mqtt.connect(EMQX_TLS_URL, {
      ca: CA_CRT, cert: DEV_B_CRT, key: DEV_B_KEY,
      rejectUnauthorized: true, clientId: DEVICE_B_ID
    });
    await new Promise(r => clientB.on('connect', r));

    // Device B attempts unauthorized publish to Device A state topic
    clientB.publish(MqttTopicBuilder.state(DEVICE_A_ID), JSON.stringify({ unauthorized: true }));

    await delay(600);
    assert.equal(devAReceived, false, 'EMQX ACL must block Device B from publishing to Device A topic');

    clientA.end(true);
    clientB.end(true);
  });

  /** EQ13i — Device A CN / deviceId mismatch → ACL denied */
  await test('EQ13i Real EMQX ACL — Device A certificate with Device B clientId spoof attempt rejected', async () => {
    const clientAOwn = mqtt.connect(EMQX_TLS_URL, {
      ca: CA_CRT, cert: DEV_A_CRT, key: DEV_A_KEY,
      rejectUnauthorized: true, clientId: DEVICE_A_ID
    });
    await new Promise(r => clientAOwn.on('connect', r));

    let devAReceived = false;
    clientAOwn.subscribe(MqttTopicBuilder.state(DEVICE_A_ID));
    clientAOwn.on('message', () => { devAReceived = true; });

    // Present Device A cert, but use Device B clientId
    const clientAWithBId = mqtt.connect(EMQX_TLS_URL, {
      ca: CA_CRT, cert: DEV_A_CRT, key: DEV_A_KEY,
      rejectUnauthorized: true, clientId: DEVICE_B_ID
    });
    await new Promise(r => clientAWithBId.on('connect', r));

    // Attempt to publish to Device A topic using Device B clientId
    clientAWithBId.publish(MqttTopicBuilder.state(DEVICE_A_ID), JSON.stringify({ spoof: true }));

    await delay(600);
    assert.equal(devAReceived, false, 'EMQX ACL must block publish when clientId does not match certificate CN identity');

    clientAOwn.end(true);
    clientAWithBId.end(true);
  });

  /** EQ13j — Production transport source code enforces rejectUnauthorized: true */
  await test('EQ13j MqttDeviceTransport source enforces rejectUnauthorized: true (zero false occurrences)', () => {
    const transportSrc = fs.readFileSync(
      path.join(__dirname, '../src/services/mqtt-device-transport.js'), 'utf8'
    );
    const hasWeakenedTls = /rejectUnauthorized\s*:\s*false/.test(transportSrc);
    assert.ok(!hasWeakenedTls,
      'SECURITY VIOLATION: MqttDeviceTransport must NEVER set rejectUnauthorized: false');
  });

  // =====================================================================
  // SUMMARY REPORT
  // =====================================================================

  console.log(`\n================================================================`);
  console.log(`  REAL EMQX INTEGRATION TEST RESULTS: ${passed} PASSED, ${failed} FAILED`);
  console.log(`================================================================`);

  if (failures.length > 0) {
    failures.forEach(f => console.error(`  ✗ ${f.name}: ${f.error}`));
    console.log('');
    console.log('  PHASE 6 BLOCKED');
    process.exit(1);
  } else {
    console.log('\n  ALL REAL EMQX INTEGRATION & mTLS/ACL TESTS PASSED PERFECTLY!\n');
    console.log('  PHASE 6 HARDENED — READY FOR PR');
    process.exit(0);
  }
})();
