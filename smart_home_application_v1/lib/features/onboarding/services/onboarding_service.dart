import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import '../ble/ble_commissioning_channel.dart';
import '../crypto/eh_prov1_crypto.dart';
import '../models/onboarding_models.dart';

abstract class OnboardingService {
  Future<OnboardingProgress> verifyQrCode(String qrPayload);
  Future<OnboardingProgress> startSecureCommissioning(
    OnboardingDeviceIdentity identity, {
    String? fixedSessionId,
    Uint8List? fixedAppChallenge,
  });
  Future<OnboardingProgress> proveIdentity({
    required String sessionId,
    required OnboardingDeviceIdentity identity,
    required Uint8List deviceChallenge,
    Uint8List? appChallenge,
    EhProv1Session? session,
  });
  Future<OnboardingProgress> provisionWifi({
    required String sessionId,
    required OnboardingDeviceIdentity identity,
    required Uint8List appChallenge,
    required Uint8List deviceChallenge,
    required String ssid,
    required String password,
    EhProv1Session? session,
  });
  Future<OnboardingProgress> waitForWifiConnection({
    required String deviceId,
    required EhProv1Session? session,
    Duration timeout = const Duration(seconds: 15),
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

  static Uint8List generateRandomBytes(int length) {
    final rnd = Random.secure();
    return Uint8List.fromList(
      List<int>.generate(length, (_) => rnd.nextInt(256)),
    );
  }

  static String generateSessionId() {
    final bytes = generateRandomBytes(16);
    // Format as canonical UUID v4: 8-4-4-4-12 = 36 ASCII characters
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-4${hex.substring(13, 16)}-8${hex.substring(17, 20)}-${hex.substring(20, 32)}';
  }

  static Uint8List parseSecretKey(String? secret) {
    if (secret == null || secret.trim().isEmpty) {
      throw ArgumentError('commissioningSecret is required and cannot be empty');
    }
    final raw = secret.trim();
    if (raw.length == 64 && RegExp(r'^[0-9a-fA-F]+$').hasMatch(raw)) {
      final bytes = <int>[];
      for (int i = 0; i < 64; i += 2) {
        bytes.add(int.parse(raw.substring(i, i + 2), radix: 16));
      }
      return Uint8List.fromList(bytes);
    }
    if (raw.length == 32) {
      return Uint8List.fromList(utf8.encode(raw));
    }
    throw ArgumentError(
      'commissioningSecret must be a 64-character hex string or 32-character ASCII string',
    );
  }

  @override
  Future<OnboardingProgress> verifyQrCode(String qrPayload) async {
    final trimmed = qrPayload.trim();
    if (!trimmed.startsWith('EH1:')) {
      return const OnboardingProgress(
        stepState: OnboardingStepState.failed,
        errorMessage:
            "Invalid QR payload version prefix. Expected 'EH1:<payload>'",
      );
    }

    try {
      final payloadRaw = trimmed.substring(4);
      String deviceId = '';
      String productVariantId = 'eh-smart-switch-3x';
      String commissioningSecret = '';
      String serialNumber = 'SN-EH-3X-2026';
      String displayName = 'EH Smart Switch 3X';

      if (payloadRaw.startsWith('{')) {
        final parsed = jsonDecode(payloadRaw) as Map<String, dynamic>;
        deviceId = parsed['deviceId'] as String? ?? '';
        productVariantId =
            parsed['productVariantId'] as String? ?? productVariantId;
        commissioningSecret = parsed['commissioningSecret'] as String? ?? '';
        serialNumber = parsed['serialNumber'] as String? ?? serialNumber;
        displayName = parsed['displayName'] as String? ?? displayName;
      } else if (payloadRaw.contains(':')) {
        // Canonical colon format after EH1: prefix -> <deviceId>:<productVariantId>:<commissioningSecretHex>:<setupCode>
        final parts = payloadRaw.split(':');
        if (parts.length < 3) {
          return const OnboardingProgress(
            stepState: OnboardingStepState.failed,
            errorMessage: 'Malformed EH1 QR code structure.',
          );
        }
        deviceId = parts[0];
        productVariantId = parts[1];
        commissioningSecret = parts[2];
      } else {
        return const OnboardingProgress(
          stepState: OnboardingStepState.failed,
          errorMessage: 'Malformed EH1 QR code structure.',
        );
      }

      if (deviceId.isEmpty || commissioningSecret.isEmpty) {
        return const OnboardingProgress(
          stepState: OnboardingStepState.failed,
          errorMessage: 'QR code does not contain required device credentials.',
        );
      }

      final identity = OnboardingDeviceIdentity(
        deviceId: deviceId,
        serialNumber: serialNumber,
        productVariantId: productVariantId,
        hardwareRevision: 'HW_1_0',
        firmwareFamily: 'esp32-switch-platform',
        displayName: displayName,
        commissioningSecret: commissioningSecret,
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
    OnboardingDeviceIdentity identity, {
    String? fixedSessionId,
    Uint8List? fixedAppChallenge,
  }) async {
    final sessionId = fixedSessionId ?? generateSessionId();
    if (sessionId.length != 36) {
      return const OnboardingProgress(
        stepState: OnboardingStepState.failed,
        errorMessage: 'sessionId must be exactly 36 ASCII characters',
      );
    }
    final appChallenge = fixedAppChallenge ?? generateRandomBytes(32);

    EhProv1Session session = EhProv1Session(
      sessionId: sessionId,
      appChallenge: appChallenge,
      identity: identity,
    );

    if (channel != null && channel!.isConnected) {
      try {
        final sessionBytes = utf8.encode(sessionId);
        final helloBuilder = BytesBuilder(copy: false)
          ..addByte(0) // EH_PROV1_MSG_HELLO
          ..add(sessionBytes)
          ..add(appChallenge);

        debugPrint('[PROV] HELLO_SENT (sessionId: $sessionId)');
        final response = await channel!.sendAndReceive(
          helloBuilder.takeBytes(),
          timeout: const Duration(seconds: 15),
        );

        // HELLO_ACK must be exact 37 bytes: 1B type(1) + 32B devChallenge + 4B seq(1)
        if (response.length != 37 || response[0] != 1) {
          return const OnboardingProgress(
            stepState: OnboardingStepState.failed,
            errorMessage: 'Invalid HELLO_ACK received from device',
          );
        }
        debugPrint('[PROV] HELLO_ACK_RECEIVED (37 bytes verified)');

        final devChallenge = response.sublist(1, 33);
        session = session.copyWith(deviceChallenge: devChallenge);
      } catch (err) {
        return OnboardingProgress(
          stepState: OnboardingStepState.failed,
          errorMessage: 'BLE HELLO exchange failed: $err',
        );
      }
    }

    return OnboardingProgress(
      stepState: OnboardingStepState.provingIdentity,
      identity: identity,
      sessionId: sessionId,
      session: session,
    );
  }

  @override
  Future<OnboardingProgress> proveIdentity({
    required String sessionId,
    required OnboardingDeviceIdentity identity,
    required Uint8List deviceChallenge,
    Uint8List? appChallenge,
    EhProv1Session? session,
  }) async {
    if (identity.commissioningSecret == null ||
        identity.commissioningSecret!.trim().isEmpty) {
      return const OnboardingProgress(
        stepState: OnboardingStepState.failed,
        errorMessage:
            'Commissioning secret is required. Please verify device with QR code.',
      );
    }

    // Preserve the original appChallenge from session; do not generate a new one!
    final activeAppChallenge = session?.appChallenge != null
        ? Uint8List.fromList(session!.appChallenge)
        : (appChallenge ?? generateRandomBytes(32));

    final activeDeviceChallenge = session?.deviceChallenge != null
        ? Uint8List.fromList(session!.deviceChallenge!)
        : deviceChallenge;

    final secretKey = parseSecretKey(identity.commissioningSecret);
    final secretFp = EhProv1Crypto.sha256(secretKey)
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join()
        .substring(0, 8);
    debugPrint(
      '[PROV] APP_PROOF_SECRET_AVAILABLE=true APP_PROOF_DEVICE_ID=${identity.deviceId} APP_PROOF_SESSION_ID=$sessionId secret_fp=$secretFp',
    );

    final appTranscript = EhProv1Crypto.encodeCanonicalTranscript(
      messageType: 'APP_PROOF',
      sessionId: sessionId,
      deviceId: identity.deviceId,
      appChallenge: activeAppChallenge,
      deviceChallenge: activeDeviceChallenge,
      sequenceNumber: 2,
    );
    final appProof = EhProv1Crypto.hmacSha256(secretKey, appTranscript);
    if (appProof.isEmpty) {
      return const OnboardingProgress(
        stepState: OnboardingStepState.failed,
        errorMessage: 'Failed to compute app proof',
      );
    }

    Uint8List deviceProof = Uint8List(32);

    if (channel != null && channel!.isConnected) {
      try {
        final authBuilder = BytesBuilder(copy: false)
          ..addByte(2) // EH_PROV1_MSG_AUTH
          ..add(appProof);

        debugPrint('[PROV] AUTH_SENT');
        final response = await channel!.sendAndReceive(
          authBuilder.takeBytes(),
          timeout: const Duration(seconds: 15),
        );

        // AUTH_ACK must be exact 37 bytes: 1B type(3) + 32B devProof + 4B seq(3)
        if (response.length != 37 || response[0] != 3) {
          return const OnboardingProgress(
            stepState: OnboardingStepState.failed,
            errorMessage: 'Invalid AUTH_ACK received from device',
          );
        }
        debugPrint('[PROV] AUTH_ACK_RECEIVED (37 bytes verified)');
        deviceProof = Uint8List.fromList(response.sublist(1, 33));
      } catch (err) {
        return OnboardingProgress(
          stepState: OnboardingStepState.failed,
          errorMessage: 'BLE AUTH exchange failed: $err',
        );
      }
    } else {
      // Test double path
      final devTranscript = EhProv1Crypto.encodeCanonicalTranscript(
        messageType: 'DEVICE_PROOF',
        sessionId: sessionId,
        deviceId: identity.deviceId,
        appChallenge: activeAppChallenge,
        deviceChallenge: activeDeviceChallenge,
        sequenceNumber: 3,
      );
      deviceProof = EhProv1Crypto.hmacSha256(secretKey, devTranscript);
    }

    final expectedDeviceTranscript = EhProv1Crypto.encodeCanonicalTranscript(
      messageType: 'DEVICE_PROOF',
      sessionId: sessionId,
      deviceId: identity.deviceId,
      appChallenge: activeAppChallenge,
      deviceChallenge: activeDeviceChallenge,
      sequenceNumber: 3,
    );
    final expectedDeviceProof = EhProv1Crypto.hmacSha256(
      secretKey,
      expectedDeviceTranscript,
    );

    final isValid = EhProv1Crypto.constantTimeCompare(
      deviceProof,
      expectedDeviceProof,
    );
    if (!isValid) {
      return const OnboardingProgress(
        stepState: OnboardingStepState.failed,
        errorMessage: 'Device authentication proof verification failed',
      );
    }

    // Derive session key
    final salt = Uint8List(64)
      ..setAll(0, activeAppChallenge)
      ..setAll(32, activeDeviceChallenge);
    final info = Uint8List.fromList(
      utf8.encode('EH-PROV/1|WIFI|$sessionId|${identity.deviceId}'),
    );
    final sessionKey = EhProv1Crypto.hkdfSha256(
      ikm: secretKey,
      salt: salt,
      info: info,
      outputLength: 32,
    );

    final updatedSession =
        (session ??
                EhProv1Session(
                  sessionId: sessionId,
                  appChallenge: activeAppChallenge,
                  identity: identity,
                ))
            .copyWith(
              deviceChallenge: activeDeviceChallenge,
              sessionKey: sessionKey,
            );

    return OnboardingProgress(
      stepState: OnboardingStepState.wifiProvisioning,
      identity: identity,
      sessionId: sessionId,
      session: updatedSession,
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
    EhProv1Session? session,
  }) async {
    if (ssid.trim().isEmpty) {
      return const OnboardingProgress(
        stepState: OnboardingStepState.failed,
        errorMessage: 'Wi-Fi SSID is required',
      );
    }

    final activeAppChallenge = session?.appChallenge != null
        ? Uint8List.fromList(session!.appChallenge)
        : appChallenge;
    final activeDeviceChallenge = session?.deviceChallenge != null
        ? Uint8List.fromList(session!.deviceChallenge!)
        : deviceChallenge;

    Uint8List sessionKey;
    if (session?.sessionKey != null) {
      sessionKey = Uint8List.fromList(session!.sessionKey!);
    } else {
      final secretKey = parseSecretKey(identity.commissioningSecret);
      final salt = Uint8List(64)
        ..setAll(0, activeAppChallenge)
        ..setAll(32, activeDeviceChallenge);
      final info = Uint8List.fromList(
        utf8.encode('EH-PROV/1|WIFI|$sessionId|${identity.deviceId}'),
      );
      sessionKey = EhProv1Crypto.hkdfSha256(
        ikm: secretKey,
        salt: salt,
        info: info,
        outputLength: 32,
      );
    }

    final nonce = generateRandomBytes(12);
    final aad = EhProv1Crypto.encodeCanonicalTranscript(
      messageType: 'WIFI',
      sessionId: sessionId,
      deviceId: identity.deviceId,
      appChallenge: activeAppChallenge,
      deviceChallenge: activeDeviceChallenge,
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

    if (channel != null && channel!.isConnected) {
      try {
        final wifiBuilder = BytesBuilder(copy: false)
          ..addByte(4) // EH_PROV1_MSG_WIFI_CRED
          ..add(nonce)
          ..add(encryptedPayload);

        debugPrint('[PROV] WIFI_CRED_SENT (SSID: $ssid)');
        final response = await channel!.sendAndReceive(
          wifiBuilder.takeBytes(),
          timeout: const Duration(seconds: 20),
        );

        // WIFI_ACK must be exact 6 bytes: 1B type(5) + 1B status(1) + 4B seq(5)
        if (response.length != 6 || response[0] != 5 || response[1] != 1) {
          return OnboardingProgress(
            stepState: OnboardingStepState.failed,
            errorMessage:
                'The device could not accept these Wi-Fi credentials.',
            session: session,
          );
        }
        debugPrint('[PROV] WIFI_ACK_RECEIVED (6 bytes verified)');
      } catch (err) {
        return OnboardingProgress(
          stepState: OnboardingStepState.failed,
          errorMessage: 'BLE Wi-Fi provisioning exchange failed: $err',
          session: session,
        );
      }
    }

    return OnboardingProgress(
      stepState: OnboardingStepState.awaitingMtlsConfirm,
      identity: identity,
      sessionId: sessionId,
      session: session,
    );
  }

  static bool _isWaitingForWifi = false;

  @override
  Future<OnboardingProgress> waitForWifiConnection({
    required String deviceId,
    required EhProv1Session? session,
    Duration timeout = const Duration(seconds: 25),
  }) async {
    if (channel == null || !channel!.isConnected) {
      return OnboardingProgress(
        stepState: OnboardingStepState.complete,
        sessionId: session?.sessionId ?? '',
        session: session,
      );
    }

    if (_isWaitingForWifi) {
      debugPrint('[PROV] WIFI_CONNECT_WAIT already in progress, skipping duplicate.');
      return OnboardingProgress(
        stepState: OnboardingStepState.complete,
        sessionId: session?.sessionId ?? '',
        session: session,
      );
    }

    _isWaitingForWifi = true;
    debugPrint('[PROV] WIFI_CONNECT_WAIT started (deviceId: $deviceId)');
    final stopwatch = Stopwatch()..start();

    try {
      while (stopwatch.elapsed < timeout) {
        try {
          final status = await channel!.readStatus();
          final isWifi = status['wifi'] == true;
          final stateStr = (status['state'] as String?)?.toUpperCase();

          debugPrint('[PROV] 6104_PARSED state=$stateStr wifi=$isWifi');

          if (isWifi || stateStr == 'ACTIVE' || stateStr == 'MQTT_CONNECTING' || stateStr == 'WIFI_CONNECTED') {
            debugPrint(
              '[PROV] WIFI_CONNECTED confirmed via status characteristic (state=$stateStr wifi=$isWifi)!',
            );
            return OnboardingProgress(
              stepState: OnboardingStepState.complete,
              sessionId: session?.sessionId ?? '',
              session: session,
            );
          } else if (stateStr == 'WIFI_CONNECTING' ||
              stateStr == 'BLE_COMMISSIONING') {
            debugPrint(
              '[PROV] Status is transient ($stateStr), awaiting completion...',
            );
          } else if (stateStr == 'WIFI_FAILED') {
            return OnboardingProgress(
              stepState: OnboardingStepState.failed,
              errorMessage:
                  'The device could not connect to this Wi-Fi network. Check the password and try again.',
              session: session,
            );
          }
        } catch (e) {
          debugPrint('[PROV] Polling status warning: $e');
        }
        await Future<void>.delayed(const Duration(milliseconds: 1500));
      }

      return OnboardingProgress(
        stepState: OnboardingStepState.failed,
        errorMessage:
            'Device is still connecting to Wi-Fi. Check your network or keep device nearby and try again.',
        session: session,
      );
    } finally {
      _isWaitingForWifi = false;
    }
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
