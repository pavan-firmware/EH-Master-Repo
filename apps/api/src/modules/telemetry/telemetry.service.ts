import { FixedPointEnergyTelemetry, FixedPointEnergyTelemetrySchema } from '@eh-home/contracts';
import { ITelemetryRepository } from './telemetry.repository';

export interface TelemetryIngestResult {
  accepted: boolean;
  status: 'ACCEPTED' | 'DROPPED_DUPLICATE' | 'REJECTED';
  reason?: string;
}

export class TelemetryIngestionService {
  private repo: ITelemetryRepository;
  private lastSequenceMap: Map<string, Map<number, number>> = new Map();
  private onLiveUpdate?: (telemetry: FixedPointEnergyTelemetry) => void;

  constructor(repo: ITelemetryRepository, onLiveUpdate?: (telemetry: FixedPointEnergyTelemetry) => void) {
    this.repo = repo;
    this.onLiveUpdate = onLiveUpdate;
  }

  public async ingest(rawPayload: unknown): Promise<TelemetryIngestResult> {
    const parseResult = FixedPointEnergyTelemetrySchema.safeParse(rawPayload);
    if (!parseResult.success) {
      return {
        accepted: false,
        status: 'REJECTED',
        reason: parseResult.error.errors.map((e) => `${e.path.join('.')}: ${e.message}`).join('; ')
      };
    }

    const telem = parseResult.data;

    // Sequence check & deduplication
    if (!this.lastSequenceMap.has(telem.deviceId)) {
      this.lastSequenceMap.set(telem.deviceId, new Map());
    }
    const channelMap = this.lastSequenceMap.get(telem.deviceId)!;
    const lastSeq = channelMap.get(telem.channelIndex) || 0;

    if (telem.sequenceNumber > 0 && telem.sequenceNumber <= lastSeq) {
      return {
        accepted: false,
        status: 'DROPPED_DUPLICATE',
        reason: `Sequence number ${telem.sequenceNumber} <= last sequence ${lastSeq}`
      };
    }

    channelMap.set(telem.channelIndex, telem.sequenceNumber);

    // Persist to telemetry store
    await this.repo.insertTelemetry(telem);

    if (this.onLiveUpdate) {
      this.onLiveUpdate(telem);
    }

    return {
      accepted: true,
      status: 'ACCEPTED'
    };
  }

  public async getLatest(deviceId: string, channelIndex = 1): Promise<FixedPointEnergyTelemetry | null> {
    return this.repo.getLatestTelemetry(deviceId, channelIndex);
  }

  public async query(filter: {
    deviceId: string;
    channelIndex?: number;
    startTime?: string;
    endTime?: string;
    limit?: number;
  }): Promise<FixedPointEnergyTelemetry[]> {
    return this.repo.queryTelemetry({
      deviceId: filter.deviceId,
      channelIndex: filter.channelIndex,
      startTime: filter.startTime,
      endTime: filter.endTime,
      limit: filter.limit || 100
    });
  }
}
