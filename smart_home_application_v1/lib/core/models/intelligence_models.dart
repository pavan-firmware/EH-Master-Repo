import 'package:flutter/foundation.dart';

enum DecisionPriority {
  safety,
  manualUserAction,
  explicitHomeMode,
  scheduledAutomation,
  energyCostOptimization,
  predictiveOptimization,
  convenienceRecommendation;

  int get rank {
    switch (this) {
      case DecisionPriority.safety:
        return 1;
      case DecisionPriority.manualUserAction:
        return 2;
      case DecisionPriority.explicitHomeMode:
        return 3;
      case DecisionPriority.scheduledAutomation:
        return 4;
      case DecisionPriority.energyCostOptimization:
        return 5;
      case DecisionPriority.predictiveOptimization:
        return 6;
      case DecisionPriority.convenienceRecommendation:
        return 7;
    }
  }

  String toApiValue() {
    switch (this) {
      case DecisionPriority.safety:
        return 'SAFETY';
      case DecisionPriority.manualUserAction:
        return 'MANUAL_USER_ACTION';
      case DecisionPriority.explicitHomeMode:
        return 'EXPLICIT_HOME_MODE';
      case DecisionPriority.scheduledAutomation:
        return 'SCHEDULED_AUTOMATION';
      case DecisionPriority.energyCostOptimization:
        return 'ENERGY_COST_OPTIMIZATION';
      case DecisionPriority.predictiveOptimization:
        return 'PREDICTIVE_OPTIMIZATION';
      case DecisionPriority.convenienceRecommendation:
        return 'CONVENIENCE_RECOMMENDATION';
    }
  }

  static DecisionPriority fromApiValue(String? val) {
    switch (val?.toUpperCase()) {
      case 'SAFETY':
        return DecisionPriority.safety;
      case 'MANUAL_USER_ACTION':
        return DecisionPriority.manualUserAction;
      case 'EXPLICIT_HOME_MODE':
        return DecisionPriority.explicitHomeMode;
      case 'SCHEDULED_AUTOMATION':
        return DecisionPriority.scheduledAutomation;
      case 'ENERGY_COST_OPTIMIZATION':
        return DecisionPriority.energyCostOptimization;
      case 'PREDICTIVE_OPTIMIZATION':
        return DecisionPriority.predictiveOptimization;
      case 'CONVENIENCE_RECOMMENDATION':
      default:
        return DecisionPriority.convenienceRecommendation;
    }
  }
}

enum ConfidenceLevel {
  low,
  medium,
  high;

  String toApiValue() => name.toUpperCase();

  static ConfidenceLevel fromApiValue(String? val) {
    switch (val?.toUpperCase()) {
      case 'HIGH':
        return ConfidenceLevel.high;
      case 'LOW':
        return ConfidenceLevel.low;
      case 'MEDIUM':
      default:
        return ConfidenceLevel.medium;
    }
  }
}

enum RiskLevel {
  low,
  medium,
  high,
  critical;

  String toApiValue() => name.toUpperCase();

  static RiskLevel fromApiValue(String? val) {
    switch (val?.toUpperCase()) {
      case 'CRITICAL':
        return RiskLevel.critical;
      case 'HIGH':
        return RiskLevel.high;
      case 'MEDIUM':
        return RiskLevel.medium;
      case 'LOW':
      default:
        return RiskLevel.low;
    }
  }
}

enum DecisionStatus {
  generated,
  viewed,
  accepted,
  rejected,
  autoExecuted,
  executed,
  failed,
  expired,
  skipped;

  String toApiValue() {
    switch (this) {
      case DecisionStatus.generated:
        return 'GENERATED';
      case DecisionStatus.viewed:
        return 'VIEWED';
      case DecisionStatus.accepted:
        return 'ACCEPTED';
      case DecisionStatus.rejected:
        return 'REJECTED';
      case DecisionStatus.autoExecuted:
        return 'AUTO_EXECUTED';
      case DecisionStatus.executed:
        return 'EXECUTED';
      case DecisionStatus.failed:
        return 'FAILED';
      case DecisionStatus.expired:
        return 'EXPIRED';
      case DecisionStatus.skipped:
        return 'SKIPPED';
    }
  }

