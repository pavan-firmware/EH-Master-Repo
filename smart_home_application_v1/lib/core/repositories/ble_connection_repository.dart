import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:permission_handler/permission_handler.dart';

import '../config/device_connection_config.dart';
import '../../features/onboarding/models/onboarding_models.dart';
import 'connection_repository.dart';

class BleConnectionRepository implements ConnectionRepository {
  BleConnectionRepository({FlutterReactiveBle? ble}) : _customBle = ble;

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

  StreamSubscription<ConnectionStateUpdate>? _connectionSubscription;

  /// Scans for physical EH Home devices emitting service 6101 or EH- prefix.
  Stream<DiscoveredDevice> scanNearby({
    Duration timeout = const Duration(seconds: 20),
  }) async* {
    final ble = _ble;
    if (ble == null) return;

    try {
      await _requestBluetoothPermission();
    } catch (_) {}

    final serviceUuid = Uuid.parse(deviceConnectionConfig.bleServiceUuid);
    final seenIds = <String>{};

    yield* ble
        .scanForDevices(withServices: const [], scanMode: ScanMode.lowLatency)
        .where((device) {
          if (seenIds.contains(device.id)) return false;
          final name = device.name.trim().toUpperCase();
          final matchesName =
              name.startsWith('EH-') ||
              name.startsWith('SH-') ||
              name.contains('EH-SW') ||
              name.contains('SMART SWITCH') ||
              name.startsWith(
                deviceConnectionConfig.deviceNamePrefix.toUpperCase(),
              );
          final matchesService = device.serviceUuids.contains(serviceUuid);

          if (matchesName || matchesService) {
            seenIds.add(device.id);
            return true;
          }
          return false;
        })
        .timeout(timeout, onTimeout: (sink) => sink.close());
  }

  /// Connects to a discovered device and reads canonical product info from 6105.
  Future<OnboardingDeviceIdentity> readProductMetadata(String deviceId) async {
    final ble = _ble;
    if (ble == null) {
      throw const ConnectionFailure(
        ConnectionFailureKind.bluetoothUnavailable,
        'Bluetooth is off or unavailable.',
      );
    }

    await _requestBluetoothPermission();
    await _waitForBluetooth(ble);

    final serviceUuid = Uuid.parse(deviceConnectionConfig.bleServiceUuid);
    final productInfoUuid = Uuid.parse(
      deviceConnectionConfig.productInfoCharacteristicUuid,
    );

    final connected = Completer<void>();
    final connSub = ble
        .connectToDevice(
          id: deviceId,
          servicesWithCharacteristicsToDiscover: {
            serviceUuid: [productInfoUuid],
          },
          connectionTimeout: const Duration(seconds: 12),
        )
        .listen(
          (update) {
            if (update.connectionState == DeviceConnectionState.connected &&
                !connected.isCompleted) {
              connected.complete();
            } else if (update.connectionState ==
                    DeviceConnectionState.disconnected &&
                !connected.isCompleted) {
              connected.completeError(
                const ConnectionFailure(
                  ConnectionFailureKind.deviceDisconnected,
                  'The nearby device disconnected before setup completed.',
                  step: ConnectionStep.pairing,
                ),
              );
            }
          },
          onError: (Object err, StackTrace st) {
            if (!connected.isCompleted) connected.completeError(err, st);
          },
        );

    try {
      await connected.future.timeout(const Duration(seconds: 12));
      await ble.discoverAllServices(deviceId);

      final rawBytes = await ble.readCharacteristic(
        QualifiedCharacteristic(
          deviceId: deviceId,
          serviceId: serviceUuid,
          characteristicId: productInfoUuid,
        ),
      );

      final jsonStr = utf8.decode(rawBytes);
      final dynamic decoded = jsonDecode(jsonStr);
      if (decoded is! Map<String, dynamic>) {
        throw const ConnectionFailure(
          ConnectionFailureKind.unsupportedDevice,
          'Device returned invalid product metadata format.',
          step: ConnectionStep.identification,
        );
      }

      final product =
          decoded['product'] as String? ??
          decoded['p'] as String? ??
          decoded['displayName'] as String? ??
          'EH Smart Switch 3X';
      final devId = decoded['deviceId'] as String? ?? deviceId;
      final serial =
          decoded['serialNumber'] as String? ??
          decoded['serial'] as String? ??
          deviceId;
      final variant = decoded['variant'] as String? ?? 'eh-smart-switch-3x';

      return OnboardingDeviceIdentity(
        deviceId: devId,
        serialNumber: serial,
        productVariantId: variant,
        hardwareRevision: 'HW_1_0',
        firmwareFamily: 'esp32-switch-platform',
        displayName: product,
      );
    } finally {
      await connSub.cancel();
    }
  }

