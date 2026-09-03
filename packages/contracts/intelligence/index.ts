/**
 * EH Home — Phase 24 Intelligence & Unified Decision Engine Contracts
 */

export type DecisionPriority =
  | 'SAFETY'
  | 'MANUAL_USER_ACTION'
  | 'EXPLICIT_HOME_MODE'
  | 'SCHEDULED_AUTOMATION'
  | 'ENERGY_COST_OPTIMIZATION'
  | 'PREDICTIVE_OPTIMIZATION'
  | 'CONVENIENCE_RECOMMENDATION';

export const DECISION_PRIORITY_RANKS: Record<DecisionPriority, number> = {
  SAFETY: 1,
  MANUAL_USER_ACTION: 2,
  EXPLICIT_HOME_MODE: 3,
  SCHEDULED_AUTOMATION: 4,
  ENERGY_COST_OPTIMIZATION: 5,
  PREDICTIVE_OPTIMIZATION: 6,
  CONVENIENCE_RECOMMENDATION: 7,
};

export type ConfidenceLevel = 'LOW' | 'MEDIUM' | 'HIGH';
export type RiskLevel = 'LOW' | 'MEDIUM' | 'HIGH' | 'CRITICAL';
export type DecisionStatus =
  | 'GENERATED'
  | 'VIEWED'
  | 'ACCEPTED'
  | 'REJECTED'
  | 'AUTO_EXECUTED'
  | 'EXECUTED'
  | 'FAILED'
  | 'EXPIRED'
  | 'SKIPPED';

export type RecommendationType =
  | 'TURN_OFF_UNUSED_DEVICE'
  | 'SHIFT_LOAD_TO_CHEAPER_PERIOD'
  | 'REDUCE_PEAK_LOAD'
  | 'INVESTIGATE_ANOMALY'
  | 'CHANGE_HOME_MODE'
  | 'OPTIMIZE_AUTOMATION'
  | 'REDUCE_STANDBY'
  | 'REVIEW_SCHEDULE'
  | 'REVIEW_TARIFF';

export interface HomeIntelligenceSnapshot {
  homeId: string;
  timestamp: string;
  homeContext: string;
  presenceState: string;
  isOccupied: boolean;
  deviceCount: number;
  activeDevicesCount: number;
  totalPowerW: number;
  tariffPeriod?: string;
  tariffPrice?: number;
  forecastPredictedKwh?: number;
  activeAnomalyCount: number;
  activeAutomationCount: number;
  activeScheduleCount: number;
  [key: string]: any;
}

export interface IntelligenceDecision {
  id: string;
  homeId: string;
  decisionType: string;
  priority: DecisionPriority;
  priorityRank?: number;
  confidence: ConfidenceLevel;
  confidenceScore?: number;
  risk: RiskLevel;
  evidence: Record<string, any>;
  proposedAction?: Record<string, any>;
  expectedEffect?: string;
  isAutoExecutable?: boolean;
  safetyResult?: {
    isSafe: boolean;
    riskLevel: string;
    reason?: string;
  };
  status: DecisionStatus;
  createdAt: string;
  expiresAt?: string;
  [key: string]: any;
}

export interface IntelligenceRecommendation {
  id: string;
  homeId: string;
  recommendationType: RecommendationType;
  priority: DecisionPriority;
  priorityRank?: number;
  confidence: ConfidenceLevel;
  risk: RiskLevel;
  title: string;
  description: string;
  evidence: Record<string, any>;
  proposedAction?: Record<string, any>;
  expectedBenefit?: string;
  isAutoExecutable?: boolean;
  status: DecisionStatus;
  createdAt: string;
  expiresAt?: string;
  [key: string]: any;
}

export interface DecisionOutcome {
  id: string;
  decisionId: string;
  homeId: string;
  status: DecisionStatus;
  executedAt: string;
  previousState?: Record<string, any>;
  newState?: Record<string, any>;
  expectedBenefit?: string;
  actualBenefit?: string;
  feedback?: string;
  failureReason?: string;
  [key: string]: any;
}
