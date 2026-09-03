/**
 * EH Home — Phase 22 Energy Forecasting + Predictive Intelligence Test Suite
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
  AutomationRepository,
  AutomationExecutionLogRepository
} = require('../src/repositories');
const { EnergyService } = require('../src/services/energy.service');
const { AutomationService } = require('../src/services/automation.service');
const { DataRetentionService } = require('../src/services/data-retention.service');
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

async function runTests() {
  console.log('=== PHASE 22: ENERGY FORECASTING & PREDICTIVE INTELLIGENCE TESTS ===\n');

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
  const forecastRepo = new EnergyForecastRepository(db);
  const anomalyRepo = new EnergyAnomalyRepository(db);
  const baselineRepo = new EnergyBaselineRepository(db);
  const accuracyRepo = new ForecastAccuracyRepository(db);
  const efficiencyRepo = new EnergyEfficiencyScoreRepository(db);
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
    costOptimizationRepo,
    forecastRepo,
    anomalyRepo,
    baselineRepo,
    accuracyRepo,
    efficiencyRepo
  });

  automationService.setEnergyService(energyService);

  const retentionService = new DataRetentionService({ db });

  const router = new EnergyApiRouter({
    energyService,
    homeAuthService,
    deviceRepo,
    roomRepo,
    telemetryRepo,
    thresholdRepo,
    eventRepo,
    automationService,
    executionRepo,
    optimizationRepo
  });

  const homeId = 'home_p22_01';
  const otherHomeId = 'home_p22_02';
  const roomId = 'room_living_01';
  const devAcId = 'dev_ac_01';
  const devEvId = 'dev_ev_01';
  const ownerUserId = 'user_owner_01';
  const memberUserId = 'user_member_01';

  // Seed baseline Home, Memberships & Devices
  await db.insert('homes', homeId, { id: homeId, name: 'Smart Villa Phase 22', owner_id: ownerUserId });
  await db.insert('homes', otherHomeId, { id: otherHomeId, name: 'Other Villa', owner_id: 'other_owner' });
  await db.insert('rooms', roomId, { id: roomId, home_id: homeId, name: 'Living Room' });

  await db.insert('home_memberships', `mem_${ownerUserId}`, {
    id: `mem_${ownerUserId}`,
    home_id: homeId,
    user_id: ownerUserId,
    role: 'OWNER',
    can_control_devices: true,
    can_manage_devices: true,
    can_manage_automations: true,
    can_manage_home: true
  });

  await db.insert('home_memberships', `mem_${memberUserId}`, {
    id: `mem_${memberUserId}`,
    home_id: homeId,
    user_id: memberUserId,
    role: 'MEMBER',
    can_control_devices: true,
    can_manage_devices: false,
    can_manage_automations: false,
    can_manage_home: false
  });

  await db.insert('devices', devAcId, {
    id: devAcId,
    home_id: homeId,
    room_id: roomId,
    product_variant_id: 'eh-smart-switch-3x',
    custom_name: 'Living Room AC',
    is_active: true
  });

  await db.insert('devices', devEvId, {
    id: devEvId,
    home_id: homeId,
    room_id: roomId,
    product_variant_id: 'eh-ev-charger-1x',
    custom_name: 'EV Charger',
    is_active: true
  });

  // Seed active TOU tariff
  await energyService.createTariff({
    homeId,
    name: 'Standard TOU Plan',
    tariffType: 'TIME_OF_USE',
    currency: 'USD',
    effectiveFrom: '2026-01-01T00:00:00Z',
    fixedDailyCharge: 0.50,
    carbonIntensityGPerKwh: 400,
    isActive: true,
    periods: [
      { id: 'p_off', periodType: 'OFF_PEAK', startTime: '22:00', endTime: '06:00', applicableWeekdays: [1,2,3,4,5,6,7], pricePerKwh: 0.10 },
      { id: 'p_peak', periodType: 'PEAK', startTime: '16:00', endTime: '21:00', applicableWeekdays: [1,2,3,4,5], pricePerKwh: 0.35 },
      { id: 'p_std', periodType: 'STANDARD', startTime: '06:00', endTime: '16:00', applicableWeekdays: [1,2,3,4,5], pricePerKwh: 0.18 }
    ]
  });

  // Populate 48 hours of historical aggregates for AC and EV
  const baseTimestamp = new Date('2026-07-15T12:00:00Z');
  for (let i = 48; i > 0; i--) {
    const bucketStart = new Date(baseTimestamp.getTime() - i * 3600 * 1000).toISOString();
    const bucketEnd = new Date(baseTimestamp.getTime() - (i - 1) * 3600 * 1000).toISOString();
    const h = new Date(bucketStart).getUTCHours();

    // AC pattern: high power in afternoons (14-20h), low overnight
    const isAcActive = h >= 14 && h <= 20;
    const isOvernight = h >= 0 && h < 6;
    const acPowerW = isAcActive ? 1800 : (isOvernight ? 15 : 120);
    const acEnergyWh = acPowerW * 1.0;

    await db.insert('telemetry_aggregates', `agg_ac_${i}`, {
      id: `agg_ac_${i}`,
      home_id: homeId,
      device_id: devAcId,
      room_id: roomId,
      channel_index: 1,
      bucket_type: 'hour',
      bucket_start: bucketStart,
      bucket_end: bucketEnd,
      start_time: bucketStart,
      end_time: bucketEnd,
      energy_delta_wh: acEnergyWh,
      total_energy_wh: acEnergyWh,
      avg_power_w: acPowerW,
      peak_power_w: acPowerW * 1.2,
      min_power_w: acPowerW * 0.8,
      sample_count: 60,
      created_at: bucketStart
    });
  }

  // --- Suite 1: Forecast Engine & Multi-Horizon Verification ---
  console.log('--- Suite 1: Forecast Engine & Multi-Horizon Verification ---');
  {
    // Next 24 hours forecast
    const fc24h = await energyService.getForecast({
      homeId,
      horizon: 'next_24_hours',
      asOfDate: baseTimestamp
    });

    assert('Next 24 hours forecast generated', !!fc24h);
    assert('Forecast is marked isEstimate: true', fc24h.isEstimate === true);
    assert('Forecast has 24 hourly points', fc24h.points.length === 24);
    assert('Forecast predictedKwh is positive (> 0)', fc24h.predictedKwh > 0);
    assert('Forecast predictedCost is positive (> 0)', fc24h.predictedCost > 0);
    assert('Forecast dataCoverage is FULL', fc24h.dataCoverage === 'FULL');
    assert('Forecast confidenceScore is high (>= 0.8)', fc24h.confidenceScore >= 0.8);
    assert('Methodology is HISTORICAL_HOURLY_PROFILE_DAY_OF_WEEK', fc24h.methodology === 'HISTORICAL_HOURLY_PROFILE_DAY_OF_WEEK');

    // Next hour forecast (15-min intervals)
    const fc1h = await energyService.getForecast({
      homeId,
      horizon: 'next_hour',
      asOfDate: baseTimestamp
    });
    assert('Next 1 hour forecast generated with 4 points', fc1h.points.length === 4);

    // Current month forecast
    const fcMonth = await energyService.getMonthlyForecast(homeId, { asOfDate: baseTimestamp });
    assert('Monthly forecast generated', !!fcMonth);
    assert('Monthly predictedKwh > 24h predictedKwh', fcMonth.predictedKwh > fc24h.predictedKwh);

    // Insufficient historical data guard
    const fcEmpty = await energyService.getForecast({
      homeId: otherHomeId,
      horizon: 'next_24_hours',
      asOfDate: baseTimestamp
    });
    assert('Empty history returns INSUFFICIENT data coverage', fcEmpty.dataCoverage === 'INSUFFICIENT');
    assert('Empty history confidence score is low (<= 0.25)', fcEmpty.confidenceScore <= 0.25);
  }

  // --- Suite 2: Device, Room & Home Baselines ---
  console.log('\n--- Suite 2: Device, Room & Home Baselines ---');
  {
    const acBase = await energyService.getDeviceBaseline(homeId, devAcId, { asOfDate: baseTimestamp });
    assert('Device baseline calculated', !!acBase);
    assert('AC typicalPowerW is calculated (> 100W)', acBase.typicalPowerW > 100);
    assert('AC typicalDailyEnergyKwh is calculated (> 5 kWh)', acBase.typicalDailyEnergyKwh > 5);
    assert('AC typicalOperatingHours contains afternoon hours (14, 15, 16)', acBase.typicalOperatingHours.includes(15));
    assert('AC sampleCount matches observations (48)', acBase.sampleCount === 48);

    const roomBase = await energyService.getRoomBaseline(homeId, roomId, { asOfDate: baseTimestamp });
    assert('Room baseline calculated', !!roomBase);
    assert('Room typicalDailyEnergyKwh >= AC typicalDailyEnergyKwh', roomBase.typicalDailyEnergyKwh >= acBase.typicalDailyEnergyKwh);

    const homeBase = await energyService.getHomeBaseline(homeId, { asOfDate: baseTimestamp });
    assert('Home baseline calculated', !!homeBase);
    assert('Home typicalDailyEnergyKwh >= Room typicalDailyEnergyKwh', homeBase.typicalDailyEnergyKwh >= roomBase.typicalDailyEnergyKwh);
  }

  // --- Suite 3: Explainable Anomaly Detection & Severity ---
  console.log('\n--- Suite 3: Explainable Anomaly Detection & Severity ---');
  {
    // Inject abnormal overnight consumption for AC (3500W during 02:00-04:00)
    const anomalyTime = new Date('2026-07-16T03:00:00Z');
    await db.insert('telemetry_aggregates', 'agg_ac_anom_1', {
      id: 'agg_ac_anom_1',
      home_id: homeId,
      device_id: devAcId,
      room_id: roomId,
      channel_index: 1,
      bucket_type: 'hour',
      bucket_start: '2026-07-16T02:00:00Z',
      bucket_end: '2026-07-16T03:00:00Z',
      start_time: '2026-07-16T02:00:00Z',
      end_time: '2026-07-16T03:00:00Z',
      energy_delta_wh: 3500.0,
      total_energy_wh: 3500.0,
      avg_power_w: 3500.0,
      peak_power_w: 3800.0,
      sample_count: 60,
      created_at: '2026-07-16T03:00:00Z'
    });

    const anomalies = await energyService.detectAnomalies(homeId, { asOfDate: anomalyTime });
    assert('Anomalies detected for abnormal AC usage', anomalies.length > 0);

    const powerSpike = anomalies.find(a => a.anomaly_type === 'UNUSUAL_POWER_SPIKE');
    assert('Unusual power spike anomaly detected', !!powerSpike);
    assert('Power spike has high severity (HIGH or CRITICAL)', powerSpike.severity === 'HIGH' || powerSpike.severity === 'CRITICAL');
    assert('Anomaly contains evidence', !!powerSpike.evidence_json || !!powerSpike.evidence);

    // Confirm anomaly
    const confirmed = await energyService.confirmAnomaly(powerSpike.id);
    assert('Anomaly confirmed successfully', confirmed.is_confirmed === true);
  }

  // --- Suite 4: Forecasted Cost & Budget Overrun Prediction ---
  console.log('\n--- Suite 4: Forecasted Cost & Budget Overrun Prediction ---');
  {
    // Configure tight monthly budget of $15
    await energyService.setBudget({
      homeId,
      periodType: 'monthly',
      budgetAmount: 15.0,
      currency: 'USD',
      alertThresholdPercent: 80,
      isEnabled: true
    });

    const budgetFc = await energyService.getBudgetForecast(homeId, { periodType: 'monthly', asOfDate: baseTimestamp });
    assert('Budget forecast calculated', !!budgetFc);
    assert('Configured status is true', budgetFc.configured === true);
    assert('Predicted total budget usage is calculated', budgetFc.predictedBudgetUsage > 0);
    assert('Overrun detection flag computed', typeof budgetFc.isOverrunPredicted === 'boolean');
    assert('isEstimate is true', budgetFc.isEstimate === true);
  }

  // --- Suite 5: Peak Demand Forecasting ---
  console.log('\n--- Suite 5: Peak Demand Forecasting ---');
  {
    const peakFc = await energyService.getPeakDemandForecast(homeId, { horizon: 'next_24_hours', asOfDate: baseTimestamp });
    assert('Peak demand forecast calculated', !!peakFc);
    assert('predictedPeakLoadW is positive (> 0)', peakFc.predictedPeakLoadW > 0);
    assert('expectedPeakTime is valid timestamp', !isNaN(new Date(peakFc.expectedPeakTime).getTime()));
    assert('Supporting evidence is included', !!peakFc.supportingEvidence);
  }

  // --- Suite 6: Energy Efficiency Score ---
  console.log('\n--- Suite 6: Energy Efficiency Score ---');
  {
    const scoreData = await energyService.getEfficiencyScore(homeId, { asOfDate: baseTimestamp });
    assert('Efficiency score calculated', !!scoreData);
    assert('Score is bounded between 0 and 100', scoreData.score >= 0 && scoreData.score <= 100);
    assert('Grade is assigned (A+, A, B, C, D, F)', ['A+', 'A', 'B', 'C', 'D', 'F'].includes(scoreData.grade));
    assert('Factors contains standbyLossScore', typeof scoreData.factors.standbyLossScore === 'number');
    assert('Factors contains peakDemandScore', typeof scoreData.factors.peakDemandScore === 'number');
    assert('Factors contains thresholdViolationScore', typeof scoreData.factors.thresholdViolationScore === 'number');
    assert('Factors contains tariffEfficiencyScore', typeof scoreData.factors.tariffEfficiencyScore === 'number');
  }

  // --- Suite 7: Predictive Optimization Recommendations ---
  console.log('\n--- Suite 7: Predictive Optimization Recommendations ---');
  {
    const recommendations = await energyService.getPredictiveOptimizations(homeId, { asOfDate: baseTimestamp });
    assert('Predictive optimization recommendations returned', Array.isArray(recommendations));
    if (recommendations.length > 0) {
      const rec = recommendations[0];
      assert('Recommendation marked isEstimate: true', rec.isEstimate === true);
      assert('Recommendation has confidence score', typeof rec.confidence === 'number');
      assert('Recommendation contains reason and description', !!rec.reason && !!rec.description);
    }
  }

  // --- Suite 8: Forecast Accuracy Tracking (MAE / MAPE) ---
  console.log('\n--- Suite 8: Forecast Accuracy Tracking (MAE / MAPE) ---');
  {
    // Record sample past prediction vs actual
    await energyService.recordForecastAccuracy({
      homeId,
      horizon: 'next_24_hours',
      predictedValue: 14.0,
      actualValue: 15.0
    });
    await energyService.recordForecastAccuracy({
      homeId,
      horizon: 'next_24_hours',
      predictedValue: 16.5,
      actualValue: 15.5
    });
    await energyService.recordForecastAccuracy({
      homeId,
      horizon: 'next_24_hours',
      predictedValue: 12.0,
      actualValue: 13.0
    });

    const metrics = await energyService.getForecastAccuracy(homeId, { horizon: 'next_24_hours' });
    assert('Accuracy sample count is 3', metrics.sampleCount === 3);
    assert('MAE is calculated accurately (1.0)', metrics.mae === 1.0);
    assert('MAPE is calculated accurately (> 0)', metrics.mape > 0);
    assert('hasSufficientData is true (>= 3)', metrics.hasSufficientData === true);
  }

  // --- Suite 9: Predictive Automation Condition Evaluation ---
  console.log('\n--- Suite 9: Predictive Automation Condition Evaluation ---');
  {
    // 1. forecast_daily_energy condition
    const isDailyEnergyMet = await automationService.evaluateCondition(
      { metric: 'forecast_daily_energy', operator: 'GT', threshold: 1.0, homeId },
      { homeId, asOfTime: baseTimestamp }
    );
    assert('forecast_daily_energy condition evaluates to true (> 1.0 kWh)', isDailyEnergyMet === true);

    // 2. efficiency_score condition
    const isEfficiencyMet = await automationService.evaluateCondition(
      { metric: 'efficiency_score', operator: 'LT', threshold: 99.0, homeId },
      { homeId, asOfTime: baseTimestamp }
    );
    assert('efficiency_score condition evaluates to true (< 99.0)', isEfficiencyMet === true);

    // 3. predicted_peak_power condition
    const isPeakPowerMet = await automationService.evaluateCondition(
      { metric: 'predicted_peak_power', operator: 'GT', threshold: 50.0, homeId },
      { homeId, asOfTime: baseTimestamp }
    );
    assert('predicted_peak_power condition evaluates to true (> 50W)', isPeakPowerMet === true);

    // 4. forecast_budget_overrun condition
    const isOverrunMet = await automationService.evaluateCondition(
      { metric: 'forecast_budget_overrun', operator: 'GTE', threshold: 0.0, homeId },
      { homeId, asOfTime: baseTimestamp }
    );
    assert('forecast_budget_overrun condition evaluated', typeof isOverrunMet === 'boolean');

    // 5. Create and run rule
    const autoRule = await automationService.createAutomation({
      homeId,
      userId: ownerUserId,
      name: 'High Daily Energy Warning',
      triggerType: 'energy',
      triggerCondition: {
        metric: 'forecast_daily_energy',
        operator: 'GT',
        threshold: 1.0,
        homeId
      },
      actions: [{ actionType: 'device_command', deviceId: devAcId, command: 'SET_POWER_MODE', params: { eco: true } }]
    });

    const runResult = await automationService.runAutomation({
      homeId,
      userId: ownerUserId,
      automationId: autoRule.id,
      triggerSource: 'predictive_forecast',
      context: { homeId, asOfTime: baseTimestamp }
    });
    assert('runAutomation executed successfully with predictive context', runResult.success === true);
  }

  // --- Suite 10: Data Retention & Policy Pruning ---
  console.log('\n--- Suite 10: Data Retention & Policy Pruning ---');
  {
    const oldDate = new Date(Date.now() - 40 * 24 * 3600 * 1000).toISOString();
    await db.insert('energy_forecasts', 'fc_old_01', {
      id: 'fc_old_01',
      home_id: homeId,
      horizon: 'next_24_hours',
      created_at: oldDate
    });

    const cycleResult = await retentionService.runRetentionCycle({ forecastDays: 30 });
    assert('Forecast retention pruned stale forecasts', cycleResult.forecastsPruned >= 1);
    const deletedFc = await db.findById('energy_forecasts', 'fc_old_01');
    assert('Old forecast was deleted', deletedFc === null);
  }

  // --- Suite 11: REST APIs & RBAC Authorization Checks ---
  console.log('\n--- Suite 11: REST APIs & RBAC Authorization Checks ---');
  {
    // GET /api/v1/energy/homes/:homeId/forecast (200 for Owner)
    const resFc = await router.handleRequest({
      method: 'GET',
      url: `/api/v1/energy/homes/${homeId}/forecast?horizon=next_24_hours`,
      userId: ownerUserId
    });
    assert('GET /forecast returns 200 for Owner', resFc.statusCode === 200 && resFc.body.success === true);

    // GET /api/v1/energy/devices/:deviceId/baseline (200 for Member)
    const resBase = await router.handleRequest({
      method: 'GET',
      url: `/api/v1/energy/devices/${devAcId}/baseline`,
      userId: memberUserId
    });
    assert('GET /devices/:deviceId/baseline returns 200 for Member', resBase.statusCode === 200 && resBase.body.success === true);

    // GET /api/v1/energy/homes/:homeId/efficiency-score (200)
    const resEff = await router.handleRequest({
      method: 'GET',
      url: `/api/v1/energy/homes/${homeId}/efficiency-score`,
      userId: ownerUserId
    });
    assert('GET /efficiency-score returns 200', resEff.statusCode === 200 && resEff.body.data.score > 0);

    // GET /api/v1/energy/homes/:homeId/predictive-optimization (200)
    const resPredOpt = await router.handleRequest({
      method: 'GET',
      url: `/api/v1/energy/homes/${homeId}/predictive-optimization`,
      userId: ownerUserId
    });
    assert('GET /predictive-optimization returns 200', resPredOpt.statusCode === 200);

    // GET /api/v1/energy/homes/:homeId/forecast/accuracy (200)
    const resAcc = await router.handleRequest({
      method: 'GET',
      url: `/api/v1/energy/homes/${homeId}/forecast/accuracy?horizon=next_24_hours`,
      userId: ownerUserId
    });
    assert('GET /forecast/accuracy returns 200', resAcc.statusCode === 200 && resAcc.body.data.sampleCount > 0);

    // Unauthenticated request (401)
    const resUnauth = await router.handleRequest({
      method: 'GET',
      url: `/api/v1/energy/homes/${homeId}/forecast`,
      userId: null
    });
    assert('Unauthenticated request returns 401', resUnauth.statusCode === 401);

    // Cross-home unauthorized request (403)
    const resCross = await router.handleRequest({
      method: 'GET',
      url: `/api/v1/energy/homes/${otherHomeId}/forecast`,
      userId: ownerUserId
    });
    assert('Cross-home request returns 403 Forbidden', resCross.statusCode === 403);
  }

  console.log(`\n===============================================================`);
  console.log(`Phase 22 Tests Complete: ${passed} Passed, ${failed} Failed`);
  console.log(`===============================================================\n`);

  process.exit(failed > 0 ? 1 : 0);
}

runTests().catch(err => {
  console.error('Test execution error:', err);
  process.exit(1);
});
