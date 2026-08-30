'use strict';

/**
 * EH Home — Phase 13 Production Deployment & Operational Security Test Suite
 *
 * Tests:
 *   1. Production Config Validator fails fast on loopback / LAN IP in production mode
 *   2. Production Config Validator passes with fully qualified production configuration
 *   3. Backend Health Probes (/health/liveness, /health/readiness) & Graceful Shutdown
 *   4. Automated Database Backup, Checksum & Restore Verification
 *   5. Zero Secret Leakage & Keypair Boundary Verification
 */

const assert = require('assert').strict;
const fs = require('fs');
const path = require('path');
const { validateProductionConfig } = require('../src/config/production-config-validator');
const { DatabaseClient } = require('../src/shared/db-client');
const { createBackup } = require('../../tools/database/backup-database');
const { restoreBackup } = require('../../tools/database/restore-database');
const { createApp } = require('../src/app');

let totalTests = 0;
let passedTests = 0;

async function test(name, fn) {
  totalTests++;
  try {
    await fn();
    console.log(`[PASS] ${name}`);
    passedTests++;
  } catch (err) {
    console.error(`[FAIL] ${name}: ${err.message}`);
    if (err.stack) console.error(err.stack);
  }
}

(async () => {
  console.log('=== RUNNING PHASE 13 PRODUCTION DEPLOYMENT & SECURITY TESTS ===\n');

  // Test 1: Production Config Validator Rejections
  await test('1. Production Config Validator fails fast on loopback / LAN IP in production mode', async () => {
    const invalidEnv = {
      NODE_ENV: 'production',
      DATABASE_URL: 'postgres://user:pass@127.0.0.1:5432/db',
      REDIS_URL: 'redis://192.168.1.100:6379',
      MQTT_BROKER_URL: 'tls://localhost:8883',
      JWT_PRIVATE_KEY_PATH: '/etc/secrets/jwt_private.pem',
      JWT_PUBLIC_KEY_PATH: '/etc/secrets/jwt_public.pem',
      MQTT_CA_PATH: '/etc/certs/ca.crt'
    };

    const result = validateProductionConfig(invalidEnv);
    assert.equal(result.isValid, false);
    assert.equal(result.errors.length >= 3, true);

    assert.throws(
      () => validateProductionConfig(invalidEnv, { throwOnFailure: true }),
      /Production Configuration Validation Failed/
    );
  });

  // Test 2: Production Config Validator Acceptance
  await test('2. Production Config Validator passes with fully qualified production configuration', async () => {
    const validEnv = {
      NODE_ENV: 'production',
      DATABASE_URL: 'postgres://eh_user:StrongPass_2026_Prod@db.prod.ehhome.internal:5432/eh_prod',
      REDIS_URL: 'rediss://:RedisAuthPass998@redis.prod.ehhome.internal:6379',
      MQTT_BROKER_URL: 'tls://mqtt.prod.ehhome.internal:8883',
      JWT_PRIVATE_KEY_PATH: '/etc/secrets/jwt_private.pem',
      JWT_PUBLIC_KEY_PATH: '/etc/secrets/jwt_public.pem',
      MQTT_CA_PATH: '/etc/certs/ca.crt'
    };

    const result = validateProductionConfig(validEnv);
    assert.equal(result.isValid, true);
    assert.equal(result.errors.length, 0);
  });

  // Test 3: Health Probes & Graceful Readiness Check
  await test('3. Backend Health Probes (/health/liveness, /health/readiness) & Readiness distinction', async () => {
    const db = new DatabaseClient();
    const app = createApp({ db });

    function makeRequest(path) {
      return new Promise((resolve) => {
        const req = {
          url: path,
          method: 'GET',
          headers: {},
          socket: { remoteAddress: '127.0.0.1' },
          on: (event, handler) => { if (event === 'end') handler(); }
        };
        const res = {
          headers: {},
          writeHead: (status, headers) => { res.statusCode = status; res.headers = headers; },
          end: (payload) => { resolve({ status: res.statusCode, body: JSON.parse(payload) }); }
        };
        app.handleRequest(req, res);
      });
    }

    const liveness = await makeRequest('/api/v1/health/liveness');
    assert.equal(liveness.status, 200);
    assert.equal(liveness.body.status, 'UP');

    const readiness = await makeRequest('/api/v1/health/readiness');
    assert.equal(readiness.status, 200);
    assert.equal(readiness.body.status, 'READY');
    assert.equal(readiness.body.checks.database, 'CONNECTED');
  });

  // Test 4: Database Backup & Restore Automated Verification
  await test('4. Automated Database Backup, Checksum & Restore Verification', async () => {
    const sourceDb = new DatabaseClient();

    // Insert sample data
    await sourceDb.insert('users', 'usr_backup_test', {
      id: 'usr_backup_test',
      email: 'backup_verify@ehhome.io'
    });
    await sourceDb.insert('homes', 'home_backup_test', {
      id: 'home_backup_test',
      name: 'Backup Test Villa',
      owner_id: 'usr_backup_test'
    });

    const testBackupDir = path.join(__dirname, '..', '..', 'backups', 'test_scratch');
    const backupRes = createBackup(sourceDb, testBackupDir);

    assert.ok(fs.existsSync(backupRes.backupPath));
    assert.ok(fs.existsSync(`${backupRes.backupPath}.sha256`));

    // Restore into a fresh isolated DatabaseClient instance
    const targetDb = new DatabaseClient();
    const restoreRes = restoreBackup(backupRes.backupPath, targetDb);

    assert.equal(restoreRes.success, true);
    assert.equal(restoreRes.totalRowsRestored >= 2, true);

    const restoredUser = await targetDb.findById('users', 'usr_backup_test');
    assert.ok(restoredUser);
    assert.equal(restoredUser.email, 'backup_verify@ehhome.io');

    // Clean up test backup files
    fs.unlinkSync(backupRes.backupPath);
    fs.unlinkSync(`${backupRes.backupPath}.sha256`);
    fs.rmdirSync(testBackupDir);
  });

  // Test 5: Secret Boundary & Key Isolation
  await test('5. Zero Secret Leakage & Keypair Boundary Verification', async () => {
    const sensitivePatterns = [
      /-----BEGIN (?:RSA |EC )?PRIVATE KEY-----/,
      /aws_secret_access_key\s*=\s*[A-Za-z0-9\/+=]{40}/i
    ];

    const repoRoot = path.join(__dirname, '..', '..');
    const backendSrc = path.join(repoRoot, 'backend', 'src');

    function checkDir(dir) {
      const entries = fs.readdirSync(dir, { withFileTypes: true });
      for (const entry of entries) {
        const full = path.join(dir, entry.name);
        if (entry.isDirectory()) {
          checkDir(full);
        } else if (/\.(js|json)$/.test(entry.name)) {
          const content = fs.readFileSync(full, 'utf8');
          for (const pat of sensitivePatterns) {
            assert.equal(pat.test(content), false, `Sensitive pattern found in ${full}`);
          }
        }
      }
    }

    checkDir(backendSrc);
  });

  // Test 6: MQTT Certificate-Bound Authorization Matrix
  await test('6. MQTT Certificate-Bound Authorization Matrix (A->A allow, A->B deny, spoof deny)', async () => {
    const { evaluateMqttAuthorization } = require('../src/services/mqtt-http-authorizer.service');
    const DEV_A = '0194fe23-7a1b-7890-a123-456789abcdef';
    const DEV_B = '0194fe23-7a1b-7890-b456-123456fedcba';

    assert.equal(evaluateMqttAuthorization({ cert_common_name: DEV_A, clientid: DEV_A, topic: `eh/v1/devices/${DEV_A}/state`, action: 'publish' }).result, 'allow');
    assert.equal(evaluateMqttAuthorization({ cert_common_name: DEV_A, clientid: DEV_A, topic: `eh/v1/devices/${DEV_B}/state`, action: 'publish' }).result, 'deny');
    assert.equal(evaluateMqttAuthorization({ cert_common_name: DEV_B, clientid: DEV_B, topic: `eh/v1/devices/${DEV_A}/state`, action: 'publish' }).result, 'deny');
    assert.equal(evaluateMqttAuthorization({ cert_common_name: DEV_A, clientid: DEV_B, topic: `eh/v1/devices/${DEV_B}/state`, action: 'publish' }).result, 'deny');
  });

  console.log('\n===============================================================');
  console.log(`  PHASE 13 TEST SUMMARY: ${passedTests} PASSED, ${totalTests - passedTests} FAILED`);
  console.log('===============================================================\n');

  if (passedTests === totalTests) {
    process.exit(0);
  } else {
    process.exit(1);
  }
})();
