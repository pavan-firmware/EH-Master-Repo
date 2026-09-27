import { z } from 'zod';
import { SchemaVersionSchema } from '../common';

export const OpaqueTokenRegex = /^[A-Za-z0-9_-]{16,64}$/;
export const QrUriRegex = /^eh:\/\/p\/v1\?t=[A-Za-z0-9_-]{16,64}$/;

export const OpaqueQrTokenSchema = z.string().regex(OpaqueTokenRegex, {
  message: 'Token must be a high-entropy opaque cryptographic string (16-64 chars base64url/hex)'
});
export type OpaqueQrToken = z.infer<typeof OpaqueQrTokenSchema>;

export const QrUriSchema = z.string().regex(QrUriRegex, {
  message: 'QR URI must follow canonical format: eh://p/v1?t=<OPAQUE_TOKEN>'
});
export type QrUri = z.infer<typeof QrUriSchema>;

export const QrPayloadSchema = z.object({
  schemaVersion: SchemaVersionSchema,
  token: OpaqueQrTokenSchema,
  qrUri: QrUriSchema,
  generatedAt: z.string().datetime()
}).refine(
  (data) => {
    // Invariant: QR URI must contain the exact same token parameter
    const expectedUri = `eh://p/v1?t=${data.token}`;
    return data.qrUri === expectedUri;
  },
  {
    message: 'qrUri must strictly match eh://p/v1?t=<token>'
  }
);
export type QrPayload = z.infer<typeof QrPayloadSchema>;

export const QrCodeRecordSchema = z.object({
  schemaVersion: SchemaVersionSchema,
  qrId: z.string().uuid(),
  deviceId: z.string().uuid(),
  token: OpaqueQrTokenSchema,
  qrUri: QrUriSchema,
  printedStatus: z.enum(['PENDING', 'PRINTED', 'REPRINTED']).default('PENDING'),
  claimedStatus: z.enum(['UNCLAIMED', 'CLAIMED']).default('UNCLAIMED'),
  claimedAt: z.string().datetime().optional(),
  createdAt: z.string().datetime()
});
export type QrCodeRecord = z.infer<typeof QrCodeRecordSchema>;
