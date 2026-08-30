'use strict';

/**
 * EH Home — ScheduleService (Phase 10)
 *
 * Manages schedule configuration, next run timestamp calculations (daily, weekly, one-time),
 * and triggers associated automations or scenes.
 */

const crypto = require('crypto');

class ScheduleService {
  constructor({ scheduleRepo, homeAuthService, automationService = null, sceneService = null }) {
    this.scheduleRepo = scheduleRepo;
    this.homeAuthService = homeAuthService;
    this.automationService = automationService;
    this.sceneService = sceneService;
  }

  /**
   * Calculates the next execution timestamp for a schedule
   */
  calculateNextRun({
    scheduleType = 'daily',
    timeOfDay = '08:00',
    daysOfWeek = [],
    timezone = 'UTC',
    asOfDate = new Date()
  }) {
    const baseDate = new Date(asOfDate);
    const [targetHour, targetMinute] = (timeOfDay || '08:00').split(':').map(Number);

    if (scheduleType === 'one_time') {
      const target = new Date(baseDate);
      target.setUTCHours(targetHour, targetMinute, 0, 0);
      if (target <= baseDate) {
        // If already passed for today, set for tomorrow (or keep in past for expiration)
        target.setUTCDate(target.getUTCDate() + 1);
      }
      return target;
    }

    if (scheduleType === 'daily') {
      const target = new Date(baseDate);
      target.setUTCHours(targetHour, targetMinute, 0, 0);
      if (target <= baseDate) {
        target.setUTCDate(target.getUTCDate() + 1);
      }
      return target;
    }

    if (scheduleType === 'weekly') {
      const activeDays = Array.isArray(daysOfWeek) && daysOfWeek.length > 0
        ? daysOfWeek
        : [1, 2, 3, 4, 5, 6, 7]; // Default to all days

      // Find the earliest upcoming matching weekday
      for (let offset = 0; offset <= 7; offset++) {
        const candidate = new Date(baseDate);
        candidate.setUTCDate(candidate.getUTCDate() + offset);
        candidate.setUTCHours(targetHour, targetMinute, 0, 0);

        // JavaScript getUTCDay(): 0=Sun, 1=Mon, ..., 6=Sat
        // ISO weekday convention: 1=Mon, ..., 7=Sun
        const jsDay = candidate.getUTCDay();
        const isoDay = jsDay === 0 ? 7 : jsDay;

        if (activeDays.includes(isoDay)) {
          if (candidate > baseDate) {
            return candidate;
          }
        }
      }

      // Fallback: 7 days later
      const fallback = new Date(baseDate);
      fallback.setUTCDate(fallback.getUTCDate() + 7);
      fallback.setUTCHours(targetHour, targetMinute, 0, 0);
      return fallback;
    }

    // Default 24h fallback
    const fallback = new Date(baseDate);
    fallback.setUTCDate(fallback.getUTCDate() + 1);
    fallback.setUTCHours(targetHour, targetMinute, 0, 0);
    return fallback;
  }

  async createSchedule({
    homeId,
    userId,
    automationId = null,
    sceneId = null,
    name,
    scheduleType = 'daily',
    cronExpression = null,
    timeOfDay = '08:00',
    daysOfWeek = [],
    timezone = 'UTC',
    isEnabled = true
  }) {
    if (!name || name.trim() === '') {
      const err = new Error('Schedule name is required');
      err.statusCode = 400;
      throw err;
    }
    if (!automationId && !sceneId) {
      const err = new Error('Either automationId or sceneId is required for schedule');
      err.statusCode = 400;
      throw err;
    }

    if (this.homeAuthService) {
      await this.homeAuthService.requireMembership(userId, homeId);
    }

    const nextRunAt = this.calculateNextRun({
      scheduleType,
      timeOfDay,
      daysOfWeek,
      timezone,
      asOfDate: new Date()
    });

    const scheduleId = `sched_${crypto.randomUUID()}`;
    return this.scheduleRepo.createSchedule({
      id: scheduleId,
      homeId,
      automationId,
      sceneId,
      name: name.trim(),
      scheduleType,
      cronExpression,
      timeOfDay,
      daysOfWeek,
      timezone,
      isEnabled,
      nextRunAt
    });
  }

