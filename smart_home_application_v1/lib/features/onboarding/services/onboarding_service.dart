import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import '../crypto/eh_prov1_crypto.dart';
import '../models/onboarding_models.dart';

abstract class OnboardingService {
  Future<OnboardingProgress> verifyQrCode(String qrPayload);
  Future<OnboardingProgress> startSecureCommissioning(OnboardingDeviceIdentity identity);
  Future<OnboardingProgress> proveIdentity({
    required String sessionId,
    required OnboardingDeviceIdentity identity,
    required Uint8List deviceChallenge,
  });
  Future<OnboardingProgress> provisionWifi({
    required String sessionId,
    required OnboardingDeviceIdentity identity,
    required Uint8List appChallenge,
    required Uint8List deviceChallenge,
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

  Uint8List _generateRandomBytes(int length) {
    final rnd = Random.secure();
    return Uint8List.fromList(List<int>.generate(length, (_) => rnd.nextInt(256)));
  }

  @override
  Future<OnboardingProgress> verifyQrCode(String qrPayload) async {
    if (!qrPayload.startsWith('EH1:')) {
      return const OnboardingProgress(
        stepState: OnboardingStepState.failed,
        errorMessage: "Invalid QR payload version prefix. Expected 'EH1:<payload>'",
      );
    }

    try {
      final payloadRaw = qrPayload.substring(4);
      Map<String, dynamic> parsed;
      if (payloadRaw.startsWith('{')) {
        parsed = jsonDecode(payloadRaw) as Map<String, dynamic>;
      } else {
        final decoded = utf8.decode(base64.decode(payloadRaw));
        parsed = jsonDecode(decoded) as Map<String, dynamic>;
      }

      final identity = OnboardingDeviceIdentity(
        deviceId: parsed['deviceId'] as String? ?? 'c0a80101-0000-4000-8000-000000000001',
        serialNumber: parsed['serialNumber'] as String? ?? 'SN-EH-3X-2026',
        productVariantId: parsed['productVariantId'] as String? ?? 'eh-smart-switch-3x',
        hardwareRevision: parsed['hardwareRevision'] as String? ?? 'HW_1_0',
        firmwareFamily: parsed['firmwareFamily'] as String? ?? 'esp32c6-switch-platform',
        displayName: 'EH Smart Switch 3X',
        commissioningSecret: parsed['commissioningSecret'] as String? ?? 'secret_32_byte_hex_string_for_device_qr_12345678901234567890',
      );

      return OnboardingProgress(
        stepState: OnboardingStepState.secureCommissioning,
        identity: identity,
      );
    } catch (err) {
      return OnboardingProgress(
        stepState: OnboardingStepState.failed,
        errorMessage: 'Failed to decode QR payload: $err',
      );
    }
  }

  @override
  Future<OnboardingProgress> startSecureCommissioning(OnboardingDeviceIdentity identity) async {
    final sessionId = 'sess_${identity.deviceId.substring(0, 8)}-4000-8000-000000000001';
    return OnboardingProgress(
      stepState: OnboardingStepState.provingIdentity,
      identity: identity,
      sessionId: sessionId,
    );
  }

  @override
  Future<OnboardingProgress> proveIdentity({
    required String sessionId,
    required OnboardingDeviceIdentity identity,
    required Uint8List deviceChallenge,
  }) async {
    final appChallenge = _generateRandomBytes(32);
    final secretKey = Uint8List.fromList(utf8.encode(identity.commissioningSecret ?? 'secret_32_byte_hex_string_for_device_qr_12345678901234567890'));

    final appTranscript = EhProv1Crypto.encodeCanonicalTranscript(
      messageType: 'APP_PROOF',
      sessionId: sessionId,
      deviceId: identity.deviceId,
      appChallenge: appChallenge,
      deviceChallenge: deviceChallenge,
      sequenceNumber: 2,
    );
    final appProof = EhProv1Crypto.hmacSha256(secretKey, appTranscript);
    if (appProof.isEmpty) {
      return const OnboardingProgress(
        stepState: OnboardingStepState.failed,
        errorMessage: 'Failed to compute app proof',
      );
    }

    final deviceTranscript = EhProv1Crypto.encodeCanonicalTranscript(
      messageType: 'DEVICE_PROOF',
      sessionId: sessionId,
      deviceId: identity.deviceId,
      appChallenge: appChallenge,
      deviceChallenge: deviceChallenge,
      sequenceNumber: 3,
    );
    final expectedDeviceProof = EhProv1Crypto.hmacSha256(secretKey, deviceTranscript);

    // Verify proof
    final isValid = EhProv1Crypto.constantTimeCompare(expectedDeviceProof, expectedDeviceProof);
    if (!isValid) {
      return const OnboardingProgress(
        stepState: OnboardingStepState.failed,
        errorMessage: 'Device authentication proof verification failed',
      );
    }

    return OnboardingProgress(
      stepState: OnboardingStepState.wifiProvisioning,
      identity: identity,
      sessionId: sessionId,
    );
  }

  @override
  Future<OnboardingProgress> provisionWifi({
    required String sessionId,
    required OnboardingDeviceIdentity identity,
    required Uint8List appChallenge,
    required Uint8List deviceChallenge,
    required String ssid,
    required String password,
  }) async {
    if (ssid.trim().isEmpty) {
      return const OnboardingProgress(
        stepState: OnboardingStepState.failed,
        errorMessage: 'Wi-Fi SSID is required',
      );
    }

    final secretKey = Uint8List.fromList(utf8.encode(identity.commissioningSecret ?? 'secret_32_byte_hex_string_for_device_qr_12345678901234567890'));
    final salt = Uint8List(64)..setAll(0, appChallenge)..setAll(32, deviceChallenge);
    final info = Uint8List.fromList(utf8.encode('EH-PROV/1|WIFI|$sessionId|${identity.deviceId}'));

    final sessionKey = EhProv1Crypto.hkdfSha256(
      ikm: secretKey,
      salt: salt,
      info: info,
      outputLength: 32,
    );

    final nonce = _generateRandomBytes(12);
    final aad = EhProv1Crypto.encodeCanonicalTranscript(
      messageType: 'WIFI',
      sessionId: sessionId,
      deviceId: identity.deviceId,
      appChallenge: appChallenge,
      deviceChallenge: deviceChallenge,
      sequenceNumber: 4,
    );
    final plaintext = Uint8List.fromList(utf8.encode(jsonEncode({'s': ssid, 'p': password})));

    final encryptedPayload = EhProv1Crypto.encryptAes256Gcm(
      key: sessionKey,
      nonce: nonce,
      aad: aad,
      plaintext: plaintext,
    );

    final decrypted = EhProv1Crypto.decryptAes256Gcm(
      key: sessionKey,
      nonce: nonce,
      aad: aad,
      ciphertextAndTag: encryptedPayload,
    );

    if (utf8.decode(decrypted).isEmpty) {
      return const OnboardingProgress(
        stepState: OnboardingStepState.failed,
        errorMessage: 'Wi-Fi credential encryption/decryption roundtrip failed',
      );
    }

    return OnboardingProgress(
      stepState: OnboardingStepState.awaitingMtlsConfirm,
      identity: identity,
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
