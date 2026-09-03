'use strict';

/**
 * EH Home — Phase 20 Smart Energy Automation & Optimization Test Suite
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
  AutomationRepository,
  AutomationExecutionLogRepository,
  SceneRepository,
  DeviceTelemetryRepository,
  TelemetryAggregateRepository,
  EnergyThresholdRepository,
  EnergyEventRepository,
  EnergyAutomationExecutionRepository,
  EnergyOptimizationRepository
} = require('../src/repositories');

const { HomeAuthorizationService } = require('../src/shared/home-authorization');
const { DeviceCommandService } = require('../src/services/device-command.service');
const { AutomationService } = require('../src/services/automation.service');
const { SceneService } = require('../src/services/scene.service');
const { EnergyService } = require('../src/services/energy.service');
const { EnergyApiRouter } = require('../src/api/energy.router');
const { DataRetentionService } = require('../src/services/data-retention.service');

console.log('===============================================================');
console.log('  EH HOME — PHASE 20 SMART ENERGY AUTOMATION & OPTIMIZATION    ');
console.log('===============================================================\n');

let passedTests = 0;
let totalTests = 0;

async function runAsyncTest(name, fn) {
  totalTests++;
  try {
    await fn();
    console.log(`[PASS] ${name}`);
    passedTests++;
  } catch (err) {
    console.error(`[FAIL] ${name}:`, err);
    throw err;
  }
}

// Canonical UUID Fixtures
const USER_OWNER = '0194fe20-0000-7000-8000-000000000001';
const USER_MEMBER = '0194fe20-0000-7000-8000-000000000002';
const USER_VIEWER = '0194fe20-0000-7000-8000-000000000003';
const USER_STRANGER = '0194fe20-0000-7000-8000-000000000004';
const HOME_1 = '0194fe20-0000-7000-8000-111111111111';
const HOME_2 = '0194fe20-0000-7000-8000-222222222222';
const ROOM_KITCHEN = '0194fe20-0000-7000-8000-333333333331';
const ROOM_LIVING = '0194fe20-0000-7000-8000-333333333332';
const DEV_OVEN_1 = '0194fe20-0000-7000-8000-444444444441';
const DEV_HEATER_1 = '0194fe20-0000-7000-8000-444444444442';

// ---------------------------------------------------------------------------
// Test Setup Helper
// ---------------------------------------------------------------------------
async function setupTestContext() {
  const db = new DatabaseClient(':memory:');
  const userRepo = new UserRepository(db);
  const homeRepo = new HomeRepository(db);
  const roomRepo = new RoomRepository(db);
  const deviceRepo = new DeviceRepository(db);
  const deviceStateRepo = new DeviceStateRepository(db);
  const commandRepo = new CommandRepository(db);
  const eventRepo = new EventRepository(db);
  const auditRepo = new AuditRepository(db);
  const outboxRepo = new OutboxRepository(db);
  const automationRepo = new AutomationRepository(db);
  const logRepo = new AutomationExecutionLogRepository(db);
  const sceneRepo = new SceneRepository(db);
  const telemetryRepo = new DeviceTelemetryRepository(db);
  const aggregateRepo = new TelemetryAggregateRepository(db);
  const thresholdRepo = new EnergyThresholdRepository(db);
  const energyEventRepo = new EnergyEventRepository(db);
  const energyExecutionRepo = new EnergyAutomationExecutionRepository(db);
  const energyOptimizationRepo = new EnergyOptimizationRepository(db);

  const homeAuthService = new HomeAuthorizationService({ homeRepo, deviceRepo, roomRepo });

  // Simulated MQTT command transport
  const sentMqttCommands = [];
  const mqttTransport = {
    sendCommand: async (commandEnvelope) => {
      sentMqttCommands.push(commandEnvelope);
      return { status: 'APPLIED', state: 'applied' };
    }
  };

  const commandService = new DeviceCommandService({
    commandRepo, outboxRepo, deviceRepo, deviceStateRepo, auditRepo, mqttTransport
  });

  const sceneService = new SceneService({
    sceneRepo, homeAuthService, deviceCommandService: commandService, logRepo
  });

  const automationService = new AutomationService({
    automationRepo,
    homeAuthService,
    deviceCommandService: commandService,
    deviceStateRepo,
    logRepo,
    telemetryRepo,
    aggregateRepo,
    energyExecutionRepo,
    sceneService
  });

  const energyService = new EnergyService({
    telemetryRepo,
    aggregateRepo,
    thresholdRepo,
    eventRepo: energyEventRepo,
    deviceRepo,
    roomRepo,
    homeRepo,
    automationService,
    optimizationRepo: energyOptimizationRepo
  });

  const energyRouter = new EnergyApiRouter({
    energyService,
    homeAuthService,
    telemetryRepo,
    thresholdRepo,
    eventRepo: energyEventRepo,
    automationService,
    executionRepo: energyExecutionRepo,
    optimizationRepo: energyOptimizationRepo
  });

  // Seed Product Families & Variants
  await db.insert('product_families', 'fam-switches', { id: 'fam-switches', name: 'EH Smart Switches', slug: 'switches' });
  await db.insert('products', 'prod-sw3x', { id: 'prod-sw3x', family_id: 'fam-switches', name: 'Smart Switch 3X', slug: 'smart-switch-3x' });
  await db.insert('product_variants', 'eh-smart-switch-3x', {
    id: 'eh-smart-switch-3x',
    product_id: 'prod-sw3x',
    name: '3X',
    sku_code: 'EH-SW3X',
    channel_count: 3,
    hardware_capabilities: ['power', 'relay', 'energy', 'voltage', 'current'],
    supported_firmware_families: ['esp32c6-switch-platform', 'esp32-switch-platform']
  });

  // Seed Users
  await userRepo.createUser({ id: USER_OWNER, email: 'owner@ehhome.io', passwordHash: 'hash' });
  await userRepo.createUser({ id: USER_MEMBER, email: 'member@ehhome.io', passwordHash: 'hash' });
  await userRepo.createUser({ id: USER_VIEWER, email: 'viewer@ehhome.io', passwordHash: 'hash' });
  await userRepo.createUser({ id: USER_STRANGER, email: 'stranger@ehhome.io', passwordHash: 'hash' });

  // Seed Homes
  await homeRepo.createHome({ id: HOME_1, name: 'EH Smart Home A', ownerId: USER_OWNER });
  await homeRepo.createHome({ id: HOME_2, name: 'EH Smart Home B', ownerId: USER_STRANGER });

  // Seed Memberships
  await homeRepo.addMembership({ homeId: HOME_1, userId: USER_MEMBER, role: 'MEMBER' });
  await homeRepo.addMembership({ homeId: HOME_1, userId: USER_VIEWER, role: 'VIEWER' });

  // Seed Rooms
  await roomRepo.createRoom({ id: ROOM_KITCHEN, homeId: HOME_1, name: 'Kitchen' });
  await roomRepo.createRoom({ id: ROOM_LIVING, homeId: HOME_1, name: 'Living Room' });

  // Seed Devices
  await deviceRepo.createDevice({
    id: DEV_OVEN_1,
    serial_number: 'SN_OVEN_01',
    product_variant_id: 'eh-smart-switch-3x',
    product_family: 'switch',
    hardware_revision: '1.0'
  });
  await deviceRepo.claimDevice({
    deviceId: DEV_OVEN_1,
    homeId: HOME_1,
    roomId: ROOM_KITCHEN,
    customName: 'Smart Oven'
  });
  await deviceStateRepo.updateChannelState(DEV_OVEN_1, 1, { reportedState: { power: true } });

  await deviceRepo.createDevice({
    id: DEV_HEATER_1,
    serial_number: 'SN_HEAT_01',
    product_variant_id: 'eh-smart-switch-3x',
    product_family: 'switch',
    hardware_revision: '1.0'
  });
  await deviceRepo.claimDevice({
    deviceId: DEV_HEATER_1,
    homeId: HOME_1,
    roomId: ROOM_LIVING,
    customName: 'Living Room Heater'
  });
  await deviceStateRepo.updateChannelState(DEV_HEATER_1, 1, { reportedState: { power: true } });

  return {
    db,
    userRepo,
    homeRepo,
    roomRepo,
    deviceRepo,
    deviceStateRepo,
    commandRepo,
    automationRepo,
    sceneRepo,
    telemetryRepo,
    aggregateRepo,
    thresholdRepo,
    energyEventRepo,
    energyExecutionRepo,
    energyOptimizationRepo,
    homeAuthService,
    commandService,
    sceneService,
    automationService,
    energyService,
    energyRouter,
    sentMqttCommands
  };
}

async function main() {
  // ---------------------------------------------------------------------------
  // 1. Energy Condition Evaluation & Scope Tests
  // ---------------------------------------------------------------------------
  await runAsyncTest('1. Energy Condition Evaluation (Instantaneous power, cumulative energy, scopes, time windows)', async () => {
    const ctx = await setupTestContext();

    // Condition A: Instantaneous power > 1500W
    const condPowerGT = {
      type: 'energy_condition',
      metric: 'instantaneous_power',
      operator: 'GT',
      threshold: 1500.0
    };

    assert.strictEqual(
      await ctx.automationService.evaluateCondition(condPowerGT, { telemetry: { powerW: 1800.0 } }),
      true,
      '1800W should satisfy > 1500W'
    );
    assert.strictEqual(
      await ctx.automationService.evaluateCondition(condPowerGT, { telemetry: { powerW: 1400.0 } }),
      false,
      '1400W should not satisfy > 1500W'
    );

    // Condition B: Time Window constraint (e.g. 22:00 to 06:00 wrap)
    const condOvernight = {
      type: 'energy_condition',
      metric: 'instantaneous_power',
      operator: 'GT',
      threshold: 500.0,
      timeWindow: { startTime: '22:00', endTime: '06:00' }
    };

    assert.strictEqual(
      await ctx.automationService.evaluateCondition(condOvernight, {
        telemetry: { powerW: 600.0 },
        asOfDate: '2026-09-03T23:30:00.000Z'
      }),
      true,
      'Overnight condition should pass at 23:30'
    );

    assert.strictEqual(
      await ctx.automationService.evaluateCondition(condOvernight, {
        telemetry: { powerW: 600.0 },
        asOfDate: '2026-09-03T14:00:00.000Z'
      }),
      false,
      'Overnight condition should fail at 14:00'
    );

    // Condition C: Missing telemetry handling — never assumes zero!
    assert.strictEqual(
      await ctx.automationService.evaluateCondition(condPowerGT, { telemetry: null }),
      false,
      'Missing telemetry must return false without assuming zero'
    );
  });

  // ---------------------------------------------------------------------------
  // 2. Sustained High Power & Duration Conditions
  // ---------------------------------------------------------------------------
  await runAsyncTest('2. Sustained Power Duration Condition Evaluation', async () => {
    const ctx = await setupTestContext();

    const condSustained = {
      type: 'energy_condition',
      metric: 'sustained_power',
      operator: 'GT',
      threshold: 2000.0,
      durationSeconds: 10,
      deviceId: DEV_OVEN_1
    };

    const evalCtx = {
      automationId: 'auto_sustained_1',
      telemetry: { deviceId: DEV_OVEN_1, powerW: 2500.0 }
    };

    // First sample at t=0
    const firstEval = await ctx.automationService.evaluateCondition(condSustained, evalCtx);
    assert.strictEqual(firstEval, false, 'First observation should not trigger immediately');

    // Fast-forward sustained tracker by 11 seconds
    const trackerKey = `auto_sustained_1_${DEV_OVEN_1}`;
    ctx.automationService._sustainedTracker.set(trackerKey, {
      firstExceededAt: Date.now() - 11000
    });

    const sustainedEval = await ctx.automationService.evaluateCondition(condSustained, evalCtx);
    assert.strictEqual(sustainedEval, true, 'Sustained observation > 10s should trigger');

    // Value drops below threshold — resets tracker
    await ctx.automationService.evaluateCondition(condSustained, {
      automationId: 'auto_sustained_1',
      telemetry: { deviceId: DEV_OVEN_1, powerW: 1200.0 }
    });
    assert.strictEqual(ctx.automationService._sustainedTracker.has(trackerKey), false, 'Tracker reset when power drops');
  });

  // ---------------------------------------------------------------------------
  // 3. Hysteresis & Debounce Engine
  // ---------------------------------------------------------------------------
  await runAsyncTest('3. Hysteresis & Recovery Threshold (Anti-Oscillation)', async () => {
    const ctx = await setupTestContext();

    // Create an automation with activation at 1500W and recovery at 1200W
    const auto = await ctx.automationService.createAutomation({
      homeId: HOME_1,
      userId: USER_OWNER,
      name: 'Oven Overload Protection',
      triggerType: 'energy_threshold',
      scopeType: 'device',
      scopeId: DEV_OVEN_1,
      conditions: [
        {
          type: 'energy_condition',
          metric: 'instantaneous_power',
          operator: 'GT',
          threshold: 1500.0,
          deviceId: DEV_OVEN_1
        }
      ],
      hysteresis: {
        recoveryThreshold: 1200.0,
        cooldownSeconds: 0
      },
      actions: [
        {
          actionType: 'device_command',
          deviceId: DEV_OVEN_1,
          channelIndex: 1,
          command: 'setPower',
          params: { value: false }
        }
      ]
    });

    // 1. First trigger at 1600W -> should succeed
    const res1 = await ctx.automationService.runAutomation({
      homeId: HOME_1,
      automationId: auto.id,
      triggerSource: 'energy_telemetry',
      context: { telemetry: { deviceId: DEV_OVEN_1, powerW: 1600.0 } }
    });
    assert.strictEqual(res1.status, 'succeeded', 'First trigger at 1600W should succeed');

    // 2. Telemetry fluctuates to 1499W (below 1500W, but ABOVE recovery threshold 1200W)
    // Should NOT re-execute or reverse because hysteresis is active!
    const res2 = await ctx.automationService.runAutomation({
      homeId: HOME_1,
      automationId: auto.id,
      triggerSource: 'energy_telemetry',
      context: { telemetry: { deviceId: DEV_OVEN_1, powerW: 1499.0 } }
    });
    assert.strictEqual(res2.status, 'skipped', 'Should be skipped while hysteresis is active');
    assert.strictEqual(res2.skipReason, 'hysteresis_active');

    // 3. Power drops to 1100W (BELOW recovery threshold 1200W) -> recovers!
    const res3 = await ctx.automationService.runAutomation({
      homeId: HOME_1,
      automationId: auto.id,
      triggerSource: 'energy_telemetry',
      context: { telemetry: { deviceId: DEV_OVEN_1, powerW: 1100.0 } }
    });
    assert.strictEqual(res3.status, 'conditions_not_met', 'Conditions not met at 1100W, but hysteresis recovered');

    // 4. Power spikes again to 1700W -> triggers again cleanly!
    const res4 = await ctx.automationService.runAutomation({
      homeId: HOME_1,
      automationId: auto.id,
      triggerSource: 'energy_telemetry',
      context: { telemetry: { deviceId: DEV_OVEN_1, powerW: 1700.0 } }
    });
    assert.strictEqual(res4.status, 'succeeded', 'Triggers again after clean recovery');
  });

  // ---------------------------------------------------------------------------
  // 4. Cooldown & Rate Limiting Debounce
  // ---------------------------------------------------------------------------
  await runAsyncTest('4. Cooldown Debounce & Duplicate Suppression', async () => {
    const ctx = await setupTestContext();

    const auto = await ctx.automationService.createAutomation({
      homeId: HOME_1,
      userId: USER_OWNER,
      name: 'Heater Cooldown Guard',
      triggerType: 'energy_threshold',
      scopeType: 'device',
      scopeId: DEV_HEATER_1,
      cooldownSeconds: 60,
      conditions: [
        {
          type: 'energy_condition',
          metric: 'instantaneous_power',
          operator: 'GT',
          threshold: 1000.0,
          deviceId: DEV_HEATER_1
        }
      ],
      actions: [
        {
          actionType: 'device_command',
          deviceId: DEV_HEATER_1,
          channelIndex: 1,
          command: 'setPower',
          params: { value: false }
        }
      ]
    });

    // First run
    const res1 = await ctx.automationService.runAutomation({
      homeId: HOME_1,
      automationId: auto.id,
      triggerSource: 'energy_telemetry',
      context: { telemetry: { deviceId: DEV_HEATER_1, powerW: 1200.0 } }
    });
    assert.strictEqual(res1.status, 'succeeded');

    // Immediate second run within 60s cooldown -> suppressed
    const res2 = await ctx.automationService.runAutomation({
      homeId: HOME_1,
      automationId: auto.id,
      triggerSource: 'energy_telemetry',
      context: { telemetry: { deviceId: DEV_HEATER_1, powerW: 1300.0 } }
    });
    assert.strictEqual(res2.status, 'skipped');
    assert.strictEqual(res2.skipReason, 'in_cooldown');
  });

  // ---------------------------------------------------------------------------
  // 5. Automation Loop Prevention
  // ---------------------------------------------------------------------------
  await runAsyncTest('5. Automation Recursion & Loop Prevention Safeguard', async () => {
    const ctx = await setupTestContext();

    const auto = await ctx.automationService.createAutomation({
      homeId: HOME_1,
      userId: USER_OWNER,
      name: 'Recursive Automation',
      triggerType: 'energy_threshold',
      conditions: [],
      actions: []
    });

    // Attempt to run with executionChain already containing auto.id
    const res = await ctx.automationService.runAutomation({
      homeId: HOME_1,
      automationId: auto.id,
      triggerSource: 'scene_execution',
      context: {
        depth: 4,
        executionChain: [auto.id, 'scene_1', auto.id]
      }
    });

    assert.strictEqual(res.status, 'skipped');
    assert.strictEqual(res.skipReason, 'loop_detected');
  });

  // ---------------------------------------------------------------------------
  // 6. Ingestion Telemetry Hook & Execution Logging
  // ---------------------------------------------------------------------------
  await runAsyncTest('6. Telemetry Ingestion Auto-Trigger & Execution Logging', async () => {
    const ctx = await setupTestContext();

    // Create rule that triggers on oven power > 2000W
    const auto = await ctx.automationService.createAutomation({
      homeId: HOME_1,
      userId: USER_OWNER,
      name: 'High Load Cutoff',
      triggerType: 'energy_threshold',
      scopeType: 'device',
      scopeId: DEV_OVEN_1,
      conditions: [
        {
          type: 'energy_condition',
          metric: 'instantaneous_power',
          operator: 'GT',
          threshold: 2000.0,
          deviceId: DEV_OVEN_1
        }
      ],
      actions: [
        {
          actionType: 'device_command',
          deviceId: DEV_OVEN_1,
          channelIndex: 1,
          command: 'setPower',
          params: { value: false }
        }
      ]
    });

    // Ingest high telemetry (2400W = 2,400,000 mW)
    const telemMsg = {
      deviceId: DEV_OVEN_1,
      channelIndex: 1,
      v_mv: 230000,
      i_ma: 10430,
      p_mw: 2400000,
      e_tot_wh: 5200,
      e_int_mwh: 100,
      freq_mhz: 50000,
      pf_x1000: 1000,
      flags: 0,
      sequenceNumber: 101,
      timestamp: new Date().toISOString()
    };

    await ctx.energyService.ingestTelemetry(telemMsg);

    // Verify command was sent to MQTT
    const lastCmd = ctx.sentMqttCommands.find(c => c.deviceId === DEV_OVEN_1);
    assert.ok(lastCmd, 'Command should have been dispatched via DeviceCommandService');
    assert.strictEqual(lastCmd.action, 'setPower');
    assert.strictEqual(lastCmd.params.value, false);

    // Verify durable execution log was persisted
    const logs = await ctx.energyExecutionRepo.findByAutomationId(auto.id);
    assert.ok(logs.length >= 1, 'Execution log must be persisted in database');
    assert.strictEqual(logs[0].status, 'succeeded');
    assert.strictEqual(logs[0].scope_id, DEV_OVEN_1);
  });

  // ---------------------------------------------------------------------------
  // 7. Energy Optimization Engine & Estimated Savings
  // ---------------------------------------------------------------------------
  await runAsyncTest('7. Energy Optimization Detection & Evidence-Based Savings Calculation', async () => {
    const ctx = await setupTestContext();

    // Configure custom tariff for HOME_1: $0.20 per kWh
    await ctx.thresholdRepo.upsertThreshold({
      homeId: HOME_1,
      costPerKwh: 0.20,
      currency: 'USD'
    });

    // Seed vampire standby telemetry for DEV_OVEN_1: continuous 25W baseline power
    const baseTs = new Date('2026-09-02T00:00:00Z').getTime();
    for (let h = 0; h < 24; h++) {
      const startIso = new Date(baseTs + h * 3600 * 1000).toISOString();
      const endIso = new Date(baseTs + (h + 1) * 3600 * 1000).toISOString();
      await ctx.aggregateRepo.upsertAggregate({
        deviceId: DEV_OVEN_1,
        channelIndex: 1,
        bucketType: 'HOUR',
        bucketStart: startIso,
        bucketEnd: endIso,
        totalEnergyWh: 25.0,
        avgPowerW: 25.0,
        peakPowerW: 30.0,
        minPowerW: 25.0,
        sampleCount: 60,
        dataQuality: 'GOOD'
      });
    }

    // Seed overnight usage for DEV_HEATER_1: 100W power during 23:00-06:00
    for (let h = 0; h < 6; h++) {
      const startIso = new Date(baseTs + h * 3600 * 1000).toISOString(); // 00:00 to 06:00
      const endIso = new Date(baseTs + (h + 1) * 3600 * 1000).toISOString();
      await ctx.aggregateRepo.upsertAggregate({
        deviceId: DEV_HEATER_1,
        channelIndex: 1,
        bucketType: 'HOUR',
        bucketStart: startIso,
        bucketEnd: endIso,
        totalEnergyWh: 100.0,
        avgPowerW: 100.0,
        peakPowerW: 120.0,
        minPowerW: 80.0,
        sampleCount: 60,
        dataQuality: 'GOOD'
      });
    }

    // Run Optimization Engine
    const result = await ctx.energyService.getOptimizationRecommendations(HOME_1);

    assert.ok(result.summary, 'Result must contain summary');
    assert.strictEqual(result.summary.isEstimate, true, 'Savings must be explicitly labeled as estimates');
    assert.strictEqual(result.summary.tariffPerKwh, 0.20, 'Tariff must match configured value');
    assert.ok(result.recommendations.length >= 2, 'Should detect vampire power and overnight consumption');

    const vampireRec = result.recommendations.find(r => r.category === 'VAMPIRE_STANDBY_POWER');
    assert.ok(vampireRec, 'Vampire standby recommendation must be generated');
    assert.strictEqual(vampireRec.deviceId, DEV_OVEN_1);
    assert.strictEqual(vampireRec.estimatedSavings.isEstimate, true);
    assert.ok(vampireRec.estimatedSavings.monthlyCost > 0, 'Cost savings must be calculated');

    // Verify persistence in repository
    const persisted = await ctx.energyOptimizationRepo.findByHomeId(HOME_1);
    assert.ok(persisted.length >= 2, 'Optimizations must be persisted in database');

    // Test dismissal
    await ctx.energyService.dismissOptimization(HOME_1, vampireRec.id);
    const activeOnly = await ctx.energyOptimizationRepo.findByHomeId(HOME_1, { includeDismissed: false });
    assert.ok(!activeOnly.some(o => o.id === vampireRec.id), 'Dismissed optimization should be excluded');
  });

  // ---------------------------------------------------------------------------
  // 8. Authorization & Multi-Home Isolation
  // ---------------------------------------------------------------------------
  await runAsyncTest('8. RBAC Capability Enforcement & Multi-Home Isolation', async () => {
    const ctx = await setupTestContext();

    // 1. VIEWER tries to create automation -> 403 Forbidden
    const createReq = {
      method: 'POST',
      path: '/api/v1/energy/automations',
      body: {
        homeId: HOME_1,
        name: 'Viewer Rule',
        triggerType: 'energy_threshold',
        conditions: [],
        actions: []
      }
    };
    const viewerRes = await ctx.energyRouter.handleRequest(createReq, { userId: USER_VIEWER });
    assert.strictEqual(viewerRes.statusCode, 403, 'VIEWER cannot create automations');

    // 2. OWNER creates automation -> 201 Created
    const ownerRes = await ctx.energyRouter.handleRequest(createReq, { userId: USER_OWNER });
    assert.strictEqual(ownerRes.statusCode, 201, 'OWNER can create automations');
    const autoId = ownerRes.body.data.id;

    // 3. MEMBER evaluates / runs automation -> 200 OK (canExecuteAutomations)
    const evalReq = {
      method: 'POST',
      path: `/api/v1/energy/automations/${autoId}/evaluate`,
      body: { context: {} }
    };
    const memberRes = await ctx.energyRouter.handleRequest(evalReq, { userId: USER_MEMBER });
    assert.strictEqual(memberRes.statusCode, 200, 'MEMBER can evaluate/execute automations');

    // 4. Multi-Home Isolation: Stranger in HOME_2 tries to read HOME_1 automations -> 403 Forbidden
    const listReq = {
      method: 'GET',
      path: '/api/v1/energy/automations',
      query: { homeId: HOME_1 }
    };
    const strangerRes = await ctx.energyRouter.handleRequest(listReq, { userId: USER_STRANGER });
    assert.strictEqual(strangerRes.statusCode, 403, 'User cannot access automations from unmembered home');
  });

  // ---------------------------------------------------------------------------
  // 9. REST API Full CRUD & History
  // ---------------------------------------------------------------------------
  await runAsyncTest('9. REST API Automation CRUD, Toggle, and History Endpoints', async () => {
    const ctx = await setupTestContext();

    // Create
    const createRes = await ctx.energyRouter.handleRequest({
      method: 'POST',
      path: '/api/v1/energy/automations',
      body: {
        homeId: HOME_1,
        name: 'REST Auto Rule',
        triggerType: 'energy_threshold',
        scopeType: 'device',
        scopeId: DEV_OVEN_1,
        conditions: [{ type: 'energy_condition', metric: 'instantaneous_power', operator: 'GT', threshold: 1800 }],
        actions: [{ actionType: 'device_command', deviceId: DEV_OVEN_1, channelIndex: 1, command: 'setPower', params: { value: false } }]
      }
    }, { userId: USER_OWNER });

    assert.strictEqual(createRes.statusCode, 201);
    const autoId = createRes.body.data.id;

    // Get
    const getRes = await ctx.energyRouter.handleRequest({
      method: 'GET',
      path: `/api/v1/energy/automations/${autoId}`
    }, { userId: USER_OWNER });
    assert.strictEqual(getRes.statusCode, 200);
    assert.strictEqual(getRes.body.data.name, 'REST Auto Rule');

    // Disable
    const disableRes = await ctx.energyRouter.handleRequest({
      method: 'POST',
      path: `/api/v1/energy/automations/${autoId}/disable`
    }, { userId: USER_OWNER });
    assert.strictEqual(disableRes.statusCode, 200);
    assert.strictEqual(disableRes.body.data.is_enabled, false);

    // Enable
    const enableRes = await ctx.energyRouter.handleRequest({
      method: 'POST',
      path: `/api/v1/energy/automations/${autoId}/enable`
    }, { userId: USER_OWNER });
    assert.strictEqual(enableRes.statusCode, 200);
    assert.strictEqual(enableRes.body.data.is_enabled, true);

    // Get History
    const histRes = await ctx.energyRouter.handleRequest({
      method: 'GET',
      path: `/api/v1/energy/automations/${autoId}/history`
    }, { userId: USER_OWNER });
    assert.strictEqual(histRes.statusCode, 200);
    assert.ok(Array.isArray(histRes.body.data));

    // Optimization Endpoint
    const optRes = await ctx.energyRouter.handleRequest({
      method: 'GET',
      path: '/api/v1/energy/optimization',
      query: { homeId: HOME_1 }
    }, { userId: USER_OWNER });
    assert.strictEqual(optRes.statusCode, 200);
    assert.ok(optRes.body.data.summary);

    // Delete
    const deleteRes = await ctx.energyRouter.handleRequest({
      method: 'DELETE',
      path: `/api/v1/energy/automations/${autoId}`
    }, { userId: USER_OWNER });
    assert.strictEqual(deleteRes.statusCode, 200);
  });

  // ---------------------------------------------------------------------------
  // 10. Data Retention & Policy Pruning
  // ---------------------------------------------------------------------------
  await runAsyncTest('10. Data Retention Policy Prunes Old Executions Without Affecting Devices', async () => {
    const ctx = await setupTestContext();
    const retentionService = new DataRetentionService({ db: ctx.db });

    // Seed old execution record (> 40 days old)
    const oldDate = new Date(Date.now() - 40 * 86400 * 1000).toISOString();
    await ctx.energyExecutionRepo.createExecution({
      homeId: HOME_1,
      automationId: '0194fe20-0000-7000-8000-999999999991',
      triggerType: 'energy',
      triggerReason: 'Old execution',
      status: 'succeeded',
      createdAt: oldDate
    });

    // Seed recent execution record (today)
    await ctx.energyExecutionRepo.createExecution({
      homeId: HOME_1,
      automationId: '0194fe20-0000-7000-8000-999999999992',
      triggerType: 'energy',
      triggerReason: 'Recent execution',
      status: 'succeeded',
      createdAt: new Date().toISOString()
    });

    const result = await retentionService.runRetentionCycle({ energyExecutionDays: 30 });
    assert.strictEqual(result.energyExecutionsPruned, 1, 'Only records older than 30 days should be pruned');

    const remaining = await ctx.energyExecutionRepo.findByHomeId(HOME_1);
    assert.strictEqual(remaining.length, 1, 'Recent execution record must be preserved');
    assert.strictEqual(remaining[0].automation_id, '0194fe20-0000-7000-8000-999999999992');

    // Verify devices and homes are untouched
    const devices = await ctx.deviceRepo.getDevicesByHome(HOME_1);
    assert.ok(devices.length >= 2, 'Devices must NEVER be deleted by retention cycle');
  });

  console.log(`\n===============================================================`);
  console.log(`  PHASE 20 TEST SUMMARY: ${passedTests} PASSED, ${totalTests - passedTests} FAILED`);
  console.log(`===============================================================`);
}

main().catch(err => {
  console.error('\nFatal test error:', err);
  process.exit(1);
});
