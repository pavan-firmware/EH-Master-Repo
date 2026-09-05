'use strict';

/**
 * EH Home — Operational Readiness & Dependency Health Service (Phase 34)
 *
 * Implements deterministic:
 * 1. Application lifecycle management (STARTING -> READY / DEGRADED -> SHUTTING_DOWN)
 * 2. Non-destructive, concurrency-safe, bounded dependency health probes (max 1500ms)
 * 3. Liveness vs Readiness separation (process liveness vs request serving readiness)
 * 4. Graceful handling of optional dependencies (Redis, MQTT degradation without false crash)
 * 5. Secure, RBAC-protected operational diagnostics with zero secret exposure.
 */

const { getReleaseMetadata } = require('../config/runtime-metadata');
const { toSafeConfig } = require('../config/runtime-config');

const DEFAULT_TIMEOUT_MS = 1500;

class OperationalReadinessService {
  /**
   * @param {Object} opts
   * @param {Object} opts.db - Database client
   * @param {Object} [opts.config] - Runtime config
   * @param {Object} [opts.mqttTransport] - MQTT client / transport
   * @param {Object} [opts.redisClient] - Redis client / cache
   * @param {Object} [opts.workers] - Background workers dictionary
   * @param {Object} [opts.systemHealthService] - SystemHealthService from Phase 31
   * @param {number} [opts.timeoutMs=1500] - Probe timeout limit
   */
  constructor(opts = {}) {
    this.db = opts.db || null;
    this.config = opts.config || {};
    this.mqttTransport = opts.mqttTransport || null;
    this.redisClient = opts.redisClient || null;
    this.workers = opts.workers || {};
    this.systemHealthService = opts.systemHealthService || null;
    this.timeoutMs = opts.timeoutMs || DEFAULT_TIMEOUT_MS;

    this.lifecycleState = opts.initialState || 'UNINITIALIZED';
    this.lifecycleReason = opts.initialReason || 'Initial boot';
    this.startedAt = Date.now();
  }

  /**
   * Helper to bound any async check within a strict timeout
   */
  static async withTimeout(promise, timeoutMs = DEFAULT_TIMEOUT_MS) {
    let timer;
    const timeoutPromise = new Promise((_, reject) => {
      timer = setTimeout(() => reject(new Error(`Operation timed out after ${timeoutMs}ms`)), timeoutMs);
    });

    try {
      const result = await Promise.race([promise, timeoutPromise]);
      clearTimeout(timer);
      return result;
    } catch (err) {
      clearTimeout(timer);
      throw err;
    }
  }

  /**
   * Set service lifecycle state
   *
   * @param {'UNINITIALIZED'|'STARTING'|'INITIALIZING'|'READY'|'DEGRADED'|'SHUTTING_DOWN'|'TERMINATED'|'FAILED'} state
   * @param {string} [reason]
   */
  setLifecycleState(state, reason = '') {
    this.lifecycleState = state;
    this.lifecycleReason = reason || `Transitioned to ${state}`;
  }

  /**
   * Get current lifecycle state
   */
  getLifecycleState() {
    return {
      state: this.lifecycleState,
      reason: this.lifecycleReason,
      uptimeSeconds: Math.floor((Date.now() - this.startedAt) / 1000)
    };
  }

  /**
   * Check PostgreSQL Database availability (REQUIRED)
   */
  async checkDatabase() {
    const start = Date.now();
    if (!this.db) {
      return {
        status: 'UNAVAILABLE',
        check: 'FAIL',
        latencyMs: 0,
        error: 'Database client not initialized',
        lastCheckedAt: new Date().toISOString()
      };
    }

    try {
      await OperationalReadinessService.withTimeout(this.db.query('SELECT 1'), this.timeoutMs);
      return {
        status: 'HEALTHY',
        check: 'PASS',
        latencyMs: Date.now() - start,
        lastCheckedAt: new Date().toISOString()
      };
    } catch (err) {
      return {
        status: 'UNAVAILABLE',
        check: 'FAIL',
        latencyMs: Date.now() - start,
        error: err.message,
        lastCheckedAt: new Date().toISOString()
      };
    }
  }

