'use strict';

/**
 * EH Home — Worker Runner Lifecycle (Phase 7B)
 *
 * Provides clean start/stop/graceful-shutdown for interval-based workers.
 *
 * Design:
 * - Workers are objects with a tick() method and a name.
 * - WorkerRunner owns the setInterval and handles graceful stop.
 * - Prevents duplicate registration of the same worker name.
 * - Safe to import in test environments — workers do NOT auto-start.
 * - Supports dependency injection for testability.
 */

class WorkerRunner {
  constructor() {
    // Map<workerName, { interval, worker }>
    this._workers = new Map();
    this._stopping = false;
  }

  /**
   * Register and start a worker.
   * @param {Object} opts
   * @param {string}   opts.name          Worker unique name
   * @param {Object}   opts.worker        Object with async tick() method
   * @param {number}   opts.intervalMs    How frequently to call tick()
   * @param {boolean}  [opts.runNow=false] Call tick() immediately before interval
   */
  async register({ name, worker, intervalMs, runNow = false }) {
    if (this._stopping) {
      throw new Error(`WorkerRunner is shutting down; cannot register worker "${name}"`);
    }
    if (!name || typeof worker.tick !== 'function') {
      throw new Error(`Worker "${name}" must have a tick() method`);
    }
    if (this._workers.has(name)) {
      throw new Error(`Worker "${name}" is already registered`);
    }

    if (runNow) {
      await this._runTick(name, worker);
    }

    const intervalRef = setInterval(async () => {
      await this._runTick(name, worker);
    }, intervalMs);

    // Allow Node.js to exit without waiting for intervals
    if (intervalRef.unref) intervalRef.unref();

    this._workers.set(name, { interval: intervalRef, worker });
    console.log(`[WorkerRunner] Started worker "${name}" (every ${intervalMs}ms)`);
  }

  async _runTick(name, worker) {
    try {
      await worker.tick();
    } catch (err) {
      console.error(`[WorkerRunner] Worker "${name}" tick error:`, err.message);
    }
  }

  /**
   * Stop a specific worker by name.
   */
  stop(name) {
    const entry = this._workers.get(name);
    if (entry) {
      clearInterval(entry.interval);
      this._workers.delete(name);
      console.log(`[WorkerRunner] Stopped worker "${name}"`);
    }
  }

  /**
   * Gracefully stop all registered workers.
   */
  async stopAll() {
    this._stopping = true;
    for (const [name, { interval }] of this._workers) {
      clearInterval(interval);
      console.log(`[WorkerRunner] Stopped worker "${name}" (graceful shutdown)`);
    }
    this._workers.clear();
  }

  /**
   * List names of all active workers.
   */
  activeWorkers() {
    return [...this._workers.keys()];
  }

  /**
   * Reset the runner (for tests).
   */
  reset() {
    this.stopAll();
    this._stopping = false;
  }
}

module.exports = { WorkerRunner };
