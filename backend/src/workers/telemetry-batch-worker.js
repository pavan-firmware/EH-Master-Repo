'use strict';

/**
 * EH Home — Telemetry & State Batch Ingestion Worker
 *
 * Implements batching to protect PostgreSQL against high-frequency MQTT telemetry spam.
 * Buffers measurements in memory (or BullMQ) and flushes in bulk every 2.0 seconds.
 */

class TelemetryBatchWorker {
  constructor({ telemetryRepo, redisStateCache = null, flushIntervalMs = 2000, maxBatchSize = 100 }) {
    this.telemetryRepo = telemetryRepo;
    this.redisStateCache = redisStateCache;
    this.flushIntervalMs = flushIntervalMs;
    this.maxBatchSize = maxBatchSize;
    this._buffer = [];
    this._timer = null;
    this._isFlushing = false;
  }

  start() {
    if (this._timer) return;
    this._timer = setInterval(() => {
      this.flush().catch(err => {
        console.warn('[TelemetryBatchWorker] Error during scheduled flush:', err.message);
      });
    }, this.flushIntervalMs);
  }

  enqueue(measurement) {
    if (!measurement) return;
    this._buffer.push(measurement);

    // If buffer exceeds max batch size, trigger immediate flush
    if (this._buffer.length >= this.maxBatchSize) {
      setImmediate(() => {
        this.flush().catch(() => {});
      });
    }
  }

  async flush() {
    if (this._isFlushing || this._buffer.length === 0) return;
    this._isFlushing = true;

    const toFlush = this._buffer.splice(0, this._buffer.length);

    try {
      if (this.telemetryRepo && typeof this.telemetryRepo.recordBatch === 'function') {
        await this.telemetryRepo.recordBatch(toFlush);
      } else if (this.telemetryRepo && typeof this.telemetryRepo.recordMeasurement === 'function') {
        for (const m of toFlush) {
          await this.telemetryRepo.recordMeasurement(m).catch(() => {});
        }
      }
    } catch (err) {
      console.warn('[TelemetryBatchWorker] Batch insertion failed:', err.message);
    } finally {
      this._isFlushing = false;
    }
  }

  async stop() {
    if (this._timer) {
      clearInterval(this._timer);
      this._timer = null;
    }
    await this.flush();
  }
}

module.exports = {
  TelemetryBatchWorker
};
