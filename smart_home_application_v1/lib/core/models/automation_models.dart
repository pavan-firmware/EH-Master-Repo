import 'package:flutter/foundation.dart';

/// Target action for a Scene or Automation Rule
@immutable
class AutomationActionModel {
  const AutomationActionModel({
    required this.deviceId,
    this.channel,
    this.command = 'set_power',
    this.parameters = const {},
    this.enabled,
  });

  factory AutomationActionModel.fromJson(Map<String, dynamic> json) {
    return AutomationActionModel(
      deviceId: (json['deviceId'] ?? json['device_id'] ?? '').toString(),
      channel: json['channel'] is int
          ? json['channel'] as int
          : (json['channelIndex'] is int ? json['channelIndex'] as int : null),
      command: (json['command'] ?? json['action'] ?? 'set_power').toString(),
      parameters: json['parameters'] is Map<String, dynamic>
          ? Map<String, dynamic>.from(json['parameters'] as Map)
          : (json['params'] is Map<String, dynamic>
                ? Map<String, dynamic>.from(json['params'] as Map)
                : const {}),
      enabled: json['enabled'] as bool?,
    );
  }

  final String deviceId;
  final int? channel;
  final String command;
  final Map<String, dynamic> parameters;
  final bool? enabled;

  Map<String, dynamic> toJson() => {
    'deviceId': deviceId,
    if (channel != null) 'channel': channel,
    'command': command,
    'parameters': parameters,
    if (enabled != null) 'enabled': enabled,
  };
}

/// Multi-device Scene Definition
@immutable
class SceneModel {
  const SceneModel({
    required this.id,
    required this.homeId,
    required this.name,
    this.description,
    this.icon = 'scene_default',
    this.isActive = false,
    this.actions = const [],
    this.createdAt,
    this.updatedAt,
  });

