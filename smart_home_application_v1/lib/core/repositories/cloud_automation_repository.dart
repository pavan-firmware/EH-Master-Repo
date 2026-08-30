import '../api/api_client.dart';
import '../models/automation_models.dart';

abstract class AutomationRepository {
  Future<List<SceneModel>> getScenes(String homeId);
  Future<SceneModel?> createScene(String homeId, SceneModel scene);
  Future<SceneModel?> updateScene(String homeId, SceneModel scene);
  Future<bool> deleteScene(String homeId, String sceneId);
  Future<Map<String, dynamic>?> runScene(String homeId, String sceneId);

  Future<List<AutomationRuleModel>> getAutomations(String homeId);
  Future<AutomationRuleModel?> createAutomation(
    String homeId,
    AutomationRuleModel automation,
  );
  Future<AutomationRuleModel?> updateAutomation(
    String homeId,
    AutomationRuleModel automation,
  );
  Future<bool> toggleAutomation(
    String homeId,
    String automationId,
    bool isEnabled,
  );
  Future<bool> deleteAutomation(String homeId, String automationId);
  Future<Map<String, dynamic>?> runAutomation(
    String homeId,
    String automationId,
  );

  Future<List<ScheduleModel>> getSchedules(String homeId);
  Future<ScheduleModel?> createSchedule(String homeId, ScheduleModel schedule);
  Future<ScheduleModel?> updateSchedule(String homeId, ScheduleModel schedule);
  Future<bool> toggleSchedule(String homeId, String scheduleId, bool isEnabled);
  Future<bool> deleteSchedule(String homeId, String scheduleId);

  Future<List<AutomationExecutionLogModel>> getExecutionHistory(
    String homeId, {
    String? automationId,
    int limit = 50,
  });
}

class CloudAutomationRepository implements AutomationRepository {
  final ApiClient _apiClient;

  CloudAutomationRepository(this._apiClient);

