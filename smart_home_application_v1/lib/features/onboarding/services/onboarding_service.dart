import 'dart:async';
import '../models/onboarding_models.dart';

abstract class OnboardingService {
  Future<OnboardingProgress> verifyQrCode(String qrPayload);
  Future<OnboardingProgress> startSecureCommissioning(OnboardingDeviceIdentity identity);
  Future<OnboardingProgress> provisionWifi({
    required String sessionId,
    required String ssid,
    required String password,
  });
  Future<OnboardingProgress> claimAndAssignDevice({
    required String deviceId,
    required String sessionId,
    required String homeId,
    String? roomId,
    String? customName,
  });
}

class DefaultOnboardingService implements OnboardingService {
  const DefaultOnboardingService();

  @override
  Future<OnboardingProgress> verifyQrCode(String qrPayload) async {
    if (!qrPayload.startsWith('EH1:')) {
      return const OnboardingProgress(
        stepState: OnboardingStepState.failed,
        errorMessage: "Invalid QR payload version prefix. Expected 'EH1:<payload>'",
      );
    }

    // Mock/Parse valid identity
    const identity = OnboardingDeviceIdentity(
      deviceId: 'c0a80101-0000-4000-8000-000000000001',
      serialNumber: 'SN-EH-3X-2026',
      productVariantId: 'eh-smart-switch-3x',
      hardwareRevision: 'HW_1_0',
      firmwareFamily: 'esp32c6-switch-platform',
      displayName: 'EH Smart Switch 3X',
    );

    return const OnboardingProgress(
      stepState: OnboardingStepState.secureCommissioning,
      identity: identity,
    );
  }

  @override
  Future<OnboardingProgress> startSecureCommissioning(OnboardingDeviceIdentity identity) async {
    final sessionId = 'sess_${identity.deviceId.substring(0, 8)}';
    return OnboardingProgress(
      stepState: OnboardingStepState.wifiProvisioning,
      identity: identity,
      sessionId: sessionId,
    );
  }

  @override
  Future<OnboardingProgress> provisionWifi({
    required String sessionId,
    required String ssid,
    required String password,
  }) async {
    if (ssid.trim().isEmpty) {
      return const OnboardingProgress(
        stepState: OnboardingStepState.failed,
        errorMessage: 'Wi-Fi SSID is required',
      );
    }

    return OnboardingProgress(
      stepState: OnboardingStepState.deviceClaim,
      sessionId: sessionId,
    );
  }

  @override
  Future<OnboardingProgress> claimAndAssignDevice({
    required String deviceId,
    required String sessionId,
    required String homeId,
    String? roomId,
    String? customName,
  }) async {
    if (homeId.trim().isEmpty) {
      return const OnboardingProgress(
        stepState: OnboardingStepState.failed,
        errorMessage: 'Home assignment is required to complete claiming',
      );
    }

    return OnboardingProgress(
      stepState: OnboardingStepState.complete,
      sessionId: sessionId,
      homeId: homeId,
      roomId: roomId,
      customName: customName,
    );
  }
}
