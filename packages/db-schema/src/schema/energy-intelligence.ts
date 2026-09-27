/**
 * EH Home Schema — energy-intelligence
 * Source: PostgreSQL Migrations 001–029
 */
import { boolean, integer, jsonb, numeric, pgTable, real, text, timestamp, varchar } from 'drizzle-orm/pg-core';

// --- device_telemetry_measurements (012_energy_intelligence.sql) ---
export const deviceTelemetryMeasurements = pgTable('device_telemetry_measurements', {
  id: text('id').primaryKey(),
  deviceId: text('device_id').notNull(),
  channelIndex: integer('channel_index').notNull().default(1),
  vMv: integer('v_mv').notNull(),
  iMa: integer('i_ma').notNull(),
  pMw: integer('p_mw').notNull(),
  eTotWh: integer('e_tot_wh').notNull(),
  eIntMwh: integer('e_int_mwh').notNull(),
  freqMhz: integer('freq_mhz').notNull(),
  pfX1000: integer('pf_x1000').notNull(),
  flags: integer('flags').notNull().default(0),
  sequenceNumber: integer('sequence_number').notNull().default(0),
  deviceTimestamp: text('device_timestamp').notNull(),
  ingestedAt: text('ingested_at').notNull(),
});

export type DeviceTelemetryMeasurements = typeof deviceTelemetryMeasurements.$inferSelect;
export type NewDeviceTelemetryMeasurements = typeof deviceTelemetryMeasurements.$inferInsert;

// --- telemetry_aggregates (012_energy_intelligence.sql) ---
export const telemetryAggregates = pgTable('telemetry_aggregates', {
  id: text('id').primaryKey(),
  deviceId: text('device_id').notNull(),
  channelIndex: integer('channel_index').notNull().default(1),
  bucketType: text('bucket_type').notNull(),
  bucketStart: text('bucket_start').notNull(),
  bucketEnd: text('bucket_end').notNull(),
  totalEnergyWh: real('total_energy_wh').notNull(),
  avgPowerW: real('avg_power_w').notNull(),
  peakPowerW: real('peak_power_w').notNull(),
  minPowerW: real('min_power_w').notNull(),
  sampleCount: integer('sample_count').notNull().default(0),
  dataQuality: text('data_quality').notNull().default('GOOD'),
  createdAt: text('created_at').notNull(),
  updatedAt: text('updated_at').notNull(),
});

export type TelemetryAggregates = typeof telemetryAggregates.$inferSelect;
export type NewTelemetryAggregates = typeof telemetryAggregates.$inferInsert;

// --- energy_threshold_configs (012_energy_intelligence.sql) ---
export const energyThresholdConfigs = pgTable('energy_threshold_configs', {
  id: text('id').primaryKey(),
  homeId: text('home_id').notNull(),
  deviceId: text('device_id'),
  highPowerW: real('high_power_w'),
  dailyEnergyKwh: real('daily_energy_kwh'),
  monthlyEnergyKwh: real('monthly_energy_kwh'),
  costPerKwh: real('cost_per_kwh').default(0.15),
  currency: text('currency').default('USD'),
  isEnabled: integer('is_enabled').default(1),
  createdAt: text('created_at').notNull(),
  updatedAt: text('updated_at').notNull(),
});

export type EnergyThresholdConfigs = typeof energyThresholdConfigs.$inferSelect;
export type NewEnergyThresholdConfigs = typeof energyThresholdConfigs.$inferInsert;

// --- energy_events (012_energy_intelligence.sql) ---
export const energyEvents = pgTable('energy_events', {
  id: text('id').primaryKey(),
  homeId: text('home_id').notNull(),
  deviceId: text('device_id'),
  eventType: text('event_type').notNull(),
  severity: text('severity').notNull().default('WARN'),
  valueRecorded: real('value_recorded').notNull(),
  thresholdValue: real('threshold_value').notNull(),
  message: text('message').notNull(),
  detailsJson: text('details_json'),
  createdAt: text('created_at').notNull(),
});

