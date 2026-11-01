import { z } from 'zod';
import { SchemaVersionSchema } from '../common';

export const TOPIC_PREFIX = 'eh/v1/devices' as const;

export const TopicCategorySchema = z.enum([
  'commands',
  'command-receipts',
  'state',
  'events',
  'telemetry',
  'availability',
  'ota'
]);
export type TopicCategory = z.infer<typeof TopicCategorySchema>;

export const TOPIC_CATEGORIES = {
  COMMANDS: 'commands',
  COMMAND_RECEIPTS: 'command-receipts',
  STATE: 'state',
  EVENTS: 'events',
  TELEMETRY: 'telemetry',
  AVAILABILITY: 'availability',
  OTA: 'ota'
} as const;

export interface QosPolicy {
  qos: 0 | 1 | 2;
  retain: boolean;
}

export const QOS_POLICY: Record<TopicCategory, QosPolicy> = Object.freeze({
  commands: { qos: 1, retain: false },
  'command-receipts': { qos: 1, retain: false },
  state: { qos: 1, retain: false },
  events: { qos: 1, retain: false },
  telemetry: { qos: 0, retain: false },
  availability: { qos: 1, retain: true },
  ota: { qos: 1, retain: false }
});

const UUID_REGEX = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

function assertValidDeviceId(deviceId: string): void {
  if (!deviceId || typeof deviceId !== 'string') {
    throw new Error('deviceId must be a non-empty string');
  }
  if (!UUID_REGEX.test(deviceId)) {
    throw new Error(`deviceId '${deviceId}' is not a canonical UUID`);
  }
}

function assertValidCategory(category: string): asserts category is TopicCategory {
  const result = TopicCategorySchema.safeParse(category);
  if (!result.success) {
    throw new Error(`Unknown topic category '${category}'. Valid categories: ${Object.values(TOPIC_CATEGORIES).join(', ')}`);
  }
}

function assertNoWildcards(topic: string): void {
  if (topic.includes('+') || topic.includes('#')) {
    throw new Error(`Topic '${topic}' must not contain MQTT wildcards ('+' or '#')`);
  }
}

export const MqttTopicBuilder = Object.freeze({
  commands(deviceId: string): string {
    assertValidDeviceId(deviceId);
    return `${TOPIC_PREFIX}/${deviceId}/commands`;
  },
  commandReceipts(deviceId: string): string {
    assertValidDeviceId(deviceId);
    return `${TOPIC_PREFIX}/${deviceId}/command-receipts`;
  },
  state(deviceId: string): string {
    assertValidDeviceId(deviceId);
    return `${TOPIC_PREFIX}/${deviceId}/state`;
  },
  events(deviceId: string): string {
    assertValidDeviceId(deviceId);
    return `${TOPIC_PREFIX}/${deviceId}/events`;
  },
  telemetry(deviceId: string): string {
    assertValidDeviceId(deviceId);
    return `${TOPIC_PREFIX}/${deviceId}/telemetry`;
  },
  availability(deviceId: string): string {
    assertValidDeviceId(deviceId);
    return `${TOPIC_PREFIX}/${deviceId}/availability`;
  },
  ota(deviceId: string): string {
    assertValidDeviceId(deviceId);
    return `${TOPIC_PREFIX}/${deviceId}/ota`;
  },
  backendSubscribe(category: TopicCategory): string {
    assertValidCategory(category);
    return `${TOPIC_PREFIX}/+/${category}`;
  },
  qosPolicy(category: TopicCategory): QosPolicy {
    assertValidCategory(category);
    return QOS_POLICY[category];
  }
});

export interface ParsedTopic {
  deviceId: string;
  category: TopicCategory;
}

export const MqttTopicParser = Object.freeze({
  parse(topic: string): ParsedTopic {
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

    return { deviceId, category: category as TopicCategory };
  },

  isValidForDevice(topic: string, deviceId: string): boolean {
    try {
      const parsed = MqttTopicParser.parse(topic);
      return parsed.deviceId === deviceId;
    } catch {
      return false;
    }
  }
});

export const CommandActionSchema = z.enum([
  'setPower',
  'set_power',
  'toggle_power',
  'setLevel',
  'setColorTemp',
  'identifyDevice',
  'otaUpdate'
]);
export type CommandAction = z.infer<typeof CommandActionSchema>;

export const CommandEnvelopeSchema = z.object({
  schemaVersion: SchemaVersionSchema.default(1),
  commandId: z.string().uuid(),
  deviceId: z.string().uuid(),
  channelIndex: z.number().int().min(1).max(16),
  action: CommandActionSchema,
  params: z.record(z.unknown()).default({}),
  idempotencyKey: z.string().min(1),
  source: z.string().min(1).default('APP'),
  expiresAt: z.string().datetime(),
  expiresAtUnixMs: z.number().int().optional(),
  timestamp: z.string().datetime().optional()
});
export type CommandEnvelope = z.infer<typeof CommandEnvelopeSchema>;

export const CommandReceiptStatusSchema = z.enum([
  'APPLIED',
  'FAILED',
  'EXPIRED',
  'OVERRIDDEN'
]);
export type CommandReceiptStatus = z.infer<typeof CommandReceiptStatusSchema>;

export const CommandReceiptSchema = z.object({
  schemaVersion: SchemaVersionSchema.default(1),
  commandId: z.string().uuid(),
  deviceId: z.string().uuid(),
  channelIndex: z.number().int().min(1).max(16),
  status: CommandReceiptStatusSchema,
  failureReason: z.string().nullable().optional(),
  timestamp: z.string().datetime()
});
export type CommandReceipt = z.infer<typeof CommandReceiptSchema>;

export const DeviceAvailabilityStatusSchema = z.enum(['ONLINE', 'OFFLINE']);
export type DeviceAvailabilityStatus = z.infer<typeof DeviceAvailabilityStatusSchema>;

export const DeviceAvailabilityPayloadSchema = z.union([
  DeviceAvailabilityStatusSchema,
  z.object({
    status: DeviceAvailabilityStatusSchema,
    timestamp: z.string().datetime().optional(),
    reason: z.string().optional()
  })
]);
export type DeviceAvailabilityPayload = z.infer<typeof DeviceAvailabilityPayloadSchema>;
