"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.QrCodeRecordSchema = exports.QrPayloadSchema = exports.QrUriSchema = exports.OpaqueQrTokenSchema = exports.QrUriRegex = exports.OpaqueTokenRegex = void 0;
const zod_1 = require("zod");
const common_1 = require("../common");
exports.OpaqueTokenRegex = /^[A-Za-z0-9_-]{16,64}$/;
exports.QrUriRegex = /^eh:\/\/p\/v1\?t=[A-Za-z0-9_-]{16,64}$/;
exports.OpaqueQrTokenSchema = zod_1.z.string().regex(exports.OpaqueTokenRegex, {
    message: 'Token must be a high-entropy opaque cryptographic string (16-64 chars base64url/hex)'
});
exports.QrUriSchema = zod_1.z.string().regex(exports.QrUriRegex, {
    message: 'QR URI must follow canonical format: eh://p/v1?t=<OPAQUE_TOKEN>'
});
exports.QrPayloadSchema = zod_1.z.object({
    schemaVersion: common_1.SchemaVersionSchema,
    token: exports.OpaqueQrTokenSchema,
    qrUri: exports.QrUriSchema,
    generatedAt: zod_1.z.string().datetime()
}).refine((data) => {
    // Invariant: QR URI must contain the exact same token parameter
    const expectedUri = `eh://p/v1?t=${data.token}`;
    return data.qrUri === expectedUri;
}, {
    message: 'qrUri must strictly match eh://p/v1?t=<token>'
});
exports.QrCodeRecordSchema = zod_1.z.object({
    schemaVersion: common_1.SchemaVersionSchema,
    qrId: zod_1.z.string().uuid(),
    deviceId: zod_1.z.string().uuid(),
    token: exports.OpaqueQrTokenSchema,
    qrUri: exports.QrUriSchema,
    printedStatus: zod_1.z.enum(['PENDING', 'PRINTED', 'REPRINTED']).default('PENDING'),
    claimedStatus: zod_1.z.enum(['UNCLAIMED', 'CLAIMED']).default('UNCLAIMED'),
    claimedAt: zod_1.z.string().datetime().optional(),
    createdAt: zod_1.z.string().datetime()
});
//# sourceMappingURL=base.js.map