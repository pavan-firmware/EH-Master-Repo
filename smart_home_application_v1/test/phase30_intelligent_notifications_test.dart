import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_home_application_v1/core/models/notification_models.dart';
import 'package:smart_home_application_v1/core/repositories/notification_repository.dart';
import 'package:smart_home_application_v1/features/notifications/presentation/notification_card.dart';
import 'package:smart_home_application_v1/features/notifications/presentation/notification_center_page.dart';
import 'package:smart_home_application_v1/features/notifications/presentation/notification_badge.dart';
import 'package:smart_home_application_v1/features/settings/presentation/notification_preferences_page.dart';

class MockNotificationRepository implements NotificationRepository {
  MockNotificationRepository({List<NotificationItem>? initialItems}) {
    items = initialItems ?? [];
  }

  late List<NotificationItem> items;
  bool shouldThrow = false;
  Map<String, dynamic> prefs = {
    'pushEnabled': true,
    'emailEnabled': false,
    'inAppEnabled': true,
    'criticalAlerts': true,
    'deviceOffline': true,
    'deviceHealth': true,
    'automationFailure': true,
    'firmwareUpdates': true,
    'energyAlerts': true,
    'securityAlerts': true,
    'matterAlerts': true,
    'memberAlerts': true,
    'quietHoursEnabled': false,
    'quietHoursStart': '22:00',
    'quietHoursEnd': '07:00',
  };
  List<String> registeredTokens = [];
  List<String> actionLogs = [];

