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
    'a8d4e1f0-2b47-4c60-8e19-5c7a9f3b6102',
  );
  static final Uuid rxCharUuid = Uuid.parse(
    'a8d4e1f0-2b47-4c60-8e19-5c7a9f3b6110',
  );
  static final Uuid txCharUuid = Uuid.parse(
    'a8d4e1f0-2b47-4c60-8e19-5c7a9f3b6111',
  );

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

  Future<void> connect(String deviceId) async {
    await disconnect();

    _connectedDeviceId = deviceId;
    final connectedCompleter = Completer<void>();

    _connSub = _ble
        .connectToDevice(
          id: deviceId,
          servicesWithCharacteristicsToDiscover: {
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

    await _ble.discoverAllServices(deviceId);

    final txChar = QualifiedCharacteristic(
      deviceId: deviceId,
      serviceId: provServiceUuid,
      characteristicId: txCharUuid,
    );

    _notifySub = _ble
        .subscribeToCharacteristic(txChar)
        .listen(
          (data) {
            if (data.isNotEmpty) {
              _responseController.add(Uint8List.fromList(data));
            }
          },
          onError: (Object err) {
            // Notification error handling
          },
        );
  }

  Future<void> writeMessage(
    Uint8List data, {
    QualifiedCharacteristic? customChar,
  }) async {
    final devId = customChar?.deviceId ?? _connectedDeviceId;
    if (devId == null) {
      throw StateError('Cannot write message: BLE channel not connected');
    }
    final targetChar =
        customChar ??
        QualifiedCharacteristic(
          deviceId: devId,
          serviceId: provServiceUuid,
          characteristicId: rxCharUuid,
        );

    await _ble.writeCharacteristicWithResponse(
      targetChar,
      value: data.toList(),
    );
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
    await _notifySub?.cancel();
    _notifySub = null;
    await _connSub?.cancel();
    _connSub = null;
  }

  void dispose() {
    disconnect();
    _responseController.close();
  }
}
