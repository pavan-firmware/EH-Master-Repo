'use strict';

/**
 * EH Home — In-Memory Multi-Bucket Rate Limiter (Phase 7A & Phase 42 Hardening)
 *
 * Bounded sliding-window rate limiter supporting categorized buckets for:
 * - Authentication attempts (login, register, refresh)
 * - Administrative operations (fleet management, configuration)
 * - Device commands and controls
 * - OTA and rollout actions
 * - Password reset and sensitive credential actions
 */

class RateLimiter {
  constructor({ windowMs = 60000, maxRequests = 10, buckets = null } = {}) {
    this.windowMs = windowMs;
    this.maxRequests = maxRequests;
    this.hits = new Map();
    this.buckets = buckets || {
      auth: { windowMs: 60000, maxRequests: 10 },
      admin: { windowMs: 60000, maxRequests: 30 },
      commands: { windowMs: 60000, maxRequests: 60 },
      ota: { windowMs: 60000, maxRequests: 20 },
      password: { windowMs: 60000, maxRequests: 5 }
    };
  }

  isRateLimited(key, bucketName = null) {
    let windowMs = this.windowMs;
    let maxRequests = this.maxRequests;

    if (bucketName && this.buckets[bucketName]) {
      windowMs = this.buckets[bucketName].windowMs || windowMs;
      maxRequests = this.buckets[bucketName].maxRequests || maxRequests;
    }

    const fullKey = bucketName ? `${bucketName}:${key}` : key;
    const now = Date.now();
    const windowStart = now - windowMs;

    let timestamps = this.hits.get(fullKey) || [];
    // Filter out old timestamps
    timestamps = timestamps.filter(ts => ts > windowStart);

    if (timestamps.length >= maxRequests) {
      const oldestInWindow = timestamps[0];
      const retryAfterSeconds = Math.ceil((oldestInWindow + windowMs - now) / 1000);
      return { limited: true, retryAfterSeconds: Math.max(1, retryAfterSeconds) };
    }

    timestamps.push(now);
    this.hits.set(fullKey, timestamps);

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

  isAllowed(key, bucketName = null) {
    const res = this.isRateLimited(key, bucketName);
    return {
      allowed: !res.limited,
      limited: res.limited,
      retryAfterSeconds: res.retryAfterSeconds
    };
  }

  reset(key, bucketName = null) {
    if (key) {
      const fullKey = bucketName ? `${bucketName}:${key}` : key;
      this.hits.delete(fullKey);
    } else {
      this.hits.clear();
    }
  }
}

module.exports = {
  RateLimiter,
  SlidingWindowRateLimiter: RateLimiter
};
