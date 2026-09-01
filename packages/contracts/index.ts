/**
 * EH Home Canonical Contract Types (v3.2)
 * Auto-generated & typed directly from JSON Schemas.
 */

export interface DeviceIdentity {
  schemaVersion: 1;
  deviceId: string;
  serialNumber: string;
  productVariantId: string;
  hardwareRevision: string;
  firmwareFamily: string;
}

export interface NetworkIdentity {
  schemaVersion: 1;
  deviceId: string;
  wifiMacAddress?: string | null;
  threadExtendedAddress?: string | null;
  currentIpv4Address?: string | null;
  currentIpv6Address?: string | null;
  bleMacAddress?: string | null;
}

export type CredentialState =
  | 'FACTORY'
  | 'PROVISIONED'
  | 'CLAIMED'
  | 'ACTIVE'
  | 'ROTATED'
  | 'REVOKED'
  | 'RESET';

export interface DeviceCredential {
  schemaVersion: 1;
  deviceId: string;
  mqttUsername: string;
  mqttPasswordHash: string;
  tlsClientCertFingerprint?: string | null;
  localSessionKeyHash: string;
  credentialState: CredentialState;
  createdAt: string;
  rotatedAt?: string | null;
}

export type HomeRole = 'OWNER' | 'ADMIN' | 'MEMBER' | 'GUEST';

export interface HomeMembership {
  schemaVersion: 1;
  homeId: string;
  userId: string;
  role: HomeRole;
  invitedAt: string;
  acceptedAt?: string | null;
}

export interface DeviceAuthorization {
  schemaVersion: 1;
  deviceId: string;
  homeId: string;
  roomId?: string | null;
  customName: string;
  channelLabels?: Record<string, string>;
  claimedAt: string;
  claimedByUserId: string;
}

export type McuFamily =
  | 'esp32-c3'
  | 'esp32-s3'
  | 'esp32-c6'
  | 'nrf5340'
  | 'nrf52840'
  | 'efr32mg24'
  | 'generic-arm';

export interface HardwareProfile {
  schemaVersion: 1;
  mcuFamily: McuFamily;
  flashSizeBytes: number;
  psramSizeBytes?: number | null;
  hasEnergyMetering: boolean;
  energyMeterChip?: string | null;
  maxRelayAmpsPerChannel: number;
  maxTotalAmps?: number;
  gpioMap?: Record<string, number>;
}

export interface ConnectivityProfile {
  schemaVersion: 1;
  supportsWifi: boolean;
  wifiStandards?: ('802.11b' | '802.11g' | '802.11n' | '802.11ax')[];
  supportsBle: boolean;
  bleVersion?: string | null;
  supportsThread: boolean;
  threadVersion?: string | null;
  supportsMatter: boolean;
  matterDeviceType?: string | null;
}

export interface ProductChannelMetadata {
  channelIndex: number;
  defaultLabel: string;
  capabilities: string[];
  config?: Record<string, any>;
}

export type ProductFamily =
  | 'smart_switch'
  | 'smart_socket'
  | 'smart_climate'
  | 'smart_lighting'
  | 'smart_sensor'
  | 'smart_controller';

export interface ProductMetadata {
  schemaVersion: 1;
  productVariantId: string;
  productFamily: ProductFamily;
  displayName: string;
  channelCount: number;
  channels: ProductChannelMetadata[];
  hardwareProfile: HardwareProfile;
  connectivityProfile: ConnectivityProfile;
  capabilities: string[];
  electricalSpecifications: {
    voltageRange: string;
    frequencyHz: string;
    maxCurrentPerChannelAmps?: number;
    maxTotalCurrentAmps?: number;
  };
  images?: Record<string, string>;
  firmwareFamily: string;
  supportedHardwareRevisions: string[];
}

export interface CapabilityPropertyDef {
  type: 'boolean' | 'integer' | 'number' | 'string' | 'object' | 'array';
  readable: boolean;
  writable: boolean;
  minimum?: number;
  maximum?: number;
  enum?: any[];
  unit?: string;
}

export interface CapabilityCommandDef {
  action: string;
  params?: Record<string, any>;
  description?: string;
}

export interface CapabilitySchema {
  schemaVersion: 1;
  capabilityId: string;
  version: number;
  displayName: string;
  description?: string;
  properties: Record<string, CapabilityPropertyDef>;
  commands: CapabilityCommandDef[];
  events: string[];
  telemetryFields?: string[];
  uiComponentHint: string;
  automationTriggers?: string[];
  automationActions?: string[];
}

export type ChannelConfidence =
  | 'UNKNOWN'
  | 'PENDING'
  | 'CONFIRMED'
  | 'FAILED'
  | 'UNAVAILABLE';

export interface ChannelState {
  schemaVersion: 1;
  channelIndex: number;
  desiredState?: Record<string, any>;
  reportedState: Record<string, any>;
  confidence: ChannelConfidence;
  updatedAt: string;
}

