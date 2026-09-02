// EH Home — Energy Intelligence & Telemetry Models (Phase 19)

enum EnergyPeriod {
  today,
  week,
  month,
  year;

  static EnergyPeriod fromString(String? val) {
    if (val == null) return EnergyPeriod.today;
    switch (val.toLowerCase()) {
      case 'today':
        return EnergyPeriod.today;
      case 'week':
        return EnergyPeriod.week;
      case 'month':
        return EnergyPeriod.month;
      case 'year':
        return EnergyPeriod.year;
      default:
        return EnergyPeriod.today;
    }
  }

  String toApiString() {
    switch (this) {
      case EnergyPeriod.today:
        return 'today';
      case EnergyPeriod.week:
        return 'week';
      case EnergyPeriod.month:
        return 'month';
      case EnergyPeriod.year:
        return 'year';
    }
  }

  String get displayName {
    switch (this) {
      case EnergyPeriod.today:
        return 'Today';
      case EnergyPeriod.week:
        return 'This Week';
      case EnergyPeriod.month:
        return 'This Month';
      case EnergyPeriod.year:
        return 'This Year';
    }
  }
}

enum TrendDirection {
  up,
  down,
  stable;

  static TrendDirection fromString(String? val) {
    if (val == null) return TrendDirection.stable;
    switch (val.toUpperCase()) {
      case 'UP':
        return TrendDirection.up;
      case 'DOWN':
        return TrendDirection.down;
      default:
        return TrendDirection.stable;
    }
  }
}

/// Instantaneous or historical electrical telemetry measurement
class EnergyMeasurement {
  final String? id;
  final String? deviceId;
  final int channelIndex;
  final double voltageV;
  final double currentA;
  final double powerW;
  final double totalEnergyKwh;
  final double? intervalEnergyWh;
  final double frequencyHz;
  final double powerFactor;
  final int flags;
  final int sequenceNumber;
  final DateTime timestamp;

  const EnergyMeasurement({
    this.id,
    this.deviceId,
    this.channelIndex = 1,
    required this.voltageV,
    required this.currentA,
    required this.powerW,
    required this.totalEnergyKwh,
    this.intervalEnergyWh,
    this.frequencyHz = 50.0,
    this.powerFactor = 1.0,
    this.flags = 0,
    this.sequenceNumber = 0,
    required this.timestamp,
  });

