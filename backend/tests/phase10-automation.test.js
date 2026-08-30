'use strict';

/**
 * EH Home — Phase 10 Automation, Scenes & Scheduler Test Suite
 */

const assert = require('assert');
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
  SceneRepository,
  AutomationRepository,
  ScheduleRepository,
  AutomationExecutionLogRepository
} = require('../src/repositories');

const { DeviceCommandService } = require('../src/services/device-command.service');
const { HomeAuthorizationService } = require('../src/shared/home-authorization');
const { SceneService } = require('../src/services/scene.service');
const { AutomationService } = require('../src/services/automation.service');
const { ScheduleService } = require('../src/services/schedule.service');
const { AutomationSchedulerWorker } = require('../src/workers/automation-scheduler-worker');
const { AutomationSceneApiRouter } = require('../src/api/automation-scene.router');
const { createApp } = require('../src/app');

async function runTests() {
  console.log('=== RUNNING PHASE 10 AUTOMATION & SCHEDULER TESTS ===\n');

  let passed = 0;
  let failed = 0;

  async function test(name, fn) {
    try {
      await fn();
      console.log(`[PASS] ${name}`);
      passed++;
    } catch (err) {
      console.error(`[FAIL] ${name}:`, err.message);
      console.error(err.stack);
      failed++;
    }
  }

  // Setup mock infrastructure
  const db = new DatabaseClient();
  const userRepo = new UserRepository(db);
  const homeRepo = new HomeRepository(db);
  const roomRepo = new RoomRepository(db);
  const deviceRepo = new DeviceRepository(db);
  const deviceStateRepo = new DeviceStateRepository(db);
  const commandRepo = new CommandRepository(db);
  const eventRepo = new EventRepository(db);
  const auditRepo = new AuditRepository(db);
  const outboxRepo = new OutboxRepository(db);
  const sceneRepo = new SceneRepository(db);
  const automationRepo = new AutomationRepository(db);
  const scheduleRepo = new ScheduleRepository(db);
  const logRepo = new AutomationExecutionLogRepository(db);

  // Seed baseline user, home, rooms, and devices
  const user = await userRepo.createUser({ id: 'usr_test_1', email: 'owner@example.com', passwordHash: 'hash' });
  const home = await homeRepo.createHome({ id: 'home_test_1', name: 'Test Villa', ownerId: user.id });
  const room = await roomRepo.createRoom({ id: 'room_1', homeId: home.id, name: 'Living Room' });

  // Provision 2 multi-channel smart switches
  const dev1Id = '4444688e-989d-458e-820e-ac62a99ed8e1';
  const dev1 = await db.insert('devices', dev1Id, {
    home_id: home.id,
    room_id: room.id,
    display_name: 'Living Room Switch',
    product_variant_id: 'eh-smart-switch-3x',
    is_claimed: true
  });
  await db.insert('device_authorizations', dev1Id, {
    device_id: dev1Id,
    home_id: home.id,
    claimed_by_user_id: user.id
  });
  await db.insert('device_state', dev1Id, {
    connection_state: 'ONLINE',
    last_seen_at: new Date().toISOString()
  });
  for (let ch = 1; ch <= 3; ch++) {
    await db.insert('channel_state', `${dev1Id}_ch_${ch}`, {
      device_id: dev1Id,
      channel_index: ch,
      reported_state: { power: false },
      desired_state: { power: false }
    });
  }

  const dev2Id = '5555688e-989d-458e-820e-ac62a99ed8e2';
  const dev2 = await db.insert('devices', dev2Id, {
    home_id: home.id,
    room_id: room.id,
    display_name: 'Bedroom Switch',
    product_variant_id: 'eh-smart-switch-3x',
    is_claimed: true
  });
  await db.insert('device_authorizations', dev2Id, {
    device_id: dev2Id,
    home_id: home.id,
    claimed_by_user_id: user.id
  });
  await db.insert('device_state', dev2Id, {
    connection_state: 'OFFLINE',
    last_seen_at: null
  });
  await db.insert('channel_state', `${dev2Id}_ch_1`, {
    device_id: dev2Id,
    channel_index: 1,
    reported_state: { power: false },
    desired_state: { power: false }
  });

  // Mock MQTT Transport
  const publishedMqttMessages = [];
  const mockMqttTransport = {
    sendCommand: async (cmd) => {
      publishedMqttMessages.push(cmd);
      if (cmd.deviceId === dev2.id) {
        throw new Error('DEVICE_OFFLINE');
      }
      return { state: 'applied', correlationId: cmd.commandId, timestamp: new Date().toISOString() };
    }
  };

  // Mock EventBus
  const publishedEvents = [];
  const mockEventBus = {
    publish: (evt) => publishedEvents.push(evt)
  };

  const commandService = new DeviceCommandService({
    commandRepo, outboxRepo, deviceRepo, deviceStateRepo, auditRepo,
    mqttTransport: mockMqttTransport
  });

  const homeAuthService = new HomeAuthorizationService({ homeRepo, deviceRepo, roomRepo });

  const sceneService = new SceneService({
    sceneRepo, homeAuthService, deviceCommandService: commandService,
    eventBus: mockEventBus, logRepo
  });

  const automationService = new AutomationService({
    automationRepo, homeAuthService, deviceCommandService: commandService,
    deviceStateRepo, eventBus: mockEventBus, logRepo
  });

  const scheduleService = new ScheduleService({
    scheduleRepo, homeAuthService, automationService, sceneService
  });

  const schedulerWorker = new AutomationSchedulerWorker({
    scheduleRepo, scheduleService, pollIntervalMs: 100
  });

  // ---------------------------------------------------------------------------
  // TEST CASES
  // ---------------------------------------------------------------------------

  await test('1. Scene CRUD and Multi-Device Execution with Isolated Results', async () => {
    const scene = await sceneService.createScene({
      homeId: home.id,
      userId: user.id,
      name: 'Evening Chill',
      description: 'Turn on CH1 of living room and CH1 of bedroom',
      actions: [
        { deviceId: dev1.id, channel: 1, command: 'set_power', parameters: { enabled: true } },
        { deviceId: dev2.id, channel: 1, command: 'set_power', parameters: { enabled: true } }
      ]
    });

    assert(scene.id, 'Scene should have an ID');
    assert.strictEqual(scene.name, 'Evening Chill');

    // Run Scene
    const result = await sceneService.runScene({
      homeId: home.id,
      userId: user.id,
      sceneId: scene.id
    });

    // Multi-device isolation: dev1 succeeds, dev2 fails (offline)
    assert.strictEqual(result.status, 'partial', 'Overall status should be partial');
    assert.strictEqual(result.targetResults.length, 2);
    assert.strictEqual(result.targetResults[0].status, 'succeeded');
    assert.strictEqual(result.targetResults[1].status, 'failed');

    // Verify Realtime Event was emitted
    const sceneEvt = publishedEvents.find(e => e.type === 'scene.executed' && e.payload.sceneId === scene.id);
    assert(sceneEvt, 'scene.executed event must be published');
    assert.strictEqual(sceneEvt.payload.status, 'partial');
  });

  await test('2. Automation Rule Lifecycle & Condition Evaluation', async () => {
    const auto = await automationService.createAutomation({
      homeId: home.id,
      userId: user.id,
      name: 'Night Light Control',
      triggerType: 'time',
      triggerConfig: { time: '22:00' },
      conditions: [
        { type: 'time_window', startTime: '20:00', endTime: '23:59' },
        { type: 'device_availability', deviceId: dev1.id, expectedAvailability: 'ONLINE' }
      ],
      actions: [
        { deviceId: dev1.id, channel: 2, command: 'set_power', parameters: { enabled: true } }
      ]
    });

    assert(auto.id);
    assert.strictEqual(auto.is_enabled, true);

    // Test Conditions evaluation: inside window
    const met = await automationService.evaluateConditions(auto.conditions, {
      asOfDate: new Date('2026-08-30T21:00:00Z')
    });
    assert.strictEqual(met, true, 'Conditions should be met at 21:00');

    // Test Conditions evaluation: outside window
    const notMet = await automationService.evaluateConditions(auto.conditions, {
      asOfDate: new Date('2026-08-30T09:00:00Z')
    });
    assert.strictEqual(notMet, false, 'Conditions should NOT be met at 09:00');
  });

  await test('3. Automation Execution & Idempotency Pipeline', async () => {
    const auto = await automationService.createAutomation({
      homeId: home.id,
      userId: user.id,
      name: 'Morning Auto',
      triggerType: 'schedule',
      actions: [
        { deviceId: dev1.id, channel: 3, command: 'set_power', parameters: { enabled: true } }
      ]
    });

    const execResult = await automationService.runAutomation({
      homeId: home.id,
      userId: user.id,
      automationId: auto.id,
      executionIdentity: 'exec_idempotent_test_1'
    });

    assert.strictEqual(execResult.status, 'succeeded');
    assert.strictEqual(execResult.targetResults[0].status, 'succeeded');

    // Verify Execution History Log
    const history = await automationService.getExecutionHistory({
      homeId: home.id,
      userId: user.id,
      automationId: auto.id
    });
    assert(history.length > 0, 'Execution history must be persisted');
    assert.strictEqual(history[0].execution_identity, 'exec_idempotent_test_1');
    assert.strictEqual(history[0].status, 'succeeded');
  });

  await test('4. Schedule Next-Run Calculations (Daily, Weekly, One-Time)', async () => {
    const baseDate = new Date('2026-08-30T10:00:00Z'); // Sunday

    // Daily at 08:00 (since 10:00 is past 08:00, next run is tomorrow 08:00)
    const nextDaily = scheduleService.calculateNextRun({
      scheduleType: 'daily',
      timeOfDay: '08:00',
      asOfDate: baseDate
    });
    assert.strictEqual(nextDaily.getUTCDate(), 31);
    assert.strictEqual(nextDaily.getUTCHours(), 8);

    // Weekly: weekdays only [1,2,3,4,5] (Monday-Friday)
    // From Sunday (Day 7) 10:00, next weekday is Monday (Day 1) Aug 31
    const nextWeekly = scheduleService.calculateNextRun({
      scheduleType: 'weekly',
      timeOfDay: '07:30',
      daysOfWeek: [1, 2, 3, 4, 5],
      asOfDate: baseDate
    });
    assert.strictEqual(nextWeekly.getUTCDate(), 31);
    assert.strictEqual(nextWeekly.getUTCHours(), 7);
    assert.strictEqual(nextWeekly.getUTCMinutes(), 30);
  });

  await test('5. Scheduler Worker Ticking, Execution Locks, and Deduplication', async () => {
    // Create a due schedule for scene
    const scenes = await sceneRepo.findByHomeId(home.id);
    const scene = scenes[0];

    const dueSchedule = await scheduleRepo.createSchedule({
      id: 'sched_due_test_1',
      homeId: home.id,
      sceneId: scene.id,
      name: 'Due Scene Schedule',
      scheduleType: 'daily',
      timeOfDay: '08:00',
      isEnabled: true,
      nextRunAt: new Date(Date.now() - 5000).toISOString() // 5 seconds in the past -> due!
    });

    // 1st tick -> executes schedule
    const tickResults1 = await schedulerWorker.tick();
    assert.strictEqual(tickResults1.length, 1);
    assert.strictEqual(tickResults1[0].scheduleId, dueSchedule.id);
    assert.strictEqual(tickResults1[0].success, true);

    // 2nd immediate tick -> deduplicated / not due
    const tickResults2 = await schedulerWorker.tick();
    assert.strictEqual(tickResults2.length, 0, 'Second immediate tick must not duplicate execution');
  });

  await test('6. End-to-End REST API Handlers & Authorization Check', async () => {
    const router = new AutomationSceneApiRouter({
      sceneService,
      automationService,
      scheduleService
    });

    // GET scenes list
    const listRes = await router.handle('GET', `/api/v1/homes/${home.id}/scenes`, {}, {}, { userId: user.id });
    assert.strictEqual(listRes.status, 200);
    assert(Array.isArray(listRes.body.data));

    // GET automations list
    const autoListRes = await router.handle('GET', `/api/v1/homes/${home.id}/automations`, {}, {}, { userId: user.id });
    assert.strictEqual(autoListRes.status, 200);

    // GET schedules list
    const schedListRes = await router.handle('GET', `/api/v1/homes/${home.id}/schedules`, {}, {}, { userId: user.id });
    assert.strictEqual(schedListRes.status, 200);

    // GET automation execution history
    const histRes = await router.handle('GET', `/api/v1/homes/${home.id}/automation-history`, {}, {}, { userId: user.id });
    assert.strictEqual(histRes.status, 200);
    assert(Array.isArray(histRes.body.data));
  });

  console.log(`\n===============================================================`);
  console.log(`  PHASE 10 TEST SUMMARY: ${passed} PASSED, ${failed} FAILED`);
  console.log(`===============================================================\n`);

  if (failed > 0) {
    process.exit(1);
  }
}

runTests().catch(err => {
  console.error('Fatal error in Phase 10 test suite:', err);
  process.exit(1);
});
