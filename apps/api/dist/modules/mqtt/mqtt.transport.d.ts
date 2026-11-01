/**
 * EH Home API — MQTT Device Transport Implementation (Part 13)
 *
 * Implements IDeviceTransport with official mqtt client and MockMqttClient for tests.
 * Topics: eh/v1/devices/{deviceId}/{category}
 */
import { CommandEnvelope } from '@eh-home/contracts';
import { IDeviceTransport, MqttTransportOptions, MqttPublishOptions, PublishedMqttMessage } from './mqtt.types';
export declare class MockMqttClient {
    private subscriptions;
    private published;
    connected: boolean;
    private eventHandlers;
    publish(topic: string, payload: string | Buffer, opts?: MqttPublishOptions, cb?: (err?: Error | null) => void): void;
    subscribe(topic: string, opts?: {
        qos?: number;
    }, cb?: (err?: Error | null, granted?: any[]) => void): void;
    on(event: string, handler: (...args: any[]) => void): this;
    simulateMessage(topic: string, payloadObj: unknown): void;
    end(): void;
    getPublished(): PublishedMqttMessage[];
    clearPublished(): void;
}
export declare class MqttDeviceTransport implements IDeviceTransport {
    private onReceipt?;
    private onState?;
    private onEvent?;
    private onTelemetry?;
    private onAvailability?;
    private onOtaStatus?;
    private client;
    private ready;
    constructor(opts?: MqttTransportOptions);
    private bindClientEvents;
    sendCommand(cmd: CommandEnvelope): Promise<void>;
    probeAvailability(deviceId: string): Promise<{
        deviceId: string;
        status?: string;
        probe: string;
    }>;
    private setupBackendSubscriptions;
    private handleIncomingMessage;
    private publish;
    disconnect(): void;
    get isReady(): boolean;
    get rawClient(): any;
}
//# sourceMappingURL=mqtt.transport.d.ts.map