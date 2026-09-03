import 'package:flutter/foundation.dart';

/// Supported tariff pricing types
enum TariffType {
  flat,
  timeOfUse,
  dynamicPricing;

  static TariffType fromString(String? val) {
    switch (val?.toUpperCase()) {
      case 'TIME_OF_USE':
      case 'TOU':
        return TariffType.timeOfUse;
      case 'DYNAMIC':
        return TariffType.dynamicPricing;
      case 'FLAT':
      default:
        return TariffType.flat;
    }
  }

  String toServerString() {
    switch (this) {
      case TariffType.timeOfUse:
        return 'TIME_OF_USE';
      case TariffType.dynamicPricing:
        return 'DYNAMIC';
      case TariffType.flat:
        return 'FLAT';
    }
  }

  String get displayName {
    switch (this) {
      case TariffType.timeOfUse:
        return 'Time of Use (TOU)';
      case TariffType.dynamicPricing:
        return 'Dynamic Pricing';
      case TariffType.flat:
        return 'Flat Rate';
    }
  }
}

/// Supported TOU period classifications
enum TariffPeriodType {
  offPeak,
  standard,
  peak,
  criticalPeak;

  static TariffPeriodType fromString(String? val) {
    switch (val?.toUpperCase()) {
      case 'OFF_PEAK':
        return TariffPeriodType.offPeak;
      case 'PEAK':
        return TariffPeriodType.peak;
      case 'CRITICAL_PEAK':
        return TariffPeriodType.criticalPeak;
      case 'STANDARD':
      default:
        return TariffPeriodType.standard;
    }
  }

  String toServerString() {
    switch (this) {
      case TariffPeriodType.offPeak:
        return 'OFF_PEAK';
      case TariffPeriodType.peak:
        return 'PEAK';
      case TariffPeriodType.criticalPeak:
        return 'CRITICAL_PEAK';
      case TariffPeriodType.standard:
        return 'STANDARD';
    }
  }

  String get displayName {
    switch (this) {
      case TariffPeriodType.offPeak:
        return 'Off-Peak';
      case TariffPeriodType.peak:
        return 'Peak';
      case TariffPeriodType.criticalPeak:
        return 'Critical Peak';
      case TariffPeriodType.standard:
        return 'Standard';
    }
  }
}

/// Represents a specific Time-of-Use rate window
@immutable
class TariffPeriodModel {
  final String id;
  final TariffPeriodType periodType;
  final String startTime; // 'HH:MM'
  final String endTime;   // 'HH:MM'
  final List<int> applicableWeekdays; // 1 = Monday ... 7 = Sunday
  final double pricePerKwh;

  const TariffPeriodModel({
    required this.id,
    required this.periodType,
    required this.startTime,
    required this.endTime,
    required this.applicableWeekdays,
    required this.pricePerKwh,
  });

  factory TariffPeriodModel.fromJson(Map<String, dynamic> json) {
    List<int> weekdays = [1, 2, 3, 4, 5, 6, 7];
    if (json['applicable_weekdays'] != null) {
      if (json['applicable_weekdays'] is List) {
        weekdays = (json['applicable_weekdays'] as List).map((e) => (e as num).toInt()).toList();
      } else if (json['applicable_weekdays'] is String) {
        // String array
        try {
          final stripped = (json['applicable_weekdays'] as String)
              .replaceAll('[', '')
              .replaceAll(']', '')
              .split(',');
          weekdays = stripped.map((s) => int.parse(s.trim())).toList();
        } catch (_) {}
      }
    } else if (json['applicableWeekdays'] is List) {
      weekdays = (json['applicableWeekdays'] as List).map((e) => (e as num).toInt()).toList();
    }

    return TariffPeriodModel(
      id: json['id']?.toString() ?? '',
      periodType: TariffPeriodType.fromString(json['period_type'] ?? json['periodType']),
      startTime: json['start_time'] ?? json['startTime'] ?? '00:00',
      endTime: json['end_time'] ?? json['endTime'] ?? '23:59',
      applicableWeekdays: weekdays,
      pricePerKwh: (json['price_per_kwh'] ?? json['pricePerKwh'] ?? 0.0).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'periodType': periodType.toServerString(),
      'startTime': startTime,
      'endTime': endTime,
      'applicableWeekdays': applicableWeekdays,
      'pricePerKwh': pricePerKwh,
    };
  }