  @override
  Future<List<SceneModel>> getScenes(String homeId) async {
    final response = await _apiClient.get('/api/v1/homes/$homeId/scenes');
    if (response == null || response['data'] == null) return [];
    final list = response['data'] as List;
    return list
        .map((item) => SceneModel.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<SceneModel?> createScene(String homeId, SceneModel scene) async {
    final response = await _apiClient.post(
      '/api/v1/homes/$homeId/scenes',
      body: scene.toJson(),
    );
    if (response == null || response['data'] == null) return null;
    return SceneModel.fromJson(response['data'] as Map<String, dynamic>);
  }

  @override
  Future<SceneModel?> updateScene(String homeId, SceneModel scene) async {
    final response = await _apiClient.put(
      '/api/v1/homes/$homeId/scenes/${scene.id}',
      body: scene.toJson(),
    );
    if (response == null || response['data'] == null) return null;
    return SceneModel.fromJson(response['data'] as Map<String, dynamic>);
  }

  @override
  Future<bool> deleteScene(String homeId, String sceneId) async {
    final response = await _apiClient.delete(
      '/api/v1/homes/$homeId/scenes/$sceneId',
    );
    return response != null;
  }

  @override
  Future<Map<String, dynamic>?> runScene(String homeId, String sceneId) async {
    final response = await _apiClient.post(
      '/api/v1/homes/$homeId/scenes/$sceneId/run',
      body: {},
    );
    if (response == null || response['data'] == null) return null;
    return response['data'] as Map<String, dynamic>;
  }

  @override
  Future<List<AutomationRuleModel>> getAutomations(String homeId) async {
    final response = await _apiClient.get('/api/v1/homes/$homeId/automations');
    if (response == null || response['data'] == null) return [];
    final list = response['data'] as List;
    return list
        .map(
          (item) => AutomationRuleModel.fromJson(item as Map<String, dynamic>),
        )
        .toList();
  }

  @override
  Future<AutomationRuleModel?> createAutomation(
    String homeId,
    AutomationRuleModel automation,
  ) async {
    final response = await _apiClient.post(
      '/api/v1/homes/$homeId/automations',
      body: automation.toJson(),
    );
    if (response == null || response['data'] == null) return null;
    return AutomationRuleModel.fromJson(
      response['data'] as Map<String, dynamic>,
    );
  }

  @override
  Future<AutomationRuleModel?> updateAutomation(
    String homeId,
    AutomationRuleModel automation,
  ) async {
    final response = await _apiClient.put(
      '/api/v1/homes/$homeId/automations/${automation.id}',
      body: automation.toJson(),
    );
    if (response == null || response['data'] == null) return null;
    return AutomationRuleModel.fromJson(
      response['data'] as Map<String, dynamic>,
    );
  }

  @override
  Future<bool> toggleAutomation(
    String homeId,
    String automationId,
    bool isEnabled,
  ) async {
    final response = await _apiClient.post(
      '/api/v1/homes/$homeId/automations/$automationId/toggle',
      body: {'isEnabled': isEnabled},
    );
    return response != null;
  }

  @override
  Future<bool> deleteAutomation(String homeId, String automationId) async {
    final response = await _apiClient.delete(
      '/api/v1/homes/$homeId/automations/$automationId',
    );
    return response != null;
  }

  @override
  Future<Map<String, dynamic>?> runAutomation(
    String homeId,
    String automationId,
  ) async {
    final response = await _apiClient.post(
      '/api/v1/homes/$homeId/automations/$automationId/run',
      body: {},
    );
    if (response == null || response['data'] == null) return null;
    return response['data'] as Map<String, dynamic>;
  }

  @override
  Future<List<ScheduleModel>> getSchedules(String homeId) async {
    final response = await _apiClient.get('/api/v1/homes/$homeId/schedules');
    if (response == null || response['data'] == null) return [];
    final list = response['data'] as List;
    return list
        .map((item) => ScheduleModel.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<ScheduleModel?> createSchedule(
    String homeId,
    ScheduleModel schedule,
  ) async {
    final response = await _apiClient.post(
      '/api/v1/homes/$homeId/schedules',
      body: schedule.toJson(),
    );
    if (response == null || response['data'] == null) return null;
    return ScheduleModel.fromJson(response['data'] as Map<String, dynamic>);
  }

  @override
  Future<ScheduleModel?> updateSchedule(
    String homeId,
    ScheduleModel schedule,
  ) async {
    final response = await _apiClient.put(
      '/api/v1/homes/$homeId/schedules/${schedule.id}',
      body: schedule.toJson(),
    );
    if (response == null || response['data'] == null) return null;
    return ScheduleModel.fromJson(response['data'] as Map<String, dynamic>);
  }

  @override
  Future<bool> toggleSchedule(
    String homeId,
    String scheduleId,
    bool isEnabled,
  ) async {
    final response = await _apiClient.post(
      '/api/v1/homes/$homeId/schedules/$scheduleId/toggle',
      body: {'isEnabled': isEnabled},
    );
    return response != null;
  }

  @override
  Future<bool> deleteSchedule(String homeId, String scheduleId) async {
    final response = await _apiClient.delete(
      '/api/v1/homes/$homeId/schedules/$scheduleId',
    );
    return response != null;
  }

  @override
  Future<List<AutomationExecutionLogModel>> getExecutionHistory(
    String homeId, {
    String? automationId,
    int limit = 50,
  }) async {
    final path = automationId != null
        ? '/api/v1/homes/$homeId/automations/$automationId/history'
        : '/api/v1/homes/$homeId/automation-history';
    final response = await _apiClient.get(path);
    if (response == null || response['data'] == null) return [];
    final list = response['data'] as List;
    return list
        .map(
          (item) => AutomationExecutionLogModel.fromJson(
            item as Map<String, dynamic>,
          ),
        )
        .toList();
  }
}
