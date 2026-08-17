import 'package:flutter/foundation.dart';

import '../core/models/device_models.dart';
import '../core/models/home_dashboard_models.dart';
import '../core/repositories/fake_home_repository.dart';
import '../core/repositories/home_repository.dart';
import '../core/repositories/connection_repository.dart';
import '../core/repositories/ble_connection_repository.dart';
import '../core/config/device_connection_config.dart';

/// Temporary local implementation of the app/device contract.
///
/// Replace the simulated delay in each command with BLE GATT, local-hub, or
/// cloud calls. The UI only treats a command as complete after this controller
/// receives its acknowledgement.
class HomeController extends ChangeNotifier {
  HomeController({
    HomeRepository? repository,
    ConnectionRepository? connectionRepository,
  }) : _repository = repository ?? FakeHomeRepository(),
       _connectionRepository =
           connectionRepository ?? BleConnectionRepository();

  final HomeRepository _repository;
  final ConnectionRepository _connectionRepository;
  static const bool _secureActuatorCommandsAvailable = false;
  bool _awayMode = false;
  bool _livingRoomLightOn = true;
  bool _misting = false;
  bool _alertAcknowledged = false;
  bool _lightCommandPending = false;
  bool _mistingCommandPending = false;
  bool _showDesignPreview = true;
  ActuatorConfidence _lightConfidence = ActuatorConfidence.unknown;
  FirmwareRelease? _availableRelease;
  HomeConnectionState _connectionState = HomeConnectionState.notConfigured;
  String? _connectionMessage;

  bool get awayMode => _awayMode;
  bool get livingRoomLightOn => _livingRoomLightOn;
  bool get misting => _misting;
  bool get alertAcknowledged => _alertAcknowledged;
  bool get lightCommandPending => _lightCommandPending;
  bool get mistingCommandPending => _mistingCommandPending;
  FirmwareRelease? get availableRelease => _availableRelease;
  HomeConnectionState get connectionState => _connectionState;
  String? get connectionMessage => _connectionMessage;
  ActuatorConfidence get lightConfidence => _lightConfidence;
  bool get hardwareControlsAvailable => _secureActuatorCommandsAvailable;

  /// The completed-home preview exists only until the user starts connecting a
  /// real device. Once BLE succeeds, the dashboard correctly moves to Wi-Fi
  /// setup instead of pretending that a BLE-only node is online at home.
  HomeDashboardData get dashboard {
    if (_showDesignPreview) {
      return HomeDashboardData.designPreview(
        lightOn: _livingRoomLightOn,
        lightConfidence: _lightConfidence,
      );
    }

    switch (_connectionState) {
      case HomeConnectionState.connecting:
        return HomeDashboardData.setup(
          state: HomeDashboardState.loading,
          title: 'Finding your device',
          message: 'Keep your phone close to the powered-on home device.',
          action: 'Searching nearby…',
          connectivity: ConnectivityCause.bleDisconnected,
        );
      case HomeConnectionState.connected:
        return HomeDashboardData.setup(
          state: HomeDashboardState.wifiRequired,
          title: 'Almost there',
          message:
              'SH-8EF248 is connected nearby. Connect it to your home Wi-Fi to finish setup.',
          action: 'Continue setup',
          connectivity: ConnectivityCause.wifiUnavailable,
        );
      case HomeConnectionState.failed:
      case HomeConnectionState.offline:
        return HomeDashboardData.setup(
          state: HomeDashboardState.offline,
          title: 'Device unavailable',
          message:
              _connectionMessage ??
              'Make sure the device is powered on and nearby.',
          action: 'Try again',
          connectivity: ConnectivityCause.deviceOffline,
        );
      case HomeConnectionState.notConfigured:
        return HomeDashboardData.setup(
          state: HomeDashboardState.setupRequired,
          title: 'Connect your first device',
          message: 'Add a nearby device to get your home up and running.',
          action: 'Add a device',
          connectivity: ConnectivityCause.unknown,
        );
    }
  }

  Future<ConnectionResult> startConnectionSetup() async {
    _showDesignPreview = false;
    _connectionState = HomeConnectionState.connecting;
    _connectionMessage = 'Looking for your home device nearby';
    notifyListeners();

    final result = await _connectionRepository.connect(
      config: deviceConnectionConfig,
    );
    _connectionState = result.success
        ? HomeConnectionState.connected
        : HomeConnectionState.failed;
    _connectionMessage = result.message;
    notifyListeners();
    return result;
  }

  Future<FirmwareRelease?> loadAvailableRelease() async {
    _availableRelease = await _repository.getAvailableRelease();
    notifyListeners();
    return _availableRelease;
  }

  void setAwayMode(bool value) {
    _awayMode = value;
    notifyListeners();
  }

  Future<void> setLivingRoomLight(bool value) async {
    if (_lightCommandPending || _livingRoomLightOn == value) return;
    if (!_secureActuatorCommandsAvailable) {
      _lightConfidence = ActuatorConfidence.unavailable;
      notifyListeners();
      return;
    }
    _lightCommandPending = true;
    _lightConfidence = ActuatorConfidence.pending;
    notifyListeners();

    try {
      final receipt = await _repository.sendCommand(
        deviceId: 'living-room-light',
        action: 'set_power',
        parameters: {'enabled': value},
        idempotencyKey: 'light-${DateTime.now().microsecondsSinceEpoch}',
      );
      if (receipt.state == CommandState.succeeded) {
        _livingRoomLightOn = value;
        _lightConfidence = ActuatorConfidence.confirmed;
      } else {
        _lightConfidence = ActuatorConfidence.failed;
      }
    } catch (_) {
      _lightConfidence = ActuatorConfidence.failed;
    }
    _lightCommandPending = false;
    notifyListeners();
  }

  Future<void> setMisting(bool value) async {
    if (_mistingCommandPending || _misting == value) return;
    if (!_secureActuatorCommandsAvailable) {
      notifyListeners();
      return;
    }
    _mistingCommandPending = true;
    notifyListeners();

    final receipt = await _repository.sendCommand(
      deviceId: 'plant-mister',
      action: 'set_misting',
      parameters: {'enabled': value},
      idempotencyKey: 'misting-${DateTime.now().microsecondsSinceEpoch}',
    );
    if (receipt.state == CommandState.succeeded) {
      _misting = value;
    }
    _mistingCommandPending = false;
    notifyListeners();
  }

  void acknowledgeAlert() {
    _alertAcknowledged = true;
    notifyListeners();
  }
}
