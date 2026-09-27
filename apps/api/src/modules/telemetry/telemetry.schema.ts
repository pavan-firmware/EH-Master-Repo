import { z } from 'zod';
import { FixedPointEnergyTelemetrySchema, TelemetryQueryFilterSchema } from '@eh-home/contracts';

export { FixedPointEnergyTelemetrySchema, TelemetryQueryFilterSchema };

export const IngestTelemetryResponseSchema = z.object({
  success: z.boolean(),
  status: z.enum(['ACCEPTED', 'DROPPED_DUPLICATE', 'REJECTED']),
  message: z.string().optional()
});
export type IngestTelemetryResponse = z.infer<typeof IngestTelemetryResponseSchema>;

export const TelemetryLiveStateSchema = z.object({
  deviceId: z.string().uuid(),
  channelIndex: z.number().int(),
  v_mv: z.number().int(),
  i_ma: z.number().int(),
  p_mw: z.number().int(),
  e_tot_wh: z.number().int(),
  pf_x1000: z.number().int(),
  freq_mhz: z.number().int(),
  sequenceNumber: z.number().int(),
  timestamp: z.string().datetime(),
  connectionState: z.enum(['ONLINE', 'STALE', 'OFFLINE'])
});
export type TelemetryLiveState = z.infer<typeof TelemetryLiveStateSchema>;
