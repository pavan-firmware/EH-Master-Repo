import '../models/notification_models.dart';
import 'notification_repository.dart';

class LocalNotificationRepository implements NotificationRepository {
  LocalNotificationRepository();

  final List<NotificationItem> _items = [
    NotificationItem(
      id: 'notif_1',
      title: 'LAN Backup Mode Active',
      body: 'Your device is communicating directly over local Wi-Fi with <10ms actuation.',
      type: NotificationType.systemEvent,
      category: NotificationCategory.system,
      priority: NotificationPriority.normal,
      severity: NotificationSeverity.info,
      createdAt: DateTime.now().subtract(const Duration(minutes: 5)),
    ),
    NotificationItem(
      id: 'notif_2',
      title: 'Smoke Sensor Normal',
      body: 'All smoke and environment sensors reported clear status in Home.',
      type: NotificationType.securityEvent,
      category: NotificationCategory.security,
      priority: NotificationPriority.normal,
      severity: NotificationSeverity.notice,
      createdAt: DateTime.now().subtract(const Duration(hours: 1)),
      readAt: DateTime.now().subtract(const Duration(minutes: 30)),
    ),
    NotificationItem(
      id: 'notif_3',
      title: 'Firmware v1.0.1 Ready',
      body: 'New optimized low-latency firmware is ready for your smart switch.',
      type: NotificationType.otaAvailable,
      category: NotificationCategory.update,
      priority: NotificationPriority.normal,
      severity: NotificationSeverity.notice,
      createdAt: DateTime.now().subtract(const Duration(hours: 4)),
    ),
  ];

  @override
  Future<List<NotificationItem>> getNotifications({
    String? homeId,
    NotificationCategory? category,
    NotificationSeverity? severity,
    int limit = 50,
    int offset = 0,
    bool unreadOnly = false,
  }) async {
    return _items.where((it) {
      if (unreadOnly && it.isRead) return false;
      if (category != null && category != NotificationCategory.all && it.category != category) return false;
      if (severity != null && it.severity != severity) return false;
      return true;
    }).toList();
  }

  @override
  Future<int> getUnreadCount({String? homeId}) async {
    return _items.where((it) => !it.isRead).length;
  }

  @override
  Future<bool> markAsRead(String notificationId) async {
    final idx = _items.indexWhere((it) => it.id == notificationId);
    if (idx >= 0) {
      _items[idx] = _items[idx].copyWith(readAt: DateTime.now());
      return true;
    }
    return false;
  }

  @override
  Future<int> markAllAsRead({String? homeId}) async {
    int count = 0;
    for (int i = 0; i < _items.length; i++) {
      if (!_items[i].isRead) {
        _items[i] = _items[i].copyWith(readAt: DateTime.now());
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
    return true;
  }

  @override
  Future<Map<String, dynamic>> getPreferences() async {
    return {
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
  }

  @override
  Future<bool> updatePreferences(Map<String, dynamic> preferences) async {
    return true;
  }

  @override
  Future<bool> registerPushToken(
    String token, {
    String platform = 'android',
    String? deviceName,
  }) async {
    return true;
  }

  @override
  Future<bool> removePushToken(String token) async {
    return true;
  }
}
