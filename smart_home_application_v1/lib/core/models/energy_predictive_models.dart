import 'package:flutter/foundation.dart';

enum ForecastHorizon {
  nextHour,
  next24Hours,
  next7Days,
  currentMonth;

  String toApiValue() {
    switch (this) {
      case ForecastHorizon.nextHour:
        return 'next_hour';
      case ForecastHorizon.next24Hours:
        return 'next_24_hours';
      case ForecastHorizon.next7Days:
        return 'next_7_days';
      case ForecastHorizon.currentMonth:
        return 'current_month';
    }
  }

  static ForecastHorizon fromApiValue(String val) {
    switch (val) {
      case 'next_hour':
        return ForecastHorizon.nextHour;
      case 'next_24_hours':
        return ForecastHorizon.next24Hours;
      case 'next_7_days':
        return ForecastHorizon.next7Days;
      case 'current_month':
        return ForecastHorizon.currentMonth;
      default:
        return ForecastHorizon.next24Hours;
    }
  }
}

enum AnomalySeverity {
  info,
  low,
  medium,
  high,
  critical;

  static AnomalySeverity fromString(String val) {
    switch (val.toUpperCase()) {
      case 'INFO':
        return AnomalySeverity.info;
      case 'LOW':
        return AnomalySeverity.low;
      case 'MEDIUM':
        return AnomalySeverity.medium;
      case 'HIGH':
        return AnomalySeverity.high;
      case 'CRITICAL':
        return AnomalySeverity.critical;
      default:
        return AnomalySeverity.low;
    }
  }
}

@immutable
class ForecastPoint {
  final DateTime timestamp;
  final double predictedPowerW;
  final double predictedEnergyWh;
  final double predictedCost;
  final double confidenceScore;

  const ForecastPoint({
    required this.timestamp,
    required this.predictedPowerW,
    required this.predictedEnergyWh,
    required this.predictedCost,
    required this.confidenceScore,
  });

  factory ForecastPoint.fromJson(Map<String, dynamic> json) {
    return ForecastPoint(
      timestamp: DateTime.tryParse(json['timestamp'] ?? '') ?? DateTime.now(),
      predictedPowerW: (json['predictedPowerW'] as num?)?.toDouble() ?? 0.0,
      predictedEnergyWh: (json['predictedEnergyWh'] as num?)?.toDouble() ?? 0.0,
      predictedCost: (json['predictedCost'] as num?)?.toDouble() ?? 0.0,
      confidenceScore: (json['confidenceScore'] as num?)?.toDouble() ?? 0.5,
    );
  }

  Map<String, dynamic> toJson() => {
        'timestamp': timestamp.toIso8601String(),
        'predictedPowerW': predictedPowerW,
        'predictedEnergyWh': predictedEnergyWh,
        'predictedCost': predictedCost,
        'confidenceScore': confidenceScore,
      };
}

@immutable
class EnergyForecast {
  final String? id;
  final String homeId;
  final String scopeType;
  final String scopeId;
  final ForecastHorizon horizon;
  final DateTime startTime;
  final DateTime endTime;
  final double predictedKwh;
  final double predictedCost;
  final String currency;
  final double confidenceScore;
  final String methodology;
  final String dataCoverage;
  final bool isEstimate;
  final DateTime generatedAt;
  final List<ForecastPoint> points;

  const EnergyForecast({
    this.id,
    required this.homeId,
    required this.scopeType,
    required this.scopeId,
    required this.horizon,
    required this.startTime,
    required this.endTime,
    required this.predictedKwh,
    required this.predictedCost,
    required this.currency,
    required this.confidenceScore,
    required this.methodology,
    required this.dataCoverage,
    this.isEstimate = true,
    required this.generatedAt,
    required this.points,
  });

  factory EnergyForecast.fromJson(Map<String, dynamic> json) {
    final pointsList = (json['points'] as List<dynamic>?)
            ?.map((p) => ForecastPoint.fromJson(p as Map<String, dynamic>))
            .toList() ??
        [];

    return EnergyForecast(
      id: json['id'] as String?,
      homeId: json['homeId'] as String? ?? '',
      scopeType: json['scopeType'] as String? ?? 'home',
      scopeId: json['scopeId'] as String? ?? '',
      horizon: ForecastHorizon.fromApiValue(json['horizon'] as String? ?? 'next_24_hours'),
      startTime: DateTime.tryParse(json['startTime'] ?? '') ?? DateTime.now(),
      endTime: DateTime.tryParse(json['endTime'] ?? '') ?? DateTime.now(),
      predictedKwh: (json['predictedKwh'] as num?)?.toDouble() ?? 0.0,
      predictedCost: (json['predictedCost'] as num?)?.toDouble() ?? 0.0,
      currency: json['currency'] as String? ?? 'USD',
      confidenceScore: (json['confidenceScore'] as num?)?.toDouble() ?? 0.5,
      methodology: json['methodology'] as String? ?? 'HISTORICAL_HOURLY_PROFILE',
      dataCoverage: json['dataCoverage'] as String? ?? 'FULL',
      isEstimate: json['isEstimate'] as bool? ?? true,
      generatedAt: DateTime.tryParse(json['generatedAt'] ?? '') ?? DateTime.now(),
      points: pointsList,
    );
  }
}

