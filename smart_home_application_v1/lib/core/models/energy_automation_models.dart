// EH Home — Smart Energy Automation & Optimization Models (Phase 20)

enum EnergyMetric {
  instantaneousPower,
  cumulativeEnergy,
  sustainedPower,
  dailyEnergy,
  monthlyEnergy,
  powerSpike,
  costThreshold;

  static EnergyMetric fromString(String? val) {
    if (val == null) return EnergyMetric.instantaneousPower;
    switch (val.toLowerCase()) {
      case 'instantaneous_power':
      case 'instantaneouspower':
        return EnergyMetric.instantaneousPower;
      case 'cumulative_energy':
      case 'cumulativeenergy':
        return EnergyMetric.cumulativeEnergy;
      case 'sustained_power':
      case 'sustainedpower':
        return EnergyMetric.sustainedPower;
      case 'daily_energy':
      case 'dailyenergy':
        return EnergyMetric.dailyEnergy;
      case 'monthly_energy':
      case 'monthlyenergy':
        return EnergyMetric.monthlyEnergy;
      case 'power_spike':
      case 'powerspike':
        return EnergyMetric.powerSpike;
      case 'cost_threshold':
      case 'costthreshold':
        return EnergyMetric.costThreshold;
      default:
        return EnergyMetric.instantaneousPower;
    }
  }

  String toApiString() {
    switch (this) {
      case EnergyMetric.instantaneousPower:
        return 'instantaneous_power';
      case EnergyMetric.cumulativeEnergy:
        return 'cumulative_energy';
      case EnergyMetric.sustainedPower:
        return 'sustained_power';
      case EnergyMetric.dailyEnergy:
        return 'daily_energy';
      case EnergyMetric.monthlyEnergy:
        return 'monthly_energy';
      case EnergyMetric.powerSpike:
        return 'power_spike';
      case EnergyMetric.costThreshold:
        return 'cost_threshold';
    }
  }

  String get displayName {
    switch (this) {
      case EnergyMetric.instantaneousPower:
        return 'Instantaneous Power (W)';
      case EnergyMetric.cumulativeEnergy:
        return 'Cumulative Energy (kWh)';
      case EnergyMetric.sustainedPower:
        return 'Sustained High Power';
      case EnergyMetric.dailyEnergy:
        return 'Daily Energy Budget (kWh)';
      case EnergyMetric.monthlyEnergy:
        return 'Monthly Energy Budget (kWh)';
      case EnergyMetric.powerSpike:
        return 'Power Spike Detection';
      case EnergyMetric.costThreshold:
        return 'Cost Threshold';
    }
  }

  String get defaultUnit {
    switch (this) {
      case EnergyMetric.instantaneousPower:
      case EnergyMetric.sustainedPower:
      case EnergyMetric.powerSpike:
        return 'W';
      case EnergyMetric.cumulativeEnergy:
      case EnergyMetric.dailyEnergy:
      case EnergyMetric.monthlyEnergy:
        return 'kWh';
      case EnergyMetric.costThreshold:
        return 'USD';
    }
  }
}

enum EnergyOperator {
  gt,
  gte,
  lt,
  lte,
  eq;

  static EnergyOperator fromString(String? val) {
    if (val == null) return EnergyOperator.gt;
    switch (val.toUpperCase()) {
      case 'GT':
      case '>':
        return EnergyOperator.gt;
      case 'GTE':
      case '>=':
        return EnergyOperator.gte;
      case 'LT':
      case '<':
        return EnergyOperator.lt;
      case 'LTE':
      case '<=':
        return EnergyOperator.lte;
      case 'EQ':
      case '==':
        return EnergyOperator.eq;
      default:
        return EnergyOperator.gt;
    }
  }

  String toApiString() {
    switch (this) {
      case EnergyOperator.gt:
        return 'GT';
      case EnergyOperator.gte:
        return 'GTE';
      case EnergyOperator.lt:
        return 'LT';
      case EnergyOperator.lte:
        return 'LTE';
      case EnergyOperator.eq:
        return 'EQ';
    }
  }

  String get symbol {
    switch (this) {
      case EnergyOperator.gt:
        return '>';
      case EnergyOperator.gte:
        return '>=';
      case EnergyOperator.lt:
        return '<';
      case EnergyOperator.lte:
        return '<=';
      case EnergyOperator.eq:
        return '==';
    }
  }

