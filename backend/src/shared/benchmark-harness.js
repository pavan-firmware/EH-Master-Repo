'use strict';

/**
 * EH Home — Performance & Scalability Benchmark Harness (Phase 44)
 *
 * Provides reproducible micro-benchmarking, concurrency measurement,
 * and memory profiling utilities for automated performance regressions.
 */

class BenchmarkHarness {
  constructor(options = {}) {
    this.name = options.name || 'Benchmark';
    this.environment = options.environment || 'Node.js ' + process.version;
  }

  /**
   * Run an asynchronous or synchronous function across multiple iterations with optional concurrency limit.
   */
  async run({
    workloadName = 'workload',
    iterations = 100,
    warmupIterations = 10,
    concurrency = 1,
    taskFn
  }) {
    if (typeof taskFn !== 'function') {
      throw new Error('taskFn must be a function');
    }

    // 1. Warmup phase
    for (let i = 0; i < warmupIterations; i++) {
      await taskFn(i);
    }

    // Force garbage collection if exposed, otherwise baseline memory snapshot
    if (global.gc) {
      global.gc();
    }
    const memBefore = process.memoryUsage();
    const latencies = [];
    let errors = 0;

    const startTime = process.hrtime.bigint();

    // 2. Execution phase with concurrency control
    if (concurrency <= 1) {
      for (let i = 0; i < iterations; i++) {
        const iterStart = process.hrtime.bigint();
        try {
          await taskFn(i);
        } catch (err) {
          errors++;
        }
        const iterEnd = process.hrtime.bigint();
        latencies.push(Number(iterEnd - iterStart) / 1e6); // Convert nanoseconds to milliseconds
      }
    } else {
      let index = 0;
      const workers = Array.from({ length: Math.min(concurrency, iterations) }, async () => {
        while (index < iterations) {
          const currentIndex = index++;
          const iterStart = process.hrtime.bigint();
          try {
            await taskFn(currentIndex);
          } catch (err) {
            errors++;
          }
          const iterEnd = process.hrtime.bigint();
          latencies.push(Number(iterEnd - iterStart) / 1e6);
        }
      });
      await Promise.all(workers);
    }

    const endTime = process.hrtime.bigint();
    const totalDurationMs = Number(endTime - startTime) / 1e6;
    const memAfter = process.memoryUsage();

    // 3. Statistical Analysis
    latencies.sort((a, b) => a - b);
    const sum = latencies.reduce((acc, val) => acc + val, 0);
    const min = latencies[0] || 0;
    const max = latencies[latencies.length - 1] || 0;
    const avg = latencies.length > 0 ? sum / latencies.length : 0;

    const getPercentile = (p) => {
      if (latencies.length === 0) return 0;
      const idx = Math.min(Math.floor((p / 100) * latencies.length), latencies.length - 1);
      return latencies[idx];
    };

    const p50 = getPercentile(50);
    const p90 = getPercentile(90);
    const p95 = getPercentile(95);
    const p99 = getPercentile(99);

    const throughput = totalDurationMs > 0 ? (iterations / (totalDurationMs / 1000)) : 0;
    const heapDiffMb = (memAfter.heapUsed - memBefore.heapUsed) / (1024 * 1024);
    const rssDiffMb = (memAfter.rss - memBefore.rss) / (1024 * 1024);

    return {
      name: this.name,
      workload: workloadName,
      environment: this.environment,
      iterations,
      concurrency,
      total_duration_ms: Number(totalDurationMs.toFixed(2)),
      totalDurationMs: Number(totalDurationMs.toFixed(2)),
      throughput_ops_per_sec: Number(throughput.toFixed(2)),
      throughputOpsPerSec: Number(throughput.toFixed(2)),
      error_count: errors,
      errors,
      error_rate: iterations > 0 ? Number((errors / iterations).toFixed(4)) : 0,
      errorRate: iterations > 0 ? Number((errors / iterations).toFixed(4)) : 0,
      latency: {
        min: Number(min.toFixed(3)),
        max: Number(max.toFixed(3)),
        avg: Number(avg.toFixed(3)),
        p50: Number(p50.toFixed(3)),
        p90: Number(p90.toFixed(3)),
        p95: Number(p95.toFixed(3)),
        p99: Number(p99.toFixed(3))
      },
      memory: {
        heap_used_diff_mb: Number(heapDiffMb.toFixed(3)),
        rss_diff_mb: Number(rssDiffMb.toFixed(3))
      },
      memoryDelta: {
        heapUsedMB: Number(heapDiffMb.toFixed(3)),
        rssMB: Number(rssDiffMb.toFixed(3))
      },
      timestamp: new Date().toISOString()
    };
  }

  /**
   * Convenient wrapper for benchmarking a named workload.
   */
  async benchmark(workloadName, taskFn, options = {}) {
    return await this.run({
      workloadName,
      taskFn,
      iterations: options.iterations || 100,
      warmupIterations: options.warmupIterations || 10,
      concurrency: options.concurrency || 1
    });
  }

  /**
   * Helper to evaluate whether a benchmark measurement satisfies a local regression threshold.
   */
  assertPerformance(result, thresholds = {}) {
    if (thresholds.maxP95Ms !== undefined && result.latency.p95 > thresholds.maxP95Ms) {
      throw new Error(`Performance regression detected: p95 latency ${result.latency.p95}ms exceeds threshold ${thresholds.maxP95Ms}ms`);
    }
    if (thresholds.maxErrorRate !== undefined && result.errorRate > thresholds.maxErrorRate) {
      throw new Error(`Performance regression detected: error rate ${result.errorRate} exceeds threshold ${thresholds.maxErrorRate}`);
    }
    if (thresholds.minThroughputOpsPerSec !== undefined && result.throughputOpsPerSec < thresholds.minThroughputOpsPerSec) {
      throw new Error(`Performance regression detected: throughput ${result.throughputOpsPerSec} ops/sec is below threshold ${thresholds.minThroughputOpsPerSec}`);
    }
    return true;
  }

  static assertRegressionThreshold(measured, threshold, metricName = 'p95') {
    const val = metricName.startsWith('latency.') ?
      measured.latency[metricName.split('.')[1]] :
      (measured.latency[metricName] || measured[metricName]);

    if (val > threshold) {
      throw new Error(`Performance regression detected: ${metricName} measured at ${val} exceeds threshold of ${threshold}`);
    }
    return true;
  }
}

module.exports = { BenchmarkHarness };
