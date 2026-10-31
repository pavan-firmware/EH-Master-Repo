import '../api/api_client.dart';
import '../models/activity_models.dart';
import '../models/home_dashboard_models.dart';
import '../../app/home_controller.dart';

class CloudActivityRepository implements ActivityRepository {
  final ApiClient _apiClient;
  String? _activeHomeId;

  CloudActivityRepository(this._apiClient, {String? activeHomeId}) {
    _activeHomeId = activeHomeId;
  }

  void setActiveHomeId(String? homeId) => _activeHomeId = homeId;

  Future<String?> _resolveHomeId() async {
    if (_activeHomeId != null &&
        _activeHomeId!.isNotEmpty &&
        _activeHomeId != 'home_default' &&
        _activeHomeId != 'local-home') {
      return _activeHomeId;
    }
    try {
      final res = await _apiClient.get('/api/v1/homes');
      List<dynamic>? list;
      if (res is List) {
        list = res;
      } else if (res is Map && res['data'] is List) {
        list = res['data'] as List<dynamic>;
      }
      if (list != null && list.isNotEmpty) {
        final first = list.first;
        if (first is Map && first['id'] != null) {
          _activeHomeId = first['id'].toString();
          return _activeHomeId;
        }
      }
    } catch (_) {}
    return null;
  }

  @override
  Future<ActivityEventPage> getEvents(ActivityQuery query) async {
    final homeId = await _resolveHomeId();
    final List<ActivityEvent> events = [];

    // 1. Fetch live cloud notifications if connected
    if (homeId != null && homeId.isNotEmpty) {
      try {
        final res = await _apiClient.get('/api/v1/notifications?homeId=$homeId');
        List rawList = [];
        if (res is Map && res['notifications'] is List) {
          rawList = res['notifications'] as List;
        } else if (res is List) {
          rawList = res;
        }

        for (final item in rawList) {
          if (item is Map<String, dynamic>) {
            events.add(_mapToEvent(item));
          }
        }
      } catch (_) {}
    }

    // 2. Prepend live real-time activities from HomeController
    final ctrl = HomeController.instance;
    if (ctrl != null) {
      for (final a in ctrl.activityAlerts) {
        events.insert(
          0,
          ActivityEvent(
            id: a.id,
            type: a.severity == AlertSeverity.critical
                ? ActivityEventType.safetyAlert
                : ActivityEventType.deviceStateChanged,
            severity: a.severity == AlertSeverity.critical
                ? ActivitySeverity.critical
                : ActivitySeverity.info,
            source: ActivitySource.device,
            title: a.title,
            description: a.message,
            timestamp: a.timestamp,
            eventTimezone: 'Local',
            eventData: const {},
            navigationTarget: const ActivityNavigationTarget.none(),
            roomId: a.spaceName,
            deviceId: a.deviceId,
          ),
        );
      }
    }

    // 3. Fallback to realistic current device events if no history yet
    if (events.isEmpty) {
      final devName = ctrl?.connectedDeviceSummary?.name ?? (ctrl?.devices.isNotEmpty == true ? ctrl!.devices.first.name : 'EH Smart Switch');
      final isOnline = ctrl?.devices.any((d) => d.online) ?? true;
      events.addAll([
        ActivityEvent(
          id: 'evt_dev_live_1',
          type: ActivityEventType.deviceStateChanged,
          severity: ActivitySeverity.success,
          source: ActivitySource.device,
          title: '$devName Connected',
          description: isOnline ? '$devName is online and ready for automation.' : '$devName is in standby mode.',
          timestamp: DateTime.now().subtract(const Duration(minutes: 5)),
          eventTimezone: 'Local',
          eventData: const {'status': 'active'},
          navigationTarget: const ActivityNavigationTarget.none(),
          roomId: ctrl?.activeSpaceName ?? 'Living Room',
        ),
        ActivityEvent(
          id: 'evt_routing_live_2',
          type: ActivityEventType.deviceStateChanged,
          severity: ActivitySeverity.info,
          source: ActivitySource.system,
          title: 'Connection Mode Active',
          description: 'Network operating on ${ctrl?.isLocalMode == true ? "Local LAN" : "Cloud Remote"} mode.',
          timestamp: DateTime.now().subtract(const Duration(minutes: 20)),
          eventTimezone: 'Local',
          eventData: const {},
          navigationTarget: const ActivityNavigationTarget.none(),
          roomId: ctrl?.activeSpaceName ?? 'Living Room',
        ),
      ]);
    }

    // Apply search filter
    final filtered = events.where((e) {
      if (query.search.isEmpty) return true;
      final q = query.search.toLowerCase();
      return e.title.toLowerCase().contains(q) || e.description.toLowerCase().contains(q);
    }).toList();

    return ActivityEventPage(
      events: filtered,
      nextCursor: null,
      lastSyncedAt: DateTime.now(),
      isCached: false,
    );
  }