  String get displayName {
    switch (this) {
      case EnergyOperator.gt:
        return 'Greater than (>)';
      case EnergyOperator.gte:
        return 'Greater than or equal (>=)';
      case EnergyOperator.lt:
        return 'Less than (<)';
      case EnergyOperator.lte:
        return 'Less than or equal (<=)';
      case EnergyOperator.eq:
        return 'Exactly equals (==)';
    }
  }
}

class TimeWindowModel {
  final String startTime;
  final String endTime;

  const TimeWindowModel({
    required this.startTime,
    required this.endTime,
  });

  factory TimeWindowModel.fromJson(Map<String, dynamic> json) {
    return TimeWindowModel(
      startTime: json['startTime'] ?? json['start_time'] ?? '00:00',
      endTime: json['endTime'] ?? json['end_time'] ?? '23:59',
    );
  }

  Map<String, dynamic> toJson() => {
    'startTime': startTime,
    'endTime': endTime,
  };
}

class EnergyConditionModel {
  final String type;
  final EnergyMetric metric;
  final EnergyOperator operator;
  final double threshold;
  final String unit;
  final int? durationSeconds;
  final TimeWindowModel? timeWindow;
  final String? deviceId;
  final String? roomId;
  final String? homeId;

  const EnergyConditionModel({
    this.type = 'energy_condition',
    required this.metric,
    required this.operator,
    required this.threshold,
    this.unit = 'W',
    this.durationSeconds,
    this.timeWindow,
    this.deviceId,
    this.roomId,
    this.homeId,
  });

  factory EnergyConditionModel.fromJson(Map<String, dynamic> json) {
    return EnergyConditionModel(
      type: json['type'] ?? 'energy_condition',
      metric: EnergyMetric.fromString(json['metric']),
      operator: EnergyOperator.fromString(json['operator']),
      threshold: (json['threshold'] as num?)?.toDouble() ?? 0.0,
      unit: json['unit'] ?? 'W',
      durationSeconds: json['durationSeconds'] ?? json['duration_seconds'],
      timeWindow: json['timeWindow'] != null
          ? TimeWindowModel.fromJson(Map<String, dynamic>.from(json['timeWindow']))
          : (json['time_window'] != null
              ? TimeWindowModel.fromJson(Map<String, dynamic>.from(json['time_window']))
              : null),
      deviceId: json['deviceId'] ?? json['device_id'],
      roomId: json['roomId'] ?? json['room_id'],
      homeId: json['homeId'] ?? json['home_id'],
    );
  }

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'type': type,
      'metric': metric.toApiString(),
      'operator': operator.toApiString(),
      'threshold': threshold,
      'unit': unit,
    };
    if (durationSeconds != null) map['durationSeconds'] = durationSeconds;
    if (timeWindow != null) map['timeWindow'] = timeWindow!.toJson();
    if (deviceId != null) map['deviceId'] = deviceId;
    if (roomId != null) map['roomId'] = roomId;
    if (homeId != null) map['homeId'] = homeId;
    return map;
  }
}

class EnergyHysteresisConfigModel {
  final double? recoveryThreshold;
  final int cooldownSeconds;

  const EnergyHysteresisConfigModel({
    this.recoveryThreshold,
    this.cooldownSeconds = 60,
  });

  factory EnergyHysteresisConfigModel.fromJson(Map<String, dynamic> json) {
    return EnergyHysteresisConfigModel(
      recoveryThreshold: (json['recoveryThreshold'] ?? json['recovery_threshold'] as num?)?.toDouble(),
      cooldownSeconds: json['cooldownSeconds'] ?? json['cooldown_seconds'] ?? 60,
    );
  }

  Map<String, dynamic> toJson() => {
    if (recoveryThreshold != null) 'recoveryThreshold': recoveryThreshold,
    'cooldownSeconds': cooldownSeconds,
  };
}

class EnergyActionModel {
  final String actionType;
  final String? deviceId;
  final int? channelIndex;
  final String? command;
  final Map<String, dynamic>? params;
  final String? sceneId;
  final int? delaySeconds;