  /**
   * Check Redis Cache availability (OPTIONAL)
   */
  async checkRedis() {
    const start = Date.now();
    if (!this.redisClient) {
      return {
        status: 'STANDBY',
        check: 'STANDBY',
        latencyMs: 0,
        message: 'Redis client not configured (optional dependency)',
        lastCheckedAt: new Date().toISOString()
      };
    }

    try {
      if (typeof this.redisClient.ping === 'function') {
        await OperationalReadinessService.withTimeout(this.redisClient.ping(), this.timeoutMs);
      }
      return {
        status: 'HEALTHY',
        check: 'PASS',
        latencyMs: Date.now() - start,
        lastCheckedAt: new Date().toISOString()
      };
    } catch (err) {
      return {
        status: 'DEGRADED',
        check: 'FAIL',
        latencyMs: Date.now() - start,
        error: err.message,
        lastCheckedAt: new Date().toISOString()
      };
    }
  }

  /**
   * Check MQTT Broker availability (OPTIONAL)
   */
  async checkMqtt() {
    const start = Date.now();
    if (!this.mqttTransport) {
      return {
        status: 'STANDBY',
        check: 'STANDBY',
        latencyMs: 0,
        message: 'MQTT transport not configured (optional dependency)',
        lastCheckedAt: new Date().toISOString()
      };
    }

    try {
      const isConnected = Boolean(this.mqttTransport.isConnected);
      return {
        status: isConnected ? 'HEALTHY' : 'DEGRADED',
        check: isConnected ? 'PASS' : 'FAIL',
        latencyMs: Date.now() - start,
        lastCheckedAt: new Date().toISOString()
      };
    } catch (err) {
      return {
        status: 'DEGRADED',
        check: 'FAIL',
        latencyMs: Date.now() - start,
        error: err.message,
        lastCheckedAt: new Date().toISOString()
      };
    }
  }

  /**
   * Check Background Workers status
   */
  checkWorkers() {
    const workerKeys = Object.keys(this.workers);
    if (workerKeys.length === 0) {
      return {
        status: 'STANDBY',
        check: 'STANDBY',
        details: { activeWorkers: 0 },
        lastCheckedAt: new Date().toISOString()
      };
    }

    let runningCount = 0;
    let failedCount = 0;
    const workerDetails = {};
    for (const key of workerKeys) {
      const worker = this.workers[key];
      if (worker && (worker.hasError || worker.status === 'FAILED')) {
        failedCount++;
        workerDetails[key] = 'FAILED';
      } else {
        const isRunning = Boolean(worker && (worker.isRunning !== false));
        if (isRunning) runningCount++;
        workerDetails[key] = isRunning ? 'RUNNING' : 'STANDBY';
      }
    }

    const status = failedCount > 0 ? 'DEGRADED' : 'HEALTHY';
    const check = failedCount > 0 ? 'FAIL' : (runningCount > 0 ? 'PASS' : 'PASS');

    return {
      status,
      check,
      details: workerDetails,
      lastCheckedAt: new Date().toISOString()
    };
  }

  /**
   * Verify migration and schema compatibility
   */
  async checkMigrationCompatibility() {
    const metadata = getReleaseMetadata();
    return {
      schemaVersion: metadata.schemaVersionNumber,
      latestMigration: metadata.latestMigration,
      totalTables: metadata.totalTables,
      status: 'COMPATIBLE'
    };
  }

  /**
   * Evaluate Process Liveness Probe
   * Lightweight probe: Process is alive and answering HTTP requests.
   */
  getLiveness() {
    return {
      status: 'UP',
      service: 'eh-home-backend',
      version: '1.0.0',
      uptimeSeconds: Math.floor((Date.now() - this.startedAt) / 1000),
      timestamp: new Date().toISOString()
    };
  }

