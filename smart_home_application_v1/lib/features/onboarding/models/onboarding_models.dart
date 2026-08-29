enum OnboardingStepState {
  discovery,
  scanning,
  bleConnecting,
  discoveringGatt,
  verifyingIdentity,
  secureCommissioning,
  provingIdentity,
  wifiProvisioning,
  sendingWifi,
  awaitingMtlsConfirm,
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
    this.commissioningSecret,
  });

  final String deviceId;
  final String serialNumber;
  final String productVariantId;
  final String hardwareRevision;
  final String firmwareFamily;
  final String displayName;
  final String? commissioningSecret;

  OnboardingDeviceIdentity copyWith({
    String? deviceId,
    String? serialNumber,
    String? productVariantId,
    String? hardwareRevision,
    String? firmwareFamily,
    String? displayName,
    String? commissioningSecret,
  }) {
    return OnboardingDeviceIdentity(
      deviceId: deviceId ?? this.deviceId,
      serialNumber: serialNumber ?? this.serialNumber,
      productVariantId: productVariantId ?? this.productVariantId,
      hardwareRevision: hardwareRevision ?? this.hardwareRevision,
      firmwareFamily: firmwareFamily ?? this.firmwareFamily,
      displayName: displayName ?? this.displayName,
      commissioningSecret: commissioningSecret ?? this.commissioningSecret,
    );
  }
}

class EhProv1Session {
  const EhProv1Session({
    required this.sessionId,
    required this.appChallenge,
    required this.identity,
    this.deviceChallenge,
    this.sessionKey,
  });

  final String sessionId;
  final List<int> appChallenge;
  final OnboardingDeviceIdentity identity;
  final List<int>? deviceChallenge;
  final List<int>? sessionKey;

  EhProv1Session copyWith({
    String? sessionId,
    List<int>? appChallenge,
    OnboardingDeviceIdentity? identity,
    List<int>? deviceChallenge,
    List<int>? sessionKey,
  }) {
    return EhProv1Session(
      sessionId: sessionId ?? this.sessionId,
      appChallenge: appChallenge ?? this.appChallenge,
      identity: identity ?? this.identity,
      deviceChallenge: deviceChallenge ?? this.deviceChallenge,
      sessionKey: sessionKey ?? this.sessionKey,
    );
  }
}

class OnboardingProgress {
  const OnboardingProgress({
    required this.stepState,
    this.identity,
    this.sessionId,
    this.session,
    this.homeId,
    this.roomId,
    this.customName,
    this.errorMessage,
  });

  final OnboardingStepState stepState;
  final OnboardingDeviceIdentity? identity;
  final String? sessionId;
  final EhProv1Session? session;
  final String? homeId;
  final String? roomId;
  final String? customName;
  final String? errorMessage;

  bool get isComplete => stepState == OnboardingStepState.complete;
  bool get hasFailed => stepState == OnboardingStepState.failed;
}