  @override
  Future<List<NotificationItem>> getNotifications({
    String? homeId,
    NotificationCategory? category,
    NotificationSeverity? severity,
    int limit = 50,
    int offset = 0,
    bool unreadOnly = false,
  }) async {
    if (shouldThrow) throw Exception('Network error');
    return items.where((n) {
      if (category != null && category != NotificationCategory.all && n.category != category) {
        return false;
      }
      if (severity != null && n.severity != severity) {
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
  Future<bool> performAction(
    String notificationId,
    String actionType, {
    Map<String, dynamic>? payload,
  }) async {
    actionLogs.add('$notificationId:$actionType');
    return true;
  }

  @override
  Future<Map<String, dynamic>> getPreferences() async => Map.from(prefs);

  @override
  Future<bool> updatePreferences(Map<String, dynamic> preferences) async {
    preferences.forEach((k, v) {
      prefs[k] = v;
    });
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
  group('Phase 30 — Intelligent Notifications & Event Center Tests', () {
    // -------------------------------------------------------------------------
    // 1. Serialization & Domain Models
    // -------------------------------------------------------------------------
    test('1. NotificationItem and NotificationPreferences serialization with Phase 30 fields', () {
      final json = {
        'id': 'notif_p30_1',
        'type': 'deviceOffline',
        'category': 'connectivity',
        'priority': 'CRITICAL',
        'severity': 'CRITICAL',
        'title': 'Kitchen Plug Offline',
        'body': 'Device stopped responding after 3 pings',
        'homeId': 'home_alpha',
        'deviceId': 'dev_plug_1',
        'actionType': 'RECONNECT_DEVICE',
        'actionPrimary': 'RECONNECT_DEVICE',
        'actionSecondary': 'MUTE_ALERTS',
        'isAggregated': true,
        'aggregatedCount': 4,
        'aggregatedIds': ['e1', 'e2', 'e3', 'e4'],
        'decisionMetadata': {'policy': 'SAFETY_CRITICAL', 'bypassQuietHours': true},
        'createdAt': '2026-09-04T12:00:00.000Z',
        'readAt': null,
      };

      final item = NotificationItem.fromJson(json);
      expect(item.id, 'notif_p30_1');
      expect(item.severity, NotificationSeverity.critical);
      expect(item.priority, NotificationPriority.critical);
      expect(item.actionPrimary, 'RECONNECT_DEVICE');
      expect(item.actionSecondary, 'MUTE_ALERTS');
      expect(item.isAggregated, true);
      expect(item.aggregatedCount, 4);
      expect(item.aggregatedIds.length, 4);
      expect(item.decisionMetadata['policy'], 'SAFETY_CRITICAL');
      expect(item.isCritical, true);
      expect(item.hasAction, true);

      final encoded = item.toJson();
      expect(encoded['severity'], 'CRITICAL');
      expect(encoded['actionPrimary'], 'RECONNECT_DEVICE');
      expect(encoded['actionSecondary'], 'MUTE_ALERTS');
      expect(encoded['isAggregated'], true);
      expect(encoded['aggregatedCount'], 4);

      // Preferences serialization
      final prefJson = {
        'userId': 'usr_alice',
        'pushEnabled': true,
        'emailEnabled': true,
        'inAppEnabled': true,
        'criticalAlerts': true,
        'deviceOffline': true,
        'deviceHealth': true,
        'automationFailure': true,
        'firmwareUpdates': true,
        'energyAlerts': true,
        'securityAlerts': true,
        'matterAlerts': true,
        'memberAlerts': true,
        'quietHoursEnabled': true,
        'quietHoursStart': '23:00',
        'quietHoursEnd': '06:30',
      };
      final prefs = NotificationPreferences.fromJson(prefJson);
      expect(prefs.quietHoursEnabled, true);
      expect(prefs.quietHoursStart, '23:00');
      expect(prefs.quietHoursEnd, '06:30');
      expect(prefs.energyAlerts, true);
      expect(prefs.matterAlerts, true);

      final prefEncoded = prefs.toJson();
      expect(prefEncoded['quietHoursEnabled'], true);
      expect(prefEncoded['quietHoursStart'], '23:00');
      expect(prefEncoded['quietHoursEnd'], '06:30');
    });

    // -------------------------------------------------------------------------
    // 2. NotificationCard Visual Features (Critical Badge, Aggregation, Actions)
    // -------------------------------------------------------------------------
    testWidgets('2. NotificationCard renders CRITICAL SAFETY ALERT and aggregation pill', (tester) async {
      final criticalAggregatedItem = NotificationItem(
        id: 'notif_crit_agg',
        type: NotificationType.deviceOffline,
        category: NotificationCategory.alert,
        priority: NotificationPriority.critical,
        severity: NotificationSeverity.critical,
        title: 'Multiple Devices Offline',
        body: 'Living room devices disconnected simultaneously',
        actionType: 'RECONNECT_DEVICE',
        actionPrimary: 'RECONNECT_DEVICE',
        isAggregated: true,
        aggregatedCount: 3,
        createdAt: DateTime.now().subtract(const Duration(minutes: 5)),
      );

      NotificationItem? tappedItem;
      NotificationItem? actionedItem;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NotificationCard(
              item: criticalAggregatedItem,
              onTap: () => tappedItem = criticalAggregatedItem,
              onAction: (item) => actionedItem = item,
            ),
          ),
        ),
      );

      // Verify title and body
      expect(find.text('Multiple Devices Offline'), findsOneWidget);
      expect(find.text('Living room devices disconnected simultaneously'), findsOneWidget);

      // Verify CRITICAL SAFETY ALERT banner
      expect(find.text('CRITICAL SAFETY ALERT'), findsOneWidget);

      // Verify aggregation pill (3x)
      expect(find.text('3x'), findsOneWidget);

      // Verify primary action button ('Reconnect Device')
      expect(find.text('Reconnect Device'), findsOneWidget);

      // Tap action button
      await tester.tap(find.text('Reconnect Device'));
      await tester.pump();
      expect(actionedItem?.id, 'notif_crit_agg');

      // Tap card
      await tester.tap(find.byType(NotificationCard));
      await tester.pump();
      expect(tappedItem?.id, 'notif_crit_agg');
    });

    // -------------------------------------------------------------------------
    // 3. NotificationCenterPage Severity Filtering & Tabs
    // -------------------------------------------------------------------------
    testWidgets('3. NotificationCenterPage filters by category and severity', (tester) async {
      final mockItems = [
        NotificationItem(
          id: 'n_crit',
          type: NotificationType.securityAlert,
          category: NotificationCategory.security,
          priority: NotificationPriority.critical,
          severity: NotificationSeverity.critical,
          title: 'Tamper Alarm Triggered',
          body: 'Front door sensor detected physical tamper',
          createdAt: DateTime.now().subtract(const Duration(minutes: 2)),
        ),
        NotificationItem(
          id: 'n_warn',
          type: NotificationType.energyHigh,
          category: NotificationCategory.energy,
          priority: NotificationPriority.high,
          severity: NotificationSeverity.warning,
          title: 'High Energy Spike',
          body: 'Kitchen oven exceeded 3.5 kW threshold',
          createdAt: DateTime.now().subtract(const Duration(minutes: 10)),
        ),
        NotificationItem(
          id: 'n_info',
          type: NotificationType.deviceStateChanged,
          category: NotificationCategory.system,
          priority: NotificationPriority.normal,
          severity: NotificationSeverity.info,
          title: 'Porch Light On',
          body: 'Porch light turned on via routine',
          createdAt: DateTime.now().subtract(const Duration(minutes: 20)),
        ),
      ];

      final repo = MockNotificationRepository(initialItems: mockItems);

      await tester.pumpWidget(
        MaterialApp(
          home: NotificationCenterPage(repository: repo),
        ),
      );
      await tester.pumpAndSettle();

      // Initial state shows all 3
      expect(find.text('Tamper Alarm Triggered'), findsOneWidget);
      expect(find.text('High Energy Spike'), findsOneWidget);
      expect(find.text('Porch Light On'), findsOneWidget);

      // Filter by Energy category chip
      final energyChip = find.text('Energy');
      expect(energyChip, findsOneWidget);
      await tester.tap(energyChip);
      await tester.pumpAndSettle();

      expect(find.text('High Energy Spike'), findsOneWidget);
      expect(find.text('Tamper Alarm Triggered'), findsNothing);
      expect(find.text('Porch Light On'), findsNothing);

      // Reset to All chip
      await tester.tap(find.text('All'));
      await tester.pumpAndSettle();

      expect(find.text('Tamper Alarm Triggered'), findsOneWidget);
      expect(find.text('High Energy Spike'), findsOneWidget);
      expect(find.text('Porch Light On'), findsOneWidget);
    });

    // -------------------------------------------------------------------------
    // 4. NotificationBadge Visual Rendering
    // -------------------------------------------------------------------------
    testWidgets('4. NotificationBadge renders badge count and dot indicator', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: NotificationBadge(
                count: 5,
              ),
            ),
          ),
        ),
      );

      expect(find.text('5'), findsOneWidget);
      expect(find.byIcon(Icons.notifications_outlined), findsOneWidget);

      // Test with 0 unread
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: NotificationBadge(
                count: 0,
              ),
            ),
          ),
        ),
      );

      expect(find.text('0'), findsNothing);
    });

    // -------------------------------------------------------------------------
    // 5. NotificationPreferencesPage Quiet Hours & Channels
    // -------------------------------------------------------------------------
    testWidgets('5. NotificationPreferencesPage renders quiet hours & channel settings', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(
        const MaterialApp(
          home: NotificationPreferencesPage(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Verify headings
      expect(find.text('Notifications'), findsOneWidget);
      expect(find.text('PUSH ALERTS'), findsOneWidget);
      expect(find.text('ALERT CATEGORIES'), findsOneWidget);

      // Verify category items exist
      expect(find.text('Critical safety alerts'), findsOneWidget);
      expect(find.text('Device offline alerts'), findsOneWidget);

      // Scroll to Quiet Hours section
      await tester.scrollUntilVisible(find.text('QUIET HOURS'), 300);
      await tester.pumpAndSettle();

      expect(find.text('QUIET HOURS'), findsOneWidget);
      expect(find.text('Enable quiet hours'), findsOneWidget);
    });
  });
}
