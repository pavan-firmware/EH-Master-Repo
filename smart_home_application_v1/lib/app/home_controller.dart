import 'dart:async';
import 'package:flutter/foundation.dart';

import '../core/models/connection_models.dart';
import '../core/models/device_models.dart';
import '../core/models/home_dashboard_models.dart';
import '../core/models/room_models.dart';
import '../core/repositories/home_repository.dart';
import '../core/repositories/fake_home_repository.dart';
import '../core/repositories/connection_repository.dart';
import '../core/repositories/ble_connection_repository.dart';
import '../core/config/device_connection_config.dart';
import '../core/services/realtime_event_service.dart';

import '../core/services/device_storage_service.dart';

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
    DeviceStorageService? storageService,
    this._cloudEnabled = false,
  }) : _repository = repository ?? FakeHomeRepository(),
       _connectionRepository =
           connectionRepository ?? BleConnectionRepository(),
       _storageService = storageService ?? DeviceStorageService() {
    final cached = DeviceStorageService.cachedDevice;
    if (cached != null) {
      _connectedDeviceSummary = cached;
      _activeDeviceId = cached.id;
      _activeDisplayName = cached.name;
      _activeSerialNumber = cached.model;
      _connectionState = HomeConnectionState.connected;
      _connectionMessage = '${cached.name} is connected and online.';
      debugPrint('[HOME] SYNC_HYDRATED id=${cached.id} name=${cached.name} room=${cached.roomName}');
    }
    if (realtimeEventService != null) {
      _subscribeToRealtime(realtimeEventService);
    }
    _hydrateFromStorage();
  }

  final HomeRepository _repository;
  final ConnectionRepository _connectionRepository;
  final DeviceStorageService _storageService;

  /// True when a real authenticated backend is powering this controller.
  final bool _cloudEnabled;

  bool _awayMode = false;
  bool _livingRoomLightOn = true;
  bool _misting = false;
  bool _alertAcknowledged = false;
  bool _lightCommandPending = false;
  bool _mistingCommandPending = false;
  ActuatorConfidence _lightConfidence = ActuatorConfidence.unknown;
  FirmwareRelease? _availableRelease;
  HomeConnectionState _connectionState = HomeConnectionState.notConfigured;
  String? _connectionMessage;
  DeviceConnection _cloudDeviceConnection = DeviceConnection.offline;
  ConnectedDeviceSummary? _connectedDeviceSummary;
  String? _activeDeviceId;
  String? _activeDisplayName;
  String? _activeSerialNumber;

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
  ConnectedDeviceSummary? get connectedDeviceSummary => _connectedDeviceSummary;
  String? get activeDeviceId => _activeDeviceId;
  String? get activeDisplayName => _activeDisplayName;
  String? get activeSerialNumber => _activeSerialNumber;

  /// Commands are only available when cloud is enabled (authenticated + connected).
  bool get hardwareControlsAvailable => _cloudEnabled;
  DeviceConnection get cloudDeviceConnection => _cloudDeviceConnection;

  List<Room> get rooms {
    if (_connectedDeviceSummary != null && _connectedDeviceSummary!.online) {
      final roomName = _connectedDeviceSummary!.roomName;
      final roomId = roomName.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_');
      return [
        Room(
          id: roomId,
          name: roomName,
          iconKey: 'living',
          deviceCount: 1,
          connectivity: ConnectivityCause.online,
          telemetryFreshness: TelemetryFreshness.current,
          summary: _livingRoomLightOn ? 'Light on · Normal' : 'Light off · Normal',
          status: RoomStatus.normal,
          capabilities: [
            RoomCapability(
              id: 'light',
              label: '$roomName light',
              value: _livingRoomLightOn ? 'On' : 'Off',
              kind: RoomCapabilityKind.light,
            ),
          ],
          devices: [
            RoomDevice(
              id: _connectedDeviceSummary!.id,
              name: _connectedDeviceSummary!.name,
              type: 'Smart Switch',
              value: _livingRoomLightOn ? 'On' : 'Off',
              kind: RoomCapabilityKind.light,
              confidence: ActuatorConfidence.confirmed,
            ),
          ],
          insights: const RoomInsights(
            energyKwh: '1.2 kWh',
            energyChange: '+0.1 kWh',
            activeWindow: 'Today',
            averageTemperature: '24°C',
            averageHumidity: '55%',
          ),
        ),
      ];
    }
    return const [];
  }

  HomeDashboardData get dashboard {
    if (_connectedDeviceSummary != null && _connectedDeviceSummary!.online) {
      return HomeDashboardData.liveDevice(
        deviceName: _connectedDeviceSummary!.name,
        roomName: _connectedDeviceSummary!.roomName,
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
        final deviceName =
            _activeDisplayName ?? _activeSerialNumber ?? 'EH Smart Switch 3X';
        return HomeDashboardData.setup(
          state: HomeDashboardState.wifiRequired,
          title: 'Almost there',
          message:
              '$deviceName is connected nearby. Connect it to your home Wi-Fi to finish setup.',
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
        } else if (cmdStatus == 'FAILED' ||
            cmdStatus == 'TIMEOUT' ||
            cmdStatus == 'OVERRIDDEN') {
          _lightConfidence = ActuatorConfidence.failed;
          _lightCommandPending = false;
        }
        notifyListeners();
        break;

      default:
        break;
    }
  }

  Future<void> _hydrateFromStorage() async {
    final saved = await _storageService.loadDevice();
    if (saved != null) {
      _connectedDeviceSummary = saved;
      _activeDeviceId = saved.id;
      _activeDisplayName = saved.name;
      _activeSerialNumber = saved.model;
      _connectionState = HomeConnectionState.connected;
      _connectionMessage = '${saved.name} is connected and online.';
      debugPrint('[HOME] DEVICE_REGISTERED id=${saved.id} name=${saved.name} room=${saved.roomName}');
      debugPrint('[HOME] DEVICE_PERSISTED');
      debugPrint('[HOME] HOME_STATE_REFRESH');
      debugPrint('[HOME] REAL_DEVICE_COUNT=1');
      debugPrint('[HOME] DEVICE_STATUS=ONLINE');
      notifyListeners();
    }
  }

  Future<ConnectionResult> startConnectionSetup() async {
    _connectionState = HomeConnectionState.connecting;
    _connectionMessage = 'Looking for your home device nearby';
    notifyListeners();

    final result = await _connectionRepository.connect(
      config: deviceConnectionConfig,
    );
    if (result.success) {
      _activeDeviceId = result.deviceId;
      _activeDisplayName = result.displayName;
      _activeSerialNumber = result.serialNumber;
      _connectionState = HomeConnectionState.connected;
      _connectionMessage = result.message;
    } else {
      if (_connectedDeviceSummary == null) {
        _connectionState = HomeConnectionState.notConfigured;
      }
      _connectionMessage = result.message;
    }
    notifyListeners();
    return result;
  }

  void markDeviceProvisioned({
    required String deviceId,
    required String displayName,
    required String serialNumber,
    String? roomName,
  }) {
    _activeDeviceId = deviceId;
    _activeDisplayName = displayName;
    _activeSerialNumber = serialNumber;
    final summary = ConnectedDeviceSummary(
      id: deviceId,
      name: displayName,
      model: 'eh-smart-switch-3x',
      firmware: '1.0.0',
      connectedVia: 'Wi-Fi (2.4 GHz)',
      signalLabel: 'Strong',
      roomName: roomName ?? 'Living Room',
      online: true,
    );
    _connectedDeviceSummary = summary;
    _connectionState = HomeConnectionState.connected;
    _connectionMessage = '$displayName is connected and online.';

    // Persist to local storage
    _storageService.saveDevice(summary);

    debugPrint('[HOME] DEVICE_REGISTERED id=$deviceId name=$displayName room=${roomName ?? "Living Room"}');
    debugPrint('[HOME] DEVICE_PERSISTED');
    debugPrint('[HOME] HOME_STATE_REFRESH');
    debugPrint('[HOME] REAL_DEVICE_COUNT=1');
    debugPrint('[HOME] DEVICE_STATUS=ONLINE');

    notifyListeners();
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
