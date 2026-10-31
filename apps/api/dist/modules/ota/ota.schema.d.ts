import { z } from 'zod';
import { OtaManifestSchema, FirmwareReleaseSchema, OtaExecutionStateSchema, OtaJobStatusUpdateRequestSchema, OtaJobCreateRequestSchema, OtaCheckUpdateRequestSchema, OtaExecutionState, isValidOtaStateTransition, validateOtaStateTransition } from '@eh-home/contracts';
export { OtaManifestSchema, FirmwareReleaseSchema, OtaExecutionStateSchema, OtaJobStatusUpdateRequestSchema, OtaJobCreateRequestSchema, OtaCheckUpdateRequestSchema, isValidOtaStateTransition, validateOtaStateTransition };
export type OtaLifecycleState = OtaExecutionState;
export declare const OtaLifecycleStateSchema: z.ZodEnum<["REQUESTED", "AUTHORIZED", "AVAILABLE", "DOWNLOADING", "VERIFYING", "INSTALLING", "SUCCEEDED", "FAILED", "ROLLED_BACK", "CANCELLED"]>;
export declare const UpdateOtaJobStatusSchema: z.ZodObject<{
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
export type UpdateOtaJobStatus = z.infer<typeof UpdateOtaJobStatusSchema>;
export declare const CreateOtaJobRequestSchema: z.ZodObject<{
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
export type CreateOtaJobRequest = z.infer<typeof CreateOtaJobRequestSchema>;
export declare const CheckOtaUpdateRequestSchema: z.ZodObject<{
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
export type CheckOtaUpdateRequest = z.infer<typeof CheckOtaUpdateRequestSchema>;
export declare const AuthorizeOtaJobRequestSchema: z.ZodObject<{
    deviceTrustState: z.ZodOptional<z.ZodEnum<["PROVISIONED", "COMMISSIONED", "TRUSTED", "DEGRADED", "QUARANTINED", "REVOKED", "DECOMMISSIONED"]>>;
    deviceHardwareRevision: z.ZodOptional<z.ZodString>;
    deviceMcu: z.ZodOptional<z.ZodString>;
    deviceProductVariantId: z.ZodOptional<z.ZodString>;
}, "strip", z.ZodTypeAny, {
    deviceTrustState?: "REVOKED" | "PROVISIONED" | "QUARANTINED" | "TRUSTED" | "DECOMMISSIONED" | "COMMISSIONED" | "DEGRADED" | undefined;
    deviceHardwareRevision?: string | undefined;
    deviceMcu?: string | undefined;
    deviceProductVariantId?: string | undefined;
}, {
    deviceTrustState?: "REVOKED" | "PROVISIONED" | "QUARANTINED" | "TRUSTED" | "DECOMMISSIONED" | "COMMISSIONED" | "DEGRADED" | undefined;
    deviceHardwareRevision?: string | undefined;
    deviceMcu?: string | undefined;
    deviceProductVariantId?: string | undefined;
}>;
export type AuthorizeOtaJobRequest = z.infer<typeof AuthorizeOtaJobRequestSchema>;
//# sourceMappingURL=ota.schema.d.ts.map