  const EnergyActionModel({
    required this.actionType,
    this.deviceId,
    this.channelIndex,
    this.command,
    this.params,
    this.sceneId,
    this.delaySeconds,
  });

  factory EnergyActionModel.fromJson(Map<String, dynamic> json) {
    return EnergyActionModel(
      actionType: json['actionType'] ?? json['action_type'] ?? 'device_command',
      deviceId: json['deviceId'] ?? json['device_id'],
      channelIndex: json['channelIndex'] ?? json['channel_index'],
      command: json['command'],
      params: json['params'] != null ? Map<String, dynamic>.from(json['params']) : null,
      sceneId: json['sceneId'] ?? json['scene_id'],
      delaySeconds: json['delaySeconds'] ?? json['delay_seconds'],
    );
  }

  Map<String, dynamic> toJson() => {
    'actionType': actionType,
    if (deviceId != null) 'deviceId': deviceId,
    if (channelIndex != null) 'channelIndex': channelIndex,
    if (command != null) 'command': command,
    if (params != null) 'params': params,
    if (sceneId != null) 'sceneId': sceneId,
    if (delaySeconds != null) 'delaySeconds': delaySeconds,
  };
}

class EnergyAutomationRuleModel {
  final String id;
  final String homeId;
  final String name;
  final String? description;
  final bool isEnabled;
  final String triggerType;
  final String scopeType;
  final String? scopeId;
  final List<EnergyConditionModel> conditions;
  final String conditionLogic;
  final EnergyHysteresisConfigModel? hysteresis;
  final int cooldownSeconds;
  final List<EnergyActionModel> actions;
  final DateTime? lastTriggeredAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const EnergyAutomationRuleModel({
    required this.id,
    required this.homeId,
    required this.name,
    this.description,
    this.isEnabled = true,
    this.triggerType = 'energy_threshold',
    this.scopeType = 'home',
    this.scopeId,
    this.conditions = const [],
    this.conditionLogic = 'AND',
    this.hysteresis,
    this.cooldownSeconds = 60,
    this.actions = const [],
    this.lastTriggeredAt,
    this.createdAt,
    this.updatedAt,
  });

  factory EnergyAutomationRuleModel.fromJson(Map<String, dynamic> json) {
    final rawConds = json['conditions'] as List<dynamic>? ?? [];
    final conditions = rawConds
        .map((c) => EnergyConditionModel.fromJson(Map<String, dynamic>.from(c)))
        .toList();

    final rawActions = json['actions'] as List<dynamic>? ?? [];
    final actions = rawActions
        .map((a) => EnergyActionModel.fromJson(Map<String, dynamic>.from(a)))
        .toList();

    return EnergyAutomationRuleModel(
      id: json['id'] ?? '',
      homeId: json['homeId'] ?? json['home_id'] ?? '',
      name: json['name'] ?? 'Energy Rule',
      description: json['description'],
      isEnabled: json['isEnabled'] ?? json['is_enabled'] ?? json['enabled'] ?? true,
      triggerType: json['triggerType'] ?? json['trigger_type'] ?? 'energy_threshold',
      scopeType: json['scopeType'] ?? json['scope_type'] ?? 'home',
      scopeId: json['scopeId'] ?? json['scope_id'],
      conditions: conditions,
      conditionLogic: json['conditionLogic'] ?? json['condition_logic'] ?? 'AND',
      hysteresis: json['hysteresis'] != null
          ? EnergyHysteresisConfigModel.fromJson(Map<String, dynamic>.from(json['hysteresis']))
          : null,
      cooldownSeconds: json['cooldownSeconds'] ?? json['cooldown_seconds'] ?? 60,
      actions: actions,
      lastTriggeredAt: json['lastTriggeredAt'] != null
          ? DateTime.tryParse(json['lastTriggeredAt'])
          : (json['last_triggered_at'] != null ? DateTime.tryParse(json['last_triggered_at']) : null),
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'])
          : (json['created_at'] != null ? DateTime.tryParse(json['created_at']) : null),
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'])
          : (json['updated_at'] != null ? DateTime.tryParse(json['updated_at']) : null),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'homeId': homeId,
    'name': name,
    if (description != null) 'description': description,
    'isEnabled': isEnabled,
    'triggerType': triggerType,
    'scopeType': scopeType,
    if (scopeId != null) 'scopeId': scopeId,
    'conditions': conditions.map((c) => c.toJson()).toList(),
    'conditionLogic': conditionLogic,
    if (hysteresis != null) 'hysteresis': hysteresis!.toJson(),
    'cooldownSeconds': cooldownSeconds,
    'actions': actions.map((a) => a.toJson()).toList(),
  };
}

class EnergyAutomationExecutionModel {
  final String id;
  final String homeId;
  final String? automationId;
  final String scopeType;
  final String? scopeId;
  final String triggerType;
  final String? triggerReason;
  final Map<String, dynamic>? telemetryContext;
  final String status;
  final String? skipReason;
  final String? errorMessage;
  final int durationMs;
  final DateTime createdAt;

