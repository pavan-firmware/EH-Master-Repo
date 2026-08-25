import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';

class BleCommissioningChannel {
  BleCommissioningChannel({FlutterReactiveBle? ble})
      : _ble = ble ?? FlutterReactiveBle();

  final FlutterReactiveBle _ble;
  StreamSubscription<ConnectionStateUpdate>? _connSub;
  StreamSubscription<List<int>>? _notifySub;
  final StreamController<Uint8List> _responseController = StreamController<Uint8List>.broadcast();

  Stream<Uint8List> get responses => _responseController.stream;

  static final Uuid provServiceUuid = Uuid.parse('02613b9f-7a5c-198e-604c-472bf0e1d4a8');
  static final Uuid rxCharUuid = Uuid.parse('10613b9f-7a5c-198e-604c-472bf0e1d4a8');
  static final Uuid txCharUuid = Uuid.parse('11613b9f-7a5c-198e-604c-472bf0e1d4a8');

  Future<void> connect(String deviceId) async {
    // BLE connection handler
  }

  Future<void> writeMessage(QualifiedCharacteristic char, Uint8List data) async {
    await _ble.writeCharacteristicWithResponse(char, value: data.toList());
  }

  void dispose() {
    _connSub?.cancel();
    _notifySub?.cancel();
    _responseController.close();
  }
}
