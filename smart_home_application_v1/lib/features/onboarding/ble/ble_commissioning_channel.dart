import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';

class BleCommissioningChannel {
  BleCommissioningChannel({FlutterReactiveBle? ble}) : _customBle = ble;

  final FlutterReactiveBle? _customBle;
  FlutterReactiveBle? get _ble {
    if (_customBle != null) return _customBle;
    if (Platform.environment.containsKey('FLUTTER_TEST')) return null;
    try {
      return FlutterReactiveBle();
    } catch (_) {
      return null;
    }
  }

  StreamSubscription<ConnectionStateUpdate>? _connSub;
  StreamSubscription<List<int>>? _notifySub1;
  StreamSubscription<List<int>>? _notifySub2;
  final StreamController<Uint8List> _responseController =
      StreamController<Uint8List>.broadcast();

  Stream<Uint8List> get responses => _responseController.stream;

  static final Uuid service1Uuid = Uuid.parse(
    'a8d4e1f0-2b47-4c60-8e19-5c7a9f3b6101',
  );
  static final Uuid provServiceUuid = Uuid.parse(
    'a8d4e1f0-2b47-4c60-8e19-5c7a9f3b6102',
  );
  static final Uuid rxCharUuid = Uuid.parse(
    'a8d4e1f0-2b47-4c60-8e19-5c7a9f3b6110',
  );
  static final Uuid txCharUuid = Uuid.parse(
    'a8d4e1f0-2b47-4c60-8e19-5c7a9f3b6111',
  );
  static final Uuid productInfoUuid = Uuid.parse(
    'a8d4e1f0-2b47-4c60-8e19-5c7a9f3b6105',
  );

  QualifiedCharacteristic? _resolvedRxChar;

  String? _connectedDeviceId;
  bool _isConnected = false;
  bool get isConnected => _isConnected;
  String? get connectedDeviceId => _connectedDeviceId;

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
      if (frame.length < 2) {
        throw const FormatException('Invalid BLE frame header');
      }
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

  void _handleIncomingNotification(
    List<int> data,
    List<Uint8List> frameBuffer,
  ) {
    if (data.isEmpty) return;
    final bytes = Uint8List.fromList(data);
    if (bytes.length >= 2 && bytes[1] > 1) {
      frameBuffer.add(bytes);
      if (frameBuffer.length == bytes[1]) {
        try {
          final complete = reassembleFrames(frameBuffer);
          frameBuffer.clear();
          _responseController.add(complete);
        } catch (_) {
          frameBuffer.clear();
        }
      }
    } else if (bytes.length >= 2 && bytes[0] == 0 && bytes[1] == 1) {
      _responseController.add(bytes.sublist(2));
    } else {
      _responseController.add(bytes);
    }
  }

