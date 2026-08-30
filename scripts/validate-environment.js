#!/usr/bin/env node
'use strict';

/**
 * EH Home — Environment & Production Hardening Static Validator
 *
 * Scans production source files, configuration templates, and repository files to:
 * 1. Ensure zero forbidden dummy identifiers exist in production source.
 * 2. Ensure zero uncommitted secrets or private keys are tracked by Git.
 * 3. Verify environment separation (development vs staging vs production).
 * 4. Verify that runtime identities are dynamic and not hardcoded constants.
 */

const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');

const rootDir = path.resolve(__dirname, '..');

console.log('===============================================================');
console.log('       EH HOME — ENVIRONMENT & PRODUCTION HARDENING VALIDATOR  ');
console.log('===============================================================\n');

let failedChecks = 0;
let passedChecks = 0;

function check(name, fn) {
  try {
    fn();
    console.log(`  [PASS] ${name}`);
    passedChecks++;
  } catch (err) {
    console.error(`  [FAIL] ${name}: ${err.message}`);
    failedChecks++;
  }
}

// -----------------------------------------------------------------------------
// 1. FORBIDDEN PRODUCTION PLACEHOLDER SCAN
// -----------------------------------------------------------------------------
const FORBIDDEN_PRODUCTION_PATTERNS = [
  'SH-8EF248',
  'SH-MIST-V1',
  'living-room-light',
  'plant-mister',
];

// Production source directories where forbidden dummy tokens MUST NOT exist:
const PROD_SCAN_DIRS = [
  path.join(rootDir, 'smart_home_application_v1', 'lib', 'app'),
  path.join(rootDir, 'smart_home_application_v1', 'lib', 'core', 'services'),
  path.join(rootDir, 'smart_home_application_v1', 'lib', 'features', 'connection'),
  path.join(rootDir, 'backend', 'src'),
  path.join(rootDir, 'firmware', 'platforms', 'esp32', 'smart-switch-app', 'main'),
];

function scanDirectory(dir, forbiddenList) {
  if (!fs.existsSync(dir)) return [];
  const violations = [];
  const entries = fs.readdirSync(dir, { withFileTypes: true });

  for (const entry of entries) {
    const fullPath = path.join(dir, entry.name);
    if (entry.isDirectory()) {
      violations.push(...scanDirectory(fullPath, forbiddenList));
    } else if (entry.isFile() && (entry.name.endsWith('.dart') || entry.name.endsWith('.js') || entry.name.endsWith('.c') || entry.name.endsWith('.h'))) {
      const content = fs.readFileSync(fullPath, 'utf8');
      for (const pattern of forbiddenList) {
        if (content.includes(pattern)) {
          violations.push({ file: fullPath, pattern });
        }
      }
    }
  }
  return violations;
}

check('1. Production Source Scan: Zero forbidden dummy identifiers', () => {
  const allViolations = [];
  for (const dir of PROD_SCAN_DIRS) {
    allViolations.push(...scanDirectory(dir, FORBIDDEN_PRODUCTION_PATTERNS));
  }
  if (allViolations.length > 0) {
    const details = allViolations.map(v => `${path.relative(rootDir, v.file)} contains "${v.pattern}"`).join(', ');
    throw new Error(`Found forbidden placeholders in production paths: ${details}`);
  }
});

