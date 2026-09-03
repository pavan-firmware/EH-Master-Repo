'use strict';

/**
 * EH Home — Phase 23 Presence, Context Intelligence + Context-Aware Automation Test Suite
 */

const { DatabaseClient } = require('../src/shared/db-client');
const {
  UserRepository,
  HomeRepository,
  RoomRepository,
  DeviceRepository,
  DeviceStateRepository,
  DeviceTelemetryRepository,
  TelemetryAggregateRepository,
  EnergyThresholdRepository,
  EnergyEventRepository,
  EnergyAutomationExecutionRepository,
  EnergyOptimizationRepository,
  EnergyTariffRepository,
  TariffPeriodRepository,
  EnergyBudgetRepository,
  CostOptimizationRepository,
  EnergyForecastRepository,
  EnergyAnomalyRepository,
  EnergyBaselineRepository,
  ForecastAccuracyRepository,
  EnergyEfficiencyScoreRepository,
  PresenceSignalRepository,
  PresenceStateRepository,
  HomeContextRepository,
  ContextOverrideRepository,
  ContextTransitionRepository,
  AutomationRepository,
  AutomationExecutionLogRepository
} = require('../src/repositories');
const { ContextService } = require('../src/services/context.service');
const { AutomationService } = require('../src/services/automation.service');
const { EnergyService } = require('../src/services/energy.service');
const { DataRetentionService } = require('../src/services/data-retention.service');
const { ContextApiRouter } = require('../src/api/context.router');
const { HomeAuthorizationService } = require('../src/shared/home-authorization');

let passed = 0;
let failed = 0;

function assert(description, condition, details = '') {
  if (condition) {
    console.log(`  [PASS] ${description}`);
    passed++;
  } else {
    console.error(`  [FAIL] ${description} ${details}`);
    failed++;
  }
}

