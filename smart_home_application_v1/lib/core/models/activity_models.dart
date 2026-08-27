import 'package:flutter/foundation.dart';

enum ActivityEventType {
  deviceStateChanged,
  deviceWarning,
  routineCompleted,
  routineFailed,
  userAction,
  systemUpdate,
  connectionChanged,
  safetyAlert,
}

enum ActivitySeverity { info, success, warning, critical }

enum ActivitySource { user, routine, device, system, firmware }

enum ActivityEventStatus { recorded, acknowledged, resolved }

enum ActivityNavigationKind { device, routine, systemUpdate, safetyAlert, none }

class ActivityNavigationTarget {
  const ActivityNavigationTarget({required this.kind, this.id});

  const ActivityNavigationTarget.none()
    : kind = ActivityNavigationKind.none,
      id = null;

  final ActivityNavigationKind kind;
  final String? id;
}

class ActivityEvent {
  const ActivityEvent({
    required this.id,
    required this.type,
    required this.severity,
    required this.source,
    required this.title,
    required this.description,
    required this.timestamp,
    required this.eventTimezone,
    required this.eventData,
    required this.navigationTarget,
    this.roomId,
    this.deviceId,
    this.routineId,
    this.executionId,
    this.eventStatus,
  });

  final String id;
  final ActivityEventType type;
  final ActivitySeverity severity;
  final ActivitySource source;
  final String title;
  final String description;
  final DateTime timestamp;
  final String eventTimezone;
  final Map<String, String> eventData;
  final String? roomId;
  final String? deviceId;
  final String? routineId;
  final String? executionId;
  final ActivityNavigationTarget navigationTarget;
  final ActivityEventStatus? eventStatus;

  bool get isNavigable =>
      navigationTarget.kind != ActivityNavigationKind.none &&
      navigationTarget.id != null;

  String get sourceLabel => switch (source) {
    ActivitySource.user => 'You',
    ActivitySource.routine => 'Routine',
    ActivitySource.device => 'Device',
    ActivitySource.system => 'EH Home',
    ActivitySource.firmware => 'Home device',
  };
}

enum ActivityFilter { all, alerts, devices, routines, system }

enum ActivitySort { recent, oldest }

class ActivityQuery {
  const ActivityQuery({
    this.search = '',
    this.filter = ActivityFilter.all,
    this.sort = ActivitySort.recent,
    this.cursor,
    this.limit = 20,
  });

  final String search;
  final ActivityFilter filter;
  final ActivitySort sort;
  final String? cursor;
  final int limit;
}

class ActivityEventPage {
  const ActivityEventPage({
    required this.events,
    required this.nextCursor,
    required this.lastSyncedAt,
    this.isCached = false,
  });

  final List<ActivityEvent> events;
  final String? nextCursor;
  final DateTime lastSyncedAt;
  final bool isCached;
}

enum ActivityDeviceConnection { online, stale, offline, unavailable }

class ActivityDeviceSnapshot {
  const ActivityDeviceSnapshot({
    required this.id,
    required this.name,
    required this.room,
    required this.connection,
    required this.lastSeen,
    required this.lastReading,
    this.battery,
  });

  final String id;
  final String name;
  final String room;
  final ActivityDeviceConnection connection;
  final DateTime? lastSeen;
  final String lastReading;
  final String? battery;

  String get connectionLabel => switch (connection) {
    ActivityDeviceConnection.online => 'Online',
    ActivityDeviceConnection.stale => 'Stale data',
    ActivityDeviceConnection.offline => 'Offline',
    ActivityDeviceConnection.unavailable => 'Unavailable',
  };
}

abstract interface class ActivityRepository {
  Future<ActivityEventPage> getEvents(ActivityQuery query);
  Future<ActivityEvent?> getEvent(String id);
  Future<ActivityEventPage> getEventsByRoom(String roomId, ActivityQuery query);
  Future<ActivityEventPage> getEventsByDevice(
    String deviceId,
    ActivityQuery query,
  );
  Future<ActivityEventPage> getEventsByRoutine(
    String routineId,
    ActivityQuery query,
  );
}

abstract interface class ActivityDeviceRepository {
  Future<ActivityDeviceSnapshot?> getDevice(String id);
}

class PreviewActivityDeviceRepository implements ActivityDeviceRepository {
  const PreviewActivityDeviceRepository();

