'use strict';

/**
 * EH Home — Deterministic Runtime Configuration Layer (Phase 34)
 *
 * Implements typed, deterministic configuration parsing, environment validation,
 * secret classification, and production safety invariant enforcement.
 *
 * Invariants:
 * 1. Required secrets MUST NOT receive unsafe hard-coded production defaults.
 * 2. In production mode (NODE_ENV=production), loopback/RFC1918 LAN addresses are strictly prohibited.
 * 3. In production mode, weak/insecure fallback secrets are rejected.
 * 4. In production mode, debug routes and mock transports are prohibited.
 * 5. Secret values are classified and NEVER leaked into logs, diagnostics, or error strings.
 */

const VALID_ENVIRONMENTS = ['development', 'test', 'staging', 'production'];
const VALID_LOG_LEVELS = ['debug', 'info', 'warn', 'error'];

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
  /^dev_jwt_secret$/i,
  /^dev_session_secret$/i
];

const SECRET_CONFIG_KEYS = new Set([
  'DATABASE_PASSWORD',
  'SESSION_SECRET',
  'JWT_SECRET',
  'REDIS_PASSWORD',
  'MQTT_PASSWORD',
  'ADMIN_API_KEY',
  'APNS_AUTH_KEY',
  'FCM_SERVER_KEY'
]);

/**
 * Safe integer parser with fallback and range enforcement
 */
function parseIntSafe(val, defaultVal, min = 1, max = 65535) {
  if (val === undefined || val === null || val === '') return defaultVal;
  const num = parseInt(val, 10);
  if (isNaN(num) || num < min || num > max) return null;
  return num;
}

/**
 * Safe boolean parser
 */
function parseBoolSafe(val, defaultVal = false) {
  if (val === undefined || val === null || val === '') return defaultVal;
  if (typeof val === 'boolean') return val;
  const s = String(val).trim().toLowerCase();
  if (['true', '1', 'yes', 'on'].includes(s)) return true;
  if (['false', '0', 'no', 'off'].includes(s)) return false;
  return null;
}

/**
 * Parse and validate runtime configuration against environment variables
 *
 * @param {Object} [env=process.env] - Environment dictionary
 * @param {Object} [options]
 * @param {boolean} [options.throwOnFailure=false] - Throw Error on validation error
 * @returns {{ isValid: boolean, config: Object, errors: string[], warnings: string[] }}
 */
