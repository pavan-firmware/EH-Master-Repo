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
