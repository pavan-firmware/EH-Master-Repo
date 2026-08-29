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

import '../core/utils/device_name_formatter.dart';

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
    final cachedList = DeviceStorageService.cachedDevices;
    if (cachedList.isNotEmpty) {
      _devices = List.from(cachedList);
      _connectedDeviceSummary = _devices.first;
      _activeDeviceId = _devices.first.id;
      _activeDisplayName = _devices.first.name;
      _activeSerialNumber = _devices.first.model;
      _connectionState = HomeConnectionState.connected;
      _connectionMessage = '${_devices.first.name} is connected and online.';
      debugPrint('[HOME] SYNC_HYDRATED devices_count=${_devices.length}');
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
  bool _livingRoomLightOn = false;
  bool _misting = false;
  bool _alertAcknowledged = false;
  bool _lightCommandPending = false;
  bool _mistingCommandPending = false;
  bool _disposed = false;
  ActuatorConfidence _lightConfidence = ActuatorConfidence.unknown;
  FirmwareRelease? _availableRelease;
  HomeConnectionState _connectionState = HomeConnectionState.notConfigured;
  String? _connectionMessage;
  DeviceConnection _cloudDeviceConnection = DeviceConnection.offline;
  ConnectedDeviceSummary? _connectedDeviceSummary;
  List<ConnectedDeviceSummary> _devices = [];
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
  List<ConnectedDeviceSummary> get devices => List.unmodifiable(_devices);
  String? get activeDeviceId => _activeDeviceId;
  String? get activeDisplayName => _activeDisplayName;
  String? get activeSerialNumber => _activeSerialNumber;

  /// Commands are only available when cloud is enabled (authenticated + connected).
  bool get hardwareControlsAvailable => _cloudEnabled;
  DeviceConnection get cloudDeviceConnection => _cloudDeviceConnection;

  final List<String> _customRooms = [];
  List<String> get customRooms => List.unmodifiable(_customRooms);

  Future<void> addCustomRoom(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    await _storageService.addRoom(trimmed);
    if (!_customRooms.contains(trimmed)) {
      _customRooms.add(trimmed);
    }
    notifyListeners();
  }

  List<Room> get rooms {
    final Map<String, List<ConnectedDeviceSummary>> roomMap = {};
    for (final d in _devices) {
      final room = d.roomName.trim().isEmpty ? 'Living Room' : d.roomName;
      roomMap.putIfAbsent(room, () => []).add(d);
    }
    for (final r in _customRooms) {
      roomMap.putIfAbsent(r, () => []);
    }

    if (roomMap.isNotEmpty) {
      return roomMap.entries.map((entry) {
        final roomName = entry.key;
        final roomDevices = entry.value;
        final roomId = roomName.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_');
        return Room(
          id: roomId,
          name: roomName,
          iconKey: 'living',
          deviceCount: roomDevices.length,
          connectivity: roomDevices.isNotEmpty ? ConnectivityCause.online : ConnectivityCause.unknown,
          telemetryFreshness: roomDevices.isNotEmpty ? TelemetryFreshness.current : TelemetryFreshness.unknown,
          summary: roomDevices.isNotEmpty
              ? (_livingRoomLightOn ? 'Active · Normal' : 'Standby · Normal')
              : '0 devices',
          status: RoomStatus.normal,
          capabilities: roomDevices.expand((d) {
            final opName = formatOperatingName(d.name);
            final ch1On = getDeviceChannelPower(d.id, 1, defaultValue: _livingRoomLightOn);
            final ch2On = getDeviceChannelPower(d.id, 2, defaultValue: false);
            final ch3On = getDeviceChannelPower(d.id, 3, defaultValue: false);
            return [
              RoomCapability(
                id: '${d.id}_ch1',
                label: '$opName Switch 1',
                value: ch1On ? 'On' : 'Off',
                kind: RoomCapabilityKind.light,
              ),
              RoomCapability(
                id: '${d.id}_ch2',
                label: '$opName Switch 2',
                value: ch2On ? 'On' : 'Off',
                kind: RoomCapabilityKind.outlet,
              ),
              RoomCapability(
                id: '${d.id}_ch3',
                label: '$opName Switch 3',
                value: ch3On ? 'On' : 'Off',
                kind: RoomCapabilityKind.switchControl,
              ),
            ];
          }).toList(),
          devices: roomDevices.map((d) {
            final opName = formatOperatingName(d.name);
            final ch1On = getDeviceChannelPower(d.id, 1, defaultValue: _livingRoomLightOn);
            return RoomDevice(
              id: d.id,
              name: opName,
              type: 'Smart Switch 3X',
              value: ch1On ? 'On' : 'Off',
              kind: RoomCapabilityKind.light,
              confidence: _deviceConfidences[d.id] ?? ActuatorConfidence.confirmed,
            );
          }).toList(),
          insights: const RoomInsights(
            energyKwh: '1.2 kWh',
            energyChange: '+0.1 kWh',
            activeWindow: 'Today',
            averageTemperature: '24°C',
            averageHumidity: '55%',
          ),
        );
      }).toList();
    }
    return const [];
  }

  List<String> _quickControlIds = [];
  List<String> get quickControlIds => List.unmodifiable(_quickControlIds);

  Future<void> setQuickControls(List<String> ids) async {
    _quickControlIds = List.from(ids);
    await _storageService.saveQuickControlIds(_quickControlIds);
    notifyListeners();
  }

  HomeDashboardData get dashboard {
    if (_devices.isNotEmpty) {
      List<QuickControlPreview>? customControls;
      if (_quickControlIds.isNotEmpty) {
        customControls = [];
        for (final qId in _quickControlIds) {
          // format: deviceId:channelIndex
          final parts = qId.split(':');
          final devId = parts.first;
          final chIdx = parts.length > 1 ? int.tryParse(parts[1]) ?? 1 : 1;
          final dev = _devices.firstWhere((d) => d.id == devId, orElse: () => _devices.first);
          final cleanName = formatOperatingName(dev.name);
          final chPower = getDeviceChannelPower(dev.id, chIdx, defaultValue: chIdx == 1 ? _livingRoomLightOn : false);
          customControls.add(
            QuickControlPreview(
              id: qId,
              kind: chIdx == 2 ? QuickControlKind.fan : QuickControlKind.light,
              title: '${dev.roomName}\n$cleanName SW$chIdx',
              value: chPower ? 'On' : 'Off',
              confidence: _deviceConfidences[dev.id] ?? ActuatorConfidence.confirmed,
              isEnabled: true,
            ),
          );
        }
      }

      return HomeDashboardData.forLiveDevices(
        devices: _devices,
        lightOn: _livingRoomLightOn,
        lightConfidence: _lightConfidence,
        customControls: customControls,
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

  final Map<String, Map<int, bool>> _channelStates = {};
  final Map<String, ActuatorConfidence> _deviceConfidences = {};

  bool getDeviceChannelPower(String deviceId, int channelIndex, {bool defaultValue = false}) {
    return _channelStates[deviceId]?[channelIndex] ?? defaultValue;
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
        final devId = state['deviceId'] as String? ?? _activeDeviceId;
        if (state.containsKey('channels') && state['channels'] is Map) {
          final channels = state['channels'] as Map;
          channels.forEach((key, val) {
            if (val is Map && val.containsKey('relay')) {
              final chIdx = int.tryParse(key.toString().replaceAll(RegExp(r'[^0-9]'), '')) ?? 1;
              final relay = val['relay'] as bool?;
              if (relay != null) {
                if (devId != null) {
                  _channelStates.putIfAbsent(devId, () => {})[chIdx] = relay;
                }
                if (chIdx == 1) {
                  _livingRoomLightOn = relay;
                  _lightConfidence = ActuatorConfidence.confirmed;
                  _lightCommandPending = false;
                }
              }
            }
          });
        }
        debugPrint('[DEVICE] STATE_RECONCILED devId=$devId');
        notifyListeners();
        break;

      case 'command.receipt':
        final cmdStatus = envelope.payload['status'] as String?;
        if (cmdStatus == 'APPLIED' || cmdStatus == 'DELIVERED') {
          _lightConfidence = ActuatorConfidence.confirmed;
          _lightCommandPending = false;
          debugPrint('[DEVICE] COMMAND_APPLIED');
        } else if (cmdStatus == 'FAILED' ||
            cmdStatus == 'TIMEOUT' ||
            cmdStatus == 'OVERRIDDEN') {
          _lightConfidence = ActuatorConfidence.failed;
          _lightCommandPending = false;
          debugPrint('[DEVICE] COMMAND_FAILED status=$cmdStatus');
        }
        notifyListeners();
        break;

      default:
        break;
    }
  }

  Future<void> _hydrateFromStorage() async {
    final savedList = await _storageService.loadDevices();
    if (_disposed) return;
    if (savedList.isNotEmpty) {
      _devices = List.from(savedList);
      _connectedDeviceSummary = _devices.first;
      _activeDeviceId = _devices.first.id;
      _activeDisplayName = _devices.first.name;
      _activeSerialNumber = _devices.first.model;
      _connectionState = HomeConnectionState.connected;
      _connectionMessage = '${_devices.first.name} is connected and online.';
      _quickControlIds = await _storageService.loadQuickControlIds();
      if (_disposed) return;
      debugPrint('[HOME] DEVICE_REGISTERED count=${_devices.length}');
      debugPrint('[HOME] DEVICE_PERSISTED');
      debugPrint('[HOME] HOME_STATE_REFRESH');
      debugPrint('[HOME] REAL_DEVICE_COUNT=${_devices.length}');
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
      if (_devices.isEmpty) {
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
    final idx = _devices.indexWhere((d) => d.id == deviceId);
    if (idx >= 0) {
      _devices[idx] = summary;
    } else {
      _devices.add(summary);
    }
    _connectedDeviceSummary = summary;
    _connectionState = HomeConnectionState.connected;
    _connectionMessage = '$displayName is connected and online.';

    // Persist to local storage
    _storageService.saveDevice(summary);

    debugPrint('[HOME] DEVICE_REGISTERED id=$deviceId name=$displayName room=${roomName ?? "Living Room"}');
    debugPrint('[HOME] DEVICE_PERSISTED');
    debugPrint('[HOME] HOME_STATE_REFRESH');
    debugPrint('[HOME] REAL_DEVICE_COUNT=${_devices.length}');
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
    _lightCommandPending = true;
    _lightConfidence = ActuatorConfidence.pending;
    notifyListeners();

    final targetId = _activeDeviceId ??
        (_devices.isNotEmpty ? _devices.first.id : '4444688e-989d-458e-820e-ac62a99ed8e1');

    if (!_cloudEnabled) {
      try {
        final receipt = await _repository.sendCommand(
          deviceId: targetId,
          action: 'set_power',
          parameters: {'channel': 1, 'enabled': value},
          idempotencyKey: 'light-${DateTime.now().microsecondsSinceEpoch}',
        );
        if (receipt.state == CommandState.succeeded) {
          _livingRoomLightOn = value;
          _channelStates.putIfAbsent(targetId, () => {})[1] = value;
          _lightConfidence = ActuatorConfidence.confirmed;
          _lightCommandPending = false;
        } else if (receipt.state == CommandState.failed) {
          _lightConfidence = ActuatorConfidence.failed;
          _lightCommandPending = false;
        } else {
          _lightConfidence = ActuatorConfidence.pending;
        }
      } catch (_) {
        _lightConfidence = ActuatorConfidence.failed;
        _lightCommandPending = false;
      }
      notifyListeners();
      return;
    }

    try {
      await _repository.sendCommand(
        deviceId: targetId,
        action: 'set_power',
        parameters: {'channel': 1, 'enabled': value},
        idempotencyKey: 'light-${DateTime.now().microsecondsSinceEpoch}',
      );
      // Wait for SSE in cloud mode
    } catch (_) {
      _lightConfidence = ActuatorConfidence.failed;
      _lightCommandPending = false;
      notifyListeners();
    }
  }

  Future<void> setDeviceChannelPower({
    required String deviceId,
    required int channelIndex,
    required bool value,
  }) async {
    _channelStates.putIfAbsent(deviceId, () => {})[channelIndex] = value;
    if (channelIndex == 1 &&
        (deviceId == _activeDeviceId ||
            (_devices.isNotEmpty && deviceId == _devices.first.id))) {
      _livingRoomLightOn = value;
    }
    _deviceConfidences[deviceId] = ActuatorConfidence.pending;
    debugPrint(
      '[DEVICE] COMMAND_SENT deviceId=$deviceId channel=$channelIndex enabled=$value',
    );
    notifyListeners();

    if (!_cloudEnabled) {
      try {
        final receipt = await _repository.sendCommand(
          deviceId: deviceId,
          action: 'set_power',
          parameters: {'channel': channelIndex, 'enabled': value},
          idempotencyKey:
              'cmd-$deviceId-ch$channelIndex-${DateTime.now().microsecondsSinceEpoch}',
        );
        if (receipt.state == CommandState.succeeded) {
          _deviceConfidences[deviceId] = ActuatorConfidence.confirmed;
        } else if (receipt.state == CommandState.failed) {
          _deviceConfidences[deviceId] = ActuatorConfidence.failed;
        } else {
          _deviceConfidences[deviceId] = ActuatorConfidence.pending;
        }
      } catch (_) {
        _deviceConfidences[deviceId] = ActuatorConfidence.failed;
      }
      notifyListeners();
      return;
    }

    try {
      final receipt = await _repository.sendCommand(
        deviceId: deviceId,
        action: 'set_power',
        parameters: {'channel': channelIndex, 'enabled': value},
        idempotencyKey:
            'cmd-$deviceId-ch$channelIndex-${DateTime.now().microsecondsSinceEpoch}',
      );
      if (receipt.state == CommandState.failed) {
        _deviceConfidences[deviceId] = ActuatorConfidence.failed;
        notifyListeners();
      }
      // Keep pending until authoritative SSE event (device.state or command.receipt APPLIED)
    } catch (_) {
      _deviceConfidences[deviceId] = ActuatorConfidence.failed;
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

    final targetId = _activeDeviceId ??
        (_devices.isNotEmpty ? _devices.first.id : 'plant-mister');

    final receipt = await _repository.sendCommand(
      deviceId: targetId,
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
    _disposed = true;
    _sseSubscription?.cancel();
    super.dispose();
  }
}
