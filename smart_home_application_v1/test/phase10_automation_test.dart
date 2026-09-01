import 'package:flutter_test/flutter_test.dart';
import 'package:smart_home_application_v1/core/api/api_client.dart';
import 'package:smart_home_application_v1/core/models/automation_models.dart';
import 'package:smart_home_application_v1/core/repositories/cloud_automation_repository.dart';

class MockApiClient extends ApiClient {
  MockApiClient() : super(baseUrl: 'http://localhost:3000');

  final Map<String, dynamic> responses = {};
  String? lastPath;
  dynamic lastBody;

  @override
  Future<dynamic> get(String path, {Map<String, dynamic>? query}) async {
    lastPath = path;
    return responses[path];
  }

  @override
  Future<dynamic> post(String path, {dynamic body}) async {
    lastPath = path;
    lastBody = body;
    return responses[path] ??
        {
          'data': {'id': 'created_1', ...?body},
        };
  }

  @override
  Future<dynamic> put(String path, {dynamic body}) async {
    lastPath = path;
    lastBody = body;
    return responses[path] ??
        {
          'data': {'id': 'updated_1', ...?body},
        };
  }

  @override
  Future<dynamic> delete(String path, {Map<String, dynamic>? body}) async {
    lastPath = path;
    return {'success': true};
  }
}