export type EnergyEvents = typeof energyEvents.$inferSelect;
export type NewEnergyEvents = typeof energyEvents.$inferInsert;

// --- energy_automation_executions (013_smart_energy_automation.sql) ---
export const energyAutomationExecutions = pgTable('energy_automation_executions', {
  id: text('id').primaryKey(),
  homeId: text('home_id').notNull(),
  automationId: text('automation_id'),
  scopeType: text('scope_type').default('device'),
  scopeId: text('scope_id'),
  triggerType: text('trigger_type').notNull(),
  triggerReason: text('trigger_reason').notNull(),
  telemetryContext: text('telemetry_context'),
  previousState: text('previous_state'),
  requestedAction: text('requested_action'),
  resultingState: text('resulting_state'),
  status: text('status').notNull(),
  skipReason: text('skip_reason'),
  errorMessage: text('error_message'),
  durationMs: integer('duration_ms').default(0),
  createdAt: text('created_at').notNull(),
});

export type EnergyAutomationExecutions = typeof energyAutomationExecutions.$inferSelect;
export type NewEnergyAutomationExecutions = typeof energyAutomationExecutions.$inferInsert;

// --- energy_optimizations (013_smart_energy_automation.sql) ---
export const energyOptimizations = pgTable('energy_optimizations', {
  id: text('id').primaryKey(),
  homeId: text('home_id').notNull(),
  deviceId: text('device_id'),
  category: text('category').notNull(),
  severity: text('severity').notNull().default('MEDIUM'),
  title: text('title').notNull(),
  description: text('description').notNull(),
  estimatedDailySavingsKwh: real('estimated_daily_savings_kwh').notNull().default(0),
  estimatedMonthlySavingsKwh: real('estimated_monthly_savings_kwh').notNull().default(0),
  estimatedMonthlyCostSavings: real('estimated_monthly_cost_savings').notNull().default(0),
  currency: text('currency').notNull().default('USD'),
  calculationBasis: text('calculation_basis'),
  suggestedAction: text('suggested_action'),
  isDismissed: integer('is_dismissed').default(0),
  createdAt: text('created_at').notNull(),
  updatedAt: text('updated_at').notNull(),
});

export type EnergyOptimizations = typeof energyOptimizations.$inferSelect;
export type NewEnergyOptimizations = typeof energyOptimizations.$inferInsert;

// --- energy_tariffs (014_energy_cost_tariffs.sql) ---
export const energyTariffs = pgTable('energy_tariffs', {
  id: text('id').primaryKey(),
  homeId: text('home_id').notNull(),
  name: text('name').notNull(),
  tariffType: text('tariff_type').notNull(),
  currency: text('currency').notNull().default('USD'),
  flatRatePerKwh: real('flat_rate_per_kwh'),
  fixedDailyCharge: real('fixed_daily_charge').default(0),
  effectiveFrom: text('effective_from').notNull(),
  effectiveTo: text('effective_to'),
  carbonIntensityGPerKwh: real('carbon_intensity_g_per_kwh'),
  isActive: integer('is_active').notNull().default(1),
  metadata: text('metadata'),
  createdAt: text('created_at').notNull(),
  updatedAt: text('updated_at').notNull(),
});

export type EnergyTariffs = typeof energyTariffs.$inferSelect;
export type NewEnergyTariffs = typeof energyTariffs.$inferInsert;

// --- tariff_periods (014_energy_cost_tariffs.sql) ---
export const tariffPeriods = pgTable('tariff_periods', {
  id: text('id').primaryKey(),
  tariffId: text('tariff_id').notNull(),
  homeId: text('home_id').notNull(),
  periodType: text('period_type').notNull(),
  startTime: text('start_time').notNull(),
  endTime: text('end_time').notNull(),
  applicableWeekdays: text('applicable_weekdays').notNull(),
  pricePerKwh: real('price_per_kwh').notNull(),
  createdAt: text('created_at').notNull(),
});

export type TariffPeriods = typeof tariffPeriods.$inferSelect;
export type NewTariffPeriods = typeof tariffPeriods.$inferInsert;

