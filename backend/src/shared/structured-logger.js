'use strict';

/**
 * EH Home — Structured Logger (Phase 43)
 *
 * Emits JSON-formatted structured log entries with mandatory redaction of
 * credentials/secrets and automatic correlation context attachment.
 */

const SENSITIVE_KEY_PATTERNS = [
  /password/i,
  /secret/i,
  /token/i,
  /key/i,
  /authorization/i,
  /credential/i,
  /private/i,
  /pin/i,
  /cert/i,
  /bearer/i,
  /cookie/i,
  /session/i
];

const LOG_LEVELS = {
  DEBUG: 10,
  INFO: 20,
  WARN: 30,
  ERROR: 40,
  FATAL: 50
};

class StructuredLogger {
  constructor(options = {}) {
    this.serviceName = options.serviceName || 'eh-backend';
    this.minLevel = (options.minLevel || process.env.LOG_LEVEL || 'INFO').toUpperCase();
    this.sink = options.sink || console.log;
    this.errorSink = options.errorSink || console.error;
    this.defaultContext = options.defaultContext || {};
  }

  static redactValue(val) {
    return '[REDACTED]';
  }

  static isSensitiveKey(key) {
    if (typeof key !== 'string') return false;
    return SENSITIVE_KEY_PATTERNS.some(regex => regex.test(key));
  }

  static sanitizeObject(obj, seen = new WeakSet()) {
    if (obj === null || obj === undefined) return obj;
    if (typeof obj !== 'object') {
      return obj;
    }

    if (seen.has(obj)) {
      return '[CIRCULAR]';
    }
    seen.add(obj);

    if (obj instanceof Error) {
      return {
        name: obj.name,
        message: obj.message,
        stack: obj.stack
      };
    }

    if (Array.isArray(obj)) {
      return obj.map(item => StructuredLogger.sanitizeObject(item, seen));
    }

    const sanitized = {};
    for (const [k, v] of Object.entries(obj)) {
      if (StructuredLogger.isSensitiveKey(k)) {
        sanitized[k] = StructuredLogger.redactValue(v);
      } else if (typeof v === 'object' && v !== null) {
        sanitized[k] = StructuredLogger.sanitizeObject(v, seen);
      } else {
        sanitized[k] = v;
      }
    }
    return sanitized;
  }

  child(context = {}) {
    return new StructuredLogger({
      serviceName: this.serviceName,
      minLevel: this.minLevel,
      sink: this.sink,
      errorSink: this.errorSink,
      defaultContext: { ...this.defaultContext, ...context }
    });
  }

  _shouldLog(level) {
    const minVal = LOG_LEVELS[this.minLevel] || LOG_LEVELS.INFO;
    const currentVal = LOG_LEVELS[level] || LOG_LEVELS.INFO;
    return currentVal >= minVal;
  }

  _formatEntry(level, message, context = {}, error = null) {
    const mergedContext = { ...this.defaultContext, ...context };
    const sanitizedContext = StructuredLogger.sanitizeObject(mergedContext);

    const correlationId = mergedContext.correlationId ||
                          mergedContext.correlation_id ||
                          mergedContext.requestId ||
                          mergedContext.request_id ||
                          null;

    const entry = {
      timestamp: new Date().toISOString(),
      level,
      service: this.serviceName,
      message,
      correlation_id: correlationId,
      context: sanitizedContext
    };

    if (error) {
      entry.error = {
        name: error.name || 'Error',
        message: error.message || String(error),
        stack: error.stack || null
      };
    }

    return entry;
  }

  log(level, message, context = {}, error = null) {
    const normalizedLevel = level.toUpperCase();
    if (!this._shouldLog(normalizedLevel)) {
      return null;
    }

    const entry = this._formatEntry(normalizedLevel, message, context, error);
    const jsonStr = JSON.stringify(entry);

    if (normalizedLevel === 'ERROR' || normalizedLevel === 'FATAL') {
      this.errorSink(jsonStr);
    } else {
      this.sink(jsonStr);
    }

    return entry;
  }

  debug(message, context = {}) {
    return this.log('DEBUG', message, context);
  }

  info(message, context = {}) {
    return this.log('INFO', message, context);
  }

  warn(message, context = {}, error = null) {
    return this.log('WARN', message, context, error);
  }

  error(message, context = {}, error = null) {
    return this.log('ERROR', message, context, error);
  }

  fatal(message, context = {}, error = null) {
    return this.log('FATAL', message, context, error);
  }
}

const defaultLogger = new StructuredLogger();

module.exports = {
  StructuredLogger,
  defaultLogger,
  LOG_LEVELS
};