  static final _devices = <String, ActivityDeviceSnapshot>{
    'kitchen-air': ActivityDeviceSnapshot(
      id: 'kitchen-air',
      name: 'Kitchen Air Sensor',
      room: 'Kitchen',
      connection: ActivityDeviceConnection.offline,
      lastSeen: DateTime(2026, 8, 14, 18, 35),
      lastReading: 'Unavailable',
      battery: '84%',
    ),
    'mist': ActivityDeviceSnapshot(
      id: 'mist',
      name: 'Mist Maker',
      room: 'Plant Corner',
      connection: ActivityDeviceConnection.offline,
      lastSeen: DateTime(2026, 8, 14, 17, 5),
      lastReading: 'Unavailable',
    ),
    'living-light': ActivityDeviceSnapshot(
      id: 'living-light',
      name: 'Living Room Light',
      room: 'Living Room',
      connection: ActivityDeviceConnection.online,
      lastSeen: DateTime(2026, 8, 14, 16, 29),
      lastReading: 'On',
    ),
    'tank': ActivityDeviceSnapshot(
      id: 'tank',
      name: 'Water Level Sensor',
      room: 'Water Tank',
      connection: ActivityDeviceConnection.online,
      lastSeen: DateTime(2026, 8, 14, 13, 16),
      lastReading: '72%',
    ),
  };

  @override
  Future<ActivityDeviceSnapshot?> getDevice(String id) async => _devices[id];
}

class PreviewActivityRepository implements ActivityRepository {
  const PreviewActivityRepository();

  static final DateTime _now = DateTime.now();
  static final DateTime _yesterday = _now.subtract(const Duration(days: 1));

  static final List<ActivityEvent> _events = [
    ActivityEvent(
      id: 'evt-kitchen-warning',
      type: ActivityEventType.deviceWarning,
      severity: ActivitySeverity.warning,
      source: ActivitySource.device,
      title: 'Kitchen needs attention',
      description: 'Please inspect the air sensor.',
      timestamp: DateTime(_now.year, _now.month, _now.day, 18, 42),
      eventTimezone: 'Home timezone',
      eventData: const {
        'observed': 'Sensor state cannot be confirmed.',
        'reading': 'Unavailable',
        'lastUpdate': '6:35 PM',
      },
      roomId: 'kitchen',
      deviceId: 'kitchen-air',
      navigationTarget: const ActivityNavigationTarget(
        kind: ActivityNavigationKind.device,
        id: 'kitchen-air',
      ),
    ),
    ActivityEvent(
      id: 'evt-plant-completed',
      type: ActivityEventType.routineCompleted,
      severity: ActivitySeverity.success,
      source: ActivitySource.routine,
      title: 'Plant care completed',
      description: 'A short misting session finished.',
      timestamp: DateTime(_now.year, _now.month, _now.day, 17, 10),
      eventTimezone: 'Home timezone',
      eventData: const {
        'observed': 'Soil moisture reached the configured trigger.',
        'action': 'Mist maker ran for 30 seconds.',
        'result': 'Completed successfully',
      },
      roomId: 'plant',
      routineId: 'plant-care',
      executionId: 'activity-run-plant-1',
      navigationTarget: const ActivityNavigationTarget(
        kind: ActivityNavigationKind.routine,
        id: 'plant-care',
      ),
    ),
    ActivityEvent(
      id: 'evt-light-on',
      type: ActivityEventType.userAction,
      severity: ActivitySeverity.info,
      source: ActivitySource.user,
      title: 'Living room light turned on',
      description: 'You turned it on from EH Home.',
      timestamp: DateTime(_now.year, _now.month, _now.day, 16, 28),
      eventTimezone: 'Home timezone',
      eventData: const {'observed': 'Power state changed to On.'},
      roomId: 'living',
      deviceId: 'living-light',
      navigationTarget: const ActivityNavigationTarget(
        kind: ActivityNavigationKind.device,
        id: 'living-light',
      ),
    ),
    ActivityEvent(
      id: 'evt-tank-low',
      type: ActivityEventType.deviceWarning,
      severity: ActivitySeverity.warning,
      source: ActivitySource.device,
      title: 'Water tank level was low',
      description: 'The reported level was 18%.',
      timestamp: DateTime(_now.year, _now.month, _now.day, 13, 15),
      eventTimezone: 'Home timezone',
      eventData: const {
        'observed': 'Water level was 18%.',
        'reading': '18%',
        'updated': '1:15 PM',
      },
      roomId: 'water',
      deviceId: 'tank',
      navigationTarget: const ActivityNavigationTarget(
        kind: ActivityNavigationKind.device,
        id: 'tank',
      ),
    ),
    ActivityEvent(
      id: 'evt-system-update',
      type: ActivityEventType.systemUpdate,
      severity: ActivitySeverity.info,
      source: ActivitySource.system,
      title: 'System update is ready',
      description: 'Choose a convenient time in Settings.',
      timestamp: DateTime(_yesterday.year, _yesterday.month, _yesterday.day, 9),
      eventTimezone: 'Home timezone',
      eventData: const {
        'version': '2.1.0',
        'observed': 'A new EH Home update is available.',
      },
      navigationTarget: const ActivityNavigationTarget(
        kind: ActivityNavigationKind.systemUpdate,
        id: '2.1.0',
      ),
    ),
    ActivityEvent(
      id: 'evt-tank-healthy',
      type: ActivityEventType.deviceStateChanged,
      severity: ActivitySeverity.success,
      source: ActivitySource.device,
      title: 'Water tank level was healthy',
      description: 'The reported level was 72%.',
      timestamp: DateTime(_yesterday.year, _yesterday.month, _yesterday.day, 9),
      eventTimezone: 'Home timezone',
      eventData: const {'reading': '72%', 'observed': 'Level was 72%.'},
      roomId: 'water',
      deviceId: 'tank',
      navigationTarget: const ActivityNavigationTarget(
        kind: ActivityNavigationKind.device,
        id: 'tank',
      ),
    ),
  ];

