import { z } from 'zod';
import { HardwareRevisionCodeSchema, SemanticVersionSchema } from '../common';

export const OtaExecutionStateSchema = z.enum([
  'REQUESTED',
  'AUTHORIZED',
  'AVAILABLE',
  'DOWNLOADING',
  'VERIFYING',
  'INSTALLING',
  'SUCCEEDED',
  'FAILED',
  'ROLLED_BACK',
  'CANCELLED'
]);
export type OtaExecutionState = z.infer<typeof OtaExecutionStateSchema>;

export const OTA_TERMINAL_STATES: ReadonlySet<OtaExecutionState> = new Set([
  'SUCCEEDED',
  'ROLLED_BACK',
  'CANCELLED'
]);

export const OTA_STATE_TRANSITIONS: Record<OtaExecutionState, readonly OtaExecutionState[]> = {
  REQUESTED: ['AUTHORIZED', 'FAILED', 'CANCELLED'],
  AUTHORIZED: ['AVAILABLE', 'FAILED', 'CANCELLED'],
  AVAILABLE: ['DOWNLOADING', 'FAILED', 'CANCELLED'],
  DOWNLOADING: ['VERIFYING', 'FAILED'],
  VERIFYING: ['INSTALLING', 'FAILED', 'ROLLED_BACK'],
  INSTALLING: ['SUCCEEDED', 'FAILED', 'ROLLED_BACK'],
  SUCCEEDED: [],
  FAILED: ['ROLLED_BACK'],
  ROLLED_BACK: [],
  CANCELLED: []
};

export function isValidOtaStateTransition(current: OtaExecutionState, next: OtaExecutionState): boolean {
  if (current === next) return true; // Idempotent
  const allowed = OTA_STATE_TRANSITIONS[current] || [];
  return allowed.includes(next);
}

export function validateOtaStateTransition(current: OtaExecutionState, next: OtaExecutionState): void {
  if (!isValidOtaStateTransition(current, next)) {
    throw new Error(
      `Invalid OTA state transition from '${current}' to '${next}'. Allowed next states: [${(OTA_STATE_TRANSITIONS[current] || []).join(', ')}]`
    );
  }
}

export const OtaJobStatusUpdateRequestSchema = z.object({
  jobId: z.string().uuid({ message: 'jobId must be a valid UUID' }),
  status: OtaExecutionStateSchema,
  progressPercent: z.number().int().min(0).max(100).optional(),
  errorCode: z.string().optional(),
  errorMessage: z.string().optional()
});
export type OtaJobStatusUpdateRequest = z.infer<typeof OtaJobStatusUpdateRequestSchema>;

export const OtaJobCreateRequestSchema = z.object({
  deviceId: z.string().uuid({ message: 'deviceId must be a valid UUID' }),
  releaseId: z.string().uuid({ message: 'releaseId must be a valid UUID' }),
  rolloutId: z.string().optional(),
  fromVersion: SemanticVersionSchema
});
export type OtaJobCreateRequest = z.infer<typeof OtaJobCreateRequestSchema>;

export const OtaCheckUpdateRequestSchema = z.object({
  deviceId: z.string().uuid().optional(),
  productVariantId: z.string().regex(/^eh-[a-z0-9-]+$/),
  hardwareRevision: HardwareRevisionCodeSchema,
  currentVersion: SemanticVersionSchema
});
export type OtaCheckUpdateRequest = z.infer<typeof OtaCheckUpdateRequestSchema>;
