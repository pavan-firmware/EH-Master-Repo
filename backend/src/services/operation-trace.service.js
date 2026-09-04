/**
 * Operation Trace Service
 *
 * Reconstructs end-to-end multi-hop execution traces across subsystems,
 * linking causation chains and calculating phase latencies.
 */

class OperationTraceService {
  constructor({ operationalEventRepo }) {
    this.operationalEventRepo = operationalEventRepo;
  }

  /**
   * Reconstruct a complete trace from all operational events sharing a correlationId.
   */
  async getTraceByCorrelationId(correlationId) {
    const events = await this.operationalEventRepo.findByCorrelationId(correlationId);
    if (!events || events.length === 0) {
      return null;
    }

    // Sort chronologically
    events.sort((a, b) => new Date(a.occurred_at) - new Date(b.occurred_at));

    const rootEvent = events[0];
    const lastEvent = events[events.length - 1];

    const startTime = rootEvent.occurred_at;
    const endTime = lastEvent.occurred_at;
    const totalDurationMs = Math.max(0, new Date(endTime).getTime() - new Date(startTime).getTime());

    // Determine overall trace status
    let status = 'COMPLETED';
    const hasFailures = events.some(e => e.outcome === 'FAILURE' || e.outcome === 'TIMEOUT');
    const hasPartials = events.some(e => e.outcome === 'PARTIAL');
    const isOngoing = events.some(e => e.trace_lifecycle === 'IN_PROGRESS' || e.trace_lifecycle === 'START');

    if (hasFailures) {
      status = 'FAILED';
    } else if (hasPartials) {
      status = 'PARTIAL';
    } else if (isOngoing && rootEvent.trace_lifecycle !== 'COMPLETE') {
      status = 'IN_PROGRESS';
    }

    // Map each operational event to a trace span
    const spans = events.map(e => ({
      spanId: e.id,
      parentSpanId: e.causation_id || null,
      subsystem: e.subsystem,
      operation: e.operation,
      executionPath: e.execution_path || 'CLOUD',
      outcome: e.outcome,
      durationMs: e.duration_ms !== undefined ? e.duration_ms : null,
      timestamp: e.occurred_at,
      details: {
        action: e.action,
        source: e.source,
        severity: e.severity,
        authorizationResult: e.authorization_result,
        failureCode: e.failure_code,
        metadata: e.metadata
      }
    }));

    return {
      schemaVersion: 1,
      traceId: `trace_${correlationId}`,
      correlationId,
      rootOperation: rootEvent.operation,
      status,
      startTime,
      endTime,
      totalDurationMs,
      spans,
      metadata: {
        totalSpans: spans.length,
        homeId: rootEvent.home_id,
        deviceId: rootEvent.device_id,
        userId: rootEvent.user_id
      }
    };
  }
}

module.exports = { OperationTraceService };
