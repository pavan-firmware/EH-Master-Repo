/**
 * Operations Metrics Service
 *
 * Computes derived operational metrics and failure distributions from
 * authoritative operational events. Survives server restarts by querying
 * database records rather than relying solely on ephemeral in-memory state.
 *
 * Prevents misleading percentages on small sample sizes.
 */

class OperationsMetricsService {
  constructor({ operationalEventRepo }) {
    this.operationalEventRepo = operationalEventRepo;
  }

  /**
   * Calculate aggregated operational metrics for a home or platform over a window.
   */
  async getMetricsSummary({ homeId = null, since = null }) {
    const events = await this.operationalEventRepo.findEvents({
      homeId,
      since,
      limit: 10000
    });

    const totalEvents = events.length;
    let successCount = 0;
    let failureCount = 0;
    let partialCount = 0;
    let timeoutCount = 0;

    let totalDurationMs = 0;
    let timedEventsCount = 0;

    const subsystemCounts = {};
    const failureCodeCounts = {};
    const executionPathCounts = {};

    for (const e of events) {
      if (e.outcome === 'SUCCESS') successCount++;
      else if (e.outcome === 'FAILURE') failureCount++;
      else if (e.outcome === 'PARTIAL') partialCount++;
      else if (e.outcome === 'TIMEOUT') timeoutCount++;

      if (typeof e.duration_ms === 'number' && e.duration_ms >= 0) {
        totalDurationMs += e.duration_ms;
        timedEventsCount++;
      }

      // Breakdown by subsystem
      subsystemCounts[e.subsystem] = (subsystemCounts[e.subsystem] || 0) + 1;

      // Breakdown by execution path
      const path = e.execution_path || 'UNKNOWN';
      executionPathCounts[path] = (executionPathCounts[path] || 0) + 1;

      // Breakdown by failure code
      if (e.failure_code) {
        failureCodeCounts[e.failure_code] = (failureCodeCounts[e.failure_code] || 0) + 1;
      }
    }

    // Success rate calculation: flag as statistically insignificant if sample size < 5
    const isStatisticallySignificant = totalEvents >= 5;
    const successRate = totalEvents > 0 ? (successCount / totalEvents) : null;
    const avgDurationMs = timedEventsCount > 0 ? Math.round(totalDurationMs / timedEventsCount) : 0;

    return {
      windowSince: since,
      totalEvents,
      successCount,
      failureCount,
      partialCount,
      timeoutCount,
      successRate,
      isStatisticallySignificant,
      avgDurationMs,
      subsystems: subsystemCounts,
      executionPaths: executionPathCounts,
      failureCodes: failureCodeCounts,
      sampleSizeNote: isStatisticallySignificant ? null : 'Sample size too small (<5) for statistically reliable success rate percentage'
    };
  }
}

module.exports = { OperationsMetricsService };
