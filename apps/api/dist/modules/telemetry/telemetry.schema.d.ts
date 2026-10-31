import { z } from 'zod';
import { FixedPointEnergyTelemetrySchema, TelemetryQueryFilterSchema } from '@eh-home/contracts';
export { FixedPointEnergyTelemetrySchema, TelemetryQueryFilterSchema };
export declare const IngestTelemetryResponseSchema: z.ZodObject<{
    success: z.ZodBoolean;
    status: z.ZodEnum<["ACCEPTED", "DROPPED_DUPLICATE", "REJECTED"]>;
    message: z.ZodOptional<z.ZodString>;
}, "strip", z.ZodTypeAny, {
    status: "REJECTED" | "ACCEPTED" | "DROPPED_DUPLICATE";
    success: boolean;
    message?: string | undefined;
}, {
    status: "REJECTED" | "ACCEPTED" | "DROPPED_DUPLICATE";
    success: boolean;
    message?: string | undefined;
}>;
export type IngestTelemetryResponse = z.infer<typeof IngestTelemetryResponseSchema>;
export declare const TelemetryLiveStateSchema: z.ZodObject<{
    deviceId: z.ZodString;
    channelIndex: z.ZodNumber;
    v_mv: z.ZodNumber;
    i_ma: z.ZodNumber;
    p_mw: z.ZodNumber;
    e_tot_wh: z.ZodNumber;
    pf_x1000: z.ZodNumber;
    freq_mhz: z.ZodNumber;
    sequenceNumber: z.ZodNumber;
    timestamp: z.ZodString;
    connectionState: z.ZodEnum<["ONLINE", "STALE", "OFFLINE"]>;
}, "strip", z.ZodTypeAny, {
    timestamp: string;
    channelIndex: number;
    deviceId: string;
    connectionState: "ONLINE" | "STALE" | "OFFLINE";
    sequenceNumber: number;
    v_mv: number;
    i_ma: number;
    p_mw: number;
    e_tot_wh: number;
    freq_mhz: number;
    pf_x1000: number;
}, {
    timestamp: string;
    channelIndex: number;
    deviceId: string;
    connectionState: "ONLINE" | "STALE" | "OFFLINE";
    sequenceNumber: number;
    v_mv: number;
    i_ma: number;
    p_mw: number;
    e_tot_wh: number;
    freq_mhz: number;
    pf_x1000: number;
}>;
export type TelemetryLiveState = z.infer<typeof TelemetryLiveStateSchema>;
//# sourceMappingURL=telemetry.schema.d.ts.map