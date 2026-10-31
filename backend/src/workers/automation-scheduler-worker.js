'use strict';

/**
 * EH Home — AutomationSchedulerWorker (Phase 10)
 *
 * Background worker ticking every second to evaluate due schedules,
 * execute corresponding automations/scenes with strict idempotency locks,
 * and prevent duplicate executions across worker iterations and restarts.
 */

class AutomationSchedulerWorker {
  constructor({ scheduleRepo, scheduleService, automationRepo = null, automationService = null, pollIntervalMs = 1000 }) {
    this.scheduleRepo = scheduleRepo;
    this.scheduleService = scheduleService;
    this.automationRepo = automationRepo;
    this.automationService = automationService;
    this.pollIntervalMs = pollIntervalMs;

    this._timer = null;
    this._running = false;
    this._lockedScheduleIds = new Set();
    this._executedIdempotencyKeys = new Set();
  }

  start() {
    if (this._running) return;
    this._running = true;
    console.log('[AutomationSchedulerWorker] Started 24/7 autonomous background automation worker.');
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

  _parseTimeToMinutes(str) {
    if (!str || typeof str !== 'string') return null;
    const clean = str.trim().toUpperCase();
    const match = clean.match(/(\d{1,2}):(\d{2})(?::\d{2})?\s*(AM|PM)?/);
    if (!match) return null;
    let h = parseInt(match[1], 10);
    const m = parseInt(match[2], 10);
    const ampm = match[3];
    if (ampm === 'PM' && h < 12) h += 12;
    if (ampm === 'AM' && h === 12) h = 0;
    return h * 60 + m;
  }

  async tick(asOfDate = new Date()) {
    const results = [];

    // 1. Evaluate explicit due schedules
    if (this.scheduleRepo && this.scheduleService) {
      try {
        const dueSchedules = await this.scheduleRepo.findDueSchedules(asOfDate);
        if (dueSchedules && dueSchedules.length > 0) {
          for (const schedule of dueSchedules) {
            if (this._lockedScheduleIds.has(schedule.id)) continue;
            const scheduledTimestamp = schedule.next_run_at || new Date(asOfDate).toISOString();

            // Safety guard: If schedule is overdue by more than 2 minutes (e.g., server was offline or restarted),
            // do NOT fire stale backlog actuations retroactively upon restart.
            const schedTimeMs = new Date(scheduledTimestamp).getTime();
            if (schedTimeMs < asOfDate.getTime() - 120000) {
              this._lockedScheduleIds.add(schedule.id);
              try {
                if (typeof this.scheduleRepo.updateSchedule === 'function') {
                  await this.scheduleRepo.updateSchedule(schedule.id, { lastRunAt: asOfDate.toISOString(), nextRunAt: null });
                }
              } catch (_) {}
              finally {
                this._lockedScheduleIds.delete(schedule.id);
              }
              continue;
            }

            const idempotencyKey = `schedule-${schedule.id}-${scheduledTimestamp}`;
            if (this._executedIdempotencyKeys.has(idempotencyKey)) continue;

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
        }
      } catch (sErr) {
        console.error('[AutomationSchedulerWorker] Error checking schedules:', sErr.message);
      }
    }

    // 2. Evaluate time-based automations autonomously 24/7
    if (this.automationRepo && this.automationService) {
      try {
        let timeAutomations = [];
        if (typeof this.automationRepo.findScheduledAutomations === 'function') {
          timeAutomations = await this.automationRepo.findScheduledAutomations();
        } else {
          timeAutomations = await this.automationRepo.findByTriggerType('TIME');
        }

        if (timeAutomations && timeAutomations.length > 0) {
          const currentMinutes = asOfDate.getHours() * 60 + asOfDate.getMinutes();
          const dayNames = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
          const currentDay = dayNames[asOfDate.getDay()];
          const dateMinuteKey = `${asOfDate.getFullYear()}-${asOfDate.getMonth()}-${asOfDate.getDate()}-${asOfDate.getHours()}:${asOfDate.getMinutes()}`;

          for (const auto of timeAutomations) {
            if (!auto.is_enabled) continue;

            // Prevent duplicate execution: Skip any automation designated for on-chip EDGE execution.
            // The ESP32 edge_routine_engine executes 'EDGE' routines locally; PostgreSQL only backs them up.
            const target = (auto.execution_target || (auto.trigger_config && auto.trigger_config.executionTarget) || 'CLOUD').toUpperCase();
            if (target === 'EDGE') {
              continue;
            }

            const trigType = (auto.trigger_type || '').toLowerCase();
            const trigCfg = auto.trigger_config || {};
            const kind = (trigCfg.kind || '').toLowerCase();
            if (trigType !== 'time' && trigType !== 'schedule' && kind !== 'timeschedule') {
              continue; // Do NOT evaluate non-time routines in time worker
            }

            const autoTimeStr = trigCfg.time || trigCfg.timeOfDay || trigCfg.detail || trigCfg.label || auto.description;
            const targetMins = this._parseTimeToMinutes(autoTimeStr);
            if (targetMins === null) continue;

            // Day of week check
            const days = Array.isArray(trigCfg.days) ? trigCfg.days : [];
            if (days.length > 0) {
              const matchesDay = days.some(d => {
                const cleanD = String(d).trim().toLowerCase();
                return cleanD.startsWith(currentDay.toLowerCase()) || currentDay.toLowerCase().startsWith(cleanD);
              });
              if (!matchesDay) continue;
            }

            // Check if current minute matches
            if (currentMinutes === targetMins) {
              const autoIdempotencyKey = `auto-${auto.id}-${dateMinuteKey}`;
              if (this._executedIdempotencyKeys.has(autoIdempotencyKey)) {
                continue;
              }
              this._executedIdempotencyKeys.add(autoIdempotencyKey);

              console.log(`[AutomationSchedulerWorker] Autonomous trigger fired for routine: "${auto.name}" (${auto.id}) at ${asOfDate.toLocaleTimeString()}`);
              try {
                const res = await this.automationService.runAutomation({
                  homeId: auto.home_id,
                  userId: 'system_scheduler',
                  automationId: auto.id,
                  triggerSource: 'time_schedule',
                  executionIdentity: autoIdempotencyKey
                });
                results.push({ automationId: auto.id, idempotencyKey: autoIdempotencyKey, success: true, result: res });
              } catch (aErr) {
                console.error(`[AutomationSchedulerWorker] Failed autonomous execution of routine ${auto.id}:`, aErr.message);
                results.push({ automationId: auto.id, idempotencyKey: autoIdempotencyKey, success: false, error: aErr.message });
              }
            }
          }
        }
      } catch (aErr) {
        console.error('[AutomationSchedulerWorker] Error checking automations:', aErr.message);
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
