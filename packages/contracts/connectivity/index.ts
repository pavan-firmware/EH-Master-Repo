/**
 * Phase 26 Multi-Protocol Connectivity TypeScript Interfaces
 * EH Home — Multi-Protocol Device Connectivity & Interoperability
 */

export type DeviceTransportType = 'WIFI_MQTT' | 'BLE' | 'THREAD' | 'MATTER';

export type TransportAvailability = 'ONLINE' | 'DEGRADED' | 'UNREACHABLE' | 'UNCONFIGURED';

export type DeviceConnectionState =
  | 'DISCOVERING'
  | 'COMMISSIONING'
  | 'CONNECTING'
  | 'CONNECTED'
  | 'DEGRADED'
  | 'RECONNECTING'
  | 'DISCONNECTED'
  | 'FAILED'
  | 'DECOMMISSIONED';

export type CommissioningStage =
  | 'DISCOVERED'
  | 'READY'
  | 'STARTED'
  | 'AUTHENTICATING'
  | 'NETWORK_JOINING'
  | 'VERIFYING'
  | 'COMPLETED'
  | 'FAILED'
  | 'CANCELLED';

export interface TransportCapability {
  transportType: DeviceTransportType;
  isSupported: boolean;
  isConfigured: boolean;
  priorityRank: number;
  directIp?: boolean;
  meshCapable?: boolean;
  lowPower?: boolean;
  localOnly?: boolean;
  maxPayloadBytes?: number;
}

export interface TransportHealth {
  transportType: DeviceTransportType;
  availability: TransportAvailability;
  latencyMs: number;
  errorRate: number;
  reconnectCount: number;
  lastSuccessfulCommand?: string | null;
  lastSuccessfulTelemetry?: string | null;
  signalRssi?: number | null;
  metrics?: Record<string, any> | null;
}

export interface DeviceConnectionSnapshot {
  deviceId: string;
  homeId: string;
  activeTransport: DeviceTransportType;
  connectionState: DeviceConnectionState;
  supportedTransports: DeviceTransportType[];
  transportHealth: Record<string, TransportHealth>;
  lastSelectedReason?: string | null;
  reconnectCount?: number;
  lastConnectedAt?: string | null;
  lastDisconnectedAt?: string | null;
  updatedAt: string;
}

export interface TransportSelection {
  deviceId: string;
  selectedTransport: DeviceTransportType;
  reason: string;
  confidence: number;
  fallbackOrder: DeviceTransportType[];
  evaluatedAt?: string;
}

export interface TransportFallbackPolicy {
  preferredOrder: DeviceTransportType[];
  retryBudget: number;
  timeoutMs: number;
  verifyBeforeFallback: boolean;
}

export interface DeviceDiscoveryResult {
  provisionalIdentity: string;
  protocol: DeviceTransportType;
  deviceModel?: string | null;
  vendorId?: string | null;
  productId?: string | null;
  discriminator?: number | null;
  isCommissionable: boolean;
  signalStrength?: number | null;
  metadata?: Record<string, any> | null;
  discoveredAt: string;
}

export interface CommissioningSession {
  sessionId: string;
  homeId: string;
  deviceId: string;
  transportType: DeviceTransportType;
  stage: CommissioningStage;
  authMethod?: string | null;
  errorDetails?: string | null;
  startedAt: string;
  completedAt?: string | null;
}

export interface CommissioningResult {
  sessionId: string;
  deviceId: string;
  homeId: string;
  transportType: DeviceTransportType;
  success: boolean;
  assignedNetwork?: string | null;
  error?: string | null;
  completedAt: string;
}