  static DecisionStatus fromApiValue(String? val) {
    switch (val?.toUpperCase()) {
      case 'VIEWED':
        return DecisionStatus.viewed;
      case 'ACCEPTED':
        return DecisionStatus.accepted;
      case 'REJECTED':
        return DecisionStatus.rejected;
      case 'AUTO_EXECUTED':
        return DecisionStatus.autoExecuted;
      case 'EXECUTED':
        return DecisionStatus.executed;
      case 'FAILED':
        return DecisionStatus.failed;
      case 'EXPIRED':
        return DecisionStatus.expired;
      case 'SKIPPED':
        return DecisionStatus.skipped;
      case 'GENERATED':
      default:
        return DecisionStatus.generated;
    }
  }
}

enum RecommendationType {
  turnOffUnusedDevice,
  shiftLoadToCheaperPeriod,
  reducePeakLoad,
  investigateAnomaly,
  changeHomeMode,
  optimizeAutomation,
  reduceStandby,
  reviewSchedule,
  reviewTariff;

  String toApiValue() {
    switch (this) {
      case RecommendationType.turnOffUnusedDevice:
        return 'TURN_OFF_UNUSED_DEVICE';
      case RecommendationType.shiftLoadToCheaperPeriod:
        return 'SHIFT_LOAD_TO_CHEAPER_PERIOD';
      case RecommendationType.reducePeakLoad:
        return 'REDUCE_PEAK_LOAD';
      case RecommendationType.investigateAnomaly:
        return 'INVESTIGATE_ANOMALY';
      case RecommendationType.changeHomeMode:
        return 'CHANGE_HOME_MODE';
      case RecommendationType.optimizeAutomation:
        return 'OPTIMIZE_AUTOMATION';
      case RecommendationType.reduceStandby:
        return 'REDUCE_STANDBY';
      case RecommendationType.reviewSchedule:
        return 'REVIEW_SCHEDULE';
      case RecommendationType.reviewTariff:
        return 'REVIEW_TARIFF';
    }
  }

  static RecommendationType fromApiValue(String? val) {
    switch (val?.toUpperCase()) {
      case 'SHIFT_LOAD_TO_CHEAPER_PERIOD':
        return RecommendationType.shiftLoadToCheaperPeriod;
      case 'REDUCE_PEAK_LOAD':
        return RecommendationType.reducePeakLoad;
      case 'INVESTIGATE_ANOMALY':
        return RecommendationType.investigateAnomaly;
      case 'CHANGE_HOME_MODE':
        return RecommendationType.changeHomeMode;
      case 'OPTIMIZE_AUTOMATION':
        return RecommendationType.optimizeAutomation;
      case 'REDUCE_STANDBY':
        return RecommendationType.reduceStandby;
      case 'REVIEW_SCHEDULE':
        return RecommendationType.reviewSchedule;
      case 'REVIEW_TARIFF':
        return RecommendationType.reviewTariff;
      case 'TURN_OFF_UNUSED_DEVICE':
      default:
        return RecommendationType.turnOffUnusedDevice;
    }
  }
}

@immutable
class HomeIntelligenceSnapshot {
  final String homeId;
  final DateTime timestamp;
  final String homeContext;
  final String presenceState;
  final bool isOccupied;
  final double contextConfidence;
  final int deviceCount;
  final int activeDevicesCount;
  final double totalPowerW;
  final String tariffPeriod;
  final double tariffPrice;
  final double forecastPredictedKwh;
  final int activeAnomalyCount;
  final int activeAutomationCount;
  final int activeScheduleCount;
  final List<Map<String, dynamic>> devicesSummary;

