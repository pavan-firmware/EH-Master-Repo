import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_home_application_v1/core/models/notification_models.dart';
import 'package:smart_home_application_v1/core/repositories/notification_repository.dart';
import 'package:smart_home_application_v1/features/notifications/presentation/notification_center_page.dart';

class MockNotificationRepository implements NotificationRepository {
  MockNotificationRepository({List<NotificationItem>? initialItems}) {
    items = initialItems ?? [];
  }

  late List<NotificationItem> items;
  bool shouldThrow = false;
  Map<String, bool> prefs = {
    'pushEnabled': true,
    'criticalAlerts': true,
    'deviceOffline': true,
    'automationFailure': true,
    'firmwareUpdates': true,
  };
  List<String> registeredTokens = [];

  @override
  Future<List<NotificationItem>> getNotifications({
    String? homeId,
    NotificationCategory? category,
    int limit = 50,
    int offset = 0,
    bool unreadOnly = false,
  }) async {
    if (shouldThrow) throw Exception('Network error');
    return items.where((n) {
      if (category != null && category != NotificationCategory.all && n.category != category) {
        return false;
      }
      if (unreadOnly && n.isRead) return false;
      return true;
    }).toList();
  }

  @override
  Future<int> getUnreadCount({String? homeId}) async {
    if (shouldThrow) throw Exception('Network error');
    return items.where((n) => !n.isRead).length;
  }

  @override
  Future<bool> markAsRead(String notificationId) async {
    final idx = items.indexWhere((n) => n.id == notificationId);
    if (idx >= 0) {
      items[idx] = items[idx].copyWith(readAt: DateTime.now());
      return true;
    }
    return false;
  }

  @override
  Future<int> markAllAsRead({String? homeId}) async {
    final now = DateTime.now();
    int count = 0;
    for (int i = 0; i < items.length; i++) {
      if (!items[i].isRead) {
        items[i] = items[i].copyWith(readAt: now);
        count++;
      }
    }
    return count;
  }

  @override
  Future<Map<String, bool>> getPreferences() async => Map.from(prefs);

  @override
  Future<bool> updatePreferences(Map<String, bool> preferences) async {
    prefs.addAll(preferences);
    return true;
  }

  @override
  Future<bool> registerPushToken(
    String token, {
    String platform = 'android',
    String? deviceName,
  }) async {
    registeredTokens.add(token);
    return true;
  }

