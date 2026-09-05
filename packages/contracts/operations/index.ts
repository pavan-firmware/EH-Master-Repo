/**
 * EH Home Canonical Operational & Observability Contracts (Phase 31 & Phase 34)
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

// ==============================================================================
// Phase 34 — Production Deployment & Operational Readiness
// ==============================================================================

export type ServiceReadinessStatus =
  | 'READY'
  | 'NOT_READY'
  | 'DEGRADED'
  | 'STARTING'
  | 'SHUTTING_DOWN';

export interface ServiceReadiness {
  schemaVersion: 1;
  status: ServiceReadinessStatus;
  service: string;
  version: string;
  schema_version?: number | null;
  migration_version?: number | string | null;
  timestamp: string;
  uptimeSeconds?: number;
  checks: {
    database: 'PASS' | 'FAIL' | 'CONNECTED' | 'DISCONNECTED' | 'DEGRADED';
    redis?: 'PASS' | 'FAIL' | 'CONNECTED' | 'DISCONNECTED' | 'STANDBY' | 'DISABLED' | null;
    mqtt?: 'PASS' | 'FAIL' | 'CONNECTED' | 'DISCONNECTED' | 'STANDBY' | 'DISABLED' | null;
    workers?: 'PASS' | 'FAIL' | 'RUNNING' | 'INACTIVE' | 'DEGRADED' | null;
    [key: string]: unknown;
  };
  metadata?: Record<string, unknown>;
}

export type LifecycleState =
  | 'UNINITIALIZED'
  | 'STARTING'
  | 'INITIALIZING'
  | 'READY'
  | 'DEGRADED'
  | 'SHUTTING_DOWN'
  | 'TERMINATED'
  | 'FAILED';

export interface OperationalDiagnostics {
  schemaVersion: 1;
  service: string;
  version: string;
  flutterAppVersion?: string;
  environment: 'development' | 'test' | 'staging' | 'production';
  lifecycleState: LifecycleState;
  uptimeSeconds: number;
  timestamp: string;
  release?: Record<string, unknown>;
  dependencies: {
    database: { status: string; [key: string]: unknown };
    redis?: Record<string, unknown>;
    mqtt?: Record<string, unknown>;
    workers?: Record<string, unknown>;
    [key: string]: unknown;
  };
  process?: Record<string, unknown>;
  features?: Record<string, unknown>;
}

export interface ReleaseMetadata {
  schemaVersion: 1;
  appName: string;
  service: string;
  appVersion: string;
  flutterAppVersion: string;
  schemaVersionNumber: number;
  latestMigration: string;
  totalTables?: number;
  gitCommit?: string;
  buildTimestamp?: string;
  environment: 'development' | 'test' | 'staging' | 'production';
}

export interface RuntimeConfiguration {
  schemaVersion: 1;
  environment: 'development' | 'test' | 'staging' | 'production';
  port: number;
  host: string;
  databaseBound: boolean;
  redisConfigured: boolean;
  mqttConfigured: boolean;
  timestamp: string;
  features?: Record<string, unknown>;
  validationStatus?: 'VALID' | 'INVALID' | 'DEGRADED';
}
