import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';

class BleCommissioningChannel {
  BleCommissioningChannel({FlutterReactiveBle? ble})
    : _ble = ble ?? FlutterReactiveBle();

  final FlutterReactiveBle _ble;
  StreamSubscription<ConnectionStateUpdate>? _connSub;
  StreamSubscription<List<int>>? _notifySub;
  final StreamController<Uint8List> _responseController =
      StreamController<Uint8List>.broadcast();

  Stream<Uint8List> get responses => _responseController.stream;

  static final Uuid provServiceUuid = Uuid.parse(
    '02613b9f-7a5c-198e-604c-472bf0e1d4a8',
  );
  static final Uuid rxCharUuid = Uuid.parse(
    '10613b9f-7a5c-198e-604c-472bf0e1d4a8',
  );
  static final Uuid txCharUuid = Uuid.parse(
    '11613b9f-7a5c-198e-604c-472bf0e1d4a8',
  );

  /// Fragment payload into 20-byte BLE chunks (2-byte header + 16-byte chunk)
  static List<Uint8List> fragmentPayload(
    Uint8List payload, {
    int chunkSize = 16,
  }) {
    if (payload.isEmpty) return [];
    final totalFrames = (payload.length + chunkSize - 1) ~/ chunkSize;
    final frames = <Uint8List>[];

    for (int i = 0; i < totalFrames; i++) {
      final start = i * chunkSize;
      final end = (start + chunkSize < payload.length)
          ? start + chunkSize
          : payload.length;
      final chunk = payload.sublist(start, end);

      final frame = BytesBuilder(copy: false);
      frame.addByte(i);
      frame.addByte(totalFrames);
      frame.add(chunk);
      frames.add(frame.takeBytes());
    }
    return frames;
  }

  /// Reassemble BLE frames into complete payload
  static Uint8List reassembleFrames(List<Uint8List> frames) {
    if (frames.isEmpty) return Uint8List(0);
    final builder = BytesBuilder(copy: false);
    for (int i = 0; i < frames.length; i++) {
      final frame = frames[i];
      if (frame.length < 2) throw FormatException('Invalid BLE frame header');
      final frameIndex = frame[0];
      if (frameIndex != i) {
        throw FormatException(
          'Out of order BLE frame index: $frameIndex, expected $i',
        );
      }
      builder.add(frame.sublist(2));
    }
    return builder.takeBytes();
  }

  Future<void> connect(String deviceId) async {
    // BLE connection handler
  }

  Future<void> writeMessage(
    QualifiedCharacteristic char,
    Uint8List data,
  ) async {
    final frames = fragmentPayload(data);
    for (final frame in frames) {
      await _ble.writeCharacteristicWithResponse(char, value: frame.toList());
    }
  }

  void dispose() {
    _connSub?.cancel();
    _notifySub?.cancel();
    _responseController.close();
  }
}
