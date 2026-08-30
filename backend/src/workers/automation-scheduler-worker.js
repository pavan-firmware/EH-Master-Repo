'use strict';

/**
 * EH Home — AutomationSchedulerWorker (Phase 10)
 *
 * Background worker ticking every second to evaluate due schedules,
 * execute corresponding automations/scenes with strict idempotency locks,
 * and prevent duplicate executions across worker iterations and restarts.
 */

class AutomationSchedulerWorker {
  constructor({ scheduleRepo, scheduleService, pollIntervalMs = 1000 }) {
    this.scheduleRepo = scheduleRepo;
    this.scheduleService = scheduleService;
    this.pollIntervalMs = pollIntervalMs;

    this._timer = null;
    this._running = false;
    this._lockedScheduleIds = new Set();
    this._executedIdempotencyKeys = new Set();
  }

  start() {
    if (this._running) return;
    this._running = true;
    this._timer = setInterval(() => {
      this.tick().catch(err => {
        console.error('[AutomationSchedulerWorker] Error during tick:', err.message);
      });
    }, this.pollIntervalMs);
  }

  stop() {
    if (this._timer) {
      clearInterval(this._timer);
      this._timer = null;
    }
    this._running = false;
  }

  async tick(asOfDate = new Date()) {
    if (!this.scheduleRepo || !this.scheduleService) return [];

    const dueSchedules = await this.scheduleRepo.findDueSchedules(asOfDate);
    if (!dueSchedules || dueSchedules.length === 0) return [];

    const results = [];

    for (const schedule of dueSchedules) {
      // 1. In-memory execution lock guard
      if (this._lockedScheduleIds.has(schedule.id)) {
        continue;
      }

      // 2. Deterministic idempotency key guard
      const scheduledTimestamp = schedule.next_run_at || new Date(asOfDate).toISOString();
      const idempotencyKey = `schedule-${schedule.id}-${scheduledTimestamp}`;

      if (this._executedIdempotencyKeys.has(idempotencyKey)) {
        continue;
      }

      this._lockedScheduleIds.add(schedule.id);
      this._executedIdempotencyKeys.add(idempotencyKey);

      try {
        const res = await this.scheduleService.executeDueSchedule(schedule, asOfDate);
        results.push({ scheduleId: schedule.id, idempotencyKey, success: true, result: res });
      } catch (err) {
        console.error(`[AutomationSchedulerWorker] Failed executing schedule ${schedule.id}:`, err.message);
        results.push({ scheduleId: schedule.id, idempotencyKey, success: false, error: err.message });
      } finally {
        this._lockedScheduleIds.delete(schedule.id);
      }
    }

    // Keep idempotency set bounded
    if (this._executedIdempotencyKeys.size > 10000) {
      this._executedIdempotencyKeys.clear();
    }

    return results;
  }
}

module.exports = { AutomationSchedulerWorker };
