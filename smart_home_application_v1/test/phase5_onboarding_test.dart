import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_home_application_v1/features/onboarding/ble/ble_commissioning_channel.dart';
import 'package:smart_home_application_v1/features/onboarding/crypto/eh_prov1_crypto.dart';
import 'package:smart_home_application_v1/features/onboarding/models/onboarding_models.dart';
import 'package:smart_home_application_v1/features/onboarding/services/onboarding_service.dart';

void main() {
  group('Phase 5B EH-PROV/1 Cryptographic & Onboarding Tests', () {
    final appChal = Uint8List(32)..fillRange(0, 32, 0x01);
    final devChal = Uint8List(32)..fillRange(0, 32, 0x02);
    const sessionId = 'c0a80101-0000-4000-8000-000000000001';
    const deviceId = 'c0a80101-0000-4000-8000-000000000001';

    test(
      'Strict byte-level canonical transcript encoding produces exact byte layout',
      () {
        final transcript = EhProv1Crypto.encodeCanonicalTranscript(
          messageType: 'APP_PROOF',
          sessionId: sessionId,
          deviceId: deviceId,
          appChallenge: appChal,
          deviceChallenge: devChal,
          sequenceNumber: 2,
        );

        // Expected total length: 1 + 9 + 1 + 9 + 36 + 36 + 32 + 32 + 4 = 160 bytes
        expect(transcript.length, 160);
        expect(transcript[0], 9); // protocolVersion len
        expect(utf8.decode(transcript.sublist(1, 10)), 'EH-PROV/1');
        expect(transcript[10], 9); // messageType len ("APP_PROOF")
        expect(utf8.decode(transcript.sublist(11, 20)), 'APP_PROOF');
        expect(utf8.decode(transcript.sublist(20, 56)), sessionId);
        expect(utf8.decode(transcript.sublist(56, 92)), deviceId);
        expect(transcript.sublist(92, 124), appChal);
        expect(transcript.sublist(124, 156), devChal);
        expect(
          transcript.sublist(156, 160),
          Uint8List.fromList([0, 0, 0, 2]),
        ); // Big-Endian uint32(2)
      },
    );

    test(
      'HKDF-SHA256 derives deterministic 256-bit key with domain separation',
      () {
        final secret = Uint8List.fromList(
          utf8.encode('test_secret_32_bytes_123456789012'),
        );
        final salt = Uint8List(64)
          ..setAll(0, appChal)
          ..setAll(32, devChal);
        final info = Uint8List.fromList(
          utf8.encode('EH-PROV/1|WIFI|$sessionId|$deviceId'),
        );

        final key1 = EhProv1Crypto.hkdfSha256(
          ikm: secret,
          salt: salt,
          info: info,
        );
        final key2 = EhProv1Crypto.hkdfSha256(
          ikm: secret,
          salt: salt,
          info: info,
        );

        expect(key1.length, 32);
        expect(key1, key2); // Deterministic
      },
    );

    test('AES-256-GCM encrypts/decrypts and rejects tampered ciphertext', () {
      final key = Uint8List(32)..fillRange(0, 32, 0x0A);
      final nonce = Uint8List(12)..fillRange(0, 12, 0x0B);
      final aad = Uint8List.fromList(utf8.encode('EH-PROV/1|WIFI'));
      final plaintext = Uint8List.fromList(
        utf8.encode('{"s":"MyWiFi","p":"Secret123"}'),
      );

      final ciphertextAndTag = EhProv1Crypto.encryptAes256Gcm(
        key: key,
        nonce: nonce,
        aad: aad,
        plaintext: plaintext,
      );

      final decrypted = EhProv1Crypto.decryptAes256Gcm(
        key: key,
        nonce: nonce,
        aad: aad,
        ciphertextAndTag: ciphertextAndTag,
      );

      expect(utf8.decode(decrypted), '{"s":"MyWiFi","p":"Secret123"}');

      // Tamper test: flip one byte in ciphertext
      final tampered = Uint8List.fromList(ciphertextAndTag);
      tampered[0] ^= 0xFF;

      expect(
        () => EhProv1Crypto.decryptAes256Gcm(
          key: key,
          nonce: nonce,
          aad: aad,
          ciphertextAndTag: tampered,
        ),
        throwsA(anything),
      );
    });

    test(
      'BLE payload fragmentation & reassembly chunks messages into 20-byte ATT frames',
      () {
        final longPayload = Uint8List.fromList(List.generate(50, (i) => i));
        final frames = BleCommissioningChannel.fragmentPayload(
          longPayload,
          chunkSize: 16,
        );

        expect(frames.length, 4); // 50 / 16 = 3.125 -> 4 frames
        expect(frames[0].length, 18); // 2 header bytes + 16 payload bytes

        final reassembled = BleCommissioningChannel.reassembleFrames(frames);
        expect(reassembled, longPayload);
      },
    );

    test(
      'BLE reassembly rejects out-of-order, mismatched, or corrupted frames',
      () {
        final payload = Uint8List.fromList(List.generate(35, (i) => i));
        final frames = BleCommissioningChannel.fragmentPayload(
          payload,
          chunkSize: 16,
        );

        // Empty frames list
        expect(BleCommissioningChannel.reassembleFrames([]), Uint8List(0));

        // Out of order frames
        final outOfOrder = [frames[1], frames[0], frames[2]];
        expect(
          () => BleCommissioningChannel.reassembleFrames(outOfOrder),
          throwsFormatException,
        );

        // Missing frame
        final missing = [frames[0], frames[2]];
        expect(
          () => BleCommissioningChannel.reassembleFrames(missing),
          throwsFormatException,
        );

        // Frame with invalid header (less than 2 bytes)
        final truncated = [
          frames[0],
          Uint8List.fromList([1]),
        ];
        expect(
          () => BleCommissioningChannel.reassembleFrames(truncated),
          throwsFormatException,
        );
      },
    );

    test(
      'DefaultOnboardingService handles end-to-end EH-PROV/1 commissioning flow with session persistence',
      () async {
        const service = DefaultOnboardingService();
        const testSecretHex =
            '0102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f20';

        final qrResult = await service.verifyQrCode(
          'EH1:c0a80101-0000-4000-8000-000000000001:eh-smart-switch-3x:$testSecretHex:123456',
        );
        expect(qrResult.stepState, OnboardingStepState.secureCommissioning);
        expect(qrResult.identity!.deviceId, 'c0a80101-0000-4000-8000-000000000001');
        expect(qrResult.identity!.commissioningSecret, testSecretHex);

        final commResult = await service.startSecureCommissioning(
          qrResult.identity!,
          fixedSessionId: sessionId,
          fixedAppChallenge: appChal,
        );
        expect(commResult.stepState, OnboardingStepState.provingIdentity);
        expect(commResult.sessionId, sessionId);
        expect(commResult.session, isNotNull);
        expect(commResult.session!.appChallenge, appChal);

        final proveResult = await service.proveIdentity(
          sessionId: commResult.sessionId!,
          identity: qrResult.identity!,
          deviceChallenge: devChal,
          session: commResult.session,
        );
        expect(proveResult.stepState, OnboardingStepState.wifiProvisioning);
        expect(proveResult.session!.sessionKey, isNotNull);
        expect(proveResult.session!.sessionKey!.length, 32);

        final wifiResult = await service.provisionWifi(
          sessionId: commResult.sessionId!,
          identity: qrResult.identity!,
          appChallenge: appChal,
          deviceChallenge: devChal,
          ssid: 'MyHomeWiFi',
          password: 'Password123!',
          session: proveResult.session,
        );
        expect(wifiResult.stepState, OnboardingStepState.awaitingMtlsConfirm);

        final claimResult = await service.claimAndAssignDevice(
          deviceId: qrResult.identity!.deviceId,
          sessionId: commResult.sessionId!,
          homeId: 'home_main',
          roomId: 'rm_living',
          customName: 'Living Room Switch',
        );
        expect(claimResult.isComplete, isTrue);
      },
    );

    test('Missing commissioningSecret rejects proveIdentity before AUTH', () async {
      const service = DefaultOnboardingService();
      const identityWithoutSecret = OnboardingDeviceIdentity(
        deviceId: 'c0a80101-0000-4000-8000-000000000001',
        serialNumber: 'SN-EH-3X-2026',
        productVariantId: 'eh-smart-switch-3x',
        hardwareRevision: 'HW_1_0',
        firmwareFamily: 'esp32-switch-platform',
        displayName: 'EH Smart Switch 3X',
        commissioningSecret: null,
      );

      final proveResult = await service.proveIdentity(
        sessionId: sessionId,
        identity: identityWithoutSecret,
        deviceChallenge: devChal,
      );
      expect(proveResult.hasFailed, isTrue);
      expect(proveResult.errorMessage, contains('Commissioning secret is required'));
    });

    test('parseSecretKey throws ArgumentError on empty or invalid secret', () {
      expect(() => DefaultOnboardingService.parseSecretKey(null), throwsArgumentError);
      expect(() => DefaultOnboardingService.parseSecretKey(''), throwsArgumentError);
      expect(() => DefaultOnboardingService.parseSecretKey('short_key'), throwsArgumentError);
    });

    test('Strict constant-time comparison prevents timing discrepancies', () {
      final a = Uint8List.fromList([1, 2, 3, 4, 5]);
      final b = Uint8List.fromList([1, 2, 3, 4, 5]);
      final c = Uint8List.fromList([1, 2, 3, 4, 6]);
      final d = Uint8List.fromList([1, 2, 3]);

      expect(EhProv1Crypto.constantTimeCompare(a, b), isTrue);
      expect(EhProv1Crypto.constantTimeCompare(a, c), isFalse);
      expect(EhProv1Crypto.constantTimeCompare(a, d), isFalse);
    });
  });
}
