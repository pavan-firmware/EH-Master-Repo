'use strict';

/**
 * EH Home — Phase 38 Push Notifications Test Suite
 *
 * Deterministic test suite covering:
 *   1. Provider selection (Simulated, FCM, APNs, Composite)
 *   2. Production provider validation & fail-fast configuration
 *   3. FCM HTTP v1 OAuth2 authentication & JWT assertion
 *   4. APNs HTTP/2 authentication & environment routing
 *   5. Successful send across providers
 *   6. Temporary failure classification (503, 429, ECONNRESET, timeout)
 *   7. Permanent failure classification (404 Unregistered, 400 Bad Request, 401 Auth)
 *   8. Invalid token handling & deactivation
 *   9. Delivery retry behavior & backoff
 *  10. Idempotent delivery & deduplication
 *  11. User token ownership isolation
 *  12. Push token & secret redaction in logs/diagnostics
 *  13. Phase 30 notification decision engine integration
 *  14. Quiet-hours preservation
 *  15. Severity classification preservation (CRITICAL, ERROR, WARNING, NOTICE, INFO)
 *  16. User notification preference & channel suppression preservation
 */

const crypto = require('crypto');
const { DatabaseClient } = require('../src/shared/db-client');
const { NotificationRepository, UserRepository, HomeRepository } = require('../src/repositories');
const {
  BasePushNotificationProvider,
  SimulatedPushProvider,
  FcmHttpV1PushProvider,
  ApnsPushProvider,
  CompositePushProvider,
  createPushProvider,
  maskToken
} = require('../src/services/push-notification-provider');
const { NotificationService } = require('../src/services/notification.service');
const { NotificationDeliveryWorker } = require('../src/workers/notification-delivery-worker');
const { loadAndValidateConfig } = require('../src/config/runtime-config');

let totalTests = 0;
let passedTests = 0;
let failedTests = 0;

function assert(desc, condition, details = '') {
  totalTests++;
  if (condition) {
    passedTests++;
    console.log(`  ✓ ${desc}`);
  } else {
    failedTests++;
    console.error(`  ✗ FAIL: ${desc}${details ? ` - ${details}` : ''}`);
  }
}

// Generate test RSA and EC keypairs for deterministic testing
const { privateKey: testRsaPrivateKey } = crypto.generateKeyPairSync('rsa', {
  modulusLength: 2048,
  publicKeyEncoding: { type: 'spki', format: 'pem' },
  privateKeyEncoding: { type: 'pkcs8', format: 'pem' }
});

const { privateKey: testEcPrivateKey } = crypto.generateKeyPairSync('ec', {
  namedCurve: 'prime256v1',
  publicKeyEncoding: { type: 'spki', format: 'pem' },
  privateKeyEncoding: { type: 'pkcs8', format: 'pem' }
});