  @override
  Future<ActivityEventPage> getEvents(ActivityQuery query) async {
    final term = query.search.trim().toLowerCase();
    var filtered = _events.where((event) {
      final matchesSearch = term.isEmpty || _searchText(event).contains(term);
      final matchesFilter = switch (query.filter) {
        ActivityFilter.all => true,
        ActivityFilter.alerts =>
          event.severity == ActivitySeverity.warning ||
              event.severity == ActivitySeverity.critical,
        ActivityFilter.devices => event.source == ActivitySource.device,
        ActivityFilter.routines => event.source == ActivitySource.routine,
        ActivityFilter.system =>
          event.type == ActivityEventType.systemUpdate ||
              event.source == ActivitySource.system ||
              event.source == ActivitySource.firmware,
      };
      return matchesSearch && matchesFilter;
    }).toList();
    filtered.sort(
      (a, b) => query.sort == ActivitySort.recent
          ? b.timestamp.compareTo(a.timestamp)
          : a.timestamp.compareTo(b.timestamp),
    );
    final start = int.tryParse(query.cursor ?? '0') ?? 0;
    final end = (start + query.limit).clamp(0, filtered.length);
    final page = filtered.sublist(start, end);
    return ActivityEventPage(
      events: page,
      nextCursor: end < filtered.length ? '$end' : null,
      lastSyncedAt: DateTime.now(),
    );
  }

  @override
  Future<ActivityEvent?> getEvent(String id) async {
    for (final event in _events) {
      if (event.id == id) return event;
    }
    return null;
  }

  @override
  Future<ActivityEventPage> getEventsByRoom(
    String roomId,
    ActivityQuery query,
  ) => _getBy((event) => event.roomId == roomId, query);

  @override
  Future<ActivityEventPage> getEventsByDevice(
    String deviceId,
    ActivityQuery query,
  ) => _getBy((event) => event.deviceId == deviceId, query);

  @override
  Future<ActivityEventPage> getEventsByRoutine(
    String routineId,
    ActivityQuery query,
  ) => _getBy((event) => event.routineId == routineId, query);

  Future<ActivityEventPage> _getBy(
    bool Function(ActivityEvent event) predicate,
    ActivityQuery query,
  ) async {
    final page = await getEvents(query);
    return ActivityEventPage(
      events: page.events.where(predicate).toList(),
      nextCursor: page.nextCursor,
      lastSyncedAt: page.lastSyncedAt,
      isCached: page.isCached,
    );
  }

  static String _searchText(ActivityEvent event) => [
    event.title,
    event.description,
    event.roomId ?? '',
    event.deviceId ?? '',
    event.routineId ?? '',
    event.sourceLabel,
    ...event.eventData.values,
  ].join(' ').toLowerCase();
}

String activityTimeLabel(DateTime value) {
  final hour = value.hour == 0
      ? 12
      : value.hour > 12
      ? value.hour - 12
      : value.hour;
  final minute = value.minute.toString().padLeft(2, '0');
  return '$hour:$minute ${value.hour >= 12 ? 'PM' : 'AM'}';
}

String activityDateLabel(DateTime value, DateTime now) {
  final date = DateTime(value.year, value.month, value.day);
  final today = DateTime(now.year, now.month, now.day);
  final difference = today.difference(date).inDays;
  if (difference == 0) return 'Today';
  if (difference == 1) return 'Yesterday';
  const weekdays = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];
  if (difference >= 0 && difference < 7) return weekdays[value.weekday - 1];
  return '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';
}

String activityFilterLabel(ActivityFilter filter) => switch (filter) {
  ActivityFilter.all => 'All',
  ActivityFilter.alerts => 'Alerts',
  ActivityFilter.devices => 'Devices',
  ActivityFilter.routines => 'Routines',
  ActivityFilter.system => 'System',
};

@visibleForTesting
List<ActivityEvent> previewActivityEvents() =>
    PreviewActivityRepository._events;
