/**
 * EH Home Canonical Operational & Observability Contracts (Phase 31)
 */

export type ExecutionPath =
  | 'LOCAL_EDGE'
  | 'CLOUD'
  | 'DEVICE'
  | 'HYBRID'
  | 'UNKNOWN';

export type OperationalSeverity =
  | 'INFO'
  | 'NOTICE'
  | 'WARNING'
  | 'ERROR'
  | 'CRITICAL';

export type AuthorizationResult =
  | 'AUTHORIZED'
  | 'DENIED'
  | 'BYPASSED_INTERNAL'
  | 'UNKNOWN';

export type OperationalOutcome =
  | 'SUCCESS'
  | 'FAILURE'
  | 'PARTIAL'
  | 'TIMEOUT'
  | 'DEFERRED'
  | 'UNKNOWN';

export type SystemHealthStatus =
  | 'HEALTHY'
  | 'DEGRADED'
  | 'UNAVAILABLE'
  | 'NOT_CHECKED'
  | 'UNKNOWN';

export type OperationalSubsystem =
  | 'DEVICE'
  | 'CONNECTIVITY'
  | 'RELIABILITY'
  | 'OTA'
  | 'ENERGY'
  | 'AUTOMATION'
  | 'MATTER'
  | 'SECURITY'
  | 'ACCOUNT'
  | 'EDGE'
  | 'SYSTEM';

export interface OperationalEvent {
  schemaVersion: 1;
  eventId: string;
  correlationId: string;
  causationId?: string | null;
  timestamp: string;
  homeId?: string | null;
  userId?: string | null;
  deviceId?: string | null;
  roomId?: string | null;
  subsystem: OperationalSubsystem;
  operation: string;
  action: string;
  source: string;
  executionPath: ExecutionPath;
  severity: OperationalSeverity;
  authorizationResult: AuthorizationResult;
  outcome: OperationalOutcome;
  failureCode?: string | null;
  durationMs?: number | null;
  metadata?: Record<string, unknown>;
  redactionMarkers?: string[];
  traceLifecycle?: 'START' | 'IN_PROGRESS' | 'COMPLETE' | 'FAILED' | null;
}

export interface SecurityAuditRecord {
  schemaVersion: 1;
  auditId: string;
  sequenceNumber: number;
  recordHash: string;
  prevRecordHash: string;
  timestamp: string;
  actorUserId?: string | null;
  homeId?: string | null;
  deviceId?: string | null;
  action: string;
  resourceType: string;
  resourceId?: string | null;
  outcome: 'SUCCESS' | 'DENIED' | 'FAILURE' | 'ERROR';
  ipAddress?: string | null;
  correlationId?: string | null;
  canonicalPayload?: Record<string, unknown>;
  metadata?: Record<string, unknown>;
}

export interface OperationTraceSpan {
  spanId: string;
  parentSpanId?: string | null;
  subsystem: string;
  operation: string;
  executionPath: ExecutionPath;
  outcome: OperationalOutcome;
  durationMs?: number | null;
  timestamp: string;
  details?: Record<string, unknown>;
}

export interface OperationTrace {
  schemaVersion: 1;
  traceId: string;
  correlationId: string;
  rootOperation: string;
  status: 'IN_PROGRESS' | 'COMPLETED' | 'FAILED' | 'PARTIAL';
  startTime: string;
  endTime?: string | null;
  totalDurationMs?: number | null;
  spans: OperationTraceSpan[];
  metadata?: Record<string, unknown>;
}

export interface SubsystemHealthDetail {
  status: SystemHealthStatus;
  latencyMs?: number | null;
  errorRate?: number | null;
  lastCheckedAt: string;
  details?: Record<string, unknown>;
}

export interface SystemHealthSnapshot {
  schemaVersion: 1;
  status: 'HEALTHY' | 'DEGRADED' | 'UNAVAILABLE' | 'UNKNOWN';
  timestamp: string;
  subsystems: Record<string, SubsystemHealthDetail>;
  metadata?: Record<string, unknown>;
}
