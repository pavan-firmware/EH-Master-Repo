import 'package:flutter_test/flutter_test.dart';
import 'package:smart_home_application_v1/features/onboarding/models/onboarding_models.dart';
import 'package:smart_home_application_v1/features/onboarding/services/onboarding_service.dart';

void main() {
  group('Phase 5 Flutter Onboarding Models & Service Tests', () {
    test('OnboardingDeviceIdentity holds canonical device identity fields', () {
      const identity = OnboardingDeviceIdentity(
        deviceId: 'c0a80101-0000-4000-8000-000000000001',
        serialNumber: 'SN-EH-3X-2026',
        productVariantId: 'eh-smart-switch-3x',
        hardwareRevision: 'HW_1_0',
        firmwareFamily: 'esp32c6-switch-platform',
        displayName: 'EH Smart Switch 3X',
      );

      expect(identity.deviceId, 'c0a80101-0000-4000-8000-000000000001');
      expect(identity.serialNumber, 'SN-EH-3X-2026');
      expect(identity.productVariantId, 'eh-smart-switch-3x');
      expect(identity.hardwareRevision, 'HW_1_0');
      expect(identity.firmwareFamily, 'esp32c6-switch-platform');
    });

    test('DefaultOnboardingService validates EH1 QR payload prefix', () async {
      const service = DefaultOnboardingService();

      final invalidResult = await service.verifyQrCode('INVALID_QR_PAYLOAD');
      expect(invalidResult.hasFailed, isTrue);
      expect(invalidResult.errorMessage, contains('version prefix'));

      final validResult = await service.verifyQrCode('EH1:{"deviceId":"c0a80101-0000-4000-8000-000000000001"}');
      expect(validResult.hasFailed, isFalse);
      expect(validResult.stepState, OnboardingStepState.secureCommissioning);
      expect(validResult.identity?.deviceId, 'c0a80101-0000-4000-8000-000000000001');
    });

    test('DefaultOnboardingService manages commissioning, Wi-Fi provisioning, and claiming pipeline', () async {
      const service = DefaultOnboardingService();

      const identity = OnboardingDeviceIdentity(
        deviceId: 'c0a80101-0000-4000-8000-000000000001',
        serialNumber: 'SN-EH-3X-2026',
        productVariantId: 'eh-smart-switch-3x',
        hardwareRevision: 'HW_1_0',
        firmwareFamily: 'esp32c6-switch-platform',
        displayName: 'EH Smart Switch 3X',
      );

      final commResult = await service.startSecureCommissioning(identity);
      expect(commResult.stepState, OnboardingStepState.wifiProvisioning);
      expect(commResult.sessionId, isNotNull);

      final wifiResult = await service.provisionWifi(
        sessionId: commResult.sessionId!,
        ssid: 'MyHomeWiFi',
        password: 'Password123!',
      );
      expect(wifiResult.stepState, OnboardingStepState.deviceClaim);

      final claimResult = await service.claimAndAssignDevice(
        deviceId: identity.deviceId,
        sessionId: commResult.sessionId!,
        homeId: 'home_main',
        roomId: 'rm_living',
        customName: 'Living Room Switch',
      );
      expect(claimResult.isComplete, isTrue);
      expect(claimResult.homeId, 'home_main');
      expect(claimResult.roomId, 'rm_living');
    });
  });
}
