export interface MatterDevice {
  schemaVersion: number;
  matterDeviceId: string;
  deviceId: string;
  homeId: string;
  nodeId: string;
  vendorId: number;
  productId: number;
  matterDeviceType:
    | 'ON_OFF_LIGHT'
    | 'DIMMABLE_LIGHT'
    | 'COLOR_TEMPERATURE_LIGHT'
    | 'EXTENDED_COLOR_LIGHT'
    | 'ON_OFF_PLUGIN_UNIT'
    | 'DIMMABLE_PLUGIN_UNIT'
    | 'FAN'
    | 'THERMOSTAT'
    | 'GENERIC_SWITCH'
    | 'ELECTRICAL_SENSOR';
  commissioningState:
    | 'NOT_COMMISSIONED'
    | 'COMMISSIONING'
    | 'COMMISSIONED'
    | 'PARTIALLY_CONNECTED'
    | 'CONNECTED'
    | 'DISCONNECTED'
    | 'DECOMMISSIONED';
  subscriptionState?: 'ACTIVE' | 'INACTIVE' | 'ERROR' | 'NONE';
  softwareVersion?: number;
  softwareVersionString?: string;
  hardwareVersion?: number;
  hardwareVersionString?: string;
  discriminator?: number;
  setupPasscode?: number;
  lastSynchronizedAt?: string | null;
  createdAt: string;
  updatedAt: string;
}

export interface MatterFabric {
  schemaVersion: number;
  fabricId: string;
  matterDeviceId: string;
  fabricIndex: number;
  fabricName: 'APPLE_HOME' | 'GOOGLE_HOME' | 'AMAZON_ALEXA' | 'EH_HOME' | 'CUSTOM_CONTROLLER';
  vendorId: number;
  controllerNodeId?: string | null;
  commissioningState:
    | 'NOT_COMMISSIONED'
    | 'COMMISSIONING'
    | 'COMMISSIONED'
    | 'PARTIALLY_CONNECTED'
    | 'CONNECTED'
    | 'DISCONNECTED'
    | 'DECOMMISSIONED';
  label?: string | null;
  pairedAt?: string | null;
  lastSynchronizedAt?: string | null;
  createdAt: string;
  updatedAt: string;
}

export interface MatterEndpoint {
  schemaVersion: number;
  endpointId: string;
  matterDeviceId: string;
  endpointNumber: number;
  deviceType: string;
  channelIndex: number;
  serverClusters: Array<{
    clusterId: number;
    clusterName: string;
    supportedAttributes?: string[];
    supportedCommands?: string[];
  }>;
  clientClusters?: Array<{
    clusterId: number;
    clusterName: string;
  }>;
}

export interface MatterCommissioningSession {
  schemaVersion: number;
  sessionId: string;
  deviceId: string;
  homeId: string;
  stage:
    | 'INITIALIZED'
    | 'ADVERTISING'
    | 'PASE_IN_PROGRESS'
    | 'PASE_ESTABLISHED'
    | 'CASE_AUTHENTICATING'
    | 'FABRIC_ASSIGNED'
    | 'VERIFIED'
    | 'COMPLETED'
    | 'FAILED'
    | 'EXPIRED';
  targetFabric?: 'APPLE_HOME' | 'GOOGLE_HOME' | 'AMAZON_ALEXA' | 'EH_HOME' | 'CUSTOM_CONTROLLER';
  discriminator: number;
  setupPasscode: number;
  qrCodePayload: string;
  manualPairingCode: string;
  errorMessage?: string | null;
  expiresAt: string;
  createdAt: string;
  completedAt?: string | null;
}

export interface MatterSyncEvent {
  schemaVersion: number;
  eventId: string;
  deviceId: string;
  homeId: string;
  fabricId?: string | null;
  endpointNumber: number;
  clusterId: number;
  attributeName: string;
  attributeValue: any;
  direction: 'INBOUND_FROM_MATTER' | 'OUTBOUND_TO_MATTER';
  stateVersion: number;
  isPhysicalConfirmed?: boolean;
  timestamp: string;
}

export interface ExternalPlatformLink {
  schemaVersion: number;
  linkId: string;
  homeId: string;
  deviceId: string;
  platform: 'MATTER' | 'APPLE_HOME' | 'GOOGLE_HOME' | 'AMAZON_ALEXA';
  status:
    | 'CONNECTED'
    | 'NOT_CONNECTED'
    | 'CONNECTING'
    | 'CONNECTION_ISSUE'
    | 'FAILED'
    | 'DISCONNECTED';
  externalIdentifier?: string | null;
  displayName: string;
  syncStatus: 'SYNCHRONIZED' | 'PENDING_SYNC' | 'SYNC_ERROR' | 'IDLE';
  lastErrorMessage?: string | null;
  linkedAt?: string | null;
  lastSyncedAt?: string | null;
  createdAt: string;
  updatedAt: string;
}

export interface InteroperabilityCapabilityMapping {
  schemaVersion: number;
  ehCapability: string;
  productVariantId: string;
  isSupportedByHardware: boolean;
  matterClusterId: number;
  matterClusterName: string;
  matterDeviceType?: string;
  supportedMatterAttributes: string[];
  supportedMatterCommands?: string[];
  hardwareMeteringVerified?: boolean;
  notes?: string | null;
}
