import { z } from 'zod';
export declare const TOPIC_PREFIX: "eh/v1/devices";
export declare const TopicCategorySchema: z.ZodEnum<["commands", "command-receipts", "state", "events", "telemetry", "availability", "ota"]>;
export type TopicCategory = z.infer<typeof TopicCategorySchema>;
export declare const TOPIC_CATEGORIES: {
    readonly COMMANDS: "commands";
    readonly COMMAND_RECEIPTS: "command-receipts";
    readonly STATE: "state";
    readonly EVENTS: "events";
    readonly TELEMETRY: "telemetry";
    readonly AVAILABILITY: "availability";
    readonly OTA: "ota";
};
export interface QosPolicy {
    qos: 0 | 1 | 2;
    retain: boolean;
}
export declare const QOS_POLICY: Record<TopicCategory, QosPolicy>;
export declare const MqttTopicBuilder: Readonly<{
    commands(deviceId: string): string;
    commandReceipts(deviceId: string): string;
    state(deviceId: string): string;
    events(deviceId: string): string;
    telemetry(deviceId: string): string;
    availability(deviceId: string): string;
    ota(deviceId: string): string;
    backendSubscribe(category: TopicCategory): string;
    qosPolicy(category: TopicCategory): QosPolicy;
}>;
export interface ParsedTopic {
    deviceId: string;
    category: TopicCategory;
}
export declare const MqttTopicParser: Readonly<{
    parse(topic: string): ParsedTopic;
    isValidForDevice(topic: string, deviceId: string): boolean;
}>;
export declare const CommandActionSchema: z.ZodEnum<["setPower", "set_power", "toggle_power", "setLevel", "setColorTemp", "identifyDevice", "otaUpdate"]>;
export type CommandAction = z.infer<typeof CommandActionSchema>;
export declare const CommandEnvelopeSchema: z.ZodObject<{
    schemaVersion: z.ZodDefault<z.ZodDefault<z.ZodNumber>>;
    commandId: z.ZodString;
    deviceId: z.ZodString;
    channelIndex: z.ZodNumber;
    action: z.ZodEnum<["setPower", "set_power", "toggle_power", "setLevel", "setColorTemp", "identifyDevice", "otaUpdate"]>;
    params: z.ZodDefault<z.ZodRecord<z.ZodString, z.ZodUnknown>>;
    idempotencyKey: z.ZodString;
    source: z.ZodDefault<z.ZodString>;
    expiresAt: z.ZodString;
    expiresAtUnixMs: z.ZodOptional<z.ZodNumber>;
    timestamp: z.ZodOptional<z.ZodString>;
}, "strip", z.ZodTypeAny, {
    params: Record<string, unknown>;
    schemaVersion: number;
    channelIndex: number;
    deviceId: string;
    commandId: string;
    action: "setPower" | "set_power" | "toggle_power" | "setLevel" | "setColorTemp" | "identifyDevice" | "otaUpdate";
    idempotencyKey: string;
    source: string;
    expiresAt: string;
    timestamp?: string | undefined;
    expiresAtUnixMs?: number | undefined;
}, {
    channelIndex: number;
    deviceId: string;
    commandId: string;
    action: "setPower" | "set_power" | "toggle_power" | "setLevel" | "setColorTemp" | "identifyDevice" | "otaUpdate";
    idempotencyKey: string;
    expiresAt: string;
    params?: Record<string, unknown> | undefined;
    schemaVersion?: number | undefined;
    timestamp?: string | undefined;
    source?: string | undefined;
    expiresAtUnixMs?: number | undefined;
}>;
export type CommandEnvelope = z.infer<typeof CommandEnvelopeSchema>;
export declare const CommandReceiptStatusSchema: z.ZodEnum<["APPLIED", "FAILED", "EXPIRED", "OVERRIDDEN"]>;
export type CommandReceiptStatus = z.infer<typeof CommandReceiptStatusSchema>;
export declare const CommandReceiptSchema: z.ZodObject<{
    schemaVersion: z.ZodDefault<z.ZodDefault<z.ZodNumber>>;
    commandId: z.ZodString;
    deviceId: z.ZodString;
    channelIndex: z.ZodNumber;
    status: z.ZodEnum<["APPLIED", "FAILED", "EXPIRED", "OVERRIDDEN"]>;
    failureReason: z.ZodOptional<z.ZodNullable<z.ZodString>>;
    timestamp: z.ZodString;
}, "strip", z.ZodTypeAny, {
    status: "FAILED" | "APPLIED" | "EXPIRED" | "OVERRIDDEN";
    schemaVersion: number;
    timestamp: string;
    channelIndex: number;
    deviceId: string;
    commandId: string;
    failureReason?: string | null | undefined;
}, {
    status: "FAILED" | "APPLIED" | "EXPIRED" | "OVERRIDDEN";
    timestamp: string;
    channelIndex: number;
    deviceId: string;
    commandId: string;
    schemaVersion?: number | undefined;
    failureReason?: string | null | undefined;
}>;
export type CommandReceipt = z.infer<typeof CommandReceiptSchema>;
export declare const DeviceAvailabilityStatusSchema: z.ZodEnum<["ONLINE", "OFFLINE"]>;
export type DeviceAvailabilityStatus = z.infer<typeof DeviceAvailabilityStatusSchema>;
export declare const DeviceAvailabilityPayloadSchema: z.ZodUnion<[z.ZodEnum<["ONLINE", "OFFLINE"]>, z.ZodObject<{
    status: z.ZodEnum<["ONLINE", "OFFLINE"]>;
    timestamp: z.ZodOptional<z.ZodString>;
    reason: z.ZodOptional<z.ZodString>;
}, "strip", z.ZodTypeAny, {
    status: "ONLINE" | "OFFLINE";
    timestamp?: string | undefined;
    reason?: string | undefined;
}, {
    status: "ONLINE" | "OFFLINE";
    timestamp?: string | undefined;
    reason?: string | undefined;
}>]>;
export type DeviceAvailabilityPayload = z.infer<typeof DeviceAvailabilityPayloadSchema>;
//# sourceMappingURL=index.d.ts.map