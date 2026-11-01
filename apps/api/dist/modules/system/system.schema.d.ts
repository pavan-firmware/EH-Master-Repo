/**
 * System Module Schemas
 * Request & response validation contracts for the system module.
 */
import { z } from 'zod';
export declare const SystemInfoResponseSchema: z.ZodObject<{
    service: z.ZodLiteral<"eh-home-api">;
    version: z.ZodString;
    nodeVersion: z.ZodString;
    environment: z.ZodString;
    uptimeSeconds: z.ZodNumber;
    timestamp: z.ZodString;
}, "strip", z.ZodTypeAny, {
    version: string;
    service: "eh-home-api";
    nodeVersion: string;
    environment: string;
    uptimeSeconds: number;
    timestamp: string;
}, {
    version: string;
    service: "eh-home-api";
    nodeVersion: string;
    environment: string;
    uptimeSeconds: number;
    timestamp: string;
}>;
export type SystemInfoResponse = z.infer<typeof SystemInfoResponseSchema>;
export declare const EchoRequestSchema: z.ZodObject<{
    message: z.ZodString;
    metadata: z.ZodOptional<z.ZodRecord<z.ZodString, z.ZodUnknown>>;
}, "strip", z.ZodTypeAny, {
    message: string;
    metadata?: Record<string, unknown> | undefined;
}, {
    message: string;
    metadata?: Record<string, unknown> | undefined;
}>;
export type EchoRequest = z.infer<typeof EchoRequestSchema>;
export declare const EchoResponseSchema: z.ZodObject<{
    echo: z.ZodString;
    metadata: z.ZodOptional<z.ZodRecord<z.ZodString, z.ZodUnknown>>;
    receivedAt: z.ZodString;
}, "strip", z.ZodTypeAny, {
    echo: string;
    receivedAt: string;
    metadata?: Record<string, unknown> | undefined;
}, {
    echo: string;
    receivedAt: string;
    metadata?: Record<string, unknown> | undefined;
}>;
export type EchoResponse = z.infer<typeof EchoResponseSchema>;
//# sourceMappingURL=system.schema.d.ts.map