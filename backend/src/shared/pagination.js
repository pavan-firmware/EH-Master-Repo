'use strict';

/**
 * EH Home — Bounded Pagination & Resource Limits (Phase 44)
 *
 * Enforces strict upper bounds on list endpoints to prevent unbounded result sets,
 * excessive database scans, or high memory serialization spikes.
 */

const DEFAULT_LIMIT = 50;
const MAX_LIMIT = 200;

function parsePagination(query = {}, customDefaults = {}) {
  const defaultLimit = customDefaults.defaultLimit || DEFAULT_LIMIT;
  const maxLimit = customDefaults.maxLimit || MAX_LIMIT;

  let limit = parseInt(query.limit, 10);
  if (isNaN(limit) || limit <= 0) {
    limit = defaultLimit;
  } else if (limit > maxLimit) {
    limit = maxLimit; // Strictly clamp to maximum allowable limit
  }

  let page = parseInt(query.page, 10);
  let offset = parseInt(query.offset, 10);

  if (!isNaN(offset) && offset >= 0) {
    // offset-based pagination
    return { limit, offset, maxLimit };
  }

  if (isNaN(page) || page <= 0) {
    page = 1;
  }
  offset = (page - 1) * limit;

  return { limit, offset, page, maxLimit };
}

/**
 * Executes an array of async tasks with bounded concurrency limit.
 * Eliminates unbounded Promise.all() execution across large fleet sizes.
 * Supports signatures: (items, taskFn, concurrencyLimit) or (items, concurrencyLimit, taskFn)
 */
async function runWithConcurrencyLimit(items, arg2, arg3) {
  if (!Array.isArray(items) || items.length === 0) {
    return [];
  }

  let taskFn;
  let concurrencyLimit;

  if (typeof arg2 === 'function') {
    taskFn = arg2;
    concurrencyLimit = typeof arg3 === 'number' ? arg3 : 10;
  } else if (typeof arg3 === 'function') {
    taskFn = arg3;
    concurrencyLimit = typeof arg2 === 'number' ? arg2 : 10;
  } else {
    throw new Error('runWithConcurrencyLimit requires a task function');
  }

  const limit = Math.max(1, Math.min(concurrencyLimit || 10, items.length));
  const results = new Array(items.length);
  let currentIndex = 0;

  const workers = Array.from({ length: limit }, async () => {
    while (currentIndex < items.length) {
      const idx = currentIndex++;
      try {
        results[idx] = await taskFn(items[idx], idx);
      } catch (err) {
        results[idx] = { error: err.message, item: items[idx], idx };
      }
    }
  });

  await Promise.all(workers);
  return results;
}

module.exports = {
  DEFAULT_LIMIT,
  MAX_LIMIT,
  parsePagination,
  runWithConcurrencyLimit
};
