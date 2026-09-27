/**
 * EH Home API — MQTT Device Transport Implementation (Part 13)
 *
 * Implements IDeviceTransport with official mqtt client and MockMqttClient for tests.
 * Topics: eh/v1/devices/{deviceId}/{category}
 */

import {
  MqttTopicBuilder,
  MqttTopicParser,
  CommandEnvelope,
  CommandReceipt,
  TopicCategory
} from '@eh-home/contracts';
import {
  IDeviceTransport,
  MqttTransportOptions,
  MqttPublishOptions,
  PublishedMqttMessage
} from './mqtt.types';

export class MockMqttClient {
  private subscriptions: Map<string, Array<(topic: string, message: Buffer) => void>> = new Map();
  private published: PublishedMqttMessage[] = [];
  public connected = true;
  private eventHandlers: Record<string, Array<(...args: any[]) => void>> = {};

  publish(topic: string, payload: string | Buffer, opts?: MqttPublishOptions, cb?: (err?: Error | null) => void): void {
    let parsedPayload: unknown;
    try {
      parsedPayload = JSON.parse(payload.toString());
    } catch {
      parsedPayload = payload.toString();
    }
    this.published.push({ topic, payload: parsedPayload, opts });
    if (typeof cb === 'function') cb(null);
  }

  subscribe(topic: string, opts?: { qos?: number }, cb?: (err?: Error | null, granted?: any[]) => void): void {
    if (!this.subscriptions.has(topic)) {
      this.subscriptions.set(topic, []);
    }
    if (typeof cb === 'function') cb(null, [{ topic, qos: opts?.qos || 1 }]);
  }

  on(event: string, handler: (...args: any[]) => void): this {
    if (event === 'connect') {
      setImmediate(() => handler());
    }
    if (!this.eventHandlers[event]) {
      this.eventHandlers[event] = [];
    }
    this.eventHandlers[event].push(handler);
    return this;
  }

  simulateMessage(topic: string, payloadObj: unknown): void {
    const payloadBuf = Buffer.from(typeof payloadObj === 'string' ? payloadObj : JSON.stringify(payloadObj));
    const handlers = this.eventHandlers['message'] || [];
    handlers.forEach((h) => h(topic, payloadBuf, {}));
  }

  end(): void {
    this.connected = false;
  }

  getPublished(): PublishedMqttMessage[] {
    return [...this.published];
  }

  clearPublished(): void {
    this.published = [];
  }
}

export class MqttDeviceTransport implements IDeviceTransport {
  private onReceipt?: (receipt: CommandReceipt) => void | Promise<void>;
  private onState?: (statePayload: unknown) => void | Promise<void>;
  private onEvent?: (eventPayload: unknown) => void | Promise<void>;
  private onTelemetry?: (telemetryPayload: unknown) => void | Promise<void>;
  private onAvailability?: (deviceId: string, availability: string) => void | Promise<void>;
  private onOtaStatus?: (deviceId: string, otaPayload: unknown) => void | Promise<void>;

  private client: any;
  private ready = false;

  constructor(opts: MqttTransportOptions = {}) {
    this.onReceipt = opts.onReceipt;
    this.onState = opts.onState;
    this.onEvent = opts.onEvent;
    this.onTelemetry = opts.onTelemetry;
    this.onAvailability = opts.onAvailability;
    this.onOtaStatus = opts.onOtaStatus;

    if (opts.mqttClient) {
      this.client = opts.mqttClient;
      this.bindClientEvents();
    } else if (process.env.NODE_ENV === 'test' && !opts.brokerUrl) {
      this.client = new MockMqttClient();
      this.bindClientEvents();
    } else {
      let mqttModule: any;
      try {
        mqttModule = require('mqtt');
      } catch {
        // Fallback for mock environments if mqtt package is not linked
        mqttModule = {
          connect: () => new MockMqttClient()
        };
      }

      const brokerUrl = opts.brokerUrl || process.env.MQTT_BROKER_URL || 'mqtt://127.0.0.1:1883';
      const connectOpts: Record<string, unknown> = {
        clientId: opts.clientId || `backend_api_${Math.floor(Math.random() * 100000)}`,
        clean: true,
        connectTimeout: 10000,
        reconnectPeriod: 2000,
        rejectUnauthorized: opts.rejectUnauthorized !== undefined ? opts.rejectUnauthorized : true
      };

      if (opts.ca) connectOpts.ca = opts.ca;
      if (opts.cert) connectOpts.cert = opts.cert;
      if (opts.key) connectOpts.key = opts.key;

      this.client = mqttModule.connect(brokerUrl, connectOpts);
      this.bindClientEvents();
    }
  }