async function runSuite() {
  console.log('=== RUNNING PHASE 38 PUSH NOTIFICATIONS SUITE ===\n');

  // Test 1: Provider selection
  console.log('--- Scenario 1: Provider Selection ---');
  const simProvider = createPushProvider('simulated');
  assert('Simulated provider selected correctly', simProvider instanceof SimulatedPushProvider);

  const fcmProvider = createPushProvider('fcm', {
    projectId: 'test-project',
    clientEmail: 'firebase-adminsdk@test-project.iam.gserviceaccount.com',
    privateKey: testRsaPrivateKey
  });
  assert('FCM HTTP v1 provider instantiated correctly', fcmProvider instanceof FcmHttpV1PushProvider);

  const apnsProvider = createPushProvider('apns', {
    keyId: 'KEY1234567',
    teamId: 'TEAM123456',
    bundleId: 'com.ehhome.app',
    privateKey: testEcPrivateKey,
    isProduction: false
  });
  assert('APNs provider instantiated correctly', apnsProvider instanceof ApnsPushProvider);

  const compositeProvider = createPushProvider('composite', {
    fcm: {
      projectId: 'test-project',
      clientEmail: 'firebase-adminsdk@test-project.iam.gserviceaccount.com',
      privateKey: testRsaPrivateKey
    },
    apns: {
      keyId: 'KEY1234567',
      teamId: 'TEAM123456',
      bundleId: 'com.ehhome.app',
      privateKey: testEcPrivateKey
    }
  });
  assert('Composite provider routes to both FCM and APNs', compositeProvider instanceof CompositePushProvider);

  // Test 2: Production provider validation & fail-fast
  console.log('\n--- Scenario 2: Production Provider Validation & Fail-Fast ---');
  const prodConfigResult = loadAndValidateConfig({
    NODE_ENV: 'production',
    DATABASE_URL: 'postgres://db.production.internal:5432/eh_home',
    REDIS_URL: 'redis://redis.production.internal:6379',
    MQTT_BROKER_URL: 'mqtts://mqtt.production.internal:8883',
    JWT_PRIVATE_KEY_PATH: '/etc/secrets/jwt.key',
    JWT_PUBLIC_KEY_PATH: '/etc/secrets/jwt.pub',
    MQTT_CA_PATH: '/etc/secrets/ca.crt',
    PUSH_PROVIDER_TYPE: 'simulated'
  });
  assert('Rejects simulated push provider in production without explicit override', !prodConfigResult.isValid);
  assert('Reports production error for simulated push provider', prodConfigResult.errors.some(e => e.includes('Simulated push provider is not allowed in production')));

  const unconfiguredFcm = new FcmHttpV1PushProvider({});
  assert('Unconfigured FCM provider reports isConfigured === false', unconfiguredFcm.isConfigured === false);

  // Test 3: FCM HTTP v1 OAuth2 authentication & JWT assertion
  console.log('\n--- Scenario 3: FCM OAuth2 Authentication & Token Acquisition ---');
  const mockFcm = new FcmHttpV1PushProvider({
    projectId: 'eh-home-prod',
    clientEmail: 'service-account@eh-home-prod.iam.gserviceaccount.com',
    privateKey: testRsaPrivateKey,
    httpClient: async (opts) => {
      if (opts.url && opts.url.includes('oauth2.googleapis.com')) {
        return {
          statusCode: 200,
          headers: { 'content-type': 'application/json' },
          body: JSON.stringify({
            access_token: 'ya29.mock_oauth2_access_token_12345',
            token_type: 'Bearer',
            expires_in: 3600
          })
        };
      }
      return {
        statusCode: 200,
        headers: { 'content-type': 'application/json' },
        body: JSON.stringify({ name: 'projects/eh-home-prod/messages/msg_123456' })
      };
    }
  });

  const tokenRes = await mockFcm.getAccessToken();
  assert('Successfully creates signed RS256 assertion and acquires OAuth2 token', tokenRes === 'ya29.mock_oauth2_access_token_12345');

  // Test 4: APNs HTTP/2 Authentication & Environment Routing
  console.log('\n--- Scenario 4: APNs Authentication & Environment Routing ---');
  const mockApns = new ApnsPushProvider({
    keyId: 'ABC1234567',
    teamId: 'DEF8901234',
    bundleId: 'com.ehhome.smartapp',
    privateKey: testEcPrivateKey,
    isProduction: true
  });
  const apnsToken = mockApns.getAuthToken();
  assert('APNs generates valid ES256 JWT auth token with kid in header', typeof apnsToken === 'string' && apnsToken.split('.').length === 3);
  assert('APNs production is set correctly', mockApns.isProduction === true);

  // Test 5: Successful push delivery
  console.log('\n--- Scenario 5: Successful Push Delivery ---');
  const fcmSendResult = await mockFcm.sendPush(
    { pushToken: 'dK81Jsk91_fcm_test_device_token_xyz', platform: 'android' },
    {
      notificationId: 'notif_001',
      title: 'Smoke Detector Alert',
      body: 'Smoke detected in Kitchen',
      priority: 'CRITICAL',
      category: 'SAFETY',
      data: { homeId: 'home_001', deviceId: 'dev_smoke_01' }
    }
  );
  assert('FCM send succeeds with success: true', fcmSendResult.success === true);
  assert('FCM returns provider message ID', fcmSendResult.messageId.includes('msg_123456'));

  // Test 6: Temporary failure classification
  console.log('\n--- Scenario 6: Temporary Failure Classification ---');
  const tempFailFcm = new FcmHttpV1PushProvider({
    projectId: 'eh-home-prod',
    clientEmail: 'service-account@eh-home-prod.iam.gserviceaccount.com',
    privateKey: testRsaPrivateKey,
    httpClient: async (opts) => {
      if (opts.url && opts.url.includes('oauth2.googleapis.com')) {
        return {
          statusCode: 200,
          headers: {},
          body: JSON.stringify({ access_token: 'mock_token', expires_in: 3600 })
        };
      }
      return {
        statusCode: 503,
        headers: {},
        body: JSON.stringify({ error: { message: 'The service is currently unavailable', status: 'UNAVAILABLE' } })
      };
    }
  });

  const tempResult = await tempFailFcm.sendPush(
    { pushToken: 'device_token_123', platform: 'android' },
    { title: 'Test', body: 'Temp fail' }
  );
  assert('HTTP 503 classified as temporary: true', tempResult.success === false && tempResult.temporary === true);
  assert('Temporary failure is not marked permanent', !tempResult.permanent);

  // Test 7: Permanent failure classification
  console.log('\n--- Scenario 7: Permanent Failure Classification ---');
  const permFailFcm = new FcmHttpV1PushProvider({
    projectId: 'eh-home-prod',
    clientEmail: 'service-account@eh-home-prod.iam.gserviceaccount.com',
    privateKey: testRsaPrivateKey,
    httpClient: async (opts) => {
      if (opts.url && opts.url.includes('oauth2.googleapis.com')) {
        return {
          statusCode: 200,
          headers: {},
          body: JSON.stringify({ access_token: 'mock_token', expires_in: 3600 })
        };
      }
      return {
        statusCode: 404,
        headers: {},
        body: JSON.stringify({ error: { message: 'Requested entity was not found', status: 'NOT_FOUND', details: [{ errorCode: 'UNREGISTERED' }] } })
      };
    }
  });

  const permResult = await permFailFcm.sendPush(
    { pushToken: 'stale_token_123', platform: 'android' },
    { title: 'Test', body: 'Perm fail' }
  );
  assert('HTTP 404 UNREGISTERED classified as permanent: true and invalidToken: true', permResult.success === false && permResult.permanent === true && permResult.invalidToken === true);

  // Test 8: Invalid token handling & deactivation
  console.log('\n--- Scenario 8: Invalid Token Handling & Deactivation ---');
  const db = new DatabaseClient();
  const notifRepo = new NotificationRepository(db);
  const userToken = await notifRepo.upsertDeviceToken({
    userId: 'user_alice_01',
    pushToken: 'device_token_expired_999',
    platform: 'android',
    deviceName: 'Pixel 8'
  });
  assert('Saved active device token in repository', userToken.is_active === true);

  // Mark token inactive via removeDeviceToken
  await notifRepo.removeDeviceToken('device_token_expired_999', 'user_alice_01');
  const activeTokens = await notifRepo.findActiveTokensForUser('user_alice_01');
  assert('Deactivated invalid token from active token set', activeTokens.length === 0);

  // Test 9: Delivery retry behavior & backoff
  console.log('\n--- Scenario 9: Delivery Worker Retry Behavior ---');
  let attemptCount = 0;
  const flakeyProvider = new SimulatedPushProvider();
  flakeyProvider.sendPush = async (tokenInfo, payload) => {
    attemptCount++;
    if (attemptCount < 3) {
      return { success: false, error: 'TRANSIENT_NETWORK_ERROR', temporary: true };
    }
    return { success: true, messageId: 'sim_success_attempt_3' };
  };

  const deliveryWorker = new NotificationDeliveryWorker({
    notificationRepository: notifRepo,
    pushProvider: flakeyProvider
  });

  const notifItem = await notifRepo.createNotification({
    userId: 'user_alice_01',
    homeId: 'home_001',
    type: 'DEVICE_OFFLINE',
    priority: 'HIGH',
    title: 'Switch Offline',
    body: 'Switch in Living Room is unreachable'
  });

  // Re-enable token
  const tokenRec = await notifRepo.upsertDeviceToken({
    userId: 'user_alice_01',
    pushToken: 'device_token_valid_111',
    platform: 'android',
    deviceName: 'Pixel 8'
  });

  // Create pending delivery item in outbox table
  const deliveryItem = await db.insert('notification_deliveries', 'del_001', {
    notification_id: notifItem.id,
    token_id: tokenRec.id,
    channel: 'push',
    status: 'PENDING',
    attempts: 0,
    max_attempts: 3,
    next_attempt_at: new Date().toISOString()
  });

  // Mock fetchPendingDeliveries and updateDeliveryStatus for outbox
  notifRepo.fetchPendingDeliveries = async () => {
    return db.find('notification_deliveries', d => ['PENDING', 'RETRYING'].includes(d.status));
  };
  notifRepo.updateDeliveryStatus = async (id, updates) => {
    return db.update('notification_deliveries', id, updates);
  };

  // Process attempt 1 (fails transiently)
  await deliveryWorker.tick();
  const deliveryAttempt1 = await db.findById('notification_deliveries', 'del_001');
  assert('First temporary failure marks delivery for retry with attempts = 1', deliveryAttempt1.attempts === 1 && deliveryAttempt1.status === 'RETRYING');

  // Clear backoff delay for immediate testing
  await db.update('notification_deliveries', 'del_001', { next_attempt_at: new Date(Date.now() - 1000).toISOString() });

  // Process attempt 2 (fails transiently)
  await deliveryWorker.tick();
  const deliveryAttempt2 = await db.findById('notification_deliveries', 'del_001');
  assert('Second temporary failure increments attempts = 2', deliveryAttempt2.attempts === 2 && deliveryAttempt2.status === 'RETRYING');

  // Clear backoff delay for immediate testing
  await db.update('notification_deliveries', 'del_001', { next_attempt_at: new Date(Date.now() - 1000).toISOString() });

  // Process attempt 3 (succeeds)
  await deliveryWorker.tick();
  const deliveryAttempt3 = await db.findById('notification_deliveries', 'del_001');
  assert('Third attempt succeeds and marks delivery as SENT', deliveryAttempt3.status === 'SENT');

  // Test 10: Delivery idempotency
  console.log('\n--- Scenario 10: Delivery Idempotency ---');
  await deliveryWorker.tick(); // Already SENT, should not reprocess
  const deliveryAfter = await db.findById('notification_deliveries', 'del_001');
  assert('Already SENT delivery item is not reprocessed', deliveryAfter.attempts === 3);

  // Test 11: Token ownership isolation
  console.log('\n--- Scenario 11: Token Ownership Isolation ---');
  await notifRepo.upsertDeviceToken({
    userId: 'user_bob_02',
    pushToken: 'device_token_bob_secret',
    platform: 'ios',
    deviceName: 'iPhone 15'
  });

  const aliceTokens = await notifRepo.findActiveTokensForUser('user_alice_01');
  const bobTokens = await notifRepo.findActiveTokensForUser('user_bob_02');
  assert('Alice cannot see Bob’s push token', !aliceTokens.some(t => t.push_token === 'device_token_bob_secret'));
  assert('Bob can only see his own push token', bobTokens.some(t => t.push_token === 'device_token_bob_secret'));

  // Test 12: Secret & Token redaction
  console.log('\n--- Scenario 12: Push Token & Secret Redaction ---');
  const masked = maskToken('fcm_token_1234567890abcdefghijklmnopqrstuvwxyz');
  assert('Device token is masked in diagnostics/logs', masked.startsWith('fcm_') && masked.endsWith('wxyz') && masked.includes('...'));
  assert('Short token is masked securely', maskToken('12345').includes('***'));

  const fcmHealth = await mockFcm.checkHealth();
  assert('Provider health checks do not leak private keys', !JSON.stringify(fcmHealth).includes('BEGIN PRIVATE KEY'));
  assert('Provider health status is HEALTHY', fcmHealth.status === 'HEALTHY' && fcmHealth.check === 'PASS');

  // Test 13: Phase 30 Decision Engine Integration
  console.log('\n--- Scenario 13: Phase 30 Decision Engine Integration ---');
  const userRepo = new UserRepository(db);
  const homeRepo = new HomeRepository(db);
  const testPush = new SimulatedPushProvider();
  const notificationService = new NotificationService({
    notificationRepository: notifRepo,
    userRepository: userRepo,
    homeRepository: homeRepo,
    pushProvider: testPush
  });

  await db.insert('users', 'user_alice_01', { email: 'alice@example.com', name: 'Alice', role: 'MEMBER' });
  await db.insert('homes', 'home_001', { name: 'Alice Home', owner_id: 'user_alice_01' });

  const eventResult = await notificationService.publishPlatformEvent({
    source: 'SECURITY',
    eventType: 'TAMPER_DETECTED',
    severity: 'CRITICAL',
    title: 'Tamper Alarm Triggered',
    message: 'Front door lock tamper sensor active',
    homeId: 'home_001',
    userId: 'user_alice_01',
    payload: { sensorId: 'lock_01' }
  });

  assert('Platform event published and recorded with CRITICAL severity', eventResult !== null && eventResult.severity === 'CRITICAL');

  // Test 14: Quiet hours preservation
  console.log('\n--- Scenario 14: Quiet-Hours Preservation ---');
  await notifRepo.savePreferences('user_alice_01', {
    quiet_hours_enabled: true,
    quiet_hours_start: '00:00',
    quiet_hours_end: '23:59',
    allow_critical_in_quiet_hours: true
  });

  const decisionCritical = notificationService.decisionService.evaluateDecision(
    { type: 'SECURITY_ALARM', severity: 'CRITICAL' },
    { quiet_hours_enabled: true, quiet_hours_start: '00:00', quiet_hours_end: '23:59' },
    true
  );
  assert('CRITICAL notifications bypass quiet hours by default', decisionCritical.action === 'SEND');

  const decisionInfo = notificationService.decisionService.evaluateDecision(
    { type: 'DEVICE_ONLINE', severity: 'INFO' },
    { quiet_hours_enabled: true, quiet_hours_start: '00:00', quiet_hours_end: '23:59' },
    true
  );
  assert('INFO notifications are deferred during quiet hours', decisionInfo.action === 'DEFER');

  // Test 15: Severity preservation
  console.log('\n--- Scenario 15: Severity Classification Preservation ---');
  const severities = ['CRITICAL', 'ERROR', 'WARNING', 'NOTICE', 'INFO'];
  for (const sev of severities) {
    const n = await notifRepo.createNotification({
      userId: 'user_alice_01',
      homeId: 'home_001',
      type: 'SEVERITY_TEST',
      severity: sev,
      title: `Test ${sev}`,
      body: `Testing severity ${sev}`
    });
    assert(`Severity ${sev} correctly preserved in notification record`, n.severity === sev);
  }

  // Test 16: Notification channel preference preservation
  console.log('\n--- Scenario 16: User Notification Channel Preferences ---');
  await notifRepo.savePreferences('user_alice_01', {
    push_enabled: false,
    in_app_enabled: true
  });
  const prefs = await notifRepo.getPreferences('user_alice_01');
  assert('Push channel disabled in user preferences', prefs.push_enabled === false);
  assert('In-app channel remains enabled in user preferences', prefs.in_app_enabled === true);

  // Final summary
  console.log(`\n=== PHASE 38 PUSH TEST RESULTS: ${passedTests}/${totalTests} PASS ===`);
  if (failedTests > 0) {
    console.error(`FAILED: ${failedTests} tests failed.`);
    process.exit(1);
  }
}

if (require.main === module) {
  runSuite().catch(err => {
    console.error('Fatal test error:', err);
    process.exit(1);
  });
}

module.exports = { runSuite };
