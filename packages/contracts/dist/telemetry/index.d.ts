import { z } from 'zod';
export declare const FixedPointEnergyTelemetrySchema: z.ZodObject<{
    schemaVersion: z.ZodDefault<z.ZodDefault<z.ZodNumber>>;
    deviceId: z.ZodString;
    channelIndex: z.ZodDefault<z.ZodNumber>;
    v_mv: z.ZodNumber;
    i_ma: z.ZodNumber;
    p_mw: z.ZodNumber;
    e_tot_wh: z.ZodNumber;
    e_int_mwh: z.ZodOptional<z.ZodNumber>;
    freq_mhz: z.ZodDefault<z.ZodNumber>;
    pf_x1000: z.ZodNumber;
    flags: z.ZodDefault<z.ZodNumber>;
    sequenceNumber: z.ZodDefault<z.ZodNumber>;
    timestamp: z.ZodString;
    ingestedAt: z.ZodOptional<z.ZodString>;
}, "strip", z.ZodTypeAny, {
    schemaVersion: number;
    timestamp: string;
    channelIndex: number;
    deviceId: string;
    v_mv: number;
    i_ma: number;
    p_mw: number;
    e_tot_wh: number;
    freq_mhz: number;
    pf_x1000: number;
    flags: number;
    sequenceNumber: number;
    e_int_mwh?: number | undefined;
    ingestedAt?: string | undefined;
}, {
    timestamp: string;
    deviceId: string;
    v_mv: number;
    i_ma: number;
    p_mw: number;
    e_tot_wh: number;
    pf_x1000: number;
    schemaVersion?: number | undefined;
    channelIndex?: number | undefined;
    e_int_mwh?: number | undefined;
    freq_mhz?: number | undefined;
    flags?: number | undefined;
    sequenceNumber?: number | undefined;
    ingestedAt?: string | undefined;
}>;
export type FixedPointEnergyTelemetry = z.infer<typeof FixedPointEnergyTelemetrySchema>;
export declare const TelemetryQueryFilterSchema: z.ZodObject<{
    deviceId: z.ZodString;
    channelIndex: z.ZodOptional<z.ZodNumber>;
    startTime: z.ZodOptional<z.ZodString>;
    endTime: z.ZodOptional<z.ZodString>;
    limit: z.ZodDefault<z.ZodNumber>;
}, "strip", z.ZodTypeAny, {
    limit: number;
    deviceId: string;
    channelIndex?: number | undefined;
    startTime?: string | undefined;
    endTime?: string | undefined;
}, {
    deviceId: string;
    limit?: number | undefined;
    channelIndex?: number | undefined;
    startTime?: string | undefined;
    endTime?: string | undefined;
}>;
export type TelemetryQueryFilter = z.infer<typeof TelemetryQueryFilterSchema>;
export declare const TelemetryAggregateBucketSchema: z.ZodEnum<["1m", "5m", "1h", "1d", "1w", "1mo"]>;
export type TelemetryAggregateBucket = z.infer<typeof TelemetryAggregateBucketSchema>;
export declare const TelemetryAggregateRecordSchema: z.ZodObject<{
    deviceId: z.ZodString;
    channelIndex: z.ZodNumber;
    bucketType: z.ZodEnum<["1m", "5m", "1h", "1d", "1w", "1mo"]>;
    bucketStart: z.ZodString;
    bucketEnd: z.ZodString;
    totalEnergyWh: z.ZodNumber;
    avgPowerW: z.ZodNumber;
    peakPowerW: z.ZodNumber;
    minPowerW: z.ZodNumber;
    sampleCount: z.ZodNumber;
    dataQuality: z.ZodDefault<z.ZodEnum<["GOOD", "DEGRADED", "INTERPOLATED"]>>;
}, "strip", z.ZodTypeAny, {
    channelIndex: number;
    deviceId: string;
    bucketType: "1m" | "5m" | "1h" | "1d" | "1w" | "1mo";
    bucketStart: string;
    bucketEnd: string;
    totalEnergyWh: number;
    avgPowerW: number;
    peakPowerW: number;
    minPowerW: number;
    sampleCount: number;
    dataQuality: "GOOD" | "DEGRADED" | "INTERPOLATED";
}, {
    channelIndex: number;
    deviceId: string;
    bucketType: "1m" | "5m" | "1h" | "1d" | "1w" | "1mo";
    bucketStart: string;
    bucketEnd: string;
    totalEnergyWh: number;
    avgPowerW: number;
    peakPowerW: number;
    minPowerW: number;
    sampleCount: number;
    dataQuality?: "GOOD" | "DEGRADED" | "INTERPOLATED" | undefined;
}>;
export type TelemetryAggregateRecord = z.infer<typeof TelemetryAggregateRecordSchema>;
//# sourceMappingURL=index.d.ts.map