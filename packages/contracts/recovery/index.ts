/**
 * EH Home Canonical Disaster Recovery & State Resilience Contracts (Phase 33)
 */

export type BackupStatus =
  | 'CREATED'
  | 'IN_PROGRESS'
  | 'COMPLETED'
  | 'FAILED'
  | 'INVALID'
  | 'EXPIRED';

export type BackupScope =
  | 'FULL'
  | 'HOME'
  | 'SECURITY'
  | 'CONFIGURATION'
  | 'HISTORICAL';

export type DataClassification =
  | 'CRITICAL_STATE'
  | 'SECURITY_STATE'
  | 'CONFIGURATION_STATE'
  | 'HISTORICAL_STATE'
  | 'DERIVED_STATE';

export type SecretHandling =
  | 'EXCLUDED'
  | 'REGENERATED'
  | 'EXTERNAL_AUTHORITY'
  | 'NONE';

export interface BackupObjectManifest {
  objectKey: string;
  entityType: string;
  recordCount: number;
  byteSize: number;
  sha256Checksum: string;
  dataClassification: DataClassification;
  secretHandling?: SecretHandling;
}

export interface BackupManifest {
  schemaVersion: 1;
  backupId: string;
  createdAt: string;
  completedAt?: string | null;
  expiresAt?: string | null;
  source: string;
  appVersion?: string;
  migrationVersion: number;
  status: BackupStatus;
  scope?: BackupScope;
  homeId?: string | null;
  objects: BackupObjectManifest[];
  manifestChecksum: string;
  totalBytes: number;
  objectCount: number;
  encryption?: {
    enabled: boolean;
    algorithm?: string;
    keyIdentifier?: string;
  };
  dependencies?: string[];
  metadata?: Record<string, unknown>;
}

export interface BackupRecord {
  schemaVersion: 1;
  backupId: string;
  status: BackupStatus;
  scope?: BackupScope;
  homeId?: string | null;
  provider: string;
  location: string;
  schemaVersionRecorded: number;
  migrationVersionRecorded: number;
  objectCount: number;
  totalBytes: number;
  manifestChecksum?: string | null;
  errorMessage?: string | null;
  createdAt: string;
  completedAt?: string | null;
  expiresAt?: string | null;
}

export type RestoreStatus =
  | 'PENDING'
  | 'IN_PROGRESS'
  | 'COMPLETED'
  | 'FAILED'
  | 'ROLLED_BACK';

export type RestoreStage =
  | 'VALIDATE'
  | 'PRECHECK'
  | 'PLAN'
  | 'APPLY'
  | 'VERIFY'
  | 'COMPLETE'
  | 'FAILED';

export type MigrationCompatibility =
  | 'COMPATIBLE'
  | 'MIGRATION_REQUIRED'
  | 'INCOMPATIBLE';

export type ReconciliationStatus =
  | 'CONSISTENT'
  | 'PARTIALLY_RECONCILED'
  | 'NEEDS_RECOMMISSIONING'
  | 'TRUST_REVIEW_REQUIRED'
  | 'FAILED';

export interface RestorePlanConflict {
  entityType: string;
  entityId: string;
  conflictType: string;
  resolution: string;
}

export interface RestorePlan {
  restorableEntities: string[];
  excludedEntities: string[];
  conflicts: RestorePlanConflict[];
  migrationCompatibility: MigrationCompatibility;
}

export interface RestoreReconciliation {
  status: ReconciliationStatus;
  revocationsPreserved: number;
  decommissionedPreserved: number;
  expiredCredentialsPreserved: number;
  trustReEvaluatedCount: number;
  devicesRequiringRecommissioning: string[];
  warnings: string[];
}

export interface RestoreOperation {
  schemaVersion: 1;
  operationId: string;
  backupId: string;
  status: RestoreStatus;
  stage: RestoreStage;
  targetScope?: BackupScope;
  homeId?: string | null;
  initiatedBy: string;
  dryRun: boolean;
  plan?: RestorePlan;
  reconciliation?: RestoreReconciliation;
  errorMessage?: string | null;
  createdAt: string;
  completedAt?: string | null;
}

export type CheckpointType =
  | 'PRE_RESTORE'
  | 'POST_RESTORE'
  | 'PRE_MIGRATION'
  | 'SCHEDULED'
  | 'MANUAL';

export interface RecoveryCheckpoint {
  schemaVersion: 1;
  checkpointId: string;
  name: string;
  checkpointType: CheckpointType;
  appVersion?: string;
  schemaVersionRecorded: number;
  migrationVersionRecorded: number;
  activeOperationId?: string | null;
  stateSummary?: {
    userCount?: number;
    homeCount?: number;
    deviceCount?: number;
    revokedDeviceCount?: number;
    automationCount?: number;
  };
  metadata?: Record<string, unknown>;
  createdAt: string;
}

export type IntegrityStatus =
  | 'VALID'
  | 'INVALID'
  | 'INCOMPATIBLE'
  | 'UNKNOWN';

export interface FailedIntegrityObject {
  objectKey: string;
  expectedChecksum: string;
  calculatedChecksum: string;
  reason: string;
}

export interface RecoveryIntegrity {
  schemaVersion: 1;
  verificationId: string;
  backupId: string;
  status: IntegrityStatus;
  manifestValid: boolean;
  checksumsValid: boolean;
  schemaCompatible: boolean;
  migrationCompatible: boolean;
  verifiedObjectsCount?: number;
  failedObjectsCount?: number;
  failedObjects?: FailedIntegrityObject[];
  details?: Record<string, unknown>;
  verifiedBy: string;
  verifiedAt: string;
}

export type RecoveryEventType =
  | 'BACKUP_CREATED'
  | 'BACKUP_COMPLETED'
  | 'BACKUP_FAILED'
  | 'BACKUP_VERIFIED'
  | 'BACKUP_INTEGRITY_FAILED'
  | 'RESTORE_REQUESTED'
  | 'RESTORE_PLANNED'
  | 'RESTORE_STARTED'
  | 'RESTORE_COMPLETED'
  | 'RESTORE_FAILED'
  | 'RECONCILIATION_REQUIRED'
  | 'CHECKPOINT_CREATED';

export type RecoveryEventSeverity = 'INFO' | 'WARNING' | 'ERROR' | 'CRITICAL';

export interface RecoveryEvent {
  schemaVersion: 1;
  id: string;
  backupId?: string | null;
  operationId?: string | null;
  eventType: RecoveryEventType;
  severity: RecoveryEventSeverity;
  actorUserId?: string | null;
  details?: Record<string, unknown>;
  timestamp: string;
}