// --- energy_budgets (014_energy_cost_tariffs.sql) ---
export const energyBudgets = pgTable('energy_budgets', {
  id: text('id').primaryKey(),
  homeId: text('home_id').notNull(),
  periodType: text('period_type').notNull(),
  budgetAmount: real('budget_amount').notNull(),
  currency: text('currency').notNull().default('USD'),
  alertThresholdPercent: real('alert_threshold_percent').notNull().default(80),
  isEnabled: integer('is_enabled').notNull().default(1),
  createdAt: text('created_at').notNull(),
  updatedAt: text('updated_at').notNull(),
});

export type EnergyBudgets = typeof energyBudgets.$inferSelect;
export type NewEnergyBudgets = typeof energyBudgets.$inferInsert;

// --- cost_optimizations (014_energy_cost_tariffs.sql) ---
export const costOptimizations = pgTable('cost_optimizations', {
  id: text('id').primaryKey(),
  homeId: text('home_id').notNull(),
  deviceId: text('device_id'),
  category: text('category').notNull(),
  priority: text('priority').notNull().default('MEDIUM'),
  title: text('title').notNull(),
  description: text('description').notNull(),
  evidence: text('evidence'),
  estimatedSavings: text('estimated_savings'),
  recommendedWindow: text('recommended_window'),
  isDismissed: integer('is_dismissed').default(0),
  createdAt: text('created_at').notNull(),
  updatedAt: text('updated_at').notNull(),
});

export type CostOptimizations = typeof costOptimizations.$inferSelect;
export type NewCostOptimizations = typeof costOptimizations.$inferInsert;

// --- energy_forecasts (015_energy_forecasting_predictive.sql) ---
export const energyForecasts = pgTable('energy_forecasts', {
  id: varchar('id', { length: 64 }).primaryKey(),
  homeId: varchar('home_id', { length: 64 }).notNull(),
  scopeType: varchar('scope_type', { length: 16 }).notNull().default('home'),
  scopeId: varchar('scope_id', { length: 64 }).notNull(),
  horizon: varchar('horizon', { length: 32 }).notNull(),
  startTime: timestamp('start_time', { withTimezone: true }).notNull(),
  endTime: timestamp('end_time', { withTimezone: true }).notNull(),
  predictedKwh: numeric('predicted_kwh', { precision: 12, scale: 4 }).notNull().default('0'),
  predictedCost: numeric('predicted_cost', { precision: 12, scale: 4 }).default('0'),
  currency: varchar('currency', { length: 3 }).default('USD'),
  confidenceScore: numeric('confidence_score', { precision: 5, scale: 4 }).notNull().default('0.5'),
  methodology: varchar('methodology', { length: 64 }).notNull().default('HISTORICAL_HOURLY_PROFILE'),
  dataCoverage: varchar('data_coverage', { length: 16 }).default('FULL'),
  isEstimate: boolean('is_estimate').notNull().default(true),
  pointsJson: jsonb('points_json').default([]),
  createdAt: timestamp('created_at', { withTimezone: true }).notNull().defaultNow(),
});

export type EnergyForecasts = typeof energyForecasts.$inferSelect;
export type NewEnergyForecasts = typeof energyForecasts.$inferInsert;

// --- energy_anomalies (015_energy_forecasting_predictive.sql) ---
export const energyAnomalies = pgTable('energy_anomalies', {
  id: varchar('id', { length: 64 }).primaryKey(),
  homeId: varchar('home_id', { length: 64 }).notNull(),
  scopeType: varchar('scope_type', { length: 16 }).notNull().default('device'),
  scopeId: varchar('scope_id', { length: 64 }).notNull(),
  anomalyType: varchar('anomaly_type', { length: 64 }).notNull(),
  severity: varchar('severity', { length: 16 }).notNull().default('LOW'),
  observedValue: numeric('observed_value', { precision: 12, scale: 4 }).notNull(),
  baselineValue: numeric('baseline_value', { precision: 12, scale: 4 }).notNull(),
  deviationPercentage: numeric('deviation_percentage', { precision: 10, scale: 2 }).notNull(),
  isConfirmed: boolean('is_confirmed').notNull().default(false),
  confirmationCount: integer('confirmation_count').notNull().default(1),
  evidenceJson: jsonb('evidence_json').default({}),
  detectedAt: timestamp('detected_at', { withTimezone: true }).notNull(),
  createdAt: timestamp('created_at', { withTimezone: true }).notNull().defaultNow(),
});

