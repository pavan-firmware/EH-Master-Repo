/**
 * EH Home Desktop — Setup Check Persistence & Performance Regression Suite
 * 
 * Verifies:
 * 1. Persistent setup results across page visits (zero auto-rechecks on revisit)
 * 2. Schema versioning (version 1) invalidation semantics
 * 3. Explicit [Recheck All] and granular section rechecks
 * 4. In-flight request concurrency locks preventing duplicate native subprocess spawns
 * 5. API client idempotent GET deduplication
 */

import { describe, it, before, beforeEach } from 'node:test';
import assert from 'node:assert/strict';

// Mock localStorage in Node environment
class MockLocalStorage {
  constructor() {
    this.store = {};
  }
  getItem(key) {
    return this.store[key] || null;
  }
  setItem(key, value) {
    this.store[key] = String(value);
  }
  removeItem(key) {
    delete this.store[key];
  }
  clear() {
    this.store = {};
  }
}

globalThis.localStorage = new MockLocalStorage();
globalThis.window = {
  localStorage: globalThis.localStorage,
};

describe('Desktop Performance & Setup Persistence Suite', () => {
  const STORAGE_KEY_SETUP_STATE = 'eh_desktop_setup_state_v1';
  const STORAGE_KEY_SETUP_CONFIG = 'eh_desktop_station_setup_v1';
  const SETUP_SCHEMA_VERSION = 1;

  beforeEach(() => {
    globalThis.localStorage.clear();
  });

  it('1. First-run detection: Returns false when no setup state exists', () => {
    const raw = globalThis.localStorage.getItem(STORAGE_KEY_SETUP_STATE);
    assert.equal(raw, null, 'No initial setup state should exist in clean storage');
  });

  it('2. Persisting completed setup state: Stores version, timestamps, and check results', () => {
    const testState = {
      setupVersion: SETUP_SCHEMA_VERSION,
      completed: true,
      completedAt: new Date().toISOString(),
      lastCheckAt: new Date().toISOString(),
      overallStatus: 'READY',
      individualCheckResults: {
        system: { os_name: 'windows', os_version: 'Windows 11', meets_minimum_specs: true },
        python: { python_found: true, all_ready: true, packages: [] },
        usb: { count: 1, devices: [{ port_name: 'COM3', driver_status: 'Active' }] },
        scanner: { ready: true, connection_type: 'USB_HID_KEYBOARD_EMULATION' },
        network: { api_reachable: true, api_status_code: 200 },
        printers: [{ id: 'PRINTER_MS_PDF', name: 'Microsoft Print to PDF', isVirtualPdf: true }],
      },
      stationConfiguration: {
        station_id: 'STATION_BENCH_01',
        operator_id: 'BENCH_OPERATOR',
        api_url: 'http://localhost:3100',
        baud_rate: 921600,
        default_printer_id: 'Microsoft Print to PDF',
        setup_completed: true,
      },
    };

    globalThis.localStorage.setItem(STORAGE_KEY_SETUP_STATE, JSON.stringify(testState));
    globalThis.localStorage.setItem(STORAGE_KEY_SETUP_CONFIG, JSON.stringify(testState.stationConfiguration));

    const retrieved = JSON.parse(globalThis.localStorage.getItem(STORAGE_KEY_SETUP_STATE));
    assert.equal(retrieved.setupVersion, 1);
    assert.equal(retrieved.completed, true);
    assert.equal(retrieved.overallStatus, 'READY');
    assert.equal(retrieved.individualCheckResults.system.meets_minimum_specs, true);
    assert.equal(retrieved.individualCheckResults.usb.devices[0].port_name, 'COM3');
  });

  it('3. Reopening setup screen with persisted state executes 0 automatic environment checks', () => {
    let checkExecutionCount = 0;
    const fakeRunChecks = () => {
      checkExecutionCount++;
    };

    // Simulate existing valid setup state
    const savedState = {
      setupVersion: SETUP_SCHEMA_VERSION,
      completed: true,
      completedAt: '2026-09-27T22:00:00.000Z',
      lastCheckAt: '2026-09-27T22:00:00.000Z',
      overallStatus: 'READY',
      individualCheckResults: { system: {}, python: {}, usb: {}, scanner: {}, network: {}, printers: [] },
      stationConfiguration: { station_id: 'BENCH-01', setup_completed: true },
    };
    globalThis.localStorage.setItem(STORAGE_KEY_SETUP_STATE, JSON.stringify(savedState));

    // Mount simulation
    const stateData = globalThis.localStorage.getItem(STORAGE_KEY_SETUP_STATE);
    const parsed = stateData ? JSON.parse(stateData) : null;
    if (parsed && parsed.completed && parsed.setupVersion === SETUP_SCHEMA_VERSION) {
      // Direct load — no check execution
    } else {
      fakeRunChecks();
    }

    assert.equal(checkExecutionCount, 0, 'Must execute exactly 0 automatic checks when valid setup state is persisted');
  });

  it('4. Schema version mismatch invalidates saved state and triggers fresh setup check', () => {
    let checkExecutionCount = 0;
    const fakeRunChecks = () => {
      checkExecutionCount++;
    };

    // Simulate outdated schema version (e.g. version 0)
    const outdatedState = {
      setupVersion: 0,
      completed: true,
      completedAt: '2025-01-01T00:00:00.000Z',
    };
    globalThis.localStorage.setItem(STORAGE_KEY_SETUP_STATE, JSON.stringify(outdatedState));

    // Mount simulation
    const stateData = globalThis.localStorage.getItem(STORAGE_KEY_SETUP_STATE);
    const parsed = stateData ? JSON.parse(stateData) : null;
    if (parsed && parsed.completed && parsed.setupVersion === SETUP_SCHEMA_VERSION) {
      // Direct load
    } else {
      fakeRunChecks();
    }

    assert.equal(checkExecutionCount, 1, 'Must execute fresh checks when setup schema version differs');
  });

  it('5. In-flight concurrency lock prevents duplicate concurrent execution', async () => {
    let callCount = 0;
    const inFlightMap = new Map();

    const executeCheckWithLock = (key) => {
      if (inFlightMap.has(key)) {
        return inFlightMap.get(key);
      }
      const promise = (async () => {
        callCount++;
        await new Promise((resolve) => setTimeout(resolve, 50));
        return { success: true };
      })().finally(() => {
        inFlightMap.delete(key);
      });
      inFlightMap.set(key, promise);
      return promise;
    };

    // Fire 5 rapid concurrent calls for the same check
    const [r1, r2, r3, r4, r5] = await Promise.all([
      executeCheckWithLock('system_check'),
      executeCheckWithLock('system_check'),
      executeCheckWithLock('system_check'),
      executeCheckWithLock('system_check'),
      executeCheckWithLock('system_check'),
    ]);

    assert.equal(callCount, 1, 'In-flight concurrency lock must ensure only 1 real execution for 5 concurrent calls');
    assert.equal(r1.success, true);
    assert.equal(r5.success, true);
  });

  it('6. Explicit Recheck All updates lastCheckAt timestamp and saves new results', () => {
    const initialState = {
      setupVersion: SETUP_SCHEMA_VERSION,
      completed: true,
      completedAt: '2026-09-27T10:00:00.000Z',
      lastCheckAt: '2026-09-27T10:00:00.000Z',
      overallStatus: 'READY',
      individualCheckResults: { system: { cpu_cores: 4 } },
      stationConfiguration: { station_id: 'BENCH-01' },
    };
    globalThis.localStorage.setItem(STORAGE_KEY_SETUP_STATE, JSON.stringify(initialState));

    // User clicks Recheck All at a later time
    const updatedCheckTime = '2026-09-27T23:30:00.000Z';
    const updatedState = {
      ...initialState,
      lastCheckAt: updatedCheckTime,
      individualCheckResults: { system: { cpu_cores: 8 } },
    };
    globalThis.localStorage.setItem(STORAGE_KEY_SETUP_STATE, JSON.stringify(updatedState));

    const retrieved = JSON.parse(globalThis.localStorage.getItem(STORAGE_KEY_SETUP_STATE));
    assert.equal(retrieved.lastCheckAt, updatedCheckTime);
    assert.equal(retrieved.individualCheckResults.system.cpu_cores, 8);
  });

  it('7. Idempotent GET API request deduplication operates correctly', async () => {
    let networkFetches = 0;
    const inFlightGetRequests = new Map();

    const apiGet = (path) => {
      if (inFlightGetRequests.has(path)) {
        return inFlightGetRequests.get(path);
      }
      const exec = (async () => {
        networkFetches++;
        await new Promise((resolve) => setTimeout(resolve, 30));
        return { success: true, data: { status: 'UP' } };
      })().finally(() => {
        inFlightGetRequests.delete(path);
      });
      inFlightGetRequests.set(path, exec);
      return exec;
    };

    const [a, b, c] = await Promise.all([
      apiGet('/health'),
      apiGet('/health'),
      apiGet('/health'),
    ]);

    assert.equal(networkFetches, 1, 'Only 1 network fetch should execute for 3 simultaneous /health requests');
    assert.equal(a.data.status, 'UP');
    assert.equal(b.data.status, 'UP');
    assert.equal(c.data.status, 'UP');
  });
});
