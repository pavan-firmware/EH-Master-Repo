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
    `);
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

  wipeAll() {
    this.db.exec(`
      DELETE FROM metadata;
      DELETE FROM devices;
      DELETE FROM routines;
      DELETE FROM active_timers;
    `);
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

  wipeAll() {
    this.state = {
      metadata: {},
      devices: {},
      routines: {},
      activeTimers: {},
    };
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