void main() {
  group('Phase 10: Automation & Scene Models', () {
    test('SceneModel serialization and deserialization', () {
      final scene = SceneModel(
        id: 'scene_123',
        homeId: 'home_abc',
        name: 'Movie Night',
        description: 'Dim living room lights',
        icon: 'movie',
        isActive: true,
        actions: const [
          AutomationActionModel(
            deviceId: 'dev_sw1',
            channel: 1,
            command: 'set_power',
            parameters: {'channel': 1, 'enabled': false},
            enabled: false,
          ),
          AutomationActionModel(
            deviceId: 'dev_sw1',
            channel: 2,
            command: 'set_power',
            parameters: {'channel': 2, 'enabled': true},
            enabled: true,
          ),
        ],
      );

      final json = scene.toJson();
      expect(json['id'], 'scene_123');
      expect(json['name'], 'Movie Night');
      expect(json['actions'], hasLength(2));

      final restored = SceneModel.fromJson(json);
      expect(restored.id, 'scene_123');
      expect(restored.name, 'Movie Night');
      expect(restored.actions, hasLength(2));
      expect(restored.actions[0].deviceId, 'dev_sw1');
      expect(restored.actions[0].channel, 1);
      expect(restored.actions[0].enabled, false);
      expect(restored.actions[1].channel, 2);
      expect(restored.actions[1].enabled, true);
    });

    test('AutomationRuleModel serialization and deserialization', () {
      final rule = AutomationRuleModel(
        id: 'auto_456',
        homeId: 'home_abc',
        name: 'Nightly Porch Light',
        description: 'Turn on porch at dusk',
        isEnabled: true,
        triggerType: 'time',
        triggerConfig: const {'time': '19:00'},
        conditions: const [
          {'type': 'time_window', 'startTime': '18:00', 'endTime': '23:00'},
        ],
        actions: const [
          AutomationActionModel(
            deviceId: 'dev_sw2',
            channel: 3,
            command: 'set_power',
            enabled: true,
          ),
        ],
        timezone: 'Asia/Kolkata',
      );

      final json = rule.toJson();
      expect(json['id'], 'auto_456');
      expect(json['triggerType'], 'time');
      expect(json['timezone'], 'Asia/Kolkata');

      final restored = AutomationRuleModel.fromJson(json);
      expect(restored.id, 'auto_456');
      expect(restored.name, 'Nightly Porch Light');
      expect(restored.isEnabled, isTrue);
      expect(restored.triggerConfig['time'], '19:00');
      expect(restored.actions, hasLength(1));
      expect(restored.actions[0].deviceId, 'dev_sw2');
    });

    test('ScheduleModel serialization and deserialization', () {
      final schedule = ScheduleModel(
        id: 'sched_789',
        homeId: 'home_abc',
        automationId: 'auto_456',
        name: 'Morning Schedule',
        scheduleType: 'weekly',
        timeOfDay: '06:30',
        daysOfWeek: const [1, 2, 3, 4, 5],
        timezone: 'America/New_York',
        isEnabled: true,
      );

      final json = schedule.toJson();
      expect(json['id'], 'sched_789');
      expect(json['timeOfDay'], '06:30');
      expect(json['daysOfWeek'], [1, 2, 3, 4, 5]);

      final restored = ScheduleModel.fromJson(json);
      expect(restored.id, 'sched_789');
      expect(restored.scheduleType, 'weekly');
      expect(restored.daysOfWeek, [1, 2, 3, 4, 5]);
    });

    test('AutomationExecutionLogModel deserialization', () {
      final json = {
        'id': 'log_999',
        'home_id': 'home_abc',
        'automation_id': 'auto_456',
        'trigger_source': 'schedule',
        'status': 'succeeded',
        'execution_identity': 'schedule-sched_789-2026-08-30T10:00:00Z',
        'target_results': [
          {'deviceId': 'dev_sw1', 'channel': 1, 'status': 'succeeded'},
        ],
        'duration_ms': 42,
        'executed_at': '2026-08-30T10:00:00.000Z',
      };

      final log = AutomationExecutionLogModel.fromJson(json);
      expect(log.id, 'log_999');
      expect(log.automationId, 'auto_456');
      expect(log.status, 'succeeded');
      expect(log.durationMs, 42);
      expect(log.targetResults, hasLength(1));
    });
  });

  group('Phase 10: CloudAutomationRepository Operations', () {
    late MockApiClient mockApi;
    late CloudAutomationRepository repo;

    setUp(() {
      mockApi = MockApiClient();
      repo = CloudAutomationRepository(mockApi);
    });

    test('getScenes parses list correctly', () async {
      mockApi.responses['/api/v1/homes/h1/scenes'] = {
        'data': [
          {
            'id': 's1',
            'home_id': 'h1',
            'name': 'Evening Relax',
            'actions': [
              {'deviceId': 'd1', 'channel': 1, 'command': 'set_power'},
            ],
          },
        ],
      };

      final scenes = await repo.getScenes('h1');
      expect(scenes, hasLength(1));
      expect(scenes.first.name, 'Evening Relax');
      expect(scenes.first.actions, hasLength(1));
      expect(mockApi.lastPath, '/api/v1/homes/h1/scenes');
    });

    test('runScene dispatches execution to backend', () async {
      mockApi.responses['/api/v1/homes/h1/scenes/s1/run'] = {
        'data': {
          'success': true,
          'sceneId': 's1',
          'status': 'succeeded',
          'durationMs': 15,
        },
      };

      final result = await repo.runScene('h1', 's1');
      expect(result, isNotNull);
      expect(result!['status'], 'succeeded');
      expect(mockApi.lastPath, '/api/v1/homes/h1/scenes/s1/run');
    });

    test('toggleAutomation sends PATCH/POST toggle', () async {
      mockApi.responses['/api/v1/homes/h1/automations/a1/toggle'] = {
        'data': {'id': 'a1', 'is_enabled': false},
      };

      final success = await repo.toggleAutomation('h1', 'a1', false);
      expect(success, isTrue);
      expect(mockApi.lastPath, '/api/v1/homes/h1/automations/a1/toggle');
      expect(mockApi.lastBody, {'isEnabled': false});
    });

    test('getExecutionHistory fetches home-level logs', () async {
      mockApi.responses['/api/v1/homes/h1/automation-history'] = {
        'data': [
          {
            'id': 'l1',
            'home_id': 'h1',
            'trigger_source': 'manual',
            'status': 'succeeded',
            'execution_identity': 'exec_test_1',
            'executed_at': '2026-08-30T12:00:00Z',
          },
        ],
      };

      final logs = await repo.getExecutionHistory('h1');
      expect(logs, hasLength(1));
      expect(logs.first.id, 'l1');
      expect(logs.first.status, 'succeeded');
    });
  });
}
