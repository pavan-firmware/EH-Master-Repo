import 'package:flutter/foundation.dart';

/// Discrete lifecycle and continuous trust evaluation states (Phase 32)
enum TrustState {
  provisioned,
  commissioned,
  trusted,
  degraded,
  quarantined,
  revoked,
  decommissioned,
  factoryReset;

  static TrustState fromString(String? val) {
    switch (val?.toUpperCase()) {
      case 'COMMISSIONED':
        return TrustState.commissioned;
      case 'TRUSTED':
        return TrustState.trusted;
      case 'DEGRADED':
        return TrustState.degraded;
      case 'QUARANTINED':
        return TrustState.quarantined;
      case 'REVOKED':
        return TrustState.revoked;
      case 'DECOMMISSIONED':
        return TrustState.decommissioned;
      case 'FACTORY_RESET':
        return TrustState.factoryReset;
      case 'PROVISIONED':
      default:
        return TrustState.provisioned;
    }
  }

  String toApiString() {
    switch (this) {
      case TrustState.provisioned:
        return 'PROVISIONED';
      case TrustState.commissioned:
        return 'COMMISSIONED';
      case TrustState.trusted:
        return 'TRUSTED';
      case TrustState.degraded:
        return 'DEGRADED';
      case TrustState.quarantined:
        return 'QUARANTINED';
      case TrustState.revoked:
        return 'REVOKED';
      case TrustState.decommissioned:
        return 'DECOMMISSIONED';
      case TrustState.factoryReset:
        return 'FACTORY_RESET';
    }
  }

  String toDisplayString() {
    switch (this) {
      case TrustState.provisioned:
        return 'Provisioned';
      case TrustState.commissioned:
        return 'Commissioned';
      case TrustState.trusted:
        return 'Trusted';
      case TrustState.degraded:
        return 'Degraded';
      case TrustState.quarantined:
        return 'Quarantined';
      case TrustState.revoked:
        return 'Revoked';
      case TrustState.decommissioned:
        return 'Decommissioned';
      case TrustState.factoryReset:
        return 'Factory Reset';
    }
  }

  bool get isUsable => this == TrustState.trusted || this == TrustState.degraded;
  bool get isQuarantined => this == TrustState.quarantined;
  bool get isRevoked => this == TrustState.revoked || this == TrustState.decommissioned;
}

enum CredentialLifecycleStatus {
  rotationPending,
  confirmed,
  rotated,
  revoked,
  expired;

  static CredentialLifecycleStatus fromString(String? val) {
    switch (val?.toUpperCase()) {
      case 'CONFIRMED':
        return CredentialLifecycleStatus.confirmed;
      case 'ROTATED':
        return CredentialLifecycleStatus.rotated;
      case 'REVOKED':
        return CredentialLifecycleStatus.revoked;
      case 'EXPIRED':
        return CredentialLifecycleStatus.expired;
      case 'ROTATION_PENDING':
      default:
        return CredentialLifecycleStatus.rotationPending;
    }
  }

  String toApiString() {
    switch (this) {
      case CredentialLifecycleStatus.rotationPending:
        return 'ROTATION_PENDING';
      case CredentialLifecycleStatus.confirmed:
        return 'CONFIRMED';
      case CredentialLifecycleStatus.rotated:
        return 'ROTATED';
      case CredentialLifecycleStatus.revoked:
        return 'REVOKED';
      case CredentialLifecycleStatus.expired:
        return 'EXPIRED';
    }
  }
}

enum LifecycleCredentialType {
  mqtt,
  directLan,
  tlsCert,
  matterNoc;

  static LifecycleCredentialType fromString(String? val) {
    switch (val?.toUpperCase()) {
      case 'DIRECT_LAN':
        return LifecycleCredentialType.directLan;
      case 'TLS_CERT':
        return LifecycleCredentialType.tlsCert;
      case 'MATTER_NOC':
        return LifecycleCredentialType.matterNoc;
      case 'MQTT':
      default:
        return LifecycleCredentialType.mqtt;
    }
  }

