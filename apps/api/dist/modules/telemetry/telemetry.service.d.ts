import { FixedPointEnergyTelemetry } from '@eh-home/contracts';
import { ITelemetryRepository } from './telemetry.repository';
export interface TelemetryIngestResult {
    accepted: boolean;
    status: 'ACCEPTED' | 'DROPPED_DUPLICATE' | 'REJECTED';
    reason?: string;
}
export declare class TelemetryIngestionService {
    private repo;
    private lastSequenceMap;
    private onLiveUpdate?;
    constructor(repo: ITelemetryRepository, onLiveUpdate?: (telemetry: FixedPointEnergyTelemetry) => void);
    ingest(rawPayload: unknown): Promise<TelemetryIngestResult>;
    getLatest(deviceId: string, channelIndex?: number): Promise<FixedPointEnergyTelemetry | null>;
    query(filter: {
        deviceId: string;
        channelIndex?: number;
        startTime?: string;
        endTime?: string;
        limit?: number;
    }): Promise<FixedPointEnergyTelemetry[]>;
}
//# sourceMappingURL=telemetry.service.d.ts.map