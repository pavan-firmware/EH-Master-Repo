import { z } from 'zod';
import { SchemaVersionSchema } from '../common';

export const FixedPointEnergyTelemetrySchema = z.object({
  schemaVersion: SchemaVersionSchema.default(1),
  deviceId: z.string().uuid(),
  channelIndex: z.number().int().min(1).max(16).default(1),
  v_mv: z.number().int().positive({ message: 'Voltage in mV must be positive' }),
  i_ma: z.number().int().nonnegative({ message: 'Current in mA must be non-negative' }),
  p_mw: z.number().int().nonnegative({ message: 'Power in mW must be non-negative' }),
  e_tot_wh: z.number().int().nonnegative({ message: 'Total energy in Wh must be non-negative' }),
  e_int_mwh: z.number().int().nonnegative({ message: 'Interval energy in mWh must be non-negative' }).optional(),
  freq_mhz: z.number().int().positive({ message: 'Grid frequency in mHz must be positive' }).default(50000),
  pf_x1000: z.number().int().min(0).max(1000, { message: 'Power factor x1000 must be in range 0..1000' }),
  flags: z.number().int().default(0),
  sequenceNumber: z.number().int().nonnegative().default(0),
  timestamp: z.string().datetime(),
  ingestedAt: z.string().datetime().optional()
});
export type FixedPointEnergyTelemetry = z.infer<typeof FixedPointEnergyTelemetrySchema>;

export const TelemetryQueryFilterSchema = z.object({
  deviceId: z.string().uuid(),
  channelIndex: z.number().int().min(1).max(16).optional(),
  startTime: z.string().datetime().optional(),
  endTime: z.string().datetime().optional(),
  limit: z.number().int().min(1).max(1000).default(100)
});
export type TelemetryQueryFilter = z.infer<typeof TelemetryQueryFilterSchema>;

export const TelemetryAggregateBucketSchema = z.enum(['1m', '5m', '1h', '1d', '1w', '1mo']);
export type TelemetryAggregateBucket = z.infer<typeof TelemetryAggregateBucketSchema>;

export const TelemetryAggregateRecordSchema = z.object({
  deviceId: z.string().uuid(),
  channelIndex: z.number().int().min(1).max(16),
  bucketType: TelemetryAggregateBucketSchema,
  bucketStart: z.string().datetime(),
  bucketEnd: z.string().datetime(),
  totalEnergyWh: z.number().nonnegative(),
  avgPowerW: z.number().nonnegative(),
  peakPowerW: z.number().nonnegative(),
  minPowerW: z.number().nonnegative(),
  sampleCount: z.number().int().nonnegative(),
  dataQuality: z.enum(['GOOD', 'DEGRADED', 'INTERPOLATED']).default('GOOD')
});
export type TelemetryAggregateRecord = z.infer<typeof TelemetryAggregateRecordSchema>;