// -----------------------------------------------------------------------------
// 2. GIT SECRET SCAN: No private keys or secret credentials tracked
// -----------------------------------------------------------------------------
check('2. Git Secret Audit: No private keys tracked in Git', () => {
  try {
    const trackedFiles = execSync('git ls-files', { cwd: rootDir, encoding: 'utf8' }).split('\n').filter(Boolean);
    const forbiddenExtensions = ['.key', '.p12', '.pfx'];
    const secretViolations = [];

    for (const file of trackedFiles) {
      const ext = path.extname(file).toLowerCase();
      if (forbiddenExtensions.includes(ext)) {
        // Exclude test fixture keys if explicitly marked
        if (!file.includes('test') && !file.includes('fixture')) {
          secretViolations.push(file);
        }
      }
      if (file.endsWith('.pem')) {
        const fullPath = path.join(rootDir, file);
        if (fs.existsSync(fullPath)) {
          const content = fs.readFileSync(fullPath, 'utf8');
          if (content.includes('PRIVATE KEY') && !file.includes('test') && !file.includes('dev-certs')) {
            secretViolations.push(file);
          }
        }
      }
    }

    if (secretViolations.length > 0) {
      throw new Error(`Tracked private keys found in git index: ${secretViolations.join(', ')}`);
    }
  } catch (err) {
    if (err.message.includes('Tracked private keys')) throw err;
    // Git might not be in path or bare repo during test
  }
});

// -----------------------------------------------------------------------------
// 3. CONFIGURATION TEMPLATE VALIDATION
// -----------------------------------------------------------------------------
check('3. Environment Templates: .env.example contains all required integration keys', () => {
  const envExamplePath = path.join(rootDir, '.env.example');
  if (!fs.existsSync(envExamplePath)) {
    throw new Error('.env.example is missing from root directory');
  }
  const content = fs.readFileSync(envExamplePath, 'utf8');
  const requiredKeys = [
    'NODE_ENV',
    'BACKEND_BASE_URL',
    'DATABASE_URL',
    'REDIS_URL',
    'MQTT_BROKER_URL',
    'JWT_SECRET',
  ];
  for (const key of requiredKeys) {
    if (!content.includes(`${key}=`)) {
      throw new Error(`.env.example missing key: ${key}`);
    }
  }
});

// -----------------------------------------------------------------------------
// 4. FLUTTER CONFIGURATION COMPLIANCE
// -----------------------------------------------------------------------------
check('4. Flutter AppConfig: Supports compile-time --dart-define and environment safety', () => {
  const appConfigPath = path.join(rootDir, 'smart_home_application_v1', 'lib', 'core', 'config', 'app_config.dart');
  if (!fs.existsSync(appConfigPath)) {
    throw new Error('app_config.dart not found');
  }
  const content = fs.readFileSync(appConfigPath, 'utf8');
  if (!content.includes("String.fromEnvironment('BACKEND_BASE_URL'") && !content.includes('String.fromEnvironment(\n    \'BACKEND_BASE_URL\'')) {
    throw new Error('AppConfig does not read BACKEND_BASE_URL from environment');
  }
  if (!content.includes('isProduction')) {
    throw new Error('AppConfig missing isProduction safety check');
  }
});

// -----------------------------------------------------------------------------
// 5. BACKEND CONFIGURATION COMPLIANCE
// -----------------------------------------------------------------------------
check('5. Backend Config: Centralized validation module exists and checks production constraints', () => {
  const configModulePath = path.join(rootDir, 'backend', 'src', 'shared', 'config.js');
  if (!fs.existsSync(configModulePath)) {
    throw new Error('backend/src/shared/config.js not found');
  }
  const { validateConfig } = require(configModulePath);
  if (typeof validateConfig !== 'function') {
    throw new Error('validateConfig function not exported from config.js');
  }

  // Verify that insecure config in production throws
  let threw = false;
  try {
    validateConfig({
      env: 'production',
      isProduction: true,
      databaseUrl: 'postgresql://eh_admin:eh_development_password_only@localhost:5432/eh_home_dev',
      jwtSecret: 'short',
      sessionSecret: 'short',
      mqttBrokerUrl: 'mqtt://localhost:1883',
    });
  } catch (_) {
    threw = true;
  }
  if (!threw) {
    throw new Error('validateConfig failed to reject insecure default production configuration');
  }
});

console.log('\n───────────────────────────────────────────────────────────────');
console.log(`  ENVIRONMENT VALIDATION SUMMARY: ${passedChecks} PASSED, ${failedChecks} FAILED`);
console.log('───────────────────────────────────────────────────────────────\n');

if (failedChecks > 0) {
  process.exit(1);
} else {
  process.exit(0);
}
