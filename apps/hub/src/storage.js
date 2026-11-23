/**
 * EH Home - Smart Hub Power-Cut Safe Storage Engine
 * Dual Engine: SQLite WAL Mode (when node:sqlite is present)
 * Fallback: Atomic WAL (Write-Ahead-Log + Atomic Temp Rename)
 */

const fs = require('fs');
const path = require('path');

class SQLiteWalEngine {
  constructor(dbPath) {
    this.type = 'sqlite-wal';
    const { DatabaseSync } = require('node:sqlite');
    this.db = new DatabaseSync(dbPath);
    this.db.exec('PRAGMA journal_mode = WAL;');
    this.db.exec('PRAGMA synchronous = NORMAL;');

    this.initTables();
  }

  initTables() {
    this.db.exec(`
      CREATE TABLE IF NOT EXISTS metadata (
        key TEXT PRIMARY KEY,
        value TEXT
      );

      CREATE TABLE IF NOT EXISTS devices (
        id TEXT PRIMARY KEY,
        name TEXT,
        ip_address TEXT,
        channel_count INTEGER,
        channels_json TEXT,
        active_routines_count INTEGER,
        has_critical_fallback INTEGER,
        online INTEGER,
        latency_ms INTEGER,
        last_seen_at TEXT
      );

      CREATE TABLE IF NOT EXISTS routines (
        id TEXT PRIMARY KEY,
        name TEXT,
        device_id TEXT,
        channel INTEGER,
        target_state INTEGER,
        hour INTEGER,
        minute INTEGER,
        days_mask INTEGER,
        duration_sec INTEGER,
        enabled INTEGER,
        critical_hardware_fallback INTEGER,
        trigger_type INTEGER,
        updated_at TEXT
      );

      CREATE TABLE IF NOT EXISTS active_timers (
        id TEXT PRIMARY KEY,
        routine_id TEXT,
        device_id TEXT,
        channel INTEGER,
        target_state INTEGER,
        fire_at_epoch INTEGER,
        created_at TEXT
      );

      CREATE TABLE IF NOT EXISTS rules (
        id TEXT PRIMARY KEY,
        name TEXT,
        enabled INTEGER,
        trigger_device_id TEXT,
        trigger_channel INTEGER,
        trigger_state INTEGER,
        action_device_id TEXT,
        action_device_ip TEXT,
        action_channel INTEGER,
        action_command TEXT,
        created_at TEXT,
        updated_at TEXT
      );

      CREATE TABLE IF NOT EXISTS execution_logs (
        id TEXT PRIMARY KEY,
        rule_id TEXT,
        rule_name TEXT,
        trigger_event TEXT,
        action_summary TEXT,
        latency_ms INTEGER,
        status TEXT,
        timestamp TEXT
      );

      CREATE TABLE IF NOT EXISTS energy_telemetry_hourly (
        id TEXT PRIMARY KEY,
        device_id TEXT,
        channel INTEGER,
        hour_epoch INTEGER,
        sample_count INTEGER,
        avg_power_w REAL,
        peak_power_w REAL,
        min_power_w REAL,
        energy_kwh REAL,
        voltage_v REAL,
        current_a REAL,
        updated_at TEXT
      );
      CREATE INDEX IF NOT EXISTS idx_energy_dev_ch_epoch ON energy_telemetry_hourly(device_id, channel, hour_epoch);
    `);
    this.migrateLegacyStateIfPresent();
  }

  migrateLegacyStateIfPresent() {
    try {
      const legacyFile = path.join(this.dataDir, 'hub-state.json');
      if (fs.existsSync(legacyFile)) {
        const content = fs.readFileSync(legacyFile, 'utf8');
        const legacy = JSON.parse(content);
        if (legacy.homeId && !this.getMetadata('homeId')) {
          this.setMetadata('homeId', legacy.homeId);
          if (legacy.claimToken) this.setMetadata('claimToken', legacy.claimToken);
          if (legacy.linkedAt) this.setMetadata('linkedAt', legacy.linkedAt);
        }
        if (Array.isArray(legacy.devices)) {
          for (const dev of legacy.devices) {
            if (dev.id && !this.getDevice(dev.id)) {
              this.upsertDevice(dev);
            }
          }
        }
      }
    } catch (_) {}
  }

  getMetadata(key, defaultVal = null) {
    const row = this.db.prepare('SELECT value FROM metadata WHERE key = ?').get(key);
    if (!row) return defaultVal;
    try {
      return JSON.parse(row.value);
    } catch (_) {
      return row.value;
    }
  }

  setMetadata(key, value) {
    const serialized = typeof value === 'object' ? JSON.stringify(value) : String(value);
    this.db.prepare(`
      INSERT INTO metadata (key, value) VALUES (?, ?)
      ON CONFLICT(key) DO UPDATE SET value = excluded.value
    `).run(key, serialized);
  }

  getAllMetadata() {
    const rows = this.db.prepare('SELECT key, value FROM metadata').all();
    const result = {};
    for (const r of rows) {
      try {
        result[r.key] = JSON.parse(r.value);
      } catch (_) {
        result[r.key] = r.value;
      }
    }
    return result;
  }

  getDevices() {
    const rows = this.db.prepare('SELECT * FROM devices').all();
    return rows.map(r => ({
      id: r.id,
      name: r.name,
      ipAddress: r.ip_address,
      channelCount: r.channel_count,
      channels: r.channels_json ? JSON.parse(r.channels_json) : {},
      activeRoutinesCount: r.active_routines_count,
      hasCriticalHardwareFallback: Boolean(r.has_critical_fallback),
      online: Boolean(r.online),
      latencyMs: r.latency_ms,
      lastSeenAt: r.last_seen_at,
    }));
  }

  getDevice(id) {
    const r = this.db.prepare('SELECT * FROM devices WHERE id = ?').get(id);
    if (!r) return null;
    return {
      id: r.id,
      name: r.name,
      ipAddress: r.ip_address,
      channelCount: r.channel_count,
      channels: r.channels_json ? JSON.parse(r.channels_json) : {},
      activeRoutinesCount: r.active_routines_count,
      hasCriticalHardwareFallback: Boolean(r.has_critical_fallback),
      online: Boolean(r.online),
      latencyMs: r.latency_ms,
      lastSeenAt: r.last_seen_at,
    };
  }

