import '../models/fleet_models.dart';

abstract class FleetFirmwareRepository {
  Future<List<FirmwareReleaseModel>> listReleases({String? productVariantId, String? releaseChannel});
  Future<FirmwareReleaseModel> createRelease(Map<String, dynamic> manifest);
  Future<FirmwareReleaseModel> publishRelease(String releaseId);
  Future<List<OtaRolloutModel>> listRollouts({String? releaseId, String? rolloutState});
  Future<OtaRolloutModel> createRollout(Map<String, dynamic> data);
  Future<OtaRolloutModel> startRollout(String rolloutId);
  Future<OtaRolloutModel> pauseRollout(String rolloutId, {String? reason});
  Future<OtaRolloutModel> resumeRollout(String rolloutId);
  Future<OtaRolloutModel> cancelRollout(String rolloutId, {String? reason});
  Future<Map<String, dynamic>> initiateRollback(String rolloutId, {String? targetReleaseId, String? reason});
  Future<Map<String, dynamic>> executeBatch(String rolloutId);
  Future<List<FleetDeviceFirmwareStateModel>> listFleetFirmwareStates({String? productVariantId, String? rolloutId});
  Future<FleetDeviceFirmwareStateModel?> getDeviceFirmwareState(String deviceId);
}
