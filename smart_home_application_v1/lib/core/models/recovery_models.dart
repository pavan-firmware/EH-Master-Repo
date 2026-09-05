import 'package:flutter/foundation.dart';

enum BackupStatus {
  created,
  inProgress,
  completed,
  failed,
  invalid,
  expired,
  unknown;

  static BackupStatus fromString(String? val) {
    if (val == null) return BackupStatus.unknown;
    switch (val.toUpperCase()) {
      case 'CREATED':
        return BackupStatus.created;
      case 'IN_PROGRESS':
        return BackupStatus.inProgress;
      case 'COMPLETED':
        return BackupStatus.completed;
      case 'FAILED':
        return BackupStatus.failed;
      case 'INVALID':
        return BackupStatus.invalid;
      case 'EXPIRED':
        return BackupStatus.expired;
      default:
        return BackupStatus.unknown;
    }
  }

  String get label {
    switch (this) {
      case BackupStatus.created:
        return 'CREATED';
      case BackupStatus.inProgress:
        return 'IN PROGRESS';
      case BackupStatus.completed:
        return 'COMPLETED';
      case BackupStatus.failed:
        return 'FAILED';
      case BackupStatus.invalid:
        return 'INVALID';
      case BackupStatus.expired:
        return 'EXPIRED';
      case BackupStatus.unknown:
        return 'UNKNOWN';
    }
  }
}

enum IntegrityStatus {
  valid,
  invalid,
  incompatible,
  unknown;

  static IntegrityStatus fromString(String? val) {
    if (val == null) return IntegrityStatus.unknown;
    switch (val.toUpperCase()) {
      case 'VALID':
        return IntegrityStatus.valid;
      case 'INVALID':
        return IntegrityStatus.invalid;
      case 'INCOMPATIBLE':
        return IntegrityStatus.incompatible;
      default:
        return IntegrityStatus.unknown;
    }
  }

  String get label {
    switch (this) {
      case IntegrityStatus.valid:
        return 'VERIFIED';
      case IntegrityStatus.invalid:
        return 'INVALID';
      case IntegrityStatus.incompatible:
        return 'INCOMPATIBLE';
      case IntegrityStatus.unknown:
        return 'UNKNOWN';
    }
  }
}

enum RestoreStage {
  validate,
  precheck,
  plan,
  apply,
  verify,
  complete,
  failed,
  unknown;

  static RestoreStage fromString(String? val) {
    if (val == null) return RestoreStage.unknown;
    switch (val.toUpperCase()) {
      case 'VALIDATE':
        return RestoreStage.validate;
      case 'PRECHECK':
        return RestoreStage.precheck;
      case 'PLAN':
        return RestoreStage.plan;
      case 'APPLY':
        return RestoreStage.apply;
      case 'VERIFY':
        return RestoreStage.verify;
      case 'COMPLETE':
        return RestoreStage.complete;
      case 'FAILED':
        return RestoreStage.failed;
      default:
        return RestoreStage.unknown;
    }
  }
}

enum ReconciliationStatus {
  consistent,
  partiallyReconciled,
  needsRecommissioning,
  trustReviewRequired,
  failed,
  unknown;

  static ReconciliationStatus fromString(String? val) {
    if (val == null) return ReconciliationStatus.unknown;
    switch (val.toUpperCase()) {
      case 'CONSISTENT':
        return ReconciliationStatus.consistent;
      case 'PARTIALLY_RECONCILED':
        return ReconciliationStatus.partiallyReconciled;
      case 'NEEDS_RECOMMISSIONING':
        return ReconciliationStatus.needsRecommissioning;
      case 'TRUST_REVIEW_REQUIRED':
        return ReconciliationStatus.trustReviewRequired;
      case 'FAILED':
        return ReconciliationStatus.failed;
      default:
        return ReconciliationStatus.unknown;
    }
  }

