import '../models/notification_models.dart';

abstract class NotificationRepository {
  Future<List<NotificationItem>> getNotifications({
    String? homeId,
    NotificationCategory? category,
    int limit = 50,
    int offset = 0,
    bool unreadOnly = false,
  });

  Future<int> getUnreadCount({String? homeId});

  Future<bool> markAsRead(String notificationId);

  Future<int> markAllAsRead({String? homeId});

  Future<Map<String, bool>> getPreferences();

  Future<bool> updatePreferences(Map<String, bool> preferences);

  Future<bool> registerPushToken(
    String token, {
    String platform = 'android',
    String? deviceName,
  });

  Future<bool> removePushToken(String token);
}
