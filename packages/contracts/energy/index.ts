/**
 * EH Home Canonical Energy & Telemetry Contracts (Phase 19)
 */

export interface EnergyMeasurement {
  id: string;
  deviceId: string;
  channelIndex: number;
  v_mv: number;
  i_ma: number;
  p_mw: number;
  e_tot_wh: number;
  e_int_mwh: number;
  freq_mhz: number;
  pf_x1000: number;
  flags: number;
  sequenceNumber: number;
  deviceTimestamp: string;
  ingestedAt: string;
}

export type BucketType = 'MINUTE' | 'HOUR' | 'DAY';
export type DataQuality = 'GOOD' | 'PARTIAL' | 'INTERPOLATED' | 'DEGRADED';

export interface EnergyAggregate {
  id: string;
  deviceId: string;
  channelIndex: number;
  bucketType: BucketType;
  bucketStart: string;
  bucketEnd: string;
  totalEnergyWh: number;
  avgPowerW: number;
  peakPowerW: number;
  minPowerW: number;
  sampleCount: number;
  dataQuality: DataQuality;
  createdAt: string;
  updatedAt: string;
}

export type EnergyPeriod = 'today' | 'week' | 'month' | 'year' | 'custom';
export type EnergyEntityType = 'device' | 'room' | 'home';

export interface EnergyUsageSummary {
  schemaVersion: 1;
  entityType: EnergyEntityType;
  entityId: string;
  period: EnergyPeriod;
  currentPowerW: number;
  totalEnergyKwh: number;
  peakPowerW: number;
  avgPowerW: number;
  minPowerW?: number;
  costEstimate?: number;
  currency?: string;
  dataQuality: DataQuality;
  sampleCount: number;
  lastUpdated: string;
}

export interface EnergyTrendPoint {
  timestamp: string;
  energyKwh: number;
  avgPowerW: number;
  peakPowerW: number;
  sampleCount: number;
}

export interface EnergyPeriodComparison {
  currentPeriodEnergyKwh: number;
  previousPeriodEnergyKwh: number;
  deltaEnergyKwh: number;
  percentageChange: number; // e.g. +12.5 or -8.2
  trendDirection: 'UP' | 'DOWN' | 'STABLE';
}

export interface EnergyThresholdConfig {
  id: string;
  homeId: string;
  deviceId?: string | null;
  highPowerW?: number | null;
  dailyEnergyKwh?: number | null;
  monthlyEnergyKwh?: number | null;
  costPerKwh?: number;
  currency?: string;
  isEnabled: boolean;
  createdAt: string;
  updatedAt: string;
}

export type EnergyEventType =
  | 'HIGH_POWER_EXCEEDED'
  | 'DAILY_ENERGY_EXCEEDED'
  | 'REVERSE_POWER_FLOW'
  | 'COUNTER_RESET';

export type EnergyEventSeverity = 'INFO' | 'WARN' | 'CRITICAL';

export interface EnergyAnomalyEvent {
  id: string;
  homeId: string;
  deviceId?: string | null;
  eventType: EnergyEventType;
  severity: EnergyEventSeverity;
  valueRecorded: number;
  thresholdValue: number;
  message: string;
  details?: Record<string, any>;
  createdAt: string;
}

export interface TopEnergyConsumer {
  id: string; // deviceId or roomId
  name: string;
  type: 'device' | 'room';
  roomName?: string;
  energyKwh: number;
  currentPowerW: number;
  percentageOfTotal: number;
}

// ---------------------------------------------------------------------------
// Phase 20: Smart Energy Automation & Optimization Contracts
// ---------------------------------------------------------------------------

export type EnergyConditionMetric =
  | 'instantaneous_power'
  | 'cumulative_energy'
  | 'daily_energy'
  | 'monthly_energy'
  | 'sustained_power';

export type EnergyComparisonOperator = 'GT' | 'GTE' | 'LT' | 'LTE' | 'EQ';
export type EnergyScopeType = 'device' | 'room' | 'home';

export interface EnergyTimeWindow {
  startTime?: string; // 'HH:mm'
  endTime?: string;   // 'HH:mm'
  daysOfWeek?: number[]; // [1..7]
}

export interface EnergyCondition {
  metric: EnergyConditionMetric;
  operator: EnergyComparisonOperator;
  threshold: number;
  durationSeconds?: number;
  timeWindow?: EnergyTimeWindow;
}

export interface EnergyHysteresisConfig {
  recoveryThreshold?: number;
  cooldownSeconds?: number;
  minimumDurationSeconds?: number;
}

