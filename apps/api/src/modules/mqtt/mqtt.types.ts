/**
 * EH Home API — MQTT Transport Types
 */

import { CommandEnvelope, CommandReceipt } from '@eh-home/contracts';

export interface IDeviceTransport {
  sendCommand(cmd: CommandEnvelope): Promise<void>;
  probeAvailability(deviceId: string): Promise<{ deviceId: string; status?: string; probe: string }>;
  disconnect(): void;
  isReady: boolean;
}

export interface MqttTransportOptions {
  brokerUrl?: string;
  clientId?: string;
  ca?: string;
  cert?: string;
  key?: string;
  rejectUnauthorized?: boolean;
  mqttClient?: unknown;
  onReceipt?: (receipt: CommandReceipt) => void | Promise<void>;
  onState?: (statePayload: unknown) => void | Promise<void>;
  onEvent?: (eventPayload: unknown) => void | Promise<void>;
  onTelemetry?: (telemetryPayload: unknown) => void | Promise<void>;
  onAvailability?: (deviceId: string, availability: string) => void | Promise<void>;
  onOtaStatus?: (deviceId: string, otaPayload: unknown) => void | Promise<void>;
}

export interface MqttPublishOptions {
  qos?: 0 | 1 | 2;
  retain?: boolean;
}

export interface PublishedMqttMessage {
  topic: string;
  payload: unknown;
  opts?: MqttPublishOptions;
}