  factory SceneModel.fromJson(Map<String, dynamic> json) {
    final rawActions = json['actions'];
    final actionList = <AutomationActionModel>[];
    if (rawActions is List) {
      for (final a in rawActions) {
        if (a is Map<String, dynamic>) {
          actionList.add(AutomationActionModel.fromJson(a));
        }
      }
    }

    return SceneModel(
      id: (json['id'] ?? '').toString(),
      homeId: (json['homeId'] ?? json['home_id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      description: json['description']?.toString(),
      icon: (json['icon'] ?? 'scene_default').toString(),
      isActive: json['isActive'] ?? json['is_active'] ?? false,
      actions: actionList,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'].toString())
          : null,
    );
  }

  final String id;
  final String homeId;
  final String name;
  final String? description;
  final String icon;
  final bool isActive;
  final List<AutomationActionModel> actions;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Map<String, dynamic> toJson() => {
    'id': id,
    'homeId': homeId,
    'name': name,
    if (description != null) 'description': description,
    'icon': icon,
    'isActive': isActive,
    'actions': actions.map((a) => a.toJson()).toList(),
  };
}

/// Automation Rule Definition
@immutable
class AutomationRuleModel {
  const AutomationRuleModel({
    required this.id,
    required this.homeId,
    required this.name,
    this.description,
    this.isEnabled = true,
    required this.triggerType,
    this.triggerConfig = const {},
    this.conditions = const [],
    this.actions = const [],
    this.timezone = 'UTC',
    this.createdAt,
    this.updatedAt,
  });

  factory AutomationRuleModel.fromJson(Map<String, dynamic> json) {
    final rawActions = json['actions'];
    final actionList = <AutomationActionModel>[];
    if (rawActions is List) {
      for (final a in rawActions) {
        if (a is Map<String, dynamic>) {
          actionList.add(AutomationActionModel.fromJson(a));
        }
      }
    }

    return AutomationRuleModel(
      id: (json['id'] ?? '').toString(),
      homeId: (json['homeId'] ?? json['home_id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      description: json['description']?.toString(),
      isEnabled: json['isEnabled'] ?? json['is_enabled'] ?? true,
      triggerType: (json['triggerType'] ?? json['trigger_type'] ?? 'schedule')
          .toString(),
      triggerConfig: json['triggerConfig'] is Map<String, dynamic>
          ? Map<String, dynamic>.from(json['triggerConfig'] as Map)
          : (json['trigger_config'] is Map<String, dynamic>
                ? Map<String, dynamic>.from(json['trigger_config'] as Map)
                : const {}),
      conditions: json['conditions'] is List
          ? List.from(json['conditions'] as List)
          : const [],
      actions: actionList,
      timezone: (json['timezone'] ?? 'UTC').toString(),
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'].toString())
          : null,
    );
  }

  final String id;
  final String homeId;
  final String name;
  final String? description;
  final bool isEnabled;
  final String triggerType;
  final Map<String, dynamic> triggerConfig;
  final List<dynamic> conditions;
  final List<AutomationActionModel> actions;
  final String timezone;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Map<String, dynamic> toJson() => {
    'id': id,
    'homeId': homeId,
    'name': name,
    if (description != null) 'description': description,
    'isEnabled': isEnabled,
    'triggerType': triggerType,
    'triggerConfig': triggerConfig,
    'conditions': conditions,
    'actions': actions.map((a) => a.toJson()).toList(),
    'timezone': timezone,
  };
}

/// Time or Recurring Schedule Definition
@immutable
class ScheduleModel {
  const ScheduleModel({
    required this.id,
    required this.homeId,
    this.automationId,
    this.sceneId,
    required this.name,
    this.scheduleType = 'daily',
    this.cronExpression,
    this.timeOfDay = '08:00',
    this.daysOfWeek = const [],
    this.timezone = 'UTC',
    this.isEnabled = true,
    this.nextRunAt,
    this.lastRunAt,
  });

  factory ScheduleModel.fromJson(Map<String, dynamic> json) {
    return ScheduleModel(
      id: (json['id'] ?? '').toString(),
      homeId: (json['homeId'] ?? json['home_id'] ?? '').toString(),
      automationId:
          json['automationId']?.toString() ?? json['automation_id']?.toString(),
      sceneId: json['sceneId']?.toString() ?? json['scene_id']?.toString(),
      name: (json['name'] ?? '').toString(),
      scheduleType: (json['scheduleType'] ?? json['schedule_type'] ?? 'daily')
          .toString(),
      cronExpression:
          json['cronExpression']?.toString() ??
          json['cron_expression']?.toString(),
      timeOfDay: (json['timeOfDay'] ?? json['time_of_day'] ?? '08:00')
          .toString(),
      daysOfWeek: json['daysOfWeek'] is List
          ? List<int>.from(json['daysOfWeek'] as List)
          : (json['days_of_week'] is List
                ? List<int>.from(json['days_of_week'] as List)
                : const []),
      timezone: (json['timezone'] ?? 'UTC').toString(),
      isEnabled: json['isEnabled'] ?? json['is_enabled'] ?? true,
      nextRunAt: json['nextRunAt'] != null || json['next_run_at'] != null
          ? DateTime.tryParse(
              (json['nextRunAt'] ?? json['next_run_at']).toString(),
            )
          : null,
      lastRunAt: json['lastRunAt'] != null || json['last_run_at'] != null
          ? DateTime.tryParse(
              (json['lastRunAt'] ?? json['last_run_at']).toString(),
            )
          : null,
    );
  }

  final String id;
  final String homeId;
  final String? automationId;
  final String? sceneId;
  final String name;
  final String scheduleType;
  final String? cronExpression;
  final String timeOfDay;
  final List<int> daysOfWeek;
  final String timezone;
  final bool isEnabled;
  final DateTime? nextRunAt;
  final DateTime? lastRunAt;

  Map<String, dynamic> toJson() => {
    'id': id,
    'homeId': homeId,
    if (automationId != null) 'automationId': automationId,
    if (sceneId != null) 'sceneId': sceneId,
    'name': name,
    'scheduleType': scheduleType,
    if (cronExpression != null) 'cronExpression': cronExpression,
    'timeOfDay': timeOfDay,
    'daysOfWeek': daysOfWeek,
    'timezone': timezone,
    'isEnabled': isEnabled,
  };
}

/// Execution History Record
@immutable
class AutomationExecutionLogModel {
  const AutomationExecutionLogModel({
    required this.id,
    required this.homeId,
    this.automationId,
    this.sceneId,
    this.scheduleId,
    required this.triggerSource,
    required this.status,
    required this.executionIdentity,
    this.targetResults = const [],
    this.errorMessage,
    this.durationMs = 0,
    required this.executedAt,
  });

  factory AutomationExecutionLogModel.fromJson(Map<String, dynamic> json) {
    return AutomationExecutionLogModel(
      id: (json['id'] ?? '').toString(),
      homeId: (json['homeId'] ?? json['home_id'] ?? '').toString(),
      automationId:
          json['automationId']?.toString() ?? json['automation_id']?.toString(),
      sceneId: json['sceneId']?.toString() ?? json['scene_id']?.toString(),
      scheduleId:
          json['scheduleId']?.toString() ?? json['schedule_id']?.toString(),
      triggerSource:
          (json['triggerSource'] ?? json['trigger_source'] ?? 'manual')
              .toString(),
      status: (json['status'] ?? 'succeeded').toString(),
      executionIdentity:
          (json['executionIdentity'] ?? json['execution_identity'] ?? '')
              .toString(),
      targetResults: json['targetResults'] is List
          ? List<dynamic>.from(json['targetResults'] as List)
          : (json['target_results'] is List
                ? List<dynamic>.from(json['target_results'] as List)
                : const []),
      errorMessage:
          json['errorMessage']?.toString() ?? json['error_message']?.toString(),
      durationMs:
          json['durationMs'] as int? ?? json['duration_ms'] as int? ?? 0,
      executedAt: json['executedAt'] != null || json['executed_at'] != null
          ? DateTime.tryParse(
                  (json['executedAt'] ?? json['executed_at']).toString(),
                ) ??
                DateTime.now()
          : DateTime.now(),
    );
  }

  final String id;
  final String homeId;
  final String? automationId;
  final String? sceneId;
  final String? scheduleId;
  final String triggerSource;
  final String status;
  final String executionIdentity;
  final List<dynamic> targetResults;
  final String? errorMessage;
  final int durationMs;
  final DateTime executedAt;
}
