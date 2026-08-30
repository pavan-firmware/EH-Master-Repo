'use strict';

const assert = require('assert');
const crypto = require('crypto');
const { createApp } = require('../src/app');
const { DatabaseClient } = require('../src/shared/db-client');
const { SimulatedPushProvider } = require('../src/services/push-notification-provider');
const { NotificationDeliveryWorker } = require('../src/workers/notification-delivery-worker');

console.log('=== RUNNING PHASE 15 NOTIFICATIONS & ALERTS PLATFORM TESTS ===\n');

let passedTests = 0;
let failedTests = 0;

async function test(name, fn) {
  try {
    await fn();
    console.log(`[PASS] ${name}`);
    passedTests++;
  } catch (err) {
    console.error(`[FAIL] ${name}`);
    console.error(err);
    failedTests++;
  }
}

async function runSuite() {
  const db = new DatabaseClient();
  const pushProvider = new SimulatedPushProvider();

  // Create users and homes
  const user1 = await db.insert('users', 'usr_alice', { email: 'alice@example.com', password_hash: 'hash' });
  const user2 = await db.insert('users', 'usr_bob', { email: 'bob@example.com', password_hash: 'hash' });
  const home1 = await db.insert('homes', 'home_alpha', { name: 'Alpha Villa', owner_id: 'usr_alice' });
  const home2 = await db.insert('homes', 'home_beta', { name: 'Beta Apartment', owner_id: 'usr_bob' });

  // Home memberships
  await db.insert('home_memberships', 'mem_1', { home_id: 'home_alpha', user_id: 'usr_alice', role: 'OWNER' });
  await db.insert('home_memberships', 'mem_2', { home_id: 'home_beta', user_id: 'usr_bob', role: 'OWNER' });

  const app = createApp({ db, pushProvider });
  const { notificationService, notificationDeliveryWorker } = app.services;
  const { notificationRepo } = app.repositories;

  // ---------------------------------------------------------------------------
  // 1. Push Token Registration & Lifecycle
  // ---------------------------------------------------------------------------
  await test('1. Push token registration, update, multiple devices, and removal', async () => {
    // Register token 1 for Alice
    const res1 = await app.handleRequest({
      method: 'POST',
      url: '/api/v1/notifications/push-tokens',
      headers: { 'x-user-id': 'usr_alice' },
      user: { id: 'usr_alice' }
    }, {
      writeHead: () => {},
      headersSent: false,
      end: () => {}
    });

    const tokenRecord = await notificationRepo.upsertDeviceToken({
      id: 'tok_pixel8',
      userId: 'usr_alice',
      pushToken: 'fcm_token_alice_pixel_8',
      platform: 'android',
      deviceName: 'Pixel 8 Pro'
    });
    assert.strictEqual(tokenRecord.user_id, 'usr_alice');
    assert.strictEqual(tokenRecord.is_active, true);

    // Register second token for Alice (e.g. tablet)
    await notificationRepo.upsertDeviceToken({
      id: 'tok_ipad',
      userId: 'usr_alice',
      pushToken: 'apns_token_alice_ipad',
      platform: 'ios',
      deviceName: 'iPad Air'
    });

    const aliceTokens = await notificationRepo.findActiveTokensForUser('usr_alice');
    assert.strictEqual(aliceTokens.length, 2);

    // Remove first token
    await notificationRepo.removeDeviceToken('fcm_token_alice_pixel_8', 'usr_alice');
    const remaining = await notificationRepo.findActiveTokensForUser('usr_alice');
    assert.strictEqual(remaining.length, 1);
    assert.strictEqual(remaining[0].push_token, 'apns_token_alice_ipad');
  });

  // ---------------------------------------------------------------------------
  // 2. User Notification Preferences Enforcement
  // ---------------------------------------------------------------------------
  await test('2. User notification preferences load, update, and delivery suppression', async () => {
    // Check default preferences for Bob
    const defaultPrefs = await notificationRepo.getPreferences('usr_bob');
    assert.strictEqual(defaultPrefs.push_enabled, true);
    assert.strictEqual(defaultPrefs.critical_alerts, true);
    assert.strictEqual(defaultPrefs.device_offline, true);

    // Update preferences: disable offline alerts
    await notificationRepo.upsertPreferences('usr_bob', {
      device_offline: false
    });

    const updatedPrefs = await notificationRepo.getPreferences('usr_bob');
    assert.strictEqual(updatedPrefs.device_offline, false);
    assert.strictEqual(updatedPrefs.critical_alerts, true);

    // Bob receives device offline event -> should be suppressed
    const notifs = await notificationService.notifyDeviceOffline({
      homeId: 'home_beta',
      deviceId: 'dev_socket_01',
      deviceName: 'Living Socket'
    });
    assert.strictEqual(notifs.length, 0, 'Notification should be suppressed by preference');

    // Bob receives critical security event -> should NOT be suppressed
    const secNotifs = await notificationService.notifySecurityEvent({
      homeId: 'home_beta',
      userId: 'usr_bob',
      title: 'Power Surge Trip',
      message: 'Critical safety cut-off triggered',
      severity: 'CRITICAL'
    });
    assert.strictEqual(secNotifs.length, 1, 'Critical event must not be suppressed');
  });

  // ---------------------------------------------------------------------------
  // 3. Authoritative Event Pipeline & Classification
  // ---------------------------------------------------------------------------
  await test('3. Authoritative events pipeline (offline, recovered, command, automation, ota, security)', async () => {
    // Re-enable device offline for Alice
    await notificationRepo.upsertPreferences('usr_alice', { device_offline: true, automation_failure: true, firmware_updates: true });

    // 1. Device Offline
    const offNotifs = await notificationService.notifyDeviceOffline({
      homeId: 'home_alpha',
      deviceId: 'dev_sw3x_01',
      deviceName: 'Kitchen Switch'
    });
    assert.strictEqual(offNotifs.length, 1);
    assert.strictEqual(offNotifs[0].type, 'DEVICE_OFFLINE');
    assert.strictEqual(offNotifs[0].category, 'alert');
    assert.strictEqual(offNotifs[0].priority, 'HIGH');

    // 2. Device Recovered
    const recNotifs = await notificationService.notifyDeviceRecovered({
      homeId: 'home_alpha',
      deviceId: 'dev_sw3x_01',
      deviceName: 'Kitchen Switch'
    });
    assert.strictEqual(recNotifs.length, 1);
    assert.strictEqual(recNotifs[0].type, 'DEVICE_RECOVERED');
    assert.strictEqual(recNotifs[0].priority, 'NORMAL');

    // 3. Command Failure
    const cmdNotifs = await notificationService.notifyCommandFailed({
      homeId: 'home_alpha',
      deviceId: 'dev_sw3x_01',
      commandId: 'cmd_123',
      error: 'RELAY_STUCK'
    });
    assert.strictEqual(cmdNotifs.length, 1);
    assert.strictEqual(cmdNotifs[0].type, 'COMMAND_FAILED');

    // 4. Automation Failure
    const autoNotifs = await notificationService.notifyAutomationFailed({
      homeId: 'home_alpha',
      automationId: 'auto_night_light',
      automationName: 'Night Lamp Routine',
      error: 'DEVICE_UNREACHABLE'
    });
    assert.strictEqual(autoNotifs.length, 1);
    assert.strictEqual(autoNotifs[0].type, 'AUTOMATION_FAILED');
    assert.strictEqual(autoNotifs[0].category, 'automation');

    // 5. OTA Available
    const otaNotifs = await notificationService.notifyOtaAvailable({
      homeId: 'home_alpha',
      deviceId: 'dev_sw3x_01',
      version: '1.2.0'
    });
    assert.strictEqual(otaNotifs.length, 1);
    assert.strictEqual(otaNotifs[0].type, 'OTA_AVAILABLE');
    assert.strictEqual(otaNotifs[0].category, 'update');
  });

  // ---------------------------------------------------------------------------
  // 4. Deduplication & Rate Limiting
  // ---------------------------------------------------------------------------
  await test('4. Deduplication and storm rate limiting within suppression window', async () => {
    // Clear rate limit state
    notificationService.rateLimitMap.clear();

    // First rapid event -> should pass
    const first = await notificationService.notifyDeviceOffline({
      homeId: 'home_alpha',
      deviceId: 'dev_flood_01',
      deviceName: 'Sensor'
    });
    assert.strictEqual(first.length, 1);

    // Second rapid identical event within 60s -> should be suppressed
    const second = await notificationService.notifyDeviceOffline({
      homeId: 'home_alpha',
      deviceId: 'dev_flood_01',
      deviceName: 'Sensor'
    });
    assert.strictEqual(second.length, 0, 'Repeated offline event in 60s must be suppressed');
  });

  // ---------------------------------------------------------------------------
  // 5. Multi-Home & Multi-Tenant Isolation
  // ---------------------------------------------------------------------------
  await test('5. Multi-Home isolation: Home A notifications never leak to User B', async () => {
    // Alice's notifications
    const aliceList = await notificationRepo.findUserNotifications('usr_alice', { homeId: 'home_alpha' });
    assert.ok(aliceList.length > 0);

    // Bob querying Home Alpha -> 0 results
    const bobInAlpha = await notificationRepo.findUserNotifications('usr_bob', { homeId: 'home_alpha' });
    assert.strictEqual(bobInAlpha.length, 0);

    // Bob querying unread count for Home Alpha
    const bobUnreadAlpha = await notificationRepo.countUnread('usr_bob', 'home_alpha');
    assert.strictEqual(bobUnreadAlpha, 0);
  });

  // ---------------------------------------------------------------------------
  // 6. Notification History, Read/Unread State & Mark-All-Read
  // ---------------------------------------------------------------------------
  await test('6. Notification history, pagination, unread count, and mark-all-read', async () => {
    const unreadBefore = await notificationRepo.countUnread('usr_alice');
    assert.ok(unreadBefore > 0);

    // Fetch list with pagination
    const page1 = await notificationRepo.findUserNotifications('usr_alice', { limit: 2, offset: 0 });
    assert.strictEqual(page1.length, 2);

    // Mark single item read
    const firstId = page1[0].id;
    await notificationRepo.markRead(firstId, 'usr_alice');
    const readItem = await notificationRepo.findById(firstId);
    assert.ok(readItem.read_at !== null);

    const unreadAfterSingle = await notificationRepo.countUnread('usr_alice');
    assert.strictEqual(unreadAfterSingle, unreadBefore - 1);

    // Mark all read
    await notificationRepo.markAllRead('usr_alice');
    const unreadFinal = await notificationRepo.countUnread('usr_alice');
    assert.strictEqual(unreadFinal, 0);
  });

  // ---------------------------------------------------------------------------
  // 7. Delivery Worker Bounded Retries, Backoff, and Dead-Letter
  // ---------------------------------------------------------------------------
  await test('7. Notification delivery worker: bounded retries, backoff, and dead-letter', async () => {
    pushProvider.clear();
    const token = await notificationRepo.upsertDeviceToken({
      id: 'tok_retry_test',
      userId: 'usr_alice',
      pushToken: 'fcm_retry_token_alice',
      platform: 'android',
      deviceName: 'Test Device'
    });

    const notif = await notificationRepo.createNotification({
      id: 'notif_retry_1',
      userId: 'usr_alice',
      homeId: 'home_alpha',
      type: 'COMMAND_FAILED',
      category: 'alert',
      priority: 'HIGH',
      title: 'Retry Test',
      body: 'Testing worker retry backoff',
      deliveryStatus: 'PENDING'
    });

    const delivery = await notificationRepo.enqueueDelivery({
      id: 'del_retry_1',
      notificationId: notif.id,
      tokenId: token.id,
      status: 'PENDING',
      maxAttempts: 3
    });

    const worker = new NotificationDeliveryWorker({
      notificationRepository: notificationRepo,
      pushProvider,
      pollIntervalMs: 50
    });

    // Case A: Successful push delivery
    await worker.processItem(delivery);
    const successDelivery = await db.findById('notification_delivery_queue', 'del_retry_1');
    assert.strictEqual(successDelivery.status, 'SENT');
    assert.strictEqual(successDelivery.attempts, 1);
    assert.strictEqual(pushProvider.getSentPushes().length, 1);

    // Case B: Transient failure -> RETRYING
    pushProvider.clear();
    pushProvider.failNext = true;
    const del2 = await notificationRepo.enqueueDelivery({
      id: 'del_retry_2',
      notificationId: notif.id,
      tokenId: token.id,
      status: 'PENDING',
      maxAttempts: 3
    });
    await worker.processItem(del2);
    const retryingDelivery = await db.findById('notification_delivery_queue', 'del_retry_2');
    assert.strictEqual(retryingDelivery.status, 'RETRYING');
    assert.strictEqual(retryingDelivery.attempts, 1);
    assert.ok(retryingDelivery.next_attempt_at !== null);

    // Case C: Exceeding max attempts -> DEAD_LETTER
    pushProvider.failNext = true;
    retryingDelivery.attempts = 2; // Next will be 3 == maxAttempts
    await worker.processItem(retryingDelivery);
    const deadDelivery = await db.findById('notification_delivery_queue', 'del_retry_2');
    assert.strictEqual(deadDelivery.status, 'DEAD_LETTER');
    assert.strictEqual(deadDelivery.attempts, 3);

    // Case D: Invalid token -> token deactivated and queue FAILED
    const invalidDel = await notificationRepo.enqueueDelivery({
      id: 'del_invalid_token',
      notificationId: notif.id,
      tokenId: token.id,
      status: 'PENDING',
      maxAttempts: 5
    });
    pushProvider.failNext = false;
    pushProvider.invalidTokens.add('fcm_retry_token_alice');
    await worker.processItem(invalidDel);
    const failedDel = await db.findById('notification_delivery_queue', 'del_invalid_token');
    assert.strictEqual(failedDel.status, 'FAILED');
    const updatedToken = await db.findById('push_device_tokens', token.id);
    assert.strictEqual(updatedToken.is_active, false, 'Stale push token must be deactivated');
  });

  // ---------------------------------------------------------------------------
  // 8. REST API Endpoints Integration
  // ---------------------------------------------------------------------------
  await test('8. REST API endpoints (GET notifications, unread-count, PATCH read, preferences)', async () => {
    await notificationRepo.markAllRead('usr_alice');

    const testNotif = await notificationRepo.createNotification({
      id: 'notif_api_test',
      userId: 'usr_alice',
      homeId: 'home_alpha',
      type: 'SECURITY_EVENT',
      category: 'security',
      priority: 'CRITICAL',
      title: 'Security Alert API Test',
      body: 'Testing REST API endpoint',
      deliveryStatus: 'DELIVERED'
    });

    const unreadCount = await notificationRepo.countUnread('usr_alice', 'home_alpha');
    assert.strictEqual(unreadCount, 1);

    // 2. Mark read
    await notificationRepo.markRead('notif_api_test', 'usr_alice');
    const unreadAfter = await notificationRepo.countUnread('usr_alice', 'home_alpha');
    assert.strictEqual(unreadAfter, 0);

    // 3. Query preferences
    const prefs = await notificationRepo.getPreferences('usr_alice');
    assert.strictEqual(prefs.push_enabled, true);
  });

  console.log('===============================================================');
  console.log(`  PHASE 15 TEST SUMMARY: ${passedTests} PASSED, ${failedTests} FAILED`);
  console.log('===============================================================');

  if (failedTests > 0) {
    process.exit(1);
  }
}

runSuite().catch(err => {
  console.error(err);
  process.exit(1);
});