  TariffPeriodModel copyWith({
    String? id,
    TariffPeriodType? periodType,
    String? startTime,
    String? endTime,
    List<int>? applicableWeekdays,
    double? pricePerKwh,
  }) {
    return TariffPeriodModel(
      id: id ?? this.id,
      periodType: periodType ?? this.periodType,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      applicableWeekdays: applicableWeekdays ?? this.applicableWeekdays,
      pricePerKwh: pricePerKwh ?? this.pricePerKwh,
    );
  }
}

/// Represents an authoritative electricity tariff definition
@immutable
class ElectricityTariffModel {
  final String id;
  final String homeId;
  final String name;
  final TariffType tariffType;
  final String currency;
  final double? flatRatePerKwh;
  final double fixedDailyCharge;
  final DateTime effectiveFrom;
  final DateTime? effectiveTo;
  final double? carbonIntensityGPerKwh;
  final bool isActive;
  final List<TariffPeriodModel> periods;
  final Map<String, dynamic>? metadata;

  const ElectricityTariffModel({
    required this.id,
    required this.homeId,
    required this.name,
    required this.tariffType,
    this.currency = 'USD',
    this.flatRatePerKwh,
    this.fixedDailyCharge = 0.0,
    required this.effectiveFrom,
    this.effectiveTo,
    this.carbonIntensityGPerKwh,
    this.isActive = true,
    this.periods = const [],
    this.metadata,
  });

  factory ElectricityTariffModel.fromJson(Map<String, dynamic> json) {
    final rawPeriods = json['periods'] as List<dynamic>? ?? [];
    return ElectricityTariffModel(
      id: json['id']?.toString() ?? '',
      homeId: json['home_id'] ?? json['homeId'] ?? '',
      name: json['name']?.toString() ?? 'Unnamed Tariff',
      tariffType: TariffType.fromString(json['tariff_type'] ?? json['tariffType']),
      currency: (json['currency'] ?? 'USD').toString().toUpperCase(),
      flatRatePerKwh: json['flat_rate_per_kwh'] != null
          ? (json['flat_rate_per_kwh'] as num).toDouble()
          : (json['flatRatePerKwh'] != null ? (json['flatRatePerKwh'] as num).toDouble() : null),
      fixedDailyCharge: (json['fixed_daily_charge'] ?? json['fixedDailyCharge'] ?? 0.0).toDouble(),
      effectiveFrom: json['effective_from'] != null
          ? DateTime.parse(json['effective_from'].toString())
          : (json['effectiveFrom'] != null ? DateTime.parse(json['effectiveFrom'].toString()) : DateTime.now()),
      effectiveTo: json['effective_to'] != null
          ? DateTime.parse(json['effective_to'].toString())
          : (json['effectiveTo'] != null ? DateTime.parse(json['effectiveTo'].toString()) : null),
      carbonIntensityGPerKwh: json['carbon_intensity_g_per_kwh'] != null
          ? (json['carbon_intensity_g_per_kwh'] as num).toDouble()
          : (json['carbonIntensityGPerKwh'] != null ? (json['carbonIntensityGPerKwh'] as num).toDouble() : null),
      isActive: json['is_active'] == 1 || json['is_active'] == true || json['isActive'] == true,
      periods: rawPeriods.map((p) => TariffPeriodModel.fromJson(p as Map<String, dynamic>)).toList(),
      metadata: json['metadata'] is Map<String, dynamic> ? json['metadata'] as Map<String, dynamic> : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id.isNotEmpty) 'id': id,
      'homeId': homeId,
      'name': name,
      'tariffType': tariffType.toServerString(),
      'currency': currency,
      'flatRatePerKwh': flatRatePerKwh,
      'fixedDailyCharge': fixedDailyCharge,
      'effectiveFrom': effectiveFrom.toUtc().toIso8601String(),
      if (effectiveTo != null) 'effectiveTo': effectiveTo!.toUtc().toIso8601String(),
      if (carbonIntensityGPerKwh != null) 'carbonIntensityGPerKwh': carbonIntensityGPerKwh,
      'isActive': isActive,
      'periods': periods.map((p) => p.toJson()).toList(),
      if (metadata != null) 'metadata': metadata,
    };
  }
}

/// Budget period classification
enum BudgetPeriodType {
  daily,
  weekly,
  monthly;

  static BudgetPeriodType fromString(String? val) {
    switch (val?.toLowerCase()) {
      case 'daily':
        return BudgetPeriodType.daily;
      case 'weekly':
        return BudgetPeriodType.weekly;
      case 'monthly':
      default:
        return BudgetPeriodType.monthly;
    }
  }

  String toServerString() => name;

