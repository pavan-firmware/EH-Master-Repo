import { FixedPointEnergyTelemetry, TelemetryQueryFilter } from '@eh-home/contracts';
export interface ITelemetryRepository {
    insertTelemetry(record: FixedPointEnergyTelemetry): Promise<void>;
    getLatestTelemetry(deviceId: string, channelIndex?: number): Promise<FixedPointEnergyTelemetry | null>;
    queryTelemetry(filter: TelemetryQueryFilter): Promise<FixedPointEnergyTelemetry[]>;
}
export declare class TelemetryRepository implements ITelemetryRepository {
    private db;
    private inMemoryStore;
    constructor(db?: any);
    insertTelemetry(record: FixedPointEnergyTelemetry): Promise<void>;
    getLatestTelemetry(deviceId: string, channelIndex?: number): Promise<FixedPointEnergyTelemetry | null>;
    queryTelemetry(filter: TelemetryQueryFilter): Promise<FixedPointEnergyTelemetry[]>;
}
//# sourceMappingURL=telemetry.repository.d.ts.map