  Future<void> connect(String deviceId) async {
    await disconnect();

    final ble = _ble;
    if (ble == null) {
      throw StateError('Bluetooth is off or unavailable');
    }

    _connectedDeviceId = deviceId;
    final connectedCompleter = Completer<void>();

    // Pass servicesWithCharacteristicsToDiscover for both Service 1 and Service 2
    _connSub = ble
        .connectToDevice(
          id: deviceId,
          servicesWithCharacteristicsToDiscover: {
            service1Uuid: [productInfoUuid, rxCharUuid, txCharUuid],
            provServiceUuid: [rxCharUuid, txCharUuid],
          },
          connectionTimeout: const Duration(seconds: 15),
        )
        .listen(
          (update) {
            if (update.connectionState == DeviceConnectionState.connected) {
              _isConnected = true;
              if (!connectedCompleter.isCompleted) {
                connectedCompleter.complete();
              }
            } else if (update.connectionState ==
                DeviceConnectionState.disconnected) {
              _isConnected = false;
              if (!connectedCompleter.isCompleted) {
                connectedCompleter.completeError(
                  TimeoutException(
                    'Device disconnected before commissioning setup completed',
                  ),
                );
              }
            }
          },
          onError: (Object err, StackTrace st) {
            _isConnected = false;
            if (!connectedCompleter.isCompleted) {
              connectedCompleter.completeError(err, st);
            }
          },
        );

    await connectedCompleter.future.timeout(const Duration(seconds: 15));

    _resolvedRxChar = QualifiedCharacteristic(
      deviceId: deviceId,
      serviceId: provServiceUuid,
      characteristicId: rxCharUuid,
    );

    final receivedFrames1 = <Uint8List>[];
    final receivedFrames2 = <Uint8List>[];

    // Subscribe to Service 2 TX (6102)
    try {
      final txChar6102 = QualifiedCharacteristic(
        deviceId: deviceId,
        serviceId: provServiceUuid,
        characteristicId: txCharUuid,
      );
      _notifySub2 = ble
          .subscribeToCharacteristic(txChar6102)
          .listen(
            (data) => _handleIncomingNotification(data, receivedFrames2),
            onError: (_) {},
          );
    } catch (_) {}

    // Subscribe to Service 1 TX (6101)
    try {
      final txChar6101 = QualifiedCharacteristic(
        deviceId: deviceId,
        serviceId: service1Uuid,
        characteristicId: txCharUuid,
      );
      _notifySub1 = ble
          .subscribeToCharacteristic(txChar6101)
          .listen(
            (data) => _handleIncomingNotification(data, receivedFrames1),
            onError: (_) {},
          );
    } catch (_) {}
  }

  Future<void> writeMessage(
    Uint8List data, {
    QualifiedCharacteristic? customChar,
  }) async {
    final ble = _ble;
    if (ble == null) {
      throw StateError('Bluetooth is off or unavailable');
    }
    final targetChar = customChar ?? _resolvedRxChar;
    if (targetChar == null) {
      throw StateError('Cannot write message: BLE channel not connected');
    }

    final frames = fragmentPayload(data, chunkSize: 16);
    for (final frame in frames) {
      bool written = false;

      // 1. Try Service 2 write with response
      try {
        await ble.writeCharacteristicWithResponse(
          targetChar,
          value: frame.toList(),
        );
        written = true;
      } catch (_) {}

      // 2. Try Service 2 write without response
      if (!written) {
        try {
          await ble.writeCharacteristicWithoutResponse(
            targetChar,
            value: frame.toList(),
          );
          written = true;
        } catch (_) {}
      }

      // 3. Fallback to Service 1 write with response
      if (!written) {
        final fallbackChar = QualifiedCharacteristic(
          deviceId: targetChar.deviceId,
          serviceId: service1Uuid,
          characteristicId: rxCharUuid,
        );
        _resolvedRxChar = fallbackChar;
        try {
          await ble.writeCharacteristicWithResponse(
            fallbackChar,
            value: frame.toList(),
          );
          written = true;
        } catch (_) {}

        // 4. Fallback to Service 1 write without response
        if (!written) {
          await ble.writeCharacteristicWithoutResponse(
            fallbackChar,
            value: frame.toList(),
          );
          written = true;
        }
      }
    }
  }

  Future<Uint8List> sendAndReceive(
    Uint8List request, {
    Duration timeout = const Duration(seconds: 10),
  }) async {
    final responseCompleter = Completer<Uint8List>();
    late final StreamSubscription<Uint8List> sub;

    sub = responses.listen(
      (data) {
        if (!responseCompleter.isCompleted) {
          responseCompleter.complete(data);
        }
      },
      onError: (Object err) {
        if (!responseCompleter.isCompleted) {
          responseCompleter.completeError(err);
        }
      },
    );

    try {
      await writeMessage(request);
      return await responseCompleter.future.timeout(timeout);
    } finally {
      await sub.cancel();
    }
  }

  Future<void> disconnect() async {
    _isConnected = false;
    _connectedDeviceId = null;
    _resolvedRxChar = null;
    await _notifySub1?.cancel();
    _notifySub1 = null;
    await _notifySub2?.cancel();
    _notifySub2 = null;
    await _connSub?.cancel();
    _connSub = null;
  }

  void dispose() {
    disconnect();
    _responseController.close();
  }
}
