import '../api/api_client.dart';
import '../models/routine_models.dart';

class CloudRoutineRepository implements RoutineRepository {
  final ApiClient _apiClient;
  String? _activeHomeId;

  CloudRoutineRepository(this._apiClient, {String? activeHomeId}) {
    _activeHomeId = activeHomeId;
  }

  void setActiveHomeId(String? homeId) => _activeHomeId = homeId;

  Future<String?> _resolveHomeId() async {
    if (_activeHomeId != null && _activeHomeId!.isNotEmpty) {
      return _activeHomeId;
    }
    try {
      final homes = await _apiClient.get('/api/v1/homes');
      if (homes is List && homes.isNotEmpty) {
        _activeHomeId = homes.first['id']?.toString();
        return _activeHomeId;
      }
    } catch (_) {}
    return null;
  }

  @override
  Future<List<Routine>> getRoutines() async {
    final homeId = await _resolveHomeId();
    if (homeId == null || homeId.isEmpty) return [];

    try {
      final res = await _apiClient.get('/api/v1/homes/$homeId/automations');
      if (res is List) {
        return res.map<Routine>((item) => _mapToRoutine(item as Map<String, dynamic>)).toList();
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  @override
  Future<Routine?> getRoutine(String id) async {
    final homeId = await _resolveHomeId();
    if (homeId == null || homeId.isEmpty) return null;

    try {
      final res = await _apiClient.get('/api/v1/homes/$homeId/automations/$id');
      if (res is Map<String, dynamic>) {
        return _mapToRoutine(res);
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<List<RoutineExecution>> getRecentExecutions(String id) async {
    final homeId = await _resolveHomeId();
    if (homeId == null || homeId.isEmpty) return [];

    try {
      final res = await _apiClient.get('/api/v1/homes/$homeId/automations/$id/history');
      if (res is List) {
        return res.map<RoutineExecution>((e) {
          final map = e as Map<String, dynamic>;
          final startedAt = map['started_at'] != null
              ? DateTime.tryParse(map['started_at'].toString()) ?? DateTime.now()
              : DateTime.now();
          final completedAt = map['completed_at'] != null
              ? DateTime.tryParse(map['completed_at'].toString()) ?? startedAt
              : startedAt;
          final status = (map['status'] ?? 'SUCCESS').toString().toUpperCase();

          return RoutineExecution(
            id: map['id'] ?? 'exec_${DateTime.now().millisecondsSinceEpoch}',
            routineId: id,
            startedAt: startedAt,
            completedAt: completedAt,
            result: status == 'SUCCESS' ? RoutineExecutionResult.succeeded : RoutineExecutionResult.failed,
            message: map['message'] ?? (status == 'SUCCESS' ? 'Routine completed successfully' : 'Routine execution failed'),
          );
        }).toList();
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  @override
  Future<RepositoryResult> createRoutine(RoutineDraft draft) async {
    final homeId = await _resolveHomeId();
    if (homeId == null || homeId.isEmpty) return RepositoryResult.unavailable;

    try {
      final triggerType = _mapTriggerType(draft.trigger?.kind);
      final triggerConfig = <String, dynamic>{
        'time': draft.schedule?.label ?? '08:00',
        if (draft.trigger?.threshold != null) 'threshold': draft.trigger!.threshold,
      };

      final actionsList = draft.actions.map((a) {
        return {
          'deviceId': a.deviceId,
          'action': _mapActionName(a.kind),
          'parameters': {'enabled': true},
        };
      }).toList();

      await _apiClient.post(
        '/api/v1/homes/$homeId/automations',
        body: {
          'name': draft.name.trim(),
          'description': draft.schedule?.label ?? 'Custom Routine',
          'triggerType': triggerType,
          'triggerConfig': triggerConfig,
          'actions': actionsList,
          'isEnabled': true,
        },
      );
      return RepositoryResult.success;
    } catch (e) {
      if (e is ApiException && (e.statusCode == 401 || e.statusCode == 403)) {
        return RepositoryResult.unauthorized;
      }
      return RepositoryResult.failed;
    }
  }

  @override
  Future<RepositoryResult> updateRoutine(String id, RoutineDraft draft) async {
    final homeId = await _resolveHomeId();
    if (homeId == null || homeId.isEmpty) return RepositoryResult.unavailable;

    try {
      await _apiClient.put(
        '/api/v1/homes/$homeId/automations/$id',
        body: {
          'name': draft.name.trim(),
          'description': draft.schedule?.label ?? 'Custom Routine',
        },
      );
      return RepositoryResult.success;
    } catch (e) {
      if (e is ApiException && (e.statusCode == 401 || e.statusCode == 403)) {
        return RepositoryResult.unauthorized;
      }
      return RepositoryResult.failed;
    }
  }

  @override
  Future<RepositoryResult> deleteRoutine(String id) async {
    final homeId = await _resolveHomeId();
    if (homeId == null || homeId.isEmpty) return RepositoryResult.unavailable;

    try {
      await _apiClient.delete('/api/v1/homes/$homeId/automations/$id');
      return RepositoryResult.success;
    } catch (e) {
      if (e is ApiException && (e.statusCode == 401 || e.statusCode == 403)) {
        return RepositoryResult.unauthorized;
      }
      return RepositoryResult.failed;
    }
  }

  @override
  Future<RepositoryResult> enableRoutine(String id) async {
    return _toggleRoutine(id, true);
  }

  @override
  Future<RepositoryResult> disableRoutine(String id) async {
    return _toggleRoutine(id, false);
  }

  Future<RepositoryResult> _toggleRoutine(String id, bool enabled) async {
    final homeId = await _resolveHomeId();
    if (homeId == null || homeId.isEmpty) return RepositoryResult.unavailable;

    try {
      await _apiClient.patch(
        '/api/v1/homes/$homeId/automations/$id/toggle',
        body: {'isEnabled': enabled},
      );
      return RepositoryResult.success;
    } catch (e) {
      if (e is ApiException && (e.statusCode == 401 || e.statusCode == 403)) {
        return RepositoryResult.unauthorized;
      }
      return RepositoryResult.failed;
    }
  }

  @override
  Future<RepositoryResult> executeRoutine(String id) async {
    final homeId = await _resolveHomeId();
    if (homeId == null || homeId.isEmpty) return RepositoryResult.unavailable;

    try {
      await _apiClient.post('/api/v1/homes/$homeId/automations/$id/run');
      return RepositoryResult.success;
    } catch (e) {
      if (e is ApiException && (e.statusCode == 401 || e.statusCode == 403)) {
        return RepositoryResult.unauthorized;
      }
      return RepositoryResult.failed;
    }
  }

  String _mapTriggerType(RoutineTriggerKind? kind) {
    switch (kind) {
      case RoutineTriggerKind.soilMoisture:
        return 'device_state';
      case RoutineTriggerKind.darkness:
        return 'device_state';
      case RoutineTriggerKind.waterLevel:
        return 'device_state';
      default:
        return 'schedule';
    }
  }

  String _mapActionName(RoutineActionKind kind) {
    switch (kind) {
      case RoutineActionKind.mistMaker:
        return 'set_power';
      case RoutineActionKind.light:
        return 'set_light';
      case RoutineActionKind.notification:
        return 'send_notification';
    }
  }

  Routine _mapToRoutine(Map<String, dynamic> map) {
    final id = map['id']?.toString() ?? '';
    final name = map['name']?.toString() ?? 'Routine';
    final isEnabled = (map['isEnabled'] ?? map['is_enabled'] ?? true) == true;
    final createdAt = map['createdAt'] != null
        ? DateTime.tryParse(map['createdAt'].toString()) ?? DateTime.now()
        : DateTime.now();
    final updatedAt = map['updatedAt'] != null
        ? DateTime.tryParse(map['updatedAt'].toString()) ?? createdAt
        : createdAt;

    final triggerType = map['triggerType']?.toString() ?? 'schedule';
    final triggerConfig = map['triggerConfig'] is Map ? map['triggerConfig'] as Map : {};
    final timeStr = triggerConfig['time']?.toString() ?? '08:00';

    return Routine(
      id: id,
      name: name,
      icon: 'auto_awesome',
      isFavorite: false,
      enabled: isEnabled,
      availability: RoutineAvailability.available,
      trigger: RoutineTrigger(
        kind: RoutineTriggerKind.darkness,
        title: 'Trigger: $triggerType',
        detail: 'Scheduled at $timeStr',
      ),
      conditions: const [],
      actions: [
        RoutineAction(
          kind: RoutineActionKind.light,
          title: 'Device Action',
          detail: 'Control channels',
          deviceId: 'all',
        ),
      ],
      schedule: RoutineSchedule(
        label: 'Daily at $timeStr',
        timezone: 'UTC',
        days: const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'],
      ),
      involvedDevices: const [],
      lastExecution: null,
      nextRun: 'Scheduled',
      createdAt: createdAt,
      updatedAt: updatedAt,
      summary: 'Automatic automation for $name',
    );
  }
}
