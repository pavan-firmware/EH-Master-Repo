'use strict';

/**
 * EH Home — Metrics Service (Phase 43)
 *
 * Bounded metrics collection, aggregation, and snapshot engine across
 * API, Auth, Device, Fleet/OTA, Database, Notifications, and Backup categories.
 */

const MAX_HISTOGRAM_SAMPLES = 500;

class MetricsService {
  constructor(options = {}) {
    this.maxSamples = options.maxSamples || MAX_HISTOGRAM_SAMPLES;
    this.counters = new Map();
    this.gauges = new Map();
    this.histograms = new Map();
    this.startTime = new Date().toISOString();
  }

  // --- Core Primitives ---

  incrementCounter(name, value = 1, labels = {}) {
    const key = this._buildKey(name, labels);
    const current = this.counters.get(key) || { name, labels, value: 0 };
    current.value += value;
    this.counters.set(key, current);
    return current.value;
  }

  setGauge(name, value, labels = {}) {
    const key = this._buildKey(name, labels);
    const entry = { name, labels, value, updatedAt: new Date().toISOString() };
    this.gauges.set(key, entry);
    return entry.value;
  }

  recordHistogram(name, value, labels = {}) {
    const key = this._buildKey(name, labels);
    let entry = this.histograms.get(key);
    if (!entry) {
      entry = { name, labels, samples: [], count: 0, sum: 0, min: value, max: value };
      this.histograms.set(key, entry);
    }
    entry.count += 1;
    entry.sum += value;
    if (value < entry.min) entry.min = value;
    if (value > entry.max) entry.max = value;

    if (entry.samples.length >= this.maxSamples) {
      entry.samples.shift(); // Evict oldest sample to maintain bounds
    }
    entry.samples.push(value);
  }

  _buildKey(name, labels = {}) {
    const sortedKeys = Object.keys(labels).sort();
    const labelStr = sortedKeys.map(k => `${k}=${labels[k]}`).join(',');
    return labelStr ? `${name}{${labelStr}}` : name;
  }

  _calculatePercentiles(samples) {
    if (!samples || samples.length === 0) {
      return { p50: 0, p90: 0, p95: 0, p99: 0 };
    }
    const sorted = [...samples].sort((a, b) => a - b);
    const getP = (p) => {
      const idx = Math.min(Math.floor((p / 100) * sorted.length), sorted.length - 1);
      return sorted[idx];
    };
    return {
      p50: getP(50),
      p90: getP(90),
      p95: getP(95),
      p99: getP(99)
    };
  }

  // --- Domain Helper Metrics ---

  recordApiRequest({ method, route, statusCode, durationMs }) {
    this.incrementCounter('api_requests_total', 1, { method, route, status: String(statusCode) });
    if (statusCode >= 400 && statusCode < 500) {
      this.incrementCounter('api_client_errors_total', 1, { route, status: String(statusCode) });
    } else if (statusCode >= 500) {
      this.incrementCounter('api_server_errors_total', 1, { route, status: String(statusCode) });
    }
    this.recordHistogram('api_request_duration_ms', durationMs, { route });
  }

  recordAuthAttempt({ success, reason = 'success' }) {
    if (success) {
      this.incrementCounter('auth_success_total', 1);
    } else {
      this.incrementCounter('auth_failure_total', 1, { reason });
    }
  }

  recordRateLimitHit({ route, identifierType = 'ip' }) {
    this.incrementCounter('rate_limit_hits_total', 1, { route, type: identifierType });
  }

  recordDeviceHeartbeat({ status = 'ONLINE' }) {
    this.incrementCounter('device_heartbeats_total', 1, { status });
  }

  recordDeviceDisconnect({ reason = 'timeout' }) {
    this.incrementCounter('device_disconnects_total', 1, { reason });
  }

  recordOtaAttempt({ outcome, failureReason = null }) {
    const labels = { outcome };
    if (failureReason) labels.reason = failureReason;
    this.incrementCounter('ota_attempts_total', 1, labels);
  }

  recordDatabaseQuery({ durationMs, success = true }) {
    this.incrementCounter('db_queries_total', 1, { success: String(success) });
    this.recordHistogram('db_query_duration_ms', durationMs);
  }

  recordNotificationDispatch({ channel, success = true }) {
    this.incrementCounter('notifications_total', 1, { channel, success: String(success) });
  }

  recordBackupOperation({ type = 'BACKUP', success = true, durationMs = 0 }) {
    this.incrementCounter('backup_operations_total', 1, { type, success: String(success) });
    if (durationMs > 0) {
      this.recordHistogram('backup_duration_ms', durationMs, { type });
    }
  }

  // --- Aggregation & Snapshots ---

  getSnapshot(categoryFilter = null) {
    const result = {
      uptime_seconds: Math.floor((Date.now() - new Date(this.startTime).getTime()) / 1000),
      timestamp: new Date().toISOString(),
      counters: {},
      gauges: {},
      histograms: {}
    };

    for (const [key, item] of this.counters.entries()) {
      if (!categoryFilter || this._matchesCategory(item.name, categoryFilter)) {
        result.counters[key] = item.value;
      }
    }

    for (const [key, item] of this.gauges.entries()) {
      if (!categoryFilter || this._matchesCategory(item.name, categoryFilter)) {
        result.gauges[key] = item.value;
      }
    }

    for (const [key, item] of this.histograms.entries()) {
      if (!categoryFilter || this._matchesCategory(item.name, categoryFilter)) {
        const percentiles = this._calculatePercentiles(item.samples);
        const avg = item.count > 0 ? Number((item.sum / item.count).toFixed(2)) : 0;
        result.histograms[key] = {
          count: item.count,
          avg,
          min: item.min,
          max: item.max,
          ...percentiles
        };
      }
    }

    return result;
  }

  _matchesCategory(metricName, category) {
    const prefixMap = {
      api: ['api_'],
      auth: ['auth_', 'rate_limit_'],
      device: ['device_'],
      ota: ['ota_'],
      fleet: ['ota_', 'fleet_'],
      db: ['db_'],
      database: ['db_'],
      notification: ['notifications_'],
      backup: ['backup_']
    };

    const prefixes = prefixMap[category.toLowerCase()] || [category.toLowerCase()];
    return prefixes.some(p => metricName.startsWith(p));
  }

  reset() {
    this.counters.clear();
    this.gauges.clear();
    this.histograms.clear();
    this.startTime = new Date().toISOString();
  }
}

const defaultMetrics = new MetricsService();

module.exports = {
  MetricsService,
  defaultMetrics
};
