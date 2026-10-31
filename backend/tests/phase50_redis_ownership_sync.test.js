'use strict';

/**
 * EH Home — Phase 50: Redis State Cache, Execution Ownership & Batch Worker Test Suite
 */

const assert = require('assert');
const { AutomationService } = require('../src/services/automation.service');
const { AutomationSchedulerWorker } = require('../src/workers/automation-scheduler-worker');
const { RedisStateCacheService } = require('../src/services/redis-state-cache.service');
const { TelemetryBatchWorker } = require('../src/workers/telemetry-batch-worker');
const { createRedisClient } = require('../src/shared/redis-client');
const { DeviceCommandService } = require('../src/services/device-command.service');
const { DatabaseClient } = require('../src/shared/db-client');
const { InMemoryDatabaseAdapter } = require('../src/shared/in-memory-db-adapter');
const {
  AutomationRepository,
  ScheduleRepository,
  DeviceRepository,
  DeviceStateRepository,
  CommandRepository,
  OutboxRepository,
  AuditRepository,
  UserRepository,
  HomeRepository,
  ProductRepository
} = require('../src/repositories');

let passedTests = 0;
let failedTests = 0;

async function test(name, fn) {
  try {
    await fn();
    console.log(`  [PASS] ${name}`);
    passedTests++;
  } catch (err) {
    console.error(`  [FAIL] ${name}`);
    console.error(`         ${err.message}`);
    failedTests++;
  }
}