  const EnergyAutomationExecutionModel({
    required this.id,
    required this.homeId,
    this.automationId,
    this.scopeType = 'device',
    this.scopeId,
    required this.triggerType,
    this.triggerReason,
    this.telemetryContext,
    required this.status,
    this.skipReason,
    this.errorMessage,
    this.durationMs = 0,
    required this.createdAt,
  });

  factory EnergyAutomationExecutionModel.fromJson(Map<String, dynamic> json) {
    Map<String, dynamic>? telem;
    if (json['telemetry_context'] != null) {
      if (json['telemetry_context'] is String) {
        // May be stored as serialized JSON
        telem = {'raw': json['telemetry_context']};
      } else if (json['telemetry_context'] is Map) {
        telem = Map<String, dynamic>.from(json['telemetry_context']);
      }
    } else if (json['telemetryContext'] is Map) {
      telem = Map<String, dynamic>.from(json['telemetryContext']);
    }

    return EnergyAutomationExecutionModel(
      id: json['id'] ?? '',
      homeId: json['home_id'] ?? json['homeId'] ?? '',
      automationId: json['automation_id'] ?? json['automationId'],
      scopeType: json['scope_type'] ?? json['scopeType'] ?? 'device',
      scopeId: json['scope_id'] ?? json['scopeId'],
      triggerType: json['trigger_type'] ?? json['triggerType'] ?? 'energy',
      triggerReason: json['trigger_reason'] ?? json['triggerReason'],
      telemetryContext: telem,
      status: json['status'] ?? 'unknown',
      skipReason: json['skip_reason'] ?? json['skipReason'],
      errorMessage: json['error_message'] ?? json['errorMessage'],
      durationMs: json['duration_ms'] ?? json['durationMs'] ?? 0,
      createdAt: json['created_at'] != null
          ? (DateTime.tryParse(json['created_at']) ?? DateTime.now())
          : (json['createdAt'] != null ? (DateTime.tryParse(json['createdAt']) ?? DateTime.now()) : DateTime.now()),
    );
  }
}

class EstimatedSavingsModel {
  final double dailyKwh;
  final double monthlyKwh;
  final double dailyCost;
  final double monthlyCost;
  final String currency;
  final double tariffPerKwh;
  final bool isEstimate;

  const EstimatedSavingsModel({
    this.dailyKwh = 0.0,
    this.monthlyKwh = 0.0,
    this.dailyCost = 0.0,
    this.monthlyCost = 0.0,
    this.currency = 'USD',
    this.tariffPerKwh = 0.15,
    this.isEstimate = true,
  });