  @override
  Future<bool> removePushToken(String token) async {
    registeredTokens.remove(token);
    return true;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  Widget app(Widget child) => MaterialApp(home: child);

  group('Phase 15 — Notifications & Alerts Platform Tests', () {
    test('1. NotificationItem and PushTokenInfo JSON serialization', () {
      final now = DateTime.now();
      final item = NotificationItem(
        id: 'notif_test_1',
        userId: 'usr_alice',
        homeId: 'home_alpha',
        type: NotificationType.deviceOffline,
        category: NotificationCategory.alert,
        priority: NotificationPriority.high,
        title: 'Switch Offline',
        body: 'Living Switch lost power',
        deliveryStatus: 'DELIVERED',
        createdAt: now,
      );

      final json = item.toJson();
      expect(json['id'], 'notif_test_1');
      expect(json['type'], 'DEVICE_OFFLINE');
      expect(json['priority'], 'HIGH');

      final fromJson = NotificationItem.fromJson(json);
      expect(fromJson.id, 'notif_test_1');
      expect(fromJson.type, NotificationType.deviceOffline);
      expect(fromJson.isRead, isFalse);
      expect(fromJson.isCritical, isFalse);

      final pushInfo = PushTokenInfo(
        pushToken: 'fcm_token_123',
        platform: 'android',
        deviceName: 'Pixel 8',
      );
      final pushJson = pushInfo.toJson();
      expect(pushJson['pushToken'], 'fcm_token_123');
      expect(PushTokenInfo.fromJson(pushJson).platform, 'android');
    });

    testWidgets('2. NotificationCenterPage renders notification list, unread badge, and priority chips', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(360, 800));

      final items = [
        NotificationItem(
          id: 'n1',
          type: NotificationType.securityEvent,
          category: NotificationCategory.security,
          priority: NotificationPriority.critical,
          title: 'Power Surge Trip',
          body: 'Breaker tripped on Phase A',
          createdAt: DateTime.now().subtract(const Duration(minutes: 5)),
        ),
        NotificationItem(
          id: 'n2',
          type: NotificationType.deviceOffline,
          category: NotificationCategory.alert,
          priority: NotificationPriority.high,
          title: 'Kitchen Socket Offline',
          body: 'Connection lost at 14:00',
          createdAt: DateTime.now().subtract(const Duration(hours: 1)),
        ),
      ];

      final repo = MockNotificationRepository(initialItems: items);

      await tester.pumpWidget(app(NotificationCenterPage(repository: repo)));
      await tester.pumpAndSettle();

      // Verify list items rendered
      expect(find.text('Notifications'), findsOneWidget);
      expect(find.text('Power Surge Trip'), findsOneWidget);
      expect(find.text('Kitchen Socket Offline'), findsOneWidget);
      expect(find.text('CRITICAL SAFETY ALERT'), findsOneWidget);
      expect(find.text('Mark all read'), findsOneWidget);
    });

    testWidgets('3. Category filter chips filter notifications', (tester) async {
      await tester.binding.setSurfaceSize(const Size(360, 800));

      final items = [
        NotificationItem(
          id: 'n1',
          type: NotificationType.automationFailed,
          category: NotificationCategory.automation,
          priority: NotificationPriority.high,
          title: 'Routine Failed',
          body: 'Morning lights failed',
          createdAt: DateTime.now(),
        ),
        NotificationItem(
          id: 'n2',
          type: NotificationType.otaAvailable,
          category: NotificationCategory.update,
          priority: NotificationPriority.normal,
          title: 'Firmware Update',
          body: 'v1.2.0 available',
          createdAt: DateTime.now(),
        ),
      ];

      final repo = MockNotificationRepository(initialItems: items);

      await tester.pumpWidget(app(NotificationCenterPage(repository: repo)));
      await tester.pumpAndSettle();

      // Tap 'Updates' filter chip
      await tester.ensureVisible(find.text('Updates'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Updates'));
      await tester.pumpAndSettle();

      expect(find.text('Firmware Update'), findsOneWidget);
      expect(find.text('Routine Failed'), findsNothing);
    });

    testWidgets('4. Tapping unread notification marks as read and updates count', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(360, 800));

      final items = [
        NotificationItem(
          id: 'n1',
          type: NotificationType.deviceOffline,
          category: NotificationCategory.alert,
          priority: NotificationPriority.high,
          title: 'Lamp Offline',
          body: 'Device went offline',
          createdAt: DateTime.now(),
        ),
      ];

      final repo = MockNotificationRepository(initialItems: items);

      await tester.pumpWidget(app(NotificationCenterPage(repository: repo)));
      await tester.pumpAndSettle();

      // Verify unread state (Mark all read button visible)
      expect(find.text('Mark all read'), findsOneWidget);

      // Tap item to read
      await tester.tap(find.text('Lamp Offline'));
      await tester.pumpAndSettle();

      expect(repo.items.first.isRead, isTrue);
      expect(find.text('Mark all read'), findsNothing);
    });

    testWidgets('5. Mark all read action marks all unread items', (tester) async {
      await tester.binding.setSurfaceSize(const Size(360, 800));

      final items = [
        NotificationItem(
          id: 'n1',
          type: NotificationType.deviceOffline,
          category: NotificationCategory.alert,
          priority: NotificationPriority.high,
          title: 'Item 1',
          body: 'Body 1',
          createdAt: DateTime.now(),
        ),
        NotificationItem(
          id: 'n2',
          type: NotificationType.commandFailed,
          category: NotificationCategory.alert,
          priority: NotificationPriority.high,
          title: 'Item 2',
          body: 'Body 2',
          createdAt: DateTime.now(),
        ),
      ];

      final repo = MockNotificationRepository(initialItems: items);

      await tester.pumpWidget(app(NotificationCenterPage(repository: repo)));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Mark all read'));
      await tester.pumpAndSettle();

      expect(repo.items.every((n) => n.isRead), isTrue);
      expect(find.text('Mark all read'), findsNothing);
    });

    testWidgets('6. Empty state and Error/Retry states render gracefully', (tester) async {
      await tester.binding.setSurfaceSize(const Size(360, 800));

      // A. Empty state
      final emptyRepo = MockNotificationRepository(initialItems: []);
      await tester.pumpWidget(app(NotificationCenterPage(repository: emptyRepo)));
      await tester.pumpAndSettle();

      expect(find.text('No notifications'), findsOneWidget);
      expect(find.text("You're all caught up with your home alerts."), findsOneWidget);

      // B. Error state
      final errorRepo = MockNotificationRepository(initialItems: []);
      errorRepo.shouldThrow = true;

      await tester.pumpWidget(app(NotificationCenterPage(key: const ValueKey('error_state'), repository: errorRepo)));
      await tester.pumpAndSettle();

      expect(find.text('Failed to load notifications. Please try again.'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);

      // Tap retry with fixed repo
      errorRepo.shouldThrow = false;
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();

      expect(find.text('No notifications'), findsOneWidget);
    });
  });
}
