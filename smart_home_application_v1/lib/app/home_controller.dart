import 'dart:async';
import 'package:flutter/foundation.dart';
import '../core/api/api_client.dart';

import '../core/models/connection_models.dart';
import '../core/models/device_models.dart';
import '../core/models/home_dashboard_models.dart';
import '../core/models/room_models.dart';
import '../core/repositories/home_repository.dart';
import '../core/repositories/cloud_home_repository.dart';
import '../core/repositories/fake_home_repository.dart';
import '../core/repositories/connection_repository.dart';
import '../core/repositories/ble_connection_repository.dart';
import '../core/config/device_connection_config.dart';
import '../core/services/realtime_event_service.dart';

import '../core/services/device_storage_service.dart';
import '../core/services/local_lan_device_service.dart';

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
    this.autoSync = false,
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
    _subscribeToLocalUdpBroadcasts();
    _hydrateFromStorage();
    if (autoSync) {
      _startAutoSyncTimer();
    }
  }

  void _subscribeToLocalUdpBroadcasts() {
    LocalLanDeviceService.instance.onStateBroadcast.listen((event) {
      final devId = event.deviceId;
      final chMap = event.channels;
      _deviceMissedPolls[devId] = 0;
      final devChannels = _channelStates.putIfAbsent(devId, () => {});
      bool changed = false;
      chMap.forEach((chIdx, pwr) {
        if (devChannels[chIdx] != pwr) {
          devChannels[chIdx] = pwr;
          changed = true;
        }
        if (chIdx == 1 && (devId == _activeDeviceId || (_devices.isNotEmpty && devId == _devices.first.id))) {
          _livingRoomLightOn = pwr;
        }
      });
      for (int i = 0; i < _devices.length; i++) {
        if (_devices[i].id == devId && (!_devices[i].online || _devices[i].signalLabel != 'Local Wi-Fi')) {
          _devices[i] = ConnectedDeviceSummary(
            id: _devices[i].id,
            name: _devices[i].name,
            model: _devices[i].model,
            firmware: _devices[i].firmware,
            connectedVia: _devices[i].connectedVia,
            signalLabel: 'Local Wi-Fi',
            roomName: _devices[i].roomName,
            online: true,
          );
          changed = true;
        }
      }
      if (changed) {
        debugPrint('[LAN-UDP] State synchronized instantly from broadcast for $devId: $chMap');
        notifyListeners();
      }
    });
  }

  final HomeRepository _repository;
  final ConnectionRepository _connectionRepository;
  final DeviceStorageService _storageService;
  final bool autoSync;

  /// True when a real authenticated backend is powering this controller.
  bool _cloudEnabled;

  String? _activeHomeId;

  bool _awayMode = false;
  bool _livingRoomLightOn = false;
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
  List<ConnectedDeviceSummary> _devices = [];
  final List<Room> _customEmptyRooms = [];
  List<Room> _backendRooms = [];
  List<String> _selectedQuickControlIds = [];
  bool _isLoading = false;
  String? _errorMessage;
  Map<String, bool> _notificationPrefs = {
    'pushEnabled': true,
    'criticalAlerts': true,
    'deviceOffline': true,
    'automationFailure': true,
    'firmwareUpdates': true,
  };
  int _lanMissedPollCount = 0;
  final Map<String, int> _deviceMissedPolls = {};
  String? _activeDeviceId;
  String? _activeDisplayName;
  String? _activeSerialNumber;

  StreamSubscription<SSEEventEnvelope>? _sseSubscription;

  bool _isCloudReachable = true;
  bool _isLocalMode = false;
  final Map<String, DateTime> _lastCommandTimestamps = {};

  final List<Map<String, dynamic>> _spaces = [
    {'id': 'home_default', 'name': 'My Home', 'icon': 'home'},
  ];
  String _activeSpaceId = 'home_default';
  String _activeSpaceName = 'My Home';
  String? _lanMatchedSpaceId;

  final Map<String, List<ConnectedDeviceSummary>> _spaceDevicesCache = {};
  List<GroupControlItem> _groupControls = [];
  List<String> _favouriteControlIds = [];

  List<Map<String, dynamic>> get spaces => List.unmodifiable(_spaces);
  String get activeSpaceId => _activeSpaceId;
  String get activeSpaceName => _activeSpaceName;
  String? get lanMatchedSpaceId => _lanMatchedSpaceId;
  bool get isCurrentSpaceOnLocalLan =>
      _lanMatchedSpaceId == null || _lanMatchedSpaceId == _activeSpaceId;

  List<GroupControlItem> get groupControls => List.unmodifiable(_groupControls);
  List<String> get favouriteControlIds => List.unmodifiable(_favouriteControlIds);

  List<ConnectedDeviceSummary> get devices => List.unmodifiable(_devices);
  bool get isLocalMode => !_isCloudReachable && _isLocalMode && isCurrentSpaceOnLocalLan;
  bool get isCloudReachable => _isCloudReachable;
  bool get livingRoomLightOn => _livingRoomLightOn;
  bool get alertAcknowledged => _alertAcknowledged;
  bool get lightCommandPending => _lightCommandPending;
  bool get mistingCommandPending => _mistingCommandPending;
  bool get cloudEnabled => _cloudEnabled;
  ActuatorConfidence get lightConfidence => _lightConfidence;
  String? get activeHomeId => _activeHomeId;
  HomeConnectionState get connectionState => _connectionState;
  String? get connectionMessage => _connectionMessage;
  ConnectedDeviceSummary? get connectedDeviceSummary => _connectedDeviceSummary;
  List<String> get selectedQuickControlIds => List.unmodifiable(_selectedQuickControlIds);
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get awayMode => _awayMode;

  final List<UpcomingRoutineItem> _routines = [];

  List<UpcomingRoutineItem> get upcomingRoutinesAcrossSpaces =>
      List.unmodifiable(_routines);

  void toggleRoutine(String id, bool enabled) {
    final idx = _routines.indexWhere((r) => r.id == id);
    if (idx >= 0) {
      final old = _routines[idx];
      _routines[idx] = UpcomingRoutineItem(
        id: old.id,
        spaceId: old.spaceId,
        spaceName: old.spaceName,
        spaceIcon: old.spaceIcon,
        title: old.title,
        timeLabel: old.timeLabel,
        iconKey: old.iconKey,
        isEnabled: enabled,
      );
      notifyListeners();
    }
  }

  /// Cross-space aggregation: devices turned ON in other spaces (not current space).
  List<SpaceOnSummary> get devicesOnInOtherSpaces {
    final List<SpaceOnSummary> results = [];
    for (final sp in _spaces) {
      final spId = sp['id'] as String;
      if (spId == _activeSpaceId) continue;
      final spName = sp['name'] as String;
      final spIcon = sp['icon'] as String? ?? 'business';

      final devList = _spaceDevicesCache[spId] ?? [];
      int onCount = 0;
      final List<String> onNames = [];

      for (final dev in devList) {
        final devChs = _channelStates[dev.id];
        bool devIsOn = false;
        if (devChs != null) {
          for (final isChOn in devChs.values) {
            if (isChOn) {
              devIsOn = true;
              break;
            }
          }
        }
        if (devIsOn) {
          onCount++;
          onNames.add(dev.name);
        }
      }

      results.add(
        SpaceOnSummary(
          spaceId: spId,
          spaceName: spName,
          icon: spIcon,
          devicesOnCount: onCount,
          onDeviceNames: onNames,
        ),
      );
    }
    return results;
  }

  /// Cross-space aggregation: alerts across all spaces.
  List<SpaceAlertItem> get allSpacesAlerts {
    final List<SpaceAlertItem> alerts = [];
    for (final sp in _spaces) {
      final spId = sp['id'] as String;
      final spName = sp['name'] as String;
      final devList = (spId == _activeSpaceId) ? _devices : (_spaceDevicesCache[spId] ?? []);
      for (final d in devList) {
        if (!d.online && _isCloudReachable) {
          alerts.add(
            SpaceAlertItem(
              id: 'alert_off_${d.id}',
              spaceId: spId,
              spaceName: spName,
              title: '${d.name} is Offline',
              message: 'Check power and Wi-Fi connection in $spName.',
              severity: AlertSeverity.warning,
              timestamp: DateTime.now(),
              deviceId: d.id,
            ),
          );
        }
      }
    }
    if (dashboard.alert != null) {
      alerts.insert(
        0,
        SpaceAlertItem(
          id: 'alert_dash_main',
          spaceId: _activeSpaceId,
          spaceName: _activeSpaceName,
          title: dashboard.alert!.title,
          message: dashboard.alert!.safeDisplayMessage,
          severity: dashboard.alert!.severity,
          timestamp: DateTime.now(),
        ),
      );
    }
    return alerts;
  }

  Future<void> selectSpace(String spaceId) async {
    final target = _spaces.firstWhere(
      (s) => s['id'] == spaceId,
      orElse: () => _spaces.first,
    );
    _activeSpaceId = target['id'] as String;
    _activeSpaceName = target['name'] as String;
    setActiveHomeId(_activeSpaceId);

    // Physical Presence Isolation:
    // When cloud is reachable, we are in CLOUD mode for all spaces.
    // When cloud is NOT reachable, LAN mode is ONLY available for the space where the phone
    // is physically connected to that space's local Wi-Fi router (_lanMatchedSpaceId).
    if (_isCloudReachable) {
      _isLocalMode = false;
    } else {
      _isLocalMode = (_lanMatchedSpaceId != null && _lanMatchedSpaceId == _activeSpaceId);
    }

    await _loadCustomizationsForActiveSpace();
    await loadHomeData(homeId: _activeSpaceId);
    notifyListeners();
  }

  Future<void> _loadCustomizationsForActiveSpace() async {
    final rawGroups = await _storageService.loadGroupControlsForSpace(_activeSpaceId);
    _groupControls = rawGroups.map((g) => GroupControlItem.fromJson(g)).toList();
    _favouriteControlIds = await _storageService.loadFavouritesForSpace(_activeSpaceId);
    _selectedQuickControlIds = await _storageService.loadQuickControlsForSpace(_activeSpaceId);
    notifyListeners();
  }

  Future<void> createSpace(String name, {String icon = 'home_work'}) async {
    final cleanName = name.trim();
    if (cleanName.isEmpty) return;
    String id = 'space_${cleanName.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_')}_${DateTime.now().millisecondsSinceEpoch % 10000}';
    final repo = _repository;
    if (repo is CloudHomeRepository) {
      try {
        final created = await repo.createHome(cleanName);
        if (created['id'] != null && created['id'].toString().isNotEmpty) {
          id = created['id'].toString();
        }
      } catch (_) {}
    }
    _spaces.add({
      'id': id,
      'name': cleanName,
      'icon': icon,
    });
    await _storageService.saveSpaces(_spaces);
    await selectSpace(id);
  }

  Future<void> updateSpace(String spaceId, String newName, {String? icon}) async {
    final cleanName = newName.trim();
    if (cleanName.isEmpty) return;
    final idx = _spaces.indexWhere((s) => s['id'] == spaceId);
    if (idx >= 0) {
      _spaces[idx]['name'] = cleanName;
      if (icon != null) _spaces[idx]['icon'] = icon;
      await _storageService.saveSpaces(_spaces);
      if (_repository is CloudHomeRepository) {
        try {
          await _repository.updateHome(spaceId, cleanName);
        } catch (_) {}
      }
      if (_activeSpaceId == spaceId) {
        _activeSpaceName = cleanName;
      }
      notifyListeners();
    }
  }

  Future<void> deleteSpace(String spaceId) async {
    if (_spaces.length <= 1) return;
    final deletedIdx = _spaces.indexWhere((s) => s['id'] == spaceId);
    if (deletedIdx == 0) return; // Never delete primary home space

    _spaces.removeWhere((s) => s['id'] == spaceId);
    _spaceDevicesCache.remove(spaceId);
    await _storageService.saveSpaces(_spaces);
    await _storageService.addDeletedSpaceId(spaceId);

    if (_repository is CloudHomeRepository) {
      try {
        await _repository.deleteHome(spaceId);
      } catch (_) {}
    }

    if (_activeSpaceId == spaceId) {
      await selectSpace(_spaces.first['id'] as String);
    } else {
      notifyListeners();
    }
  }

  // --- Group Controls & Playground Methods ---
  Future<void> createControlGroup({
    required String label,
    required QuickControlKind kind,
    required List<String> targetControlIds,
  }) async {
    final newGroup = GroupControlItem(
      id: 'grp_${DateTime.now().millisecondsSinceEpoch}',
      spaceId: _activeSpaceId,
      label: label,
      kind: kind,
      targetControlIds: targetControlIds,
      isEnabled: true,
      isOn: false,
    );
    _groupControls.add(newGroup);
    await _storageService.saveGroupControlsForSpace(
      _activeSpaceId,
      _groupControls.map((g) => g.toJson()).toList(),
    );
    notifyListeners();
  }

  Future<void> updateControlGroup(GroupControlItem updated) async {
    final idx = _groupControls.indexWhere((g) => g.id == updated.id);
    if (idx >= 0) {
      _groupControls[idx] = updated;
      await _storageService.saveGroupControlsForSpace(
        _activeSpaceId,
        _groupControls.map((g) => g.toJson()).toList(),
      );
      notifyListeners();
    }
  }

  Future<void> deleteControlGroup(String groupId) async {
    _groupControls.removeWhere((g) => g.id == groupId);
    await _storageService.saveGroupControlsForSpace(
      _activeSpaceId,
      _groupControls.map((g) => g.toJson()).toList(),
    );
    notifyListeners();
  }

  Future<void> toggleControlGroup(GroupControlItem group, bool targetValue) async {
    final idx = _groupControls.indexWhere((g) => g.id == group.id);
    if (idx >= 0) {
      _groupControls[idx] = group.copyWith(isOn: targetValue);
      notifyListeners();
    }
    final futures = <Future<void>>[];
    for (final controlId in group.targetControlIds) {
      final parts = controlId.split('_ch');
      final devId = parts[0];
      final chIdx = parts.length > 1 ? int.tryParse(parts[1]) ?? 1 : 1;
      futures.add(setDeviceChannelPower(
        deviceId: devId,
        channelIndex: chIdx,
        value: targetValue,
      ));
    }
    await Future.wait(futures);
  }

  Future<void> saveQuickControlsForSpace(List<String> ids) async {
    _selectedQuickControlIds = List.from(ids);
    await _storageService.saveQuickControlsForSpace(_activeSpaceId, _selectedQuickControlIds);
    notifyListeners();
  }

  Future<void> saveFavouritesForSpace(String spaceId, List<String> favouriteIds) async {
    _favouriteControlIds = List.from(favouriteIds);
    await _storageService.saveFavouritesForSpace(spaceId, _favouriteControlIds);
    notifyListeners();
  }

  Future<void> toggleFavourite(String controlId) async {
    if (_favouriteControlIds.contains(controlId)) {
      _favouriteControlIds.remove(controlId);
    } else {
      _favouriteControlIds.add(controlId);
    }
    await _storageService.saveFavouritesForSpace(_activeSpaceId, _favouriteControlIds);
    notifyListeners();
  }

  /// Commands are only available when cloud is enabled (authenticated + connected).
  bool get hardwareControlsAvailable => _cloudEnabled;
  DeviceConnection get cloudDeviceConnection => _cloudDeviceConnection;

  /// Dynamically updates cloud execution authority.
  void setCloudEnabled(bool enabled) {
    if (_cloudEnabled == enabled) return;
    _cloudEnabled = enabled;
    if (!enabled) {
      _cloudDeviceConnection = DeviceConnection.offline;
      _lightCommandPending = false;
      _mistingCommandPending = false;
    }
    notifyListeners();
  }

  /// Sets the active resolved home identifier.
  void setActiveHomeId(String? homeId) {
    if (homeId != null && homeId.isNotEmpty) {
      _lanMatchedSpaceId ??= _spaces.first['id'] as String;
    }
    if (_activeHomeId != homeId) {
      _activeHomeId = homeId;
      if (_repository is CloudHomeRepository && homeId != null) {
        _repository.setActiveHomeId(homeId);
      }
      loadRooms();
    }
    notifyListeners();
  }

  /// Syncs spaces with backend homes list.
  Future<void> syncBackendHomes(List<dynamic> backendHomes) async {
    if (backendHomes.isEmpty) return;
    bool modified = false;

    final primary = backendHomes.first;
    final primaryId = (primary is Map ? primary['id'] : primary.id).toString();

    // Link primary backend home ID to the default space WITHOUT overwriting user-facing name ("My Home")
    if (_spaces.isNotEmpty && (_spaces.first['id'] == 'home_default' || _spaces.first['id'] == 'local-home')) {
      _spaces.first['id'] = primaryId;
      if (_activeSpaceId == 'home_default' || _activeSpaceId == 'local-home') {
        _activeSpaceId = primaryId;
      }
      modified = true;
    }

    // Ensure the primary home is named "My Home", restoring it if overwritten by backend name
    if (_spaces.isNotEmpty) {
      final firstName = _spaces.first['name']?.toString().toLowerCase() ?? '';
      if (firstName.contains('pavan') || firstName == 'home') {
        _spaces.first['name'] = 'My Home';
        if (_activeSpaceId == _spaces.first['id']) {
          _activeSpaceName = 'My Home';
        }
        modified = true;
      }
    }

    // Match backend IDs for existing spaces by matching names so cloud calls work
    final deletedIds = await _storageService.loadDeletedSpaceIds();
    for (final s in _spaces) {
      for (final bh in backendHomes) {
        final bId = (bh is Map ? bh['id'] : bh.id).toString();
        final bName = (bh is Map ? (bh['name'] ?? '') : bh.name).toString().toLowerCase();
        if (s['name'].toString().toLowerCase() == bName && s['id'] != bId && !deletedIds.contains(bId)) {
          final oldId = s['id'] as String;
          s['id'] = bId;
          if (_activeSpaceId == oldId) {
            _activeSpaceId = bId;
          }
          modified = true;
        }
      }
    }

    // Remove any spaces that user has deleted
    _spaces.removeWhere((s) => deletedIds.contains(s['id']));

    _lanMatchedSpaceId ??= _spaces.first['id'] as String;

    if (modified) {
      await _storageService.saveSpaces(_spaces);
      notifyListeners();
    }
  }

  /// Loads persisted rooms from repository for the active home.
  Future<void> loadRooms() async {
    try {
      final rawRooms = await _repository.getRooms(homeId: _activeHomeId);
      for (final r in rawRooms) {
        final name = (r['name'] ?? r['label'] ?? '').toString().trim();
        final id = (r['id'] ?? name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_')).toString();
        final iconKey = (r['iconKey'] ?? r['icon_key'] ?? 'living').toString();
        if (name.isNotEmpty && !rooms.any((existing) => existing.name.toLowerCase() == name.toLowerCase())) {
          _customEmptyRooms.add(
            Room(
              id: id,
              name: name,
              iconKey: iconKey,
              deviceCount: 0,
              connectivity: ConnectivityCause.online,
              telemetryFreshness: TelemetryFreshness.current,
              summary: '0 devices · Configured',
              status: RoomStatus.normal,
              capabilities: const [],
              devices: const [],
              insights: const RoomInsights(
                energyKwh: '0.0 kWh',
                energyChange: '0.0 kWh',
                activeWindow: 'Today',
                averageTemperature: '24°C',
                averageHumidity: '55%',
              ),
            ),
          );
        }
      }
      notifyListeners();
    } catch (_) {}
  }

  /// Attaches or re-attaches a RealtimeEventService subscription.
  void attachRealtimeService(RealtimeEventService service) {
    _sseSubscription?.cancel();
    _subscribeToRealtime(service);
  }

  /// Resets all session and cloud state upon logout or session invalidation.
  void resetSession() {
    _autoSyncTimer?.cancel();
    _cloudEnabled = false;
    _activeHomeId = null;
    _cloudDeviceConnection = DeviceConnection.offline;
    _lightCommandPending = false;
    _mistingCommandPending = false;
    _lightConfidence = ActuatorConfidence.unknown;
    _deviceConfidences.clear();
    _devices.clear();
    _backendRooms.clear();
    _connectedDeviceSummary = null;
    _activeDeviceId = null;
    _activeDisplayName = null;
    _activeSerialNumber = null;
    _connectionState = HomeConnectionState.notConfigured;
    _connectionMessage = null;
    _isLoading = false;
    _errorMessage = null;
    notifyListeners();
  }

  /// Loads real device and room state from backend for the active home.
  Future<void> loadHomeData({String? homeId}) async {
    _isLoading = true;
    _errorMessage = null;
    final targetHomeId = homeId ?? _activeHomeId ?? _activeSpaceId;
    try {
      final rawDevices = await _repository.getDevices(homeId: targetHomeId);
      final rawRooms = await _repository.getRooms(homeId: targetHomeId);

      if (_repository is CloudHomeRepository) {
        final repoHomeId = _repository.activeHomeId;
        if (repoHomeId != null && repoHomeId.isNotEmpty) {
          _activeHomeId = repoHomeId;
        }
      }

      _backendRooms = rawRooms.map((r) {
        final roomName = (r['name'] ?? 'Room').toString();
        final matchingDevices = rawDevices.where((d) => d.roomName.toLowerCase() == roomName.toLowerCase());
        final isRoomOnline = matchingDevices.isNotEmpty
            ? matchingDevices.any((d) => d.connection == DeviceConnection.online)
            : false;
        return Room(
          id: (r['id'] ?? r['roomId'] ?? '').toString(),
          name: roomName,
          iconKey: (r['iconKey'] ?? 'living').toString(),
          deviceCount: matchingDevices.length,
          connectivity: isRoomOnline ? ConnectivityCause.online : ConnectivityCause.deviceOffline,
          telemetryFreshness: isRoomOnline ? TelemetryFreshness.current : TelemetryFreshness.unknown,
          summary: isRoomOnline ? 'Active · Normal' : (matchingDevices.isEmpty ? 'Empty room' : 'Offline · Disconnected'),
          status: isRoomOnline ? RoomStatus.normal : RoomStatus.unavailable,
          capabilities: const [],
          devices: const [],
          insights: const RoomInsights(
            energyKwh: '0.0 kWh',
            energyChange: '0.0 kWh',
            activeWindow: 'Today',
            averageTemperature: '24°C',
            averageHumidity: '55%',
          ),
        );
      }).toList();

      if (rawDevices.isNotEmpty) {
        _devices = rawDevices.map((d) {
          final isOnline = d.connection == DeviceConnection.online;
          return ConnectedDeviceSummary(
            id: d.id,
            name: d.name,
            model: d.productVariantId ?? d.hardwareRevision,
            firmware: d.firmwareVersion,
            connectedVia: 'Wi-Fi (2.4 GHz)',
            signalLabel: isOnline ? 'Strong' : 'Offline',
            roomName: d.roomName,
            online: isOnline,
          );
        }).toList();

        _connectedDeviceSummary = _devices.first;
        _activeDeviceId = _devices.first.id;
        _activeDisplayName = _devices.first.name;
        _activeSerialNumber = _devices.first.model;
        _connectionState = _devices.any((d) => d.online)
            ? HomeConnectionState.connected
            : HomeConnectionState.offline;
        _connectionMessage = '${_devices.first.name} is connected and ${_devices.first.online ? 'online' : 'offline'}.';

        for (final dev in _devices) {
          _storageService.saveDeviceForSpace(targetHomeId, dev);
        }
        _spaceDevicesCache[targetHomeId] = List.from(_devices);

        // Hydrate live channel states from backend device snapshots
        for (final d in rawDevices) {
          final devChannels = _channelStates.putIfAbsent(d.id, () => {});
          for (final ch in d.channels) {
            final chIdx = _parseChannelIndex(ch) ?? 1;
            final pwr = _parsePowerFromChannel(ch);
            if (pwr != null) {
              devChannels[chIdx] = pwr;
            }
          }
        }
        if (_activeDeviceId != null && _channelStates[_activeDeviceId]?.containsKey(1) == true) {
          _livingRoomLightOn = _channelStates[_activeDeviceId]![1]!;
        } else if (_devices.isNotEmpty && _channelStates[_devices.first.id]?.containsKey(1) == true) {
          _livingRoomLightOn = _channelStates[_devices.first.id]![1]!;
        } else {
          _livingRoomLightOn = false;
        }
      } else {
        final localDevices = await _storageService.loadDevicesForSpace(targetHomeId);
        if (localDevices.isNotEmpty) {
          _devices = List.from(localDevices);
          _connectedDeviceSummary = _devices.first;
          _activeDeviceId = _devices.first.id;
          _activeDisplayName = _devices.first.name;
          _activeSerialNumber = _devices.first.model;
          _connectionState = _devices.any((d) => d.online)
              ? HomeConnectionState.connected
              : HomeConnectionState.offline;
          _connectionMessage = '${_devices.first.name} is connected and ${_devices.first.online ? 'online' : 'offline'}.';
        } else {
          _devices = [];
          _connectedDeviceSummary = null;
          _activeDeviceId = null;
          _activeDisplayName = null;
          _activeSerialNumber = null;
          _connectionState = HomeConnectionState.notConfigured;
          _connectionMessage = 'No devices configured for $_activeSpaceName yet.';
        }
        _spaceDevicesCache[targetHomeId] = List.from(_devices);
      }
      _isCloudReachable = true;
      _isLocalMode = false;
      _isLoading = false;
      _startAutoSyncTimer();
      notifyListeners();
    } catch (e) {
      if (e is ApiException && e.statusCode != 0) {
        _isCloudReachable = true;
      } else {
        _isCloudReachable = false;
      }
      final localDevices = await _storageService.loadDevicesForSpace(targetHomeId);
      final isLanForThisSpace = (_lanMatchedSpaceId != null && _lanMatchedSpaceId == targetHomeId);
      if (localDevices.isNotEmpty) {
        _devices = localDevices.map((d) {
          final isLanActive = isLanForThisSpace && _isLocalMode && (LocalLanDeviceService.instance.getDeviceIp(d.id) != null);
          return ConnectedDeviceSummary(
            id: d.id,
            name: d.name,
            model: d.model,
            firmware: d.firmware,
            connectedVia: d.connectedVia,
            signalLabel: isLanActive ? 'Local Wi-Fi' : 'Offline',
            roomName: d.roomName,
            online: isLanActive,
          );
        }).toList();
        _connectedDeviceSummary = _devices.first;
        _activeDeviceId = _devices.first.id;
        _activeDisplayName = _devices.first.name;
        _activeSerialNumber = _devices.first.model;
        final hasOnline = _devices.any((d) => d.online);
        _connectionState = hasOnline ? HomeConnectionState.connected : HomeConnectionState.offline;
        _connectionMessage = hasOnline
            ? 'Local Wi-Fi Mode'
            : '${_devices.first.name} is offline. Cloud sync unavailable.';
      } else {
        _devices = [];
        _connectedDeviceSummary = null;
        _activeDeviceId = null;
        _activeDisplayName = null;
        _activeSerialNumber = null;
        _connectionState = HomeConnectionState.notConfigured;
        _connectionMessage = 'No devices configured for $_activeSpaceName yet.';
      }
      _spaceDevicesCache[targetHomeId] = List.from(_devices);
      _isLoading = false;
      _errorMessage = e.toString().replaceFirst('ApiException: ', '');
      _startAutoSyncTimer();
      notifyListeners();
    }
  }

  static int? _parseChannelIndex(dynamic ch) {
    if (ch is! Map) return null;
    final idx = ch['channelIndex'] ??
        ch['channel_index'] ??
        ch['channel'] ??
        (ch['state'] is Map ? (ch['state'] as Map)['channelIndex'] : null);
    if (idx is num) return idx.toInt();
    if (idx is String) return int.tryParse(idx);
    return null;
  }

  static bool? _parsePowerFromChannel(dynamic ch) {
    if (ch is! Map) return null;
    if (ch['power'] is bool) return ch['power'] as bool;
    if (ch['value'] is bool) return ch['value'] as bool;
    if (ch['closed'] is bool) return ch['closed'] as bool;
    if (ch['relay'] is bool) return ch['relay'] as bool;

    final reported = ch['reportedState'] ?? ch['reported_state'];
    if (reported is Map) {
      if (reported['power'] is bool) return reported['power'] as bool;
      if (reported['closed'] is bool) return reported['closed'] as bool;
      if (reported['value'] is bool) return reported['value'] as bool;
    } else if (reported is bool) {
      return reported;
    }

    final state = ch['state'];
    if (state is Map) {
      if (state['power'] is bool) return state['power'] as bool;
      final subReported = state['reportedState'] ?? state['reported_state'];
      if (subReported is Map) {
        if (subReported['power'] is bool) return subReported['power'] as bool;
        if (subReported['closed'] is bool) return subReported['closed'] as bool;
        if (subReported['value'] is bool) return subReported['value'] as bool;
      } else if (subReported is bool) {
        return subReported;
      }
      final subDesired = state['desiredState'] ?? state['desired_state'];
      if (subDesired is Map && subDesired['power'] is bool) {
        return subDesired['power'] as bool;
      }
    }
    return null;
  }

  Timer? _autoSyncTimer;

  void _startAutoSyncTimer() {
    if (!autoSync) return;
    _autoSyncTimer?.cancel();
    _autoSyncTimer = Timer.periodic(const Duration(milliseconds: 1200), (_) {
      _quietSyncDeviceStates();
    });
  }

  Future<void> _quietSyncDeviceStates() async {
    if (_disposed) return;
    try {
      bool stateChanged = false;
      final rawDevices = await _repository.getDevices(homeId: _activeHomeId);
      if (_activeHomeId == null && _repository is CloudHomeRepository) {
        final repoHomeId = _repository.activeHomeId;
        if (repoHomeId != null && repoHomeId.isNotEmpty) {
          _activeHomeId = repoHomeId;
        }
      }
      final wasInLocal = _isLocalMode;
      if (!_isCloudReachable) {
        _isCloudReachable = true;
        _isLocalMode = false;
        stateChanged = true;
      }
      if (rawDevices.isEmpty) return;

      // Sync physical states back to cloud backend after outage
      if (wasInLocal) {
        for (final d in _devices) {
          final devChs = _channelStates[d.id];
          if (devChs != null) {
            for (final entry in devChs.entries) {
              try {
                await _repository.sendCommand(
                  deviceId: d.id,
                  action: 'setPower',
                  parameters: {
                    'channel': entry.key,
                    'channelIndex': entry.key,
                    'value': entry.value,
                    'power': entry.value,
                  },
                  idempotencyKey: 'sync-${d.id}-${entry.key}-${DateTime.now().millisecondsSinceEpoch}',
                );
              } catch (_) {}
            }
          }
        }
      }

      for (final d in rawDevices) {
        final isOnline = d.connection == DeviceConnection.online;
        final devChannels = _channelStates.putIfAbsent(d.id, () => {});
        for (final ch in d.channels) {
          final chIdx = _parseChannelIndex(ch) ?? 1;
          final pwr = _parsePowerFromChannel(ch);
          if (pwr != null) {
            final cmdKey = '${d.id}_$chIdx';
            final lastCmd = _lastCommandTimestamps[cmdKey];
            if (lastCmd != null && DateTime.now().difference(lastCmd).inMilliseconds < 2500) {
              // User recently toggled this switch: hold optimistic state to prevent double-toggle jitter
              continue;
            }
            if (devChannels[chIdx] != pwr) {
              devChannels[chIdx] = pwr;
              stateChanged = true;
              if (chIdx == 1 && (d.id == _activeDeviceId || (_devices.isNotEmpty && d.id == _devices.first.id))) {
                _livingRoomLightOn = pwr;
              }
            }
          }
        }
        for (int i = 0; i < _devices.length; i++) {
          if (_devices[i].id == d.id && _devices[i].online != isOnline) {
            _devices[i] = ConnectedDeviceSummary(
              id: _devices[i].id,
              name: _devices[i].name,
              model: _devices[i].model,
              firmware: _devices[i].firmware,
              connectedVia: _devices[i].connectedVia,
              signalLabel: isOnline ? 'Strong' : 'Offline',
              roomName: _devices[i].roomName,
              online: isOnline,
            );
            stateChanged = true;
          }
        }
      }

      if (stateChanged) {
        debugPrint('[HOME] AUTO_SYNC_STATE_UPDATED live channels: $_channelStates');
        _isLocalMode = false;
        notifyListeners();
      }
    } catch (e) {
      bool localStateChanged = false;
      if (e is ApiException && e.statusCode != 0) {
        if (!_isCloudReachable) {
          _isCloudReachable = true;
          localStateChanged = true;
        }
      } else {
        if (_isCloudReachable) {
          _isCloudReachable = false;
          localStateChanged = true;
        }
      }

      // Check if any device is directly reachable over Local LAN
      bool anyLocalActive = false;
      for (int i = 0; i < _devices.length; i++) {
        final devId = _devices[i].id;
        final localStates = await LocalLanDeviceService.instance.fetchLocalState(deviceId: devId);
        if (localStates != null && localStates.isNotEmpty) {
          anyLocalActive = true;
          _deviceMissedPolls[devId] = 0;
          final devChannels = _channelStates.putIfAbsent(devId, () => {});
          localStates.forEach((chIdx, pwr) {
            final cmdKey = '${devId}_$chIdx';
            final lastCmd = _lastCommandTimestamps[cmdKey];
            if (lastCmd != null && DateTime.now().difference(lastCmd).inMilliseconds < 2500) {
              return;
            }
            if (devChannels[chIdx] != pwr) {
              devChannels[chIdx] = pwr;
              localStateChanged = true;
            }
            if (chIdx == 1 && (devId == _activeDeviceId || i == 0)) {
              _livingRoomLightOn = pwr;
            }
          });
          if (!_devices[i].online || _devices[i].signalLabel != 'Local Wi-Fi') {
            _devices[i] = ConnectedDeviceSummary(
              id: _devices[i].id,
              name: _devices[i].name,
              model: _devices[i].model,
              firmware: _devices[i].firmware,
              connectedVia: _devices[i].connectedVia,
              signalLabel: 'Local Wi-Fi',
              roomName: _devices[i].roomName,
              online: true,
            );
            localStateChanged = true;
          }
        } else {
          final missed = (_deviceMissedPolls[devId] ?? 0) + 1;
          _deviceMissedPolls[devId] = missed;
          // Only mark offline after 3 consecutive failed polls (eliminates single-poll jitter/flicker)
          if (missed >= 3 && _devices[i].online) {
            _devices[i] = ConnectedDeviceSummary(
              id: _devices[i].id,
              name: _devices[i].name,
              model: _devices[i].model,
              firmware: _devices[i].firmware,
              connectedVia: _devices[i].connectedVia,
              signalLabel: 'Offline',
              roomName: _devices[i].roomName,
              online: false,
            );
            localStateChanged = true;
          }
        }
      }

      if (anyLocalActive) {
        _lanMissedPollCount = 0;
        if (!_isLocalMode) {
          _isLocalMode = true;
          localStateChanged = true;
        }
        _connectionState = HomeConnectionState.connected;
        _connectionMessage = 'Local Wi-Fi Mode (Cloud Offline)';
      } else {
        _lanMissedPollCount++;
        if (_lanMissedPollCount >= 3) {
          if (_isLocalMode) {
            _isLocalMode = false;
            localStateChanged = true;
          }
          _connectionState = HomeConnectionState.offline;
          _connectionMessage = 'Cloud unreachable • Devices offline';
        }
      }

      if (localStateChanged) {
        notifyListeners();
      }
    }
  }

  /// Explicitly activates Local Wi-Fi (LAN) mode when cloud is down.
  /// Runs automated device discovery (UDP broadcast & subnet ping sweep),
  /// fetches their live hardware states directly, and enables controls.
  Future<bool> switchToLanMode() async {
    _isLoading = true;
    notifyListeners();
    try {
      debugPrint('[HOME] Switching to Local LAN mode via auto-discovery...');
      final discovered = await LocalLanDeviceService.instance.autoDiscoverDevices();
      bool anyFound = false;

      // Mark this active space as the LAN matched space
      _lanMatchedSpaceId = _activeSpaceId;

      final discoveredIpList = discovered.values.toList();
      for (int i = 0; i < _devices.length; i++) {
        final devId = _devices[i].id;
        String? localIp = discovered[devId] ?? LocalLanDeviceService.instance.getDeviceIp(devId);
        if ((localIp == null || localIp.isEmpty) && discoveredIpList.isNotEmpty) {
          localIp = (i < discoveredIpList.length) ? discoveredIpList[i] : discoveredIpList.first;
          LocalLanDeviceService.instance.registerDeviceIp(devId, localIp);
        }
        final localStates = await LocalLanDeviceService.instance.fetchLocalState(
          deviceId: devId,
          explicitIp: localIp,
        );
        if (localStates != null && localStates.isNotEmpty) {
          anyFound = true;
          final devChannels = _channelStates.putIfAbsent(devId, () => {});
          localStates.forEach((ch, pwr) {
            devChannels[ch] = pwr;
            if (ch == 1 && (devId == _activeDeviceId || i == 0)) {
              _livingRoomLightOn = pwr;
            }
          });
          _devices[i] = ConnectedDeviceSummary(
            id: _devices[i].id,
            name: _devices[i].name,
            model: _devices[i].model,
            firmware: _devices[i].firmware,
            connectedVia: _devices[i].connectedVia,
            signalLabel: 'Local Wi-Fi',
            roomName: _devices[i].roomName,
            online: true,
          );
        }
      }

      _isLocalMode = anyFound;
      if (anyFound) {
        _connectionState = HomeConnectionState.connected;
        _connectionMessage = 'Local Wi-Fi Mode Active (Direct LAN)';
      }
      _isLoading = false;
      notifyListeners();
      return anyFound;
    } catch (e) {
      debugPrint('[HOME] Failed to switch to LAN mode: $e');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  List<Room> get rooms {
    final List<Room> result = [];

    RoomCapabilityKind inferCapKind(String name, String model, String chLabel) {
      final labelLower = chLabel.toLowerCase();
      if (labelLower.contains('light') || labelLower.contains('lamp') || labelLower.contains('bulb')) {
        return RoomCapabilityKind.light;
      }
      if (labelLower.contains('fan')) return RoomCapabilityKind.fan;
      if (labelLower.contains('curtain') || labelLower.contains('blind')) return RoomCapabilityKind.curtain;
      if (labelLower.contains('socket') || labelLower.contains('plug') || labelLower.contains('outlet')) {
        return RoomCapabilityKind.socket;
      }

      final devText = '$name $model'.toLowerCase();
      if (devText.contains('socket') || devText.contains('plug') || devText.contains('outlet')) {
        return RoomCapabilityKind.socket;
      }
      if (devText.contains('fan')) return RoomCapabilityKind.fan;
      if (devText.contains('curtain') || devText.contains('blind')) return RoomCapabilityKind.curtain;
      if (devText.contains('light') || devText.contains('lamp') || devText.contains('bulb')) {
        return RoomCapabilityKind.light;
      }
      return RoomCapabilityKind.switchControl;
    }

    if (_devices.isNotEmpty) {
      final Map<String, List<ConnectedDeviceSummary>> roomMap = {};
      for (final d in _devices) {
        final room = d.roomName.trim().isEmpty ? 'Living Room' : d.roomName;
        roomMap.putIfAbsent(room, () => []).add(d);
      }
      result.addAll(roomMap.entries.map((entry) {
        final roomName = entry.key;
        final roomDevices = entry.value;
        final matchingBackendRoom = _backendRooms.cast<Room?>().firstWhere(
          (br) => br?.name.toLowerCase() == roomName.toLowerCase(),
          orElse: () => null,
        );
        final roomId = matchingBackendRoom?.id ?? roomName.toLowerCase().replaceAll(
          RegExp(r'[^a-z0-9]'),
          '_',
        );
        final anyOnline = roomDevices.any((d) => d.online);
        final roomConnectivity = anyOnline ? ConnectivityCause.online : ConnectivityCause.deviceOffline;
        final roomStatus = anyOnline ? RoomStatus.normal : RoomStatus.unavailable;
        final anyChannelOnInRoom = roomDevices.any((d) {
          for (int ch = 1; ch <= 4; ch++) {
            if (getDeviceChannelPower(d.id, ch, defaultValue: ch == 1 ? _livingRoomLightOn : false)) {
              return true;
            }
          }
          return false;
        });
        final roomSummary = anyOnline
            ? (anyChannelOnInRoom ? 'Active · Normal' : 'Standby · Normal')
            : 'Offline · Disconnected';

        return Room(
          id: roomId,
          name: roomName,
          iconKey: matchingBackendRoom?.iconKey ?? 'living',
          deviceCount: roomDevices.length,
          connectivity: roomConnectivity,
          telemetryFreshness: anyOnline ? TelemetryFreshness.current : TelemetryFreshness.unknown,
          summary: roomSummary,
          status: roomStatus,
          capabilities: roomDevices.expand((d) {
            final isSocket = d.name.toLowerCase().contains('socket') ||
                d.model.toLowerCase().contains('socket');
            final channelPrefix = isSocket ? 'Socket' : 'Switch';
            final labels = DeviceStorageService.getChannelLabels(d.id);
            final ch1Name = labels[1] ?? '$channelPrefix 1';
            final ch2Name = labels[2] ?? '$channelPrefix 2';
            final ch3Name = labels[3] ?? '$channelPrefix 3';
            final ch1On = getDeviceChannelPower(
              d.id,
              1,
              defaultValue: _livingRoomLightOn,
            );
            final ch2On = getDeviceChannelPower(d.id, 2, defaultValue: false);
            final ch3On = getDeviceChannelPower(d.id, 3, defaultValue: false);
            return [
              RoomCapability(
                id: '${d.id}_ch1',
                label: ch1Name,
                value: ch1On ? 'On' : 'Off',
                kind: inferCapKind(d.name, d.model, ch1Name),
                isOnline: d.online,
              ),
              RoomCapability(
                id: '${d.id}_ch2',
                label: ch2Name,
                value: ch2On ? 'On' : 'Off',
                kind: inferCapKind(d.name, d.model, ch2Name),
                isOnline: d.online,
              ),
              RoomCapability(
                id: '${d.id}_ch3',
                label: ch3Name,
                value: ch3On ? 'On' : 'Off',
                kind: inferCapKind(d.name, d.model, ch3Name),
                isOnline: d.online,
              ),
            ];
          }).toList(),
          devices: roomDevices.map((d) {
            final opName = formatOperatingName(d.name);
            final isSocket = d.name.toLowerCase().contains('socket') ||
                d.model.toLowerCase().contains('socket');
            final devType =
                isSocket ? 'Smart Socket 3X' : 'Smart Switch 3X';
            final ch1On = getDeviceChannelPower(
              d.id,
              1,
              defaultValue: _livingRoomLightOn,
            );
            return RoomDevice(
              id: d.id,
              name: opName,
              type: devType,
              value: ch1On ? 'On' : 'Off',
              kind: inferCapKind(d.name, d.model, opName),
              confidence: !d.online
                  ? ActuatorConfidence.unavailable
                  : (_deviceConfidences[d.id] ?? ActuatorConfidence.confirmed),
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
      }));
    }

    // Include backend rooms that don't have devices assigned yet
    for (final bRoom in _backendRooms) {
      if (!result.any((r) => r.name.toLowerCase() == bRoom.name.toLowerCase())) {
        result.add(Room(
          id: bRoom.id,
          name: bRoom.name,
          iconKey: bRoom.iconKey,
          deviceCount: 0,
          connectivity: ConnectivityCause.deviceOffline,
          telemetryFreshness: TelemetryFreshness.unknown,
          summary: 'Empty room',
          status: RoomStatus.normal,
          capabilities: const [],
          devices: const [],
          insights: bRoom.insights,
        ));
      }
    }

    // Include custom rooms that don't have devices assigned yet
    for (final emptyRoom in _customEmptyRooms) {
      if (!result.any((r) => r.name.toLowerCase() == emptyRoom.name.toLowerCase())) {
        result.add(Room(
          id: emptyRoom.id,
          name: emptyRoom.name,
          iconKey: emptyRoom.iconKey,
          deviceCount: 0,
          connectivity: ConnectivityCause.deviceOffline,
          telemetryFreshness: TelemetryFreshness.unknown,
          summary: 'Empty room',
          status: RoomStatus.normal,
          capabilities: const [],
          devices: const [],
          insights: emptyRoom.insights,
        ));
      }
    }

    return result;
  }

  /// Rename device channel persistently across local storage and cloud
  Future<void> renameDeviceChannel({
    required String deviceId,
    required int channelIndex,
    required String newName,
  }) async {
    await DeviceStorageService.saveChannelLabel(deviceId, channelIndex, newName);
    if (_repository is CloudHomeRepository) {
      await _repository.renameChannel(
        deviceId: deviceId,
        channelIndex: channelIndex,
        newName: newName,
      );
    } else {
      await _repository.claimDevice(
        deviceId: deviceId,
        homeId: _activeHomeId ?? 'home_01',
        channelLabels: {channelIndex.toString(): newName},
      );
    }
    notifyListeners();
  }

  /// Rename room persistently across local cache and cloud
  Future<void> renameRoom({
    required String roomId,
    required String oldName,
    required String newName,
  }) async {
    await DeviceStorageService.renameRoom(oldName, newName);
    final matchingBackendRoom = _backendRooms.cast<Room?>().firstWhere(
      (br) => br?.id == roomId || br?.name.toLowerCase() == oldName.toLowerCase(),
      orElse: () => null,
    );
    final effectiveRoomId = matchingBackendRoom?.id ?? roomId;

    if (_repository is CloudHomeRepository) {
      await _repository.renameRoom(
        roomId: effectiveRoomId,
        newName: newName,
      );
    }
    for (int i = 0; i < _backendRooms.length; i++) {
      if (_backendRooms[i].id == roomId || _backendRooms[i].id == effectiveRoomId || _backendRooms[i].name.toLowerCase() == oldName.toLowerCase()) {
        _backendRooms[i] = Room(
          id: _backendRooms[i].id,
          name: newName,
          iconKey: _backendRooms[i].iconKey,
          deviceCount: _backendRooms[i].deviceCount,
          connectivity: _backendRooms[i].connectivity,
          telemetryFreshness: _backendRooms[i].telemetryFreshness,
          summary: _backendRooms[i].summary,
          status: _backendRooms[i].status,
          capabilities: _backendRooms[i].capabilities,
          devices: _backendRooms[i].devices,
          insights: _backendRooms[i].insights,
        );
      }
    }
    for (int i = 0; i < _customEmptyRooms.length; i++) {
      if (_customEmptyRooms[i].id == roomId || _customEmptyRooms[i].id == effectiveRoomId || _customEmptyRooms[i].name.toLowerCase() == oldName.toLowerCase()) {
        _customEmptyRooms[i] = Room(
          id: _customEmptyRooms[i].id,
          name: newName,
          iconKey: _customEmptyRooms[i].iconKey,
          deviceCount: _customEmptyRooms[i].deviceCount,
          connectivity: _customEmptyRooms[i].connectivity,
          telemetryFreshness: _customEmptyRooms[i].telemetryFreshness,
          summary: _customEmptyRooms[i].summary,
          status: _customEmptyRooms[i].status,
          capabilities: _customEmptyRooms[i].capabilities,
          devices: _customEmptyRooms[i].devices,
          insights: _customEmptyRooms[i].insights,
        );
      }
    }
    for (int i = 0; i < _devices.length; i++) {
      if (_devices[i].roomName.toLowerCase() == oldName.toLowerCase()) {
        _devices[i] = ConnectedDeviceSummary(
          id: _devices[i].id,
          name: _devices[i].name,
          model: _devices[i].model,
          firmware: _devices[i].firmware,
          connectedVia: _devices[i].connectedVia,
          signalLabel: _devices[i].signalLabel,
          roomName: newName,
          online: _devices[i].online,
        );
      }
    }
    notifyListeners();
  }

  /// Delete room persistently across local cache and cloud
  Future<void> deleteRoom({
    required String roomId,
    required String roomName,
  }) async {
    await DeviceStorageService.deleteRoom(roomName);
    final matchingBackendRoom = _backendRooms.cast<Room?>().firstWhere(
      (br) => br?.id == roomId || br?.name.toLowerCase() == roomName.toLowerCase(),
      orElse: () => null,
    );
    final effectiveRoomId = matchingBackendRoom?.id ?? roomId;

    _customEmptyRooms.removeWhere((r) => r.id == roomId || r.id == effectiveRoomId || r.name.toLowerCase() == roomName.toLowerCase());
    _backendRooms.removeWhere((r) => r.id == roomId || r.id == effectiveRoomId || r.name.toLowerCase() == roomName.toLowerCase());
    for (int i = 0; i < _devices.length; i++) {
      if (_devices[i].roomName.toLowerCase() == roomName.toLowerCase()) {
        _devices[i] = ConnectedDeviceSummary(
          id: _devices[i].id,
          name: _devices[i].name,
          model: _devices[i].model,
          firmware: _devices[i].firmware,
          connectedVia: _devices[i].connectedVia,
          signalLabel: _devices[i].signalLabel,
          roomName: 'Living Room',
          online: _devices[i].online,
        );
      }
    }
    if (_repository is CloudHomeRepository) {
      await _repository.deleteRoom(effectiveRoomId);
    }
    notifyListeners();
  }

  HomeDashboardData get dashboard {
    if (_devices.isNotEmpty) {
      final Map<String, Map<int, String>> allChannelLabels = {};
      for (final d in _devices) {
        allChannelLabels[d.id] = DeviceStorageService.getChannelLabels(d.id);
      }
      return HomeDashboardData.forLiveDevices(
        devices: _devices,
        lightOn: _livingRoomLightOn,
        lightConfidence: _lightConfidence,
        selectedControlIds: _selectedQuickControlIds,
        channelStates: _channelStates,
        channelLabels: allChannelLabels,
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

  bool getDeviceChannelPower(
    String deviceId,
    int channelIndex, {
    bool defaultValue = false,
  }) {
    return _channelStates[deviceId]?[channelIndex] ?? defaultValue;
  }

  void _subscribeToRealtime(RealtimeEventService service) {
    _sseSubscription = service.events.listen(_handleSseEvent);
  }

  void _handleSseEvent(SSEEventEnvelope envelope) {
    switch (envelope.type) {
      case 'device.availability':
        final status = envelope.payload['status'] as String?;
        final devId = envelope.payload['deviceId'] as String?;
        final isOnline = status == 'ONLINE';
        if (isOnline) {
          _cloudDeviceConnection = DeviceConnection.online;
        } else if (status == 'STALE') {
          _cloudDeviceConnection = DeviceConnection.stale;
        } else {
          _cloudDeviceConnection = DeviceConnection.offline;
        }

        // Reflect in live devices list
        for (int i = 0; i < _devices.length; i++) {
          if (devId == null || _devices[i].id == devId) {
            _devices[i] = ConnectedDeviceSummary(
              id: _devices[i].id,
              name: _devices[i].name,
              model: _devices[i].model,
              firmware: _devices[i].firmware,
              connectedVia: _devices[i].connectedVia,
              signalLabel: isOnline ? 'Strong' : 'Offline',
              roomName: _devices[i].roomName,
              online: isOnline,
            );
          }
        }
        if (_connectedDeviceSummary != null && (devId == null || _connectedDeviceSummary!.id == devId)) {
          _connectedDeviceSummary = ConnectedDeviceSummary(
            id: _connectedDeviceSummary!.id,
            name: _connectedDeviceSummary!.name,
            model: _connectedDeviceSummary!.model,
            firmware: _connectedDeviceSummary!.firmware,
            connectedVia: _connectedDeviceSummary!.connectedVia,
            signalLabel: isOnline ? 'Strong' : 'Offline',
            roomName: _connectedDeviceSummary!.roomName,
            online: isOnline,
          );
        }
        _connectionState = _devices.any((d) => d.online)
            ? HomeConnectionState.connected
            : HomeConnectionState.offline;
        notifyListeners();
        break;

      case 'device.state':
        // Authoritative state convergence for toggle channels
        final state = envelope.payload;
        final devId = state['deviceId'] as String? ?? _activeDeviceId;
        if (devId != null) {
          // 1. Handle channels as List (standard firmware envelope)
          if (state['channels'] is List) {
            for (final ch in (state['channels'] as List)) {
              if (ch is Map) {
                final chIdx = _parseChannelIndex(ch) ?? 1;
                final pwr = _parsePowerFromChannel(ch);
                if (pwr != null) {
                  _channelStates.putIfAbsent(devId, () => {})[chIdx] = pwr;
                  if (chIdx == 1 && (devId == _activeDeviceId || (_devices.isNotEmpty && devId == _devices.first.id))) {
                    _livingRoomLightOn = pwr;
                    _lightConfidence = ActuatorConfidence.confirmed;
                    _lightCommandPending = false;
                  }
                }
              }
            }
          }
          // 2. Handle channels as Map
          else if (state['channels'] is Map) {
            final channels = state['channels'] as Map;
            channels.forEach((key, val) {
              final chIdx = int.tryParse(key.toString().replaceAll(RegExp(r'[^0-9]'), '')) ?? 1;
              bool? pwr;
              if (val is Map) {
                pwr = _parsePowerFromChannel(val);
              } else if (val is bool) {
                pwr = val;
              }
              if (pwr != null) {
                _channelStates.putIfAbsent(devId, () => {})[chIdx] = pwr;
                if (chIdx == 1 && (devId == _activeDeviceId || (_devices.isNotEmpty && devId == _devices.first.id))) {
                  _livingRoomLightOn = pwr;
                  _lightConfidence = ActuatorConfidence.confirmed;
                  _lightCommandPending = false;
                }
              }
            });
          }
          // 3. Handle single-channel state update
          else if (state.containsKey('channelIndex') || state.containsKey('channel')) {
            final chIdx = _parseChannelIndex(state) ?? 1;
            final pwr = _parsePowerFromChannel(state);
            if (pwr != null) {
              _channelStates.putIfAbsent(devId, () => {})[chIdx] = pwr;
              if (chIdx == 1 && (devId == _activeDeviceId || (_devices.isNotEmpty && devId == _devices.first.id))) {
                _livingRoomLightOn = pwr;
                _lightConfidence = ActuatorConfidence.confirmed;
                _lightCommandPending = false;
              }
            }
          }
        }
        debugPrint('[DEVICE] STATE_RECONCILED devId=$devId');
        notifyListeners();
        break;

      case 'device.event':
        final event = envelope.payload;
        final devId = event['deviceId'] as String? ?? _activeDeviceId;
        if (devId != null) {
          final chIdx = _parseChannelIndex(event) ?? 1;
          final pwr = _parsePowerFromChannel(event) ??
              (event['payload'] is Map ? _parsePowerFromChannel(event['payload'] as Map) : null) ??
              (event['payload'] is bool ? (event['payload'] as bool) : null);
          if (pwr != null) {
            _channelStates.putIfAbsent(devId, () => {})[chIdx] = pwr;
            if (chIdx == 1 && (devId == _activeDeviceId || (_devices.isNotEmpty && devId == _devices.first.id))) {
              _livingRoomLightOn = pwr;
              _lightConfidence = ActuatorConfidence.confirmed;
              _lightCommandPending = false;
            }
          }
        }
        debugPrint('[DEVICE] EVENT_RECONCILED devId=$devId');
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
    final deletedIds = await _storageService.loadDeletedSpaceIds();
    final loadedSpaces = await _storageService.loadSpaces();
    _spaces.clear();
    for (final sp in loadedSpaces) {
      if (!deletedIds.contains(sp['id'])) {
        _spaces.add(sp);
      }
    }
    if (_spaces.isEmpty) {
      _spaces.add({'id': 'home_default', 'name': 'My Home', 'icon': 'home'});
    } else {
      final firstName = _spaces.first['name']?.toString().toLowerCase() ?? '';
      if (firstName.contains('pavan') || firstName == 'home') {
        _spaces.first['name'] = 'My Home';
      }
    }

    if (!_spaces.any((s) => s['id'] == _activeSpaceId)) {
      _activeSpaceId = _spaces.first['id'] as String;
      _activeSpaceName = _spaces.first['name'] as String;
    } else {
      final cur = _spaces.firstWhere((s) => s['id'] == _activeSpaceId);
      _activeSpaceName = cur['name'] as String;
    }

    if (_devices.isEmpty) {
      final savedList = await _storageService.loadDevicesForSpace(_activeSpaceId);
      if (savedList.isNotEmpty) {
        _devices = List.from(savedList);
        _connectedDeviceSummary = _devices.first;
        _activeDeviceId = _devices.first.id;
        _activeDisplayName = _devices.first.name;
        _activeSerialNumber = _devices.first.model;
        _connectionState = HomeConnectionState.connected;
        _connectionMessage = '${_devices.first.name} is connected and online.';
        debugPrint('[HOME] DEVICE_REGISTERED count=${_devices.length}');
        debugPrint('[HOME] DEVICE_PERSISTED');
        debugPrint('[HOME] HOME_STATE_REFRESH');
        debugPrint('[HOME] REAL_DEVICE_COUNT=${_devices.length}');
        debugPrint('[HOME] DEVICE_STATUS=ONLINE');
      }
    }
    _spaceDevicesCache[_activeSpaceId] = List.from(_devices);

    for (final sp in _spaces) {
      final spId = sp['id'] as String;
      if (spId != _activeSpaceId) {
        _spaceDevicesCache[spId] = await _storageService.loadDevicesForSpace(spId);
      }
    }

    await _loadCustomizationsForActiveSpace();

    final qControls = await _storageService.loadQuickControls();
    if (qControls.isNotEmpty) {
      _selectedQuickControlIds = List.from(qControls);
    }
    final nPrefs = await _storageService.loadNotificationPrefs();
    if (nPrefs.isNotEmpty) {
      _notificationPrefs = Map.from(nPrefs);
    }
    notifyListeners();
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

    if (_activeHomeId != null) {
      _repository
          .claimDevice(
            deviceId: deviceId,
            homeId: _activeHomeId!,
            customName: displayName,
          )
          .catchError((err) {
            debugPrint('[HOME] Warning: could not claim device on backend: $err');
          });
    }

    debugPrint(
      '[HOME] DEVICE_REGISTERED id=$deviceId name=$displayName room=${roomName ?? "Living Room"}',
    );
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

  Future<void> setLivingRoomLight(bool value) {
    if (!_cloudEnabled) {
      _lightConfidence = ActuatorConfidence.unavailable;
      _lightCommandPending = false;
      notifyListeners();
      return Future.value();
    }
    _lightCommandPending = true;
    notifyListeners();
    final targetId =
        _activeDeviceId ??
        (_devices.isNotEmpty ? _devices.first.id : 'ce196211-91cf-496a-9403-709d8589eb15');
    return setDeviceChannelPower(
      deviceId: targetId,
      channelIndex: 1,
      value: value,
    );
  }

  Future<void> setDeviceChannelPower({
    required String deviceId,
    required int channelIndex,
    required bool value,
  }) async {
    _channelStates.putIfAbsent(deviceId, () => {})[channelIndex] = value;
    _lastCommandTimestamps['${deviceId}_$channelIndex'] = DateTime.now();
    if (channelIndex == 1 &&
        (deviceId == _activeDeviceId ||
            (_devices.isNotEmpty && deviceId == _devices.first.id))) {
      _livingRoomLightOn = value;
    }
    _deviceConfidences[deviceId] = ActuatorConfidence.pending;
    _lightCommandPending = true;
    debugPrint(
      '[DEVICE] COMMAND_SENT deviceId=$deviceId channel=$channelIndex enabled=$value (isLocalMode=$_isLocalMode)',
    );
    notifyListeners();

    bool commandHandled = false;

    // Fast-path 1: If already operating in Local Wi-Fi Mode or cloud is known unreachable,
    // dispatch directly to ESP32 local HTTP server immediately (0ms delay)
    if (_isLocalMode || !_isCloudReachable) {
      final localSuccess = await LocalLanDeviceService.instance.sendLocalControl(
        deviceId: deviceId,
        channelIndex: channelIndex,
        power: value,
      );
      if (localSuccess) {
        _deviceMissedPolls[deviceId] = 0;
        _lanMissedPollCount = 0;
        for (int i = 0; i < _devices.length; i++) {
          if (_devices[i].id == deviceId && (!_devices[i].online || _devices[i].signalLabel != 'Local Wi-Fi')) {
            _devices[i] = ConnectedDeviceSummary(
              id: _devices[i].id,
              name: _devices[i].name,
              model: _devices[i].model,
              firmware: _devices[i].firmware,
              connectedVia: _devices[i].connectedVia,
              signalLabel: 'Local Wi-Fi',
              roomName: _devices[i].roomName,
              online: true,
            );
          }
        }
        _deviceConfidences[deviceId] = ActuatorConfidence.confirmed;
        _lightConfidence = ActuatorConfidence.confirmed;
        _lightCommandPending = false;
        notifyListeners();
        debugPrint('[DEVICE] DIRECT_LOCAL_LAN_SUCCESS deviceId=$deviceId channel=$channelIndex');
        return;
      }
    }

    // Normal path: Attempt Cloud MQTT/REST first
    try {
      final receipt = await _repository.sendCommand(
        deviceId: deviceId,
        action: 'setPower',
        parameters: {
          'channel': channelIndex,
          'channelIndex': channelIndex,
          'value': value,
          'enabled': value,
          'power': value,
        },
        idempotencyKey:
            'cmd-$deviceId-ch$channelIndex-${DateTime.now().microsecondsSinceEpoch}',
      );
      if (receipt.state == CommandState.accepted ||
          receipt.state == CommandState.succeeded) {
        _deviceConfidences[deviceId] = ActuatorConfidence.confirmed;
        _lightConfidence = ActuatorConfidence.confirmed;
        commandHandled = true;
      }
    } catch (e) {
      debugPrint('[DEVICE] Cloud command failed ($e), falling back to Local LAN...');
    }

    if (!commandHandled) {
      // Cloud is offline or unreachable -> Fallback to Direct Local LAN Control over Wi-Fi
      final localSuccess = await LocalLanDeviceService.instance.sendLocalControl(
        deviceId: deviceId,
        channelIndex: channelIndex,
        power: value,
      );
      if (localSuccess) {
        _isLocalMode = true;
        _deviceMissedPolls[deviceId] = 0;
        _lanMissedPollCount = 0;
        for (int i = 0; i < _devices.length; i++) {
          if (_devices[i].id == deviceId && (!_devices[i].online || _devices[i].signalLabel != 'Local Wi-Fi')) {
            _devices[i] = ConnectedDeviceSummary(
              id: _devices[i].id,
              name: _devices[i].name,
              model: _devices[i].model,
              firmware: _devices[i].firmware,
              connectedVia: _devices[i].connectedVia,
              signalLabel: 'Local Wi-Fi',
              roomName: _devices[i].roomName,
              online: true,
            );
          }
        }
        _deviceConfidences[deviceId] = ActuatorConfidence.confirmed;
        _lightConfidence = ActuatorConfidence.confirmed;
        debugPrint('[DEVICE] LOCAL_LAN_COMMAND_SUCCESS deviceId=$deviceId channel=$channelIndex');
      } else {
        _deviceConfidences[deviceId] = ActuatorConfidence.confirmed;
        debugPrint('[DEVICE] Both Cloud and Local LAN failed for deviceId=$deviceId');
      }
    }

    _lightCommandPending = false;
    notifyListeners();
  }

  Future<void> updateDeviceWifi({
    required String deviceId,
    required String ssid,
    required String password,
  }) async {
    try {
      await _repository.sendCommand(
        deviceId: deviceId,
        action: 'setWifiConfig',
        parameters: {
          'ssid': ssid,
          'password': password,
        },
        idempotencyKey: 'wifi-${DateTime.now().microsecondsSinceEpoch}',
      );
      debugPrint('[HOME] Wi-Fi credentials dispatched to device $deviceId');
    } catch (e) {
      debugPrint('[HOME] Failed to dispatch Wi-Fi credentials: $e');
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

    final targetId =
        _activeDeviceId ??
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

  Future<void> addCustomRoom(String roomName, {String iconKey = 'living'}) async {
    final trimmed = roomName.trim();
    if (trimmed.isEmpty) return;

    Map<String, dynamic>? createdData;
    try {
      createdData = await _repository.createRoom(
        name: trimmed,
        homeId: _activeHomeId,
        iconKey: iconKey,
      );
    } catch (e) {
      debugPrint('[HOME] Failed to persist room to cloud: $e');
    }

    await _storageService.addRoom(trimmed);
    final roomId = (createdData != null && createdData['id'] != null)
        ? createdData['id'].toString()
        : trimmed.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_');

    final exists = rooms.any((r) => r.name.toLowerCase() == trimmed.toLowerCase());
    if (!exists) {
      _customEmptyRooms.add(
        Room(
          id: roomId,
          name: trimmed,
          iconKey: iconKey,
          deviceCount: 0,
          connectivity: ConnectivityCause.online,
          telemetryFreshness: TelemetryFreshness.current,
          summary: '0 devices · Configured',
          status: RoomStatus.normal,
          capabilities: const [],
          devices: const [],
          insights: const RoomInsights(
            energyKwh: '0.0 kWh',
            energyChange: '0.0 kWh',
            activeWindow: 'Today',
            averageTemperature: '24°C',
            averageHumidity: '55%',
          ),
        ),
      );
      notifyListeners();
    }
  }

  Future<void> moveDeviceToRoom(String deviceId, String newRoomName) async {
    final trimmedRoom = newRoomName.trim().isEmpty ? 'Living Room' : newRoomName.trim();
    final idx = _devices.indexWhere((d) => d.id == deviceId);
    if (idx >= 0) {
      final old = _devices[idx];
      final updated = ConnectedDeviceSummary(
        id: old.id,
        name: old.name,
        model: old.model,
        firmware: old.firmware,
        connectedVia: old.connectedVia,
        signalLabel: old.signalLabel,
        roomName: trimmedRoom,
        online: old.online,
      );
      _devices[idx] = updated;
      await _storageService.saveDevice(updated);
      _customEmptyRooms.removeWhere((r) => r.name.toLowerCase() == trimmedRoom.toLowerCase());
      notifyListeners();
    }
  }

  Future<void> saveQuickControlSelection(List<String> controlIds) async {
    _selectedQuickControlIds = List.from(controlIds);
    await _storageService.saveQuickControls(_selectedQuickControlIds);
    notifyListeners();
  }

  Future<void> updateNotificationPreference(String key, bool value) async {
    _notificationPrefs[key] = value;
    await _storageService.saveNotificationPrefs({key: value});
    notifyListeners();
  }

  bool _disposed = false;

  @override
  void notifyListeners() {
    if (_disposed) return;
    super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _autoSyncTimer?.cancel();
    _sseSubscription?.cancel();
    super.dispose();
  }
}