  factory EstimatedSavingsModel.fromJson(Map<String, dynamic> json) {
    return EstimatedSavingsModel(
      dailyKwh: (json['dailyKwh'] ?? json['daily_kwh'] as num?)?.toDouble() ?? 0.0,
      monthlyKwh: (json['monthlyKwh'] ?? json['monthly_kwh'] as num?)?.toDouble() ?? 0.0,
      dailyCost: (json['dailyCost'] ?? json['daily_cost'] as num?)?.toDouble() ?? 0.0,
      monthlyCost: (json['monthlyCost'] ?? json['monthly_cost'] as num?)?.toDouble() ?? 0.0,
      currency: json['currency'] ?? 'USD',
      tariffPerKwh: (json['tariffPerKwh'] ?? json['tariff_per_kwh'] as num?)?.toDouble() ?? 0.15,
      isEstimate: json['isEstimate'] ?? json['is_estimate'] ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
    'dailyKwh': dailyKwh,
    'monthlyKwh': monthlyKwh,
    'dailyCost': dailyCost,
    'monthlyCost': monthlyCost,
    'currency': currency,
    'tariffPerKwh': tariffPerKwh,
    'isEstimate': isEstimate,
  };
}

class EnergyOptimizationRecommendationModel {
  final String id;
  final String homeId;
  final String? deviceId;
  final String? roomId;
  final String category;
  final String title;
  final String description;
  final String priority;
  final bool isDismissed;
  final EstimatedSavingsModel estimatedSavings;
  final Map<String, dynamic>? suggestedAction;
  final Map<String, dynamic>? evidence;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const EnergyOptimizationRecommendationModel({
    required this.id,
    required this.homeId,
    this.deviceId,
    this.roomId,
    required this.category,
    required this.title,
    required this.description,
    this.priority = 'MEDIUM',
    this.isDismissed = false,
    this.estimatedSavings = const EstimatedSavingsModel(),
    this.suggestedAction,
    this.evidence,
    this.createdAt,
    this.updatedAt,
  });

  factory EnergyOptimizationRecommendationModel.fromJson(Map<String, dynamic> json) {
    return EnergyOptimizationRecommendationModel(
      id: json['id'] ?? '',
      homeId: json['homeId'] ?? json['home_id'] ?? '',
      deviceId: json['deviceId'] ?? json['device_id'],
      roomId: json['roomId'] ?? json['room_id'],
      category: json['category'] ?? 'GENERAL',
      title: json['title'] ?? 'Energy Optimization Opportunity',
      description: json['description'] ?? '',
      priority: json['priority'] ?? 'MEDIUM',
      isDismissed: json['isDismissed'] ?? (json['is_dismissed'] == 1 || json['is_dismissed'] == true),
      estimatedSavings: json['estimatedSavings'] != null
          ? EstimatedSavingsModel.fromJson(Map<String, dynamic>.from(json['estimatedSavings']))
          : (json['estimated_savings'] != null
              ? EstimatedSavingsModel.fromJson(Map<String, dynamic>.from(json['estimated_savings']))
              : const EstimatedSavingsModel()),
      suggestedAction: json['suggestedAction'] != null
          ? Map<String, dynamic>.from(json['suggestedAction'])
          : (json['suggested_action'] != null ? Map<String, dynamic>.from(json['suggested_action']) : null),
      evidence: json['evidence'] != null ? Map<String, dynamic>.from(json['evidence']) : null,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'])
          : (json['created_at'] != null ? DateTime.tryParse(json['created_at']) : null),
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'])
          : (json['updated_at'] != null ? DateTime.tryParse(json['updated_at']) : null),
    );
  }
}

class EnergyOptimizationSummaryModel {
  final double totalMonthlyKwhSavings;
  final double totalMonthlyCostSavings;
  final String currency;
  final int activeCount;
  final int dismissedCount;
  final double tariffPerKwh;
  final bool isEstimate;

  const EnergyOptimizationSummaryModel({
    this.totalMonthlyKwhSavings = 0.0,
    this.totalMonthlyCostSavings = 0.0,
    this.currency = 'USD',
    this.activeCount = 0,
    this.dismissedCount = 0,
    this.tariffPerKwh = 0.15,
    this.isEstimate = true,
  });

  factory EnergyOptimizationSummaryModel.fromJson(Map<String, dynamic> json) {
    return EnergyOptimizationSummaryModel(
      totalMonthlyKwhSavings: (json['totalMonthlyKwhSavings'] ?? json['total_monthly_kwh_savings'] as num?)?.toDouble() ?? 0.0,
      totalMonthlyCostSavings: (json['totalMonthlyCostSavings'] ?? json['total_monthly_cost_savings'] as num?)?.toDouble() ?? 0.0,
      currency: json['currency'] ?? 'USD',
      activeCount: json['activeCount'] ?? json['active_count'] ?? 0,
      dismissedCount: json['dismissedCount'] ?? json['dismissed_count'] ?? 0,
      tariffPerKwh: (json['tariffPerKwh'] ?? json['tariff_per_kwh'] as num?)?.toDouble() ?? 0.15,
      isEstimate: json['isEstimate'] ?? json['is_estimate'] ?? true,
    );
  }
}
