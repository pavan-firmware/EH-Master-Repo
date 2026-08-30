'use strict';

/**
 * EH Home — Production Configuration Validator (Phase 13)
 *
 * Enforces production security, secret separation, and zero-leakage startup gates.
 * In production mode (`NODE_ENV=production`), refuses to boot if:
 *   - Missing required database, Redis, MQTT, or JWT keypair configurations
 *   - Any production service endpoint points to localhost, 127.0.0.1, or developer LAN IPs (192.168.x.x)
 *   - Default or insecure fallback secrets are detected
 */

const REQUIRED_PROD_VARS = [
  'DATABASE_URL',
  'REDIS_URL',
  'MQTT_BROKER_URL',
  'JWT_PRIVATE_KEY_PATH',
  'JWT_PUBLIC_KEY_PATH',
  'MQTT_CA_PATH'
];

const DISALLOWED_PROD_PATTERNS = [
  { pattern: /localhost/i, message: 'localhost is not permitted in production configuration' },
  { pattern: /127\.0\.0\.1/, message: '127.0.0.1 loopback IP is not permitted in production configuration' },
  { pattern: /192\.168\.\d{1,3}\.\d{1,3}/, message: 'Developer LAN IP (192.168.x.x) is not permitted in production configuration' }
];

const WEAK_SECRET_PATTERNS = [
  /^password$/i,
  /^secret$/i,
  /^changeme$/i,
  /^123456$/,
  /^admin$/i,
  /^test$/i,
  /^dev_jwt_secret$/i
];

/**
 * Validate configuration object or environment variables
 *
 * @param {Object} env - Environment variables dictionary (defaults to process.env)
 * @param {Object} [options]
 * @param {boolean} [options.throwOnFailure=false] - Whether to throw an Error on validation failure
 * @returns {{ isValid: boolean, mode: string, errors: string[] }}
 */
function validateProductionConfig(env = process.env, options = {}) {
  const isProduction = env.NODE_ENV === 'production';
  const errors = [];

  if (!isProduction) {
    return {
      isValid: true,
      mode: env.NODE_ENV || 'development',
      errors: []
    };
  }

  // 1. Verify all mandatory production environment variables are present and non-empty
  for (const varName of REQUIRED_PROD_VARS) {
    const val = env[varName];
    if (!val || typeof val !== 'string' || val.trim() === '') {
      errors.push(`Missing mandatory production environment variable: ${varName}`);
    }
  }

  // 2. Check for disallowed dev endpoints in URLs
  const checkFields = ['DATABASE_URL', 'REDIS_URL', 'MQTT_BROKER_URL', 'BACKEND_BASE_URL'];
  for (const field of checkFields) {
    const val = env[field];
    if (val && typeof val === 'string') {
      for (const { pattern, message } of DISALLOWED_PROD_PATTERNS) {
        if (pattern.test(val)) {
          errors.push(`Invalid ${field}: ${message} (found "${val}")`);
        }
      }
    }
  }

  // 3. Check for weak fallback secrets
  const secretFields = ['SESSION_SECRET', 'JWT_SECRET', 'DATABASE_PASSWORD'];
  for (const field of secretFields) {
    const val = env[field];
    if (val && typeof val === 'string') {
      for (const pattern of WEAK_SECRET_PATTERNS) {
        if (pattern.test(val)) {
          errors.push(`Insecure ${field}: Weak/default secret detected in production`);
        }
      }
    }
  }

  const isValid = errors.length === 0;

  if (!isValid && options.throwOnFailure) {
    const err = new Error(`Production Configuration Validation Failed:\n  - ${errors.join('\n  - ')}`);
    err.code = 'INVALID_PROD_CONFIG';
    err.errors = errors;
    throw err;
  }

  return {
    isValid,
    mode: 'production',
    errors
  };
}

module.exports = {
  validateProductionConfig,
  REQUIRED_PROD_VARS
};