export interface EnergyAction {
  actionType: 'device_command' | 'scene_execution';
  deviceId?: string;
  channelIndex?: number;
  command?: string;
  params?: Record<string, any>;
  sceneId?: string;
}

export interface EnergyAutomationRule {
  schemaVersion: 1;
  id: string;
  homeId: string;
  name: string;
  description?: string | null;
  isEnabled: boolean;
  scopeType?: EnergyScopeType;
  scopeId?: string | null;
  triggerCondition: EnergyCondition;
  hysteresis?: EnergyHysteresisConfig;
  actions: EnergyAction[];
  cooldownSeconds?: number;
}

export type EnergyExecutionStatus = 'succeeded' | 'failed' | 'partial' | 'skipped';
export type EnergySkipReason =
  | 'in_cooldown'
  | 'hysteresis_active'
  | 'conditions_not_met'
  | 'loop_detected'
  | 'disabled'
  | 'missing_telemetry'
  | 'stale_telemetry';

export interface EnergyAutomationExecution {
  id: string;
  homeId: string;
  automationId: string;
  scopeType?: EnergyScopeType;
  scopeId?: string | null;
  triggerType: string;
  triggerReason: string;
  telemetryContext?: Record<string, any>;
  previousState?: Record<string, any>;
  requestedAction?: Record<string, any>;
  resultingState?: Record<string, any>;
  status: EnergyExecutionStatus;
  skipReason?: EnergySkipReason | null;
  errorMessage?: string | null;
  durationMs: number;
  createdAt: string;
}

export type OptimizationCategory =
  | 'VAMPIRE_STANDBY_POWER'
  | 'OVERNIGHT_CONSUMPTION'
  | 'HIGH_PEAK_DEMAND'
  | 'THRESHOLD_FREQUENT_EXCEED';

export type OptimizationSeverity = 'LOW' | 'MEDIUM' | 'HIGH';

export interface EstimatedSavings {
  dailyKwh: number;
  monthlyKwh: number;
  annualKwh: number;
  monthlyCost: number;
  annualCost: number;
  currency: string;
  tariffPerKwh: number;
  isEstimate: true;
}

export interface EnergyOptimizationRecommendation {
  id: string;
  homeId: string;
  deviceId?: string | null;
  deviceName?: string | null;
  roomName?: string | null;
  category: OptimizationCategory;
  severity: OptimizationSeverity;
  title: string;
  description: string;
  estimatedSavings: EstimatedSavings;
  calculationBasis: {
    observedAvgPowerW?: number;
    baselineStandbyW?: number;
    activeHoursPerDay?: number;
    sampleCount?: number;
    confidenceScore?: number;
  };
  suggestedAction: {
    actionType: 'create_automation' | 'schedule_off' | 'power_cap';
    automationTemplate?: Partial<EnergyAutomationRule>;
  };
  isDismissed: boolean;
  createdAt: string;
  updatedAt: string;
}

// --- PHASE 21 TARIFFS & COST INTELLIGENCE ---

export type TariffType = 'FLAT' | 'TIME_OF_USE' | 'DYNAMIC';

export type TariffPeriodType = 'OFF_PEAK' | 'STANDARD' | 'PEAK' | 'CRITICAL_PEAK';

export interface TariffPeriod {
  id: string;
  periodType: TariffPeriodType;
  startTime: string; // HH:MM
  endTime: string; // HH:MM
  applicableWeekdays: number[]; // 1 = Monday ... 7 = Sunday
  pricePerKwh: number;
}

export interface ElectricityTariff {
  schemaVersion: 1;
  id: string;
  homeId: string;
  name: string;
  tariffType: TariffType;
  currency: string;
  flatRatePerKwh?: number | null;
  fixedDailyCharge?: number | null;
  effectiveFrom: string;
  effectiveTo?: string | null;
  carbonIntensityGPerKwh?: number | null;
  isActive: boolean;
  periods?: TariffPeriod[];
  metadata?: Record<string, any> | null;
}

export type BudgetPeriodType = 'daily' | 'weekly' | 'monthly';

export interface EnergyBudget {
  schemaVersion: 1;
  id: string;
  homeId: string;
  periodType: BudgetPeriodType;
  budgetAmount: number;
  currency: string;
  alertThresholdPercent: number;
  isEnabled: boolean;
  createdAt?: string;
  updatedAt?: string;
}

export interface CostForecast {
  homeId: string;
  period: BudgetPeriodType;
  currency: string;
  actualCostToDate: number;
  estimatedRemainingCost: number;
  projectedTotalCost: number;
  actualKwhToDate: number;
  projectedTotalKwh: number;
  confidenceScore: number;
  isEstimate: true;
  generatedAt: string;
}

