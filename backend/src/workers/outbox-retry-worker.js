'use strict';

/**
 * EH Home — Outbox Retry Worker (Phase 7B)
 *
 * Responsibilities:
 * - Find pending outbox entries where retryCount < maxRetries
 * - Retry MQTT transport for transient failures
 * - Exponential backoff between retries
 * - Idempotent: command idempotency prevents duplicate hardware actuation
 * - Mark permanently failed entries (retry count exhausted)
 * - Process bounded batches
 *
 * NOTE: No dead-letter queue implemented yet.
 * Extension point: failed entries with exhausted retries could be pushed
 * to a DLQ or dead_letter_outbox table in a future phase.
 *
 * Outbox entry expected fields:
 *   id, home_id, device_id, command_id, payload (JSON), retry_count,
 *   max_retries, next_retry_at, status ('PENDING'|'DELIVERED'|'FAILED')
 */

const OUTBOX_PENDING_STATUS = 'PENDING';
const OUTBOX_FAILED_STATUS = 'FAILED';
const OUTBOX_DELIVERED_STATUS = 'DELIVERED';
const DEFAULT_MAX_RETRIES = 5;
const DEFAULT_BATCH_SIZE = 50;

// Exponential backoff: 5s, 10s, 20s, 40s, 80s
const BACKOFF_BASE_MS = 5_000;

class OutboxRetryWorker {
  /**
   * @param {Object}  opts
   * @param {Object}  opts.db              DbClient instance
   * @param {Function} opts.mqttPublish    (topic, payload) => Promise<void>
   * @param {number}  [opts.maxRetries]
   * @param {number}  [opts.batchSize]
   */
  constructor({ db, mqttPublish, maxRetries = DEFAULT_MAX_RETRIES, batchSize = DEFAULT_BATCH_SIZE }) {
    if (typeof mqttPublish !== 'function') {
      throw new Error('OutboxRetryWorker requires mqttPublish function');
    }
    this.db = db;
    this.mqttPublish = mqttPublish;
    this.maxRetries = maxRetries;
    this.batchSize = batchSize;
  }

  /**
   * Called periodically by WorkerRunner.
   * Idempotent: an already-delivered entry is left unchanged.
   */
  async tick() {
    const now = new Date().toISOString();

    const pendingEntries = await this.db.find('outbox', {
      where: {
        status: OUTBOX_PENDING_STATUS,
        next_retry_at_lte: now
      },
      limit: this.batchSize
    });

    for (const entry of pendingEntries) {
      await this._processEntry(entry);
    }
  }

  async _processEntry(entry) {
    const { id, device_id: deviceId, payload, retry_count: retryCount } = entry;

    if (retryCount >= this.maxRetries) {
      await this._markFailed(id, retryCount);
      return;
    }

    try {
      const topic = typeof payload === 'string' ? JSON.parse(payload).topic : payload.topic;
      const messagePayload = typeof payload === 'string' ? JSON.parse(payload).payload : payload.payload;
      await this.mqttPublish(topic, messagePayload);
      await this._markDelivered(id);
    } catch (err) {
      console.warn(`[OutboxRetryWorker] Retry ${retryCount + 1}/${this.maxRetries} failed for entry ${id}:`, err.message);
      await this._scheduleRetry(id, retryCount + 1);
    }
  }

  async _markDelivered(id) {
    await this.db.update('outbox', id, {
      status: OUTBOX_DELIVERED_STATUS,
      updated_at: new Date().toISOString()
    });
  }

  async _markFailed(id, retryCount) {
    console.error(`[OutboxRetryWorker] Entry ${id} exhausted ${retryCount} retries — marking FAILED`);
    await this.db.update('outbox', id, {
      status: OUTBOX_FAILED_STATUS,
      updated_at: new Date().toISOString()
    });
    // Future extension: push to DLQ/dead_letter_outbox table here
  }

  async _scheduleRetry(id, nextRetryCount) {
    const backoffMs = BACKOFF_BASE_MS * Math.pow(2, nextRetryCount - 1);
    const nextRetryAt = new Date(Date.now() + backoffMs).toISOString();
    await this.db.update('outbox', id, {
      retry_count: nextRetryCount,
      next_retry_at: nextRetryAt,
      updated_at: new Date().toISOString()
    });
  }

  /**
   * Compute the next retry delay in ms (for testing and documentation purposes).
   */
  static backoffMs(retryCount) {
    return BACKOFF_BASE_MS * Math.pow(2, retryCount - 1);
  }
}

module.exports = {
  OutboxRetryWorker,
  OUTBOX_PENDING_STATUS,
  OUTBOX_FAILED_STATUS,
  OUTBOX_DELIVERED_STATUS,
  DEFAULT_MAX_RETRIES,
  BACKOFF_BASE_MS
};