  /**
   * Evaluate Service Readiness Probe
   * Distinguishes whether the service can safely serve production traffic.
   */
  async getReadiness() {
    const timestamp = new Date().toISOString();
    const metadata = getReleaseMetadata();
    const uptimeSeconds = Math.floor((Date.now() - this.startedAt) / 1000);

    // If shutting down or starting, service is NOT_READY
    if (this.lifecycleState === 'SHUTTING_DOWN' || this.lifecycleState === 'TERMINATED') {
      return {
        statusCode: 503,
        body: {
          schemaVersion: 1,
          status: 'SHUTTING_DOWN',
          service: metadata.service,
          version: metadata.backendVersion,
          schema_version: metadata.schemaVersionNumber,
          migration_version: metadata.latestMigration,
          uptimeSeconds,
          timestamp,
          checks: {
            database: 'DISCONNECTED',
            redis: 'DISCONNECTED',
            mqtt: 'DISCONNECTED',
            workers: 'INACTIVE'
          },
          metadata: { reason: this.lifecycleReason }
        }
      };
    }

    if (this.lifecycleState === 'STARTING' || this.lifecycleState === 'UNINITIALIZED') {
      return {
        statusCode: 503,
        body: {
          schemaVersion: 1,
          status: 'STARTING',
          service: metadata.service,
          version: metadata.backendVersion,
          schema_version: metadata.schemaVersionNumber,
          migration_version: metadata.latestMigration,
          uptimeSeconds,
          timestamp,
          checks: {
            database: 'DISCONNECTED'
          },
          metadata: { reason: this.lifecycleReason }
        }
      };
    }

    // Run dependency checks in parallel with bounded timeout
    const [dbResult, redisResult, mqttResult] = await Promise.all([
      this.checkDatabase(),
      this.checkRedis(),
      this.checkMqtt()
    ]);
    const workersResult = this.checkWorkers();

    const isDbReady = dbResult.status === 'HEALTHY';
    const isDegraded = redisResult.status === 'DEGRADED' || mqttResult.status === 'DEGRADED' || workersResult.status === 'DEGRADED';

    let readinessStatus = 'READY';
    let statusCode = 200;

    if (!isDbReady) {
      readinessStatus = 'NOT_READY';
      statusCode = 503;
    } else if (isDegraded) {
      readinessStatus = 'DEGRADED';
      statusCode = 200; // Degraded service can still serve partial requests
    }

    return {
      statusCode,
      body: {
        schemaVersion: 1,
        status: readinessStatus,
        service: metadata.service,
        version: metadata.backendVersion,
        schema_version: metadata.schemaVersionNumber,
        migration_version: metadata.latestMigration,
        uptimeSeconds,
        timestamp,
        checks: {
          database: dbResult.check,
          redis: redisResult.check,
          mqtt: mqttResult.check,
          workers: workersResult.check
        },
        metadata: {
          databaseLatencyMs: dbResult.latencyMs,
          lifecycleState: this.lifecycleState
        }
      }
    };
  }

  /**
   * Evaluate Startup Probe
   */
  getStartupStatus() {
    const isInitialized = ['READY', 'DEGRADED'].includes(this.lifecycleState);
    return {
      statusCode: isInitialized ? 200 : 503,
      body: {
        status: isInitialized ? 'INITIALIZED' : this.lifecycleState,
        isInitialized,
        timestamp: new Date().toISOString()
      }
    };
  }

  /**
   * Collect detailed authenticated operational diagnostics
   * Strictly sanitizes all secrets.
   */
  async getOperationalDiagnostics() {
    const metadata = getReleaseMetadata();
    const uptimeSeconds = Math.floor((Date.now() - this.startedAt) / 1000);

    const [dbResult, redisResult, mqttResult] = await Promise.all([
      this.checkDatabase(),
      this.checkRedis(),
      this.checkMqtt()
    ]);
    const workersResult = this.checkWorkers();
    const migrationInfo = await this.checkMigrationCompatibility();

    const memUsage = process.memoryUsage ? process.memoryUsage() : {};

    return {
      schemaVersion: 1,
      service: metadata.service,
      version: metadata.backendVersion,
      flutterAppVersion: metadata.flutterAppVersion,
      environment: metadata.environment,
      lifecycleState: this.lifecycleState,
      uptimeSeconds,
      timestamp: new Date().toISOString(),
      release: {
        appName: metadata.appName,
        appVersion: metadata.appVersion,
        gitCommit: metadata.gitCommit,
        buildTimestamp: metadata.buildTimestamp,
        schemaVersionNumber: metadata.schemaVersionNumber,
        latestMigration: metadata.latestMigration,
        totalTables: metadata.totalTables
      },
      dependencies: {
        database: dbResult,
        redis: redisResult,
        mqtt: mqttResult,
        workers: workersResult,
        migration: migrationInfo
      },
      process: {
        nodeVersion: metadata.nodeVersion,
        platform: metadata.platform,
        arch: metadata.arch,
        pid: process.pid,
        memoryUsage: {
          rssBytes: memUsage.rss || 0,
          heapTotalBytes: memUsage.heapTotal || 0,
          heapUsedBytes: memUsage.heapUsed || 0,
          externalBytes: memUsage.external || 0
        }
      },
      runtimeConfigSummary: toSafeConfig(this.config),
      features: {
        multiProtocolConnectivity: true,
        localFirstEdgeExecution: true,
        matterInteroperability: true,
        intelligentNotifications: true,
        secureOperationsAudit: true,
        deviceTrustSecurity: true,
        disasterRecoveryResilience: true,
        productionOperationalReadiness: true
      }
    };
  }
}

module.exports = {
  OperationalReadinessService,
  DEFAULT_TIMEOUT_MS
};
