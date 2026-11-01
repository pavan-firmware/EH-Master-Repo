import { z } from 'zod';
import {
  OtaManifestSchema,
  FirmwareReleaseSchema,
  HardwareRevisionCodeSchema,
  OtaExecutionStateSchema,
  OtaJobStatusUpdateRequestSchema,
  OtaJobCreateRequestSchema,
  OtaCheckUpdateRequestSchema,
  OtaExecutionState,
  isValidOtaStateTransition,
  validateOtaStateTransition
} from '@eh-home/contracts';

export {
  OtaManifestSchema,
  FirmwareReleaseSchema,
  OtaExecutionStateSchema,
  OtaJobStatusUpdateRequestSchema,
  OtaJobCreateRequestSchema,
  OtaCheckUpdateRequestSchema,
  isValidOtaStateTransition,
  validateOtaStateTransition
};

export type OtaLifecycleState = OtaExecutionState;
export const OtaLifecycleStateSchema = OtaExecutionStateSchema;

export const UpdateOtaJobStatusSchema = OtaJobStatusUpdateRequestSchema;
export type UpdateOtaJobStatus = z.infer<typeof UpdateOtaJobStatusSchema>;

export const CreateOtaJobRequestSchema = OtaJobCreateRequestSchema;
export type CreateOtaJobRequest = z.infer<typeof CreateOtaJobRequestSchema>;

export const CheckOtaUpdateRequestSchema = OtaCheckUpdateRequestSchema;
export type CheckOtaUpdateRequest = z.infer<typeof CheckOtaUpdateRequestSchema>;

export const AuthorizeOtaJobRequestSchema = z.object({
  deviceTrustState: z.enum(['PROVISIONED', 'COMMISSIONED', 'TRUSTED', 'DEGRADED', 'QUARANTINED', 'REVOKED', 'DECOMMISSIONED']).optional(),
  deviceHardwareRevision: HardwareRevisionCodeSchema.optional(),
  deviceMcu: z.string().optional(),
  deviceProductVariantId: z.string().optional()
});
export type AuthorizeOtaJobRequest = z.infer<typeof AuthorizeOtaJobRequestSchema>;
