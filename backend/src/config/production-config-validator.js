'use strict';

/**
 * EH Home — Production Configuration Validator (Phase 13 & Phase 34)
 *
 * Enforces production security, secret separation, and zero-leakage startup gates.
 * Integrates with Phase 34 runtime-config module.
 */

const { loadAndValidateConfig } = require('./runtime-config');

const REQUIRED_PROD_VARS = [
  'DATABASE_URL',
  'REDIS_URL',
  'MQTT_BROKER_URL',
  'JWT_PRIVATE_KEY_PATH',
  'JWT_PUBLIC_KEY_PATH',
  'MQTT_CA_PATH'
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
  const result = loadAndValidateConfig(env, options);

  return {
    isValid: result.isValid,
    mode: env.NODE_ENV || 'development',
    errors: result.errors
  };
}

module.exports = {
  validateProductionConfig,
  REQUIRED_PROD_VARS
};