  upsertDevice(device) {
    this.db.prepare(`
      INSERT INTO devices (
        id, name, ip_address, channel_count, channels_json,
        active_routines_count, has_critical_fallback, online, latency_ms, last_seen_at
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      ON CONFLICT(id) DO UPDATE SET
        name = excluded.name,
        ip_address = excluded.ip_address,
        channel_count = excluded.channel_count,
        channels_json = excluded.channels_json,
        active_routines_count = excluded.active_routines_count,
        has_critical_fallback = excluded.has_critical_fallback,
        online = excluded.online,
        latency_ms = excluded.latency_ms,
        last_seen_at = excluded.last_seen_at
    `).run(
      device.id,
      device.name || `Switch (${device.id.slice(-4)})`,
      device.ipAddress || '',
      device.channelCount || 3,
      JSON.stringify(device.channels || {}),
      device.activeRoutinesCount || 0,
      device.hasCriticalHardwareFallback ? 1 : 0,
      device.online !== false ? 1 : 0,
      device.latencyMs || 3,
      device.lastSeenAt || new Date().toISOString()
    );
  }

  removeDevice(id) {
    this.db.prepare('DELETE FROM devices WHERE id = ?').run(id);
  }

  clearDevices() {
    this.db.exec('DELETE FROM devices;');
  }

  getRoutines() {
    const rows = this.db.prepare('SELECT * FROM routines').all();
    return rows.map(r => ({
      id: r.id,
      name: r.name,
      deviceId: r.device_id,
      channel: r.channel,
      targetState: Boolean(r.target_state),
      hour: r.hour,
      minute: r.minute,
      daysMask: r.days_mask,
      durationSec: r.duration_sec,
      enabled: Boolean(r.enabled),
      criticalHardwareFallback: Boolean(r.critical_hardware_fallback),
      triggerType: r.trigger_type,
      updatedAt: r.updated_at,
    }));
  }

  getRoutine(id) {
    const r = this.db.prepare('SELECT * FROM routines WHERE id = ?').get(id);
    if (!r) return null;
    return {
      id: r.id,
      name: r.name,
      deviceId: r.device_id,
      channel: r.channel,
      targetState: Boolean(r.target_state),
      hour: r.hour,
      minute: r.minute,
      daysMask: r.days_mask,
      durationSec: r.duration_sec,
      enabled: Boolean(r.enabled),
      criticalHardwareFallback: Boolean(r.critical_hardware_fallback),
      triggerType: r.trigger_type,
      updatedAt: r.updated_at,
    };
  }

  upsertRoutine(routine) {
    this.db.prepare(`
      INSERT INTO routines (
        id, name, device_id, channel, target_state, hour, minute,
        days_mask, duration_sec, enabled, critical_hardware_fallback, trigger_type, updated_at
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      ON CONFLICT(id) DO UPDATE SET
        name = excluded.name,
        device_id = excluded.device_id,
        channel = excluded.channel,
        target_state = excluded.target_state,
        hour = excluded.hour,
        minute = excluded.minute,
        days_mask = excluded.days_mask,
        duration_sec = excluded.duration_sec,
        enabled = excluded.enabled,
        critical_hardware_fallback = excluded.critical_hardware_fallback,
        trigger_type = excluded.trigger_type,
        updated_at = excluded.updated_at
    `).run(
      routine.id,
      routine.name || 'Unnamed Routine',
      routine.deviceId,
      routine.channel ?? 1,
      routine.targetState ? 1 : 0,
      routine.hour ?? 6,
      routine.minute ?? 0,
      routine.daysMask ?? 0x7F,
      routine.durationSec ?? 0,
      routine.enabled !== false ? 1 : 0,
      routine.criticalHardwareFallback ? 1 : 0,
      routine.triggerType ?? 2,
      routine.updatedAt || new Date().toISOString()
    );
  }

  deleteRoutine(id) {
    this.db.prepare('DELETE FROM routines WHERE id = ?').run(id);
  }

  clearRoutines() {
    this.db.exec('DELETE FROM routines;');
  }

  getActiveTimers() {
    const rows = this.db.prepare('SELECT * FROM active_timers').all();
    return rows.map(r => ({
      id: r.id,
      routineId: r.routine_id,
      deviceId: r.device_id,
      channel: r.channel,
      targetState: Boolean(r.target_state),
      fireAtEpoch: r.fire_at_epoch,
      createdAt: r.created_at,
    }));
  }

  addActiveTimer(timer) {
    this.db.prepare(`
      INSERT INTO active_timers (
        id, routine_id, device_id, channel, target_state, fire_at_epoch, created_at
      ) VALUES (?, ?, ?, ?, ?, ?, ?)
      ON CONFLICT(id) DO UPDATE SET
        fire_at_epoch = excluded.fire_at_epoch
    `).run(
      timer.id,
      timer.routineId,
      timer.deviceId,
      timer.channel,
      timer.targetState ? 1 : 0,
      timer.fireAtEpoch,
      timer.createdAt || new Date().toISOString()
    );
  }

  removeActiveTimer(id) {
    this.db.prepare('DELETE FROM active_timers WHERE id = ?').run(id);
  }

  clearActiveTimers() {
    this.db.exec('DELETE FROM active_timers;');
  }

  getRules() {
    const rows = this.db.prepare('SELECT * FROM rules').all();
    return rows.map(r => ({
      id: r.id,
      name: r.name,
      enabled: Boolean(r.enabled),
      triggerDeviceId: r.trigger_device_id,
      triggerChannel: r.trigger_channel,
      triggerState: r.trigger_state !== null ? Boolean(r.trigger_state) : null,
      actionDeviceId: r.action_device_id,
      actionDeviceIp: r.action_device_ip,
      actionChannel: r.action_channel,
      actionCommand: r.action_command,
      createdAt: r.created_at,
      updatedAt: r.updated_at,
    }));
  }

