enum OnboardingStepState {
  discovery,
  verifyingIdentity,
  secureCommissioning,
  wifiProvisioning,
  deviceRegistration,
  deviceClaim,
  roomAssignment,
  complete,
  failed,
}

class OnboardingDeviceIdentity {
  const OnboardingDeviceIdentity({
    required this.deviceId,
    required this.serialNumber,
    required this.productVariantId,
    required this.hardwareRevision,
    required this.firmwareFamily,
    required this.displayName,
  });

  final String deviceId;
  final String serialNumber;
  final String productVariantId;
  final String hardwareRevision;
  final String firmwareFamily;
  final String displayName;
}

class OnboardingProgress {
  const OnboardingProgress({
    required this.stepState,
    this.identity,
    this.sessionId,
    this.homeId,
    this.roomId,
    this.customName,
    this.errorMessage,
  });

  final OnboardingStepState stepState;
  final OnboardingDeviceIdentity? identity;
  final String? sessionId;
  final String? homeId;
  final String? roomId;
  final String? customName;
  final String? errorMessage;

  bool get isComplete => stepState == OnboardingStepState.complete;
  bool get hasFailed => stepState == OnboardingStepState.failed;
}