  String get displayName {
    switch (this) {
      case BudgetPeriodType.daily:
        return 'Daily';
      case BudgetPeriodType.weekly:
        return 'Weekly';
      case BudgetPeriodType.monthly:
        return 'Monthly';
    }
  }
}

/// Energy budget configuration
@immutable
class EnergyBudgetModel {
  final String id;
  final String homeId;
  final BudgetPeriodType periodType;
  final double budgetAmount;
  final String currency;
  final double alertThresholdPercent;
  final bool isEnabled;

  const EnergyBudgetModel({
    required this.id,
    required this.homeId,
    required this.periodType,
    required this.budgetAmount,
    this.currency = 'USD',
    this.alertThresholdPercent = 80.0,
    this.isEnabled = true,
  });

  factory EnergyBudgetModel.fromJson(Map<String, dynamic> json) {
    return EnergyBudgetModel(
      id: json['id']?.toString() ?? '',
      homeId: json['home_id'] ?? json['homeId'] ?? '',
      periodType: BudgetPeriodType.fromString(json['period_type'] ?? json['periodType']),
      budgetAmount: (json['budget_amount'] ?? json['budgetAmount'] ?? 0.0).toDouble(),
      currency: (json['currency'] ?? 'USD').toString().toUpperCase(),
      alertThresholdPercent: (json['alert_threshold_percent'] ?? json['alertThresholdPercent'] ?? 80.0).toDouble(),
      isEnabled: json['is_enabled'] == 1 || json['is_enabled'] == true || json['isEnabled'] == true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id.isNotEmpty) 'id': id,
      'homeId': homeId,
      'periodType': periodType.toServerString(),
      'budgetAmount': budgetAmount,
      'currency': currency,
      'alertThresholdPercent': alertThresholdPercent,
      'isEnabled': isEnabled,
    };
  }
}

/// Evaluated budget consumption & forecast status
@immutable
class BudgetStatusModel {
  final bool configured;
  final String homeId;
  final BudgetPeriodType periodType;
  final double budgetAmount;
  final String currency;
  final double actualCostToDate;
  final double budgetRemaining;
  final double percentConsumed;
  final double projectedTotalCost;
  final double percentProjected;
  final double projectedOverrun;
  final bool isProjectedToExceed;

  const BudgetStatusModel({
    required this.configured,
    required this.homeId,
    required this.periodType,
    this.budgetAmount = 0.0,
    this.currency = 'USD',
    this.actualCostToDate = 0.0,
    this.budgetRemaining = 0.0,
    this.percentConsumed = 0.0,
    this.projectedTotalCost = 0.0,
    this.percentProjected = 0.0,
    this.projectedOverrun = 0.0,
    this.isProjectedToExceed = false,
  });

  factory BudgetStatusModel.fromJson(Map<String, dynamic> json) {
    return BudgetStatusModel(
      configured: json['configured'] == true,
      homeId: json['homeId']?.toString() ?? '',
      periodType: BudgetPeriodType.fromString(json['periodType']?.toString()),
      budgetAmount: (json['budgetAmount'] ?? 0.0).toDouble(),
      currency: (json['currency'] ?? 'USD').toString(),
      actualCostToDate: (json['actualCostToDate'] ?? 0.0).toDouble(),
      budgetRemaining: (json['budgetRemaining'] ?? 0.0).toDouble(),
      percentConsumed: (json['percentConsumed'] ?? 0.0).toDouble(),
      projectedTotalCost: (json['projectedTotalCost'] ?? 0.0).toDouble(),
      percentProjected: (json['percentProjected'] ?? 0.0).toDouble(),
      projectedOverrun: (json['projectedOverrun'] ?? 0.0).toDouble(),
      isProjectedToExceed: json['isProjectedToExceed'] == true,
    );
  }
}

/// Cost breakdown item for peak/off-peak/standard
@immutable
class CostBreakdownItem {
  final double cost;
  final double kwh;

  const CostBreakdownItem({required this.cost, required this.kwh});

  factory CostBreakdownItem.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const CostBreakdownItem(cost: 0.0, kwh: 0.0);
    return CostBreakdownItem(
      cost: (json['cost'] ?? 0.0).toDouble(),
      kwh: (json['kwh'] ?? 0.0).toDouble(),
    );
  }
}

/// Comprehensive Authoritative Energy Cost Summary
@immutable
class EnergyCostSummaryModel {
  final String homeId;
  final String entityType;
  final String? entityId;
  final String period;
  final double totalCost;
  final double variableCost;
  final double fixedCharges;
  final String currency;
  final double totalKwh;
  final CostBreakdownItem peak;
  final CostBreakdownItem offPeak;
  final CostBreakdownItem standard;
  final String? effectiveTariffName;
  final String dataQuality;

