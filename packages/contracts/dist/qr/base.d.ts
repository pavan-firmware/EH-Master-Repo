import { z } from 'zod';
export declare const OpaqueTokenRegex: RegExp;
export declare const QrUriRegex: RegExp;
export declare const OpaqueQrTokenSchema: z.ZodString;
export type OpaqueQrToken = z.infer<typeof OpaqueQrTokenSchema>;
export declare const QrUriSchema: z.ZodString;
export type QrUri = z.infer<typeof QrUriSchema>;
export declare const QrPayloadSchema: z.ZodEffects<z.ZodObject<{
    schemaVersion: z.ZodDefault<z.ZodNumber>;
    token: z.ZodString;
    qrUri: z.ZodString;
    generatedAt: z.ZodString;
}, "strip", z.ZodTypeAny, {
    schemaVersion: number;
    generatedAt: string;
    token: string;
    qrUri: string;
}, {
    generatedAt: string;
    token: string;
    qrUri: string;
    schemaVersion?: number | undefined;
}>, {
    schemaVersion: number;
    generatedAt: string;
    token: string;
    qrUri: string;
}, {
    generatedAt: string;
    token: string;
    qrUri: string;
    schemaVersion?: number | undefined;
}>;
export type QrPayload = z.infer<typeof QrPayloadSchema>;
export declare const QrCodeRecordSchema: z.ZodObject<{
    schemaVersion: z.ZodDefault<z.ZodNumber>;
    qrId: z.ZodString;
    deviceId: z.ZodString;
    token: z.ZodString;
    qrUri: z.ZodString;
    printedStatus: z.ZodDefault<z.ZodEnum<["PENDING", "PRINTED", "REPRINTED"]>>;
    claimedStatus: z.ZodDefault<z.ZodEnum<["UNCLAIMED", "CLAIMED"]>>;
    claimedAt: z.ZodOptional<z.ZodString>;
    createdAt: z.ZodString;
}, "strip", z.ZodTypeAny, {
    schemaVersion: number;
    createdAt: string;
    deviceId: string;
    token: string;
    qrUri: string;
    qrId: string;
    printedStatus: "PENDING" | "PRINTED" | "REPRINTED";
    claimedStatus: "CLAIMED" | "UNCLAIMED";
    claimedAt?: string | undefined;
}, {
    createdAt: string;
    deviceId: string;
    token: string;
    qrUri: string;
    qrId: string;
    schemaVersion?: number | undefined;
    printedStatus?: "PENDING" | "PRINTED" | "REPRINTED" | undefined;
    claimedStatus?: "CLAIMED" | "UNCLAIMED" | undefined;
    claimedAt?: string | undefined;
}>;
export type QrCodeRecord = z.infer<typeof QrCodeRecordSchema>;
//# sourceMappingURL=base.d.ts.map