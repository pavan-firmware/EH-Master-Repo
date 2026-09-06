/**
 * Audit Redaction Service (Phase 31 & Phase 42 Hardening)
 *
 * Deterministically sanitizes payloads to prevent secret leakage into
 * operational event logs, security audit records, error responses, and traces.
 *
 * Replaces values of sensitive keys with '[REDACTED]'.
 */

const SENSITIVE_KEY_PATTERNS = [
  /password/i,
  /secret/i,
  /token/i,
  /pin/i,
  /credential/i,
  /private_key/i,
  /privatekey/i,
  /authorization/i,
  /passphrase/i,
  /presharedkey/i,
  /psk/i,
  /jwt/i,
  /pairing_code/i,
  /setup_pin/i,
  /api_key/i,
  /apikey/i,
  /client_secret/i,
  /access_token/i,
  /refresh_token/i,
  /encryption_key/i,
  /signing_key/i,
  /db_password/i,
  /connection_string/i,
  /database_url/i,
  /db_url/i,
  /connection_url/i,
  /bearer/i,
  /private_pem/i
];

class AuditRedactionService {
  /**
   * Recursively sanitizes any object or array, redacting sensitive keys.
   * Returns a tuple of { sanitized, markers } where markers records the paths redacted.
   */
  static redact(target, currentPath = '') {
    if (target === null || target === undefined) {
      return { sanitized: target, markers: [] };
    }

    if (typeof target !== 'object') {
      return { sanitized: target, markers: [] };
    }

    if (Array.isArray(target)) {
      const sanitizedArr = [];
      const markers = [];
      for (let i = 0; i < target.length; i++) {
        const itemPath = currentPath ? `${currentPath}[${i}]` : `[${i}]`;
        const { sanitized, markers: subMarkers } = AuditRedactionService.redact(target[i], itemPath);
        sanitizedArr.push(sanitized);
        markers.push(...subMarkers);
      }
      return { sanitized: sanitizedArr, markers };
    }

    const sanitizedObj = {};
    const markers = [];

    for (const [key, value] of Object.entries(target)) {
      const fieldPath = currentPath ? `${currentPath}.${key}` : key;
      const isSensitive = SENSITIVE_KEY_PATTERNS.some(regex => regex.test(key));

      if (isSensitive) {
        sanitizedObj[key] = '[REDACTED]';
        markers.push(fieldPath);
      } else if (value !== null && typeof value === 'object') {
        const { sanitized, markers: subMarkers } = AuditRedactionService.redact(value, fieldPath);
        sanitizedObj[key] = sanitized;
        markers.push(...subMarkers);
      } else {
        sanitizedObj[key] = value;
      }
    }

    return { sanitized: sanitizedObj, markers };
  }

  /**
   * Helper that only returns sanitized object
   */
  static sanitize(target) {
    return AuditRedactionService.redact(target).sanitized;
  }

  /**
   * Redacts sensitive details from error messages and objects in production
   */
  static sanitizeError(err, isProduction = (process.env.NODE_ENV === 'production')) {
    if (!err) {
      return { code: 'INTERNAL_ERROR', message: 'An unexpected error occurred' };
    }

    const code = err.code || err.statusCode || 'INTERNAL_ERROR';
    let message = typeof err === 'string' ? err : (err.message || 'An unexpected error occurred');

    if (isProduction) {
      // In production mode, remove filesystem paths, stack traces, and internal DB details
      message = message
        .replace(/(\/|[A-Za-z]:\\)[^\s:]+/g, '[INTERNAL_PATH]')
        .replace(/SELECT\s+.*?\s+FROM/gi, '[SQL_QUERY]')
        .replace(/INSERT\s+INTO/gi, '[SQL_QUERY]')
        .replace(/UPDATE\s+.*?\s+SET/gi, '[SQL_QUERY]')
        .replace(/DELETE\s+FROM/gi, '[SQL_QUERY]');
    }

    return {
      code,
      message,
      ...(isProduction ? {} : { stack: err.stack })
    };
  }
}

module.exports = {
  AuditRedactionService,
  SENSITIVE_KEY_PATTERNS
};
