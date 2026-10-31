"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.TelemetryIngestionService = void 0;
const contracts_1 = require("@eh-home/contracts");
class TelemetryIngestionService {
    repo;
    lastSequenceMap = new Map();
    onLiveUpdate;
    constructor(repo, onLiveUpdate) {
        this.repo = repo;
        this.onLiveUpdate = onLiveUpdate;
    }
    async ingest(rawPayload) {
        const parseResult = contracts_1.FixedPointEnergyTelemetrySchema.safeParse(rawPayload);
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
        const channelMap = this.lastSequenceMap.get(telem.deviceId);
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
    async getLatest(deviceId, channelIndex = 1) {
        return this.repo.getLatestTelemetry(deviceId, channelIndex);
    }
    async query(filter) {
        return this.repo.queryTelemetry({
            deviceId: filter.deviceId,
            channelIndex: filter.channelIndex,
            startTime: filter.startTime,
            endTime: filter.endTime,
            limit: filter.limit || 100
        });
    }
}
exports.TelemetryIngestionService = TelemetryIngestionService;
//# sourceMappingURL=telemetry.service.js.map