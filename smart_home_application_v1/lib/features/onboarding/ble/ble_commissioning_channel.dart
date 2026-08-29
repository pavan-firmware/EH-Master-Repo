import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import '../models/onboarding_models.dart';

class GattDiscoveryException implements Exception {
  const GattDiscoveryException(this.message);
  final String message;

  @override
  String toString() => 'GattDiscoveryException: $message';
}

/// Authoritative single BLE connection owner and commissioning channel for EH-PROV/1.
class BleCommissioningChannel {
  BleCommissioningChannel({FlutterReactiveBle? ble})
    : _ble = ble ?? FlutterReactiveBle();

  final FlutterReactiveBle _ble;

  // Service 1: Device Info & Telemetry
  static final Uuid infoServiceUuid = Uuid.parse(
    'a8d4e1f0-2b47-4c60-8e19-5c7a9f3b6101',
  );
  static final Uuid telemetryCharUuid = Uuid.parse(
    'a8d4e1f0-2b47-4c60-8e19-5c7a9f3b6103',
  );
  static final Uuid statusCharUuid = Uuid.parse(
    'a8d4e1f0-2b47-4c60-8e19-5c7a9f3b6104',
  );
  static final Uuid productInfoCharUuid = Uuid.parse(
    'a8d4e1f0-2b47-4c60-8e19-5c7a9f3b6105',
  );

  // Service 2: EH-PROV/1 Secure Commissioning
  static final Uuid provServiceUuid = Uuid.parse(
    'a8d4e1f0-2b47-4c60-8e19-5c7a9f3b6102',
  );
  static final Uuid rxCharUuid = Uuid.parse(
    'a8d4e1f0-2b47-4c60-8e19-5c7a9f3b6110',
  );
  static final Uuid txCharUuid = Uuid.parse(
    'a8d4e1f0-2b47-4c60-8e19-5c7a9f3b6111',
  );

  StreamSubscription<ConnectionStateUpdate>? _connSub;
  StreamSubscription<List<int>>? _notifySub;
  StreamSubscription<DiscoveredDevice>? _activeScanSub;
  DateTime? _lastScanTime;
  Future<DiscoveredDevice>? _inFlightScan;

  final StreamController<Uint8List> _responseController =
      StreamController<Uint8List>.broadcast();

  Stream<Uint8List> get responses => _responseController.stream;

  String? _connectedDeviceId;
  bool _isConnected = false;
  bool _isGattReady = false;
  OnboardingDeviceIdentity? _deviceIdentity;

  bool get isConnected => _isConnected;
  bool get isGattReady => _isGattReady;
  String? get connectedDeviceId => _connectedDeviceId;
  OnboardingDeviceIdentity? get deviceIdentity => _deviceIdentity;