export type EnergyAnomalies = typeof energyAnomalies.$inferSelect;
export type NewEnergyAnomalies = typeof energyAnomalies.$inferInsert;

// --- energy_baselines (015_energy_forecasting_predictive.sql) ---
export const energyBaselines = pgTable('energy_baselines', {
  id: varchar('id', { length: 64 }).primaryKey(),
  homeId: varchar('home_id', { length: 64 }).notNull(),
  scopeType: varchar('scope_type', { length: 16 }).notNull().default('device'),
  scopeId: varchar('scope_id', { length: 64 }).notNull(),
  typicalPowerW: numeric('typical_power_w', { precision: 10, scale: 2 }).notNull().default('0'),
  typicalDailyKwh: numeric('typical_daily_kwh', { precision: 10, scale: 4 }).notNull().default('0'),
  typicalOvernightWh: numeric('typical_overnight_wh', { precision: 10, scale: 2 }).notNull().default('0'),
  typicalOperatingHours: jsonb('typical_operating_hours').default([]),
  sampleCount: integer('sample_count').notNull().default(0),
  confidence: numeric('confidence', { precision: 5, scale: 4 }).notNull().default('0.5'),
  calculatedAt: timestamp('calculated_at', { withTimezone: true }).notNull(),
  createdAt: timestamp('created_at', { withTimezone: true }).notNull().defaultNow(),
});

export type EnergyBaselines = typeof energyBaselines.$inferSelect;
export type NewEnergyBaselines = typeof energyBaselines.$inferInsert;

// --- forecast_accuracy_records (015_energy_forecasting_predictive.sql) ---
export const forecastAccuracyRecords = pgTable('forecast_accuracy_records', {
  id: varchar('id', { length: 64 }).primaryKey(),
  homeId: varchar('home_id', { length: 64 }).notNull(),
  forecastId: varchar('forecast_id', { length: 64 }),
  horizon: varchar('horizon', { length: 32 }).notNull(),
  predictedValue: numeric('predicted_value', { precision: 12, scale: 4 }).notNull(),
  actualValue: numeric('actual_value', { precision: 12, scale: 4 }).notNull(),
  absoluteError: numeric('absolute_error', { precision: 12, scale: 4 }).notNull(),
  percentageError: numeric('percentage_error', { precision: 10, scale: 2 }).notNull(),
  calculatedAt: timestamp('calculated_at', { withTimezone: true }).notNull().defaultNow(),
  createdAt: timestamp('created_at', { withTimezone: true }).notNull().defaultNow(),
});

export type ForecastAccuracyRecords = typeof forecastAccuracyRecords.$inferSelect;
export type NewForecastAccuracyRecords = typeof forecastAccuracyRecords.$inferInsert;

// --- energy_efficiency_scores (015_energy_forecasting_predictive.sql) ---
export const energyEfficiencyScores = pgTable('energy_efficiency_scores', {
  id: varchar('id', { length: 64 }).primaryKey(),
  homeId: varchar('home_id', { length: 64 }).notNull(),
  score: numeric('score', { precision: 5, scale: 2 }).notNull(),
  grade: varchar('grade', { length: 4 }).notNull(),
  factorsJson: jsonb('factors_json').notNull().default({}),
  evidenceJson: jsonb('evidence_json').default({}),
  calculatedAt: timestamp('calculated_at', { withTimezone: true }).notNull(),
  createdAt: timestamp('created_at', { withTimezone: true }).notNull().defaultNow(),
});

export type EnergyEfficiencyScores = typeof energyEfficiencyScores.$inferSelect;
export type NewEnergyEfficiencyScores = typeof energyEfficiencyScores.$inferInsert;