  const HomeIntelligenceSnapshot({
    required this.homeId,
    required this.timestamp,
    required this.homeContext,
    required this.presenceState,
    this.isOccupied = true,
    this.contextConfidence = 0.9,
    this.deviceCount = 0,
    this.activeDevicesCount = 0,
    this.totalPowerW = 0.0,
    this.tariffPeriod = 'STANDARD',
    this.tariffPrice = 0.18,
    this.forecastPredictedKwh = 0.0,
    this.activeAnomalyCount = 0,
    this.activeAutomationCount = 0,
    this.activeScheduleCount = 0,
    this.devicesSummary = const [],
  });

  factory HomeIntelligenceSnapshot.fromJson(Map<String, dynamic> json) {
    return HomeIntelligenceSnapshot(
      homeId: json['homeId'] as String? ?? '',
      timestamp: DateTime.tryParse(json['timestamp'] as String? ?? '') ?? DateTime.now(),
      homeContext: json['homeContext'] as String? ?? 'HOME',
      presenceState: json['presenceState'] as String? ?? 'HOME',
      isOccupied: json['isOccupied'] as bool? ?? true,
      contextConfidence: (json['contextConfidence'] as num?)?.toDouble() ?? 0.9,
      deviceCount: json['deviceCount'] as int? ?? 0,
      activeDevicesCount: json['activeDevicesCount'] as int? ?? 0,
      totalPowerW: (json['totalPowerW'] as num?)?.toDouble() ?? 0.0,
      tariffPeriod: json['tariffPeriod'] as String? ?? 'STANDARD',
      tariffPrice: (json['tariffPrice'] as num?)?.toDouble() ?? 0.18,
      forecastPredictedKwh: (json['forecastPredictedKwh'] as num?)?.toDouble() ?? 0.0,
      activeAnomalyCount: json['activeAnomalyCount'] as int? ?? 0,
      activeAutomationCount: json['activeAutomationCount'] as int? ?? 0,
      activeScheduleCount: json['activeScheduleCount'] as int? ?? 0,
      devicesSummary: (json['devicesSummary'] as List<dynamic>?)
              ?.map((e) => Map<String, dynamic>.from(e as Map))
              .toList() ??
          const [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'homeId': homeId,
      'timestamp': timestamp.toIso8601String(),
      'homeContext': homeContext,
      'presenceState': presenceState,
      'isOccupied': isOccupied,
      'contextConfidence': contextConfidence,
      'deviceCount': deviceCount,
      'activeDevicesCount': activeDevicesCount,
      'totalPowerW': totalPowerW,
      'tariffPeriod': tariffPeriod,
      'tariffPrice': tariffPrice,
      'forecastPredictedKwh': forecastPredictedKwh,
      'activeAnomalyCount': activeAnomalyCount,
      'activeAutomationCount': activeAutomationCount,
      'activeScheduleCount': activeScheduleCount,
      'devicesSummary': devicesSummary,
    };
  }
}

@immutable
class IntelligenceDecision {
  final String id;
  final String homeId;
  final String decisionType;
  final DecisionPriority priority;
  final int priorityRank;
  final ConfidenceLevel confidence;
  final double confidenceScore;
  final RiskLevel risk;
  final Map<String, dynamic> evidence;
  final Map<String, dynamic> proposedAction;
  final String expectedEffect;
  final bool isAutoExecutable;
  final Map<String, dynamic> safetyResult;
  final DecisionStatus status;
  final DateTime createdAt;
  final DateTime? expiresAt;

  const IntelligenceDecision({
    required this.id,
    required this.homeId,
    required this.decisionType,
    required this.priority,
    this.priorityRank = 7,
    this.confidence = ConfidenceLevel.medium,
    this.confidenceScore = 0.5,
    this.risk = RiskLevel.low,
    this.evidence = const {},
    this.proposedAction = const {},
    this.expectedEffect = '',
    this.isAutoExecutable = false,
    this.safetyResult = const {},
    this.status = DecisionStatus.generated,
    required this.createdAt,
    this.expiresAt,
  });

