import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';

import '../../features/onboarding/ble/ble_commissioning_channel.dart';
import '../config/device_connection_config.dart';
import '../services/ble_preflight_service.dart';
import 'connection_repository.dart';

/// Production connection path: single BLE connection owner (via [BleCommissioningChannel])
/// that executes: preflight -> scan -> connect -> explicit GATT discovery (6101 & 6102) -> validate 6105.
class BleConnectionRepository implements ConnectionRepository {
  BleConnectionRepository({
    FlutterReactiveBle? ble,
    BleCommissioningChannel? channel,
    BlePreflightService? preflightService,
  }) : _injectedBle = ble,
       _injectedChannel = channel,
       _injectedPreflightService = preflightService;

  final FlutterReactiveBle? _injectedBle;
  final BleCommissioningChannel? _injectedChannel;
  final BlePreflightService? _injectedPreflightService;

  FlutterReactiveBle? _bleInstance;
  BleCommissioningChannel? _channelInstance;
  BlePreflightService? _preflightServiceInstance;

  FlutterReactiveBle? get _ble {
    if (_injectedBle != null) return _injectedBle;
    if (kIsWeb) return null;
    return _bleInstance ??= FlutterReactiveBle();
  }

  BleCommissioningChannel get channel {
    if (_injectedChannel != null) return _injectedChannel;
    return _channelInstance ??= BleCommissioningChannel(ble: _ble);
  }

  BlePreflightService get preflightService {
    if (_injectedPreflightService != null) return _injectedPreflightService;
    return _preflightServiceInstance ??= BlePreflightService(ble: _ble);
  }

  /// Runs explicit pre-flight inspection before triggering any scan.
  Future<BlePreflightResult> checkPreflight({bool requestIfNeeded = true}) async {
    return preflightService.check(requestIfNeeded: requestIfNeeded);
  }

  @override
  Future<ConnectionResult> connect({
    required DeviceConnectionConfig config,
  }) async {
    if (kIsWeb) {
      return const ConnectionResult(
        success: false,
        title: 'Bluetooth not supported',
        message:
            'Bluetooth commissioning is only supported in the mobile application.',
        failureKind: ConnectionFailureKind.bleUnsupported,
      );
    }
    try {
      // 1. Centralized pre-flight check
      final preflight = await preflightService.check(requestIfNeeded: true);
      if (!preflight.isReady) {
        final kind = _mapPreflightStatus(preflight.status);
        return ConnectionResult(
          success: false,
          title: preflight.title,
          message: preflight.message,
          failureKind: kind,
        );
      }

      final activeChannel = channel;

      // 2. Scan for EH Home physical device
      final device = await activeChannel.scanForSingleDevice(
        namePrefix: config.deviceNamePrefix,
        timeout: const Duration(seconds: 15),
      );

      // 3. Connect and discover all services (6101 & 6102) via single session owner
      await activeChannel.connect(device.id, device.name);

      final identity = activeChannel.deviceIdentity;
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
        title: 'Connected',
        step: ConnectionStep.verification,
        deviceId: identity.deviceId,
        serialNumber: identity.serialNumber,
        displayName: identity.displayName,
        channel: activeChannel,
      );
    } on TimeoutException {
      return const ConnectionResult(
        success: false,
        title: 'No EH Home device found nearby',
        message:
            'No EH Home device found nearby. Make sure your Smart Switch is powered on, in commissioning mode, and close to your phone.',
        failureKind: ConnectionFailureKind.scanTimedOut,
      );
    } on GattDiscoveryException catch (e) {
      return ConnectionResult(
        success: false,
        title: 'Device setup error',
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
      final errorStr = error.toString();
      if (errorStr.contains('Location Services disabled') ||
          errorStr.contains('code 4') ||
          errorStr.contains('LocationServicesDisabled')) {
        return const ConnectionResult(
          success: false,
          title: 'Location is turned off',
          message:
              'Location services must be turned on to discover nearby Bluetooth devices on this device.',
          failureKind: ConnectionFailureKind.locationServicesDisabled,
        );
      }
      if (errorStr.contains('Bluetooth disabled') ||
          errorStr.contains('code 1') ||
          errorStr.contains('poweredOff')) {
        return const ConnectionResult(
          success: false,
          title: 'Bluetooth is turned off',
          message:
              'Bluetooth is currently turned off. Turn it on to find your Smart Switch.',
          failureKind: ConnectionFailureKind.bluetoothDisabled,
        );
      }
      if (errorStr.contains('Location permission') ||
          errorStr.contains('code 2') ||
          errorStr.contains('code 3')) {
        return const ConnectionResult(
          success: false,
          title: 'Location permission needed',
          message:
              'Android requires Location permission to discover nearby Bluetooth devices.',
          failureKind: ConnectionFailureKind.locationPermissionRequired,
        );
      }
      if (errorStr.contains('Bluetooth permission') ||
          errorStr.contains('BLUETOOTH_SCAN') ||
          errorStr.contains('BLUETOOTH_CONNECT')) {
        return const ConnectionResult(
          success: false,
          title: 'Bluetooth permission needed',
          message:
              'Bluetooth permission is required to find and connect to your Smart Switch.',
          failureKind: ConnectionFailureKind.bluetoothPermissionRequired,
        );
      }
      return ConnectionResult(
        success: false,
        title: 'Nearby connection failed',
        message: 'Nearby connection failed: $error',
        failureKind: ConnectionFailureKind.unknown,
      );
    }
  }

  static ConnectionFailureKind _mapPreflightStatus(BlePreflightStatus status) {
    return switch (status) {
      BlePreflightStatus.ready => ConnectionFailureKind.none,
      BlePreflightStatus.bluetoothPermissionRequired =>
        ConnectionFailureKind.bluetoothPermissionRequired,
      BlePreflightStatus.bluetoothPermissionPermanentlyDenied =>
        ConnectionFailureKind.bluetoothPermissionPermanentlyDenied,
      BlePreflightStatus.bluetoothDisabled =>
        ConnectionFailureKind.bluetoothDisabled,
      BlePreflightStatus.locationPermissionRequired =>
        ConnectionFailureKind.locationPermissionRequired,
      BlePreflightStatus.locationPermissionPermanentlyDenied =>
        ConnectionFailureKind.locationPermissionPermanentlyDenied,
      BlePreflightStatus.locationServicesDisabled =>
        ConnectionFailureKind.locationServicesDisabled,
      BlePreflightStatus.bleUnsupported =>
        ConnectionFailureKind.bleUnsupported,
      BlePreflightStatus.bleInitializing =>
        ConnectionFailureKind.bleInitializing,
    };
  }

  void dispose() {
    _injectedChannel?.dispose();
  }
}