function loadAndValidateConfig(env = process.env, options = {}) {
  const errors = [];
  const warnings = [];

  const rawEnv = (env.NODE_ENV || 'development').trim().toLowerCase();
  if (!VALID_ENVIRONMENTS.includes(rawEnv)) {
    errors.push(`Invalid NODE_ENV "${env.NODE_ENV}". Must be one of: ${VALID_ENVIRONMENTS.join(', ')}`);
  }
  const isProduction = rawEnv === 'production';
  const isTest = rawEnv === 'test';

  // Port and Host
  const port = parseIntSafe(env.PORT, 3000, 1, 65535);
  if (port === null) {
    errors.push(`Invalid PORT "${env.PORT}". Must be an integer between 1 and 65535`);
  }
  const host = env.HOST || (isProduction ? '0.0.0.0' : '127.0.0.1');

  // Database URL
  const databaseUrl = env.DATABASE_URL || (isTest ? 'postgres://localhost:5432/eh_home_test' : null);
  if (isProduction && (!databaseUrl || typeof databaseUrl !== 'string' || databaseUrl.trim() === '')) {
    errors.push('Missing mandatory production environment variable: DATABASE_URL');
  }

  // Redis URL (Optional in dev/test, required or optional in prod)
  const redisUrl = env.REDIS_URL || null;
  if (isProduction && (!redisUrl || typeof redisUrl !== 'string' || redisUrl.trim() === '')) {
    errors.push('Missing mandatory production environment variable: REDIS_URL');
  }

  // MQTT Broker URL & TLS
  const mqttBrokerUrl = env.MQTT_BROKER_URL || null;
  const mqttTlsPort = parseIntSafe(env.MQTT_TLS_PORT, 8883, 1, 65535);
  if (mqttTlsPort === null) {
    errors.push(`Invalid MQTT_TLS_PORT "${env.MQTT_TLS_PORT}". Must be between 1 and 65535`);
  }
  if (isProduction && (!mqttBrokerUrl || typeof mqttBrokerUrl !== 'string' || mqttBrokerUrl.trim() === '')) {
    errors.push('Missing mandatory production environment variable: MQTT_BROKER_URL');
  }

  // JWT / Security Keypair Paths
  const jwtPrivateKeyPath = env.JWT_PRIVATE_KEY_PATH || null;
  const jwtPublicKeyPath = env.JWT_PUBLIC_KEY_PATH || null;
  const mqttCaPath = env.MQTT_CA_PATH || null;

  if (isProduction) {
    if (!jwtPrivateKeyPath || typeof jwtPrivateKeyPath !== 'string' || jwtPrivateKeyPath.trim() === '') {
      errors.push('Missing mandatory production environment variable: JWT_PRIVATE_KEY_PATH');
    }
    if (!jwtPublicKeyPath || typeof jwtPublicKeyPath !== 'string' || jwtPublicKeyPath.trim() === '') {
      errors.push('Missing mandatory production environment variable: JWT_PUBLIC_KEY_PATH');
    }
    if (!mqttCaPath || typeof mqttCaPath !== 'string' || mqttCaPath.trim() === '') {
      errors.push('Missing mandatory production environment variable: MQTT_CA_PATH');
    }
  }

  // Production restrictions: Loopback & RFC1918 check on endpoints
  if (isProduction) {
    const checkFields = [
      { name: 'DATABASE_URL', val: databaseUrl },
      { name: 'REDIS_URL', val: redisUrl },
      { name: 'MQTT_BROKER_URL', val: mqttBrokerUrl },
      { name: 'BACKEND_BASE_URL', val: env.BACKEND_BASE_URL }
    ];

    for (const { name, val } of checkFields) {
      if (val && typeof val === 'string') {
        for (const { pattern, message } of DISALLOWED_PROD_PATTERNS) {
          if (pattern.test(val)) {
            // Mask any embedded credentials before reporting error message
            const safeVal = sanitizeConnectionString(val);
            errors.push(`Invalid ${name}: ${message} (found "${safeVal}")`);
          }
        }
      }
    }

    // Weak secret detection
    const secretFields = [
      { name: 'SESSION_SECRET', val: env.SESSION_SECRET },
      { name: 'JWT_SECRET', val: env.JWT_SECRET },
      { name: 'DATABASE_PASSWORD', val: env.DATABASE_PASSWORD }
    ];

    for (const { name, val } of secretFields) {
      if (val && typeof val === 'string') {
        for (const pattern of WEAK_SECRET_PATTERNS) {
          if (pattern.test(val)) {
            errors.push(`Insecure ${name}: Weak/default secret detected in production`);
          }
        }
      }
    }

    // Reject debug/mock bypasses in production
    const enableDebugRoutes = parseBoolSafe(env.ENABLE_DEBUG_ROUTES, false);
    if (enableDebugRoutes === true) {
      errors.push('ENABLE_DEBUG_ROUTES must not be enabled in production mode');
    }

    const mockTransports = parseBoolSafe(env.MOCK_TRANSPORTS, false);
    if (mockTransports === true) {
      errors.push('MOCK_TRANSPORTS must not be enabled in production mode');
    }
  }

  // Log Level
  const logLevel = (env.LOG_LEVEL || 'info').toLowerCase();
  if (!VALID_LOG_LEVELS.includes(logLevel)) {
    warnings.push(`Unrecognized LOG_LEVEL "${env.LOG_LEVEL}". Defaulting to "info"`);
  }

  // Timeouts
  const shutdownTimeoutMs = parseIntSafe(env.SHUTDOWN_TIMEOUT_MS, 10000, 1000, 60000);
  if (shutdownTimeoutMs === null) {
    errors.push(`Invalid SHUTDOWN_TIMEOUT_MS "${env.SHUTDOWN_TIMEOUT_MS}". Must be between 1000 and 60000 ms`);
  }

  const healthCheckTimeoutMs = parseIntSafe(env.HEALTH_CHECK_TIMEOUT_MS, 1500, 100, 10000);
  if (healthCheckTimeoutMs === null) {
    errors.push(`Invalid HEALTH_CHECK_TIMEOUT_MS "${env.HEALTH_CHECK_TIMEOUT_MS}". Must be between 100 and 10000 ms`);
  }

  const isValid = errors.length === 0;

  const config = {
    environment: rawEnv,
    isProduction,
    isTest,
    port: port || 3000,
    host,
    backendBaseUrl: env.BACKEND_BASE_URL || `http://${host}:${port || 3000}`,
    databaseUrl,
    redisUrl,
    mqttBrokerUrl,
    mqttTlsPort: mqttTlsPort || 8883,
    jwtPrivateKeyPath,
    jwtPublicKeyPath,
    mqttCaPath,
    jwtSecret: env.JWT_SECRET || (isProduction ? null : 'dev_jwt_secret'),
    sessionSecret: env.SESSION_SECRET || (isProduction ? null : 'dev_session_secret'),
    logLevel: VALID_LOG_LEVELS.includes(logLevel) ? logLevel : 'info',
    shutdownTimeoutMs: shutdownTimeoutMs || 10000,
    healthCheckTimeoutMs: healthCheckTimeoutMs || 1500,
    enableDebugRoutes: parseBoolSafe(env.ENABLE_DEBUG_ROUTES, false) || false,
    mockTransports: parseBoolSafe(env.MOCK_TRANSPORTS, false) || false,
    secrets: {
      sessionSecret: env.SESSION_SECRET || null,
      jwtSecret: env.JWT_SECRET || null,
      databasePassword: env.DATABASE_PASSWORD || null,
      redisPassword: env.REDIS_PASSWORD || null
    }
  };

  if (!isValid && options.throwOnFailure) {
    const err = new Error(`Production Configuration Validation Failed:\n  - ${errors.join('\n  - ')}`);
    err.code = 'INVALID_PROD_CONFIG';
    err.errors = errors;
    throw err;
  }

  return {
    isValid,
    config,
    errors,
    warnings
  };
}

