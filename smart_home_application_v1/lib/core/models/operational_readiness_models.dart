// EH Home — Operational Readiness Models (Phase 34)
//
// Typed Dart data structures for system readiness, health probes,
// dependency checks, and administrative diagnostics.

class SystemReadinessModel {
  const SystemReadinessModel({
    required this.status,
    required this.service,
    required this.version,
    required this.timestamp,
    this.schemaVersionNumber,
    this.latestMigration,
    this.uptimeSeconds = 0.0,
    required this.checks,
    this.metadata,
  });

  final String status;
  final String service;
  final String version;
  final String timestamp;
  final int? schemaVersionNumber;
  final String? latestMigration;
  final double uptimeSeconds;
  final Map<String, dynamic> checks;
  final Map<String, dynamic>? metadata;

  bool get isReady => status == 'READY' || status == 'DEGRADED';
  bool get isDegraded => status == 'DEGRADED';
  bool get isNotReady => status == 'NOT_READY' || status == 'STARTING' || status == 'SHUTTING_DOWN';

  String get databaseCheck => checks['database']?.toString() ?? 'UNKNOWN';
  String get redisCheck => checks['redis']?.toString() ?? 'STANDBY';
  String get mqttCheck => checks['mqtt']?.toString() ?? 'STANDBY';
  String get workersCheck => checks['workers']?.toString() ?? 'STANDBY';

  factory SystemReadinessModel.fromJson(Map<String, dynamic> json) {
    return SystemReadinessModel(
      status: json['status'] as String? ?? 'UNKNOWN',
      service: json['service'] as String? ?? 'eh-home-backend',
      version: json['version'] as String? ?? '1.0.0',
      timestamp: json['timestamp'] as String? ?? DateTime.now().toUtc().toIso8601String(),
      schemaVersionNumber: json['schema_version'] as int? ?? json['schemaVersion'] as int?,
      latestMigration: json['migration_version'] as String?,
      uptimeSeconds: (json['uptimeSeconds'] as num?)?.toDouble() ?? 0.0,
      checks: (json['checks'] as Map<String, dynamic>?) ?? {},
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'schemaVersion': 1,
      'status': status,
      'service': service,
      'version': version,
      'schema_version': schemaVersionNumber,
      'migration_version': latestMigration,
      'timestamp': timestamp,
      'uptimeSeconds': uptimeSeconds,
      'checks': checks,
      if (metadata != null) 'metadata': metadata,
    };
  }
}

class OperationalDiagnosticsModel {
  const OperationalDiagnosticsModel({
    required this.service,
    required this.version,
    required this.environment,
    required this.lifecycleState,
    required this.uptimeSeconds,
    required this.timestamp,
    this.flutterAppVersion = '0.1.0+1',
    this.release = const {},
    this.dependencies = const {},
    this.process = const {},
    this.features = const {},
    this.runtimeConfigSummary = const {},
  });

  final String service;
  final String version;
  final String environment;
  final String lifecycleState;
  final int uptimeSeconds;
  final String timestamp;
  final String flutterAppVersion;
  final Map<String, dynamic> release;
  final Map<String, dynamic> dependencies;
  final Map<String, dynamic> process;
  final Map<String, dynamic> features;
  final Map<String, dynamic> runtimeConfigSummary;

  factory OperationalDiagnosticsModel.fromJson(Map<String, dynamic> json) {
    return OperationalDiagnosticsModel(
      service: json['service'] as String? ?? 'eh-home-backend',
      version: json['version'] as String? ?? '1.0.0',
      environment: json['environment'] as String? ?? 'development',
      lifecycleState: json['lifecycleState'] as String? ?? 'READY',
      uptimeSeconds: (json['uptimeSeconds'] as num?)?.toInt() ?? 0,
      timestamp: json['timestamp'] as String? ?? DateTime.now().toUtc().toIso8601String(),
      flutterAppVersion: json['flutterAppVersion'] as String? ?? '0.1.0+1',
      release: (json['release'] as Map<String, dynamic>?) ?? {},
      dependencies: (json['dependencies'] as Map<String, dynamic>?) ?? {},
      process: (json['process'] as Map<String, dynamic>?) ?? {},
      features: (json['features'] as Map<String, dynamic>?) ?? {},
      runtimeConfigSummary: (json['runtimeConfigSummary'] as Map<String, dynamic>?) ?? {},
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'schemaVersion': 1,
      'service': service,
      'version': version,
      'flutterAppVersion': flutterAppVersion,
      'environment': environment,
      'lifecycleState': lifecycleState,
      'uptimeSeconds': uptimeSeconds,
      'timestamp': timestamp,
      'release': release,
      'dependencies': dependencies,
      'process': process,
      'features': features,
      'runtimeConfigSummary': runtimeConfigSummary,
    };
  }
}