@immutable
class EnergyBaseline {
  final String? id;
  final String homeId;
  final String scopeType;
  final String scopeId;
  final double typicalPowerW;
  final double typicalDailyEnergyKwh;
  final double typicalOvernightWh;
  final List<int> typicalOperatingHours;
  final int sampleCount;
  final double confidence;
  final DateTime calculatedAt;

  const EnergyBaseline({
    this.id,
    required this.homeId,
    required this.scopeType,
    required this.scopeId,
    required this.typicalPowerW,
    required this.typicalDailyEnergyKwh,
    required this.typicalOvernightWh,
    required this.typicalOperatingHours,
    required this.sampleCount,
    required this.confidence,
    required this.calculatedAt,
  });

  factory EnergyBaseline.fromJson(Map<String, dynamic> json) {
    return EnergyBaseline(
      id: json['id'] as String?,
      homeId: json['homeId'] as String? ?? '',
      scopeType: json['scopeType'] as String? ?? 'device',
      scopeId: json['scopeId'] as String? ?? '',
      typicalPowerW: (json['typicalPowerW'] as num?)?.toDouble() ?? 0.0,
      typicalDailyEnergyKwh: (json['typicalDailyEnergyKwh'] as num?)?.toDouble() ?? 0.0,
      typicalOvernightWh: (json['typicalOvernightWh'] as num?)?.toDouble() ?? 0.0,
      typicalOperatingHours: (json['typicalOperatingHours'] as List<dynamic>?)
              ?.map((e) => (e as num).toInt())
              .toList() ??
          [],
      sampleCount: (json['sampleCount'] as num?)?.toInt() ?? 0,
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.5,
      calculatedAt: DateTime.tryParse(json['calculatedAt'] ?? '') ?? DateTime.now(),
    );
  }
}

@immutable
class EnergyAnomaly {
  final String id;
  final String homeId;
  final String scopeType;
  final String scopeId;
  final String anomalyType;
  final AnomalySeverity severity;
  final double observedValue;
  final double baselineValue;
  final double deviationPercentage;
  final bool isConfirmed;
  final int confirmationCount;
  final Map<String, dynamic> evidence;
  final DateTime detectedAt;

  const EnergyAnomaly({
    required this.id,
    required this.homeId,
    required this.scopeType,
    required this.scopeId,
    required this.anomalyType,
    required this.severity,
    required this.observedValue,
    required this.baselineValue,
    required this.deviationPercentage,
    required this.isConfirmed,
    required this.confirmationCount,
    required this.evidence,
    required this.detectedAt,
  });

  factory EnergyAnomaly.fromJson(Map<String, dynamic> json) {
    return EnergyAnomaly(
      id: json['id'] as String? ?? '',
      homeId: json['homeId'] as String? ?? '',
      scopeType: json['scopeType'] as String? ?? 'device',
      scopeId: json['scopeId'] as String? ?? '',
      anomalyType: json['anomalyType'] as String? ?? 'UNUSUAL_POWER_SPIKE',
      severity: AnomalySeverity.fromString(json['severity'] as String? ?? 'LOW'),
      observedValue: (json['observedValue'] as num?)?.toDouble() ?? 0.0,
      baselineValue: (json['baselineValue'] as num?)?.toDouble() ?? 0.0,
      deviationPercentage: (json['deviationPercentage'] as num?)?.toDouble() ?? 0.0,
      isConfirmed: json['isConfirmed'] as bool? ?? false,
      confirmationCount: (json['confirmationCount'] as num?)?.toInt() ?? 1,
      evidence: (json['evidence'] as Map<String, dynamic>?) ?? {},
      detectedAt: DateTime.tryParse(json['detectedAt'] ?? '') ?? DateTime.now(),
    );
  }
}

@immutable
class EfficiencyFactors {
  final double standbyLossScore;
  final double peakDemandScore;
  final double thresholdViolationScore;
  final double tariffEfficiencyScore;
  final double trendScore;

  const EfficiencyFactors({
    required this.standbyLossScore,
    required this.peakDemandScore,
    required this.thresholdViolationScore,
    required this.tariffEfficiencyScore,
    required this.trendScore,
  });

