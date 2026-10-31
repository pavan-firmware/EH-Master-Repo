"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.TelemetryRepository = void 0;
const crypto_1 = require("crypto");
class TelemetryRepository {
    db;
    inMemoryStore = new Map();
    constructor(db) {
        this.db = db;
    }
    async insertTelemetry(record) {
        if (!this.db || !this.db.insert) {
            // In-Memory store
            const list = this.inMemoryStore.get(record.deviceId) || [];
            list.push({ ...record, ingestedAt: new Date().toISOString() });
            this.inMemoryStore.set(record.deviceId, list);
            return;
        }
        // Drizzle DB insertion
        const { deviceTelemetryMeasurements } = require('@eh-home/db-schema');
        await this.db.insert(deviceTelemetryMeasurements).values({
            id: (0, crypto_1.randomUUID)(),
            deviceId: record.deviceId,
            channelIndex: record.channelIndex,
            vMv: record.v_mv,
            iMa: record.i_ma,
            pMw: record.p_mw,
            eTotWh: record.e_tot_wh,
            eIntMwh: record.e_int_mwh || 0,
            freqMhz: record.freq_mhz,
            pfX1000: record.pf_x1000,
            flags: record.flags,
            sequenceNumber: record.sequenceNumber,
            deviceTimestamp: record.timestamp,
            ingestedAt: new Date().toISOString()
        });
    }
    async getLatestTelemetry(deviceId, channelIndex = 1) {
        if (!this.db || !this.db.select) {
            const list = this.inMemoryStore.get(deviceId) || [];
            const matching = list.filter((t) => t.channelIndex === channelIndex);
            return matching.length > 0 ? matching[matching.length - 1] : null;
        }
        const { deviceTelemetryMeasurements, eq, and, desc } = require('@eh-home/db-schema');
        const rows = await this.db
            .select()
            .from(deviceTelemetryMeasurements)
            .where(and(eq(deviceTelemetryMeasurements.deviceId, deviceId), eq(deviceTelemetryMeasurements.channelIndex, channelIndex)))
            .orderBy(desc(deviceTelemetryMeasurements.deviceTimestamp))
            .limit(1);
        if (rows.length === 0)
            return null;
        const r = rows[0];
        return {
            schemaVersion: 1,
            deviceId: r.deviceId,
            channelIndex: r.channelIndex,
            v_mv: r.vMv,
            i_ma: r.iMa,
            p_mw: r.pMw,
            e_tot_wh: r.eTotWh,
            e_int_mwh: r.eIntMwh,
            freq_mhz: r.freqMhz,
            pf_x1000: r.pfX1000,
            flags: r.flags,
            sequenceNumber: r.sequenceNumber,
            timestamp: r.deviceTimestamp,
            ingestedAt: r.ingestedAt
        };
    }
    async queryTelemetry(filter) {
        if (!this.db || !this.db.select) {
            let list = this.inMemoryStore.get(filter.deviceId) || [];
            if (filter.channelIndex) {
                list = list.filter((t) => t.channelIndex === filter.channelIndex);
            }
            if (filter.startTime) {
                list = list.filter((t) => new Date(t.timestamp) >= new Date(filter.startTime));
            }
            if (filter.endTime) {
                list = list.filter((t) => new Date(t.timestamp) <= new Date(filter.endTime));
            }
            return list.slice(-filter.limit);
        }
        const { deviceTelemetryMeasurements, eq, and, gte, lte, desc } = require('@eh-home/db-schema');
        const conditions = [eq(deviceTelemetryMeasurements.deviceId, filter.deviceId)];
        if (filter.channelIndex) {
            conditions.push(eq(deviceTelemetryMeasurements.channelIndex, filter.channelIndex));
        }
        if (filter.startTime) {
            conditions.push(gte(deviceTelemetryMeasurements.deviceTimestamp, filter.startTime));
        }
        if (filter.endTime) {
            conditions.push(lte(deviceTelemetryMeasurements.deviceTimestamp, filter.endTime));
        }
        const rows = await this.db
            .select()
            .from(deviceTelemetryMeasurements)
            .where(and(...conditions))
            .orderBy(desc(deviceTelemetryMeasurements.deviceTimestamp))
            .limit(filter.limit);
        return rows.map((r) => ({
            schemaVersion: 1,
            deviceId: r.deviceId,
            channelIndex: r.channelIndex,
            v_mv: r.vMv,
            i_ma: r.iMa,
            p_mw: r.pMw,
            e_tot_wh: r.eTotWh,
            e_int_mwh: r.eIntMwh,
            freq_mhz: r.freqMhz,
            pf_x1000: r.pfX1000,
            flags: r.flags,
            sequenceNumber: r.sequenceNumber,
            timestamp: r.deviceTimestamp,
            ingestedAt: r.ingestedAt
        }));
    }
}
exports.TelemetryRepository = TelemetryRepository;
//# sourceMappingURL=telemetry.repository.js.map