"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.AuthorizeOtaJobRequestSchema = exports.CheckOtaUpdateRequestSchema = exports.CreateOtaJobRequestSchema = exports.UpdateOtaJobStatusSchema = exports.OtaLifecycleStateSchema = exports.validateOtaStateTransition = exports.isValidOtaStateTransition = exports.OtaCheckUpdateRequestSchema = exports.OtaJobCreateRequestSchema = exports.OtaJobStatusUpdateRequestSchema = exports.OtaExecutionStateSchema = exports.FirmwareReleaseSchema = exports.OtaManifestSchema = void 0;
const zod_1 = require("zod");
const contracts_1 = require("@eh-home/contracts");
Object.defineProperty(exports, "OtaManifestSchema", { enumerable: true, get: function () { return contracts_1.OtaManifestSchema; } });
Object.defineProperty(exports, "FirmwareReleaseSchema", { enumerable: true, get: function () { return contracts_1.FirmwareReleaseSchema; } });
Object.defineProperty(exports, "OtaExecutionStateSchema", { enumerable: true, get: function () { return contracts_1.OtaExecutionStateSchema; } });
Object.defineProperty(exports, "OtaJobStatusUpdateRequestSchema", { enumerable: true, get: function () { return contracts_1.OtaJobStatusUpdateRequestSchema; } });
Object.defineProperty(exports, "OtaJobCreateRequestSchema", { enumerable: true, get: function () { return contracts_1.OtaJobCreateRequestSchema; } });
Object.defineProperty(exports, "OtaCheckUpdateRequestSchema", { enumerable: true, get: function () { return contracts_1.OtaCheckUpdateRequestSchema; } });
Object.defineProperty(exports, "isValidOtaStateTransition", { enumerable: true, get: function () { return contracts_1.isValidOtaStateTransition; } });
Object.defineProperty(exports, "validateOtaStateTransition", { enumerable: true, get: function () { return contracts_1.validateOtaStateTransition; } });
exports.OtaLifecycleStateSchema = contracts_1.OtaExecutionStateSchema;
exports.UpdateOtaJobStatusSchema = contracts_1.OtaJobStatusUpdateRequestSchema;
exports.CreateOtaJobRequestSchema = contracts_1.OtaJobCreateRequestSchema;
exports.CheckOtaUpdateRequestSchema = contracts_1.OtaCheckUpdateRequestSchema;
exports.AuthorizeOtaJobRequestSchema = zod_1.z.object({
    deviceTrustState: zod_1.z.enum(['PROVISIONED', 'COMMISSIONED', 'TRUSTED', 'DEGRADED', 'QUARANTINED', 'REVOKED', 'DECOMMISSIONED']).optional(),
    deviceHardwareRevision: contracts_1.HardwareRevisionCodeSchema.optional(),
    deviceMcu: zod_1.z.string().optional(),
    deviceProductVariantId: zod_1.z.string().optional()
});
//# sourceMappingURL=ota.schema.js.map