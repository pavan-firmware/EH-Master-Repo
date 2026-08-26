'use strict';

/**
 * EH Home — Command Timeout Worker (Phase 7B)
 *
 * Responsibilities:
 * - Find SENT/CREATED commands whose expiresAt has passed
 * - Transition their status to TIMEOUT (per existing contract semantics)
 * - Emit command.receipt realtime event
 * - Never actuate hardware
 * - Idempotent: a command already TIMEOUT/APPLIED/FAILED is left unchanged
 * - Processes bounded batches to avoid unbounded DB scans
 *
 * Contract status mapping:
 *   CREATED/SENT → TIMEOUT (heartbeat missed before device ACK)
 */

const COMMAND_RECEIPT_EVENT = 'command.receipt';
const TIMEOUT_STATUS = 'TIMEOUT';
const PENDING_STATUSES = ['CREATED', 'SENT'];
const DEFAULT_BATCH_SIZE = 50;

class CommandTimeoutWorker {
  /**
   * @param {Object} opts
   * @param {Object}           opts.db          DbClient instance
   * @param {RealtimeEventBus} opts.eventBus
   * @param {number}           [opts.batchSize]
   */
  constructor({ db, eventBus, batchSize = DEFAULT_BATCH_SIZE }) {
    this.db = db;
    this.eventBus = eventBus;
    this.batchSize = batchSize;
  }

  /**
   * Called periodically by WorkerRunner.
   * Idempotent: processing an already-timed-out command has no effect.
   */
  async tick() {
    const now = new Date().toISOString();

    const expiredCommands = await this.db.find('device_commands', {
      where: {
        status_in: PENDING_STATUSES,
        expires_at_lt: now
      },
      limit: this.batchSize
    });

    for (const command of expiredCommands) {
      await this._timeoutCommand(command);
    }
  }

  async _timeoutCommand(command) {
    const { id: commandId, device_id: deviceId, home_id: homeId, status: previousStatus } = command;
    try {
      await this.db.update('device_commands', commandId, {
        status: TIMEOUT_STATUS,
        updated_at: new Date().toISOString()
      });

      this.eventBus.publish({
        homeId,
        type: COMMAND_RECEIPT_EVENT,
        deviceId,
        payload: {
          commandId,
          deviceId,
          homeId,
          status: TIMEOUT_STATUS,
          previousStatus,
          reason: 'timeout',
          timedOutAt: new Date().toISOString()
        }
      });
    } catch (err) {
      console.error(`[CommandTimeoutWorker] Failed to timeout command ${commandId}:`, err.message);
    }
  }
}

module.exports = { CommandTimeoutWorker, TIMEOUT_STATUS, PENDING_STATUSES, DEFAULT_BATCH_SIZE };
