import '../models/device_trust_models.dart';

/// Abstract repository contract for Device Trust and Credential Lifecycle
abstract class DeviceTrustRepository {
  Future<DeviceTrustStateModel> getTrustState(String deviceId);

  Future<DeviceTrustStateModel> quarantineDevice(
    String deviceId, {
    required String reason,
    Map<String, dynamic>? evidence,
  });

  Future<DeviceRevocationModel> revokeDevice(
    String deviceId, {
    required String reason,
    String revocationType = 'COMPROMISED',
    bool remediationAllowed = false,
  });

  Future<DeviceTrustStateModel> restoreTrust(
    String deviceId, {
    required String reason,
    bool attestationVerified = true,
  });

  Future<DeviceCredentialLifecycleModel> initiateRotation(
    String deviceId, {
    required String keyIdentifier,
    String credentialType = 'MQTT',
  });

  Future<DeviceCredentialLifecycleModel> confirmRotation(
    String deviceId, {
    required String rotationId,
    Map<String, dynamic>? evidence,
  });

  Future<DeviceSecurityHistoryModel> getSecurityHistory(String deviceId);
}
