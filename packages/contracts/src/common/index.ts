import { z } from 'zod';

export const SchemaVersionSchema = z.number().int().min(1).max(1).default(1);

export const UuidSchema = z.string().uuid({ message: 'Must be a valid UUID v4' });

export const IsoTimestampSchema = z.string().datetime({ message: 'Must be an ISO 8601 UTC datetime string' });
export const IsoDateTimeSchema = IsoTimestampSchema;

export const SemanticVersionSchema = z.string().regex(/^[0-9]+\.[0-9]+\.[0-9]+(-[a-zA-Z0-9.]+)?$/, {
  message: 'Must be a valid semantic version (e.g. 1.0.0 or 1.0.0-rc.1)'
});

export const HardwareRevisionCodeSchema = z.string().regex(/^HW_[0-9]+_[0-9]+$/, {
  message: 'Must be a valid hardware revision code (e.g. HW_1_0)'
});

export const MacAddressSchema = z.string().regex(/^([0-9A-Fa-f]{2}[:-]){5}([0-9A-Fa-f]{2})$/, {
  message: 'Must be a valid 6-byte IEEE 802 MAC address'
});

export const SerialNumberSchema = z.string().regex(/^EH-[A-Z0-9]+(-[A-Z0-9]+)*-[0-9]{4,5}$/, {
  message: 'Must be a valid EH serial number (e.g. EH-SW3X-2026-00001)'
});

export const PaginationQuerySchema = z.object({
  page: z.coerce.number().int().min(1).default(1),
  limit: z.coerce.number().int().min(1).max(100).default(20),
  cursor: z.string().optional()
});

export type PaginationQuery = z.infer<typeof PaginationQuerySchema>;

export const ApiEnvelopeSchema = <T extends z.ZodTypeAny>(dataSchema: T) =>
  z.object({
    schemaVersion: SchemaVersionSchema,
    success: z.boolean(),
    data: dataSchema.optional(),
    error: z
      .object({
        code: z.string(),
        message: z.string(),
        details: z.record(z.unknown()).optional()
      })
      .optional(),
    meta: z
      .object({
        requestId: z.string().optional(),
        timestamp: IsoTimestampSchema.default(() => new Date().toISOString()),
        pagination: z
          .object({
            total: z.number().int().nonnegative(),
            page: z.number().int().positive(),
            limit: z.number().int().positive(),
            hasMore: z.boolean()
          })
          .optional()
      })
      .optional()
  });