  private bindClientEvents(): void {
    if (!this.client) return;

    this.client.on('connect', () => {
      this.ready = true;
      this.setupBackendSubscriptions();
    });

    this.client.on('message', (topic: string, buf: Buffer) => {
      this.handleIncomingMessage(topic, buf);
    });

    this.client.on('error', (err: Error) => {
      if (!this.ready || (err.message && err.message.includes('write after end'))) {
        return;
      }
      console.error('[MqttDeviceTransport] Client error:', err.message);
    });

    this.client.on('close', () => {
      this.ready = false;
    });
  }

  public async sendCommand(cmd: CommandEnvelope): Promise<void> {
    if (!cmd || !cmd.deviceId || !cmd.commandId) {
      throw new Error('MqttDeviceTransport.sendCommand: command must have deviceId and commandId');
    }

    const topic = MqttTopicBuilder.commands(cmd.deviceId);
    const policy = MqttTopicBuilder.qosPolicy('commands');
    const payload = JSON.stringify(cmd);

    await this.publish(topic, payload, policy);
  }

  public async probeAvailability(deviceId: string): Promise<{ deviceId: string; status?: string; probe: string }> {
    return { deviceId, probe: 'availability-check-via-retained-topic' };
  }

  private async setupBackendSubscriptions(): Promise<void> {
    const inboundCategories: TopicCategory[] = [
      'command-receipts',
      'state',
      'events',
      'telemetry',
      'availability',
      'ota'
    ];

    for (const category of inboundCategories) {
      const topic = MqttTopicBuilder.backendSubscribe(category);
      const policy = MqttTopicBuilder.qosPolicy(category);
      this.client.subscribe(topic, { qos: policy.qos }, (err: Error | null) => {
        if (err) {
          console.error(`[MqttDeviceTransport] Failed to subscribe to ${topic}:`, err.message);
        }
      });
    }
  }

  private handleIncomingMessage(topic: string, buf: Buffer): void {
    let parsed;
    try {
      parsed = MqttTopicParser.parse(topic);
    } catch (err: any) {
      console.warn(`[MqttDeviceTransport] Dropped message on invalid topic '${topic}': ${err.message}`);
      return;
    }

    let payload: any;
    try {
      payload = JSON.parse(buf.toString('utf8'));
    } catch {
      if (parsed.category === 'availability') {
        payload = buf.toString('utf8').replace(/^"|"$/g, '');
      } else {
        console.warn(`[MqttDeviceTransport] Dropped malformed JSON on topic '${topic}'`);
        return;
      }
    }

    const { deviceId, category } = parsed;

    switch (category) {
      case 'command-receipts':
        if (this.onReceipt) this.onReceipt(payload);
        break;
      case 'state':
        if (this.onState) this.onState(payload);
        break;
      case 'events':
        if (this.onEvent) this.onEvent(payload);
        break;
      case 'telemetry':
        if (this.onTelemetry) this.onTelemetry(payload);
        break;
      case 'availability': {
        const availStr = typeof payload === 'string' ? payload : (payload.status || 'OFFLINE');
        if (this.onAvailability) this.onAvailability(deviceId, availStr);
        break;
      }
      case 'ota':
        if (this.onOtaStatus) this.onOtaStatus(deviceId, payload);
        break;
      default:
        break;
    }
  }

  private publish(topic: string, payload: string, policy: { qos: 0 | 1 | 2; retain: boolean }): Promise<void> {
    return new Promise((resolve, reject) => {
      this.client.publish(
        topic,
        payload,
        { qos: policy.qos, retain: policy.retain },
        (err?: Error | null) => {
          if (err) {
            reject(new Error(`MqttDeviceTransport publish failed on '${topic}': ${err.message}`));
          } else {
            resolve();
          }
        }
      );
    });
  }

  public disconnect(): void {
    if (this.client && typeof this.client.end === 'function') {
      this.client.end();
      this.ready = false;
    }
  }

  public get isReady(): boolean {
    return this.ready;
  }

  public get rawClient(): any {
    return this.client;
  }
}
