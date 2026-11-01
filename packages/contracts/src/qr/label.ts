import { z } from 'zod';
import { SchemaVersionSchema, HardwareRevisionCodeSchema, SerialNumberSchema } from '../common';
import { OpaqueQrTokenSchema, QrUriSchema } from './base';

// ── 1. Printer Protocol & Error Code Schemas ──────────────────────────

export const PrinterProtocolSchema = z.enum(['TSPL', 'ESCPOS']);
export type PrinterProtocol = z.infer<typeof PrinterProtocolSchema>;

export const PrinterErrorCodeSchema = z.enum([
  'PRINTER_NOT_FOUND',
  'PRINTER_UNAVAILABLE',
  'PRINTER_BUSY',
  'PRINTER_CONNECTION_FAILED',
  'UNSUPPORTED_PRINTER_PROTOCOL',
  'INVALID_LABEL_DATA',
  'INVALID_QR_PAYLOAD',
  'SECRET_DATA_DETECTED',
  'TEMPLATE_NOT_FOUND',
  'PRINT_FAILED'
]);
export type PrinterErrorCode = z.infer<typeof PrinterErrorCodeSchema>;

// ── 2. Label Template Identifiers ─────────────────────────────────────

export const LabelTemplateIdSchema = z.enum([
  'device-primary-50x30-v1',
  'device-compact-40x20-v1',
  'device-silicon-25x10-v1',
  'box-receipt-escpos-v1'
]);
export type LabelTemplateId = z.infer<typeof LabelTemplateIdSchema>;

// ── 3. Label Dimensions ───────────────────────────────────────────────

export const LabelDimensionsSchema = z.object({
  widthMm: z.number().positive(),
  heightMm: z.number().positive(),
  gapMm: z.number().nonnegative().default(2),
  dpi: z.enum(['203', '300']).default('203')
});
export type LabelDimensions = z.infer<typeof LabelDimensionsSchema>;

// ── 4. Canonical Label Data Model ─────────────────────────────────────

export const LabelDataModelSchema = z.object({
  schemaVersion: SchemaVersionSchema.default(1),
  brand: z.literal('EH Home').default('EH Home'),
  deviceId: z.string().uuid(),
  serialNumber: SerialNumberSchema,
  productVariantId: z.string().regex(/^eh-[a-z0-9-]+$/),
  productDisplayName: z.string().min(1),
  productFamily: z.string().min(1),
  hardwareRevision: HardwareRevisionCodeSchema,
  firmwareFamily: z.string().min(1),
  firmwareVersion: z.string().min(1),
  qrUri: QrUriSchema,
  qrToken: OpaqueQrTokenSchema,
  templateId: LabelTemplateIdSchema.default('device-primary-50x30-v1'),
  traceId: z.string().uuid().optional(),
  batchId: z.string().uuid().optional(),
  manufacturedAt: z.string().datetime().optional()
});
export type LabelDataModel = z.infer<typeof LabelDataModelSchema>;

// ── 5. Print Job Request & Response ───────────────────────────────────

export const PrintJobRequestSchema = z.object({
  printerId: z.string().min(1),
  protocol: PrinterProtocolSchema.default('TSPL'),
  templateId: LabelTemplateIdSchema.default('device-primary-50x30-v1'),
  labelData: LabelDataModelSchema,
  copies: z.number().int().positive().default(1)
});
export type PrintJobRequest = z.infer<typeof PrintJobRequestSchema>;

export const PrintJobResultSchema = z.object({
  success: z.boolean(),
  jobId: z.string().optional(),
  protocol: PrinterProtocolSchema,
  printerId: z.string(),
  copiesPrinted: z.number().int().nonnegative(),
  errorCode: PrinterErrorCodeSchema.optional(),
  errorMessage: z.string().optional(),
  renderedCommandPreview: z.string().optional(),
  printedAt: z.string().datetime().optional()
});
export type PrintJobResult = z.infer<typeof PrintJobResultSchema>;