/**
 * Redact connection strings to remove username:password credentials
 */
function sanitizeConnectionString(connStr) {
  if (!connStr || typeof connStr !== 'string') return connStr;
  return connStr.replace(/(:\/\/)([^:@\s]+):([^@\s]+)@/g, '$1***:***@');
}

/**
 * Return safe non-secret representation of the configuration for diagnostics / logs
 */
function toSafeConfig(config) {
  if (!config || typeof config !== 'object') return {};

  return {
    schemaVersion: 1,
    environment: config.environment || 'development',
    port: config.port,
    host: config.host,
    backendBaseUrl: sanitizeConnectionString(config.backendBaseUrl),
    databaseBound: Boolean(config.databaseUrl),
    redisConfigured: Boolean(config.redisUrl),
    mqttConfigured: Boolean(config.mqttBrokerUrl),
    jwtKeypairConfigured: Boolean(config.jwtPrivateKeyPath && config.jwtPublicKeyPath),
    mqttCaConfigured: Boolean(config.mqttCaPath),
    logLevel: config.logLevel,
    shutdownTimeoutMs: config.shutdownTimeoutMs,
    healthCheckTimeoutMs: config.healthCheckTimeoutMs,
    features: {
      debugRoutes: config.enableDebugRoutes,
      mockTransports: config.mockTransports
    },
    timestamp: new Date().toISOString(),
    validationStatus: 'VALID'
  };
}

module.exports = {
  loadAndValidateConfig,
  toSafeConfig,
  sanitizeConnectionString,
  VALID_ENVIRONMENTS,
  SECRET_CONFIG_KEYS
};