export type ConnectionState = 'ONLINE' | 'STALE' | 'OFFLINE';

export interface DeviceState {
  schemaVersion: 1;
  deviceId: string;
  connectionState: ConnectionState;
  channels: ChannelState[];
  lastSeenAt?: string | null;
  lastCommandId?: string | null;
  lastEventId?: string | null;
  updatedAt: string;
}

export type CommandSource =
  | 'APP'
  | 'PHYSICAL_SWITCH'
  | 'AUTOMATION'
  | 'MATTER'
  | 'VOICE'
  | 'SYSTEM';

export interface Command {
  schemaVersion: 1;
  commandId: string;
  deviceId: string;
  channelIndex: number;
  action: string;
  params: Record<string, any>;
  idempotencyKey: string;
  source: CommandSource;
  timestamp: string;
  expiresAt: string;
}

export type CommandReceiptStatus =
  | 'RECEIVED'
  | 'APPLIED'
  | 'FAILED'
  | 'OVERRIDDEN'
  | 'TIMEOUT'
  | 'EXPIRED';

export interface CommandReceipt {
  schemaVersion: 1;
  commandId: string;
  deviceId: string;
  channelIndex: number;
  status: CommandReceiptStatus;
  failureReason?: string | null;
  timestamp: string;
}

export interface DeviceEvent {
  schemaVersion: 1;
  eventId: string;
  deviceId: string;
  channelIndex: number;
  eventType: string;
  source: CommandSource;
  payload: Record<string, any>;
  timestamp: string;
  sequenceNumber: number;
}

export interface EnergyTelemetry {
  schemaVersion: 1;
  deviceId: string;
  channelIndex: number;
  v_mv: number;
  i_ma: number;
  p_mw: number;
  e_tot_wh: number;
  e_int_mwh: number;
  freq_mhz: number;
  pf_x1000: number;
  flags: number;
  timestamp: string;
  sequenceNumber: number;
}

export interface Telemetry {
  schemaVersion: 1;
  deviceId: string;
  energy?: EnergyTelemetry[];
  rssi?: number;
  freeHeapBytes?: number;
  uptimeSeconds?: number;
  timestamp: string;
  sequenceNumber: number;
}

export type AutomationExecutionPolicy =
  | 'DEVICE_LOCAL'
  | 'LOCAL_ONLY'
  | 'LOCAL_PREFERRED'
  | 'CLOUD_PREFERRED'
  | 'CLOUD_ONLY';

export interface AutomationTrigger {
  kind: string;
  deviceId?: string;
  channelIndex?: number;
  config: Record<string, any>;
}

export interface AutomationCondition {
  kind: string;
  config: Record<string, any>;
}

export interface AutomationAction {
  deviceId: string;
  channelIndex: number;
  action: string;
  params: Record<string, any>;
}

export interface AutomationRule {
  schemaVersion: 1;
  automationId: string;
  homeId: string;
  name: string;
  enabled: boolean;
  executionPolicy: AutomationExecutionPolicy;
  triggers: AutomationTrigger[];
  conditions: AutomationCondition[];
  actions: AutomationAction[];
}

export interface OTAManifest {
  schemaVersion: 1;
  releaseId: string;
  productVariantId: string;
  hardwareRevision: string;
  version: string;
  minFirmwareVersion: string;
  binarySizeBytes: number;
  sha256: string;
  ed25519Signature: string;
  downloadUrl: string;
  releaseNotes?: string | null;
  createdAt: string;
}

export interface UserProfile {
  schemaVersion: 1;
  id: string;
  email: string;
  emailVerified: boolean;
  createdAt: string;
}

export interface AuthTokenResponse {
  schemaVersion: 1;
  tokenType: 'Bearer';
  accessToken: string;
  refreshToken: string;
  expiresIn: number;
  user: UserProfile;
}

export type SSEEventType =
  | 'connection.ready'
  | 'device.state'
  | 'device.event'
  | 'device.availability'
  | 'command.receipt'
  | 'telemetry.update';

export interface SSEEventEnvelope<T = any> {
  schemaVersion: 1;
  eventId: string;
  type: SSEEventType;
  occurredAt: string;
  homeId: string;
  deviceId?: string | null;
  payload: T;
}

export interface ApiEnvelope<T = any> {
  success: boolean;
  data?: T;
  error?: {
    code: string;
    message: string;
    details?: Record<string, any>;
  };
  timestamp: string;
}

/**
 * Transport-Neutral Domain Interface
 */
export interface IDeviceTransport {
  sendCommand(cmd: Command): Promise<CommandReceipt>;
  getState(deviceId: string): Promise<DeviceState>;
  subscribeEvents(deviceId: string, callback: (event: DeviceEvent) => void): () => void;
  probeAvailability(deviceId: string): Promise<ConnectionState>;
}

export * from './notification';
export * from './authorization';
export * from './sync';