  factory EnergyMeasurement.fromJson(Map<String, dynamic> json) {
    return EnergyMeasurement(
      id: json['id'] as String?,
      deviceId: json['deviceId'] as String?,
      channelIndex: json['channelIndex'] as int? ?? 1,
      voltageV: (json['voltageV'] as num?)?.toDouble() ?? 0.0,
      currentA: (json['currentA'] as num?)?.toDouble() ?? 0.0,
      powerW: (json['powerW'] as num?)?.toDouble() ?? 0.0,
      totalEnergyKwh: (json['totalEnergyKwh'] as num?)?.toDouble() ?? 0.0,
      intervalEnergyWh: (json['intervalEnergyWh'] as num?)?.toDouble(),
      frequencyHz: (json['frequencyHz'] as num?)?.toDouble() ?? 50.0,
      powerFactor: (json['powerFactor'] as num?)?.toDouble() ?? 1.0,
      flags: json['flags'] as int? ?? 0,
      sequenceNumber: json['sequenceNumber'] as int? ?? 0,
      timestamp: json['timestamp'] != null
          ? DateTime.parse(json['timestamp'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'deviceId': deviceId,
      'channelIndex': channelIndex,
      'voltageV': voltageV,
      'currentA': currentA,
      'powerW': powerW,
      'totalEnergyKwh': totalEnergyKwh,
      'intervalEnergyWh': intervalEnergyWh,
      'frequencyHz': frequencyHz,
      'powerFactor': powerFactor,
      'flags': flags,
      'sequenceNumber': sequenceNumber,
      'timestamp': timestamp.toIso8601String(),
    };
  }
}

/// Period-over-period comparison model
class EnergyPeriodComparison {
  final double currentPeriodEnergyKwh;
  final double previousPeriodEnergyKwh;
  final double deltaEnergyKwh;
  final double percentageChange;
  final TrendDirection trendDirection;

  const EnergyPeriodComparison({
    required this.currentPeriodEnergyKwh,
    required this.previousPeriodEnergyKwh,
    required this.deltaEnergyKwh,
    required this.percentageChange,
    required this.trendDirection,
  });

  factory EnergyPeriodComparison.fromJson(Map<String, dynamic> json) {
    return EnergyPeriodComparison(
      currentPeriodEnergyKwh: (json['currentPeriodEnergyKwh'] as num?)?.toDouble() ?? 0.0,
      previousPeriodEnergyKwh: (json['previousPeriodEnergyKwh'] as num?)?.toDouble() ?? 0.0,
      deltaEnergyKwh: (json['deltaEnergyKwh'] as num?)?.toDouble() ?? 0.0,
      percentageChange: (json['percentageChange'] as num?)?.toDouble() ?? 0.0,
      trendDirection: TrendDirection.fromString(json['trendDirection'] as String?),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'currentPeriodEnergyKwh': currentPeriodEnergyKwh,
      'previousPeriodEnergyKwh': previousPeriodEnergyKwh,
      'deltaEnergyKwh': deltaEnergyKwh,
      'percentageChange': percentageChange,
      'trendDirection': trendDirection.name.toUpperCase(),
    };
  }
}

/// Canonical Energy Usage Summary (Device, Room, or Home)
class EnergyUsageSummary {
  final int schemaVersion;
  final String entityType; // 'device' | 'room' | 'home'
  final String entityId;
  final String period;
  final double currentPowerW;
  final double totalEnergyKwh;
  final double peakPowerW;
  final double avgPowerW;
  final double? minPowerW;
  final double? costEstimate;
  final String currency;
  final EnergyPeriodComparison? comparison;
  final int devicesCount;
  final int roomsCount;
  final String dataQuality;
  final int sampleCount;
  final DateTime lastUpdated;

  const EnergyUsageSummary({
    this.schemaVersion = 1,
    required this.entityType,
    required this.entityId,
    required this.period,
    required this.currentPowerW,
    required this.totalEnergyKwh,
    required this.peakPowerW,
    required this.avgPowerW,
    this.minPowerW,
    this.costEstimate,
    this.currency = 'USD',
    this.comparison,
    this.devicesCount = 1,
    this.roomsCount = 0,
    this.dataQuality = 'GOOD',
    this.sampleCount = 0,
    required this.lastUpdated,
  });

  factory EnergyUsageSummary.fromJson(Map<String, dynamic> json) {
    return EnergyUsageSummary(
      schemaVersion: json['schemaVersion'] as int? ?? 1,
      entityType: json['entityType'] as String? ?? 'device',
      entityId: json['entityId'] as String? ?? '',
      period: json['period'] as String? ?? 'today',
      currentPowerW: (json['currentPowerW'] as num?)?.toDouble() ?? 0.0,
      totalEnergyKwh: (json['totalEnergyKwh'] as num?)?.toDouble() ?? 0.0,
      peakPowerW: (json['peakPowerW'] as num?)?.toDouble() ?? 0.0,
      avgPowerW: (json['avgPowerW'] as num?)?.toDouble() ?? 0.0,
      minPowerW: (json['minPowerW'] as num?)?.toDouble(),
      costEstimate: (json['costEstimate'] as num?)?.toDouble(),
      currency: json['currency'] as String? ?? 'USD',
      comparison: json['comparison'] != null
          ? EnergyPeriodComparison.fromJson(json['comparison'] as Map<String, dynamic>)
          : null,
      devicesCount: json['devicesCount'] as int? ?? 1,
      roomsCount: json['roomsCount'] as int? ?? 0,
      dataQuality: json['dataQuality'] as String? ?? 'GOOD',
      sampleCount: json['sampleCount'] as int? ?? 0,
      lastUpdated: json['lastUpdated'] != null
          ? DateTime.parse(json['lastUpdated'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'schemaVersion': schemaVersion,
      'entityType': entityType,
      'entityId': entityId,
      'period': period,
      'currentPowerW': currentPowerW,
      'totalEnergyKwh': totalEnergyKwh,
      'peakPowerW': peakPowerW,
      'avgPowerW': avgPowerW,
      'minPowerW': minPowerW,
      'costEstimate': costEstimate,
      'currency': currency,
      'comparison': comparison?.toJson(),
      'devicesCount': devicesCount,
      'roomsCount': roomsCount,
      'dataQuality': dataQuality,
      'sampleCount': sampleCount,
      'lastUpdated': lastUpdated.toIso8601String(),
    };
  }
}

/// Time-series point for trend visualization
class EnergyTrendPoint {
  final DateTime timestamp;
  final double energyKwh;
  final double avgPowerW;
  final double peakPowerW;
  final int sampleCount;

  const EnergyTrendPoint({
    required this.timestamp,
    required this.energyKwh,
    required this.avgPowerW,
    required this.peakPowerW,
    this.sampleCount = 1,
  });

  factory EnergyTrendPoint.fromJson(Map<String, dynamic> json) {
    return EnergyTrendPoint(
      timestamp: DateTime.parse(json['timestamp'] as String),
      energyKwh: (json['energyKwh'] as num?)?.toDouble() ?? 0.0,
      avgPowerW: (json['avgPowerW'] as num?)?.toDouble() ?? 0.0,
      peakPowerW: (json['peakPowerW'] as num?)?.toDouble() ?? 0.0,
      sampleCount: json['sampleCount'] as int? ?? 1,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'timestamp': timestamp.toIso8601String(),
      'energyKwh': energyKwh,
      'avgPowerW': avgPowerW,
      'peakPowerW': peakPowerW,
      'sampleCount': sampleCount,
    };
  }
}

/// Top Consumer breakdown model
class TopEnergyConsumer {
  final String id;
  final String name;
  final String type; // 'device' | 'room'
  final String? roomName;
  final double energyKwh;
  final double currentPowerW;
  final double percentageOfTotal;

  const TopEnergyConsumer({
    required this.id,
    required this.name,
    required this.type,
    this.roomName,
    required this.energyKwh,
    required this.currentPowerW,
    required this.percentageOfTotal,
  });

  factory TopEnergyConsumer.fromJson(Map<String, dynamic> json) {
    return TopEnergyConsumer(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      type: json['type'] as String? ?? 'device',
      roomName: json['roomName'] as String?,
      energyKwh: (json['energyKwh'] as num?)?.toDouble() ?? 0.0,
      currentPowerW: (json['currentPowerW'] as num?)?.toDouble() ?? 0.0,
      percentageOfTotal: (json['percentageOfTotal'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'type': type,
      'roomName': roomName,
      'energyKwh': energyKwh,
      'currentPowerW': currentPowerW,
      'percentageOfTotal': percentageOfTotal,
    };
  }
}

/// Configurable threshold model
class EnergyThresholdConfig {
  final String? id;
  final String homeId;
  final String? deviceId;
  final double? highPowerW;
  final double? dailyEnergyKwh;
  final double? monthlyEnergyKwh;
  final double costPerKwh;
  final String currency;
  final bool isEnabled;

  const EnergyThresholdConfig({
    this.id,
    required this.homeId,
    this.deviceId,
    this.highPowerW,
    this.dailyEnergyKwh,
    this.monthlyEnergyKwh,
    this.costPerKwh = 0.15,
    this.currency = 'USD',
    this.isEnabled = true,
  });

  factory EnergyThresholdConfig.fromJson(Map<String, dynamic> json) {
    return EnergyThresholdConfig(
      id: json['id'] as String?,
      homeId: json['home_id'] as String? ?? json['homeId'] as String? ?? '',
      deviceId: json['device_id'] as String? ?? json['deviceId'] as String?,
      highPowerW: (json['high_power_w'] ?? json['highPowerW'] as num?)?.toDouble(),
      dailyEnergyKwh: (json['daily_energy_kwh'] ?? json['dailyEnergyKwh'] as num?)?.toDouble(),
      monthlyEnergyKwh: (json['monthly_energy_kwh'] ?? json['monthlyEnergyKwh'] as num?)?.toDouble(),
      costPerKwh: (json['cost_per_kwh'] ?? json['costPerKwh'] as num?)?.toDouble() ?? 0.15,
      currency: json['currency'] as String? ?? 'USD',
      isEnabled: json['is_enabled'] == 1 || json['isEnabled'] == true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'homeId': homeId,
      'deviceId': deviceId,
      'highPowerW': highPowerW,
      'dailyEnergyKwh': dailyEnergyKwh,
      'monthlyEnergyKwh': monthlyEnergyKwh,
      'costPerKwh': costPerKwh,
      'currency': currency,
      'isEnabled': isEnabled,
    };
  }
}

/// Anomaly and high consumption event model
class EnergyAnomalyEvent {
  final String id;
  final String homeId;
  final String? deviceId;
  final String eventType;
  final String severity;
  final double valueRecorded;
  final double thresholdValue;
  final String message;
  final DateTime createdAt;

  const EnergyAnomalyEvent({
    required this.id,
    required this.homeId,
    this.deviceId,
    required this.eventType,
    required this.severity,
    required this.valueRecorded,
    required this.thresholdValue,
    required this.message,
    required this.createdAt,
  });

  factory EnergyAnomalyEvent.fromJson(Map<String, dynamic> json) {
    return EnergyAnomalyEvent(
      id: json['id'] as String? ?? '',
      homeId: json['home_id'] as String? ?? json['homeId'] as String? ?? '',
      deviceId: json['device_id'] as String? ?? json['deviceId'] as String?,
      eventType: json['event_type'] as String? ?? json['eventType'] as String? ?? '',
      severity: json['severity'] as String? ?? 'WARN',
      valueRecorded: (json['value_recorded'] ?? json['valueRecorded'] as num?)?.toDouble() ?? 0.0,
      thresholdValue: (json['threshold_value'] ?? json['thresholdValue'] as num?)?.toDouble() ?? 0.0,
      message: json['message'] as String? ?? '',
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : (json['createdAt'] != null ? DateTime.parse(json['createdAt'] as String) : DateTime.now()),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'homeId': homeId,
      'deviceId': deviceId,
      'eventType': eventType,
      'severity': severity,
      'valueRecorded': valueRecorded,
      'thresholdValue': thresholdValue,
      'message': message,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}
