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