  const EnergyCostSummaryModel({
    required this.homeId,
    required this.entityType,
    this.entityId,
    required this.period,
    required this.totalCost,
    required this.variableCost,
    required this.fixedCharges,
    required this.currency,
    required this.totalKwh,
    required this.peak,
    required this.offPeak,
    required this.standard,
    this.effectiveTariffName,
    required this.dataQuality,
  });

  factory EnergyCostSummaryModel.fromJson(Map<String, dynamic> json) {
    final breakdown = json['breakdown'] as Map<String, dynamic>? ?? {};
    final effTariff = json['effectiveTariff'] as Map<String, dynamic>?;
    return EnergyCostSummaryModel(
      homeId: json['homeId']?.toString() ?? '',
      entityType: json['entityType']?.toString() ?? 'home',
      entityId: json['entityId']?.toString(),
      period: json['period']?.toString() ?? 'today',
      totalCost: (json['totalCost'] ?? 0.0).toDouble(),
      variableCost: (json['variableCost'] ?? 0.0).toDouble(),
      fixedCharges: (json['fixedCharges'] ?? 0.0).toDouble(),
      currency: (json['currency'] ?? 'USD').toString(),
      totalKwh: (json['totalKwh'] ?? 0.0).toDouble(),
      peak: CostBreakdownItem.fromJson(breakdown['peak'] as Map<String, dynamic>?),
      offPeak: CostBreakdownItem.fromJson(breakdown['offPeak'] as Map<String, dynamic>?),
      standard: CostBreakdownItem.fromJson(breakdown['standard'] as Map<String, dynamic>?),
      effectiveTariffName: effTariff?['name']?.toString(),
      dataQuality: json['dataQuality']?.toString() ?? 'GOOD',
    );
  }
}

/// Cost & Energy Forecast Projection
@immutable
class CostForecastModel {
  final String homeId;
  final String period;
  final String currency;
  final double actualCostToDate;
  final double estimatedRemainingCost;
  final double projectedTotalCost;
  final double actualKwhToDate;
  final double projectedTotalKwh;
  final int daysElapsed;
  final int daysRemaining;
  final double confidenceScore;
  final bool isEstimate;

  const CostForecastModel({
    required this.homeId,
    required this.period,
    required this.currency,
    required this.actualCostToDate,
    required this.estimatedRemainingCost,
    required this.projectedTotalCost,
    required this.actualKwhToDate,
    required this.projectedTotalKwh,
    required this.daysElapsed,
    required this.daysRemaining,
    required this.confidenceScore,
    this.isEstimate = true,
  });

  factory CostForecastModel.fromJson(Map<String, dynamic> json) {
    return CostForecastModel(
      homeId: json['homeId']?.toString() ?? '',
      period: json['period']?.toString() ?? 'monthly',
      currency: (json['currency'] ?? 'USD').toString(),
      actualCostToDate: (json['actualCostToDate'] ?? 0.0).toDouble(),
      estimatedRemainingCost: (json['estimatedRemainingCost'] ?? 0.0).toDouble(),
      projectedTotalCost: (json['projectedTotalCost'] ?? 0.0).toDouble(),
      actualKwhToDate: (json['actualKwhToDate'] ?? 0.0).toDouble(),
      projectedTotalKwh: (json['projectedTotalKwh'] ?? 0.0).toDouble(),
      daysElapsed: (json['daysElapsed'] ?? 1).toInt(),
      daysRemaining: (json['daysRemaining'] ?? 0).toInt(),
      confidenceScore: (json['confidenceScore'] ?? 0.5).toDouble(),
      isEstimate: json['isEstimate'] ?? true,
    );
  }
}

/// Carbon Footprint Estimation
@immutable
class CarbonFootprintModel {
  final String entityId;
  final String entityType;
  final String period;
  final double carbonIntensityGPerKwh;
  final double totalGramsCO2;
  final double totalKgCO2;
  final String source;
  final bool isEstimate;

  const CarbonFootprintModel({
    required this.entityId,
    required this.entityType,
    required this.period,
    required this.carbonIntensityGPerKwh,
    required this.totalGramsCO2,
    required this.totalKgCO2,
    required this.source,
    this.isEstimate = true,
  });