  factory EfficiencyFactors.fromJson(Map<String, dynamic> json) {
    return EfficiencyFactors(
      standbyLossScore: (json['standbyLossScore'] as num?)?.toDouble() ?? 80.0,
      peakDemandScore: (json['peakDemandScore'] as num?)?.toDouble() ?? 80.0,
      thresholdViolationScore: (json['thresholdViolationScore'] as num?)?.toDouble() ?? 80.0,
      tariffEfficiencyScore: (json['tariffEfficiencyScore'] as num?)?.toDouble() ?? 80.0,
      trendScore: (json['trendScore'] as num?)?.toDouble() ?? 80.0,
    );
  }
}

@immutable
class EnergyEfficiencyScore {
  final String? id;
  final String homeId;
  final double score;
  final String grade;
  final EfficiencyFactors factors;
  final Map<String, dynamic> evidence;
  final DateTime calculatedAt;

  const EnergyEfficiencyScore({
    this.id,
    required this.homeId,
    required this.score,
    required this.grade,
    required this.factors,
    required this.evidence,
    required this.calculatedAt,
  });

  factory EnergyEfficiencyScore.fromJson(Map<String, dynamic> json) {
    return EnergyEfficiencyScore(
      id: json['id'] as String?,
      homeId: json['homeId'] as String? ?? '',
      score: (json['score'] as num?)?.toDouble() ?? 0.0,
      grade: json['grade'] as String? ?? 'C',
      factors: EfficiencyFactors.fromJson((json['factors'] as Map<String, dynamic>?) ?? {}),
      evidence: (json['evidence'] as Map<String, dynamic>?) ?? {},
      calculatedAt: DateTime.tryParse(json['calculatedAt'] ?? '') ?? DateTime.now(),
    );
  }
}

@immutable
class PredictiveOptimizationRecommendation {
  final String id;
  final String homeId;
  final String? deviceId;
  final String category;
  final String priority;
  final String title;
  final String description;
  final String reason;
  final Map<String, dynamic> evidence;
  final double estimatedKwhSavings;
  final double estimatedCostSavings;
  final String currency;
  final double confidence;
  final bool isEstimate;
  final DateTime generatedAt;
  final bool isDismissed;

  const PredictiveOptimizationRecommendation({
    required this.id,
    required this.homeId,
    this.deviceId,
    required this.category,
    required this.priority,
    required this.title,
    required this.description,
    required this.reason,
    required this.evidence,
    required this.estimatedKwhSavings,
    required this.estimatedCostSavings,
    required this.currency,
    required this.confidence,
    this.isEstimate = true,
    required this.generatedAt,
    this.isDismissed = false,
  });

  factory PredictiveOptimizationRecommendation.fromJson(Map<String, dynamic> json) {
    return PredictiveOptimizationRecommendation(
      id: json['id'] as String? ?? '',
      homeId: json['homeId'] as String? ?? '',
      deviceId: json['deviceId'] as String?,
      category: json['category'] as String? ?? 'LOAD_SHIFTING',
      priority: json['priority'] as String? ?? 'MEDIUM',
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      reason: json['reason'] as String? ?? '',
      evidence: (json['evidence'] as Map<String, dynamic>?) ?? {},
      estimatedKwhSavings: (json['estimatedKwhSavings'] as num?)?.toDouble() ?? 0.0,
      estimatedCostSavings: (json['estimatedCostSavings'] as num?)?.toDouble() ?? 0.0,
      currency: json['currency'] as String? ?? 'USD',
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.8,
      isEstimate: json['isEstimate'] as bool? ?? true,
      generatedAt: DateTime.tryParse(json['generatedAt'] ?? '') ?? DateTime.now(),
      isDismissed: json['isDismissed'] as bool? ?? false,
    );
  }
}

@immutable
class ForecastAccuracy {
  final String homeId;
  final String horizon;
  final int sampleCount;
  final double mae;
  final double mape;
  final bool hasSufficientData;

  const ForecastAccuracy({
    required this.homeId,
    required this.horizon,
    required this.sampleCount,
    required this.mae,
    required this.mape,
    required this.hasSufficientData,
  });

  factory ForecastAccuracy.fromJson(Map<String, dynamic> json) {
    return ForecastAccuracy(
      homeId: json['homeId'] as String? ?? '',
      horizon: json['horizon'] as String? ?? 'next_24_hours',
      sampleCount: (json['sampleCount'] as num?)?.toInt() ?? 0,
      mae: (json['mae'] as num?)?.toDouble() ?? 0.0,
      mape: (json['mape'] as num?)?.toDouble() ?? 0.0,
      hasSufficientData: json['hasSufficientData'] as bool? ?? false,
    );
  }
}