  getRule(id) {
    const r = this.db.prepare('SELECT * FROM rules WHERE id = ?').get(id);
    if (!r) return null;
    return {
      id: r.id,
      name: r.name,
      enabled: Boolean(r.enabled),
      triggerDeviceId: r.trigger_device_id,
      triggerChannel: r.trigger_channel,
      triggerState: r.trigger_state !== null ? Boolean(r.trigger_state) : null,
      actionDeviceId: r.action_device_id,
      actionDeviceIp: r.action_device_ip,
      actionChannel: r.action_channel,
      actionCommand: r.action_command,
      createdAt: r.created_at,
      updatedAt: r.updated_at,
    };
  }

  saveRule(rule) {
    this.db.prepare(`
      INSERT INTO rules (
        id, name, enabled, trigger_device_id, trigger_channel, trigger_state,
        action_device_id, action_device_ip, action_channel, action_command,
        created_at, updated_at
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      ON CONFLICT(id) DO UPDATE SET
        name = excluded.name,
        enabled = excluded.enabled,
        trigger_device_id = excluded.trigger_device_id,
        trigger_channel = excluded.trigger_channel,
        trigger_state = excluded.trigger_state,
        action_device_id = excluded.action_device_id,
        action_device_ip = excluded.action_device_ip,
        action_channel = excluded.action_channel,
        action_command = excluded.action_command,
        updated_at = excluded.updated_at
    `).run(
      rule.id,
      rule.name || 'Unnamed Rule',
      rule.enabled !== false ? 1 : 0,
      rule.triggerDeviceId,
      rule.triggerChannel,
      rule.triggerState !== null && rule.triggerState !== undefined ? (rule.triggerState ? 1 : 0) : null,
      rule.actionDeviceId,
      rule.actionDeviceIp,
      rule.actionChannel,
      rule.actionCommand || 'TOGGLE',
      rule.createdAt || new Date().toISOString(),
      rule.updatedAt || new Date().toISOString()
    );
  }

  deleteRule(id) {
    this.db.prepare('DELETE FROM rules WHERE id = ?').run(id);
  }

  clearRules() {
    this.db.exec('DELETE FROM rules;');
  }

  addExecutionLog(log) {
    this.db.prepare(`
      INSERT INTO execution_logs (
        id, rule_id, rule_name, trigger_event, action_summary, latency_ms, status, timestamp
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
    `).run(
      log.id || ('log_' + Date.now() + '_' + Math.random().toString(36).substring(2, 6)),
      log.ruleId,
      log.ruleName,
      log.triggerEvent,
      log.actionSummary,
      log.latencyMs || 0,
      log.status || 'OK',
      log.timestamp || new Date().toISOString()
    );
  }

  getExecutionLogs(limit = 50) {
    const rows = this.db.prepare('SELECT * FROM execution_logs ORDER BY timestamp DESC LIMIT ?').all(limit);
    return rows.map(r => ({
      id: r.id,
      ruleId: r.rule_id,
      ruleName: r.rule_name,
      triggerEvent: r.trigger_event,
      actionSummary: r.action_summary,
      latencyMs: r.latency_ms,
      status: r.status,
      timestamp: r.timestamp,
    }));
  }

  clearExecutionLogs() {
    this.db.exec('DELETE FROM execution_logs;');
  }

  recordEnergySample(sample) {
    const deviceId = sample.deviceId;
    const channel = sample.channel ?? 1;
    const powerW = Math.max(0, Number(sample.powerW ?? sample.activePower ?? sample.power ?? 0));
    const voltageV = Number(sample.voltageV ?? sample.voltage ?? 230);
    const currentA = Number(sample.currentA ?? sample.current ?? (powerW > 0 ? (powerW / voltageV) : 0));
    const now = sample.timestamp ? new Date(sample.timestamp) : new Date();
    const epochSec = Math.floor(now.getTime() / 1000);
    const hourEpoch = Math.floor(epochSec / 3600) * 3600;
    const id = `${deviceId}_ch${channel}_${hourEpoch}`;
    const isoString = now.toISOString();

    // Cache latest instantaneous reading in memory
    this.latestEnergy = this.latestEnergy || {};
    this.latestEnergy[`${deviceId}_${channel}`] = {
      deviceId,
      channel,
      voltageV,
      voltage: voltageV,
      currentA,
      current: currentA,
      powerW,
      activePower: powerW,
      power: powerW,
      timestamp: isoString,
    };

    const existing = this.db.prepare('SELECT * FROM energy_telemetry_hourly WHERE id = ?').get(id);
    if (!existing) {
      // First sample in this hour bucket (approximate 10s slice = 10 / 3600 h)
      const initialKwh = (powerW * 10) / 3600000;
      this.db.prepare(`
        INSERT INTO energy_telemetry_hourly (
          id, device_id, channel, hour_epoch, sample_count,
          avg_power_w, peak_power_w, min_power_w, energy_kwh, voltage_v, current_a, updated_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      `).run(id, deviceId, channel, hourEpoch, 1, powerW, powerW, powerW, initialKwh, voltageV, currentA, isoString);
    } else {
      const newCount = existing.sample_count + 1;
      const newAvg = ((existing.avg_power_w * existing.sample_count) + powerW) / newCount;
      const newPeak = Math.max(existing.peak_power_w, powerW);
      const newMin = Math.min(existing.min_power_w, powerW);
      const addedKwh = (powerW * 10) / 3600000;
      const newKwh = existing.energy_kwh + addedKwh;

      this.db.prepare(`
        UPDATE energy_telemetry_hourly SET
          sample_count = ?,
          avg_power_w = ?,
          peak_power_w = ?,
          min_power_w = ?,
          energy_kwh = ?,
          voltage_v = ?,
          current_a = ?,
          updated_at = ?
        WHERE id = ?
      `).run(newCount, newAvg, newPeak, newMin, newKwh, voltageV, currentA, isoString, id);
    }
  }