  factory IntelligenceDecision.fromJson(Map<String, dynamic> json) {
    return IntelligenceDecision(
      id: json['id'] as String? ?? '',
      homeId: json['home_id'] as String? ?? (json['homeId'] as String? ?? ''),
      decisionType: json['decision_type'] as String? ?? (json['decisionType'] as String? ?? ''),
      priority: DecisionPriority.fromApiValue(json['priority'] as String?),
      priorityRank: json['priority_rank'] as int? ?? (json['priorityRank'] as int? ?? 7),
      confidence: ConfidenceLevel.fromApiValue(json['confidence'] as String?),
      confidenceScore: (json['confidence_score'] as num?)?.toDouble() ?? ((json['confidenceScore'] as num?)?.toDouble() ?? 0.5),
      risk: RiskLevel.fromApiValue(json['risk'] as String?),
      evidence: json['evidence'] is Map ? Map<String, dynamic>.from(json['evidence'] as Map) : const {},
      proposedAction: json['proposed_action'] is Map
          ? Map<String, dynamic>.from(json['proposed_action'] as Map)
          : (json['proposedAction'] is Map ? Map<String, dynamic>.from(json['proposedAction'] as Map) : const {}),
      expectedEffect: json['expected_effect'] as String? ?? (json['expectedEffect'] as String? ?? ''),
      isAutoExecutable: json['is_auto_executable'] as bool? ?? (json['isAutoExecutable'] as bool? ?? false),
      safetyResult: json['safety_result'] is Map
          ? Map<String, dynamic>.from(json['safety_result'] as Map)
          : (json['safetyResult'] is Map ? Map<String, dynamic>.from(json['safetyResult'] as Map) : const {}),
      status: DecisionStatus.fromApiValue(json['status'] as String?),
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? (json['createdAt'] as String? ?? '')) ?? DateTime.now(),
      expiresAt: json['expires_at'] != null ? DateTime.tryParse(json['expires_at'] as String) : (json['expiresAt'] != null ? DateTime.tryParse(json['expiresAt'] as String) : null),
    );
  }
}

@immutable
class IntelligenceRecommendation {
  final String id;
  final String homeId;
  final RecommendationType recommendationType;
  final DecisionPriority priority;
  final int priorityRank;
  final ConfidenceLevel confidence;
  final RiskLevel risk;
  final String title;
  final String description;
  final Map<String, dynamic> evidence;
  final Map<String, dynamic> proposedAction;
  final String expectedBenefit;
  final bool isAutoExecutable;
  final DecisionStatus status;
  final DateTime createdAt;
  final DateTime? expiresAt;

  const IntelligenceRecommendation({
    required this.id,
    required this.homeId,
    required this.recommendationType,
    required this.priority,
    this.priorityRank = 7,
    this.confidence = ConfidenceLevel.medium,
    this.risk = RiskLevel.low,
    required this.title,
    this.description = '',
    this.evidence = const {},
    this.proposedAction = const {},
    this.expectedBenefit = '',
    this.isAutoExecutable = false,
    this.status = DecisionStatus.generated,
    required this.createdAt,
    this.expiresAt,
  });

  factory IntelligenceRecommendation.fromJson(Map<String, dynamic> json) {
    return IntelligenceRecommendation(
      id: json['id'] as String? ?? '',
      homeId: json['home_id'] as String? ?? (json['homeId'] as String? ?? ''),
      recommendationType: RecommendationType.fromApiValue(json['recommendation_type'] as String? ?? (json['recommendationType'] as String?)),
      priority: DecisionPriority.fromApiValue(json['priority'] as String?),
      priorityRank: json['priority_rank'] as int? ?? (json['priorityRank'] as int? ?? 7),
      confidence: ConfidenceLevel.fromApiValue(json['confidence'] as String?),
      risk: RiskLevel.fromApiValue(json['risk'] as String?),
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      evidence: json['evidence'] is Map ? Map<String, dynamic>.from(json['evidence'] as Map) : const {},
      proposedAction: json['proposed_action'] is Map
          ? Map<String, dynamic>.from(json['proposed_action'] as Map)
          : (json['proposedAction'] is Map ? Map<String, dynamic>.from(json['proposedAction'] as Map) : const {}),
      expectedBenefit: json['expected_benefit'] as String? ?? (json['expectedBenefit'] as String? ?? ''),
      isAutoExecutable: json['is_auto_executable'] as bool? ?? (json['isAutoExecutable'] as bool? ?? false),
      status: DecisionStatus.fromApiValue(json['status'] as String?),
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? (json['createdAt'] as String? ?? '')) ?? DateTime.now(),
      expiresAt: json['expires_at'] != null ? DateTime.tryParse(json['expires_at'] as String) : (json['expiresAt'] != null ? DateTime.tryParse(json['expiresAt'] as String) : null),
    );
  }
}

