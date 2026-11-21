/**
 * EH Home - Resilient Timestamped Automation Scheduler & Auto-Off Timer Engine
 * 
 * Features:
 *  - Minute-tracking (prevents skipped or duplicate schedules)
 *  - Second-accurate countdown timers (Auto-Off duration support)
 *  - Zero flash wear (in-RAM execution with SQLite WAL durability)
 */

const http = require('http');
const crypto = require('crypto');

class HubScheduler {
  constructor(storage, getDeviceFn) {
    this.storage = storage;
    this.getDeviceFn = getDeviceFn;
    this.lastEvaluatedMinute = null;
    this.timerHandle = null;
    this.onRoutineDispatched = null;
  }

  start() {
    if (this.timerHandle) return;
    // Tick every second for auto-off countdowns and minute boundary evaluation
    this.timerHandle = setInterval(() => this.tick(), 1000);
  }

  stop() {
    if (this.timerHandle) {
      clearInterval(this.timerHandle);
      this.timerHandle = null;
    }
  }

  tick() {
    const now = new Date();
    const nowEpoch = Math.floor(now.getTime() / 1000);

    // 1. Evaluate Active Auto-Off Countdown Timers (Every Second)
    this.evaluateActiveTimers(nowEpoch);

    // 2. Evaluate Minute Schedule Boundaries
    const currentHour = now.getHours();
    const currentMinute = now.getMinutes();
    const minuteKey = `${now.getFullYear()}-${now.getMonth() + 1}-${now.getDate()} ${currentHour}:${currentMinute}`;

    if (this.lastEvaluatedMinute === minuteKey) {
      return; // Already evaluated for this minute
    }
    this.lastEvaluatedMinute = minuteKey;

    const currentDay = now.getDay(); // 0 = Sun, 1 = Mon, ..., 6 = Sat
    const dayMask = 1 << currentDay;

    const routines = this.storage.getRoutines();
    for (const routine of routines) {
      if (!routine.enabled) continue;
      if ((routine.daysMask & dayMask) === 0) continue;
      if (routine.hour === currentHour && routine.minute === currentMinute) {
        this.dispatchRoutine(routine);
      }
    }
  }

  evaluateActiveTimers(nowEpoch) {
    const timers = this.storage.getActiveTimers();
    for (const timer of timers) {
      if (timer.fireAtEpoch <= nowEpoch) {
        // Time expired! Dispatch revert action (typically Turn OFF)
        this.dispatchRevertTimer(timer);
        this.storage.removeActiveTimer(timer.id);
      }
    }
  }

  dispatchRoutine(routine) {
    const target = this.getDeviceFn(routine.deviceId);
    const targetPower = Boolean(routine.targetState);

    if (target && target.ipAddress) {
      const postData = JSON.stringify({
        channel: routine.channel,
        channelIndex: routine.channel,
        power: targetPower,
        value: targetPower,
        enabled: targetPower,
        state: targetPower,
      });

      const req = http.request({
        hostname: target.ipAddress,
        port: 80,
        path: '/api/v1/control',
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Content-Length': Buffer.byteLength(postData),
        },
        timeout: 800,
      }, res => {
        if (target.channels) {
          target.channels[routine.channel] = targetPower;
        }
      });

      req.on('error', err => {
        console.warn(`[Hub Scheduler] Failed local HTTP dispatch to ${routine.deviceId}: ${err.message}`);
      });

      req.write(postData);
      req.end();
    } else {
      console.log(`[Hub Scheduler] Target switch ${routine.deviceId} dispatched (local simulated relay)`);
    }

    // If durationSec is set and turned ON, schedule automatic revert timer (Auto-Off)
    if (targetPower && routine.durationSec && routine.durationSec > 0) {
      const nowEpoch = Math.floor(Date.now() / 1000);
      const timerId = `tm_${crypto.randomBytes(6).toString('hex')}`;
      const activeTimer = {
        id: timerId,
        routineId: routine.id,
        deviceId: routine.deviceId,
        channel: routine.channel,
        targetState: false, // Revert to OFF
        fireAtEpoch: nowEpoch + routine.durationSec,
        createdAt: new Date().toISOString(),
      };
      this.storage.addActiveTimer(activeTimer);
      console.log(`[Hub Scheduler] Auto-Off timer armed: ${routine.name} will revert in ${routine.durationSec}s`);
    }

    if (typeof this.onRoutineDispatched === 'function') {
      this.onRoutineDispatched(routine);
    }
  }

  dispatchRevertTimer(timer) {
    const target = this.getDeviceFn(timer.deviceId);
    if (target && target.ipAddress) {
      const postData = JSON.stringify({
        channel: timer.channel,
        channelIndex: timer.channel,
        power: Boolean(timer.targetState),
        value: Boolean(timer.targetState),
        enabled: Boolean(timer.targetState),
        state: Boolean(timer.targetState),
      });

      const req = http.request({
        hostname: target.ipAddress,
        port: 80,
        path: '/api/v1/control',
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Content-Length': Buffer.byteLength(postData),
        },
        timeout: 800,
      }, res => {
        if (target.channels) {
          target.channels[timer.channel] = Boolean(timer.targetState);
        }
        console.log(`[Hub Scheduler] Auto-Off completed for ${timer.deviceId} Ch ${timer.channel} (reverted to OFF)`);
      });

      req.on('error', err => {
        console.warn(`[Hub Scheduler] Failed Auto-Off dispatch to ${timer.deviceId}: ${err.message}`);
      });

      req.write(postData);
      req.end();
    } else {
      console.log(`[Hub Scheduler] Auto-Off completed for ${timer.deviceId} Ch ${timer.channel} (simulated revert to OFF)`);
    }
  }

  triggerRoutineManual(routineId) {
    const routine = this.storage.getRoutine(routineId);
    if (!routine) return false;
    this.dispatchRoutine(routine);
    return true;
  }
}

module.exports = {
  HubScheduler,
};
