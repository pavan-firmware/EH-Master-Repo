import '../models/operational_readiness_models.dart';

abstract class OperationalReadinessRepository {
  Future<SystemReadinessModel> getSystemReadiness();
  Future<OperationalDiagnosticsModel> getOperationalDiagnostics();
}
