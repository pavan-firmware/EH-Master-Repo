import '../api/api_client.dart';
import '../models/device_trust_models.dart';
import 'device_trust_repository.dart';

class CloudDeviceTrustRepository implements DeviceTrustRepository {
  const CloudDeviceTrustRepository(this._apiClient);

  final ApiClient _apiClient;

  @override
  Future<DeviceTrustStateModel> getTrustState(String deviceId) async {
    final response = await _apiClient.get('/api/v1/devices/$deviceId/trust');
    final data = (response['data'] as Map<String, dynamic>?) ?? response;
    return DeviceTrustStateModel.fromJson(data);
  }

  @override
  Future<DeviceTrustStateModel> quarantineDevice(
    String deviceId, {
    required String reason,
    Map<String, dynamic>? evidence,
  }) async {
    final body = <String, dynamic>{
      'reason': reason,
    };
    if (evidence != null) {
      body['evidence'] = evidence;
    }

    final response = await _apiClient.post(
      '/api/v1/devices/$deviceId/quarantine',
      body: body,
    );
    final data = (response['data'] as Map<String, dynamic>?) ?? response;
    return DeviceTrustStateModel.fromJson(data);
  }

  @override
  Future<DeviceRevocationModel> revokeDevice(
    String deviceId, {
    required String reason,
    String revocationType = 'COMPROMISED',
    bool remediationAllowed = false,
  }) async {
    final response = await _apiClient.post(
      '/api/v1/devices/$deviceId/revoke',
      body: {
        'reason': reason,
        'revocationType': revocationType,
        'remediationAllowed': remediationAllowed,
      },
    );
    final data = (response['data'] as Map<String, dynamic>?) ?? response;
    return DeviceRevocationModel.fromJson(data);
  }

  @override
  Future<DeviceTrustStateModel> restoreTrust(
    String deviceId, {
    required String reason,
    bool attestationVerified = true,
  }) async {
    final response = await _apiClient.post(
      '/api/v1/devices/$deviceId/restore-trust',
      body: {
        'reason': reason,
        'attestationVerified': attestationVerified,
        'targetState': 'TRUSTED',
      },
    );
    final data = (response['data'] as Map<String, dynamic>?) ?? response;
    return DeviceTrustStateModel.fromJson(data);
  }

  @override
  Future<DeviceCredentialLifecycleModel> initiateRotation(
    String deviceId, {
    required String keyIdentifier,
    String credentialType = 'MQTT',
  }) async {
    final response = await _apiClient.post(
      '/api/v1/devices/$deviceId/credentials/rotate',
      body: {
        'keyIdentifier': keyIdentifier,
        'credentialType': credentialType,
      },
    );
    final data = (response['data'] as Map<String, dynamic>?) ?? response;
    final recordJson = (data['lifecycleRecord'] as Map<String, dynamic>?) ?? data;
    return DeviceCredentialLifecycleModel.fromJson(recordJson);
  }

  @override
  Future<DeviceCredentialLifecycleModel> confirmRotation(
    String deviceId, {
    required String rotationId,
    Map<String, dynamic>? evidence,
  }) async {
    final body = <String, dynamic>{
      'rotationId': rotationId,
    };
    if (evidence != null) {
      body['confirmationEvidence'] = evidence;
    }

    final response = await _apiClient.post(
      '/api/v1/devices/$deviceId/credentials/confirm-rotation',
      body: body,
    );
    final data = (response['data'] as Map<String, dynamic>?) ?? response;
    return DeviceCredentialLifecycleModel.fromJson(data);
  }

  @override
  Future<DeviceSecurityHistoryModel> getSecurityHistory(String deviceId) async {
    final response = await _apiClient.get('/api/v1/devices/$deviceId/security-history');
    final data = (response['data'] as Map<String, dynamic>?) ?? response;
    return DeviceSecurityHistoryModel.fromJson(data);
  }
}