  getLatestEnergySample(deviceId, channel = 1) {
    this.latestEnergy = this.latestEnergy || {};
    const key = `${deviceId}_${channel}`;
    if (this.latestEnergy[key]) {
      return this.latestEnergy[key];
    }
    const row = this.db.prepare(`
      SELECT * FROM energy_telemetry_hourly
      WHERE device_id = ? AND channel = ?
      ORDER BY hour_epoch DESC LIMIT 1
    `).get(deviceId, channel);
    if (!row) {
      return {
        deviceId,
        channel,
        voltageV: 230,
        voltage: 230,
        currentA: 0,
        current: 0,
        powerW: 0,
        activePower: 0,
        power: 0,
        timestamp: new Date().toISOString(),
      };
    }
    return {
      deviceId: row.device_id,
      channel: row.channel,
      voltageV: row.voltage_v,
      voltage: row.voltage_v,
      currentA: row.current_a,
      current: row.current_a,
      powerW: row.avg_power_w,
      activePower: row.avg_power_w,
      power: row.avg_power_w,
      timestamp: row.updated_at,
    };
  }

  getDeviceEnergyHistory({ deviceId, channel = 1, period = 'today' }) {
    const nowSec = Math.floor(Date.now() / 1000);
    let startSec = nowSec - 86400; // default 24h
    if (period === 'today') {
      const d = new Date();
      d.setHours(0, 0, 0, 0);
      startSec = Math.floor(d.getTime() / 1000);
    } else if (period === 'week') {
      startSec = nowSec - (7 * 86400);
    } else if (period === 'month') {
      startSec = nowSec - (30 * 86400);
    } else if (period === 'year') {
      startSec = nowSec - (365 * 86400);
    }

    const rows = this.db.prepare(`
      SELECT * FROM energy_telemetry_hourly
      WHERE device_id = ? AND channel = ? AND hour_epoch >= ?
      ORDER BY hour_epoch ASC
    `).all(deviceId, channel, startSec);

    let totalEnergyKwh = 0;
    let peakPowerW = 0;
    let minPowerW = rows.length > 0 ? Infinity : 0;
    let sumPowerW = 0;
    let totalSamples = 0;

    const trends = rows.map(r => {
      totalEnergyKwh += r.energy_kwh;
      if (r.peak_power_w > peakPowerW) peakPowerW = r.peak_power_w;
      if (r.min_power_w < minPowerW) minPowerW = r.min_power_w;
      sumPowerW += r.avg_power_w;
      totalSamples += r.sample_count;

      return {
        timestamp: new Date(r.hour_epoch * 1000).toISOString(),
        energyKwh: Number(r.energy_kwh.toFixed(4)),
        powerW: Number(r.avg_power_w.toFixed(1)),
        cost: Number((r.energy_kwh * 0.15).toFixed(4)),
      };
    });

    const latest = this.getLatestEnergySample(deviceId, channel);
    const avgPowerW = rows.length > 0 ? Number((sumPowerW / rows.length).toFixed(1)) : 0;
    if (minPowerW === Infinity) minPowerW = 0;

    return {
      entityType: 'device',
      entityId: deviceId,
      channelIndex: channel,
      period,
      currentPowerW: latest ? latest.powerW : (rows.length ? rows[rows.length - 1].avg_power_w : 0),
      totalEnergyKwh: Number(totalEnergyKwh.toFixed(4)),
      peakPowerW: Number(peakPowerW.toFixed(1)),
      avgPowerW,
      minPowerW: Number(minPowerW.toFixed(1)),
      costEstimate: Number((totalEnergyKwh * 0.15).toFixed(2)),
      currency: 'USD',
      sampleCount: totalSamples,
      lastUpdated: latest ? latest.timestamp : new Date().toISOString(),
      trends,
    };
  }

  getHomeEnergySummary({ period = 'today' } = {}) {
    const nowSec = Math.floor(Date.now() / 1000);
    let startSec = nowSec - 86400;
    if (period === 'today') {
      const d = new Date();
      d.setHours(0, 0, 0, 0);
      startSec = Math.floor(d.getTime() / 1000);
    } else if (period === 'week') {
      startSec = nowSec - (7 * 86400);
    } else if (period === 'month') {
      startSec = nowSec - (30 * 86400);
    } else if (period === 'year') {
      startSec = nowSec - (365 * 86400);
    }

    const rows = this.db.prepare(`
      SELECT * FROM energy_telemetry_hourly
      WHERE hour_epoch >= ?
      ORDER BY hour_epoch ASC
    `).all(startSec);

    const devices = this.getDevices();
    const devMap = new Map(devices.map(d => [d.id, d.name]));

    let homeTotalKwh = 0;
    let homePeakPowerW = 0;
    let homeCurrentPowerW = 0;
    const deviceKwhMap = new Map();
    const epochMap = new Map();

    for (const r of rows) {
      homeTotalKwh += r.energy_kwh;
      if (r.peak_power_w > homePeakPowerW) homePeakPowerW = r.peak_power_w;

      const currentDevKwh = deviceKwhMap.get(r.device_id) || 0;
      deviceKwhMap.set(r.device_id, currentDevKwh + r.energy_kwh);

      const epData = epochMap.get(r.hour_epoch) || { kwh: 0, powerSum: 0, count: 0 };
      epData.kwh += r.energy_kwh;
      epData.powerSum += r.avg_power_w;
      epData.count += 1;
      epochMap.set(r.hour_epoch, epData);
    }

    // Compute live current power from registered devices
    this.latestEnergy = this.latestEnergy || {};
    for (const d of devices) {
      const sample = this.latestEnergy[`${d.id}_1`];
      if (sample) {
        homeCurrentPowerW += sample.powerW;
      }
    }

    const topDevices = Array.from(deviceKwhMap.entries())
      .map(([id, kwh]) => ({
        deviceId: id,
        name: devMap.get(id) || `Switch (${id.slice(-4)})`,
        energyKwh: Number(kwh.toFixed(3)),
        percentage: homeTotalKwh > 0 ? Number(((kwh / homeTotalKwh) * 100).toFixed(1)) : 0,
      }))
      .sort((a, b) => b.energyKwh - a.energyKwh);

    const trends = Array.from(epochMap.entries())
      .sort((a, b) => a[0] - b[0])
      .map(([epoch, d]) => ({
        timestamp: new Date(epoch * 1000).toISOString(),
        energyKwh: Number(d.kwh.toFixed(4)),
        powerW: d.count > 0 ? Number((d.powerSum / d.count).toFixed(1)) : 0,
        cost: Number((d.kwh * 0.15).toFixed(4)),
      }));

    return {
      entityType: 'home',
      entityId: this.getMetadata('homeId', 'home_main'),
      period,
      currentPowerW: Number(homeCurrentPowerW.toFixed(1)),
      totalEnergyKwh: Number(homeTotalKwh.toFixed(3)),
      totalKwhToday: Number(homeTotalKwh.toFixed(3)),
      peakPowerW: Number(homePeakPowerW.toFixed(1)),
      avgPowerW: trends.length > 0 ? Number((trends.reduce((acc, t) => acc + t.powerW, 0) / trends.length).toFixed(1)) : 0,
      costEstimate: Number((homeTotalKwh * 0.15).toFixed(2)),
      currency: 'USD',
      devicesCount: devices.length,
      sampleCount: rows.length,
      lastUpdated: new Date().toISOString(),
      topDevices,
      trends,
    };
  }

