import { z } from 'zod';
import { SchemaVersionSchema, HardwareRevisionCodeSchema, SerialNumberSchema } from '../common';

export const ProductionBatchStatusSchema = z.enum([
  'PLANNED',
  'IN_PRODUCTION',
  'QC_IN_PROGRESS',
  'COMPLETED',
  'CANCELLED'
]);
export type ProductionBatchStatus = z.infer<typeof ProductionBatchStatusSchema>;

export const ProductionBatchSchema = z.object({
  schemaVersion: SchemaVersionSchema,
  batchId: z.string().uuid(),
  batchCode: z.string().regex(/^BATCH-[A-Z0-9-]+$/, {
    message: 'Must be a valid batch code (e.g. BATCH-2026-SW3X-001)'
  }),
  productVariantId: z.string().min(1),
  hardwareRevisionCode: HardwareRevisionCodeSchema,
  firmwareReleaseId: z.string().uuid(),
  targetQuantity: z.number().int().positive(),
  manufacturedCount: z.number().int().nonnegative().default(0),
  passedQcCount: z.number().int().nonnegative().default(0),
  failedQcCount: z.number().int().nonnegative().default(0),
  status: ProductionBatchStatusSchema.default('PLANNED'),
  operatorUserId: z.string().uuid().optional(),
  notes: z.string().optional(),
  scheduledStartDate: z.string().datetime().optional(),
  completedAt: z.string().datetime().optional(),
  createdAt: z.string().datetime()
});
export type ProductionBatch = z.infer<typeof ProductionBatchSchema>;

export const BatchDeviceAssociationSchema = z.object({
  batchId: z.string().uuid(),
  deviceId: z.string().uuid(),
  serialNumber: SerialNumberSchema,
  assignedAt: z.string().datetime()
});
export type BatchDeviceAssociation = z.infer<typeof BatchDeviceAssociationSchema>;

export const QcMeasurementSchema = z.object({
  parameter: z.string().min(1),
  measuredValue: z.number(),
  unit: z.string().min(1),
  lowerLimit: z.number().optional(),
  upperLimit: z.number().optional(),
  passed: z.boolean()
});
export type QcMeasurement = z.infer<typeof QcMeasurementSchema>;

export const QcTestLogSchema = z.object({
  schemaVersion: SchemaVersionSchema,
  testLogId: z.string().uuid(),
  deviceId: z.string().uuid(),
  serialNumber: SerialNumberSchema,
  batchId: z.string().uuid(),
  testStationId: z.string().min(1),
  operatorUserId: z.string().uuid().optional(),
  overallResult: z.enum(['PASS', 'FAIL']),
  measurements: z.array(QcMeasurementSchema).default([]),
  failureReason: z.string().optional(),
  testedAt: z.string().datetime()
});
export type QcTestLog = z.infer<typeof QcTestLogSchema>;
