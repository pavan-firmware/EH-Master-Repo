/**
 * EH Home Canonical Device Trust & Credential Lifecycle Contracts (Phase 32)
 */

export type TrustState =
  | 'PROVISIONED'
  | 'COMMISSIONED'
  | 'TRUSTED'
  | 'DEGRADED'
  | 'QUARANTINED'
  | 'REVOKED'
  | 'DECOMMISSIONED'
  | 'FACTORY_RESET';

export type AttestationType =
  | 'FACTORY_KEY'
  | 'CERTIFICATE'
  | 'SHARED_SECRET'
  | 'NONE';

export interface DeviceIdentityVerification {
  schemaVersion: 1;
  deviceId: string;
  serialNumber: string;
  productVariantId: string;
  hardwareRevision: string;
  firmwareFamily: string;
  secureElementPresent?: boolean;
  attestationType: AttestationType;
  attestationVerified: boolean;
  verifiedAt: string;
}

export interface DeviceTrustState {
  schemaVersion: 1;
  deviceId: string;
  trustState: TrustState;
  trustScore: number;
  reasoningJson?: Record<string, unknown>;
  quarantinedAt?: string | null;
  revokedAt?: string | null;
  lastEvaluatedAt: string;
  updatedAt: string;
}

export type LifecycleCredentialType =
  | 'MQTT'
  | 'DIRECT_LAN'
  | 'TLS_CERT'
  | 'MATTER_NOC';

export type LifecycleCredentialStatus =
  | 'ROTATION_PENDING'
  | 'CONFIRMED'
  | 'ROTATED'
  | 'REVOKED'
  | 'EXPIRED';

export interface DeviceCredentialLifecycle {
  schemaVersion: 1;
  id: string;
  deviceId: string;
  credentialType: LifecycleCredentialType;
  keyIdentifier: string;
  fingerprint?: string | null;
  status: LifecycleCredentialStatus;
  rotationGeneration: number;
  issuedAt: string;
  expiresAt?: string | null;
  rotatedAt?: string | null;
  revokedAt?: string | null;
  metadata?: Record<string, unknown>;
}

export type RevocationType =
  | 'CREDENTIAL_REVOKED'
  | 'TRUST_REVOKED'
  | 'DECOMMISSIONED'
  | 'COMPROMISED';

export interface DeviceRevocation {
  schemaVersion: 1;
  id: string;
  deviceId: string;
  revocationType: RevocationType;
  reason: string;
  actorUserId?: string | null;
  evidenceJson?: Record<string, unknown>;
  remediationAllowed: boolean;
  createdAt: string;
}

export type ProvisioningStage =
  | 'FACTORY_INITIALIZED'
  | 'PROVISIONING_STARTED'
  | 'CREDENTIALS_ISSUED'
  | 'CLAIMED_TO_HOME'
  | 'VERIFIED';

export interface DeviceProvisioningRecord {
  schemaVersion: 1;
  id: string;
  deviceId: string;
  stage: ProvisioningStage;
  authority: string;
  evidenceJson?: Record<string, unknown>;
  completedAt?: string | null;
  createdAt: string;
}

export type DeviceSecurityEventType =
  | 'TRUST_STATE_CHANGED'
  | 'ROTATION_INITIATED'
  | 'ROTATION_CONFIRMED'
  | 'QUARANTINE_ENACTED'
  | 'REVOCATION_ENACTED'
  | 'TRUST_RESTORED'
  | 'AUTH_FAILED_BURST';

export type DeviceSecuritySeverity =
  | 'INFO'
  | 'WARNING'
  | 'ERROR'
  | 'CRITICAL';

export interface DeviceSecurityEvent {
  schemaVersion: 1;
  id: string;
  deviceId: string;
  eventType: DeviceSecurityEventType;
  severity: DeviceSecuritySeverity;
  details?: Record<string, unknown>;
  timestamp: string;
}