  factory CarbonFootprintModel.fromJson(Map<String, dynamic> json) {
    return CarbonFootprintModel(
      entityId: json['entityId']?.toString() ?? '',
      entityType: json['entityType']?.toString() ?? 'home',
      period: json['period']?.toString() ?? 'today',
      carbonIntensityGPerKwh: (json['carbonIntensityGPerKwh'] ?? 420.0).toDouble(),
      totalGramsCO2: (json['totalGramsCO2'] ?? 0.0).toDouble(),
      totalKgCO2: (json['totalKgCO2'] ?? 0.0).toDouble(),
      source: json['source']?.toString() ?? 'default_regional_estimate',
      isEstimate: json['isEstimate'] ?? true,
    );
  }
}

/// Cheapest operating window
@immutable
class OperatingWindow {
  final String startTime;
  final String endTime;
  final double avgPricePerKwh;
  final String periodType;

  const OperatingWindow({
    required this.startTime,
    required this.endTime,
    required this.avgPricePerKwh,
    required this.periodType,
  });

  factory OperatingWindow.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return const OperatingWindow(startTime: '', endTime: '', avgPricePerKwh: 0.0, periodType: 'STANDARD');
    }
    return OperatingWindow(
      startTime: json['startTime']?.toString() ?? '',
      endTime: json['endTime']?.toString() ?? '',
      avgPricePerKwh: (json['avgPricePerKwh'] ?? 0.0).toDouble(),
      periodType: json['periodType']?.toString() ?? 'STANDARD',
    );
  }
}

/// Cheapest period analysis result
@immutable
class CheapestPeriodModel {
  final String homeId;
  final String currency;
  final int durationHours;
  final OperatingWindow cheapestWindow;
  final OperatingWindow peakWindow;
  final double potentialSavingsPercent;

  const CheapestPeriodModel({
    required this.homeId,
    required this.currency,
    required this.durationHours,
    required this.cheapestWindow,
    required this.peakWindow,
    required this.potentialSavingsPercent,
  });

  factory CheapestPeriodModel.fromJson(Map<String, dynamic> json) {
    return CheapestPeriodModel(
      homeId: json['homeId']?.toString() ?? '',
      currency: (json['currency'] ?? 'USD').toString(),
      durationHours: (json['durationHours'] ?? 2).toInt(),
      cheapestWindow: OperatingWindow.fromJson(json['cheapestWindow'] as Map<String, dynamic>?),
      peakWindow: OperatingWindow.fromJson(json['peakWindow'] as Map<String, dynamic>?),
      potentialSavingsPercent: (json['potentialSavingsPercent'] ?? 0.0).toDouble(),
    );
  }
}

/// Cost Optimization Load-Shifting Recommendation
@immutable
class CostOptimizationRecommendationModel {
  final String id;
  final String homeId;
  final String? deviceId;
  final String category;
  final String priority;
  final String title;
  final String description;
  final Map<String, dynamic>? evidence;
  final Map<String, dynamic>? estimatedSavings;
  final OperatingWindow? recommendedWindow;
  final bool isDismissed;

  const CostOptimizationRecommendationModel({
    required this.id,
    required this.homeId,
    this.deviceId,
    required this.category,
    required this.priority,
    required this.title,
    required this.description,
    this.evidence,
    this.estimatedSavings,
    this.recommendedWindow,
    this.isDismissed = false,
  });

  factory CostOptimizationRecommendationModel.fromJson(Map<String, dynamic> json) {
    return CostOptimizationRecommendationModel(
      id: json['id']?.toString() ?? '',
      homeId: json['home_id'] ?? json['homeId'] ?? '',
      deviceId: json['device_id'] ?? json['deviceId'],
      category: json['category']?.toString() ?? 'LOAD_SHIFTING',
      priority: json['priority']?.toString() ?? 'MEDIUM',
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      evidence: json['evidence'] is Map<String, dynamic> ? json['evidence'] as Map<String, dynamic> : null,
      estimatedSavings: json['estimated_savings'] is Map<String, dynamic>
          ? json['estimated_savings'] as Map<String, dynamic>
          : (json['estimatedSavings'] is Map<String, dynamic> ? json['estimatedSavings'] as Map<String, dynamic> : null),
      recommendedWindow: json['recommended_window'] != null
          ? OperatingWindow.fromJson(json['recommended_window'] as Map<String, dynamic>)
          : (json['recommendedWindow'] != null ? OperatingWindow.fromJson(json['recommendedWindow'] as Map<String, dynamic>) : null),
      isDismissed: json['is_dismissed'] == 1 || json['is_dismissed'] == true || json['isDismissed'] == true,
    );
  }
}
