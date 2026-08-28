import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import '../ble/ble_commissioning_channel.dart';
import '../crypto/eh_prov1_crypto.dart';
import '../models/onboarding_models.dart';

class EhProv1Session {
  EhProv1Session({
    required this.sessionId,
    required this.appChallenge,
    this.deviceChallenge,
    this.sessionKey,
  });

  final String sessionId;
  final Uint8List appChallenge;
  Uint8List? deviceChallenge;
  Uint8List? sessionKey;
}

abstract class OnboardingService {
  Future<OnboardingProgress> verifyQrCode(String qrPayload);
  Future<OnboardingProgress> startSecureCommissioning(
    OnboardingDeviceIdentity identity,
  );
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
  const DefaultOnboardingService({this.channel});

  final BleCommissioningChannel? channel;

  static final Map<String, EhProv1Session> _activeSessions = {};

  static String _generateCanonicalUuid() {
    final rnd = Random.secure();
    final bytes = List<int>.generate(16, (_) => rnd.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40; // RFC 4122 v4
    bytes[8] = (bytes[8] & 0x3f) | 0x80; // Variant 1
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20, 32)}';
  }

  Uint8List _generateRandomBytes(int length) {
    final rnd = Random.secure();
    return Uint8List.fromList(
      List<int>.generate(length, (_) => rnd.nextInt(256)),
    );
  }

  Uint8List _parseSecretKey(String? secret) {
    final raw =
        secret ??
        'secret_32_byte_hex_string_for_device_qr_12345678901234567890';
    if (raw.length == 64 && RegExp(r'^[0-9a-fA-F]+$').hasMatch(raw)) {
      final bytes = <int>[];
      for (int i = 0; i < 64; i += 2) {
        bytes.add(int.parse(raw.substring(i, i + 2), radix: 16));
      }
      return Uint8List.fromList(bytes);
    }
    return Uint8List.fromList(utf8.encode(raw.padRight(32).substring(0, 32)));
  }

  @override
  Future<OnboardingProgress> verifyQrCode(String qrPayload) async {
    if (!qrPayload.startsWith('EH1:')) {
      return const OnboardingProgress(
        stepState: OnboardingStepState.failed,
        errorMessage:
            "Invalid QR payload version prefix. Expected 'EH1:<payload>'",
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
        deviceId:
            parsed['deviceId'] as String? ??
            'c0a80101-0000-4000-8000-000000000001',
        serialNumber: parsed['serialNumber'] as String? ?? 'SN-EH-3X-2026',
        productVariantId:
            parsed['productVariantId'] as String? ?? 'eh-smart-switch-3x',
        hardwareRevision: parsed['hardwareRevision'] as String? ?? 'HW_1_0',
        firmwareFamily:
            parsed['firmwareFamily'] as String? ?? 'esp32-switch-platform',
        displayName: 'EH Smart Switch 3X',
        commissioningSecret:
            parsed['commissioningSecret'] as String? ??
            'secret_32_byte_hex_string_for_device_qr_12345678901234567890',
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
  Future<OnboardingProgress> startSecureCommissioning(
    OnboardingDeviceIdentity identity,
  ) async {
    final sessionId = _generateCanonicalUuid();
    final appChallenge = _generateRandomBytes(32);
    final session = EhProv1Session(
      sessionId: sessionId,
      appChallenge: appChallenge,
    );
    _activeSessions[sessionId] = session;

    if (channel != null) {
      if (!channel!.isConnected) {
        try {
          await channel!.connect(identity.deviceId);
        } catch (err) {
          return OnboardingProgress(
            stepState: OnboardingStepState.failed,
            errorMessage:
                'Failed to connect to device commissioning service: $err',
          );
        }
      }
      if (channel!.isConnected) {
        try {
          final sessionBytes = utf8.encode(sessionId);
          final helloBuilder = BytesBuilder(copy: false)
            ..addByte(0) // EH_PROV1_MSG_HELLO
            ..add(sessionBytes)
            ..add(appChallenge);

          final response = await channel!.sendAndReceive(
            helloBuilder.takeBytes(),
            timeout: const Duration(seconds: 10),
          );

          if (response.length < 37 || response[0] != 1) {
            return const OnboardingProgress(
              stepState: OnboardingStepState.failed,
              errorMessage: 'Invalid HELLO_ACK received from device',
            );
          }
          session.deviceChallenge = Uint8List.fromList(response.sublist(1, 33));
        } catch (err) {
          return OnboardingProgress(
            stepState: OnboardingStepState.failed,
            errorMessage: 'BLE HELLO exchange failed: $err',
          );
        }
      }
    }

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
    final session = _activeSessions[sessionId];
    final appChallenge = session?.appChallenge ?? _generateRandomBytes(32);
    final effectiveDevChal = session?.deviceChallenge ?? deviceChallenge;
    final secretKey = _parseSecretKey(identity.commissioningSecret);

    final appTranscript = EhProv1Crypto.encodeCanonicalTranscript(
      messageType: 'APP_PROOF',
      sessionId: sessionId,
      deviceId: identity.deviceId,
      appChallenge: appChallenge,
      deviceChallenge: effectiveDevChal,
      sequenceNumber: 2,
    );
    final appProof = EhProv1Crypto.hmacSha256(secretKey, appTranscript);
    if (appProof.isEmpty) {
      return const OnboardingProgress(
        stepState: OnboardingStepState.failed,
        errorMessage: 'Failed to compute app proof',
      );
    }

    Uint8List receivedDeviceProof = Uint8List(32);

    if (channel != null && channel!.isConnected) {
      try {
        final authBuilder = BytesBuilder(copy: false)
          ..addByte(2) // EH_PROV1_MSG_AUTH
          ..add(appProof);

        final response = await channel!.sendAndReceive(
          authBuilder.takeBytes(),
          timeout: const Duration(seconds: 10),
        );

        if (response.length < 37 || response[0] != 3) {
          return const OnboardingProgress(
            stepState: OnboardingStepState.failed,
            errorMessage: 'Invalid AUTH_ACK received from device',
          );
        }
        receivedDeviceProof = Uint8List.fromList(response.sublist(1, 33));
      } catch (err) {
        return OnboardingProgress(
          stepState: OnboardingStepState.failed,
          errorMessage: 'BLE AUTH exchange failed: $err',
        );
      }
    } else {
      // Local/offline test path
      final devTranscript = EhProv1Crypto.encodeCanonicalTranscript(
        messageType: 'DEVICE_PROOF',
        sessionId: sessionId,
        deviceId: identity.deviceId,
        appChallenge: appChallenge,
        deviceChallenge: effectiveDevChal,
        sequenceNumber: 3,
      );
      receivedDeviceProof = EhProv1Crypto.hmacSha256(secretKey, devTranscript);
    }

    final expectedDeviceTranscript = EhProv1Crypto.encodeCanonicalTranscript(
      messageType: 'DEVICE_PROOF',
      sessionId: sessionId,
      deviceId: identity.deviceId,
      appChallenge: appChallenge,
      deviceChallenge: effectiveDevChal,
      sequenceNumber: 3,
    );
    final expectedDeviceProof = EhProv1Crypto.hmacSha256(
      secretKey,
      expectedDeviceTranscript,
    );

    final isValid = EhProv1Crypto.constantTimeCompare(
      receivedDeviceProof,
      expectedDeviceProof,
    );
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

    final session = _activeSessions[sessionId];
    final effectiveAppChal = session?.appChallenge ?? appChallenge;
    final effectiveDevChal = session?.deviceChallenge ?? deviceChallenge;

    final secretKey = _parseSecretKey(identity.commissioningSecret);
    final salt = Uint8List(64)
      ..setAll(0, effectiveAppChal)
      ..setAll(32, effectiveDevChal);
    final info = Uint8List.fromList(
      utf8.encode('EH-PROV/1|WIFI|$sessionId|${identity.deviceId}'),
    );

    final sessionKey = EhProv1Crypto.hkdfSha256(
      ikm: secretKey,
      salt: salt,
      info: info,
      outputLength: 32,
    );
    session?.sessionKey = sessionKey;

    final nonce = _generateRandomBytes(12);
    final aad = EhProv1Crypto.encodeCanonicalTranscript(
      messageType: 'WIFI',
      sessionId: sessionId,
      deviceId: identity.deviceId,
      appChallenge: effectiveAppChal,
      deviceChallenge: effectiveDevChal,
      sequenceNumber: 4,
    );
    final plaintext = Uint8List.fromList(
      utf8.encode(jsonEncode({'s': ssid, 'p': password})),
    );

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

    if (channel != null && channel!.isConnected) {
      try {
        final wifiBuilder = BytesBuilder(copy: false)
          ..addByte(4) // EH_PROV1_MSG_WIFI_CRED
          ..add(nonce)
          ..add(encryptedPayload);

        final response = await channel!.sendAndReceive(
          wifiBuilder.takeBytes(),
          timeout: const Duration(seconds: 15),
        );

        if (response.isEmpty ||
            response[0] != 5 ||
            (response.length > 1 && response[1] != 1)) {
          return const OnboardingProgress(
            stepState: OnboardingStepState.failed,
            errorMessage: 'Wi-Fi credential provisioning rejected by device',
          );
        }
      } catch (err) {
        return OnboardingProgress(
          stepState: OnboardingStepState.failed,
          errorMessage: 'BLE Wi-Fi provisioning exchange failed: $err',
        );
      }
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

    _activeSessions.remove(sessionId);

    return OnboardingProgress(
      stepState: OnboardingStepState.complete,
      sessionId: sessionId,
      homeId: homeId,
      roomId: roomId,
      customName: customName,
    );
  }
}
