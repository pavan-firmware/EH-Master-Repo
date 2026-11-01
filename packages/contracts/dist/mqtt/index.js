"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.DeviceAvailabilityPayloadSchema = exports.DeviceAvailabilityStatusSchema = exports.CommandReceiptSchema = exports.CommandReceiptStatusSchema = exports.CommandEnvelopeSchema = exports.CommandActionSchema = exports.MqttTopicParser = exports.MqttTopicBuilder = exports.QOS_POLICY = exports.TOPIC_CATEGORIES = exports.TopicCategorySchema = exports.TOPIC_PREFIX = void 0;
const zod_1 = require("zod");
const common_1 = require("../common");
exports.TOPIC_PREFIX = 'eh/v1/devices';
exports.TopicCategorySchema = zod_1.z.enum([
    'commands',
    'command-receipts',
    'state',
    'events',
    'telemetry',
    'availability',
    'ota'
]);
exports.TOPIC_CATEGORIES = {
    COMMANDS: 'commands',
    COMMAND_RECEIPTS: 'command-receipts',
    STATE: 'state',
    EVENTS: 'events',
    TELEMETRY: 'telemetry',
    AVAILABILITY: 'availability',
    OTA: 'ota'
};
exports.QOS_POLICY = Object.freeze({
    commands: { qos: 1, retain: false },
    'command-receipts': { qos: 1, retain: false },
    state: { qos: 1, retain: false },
    events: { qos: 1, retain: false },
    telemetry: { qos: 0, retain: false },
    availability: { qos: 1, retain: true },
    ota: { qos: 1, retain: false }
});
const UUID_REGEX = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
function assertValidDeviceId(deviceId) {
    if (!deviceId || typeof deviceId !== 'string') {
        throw new Error('deviceId must be a non-empty string');
    }
    if (!UUID_REGEX.test(deviceId)) {
        throw new Error(`deviceId '${deviceId}' is not a canonical UUID`);
    }
}
function assertValidCategory(category) {
    const result = exports.TopicCategorySchema.safeParse(category);
    if (!result.success) {
        throw new Error(`Unknown topic category '${category}'. Valid categories: ${Object.values(exports.TOPIC_CATEGORIES).join(', ')}`);
    }
}
function assertNoWildcards(topic) {
    if (topic.includes('+') || topic.includes('#')) {
        throw new Error(`Topic '${topic}' must not contain MQTT wildcards ('+' or '#')`);
    }
}
exports.MqttTopicBuilder = Object.freeze({
    commands(deviceId) {
        assertValidDeviceId(deviceId);
        return `${exports.TOPIC_PREFIX}/${deviceId}/commands`;
    },
    commandReceipts(deviceId) {
        assertValidDeviceId(deviceId);
        return `${exports.TOPIC_PREFIX}/${deviceId}/command-receipts`;
    },
    state(deviceId) {
        assertValidDeviceId(deviceId);
        return `${exports.TOPIC_PREFIX}/${deviceId}/state`;
    },
    events(deviceId) {
        assertValidDeviceId(deviceId);
        return `${exports.TOPIC_PREFIX}/${deviceId}/events`;
    },
    telemetry(deviceId) {
        assertValidDeviceId(deviceId);
        return `${exports.TOPIC_PREFIX}/${deviceId}/telemetry`;
    },
    availability(deviceId) {
        assertValidDeviceId(deviceId);
        return `${exports.TOPIC_PREFIX}/${deviceId}/availability`;
    },
    ota(deviceId) {
        assertValidDeviceId(deviceId);
        return `${exports.TOPIC_PREFIX}/${deviceId}/ota`;
    },
    backendSubscribe(category) {
        assertValidCategory(category);
        return `${exports.TOPIC_PREFIX}/+/${category}`;
    },
    qosPolicy(category) {
        assertValidCategory(category);
        return exports.QOS_POLICY[category];
    }
});
exports.MqttTopicParser = Object.freeze({
    parse(topic) {
        if (!topic || typeof topic !== 'string') {
            throw new Error('Topic must be a non-empty string');
        }
        assertNoWildcards(topic);
        const segments = topic.split('/');
        if (segments.length !== 5) {
            throw new Error(`Topic '${topic}' has ${segments.length} segments; expected exactly 5 (eh/v1/devices/{deviceId}/{category})`);
        }
        for (let i = 0; i < segments.length; i++) {
            if (segments[i] === '') {
                throw new Error(`Topic '${topic}' contains an empty segment at position ${i}`);
            }
        }
        const prefix0 = segments[0];
        const prefix1 = segments[1];
        const prefix2 = segments[2];
        const deviceId = segments[3];
        const category = segments[4];
        if (prefix0 !== 'eh' || prefix1 !== 'v1' || prefix2 !== 'devices' || !deviceId || !category) {
            throw new Error(`Topic '${topic}' has incorrect prefix; expected 'eh/v1/devices/{deviceId}/{category}'`);
        }
        if (!UUID_REGEX.test(deviceId)) {
            throw new Error(`Topic '${topic}' contains malformed deviceId '${deviceId}'; expected canonical UUID`);
        }
        assertValidCategory(category);
        return { deviceId, category: category };
    },
    isValidForDevice(topic, deviceId) {
        try {
            const parsed = exports.MqttTopicParser.parse(topic);
            return parsed.deviceId === deviceId;
        }
        catch {
            return false;
        }
    }
});
exports.CommandActionSchema = zod_1.z.enum([
    'setPower',
    'set_power',
    'toggle_power',
    'setLevel',
    'setColorTemp',
    'identifyDevice',
    'otaUpdate'
]);
exports.CommandEnvelopeSchema = zod_1.z.object({
    schemaVersion: common_1.SchemaVersionSchema.default(1),
    commandId: zod_1.z.string().uuid(),
    deviceId: zod_1.z.string().uuid(),
    channelIndex: zod_1.z.number().int().min(1).max(16),
    action: exports.CommandActionSchema,
    params: zod_1.z.record(zod_1.z.unknown()).default({}),
    idempotencyKey: zod_1.z.string().min(1),
    source: zod_1.z.string().min(1).default('APP'),
    expiresAt: zod_1.z.string().datetime(),
    expiresAtUnixMs: zod_1.z.number().int().optional(),
    timestamp: zod_1.z.string().datetime().optional()
});
exports.CommandReceiptStatusSchema = zod_1.z.enum([
    'APPLIED',
    'FAILED',
    'EXPIRED',
    'OVERRIDDEN'
]);
exports.CommandReceiptSchema = zod_1.z.object({
    schemaVersion: common_1.SchemaVersionSchema.default(1),
    commandId: zod_1.z.string().uuid(),
    deviceId: zod_1.z.string().uuid(),
    channelIndex: zod_1.z.number().int().min(1).max(16),
    status: exports.CommandReceiptStatusSchema,
    failureReason: zod_1.z.string().nullable().optional(),
    timestamp: zod_1.z.string().datetime()
});
exports.DeviceAvailabilityStatusSchema = zod_1.z.enum(['ONLINE', 'OFFLINE']);
exports.DeviceAvailabilityPayloadSchema = zod_1.z.union([
    exports.DeviceAvailabilityStatusSchema,
    zod_1.z.object({
        status: exports.DeviceAvailabilityStatusSchema,
        timestamp: zod_1.z.string().datetime().optional(),
        reason: zod_1.z.string().optional()
    })
]);
//# sourceMappingURL=index.js.map