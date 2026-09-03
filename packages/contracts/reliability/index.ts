/**
 * Phase 25 Reliability Contract TypeScript Interfaces
 * EH Home — Proactive Device Reliability + Self-Healing Home
 */

export type DeviceHealthState = 'HEALTHY' | 'DEGRADED' | 'UNSTABLE' | 'UNAVAILABLE' | 'UNKNOWN';

export type ReliabilityIncidentType =
  | 'DEVICE_OFFLINE'
  | 'TELEMETRY_STALE'
  | 'COMMAND_FAILURE'
  | 'COMMAND_LATENCY'
  | 'MQTT_INSTABILITY'
  | 'OTA_FAILURE'
  | 'REPEATED_RECONNECT'
  | 'RELIABILITY_DEGRADATION';

export type ReliabilitySeverity = 'LOW' | 'MEDIUM' | 'HIGH' | 'CRITICAL';

export type ReliabilityDiagnosisType =
  | 'NETWORK_INSTABILITY'
  | 'DEVICE_UNREACHABLE'
  | 'TELEMETRY_PIPELINE_ISSUE'
  | 'COMMAND_EXECUTION_ISSUE'
  | 'FIRMWARE_ISSUE'
  | 'OTA_ISSUE'
  | 'UNKNOWN';

export type RecoveryActionType =
  | 'RETRY_COMMAND'
  | 'REFRESH_STATE'
  | 'REQUEST_TELEMETRY_REFRESH'
  | 'RETRY_FAILED_OPERATION'
  | 'RE_EVALUATE_OTA_ELIGIBILITY'
  | 'MARK_DEGRADED'
  | 'CREATE_MAINTENANCE_RECOMMENDATION';

export type RecoveryResultStatus = 'RECOVERED' | 'PARTIALLY_RECOVERED' | 'FAILED';

export type MaintenanceRecommendationType =
  | 'FIRMWARE_UPDATE_REQUIRED'
  | 'DEVICE_REPLACEMENT_ADVISED'
  | 'NETWORK_CHECK_REQUIRED'
  | 'POWER_CYCLE_ADVISED'
  | 'PROFESSIONAL_SERVICE_REQUIRED'
  | 'MONITOR_CLOSELY'
  | 'OTHER';

export interface DeviceReliabilitySnapshot {
  id: string;
  homeId: string;
  deviceId: string;
  healthState: DeviceHealthState;
  healthScore: number;          // 0–100
  connectivityScore?: number | null;
  telemetryScore?: number | null;
  commandScore?: number | null;
  uptimeScore?: number | null;
  factors?: Record<string, any> | null;
  activeIncidents: number;
  snapshottedAt: string;
  createdAt: string;
}

export interface ReliabilityIncident {
  id: string;
  homeId: string;
  deviceId: string;
  incidentType: ReliabilityIncidentType;
  severity: ReliabilitySeverity;
  status: 'OPEN' | 'INVESTIGATING' | 'RESOLVED' | 'AUTO_RESOLVED';
  title: string;
  description?: string | null;
  evidence?: Record<string, any> | null;
  signalCount: number;
  firstObservedAt: string;
  lastObservedAt: string;
  resolvedAt?: string | null;
  createdAt: string;
}

export interface ReliabilityDiagnosis {
  id: string;
  incidentId: string;
  homeId: string;
  deviceId: string;
  diagnosisType: ReliabilityDiagnosisType;
  confidence: number;           // 0.0–1.0
  rootCause: string;
  evidence?: Record<string, any> | null;
  recommendedActions?: string[] | null;
  createdAt: string;
}

export interface RecoveryAttempt {
  id: string;
  incidentId: string;
  homeId: string;
  deviceId: string;
  actionType: RecoveryActionType;
  status: 'PENDING' | 'EXECUTING' | 'VERIFYING' | RecoveryResultStatus;
  commandAccepted: boolean;
  preActionState?: Record<string, any> | null;
  postActionState?: Record<string, any> | null;
  verificationEvidence?: Record<string, any> | null;
  failureReason?: string | null;
  initiatedAt: string;
  commandAcceptedAt?: string | null;
  verificationStartedAt?: string | null;
  completedAt?: string | null;
}

export interface MaintenanceRecommendation {
  id: string;
  homeId: string;
  deviceId: string;
  incidentId?: string | null;
  recommendationType: MaintenanceRecommendationType;
  priority: ReliabilitySeverity;
  title: string;
  description: string;
  actionSteps?: string[] | null;
  status: 'PENDING' | 'APPROVED' | 'REJECTED' | 'IN_PROGRESS' | 'COMPLETED';
  approvedBy?: string | null;
  approvedAt?: string | null;
  completedAt?: string | null;
  createdAt: string;
}

export interface FleetHealthSummary {
  homeId: string;
  totalDevices: number;
  stateDistribution: Record<DeviceHealthState, number>;
  fleetHealthScore: number;
  activeIncidents: number;
  criticalIncidents: number;
  pendingRecoveries: number;
  generatedAt: string;
}