  pruneEnergyTelemetry(retentionDays = 365) {
    const cutoffSec = Math.floor(Date.now() / 1000) - (retentionDays * 86400);
    this.db.prepare('DELETE FROM energy_telemetry_hourly WHERE hour_epoch < ?').run(cutoffSec);
  }

  exportSnapshot() {
    return {
      version: '1.1.0',
      exportedAt: new Date().toISOString(),
      engine: this.type,
      metadata: this.getAllMetadata(),
      devices: this.getDevices(),
      routines: this.getRoutines(),
      activeTimers: this.getActiveTimers(),
      rules: this.getRules(),
      executionLogs: this.getExecutionLogs(100),
    };
  }

  restoreSnapshot(snapshot) {
    if (!snapshot || typeof snapshot !== 'object') throw new Error('Invalid snapshot payload');
    if (snapshot.metadata) {
      for (const [k, v] of Object.entries(snapshot.metadata)) {
        this.setMetadata(k, v);
      }
    }
    if (Array.isArray(snapshot.devices)) {
      for (const d of snapshot.devices) this.upsertDevice(d);
    }
    if (Array.isArray(snapshot.routines)) {
      for (const r of snapshot.routines) this.upsertRoutine(r);
    }
    if (Array.isArray(snapshot.rules)) {
      for (const ru of snapshot.rules) this.saveRule(ru);
    }
    return true;
  }

  wipeAll() {
    this.db.exec(`
      DELETE FROM metadata;
      DELETE FROM devices;
      DELETE FROM routines;
      DELETE FROM active_timers;
      DELETE FROM rules;
      DELETE FROM execution_logs;
      DELETE FROM energy_telemetry_hourly;
    `);
    this.latestEnergy = {};
  }

  close() {
    try {
      this.db.close();
    } catch (_) {}
  }
}

class AtomicWalEngine {
  constructor(dataDir) {
    this.type = 'atomic-wal';
    this.dataDir = dataDir;
    if (!fs.existsSync(dataDir)) {
      try {
        fs.mkdirSync(dataDir, { recursive: true });
      } catch (_) {}
    }
    this.dbFile = path.join(dataDir, 'hub-database.json');
    this.walFile = path.join(dataDir, 'hub-database.wal');
    this.tmpFile = path.join(dataDir, 'hub-database.tmp');

    this.state = {
      metadata: {},
      devices: {},
      routines: {},
      activeTimers: {},
      rules: {},
      executionLogs: [],
      energyTelemetry: {},
    };

    this.loadAndReplay();
  }

  loadAndReplay() {
    if (fs.existsSync(this.dbFile)) {
      try {
        const raw = fs.readFileSync(this.dbFile, 'utf8');
        this.state = JSON.parse(raw);
        this.state.metadata = this.state.metadata || {};
        this.state.devices = this.state.devices || {};
        this.state.routines = this.state.routines || {};
        this.state.activeTimers = this.state.activeTimers || {};
        this.state.rules = this.state.rules || {};
        this.state.executionLogs = this.state.executionLogs || [];
        this.state.energyTelemetry = this.state.energyTelemetry || {};
      } catch (e) {
        console.warn('[Storage:WAL] Corrupt master JSON detected, initializing clean baseline:', e.message);
      }
    }

    if (fs.existsSync(this.walFile)) {
      try {
        const walContent = fs.readFileSync(this.walFile, 'utf8');
        const lines = walContent.split('\n').filter(Boolean);
        for (const line of lines) {
          try {
            const entry = JSON.parse(line);
            this.applyWalEntry(entry);
          } catch (_) {}
        }
        // Checkpoint to master and clear WAL
        this.checkpoint();
      } catch (e) {
        console.warn('[Storage:WAL] Failed replaying WAL file:', e.message);
      }
    }
    this.migrateLegacyStateIfPresent();
  }

  migrateLegacyStateIfPresent() {
    try {
      const legacyFile = path.join(this.dataDir, 'hub-state.json');
      if (fs.existsSync(legacyFile)) {
        const content = fs.readFileSync(legacyFile, 'utf8');
        const legacy = JSON.parse(content);
        if (legacy.homeId && !this.getMetadata('homeId')) {
          this.setMetadata('homeId', legacy.homeId);
          if (legacy.claimToken) this.setMetadata('claimToken', legacy.claimToken);
          if (legacy.linkedAt) this.setMetadata('linkedAt', legacy.linkedAt);
        }
        if (Array.isArray(legacy.devices)) {
          for (const dev of legacy.devices) {
            if (dev.id && !this.getDevice(dev.id)) {
              this.upsertDevice(dev);
            }
          }
        }
      }
    } catch (_) {}
  }

