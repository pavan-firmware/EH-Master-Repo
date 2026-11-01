"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.energyEfficiencyScores = exports.forecastAccuracyRecords = exports.energyBaselines = exports.energyAnomalies = exports.energyForecasts = exports.costOptimizations = exports.energyBudgets = exports.tariffPeriods = exports.energyTariffs = exports.energyOptimizations = exports.energyAutomationExecutions = exports.energyEvents = exports.energyThresholdConfigs = exports.telemetryAggregates = exports.deviceTelemetryMeasurements = void 0;
/**
 * EH Home Schema — energy-intelligence
 * Source: PostgreSQL Migrations 001–029
 */
const pg_core_1 = require("drizzle-orm/pg-core");
// --- device_telemetry_measurements (012_energy_intelligence.sql) ---
exports.deviceTelemetryMeasurements = (0, pg_core_1.pgTable)('device_telemetry_measurements', {
    id: (0, pg_core_1.text)('id').primaryKey(),
    deviceId: (0, pg_core_1.text)('device_id').notNull(),
    channelIndex: (0, pg_core_1.integer)('channel_index').notNull().default(1),
    vMv: (0, pg_core_1.integer)('v_mv').notNull(),
    iMa: (0, pg_core_1.integer)('i_ma').notNull(),
    pMw: (0, pg_core_1.integer)('p_mw').notNull(),
    eTotWh: (0, pg_core_1.integer)('e_tot_wh').notNull(),
    eIntMwh: (0, pg_core_1.integer)('e_int_mwh').notNull(),
    freqMhz: (0, pg_core_1.integer)('freq_mhz').notNull(),
    pfX1000: (0, pg_core_1.integer)('pf_x1000').notNull(),
    flags: (0, pg_core_1.integer)('flags').notNull().default(0),
    sequenceNumber: (0, pg_core_1.integer)('sequence_number').notNull().default(0),
    deviceTimestamp: (0, pg_core_1.text)('device_timestamp').notNull(),
    ingestedAt: (0, pg_core_1.text)('ingested_at').notNull(),
});
// --- telemetry_aggregates (012_energy_intelligence.sql) ---
exports.telemetryAggregates = (0, pg_core_1.pgTable)('telemetry_aggregates', {
    id: (0, pg_core_1.text)('id').primaryKey(),
    deviceId: (0, pg_core_1.text)('device_id').notNull(),
    channelIndex: (0, pg_core_1.integer)('channel_index').notNull().default(1),
    bucketType: (0, pg_core_1.text)('bucket_type').notNull(),
    bucketStart: (0, pg_core_1.text)('bucket_start').notNull(),
    bucketEnd: (0, pg_core_1.text)('bucket_end').notNull(),
    totalEnergyWh: (0, pg_core_1.real)('total_energy_wh').notNull(),
    avgPowerW: (0, pg_core_1.real)('avg_power_w').notNull(),
    peakPowerW: (0, pg_core_1.real)('peak_power_w').notNull(),
    minPowerW: (0, pg_core_1.real)('min_power_w').notNull(),
    sampleCount: (0, pg_core_1.integer)('sample_count').notNull().default(0),
    dataQuality: (0, pg_core_1.text)('data_quality').notNull().default('GOOD'),
    createdAt: (0, pg_core_1.text)('created_at').notNull(),
    updatedAt: (0, pg_core_1.text)('updated_at').notNull(),
});
// --- energy_threshold_configs (012_energy_intelligence.sql) ---
exports.energyThresholdConfigs = (0, pg_core_1.pgTable)('energy_threshold_configs', {
    id: (0, pg_core_1.text)('id').primaryKey(),
    homeId: (0, pg_core_1.text)('home_id').notNull(),
    deviceId: (0, pg_core_1.text)('device_id'),
    highPowerW: (0, pg_core_1.real)('high_power_w'),
    dailyEnergyKwh: (0, pg_core_1.real)('daily_energy_kwh'),
    monthlyEnergyKwh: (0, pg_core_1.real)('monthly_energy_kwh'),
    costPerKwh: (0, pg_core_1.real)('cost_per_kwh').default(0.15),
    currency: (0, pg_core_1.text)('currency').default('USD'),
    isEnabled: (0, pg_core_1.integer)('is_enabled').default(1),
    createdAt: (0, pg_core_1.text)('created_at').notNull(),
    updatedAt: (0, pg_core_1.text)('updated_at').notNull(),
});
// --- energy_events (012_energy_intelligence.sql) ---
exports.energyEvents = (0, pg_core_1.pgTable)('energy_events', {
    id: (0, pg_core_1.text)('id').primaryKey(),
    homeId: (0, pg_core_1.text)('home_id').notNull(),
    deviceId: (0, pg_core_1.text)('device_id'),
    eventType: (0, pg_core_1.text)('event_type').notNull(),
    severity: (0, pg_core_1.text)('severity').notNull().default('WARN'),
    valueRecorded: (0, pg_core_1.real)('value_recorded').notNull(),
    thresholdValue: (0, pg_core_1.real)('threshold_value').notNull(),
    message: (0, pg_core_1.text)('message').notNull(),
    detailsJson: (0, pg_core_1.text)('details_json'),
    createdAt: (0, pg_core_1.text)('created_at').notNull(),
});
// --- energy_automation_executions (013_smart_energy_automation.sql) ---
exports.energyAutomationExecutions = (0, pg_core_1.pgTable)('energy_automation_executions', {
    id: (0, pg_core_1.text)('id').primaryKey(),
    homeId: (0, pg_core_1.text)('home_id').notNull(),
    automationId: (0, pg_core_1.text)('automation_id'),
    scopeType: (0, pg_core_1.text)('scope_type').default('device'),
    scopeId: (0, pg_core_1.text)('scope_id'),
    triggerType: (0, pg_core_1.text)('trigger_type').notNull(),
    triggerReason: (0, pg_core_1.text)('trigger_reason').notNull(),
    telemetryContext: (0, pg_core_1.text)('telemetry_context'),
    previousState: (0, pg_core_1.text)('previous_state'),
    requestedAction: (0, pg_core_1.text)('requested_action'),
    resultingState: (0, pg_core_1.text)('resulting_state'),
    status: (0, pg_core_1.text)('status').notNull(),
    skipReason: (0, pg_core_1.text)('skip_reason'),
    errorMessage: (0, pg_core_1.text)('error_message'),
    durationMs: (0, pg_core_1.integer)('duration_ms').default(0),
    createdAt: (0, pg_core_1.text)('created_at').notNull(),
});
// --- energy_optimizations (013_smart_energy_automation.sql) ---
exports.energyOptimizations = (0, pg_core_1.pgTable)('energy_optimizations', {
    id: (0, pg_core_1.text)('id').primaryKey(),
    homeId: (0, pg_core_1.text)('home_id').notNull(),
    deviceId: (0, pg_core_1.text)('device_id'),
    category: (0, pg_core_1.text)('category').notNull(),
    severity: (0, pg_core_1.text)('severity').notNull().default('MEDIUM'),
    title: (0, pg_core_1.text)('title').notNull(),
    description: (0, pg_core_1.text)('description').notNull(),
    estimatedDailySavingsKwh: (0, pg_core_1.real)('estimated_daily_savings_kwh').notNull().default(0),
    estimatedMonthlySavingsKwh: (0, pg_core_1.real)('estimated_monthly_savings_kwh').notNull().default(0),
    estimatedMonthlyCostSavings: (0, pg_core_1.real)('estimated_monthly_cost_savings').notNull().default(0),
    currency: (0, pg_core_1.text)('currency').notNull().default('USD'),
    calculationBasis: (0, pg_core_1.text)('calculation_basis'),
    suggestedAction: (0, pg_core_1.text)('suggested_action'),
    isDismissed: (0, pg_core_1.integer)('is_dismissed').default(0),
    createdAt: (0, pg_core_1.text)('created_at').notNull(),
    updatedAt: (0, pg_core_1.text)('updated_at').notNull(),
});
// --- energy_tariffs (014_energy_cost_tariffs.sql) ---
exports.energyTariffs = (0, pg_core_1.pgTable)('energy_tariffs', {
    id: (0, pg_core_1.text)('id').primaryKey(),
    homeId: (0, pg_core_1.text)('home_id').notNull(),
    name: (0, pg_core_1.text)('name').notNull(),
    tariffType: (0, pg_core_1.text)('tariff_type').notNull(),
    currency: (0, pg_core_1.text)('currency').notNull().default('USD'),
    flatRatePerKwh: (0, pg_core_1.real)('flat_rate_per_kwh'),
    fixedDailyCharge: (0, pg_core_1.real)('fixed_daily_charge').default(0),
    effectiveFrom: (0, pg_core_1.text)('effective_from').notNull(),
    effectiveTo: (0, pg_core_1.text)('effective_to'),
    carbonIntensityGPerKwh: (0, pg_core_1.real)('carbon_intensity_g_per_kwh'),
    isActive: (0, pg_core_1.integer)('is_active').notNull().default(1),
    metadata: (0, pg_core_1.text)('metadata'),
    createdAt: (0, pg_core_1.text)('created_at').notNull(),
    updatedAt: (0, pg_core_1.text)('updated_at').notNull(),
});
// --- tariff_periods (014_energy_cost_tariffs.sql) ---
exports.tariffPeriods = (0, pg_core_1.pgTable)('tariff_periods', {
    id: (0, pg_core_1.text)('id').primaryKey(),
    tariffId: (0, pg_core_1.text)('tariff_id').notNull(),
    homeId: (0, pg_core_1.text)('home_id').notNull(),
    periodType: (0, pg_core_1.text)('period_type').notNull(),
    startTime: (0, pg_core_1.text)('start_time').notNull(),
    endTime: (0, pg_core_1.text)('end_time').notNull(),
    applicableWeekdays: (0, pg_core_1.text)('applicable_weekdays').notNull(),
    pricePerKwh: (0, pg_core_1.real)('price_per_kwh').notNull(),
    createdAt: (0, pg_core_1.text)('created_at').notNull(),
});
// --- energy_budgets (014_energy_cost_tariffs.sql) ---
exports.energyBudgets = (0, pg_core_1.pgTable)('energy_budgets', {
    id: (0, pg_core_1.text)('id').primaryKey(),
    homeId: (0, pg_core_1.text)('home_id').notNull(),
    periodType: (0, pg_core_1.text)('period_type').notNull(),
    budgetAmount: (0, pg_core_1.real)('budget_amount').notNull(),
    currency: (0, pg_core_1.text)('currency').notNull().default('USD'),
    alertThresholdPercent: (0, pg_core_1.real)('alert_threshold_percent').notNull().default(80),
    isEnabled: (0, pg_core_1.integer)('is_enabled').notNull().default(1),
    createdAt: (0, pg_core_1.text)('created_at').notNull(),
    updatedAt: (0, pg_core_1.text)('updated_at').notNull(),
});
// --- cost_optimizations (014_energy_cost_tariffs.sql) ---
exports.costOptimizations = (0, pg_core_1.pgTable)('cost_optimizations', {
    id: (0, pg_core_1.text)('id').primaryKey(),
    homeId: (0, pg_core_1.text)('home_id').notNull(),
    deviceId: (0, pg_core_1.text)('device_id'),
    category: (0, pg_core_1.text)('category').notNull(),
    priority: (0, pg_core_1.text)('priority').notNull().default('MEDIUM'),
    title: (0, pg_core_1.text)('title').notNull(),
    description: (0, pg_core_1.text)('description').notNull(),
    evidence: (0, pg_core_1.text)('evidence'),
    estimatedSavings: (0, pg_core_1.text)('estimated_savings'),
    recommendedWindow: (0, pg_core_1.text)('recommended_window'),
    isDismissed: (0, pg_core_1.integer)('is_dismissed').default(0),
    createdAt: (0, pg_core_1.text)('created_at').notNull(),
    updatedAt: (0, pg_core_1.text)('updated_at').notNull(),
});
// --- energy_forecasts (015_energy_forecasting_predictive.sql) ---
exports.energyForecasts = (0, pg_core_1.pgTable)('energy_forecasts', {
    id: (0, pg_core_1.varchar)('id', { length: 64 }).primaryKey(),
    homeId: (0, pg_core_1.varchar)('home_id', { length: 64 }).notNull(),
    scopeType: (0, pg_core_1.varchar)('scope_type', { length: 16 }).notNull().default('home'),
    scopeId: (0, pg_core_1.varchar)('scope_id', { length: 64 }).notNull(),
    horizon: (0, pg_core_1.varchar)('horizon', { length: 32 }).notNull(),
    startTime: (0, pg_core_1.timestamp)('start_time', { withTimezone: true }).notNull(),
    endTime: (0, pg_core_1.timestamp)('end_time', { withTimezone: true }).notNull(),
    predictedKwh: (0, pg_core_1.numeric)('predicted_kwh', { precision: 12, scale: 4 }).notNull().default('0'),
    predictedCost: (0, pg_core_1.numeric)('predicted_cost', { precision: 12, scale: 4 }).default('0'),
    currency: (0, pg_core_1.varchar)('currency', { length: 3 }).default('USD'),
    confidenceScore: (0, pg_core_1.numeric)('confidence_score', { precision: 5, scale: 4 }).notNull().default('0.5'),
    methodology: (0, pg_core_1.varchar)('methodology', { length: 64 }).notNull().default('HISTORICAL_HOURLY_PROFILE'),
    dataCoverage: (0, pg_core_1.varchar)('data_coverage', { length: 16 }).default('FULL'),
    isEstimate: (0, pg_core_1.boolean)('is_estimate').notNull().default(true),
    pointsJson: (0, pg_core_1.jsonb)('points_json').default([]),
    createdAt: (0, pg_core_1.timestamp)('created_at', { withTimezone: true }).notNull().defaultNow(),
});
// --- energy_anomalies (015_energy_forecasting_predictive.sql) ---
exports.energyAnomalies = (0, pg_core_1.pgTable)('energy_anomalies', {
    id: (0, pg_core_1.varchar)('id', { length: 64 }).primaryKey(),
    homeId: (0, pg_core_1.varchar)('home_id', { length: 64 }).notNull(),
    scopeType: (0, pg_core_1.varchar)('scope_type', { length: 16 }).notNull().default('device'),
    scopeId: (0, pg_core_1.varchar)('scope_id', { length: 64 }).notNull(),
    anomalyType: (0, pg_core_1.varchar)('anomaly_type', { length: 64 }).notNull(),
    severity: (0, pg_core_1.varchar)('severity', { length: 16 }).notNull().default('LOW'),
    observedValue: (0, pg_core_1.numeric)('observed_value', { precision: 12, scale: 4 }).notNull(),
    baselineValue: (0, pg_core_1.numeric)('baseline_value', { precision: 12, scale: 4 }).notNull(),
    deviationPercentage: (0, pg_core_1.numeric)('deviation_percentage', { precision: 10, scale: 2 }).notNull(),
    isConfirmed: (0, pg_core_1.boolean)('is_confirmed').notNull().default(false),
    confirmationCount: (0, pg_core_1.integer)('confirmation_count').notNull().default(1),
    evidenceJson: (0, pg_core_1.jsonb)('evidence_json').default({}),
    detectedAt: (0, pg_core_1.timestamp)('detected_at', { withTimezone: true }).notNull(),
    createdAt: (0, pg_core_1.timestamp)('created_at', { withTimezone: true }).notNull().defaultNow(),
});
// --- energy_baselines (015_energy_forecasting_predictive.sql) ---
exports.energyBaselines = (0, pg_core_1.pgTable)('energy_baselines', {
    id: (0, pg_core_1.varchar)('id', { length: 64 }).primaryKey(),
    homeId: (0, pg_core_1.varchar)('home_id', { length: 64 }).notNull(),
    scopeType: (0, pg_core_1.varchar)('scope_type', { length: 16 }).notNull().default('device'),
    scopeId: (0, pg_core_1.varchar)('scope_id', { length: 64 }).notNull(),
    typicalPowerW: (0, pg_core_1.numeric)('typical_power_w', { precision: 10, scale: 2 }).notNull().default('0'),
    typicalDailyKwh: (0, pg_core_1.numeric)('typical_daily_kwh', { precision: 10, scale: 4 }).notNull().default('0'),
    typicalOvernightWh: (0, pg_core_1.numeric)('typical_overnight_wh', { precision: 10, scale: 2 }).notNull().default('0'),
    typicalOperatingHours: (0, pg_core_1.jsonb)('typical_operating_hours').default([]),
    sampleCount: (0, pg_core_1.integer)('sample_count').notNull().default(0),
    confidence: (0, pg_core_1.numeric)('confidence', { precision: 5, scale: 4 }).notNull().default('0.5'),
    calculatedAt: (0, pg_core_1.timestamp)('calculated_at', { withTimezone: true }).notNull(),
    createdAt: (0, pg_core_1.timestamp)('created_at', { withTimezone: true }).notNull().defaultNow(),
});
// --- forecast_accuracy_records (015_energy_forecasting_predictive.sql) ---
exports.forecastAccuracyRecords = (0, pg_core_1.pgTable)('forecast_accuracy_records', {
    id: (0, pg_core_1.varchar)('id', { length: 64 }).primaryKey(),
    homeId: (0, pg_core_1.varchar)('home_id', { length: 64 }).notNull(),
    forecastId: (0, pg_core_1.varchar)('forecast_id', { length: 64 }),
    horizon: (0, pg_core_1.varchar)('horizon', { length: 32 }).notNull(),
    predictedValue: (0, pg_core_1.numeric)('predicted_value', { precision: 12, scale: 4 }).notNull(),
    actualValue: (0, pg_core_1.numeric)('actual_value', { precision: 12, scale: 4 }).notNull(),
    absoluteError: (0, pg_core_1.numeric)('absolute_error', { precision: 12, scale: 4 }).notNull(),
    percentageError: (0, pg_core_1.numeric)('percentage_error', { precision: 10, scale: 2 }).notNull(),
    calculatedAt: (0, pg_core_1.timestamp)('calculated_at', { withTimezone: true }).notNull().defaultNow(),
    createdAt: (0, pg_core_1.timestamp)('created_at', { withTimezone: true }).notNull().defaultNow(),
});
// --- energy_efficiency_scores (015_energy_forecasting_predictive.sql) ---
exports.energyEfficiencyScores = (0, pg_core_1.pgTable)('energy_efficiency_scores', {
    id: (0, pg_core_1.varchar)('id', { length: 64 }).primaryKey(),
    homeId: (0, pg_core_1.varchar)('home_id', { length: 64 }).notNull(),
    score: (0, pg_core_1.numeric)('score', { precision: 5, scale: 2 }).notNull(),
    grade: (0, pg_core_1.varchar)('grade', { length: 4 }).notNull(),
    factorsJson: (0, pg_core_1.jsonb)('factors_json').notNull().default({}),
    evidenceJson: (0, pg_core_1.jsonb)('evidence_json').default({}),
    calculatedAt: (0, pg_core_1.timestamp)('calculated_at', { withTimezone: true }).notNull(),
    createdAt: (0, pg_core_1.timestamp)('created_at', { withTimezone: true }).notNull().defaultNow(),
});
//# sourceMappingURL=energy-intelligence.js.map