export interface PeakDemandAnalysis {
  homeId: string;
  currentPeakLoadW: number;
  highestHistoricalPeakW: number;
  dailyPeakW: number;
  monthlyPeakW: number;
  peakHourOfDay: number;
  repeatedHighLoadWindows: Array<{
    startTime: string;
    endTime: string;
    avgPeakW: number;
  }>;
}

export interface CarbonFootprint {
  entityId: string;
  entityType: 'home' | 'room' | 'device';
  carbonIntensityGPerKwh: number;
  totalGramsCO2: number;
  totalKgCO2: number;
  source: 'configured_tariff' | 'default_regional_estimate';
  isEstimate: true;
}

export interface CheapestPeriod {
  startTime: string; // ISO
  endTime: string; // ISO
  durationHours: number;
  pricePerKwh: number;
  currency: string;
  periodType: TariffPeriodType;
  potentialSavingsPercent: number;
}

// --- PHASE 22 FORECASTING & PREDICTIVE INTELLIGENCE ---

export type ForecastHorizon = 'next_hour' | 'next_24_hours' | 'next_7_days' | 'current_month';

export interface ForecastPoint {
  timestamp: string;
  predictedPowerW: number;
  predictedEnergyWh: number;
  predictedCost?: number;
  confidenceScore: number;
}

export interface EnergyForecast {
  id?: string;
  homeId: string;
  scopeType: EnergyScopeType;
  scopeId: string;
  horizon: ForecastHorizon;
  startTime: string;
  endTime: string;
  predictedKwh: number;
  predictedCost?: number;
  currency?: string;
  confidenceScore: number;
  methodology: string;
  dataCoverage: 'FULL' | 'PARTIAL' | 'INSUFFICIENT';
  isEstimate: true;
  generatedAt: string;
  points?: ForecastPoint[];
}

export interface EnergyBaseline {
  id?: string;
  homeId: string;
  scopeType: EnergyScopeType;
  scopeId: string;
  typicalPowerW: number;
  typicalDailyEnergyKwh: number;
  typicalOvernightWh: number;
  typicalOperatingHours?: number[];
  sampleCount: number;
  confidence: number;
  calculatedAt: string;
}

export type AnomalyType =
  | 'UNUSUAL_POWER_SPIKE'
  | 'UNEXPECTED_OVERNIGHT_LOAD'
  | 'UNEXPECTED_OPERATING_DURATION'
  | 'ABNORMAL_ROOM_LOAD'
  | 'ABNORMAL_TOTAL_CONSUMPTION';

export type AnomalySeverity = 'INFO' | 'LOW' | 'MEDIUM' | 'HIGH' | 'CRITICAL';

export interface EnergyAnomaly {
  id: string;
  homeId: string;
  scopeType: EnergyScopeType;
  scopeId: string;
  anomalyType: AnomalyType;
  severity: AnomalySeverity;
  observedValue: number;
  baselineValue: number;
  deviationPercentage: number;
  isConfirmed: boolean;
  confirmationCount?: number;
  evidence?: Record<string, any>;
  detectedAt: string;
}

export interface EnergyEfficiencyScore {
  id?: string;
  homeId: string;
  score: number;
  grade: 'A+' | 'A' | 'B' | 'C' | 'D' | 'F';
  factors: {
    standbyLossScore: number;
    peakDemandScore: number;
    thresholdViolationScore: number;
    tariffEfficiencyScore: number;
    trendScore: number;
  };
  evidence?: Record<string, any>;
  calculatedAt: string;
}

export interface PredictiveOptimizationRecommendation {
  id: string;
  homeId: string;
  deviceId?: string | null;
  category: 'LOAD_SHIFTING' | 'PEAK_AVOIDANCE' | 'ANOMALY_INSPECTION' | 'BUDGET_PROTECTION' | 'OVERNIGHT_OPTIMIZATION';
  priority: 'LOW' | 'MEDIUM' | 'HIGH' | 'CRITICAL';
  title: string;
  description: string;
  reason: string;
  evidence?: Record<string, any>;
  estimatedKwhSavings?: number;
  estimatedCostSavings?: number;
  currency?: string;
  confidence: number;
  isEstimate: true;
  generatedAt: string;
  isDismissed: boolean;
}

export interface ForecastAccuracy {
  homeId: string;
  horizon: string;
  sampleCount: number;
  mae: number;
  mape: number;
  evaluatedAt: string;
}
