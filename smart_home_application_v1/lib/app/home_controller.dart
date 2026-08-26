import 'dart:async';
import 'package:flutter/foundation.dart';

import '../core/models/device_models.dart';
import '../core/models/home_dashboard_models.dart';
import '../core/repositories/home_repository.dart';
import '../core/repositories/fake_home_repository.dart';
import '../core/repositories/connection_repository.dart';
import '../core/repositories/ble_connection_repository.dart';
import '../core/config/device_connection_config.dart';
import '../core/services/realtime_event_service.dart';

/// HomeController manages all home/device/connection state.
///
/// In production (Phase 7C), pass [repository] = CloudHomeRepository
/// and [realtimeEventService] = RealtimeEventService. The FakeHomeRepository
/// is retained as the default so all pre-existing tests continue to pass.
class HomeController extends ChangeNotifier {
  HomeController({
    HomeRepository? repository,
    ConnectionRepository? connectionRepository,
    RealtimeEventService? realtimeEventService,
    this._cloudEnabled = false,
  })  : _repository = repository ?? FakeHomeRepository(),
        _connectionRepository =
            connectionRepository ?? BleConnectionRepository() {
    if (realtimeEventService != null) {
      _subscribeToRealtime(realtimeEventService);
    }
  }

  final HomeRepository _repository;
  final ConnectionRepository _connectionRepository;

  /// True when a real authenticated backend is powering this controller.
  final bool _cloudEnabled;

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
  DeviceConnection _cloudDeviceConnection = DeviceConnection.offline;
  
  StreamSubscription<SSEEventEnvelope>? _sseSubscription;

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

  /// Commands are only available when cloud is enabled (authenticated + connected).
  bool get hardwareControlsAvailable => _cloudEnabled;
  DeviceConnection get cloudDeviceConnection => _cloudDeviceConnection;

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

  void _subscribeToRealtime(RealtimeEventService service) {
    _sseSubscription = service.events.listen(_handleSseEvent);
  }

  void _handleSseEvent(SSEEventEnvelope envelope) {
    switch (envelope.type) {
      case 'device.availability':
        final status = envelope.payload['status'] as String?;
        if (status == 'ONLINE') {
          _cloudDeviceConnection = DeviceConnection.online;
        } else if (status == 'STALE') {
          _cloudDeviceConnection = DeviceConnection.stale;
        } else {
          _cloudDeviceConnection = DeviceConnection.offline;
        }
        notifyListeners();
        break;

      case 'device.state':
        // Authoritative state convergence for toggle channels
        final state = envelope.payload;
        if (state.containsKey('channels') && state['channels'] is Map) {
          final channels = state['channels'] as Map;
          // ch1 → living room light
          if (channels.containsKey('ch1')) {
            final ch1 = channels['ch1'] as Map?;
            final relay = ch1?['relay'] as bool?;
            if (relay != null) {
              _livingRoomLightOn = relay;
              _lightConfidence = ActuatorConfidence.confirmed;
              _lightCommandPending = false;
            }
          }
        }
        notifyListeners();
        break;

      case 'command.receipt':
        final cmdStatus = envelope.payload['status'] as String?;
        if (cmdStatus == 'APPLIED' || cmdStatus == 'DELIVERED') {
          _lightConfidence = ActuatorConfidence.confirmed;
          _lightCommandPending = false;
        } else if (cmdStatus == 'FAILED' || cmdStatus == 'TIMEOUT' || cmdStatus == 'OVERRIDDEN') {
          _lightConfidence = ActuatorConfidence.failed;
          _lightCommandPending = false;
        }
        notifyListeners();
        break;

      default:
        break;
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
    if (!_cloudEnabled) {
      _lightConfidence = ActuatorConfidence.unavailable;
      notifyListeners();
      return;
    }
    _lightCommandPending = true;
    _lightConfidence = ActuatorConfidence.pending;
    notifyListeners();

    try {
      await _repository.sendCommand(
        deviceId: 'living-room-light',
        action: 'set_power',
        parameters: {'enabled': value},
        idempotencyKey: 'light-${DateTime.now().microsecondsSinceEpoch}',
      );
      // Do NOT assume state changed. Wait for command.receipt + device.state via SSE.
      // _lightCommandPending stays true until SSE receipt clears it.
    } catch (_) {
      _lightConfidence = ActuatorConfidence.failed;
      _lightCommandPending = false;
      notifyListeners();
    }
  }

  Future<void> setMisting(bool value) async {
    if (_mistingCommandPending || _misting == value) return;
    if (!_cloudEnabled) {
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

  @override
  void dispose() {
    _sseSubscription?.cancel();
    super.dispose();
  }
}