  String get label {
    switch (this) {
      case ReconciliationStatus.consistent:
        return 'CONSISTENT';
      case ReconciliationStatus.partiallyReconciled:
        return 'PARTIALLY RECONCILED';
      case ReconciliationStatus.needsRecommissioning:
        return 'NEEDS RECOMMISSIONING';
      case ReconciliationStatus.trustReviewRequired:
        return 'REQUIRES ACTION';
      case ReconciliationStatus.failed:
        return 'FAILED';
      case ReconciliationStatus.unknown:
        return 'UNKNOWN';
    }
  }
}

@immutable
class BackupRecordModel {
  final String backupId;
  final BackupStatus status;
  final String scope;
  final String? homeId;
  final String provider;
  final String location;
  final int objectCount;
  final int totalBytes;
  final String? manifestChecksum;
  final String? errorMessage;
  final DateTime createdAt;
  final DateTime? completedAt;
  final DateTime? expiresAt;

  const BackupRecordModel({
    required this.backupId,
    required this.status,
    required this.scope,
    this.homeId,
    required this.provider,
    required this.location,
    required this.objectCount,
    required this.totalBytes,
    this.manifestChecksum,
    this.errorMessage,
    required this.createdAt,
    this.completedAt,
    this.expiresAt,
  });

  factory BackupRecordModel.fromJson(Map<String, dynamic> json) {
    return BackupRecordModel(
      backupId: json['backup_id'] as String? ?? json['backupId'] as String? ?? '',
      status: BackupStatus.fromString(json['status'] as String?),
      scope: json['scope'] as String? ?? 'FULL',
      homeId: json['home_id'] as String? ?? json['homeId'] as String?,
      provider: json['provider'] as String? ?? 'LocalBackupProvider',
      location: json['location'] as String? ?? '',
      objectCount: (json['object_count'] ?? json['objectCount'] ?? 0) as int,
      totalBytes: (json['total_bytes'] ?? json['totalBytes'] ?? 0) as int,
      manifestChecksum: json['manifest_checksum'] as String? ?? json['manifestChecksum'] as String?,
      errorMessage: json['error_message'] as String? ?? json['errorMessage'] as String?,
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at'] as String) : (json['createdAt'] != null ? DateTime.parse(json['createdAt'] as String) : DateTime.now()),
      completedAt: json['completed_at'] != null ? DateTime.parse(json['completed_at'] as String) : (json['completedAt'] != null ? DateTime.parse(json['completedAt'] as String) : null),
      expiresAt: json['expires_at'] != null ? DateTime.parse(json['expires_at'] as String) : (json['expiresAt'] != null ? DateTime.parse(json['expiresAt'] as String) : null),
    );
  }
}

@immutable
class RecoveryIntegrityModel {
  final String verificationId;
  final String backupId;
  final IntegrityStatus status;
  final bool manifestValid;
  final bool checksumsValid;
  final bool schemaCompatible;
  final bool migrationCompatible;
  final int verifiedObjectsCount;
  final int failedObjectsCount;
  final List<Map<String, dynamic>> failedObjects;
  final String verifiedBy;
  final DateTime verifiedAt;

  const RecoveryIntegrityModel({
    required this.verificationId,
    required this.backupId,
    required this.status,
    required this.manifestValid,
    required this.checksumsValid,
    required this.schemaCompatible,
    required this.migrationCompatible,
    required this.verifiedObjectsCount,
    required this.failedObjectsCount,
    this.failedObjects = const [],
    required this.verifiedBy,
    required this.verifiedAt,
  });

  factory RecoveryIntegrityModel.fromJson(Map<String, dynamic> json) {
    return RecoveryIntegrityModel(
      verificationId: json['verification_id'] as String? ?? json['verificationId'] as String? ?? '',
      backupId: json['backup_id'] as String? ?? json['backupId'] as String? ?? '',
      status: IntegrityStatus.fromString(json['status'] as String?),
      manifestValid: (json['manifest_valid'] ?? json['manifestValid'] ?? false) as bool,
      checksumsValid: (json['checksums_valid'] ?? json['checksumsValid'] ?? false) as bool,
      schemaCompatible: (json['schema_compatible'] ?? json['schemaCompatible'] ?? false) as bool,
      migrationCompatible: (json['migration_compatible'] ?? json['migrationCompatible'] ?? false) as bool,
      verifiedObjectsCount: (json['verified_objects_count'] ?? json['verifiedObjectsCount'] ?? 0) as int,
      failedObjectsCount: (json['failed_objects_count'] ?? json['failedObjectsCount'] ?? 0) as int,
      failedObjects: (json['failed_objects'] as List<dynamic>? ?? json['failedObjects'] as List<dynamic>? ?? [])
          .map((e) => e as Map<String, dynamic>)
          .toList(),
      verifiedBy: json['verified_by'] as String? ?? json['verifiedBy'] as String? ?? 'SYSTEM',
      verifiedAt: json['verified_at'] != null ? DateTime.parse(json['verified_at'] as String) : (json['verifiedAt'] != null ? DateTime.parse(json['verifiedAt'] as String) : DateTime.now()),
    );
  }
}