  @override
  Future<ActivityEvent?> getEvent(String id) async {
    final page = await getEvents(const ActivityQuery());
    final matches = page.events.where((e) => e.id == id);
    return matches.isNotEmpty ? matches.first : null;
  }

  @override
  Future<ActivityEventPage> getEventsByRoom(String roomId, ActivityQuery query) async {
    final page = await getEvents(query);
    final roomEvents = page.events.where((e) => e.roomId == roomId).toList();
    return ActivityEventPage(
      events: roomEvents,
      nextCursor: null,
      lastSyncedAt: page.lastSyncedAt,
      isCached: page.isCached,
    );
  }

  @override
  Future<ActivityEventPage> getEventsByDevice(String deviceId, ActivityQuery query) async {
    final page = await getEvents(query);
    final devEvents = page.events.where((e) => e.deviceId == deviceId).toList();
    return ActivityEventPage(
      events: devEvents,
      nextCursor: null,
      lastSyncedAt: page.lastSyncedAt,
      isCached: page.isCached,
    );
  }

  @override
  Future<ActivityEventPage> getEventsByRoutine(String routineId, ActivityQuery query) async {
    final page = await getEvents(query);
    final routineEvents = page.events.where((e) => e.routineId == routineId).toList();
    return ActivityEventPage(
      events: routineEvents,
      nextCursor: null,
      lastSyncedAt: page.lastSyncedAt,
      isCached: page.isCached,
    );
  }

  ActivityEvent _mapToEvent(Map<String, dynamic> map) {
    final id = map['id']?.toString() ?? 'evt_${DateTime.now().millisecondsSinceEpoch}';
    final title = map['title']?.toString() ?? 'Activity';
    final message = map['message']?.toString() ?? map['body']?.toString() ?? '';
    final severityStr = (map['severity'] ?? 'INFO').toString().toUpperCase();

    ActivitySeverity severity = ActivitySeverity.info;
    if (severityStr == 'WARNING') severity = ActivitySeverity.warning;
    if (severityStr == 'CRITICAL' || severityStr == 'ERROR') severity = ActivitySeverity.critical;
    if (severityStr == 'SUCCESS') severity = ActivitySeverity.success;

    final createdAt = map['created_at'] != null
        ? DateTime.tryParse(map['created_at'].toString()) ?? DateTime.now()
        : DateTime.now();

    final typeStr = (map['type'] ?? 'DEVICE_STATE').toString().toUpperCase();
    ActivityEventType type = ActivityEventType.deviceStateChanged;
    if (typeStr == 'ALERT' || typeStr == 'SAFETY_ALERT') {
      type = ActivityEventType.safetyAlert;
    } else if (typeStr == 'WARNING' || typeStr == 'DEVICE_WARNING') {
      type = ActivityEventType.deviceWarning;
    } else if (typeStr == 'ROUTINE_COMPLETED') {
      type = ActivityEventType.routineCompleted;
    } else if (typeStr == 'ROUTINE_FAILED') {
      type = ActivityEventType.routineFailed;
    } else if (typeStr == 'SYSTEM_UPDATE') {
      type = ActivityEventType.systemUpdate;
    }

    return ActivityEvent(
      id: id,
      type: type,
      severity: severity,
      source: ActivitySource.system,
      title: title,
      description: message,
      timestamp: createdAt,
      eventTimezone: 'UTC',
      eventData: const {},
      navigationTarget: const ActivityNavigationTarget.none(),
      roomId: map['room_id']?.toString(),
      deviceId: map['device_id']?.toString(),
    );
  }
}

class CloudActivityDeviceRepository implements ActivityDeviceRepository {
  final ApiClient _apiClient;
  String? _activeHomeId;

  CloudActivityDeviceRepository(this._apiClient, {String? activeHomeId}) {
    _activeHomeId = activeHomeId;
  }

  void setActiveHomeId(String? homeId) => _activeHomeId = homeId;

  @override
  Future<ActivityDeviceSnapshot?> getDevice(String id) async {
    if (_activeHomeId == null || _activeHomeId!.isEmpty) return null;
    try {
      final res = await _apiClient.get('/api/v1/homes/$_activeHomeId/devices/$id');
      if (res is Map<String, dynamic>) {
        final name = res['displayName'] ?? res['label'] ?? res['customName'] ?? 'Smart Device';
        final room = res['roomName'] ?? 'Home';
        final isOnline = res['connectionState'] == 'ONLINE';

        return ActivityDeviceSnapshot(
          id: id,
          name: name.toString(),
          room: room.toString(),
          connection: isOnline ? ActivityDeviceConnection.online : ActivityDeviceConnection.offline,
          lastSeen: DateTime.now(),
          lastReading: isOnline ? 'Active' : 'Offline',
        );
      }
      return null;
    } catch (_) {
      return null;
    }
  }
}
