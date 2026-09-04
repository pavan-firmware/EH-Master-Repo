export interface LocalExecutionRequest {
  commandId: string;
  deviceId: string;
  homeId: string;
  channelIndex?: number | null;
  action: 'setPower' | 'setLevel' | 'setColorTemp' | 'identifyDevice' | 'otaUpdate' | 'sceneActivate';
  params?: Record<string, any>;
  idempotencyKey: string;
  preferredRoute?: 'AUTO' | 'LOCAL_ONLY' | 'CLOUD_ONLY';
  maxTimeoutMs?: number;
  expiresAt?: string | null;
  actor?: {
    userId?: string;
    role?: string;
    source?: 'APP_LOCAL' | 'APP_CLOUD' | 'EDGE_AUTOMATION' | 'EDGE_SCENE' | 'EDGE_SCHEDULE';
  };
  createdAt: string;
}

export interface ExecutionRouteDecision {
  decisionId: string;
  deviceId: string;
  homeId: string;
  routeMode: 'LOCAL' | 'CLOUD' | 'DEFERRED' | 'UNAVAILABLE';
  selectedTransport: 'WIFI_MQTT' | 'BLE' | 'THREAD' | 'MATTER' | 'HTTP_LOCAL' | 'NONE';
  localEndpoint?: string | null;
  confidenceScore: number;
  fallbackOrder?: string[];
  isCloudAvailable: boolean;
  isLocalAvailable: boolean;
  decisionRationale: string;
  decidedAt: string;
}

export interface LocalConnectivityState {
  deviceId: string;
  homeId: string;
  isReachableLocally: boolean;
  transportType: 'WIFI_MQTT' | 'BLE' | 'THREAD' | 'MATTER' | 'HTTP_LOCAL';
  localIp?: string | null;
  localPort?: number | null;
  macAddress?: string | null;
  rssiDbm?: number | null;
  latencyEstimateMs?: number | null;
  authFingerprint?: string | null;
  isTlsSecured: boolean;
  lastSeenAt: string;
}

export interface LocalDeviceDiscovery {
  discoveryId: string;
  deviceId: string;
  homeId: string;
  productVariantId: string;
  macAddress: string;
  ipAddress: string;
  port: number;
  transportType: 'WIFI_MQTT' | 'BLE' | 'THREAD' | 'MATTER' | 'HTTP_LOCAL';
  protocolVersion?: string;
  firmwareVersion?: string;
  identityFingerprint: string;
  isTrusted: boolean;
  ttlSeconds?: number;
  discoveredAt: string;
}

export interface LocalExecutionResult {
  commandId: string;
  deviceId: string;
  channelIndex?: number | null;
  action: string;
  status: 'CONFIRMED' | 'PENDING' | 'FAILED' | 'DEFERRED' | 'UNAVAILABLE' | 'EXPIRED';
  routeUsed: 'LOCAL' | 'CLOUD' | 'DEFERRED' | 'UNAVAILABLE';
  transportUsed: 'WIFI_MQTT' | 'BLE' | 'THREAD' | 'MATTER' | 'HTTP_LOCAL' | 'NONE';
  isConfirmedByDevice: boolean;
  confirmedState?: Record<string, any>;
  latencyMs: number;
  errorMessage?: string | null;
  isIdempotentReplay?: boolean;
  queuedForCloudSync?: boolean;
  executedAt: string;
}

export interface LocalStateEvent {
  eventId: string;
  deviceId: string;
  homeId: string;
  channelIndex?: number | null;
  eventType: 'RELAY_STATE_CHANGED' | 'PHYSICAL_SWITCH_TOGGLED' | 'TELEMETRY_SAMPLE' | 'CONNECTIVITY_CHANGED' | 'DEVICE_RECOVERED';
  payload: Record<string, any>;
  source?: 'LOCAL_LAN' | 'LOCAL_BLE' | 'LOCAL_THREAD' | 'LOCAL_MATTER' | 'CLOUD_SYNC';
  timestamp: string;
}

export interface EdgeAutomationExecution {
  executionId: string;
  homeId: string;
  ruleType: 'AUTOMATION' | 'SCENE' | 'SCHEDULE';
  ruleId: string;
  ruleName?: string;
  triggerSource?: string;
  status: 'SUCCESS' | 'PARTIAL_SUCCESS' | 'FAILED' | 'SKIPPED_MANUAL_OVERRIDE' | 'SKIPPED_DEBOUNCE';
  actionsTotal: number;
  actionsSuccessful: number;
  actionsFailed: number;
  actionResults?: Record<string, any>[];
  executionDurationMs: number;
  executedAt: string;
}