  applyWalEntry(entry) {
    const { op, table, key, data } = entry;
    if (op === 'SET') {
      this.state[table] = this.state[table] || {};
      this.state[table][key] = data;
    } else if (op === 'DEL') {
      if (this.state[table]) {
        delete this.state[table][key];
      }
    } else if (op === 'CLEAR') {
      this.state[table] = {};
    }
  }

  appendWal(op, table, key, data = null) {
    const entry = JSON.stringify({ op, table, key, data, ts: Date.now() }) + '\n';
    try {
      fs.appendFileSync(this.walFile, entry, 'utf8');
    } catch (_) {}
  }

  checkpoint() {
    try {
      const payload = JSON.stringify(this.state, null, 2);
      fs.writeFileSync(this.tmpFile, payload, 'utf8');
      fs.renameSync(this.tmpFile, this.dbFile);
      if (fs.existsSync(this.walFile)) {
        fs.unlinkSync(this.walFile);
      }
    } catch (e) {
      console.warn('[Storage:WAL] Checkpoint failed:', e.message);
    }
  }

  getMetadata(key, defaultVal = null) {
    return this.state.metadata[key] !== undefined ? this.state.metadata[key] : defaultVal;
  }

  setMetadata(key, value) {
    this.state.metadata[key] = value;
    this.appendWal('SET', 'metadata', key, value);
    this.checkpoint();
  }

  getAllMetadata() {
    return { ...this.state.metadata };
  }

  getDevices() {
    return Object.values(this.state.devices);
  }

  getDevice(id) {
    return this.state.devices[id] || null;
  }

  upsertDevice(device) {
    const d = {
      id: device.id,
      name: device.name || `Switch (${device.id.slice(-4)})`,
      ipAddress: device.ipAddress || '',
      channelCount: device.channelCount || 3,
      channels: device.channels || {},
      activeRoutinesCount: device.activeRoutinesCount || 0,
      hasCriticalHardwareFallback: Boolean(device.hasCriticalHardwareFallback),
      online: device.online !== false,
      latencyMs: device.latencyMs || 3,
      lastSeenAt: device.lastSeenAt || new Date().toISOString(),
    };
    this.state.devices[d.id] = d;
    this.appendWal('SET', 'devices', d.id, d);
    this.checkpoint();
  }

  removeDevice(id) {
    delete this.state.devices[id];
    this.appendWal('DEL', 'devices', id);
    this.checkpoint();
  }

  clearDevices() {
    this.state.devices = {};
    this.appendWal('CLEAR', 'devices', null);
    this.checkpoint();
  }

  getRoutines() {
    return Object.values(this.state.routines);
  }

  getRoutine(id) {
    return this.state.routines[id] || null;
  }

  upsertRoutine(routine) {
    const r = {
      id: routine.id,
      name: routine.name || 'Unnamed Routine',
      deviceId: routine.deviceId,
      channel: routine.channel ?? 1,
      targetState: Boolean(routine.targetState),
      hour: routine.hour ?? 6,
      minute: routine.minute ?? 0,
      daysMask: routine.daysMask ?? 0x7F,
      durationSec: routine.durationSec ?? 0,
      enabled: routine.enabled !== false,
      criticalHardwareFallback: Boolean(routine.criticalHardwareFallback),
      triggerType: routine.triggerType ?? 2,
      updatedAt: routine.updatedAt || new Date().toISOString(),
    };
    this.state.routines[r.id] = r;
    this.appendWal('SET', 'routines', r.id, r);
    this.checkpoint();
  }

  deleteRoutine(id) {
    delete this.state.routines[id];
    this.appendWal('DEL', 'routines', id);
    this.checkpoint();
  }

  clearRoutines() {
    this.state.routines = {};
    this.appendWal('CLEAR', 'routines', null);
    this.checkpoint();
  }

  getActiveTimers() {
    return Object.values(this.state.activeTimers);
  }

  addActiveTimer(timer) {
    this.state.activeTimers[timer.id] = timer;
    this.appendWal('SET', 'activeTimers', timer.id, timer);
    this.checkpoint();
  }

  removeActiveTimer(id) {
    delete this.state.activeTimers[id];
    this.appendWal('DEL', 'activeTimers', id);
    this.checkpoint();
  }

  clearActiveTimers() {
    this.state.activeTimers = {};
    this.appendWal('CLEAR', 'activeTimers', null);
    this.checkpoint();
  }

  getRules() {
    return Object.values(this.state.rules || {});
  }

  getRule(id) {
    return (this.state.rules || {})[id] || null;
  }

  saveRule(rule) {
    this.state.rules = this.state.rules || {};
    this.state.rules[rule.id] = rule;
    this.appendWal('SET', 'rules', rule.id, rule);
    this.checkpoint();
  }

  deleteRule(id) {
    if (this.state.rules) {
      delete this.state.rules[id];
    }
    this.appendWal('DEL', 'rules', id);
    this.checkpoint();
  }

  clearRules() {
    this.state.rules = {};
    this.appendWal('CLEAR', 'rules', null);
    this.checkpoint();
  }

  addExecutionLog(log) {
    this.state.executionLogs = this.state.executionLogs || [];
    this.state.executionLogs.unshift(log);
    if (this.state.executionLogs.length > 50) this.state.executionLogs.pop();
    this.appendWal('SET', 'executionLogs', log.id, log);
    this.checkpoint();
  }

  getExecutionLogs(limit = 50) {
    return (this.state.executionLogs || []).slice(0, limit);
  }

  clearExecutionLogs() {
    this.state.executionLogs = [];
    this.appendWal('CLEAR', 'executionLogs', null);
    this.checkpoint();
  }

