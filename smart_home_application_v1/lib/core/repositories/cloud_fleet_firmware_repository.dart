import '../api/api_client.dart';
import '../models/fleet_models.dart';
import 'fleet_firmware_repository.dart';

class CloudFleetFirmwareRepository implements FleetFirmwareRepository {
  const CloudFleetFirmwareRepository(this._apiClient);

  final ApiClient _apiClient;

  String _buildQuery(String path, Map<String, String> queryParams) {
    if (queryParams.isEmpty) return path;
    final query = queryParams.entries
        .map((e) => '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
        .join('&');
    return '$path?$query';
  }

  @override
  Future<List<FirmwareReleaseModel>> listReleases({String? productVariantId, String? releaseChannel}) async {
    final queryParams = <String, String>{};
    if (productVariantId != null) queryParams['productVariantId'] = productVariantId;
    if (releaseChannel != null) queryParams['releaseChannel'] = releaseChannel;

    final url = _buildQuery('/api/v1/admin/firmware/releases', queryParams);
    final response = await _apiClient.get(url);
    final list = (response is Map ? (response['data'] as List<dynamic>?) : null) ??
        (response is List ? response : <dynamic>[]);
    return list.map((item) => FirmwareReleaseModel.fromJson(item as Map<String, dynamic>)).toList();
  }

  @override
  Future<FirmwareReleaseModel> createRelease(Map<String, dynamic> manifest) async {
    final response = await _apiClient.post('/api/v1/admin/firmware/releases', body: manifest);
    final data = (response is Map ? (response['data'] as Map<String, dynamic>?) : null) ?? (response as Map<String, dynamic>);
    return FirmwareReleaseModel.fromJson(data);
  }

  @override
  Future<FirmwareReleaseModel> publishRelease(String releaseId) async {
    final response = await _apiClient.post('/api/v1/admin/firmware/releases/$releaseId/publish');
    final data = (response is Map ? (response['data'] as Map<String, dynamic>?) : null) ?? (response as Map<String, dynamic>);
    return FirmwareReleaseModel.fromJson(data);
  }

  @override
  Future<List<OtaRolloutModel>> listRollouts({String? releaseId, String? rolloutState}) async {
    final queryParams = <String, String>{};
    if (releaseId != null) queryParams['releaseId'] = releaseId;
    if (rolloutState != null) queryParams['rolloutState'] = rolloutState;

    final url = _buildQuery('/api/v1/admin/ota/rollouts', queryParams);
    final response = await _apiClient.get(url);
    final list = (response is Map ? (response['data'] as List<dynamic>?) : null) ??
        (response is List ? response : <dynamic>[]);
    return list.map((item) => OtaRolloutModel.fromJson(item as Map<String, dynamic>)).toList();
  }

  @override
  Future<OtaRolloutModel> createRollout(Map<String, dynamic> data) async {
    final response = await _apiClient.post('/api/v1/admin/ota/rollouts', body: data);
    final resData = (response is Map ? (response['data'] as Map<String, dynamic>?) : null) ?? (response as Map<String, dynamic>);
    return OtaRolloutModel.fromJson(resData);
  }

  @override
  Future<OtaRolloutModel> startRollout(String rolloutId) async {
    final response = await _apiClient.post('/api/v1/admin/ota/rollouts/$rolloutId/start');
    final data = (response is Map ? (response['data'] as Map<String, dynamic>?) : null) ?? (response as Map<String, dynamic>);
    return OtaRolloutModel.fromJson(data);
  }

  @override
  Future<OtaRolloutModel> pauseRollout(String rolloutId, {String? reason}) async {
    final response = await _apiClient.post('/api/v1/admin/ota/rollouts/$rolloutId/pause', body: {'reason': reason ?? 'Operator paused'});
    final data = (response is Map ? (response['data'] as Map<String, dynamic>?) : null) ?? (response as Map<String, dynamic>);
    return OtaRolloutModel.fromJson(data);
  }

  @override
  Future<OtaRolloutModel> resumeRollout(String rolloutId) async {
    final response = await _apiClient.post('/api/v1/admin/ota/rollouts/$rolloutId/resume');
    final data = (response is Map ? (response['data'] as Map<String, dynamic>?) : null) ?? (response as Map<String, dynamic>);
    return OtaRolloutModel.fromJson(data);
  }

  @override
  Future<OtaRolloutModel> cancelRollout(String rolloutId, {String? reason}) async {
    final response = await _apiClient.post('/api/v1/admin/ota/rollouts/$rolloutId/cancel', body: {'reason': reason ?? 'Operator cancelled'});
    final data = (response is Map ? (response['data'] as Map<String, dynamic>?) : null) ?? (response as Map<String, dynamic>);
    return OtaRolloutModel.fromJson(data);
  }

  @override
  Future<Map<String, dynamic>> initiateRollback(String rolloutId, {String? targetReleaseId, String? reason}) async {
    final body = <String, dynamic>{
      'reason': reason ?? 'Operator initiated rollback',
    };
    if (targetReleaseId != null) {
      body['targetReleaseId'] = targetReleaseId;
    }
    final response = await _apiClient.post(
      '/api/v1/admin/ota/rollouts/$rolloutId/rollback',
      body: body,
    );
    return (response is Map ? (response['data'] as Map<String, dynamic>?) : null) ?? (response as Map<String, dynamic>);
  }

  @override
  Future<Map<String, dynamic>> executeBatch(String rolloutId) async {
    final response = await _apiClient.post('/api/v1/admin/ota/rollouts/$rolloutId/execute-batch');
    return (response is Map ? (response['data'] as Map<String, dynamic>?) : null) ?? (response as Map<String, dynamic>);
  }

  @override
  Future<List<FleetDeviceFirmwareStateModel>> listFleetFirmwareStates({String? productVariantId, String? rolloutId}) async {
    final queryParams = <String, String>{};
    if (productVariantId != null) queryParams['productVariantId'] = productVariantId;
    if (rolloutId != null) queryParams['rolloutId'] = rolloutId;

    final url = _buildQuery('/api/v1/admin/fleet/firmware-state', queryParams);
    final response = await _apiClient.get(url);
    final list = (response is Map ? (response['data'] as List<dynamic>?) : null) ??
        (response is List ? response : <dynamic>[]);
    return list.map((item) => FleetDeviceFirmwareStateModel.fromJson(item as Map<String, dynamic>)).toList();
  }

  @override
  Future<FleetDeviceFirmwareStateModel?> getDeviceFirmwareState(String deviceId) async {
    final response = await _apiClient.get('/api/v1/admin/fleet/firmware-state/$deviceId');
    final data = (response is Map ? (response['data'] as Map<String, dynamic>?) : null);
    if (data == null) return null;
    return FleetDeviceFirmwareStateModel.fromJson(data);
  }
}