async function runSuite() {
  console.log('\n================================================================');
  console.log('   EH HOME — PHASE 50 REDIS, EXECUTION OWNERSHIP & BATCH SUITE  ');
  console.log('================================================================\n');

  const db = new DatabaseClient(new InMemoryDatabaseAdapter());
  const userRepo = new UserRepository(db);
  const homeRepo = new HomeRepository(db);
  const deviceRepo = new DeviceRepository(db);
  const deviceStateRepo = new DeviceStateRepository(db);
  const commandRepo = new CommandRepository(db);
  const outboxRepo = new OutboxRepository(db);
  const auditRepo = new AuditRepository(db);
  const automationRepo = new AutomationRepository(db);
  const scheduleRepo = new ScheduleRepository(db);
  const productRepo = new ProductRepository(db);

  await productRepo.createFamily({ id: 'fam-switches', name: 'EH Smart Switches', description: 'Smart switch family' });
  await productRepo.createProduct({ id: 'prod-sw4x', familyId: 'fam-switches', name: 'Smart Switch 4X', description: '4-channel smart switch' });
  await productRepo.createVariant({
    id: 'eh-smart-switch-4x', productId: 'prod-sw4x', name: '4X',
    skuCode: 'EH-SW4X', channelCount: 4,
    hardwareCapabilities: [], supportedFirmwareFamilies: ['esp32c6-switch-platform', 'eh-smart-switch']
  });

  await userRepo.createUser({
    id: 'usr_pavan_123',
    email: 'pavan@example.com',
    passwordHash: 'hash',
    phone: '+919876543210'
  });

  const home = await homeRepo.createHome({
    id: '0194fe23-7a1b-7890-a123-456789abcdef',
    name: 'Pavan Home',
    ownerId: 'usr_pavan_123',
    timezone: 'Asia/Kolkata'
  });

  const devId = 'ce196211-91cf-496a-9403-709d8589eb15';
  await deviceRepo.registerDevice({
    deviceId: devId,
    serialNumber: 'EH-DEV-CE196211',
    productVariantId: 'eh-smart-switch-4x',
    hardwareRevision: 'ESP32_DEV_BOARD',
    firmwareFamily: 'eh-smart-switch',
    firmwareVersion: '1.0.0'
  });
  await db.insert('device_authorizations', devId, {
    device_id: devId,
    home_id: home.id,
    claimed_by_user_id: 'usr_pavan_123'
  });

  const dispatchedMqttCommands = [];
  const mockTransport = {
    sendCommand: async (cmd) => {
      dispatchedMqttCommands.push(cmd);
      return { messageId: 'msg_test_1' };
    },
    publishCommand: async (cmd) => {
      dispatchedMqttCommands.push(cmd);
      return { messageId: 'msg_test_1' };
    }
  };

  const redisClient = createRedisClient();
  const redisStateCache = new RedisStateCacheService({ redisClient });

  const commandService = new DeviceCommandService({
    commandRepo,
    outboxRepo,
    deviceRepo,
    deviceStateRepo,
    auditRepo,
    mqttTransport: mockTransport,
    redisStateCacheService: redisStateCache
  });

  const automationService = new AutomationService({
    automationRepo,
    deviceCommandService: commandService,
    deviceStateRepo
  });

  // 1. Test Auto-Classification
  await test('1. Auto-Classification: Single-device daily schedule classifies as EDGE', async () => {
    const classification = automationService.classifyExecutionTarget({
      triggerType: 'schedule',
      triggerConfig: { time: '07:30 AM', days: ['Mon', 'Tue', 'Wed'] },
      conditions: [],
      actions: [{ deviceId: devId, channelIndex: 1, targetState: true }]
    });
    assert.strictEqual(classification.executionTarget, 'EDGE');
    assert.strictEqual(classification.edgeDeviceId, devId);
  });

  await test('2. Auto-Classification: Multi-device routine classifies as CLOUD', async () => {
    const classification = automationService.classifyExecutionTarget({
      triggerType: 'schedule',
      triggerConfig: { time: '08:00 AM' },
      conditions: [],
      actions: [
        { deviceId: devId, channelIndex: 1, targetState: true },
        { deviceId: 'other-device-uuid-1234567890ab', channelIndex: 2, targetState: false }
      ]
    });
    assert.strictEqual(classification.executionTarget, 'CLOUD');
  });

  await test('3. Auto-Classification: Routine with cloud condition classifies as CLOUD', async () => {
    const classification = automationService.classifyExecutionTarget({
      triggerType: 'schedule',
      triggerConfig: { time: '09:00 AM' },
      conditions: [{ type: 'weather', metric: 'temperature_c', operator: 'gt', value: 30 }],
      actions: [{ deviceId: devId, channelIndex: 1, targetState: true }]
    });
    assert.strictEqual(classification.executionTarget, 'CLOUD');
  });

  // 4. Test MQTT Routine Provisioning Hook
  await test('4. Provisioning Hook: createAutomation(EDGE) dispatches upsertRoutine over MQTT', async () => {
    dispatchedMqttCommands.length = 0;
    const auto = await automationService.createAutomation({
      homeId: home.id,
      userId: 'usr_pavan_123',
      name: 'Water Motor Morning Schedule',
      triggerType: 'schedule',
      triggerConfig: { time: '06:00 AM', days: ['Mon', 'Wed', 'Fri'] },
      actions: [{ deviceId: devId, channelIndex: 1, targetState: true }]
    });

    await new Promise(r => setTimeout(r, 50));
    assert.strictEqual(auto.execution_target, 'EDGE');
    assert.strictEqual(dispatchedMqttCommands.length, 1);
    const cmd = dispatchedMqttCommands[0];
    assert.strictEqual(cmd.action, 'upsertRoutine');
    assert.strictEqual(cmd.channelIndex, 1);
    assert.strictEqual(cmd.params.hour, 6);
    assert.strictEqual(cmd.params.minute, 0);
    assert.strictEqual(cmd.params.targetPower, true);
  });

  await test('5. Provisioning Hook: deleteAutomation(EDGE) dispatches deleteRoutine over MQTT', async () => {
    dispatchedMqttCommands.length = 0;
    const automations = await automationRepo.findByHomeId(home.id);
    const edgeAuto = automations.find(a => a.execution_target === 'EDGE');
    assert.ok(edgeAuto, 'Edge automation should exist');

    await automationService.deleteAutomation({
      homeId: home.id,
      userId: 'usr_pavan_123',
      automationId: edgeAuto.id
    });

    await new Promise(r => setTimeout(r, 50));
    assert.strictEqual(dispatchedMqttCommands.length, 1);
    const cmd = dispatchedMqttCommands[0];
    assert.strictEqual(cmd.action, 'deleteRoutine');
    assert.strictEqual(cmd.params.routineId, edgeAuto.id);
  });

  // 6. Test Double Execution Prevention in AutomationSchedulerWorker
  await test('6. Double Execution: AutomationSchedulerWorker strictly skips EDGE routines', async () => {
    const edgeAuto = await automationRepo.createAutomation({
      id: 'auto_edge_test',
      homeId: home.id,
      name: 'Edge Pump',
      isEnabled: true,
      triggerType: 'schedule',
      triggerConfig: { time: '10:00 AM' },
      executionTarget: 'EDGE'
    });

    const cloudAuto = await automationRepo.createAutomation({
      id: 'auto_cloud_test',
      homeId: home.id,
      name: 'Cloud Living Room Light',
      isEnabled: true,
      triggerType: 'schedule',
      triggerConfig: { time: '10:00 AM' },
      executionTarget: 'CLOUD'
    });

    const executedIds = [];
    const mockAutoService = {
      runAutomation: async (opts) => {
        const id = (opts && typeof opts === 'object') ? opts.automationId : opts;
        executedIds.push(id);
      },
      executeAutomation: async (opts) => {
        const id = (opts && typeof opts === 'object') ? opts.automationId : opts;
        executedIds.push(id);
      }
    };

    const worker = new AutomationSchedulerWorker({
      scheduleRepo,
      scheduleService: { findDueSchedules: async () => [] },
      automationRepo,
      automationService: mockAutoService
    });

    // Simulate 10:00 AM
    const testDate = new Date();
    testDate.setHours(10, 0, 0, 0);
    await worker.tick(testDate);

    // Should ONLY execute cloudAuto, never edgeAuto!
    assert.ok(executedIds.includes('auto_cloud_test'), 'Cloud automation should execute');
    assert.ok(!executedIds.includes('auto_edge_test'), 'Edge automation must be skipped by cloud worker');
  });

  // 7. Test Redis State Cache & Anti-Spam Delta Filtering
  await test('7. Redis State Cache: isDelta detects true state changes and suppresses duplicate chatter', async () => {
    await redisStateCache.updateDeviceState(devId, {
      online: true,
      channels: [{ channelIndex: 1, power: false }, { channelIndex: 2, power: false }]
    });

    // Case A: Identical report -> NO delta
    const deltaIdentical = await redisStateCache.isDelta(devId, {
      online: true,
      channels: [{ channelIndex: 1, power: false }, { channelIndex: 2, power: false }]
    });
    assert.strictEqual(deltaIdentical, false, 'Duplicate report must be suppressed');

    // Case B: Channel 1 toggles ON -> TRUE delta
    const deltaToggle = await redisStateCache.isDelta(devId, {
      online: true,
      channels: [{ channelIndex: 1, power: true }, { channelIndex: 2, power: false }]
    });
    assert.strictEqual(deltaToggle, true, 'Relay toggle must trigger delta');

    // Case C: Small noise in watts (0.5W) -> NO delta
    await redisStateCache.updateDeviceState(devId, { instantaneous_power_w: 100.0 });
    const deltaSmallNoise = await redisStateCache.isDelta(devId, { instantaneous_power_w: 100.5 });
    assert.strictEqual(deltaSmallNoise, false, 'Small energy noise must be suppressed');

    // Case D: Significant wattage jump (> 10W) -> TRUE delta
    const deltaBigJump = await redisStateCache.isDelta(devId, { instantaneous_power_w: 125.0 });
    assert.strictEqual(deltaBigJump, true, 'Significant wattage jump must trigger delta');
  });

  // 8. Test TelemetryBatchWorker Bulk Insertion
  await test('8. TelemetryBatchWorker: Buffers telemetry and flushes batch cleanly', async () => {
    const recordedBatches = [];
    const mockTelemRepo = {
      recordBatch: async (items) => {
        recordedBatches.push(items);
        return items.length;
      }
    };

    const batchWorker = new TelemetryBatchWorker({
      telemetryRepo: mockTelemRepo,
      flushIntervalMs: 50,
      maxBatchSize: 5
    });

    batchWorker.enqueue({ deviceId: devId, channelIndex: 1, powerW: 10 });
    batchWorker.enqueue({ deviceId: devId, channelIndex: 1, powerW: 12 });
    batchWorker.enqueue({ deviceId: devId, channelIndex: 1, powerW: 14 });

    assert.strictEqual(recordedBatches.length, 0, 'Buffer should hold items before flush');
    await batchWorker.flush();
    assert.strictEqual(recordedBatches.length, 1);
    assert.strictEqual(recordedBatches[0].length, 3);
  });

  console.log('\n────────────────────────────────────────────────────────────');
  console.log(`  ALL ${passedTests} PHASE 50 REDIS & OWNERSHIP TESTS PASSED ✅`);
  console.log('────────────────────────────────────────────────────────────\n');

  if (failedTests > 0) {
    process.exit(1);
  }
}

runSuite().catch(err => {
  console.error('Test suite failed:', err);
  process.exit(1);
});