async function runTests() {
  console.log('=== PHASE 23: PRESENCE & CONTEXT INTELLIGENCE TESTS ===\n');

  const db = new DatabaseClient();

  const userRepo = new UserRepository(db);
  const homeRepo = new HomeRepository(db);
  const roomRepo = new RoomRepository(db);
  const deviceRepo = new DeviceRepository(db);
  const deviceStateRepo = new DeviceStateRepository(db);
  const telemetryRepo = new DeviceTelemetryRepository(db);
  const aggregateRepo = new TelemetryAggregateRepository(db);
  const thresholdRepo = new EnergyThresholdRepository(db);
  const energyEventRepo = new EnergyEventRepository(db);
  const executionRepo = new EnergyAutomationExecutionRepository(db);
  const optimizationRepo = new EnergyOptimizationRepository(db);
  const tariffRepo = new EnergyTariffRepository(db);
  const tariffPeriodRepo = new TariffPeriodRepository(db);
  const budgetRepo = new EnergyBudgetRepository(db);
  const costOptimizationRepo = new CostOptimizationRepository(db);
  const forecastRepo = new EnergyForecastRepository(db);
  const anomalyRepo = new EnergyAnomalyRepository(db);
  const baselineRepo = new EnergyBaselineRepository(db);
  const accuracyRepo = new ForecastAccuracyRepository(db);
  const efficiencyRepo = new EnergyEfficiencyScoreRepository(db);
  const signalRepo = new PresenceSignalRepository(db);
  const presenceStateRepo = new PresenceStateRepository(db);
  const contextRepo = new HomeContextRepository(db);
  const overrideRepo = new ContextOverrideRepository(db);
  const transitionRepo = new ContextTransitionRepository(db);
  const automationRepo = new AutomationRepository(db);
  const logRepo = new AutomationExecutionLogRepository(db);

  const homeAuthService = new HomeAuthorizationService({ homeRepo, deviceRepo, roomRepo });

  const publishedEvents = [];
  const mockEventBus = {
    publish: (evt) => publishedEvents.push(evt)
  };

  const sentNotifications = [];
  const mockNotificationService = {
    notifyHome: async (n) => {
      sentNotifications.push(n);
      return { success: true };
    }
  };

  const automationService = new AutomationService({
    automationRepo,
    homeAuthService,
    deviceStateRepo,
    logRepo,
    telemetryRepo,
    aggregateRepo,
    energyExecutionRepo: executionRepo,
    notificationService: mockNotificationService,
    eventBus: mockEventBus
  });

  const energyService = new EnergyService({
    telemetryRepo,
    aggregateRepo,
    thresholdRepo,
    eventRepo: energyEventRepo,
    deviceRepo,
    roomRepo,
    homeRepo,
    notificationService: mockNotificationService,
    realtimeEventBus: mockEventBus,
    automationService,
    optimizationRepo,
    tariffRepo,
    tariffPeriodRepo,
    budgetRepo,
    costOptimizationRepo,
    forecastRepo,
    anomalyRepo,
    baselineRepo,
    accuracyRepo,
    efficiencyRepo
  });

  const contextService = new ContextService({
    signalRepo,
    stateRepo: presenceStateRepo,
    contextRepo,
    overrideRepo,
    transitionRepo,
    homeRepo,
    deviceRepo,
    roomRepo,
    energyService,
    automationService,
    notificationService: mockNotificationService,
    realtimeEventBus: mockEventBus
  });

  automationService.setEnergyService(energyService);
  automationService.setContextService(contextService);

  const retentionService = new DataRetentionService({ db });

  const router = new ContextApiRouter({
    contextService,
    homeAuthService
  });

  const homeId = 'home_p23_01';
  const otherHomeId = 'home_p23_02';
  const ownerUserId = 'usr_p23_owner';
  const memberUserId = 'usr_p23_member';
  const foreignUserId = 'usr_p23_foreign';

  // Seed Users, Home & Memberships
  await userRepo.createUser({ id: ownerUserId, email: 'owner@ehhome.io', password_hash: 'hash' });
  await userRepo.createUser({ id: memberUserId, email: 'member@ehhome.io', password_hash: 'hash' });
  await userRepo.createUser({ id: foreignUserId, email: 'foreign@ehhome.io', password_hash: 'hash' });

  await homeRepo.createHome({ id: homeId, name: 'Main Intelligent Home', owner_id: ownerUserId });
  await homeRepo.createHome({ id: otherHomeId, name: 'Foreign Home', owner_id: foreignUserId });

  await db.insert('home_memberships', `mem_1`, { home_id: homeId, user_id: ownerUserId, role: 'OWNER' });
  await db.insert('home_memberships', `mem_2`, { home_id: homeId, user_id: memberUserId, role: 'MEMBER' });
  await db.insert('home_memberships', `mem_3`, { home_id: otherHomeId, user_id: foreignUserId, role: 'OWNER' });

  // Seed Rooms & Devices
  const livingRoomId = 'room_living';
  await db.insert('rooms', livingRoomId, { id: livingRoomId, home_id: homeId, name: 'Living Room' });
  const devLightId = 'dev_light_01';
  await db.insert('devices', devLightId, {
    id: devLightId,
    home_id: homeId,
    room_id: livingRoomId,
    custom_name: 'Living Room Light',
    is_active: true
  });
  await db.insert('device_authorizations', devLightId, { home_id: homeId, room_id: livingRoomId, device_id: devLightId });

  // --- Suite 1: Presence Signal Ingestion & Source Confidence Weighting ---
  console.log('--- Suite 1: Presence Signal Ingestion & Source Confidence Weighting ---');
  {
    // 1. Ingest mobile_app signal (weight 0.90)
    const res1 = await contextService.recordPresenceSignal({
      userId: ownerUserId,
      homeId,
      source: 'mobile_app',
      state: 'HOME',
      confidence: 1.0,
      evidence: { wifiSsid: 'HomeMesh_5G' }
    });
    assert('Mobile signal recorded', res1.signal && res1.signal.id !== undefined);
    assert('Mobile confidence weighted to 0.90', res1.signal.confidence === 0.9);

    // 2. Ingest manual signal (weight 1.0)
    const res2 = await contextService.recordPresenceSignal({
      userId: memberUserId,
      homeId,
      source: 'manual',
      state: 'AWAY',
      confidence: 1.0
    });
    assert('Manual confidence weighted to 1.0', res2.signal.confidence === 1.0);

    // 3. Ingest lan_wifi signal (weight 0.80)
    const res3 = await contextService.recordPresenceSignal({
      userId: memberUserId,
      homeId,
      source: 'lan_wifi',
      state: 'HOME',
      confidence: 1.0
    });
    assert('LAN WiFi confidence weighted to 0.80', res3.signal.confidence === 0.8);

    // 4. Ingest device_activity signal (weight 0.65)
    const res4 = await contextService.recordPresenceSignal({
      userId: memberUserId,
      homeId,
      source: 'device_activity',
      state: 'HOME',
      confidence: 0.8
    });
    assert('Device activity confidence scaled (0.8 * 0.65 = 0.52)', Math.abs(res4.signal.confidence - 0.52) < 0.01);

    // 5. Invalid source throws error
    let threwInvalidSource = false;
    try {
      await contextService.recordPresenceSignal({
        userId: ownerUserId,
        homeId,
        source: 'telepathy',
        state: 'HOME'
      });
    } catch (_) {
      threwInvalidSource = true;
    }
    assert('Invalid source rejected', threwInvalidSource);

    // 6. Invalid state throws error
    let threwInvalidState = false;
    try {
      await contextService.recordPresenceSignal({
        userId: ownerUserId,
        homeId,
        source: 'manual',
        state: 'TELEPORTED'
      });
    } catch (_) {
      threwInvalidState = true;
    }
    assert('Invalid state rejected', threwInvalidState);
  }

  // --- Suite 2: Stale Signal Handling & TTL Expiration ---
  console.log('\n--- Suite 2: Stale Signal Handling & TTL Expiration ---');
  {
    const staleTime = new Date('2026-07-16T12:00:00Z');
    const expiredSignalTime = new Date('2026-07-16T10:00:00Z'); // 2 hours old

    await signalRepo.recordSignal({
      userId: ownerUserId,
      homeId,
      source: 'mobile_app',
      state: 'HOME',
      confidence: 0.9,
      observedAt: expiredSignalTime.toISOString(),
      expiresAt: new Date(expiredSignalTime.getTime() + 30 * 60 * 1000).toISOString() // expired at 10:30
    });

    await presenceStateRepo.upsertUserState({
      homeId,
      userId: ownerUserId,
      state: 'HOME',
      confidence: 0.9,
      source: 'mobile_app',
      isStale: 0,
      lastObservedAt: expiredSignalTime.toISOString(),
      expiresAt: new Date(expiredSignalTime.getTime() + 30 * 60 * 1000).toISOString()
    });

    // Clear member state
    await presenceStateRepo.upsertUserState({
      homeId,
      userId: memberUserId,
      state: 'HOME',
      confidence: 0.9,
      source: 'mobile_app',
      isStale: 0,
      lastObservedAt: expiredSignalTime.toISOString(),
      expiresAt: new Date(expiredSignalTime.getTime() + 30 * 60 * 1000).toISOString()
    });

    const snapshot = await contextService.getPresenceSnapshot(homeId, { asOfDate: staleTime });
    assert('Stale signals resolve user state to UNKNOWN', snapshot.userStates[ownerUserId].state === 'UNKNOWN');
    assert('Stale user state has isStale flag true', snapshot.userStates[ownerUserId].isStale === true);
    assert('Whole-home presence with expired signals falls back to UNKNOWN', snapshot.state === 'UNKNOWN');
    assert('isOccupied is false when presence is UNKNOWN', snapshot.isOccupied === false);
  }

  // --- Suite 3: Deterministic Signal Reconciliation & Home Aggregation ---
  console.log('\n--- Suite 3: Deterministic Signal Reconciliation & Home Aggregation ---');
  {
    const nowTime = new Date();

    // 1. One user HOME, one user AWAY -> Whole-home is HOME
    await contextService.recordPresenceSignal({
      userId: ownerUserId,
      homeId,
      source: 'mobile_app',
      state: 'HOME',
      confidence: 1.0,
      observedAt: nowTime.toISOString()
    });
    await contextService.recordPresenceSignal({
      userId: memberUserId,
      homeId,
      source: 'mobile_app',
      state: 'AWAY',
      confidence: 1.0,
      observedAt: nowTime.toISOString()
    });

    const snapshot1 = await contextService.getPresenceSnapshot(homeId);
    assert('At least 1 active user HOME aggregates whole-home to HOME', snapshot1.state === 'HOME');
    assert('Home is marked occupied (isOccupied: true)', snapshot1.isOccupied === true);
    assert('Active user count is 1', snapshot1.activeUserCount === 1);

    // 2. Both users AWAY -> Whole-home is AWAY
    await contextService.recordPresenceSignal({
      userId: ownerUserId,
      homeId,
      source: 'mobile_app',
      state: 'AWAY',
      confidence: 1.0,
      observedAt: nowTime.toISOString()
    });

    const snapshot2 = await contextService.getPresenceSnapshot(homeId);
    assert('All active users AWAY aggregates whole-home to AWAY', snapshot2.state === 'AWAY');
    assert('Home is marked unoccupied (isOccupied: false)', snapshot2.isOccupied === false);
    assert('Active user count is 0', snapshot2.activeUserCount === 0);
  }

  // --- Suite 4: Inferred Room Context & Confidence ---
  console.log('\n--- Suite 4: Inferred Room Context & Confidence ---');
  {
    // Update devLightId last_seen_at to now
    await db.update('devices', devLightId, { last_seen_at: new Date().toISOString() });

    const snapshot = await contextService.getPresenceSnapshot(homeId);
    assert('Inferred rooms array returned', Array.isArray(snapshot.inferredRooms) && snapshot.inferredRooms.length > 0);
    const living = snapshot.inferredRooms.find(r => r.roomId === livingRoomId);
    assert('Living room presence is inferred', living && living.isInferred === true);
    assert('Living room is marked occupied due to recent device activity', living && living.isOccupied === true);
    assert('Living room confidence is calculated (0.75)', living && living.confidence === 0.75);
  }

  // --- Suite 5: Context Precedence State Machine ---
  console.log('\n--- Suite 5: Context Precedence State Machine ---');
  {
    // Clear overrides first
    await overrideRepo.clearActiveOverridesForHome(homeId);

    // Reconciled HOME presence -> Context is HOME via RECONCILED_PRESENCE
    await contextService.recordPresenceSignal({
      userId: ownerUserId,
      homeId,
      source: 'manual',
      state: 'HOME'
    });

    const ctx1 = await contextService.evaluateHomeContext(homeId);
    assert('Context resolves to HOME', ctx1.mode === 'HOME');
    assert('Precedence tier is RECONCILED_PRESENCE', ctx1.precedenceTier === 'RECONCILED_PRESENCE');
    assert('Home is marked occupied', ctx1.isOccupied === true);

    // Now set manual VACATION override (Tier 1: MANUAL_OVERRIDE)
    const ovrRes = await contextService.setContextOverride({
      homeId,
      userId: ownerUserId,
      mode: 'VACATION',
      reason: 'Summer Trip',
      durationHours: 48
    });

    assert('Manual override created', ovrRes.override && ovrRes.override.mode === 'VACATION');
    assert('Context resolves to VACATION', ovrRes.context.mode === 'VACATION');
    assert('Precedence tier is MANUAL_OVERRIDE', ovrRes.context.precedenceTier === 'MANUAL_OVERRIDE');
    assert('Vacation flag is true', ovrRes.context.isVacation === true);
    assert('Occupied flag is false during VACATION', ovrRes.context.isOccupied === false);

    // New HOME signal arrives — Manual VACATION override MUST NOT be overwritten!
    await contextService.recordPresenceSignal({
      userId: memberUserId,
      homeId,
      source: 'mobile_app',
      state: 'HOME'
    });

    const ctx2 = await contextService.evaluateHomeContext(homeId);
    assert('Manual VACATION override is preserved despite incoming HOME signal', ctx2.mode === 'VACATION');
    assert('Precedence tier remains MANUAL_OVERRIDE', ctx2.precedenceTier === 'MANUAL_OVERRIDE');

    // Transitions recorded
    const transitions = await transitionRepo.getTransitionsByHome(homeId);
    assert('Context transitions recorded in database', transitions.length > 0);
  }

  // --- Suite 6: Manual Context Overrides & Expiration ---
  console.log('\n--- Suite 6: Manual Context Overrides & Expiration ---');
  {
    // 1. Clear override
    const clearRes = await contextService.clearContextOverride(homeId, ownerUserId);
    assert('Override cleared successfully', clearRes.success === true);
    assert('Context reverts to reconciled HOME state', clearRes.context.mode === 'HOME');
    assert('Precedence tier is RECONCILED_PRESENCE', clearRes.context.precedenceTier === 'RECONCILED_PRESENCE');

    // 2. Set SLEEP override with 8 hour duration
    const sleepOvr = await contextService.setContextOverride({
      homeId,
      userId: ownerUserId,
      mode: 'SLEEP',
      reason: 'Good night',
      durationHours: 8
    });
    assert('SLEEP override set', sleepOvr.context.mode === 'SLEEP');
    assert('Active override expiresAt is populated', sleepOvr.context.activeOverride?.expiresAt !== null);

    // Clean up
    await contextService.clearContextOverride(homeId, ownerUserId);
  }

  // --- Suite 7: Context-Aware Automation Condition Evaluation ---
  console.log('\n--- Suite 7: Context-Aware Automation Condition Evaluation ---');
  {
    // Record active HOME signal for owner to ensure context is HOME
    await contextService.recordPresenceSignal({
      userId: ownerUserId,
      homeId,
      source: 'manual',
      state: 'HOME',
      confidence: 1.0
    });

    const isHomeMet = await automationService.evaluateCondition(
      { metric: 'home_context', operator: 'EQ', expectedMode: 'HOME', homeId },
      { homeId }
    );
    assert('home_context EQ HOME evaluates to true', isHomeMet === true);

    const isAwayMet = await automationService.evaluateCondition(
      { metric: 'home_context', operator: 'EQ', expectedMode: 'AWAY', homeId },
      { homeId }
    );
    assert('home_context EQ AWAY evaluates to false', isAwayMet === false);

    const isOccupiedMet = await automationService.evaluateCondition(
      { metric: 'home_occupied', expected: true, homeId },
      { homeId }
    );
    assert('home_occupied condition evaluates to true', isOccupiedMet === true);

    const isConfidenceMet = await automationService.evaluateCondition(
      { metric: 'presence_confidence', operator: 'GTE', threshold: 0.7, homeId },
      { homeId }
    );
    assert('presence_confidence GTE 0.7 evaluates to true', isConfidenceMet === true);

    // Create a context-triggered automation rule
    const autoVacation = await automationService.createAutomation({
      homeId,
      userId: ownerUserId,
      name: 'Away Security Lights Off',
      triggerType: 'context',
      triggerCondition: {
        metric: 'home_context',
        operator: 'EQ',
        expectedMode: 'AWAY',
        homeId
      },
      actions: [{ actionType: 'device_command', deviceId: devLightId, command: 'setPower', params: { value: false } }]
    });
    assert('Context automation created', autoVacation && autoVacation.id !== undefined);
  }

  // --- Suite 8: Manual Command Priority & Automation Fighting Suppression ---
  console.log('\n--- Suite 8: Manual Command Priority & Automation Fighting Suppression ---');
  {
    const autoLightOff = await automationService.createAutomation({
      homeId,
      userId: ownerUserId,
      name: 'Auto Turn Off Light',
      triggerType: 'context',
      triggerCondition: {
        metric: 'home_context',
        operator: 'EQ',
        expectedMode: 'HOME',
        homeId
      },
      actions: [{ actionType: 'device_command', deviceId: devLightId, command: 'setPower', params: { value: false } }]
    });

    // Record manual user interaction on devLightId
    automationService.recordManualUserAction(devLightId, 300); // 5 min cooldown

    // Try running automation that targets devLightId
    const autoRun = await automationService.runAutomation({
      homeId,
      userId: ownerUserId,
      automationId: autoLightOff.id,
      triggerSource: 'context_change',
      context: { homeId, home_context: 'HOME' }
    });

    const devAction = autoRun.targetResults?.find(t => t.deviceId === devLightId);
    assert('Device command was skipped due to manual command priority', devAction && devAction.status === 'skipped');
    assert('Skip reason is manual_command_priority', devAction && devAction.skipReason === 'manual_command_priority');
  }

  // --- Suite 9: Energy Integration While Away / Vacation ---
  console.log('\n--- Suite 9: Energy Integration While Away / Vacation ---');
  {
    // Set home to AWAY mode
    await contextService.setContextOverride({
      homeId,
      userId: ownerUserId,
      mode: 'AWAY',
      reason: 'Work Day'
    });

    // Simulate high power draw during absence (850W)
    await telemetryRepo.insertMeasurement({
      homeId,
      deviceId: devLightId,
      powerW: 850.0,
      voltageV: 120.0,
      currentA: 7.08
    });

    const energyCheck = await contextService.checkEnergyWhileAway(homeId);
    assert('High energy while away anomaly detected', energyCheck.hasAnomaly === true);
    assert('Anomaly type is HIGH_ENERGY_WHILE_AWAY', energyCheck.type === 'HIGH_ENERGY_WHILE_AWAY');
    assert('Total power exceeds threshold (> 500W)', energyCheck.totalPowerW >= 850.0);

    // Clean up override
    await contextService.clearContextOverride(homeId, ownerUserId);
  }

  // --- Suite 10: Data Retention & Policy Pruning ---
  console.log('\n--- Suite 10: Data Retention & Policy Pruning ---');
  {
    const oldDate = new Date(Date.now() - 40 * 24 * 3600 * 1000).toISOString(); // 40 days old

    // Insert old signal & transition
    await signalRepo.recordSignal({
      userId: ownerUserId,
      homeId,
      source: 'mobile_app',
      state: 'HOME',
      observedAt: oldDate
    });

    await transitionRepo.recordTransition({
      homeId,
      fromMode: 'HOME',
      toMode: 'AWAY',
      triggerSource: 'test_retention',
      createdAt: oldDate
    });

    const pruneSignalsRes = await retentionService.prunePresenceSignals(14);
    assert('Pruned stale presence signals (> 14 days)', pruneSignalsRes.pruned >= 1);

    const pruneTransRes = await retentionService.pruneContextTransitions(30);
    assert('Pruned stale context transitions (> 30 days)', pruneTransRes.pruned >= 1);
  }

  // --- Suite 11: REST APIs & RBAC Authorization Checks ---
  console.log('\n--- Suite 11: REST APIs & RBAC Authorization Checks ---');
  {
    // 1. GET /presence (200 for Owner)
    const res1 = await router.handleRequest({
      method: 'GET',
      url: `/api/v1/context/homes/${homeId}/presence`,
      userId: ownerUserId
    });
    assert('GET /presence returns 200 for Owner', res1.statusCode === 200 && res1.body.success === true);

    // 2. POST /presence (201 for Member)
    const res2 = await router.handleRequest({
      method: 'POST',
      url: `/api/v1/context/homes/${homeId}/presence`,
      userId: memberUserId,
      body: {
        source: 'mobile_app',
        state: 'HOME',
        confidence: 0.95
      }
    });
    assert('POST /presence returns 201 for Member', res2.statusCode === 201 && res2.body.success === true);

    // 3. GET /context (200)
    const res3 = await router.handleRequest({
      method: 'GET',
      url: `/api/v1/context/homes/${homeId}/context`,
      userId: memberUserId
    });
    assert('GET /context returns 200', res3.statusCode === 200 && res3.body.data.mode !== undefined);

    // 4. POST /override (200)
    const res4 = await router.handleRequest({
      method: 'POST',
      url: `/api/v1/context/homes/${homeId}/override`,
      userId: ownerUserId,
      body: { mode: 'SLEEP', reason: 'Sleeping' }
    });
    assert('POST /override returns 200', res4.statusCode === 200 && res4.body.data.override.mode === 'SLEEP');

    // 5. DELETE /override (200)
    const res5 = await router.handleRequest({
      method: 'DELETE',
      url: `/api/v1/context/homes/${homeId}/override`,
      userId: ownerUserId
    });
    assert('DELETE /override returns 200', res5.statusCode === 200 && res5.body.success === true);

    // 6. GET /transitions (200)
    const res6 = await router.handleRequest({
      method: 'GET',
      url: `/api/v1/context/homes/${homeId}/transitions`,
      userId: ownerUserId
    });
    assert('GET /transitions returns 200', res6.statusCode === 200 && Array.isArray(res6.body.data));

    // 7. GET /signals (200)
    const res7 = await router.handleRequest({
      method: 'GET',
      url: `/api/v1/context/homes/${homeId}/signals`,
      userId: ownerUserId
    });
    assert('GET /signals returns 200', res7.statusCode === 200 && Array.isArray(res7.body.data));

    // 8. POST /vacation (200)
    const res8 = await router.handleRequest({
      method: 'POST',
      url: `/api/v1/context/homes/${homeId}/vacation`,
      userId: ownerUserId,
      body: { durationDays: 7, reason: 'Ski Holiday' }
    });
    assert('POST /vacation returns 200', res8.statusCode === 200 && res8.body.data.context.isVacation === true);

    // Clean up vacation override
    await contextService.clearContextOverride(homeId, ownerUserId);

    // 9. 401 Unauthenticated
    const res401 = await router.handleRequest({
      method: 'GET',
      url: `/api/v1/context/homes/${homeId}/context`
    });
    assert('Unauthenticated request returns 401', res401.statusCode === 401);

    // 10. 403 Cross-Home Access
    const res403 = await router.handleRequest({
      method: 'GET',
      url: `/api/v1/context/homes/${homeId}/context`,
      userId: foreignUserId
    });
    assert('Cross-home request returns 403 Forbidden', res403.statusCode === 403);
  }

  console.log(`\n===============================================================`);
  console.log(`Phase 23 Tests Complete: ${passed} Passed, ${failed} Failed`);
  console.log(`===============================================================\n`);

  process.exit(failed > 0 ? 1 : 0);
}

runTests().catch(err => {
  console.error('Test execution error:', err);
  process.exit(1);
});