  async listSchedules({ homeId, userId }) {
    if (this.homeAuthService) {
      await this.homeAuthService.requireMembership(userId, homeId);
    }
    return this.scheduleRepo.findByHomeId(homeId);
  }

  async getSchedule({ homeId, userId, scheduleId }) {
    if (this.homeAuthService) {
      await this.homeAuthService.requireMembership(userId, homeId);
    }
    const sched = await this.scheduleRepo.findById(scheduleId);
    if (!sched || sched.home_id !== homeId) {
      const err = new Error(`Schedule ${scheduleId} not found in home ${homeId}`);
      err.statusCode = 404;
      throw err;
    }
    return sched;
  }

  async updateSchedule({ homeId, userId, scheduleId, updates }) {
    const existing = await this.getSchedule({ homeId, userId, scheduleId });
    const cleanUpdates = { ...updates };

    if (updates.scheduleType || updates.timeOfDay || updates.daysOfWeek) {
      cleanUpdates.nextRunAt = this.calculateNextRun({
        scheduleType: updates.scheduleType || existing.schedule_type,
        timeOfDay: updates.timeOfDay || existing.time_of_day,
        daysOfWeek: updates.daysOfWeek || existing.days_of_week,
        timezone: updates.timezone || existing.timezone,
        asOfDate: new Date()
      });
    }

    return this.scheduleRepo.updateSchedule(scheduleId, cleanUpdates);
  }

  async toggleSchedule({ homeId, userId, scheduleId, isEnabled }) {
    await this.getSchedule({ homeId, userId, scheduleId });
    return this.scheduleRepo.updateSchedule(scheduleId, { is_enabled: isEnabled });
  }

  async deleteSchedule({ homeId, userId, scheduleId }) {
    await this.getSchedule({ homeId, userId, scheduleId });
    return this.scheduleRepo.deleteSchedule(scheduleId);
  }

  /**
   * Execute a due schedule and advance its next_run_at timestamp
   */
  async executeDueSchedule(schedule, asOfDate = new Date()) {
    const scheduledTimestamp = schedule.next_run_at || new Date(asOfDate).toISOString();
    const executionIdentity = `schedule-${schedule.id}-${scheduledTimestamp}`;

    let result = null;

    if (schedule.automation_id && this.automationService) {
      result = await this.automationService.runAutomation({
        homeId: schedule.home_id,
        userId: 'system_scheduler',
        automationId: schedule.automation_id,
        triggerSource: 'schedule',
        executionIdentity,
        context: { asOfDate, scheduleId: schedule.id }
      });
    } else if (schedule.scene_id && this.sceneService) {
      result = await this.sceneService.runScene({
        homeId: schedule.home_id,
        userId: 'system_scheduler',
        sceneId: schedule.scene_id,
        executionIdentity
      });
    }

    // Calculate next run
    if (schedule.schedule_type === 'one_time') {
      await this.scheduleRepo.updateSchedule(schedule.id, {
        is_enabled: false,
        last_run_at: new Date(asOfDate).toISOString(),
        next_run_at: null
      });
    } else {
      const nextRunAt = this.calculateNextRun({
        scheduleType: schedule.schedule_type,
        timeOfDay: schedule.time_of_day,
        daysOfWeek: schedule.days_of_week,
        timezone: schedule.timezone,
        asOfDate
      });

      await this.scheduleRepo.updateRunTimestamp(schedule.id, {
        lastRunAt: asOfDate,
        nextRunAt
      });
    }

    return result;
  }
}

module.exports = { ScheduleService };
