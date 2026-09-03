'use strict';

/**
 * EH Home — Phase 21 Energy Cost Intelligence & Dynamic Tariffs Test Suite
 *
 * Verifies:
 *   1. Tariff CRUD, Time-Of-Use periods & validation
 *   2. Overnight period windows crossing midnight
 *   3. Historical tariff lookups & effective date isolation
 *   4. Authoritative cost calculation & peak/off-peak breakdown
 *   5. Cost forecasting & confidence score
 *   6. Energy budget tracking & overrun alerts
 *   7. Peak demand analysis & high-load windows
 *   8. Carbon footprint estimation & intensity sourcing
 *   9. Cheapest period analysis & load-shifting windows
 *   10. Cost optimization recommendations & dismissal
 *   11. Cost-aware automations with Phase 20 safeguards
 *   12. Multi-home isolation & REST API RBAC security
 */

const { createApp } = require('../src/app');
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
  AutomationRepository,
  AutomationExecutionLogRepository
} = require('../src/repositories');
const { EnergyService } = require('../src/services/energy.service');
const { AutomationService } = require('../src/services/automation.service');
const { EnergyApiRouter } = require('../src/api/energy.router');
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

async function runPhase21Tests() {
  console.log('=== PHASE 21: ENERGY COST INTELLIGENCE & DYNAMIC TARIFFS TESTS ===\n');

  const db = new DatabaseClient();

  const userRepo = new UserRepository(db);
  const homeRepo = new HomeRepository(db);
  const roomRepo = new RoomRepository(db);
  const deviceRepo = new DeviceRepository(db);
  const deviceStateRepo = new DeviceStateRepository(db);
  const telemetryRepo = new DeviceTelemetryRepository(db);
  const aggregateRepo = new TelemetryAggregateRepository(db);
  const thresholdRepo = new EnergyThresholdRepository(db);
  const eventRepo = new EnergyEventRepository(db);
  const executionRepo = new EnergyAutomationExecutionRepository(db);
  const optimizationRepo = new EnergyOptimizationRepository(db);
  const tariffRepo = new EnergyTariffRepository(db);
  const tariffPeriodRepo = new TariffPeriodRepository(db);
  const budgetRepo = new EnergyBudgetRepository(db);
  const costOptimizationRepo = new CostOptimizationRepository(db);
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
    notificationService: mockNotificationService
  });

  const energyService = new EnergyService({
    telemetryRepo,
    aggregateRepo,
    thresholdRepo,
    eventRepo,
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
    costOptimizationRepo
  });

  automationService.setEnergyService(energyService);

  const router = new EnergyApiRouter({
    energyService,
    homeAuthService,
    telemetryRepo,
    thresholdRepo,
    eventRepo,
    automationService,
    executionRepo,
    optimizationRepo
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
    supported_firmware_families: ['esp32c6-switch-platform']
  });

  // Setup sample users and homes
  const ownerUser = await userRepo.createUser({
    id: 'usr_owner_01',
    email: 'owner@example.com',
    passwordHash: 'hash',
    role: 'user'
  });
  const memberUser = await userRepo.createUser({
    id: 'usr_member_01',
    email: 'member@example.com',
    passwordHash: 'hash',
    role: 'user'
  });

  const home1 = await homeRepo.createHome({
    id: '0194fe23-7a1b-7890-a123-111111111111',
    ownerId: ownerUser.id,
    name: 'Smart Manor'
  });
  await homeRepo.addMembership({
    homeId: home1.id,
    userId: memberUser.id,
    role: 'MEMBER'
  });

  const roomLiving = await roomRepo.createRoom({
    id: 'room_living_01',
    homeId: home1.id,
    name: 'Living Room'
  });

  const devAc = await deviceRepo.createDevice({
    id: 'dev_ac_01',
    productVariantId: 'eh-smart-switch-3x',
    customName: 'Living Room AC',
    serialNumber: 'SN-AC-1001'
  });
  await deviceRepo.claimDevice({
    deviceId: devAc.id,
    homeId: home1.id,
    roomId: roomLiving.id,
    customName: 'Living Room AC',
    claimedByUserId: ownerUser.id
  });

  const devEv = await deviceRepo.createDevice({
    id: 'dev_ev_01',
    productVariantId: 'eh-smart-switch-3x',
    customName: 'EV Charger',
    serialNumber: 'SN-EV-2001'
  });
  await deviceRepo.claimDevice({
    deviceId: devEv.id,
    homeId: home1.id,
    roomId: roomLiving.id,
    customName: 'EV Charger',
    claimedByUserId: ownerUser.id
  });

  // ---------------------------------------------------------------------------
  // Suite 1: Tariff Model CRUD & Validation
  // ---------------------------------------------------------------------------
  console.log('\n--- Suite 1: Tariff Model CRUD & Validation ---');
  let flatTariff;
  try {
    flatTariff = await energyService.createTariff({
      homeId: home1.id,
      name: 'Default Flat Tariff',
      tariffType: 'FLAT',
      currency: 'USD',
      flatRatePerKwh: 0.18,
      fixedDailyCharge: 0.40,
      carbonIntensityGPerKwh: 380.0,
      effectiveFrom: '2026-01-01T00:00:00Z',
      isActive: true
    });
    assert('Create FLAT tariff passes', flatTariff && flatTariff.id);
    assert('Flat tariff currency saved as uppercase', flatTariff.currency === 'USD');
    assert('Tariff changed event published', publishedEvents.some(e => e.type === 'energy.tariff_changed'));
  } catch (err) {
    assert('Create FLAT tariff passes', false, err.message);
  }

  // Reject negative rates
  try {
    await energyService.createTariff({
      homeId: home1.id,
      name: 'Invalid Negative Tariff',
      tariffType: 'FLAT',
      currency: 'USD',
      flatRatePerKwh: -0.05
    });
    assert('Negative tariff rate rejected', false);
  } catch (err) {
    assert('Negative tariff rate rejected', true);
  }

  // Reject invalid currency code
  try {
    await energyService.createTariff({
      homeId: home1.id,
      name: 'Invalid Currency Tariff',
      tariffType: 'FLAT',
      currency: 'US',
      flatRatePerKwh: 0.15
    });
    assert('Invalid currency code rejected', false);
  } catch (err) {
    assert('Invalid currency code rejected', true);
  }

  // ---------------------------------------------------------------------------
  // Suite 2: Time-of-Use Pricing & Overnight Windows
  // ---------------------------------------------------------------------------
  console.log('\n--- Suite 2: Time-of-Use Pricing & Overnight Windows ---');
  let touTariff;
  try {
    touTariff = await energyService.createTariff({
      homeId: home1.id,
      name: 'Residential Time-Of-Use 2026',
      tariffType: 'TIME_OF_USE',
      currency: 'USD',
      fixedDailyCharge: 0.50,
      carbonIntensityGPerKwh: 410.0,
      effectiveFrom: '2026-06-01T00:00:00Z',
      isActive: true,
      periods: [
        {
          periodType: 'OFF_PEAK',
          startTime: '22:00',
          endTime: '06:00', // Overnight window crossing midnight
          applicableWeekdays: [1, 2, 3, 4, 5, 6, 7],
          pricePerKwh: 0.08
        },
        {
          periodType: 'PEAK',
          startTime: '14:00',
          endTime: '20:00',
          applicableWeekdays: [1, 2, 3, 4, 5],
          pricePerKwh: 0.32
        },
        {
          periodType: 'STANDARD',
          startTime: '06:00',
          endTime: '14:00',
          applicableWeekdays: [1, 2, 3, 4, 5],
          pricePerKwh: 0.16
        }
      ]
    });
    assert('Create TOU tariff with 3 periods passes', touTariff && touTariff.periods.length === 3);
  } catch (err) {
    assert('Create TOU tariff passes', false, err.message);
  }

  // Test rate resolution at 23:30 (Overnight OFF_PEAK)
  const rateNight = await energyService.resolveCurrentRate(home1.id, '2026-07-15T23:30:00Z');
  assert('23:30 resolves to OFF_PEAK (overnight window before midnight)', rateNight.periodType === 'OFF_PEAK' && rateNight.pricePerKwh === 0.08);

  // Test rate resolution at 03:15 (Overnight OFF_PEAK after midnight)
  const rateMorning = await energyService.resolveCurrentRate(home1.id, '2026-07-15T03:15:00Z');
  assert('03:15 resolves to OFF_PEAK (overnight window after midnight)', rateMorning.periodType === 'OFF_PEAK' && rateMorning.pricePerKwh === 0.08);

  // Test rate resolution at 16:45 on Wednesday (Weekday PEAK)
  const ratePeak = await energyService.resolveCurrentRate(home1.id, '2026-07-15T16:45:00Z'); // 2026-07-15 is Wednesday
  assert('16:45 Wednesday resolves to PEAK', ratePeak.periodType === 'PEAK' && ratePeak.pricePerKwh === 0.32);

  // Test rate resolution at 10:00 on Wednesday (Weekday STANDARD)
  const rateStd = await energyService.resolveCurrentRate(home1.id, '2026-07-15T10:00:00Z');
  assert('10:00 Wednesday resolves to STANDARD', rateStd.periodType === 'STANDARD' && rateStd.pricePerKwh === 0.16);

  // ---------------------------------------------------------------------------
  // Suite 3: Historical Tariff Tracking & Boundary Isolation
  // ---------------------------------------------------------------------------
  console.log('\n--- Suite 3: Historical Tariff Tracking & Boundary Isolation ---');
  // Lookup rate before June 2026 (should resolve to flatTariff)
  const rateHistorical = await energyService.resolveCurrentRate(home1.id, '2026-03-15T12:00:00Z');
  assert('Historical query in March resolves to Flat Tariff (0.18)', rateHistorical.tariffType === 'FLAT' && rateHistorical.pricePerKwh === 0.18);

  // ---------------------------------------------------------------------------
  // Suite 4: Authoritative Cost Calculation
  // ---------------------------------------------------------------------------
  console.log('\n--- Suite 4: Authoritative Cost Calculation ---');
  // Seed hourly aggregates:
  // 02:00 - 03:00: 5.0 kWh (OFF_PEAK @ 0.08 = $0.40)
  // 15:00 - 16:00: 4.0 kWh (PEAK @ 0.32 = $1.28)
  // 10:00 - 11:00: 2.5 kWh (STANDARD @ 0.16 = $0.40)
  // Fixed daily charge: $0.50
  // Total variable: $2.08, Total with fixed: $2.58
  await aggregateRepo.upsertAggregate({
    homeId: home1.id,
    deviceId: devAc.id,
    roomId: roomLiving.id,
    bucket: 'hour',
    startTime: '2026-07-15T02:00:00Z',
    endTime: '2026-07-15T03:00:00Z',
    energyDeltaWh: 5000,
    peakPowerW: 2200,
    avgPowerW: 2000,
    minPowerW: 1800,
    sampleCount: 60
  });

  await aggregateRepo.upsertAggregate({
    homeId: home1.id,
    deviceId: devAc.id,
    roomId: roomLiving.id,
    bucket: 'hour',
    startTime: '2026-07-15T15:00:00Z',
    endTime: '2026-07-15T16:00:00Z',
    energyDeltaWh: 4000,
    peakPowerW: 3000,
    avgPowerW: 2800,
    minPowerW: 2500,
    sampleCount: 60
  });

  await aggregateRepo.upsertAggregate({
    homeId: home1.id,
    deviceId: devEv.id,
    roomId: roomLiving.id,
    bucket: 'hour',
    startTime: '2026-07-15T10:00:00Z',
    endTime: '2026-07-15T11:00:00Z',
    energyDeltaWh: 2500,
    peakPowerW: 1200,
    avgPowerW: 1000,
    minPowerW: 900,
    sampleCount: 60
  });

  const costResult = await energyService.calculateEnergyCost(home1.id, {
    period: 'today',
    asOfDate: '2026-07-15T23:59:59Z'
  });

  assert('Total energy calculated accurately (11.5 kWh)', costResult.totalKwh === 11.5);
  assert('Peak energy breakdown matches (4.0 kWh)', costResult.breakdown.peak.kwh === 4.0);
  assert('Peak cost calculated accurately ($1.28)', costResult.breakdown.peak.cost === 1.28);
  assert('Off-peak cost calculated accurately ($0.40)', costResult.breakdown.offPeak.cost === 0.40);
  assert('Standard cost calculated accurately ($0.40)', costResult.breakdown.standard.cost === 0.40);
  assert('Fixed charge added ($0.50)', costResult.fixedCharges === 0.50);
  assert('Total cost matches ($2.58)', costResult.totalCost === 2.58);
  assert('Data quality is GOOD', costResult.dataQuality === 'GOOD');

  // Device-level cost
  const devAcCost = await energyService.getDeviceCost(home1.id, devAc.id, 'today', '2026-07-15T23:59:59Z');
  assert('Device cost for AC calculated accurately (9.0 kWh)', devAcCost.totalKwh === 9.0);

  // ---------------------------------------------------------------------------
  // Suite 5: Cost Forecasting
  // ---------------------------------------------------------------------------
  console.log('\n--- Suite 5: Cost Forecasting ---');
  const forecast = await energyService.getCostForecast(home1.id, {
    period: 'monthly',
    asOfDate: '2026-07-15T12:00:00Z'
  });

  assert('Forecast returns isEstimate: true', forecast.isEstimate === true);
  assert('Forecast contains actualCostToDate', forecast.actualCostToDate > 0);
  assert('Forecast projects remaining days of month', forecast.daysRemaining === 16);
  assert('Projected total cost > actual cost', forecast.projectedTotalCost >= forecast.actualCostToDate);
  assert('Confidence score is between 0 and 1', forecast.confidenceScore > 0 && forecast.confidenceScore <= 1.0);

  // ---------------------------------------------------------------------------
  // Suite 6: Energy Budget Tracking & Overrun Alerts
  // ---------------------------------------------------------------------------
  console.log('\n--- Suite 6: Energy Budget Tracking & Overrun Alerts ---');
  // Set budget of $50/month with 80% alert threshold
  const budget = await energyService.setBudget({
    homeId: home1.id,
    periodType: 'monthly',
    budgetAmount: 50.0,
    currency: 'USD',
    alertThresholdPercent: 80,
    isEnabled: true
  });
  assert('Set monthly energy budget passes', budget && budget.budget_amount === 50.0);

  const budgetStatus = await energyService.getBudgetStatus(home1.id, 'monthly', {
    asOfDate: '2026-07-15T12:00:00Z'
  });
  assert('Budget status configured is true', budgetStatus.configured === true);
  assert('Budget remaining is calculated', typeof budgetStatus.budgetRemaining === 'number');
  assert('Percent consumed is calculated', typeof budgetStatus.percentConsumed === 'number');

  // Test Overrun Condition ($2 budget -> will be exceeded)
  await energyService.setBudget({
    homeId: home1.id,
    periodType: 'monthly',
    budgetAmount: 2.0,
    currency: 'USD',
    alertThresholdPercent: 50,
    isEnabled: true
  });
  const overrunStatus = await energyService.getBudgetStatus(home1.id, 'monthly', {
    asOfDate: '2026-07-15T12:00:00Z'
  });
  assert('Projected overrun detected', overrunStatus.isProjectedToExceed === true && overrunStatus.projectedOverrun > 0);
  assert('Budget forecast exceeded event published', publishedEvents.some(e => e.type === 'energy.budget_forecast_exceeded'));
  assert('Notification sent for budget overrun', sentNotifications.some(n => n.category === 'energy_budget'));

  // ---------------------------------------------------------------------------
  // Suite 7: Peak Demand Analysis
  // ---------------------------------------------------------------------------
  console.log('\n--- Suite 7: Peak Demand Analysis ---');
  const peakAnalysis = await energyService.getPeakDemandAnalysis(home1.id, {
    asOfDate: '2026-07-15T23:59:59Z'
  });
  assert('Peak demand analysis returns highestHistoricalPeakW >= 3000', peakAnalysis.highestHistoricalPeakW >= 3000);
  assert('Repeated high load windows returned', Array.isArray(peakAnalysis.repeatedHighLoadWindows) && peakAnalysis.repeatedHighLoadWindows.length > 0);

  // ---------------------------------------------------------------------------
  // Suite 8: Carbon Footprint Estimation
  // ---------------------------------------------------------------------------
  console.log('\n--- Suite 8: Carbon Footprint Estimation ---');
  const carbon = await energyService.getCarbonFootprint(home1.id, {
    period: 'today',
    asOfDate: '2026-07-15T23:59:59Z'
  });
  assert('Carbon footprint calculated with configured tariff intensity (410 g/kWh)', carbon.carbonIntensityGPerKwh === 410.0);
  assert('Total grams CO2 estimated (11.5 kWh * 410 = 4715g)', carbon.totalGramsCO2 === 4715);
  assert('Total kg CO2 estimated (4.72 kg)', carbon.totalKgCO2 === 4.72);
  assert('Source flagged as configured_tariff', carbon.source === 'configured_tariff');
  assert('Marked as isEstimate: true', carbon.isEstimate === true);

  // ---------------------------------------------------------------------------
  // Suite 9: Cheapest Period Analysis & Load Shifting
  // ---------------------------------------------------------------------------
  console.log('\n--- Suite 9: Cheapest Period Analysis & Load Shifting ---');
  const cheapestAnalysis = await energyService.getCheapestPeriods(home1.id, {
    durationHours: 2,
    withinHours: 24,
    asOfTime: '2026-07-15T12:00:00Z'
  });
  assert('Cheapest window identified (avg price $0.08)', cheapestAnalysis.cheapestWindow.avgPricePerKwh === 0.08);
  assert('Peak window identified (PEAK @ $0.32)', cheapestAnalysis.peakWindow.periodType === 'PEAK' && cheapestAnalysis.peakWindow.avgPricePerKwh === 0.32);
  assert('Potential savings percent is 75%', cheapestAnalysis.potentialSavingsPercent === 75);

  // ---------------------------------------------------------------------------
  // Suite 10: Cost Optimization Recommendations
  // ---------------------------------------------------------------------------
  console.log('\n--- Suite 10: Cost Optimization Recommendations ---');
  const optResult = await energyService.generateCostOptimizations(home1.id, { asOfDate: '2026-07-15T23:59:59Z' });
  assert('Cost optimization recommendations generated', optResult.recommendations.length > 0);
  const acOpt = optResult.recommendations.find(r => r.device_id === devAc.id);
  assert('AC load-shifting recommendation generated', acOpt && acOpt.category === 'LOAD_SHIFTING');
  assert('Cost optimization event published', publishedEvents.some(e => e.type === 'energy.cost_optimization_detected'));

  // Test Dismissal
  await energyService.dismissCostOptimization(acOpt.id);
  const remainingOpts = await energyService.getCostOptimizations(home1.id, { includeDismissed: false });
  assert('Dismissed optimization not included in active list', !remainingOpts.some(r => r.id === acOpt.id));

  // ---------------------------------------------------------------------------
  // Suite 11: Cost-Aware Automation Execution & Safeguards
  // ---------------------------------------------------------------------------
  console.log('\n--- Suite 11: Cost-Aware Automation Execution & Safeguards ---');
  // Create automation: Turn OFF device when price > 0.25 (i.e. During PEAK)
  const priceRule = await automationRepo.createAutomation({
    id: 'auto_cost_price_01',
    homeId: home1.id,
    name: 'Peak Price Power Limiter',
    isEnabled: true,
    triggerType: 'energy_cost',
    triggerConfig: { cooldownSeconds: 60 },
    conditions: [
      {
        metric: 'tariff_price',
        operator: 'GT',
        threshold: 0.25
      }
    ],
    actions: [
      {
        actionType: 'device_command',
        deviceId: devEv.id,
        channelIndex: 1,
        command: 'setPower',
        params: { value: false }
      }
    ]
  });

  // Evaluate rule during PEAK (rate = 0.32 > 0.25 -> Should trigger)
  const peakExecResult = await automationService.runAutomation({
    homeId: home1.id,
    automationId: priceRule.id,
    triggerSource: 'telemetry_hook',
    context: { asOfTime: '2026-07-15T16:00:00Z' }
  });
  assert('Price-based automation triggers during peak price ($0.32 > $0.25)', peakExecResult.success === true && peakExecResult.status === 'succeeded');

  // Cooldown safeguard: Run immediately again -> should be skipped by cooldown
  const cooldownExecResult = await automationService.runAutomation({
    homeId: home1.id,
    automationId: priceRule.id,
    triggerSource: 'telemetry_hook',
    context: { asOfTime: '2026-07-15T16:00:00Z' }
  });
  assert('Cost automation suppressed by cooldown', cooldownExecResult.status === 'skipped' && cooldownExecResult.skipReason === 'in_cooldown');

  // Create automation: Turn ON when tariff_period == OFF_PEAK
  const periodRule = await automationRepo.createAutomation({
    id: 'auto_cost_period_01',
    homeId: home1.id,
    name: 'Off-Peak EV Auto-Start',
    isEnabled: true,
    triggerType: 'energy_cost',
    conditions: [
      {
        metric: 'tariff_period',
        operator: 'EQ',
        threshold: 'OFF_PEAK'
      }
    ],
    actions: [
      {
        actionType: 'device_command',
        deviceId: devEv.id,
        channelIndex: 1,
        command: 'setPower',
        params: { value: true }
      }
    ]
  });

  const periodCondMet = await automationService.evaluateConditions(periodRule.conditions, { homeId: home1.id });
  // Currently rate night (23:30) vs current system time
  assert('Tariff period condition evaluation succeeds', typeof periodCondMet === 'boolean');

  // ---------------------------------------------------------------------------
  // Suite 12: REST API & Authorization RBAC
  // ---------------------------------------------------------------------------
  console.log('\n--- Suite 12: REST API & Authorization RBAC ---');

  // Owner can fetch tariffs (200)
  const apiGetTariffs = await router.handleRequest(
    { method: 'GET', path: `/api/v1/energy/homes/${home1.id}/tariffs` },
    { userId: ownerUser.id }
  );
  assert('GET /tariffs returns 200 for Owner', apiGetTariffs.statusCode === 200 && apiGetTariffs.body.data.length >= 2);

  // Member cannot create tariff (403 - requires canManageHome)
  const apiMemberCreate = await router.handleRequest(
    {
      method: 'POST',
      path: `/api/v1/energy/homes/${home1.id}/tariffs`,
      body: { name: 'Member Tariff', tariffType: 'FLAT', currency: 'USD', flatRatePerKwh: 0.15 }
    },
    { userId: memberUser.id }
  );
  assert('POST /tariffs returns 403 for Member without canManageHome', apiMemberCreate.statusCode === 403);

  // Owner can create tariff (201)
  const apiOwnerCreate = await router.handleRequest(
    {
      method: 'POST',
      path: `/api/v1/energy/homes/${home1.id}/tariffs`,
      body: { name: 'Admin Created Tariff', tariffType: 'FLAT', currency: 'EUR', flatRatePerKwh: 0.22, effectiveFrom: '2026-09-01T00:00:00Z' }
    },
    { userId: ownerUser.id }
  );
  assert('POST /tariffs returns 201 for Owner', apiOwnerCreate.statusCode === 201 && apiOwnerCreate.body.data.currency === 'EUR');

  // GET /cost endpoint
  const apiGetCost = await router.handleRequest(
    { method: 'GET', path: `/api/v1/energy/homes/${home1.id}/cost`, query: { period: 'today' } },
    { userId: ownerUser.id }
  );
  assert('GET /cost returns 200 with data', apiGetCost.statusCode === 200 && apiGetCost.body.data.totalCost !== undefined);

  // GET /cost/forecast endpoint
  const apiGetForecast = await router.handleRequest(
    { method: 'GET', path: `/api/v1/energy/homes/${home1.id}/cost/forecast`, query: { period: 'monthly' } },
    { userId: ownerUser.id }
  );
  assert('GET /cost/forecast returns 200 with forecast', apiGetForecast.statusCode === 200 && apiGetForecast.body.data.isEstimate === true);

  // GET /budget endpoint
  const apiGetBudget = await router.handleRequest(
    { method: 'GET', path: `/api/v1/energy/homes/${home1.id}/budget`, query: { periodType: 'monthly' } },
    { userId: ownerUser.id }
  );
  assert('GET /budget returns 200 with budget status', apiGetBudget.statusCode === 200 && apiGetBudget.body.data.configured === true);

  // GET /optimization/cheapest-periods
  const apiGetCheapest = await router.handleRequest(
    { method: 'GET', path: `/api/v1/energy/homes/${home1.id}/optimization/cheapest-periods` },
    { userId: ownerUser.id }
  );
  assert('GET /optimization/cheapest-periods returns 200', apiGetCheapest.statusCode === 200 && apiGetCheapest.body.data.cheapestWindow !== undefined);

  // GET /carbon
  const apiGetCarbon = await router.handleRequest(
    { method: 'GET', path: `/api/v1/energy/homes/${home1.id}/carbon` },
    { userId: ownerUser.id }
  );
  assert('GET /carbon returns 200 with CO2 estimate', apiGetCarbon.statusCode === 200 && apiGetCarbon.body.data.totalKgCO2 !== undefined);

  // Unauthenticated returns 401
  const apiUnauth = await router.handleRequest(
    { method: 'GET', path: `/api/v1/energy/homes/${home1.id}/cost` },
    null
  );
  assert('Unauthenticated request returns 401', apiUnauth.statusCode === 401);

  // Cross-home unauthorized access returns 403
  const strangerUser = await userRepo.createUser({
    id: 'usr_stranger_01',
    email: 'stranger@example.com',
    passwordHash: 'hash',
    role: 'user'
  });
  const apiCrossHome = await router.handleRequest(
    { method: 'GET', path: `/api/v1/energy/homes/${home1.id}/cost` },
    { userId: strangerUser.id }
  );
  assert('Cross-home access returns 403 Forbidden', apiCrossHome.statusCode === 403);

  console.log(`\n===============================================================`);
  console.log(`Phase 21 Tests Complete: ${passed} Passed, ${failed} Failed`);
  console.log(`===============================================================\n`);

  if (failed > 0) {
    process.exit(1);
  }
}

runPhase21Tests().catch(err => {
  console.error('Unhandled test failure:', err);
  process.exit(1);
});
