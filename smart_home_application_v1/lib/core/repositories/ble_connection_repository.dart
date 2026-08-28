import 'dart:async';
import 'dart:io';

import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../features/onboarding/ble/ble_commissioning_channel.dart';
import '../config/device_connection_config.dart';
import 'connection_repository.dart';

/// Production connection path: single BLE connection owner (via [BleCommissioningChannel])
/// that executes: scan -> connect -> explicit GATT discovery (6101 & 6102) -> validate 6105.
class BleConnectionRepository implements ConnectionRepository {
  BleConnectionRepository({
    FlutterReactiveBle? ble,
    BleCommissioningChannel? channel,
  }) : _ble = ble ?? FlutterReactiveBle(),
       _channel = channel ?? BleCommissioningChannel(ble: ble);

  final FlutterReactiveBle _ble;
  final BleCommissioningChannel _channel;

  BleCommissioningChannel get channel => _channel;

  @override
  Future<ConnectionResult> connect({
    required DeviceConnectionConfig config,
  }) async {
    try {
      await _requestBluetoothPermission();
      await _waitForBluetooth();

      final device = await _channel.scanForSingleDevice(
        namePrefix: config.deviceNamePrefix,
        timeout: const Duration(seconds: 15),
      );

      // Connect and discover all services (6101 & 6102) via single session owner
      await _channel.connect(device.id);

      final identity = _channel.deviceIdentity;
      if (identity == null) {
        throw const ConnectionFailure(
          ConnectionFailureKind.unsupportedDevice,
          'Failed to read valid product metadata from device.',
          step: ConnectionStep.identification,
        );
      }

      return ConnectionResult(
        success: true,
        message: 'Connected to ${identity.displayName} (${device.name}).',
        step: ConnectionStep.verification,
        deviceId: identity.deviceId,
        serialNumber: identity.serialNumber,
        displayName: identity.displayName,
        channel: _channel,
      );
    } on TimeoutException {
      return const ConnectionResult(
        success: false,
        message:
            'No nearby Smart Home device was found. Make sure it is powered on and close to your phone.',
        failureKind: ConnectionFailureKind.scanTimedOut,
      );
    } on GattDiscoveryException catch (e) {
      return ConnectionResult(
        success: false,
        message: e.message,
        step: ConnectionStep.identification,
        failureKind: ConnectionFailureKind.unsupportedDevice,
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
      // Request Bluetooth Scan & Connect first (Android 12+)
      final statuses = await [
        Permission.bluetoothScan,
        Permission.bluetoothConnect,
      ].request();

      final scanStatus = statuses[Permission.bluetoothScan];
      final connectStatus = statuses[Permission.bluetoothConnect];

      if (scanStatus?.isPermanentlyDenied == true ||
          connectStatus?.isPermanentlyDenied == true) {
        throw const ConnectionFailure(
          ConnectionFailureKind.permissionPermanentlyDenied,
          'Bluetooth permission was permanently denied. Enable it in app settings to continue.',
        );
      }

      // On Android <= 11, location permission is required for BLE scanning
      if (scanStatus?.isGranted != true && connectStatus?.isGranted != true) {
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
            'Bluetooth or Location permission is required to find nearby devices.',
          );
        }
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

  void dispose() {
    _channel.dispose();
  }
}
