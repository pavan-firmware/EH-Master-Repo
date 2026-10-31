import '../models/notification_models.dart';
import '../models/routine_models.dart';
import '../../app/home_controller.dart';
import '../models/home_dashboard_models.dart';
import '../services/device_storage_service.dart';
import 'notification_repository.dart';

class LocalNotificationRepository implements NotificationRepository {
  LocalNotificationRepository();

  final List<NotificationItem> _storedItems = [];

  List<NotificationItem> _buildCurrentNotifications() {
    final list = <NotificationItem>[];
    final ctrl = HomeController.instance;
    final deletedIds = DeviceStorageService.deletedNotificationIds;
    final readIds = DeviceStorageService.readNotificationIds;

    // 1. Pull real alerts active in HomeController
    if (ctrl != null) {
      for (final a in ctrl.allSpacesAlerts) {
        final notifId = 'alert_${a.id}';
        if (deletedIds.contains(notifId) || deletedIds.contains(a.id)) {
          continue;
        }
        final isRead = readIds.contains(notifId) || readIds.contains(a.id);
        list.add(
          NotificationItem(
            id: notifId,
            title: a.title,
            body: a.message,
            type: a.severity == AlertSeverity.critical
                ? NotificationType.securityEvent
                : NotificationType.systemEvent,
            category: a.severity == AlertSeverity.critical
                ? NotificationCategory.security
                : NotificationCategory.system,
            priority: a.severity == AlertSeverity.critical
                ? NotificationPriority.high
                : NotificationPriority.normal,
            severity: a.severity == AlertSeverity.critical
                ? NotificationSeverity.critical
                : NotificationSeverity.notice,
            createdAt: a.timestamp,
            readAt: isRead ? DateTime.now() : null,
          ),
        );
      }

      // 2. Add connection status notification if in LAN mode
      if (ctrl.isLocalMode && !deletedIds.contains('lan_active_notice')) {
        final lanId = 'lan_active_notice';
        final isRead = readIds.contains(lanId);
        list.add(
          NotificationItem(
            id: lanId,
            title: 'Local Wi-Fi Mode Active',
            body: 'Your smart devices are operating directly on local network with <10ms response.',
            type: NotificationType.systemEvent,
            category: NotificationCategory.system,
            priority: NotificationPriority.normal,
            severity: NotificationSeverity.info,
            createdAt: DateTime.now().subtract(const Duration(minutes: 2)),
            readAt: isRead ? DateTime.now() : null,
          ),
        );
      }
    }

    // 3. Add routine executions for automations tab with deduplication
    // Real companies deduplicate repeated executions per automation
    final executions = PreviewRoutineRepository.getAllRecentExecutions();
    final seenRoutineIds = <String>{};
    for (final ex in executions) {
      final exId = 'notif_${ex.id}';
      if (deletedIds.contains(exId)) continue;

      // Deduplicate: only show latest execution for each routine to scale cleanly
      if (!seenRoutineIds.add(ex.routineId)) {
        continue;
      }

      final rName = PreviewRoutineRepository.getRoutineNameById(ex.routineId) ?? 'Automation';
      final isRead = readIds.contains(exId);
      list.add(
        NotificationItem(
          id: exId,
          title: 'Routine: $rName',
          body: ex.message,
          type: NotificationType.automationExecuted,
          category: NotificationCategory.automation,
          priority: NotificationPriority.normal,
          severity: ex.result == RoutineExecutionResult.succeeded
              ? NotificationSeverity.info
              : NotificationSeverity.warning,
          createdAt: ex.startedAt,
          readAt: isRead ? DateTime.now() : null,
        ),
      );
    }

    for (final it in _storedItems) {
      if (deletedIds.contains(it.id)) continue;
      if (readIds.contains(it.id)) {
        list.add(it.copyWith(readAt: DateTime.now()));
      } else {
        list.add(it);
      }
    }
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    // Cap local notifications list to 50 items
    if (list.length > 50) {
      return list.sublist(0, 50);
    }
    return list;
  }

  @override
  Future<List<NotificationItem>> getNotifications({
    String? homeId,
    NotificationCategory? category,
    NotificationSeverity? severity,
    int limit = 50,
    int offset = 0,
    bool unreadOnly = false,
  }) async {
    final all = _buildCurrentNotifications();
    return all.where((it) {
      if (unreadOnly && it.isRead) return false;
      if (category != null && category != NotificationCategory.all && it.category != category) return false;
      if (severity != null && it.severity != severity) return false;
      return true;
    }).toList();
  }

  @override
  Future<int> getUnreadCount({String? homeId}) async {
    final all = _buildCurrentNotifications();
    return all.where((it) => !it.isRead).length;
  }

  @override
  Future<bool> markAsRead(String notificationId) async {
    await DeviceStorageService.markNotificationAsRead(notificationId);
    return true;
  }

  @override
  Future<int> markAllAsRead({String? homeId}) async {
    final all = _buildCurrentNotifications();
    final unread = all.where((it) => !it.isRead).map((it) => it.id).toList();
    if (unread.isNotEmpty) {
      await DeviceStorageService.markAllNotificationsAsRead(unread);
    }
    return unread.length;
  }

  @override
  Future<bool> deleteNotification(String notificationId) async {
    await DeviceStorageService.deleteNotificationId(notificationId);
    final ctrl = HomeController.instance;
    if (ctrl != null) {
      if (notificationId.startsWith('alert_')) {
        ctrl.dismissAlert(notificationId.substring(6));
      }
      ctrl.dismissAlert(notificationId);
    }
    return true;
  }

  @override
  Future<int> deleteNotifications(List<String> notificationIds) async {
    if (notificationIds.isEmpty) return 0;
    await DeviceStorageService.deleteNotificationIds(notificationIds);
    final ctrl = HomeController.instance;
    if (ctrl != null) {
      for (final id in notificationIds) {
        if (id.startsWith('alert_')) {
          ctrl.dismissAlert(id.substring(6));
        }
        ctrl.dismissAlert(id);
      }
    }
    return notificationIds.length;
  }

  @override
  Future<int> clearAllNotifications({String? homeId}) async {
    final all = _buildCurrentNotifications();
    final ids = all.map((e) => e.id).toList();
    if (ids.isNotEmpty) {
      await DeviceStorageService.clearAllNotifications(ids);
    }
    final ctrl = HomeController.instance;
    if (ctrl != null) {
      ctrl.clearAllAlerts();
    }
    return ids.length;
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
      'automationFailure': true,
      'firmwareUpdates': true,
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
  }) async => true;

  @override
  Future<bool> removePushToken(String token) async => true;
}
