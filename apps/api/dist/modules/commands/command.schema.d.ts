import { z } from 'zod';
import { CommandEnvelopeSchema, CommandReceiptSchema, CommandActionSchema, DeviceAvailabilityStatusSchema } from '@eh-home/contracts';
export { CommandEnvelopeSchema, CommandReceiptSchema, CommandActionSchema, DeviceAvailabilityStatusSchema };
export declare const SendCommandRequestSchema: z.ZodObject<{
    commandId: z.ZodOptional<z.ZodString>;
    channelIndex: z.ZodDefault<z.ZodNumber>;
    action: z.ZodEnum<["setPower", "set_power", "toggle_power", "setLevel", "setColorTemp", "identifyDevice", "otaUpdate"]>;
    params: z.ZodDefault<z.ZodRecord<z.ZodString, z.ZodUnknown>>;
    idempotencyKey: z.ZodString;
    source: z.ZodDefault<z.ZodString>;
    expiresAt: z.ZodOptional<z.ZodString>;
}, "strip", z.ZodTypeAny, {
    params: Record<string, unknown>;
    channelIndex: number;
    action: "setPower" | "set_power" | "toggle_power" | "setLevel" | "setColorTemp" | "identifyDevice" | "otaUpdate";
    idempotencyKey: string;
    source: string;
    expiresAt?: string | undefined;
    commandId?: string | undefined;
}, {
    action: "setPower" | "set_power" | "toggle_power" | "setLevel" | "setColorTemp" | "identifyDevice" | "otaUpdate";
    idempotencyKey: string;
    params?: Record<string, unknown> | undefined;
    channelIndex?: number | undefined;
    expiresAt?: string | undefined;
    source?: string | undefined;
    commandId?: string | undefined;
}>;
export type SendCommandRequest = z.infer<typeof SendCommandRequestSchema>;
export declare const SendCommandResponseSchema: z.ZodObject<{
    commandId: z.ZodString;
    status: z.ZodEnum<["CREATED", "APPLIED", "FAILED", "EXPIRED", "OVERRIDDEN"]>;
    isIdempotentReplay: z.ZodBoolean;
    message: z.ZodOptional<z.ZodString>;
}, "strip", z.ZodTypeAny, {
    status: "FAILED" | "CREATED" | "APPLIED" | "EXPIRED" | "OVERRIDDEN";
    commandId: string;
    isIdempotentReplay: boolean;
    message?: string | undefined;
}, {
    status: "FAILED" | "CREATED" | "APPLIED" | "EXPIRED" | "OVERRIDDEN";
    commandId: string;
    isIdempotentReplay: boolean;
    message?: string | undefined;
}>;
export type SendCommandResponse = z.infer<typeof SendCommandResponseSchema>;
//# sourceMappingURL=command.schema.d.ts.map