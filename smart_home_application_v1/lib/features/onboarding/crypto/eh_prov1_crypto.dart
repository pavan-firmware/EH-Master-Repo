import 'dart:convert';
import 'dart:typed_data';
import 'package:pointycastle/block/aes.dart';
import 'package:pointycastle/block/modes/gcm.dart';
import 'package:pointycastle/api.dart';
import 'package:pointycastle/digests/sha256.dart';
import 'package:pointycastle/macs/hmac.dart';

class EhProv1Crypto {
  /// Strict byte-level canonical transcript encoding
  /// Offset 0: protocolVersion len (1 byte) + ASCII bytes ("EH-PROV/1")
  /// Offset 10: messageType len (1 byte) + ASCII bytes
  /// Offset 11+len: sessionId (36 ASCII bytes)
  /// Offset 47+len: deviceId (36 ASCII bytes)
  /// Offset 83+len: appChallenge (32 raw bytes)
  /// Offset 115+len: deviceChallenge (32 raw bytes)
  /// Offset 147+len: sequenceNumber (4 bytes Big-Endian uint32)
  static Uint8List encodeCanonicalTranscript({
    required String messageType,
    required String sessionId,
    required String deviceId,
    required Uint8List appChallenge,
    required Uint8List deviceChallenge,
    required int sequenceNumber,
    String protocolVersion = 'EH-PROV/1',
  }) {
    final protoBytes = utf8.encode(protocolVersion);
    final msgTypeBytes = utf8.encode(messageType);
    final sessionBytes = utf8.encode(sessionId);
    final deviceBytes = utf8.encode(deviceId);

    if (sessionBytes.length != 36) {
      throw ArgumentError(
        'sessionId must be exactly 36 ASCII bytes (canonical UUID format)',
      );
    }
    if (deviceBytes.length != 36) {
      throw ArgumentError(
        'deviceId must be exactly 36 ASCII bytes (canonical UUID format)',
      );
    }
    if (appChallenge.length != 32) {
      throw ArgumentError('appChallenge must be exactly 32 bytes');
    }
    if (deviceChallenge.length != 32) {
      throw ArgumentError('deviceChallenge must be exactly 32 bytes');
    }

    final totalLen =
        1 + protoBytes.length + 1 + msgTypeBytes.length + 36 + 36 + 32 + 32 + 4;
    final builder = BytesBuilder(copy: false);

    builder.addByte(protoBytes.length);
    builder.add(protoBytes);

    builder.addByte(msgTypeBytes.length);
    builder.add(msgTypeBytes);

    builder.add(sessionBytes);
    builder.add(deviceBytes);
    builder.add(appChallenge);
    builder.add(deviceChallenge);

    final seqData = ByteData(4)..setUint32(0, sequenceNumber, Endian.big);
    builder.add(seqData.buffer.asUint8List());

    final out = builder.takeBytes();
    if (out.length != totalLen) {
      throw StateError(
        'Encoded transcript length mismatch: expected $totalLen, got ${out.length}',
      );
    }
    return out;
  }

  /// HMAC-SHA256 computation
  static Uint8List hmacSha256(Uint8List key, Uint8List data) {
    final hmac = HMac(SHA256Digest(), 64)..init(KeyParameter(key));
    return hmac.process(data);
  }

  /// HKDF-SHA256 key derivation (RFC 5869)
  /// IKM: commissioningSecret (32 bytes)
  /// Salt: appChallenge || deviceChallenge (64 bytes)
  /// Info: "EH-PROV/1|WIFI|" || sessionId || "|" || deviceId
  /// Output: 32-byte session key
  static Uint8List hkdfSha256({
    required Uint8List ikm,
    required Uint8List salt,
    required Uint8List info,
    int outputLength = 32,
  }) {
    // 1. Extract: PRK = HMAC-SHA256(salt, IKM)
    final prk = hmacSha256(salt.isEmpty ? Uint8List(32) : salt, ikm);

    // 2. Expand: T(1) = HMAC-SHA256(PRK, info || 0x01)
    final infoWithCounter = Uint8List(info.length + 1);
    infoWithCounter.setAll(0, info);
    infoWithCounter[info.length] = 0x01;

    final derived = hmacSha256(prk, infoWithCounter);
    if (outputLength <= derived.length) {
      return Uint8List.sublistView(derived, 0, outputLength);
    }
    throw UnsupportedError(
      'HKDF output length > 32 bytes not required for EH-PROV/1',
    );
  }

  /// AES-256-GCM Encryption
  /// Returns ciphertext concatenated with 16-byte authTag
  static Uint8List encryptAes256Gcm({
    required Uint8List key,
    required Uint8List nonce,
    required Uint8List aad,
    required Uint8List plaintext,
  }) {
    if (key.length != 32) throw ArgumentError('AES-256 key must be 32 bytes');
    if (nonce.length != 12) throw ArgumentError('GCM nonce must be 12 bytes');

    final cipher = GCMBlockCipher(AESEngine());
    final params = AEADParameters(KeyParameter(key), 128, nonce, aad);
    cipher.init(true, params);

    return cipher.process(plaintext);
  }

  /// AES-256-GCM Decryption
  /// Expects ciphertext concatenated with 16-byte authTag
  static Uint8List decryptAes256Gcm({
    required Uint8List key,
    required Uint8List nonce,
    required Uint8List aad,
    required Uint8List ciphertextAndTag,
  }) {
    if (key.length != 32) throw ArgumentError('AES-256 key must be 32 bytes');
    if (nonce.length != 12) throw ArgumentError('GCM nonce must be 12 bytes');

    final cipher = GCMBlockCipher(AESEngine());
    final params = AEADParameters(KeyParameter(key), 128, nonce, aad);
    cipher.init(false, params);

    return cipher.process(ciphertextAndTag);
  }

  /// Constant-time byte array comparison (prevents timing side-channel attacks)
  static bool constantTimeCompare(Uint8List a, Uint8List b) {
    if (a.length != b.length) return false;
    int result = 0;
    for (int i = 0; i < a.length; i++) {
      result |= a[i] ^ b[i];
    }
    return result == 0;
  }
}
