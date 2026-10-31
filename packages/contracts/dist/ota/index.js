"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.OtaCheckUpdateRequestSchema = exports.OtaJobCreateRequestSchema = exports.OtaJobStatusUpdateRequestSchema = exports.OTA_STATE_TRANSITIONS = exports.OTA_TERMINAL_STATES = exports.OtaExecutionStateSchema = void 0;
exports.isValidOtaStateTransition = isValidOtaStateTransition;
exports.validateOtaStateTransition = validateOtaStateTransition;
const zod_1 = require("zod");
const common_1 = require("../common");
exports.OtaExecutionStateSchema = zod_1.z.enum([
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
exports.OTA_TERMINAL_STATES = new Set([
    'SUCCEEDED',
    'ROLLED_BACK',
    'CANCELLED'
]);
exports.OTA_STATE_TRANSITIONS = {
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
function isValidOtaStateTransition(current, next) {
    if (current === next)
        return true; // Idempotent
    const allowed = exports.OTA_STATE_TRANSITIONS[current] || [];
    return allowed.includes(next);
}
function validateOtaStateTransition(current, next) {
    if (!isValidOtaStateTransition(current, next)) {
        throw new Error(`Invalid OTA state transition from '${current}' to '${next}'. Allowed next states: [${(exports.OTA_STATE_TRANSITIONS[current] || []).join(', ')}]`);
    }
}
exports.OtaJobStatusUpdateRequestSchema = zod_1.z.object({
    jobId: zod_1.z.string().uuid({ message: 'jobId must be a valid UUID' }),
    status: exports.OtaExecutionStateSchema,
    progressPercent: zod_1.z.number().int().min(0).max(100).optional(),
    errorCode: zod_1.z.string().optional(),
    errorMessage: zod_1.z.string().optional()
});
exports.OtaJobCreateRequestSchema = zod_1.z.object({
    deviceId: zod_1.z.string().uuid({ message: 'deviceId must be a valid UUID' }),
    releaseId: zod_1.z.string().uuid({ message: 'releaseId must be a valid UUID' }),
    rolloutId: zod_1.z.string().optional(),
    fromVersion: common_1.SemanticVersionSchema
});
exports.OtaCheckUpdateRequestSchema = zod_1.z.object({
    deviceId: zod_1.z.string().uuid().optional(),
    productVariantId: zod_1.z.string().regex(/^eh-[a-z0-9-]+$/),
    hardwareRevision: common_1.HardwareRevisionCodeSchema,
    currentVersion: common_1.SemanticVersionSchema
});
//# sourceMappingURL=index.js.map