  String toApiString() {
    switch (this) {
      case LifecycleCredentialType.mqtt:
        return 'MQTT';
      case LifecycleCredentialType.directLan:
        return 'DIRECT_LAN';
      case LifecycleCredentialType.tlsCert:
        return 'TLS_CERT';
      case LifecycleCredentialType.matterNoc:
        return 'MATTER_NOC';
    }
  }
}

@immutable
class DeviceTrustStateModel {
  final String deviceId;
  final TrustState trustState;
  final double trustScore;
  final Map<String, dynamic> reasoningJson;
  final DateTime? quarantinedAt;
  final DateTime? revokedAt;
  final DateTime lastEvaluatedAt;
  final DateTime updatedAt;

  const DeviceTrustStateModel({
    required this.deviceId,
    required this.trustState,
    required this.trustScore,
    this.reasoningJson = const {},
    this.quarantinedAt,
    this.revokedAt,
    required this.lastEvaluatedAt,
    required this.updatedAt,
  });

  factory DeviceTrustStateModel.fromJson(Map<String, dynamic> json) {
    return DeviceTrustStateModel(
      deviceId: json['device_id'] ?? json['deviceId'] ?? '',
      trustState: TrustState.fromString(json['trust_state'] ?? json['trustState']),
      trustScore: (json['trust_score'] ?? json['trustScore'] ?? 100.0).toDouble(),
      reasoningJson: (json['reasoning_json'] ?? json['reasoningJson'] ?? {}) as Map<String, dynamic>,
      quarantinedAt: json['quarantined_at'] != null ? DateTime.tryParse(json['quarantined_at']) : null,
      revokedAt: json['revoked_at'] != null ? DateTime.tryParse(json['revoked_at']) : null,
      lastEvaluatedAt: DateTime.tryParse(json['last_evaluated_at'] ?? json['lastEvaluatedAt'] ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(json['updated_at'] ?? json['updatedAt'] ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
    'device_id': deviceId,
    'trust_state': trustState.toApiString(),
    'trust_score': trustScore,
    'reasoning_json': reasoningJson,
    'quarantined_at': quarantinedAt?.toIso8601String(),
    'revoked_at': revokedAt?.toIso8601String(),
    'last_evaluated_at': lastEvaluatedAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
  };
}

@immutable
class DeviceCredentialLifecycleModel {
  final String id;
  final String deviceId;
  final LifecycleCredentialType credentialType;
  final String keyIdentifier;
  final String? fingerprint;
  final CredentialLifecycleStatus status;
  final int rotationGeneration;
  final DateTime issuedAt;
  final DateTime? expiresAt;
  final DateTime? rotatedAt;
  final DateTime? revokedAt;
  final Map<String, dynamic> metadata;

  const DeviceCredentialLifecycleModel({
    required this.id,
    required this.deviceId,
    required this.credentialType,
    required this.keyIdentifier,
    this.fingerprint,
    required this.status,
    required this.rotationGeneration,
    required this.issuedAt,
    this.expiresAt,
    this.rotatedAt,
    this.revokedAt,
    this.metadata = const {},
  });

  factory DeviceCredentialLifecycleModel.fromJson(Map<String, dynamic> json) {
    return DeviceCredentialLifecycleModel(
      id: json['id'] ?? '',
      deviceId: json['device_id'] ?? json['deviceId'] ?? '',
      credentialType: LifecycleCredentialType.fromString(json['credential_type'] ?? json['credentialType']),
      keyIdentifier: json['key_identifier'] ?? json['keyIdentifier'] ?? '',
      fingerprint: json['fingerprint'],
      status: CredentialLifecycleStatus.fromString(json['status']),
      rotationGeneration: (json['rotation_generation'] ?? json['rotationGeneration'] ?? 1) as int,
      issuedAt: DateTime.tryParse(json['issued_at'] ?? json['issuedAt'] ?? '') ?? DateTime.now(),
      expiresAt: json['expires_at'] != null ? DateTime.tryParse(json['expires_at']) : null,
      rotatedAt: json['rotated_at'] != null ? DateTime.tryParse(json['rotated_at']) : null,
      revokedAt: json['revoked_at'] != null ? DateTime.tryParse(json['revoked_at']) : null,
      metadata: (json['metadata'] ?? {}) as Map<String, dynamic>,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'device_id': deviceId,
    'credential_type': credentialType.toApiString(),
    'key_identifier': keyIdentifier,
    'fingerprint': fingerprint,
    'status': status.toApiString(),
    'rotation_generation': rotationGeneration,
    'issued_at': issuedAt.toIso8601String(),
    'expires_at': expiresAt?.toIso8601String(),
    'rotated_at': rotatedAt?.toIso8601String(),
    'revoked_at': revokedAt?.toIso8601String(),
    'metadata': metadata,
  };
}

@immutable
class DeviceRevocationModel {
  final String id;
  final String deviceId;
  final String revocationType;
  final String reason;
  final String? actorUserId;
  final Map<String, dynamic> evidenceJson;
  final bool remediationAllowed;
  final DateTime createdAt;

  const DeviceRevocationModel({
    required this.id,
    required this.deviceId,
    required this.revocationType,
    required this.reason,
    this.actorUserId,
    this.evidenceJson = const {},
    required this.remediationAllowed,
    required this.createdAt,
  });

  factory DeviceRevocationModel.fromJson(Map<String, dynamic> json) {
    return DeviceRevocationModel(
      id: json['id'] ?? '',
      deviceId: json['device_id'] ?? json['deviceId'] ?? '',
      revocationType: json['revocation_type'] ?? json['revocationType'] ?? 'COMPROMISED',
      reason: json['reason'] ?? '',
      actorUserId: json['actor_user_id'] ?? json['actorUserId'],
      evidenceJson: (json['evidence_json'] ?? json['evidenceJson'] ?? {}) as Map<String, dynamic>,
      remediationAllowed: (json['remediation_allowed'] ?? json['remediationAllowed'] ?? false) as bool,
      createdAt: DateTime.tryParse(json['created_at'] ?? json['createdAt'] ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'device_id': deviceId,
    'revocation_type': revocationType,
    'reason': reason,
    'actor_user_id': actorUserId,
    'evidence_json': evidenceJson,
    'remediation_allowed': remediationAllowed,
    'created_at': createdAt.toIso8601String(),
  };
}

@immutable
class DeviceSecurityHistoryModel {
  final String deviceId;
  final DeviceTrustStateModel trustState;
  final List<DeviceRevocationModel> revocations;
  final List<DeviceCredentialLifecycleModel> lifecycleRecords;

  const DeviceSecurityHistoryModel({
    required this.deviceId,
    required this.trustState,
    this.revocations = const [],
    this.lifecycleRecords = const [],
  });

  factory DeviceSecurityHistoryModel.fromJson(Map<String, dynamic> json) {
    final devId = json['deviceId'] ?? json['device_id'] ?? '';
    return DeviceSecurityHistoryModel(
      deviceId: devId,
      trustState: DeviceTrustStateModel.fromJson(json['trustState'] ?? json['trust_state'] ?? {}),
      revocations: (json['revocations'] as List? ?? [])
          .map((r) => DeviceRevocationModel.fromJson(r as Map<String, dynamic>))
          .toList(),
      lifecycleRecords: (json['lifecycleRecords'] as List? ?? json['lifecycle_records'] as List? ?? [])
          .map((l) => DeviceCredentialLifecycleModel.fromJson(l as Map<String, dynamic>))
          .toList(),
    );
  }
}
