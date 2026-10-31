"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.AuditRepository = void 0;
const contracts_1 = require("@eh-home/contracts");
class AuditRepository {
    _db = null;
    static memoryEvents = [];
    static sequenceCounter = 1;
    constructor(app) {
        if (app && app.db) {
            this._db = app.db;
        }
    }
    async createEvent(event) {
        // Assert zero secrets before storage
        (0, contracts_1.assertNoSecretsInAuditPayload)(event.metadata);
        const validated = contracts_1.AuditRecordSchema.parse(event);
        validated.sequenceNumber = AuditRepository.sequenceCounter++;
        AuditRepository.memoryEvents.push(validated);
        return validated;
    }
    async queryEvents(filter) {
        let filtered = [...AuditRepository.memoryEvents];
        if (filter.actorId) {
            filtered = filtered.filter((e) => e.actorId === filter.actorId);
        }
        if (filter.action) {
            filtered = filtered.filter((e) => e.action === filter.action);
        }
        if (filter.resourceType) {
            filtered = filtered.filter((e) => e.resourceType === filter.resourceType);
        }
        if (filter.resourceId) {
            filtered = filtered.filter((e) => e.resourceId === filter.resourceId);
        }
        if (filter.outcome) {
            filtered = filtered.filter((e) => e.outcome === filter.outcome);
        }
        if (filter.severity) {
            filtered = filtered.filter((e) => e.severity === filter.severity);
        }
        if (filter.correlationId) {
            filtered = filtered.filter((e) => e.correlationId === filter.correlationId);
        }
        if (filter.startDate) {
            const startMs = new Date(filter.startDate).getTime();
            filtered = filtered.filter((e) => new Date(e.timestamp).getTime() >= startMs);
        }
        if (filter.endDate) {
            const endMs = new Date(filter.endDate).getTime();
            filtered = filtered.filter((e) => new Date(e.timestamp).getTime() <= endMs);
        }
        // Sort descending by timestamp / sequenceNumber
        filtered.sort((a, b) => (b.sequenceNumber || 0) - (a.sequenceNumber || 0));
        const total = filtered.length;
        const limit = filter.limit || 50;
        const offset = filter.offset || 0;
        const paginated = filtered.slice(offset, offset + limit);
        return { records: paginated, total };
    }
}
exports.AuditRepository = AuditRepository;
//# sourceMappingURL=audit.repository.js.map