  // Reassembly state
  BytesBuilder? _reassemblyBuilder;
  int _nextExpectedFrame = 0;
  int _totalFramesExpected = 0;
  bool _reassemblyInProgress = false;

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
    final totalExpected = frames[0].length >= 2 ? frames[0][1] : 0;
    if (frames.length != totalExpected) {
      throw FormatException(
        'Frame count mismatch: expected $totalExpected, got ${frames.length}',
      );
    }
    for (int i = 0; i < frames.length; i++) {
      final frame = frames[i];
      if (frame.length < 2) {
        throw const FormatException('Invalid BLE frame header');
      }
      final frameIndex = frame[0];
      final frameTotal = frame[1];
      if (frameTotal != totalExpected) {
        throw FormatException(
          'Total frames mismatch in frame $i: expected $totalExpected, got $frameTotal',
        );
      }
      if (frameIndex != i) {
        throw FormatException(
          'Out of order BLE frame index: $frameIndex, expected $i',
        );
      }
      builder.add(frame.sublist(2));
    }
    return builder.takeBytes();
  }

  Future<void> _cancelActiveScan() async {
    await _activeScanSub?.cancel();
    _activeScanSub = null;
    _inFlightScan = null;
  }

  /// Single flight scan for nearby physical devices with service filter (6101) & scan throttle protection
  Future<DiscoveredDevice> scanForSingleDevice({
    String namePrefix = 'EH-',
    Duration timeout = const Duration(seconds: 15),
  }) async {
    if (_inFlightScan != null) {
      return _inFlightScan!;
    }

    _inFlightScan = _executeScan(namePrefix: namePrefix, timeout: timeout);
    try {
      return await _inFlightScan!;
    } finally {
      _inFlightScan = null;
    }
  }

  Future<DiscoveredDevice> _executeScan({
    required String namePrefix,
    required Duration timeout,
  }) async {
    await _cancelActiveScan();

    // Scan cooldown: ensure at least 2 seconds between scans to prevent Android SCAN_FAILED_SCANNING_TOO_FREQUENTLY
    if (_lastScanTime != null) {
      final elapsed = DateTime.now().difference(_lastScanTime!);
      if (elapsed < const Duration(seconds: 2)) {
        await Future<void>.delayed(const Duration(seconds: 2) - elapsed);
      }
    }
    _lastScanTime = DateTime.now();

    final completer = Completer<DiscoveredDevice>();
    debugPrint(
      '[BLE] BLE_SCAN_START withService=$infoServiceUuid prefix=$namePrefix',
    );

    // Production Service-Filtered scan: 6101
    _activeScanSub = _ble
        .scanForDevices(
          withServices: [infoServiceUuid],
          scanMode: ScanMode.lowLatency,
        )
        .listen(
          (device) {
            if (!completer.isCompleted) {
              debugPrint(
                '[BLE] BLE_DEVICE_FOUND id=${device.id} name=${device.name}',
              );
              completer.complete(device);
            }
          },
          onError: (Object err) {
            debugPrint('[BLE] Scan error: $err');
            if (!completer.isCompleted) {
              completer.completeError(err);
            }
          },
        );

    try {
      final result = await completer.future.timeout(
        timeout,
        onTimeout: () {
          throw TimeoutException('No nearby Smart Home device was found.');
        },
      );
      return result;
    } finally {
      await _cancelActiveScan();
    }
  }

  /// Read 6104 status characteristic to verify Wi-Fi and device state
  Future<Map<String, dynamic>> readStatus([String? deviceId]) async {
    final targetDeviceId = _connectedDeviceId ?? deviceId;
    if (targetDeviceId == null || targetDeviceId.isEmpty) {
      throw StateError('No BLE device connected to read status');
    }
    final statusChar = QualifiedCharacteristic(
      deviceId: targetDeviceId,
      serviceId: infoServiceUuid,
      characteristicId: statusCharUuid,
    );
    final rawBytes = await _ble.readCharacteristic(statusChar);
    final jsonStr = utf8.decode(rawBytes);
    debugPrint('[BLE] 6104_READ raw=$jsonStr');
    try {
      final decoded = jsonDecode(jsonStr);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
    } catch (_) {}
    return <String, dynamic>{};
  }

  /// Establish the single authoritative BLE connection and discover all GATT services.
  Future<void> connect(String deviceId) async {
    await _cancelActiveScan();
    await disconnect();
    _connectedDeviceId = deviceId;

    try {
      await _establishConnectionWithDiscovery(deviceId, allowRetry: true);
    } catch (e) {
      await disconnect();
      rethrow;
    }
  }

  Future<void> _establishConnectionWithDiscovery(
    String deviceId, {
    required bool allowRetry,
  }) async {
    final connectedCompleter = Completer<void>();
    debugPrint('[BLE] BLE_CONNECT_START id=$deviceId');

    _connSub = _ble
        .connectToDevice(
          id: deviceId,
          servicesWithCharacteristicsToDiscover: {
            infoServiceUuid: [
              telemetryCharUuid,
              statusCharUuid,
              productInfoCharUuid,
            ],
            provServiceUuid: [rxCharUuid, txCharUuid],
          },
          connectionTimeout: const Duration(seconds: 15),
        )
        .listen(
          (update) {
            if (update.connectionState == DeviceConnectionState.connected) {
              _isConnected = true;
              debugPrint('[BLE] BLE_CONNECTED id=$deviceId');
              if (!connectedCompleter.isCompleted) {
                connectedCompleter.complete();
              }
            } else if (update.connectionState ==
                DeviceConnectionState.disconnected) {
              _isConnected = false;
              _isGattReady = false;
              debugPrint('[BLE] BLE_DISCONNECTED id=$deviceId');
              if (!connectedCompleter.isCompleted) {
                connectedCompleter.completeError(
                  TimeoutException(
                    'Device disconnected before connection completed',
                  ),
                );
              }
            }
          },
          onError: (Object err, StackTrace st) {
            _isConnected = false;
            _isGattReady = false;
            if (!connectedCompleter.isCompleted) {
              connectedCompleter.completeError(err, st);
            }
          },
        );

    await connectedCompleter.future.timeout(
      const Duration(seconds: 15),
      onTimeout: () => throw TimeoutException('BLE connection timed out'),
    );

    // Negotiate higher MTU on Android to read the complete 140-byte 6105 product JSON in one transaction
    if (Platform.isAndroid) {
      try {
        final negotiatedMtu = await _ble.requestMtu(
          deviceId: deviceId,
          mtu: 256,
        );
        debugPrint('[BLE] MTU negotiated: $negotiatedMtu');
      } catch (e) {
        debugPrint('[BLE] MTU request error (continuing): $e');
      }
    }

    // Explicit service discovery
    debugPrint('[BLE] GATT_DISCOVERY_START');
    await _ble.discoverAllServices(deviceId);
    final services = await _ble.getDiscoveredServices(deviceId);
    debugPrint('[BLE] GATT_DISCOVERY_COMPLETE count=${services.length}');

    Service? infoService;
    Service? provService;

    for (final s in services) {
      if (s.id == infoServiceUuid) {
        infoService = s;
      } else if (s.id == provServiceUuid) {
        provService = s;
      }
    }

    final hasProductInfo =
        infoService != null &&
        infoService.characteristics.any((c) => c.id == productInfoCharUuid);

    final hasRx =
        provService != null &&
        provService.characteristics.any((c) => c.id == rxCharUuid);

    final hasTx =
        provService != null &&
        provService.characteristics.any((c) => c.id == txCharUuid);

    if (infoService == null ||
        provService == null ||
        !hasProductInfo ||
        !hasRx ||
        !hasTx) {
      if (allowRetry && Platform.isAndroid) {
        debugPrint(
          '[BLE] Missing required characteristics after discovery (infoService=${infoService != null}, provService=${provService != null}, prodInfo=$hasProductInfo, rx=$hasRx, tx=$hasTx). Clearing GATT cache and retrying...',
        );
        try {
          await _ble.clearGattCache(deviceId);
        } catch (_) {}
        await disconnect();
        _connectedDeviceId = deviceId;
        return await _establishConnectionWithDiscovery(
          deviceId,
          allowRetry: false,
        );
      }

      throw GattDiscoveryException(
        'Characteristic not found or discovered on $deviceId: '
        'infoService=${infoService != null}, productInfo=$hasProductInfo, '
        'provService=${provService != null}, 6110(rx)=$hasRx, 6111(tx)=$hasTx',
      );
    }

    debugPrint('[BLE] GATT_SERVICE_OK (6101 & 6102 verified)');

    // Subscribe to TX (6111) notifications
    final txChar = QualifiedCharacteristic(
      deviceId: deviceId,
      serviceId: provServiceUuid,
      characteristicId: txCharUuid,
    );

    await _notifySub?.cancel();
    _resetReassemblyState();

    _notifySub = _ble
        .subscribeToCharacteristic(txChar)
        .listen(
          _handleIncomingNotificationFrame,
          onError: (Object err) {
            debugPrint('[BLE] TX notification error: $err');
          },
        );

    debugPrint('[BLE] BLE_TX_NOTIFY_SUBSCRIBED');
    _isGattReady = true;

    // Read and parse product info from 6105
    _deviceIdentity = await readProductInfo(deviceId);
  }

  /// Read 6105 product info and validate JSON schema
  Future<OnboardingDeviceIdentity> readProductInfo(String deviceId) async {
    final productChar = QualifiedCharacteristic(
      deviceId: deviceId,
      serviceId: infoServiceUuid,
      characteristicId: productInfoCharUuid,
    );

    debugPrint('[BLE] GATT_6105_READ_START');
    final rawBytes = await _ble.readCharacteristic(productChar);
    debugPrint('[BLE] GATT_6105_READ_OK byteCount=${rawBytes.length}');
    final jsonStr = utf8.decode(rawBytes);

    try {
      final decoded = jsonDecode(jsonStr);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('Product info JSON must be an object');
      }

      final product = decoded['product'] as String? ?? decoded['p'] as String?;
      final devId = decoded['deviceId'] as String?;
      final serial = decoded['serialNumber'] as String?;
      final variant =
          decoded['variant'] as String? ??
          decoded['productVariantId'] as String? ??
          'eh-smart-switch-3x';

      if (product == null || devId == null || serial == null) {
        throw FormatException(
          'Missing required product info fields in payload: $jsonStr',
        );
      }

      return OnboardingDeviceIdentity(
        deviceId: devId,
        serialNumber: serial,
        productVariantId: variant,
        hardwareRevision: 'HW_1_0',
        firmwareFamily: 'esp32-switch-platform',
        displayName: product,
      );
    } catch (e) {
      throw FormatException(
        'Failed to parse device product info (6105): $e (raw: "$jsonStr")',
      );
    }
  }

  void _resetReassemblyState() {
    _reassemblyBuilder = null;
    _nextExpectedFrame = 0;
    _totalFramesExpected = 0;
    _reassemblyInProgress = false;
  }

  void _handleIncomingNotificationFrame(List<int> rawData) {
    if (rawData.length < 2) {
      debugPrint('[BLE] Notification frame too short: ${rawData.length} bytes');
      return;
    }

    final frameIndex = rawData[0];
    final totalFrames = rawData[1];
    final chunk = rawData.sublist(2);

    if (frameIndex == 0) {
      _reassemblyBuilder = BytesBuilder(copy: false)..add(chunk);
      _nextExpectedFrame = 1;
      _totalFramesExpected = totalFrames;
      _reassemblyInProgress = true;

      if (totalFrames == 1) {
        final completeMsg = _reassemblyBuilder!.takeBytes();
        _resetReassemblyState();
        _responseController.add(completeMsg);
      }
    } else {
      if (!_reassemblyInProgress ||
          frameIndex != _nextExpectedFrame ||
          totalFrames != _totalFramesExpected) {
        debugPrint(
          '[BLE] Out of order frame: index $frameIndex, expected $_nextExpectedFrame, total $totalFrames (expected $_totalFramesExpected)',
        );
        _resetReassemblyState();
        return;
      }

      _reassemblyBuilder!.add(chunk);
      _nextExpectedFrame++;

      if (_nextExpectedFrame == _totalFramesExpected) {
        final completeMsg = _reassemblyBuilder!.takeBytes();
        _resetReassemblyState();
        _responseController.add(completeMsg);
      }
    }
  }

  /// Write logical message to 6110 using sequential frame chunks
  Future<void> writeMessage(
    Uint8List data, {
    QualifiedCharacteristic? customChar,
  }) async {
    final devId = customChar?.deviceId ?? _connectedDeviceId;
    if (devId == null || !_isConnected) {
      throw StateError('Cannot write message: BLE channel not connected');
    }
    final targetChar =
        customChar ??
        QualifiedCharacteristic(
          deviceId: devId,
          serviceId: provServiceUuid,
          characteristicId: rxCharUuid,
        );

    final frames = fragmentPayload(data, chunkSize: 16);
    for (int i = 0; i < frames.length; i++) {
      final frame = frames[i];
      await _ble.writeCharacteristicWithResponse(
        targetChar,
        value: frame.toList(),
      );
    }
  }

  /// Send fragmented request and await reassembled response message
  Future<Uint8List> sendAndReceive(
    Uint8List request, {
    Duration timeout = const Duration(seconds: 15),
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
      return await responseCompleter.future.timeout(
        timeout,
        onTimeout: () => throw TimeoutException('BLE response timed out'),
      );
    } finally {
      await sub.cancel();
    }
  }

  Future<void> disconnect() async {
    _isConnected = false;
    _isGattReady = false;
    _connectedDeviceId = null;
    _deviceIdentity = null;
    _resetReassemblyState();

    await _cancelActiveScan();

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
