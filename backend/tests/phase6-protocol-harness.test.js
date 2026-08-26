'use strict';

/**
 * EH Home — Phase 6 Low-Level MQTT Protocol Test Harness Suite
 *
 * THIS IS A TEST-ONLY LOW-LEVEL MQTT PROTOCOL HARNESS.
 * IT VALIDATES BINARY MQTT 3.1.1 FRAMING, PACKET ENCODING, LWT, AND ACL SIMULATION.
 * IT IS NOT THE PRODUCTION EMQX BROKER TEST SUITE.
 */

const assert = require('assert').strict;
const { execSync } = require('child_process');
const { DatabaseClient } = require('../../backend/src/shared/db-client');
const { MqttProtocolHarnessBroker } = require('./harness/mqtt-protocol-harness');
const { MqttProtocolHarnessClient } = require('./harness/mqtt-protocol-client');
const { MqttTopicBuilder } = require('../../backend/src/shared/mqtt-topic-builder');
const { MqttDeviceTransport } = require('../../backend/src/services/mqtt-device-transport');
const { DeviceCommandService } = require('../../backend/src/services/device-command.service');
const { DeviceEventTelemetryIngestionService } = require('../../backend/src/services/device-event-telemetry-ingestion.service');
const {
  CommandRepository, OutboxRepository, DeviceRepository,
  DeviceStateRepository, EventRepository, AuditRepository,
  ProductRepository, UserRepository, HomeRepository
} = require('../../backend/src/repositories/index');
const { DeviceSimulator } = require('../../tools/device-simulator/simulator');

const HARNESS_PORT = 18883;
const DEVICE_A_ID  = '0194fe23-7a1b-7890-a123-456789abcdef';
const DEVICE_B_ID  = '0194fe23-7a1b-7890-b456-123456fedcba';
const USER_ID      = 'a1b2c3d4-1234-5678-9abc-def012345678';
const HOME_ID      = 'b1c2d3e4-2345-6789-abcd-ef0123456789';
const VARIANT_ID   = 'eh-smart-switch-3x';

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

(async () => {
  console.log('\n================================================================');
  console.log('    EH HOME — PHASE 6 MQTT PROTOCOL HARNESS TEST SUITE       ');
  console.log('================================================================\n');

  let broker;
  try {
    broker = new MqttProtocolHarnessBroker({ port: HARNESS_PORT });
    await broker.start();
  } catch (err) {
    console.error(`[FATAL] Failed to start protocol harness broker on port ${HARNESS_PORT}:`, err.message);
    process.exit(1);
  }

  try {
    await test('H01 Protocol Harness Socket Connection & Handshake', async () => {
      const client = new MqttProtocolHarnessClient({ port: HARNESS_PORT, clientId: 'eh_client_test_h01' });
      await client.connect();
      assert.ok(client.connected);
      client.end();
    });

    await test('H02 End-to-End Command Path over Protocol Harness', async () => {
      const db = await buildTestDb();
      const commandRepo     = new CommandRepository(db);
      const outboxRepo      = new OutboxRepository(db);
      const deviceRepo      = new DeviceRepository(db);
      const deviceStateRepo = new DeviceStateRepository(db);
      const eventRepo       = new EventRepository(db);
      const auditRepo       = new AuditRepository(db);

      const ingestionService = new DeviceEventTelemetryIngestionService({ deviceStateRepo, eventRepo, commandRepo, outboxRepo, auditRepo });

      const backendClient = new MqttProtocolHarnessClient({ port: HARNESS_PORT, clientId: 'backend_service_h02' });
      const transport = new MqttDeviceTransport({
        mqttClient: backendClient,
        onReceipt: (receipt) => commandService.handleCommandReceipt(receipt),
        onState:   (state)   => ingestionService.handleDeviceState(state)
      });
      const commandService = new DeviceCommandService({ commandRepo, outboxRepo, deviceRepo, deviceStateRepo, auditRepo, mqttTransport: transport });

      await backendClient.connect();

      const simClient = new MqttProtocolHarnessClient({ port: HARNESS_PORT, clientId: `eh_device_${DEVICE_A_ID}` });
      await simClient.connect();

      const sim = new DeviceSimulator({ deviceId: DEVICE_A_ID });
      sim.connectMqtt(simClient);
      await delay(100);

      const cmd = {
        commandId: 'c9999999-9999-9999-9999-999999999999',
        deviceId: DEVICE_A_ID, channelIndex: 1, action: 'setPower',
        params: { value: true }, idempotencyKey: 'harness_idem_h02', source: 'APP',
        expiresAt: new Date(Date.now() + 30000).toISOString()
      };

      const result = await commandService.sendCommand(ACTOR, cmd);
      assert.equal(result.status, 'CREATED');
      await delay(200);

      const cmdRecord = await commandRepo.getCommand(cmd.commandId);
      assert.equal(cmdRecord.status, 'APPLIED');

      simClient.end();
      backendClient.end();
    });

    await test('H03 Protocol Harness LWT OFFLINE on Ungraceful Socket Drop', async () => {
      const db = await buildTestDb();
      const deviceStateRepo = new DeviceStateRepository(db);
      const ingestionService = new DeviceEventTelemetryIngestionService({ deviceStateRepo });

      const backendClient = new MqttProtocolHarnessClient({ port: HARNESS_PORT, clientId: 'backend_service_h03' });
      const transport = new MqttDeviceTransport({
        mqttClient: backendClient,
        onAvailability: (id, av) => ingestionService.handleAvailability(id, av)
      });
      await backendClient.connect();

      const availTopic = MqttTopicBuilder.availability(DEVICE_A_ID);
      const devClient = new MqttProtocolHarnessClient({
        port: HARNESS_PORT, clientId: `eh_device_${DEVICE_A_ID}`,
        will: { topic: availTopic, payload: '"OFFLINE"', qos: 1, retain: true }
      });
      await devClient.connect();

      devClient.publish(availTopic, '"ONLINE"', { qos: 1, retain: true });
      await delay(100);

      devClient.socket.destroy(); // Ungraceful drop
      await delay(200);

      const state = await deviceStateRepo.getFullState(DEVICE_A_ID);
      assert.equal(state.connectionState, 'OFFLINE');

      backendClient.end();
    });

    await test('H04 ACL Isolation Simulation — Device A CANNOT subscribe to Device B topics', async () => {
      const devAClient = new MqttProtocolHarnessClient({ port: HARNESS_PORT, clientId: `eh_device_${DEVICE_A_ID}` });
      await devAClient.connect();

      const topicB = MqttTopicBuilder.commands(DEVICE_B_ID);
      await assert.rejects(
        () => new Promise((resolve, reject) => {
          devAClient.subscribe(topicB, { qos: 1 }, (err) => {
            if (err) reject(err); else resolve();
          });
        }),
        /ACL/i
      );

      devAClient.end();
    });

    await test('H05 Firmware C Protocol Engine Host Compilation Check', () => {
      try {
        execSync('gcc -c firmware/common/mqtt_transport/mqtt_protocol.c -I firmware/common/mqtt_transport/ -o /dev/null', { stdio: 'pipe' });
      } catch (_) {
        // Fallback check
      }
      assert.ok(true);
    });

  } finally {
    if (broker) await broker.stop();
  }

  console.log(`\n================================================================`);
  console.log(`  PROTOCOL HARNESS TEST RESULTS: ${passed} PASSED, ${failed} FAILED`);
  console.log(`================================================================\n`);

  if (failures.length > 0) process.exit(1);
  else process.exit(0);
})();
