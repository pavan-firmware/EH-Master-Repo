'use strict';

/**
 * EH Home — In-Memory Rate Limiter (Phase 7A)
 * Bounded sliding-window rate limiter for sensitive authentication endpoints.
 */

class RateLimiter {
  constructor({ windowMs = 60000, maxRequests = 10 } = {}) {
    this.windowMs = windowMs;
    this.maxRequests = maxRequests;
    this.hits = new Map();
  }

  isRateLimited(key) {
    const now = Date.now();
    const windowStart = now - this.windowMs;

    let timestamps = this.hits.get(key) || [];
    // Filter out old timestamps
    timestamps = timestamps.filter(ts => ts > windowStart);

    if (timestamps.length >= this.maxRequests) {
      const oldestInWindow = timestamps[0];
      const retryAfterSeconds = Math.ceil((oldestInWindow + this.windowMs - now) / 1000);
      return { limited: true, retryAfterSeconds: Math.max(1, retryAfterSeconds) };
    }

    timestamps.push(now);
    this.hits.set(key, timestamps);

    // Periodic cleanup of stale keys
    if (this.hits.size > 10000) {
      for (const [k, tsList] of this.hits.entries()) {
        if (tsList.every(ts => ts <= windowStart)) {
          this.hits.delete(k);
        }
      }
    }

    return { limited: false, retryAfterSeconds: 0 };
  }

  reset(key) {
    if (key) {
      this.hits.delete(key);
    } else {
      this.hits.clear();
    }
  }
}

module.exports = { RateLimiter };
