"use strict";
/**
 * EH Home API — MQTT Device Transport Implementation (Part 13)
 *
 * Implements IDeviceTransport with official mqtt client and MockMqttClient for tests.
 * Topics: eh/v1/devices/{deviceId}/{category}
 */
Object.defineProperty(exports, "__esModule", { value: true });
exports.MqttDeviceTransport = exports.MockMqttClient = void 0;
const contracts_1 = require("@eh-home/contracts");
class MockMqttClient {
    subscriptions = new Map();
    published = [];
    connected = true;
    eventHandlers = {};
    publish(topic, payload, opts, cb) {
        let parsedPayload;
        try {
            parsedPayload = JSON.parse(payload.toString());
        }
        catch {
            parsedPayload = payload.toString();
        }
        this.published.push({ topic, payload: parsedPayload, opts });
        if (typeof cb === 'function')
            cb(null);
    }
    subscribe(topic, opts, cb) {
        if (!this.subscriptions.has(topic)) {
            this.subscriptions.set(topic, []);
        }
        if (typeof cb === 'function')
            cb(null, [{ topic, qos: opts?.qos || 1 }]);
    }
    on(event, handler) {
        if (event === 'connect') {
            setImmediate(() => handler());
        }
        if (!this.eventHandlers[event]) {
            this.eventHandlers[event] = [];
        }
        this.eventHandlers[event].push(handler);
        return this;
    }
    simulateMessage(topic, payloadObj) {
        const payloadBuf = Buffer.from(typeof payloadObj === 'string' ? payloadObj : JSON.stringify(payloadObj));
        const handlers = this.eventHandlers['message'] || [];
        handlers.forEach((h) => h(topic, payloadBuf, {}));
    }
    end() {
        this.connected = false;
    }
    getPublished() {
        return [...this.published];
    }
    clearPublished() {
        this.published = [];
    }
}
exports.MockMqttClient = MockMqttClient;
class MqttDeviceTransport {
    onReceipt;
    onState;
    onEvent;
    onTelemetry;
    onAvailability;
    onOtaStatus;
    client;
    ready = false;
    constructor(opts = {}) {
        this.onReceipt = opts.onReceipt;
        this.onState = opts.onState;
        this.onEvent = opts.onEvent;
        this.onTelemetry = opts.onTelemetry;
        this.onAvailability = opts.onAvailability;
        this.onOtaStatus = opts.onOtaStatus;
        if (opts.mqttClient) {
            this.client = opts.mqttClient;
            this.bindClientEvents();
        }
        else if (process.env.NODE_ENV === 'test' && !opts.brokerUrl) {
            this.client = new MockMqttClient();
            this.bindClientEvents();
        }
        else {
            let mqttModule;
            try {
                mqttModule = require('mqtt');
            }
            catch {
                // Fallback for mock environments if mqtt package is not linked
                mqttModule = {
                    connect: () => new MockMqttClient()
                };
            }
            const brokerUrl = opts.brokerUrl || process.env.MQTT_BROKER_URL || 'mqtt://127.0.0.1:1883';
            const connectOpts = {
                clientId: opts.clientId || `backend_api_${Math.floor(Math.random() * 100000)}`,
                clean: true,
                connectTimeout: 10000,
                reconnectPeriod: 2000,
                rejectUnauthorized: opts.rejectUnauthorized !== undefined ? opts.rejectUnauthorized : true
            };
            if (opts.ca)
                connectOpts.ca = opts.ca;
            if (opts.cert)
                connectOpts.cert = opts.cert;
            if (opts.key)
                connectOpts.key = opts.key;
            this.client = mqttModule.connect(brokerUrl, connectOpts);
            this.bindClientEvents();
        }
    }
    bindClientEvents() {
        if (!this.client)
            return;
        this.client.on('connect', () => {
            this.ready = true;
            this.setupBackendSubscriptions();
        });
        this.client.on('message', (topic, buf) => {
            this.handleIncomingMessage(topic, buf);
        });
        this.client.on('error', (err) => {
            if (!this.ready || (err.message && err.message.includes('write after end'))) {
                return;
            }
            console.error('[MqttDeviceTransport] Client error:', err.message);
        });
        this.client.on('close', () => {
            this.ready = false;
        });
    }
    async sendCommand(cmd) {
        if (!cmd || !cmd.deviceId || !cmd.commandId) {
            throw new Error('MqttDeviceTransport.sendCommand: command must have deviceId and commandId');
        }
        const topic = contracts_1.MqttTopicBuilder.commands(cmd.deviceId);
        const policy = contracts_1.MqttTopicBuilder.qosPolicy('commands');
        const payload = JSON.stringify(cmd);
        await this.publish(topic, payload, policy);
    }
    async probeAvailability(deviceId) {
        return { deviceId, probe: 'availability-check-via-retained-topic' };
    }
    async setupBackendSubscriptions() {
        const inboundCategories = [
            'command-receipts',
            'state',
            'events',
            'telemetry',
            'availability',
            'ota'
        ];
        for (const category of inboundCategories) {
            const topic = contracts_1.MqttTopicBuilder.backendSubscribe(category);
            const policy = contracts_1.MqttTopicBuilder.qosPolicy(category);
            this.client.subscribe(topic, { qos: policy.qos }, (err) => {
                if (err) {
                    console.error(`[MqttDeviceTransport] Failed to subscribe to ${topic}:`, err.message);
                }
            });
        }
    }
    handleIncomingMessage(topic, buf) {
        let parsed;
        try {
            parsed = contracts_1.MqttTopicParser.parse(topic);
        }
        catch (err) {
            console.warn(`[MqttDeviceTransport] Dropped message on invalid topic '${topic}': ${err.message}`);
            return;
        }
        let payload;
        try {
            payload = JSON.parse(buf.toString('utf8'));
        }
        catch {
            if (parsed.category === 'availability') {
                payload = buf.toString('utf8').replace(/^"|"$/g, '');
            }
            else {
                console.warn(`[MqttDeviceTransport] Dropped malformed JSON on topic '${topic}'`);
                return;
            }
        }
        const { deviceId, category } = parsed;
        switch (category) {
            case 'command-receipts':
                if (this.onReceipt)
                    this.onReceipt(payload);
                break;
            case 'state':
                if (this.onState)
                    this.onState(payload);
                break;
            case 'events':
                if (this.onEvent)
                    this.onEvent(payload);
                break;
            case 'telemetry':
                if (this.onTelemetry)
                    this.onTelemetry(payload);
                break;
            case 'availability': {
                const availStr = typeof payload === 'string' ? payload : (payload.status || 'OFFLINE');
                if (this.onAvailability)
                    this.onAvailability(deviceId, availStr);
                break;
            }
            case 'ota':
                if (this.onOtaStatus)
                    this.onOtaStatus(deviceId, payload);
                break;
            default:
                break;
        }
    }
    publish(topic, payload, policy) {
        return new Promise((resolve, reject) => {
            this.client.publish(topic, payload, { qos: policy.qos, retain: policy.retain }, (err) => {
                if (err) {
                    reject(new Error(`MqttDeviceTransport publish failed on '${topic}': ${err.message}`));
                }
                else {
                    resolve();
                }
            });
        });
    }
    disconnect() {
        if (this.client && typeof this.client.end === 'function') {
            this.client.end();
            this.ready = false;
        }
    }
    get isReady() {
        return this.ready;
    }
    get rawClient() {
        return this.client;
    }
}
exports.MqttDeviceTransport = MqttDeviceTransport;
//# sourceMappingURL=mqtt.transport.js.map