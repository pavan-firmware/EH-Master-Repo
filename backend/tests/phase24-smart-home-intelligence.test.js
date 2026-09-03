'use strict';

/**
 * EH Home — Phase 24: Smart Home Intelligence + Unified Decision Engine Backend Tests
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
  ScheduleRepository,
  DeviceTelemetryRepository,
  EnergyTariffRepository,
  TariffPeriodRepository,
  EnergyAnomalyRepository,
  EnergyForecastRepository,
  PresenceSignalRepository,
  PresenceStateRepository,
  HomeContextRepository,
  ContextOverrideRepository,
  ContextTransitionRepository,
  IntelligenceDecisionRepository,
  IntelligenceRecommendationRepository,
  IntelligenceOutcomeRepository
} = require('../src/repositories');

const { createApp } = require('../src/app');
const { IntelligenceService, DECISION_PRIORITY_RANKS } = require('../src/services/intelligence.service');
const { ContextService } = require('../src/services/context.service');
const { EnergyService } = require('../src/services/energy.service');
const { AutomationService } = require('../src/services/automation.service');
const { DeviceCommandService } = require('../src/services/device-command.service');
const { DataRetentionService } = require('../src/services/data-retention.service');

let passedTests = 0;
let failedTests = 0;

function test(description, fn) {
  try {
    fn();
    console.log(`  [PASS] ${description}`);
    passedTests++;
  } catch (err) {
    console.error(`  [FAIL] ${description}`);
    console.error(`         ${err.message}`);
    failedTests++;
  }
}

async function asyncTest(description, fn) {
  try {
    await fn();
    console.log(`  [PASS] ${description}`);
    passedTests++;
  } catch (err) {
    console.error(`  [FAIL] ${description}`);
    console.error(`         ${err.message}`);
    failedTests++;
  }
}

async function runTests() {
  console.log('=== PHASE 24: SMART HOME INTELLIGENCE & UNIFIED DECISION ENGINE TESTS ===\n');

  const db = new DatabaseClient();

  // Seed baseline entities
  const homeId = 'home_intel_01';
  const ownerId = 'usr_owner_01';
  const memberId = 'usr_member_01';
  const devId1 = '0194fe23-7a1b-7890-a123-456789abcdef';
  const devId2 = '0194fe23-7a1b-7890-a123-456789abcde2';

  await db.insert('users', ownerId, { id: ownerId, email: 'owner@eh.home', role: 'OWNER' });
  await db.insert('users', memberId, { id: memberId, email: 'member@eh.home', role: 'MEMBER' });
  await db.insert('homes', homeId, { id: homeId, name: 'Smart Intelligence Manor', owner_id: ownerId });
  await db.insert('home_memberships', 'mem_01', { id: 'mem_01', home_id: homeId, user_id: ownerId, role: 'OWNER' });
  await db.insert('home_memberships', 'mem_02', { id: 'mem_02', home_id: homeId, user_id: memberId, role: 'MEMBER' });

  await db.insert('rooms', 'room_living', { id: 'room_living', home_id: homeId, name: 'Living Room' });
  await db.insert('devices', devId1, { id: devId1, home_id: homeId, room_id: 'room_living', name: 'Living Room Light' });
  await db.insert('devices', devId2, { id: devId2, home_id: homeId, room_id: 'room_living', name: 'Water Heater' });

  await db.insert('device_authorizations', devId1, {
    id: devId1,
    device_id: devId1,
    home_id: homeId,
    role: 'DEVICE',
    created_at: new Date().toISOString()
  });
  await db.insert('device_authorizations', devId2, {
    id: devId2,
    device_id: devId2,
    home_id: homeId,
    role: 'DEVICE',
    created_at: new Date().toISOString()
  });

  // Initialize Repositories
  const homeRepo = new HomeRepository(db);
  const roomRepo = new RoomRepository(db);
  const deviceRepo = new DeviceRepository(db);
  const deviceStateRepo = new DeviceStateRepository(db);
  const commandRepo = new CommandRepository(db);
  const eventRepo = new EventRepository(db);
  const auditRepo = new AuditRepository(db);
  const outboxRepo = new OutboxRepository(db);
  const automationRepo = new AutomationRepository(db);
  const scheduleRepo = new ScheduleRepository(db);
  const telemetryRepo = new DeviceTelemetryRepository(db);
  const tariffRepo = new EnergyTariffRepository(db);
  const tariffPeriodRepo = new TariffPeriodRepository(db);
  const anomalyRepo = new EnergyAnomalyRepository(db);
  const forecastRepo = new EnergyForecastRepository(db);
  const signalRepo = new PresenceSignalRepository(db);
  const presenceStateRepo = new PresenceStateRepository(db);
  const contextRepo = new HomeContextRepository(db);
  const overrideRepo = new ContextOverrideRepository(db);
  const transitionRepo = new ContextTransitionRepository(db);
  const decisionRepo = new IntelligenceDecisionRepository(db);
  const recommendationRepo = new IntelligenceRecommendationRepository(db);
  const outcomeRepo = new IntelligenceOutcomeRepository(db);

  // Set initial device states
  await db.insert('device_state', devId1, { id: devId1, connection_state: 'ONLINE' });
  await db.insert('channel_state', `${devId1}_ch_1`, {
    id: `${devId1}_ch_1`,
    device_id: devId1,
    channel_index: 1,
    reported_state: { enabled: true, power: true },
    desired_state: { enabled: true, power: true }
  });

  await db.insert('device_state', devId2, { id: devId2, connection_state: 'ONLINE' });
  await db.insert('channel_state', `${devId2}_ch_1`, {
    id: `${devId2}_ch_1`,
    device_id: devId2,
    channel_index: 1,
    reported_state: { enabled: true, power: true },
    desired_state: { enabled: true, power: true }
  });

  // Telemetry
  await telemetryRepo.recordMeasurement({
    deviceId: devId1,
    homeId,
    voltageV: 230,
    currentA: 0.26,
    powerW: 60,
    frequencyHz: 50,
    powerFactor: 0.95
  });
  await telemetryRepo.recordMeasurement({
    deviceId: devId2,
    homeId,
    voltageV: 230,
    currentA: 8.7,
    powerW: 2000,
    frequencyHz: 50,
    powerFactor: 0.99
  });

  // Context & Presence
  const contextService = new ContextService({
    signalRepo,
    stateRepo: presenceStateRepo,
    contextRepo,
    overrideRepo,
    transitionRepo,
    homeRepo,
    deviceRepo,
    roomRepo
  });

  // Record presence as AWAY, but context as HOME (mode mismatch scenario)
  await contextService.recordPresenceSignal({
    homeId,
    userId: ownerId,
    source: 'mobile_app',
    state: 'AWAY',
    confidence: 0.95
  });
  await contextRepo.upsertHomeContext({
    homeId,
    mode: 'HOME',
    previousMode: 'HOME',
    precedenceTier: 'MANUAL_OVERRIDE',
    isOccupied: 0,
    confidence: 1.0,
    updatedAt: new Date().toISOString()
  });

  // Energy & Tariff Service
  const energyService = new EnergyService({
    telemetryRepo,
    tariffRepo,
    tariffPeriodRepo,
    anomalyRepo,
    forecastRepo
  });

  // Set up peak tariff
  await tariffRepo.createTariff({
    id: 'tariff_intel_01',
    home_id: homeId,
    name: 'Time of Use',
    tariff_type: 'time_of_use',
    currency: 'USD',
    is_active: 1,
    effective_from: '2026-01-01T00:00:00Z'
  });
  await tariffPeriodRepo.createPeriod({
    id: 'tp_intel_peak',
    tariff_id: 'tariff_intel_01',
    home_id: homeId,
    name: 'Peak Window',
    period_type: 'PEAK',
    start_time: '00:00',
    end_time: '23:59',
    pricePerKwh: 0.45,
    applicable_weekdays: '[1,2,3,4,5,6,7]'
  });

  // Anomaly
  await anomalyRepo.createAnomaly({
    homeId,
    scopeType: 'device',
    scopeId: devId2,
    anomalyType: 'POWER_SPIKE',
    severity: 'HIGH',
    observedValue: 2000,
    baselineValue: 50,
    deviationPercentage: 3900,
    evidence: { powerW: 2000 }
  });

  const commandService = new DeviceCommandService({
    commandRepo,
    deviceStateRepo,
    outboxRepo,
    auditRepo,
    deviceRepo,
    eventRepo,
    mqttTransport: {
      sendCommand: async () => ({ status: 'APPLIED' }),
      publish: async () => true,
      subscribe: async () => true
    }
  });

  const automationService = new AutomationService({
    automationRepo,
    commandService,
    deviceStateRepo
  });

  const intelligenceService = new IntelligenceService({
    decisionRepo,
    recommendationRepo,
    outcomeRepo,
    deviceRepo,
    deviceStateRepo,
    roomRepo,
    homeRepo,
    energyService,
    contextService,
    automationService,
    commandService
  });

  // ---------------------------------------------------------------------------
  // Suite 1: Unified Home Intelligence Snapshot
  // ---------------------------------------------------------------------------
  console.log('--- Suite 1: Unified Home Intelligence Snapshot Generation ---');
  let snapshot = null;
  await asyncTest('Snapshot synthesizes context, presence, power, and tariffs', async () => {
    snapshot = await intelligenceService.generateUnifiedSnapshot(homeId);
    assert.strictEqual(snapshot.homeId, homeId);
    assert.strictEqual(snapshot.presenceState, 'AWAY');
    assert.strictEqual(snapshot.isOccupied, false);
    assert.strictEqual(snapshot.deviceCount, 2);
    assert.strictEqual(snapshot.activeDevicesCount, 2);
    assert.strictEqual(snapshot.totalPowerW, 2060);
    assert.strictEqual(snapshot.tariffPeriod, 'PEAK');
    assert.strictEqual(snapshot.tariffPrice, 0.45);
    assert.strictEqual(snapshot.activeAnomalyCount, 1);
  });

  test('Snapshot has devicesSummary list', () => {
    assert(Array.isArray(snapshot.devicesSummary));
    assert.strictEqual(snapshot.devicesSummary.length, 2);
    assert.strictEqual(snapshot.devicesSummary[0].isOn, true);
  });

  // ---------------------------------------------------------------------------
  // Suite 2: Deterministic Decision & Recommendation Rules
  // ---------------------------------------------------------------------------
  console.log('\n--- Suite 2: Deterministic Decision & Recommendation Rules ---');
  let evalResult = null;
  await asyncTest('evaluateDecisions generates explainable recommendations', async () => {
    evalResult = await intelligenceService.evaluateDecisions(homeId);
    assert(evalResult.recommendationsCount >= 3, `Expected at least 3 recommendations, got ${evalResult.recommendationsCount}`);
    assert(evalResult.decisionsCount >= 2, `Expected at least 2 decisions, got ${evalResult.decisionsCount}`);
  });

  test('Rule 1: Unused device in empty home generates TURN_OFF_UNUSED_DEVICE', () => {
    const rec = evalResult.recommendations.find(r => r.recommendation_type === 'TURN_OFF_UNUSED_DEVICE');
    assert(rec, 'TURN_OFF_UNUSED_DEVICE recommendation not found');
    assert.strictEqual(rec.priority, 'CONVENIENCE_RECOMMENDATION');
    assert.strictEqual(rec.risk, 'LOW');
    assert.strictEqual(rec.is_auto_executable, true);
    assert(rec.evidence.deviceId === devId1 || rec.evidence.deviceId === devId2);
  });

  test('Rule 2: Peak tariff load generates SHIFT_LOAD_TO_CHEAPER_PERIOD', () => {
    const rec = evalResult.recommendations.find(r => r.recommendation_type === 'SHIFT_LOAD_TO_CHEAPER_PERIOD');
    assert(rec, 'SHIFT_LOAD_TO_CHEAPER_PERIOD recommendation not found');
    assert.strictEqual(rec.priority, 'ENERGY_COST_OPTIMIZATION');
    assert.strictEqual(rec.risk, 'MEDIUM');
    assert.strictEqual(rec.is_auto_executable, false);
  });

  test('Rule 3: Active anomaly generates INVESTIGATE_ANOMALY', () => {
    const rec = evalResult.recommendations.find(r => r.recommendation_type === 'INVESTIGATE_ANOMALY');
    assert(rec, 'INVESTIGATE_ANOMALY recommendation not found');
    assert.strictEqual(rec.priority, 'SAFETY');
    assert.strictEqual(rec.risk, 'HIGH');
  });

  test('Rule 4: Presence away but context home suggests CHANGE_HOME_MODE', () => {
    const rec = evalResult.recommendations.find(r => r.recommendation_type === 'CHANGE_HOME_MODE');
    assert(rec, 'CHANGE_HOME_MODE recommendation not found');
    assert.strictEqual(rec.priority, 'EXPLICIT_HOME_MODE');
    assert.strictEqual(rec.risk, 'LOW');
  });

  // ---------------------------------------------------------------------------
  // Suite 3: Decision Priority Hierarchy (1-7)
  // ---------------------------------------------------------------------------
  console.log('\n--- Suite 3: Deterministic Priority Ordering (1–7) ---');
  test('Priority ranks match canonical hierarchy strictly', () => {
    assert.strictEqual(DECISION_PRIORITY_RANKS.SAFETY, 1);
    assert.strictEqual(DECISION_PRIORITY_RANKS.MANUAL_USER_ACTION, 2);
    assert.strictEqual(DECISION_PRIORITY_RANKS.EXPLICIT_HOME_MODE, 3);
    assert.strictEqual(DECISION_PRIORITY_RANKS.SCHEDULED_AUTOMATION, 4);
    assert.strictEqual(DECISION_PRIORITY_RANKS.ENERGY_COST_OPTIMIZATION, 5);
    assert.strictEqual(DECISION_PRIORITY_RANKS.PREDICTIVE_OPTIMIZATION, 6);
    assert.strictEqual(DECISION_PRIORITY_RANKS.CONVENIENCE_RECOMMENDATION, 7);
  });

  test('Higher priority rank is lower integer value', () => {
    assert(DECISION_PRIORITY_RANKS.SAFETY < DECISION_PRIORITY_RANKS.ENERGY_COST_OPTIMIZATION);
    assert(DECISION_PRIORITY_RANKS.EXPLICIT_HOME_MODE < DECISION_PRIORITY_RANKS.CONVENIENCE_RECOMMENDATION);
  });

  // ---------------------------------------------------------------------------
  // Suite 4: Explainability, Evidence & Confidence
  // ---------------------------------------------------------------------------
  console.log('\n--- Suite 4: Explainability, Evidence & Confidence ---');
  test('Recommendations contain structured evidence and expected benefit', () => {
    for (const r of evalResult.recommendations) {
      assert(r.title && r.title.length > 0);
      assert(r.description && r.description.length > 0);
      assert(typeof r.evidence === 'object');
      assert(r.expected_benefit && r.expected_benefit.length > 0);
      assert(['LOW', 'MEDIUM', 'HIGH'].includes(r.confidence));
    }
  });

  test('Decisions contain safetyResult with reason', () => {
    for (const d of evalResult.decisions) {
      assert(typeof d.safety_result === 'object');
      assert.strictEqual(typeof d.safety_result.isSafe, 'boolean');
      assert(d.safety_result.reason);
    }
  });

  // ---------------------------------------------------------------------------
  // Suite 5: Risk Classification & Auto-Execution Eligibility
  // ---------------------------------------------------------------------------
  console.log('\n--- Suite 5: Risk Classification & Auto-Execution Eligibility ---');
  test('High risk actions are NOT auto-executable', () => {
    const highRisk = evalResult.decisions.filter(d => d.risk === 'HIGH' || d.risk === 'CRITICAL');
    for (const d of highRisk) {
      assert.strictEqual(d.is_auto_executable, false);
    }
  });

  test('Low risk convenience actions are marked auto-executable', () => {
    const lowRisk = evalResult.decisions.filter(d => d.risk === 'LOW' && d.decision_type === 'TURN_OFF_IDLE_DEVICE');
    assert(lowRisk.length > 0);
    assert.strictEqual(lowRisk[0].is_auto_executable, true);
  });

  // ---------------------------------------------------------------------------
  // Suite 6: Safe Auto-Execution Engine & Anti-Fighting Cooldown
  // ---------------------------------------------------------------------------
  console.log('\n--- Suite 6: Safe Auto-Execution Engine & Anti-Fighting Cooldown ---');
  await asyncTest('autoExecuteSafeDecisions executes LOW-risk decisions', async () => {
    const execRes = await intelligenceService.autoExecuteSafeDecisions(homeId, { userId: ownerId });
    assert(execRes.executedCount > 0, `Expected at least 1 executed decision, got ${execRes.executedCount}`);
    const autoExec = execRes.results.find(r => r.status === 'AUTO_EXECUTED');
    assert(autoExec, 'No AUTO_EXECUTED decision found');
  });

  await asyncTest('Auto-execution respects manual command cooldown (Anti-Fighting)', async () => {
    // Simulate user manual command cooldown on devId1
    automationService.recordManualCommand(devId1);

    // Create a new pending decision on devId1
    const newDec = await decisionRepo.createDecision({
      homeId,
      decisionType: 'TURN_OFF_IDLE_DEVICE',
      priority: 'CONVENIENCE_RECOMMENDATION',
      priorityRank: 7,
      confidence: 'HIGH',
      risk: 'LOW',
      isAutoExecutable: true,
      status: 'GENERATED',
      proposedAction: {
        actionType: 'device_command',
        deviceId: devId1,
        command: 'setPower',
        params: { value: false }
      }
    });

    const res = await intelligenceService.autoExecuteSafeDecisions(homeId, { userId: ownerId });
    const skipped = res.results.find(r => r.decisionId === newDec.id);
    assert(skipped, 'Decision on cooled-down device was not processed');
    assert.strictEqual(skipped.status, 'SKIPPED');
    assert.strictEqual(skipped.reason, 'manual_command_cooldown');
  });

  // ---------------------------------------------------------------------------
  // Suite 7: Manual Recommendation Lifecycle (Accept / Reject / Execute)
  // ---------------------------------------------------------------------------
  console.log('\n--- Suite 7: Manual Recommendation Lifecycle (Accept / Reject / Execute) ---');
  let testRec = null;
  await asyncTest('acceptRecommendation dispatches action and marks ACCEPTED', async () => {
    testRec = await recommendationRepo.createRecommendation({
      homeId,
      recommendationType: 'TURN_OFF_UNUSED_DEVICE',
      priority: 'CONVENIENCE_RECOMMENDATION',
      confidence: 'HIGH',
      risk: 'LOW',
      title: 'Turn Off Water Heater',
      description: 'Water heater left on',
      status: 'GENERATED',
      proposedAction: {
        actionType: 'device_command',
        deviceId: devId2,
        command: 'setPower',
        params: { value: false }
      }
    });

    const res = await intelligenceService.acceptRecommendation(homeId, testRec.id, { userId: ownerId });
    assert.strictEqual(res.status, 'ACCEPTED');
    assert(res.outcome);

    const updated = await recommendationRepo.getRecommendationById(testRec.id);
    assert.strictEqual(updated.status, 'ACCEPTED');
  });

  await asyncTest('rejectRecommendation updates status to REJECTED with feedback', async () => {
    const rejRec = await recommendationRepo.createRecommendation({
      homeId,
      recommendationType: 'SHIFT_LOAD_TO_CHEAPER_PERIOD',
      title: 'Shift pool pump',
      status: 'GENERATED'
    });

    const res = await intelligenceService.rejectRecommendation(homeId, rejRec.id, 'Need heating now', { userId: memberId });
    assert.strictEqual(res.status, 'REJECTED');
    assert.strictEqual(res.outcome.feedback, 'Need heating now');

    const updated = await recommendationRepo.getRecommendationById(rejRec.id);
    assert.strictEqual(updated.status, 'REJECTED');
  });

  await asyncTest('executeDecision executes decision manually', async () => {
    const manualDec = await decisionRepo.createDecision({
      homeId,
      decisionType: 'LOAD_SHEDDING',
      priority: 'ENERGY_COST_OPTIMIZATION',
      risk: 'MEDIUM',
      status: 'GENERATED',
      proposedAction: {
        actionType: 'device_command',
        deviceId: devId2,
        command: 'setPower',
        params: { value: false }
      }
    });

    const res = await intelligenceService.executeDecision(homeId, manualDec.id, { userId: ownerId });
    assert.strictEqual(res.status, 'EXECUTED');

    const updated = await decisionRepo.getDecisionById(manualDec.id);
    assert.strictEqual(updated.status, 'EXECUTED');
  });

  // ---------------------------------------------------------------------------
  // Suite 8: Outcome Tracking & Audit History
  // ---------------------------------------------------------------------------
  console.log('\n--- Suite 8: Decision Outcome Tracking & History ---');
  await asyncTest('Outcomes recorded and queryable by home', async () => {
    const outcomes = await outcomeRepo.getOutcomesByHome(homeId, { limit: 10 });
    assert(outcomes.length >= 3);
    assert(outcomes[0].status);
    assert(outcomes[0].executed_at || outcomes[0].created_at);
  });

  // ---------------------------------------------------------------------------
  // Suite 9: Data Retention & Policy Pruning
  // ---------------------------------------------------------------------------
  console.log('\n--- Suite 9: Data Retention & Policy Pruning ---');
  const retentionService = new DataRetentionService({ db });
  await asyncTest('Prunes stale intelligence decisions (> 60 days)', async () => {
    const staleDate = new Date(Date.now() - 65 * 24 * 3600 * 1000).toISOString();
    await db.insert('intelligence_decisions', 'dec_stale_01', {
      id: 'dec_stale_01',
      home_id: homeId,
      decision_type: 'OLD_DEC',
      priority: 'SAFETY',
      created_at: staleDate
    });

    const res = await retentionService.pruneIntelligenceDecisions(60);
    assert.strictEqual(res.pruned, 1);
    const found = await decisionRepo.getDecisionById('dec_stale_01');
    assert.strictEqual(found, null);
  });

  await asyncTest('Prunes stale intelligence recommendations (> 30 days)', async () => {
    const staleDate = new Date(Date.now() - 35 * 24 * 3600 * 1000).toISOString();
    await db.insert('intelligence_recommendations', 'rec_stale_01', {
      id: 'rec_stale_01',
      home_id: homeId,
      recommendation_type: 'OLD_REC',
      title: 'Old',
      created_at: staleDate
    });

    const res = await retentionService.pruneIntelligenceRecommendations(30);
    assert.strictEqual(res.pruned, 1);
    const found = await recommendationRepo.getRecommendationById('rec_stale_01');
    assert.strictEqual(found, null);
  });

  await asyncTest('Prunes stale outcomes (> 90 days)', async () => {
    const staleDate = new Date(Date.now() - 95 * 24 * 3600 * 1000).toISOString();
    await db.insert('intelligence_decision_outcomes', 'out_stale_01', {
      id: 'out_stale_01',
      home_id: homeId,
      decision_id: 'dec_00',
      status: 'EXECUTED',
      executed_at: staleDate,
      created_at: staleDate
    });

    const res = await retentionService.pruneIntelligenceOutcomes(90);
    assert.strictEqual(res.pruned, 1);
  });

  // ---------------------------------------------------------------------------
  // Suite 10: REST APIs & RBAC Authorization Checks
  // ---------------------------------------------------------------------------
  console.log('\n--- Suite 10: REST APIs & RBAC Authorization Checks ---');
  const app = createApp({ db });
  const intelRouter = app.intelligenceApiRouter;

  await asyncTest('GET /api/v1/intelligence/homes/:homeId/summary returns 200 for Owner', async () => {
    const res = await intelRouter.handleRequest({
      method: 'GET',
      path: `/api/v1/intelligence/homes/${homeId}/summary`
    }, { userId: ownerId });
    assert.strictEqual(res.statusCode, 200);
    assert(res.body.data.snapshot);
  });

  await asyncTest('GET /api/v1/intelligence/homes/:homeId/recommendations returns 200 for Member', async () => {
    const res = await intelRouter.handleRequest({
      method: 'GET',
      path: `/api/v1/intelligence/homes/${homeId}/recommendations`
    }, { userId: memberId });
    assert.strictEqual(res.statusCode, 200);
    assert(Array.isArray(res.body.data));
  });

  await asyncTest('GET /api/v1/intelligence/homes/:homeId/decisions returns 200', async () => {
    const res = await intelRouter.handleRequest({
      method: 'GET',
      path: `/api/v1/intelligence/homes/${homeId}/decisions`
    }, { userId: ownerId });
    assert.strictEqual(res.statusCode, 200);
    assert(Array.isArray(res.body.data));
  });

  await asyncTest('POST /api/v1/intelligence/homes/:homeId/evaluate returns 200', async () => {
    const res = await intelRouter.handleRequest({
      method: 'POST',
      path: `/api/v1/intelligence/homes/${homeId}/evaluate`
    }, { userId: ownerId });
    assert.strictEqual(res.statusCode, 200);
    assert(res.body.data.snapshot);
  });

  await asyncTest('POST /api/v1/intelligence/homes/:homeId/auto-execute returns 200', async () => {
    const res = await intelRouter.handleRequest({
      method: 'POST',
      path: `/api/v1/intelligence/homes/${homeId}/auto-execute`
    }, { userId: ownerId });
    assert.strictEqual(res.statusCode, 200);
  });

  await asyncTest('GET /api/v1/intelligence/homes/:homeId/history returns 200', async () => {
    const res = await intelRouter.handleRequest({
      method: 'GET',
      path: `/api/v1/intelligence/homes/${homeId}/history`
    }, { userId: ownerId });
    assert.strictEqual(res.statusCode, 200);
    assert(Array.isArray(res.body.data));
  });

  await asyncTest('Unauthenticated request returns 401', async () => {
    const res = await intelRouter.handleRequest({
      method: 'GET',
      path: `/api/v1/intelligence/homes/${homeId}/summary`
    }, null);
    assert.strictEqual(res.statusCode, 401);
  });

  await asyncTest('Cross-home request returns 403 Forbidden', async () => {
    const res = await intelRouter.handleRequest({
      method: 'GET',
      path: `/api/v1/intelligence/homes/home_other_99/summary`
    }, { userId: ownerId });
    assert.strictEqual(res.statusCode, 403);
  });

  console.log('\n===============================================================');
  console.log(`Phase 24 Tests Complete: ${passedTests} Passed, ${failedTests} Failed`);
  console.log('===============================================================\n');

  if (failedTests > 0) {
    process.exit(1);
  }
}

runTests().catch(err => {
  console.error('Unhandled error running Phase 24 tests:', err);
  process.exit(1);
});
