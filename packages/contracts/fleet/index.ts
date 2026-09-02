/**
 * EH Home — Device Fleet Management & OTA Canonical Contract Types (Phase 18)
 */

export type ReleaseChannel = 'development' | 'staging' | 'production' | 'canary';

export type ReleaseStatus = 'DRAFT' | 'PUBLISHED' | 'DEPRECATED' | 'REVOKED';

export type RolloutStage = 'CANARY' | 'STAGED_25' | 'STAGED_50' | 'FULL_100';

export type RolloutStatus = 'ACTIVE' | 'PAUSED' | 'COMPLETED' | 'CANCELLED';

export type OtaOperationStatus =
  | 'QUEUED'
  | 'AVAILABLE'
  | 'DOWNLOADING'
  | 'VERIFYING'
  | 'INSTALLING'
  | 'REBOOTING'
  | 'CONFIRMING'
  | 'SUCCESS'
  | 'FAILED'
  | 'ROLLED_BACK';

export interface FirmwareReleaseContract {
  schemaVersion: 1;
  id: string;
  productVariantId: string;
  hardwareRevision?: string | null;
  firmwareFamily: string;
  version: string;
  minFirmwareVersion?: string | null;
  releaseChannel: ReleaseChannel;
  binarySizeBytes: number;
  sha256: string;
  ed25519Signature: string;
  downloadUrl: string;
  releaseNotes?: string | null;
  status: ReleaseStatus;
  createdAt: string;
  releasedAt?: string | null;
}

export interface OtaRolloutContract {
  schemaVersion: 1;
  id: string;
  releaseId: string;
  homeId?: string | null;
  rolloutStage: RolloutStage;
  status: RolloutStatus;
  targetFilters?: Record<string, any>;
  createdAt: string;
  updatedAt: string;
}

export interface OtaOperationContract {
  schemaVersion: 1;
  id: string;
  deviceId: string;
  homeId: string;
  releaseId: string;
  rolloutId?: string | null;
  fromVersion: string;
  targetVersion: string;
  status: OtaOperationStatus;
  progressPercent: number;
  errorCode?: string | null;
  errorMessage?: string | null;
  initiatedByUserId?: string | null;
  startedAt: string;
  completedAt?: string | null;
  updatedAt: string;
}

export interface DeviceMaintenanceLogContract {
  schemaVersion: 1;
  id: string;
  deviceId: string;
  homeId: string;
  operationType: 'FIRMWARE_UPGRADE' | 'FIRMWARE_ROLLBACK' | 'REBOOT' | 'DIAGNOSTIC';
  releaseId?: string | null;
  fromVersion?: string | null;
  toVersion?: string | null;
  status: 'SUCCESS' | 'FAILED' | 'ROLLED_BACK';
  details?: Record<string, any>;
  createdAt: string;
}

export interface FleetDeviceSummary {
  deviceId: string;
  serialNumber?: string | null;
  productVariantId: string;
  hardwareRevision?: string | null;
  firmwareFamily?: string | null;
  firmwareVersion: string;
  customName?: string | null;
  homeId?: string | null;
  roomId?: string | null;
  healthStatus: string;
  connectionState: string;
  lastSeenAt?: string | null;
  otaStatus?: OtaOperationStatus | null;
  availableUpdate?: {
    releaseId: string;
    version: string;
    releaseChannel: string;
    releaseNotes?: string | null;
  } | null;
}

export interface FleetStatusContract {
  schemaVersion: 1;
  homeId?: string | null;
  totalDevices: number;
  onlineDevices: number;
  offlineDevices: number;
  staleDevices: number;
  degradedDevices: number;
  otaUpdateAvailableCount: number;
  otaInProgressCount: number;
  otaFailedCount: number;
  devices: FleetDeviceSummary[];
}
