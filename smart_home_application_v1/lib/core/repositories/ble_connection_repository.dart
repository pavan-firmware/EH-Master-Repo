import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:permission_handler/permission_handler.dart';

import '../config/device_connection_config.dart';
import 'connection_repository.dart';

/// Development connection path: scan -> connect -> verify service -> read
/// public product metadata. It deliberately has no actuator-control methods.
class BleConnectionRepository implements ConnectionRepository {
  BleConnectionRepository({FlutterReactiveBle? ble})
    : _ble = ble ?? FlutterReactiveBle();

  final FlutterReactiveBle _ble;
  StreamSubscription<ConnectionStateUpdate>? _connectionSubscription;

  @override
  Future<ConnectionResult> connect({
    required DeviceConnectionConfig config,
  }) async {
    try {
      await _requestBluetoothPermission();
      await _waitForBluetooth();

      final serviceUuid = Uuid.parse(config.bleServiceUuid);
      final candidates = await _ble
          .scanForDevices(withServices: const [], scanMode: ScanMode.lowLatency)
          .where(
            (candidate) =>
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
      _connectionSubscription = _ble
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

      await _ble.discoverAllServices(device.id);
      final services = await _ble.getDiscoveredServices(device.id);
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

      final productInfo = await _ble.readCharacteristic(
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
      // Android 11 and earlier will return no BLE scan results until the
      // user grants location permission. Requesting it on newer versions is
      // harmless because it is excluded from the manifest above API 30.
      final location = await Permission.locationWhenInUse.request();
      if (location.isPermanentlyDenied) {
        throw const ConnectionFailure(
          ConnectionFailureKind.permissionPermanentlyDenied,
          'Location permission was permanently denied. Android needs it to find nearby BLE devices on this phone.',
        );
      }
      if (!location.isGranted && !location.isLimited) {
        throw const ConnectionFailure(
          ConnectionFailureKind.permissionDenied,
          'Location permission is required to find nearby BLE devices on this phone.',
        );
      }
      final statuses = await [
        Permission.bluetoothScan,
        Permission.bluetoothConnect,
      ].request();
      if (statuses.values.any((status) => status.isPermanentlyDenied)) {
        throw const ConnectionFailure(
          ConnectionFailureKind.permissionPermanentlyDenied,
          'Bluetooth permission was permanently denied. Enable it in app settings to continue.',
        );
      }
      if (statuses.values.any(
        (status) => !status.isGranted && !status.isLimited,
      )) {
        throw const ConnectionFailure(
          ConnectionFailureKind.permissionDenied,
          'Bluetooth permission is required to find your nearby device.',
        );
      }
    } else if (Platform.isIOS) {
      final status = await Permission.bluetooth.request();
      if (status.isPermanentlyDenied) {
        throw const ConnectionFailure(
          ConnectionFailureKind.permissionPermanentlyDenied,
          'Bluetooth permission was permanently denied. Enable it in Settings to continue.',
        );
      }
      if (!status.isGranted) {
        throw const ConnectionFailure(
          ConnectionFailureKind.permissionDenied,
          'Bluetooth permission was not granted.',
        );
      }
    }
  }

  Future<void> _waitForBluetooth() {
    return _ble.statusStream
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
    } catch (_) {
      // The connection itself is still valid even if a development build sends malformed metadata.
    }
    return 'Smart Home device';
  }
}