@immutable
class RestorePlanConflictModel {
  final String entityType;
  final String entityId;
  final String conflictType;
  final String resolution;

  const RestorePlanConflictModel({
    required this.entityType,
    required this.entityId,
    required this.conflictType,
    required this.resolution,
  });

  factory RestorePlanConflictModel.fromJson(Map<String, dynamic> json) {
    return RestorePlanConflictModel(
      entityType: json['entityType'] as String? ?? '',
      entityId: json['entityId'] as String? ?? '',
      conflictType: json['conflictType'] as String? ?? '',
      resolution: json['resolution'] as String? ?? '',
    );
  }
}

@immutable
class RestorePlanModel {
  final List<String> restorableEntities;
  final List<String> excludedEntities;
  final List<RestorePlanConflictModel> conflicts;
  final String migrationCompatibility;

  const RestorePlanModel({
    required this.restorableEntities,
    required this.excludedEntities,
    required this.conflicts,
    required this.migrationCompatibility,
  });

  factory RestorePlanModel.fromJson(Map<String, dynamic> json) {
    return RestorePlanModel(
      restorableEntities: (json['restorableEntities'] as List<dynamic>? ?? []).map((e) => e.toString()).toList(),
      excludedEntities: (json['excludedEntities'] as List<dynamic>? ?? []).map((e) => e.toString()).toList(),
      conflicts: (json['conflicts'] as List<dynamic>? ?? [])
          .map((e) => RestorePlanConflictModel.fromJson(e as Map<String, dynamic>))
          .toList(),
      migrationCompatibility: json['migrationCompatibility'] as String? ?? 'COMPATIBLE',
    );
  }
}

@immutable
class RestoreReconciliationModel {
  final ReconciliationStatus status;
  final int revocationsPreserved;
  final int decommissionedPreserved;
  final int expiredCredentialsPreserved;
  final int trustReEvaluatedCount;
  final List<String> devicesRequiringRecommissioning;
  final List<String> warnings;

  const RestoreReconciliationModel({
    required this.status,
    required this.revocationsPreserved,
    required this.decommissionedPreserved,
    required this.expiredCredentialsPreserved,
    required this.trustReEvaluatedCount,
    required this.devicesRequiringRecommissioning,
    required this.warnings,
  });

  factory RestoreReconciliationModel.fromJson(Map<String, dynamic> json) {
    return RestoreReconciliationModel(
      status: ReconciliationStatus.fromString(json['status'] as String?),
      revocationsPreserved: (json['revocationsPreserved'] ?? 0) as int,
      decommissionedPreserved: (json['decommissionedPreserved'] ?? 0) as int,
      expiredCredentialsPreserved: (json['expiredCredentialsPreserved'] ?? 0) as int,
      trustReEvaluatedCount: (json['trustReEvaluatedCount'] ?? 0) as int,
      devicesRequiringRecommissioning: (json['devicesRequiringRecommissioning'] as List<dynamic>? ?? [])
          .map((e) => e.toString())
          .toList(),
      warnings: (json['warnings'] as List<dynamic>? ?? []).map((e) => e.toString()).toList(),
    );
  }
}

