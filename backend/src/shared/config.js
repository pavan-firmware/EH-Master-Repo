'use strict';

/**
 * EH Home — Centralized Backend Configuration & Validation
 *
 * Provides typed, validated access to environment variables across
 * development, staging, and production environments.
 */

const NODE_ENV = process.env.NODE_ENV || 'development';
const isProduction = NODE_ENV === 'production';
const isStaging = NODE_ENV === 'staging';
const isTest = NODE_ENV === 'test';
const isDevelopment = !isProduction && !isStaging && !isTest;

/**
 * Validate configuration on startup
 */
function validateConfig(cfg) {
  const errors = [];
  const prod = cfg.isProduction || cfg.env === 'production';

  if (prod) {
    if (!cfg.databaseUrl || cfg.databaseUrl.includes('localhost') || cfg.databaseUrl.includes('eh_development_password_only')) {
      errors.push('DATABASE_URL must be configured with a production PostgreSQL connection string.');
    }
    if (!cfg.jwtSecret || cfg.jwtSecret.includes('dev_jwt_secret') || cfg.jwtSecret.length < 32) {
      errors.push('JWT_SECRET must be set to a cryptographically secure string (min 32 characters) in production.');
    }
    if (!cfg.sessionSecret || cfg.sessionSecret.includes('dev_session_secret') || cfg.sessionSecret.length < 32) {
      errors.push('SESSION_SECRET must be set to a cryptographically secure string (min 32 characters) in production.');
    }
    if (cfg.mqttBrokerUrl && !cfg.mqttBrokerUrl.startsWith('mqtts://') && !cfg.mqttBrokerUrl.startsWith('ssl://')) {
      errors.push('MQTT_BROKER_URL must use TLS (mqtts://) in production.');
    }
  }

  if (errors.length > 0) {
    const errorMsg = `[Configuration Error] Startup validation failed:\n  - ${errors.join('\n  - ')}`;
    throw new Error(errorMsg);
  }
}

const config = {
  env: NODE_ENV,
  isProduction,
  isStaging,
  isTest,
  isDevelopment,

  port: parseInt(process.env.PORT || '3000', 10),
  host: process.env.HOST || '0.0.0.0',

  databaseUrl: process.env.DATABASE_URL || 'postgresql://eh_admin:eh_development_password_only@localhost:5432/eh_home_dev',
  redisUrl: process.env.REDIS_URL || 'redis://localhost:6379',

  mqttBrokerUrl: process.env.MQTT_TLS_BROKER_URL || process.env.MQTT_BROKER_URL || 'mqtt://127.0.0.1:1883',
  mqttBackendUsername: process.env.MQTT_BACKEND_USERNAME || 'eh_backend_service',
  mqttBackendPassword: process.env.MQTT_BACKEND_PASSWORD || '',
  mqttCaFile: process.env.MQTT_CA_FILE || null,
  mqttClientCert: process.env.MQTT_CLIENT_CERT || null,
  mqttClientKey: process.env.MQTT_CLIENT_KEY || null,

  jwtSecret: process.env.JWT_SECRET || 'eh_local_dev_jwt_secret_do_not_use_in_prod_1234567890',
  sessionSecret: process.env.SESSION_SECRET || 'eh_local_dev_session_secret_do_not_use_in_prod_1234567890',
  jwtExpiresIn: process.env.JWT_EXPIRES_IN || '15m',
  refreshTokenExpiresIn: process.env.REFRESH_TOKEN_EXPIRES_IN || '30d',

  s3Endpoint: process.env.S3_ENDPOINT || 'http://localhost:9000',
  s3Bucket: process.env.S3_BUCKET || 'eh-firmware-releases',
  s3AccessKey: process.env.S3_ACCESS_KEY || '',
  s3SecretKey: process.env.S3_SECRET_KEY || '',
};

// Perform validation
validateConfig(config);

module.exports = { config, validateConfig };
