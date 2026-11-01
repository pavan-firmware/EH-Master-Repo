import { z } from 'zod';
export declare const OtaExecutionStateSchema: z.ZodEnum<["REQUESTED", "AUTHORIZED", "AVAILABLE", "DOWNLOADING", "VERIFYING", "INSTALLING", "SUCCEEDED", "FAILED", "ROLLED_BACK", "CANCELLED"]>;
export type OtaExecutionState = z.infer<typeof OtaExecutionStateSchema>;
export declare const OTA_TERMINAL_STATES: ReadonlySet<OtaExecutionState>;
export declare const OTA_STATE_TRANSITIONS: Record<OtaExecutionState, readonly OtaExecutionState[]>;
export declare function isValidOtaStateTransition(current: OtaExecutionState, next: OtaExecutionState): boolean;
export declare function validateOtaStateTransition(current: OtaExecutionState, next: OtaExecutionState): void;
export declare const OtaJobStatusUpdateRequestSchema: z.ZodObject<{
    jobId: z.ZodString;
    status: z.ZodEnum<["REQUESTED", "AUTHORIZED", "AVAILABLE", "DOWNLOADING", "VERIFYING", "INSTALLING", "SUCCEEDED", "FAILED", "ROLLED_BACK", "CANCELLED"]>;
    progressPercent: z.ZodOptional<z.ZodNumber>;
    errorCode: z.ZodOptional<z.ZodString>;
    errorMessage: z.ZodOptional<z.ZodString>;
}, "strip", z.ZodTypeAny, {
    status: "CANCELLED" | "FAILED" | "AVAILABLE" | "REQUESTED" | "AUTHORIZED" | "DOWNLOADING" | "VERIFYING" | "INSTALLING" | "SUCCEEDED" | "ROLLED_BACK";
    jobId: string;
    errorCode?: string | undefined;
    errorMessage?: string | undefined;
    progressPercent?: number | undefined;
}, {
    status: "CANCELLED" | "FAILED" | "AVAILABLE" | "REQUESTED" | "AUTHORIZED" | "DOWNLOADING" | "VERIFYING" | "INSTALLING" | "SUCCEEDED" | "ROLLED_BACK";
    jobId: string;
    errorCode?: string | undefined;
    errorMessage?: string | undefined;
    progressPercent?: number | undefined;
}>;
export type OtaJobStatusUpdateRequest = z.infer<typeof OtaJobStatusUpdateRequestSchema>;
export declare const OtaJobCreateRequestSchema: z.ZodObject<{
    deviceId: z.ZodString;
    releaseId: z.ZodString;
    rolloutId: z.ZodOptional<z.ZodString>;
    fromVersion: z.ZodString;
}, "strip", z.ZodTypeAny, {
    releaseId: string;
    deviceId: string;
    fromVersion: string;
    rolloutId?: string | undefined;
}, {
    releaseId: string;
    deviceId: string;
    fromVersion: string;
    rolloutId?: string | undefined;
}>;
export type OtaJobCreateRequest = z.infer<typeof OtaJobCreateRequestSchema>;
export declare const OtaCheckUpdateRequestSchema: z.ZodObject<{
    deviceId: z.ZodOptional<z.ZodString>;
    productVariantId: z.ZodString;
    hardwareRevision: z.ZodString;
    currentVersion: z.ZodString;
}, "strip", z.ZodTypeAny, {
    productVariantId: string;
    hardwareRevision: string;
    currentVersion: string;
    deviceId?: string | undefined;
}, {
    productVariantId: string;
    hardwareRevision: string;
    currentVersion: string;
    deviceId?: string | undefined;
}>;
export type OtaCheckUpdateRequest = z.infer<typeof OtaCheckUpdateRequestSchema>;
//# sourceMappingURL=index.d.ts.map