  @override
  Future<ConnectionResult> connect({
    required DeviceConnectionConfig config,
  }) async {
    try {
      final ble = _ble;
      if (ble == null) {
        throw const ConnectionFailure(
          ConnectionFailureKind.bluetoothUnavailable,
          'Bluetooth is off or unavailable. Turn it on and try again.',
        );
      }

      await _requestBluetoothPermission();
      await _waitForBluetooth(ble);

      final serviceUuid = Uuid.parse(config.bleServiceUuid);
      final candidates = await ble
          .scanForDevices(withServices: const [], scanMode: ScanMode.lowLatency)
          .where(
            (candidate) =>
                candidate.name.trim().toUpperCase().startsWith('EH-') ||
                candidate.name.trim().toUpperCase().startsWith('SH-') ||
                candidate.name.trim().toUpperCase().startsWith(
                  config.deviceNamePrefix.toUpperCase(),
                ) ||
                candidate.serviceUuids.contains(serviceUuid),
          )
          .take(1)
          .timeout(const Duration(seconds: 15))
          .toList();
      if (candidates.isEmpty) {
        throw const ConnectionFailure(
          ConnectionFailureKind.scanTimedOut,
          'No nearby Smart Home device was found. Make sure it is powered on and close to your phone.',
        );
      }
      final device = candidates.first;

      await _connectionSubscription?.cancel();
      final productInfoUuid = Uuid.parse(config.productInfoCharacteristicUuid);
      final connected = Completer<void>();
      _connectionSubscription = ble
          .connectToDevice(
            id: device.id,
            servicesWithCharacteristicsToDiscover: {
              serviceUuid: [
                Uuid.parse(config.telemetryCharacteristicUuid),
                Uuid.parse(config.statusCharacteristicUuid),
                productInfoUuid,
              ],
            },
            connectionTimeout: const Duration(seconds: 12),
          )
          .listen(
            (update) {
              if (update.connectionState == DeviceConnectionState.connected &&
                  !connected.isCompleted) {
                connected.complete();
              }
              if (update.connectionState ==
                      DeviceConnectionState.disconnected &&
                  !connected.isCompleted) {
                connected.completeError(
                  const ConnectionFailure(
                    ConnectionFailureKind.deviceDisconnected,
                    'The nearby device disconnected before setup completed.',
                    step: ConnectionStep.pairing,
                  ),
                );
              }
            },
            onError: (Object error, StackTrace stackTrace) {
              if (!connected.isCompleted) {
                connected.completeError(error, stackTrace);
              }
            },
          );
      await connected.future.timeout(const Duration(seconds: 15));

      await ble.discoverAllServices(device.id);
      final services = await ble.getDiscoveredServices(device.id);
      final matchingServices = services.where(
        (service) => service.id == serviceUuid,
      );
      if (matchingServices.isEmpty ||
          !matchingServices.first.characteristics.any(
            (characteristic) => characteristic.id == productInfoUuid,
          )) {
        throw const ConnectionFailure(
          ConnectionFailureKind.unsupportedDevice,
          'This nearby device does not use the approved EH Home service.',
          step: ConnectionStep.identification,
        );
      }

      final productInfo = await ble.readCharacteristic(
        QualifiedCharacteristic(
          deviceId: device.id,
          serviceId: serviceUuid,
          characteristicId: productInfoUuid,
        ),
      );
      final product = _readProductName(productInfo);
      return ConnectionResult(
        success: true,
        message: 'Connected to $product (${device.name}).',
        step: ConnectionStep.verification,
      );
    } on TimeoutException {
      return const ConnectionResult(
        success: false,
        message:
            'No nearby Smart Home device was found. Make sure it is powered on and close to your phone.',
        failureKind: ConnectionFailureKind.scanTimedOut,
      );
    } on ConnectionFailure catch (failure) {
      return ConnectionResult(
        success: false,
        message: failure.message,
        step: failure.step,
        failureKind: failure.kind,
      );
    } catch (error) {
      return ConnectionResult(
        success: false,
        message: 'Nearby connection failed: $error',
        failureKind: ConnectionFailureKind.unknown,
      );
    }
  }

  Future<void> _requestBluetoothPermission() async {
    if (Platform.isAndroid) {
      try {
        await [
          Permission.bluetoothScan,
          Permission.bluetoothConnect,
          Permission.locationWhenInUse,
        ].request();
      } catch (_) {}
    } else if (Platform.isIOS) {
      try {
        await Permission.bluetooth.request();
      } catch (_) {}
    }
  }

  Future<void> _waitForBluetooth(FlutterReactiveBle ble) {
    return ble.statusStream
        .where((status) => status == BleStatus.ready)
        .first
        .timeout(
          const Duration(seconds: 10),
          onTimeout: () => throw const ConnectionFailure(
            ConnectionFailureKind.bluetoothUnavailable,
            'Bluetooth is off or unavailable. Turn it on and try again.',
          ),
        );
  }

  String _readProductName(List<int> bytes) {
    try {
      final value = jsonDecode(utf8.decode(bytes));
      if (value case {'product': String product}) return product;
      if (value case {'p': String product}) return product;
      if (value case {'displayName': String name}) return name;
    } catch (_) {
      // The connection itself is still valid even if a development build sends malformed metadata.
    }
    return 'EH Smart Switch 3X';
  }
}