@immutable
class RestoreOperationModel {
  final String operationId;
  final String backupId;
  final String status;
  final RestoreStage stage;
  final String targetScope;
  final String? homeId;
  final String initiatedBy;
  final bool dryRun;
  final RestorePlanModel? plan;
  final RestoreReconciliationModel? reconciliation;
  final String? errorMessage;
  final DateTime createdAt;
  final DateTime? completedAt;

  const RestoreOperationModel({
    required this.operationId,
    required this.backupId,
    required this.status,
    required this.stage,
    required this.targetScope,
    this.homeId,
    required this.initiatedBy,
    required this.dryRun,
    this.plan,
    this.reconciliation,
    this.errorMessage,
    required this.createdAt,
    this.completedAt,
  });

  factory RestoreOperationModel.fromJson(Map<String, dynamic> json) {
    return RestoreOperationModel(
      operationId: json['id'] as String? ?? json['operationId'] as String? ?? '',
      backupId: json['backup_id'] as String? ?? json['backupId'] as String? ?? '',
      status: json['status'] as String? ?? 'PENDING',
      stage: RestoreStage.fromString(json['stage'] as String?),
      targetScope: json['target_scope'] as String? ?? json['targetScope'] as String? ?? 'FULL',
      homeId: json['home_id'] as String? ?? json['homeId'] as String?,
      initiatedBy: json['initiated_by'] as String? ?? json['initiatedBy'] as String? ?? '',
      dryRun: (json['dry_run'] ?? json['dryRun'] ?? false) as bool,
      plan: json['plan_json'] != null
          ? RestorePlanModel.fromJson(json['plan_json'] as Map<String, dynamic>)
          : (json['plan'] != null ? RestorePlanModel.fromJson(json['plan'] as Map<String, dynamic>) : null),
      reconciliation: json['reconciliation_json'] != null
          ? RestoreReconciliationModel.fromJson(json['reconciliation_json'] as Map<String, dynamic>)
          : (json['reconciliation'] != null ? RestoreReconciliationModel.fromJson(json['reconciliation'] as Map<String, dynamic>) : null),
      errorMessage: json['error_message'] as String? ?? json['errorMessage'] as String?,
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at'] as String) : (json['createdAt'] != null ? DateTime.parse(json['createdAt'] as String) : DateTime.now()),
      completedAt: json['completed_at'] != null ? DateTime.parse(json['completed_at'] as String) : (json['completedAt'] != null ? DateTime.parse(json['completedAt'] as String) : null),
    );
  }
}

@immutable
class RecoveryCheckpointModel {
  final String checkpointId;
  final String name;
  final String checkpointType;
  final String? appVersion;
  final int schemaVersionRecorded;
  final int migrationVersionRecorded;
  final String? activeOperationId;
  final Map<String, dynamic> stateSummary;
  final DateTime createdAt;

  const RecoveryCheckpointModel({
    required this.checkpointId,
    required this.name,
    required this.checkpointType,
    this.appVersion,
    required this.schemaVersionRecorded,
    required this.migrationVersionRecorded,
    this.activeOperationId,
    required this.stateSummary,
    required this.createdAt,
  });

  factory RecoveryCheckpointModel.fromJson(Map<String, dynamic> json) {
    return RecoveryCheckpointModel(
      checkpointId: json['id'] as String? ?? json['checkpointId'] as String? ?? '',
      name: json['name'] as String? ?? '',
      checkpointType: json['checkpoint_type'] as String? ?? json['checkpointType'] as String? ?? 'MANUAL',
      appVersion: json['app_version'] as String? ?? json['appVersion'] as String?,
      schemaVersionRecorded: (json['schema_version_recorded'] ?? json['schemaVersionRecorded'] ?? 1) as int,
      migrationVersionRecorded: (json['migration_version_recorded'] ?? json['migrationVersionRecorded'] ?? 26) as int,
      activeOperationId: json['active_operation_id'] as String? ?? json['activeOperationId'] as String?,
      stateSummary: (json['state_summary_json'] as Map<String, dynamic>? ?? json['stateSummary'] as Map<String, dynamic>? ?? {}),
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at'] as String) : (json['createdAt'] != null ? DateTime.parse(json['createdAt'] as String) : DateTime.now()),
    );
  }
}