  recordEnergySample(sample) {
    this.state.energyTelemetry = this.state.energyTelemetry || {};
    const deviceId = sample.deviceId;
    const channel = sample.channel ?? 1;
    const powerW = Math.max(0, Number(sample.powerW ?? sample.activePower ?? sample.power ?? 0));
    const voltageV = Number(sample.voltageV ?? sample.voltage ?? 230);
    const currentA = Number(sample.currentA ?? sample.current ?? (powerW > 0 ? (powerW / voltageV) : 0));
    const now = sample.timestamp ? new Date(sample.timestamp) : new Date();
    const epochSec = Math.floor(now.getTime() / 1000);
    const hourEpoch = Math.floor(epochSec / 3600) * 3600;
    const id = `${deviceId}_ch${channel}_${hourEpoch}`;
    const isoString = now.toISOString();

    this.latestEnergy = this.latestEnergy || {};
    this.latestEnergy[`${deviceId}_${channel}`] = {
      deviceId,
      channel,
      voltageV,
      voltage: voltageV,
      currentA,
      current: currentA,
      powerW,
      activePower: powerW,
      power: powerW,
      timestamp: isoString,
    };

    const existing = this.state.energyTelemetry[id];
    if (!existing) {
      const initialKwh = (powerW * 10) / 3600000;
      const rec = {
        id,
        device_id: deviceId,
        channel,
        hour_epoch: hourEpoch,
        sample_count: 1,
        avg_power_w: powerW,
        peak_power_w: powerW,
        min_power_w: powerW,
        energy_kwh: initialKwh,
        voltage_v: voltageV,
        current_a: currentA,
        updated_at: isoString,
      };
      this.state.energyTelemetry[id] = rec;
      this.appendWal('SET', 'energyTelemetry', id, rec);
    } else {
      const newCount = existing.sample_count + 1;
      const newAvg = ((existing.avg_power_w * existing.sample_count) + powerW) / newCount;
      const newPeak = Math.max(existing.peak_power_w, powerW);
      const newMin = Math.min(existing.min_power_w, powerW);
      const addedKwh = (powerW * 10) / 3600000;
      const newKwh = existing.energy_kwh + addedKwh;

      const rec = {
        ...existing,
        sample_count: newCount,
        avg_power_w: newAvg,
        peak_power_w: newPeak,
        min_power_w: newMin,
        energy_kwh: newKwh,
        voltage_v: voltageV,
        current_a: currentA,
        updated_at: isoString,
      };
      this.state.energyTelemetry[id] = rec;
      this.appendWal('SET', 'energyTelemetry', id, rec);
    }
    this.checkpoint();
  }

  getLatestEnergySample(deviceId, channel = 1) {
    this.latestEnergy = this.latestEnergy || {};
    const key = `${deviceId}_${channel}`;
    if (this.latestEnergy[key]) {
      return this.latestEnergy[key];
    }
    const all = Object.values(this.state.energyTelemetry || {})
      .filter(r => r.device_id === deviceId && r.channel === channel)
      .sort((a, b) => b.hour_epoch - a.hour_epoch);

    if (all.length === 0) {
      return {
        deviceId,
        channel,
        voltageV: 230,
        voltage: 230,
        currentA: 0,
        current: 0,
        powerW: 0,
        activePower: 0,
        power: 0,
        timestamp: new Date().toISOString(),
      };
    }
    const row = all[0];
    return {
      deviceId: row.device_id,
      channel: row.channel,
      voltageV: row.voltage_v,
      voltage: row.voltage_v,
      currentA: row.current_a,
      current: row.current_a,
      powerW: row.avg_power_w,
      activePower: row.avg_power_w,
      power: row.avg_power_w,
      timestamp: row.updated_at,
    };
  }

  getDeviceEnergyHistory({ deviceId, channel = 1, period = 'today' }) {
    const nowSec = Math.floor(Date.now() / 1000);
    let startSec = nowSec - 86400;
    if (period === 'today') {
      const d = new Date();
      d.setHours(0, 0, 0, 0);
      startSec = Math.floor(d.getTime() / 1000);
    } else if (period === 'week') {
      startSec = nowSec - (7 * 86400);
    } else if (period === 'month') {
      startSec = nowSec - (30 * 86400);
    } else if (period === 'year') {
      startSec = nowSec - (365 * 86400);
    }

    const rows = Object.values(this.state.energyTelemetry || {})
      .filter(r => r.device_id === deviceId && r.channel === channel && r.hour_epoch >= startSec)
      .sort((a, b) => a.hour_epoch - b.hour_epoch);

    let totalEnergyKwh = 0;
    let peakPowerW = 0;
    let minPowerW = rows.length > 0 ? Infinity : 0;
    let sumPowerW = 0;
    let totalSamples = 0;

    const trends = rows.map(r => {
      totalEnergyKwh += r.energy_kwh;
      if (r.peak_power_w > peakPowerW) peakPowerW = r.peak_power_w;
      if (r.min_power_w < minPowerW) minPowerW = r.min_power_w;
      sumPowerW += r.avg_power_w;
      totalSamples += r.sample_count;

      return {
        timestamp: new Date(r.hour_epoch * 1000).toISOString(),
        energyKwh: Number(r.energy_kwh.toFixed(4)),
        powerW: Number(r.avg_power_w.toFixed(1)),
        cost: Number((r.energy_kwh * 0.15).toFixed(4)),
      };
    });

    const latest = this.getLatestEnergySample(deviceId, channel);
    const avgPowerW = rows.length > 0 ? Number((sumPowerW / rows.length).toFixed(1)) : 0;
    if (minPowerW === Infinity) minPowerW = 0;

    return {
      entityType: 'device',
      entityId: deviceId,
      channelIndex: channel,
      period,
      currentPowerW: latest ? latest.powerW : (rows.length ? rows[rows.length - 1].avg_power_w : 0),
      totalEnergyKwh: Number(totalEnergyKwh.toFixed(4)),
      peakPowerW: Number(peakPowerW.toFixed(1)),
      avgPowerW,
      minPowerW: Number(minPowerW.toFixed(1)),
      costEstimate: Number((totalEnergyKwh * 0.15).toFixed(2)),
      currency: 'USD',
      sampleCount: totalSamples,
      lastUpdated: latest ? latest.timestamp : new Date().toISOString(),
      trends,
    };
  }