@immutable
class DecisionOutcome {
  final String id;
  final String decisionId;
  final String homeId;
  final DecisionStatus status;
  final DateTime executedAt;
  final Map<String, dynamic> previousState;
  final Map<String, dynamic> newState;
  final String expectedBenefit;
  final String actualBenefit;
  final String feedback;
  final String? failureReason;

  const DecisionOutcome({
    required this.id,
    required this.decisionId,
    required this.homeId,
    required this.status,
    required this.executedAt,
    this.previousState = const {},
    this.newState = const {},
    this.expectedBenefit = '',
    this.actualBenefit = '',
    this.feedback = '',
    this.failureReason,
  });

  factory DecisionOutcome.fromJson(Map<String, dynamic> json) {
    return DecisionOutcome(
      id: json['id'] as String? ?? '',
      decisionId: json['decision_id'] as String? ?? (json['decisionId'] as String? ?? ''),
      homeId: json['home_id'] as String? ?? (json['homeId'] as String? ?? ''),
      status: DecisionStatus.fromApiValue(json['status'] as String?),
      executedAt: DateTime.tryParse(json['executed_at'] as String? ?? (json['executedAt'] as String? ?? '')) ?? DateTime.now(),
      previousState: json['previous_state'] is Map
          ? Map<String, dynamic>.from(json['previous_state'] as Map)
          : (json['previousState'] is Map ? Map<String, dynamic>.from(json['previousState'] as Map) : const {}),
      newState: json['new_state'] is Map
          ? Map<String, dynamic>.from(json['new_state'] as Map)
          : (json['newState'] is Map ? Map<String, dynamic>.from(json['newState'] as Map) : const {}),
      expectedBenefit: json['expected_benefit'] as String? ?? (json['expectedBenefit'] as String? ?? ''),
      actualBenefit: json['actual_benefit'] as String? ?? (json['actualBenefit'] as String? ?? ''),
      feedback: json['feedback'] as String? ?? '',
      failureReason: json['failure_reason'] as String? ?? (json['failureReason'] as String?),
    );
  }
}

@immutable
class IntelligenceSummary {
  final HomeIntelligenceSnapshot snapshot;
  final int activeRecommendationsCount;
  final List<IntelligenceRecommendation> recommendations;
  final List<IntelligenceDecision> recentDecisions;
  final List<DecisionOutcome> recentOutcomes;

  const IntelligenceSummary({
    required this.snapshot,
    required this.activeRecommendationsCount,
    required this.recommendations,
    required this.recentDecisions,
    required this.recentOutcomes,
  });

  factory IntelligenceSummary.fromJson(Map<String, dynamic> json) {
    return IntelligenceSummary(
      snapshot: HomeIntelligenceSnapshot.fromJson(Map<String, dynamic>.from(json['snapshot'] as Map? ?? {})),
      activeRecommendationsCount: json['activeRecommendationsCount'] as int? ?? 0,
      recommendations: (json['recommendations'] as List<dynamic>?)
              ?.map((e) => IntelligenceRecommendation.fromJson(Map<String, dynamic>.from(e as Map)))
              .toList() ??
          const [],
      recentDecisions: (json['recentDecisions'] as List<dynamic>?)
              ?.map((e) => IntelligenceDecision.fromJson(Map<String, dynamic>.from(e as Map)))
              .toList() ??
          const [],
      recentOutcomes: (json['recentOutcomes'] as List<dynamic>?)
              ?.map((e) => DecisionOutcome.fromJson(Map<String, dynamic>.from(e as Map)))
              .toList() ??
          const [],
    );
  }
}