  getHomeEnergySummary({ period = 'today' } = {}) {
    const nowSec = Math.floor(Date.now() / 1000);
    let startSec = nowSec - 86400;
    if (period === 'today') {
      const d = new Date();
      d.setHours(0, 0, 0, 0);
      startSec = Math.floor(d.getTime() / 1000);
    } else if (period === 'week') {
      startSec = nowSec - (7 * 86400);
    } else if (period === 'month') {
      startSec = nowSec - (30 * 86400);
    } else if (period === 'year') {
      startSec = nowSec - (365 * 86400);
    }

    const rows = Object.values(this.state.energyTelemetry || {})
      .filter(r => r.hour_epoch >= startSec)
      .sort((a, b) => a.hour_epoch - b.hour_epoch);

    const devices = this.getDevices();
    const devMap = new Map(devices.map(d => [d.id, d.name]));

    let homeTotalKwh = 0;
    let homePeakPowerW = 0;
    let homeCurrentPowerW = 0;
    const deviceKwhMap = new Map();
    const epochMap = new Map();

    for (const r of rows) {
      homeTotalKwh += r.energy_kwh;
      if (r.peak_power_w > homePeakPowerW) homePeakPowerW = r.peak_power_w;

      const currentDevKwh = deviceKwhMap.get(r.device_id) || 0;
      deviceKwhMap.set(r.device_id, currentDevKwh + r.energy_kwh);

      const epData = epochMap.get(r.hour_epoch) || { kwh: 0, powerSum: 0, count: 0 };
      epData.kwh += r.energy_kwh;
      epData.powerSum += r.avg_power_w;
      epData.count += 1;
      epochMap.set(r.hour_epoch, epData);
    }

    this.latestEnergy = this.latestEnergy || {};
    for (const d of devices) {
      const sample = this.latestEnergy[`${d.id}_1`];
      if (sample) {
        homeCurrentPowerW += sample.powerW;
      }
    }

    const topDevices = Array.from(deviceKwhMap.entries())
      .map(([id, kwh]) => ({
        deviceId: id,
        name: devMap.get(id) || `Switch (${id.slice(-4)})`,
        energyKwh: Number(kwh.toFixed(3)),
        percentage: homeTotalKwh > 0 ? Number(((kwh / homeTotalKwh) * 100).toFixed(1)) : 0,
      }))
      .sort((a, b) => b.energyKwh - a.energyKwh);

    const trends = Array.from(epochMap.entries())
      .sort((a, b) => a[0] - b[0])
      .map(([epoch, d]) => ({
        timestamp: new Date(epoch * 1000).toISOString(),
        energyKwh: Number(d.kwh.toFixed(4)),
        powerW: d.count > 0 ? Number((d.powerSum / d.count).toFixed(1)) : 0,
        cost: Number((d.kwh * 0.15).toFixed(4)),
      }));

    return {
      entityType: 'home',
      entityId: this.getMetadata('homeId', 'home_main'),
      period,
      currentPowerW: Number(homeCurrentPowerW.toFixed(1)),
      totalEnergyKwh: Number(homeTotalKwh.toFixed(3)),
      totalKwhToday: Number(homeTotalKwh.toFixed(3)),
      peakPowerW: Number(homePeakPowerW.toFixed(1)),
      avgPowerW: trends.length > 0 ? Number((trends.reduce((acc, t) => acc + t.powerW, 0) / trends.length).toFixed(1)) : 0,
      costEstimate: Number((homeTotalKwh * 0.15).toFixed(2)),
      currency: 'USD',
      devicesCount: devices.length,
      sampleCount: rows.length,
      lastUpdated: new Date().toISOString(),
      topDevices,
      trends,
    };
  }

  pruneEnergyTelemetry(retentionDays = 365) {
    const cutoffSec = Math.floor(Date.now() / 1000) - (retentionDays * 86400);
    for (const [id, rec] of Object.entries(this.state.energyTelemetry || {})) {
      if (rec.hour_epoch < cutoffSec) {
        delete this.state.energyTelemetry[id];
        this.appendWal('DEL', 'energyTelemetry', id);
      }
    }
    this.checkpoint();
  }

  exportSnapshot() {
    return {
      version: '1.1.0',
      exportedAt: new Date().toISOString(),
      engine: this.type,
      metadata: this.getAllMetadata(),
      devices: this.getDevices(),
      routines: this.getRoutines(),
      activeTimers: this.getActiveTimers(),
      rules: this.getRules(),
      executionLogs: this.getExecutionLogs(100),
    };
  }

  restoreSnapshot(snapshot) {
    if (!snapshot || typeof snapshot !== 'object') throw new Error('Invalid snapshot payload');
    if (snapshot.metadata) {
      for (const [k, v] of Object.entries(snapshot.metadata)) {
        this.setMetadata(k, v);
      }
    }
    if (Array.isArray(snapshot.devices)) {
      for (const d of snapshot.devices) this.upsertDevice(d);
    }
    if (Array.isArray(snapshot.routines)) {
      for (const r of snapshot.routines) this.upsertRoutine(r);
    }
    if (Array.isArray(snapshot.rules)) {
      for (const ru of snapshot.rules) this.saveRule(ru);
    }
    this.checkpoint();
    return true;
  }

  wipeAll() {
    this.state = {
      metadata: {},
      devices: {},
      routines: {},
      activeTimers: {},
      rules: {},
      executionLogs: [],
      energyTelemetry: {},
    };
    this.latestEnergy = {};
    try {
      if (fs.existsSync(this.dbFile)) fs.unlinkSync(this.dbFile);
      if (fs.existsSync(this.walFile)) fs.unlinkSync(this.walFile);
      if (fs.existsSync(this.tmpFile)) fs.unlinkSync(this.tmpFile);
    } catch (_) {}
  }

  close() {}
}

function createStorageEngine(dataDir) {
  if (!fs.existsSync(dataDir)) {
    try {
      fs.mkdirSync(dataDir, { recursive: true });
    } catch (_) {}
  }

  try {
    const sqlitePath = path.join(dataDir, 'hub.sqlite');
    return new SQLiteWalEngine(sqlitePath);
  } catch (err) {
    console.log('[Storage] node:sqlite not available, using Atomic WAL Engine:', err.message);
    return new AtomicWalEngine(dataDir);
  }
}

module.exports = {
  createStorageEngine,
  SQLiteWalEngine,
  AtomicWalEngine,
};
