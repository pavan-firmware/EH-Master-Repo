import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import '../core/api/api_client.dart';
import '../core/models/routine_models.dart';
import '../core/repositories/cloud_routine_repository.dart';

import '../core/models/connection_models.dart';
import '../core/models/device_models.dart';
import '../core/models/authoritative_home_connection_state.dart';
import '../core/models/home_dashboard_models.dart';
import '../core/models/room_models.dart';
import '../core/repositories/home_repository.dart';
import '../core/repositories/cloud_home_repository.dart';
import '../core/repositories/fake_home_repository.dart';
import '../core/repositories/connection_repository.dart';
import '../core/repositories/ble_connection_repository.dart';
import '../core/config/device_connection_config.dart';
import '../core/services/realtime_event_service.dart';

import '../core/capabilities/repositories/product_catalog_repository.dart';
import '../core/services/device_storage_service.dart';
import '../core/services/local_lan_device_service.dart';
import '../core/services/edge_routine_sync_service.dart';
import '../core/services/change_tracking_service.dart';

import '../core/utils/device_name_formatter.dart';
import '../core/utils/event_classification.dart';

enum ConnectionRoutingMode {
  auto,
  localOnly,
  cloudOnly,
}

enum SyncMode {
  auto,
  manual,
}

enum UpcomingRoutineSortMode {
  currentSpaceFirst,
  currentSpaceOnly,
  nearestTimeFirst,
}

/// HomeController manages all home/device/connection state.
///
/// In production (Phase 7C), pass [repository] = CloudHomeRepository
/// and [realtimeEventService] = RealtimeEventService. The FakeHomeRepository
/// is retained as the default so all pre-existing tests continue to pass.
class HomeController extends ChangeNotifier with WidgetsBindingObserver {
  static HomeController? instance;
  RealtimeEventService? _realtimeService;
  final _channelAlertStreamController = StreamController<SpaceAlertItem>.broadcast();
  Stream<SpaceAlertItem> get channelAlertStream => _channelAlertStreamController.stream;

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
    instance = this;
    _realtimeService = realtimeEventService;
    final cachedList = DeviceStorageService.cachedDevices;
    if (cachedList.isNotEmpty) {
      _devices = _deduplicateDevices(cachedList);
      _connectedDeviceSummary = _devices.first;
      _activeDeviceId = _devices.first.id;
      _activeDisplayName = _devices.first.name;
      _activeSerialNumber = _devices.first.model;
      final anyOnline = _devices.any((d) => d.online);
      _connectionState = anyOnline ? HomeConnectionState.connected : HomeConnectionState.offline;
      _connectionMessage = anyOnline
          ? '${_devices.first.name} is connected.'
          : '${_devices.first.name} is offline.';
      debugPrint('[HOME] SYNC_HYDRATED devices_count=${_devices.length}');
    }
    if (realtimeEventService != null) {
      _subscribeToRealtime(realtimeEventService);
    }
    _subscribeToLocalUdpBroadcasts();
    _hydrateFromStorage();
    if (_routingMode == ConnectionRoutingMode.auto || _routingMode == ConnectionRoutingMode.localOnly) {
      unawaited(probeLanAndPromote());
    }
    if (autoSync) {
      _startAutoSyncTimer();
      _startRoutineScheduler();
      _startAutoModeLanPromotionTimer();
    }
    try {
      WidgetsBinding.instance.addObserver(this);
    } catch (_) {}
  }

  void _subscribeToLocalUdpBroadcasts() {
    LocalLanDeviceService.instance.onStateBroadcast.listen((event) {
      final devId = event.deviceId;
      final changed = _syncHardwareModelAndState(devId, event);

      // Auto Mode: Promote immediately to Local LAN Mode on incoming UDP broadcast
      if (_routingMode == ConnectionRoutingMode.auto && !_isLocalMode) {
        _promoteToLocalLanMode(devId, event);
        debugPrint('[LAN-UDP] Auto Mode promoted to Local LAN Mode via UDP broadcast from $devId');
        return;
      }

      if (changed) {
        debugPrint('[LAN-UDP] State & Model synchronized instantly from broadcast for $devId: ${event.channels} model=${event.model}');
        notifyListeners();
      }
    });
  }

  bool _syncHardwareModelAndState(String devId, LanDeviceState devState) {
    bool modified = false;
    final chMap = devState.channels;

    _deviceMissedPolls[devId] = 0;
    final devChannels = _channelStates.putIfAbsent(devId, () => {});
    // Determine max channels for this device to prevent phantom channels
    int devMaxChannels = 4;
    final knownDev = _devices.cast<ConnectedDeviceSummary?>().firstWhere((d) => d?.id == devId, orElse: () => null);
    if (knownDev != null) {
      final canon = MockProductCatalogRepository.resolveCanonicalProductVariant(variantId: knownDev.model, deviceName: knownDev.name);
      devMaxChannels = canon.contains('1x') ? 1 : (canon.contains('2x') ? 2 : (canon.contains('3x') ? 3 : 4));
    } else if (devState.channelCount != null && devState.channelCount! > 0) {
      devMaxChannels = devState.channelCount!;
    }
    chMap.forEach((chIdx, pwr) {
      if (chIdx > devMaxChannels) return;
      final cmdKey1 = '${devId}_$chIdx';
      final cmdKey2 = '${devId.toLowerCase()}_$chIdx';
      final cmdKey3 = '${devId}_ch$chIdx';
      final lastCmd = _lastCommandTimestamps[cmdKey1] ?? _lastCommandTimestamps[cmdKey2] ?? _lastCommandTimestamps[cmdKey3];
      if (lastCmd != null && DateTime.now().difference(lastCmd).inMilliseconds < 3500 && devChannels[chIdx] != pwr) {
        return;
      }
      if (devChannels[chIdx] != pwr) {
        devChannels[chIdx] = pwr;
        modified = true;
        _checkAndDispatchChannelAlert(devId, chIdx, pwr);
      }
      final isLivingRoomDev = _devices.any((d) => d.id == devId && d.roomName.toLowerCase().contains('living'));
      if (chIdx == 1 && isLivingRoomDev) {
        _livingRoomLightOn = pwr;
      }
    });
    devChannels.removeWhere((k, _) => k > devMaxChannels);

    // 1. Check if device belongs to the active space
    bool foundInActive = false;
    for (int i = 0; i < _devices.length; i++) {
      final d = _devices[i];
      if (d.id == devId) {
        foundInActive = true;
        _channelStates[d.id] = Map<int, bool>.from(devChannels);
        final currentDev = _devices[i];
        if (!currentDev.online || currentDev.signalLabel != 'Local Wi-Fi') {
          _devices[i] = currentDev.copyWith(
            online: true,
            signalLabel: 'Local Wi-Fi',
          );
          _storageService.saveDeviceForSpace(_activeSpaceId, _devices[i]);
          if (_connectedDeviceSummary?.id == currentDev.id) {
            _connectedDeviceSummary = _devices[i];
          }
          modified = true;
        }
        break;
      }
    }

    // 2. Check if device belongs to any other space in cache
    String? foundSpaceId;
    if (!foundInActive) {
      for (final sp in _spaces) {
        final spId = sp['id'] as String;
        final list = _spaceDevicesCache[spId];
        if (list != null) {
          final matchIdx = list.indexWhere((d) => d.id == devId);
          if (matchIdx >= 0) {
            foundSpaceId = spId;
            _channelStates[list[matchIdx].id] = Map<int, bool>.from(devChannels);
            final updated = list.map((d) {
              if (d.id == devId) {
                return d.copyWith(online: true, signalLabel: 'Local Wi-Fi');
              }
              return d;
            }).toList();
            _spaceDevicesCache[spId] = updated;
            modified = true;
            break;
          }
        }
      }
    }

    // 3. Only if device is completely unregistered anywhere
    if (!foundInActive && foundSpaceId == null && devId.isNotEmpty) {
      final alreadyInActive = _devices.any((d) => d.id == devId);
      if (!alreadyInActive) {
        final primarySpaceId = _spaces.isNotEmpty ? (_spaces.first['id'] as String) : 'home_default';
        final isPrimary = isPrimarySpaceId(_activeSpaceId);

        final tempName = (devState.model ?? '').toLowerCase().contains('sk') || (devState.model ?? '').toLowerCase().contains('socket') ? 'EH Smart Socket' : 'EH Smart Switch';
        final resolvedCanon = MockProductCatalogRepository.resolveCanonicalProductVariant(
          variantId: devState.model,
          deviceName: tempName,
        );
        final isSocket = resolvedCanon.contains('socket');
        final is4X = resolvedCanon.contains('4x');
        final is3X = resolvedCanon.contains('3x');
        final is2X = resolvedCanon.contains('2x');
        final is1X = resolvedCanon.contains('1x');
        final suffix = is4X ? '4X' : (is3X ? '3X' : (is2X ? '2X' : (is1X ? '1X' : '')));
        final devName = isSocket
            ? (suffix.isNotEmpty ? 'EH Smart Socket $suffix' : 'EH Smart Socket')
            : (suffix.isNotEmpty ? 'EH Smart Switch $suffix' : 'EH Smart Switch');
        final newDev = ConnectedDeviceSummary(
          id: devId,
          name: devName,
          model: resolvedCanon,
          firmware: '1.0.0',
          connectedVia: 'Wi-Fi (2.4 GHz)',
          signalLabel: 'Local Wi-Fi',
          roomName: 'Unassigned',
          online: true,
        );

      if (isPrimary) {
        _devices.add(newDev);
        _connectedDeviceSummary ??= newDev;
        _activeDeviceId ??= devId;
        _activeDisplayName ??= devName;
        _activeSerialNumber ??= newDev.model;
        _connectionState = HomeConnectionState.connected;
        _connectionMessage = '$devName is connected and online.';
        _storageService.saveDeviceForSpace(_activeSpaceId, newDev);
        _spaceDevicesCache[_activeSpaceId] = List.from(_devices);

        if (_selectedQuickControlIds.isEmpty) {
          final count = devState.channelCount ?? (chMap.isNotEmpty ? chMap.length : 4);
          final newIds = List.generate(count, (i) => '${devId}_ch${i + 1}');
          _selectedQuickControlIds = newIds;
          _storageService.saveQuickControlsForSpace(_activeSpaceId, newIds);
          _storageService.saveQuickControls(newIds);
        }

        if (_repository is CloudHomeRepository && _activeHomeId != null && _activeHomeId!.isNotEmpty) {
          final isDevSocket = newDev.name.toLowerCase().contains('socket') || newDev.model.toLowerCase().contains('socket');
          _repository.registerDevice(
            deviceId: devId,
            serialNumber: 'EH-${newDev.model.toUpperCase()}-${devId.substring(0, math.min(devId.length, 6))}',
            productVariantId: newDev.model,
            hardwareRevision: 'HW_1_0',
            firmwareFamily: isDevSocket ? 'esp32c6-socket-platform' : 'esp32c6-switch-platform',
            firmwareVersion: newDev.firmware.isNotEmpty ? newDev.firmware : '1.0.0',
          ).catchError((_) {});

          _repository.claimDevice(
            deviceId: devId,
            homeId: _activeHomeId!,
            customName: devName,
          ).catchError((err) {
            debugPrint('[HOME] Auto-claim discovered device error: $err');
          });
        }
        modified = true;
      } else {
        // If user is currently in a secondary space (Office, etc.), store in Primary space cache only
        final primaryList = _spaceDevicesCache[primarySpaceId] ?? [];
        if (!primaryList.any((d) => d.id == devId)) {
          primaryList.add(newDev);
          _spaceDevicesCache[primarySpaceId] = primaryList;
          _storageService.saveDeviceForSpace(primarySpaceId, newDev);
          modified = true;
        }
      }
    }
    }
    return modified;
  }

  final HomeRepository _repository;
  HomeRepository get repository => _repository;
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
  final Set<String> _dismissedAlertIds = {};
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
  int _consecutiveCloudFailures = 0;
  final Map<String, int> _deviceMissedPolls = {};
  String? _activeDeviceId;
  String? _activeDisplayName;
  String? _activeSerialNumber;

  StreamSubscription<SSEEventEnvelope>? _sseSubscription;

  bool _isCloudReachable = true;
  bool _isLocalMode = false;
  bool _hasPendingCloudUpload = DeviceStorageService.hasPendingCloudUpload;
  SyncMode _syncMode = DeviceStorageService.syncMode == 'auto' ? SyncMode.auto : SyncMode.manual;
  ConnectionRoutingMode _routingMode = DeviceStorageService.connectionRoutingMode == 'localOnly'
      ? ConnectionRoutingMode.localOnly
      : DeviceStorageService.connectionRoutingMode == 'cloudOnly'
          ? ConnectionRoutingMode.cloudOnly
          : ConnectionRoutingMode.auto;
  DateTime? _lastCloudSyncTime = DeviceStorageService.lastCloudSyncTime;
  final List<SpaceAlertItem> _activityAlerts = [];
  final Map<String, DateTime> _lastCommandTimestamps = {};

  final List<Map<String, dynamic>> _spaces = [
    {'id': 'home_default', 'name': 'My Home', 'icon': 'home'},
  ];
  String _activeSpaceId = 'home_default';
  String _activeSpaceName = 'My Home';
  String _activeHomeRole = 'OWNER';
  String? _lanMatchedSpaceId;

  final Map<String, List<ConnectedDeviceSummary>> _spaceDevicesCache = {};
  List<GroupControlItem> _groupControls = [];
  List<String> _favouriteControlIds = [];

  List<Map<String, dynamic>> get spaces => List.unmodifiable(_spaces);
  String get activeSpaceId => _activeSpaceId;
  String get activeSpaceName => _activeSpaceName;
  String get activeHomeRole => _activeHomeRole;
  bool get isHomeAdmin =>
      _activeHomeRole.toUpperCase() == 'OWNER' ||
      _activeHomeRole.toUpperCase() == 'ADMIN' ||
      _activeHomeRole.toUpperCase() == 'SYSTEM_ADMIN';
  String? get lanMatchedSpaceId => _lanMatchedSpaceId;
  bool get isCurrentSpaceOnLocalLan =>
      _lanMatchedSpaceId == null || _lanMatchedSpaceId == _activeSpaceId;

  bool isPrimarySpaceId(String spaceId) {
    if (spaceId == 'home_default' || spaceId == 'local-home' || spaceId.isEmpty) return true;
    final primaryId = _spaces.isNotEmpty ? (_spaces.first['id'] as String) : 'home_default';
    if (spaceId == primaryId) return true;
    return false;
  }

  List<GroupControlItem> get groupControls => List.unmodifiable(_groupControls);
  List<String> get favouriteControlIds => List.unmodifiable(_favouriteControlIds);

  List<ConnectedDeviceSummary> _deduplicateDevices(List<ConnectedDeviceSummary> list) {
    if (list.length <= 1) return List<ConnectedDeviceSummary>.from(list);
    final Map<String, ConnectedDeviceSummary> unique = {};
    for (final d in list) {
      final key = d.id.trim();
      if (key.isEmpty) continue;
      if (!unique.containsKey(key)) {
        unique[key] = d;
      } else {
        final existing = unique[key]!;
        final bestName = (!existing.name.startsWith('Unknown') && existing.name.isNotEmpty) ? existing.name : d.name;
        final bestRoom = (existing.roomName != 'Home' && existing.roomName != 'Unassigned' && existing.roomName.isNotEmpty)
            ? existing.roomName
            : d.roomName;
        final bestModel = (existing.model.isNotEmpty && !existing.model.startsWith('Unknown'))
            ? existing.model
            : d.model;
        unique[key] = existing.copyWith(
          name: bestName,
          model: bestModel,
          roomName: bestRoom,
          online: existing.online || d.online,
        );
      }
    }
    return unique.values.toList();
  }

  List<ConnectedDeviceSummary> get devices => List.unmodifiable(_devices);
  bool get isLocalMode {
    if (_routingMode == ConnectionRoutingMode.localOnly) return true;
    if (_routingMode == ConnectionRoutingMode.cloudOnly) return false;
    return _isLocalMode && isCurrentSpaceOnLocalLan;
  }
  bool get isCloudReachable => _isCloudReachable;
  AuthoritativeHomeConnectionState get authoritativeConnectionState {
    final effectiveHomeId = (_activeHomeId != null && _activeHomeId!.isNotEmpty)
        ? _activeHomeId
        : (_activeSpaceId.isNotEmpty ? _activeSpaceId : DeviceStorageService.cachedActiveHomeId);
    final hasHome = (effectiveHomeId != null && effectiveHomeId.isNotEmpty) || _spaces.isNotEmpty;
    final effectiveDevices = _devices.isNotEmpty ? _devices : DeviceStorageService.cachedDevices;
    final onlineCount = effectiveDevices.where((d) => d.online == true || LocalLanDeviceService.instance.isDeviceReachableOnLan(d.id)).length;

    final isCloudActive = _isCloudReachable &&
        _connectionState != HomeConnectionState.offline &&
        _connectionState != HomeConnectionState.notConfigured;

    return AuthoritativeHomeConnectionState.resolve(
      isCloudReachable: isCloudActive,
      isLocalMode: isLocalMode,
      onlineDeviceCount: onlineCount,
      totalDeviceCount: effectiveDevices.length,
      hasHome: hasHome,
    );
  }
  bool get hasPendingCloudUpload => _hasPendingCloudUpload || ChangeTrackingService.instance.hasPendingChanges;
  SyncMode get syncMode => _syncMode;
  ConnectionRoutingMode get routingMode => _routingMode;
  DateTime? get lastCloudSyncTime => _lastCloudSyncTime;
  List<SpaceAlertItem> get activityAlerts => List.unmodifiable(_activityAlerts);
  bool get livingRoomLightOn => _livingRoomLightOn;
  bool get alertAcknowledged => _alertAcknowledged;
  bool get lightCommandPending => _lightCommandPending;
  bool get mistingCommandPending => _mistingCommandPending;
  bool get cloudEnabled => _cloudEnabled;
  ActuatorConfidence get lightConfidence => _lightConfidence;
  String? get activeHomeId => _activeHomeId;
  String? get activeDeviceId => _activeDeviceId ?? (_devices.isNotEmpty ? _devices.first.id : null);
  HomeConnectionState get connectionState => _connectionState;
  String? get connectionMessage => _connectionMessage;
  ConnectedDeviceSummary? get connectedDeviceSummary => _connectedDeviceSummary;
  List<String> get selectedQuickControlIds => List.unmodifiable(_selectedQuickControlIds);
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get awayMode => _awayMode;

  Future<void> toggleAwayMode(bool enable) async {
    _awayMode = enable;
    notifyListeners();
    if (enable) {
      for (final dev in _devices) {
        for (int ch = 1; ch <= 4; ch++) {
          if (getDeviceChannelPower(dev.id, ch)) {
            await setDeviceChannelPower(
              deviceId: dev.id,
              channelIndex: ch,
              value: false,
            );
          }
        }
      }
    }
  }

  UpcomingRoutineSortMode _upcomingRoutineSortMode = UpcomingRoutineSortMode.currentSpaceFirst;
  UpcomingRoutineSortMode get upcomingRoutineSortMode => _upcomingRoutineSortMode;

  void setUpcomingRoutineSortMode(UpcomingRoutineSortMode mode) {
    if (_upcomingRoutineSortMode != mode) {
      _upcomingRoutineSortMode = mode;
      refreshUpcomingRoutines();
    }
  }

  final List<UpcomingRoutineItem> _routines = [];

  List<UpcomingRoutineItem> get upcomingRoutinesAcrossSpaces =>
      List.unmodifiable(_routines);

  List<UpcomingRoutineItem> get upcomingRoutines =>
      List.unmodifiable(_routines);

  Future<void> refreshUpcomingRoutines() async {
    try {
      final repo = const PreviewRoutineRepository();
      final allRoutines = (await repo.getRoutines())
          .where((r) => !DeviceStorageService.isRoutineDeleted(r.id, routineName: r.name))
          .toList();

      final List<UpcomingRoutineItem> items = [];

      for (final r in allRoutines) {
        String spaceId = _activeSpaceId;
        String spaceName = _activeSpaceName;
        String spaceIcon = 'home';
        String? roomName;
        String? channelLabel;

        final involvedDevIds = <String>{
          ...r.involvedDevices.map((d) => d.id),
          ...r.actions.map((a) => a.deviceId),
        };

        if (r.involvedDevices.isNotEmpty) {
          final firstDev = r.involvedDevices.first;
          if (firstDev.room.isNotEmpty) {
            roomName = firstDev.room;
          }
        }
        if (r.actions.isNotEmpty) {
          final firstAction = r.actions.first;
          channelLabel = 'CH${firstAction.channelIndex}';
        }

        // Check active space devices
        if (involvedDevIds.any((id) => _devices.any((d) => d.id == id))) {
          spaceId = _activeSpaceId;
          spaceName = _activeSpaceName;
          spaceIcon = _spaces.firstWhere((s) => s['id'] == _activeSpaceId, orElse: () => {'icon': 'home'})['icon'] as String? ?? 'home';
        } else {
          // Check cached spaces
          for (final entry in _spaceDevicesCache.entries) {
            final spId = entry.key;
            final spDevices = entry.value;
            if (involvedDevIds.any((id) => spDevices.any((d) => d.id == id))) {
              spaceId = spId;
              final spInfo = _spaces.firstWhere((s) => s['id'] == spId, orElse: () => {'name': 'Space', 'icon': 'business'});
              spaceName = spInfo['name'] as String? ?? 'Space';
              spaceIcon = spInfo['icon'] as String? ?? 'business';
              break;
            }
          }
        }

        final isCurrentSpace = (spaceId == _activeSpaceId);
        final nextExec = _computeNextExecutionTime(r);
        final timeLabel = _formatUpcomingTimeLabel(nextExec, r);

        items.add(
          UpcomingRoutineItem(
            id: r.id,
            spaceId: spaceId,
            spaceName: spaceName,
            spaceIcon: spaceIcon,
            title: r.name,
            timeLabel: timeLabel,
            iconKey: r.icon,
            isEnabled: r.enabled,
            nextExecutionTime: nextExec,
            roomName: roomName,
            channelLabel: channelLabel,
            isCurrentSpace: isCurrentSpace,
          ),
        );
      }

      List<UpcomingRoutineItem> sorted;
      switch (_upcomingRoutineSortMode) {
        case UpcomingRoutineSortMode.currentSpaceOnly:
          sorted = items.where((it) => it.isCurrentSpace).toList()
            ..sort((a, b) => _compareExecutionTime(a.nextExecutionTime, b.nextExecutionTime));
          break;

        case UpcomingRoutineSortMode.currentSpaceFirst:
          final current = items.where((it) => it.isCurrentSpace).toList()
            ..sort((a, b) => _compareExecutionTime(a.nextExecutionTime, b.nextExecutionTime));
          final others = items.where((it) => !it.isCurrentSpace).toList()
            ..sort((a, b) => _compareExecutionTime(a.nextExecutionTime, b.nextExecutionTime));
          sorted = [...current, ...others];
          break;

        case UpcomingRoutineSortMode.nearestTimeFirst:
          sorted = List.from(items)
            ..sort((a, b) => _compareExecutionTime(a.nextExecutionTime, b.nextExecutionTime));
          break;
      }

      _routines.clear();
      _routines.addAll(sorted);
      notifyListeners();
    } catch (e) {
      debugPrint('[ROUTINE] refreshUpcomingRoutines error: $e');
    }
  }

  int _compareExecutionTime(DateTime? a, DateTime? b) {
    if (a == null && b == null) return 0;
    if (a == null) return 1;
    if (b == null) return -1;
    return a.compareTo(b);
  }

  DateTime? _computeNextExecutionTime(Routine routine) {
    final now = DateTime.now();
    final trig = routine.trigger;
    final label = trig.detail.isNotEmpty ? trig.detail : (trig.timeOfDay ?? routine.schedule.label);

    final timeRegex = RegExp(r'(\d{1,2}):(\d{2})\s*(AM|PM)?', caseSensitive: false);
    final match = timeRegex.firstMatch(label);
    if (match == null) return null;

    int h = int.parse(match.group(1)!);
    final m = int.parse(match.group(2)!);
    final ampm = match.group(3)?.toUpperCase();
    if (ampm == 'PM' && h < 12) h += 12;
    if (ampm == 'AM' && h == 12) h = 0;

    final days = trig.days.isNotEmpty ? trig.days : routine.schedule.days;
    if (days.isNotEmpty) {
      const dayNames = ['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'];
      for (int offset = 0; offset < 7; offset++) {
        final candidateDate = now.add(Duration(days: offset));
        final candidateDayName = dayNames[candidateDate.weekday - 1];
        final dayMatches = days.any((d) => d.toLowerCase().startsWith(candidateDayName));
        if (!dayMatches) continue;

        final candidate = DateTime(candidateDate.year, candidateDate.month, candidateDate.day, h, m);
        if (candidate.isAfter(now)) {
          return candidate;
        }
      }
      for (int offset = 7; offset < 14; offset++) {
        final candidateDate = now.add(Duration(days: offset));
        final candidateDayName = dayNames[candidateDate.weekday - 1];
        final dayMatches = days.any((d) => d.toLowerCase().startsWith(candidateDayName));
        if (dayMatches) {
          return DateTime(candidateDate.year, candidateDate.month, candidateDate.day, h, m);
        }
      }
    }

    DateTime candidate = DateTime(now.year, now.month, now.day, h, m);
    if (candidate.isBefore(now)) {
      candidate = candidate.add(const Duration(days: 1));
    }
    return candidate;
  }

  String _formatUpcomingTimeLabel(DateTime? nextExec, Routine routine) {
    if (nextExec == null) {
      if (routine.trigger.detail.isNotEmpty) return routine.trigger.detail;
      if (routine.schedule.label.isNotEmpty) return routine.schedule.label;
      return 'Scheduled';
    }

    final now = DateTime.now();
    final diff = nextExec.difference(now);

    final hour = nextExec.hour;
    final minute = nextExec.minute.toString().padLeft(2, '0');
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
    final timeStr = '$displayHour:$minute $period';

    if (diff.inSeconds > 0 && diff.inMinutes < 60) {
      final mins = diff.inMinutes;
      if (mins <= 1) return 'In 1 min ($timeStr)';
      return 'In $mins mins ($timeStr)';
    }

    if (nextExec.year == now.year && nextExec.month == now.month && nextExec.day == now.day) {
      return 'Today, $timeStr';
    }

    final tomorrow = now.add(const Duration(days: 1));
    if (nextExec.year == tomorrow.year && nextExec.month == tomorrow.month && nextExec.day == tomorrow.day) {
      return 'Tomorrow, $timeStr';
    }

    const dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final dayStr = dayNames[nextExec.weekday - 1];
    return '$dayStr, $timeStr';
  }

  void toggleRoutine(String id, bool enabled) {
    // 1. Instant optimistic UI update in upcoming routines list (<16ms)
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
        nextExecutionTime: old.nextExecutionTime,
        roomName: old.roomName,
        channelLabel: old.channelLabel,
        isCurrentSpace: old.isCurrentSpace,
      );
      notifyListeners();
    }

    ChangeTrackingService.instance.recordChange(
      entityType: 'routine',
      entityId: id,
      field: 'enabled',
      oldValue: (!enabled).toString(),
      newValue: enabled.toString(),
      changeType: ChangeType.modified,
    );
    _markLocalChangesDirty();

    // 2. Persist in PreviewRoutineRepository and sync to edge / cloud non-blocking
    unawaited(() async {
      try {
        final repo = const PreviewRoutineRepository();
        if (enabled) {
          await repo.enableRoutine(id);
        } else {
          await repo.disableRoutine(id);
        }
      } catch (e) {
        debugPrint('[ROUTINE] toggleRoutine background error: $e');
      }
    }());
  }

  /// Cross-space aggregation: devices turned ON in other spaces (not current space).
  List<SpaceOnSummary> get devicesOnInOtherSpaces {
    final List<SpaceOnSummary> results = [];
    final activeDevIds = _devices.map((d) => d.id).toSet();

    for (final sp in _spaces) {
      final spId = sp['id'] as String;
      if (spId == _activeSpaceId) continue;
      final spName = sp['name'] as String;
      final spIcon = sp['icon'] as String? ?? 'business';

      final devList = _spaceDevicesCache[spId] ?? [];
      int onCount = 0;
      final List<String> onNames = [];

      for (final dev in devList) {
        // Must strictly not count active space devices in other spaces
        if (activeDevIds.contains(dev.id)) continue;
        if (!dev.online) continue;

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
  /// Cross-space aggregation: alerts across all spaces.
  List<SpaceAlertItem> get allSpacesAlerts {
    final List<SpaceAlertItem> alerts = [];
    final seenIds = <String>{};
    final deleted = DeviceStorageService.deletedNotificationIds;

    if (dashboard.alert != null &&
        !_alertAcknowledged &&
        !_dismissedAlertIds.contains('alert_dash_main') &&
        !deleted.contains('alert_dash_main')) {
      final item = SpaceAlertItem(
        id: 'alert_dash_main',
        spaceId: _activeSpaceId,
        spaceName: _activeSpaceName,
        title: dashboard.alert!.title,
        message: dashboard.alert!.safeDisplayMessage,
        severity: dashboard.alert!.severity,
        timestamp: DateTime.now(),
      );
      alerts.add(item);
      seenIds.add(item.id);
    }

    for (final act in _activityAlerts) {
      if (EventClassification.isRoutineControlOperation(
        title: act.title,
        message: act.message,
      )) {
        continue;
      }
      final notifId = 'alert_${act.id}';
      if (!_dismissedAlertIds.contains(act.id) &&
          !deleted.contains(act.id) &&
          !deleted.contains(notifId) &&
          seenIds.add(act.id)) {
        alerts.add(act);
      }
    }

    for (final sp in _spaces) {
      final spId = sp['id'] as String;
      final spName = sp['name'] as String;
      final devList = (spId == _activeSpaceId) ? _devices : (_spaceDevicesCache[spId] ?? []);
      for (final d in devList) {
        if (!d.online && _isCloudReachable) {
          final id = 'alert_off_${d.id}';
          if (!_dismissedAlertIds.contains(id) && !deleted.contains(id) && seenIds.add(id)) {
            alerts.add(
              SpaceAlertItem(
                id: id,
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
    }
    return alerts;
  }

  int get unreadNotificationCount {
    final deleted = DeviceStorageService.deletedNotificationIds;
    final read = DeviceStorageService.readNotificationIds;
    int count = 0;
    for (final a in allSpacesAlerts) {
      final notifId = 'alert_${a.id}';
      if (!deleted.contains(notifId) && !deleted.contains(a.id)) {
        if (!read.contains(notifId) && !read.contains(a.id)) {
          count++;
        }
      }
    }
    if (_isLocalMode && !deleted.contains('lan_active_notice') && !read.contains('lan_active_notice')) {
      count++;
    }
    return count;
  }

  void dismissAlert(String alertId) {
    _dismissedAlertIds.add(alertId);
    _activityAlerts.removeWhere((a) => a.id == alertId || 'alert_${a.id}' == alertId);
    DeviceStorageService.deleteNotificationId(alertId);
    if (alertId == 'alert_dash_main') {
      _alertAcknowledged = true;
    }
    notifyListeners();
  }

  void clearAllAlerts() {
    for (final a in allSpacesAlerts) {
      _dismissedAlertIds.add(a.id);
      DeviceStorageService.deleteNotificationId(a.id);
      DeviceStorageService.deleteNotificationId('alert_${a.id}');
    }
    _activityAlerts.clear();
    _alertAcknowledged = true;
    notifyListeners();
  }

  Future<void> selectSpace(String spaceId) async {
    final target = _spaces.firstWhere(
      (s) => s['id'] == spaceId,
      orElse: () => _spaces.first,
    );
    _activeSpaceId = target['id'] as String;
    _activeSpaceName = target['name'] as String;
    _isLoading = true;

    // Physical Presence Isolation:
    // When cloud is reachable, we are in CLOUD mode for all spaces.
    // When cloud is NOT reachable, LAN mode is ONLY available for the space where the phone
    // is physically connected to that space's local Wi-Fi router (_lanMatchedSpaceId).
    if (_isCloudReachable) {
      _isLocalMode = false;
    } else {
      _isLocalMode = (_lanMatchedSpaceId != null && _lanMatchedSpaceId == _activeSpaceId);
    }

    // Reset active space states completely before loading
    _devices = [];
    _connectedDeviceSummary = null;
    _activeDeviceId = null;
    _activeDisplayName = null;
    _activeSerialNumber = null;
    _customEmptyRooms.clear();
    _backendRooms.clear();
    _groupControls.clear();
    _favouriteControlIds.clear();
    _selectedQuickControlIds.clear();

    final primarySpaceId = _spaces.isNotEmpty ? (_spaces.first['id'] as String) : 'home_default';
    final primaryDevices = await _storageService.loadDevicesForSpace(primarySpaceId);
    final primaryDevIds = primaryDevices.map((d) => d.id).toSet();

    if (!isPrimarySpaceId(_activeSpaceId)) {
      // Secondary space (e.g. Office): strictly exclude primary home devices
      final rawSpaceDevs = await _storageService.loadDevicesForSpace(_activeSpaceId);
      final cleanSpaceDevs = _deduplicateDevices(rawSpaceDevs.where((d) => !primaryDevIds.contains(d.id)).toList());
      if (cleanSpaceDevs.length != rawSpaceDevs.length) {
        await _storageService.saveDevicesForSpace(_activeSpaceId, cleanSpaceDevs);
      }
      _spaceDevicesCache[_activeSpaceId] = cleanSpaceDevs;
      if (cleanSpaceDevs.isNotEmpty) {
        _devices = cleanSpaceDevs.map((d) {
          final isLanActive = (_isLocalMode || _routingMode != ConnectionRoutingMode.cloudOnly) &&
              LocalLanDeviceService.instance.isDeviceReachableOnLan(d.id);
          final isOnline = _isLocalMode ? isLanActive : (isLanActive || d.online);
          final signal = isLanActive
              ? 'Local Wi-Fi'
              : (isOnline ? (d.signalLabel != 'Offline' ? d.signalLabel : 'Cloud') : 'Offline');
          return d.copyWith(
            online: isOnline,
            signalLabel: signal,
          );
        }).toList();
        _connectedDeviceSummary = _devices.first;
        _activeDeviceId = _devices.first.id;
        _activeDisplayName = _devices.first.name;
        _activeSerialNumber = _devices.first.model;
        _connectionState = _devices.any((d) => d.online)
            ? HomeConnectionState.connected
            : HomeConnectionState.offline;
        _connectionMessage = _devices.any((d) => d.online)
            ? '${_devices.first.name} is connected.'
            : '${_devices.first.name} is offline.';
      } else {
        _connectionState = HomeConnectionState.notConfigured;
        _connectionMessage = 'No devices in $_activeSpaceName yet.';
      }
    } else {
      // Primary space (My Home)
      final cached = _spaceDevicesCache[_activeSpaceId] ?? primaryDevices;
      if (cached.isNotEmpty) {
        final deduped = _deduplicateDevices(cached);
        _devices = deduped.map((d) {
          final isLanActive = (_isLocalMode || _routingMode != ConnectionRoutingMode.cloudOnly) &&
              LocalLanDeviceService.instance.isDeviceReachableOnLan(d.id);
          final isOnline = _isLocalMode ? isLanActive : (isLanActive || d.online);
          final signal = isLanActive
              ? 'Local Wi-Fi'
              : (isOnline ? (d.signalLabel != 'Offline' ? d.signalLabel : 'Cloud') : 'Offline');
          return d.copyWith(
            online: isOnline,
            signalLabel: signal,
          );
        }).toList();
        _spaceDevicesCache[_activeSpaceId] = List.from(_devices);
        _connectedDeviceSummary = _devices.first;
        _activeDeviceId = _devices.first.id;
        _activeDisplayName = _devices.first.name;
        _activeSerialNumber = _devices.first.model;
        _connectionState = _devices.any((d) => d.online)
            ? HomeConnectionState.connected
            : HomeConnectionState.offline;
        _connectionMessage = _devices.any((d) => d.online)
            ? '${_devices.first.name} is connected via Local Wi-Fi.'
            : '${_devices.first.name} is offline. Cloud backend disconnected.';
      } else {
        _connectionState = HomeConnectionState.notConfigured;
        _connectionMessage = 'No devices in $_activeSpaceName yet.';
      }
    }

    // Immediate UI notification to show space switch + dimmer overlay
    notifyListeners();

    setActiveHomeId(_activeSpaceId);
    _realtimeService?.connect(_activeSpaceId);
    await loadRooms();
    await loadHomeData(homeId: _activeSpaceId);
    await _loadCustomizationsForActiveSpace();
    await refreshUpcomingRoutines();
    _isLoading = false;
    notifyListeners();
  }

  Future<void> _loadCustomizationsForActiveSpace() async {
    final rawGroups = await _storageService.loadGroupControlsForSpace(_activeSpaceId);
    _groupControls = rawGroups.map((g) => GroupControlItem.fromJson(g)).toList();
    _favouriteControlIds = await _storageService.loadFavouritesForSpace(_activeSpaceId);
    _selectedQuickControlIds = await _storageService.loadQuickControlsForSpace(_activeSpaceId);

    // Prune stale groups and favourites only if devices have loaded for this space
    final validDeviceIds = _devices.map((d) => d.id).toSet();
    if (validDeviceIds.isNotEmpty) {
      _groupControls.removeWhere((g) => g.targetControlIds.every((id) {
        final devId = id.contains('_') ? id.split('_').first : id;
        return !validDeviceIds.contains(devId);
      }));
      _favouriteControlIds.removeWhere((id) {
        final devId = id.contains('_') ? id.split('_').first : id;
        return !validDeviceIds.contains(devId);
      });
    }

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
    await ChangeTrackingService.instance.recordChange(
      entityType: 'space',
      entityId: id,
      field: 'name',
      oldValue: null,
      newValue: cleanName,
      changeType: ChangeType.created,
    );
    _markLocalChangesDirty();
    await selectSpace(id);
  }

  Future<void> updateSpace(String spaceId, String newName, {String? icon}) async {
    final cleanName = newName.trim();
    if (cleanName.isEmpty) return;
    final idx = _spaces.indexWhere((s) => s['id'] == spaceId);
    if (idx >= 0) {
      final oldName = _spaces[idx]['name'] as String?;
      _spaces[idx]['name'] = cleanName;
      if (icon != null) _spaces[idx]['icon'] = icon;
      await _storageService.saveSpaces(_spaces);
      await ChangeTrackingService.instance.recordChange(
        entityType: 'space',
        entityId: spaceId,
        field: 'name',
        oldValue: oldName,
        newValue: cleanName,
        changeType: ChangeType.modified,
      );
      _markLocalChangesDirty();
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

    final oldName = _spaces[deletedIdx]['name']?.toString() ?? spaceId;
    _spaces.removeWhere((s) => s['id'] == spaceId);
    _spaceDevicesCache.remove(spaceId);
    await _storageService.saveSpaces(_spaces);
    await _storageService.addDeletedSpaceId(spaceId);
    await ChangeTrackingService.instance.recordChange(
      entityType: 'space',
      entityId: spaceId,
      field: 'name',
      oldValue: oldName,
      newValue: null,
      changeType: ChangeType.deleted,
    );
    _markLocalChangesDirty();

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
    await _storageService.saveQuickControls(_selectedQuickControlIds);
    await ChangeTrackingService.instance.recordChange(
      entityType: 'quick_controls',
      entityId: _activeSpaceId,
      field: 'quickControls',
      oldValue: null,
      newValue: '${ids.length} actions selected',
      changeType: ChangeType.modified,
    );
    _markLocalChangesDirty();
    notifyListeners();
  }

  Future<void> saveFavouritesForSpace(String spaceId, List<String> favouriteIds) async {
    _favouriteControlIds = List.from(favouriteIds);
    await _storageService.saveFavouritesForSpace(spaceId, _favouriteControlIds);
    await ChangeTrackingService.instance.recordChange(
      entityType: 'favourites',
      entityId: spaceId,
      field: 'favourites',
      oldValue: null,
      newValue: '${favouriteIds.length} items',
      changeType: ChangeType.modified,
    );
    _markLocalChangesDirty();
    notifyListeners();
  }

  Future<void> toggleFavourite(String controlId) async {
    final wasFav = _favouriteControlIds.contains(controlId);
    if (wasFav) {
      _favouriteControlIds.remove(controlId);
    } else {
      _favouriteControlIds.add(controlId);
    }
    await _storageService.saveFavouritesForSpace(_activeSpaceId, _favouriteControlIds);
    await ChangeTrackingService.instance.recordChange(
      entityType: 'favourites',
      entityId: controlId,
      field: 'favourite',
      oldValue: wasFav.toString(),
      newValue: (!wasFav).toString(),
      changeType: ChangeType.modified,
    );
    _markLocalChangesDirty();
    notifyListeners();
  }

  /// Commands are available when authenticated via cloud with active connection, or actively verified on local LAN, or using FakeHomeRepository in tests.
  bool get hardwareControlsAvailable {
    if (_repository is FakeHomeRepository) return true;
    final hasActiveCloud = _cloudEnabled && _isCloudReachable;
    final hasActiveLan = _isLocalMode && _devices.any((d) => d.online);
    return (hasActiveCloud || hasActiveLan) && _devices.any((d) => d.online);
  }
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

  /// Syncs spaces with backend homes list, enforcing strict tenant isolation.
  Future<void> syncBackendHomes(List<dynamic> backendHomes) async {
    if (backendHomes.isEmpty) return;
    bool modified = false;

    final backendHomeIds = backendHomes
        .map((bh) => (bh is Map ? bh['id'] : bh.id).toString())
        .toSet();

    final primary = backendHomes.first;
    final primaryId = (primary is Map ? primary['id'] : primary.id).toString();
    final primaryName = (primary is Map ? (primary['name'] ?? '') : primary.name)
        .toString()
        .trim();

    for (final bh in backendHomes) {
      final bId = (bh is Map ? bh['id'] : bh.id).toString();
      if (bId == _activeSpaceId || bId == primaryId) {
        final r = (bh is Map ? (bh['role'] ?? bh['membership_role']) : bh.role)?.toString() ?? 'OWNER';
        _activeHomeRole = r.toUpperCase();
        break;
      }
    }

    // Link primary backend home ID and name to default space
    if (_spaces.isNotEmpty &&
        (_spaces.first['id'] == 'home_default' ||
            _spaces.first['id'] == 'local-home' ||
            !backendHomeIds.contains(_spaces.first['id']))) {
      _spaces.first['id'] = primaryId;
      if (primaryName.isNotEmpty) {
        _spaces.first['name'] = primaryName;
      }
      if (_activeSpaceId == 'home_default' ||
          _activeSpaceId == 'local-home' ||
          !backendHomeIds.contains(_activeSpaceId)) {
        _activeSpaceId = primaryId;
        if (primaryName.isNotEmpty) {
          _activeSpaceName = primaryName;
        }
      }
      modified = true;
    } else if (_spaces.isNotEmpty && _spaces.first['id'] == primaryId) {
      if (primaryName.isNotEmpty && _spaces.first['name'] != primaryName) {
        _spaces.first['name'] = primaryName;
        if (_activeSpaceId == primaryId) {
          _activeSpaceName = primaryName;
        }
        modified = true;
      }
    }

    // Match backend IDs for existing spaces by matching names so cloud calls work
    final deletedIds = await _storageService.loadDeletedSpaceIds();
    for (final s in _spaces) {
      for (final bh in backendHomes) {
        final bId = (bh is Map ? bh['id'] : bh.id).toString();
        final bName = (bh is Map ? (bh['name'] ?? '') : bh.name)
            .toString()
            .toLowerCase();
        if (s['name'].toString().toLowerCase() == bName &&
            s['id'] != bId &&
            !deletedIds.contains(bId)) {
          final oldId = s['id'] as String;
          s['id'] = bId;
          if (_activeSpaceId == oldId) {
            _activeSpaceId = bId;
          }
          modified = true;
        }
      }
    }

    // Add any backend spaces belonging to this user that are not present locally
    for (final bh in backendHomes) {
      final bId = (bh is Map ? bh['id'] : bh.id).toString();
      final bName = (bh is Map ? (bh['name'] ?? '') : bh.name).toString().trim();
      if (bId.isNotEmpty &&
          !_spaces.any((s) => s['id'] == bId) &&
          !deletedIds.contains(bId)) {
        _spaces.add({
          'id': bId,
          'name': bName.isNotEmpty ? bName : 'My Home',
          'icon': 'home',
        });
        modified = true;
      }
    }

    // STRICT USER ISOLATION: Remove foreign spaces not belonging to the authenticated user!
    _spaces.removeWhere((s) {
      final sId = s['id'].toString();
      if (sId != 'home_default' &&
          sId != 'local-home' &&
          !backendHomeIds.contains(sId)) {
        modified = true;
        return true;
      }
      return deletedIds.contains(sId);
    });

    if (!_spaces.any((s) => s['id'] == _activeSpaceId)) {
      _activeSpaceId = _spaces.isNotEmpty ? (_spaces.first['id'] as String) : primaryId;
      _activeSpaceName = _spaces.isNotEmpty ? (_spaces.first['name'] as String) : primaryName;
      modified = true;
    }

    _lanMatchedSpaceId ??= _spaces.first['id'] as String;

    if (modified) {
      await _storageService.saveSpaces(_spaces);
      notifyListeners();
    }
  }

  /// Loads persisted rooms from storage and repository for the active home.
  Future<void> loadRooms() async {
    try {
      _customEmptyRooms.clear();
      final savedRooms = await _storageService.loadRoomsForSpace(_activeSpaceId);
      for (final r in savedRooms) {
        final name = r.trim();
        if (name.isNotEmpty && !_customEmptyRooms.any((existing) => existing.name.toLowerCase() == name.toLowerCase())) {
          _customEmptyRooms.add(
            Room(
              id: name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_'),
              name: name,
              iconKey: 'living',
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
      final rawRooms = await _repository.getRooms(homeId: _activeHomeId ?? _activeSpaceId);
      for (final r in rawRooms) {
        final name = (r['name'] ?? r['label'] ?? '').toString().trim();
        final id = (r['id'] ?? name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_')).toString();
        final iconKey = (r['iconKey'] ?? r['icon_key'] ?? 'living').toString();
        if (name.isNotEmpty && !_customEmptyRooms.any((existing) => existing.name.toLowerCase() == name.toLowerCase())) {
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
    _realtimeService = service;
    _sseSubscription?.cancel();
    _subscribeToRealtime(service);
  }

  /// Resets all session and cloud state upon logout or session invalidation.
  void resetSession() {
    _autoSyncTimer?.cancel();
    _cloudEnabled = false;
    _activeHomeId = null;
    _activeHomeRole = 'OWNER';
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
  Future<void> loadHomeData({String? homeId, bool isBackground = false}) async {
    final targetHomeId = homeId ?? _activeHomeId ?? _activeSpaceId;
    if (!isBackground && _devices.isEmpty) {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();
    }

    // Startup Priority in Auto Mode: launch concurrent LAN probe alongside Cloud fetch
    if (_routingMode == ConnectionRoutingMode.auto && !_isLocalMode) {
      unawaited(probeLanAndPromote());
    }

    try {
      final results = await Future.wait([
        _repository.getDevices(homeId: targetHomeId).timeout(const Duration(milliseconds: 5000)),
        _repository.getRooms(homeId: targetHomeId).timeout(const Duration(milliseconds: 5000)),
      ]);
      final rawSnapshotList = results[0] as List<DeviceSnapshot>;
      final rawDevices = rawSnapshotList.where((d) => !DeviceStorageService.isDeviceDeleted(d.id)).toList();
      final rawRooms = results[1] as List<Map<String, dynamic>>;

      if (_repository is CloudHomeRepository) {
        final repoHomeId = _repository.activeHomeId;
        if (repoHomeId != null && repoHomeId.isNotEmpty) {
          _activeHomeId = repoHomeId;
        }
        unawaited(() async {
          try {
            final cloudRepo = _repository;
            final cloudRoutines = await CloudRoutineRepository(cloudRepo.client).getRoutines();
            if (cloudRoutines.isNotEmpty) {
              await PreviewRoutineRepository.syncWithCloudRoutines(cloudRoutines);
              await refreshUpcomingRoutines();
            }
          } catch (_) {}
        }());
      }

      final deletedRooms = DeviceStorageService.deletedRooms;
      _backendRooms = rawRooms.where((r) {
        final roomName = (r['name'] ?? r['label'] ?? '').toString().trim();
        return roomName.isNotEmpty && !deletedRooms.contains(roomName);
      }).map((r) {
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

      final primarySpaceId = _spaces.isNotEmpty ? (_spaces.first['id'] as String) : 'home_default';
      final primaryDevices = await _storageService.loadDevicesForSpace(primarySpaceId);
      final primaryDevIds = primaryDevices.map((d) => d.id).toSet();

      final isPrimary = isPrimarySpaceId(targetHomeId);
      final allLocalDevices = await _storageService.loadDevicesForSpace(targetHomeId);
      final localDevices = (!isPrimary)
          ? allLocalDevices.where((d) => !DeviceStorageService.isDeviceDeleted(d.id) && !primaryDevIds.contains(d.id)).toList()
          : allLocalDevices.where((d) => !DeviceStorageService.isDeviceDeleted(d.id)).toList();
      final hasLocalOverride = localDevices.isNotEmpty &&
          (_hasPendingCloudUpload || rawDevices.isEmpty || _repository is FakeHomeRepository);

      if (hasLocalOverride) {
        final deduped = _deduplicateDevices(localDevices);
        _devices = deduped.map((d) {
          final isReachableLan = LocalLanDeviceService.instance.isDeviceReachableOnLan(d.id);
          final isLanActive = (_isLocalMode || _routingMode != ConnectionRoutingMode.cloudOnly) && isReachableLan;
          final isFakeRepo = _repository is FakeHomeRepository;
          final isDevOnline = isLanActive || (isFakeRepo ? d.online : false);
          return d.copyWith(
            online: isDevOnline,
            signalLabel: isDevOnline ? (isLanActive ? 'Local Wi-Fi' : 'Strong') : 'Offline',
          );
        }).toList();
        _connectedDeviceSummary = _devices.isNotEmpty ? _devices.first : null;
        _activeDeviceId = _devices.isNotEmpty ? _devices.first.id : '';
        _activeDisplayName = _devices.isNotEmpty ? _devices.first.name : '';
        _activeSerialNumber = _devices.isNotEmpty ? _devices.first.model : '';
        final anyOnline = _devices.any((d) => d.online);
        _connectionState = anyOnline
            ? HomeConnectionState.connected
            : HomeConnectionState.offline;
        _connectionMessage = anyOnline
            ? '${_devices.first.name} is connected and online.'
            : '${_devices.first.name} is offline. Cloud backend disconnected.';
        _spaceDevicesCache[targetHomeId] = List.from(_devices);
      } else if (rawDevices.isNotEmpty) {
        final mapped = rawDevices.map((d) {
          final isReachableLan = LocalLanDeviceService.instance.isDeviceReachableOnLan(d.id);
          final isLanActive = (_isLocalMode || _routingMode != ConnectionRoutingMode.cloudOnly) && isReachableLan;
          final isCloudOnline = (d.connection == DeviceConnection.online);
          final isOnline = _routingMode == ConnectionRoutingMode.localOnly
              ? isLanActive
              : (_routingMode == ConnectionRoutingMode.cloudOnly
                  ? isCloudOnline
                  : (isLanActive || isCloudOnline));
          final localMatch = localDevices.cast<ConnectedDeviceSummary?>().firstWhere(
            (ld) => ld?.id == d.id,
            orElse: () => null,
          );
          final backendName = d.name.trim();
          final localName = (localMatch?.name ?? '').trim();
          final finalName = (backendName.isNotEmpty && !backendName.startsWith('Unknown'))
              ? backendName
              : (localName.isNotEmpty ? localName : 'EH Smart Device');

          final backendRoom = d.roomName.trim();
          final localRoom = (localMatch?.roomName ?? '').trim();
          final finalRoom = (backendRoom.isNotEmpty && backendRoom != 'Home' && backendRoom != 'Unassigned')
              ? backendRoom
              : (localRoom.isNotEmpty && localRoom != 'Home' && localRoom != 'Unassigned'
                  ? localRoom
                  : (backendRoom.isNotEmpty && backendRoom != 'Home' ? backendRoom : 'Unassigned'));

          final resolvedModel = (d.productVariantId != null && d.productVariantId!.isNotEmpty)
              ? d.productVariantId!
              : (localMatch?.model ?? d.hardwareRevision);
          final normModel = MockProductCatalogRepository.normalizeVariantId(resolvedModel.isNotEmpty ? resolvedModel : finalName);

          return ConnectedDeviceSummary(
            id: d.id,
            name: finalName,
            model: normModel.isNotEmpty ? normModel : resolvedModel,
            firmware: d.firmwareVersion,
            connectedVia: isLanActive ? 'Wi-Fi (Local)' : 'Wi-Fi (2.4 GHz)',
            signalLabel: isLanActive ? 'Local Wi-Fi' : (isOnline ? 'Strong' : 'Offline'),
            roomName: finalRoom,
            online: isOnline,
          );
        }).toList();
        _devices = _deduplicateDevices(mapped);

        _connectedDeviceSummary = _devices.isNotEmpty ? _devices.first : null;
        _activeDeviceId = _devices.isNotEmpty ? _devices.first.id : '';
        _activeDisplayName = _devices.isNotEmpty ? _devices.first.name : '';
        _activeSerialNumber = _devices.isNotEmpty ? _devices.first.model : '';
        _connectionState = _devices.any((d) => d.online)
            ? HomeConnectionState.connected
            : HomeConnectionState.offline;
        _connectionMessage = _devices.isNotEmpty
            ? '${_devices.first.name} is connected and ${_devices.first.online ? 'online' : 'offline'}.'
            : 'No devices connected.';

        for (final dev in _devices) {
          _storageService.saveDeviceForSpace(targetHomeId, dev);
          if (dev.roomName.trim().isNotEmpty && dev.roomName != 'Home' && !deletedRooms.contains(dev.roomName.trim())) {
            await _storageService.addRoomForSpace(targetHomeId, dev.roomName.trim());
          }
        }
        _spaceDevicesCache[targetHomeId] = List.from(_devices);

        // Ensure cloud rooms are stored in local rooms cache for this specific space (excluding deleted rooms)
        for (final r in rawRooms) {
          final rName = (r['name'] ?? r['label'] ?? '').toString().trim();
          if (rName.isNotEmpty && rName != 'Home' && !deletedRooms.contains(rName)) {
            await _storageService.addRoomForSpace(targetHomeId, rName);
          }
        }

        // Hydrate live channel states, custom channel labels & alert configs from backend snapshots
        for (final d in rawDevices) {
          final devChannels = _channelStates.putIfAbsent(d.id, () => {});
          final customLabels = <int, String>{};
          for (final ch in d.channels) {
            final chIdx = _parseChannelIndex(ch) ?? 1;
            final pwr = _parsePowerFromChannel(ch);
            if (pwr != null) {
              devChannels[chIdx] = pwr;
            }
            final customLabelStr = ch['customLabel']?.toString().trim();
            final fallback = ch['displayName'] ?? ch['label'] ?? ch['name'] ?? ch['title'];
            final fallbackLabel = fallback?.toString().trim();
            final labelToUse = (customLabelStr != null && customLabelStr.isNotEmpty)
                ? customLabelStr
                : ((fallbackLabel != null && fallbackLabel.isNotEmpty && !fallbackLabel.startsWith('Channel ') && !fallbackLabel.startsWith('Switch '))
                    ? fallbackLabel
                    : null);
            if (labelToUse != null) {
              customLabels[chIdx] = labelToUse;
            }
            final alertJson = ch['alertConfig'] ?? ch['config'] ?? ch['channelConfig'];
            if (alertJson is Map) {
              final alertCfg = ChannelAlertConfig.fromJson(Map<String, dynamic>.from(alertJson));
              DeviceStorageService.saveChannelAlertConfig(d.id, chIdx, alertCfg);
            }
          }
          if (d.channelLabels != null && d.channelLabels is Map) {
            d.channelLabels!.forEach((k, v) {
              final chIdx = int.tryParse(k.toString());
              if (chIdx != null && v != null && v.toString().trim().isNotEmpty) {
                customLabels[chIdx] = v.toString().trim();
              }
            });
          }
          if (customLabels.isNotEmpty) {
            DeviceStorageService.setChannelLabelsForDevice(d.id, customLabels);
            for (final localDev in localDevices) {
              if (localDev.id == d.id || localDev.id.toLowerCase() == d.id.toLowerCase()) {
                DeviceStorageService.setChannelLabelsForDevice(localDev.id, customLabels);
              }
            }
          }
          if (d.channelConfigs != null) {
            d.channelConfigs!.forEach((chKey, cfgJson) {
              final chIdx = int.tryParse(chKey.toString());
              if (chIdx != null && cfgJson is Map) {
                final alertCfg = ChannelAlertConfig.fromJson(Map<String, dynamic>.from(cfgJson));
                DeviceStorageService.saveChannelAlertConfig(d.id, chIdx, alertCfg);
              }
            });
          }
        }

        // Auto-populate quick controls if empty so dashboard is immediately usable
        if (_selectedQuickControlIds.isEmpty && _devices.isNotEmpty) {
          final initialQuickIds = <String>[];
          for (final dev in _devices) {
            final canonical = MockProductCatalogRepository.resolveCanonicalProductVariant(
              variantId: dev.model,
              deviceName: dev.name,
            );
            final nameLower = dev.name.toLowerCase();
            final is4X = nameLower.contains('4x') || canonical.contains('4x');
            final is3X = nameLower.contains('3x') || canonical.contains('3x');
            final is2X = nameLower.contains('2x') || canonical.contains('2x');
            final is1X = nameLower.contains('1x') || canonical.contains('1x');
            final count = is4X ? 4 : (is3X ? 3 : (is2X ? 2 : (is1X ? 1 : 2)));
            for (int ch = 1; ch <= count; ch++) {
              initialQuickIds.add('${dev.id}_ch$ch');
            }
          }
          _selectedQuickControlIds = initialQuickIds;
          await _storageService.saveQuickControlsForSpace(targetHomeId, initialQuickIds);
          await _storageService.saveQuickControls(initialQuickIds);
        }

        final livingRoomDev = _devices.cast<ConnectedDeviceSummary?>().firstWhere(
          (d) => d != null && d.roomName.toLowerCase().contains('living'),
          orElse: () => null,
        );
        if (livingRoomDev != null && _channelStates[livingRoomDev.id]?.containsKey(1) == true) {
          _livingRoomLightOn = _channelStates[livingRoomDev.id]![1]!;
        } else {
          _livingRoomLightOn = false;
        }
      } else {
        final isPrimary = isPrimarySpaceId(targetHomeId);
        final localDevices = await _storageService.loadDevicesForSpace(targetHomeId);
        final filteredLocal = (!isPrimary)
            ? localDevices.where((d) => !primaryDevIds.contains(d.id)).toList()
            : localDevices;
        if (filteredLocal.isNotEmpty) {
          final deduped = _deduplicateDevices(filteredLocal);
          _devices = deduped.map((d) {
            final isReachableLan = LocalLanDeviceService.instance.isDeviceReachableOnLan(d.id);
            final isLanActive = (_isLocalMode || _routingMode != ConnectionRoutingMode.cloudOnly) && isReachableLan;
            return d.copyWith(
              online: isLanActive,
              signalLabel: isLanActive ? 'Local Wi-Fi' : 'Offline',
            );
          }).toList();
          _connectedDeviceSummary = _devices.first;
          _activeDeviceId = _devices.first.id;
          _activeDisplayName = _devices.first.name;
          _activeSerialNumber = _devices.first.model;
          final anyOnline = _devices.any((d) => d.online);
          _connectionState = anyOnline ? HomeConnectionState.connected : HomeConnectionState.offline;
          _connectionMessage = anyOnline
              ? '${_devices.first.name} is connected via Local Wi-Fi.'
              : '${_devices.first.name} is offline. Cloud backend disconnected.';
          _spaceDevicesCache[targetHomeId] = List.from(_devices);

          // Auto-claim these devices to the cloud home so backend DB is populated
          if (_repository is CloudHomeRepository && targetHomeId != 'home_default' && targetHomeId != 'local-home') {
            for (final ld in filteredLocal) {
              _repository.claimDevice(
                deviceId: ld.id,
                homeId: targetHomeId,
                customName: ld.name,
              ).catchError((_) {});
            }
          }
        } else {
          _devices = [];
          _connectedDeviceSummary = null;
          _activeDeviceId = null;
          _activeDisplayName = null;
          _activeSerialNumber = null;
          _connectionState = HomeConnectionState.notConfigured;
          _connectionMessage = 'No devices configured for $_activeSpaceName yet.';
          _spaceDevicesCache[targetHomeId] = List.from(_devices);
        }
      }
      if (_routingMode == ConnectionRoutingMode.localOnly) {
        _isCloudReachable = false;
        _isLocalMode = true;
      } else if (_routingMode == ConnectionRoutingMode.cloudOnly) {
        _isCloudReachable = true;
        _isLocalMode = false;
      } else {
        // Auto Mode: check if any local device is already confirmed reachable on LAN
        _isCloudReachable = true;
        bool anyLanOnline = false;
        for (final d in _devices) {
          if (LocalLanDeviceService.instance.isDeviceReachableOnLan(d.id)) {
            anyLanOnline = true;
            break;
          }
        }
        _isLocalMode = anyLanOnline;
        if (_isLocalMode) {
          _connectionMessage = 'Local Wi-Fi Mode (Direct LAN)';
        }
      }
      // Hydrate device cache for all other spaces so cross-space summary is accurate
      for (final sp in _spaces) {
        final spId = sp['id'] as String;
        if (spId != targetHomeId) {
          final spDevs = await _storageService.loadDevicesForSpace(spId);
          final filtered = (spId != primarySpaceId)
              ? spDevs.where((d) => !primaryDevIds.contains(d.id)).toList()
              : spDevs;
          _spaceDevicesCache[spId] = filtered;
        }
      }

      if (_routingMode != ConnectionRoutingMode.cloudOnly) {
        await _probeKnownLanDevicesFast();
      }

      _isLoading = false;
      _startAutoSyncTimer();
      _startAutoModeLanPromotionTimer();
      if (_routingMode == ConnectionRoutingMode.auto && !_isLocalMode) {
        unawaited(probeLanAndPromote());
      } else if (_routingMode != ConnectionRoutingMode.cloudOnly) {
        _pollLanStateQuietly();
      }
      notifyListeners();
    } catch (e) {
      _isCloudReachable = false;
      _cloudDeviceConnection = DeviceConnection.offline;
      final isPrimary = isPrimarySpaceId(targetHomeId);
      final primarySpaceId = _spaces.isNotEmpty ? (_spaces.first['id'] as String) : 'home_default';
      final primaryDevices = await _storageService.loadDevicesForSpace(primarySpaceId);
      final primaryDevIds = primaryDevices.map((d) => d.id).toSet();

      final localDevices = await _storageService.loadDevicesForSpace(targetHomeId);
      final filteredLocal = (!isPrimary)
          ? localDevices.where((d) => !primaryDevIds.contains(d.id)).toList()
          : localDevices;
      if (filteredLocal.isNotEmpty) {
        final deduped = _deduplicateDevices(filteredLocal);
        _devices = deduped.map((d) {
          final isReachableLan = LocalLanDeviceService.instance.isDeviceReachableOnLan(d.id);
          final isLanActive = (_isLocalMode || _routingMode != ConnectionRoutingMode.cloudOnly) && isReachableLan;
          return ConnectedDeviceSummary(
            id: d.id,
            name: d.name,
            model: d.model,
            firmware: d.firmware,
            connectedVia: isLanActive ? 'Wi-Fi (Local)' : 'Offline',
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
        _isLocalMode = hasOnline;
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

      // Hydrate rooms from local storage so rooms are never empty on offline startup
      if (_backendRooms.isEmpty) {
        final cachedRoomNames = await _storageService.loadRoomsForSpace(targetHomeId);
        final deletedRooms = DeviceStorageService.deletedRooms;
        _backendRooms = cachedRoomNames.where((r) => !deletedRooms.contains(r)).map((r) {
          return Room(
            id: r.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_'),
            name: r,
            iconKey: 'living',
            deviceCount: 0,
            connectivity: ConnectivityCause.deviceOffline,
            telemetryFreshness: TelemetryFreshness.unknown,
            summary: 'Offline · Disconnected',
            status: RoomStatus.unavailable,
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
      }

      if (_routingMode != ConnectionRoutingMode.cloudOnly) {
        await _probeKnownLanDevicesFast();
      }

      _isLoading = false;
      _errorMessage = e.toString().replaceFirst('ApiException: ', '');
      _startAutoSyncTimer();
      _startAutoModeLanPromotionTimer();
      if (_routingMode == ConnectionRoutingMode.auto && !_isLocalMode) {
        unawaited(probeLanAndPromote());
      } else if (_routingMode != ConnectionRoutingMode.cloudOnly) {
        _pollLanStateQuietly();
      }
      if (_devices.isEmpty && isPrimary) {
        _triggerQuietLanDiscovery();
      }
      notifyListeners();
    }
  }

  Future<bool> _probeKnownLanDevicesFast() async {
    try {
      final cachedIps = DeviceStorageService.getAllCachedDeviceIps();
      final candidates = <String, String>{};
      for (final entry in cachedIps.entries) {
        if (entry.value.trim().isNotEmpty) {
          candidates[entry.key] = entry.value.trim();
        }
      }
      for (final d in _devices) {
        final ip = LocalLanDeviceService.instance.getDeviceIp(d.id);
        if (ip != null && ip.trim().isNotEmpty) {
          candidates[d.id] = ip.trim();
        }
      }
      if (candidates.isEmpty) return false;

      bool anySuccess = false;
      for (final entry in candidates.entries) {
        final devId = entry.key;
        final ip = entry.value;
        final state = await LocalLanDeviceService.instance.fetchLocalDeviceState(
          deviceId: devId,
          explicitIp: ip,
        );
        if (state != null && state.channels.isNotEmpty) {
          LocalLanDeviceService.instance.markDeviceReachableOnLan(devId);
          LocalLanDeviceService.instance.markDeviceReachableOnLan(state.deviceId);
          _promoteToLocalLanMode(devId, state);
          anySuccess = true;
        } else {
          LocalLanDeviceService.instance.markDeviceOfflineOnLan(devId);
          if (_routingMode == ConnectionRoutingMode.localOnly) {
            final idx = _devices.indexWhere((d) => d.id == devId);
            if (idx >= 0) {
              _devices[idx] = _devices[idx].copyWith(
                online: false,
                signalLabel: 'Offline',
              );
            }
          }
        }
      }
      if (!anySuccess) {
        if (_routingMode == ConnectionRoutingMode.auto) {
          _isLocalMode = false;
        }
        if (!_isCloudReachable) {
          _connectionState = HomeConnectionState.offline;
          _connectionMessage = 'Devices and cloud backend unreachable.';
        }
      }
      return anySuccess;
    } catch (e) {
      debugPrint('[LAN-FAST-PROBE] probe error: $e');
      return false;
    }
  }

  Future<void> _triggerQuietLanDiscovery() async {
    try {
      final discovered = await LocalLanDeviceService.instance.autoDiscoverDevices();
      if (discovered.isNotEmpty) {
        bool modified = false;
        for (final entry in discovered.entries) {
          final devId = entry.key;
          final ip = entry.value;
          final devState = await LocalLanDeviceService.instance.fetchLocalDeviceState(deviceId: devId, explicitIp: ip);
          if (devState != null) {
            LocalLanDeviceService.instance.markDeviceReachableOnLan(devId, ip: ip);
            if (_routingMode == ConnectionRoutingMode.auto && !_isLocalMode) {
              _promoteToLocalLanMode(devId, devState);
              modified = true;
            } else {
              final changed = _syncHardwareModelAndState(devId, devState);
              if (changed) modified = true;
            }
          }
        }
        if (modified) {
          notifyListeners();
        }
      }
    } catch (_) {}
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
  Timer? _autoModeLanPromotionTimer;
  bool _isQuietSyncing = false;
  bool _isProbingLan = false;

  void _startAutoSyncTimer() {
    if (!autoSync) return;
    _autoSyncTimer?.cancel();
    _autoSyncTimer = Timer.periodic(const Duration(milliseconds: 2500), (_) {
      _quietSyncDeviceStates();
    });
  }

  void _startAutoModeLanPromotionTimer() {
    if (!autoSync) return;
    _autoModeLanPromotionTimer?.cancel();
    if (_routingMode == ConnectionRoutingMode.auto && !_isLocalMode && !_disposed) {
      unawaited(probeLanAndPromote());
    }
    _autoModeLanPromotionTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (_routingMode == ConnectionRoutingMode.auto && !_isLocalMode && !_disposed) {
        probeLanAndPromote();
      }
    });
  }

  /// Asynchronously probes known and discovered LAN IPs and promotes Auto Mode to LAN Mode
  /// with zero user interaction as soon as at least one local device responds.
  Future<bool> probeLanAndPromote({String? targetDeviceId}) async {
    if (_disposed) return false;
    if (_routingMode != ConnectionRoutingMode.auto && _routingMode != ConnectionRoutingMode.localOnly) {
      return false;
    }
    final allDevicesOnline = _devices.isNotEmpty && _devices.every((d) => d.online);
    if (_isLocalMode && _routingMode == ConnectionRoutingMode.auto && allDevicesOnline && targetDeviceId == null) {
      return true;
    }
    if (_isProbingLan) return false;
    _isProbingLan = true;
    bool anyPromoted = false;

    try {
      // 1. Fast path: probe known / cached IPs directly (<50ms)
      final checkDevIds = targetDeviceId != null
          ? [targetDeviceId]
          : _devices.map((d) => d.id).toList();

      for (final devId in checkDevIds) {
        final ip = LocalLanDeviceService.instance.getDeviceIp(devId);
        if (ip != null && ip.isNotEmpty) {
          final state = await LocalLanDeviceService.instance.fetchLocalDeviceState(
            deviceId: devId,
            explicitIp: ip,
          );
          if (state != null) {
            final targetId = state.deviceId.isNotEmpty ? state.deviceId : devId;
            LocalLanDeviceService.instance.markDeviceReachableOnLan(targetId, ip: ip);
            _promoteToLocalLanMode(targetId, state);
            anyPromoted = true;
          }
        }
      }

      // Check all cached IPs from device storage for remaining offline devices
      final cachedIps = DeviceStorageService.getAllCachedDeviceIps();
      for (final entry in cachedIps.entries) {
        final devId = entry.key;
        final ip = entry.value;
        if (ip.isNotEmpty) {
          final isAlreadyOnline = _devices.any((d) => d.id == devId && d.online);
          if (!isAlreadyOnline) {
            final state = await LocalLanDeviceService.instance.fetchLocalDeviceState(
              deviceId: devId,
              explicitIp: ip,
            );
            if (state != null) {
              final targetId = state.deviceId.isNotEmpty ? state.deviceId : devId;
              LocalLanDeviceService.instance.markDeviceReachableOnLan(targetId, ip: ip);
              _promoteToLocalLanMode(targetId, state);
              anyPromoted = true;
            }
          }
        }
      }

      // 2. Concurrently run active discovery on local subnet for any still-offline devices
      final stillOffline = _devices.where((d) => !d.online).map((d) => d.id).toList();
      if (stillOffline.isNotEmpty || !anyPromoted) {
        final discovered = await LocalLanDeviceService.instance.autoDiscoverDevices(
          expectedDeviceIds: _devices.map((d) => d.id).toList(),
          timeout: const Duration(milliseconds: 1500),
        );
        if (discovered.isNotEmpty) {
          for (final entry in discovered.entries) {
            final devId = entry.key;
            final ip = entry.value;
            final state = await LocalLanDeviceService.instance.fetchLocalDeviceState(
              deviceId: devId,
              explicitIp: ip,
            );
            if (state != null) {
              final targetId = state.deviceId.isNotEmpty ? state.deviceId : devId;
              LocalLanDeviceService.instance.markDeviceReachableOnLan(targetId, ip: ip);
              _promoteToLocalLanMode(targetId, state);
              anyPromoted = true;
            }
          }
        }
      }
    } catch (e) {
      debugPrint('[LAN-PROBE] probeLanAndPromote error: $e');
    } finally {
      _isProbingLan = false;
    }
    return anyPromoted;
  }

  void _promoteToLocalLanMode(String devId, LanDeviceState devState) {
    if (_routingMode == ConnectionRoutingMode.cloudOnly) return;
    _isLocalMode = true;
    _lanMissedPollCount = 0;
    final targetId = devState.deviceId.isNotEmpty ? devState.deviceId : devId;
    _deviceMissedPolls[targetId] = 0;
    _connectionState = HomeConnectionState.connected;
    _connectionMessage = 'Local Wi-Fi Mode (Direct LAN)';

    bool devFound = false;
    for (int i = 0; i < _devices.length; i++) {
      if (_devices[i].id == targetId) {
        devFound = true;
        _devices[i] = _devices[i].copyWith(
          online: true,
          signalLabel: 'Local Wi-Fi',
        );
        _connectedDeviceSummary = _devices[i];
        break;
      }
    }

    if (!devFound) {
      // Find from storage or cached space devices
      ConnectedDeviceSummary? cachedMatch;
      for (final list in _spaceDevicesCache.values) {
        final match = list.cast<ConnectedDeviceSummary?>().firstWhere(
          (d) => d != null && d.id == targetId,
          orElse: () => null,
        );
        if (match != null) {
          cachedMatch = match;
          break;
        }
      }
      final canon = MockProductCatalogRepository.resolveCanonicalProductVariant(
        variantId: devState.model ?? cachedMatch?.model,
        deviceName: cachedMatch?.name,
      );
      final isSocket = canon.contains('socket');
      final is4X = canon.contains('4x');
      final is3X = canon.contains('3x');
      final is2X = canon.contains('2x');
      final is1X = canon.contains('1x');
      final suffix = is4X ? '4X' : (is3X ? '3X' : (is2X ? '2X' : (is1X ? '1X' : '')));
      final defaultName = isSocket
          ? (suffix.isNotEmpty ? 'EH Smart Socket $suffix' : 'EH Smart Socket')
          : (suffix.isNotEmpty ? 'EH Smart Switch $suffix' : 'EH Smart Switch');
      final devName = cachedMatch?.name ?? defaultName;
      final newDev = (cachedMatch != null)
          ? cachedMatch.copyWith(online: true, signalLabel: 'Local Wi-Fi', model: canon)
          : ConnectedDeviceSummary(
              id: targetId,
              name: devName,
              model: canon,
              firmware: '1.0.0',
              connectedVia: 'Wi-Fi (Local)',
              signalLabel: 'Local Wi-Fi',
              roomName: cachedMatch?.roomName ?? 'Unassigned',
              online: true,
            );
      _devices.add(newDev);
      _connectedDeviceSummary ??= newDev;
      _activeDeviceId ??= targetId;
      _activeDisplayName ??= devName;
      _activeSerialNumber ??= newDev.model;
      _storageService.saveDeviceForSpace(_activeSpaceId, newDev);
      _spaceDevicesCache[_activeSpaceId] = List.from(_devices);
    }

    _syncHardwareModelAndState(targetId, devState);
    debugPrint('[LAN-PROBE] Auto Mode promoted to LAN Mode for device $devId (0 button taps required)');
    unawaited(EdgeRoutineSyncService.instance.syncRoutinesFromEdgeToApp(targetDeviceId: devId).then((_) {
      refreshUpcomingRoutines();
    }));
    notifyListeners();
  }

  Future<void> _pollLanStateQuietly() async {
    if (_devices.isEmpty || _routingMode == ConnectionRoutingMode.cloudOnly) return;
    bool localStateChanged = false;
    bool anyLocalActive = false;

    for (int i = 0; i < _devices.length; i++) {
      final devId = _devices[i].id;
      final cachedIp = LocalLanDeviceService.instance.getDeviceIp(devId);
      if (cachedIp == null || cachedIp.isEmpty) {
        unawaited(LocalLanDeviceService.instance.autoDiscoverDevices(
          expectedDeviceIds: [devId],
          timeout: const Duration(seconds: 2),
        ));
      }
      final devState = await LocalLanDeviceService.instance.fetchLocalDeviceState(deviceId: devId);
      if (devState != null && devState.channels.isNotEmpty) {
        anyLocalActive = true;
        LocalLanDeviceService.instance.markDeviceReachableOnLan(devId);
        LocalLanDeviceService.instance.markDeviceReachableOnLan(devState.deviceId);
        _deviceMissedPolls[devId] = 0;
        if (!_devices[i].online || _devices[i].signalLabel != 'Local Wi-Fi') {
          _devices[i] = _devices[i].copyWith(
            signalLabel: 'Local Wi-Fi',
            online: true,
          );
          localStateChanged = true;
        }
        if (_syncHardwareModelAndState(devId, devState)) {
          localStateChanged = true;
        }
      } else {
        final missed = (_deviceMissedPolls[devId] ?? 0) + 1;
        _deviceMissedPolls[devId] = missed;
        // Require at least 5 consecutive failed polls before dropping to offline
        if (missed >= 5 && _devices[i].online) {
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
      _connectionMessage = 'Local Wi-Fi Mode (Direct LAN)';
    } else {
      _lanMissedPollCount++;
      if (_lanMissedPollCount >= 1 && _isLocalMode && _routingMode != ConnectionRoutingMode.localOnly) {
        _isLocalMode = false;
        localStateChanged = true;
      }
      if (_isCloudReachable) {
        _connectionState = HomeConnectionState.connected;
        _connectionMessage = 'Cloud Mode (Remote)';
      } else {
        if (_connectionState != HomeConnectionState.offline) {
          _connectionState = HomeConnectionState.offline;
          _connectionMessage = _routingMode == ConnectionRoutingMode.localOnly
              ? 'Local LAN Devices Offline'
              : 'Cloud unreachable • Devices offline';
          localStateChanged = true;
        }
      }
    }

    if (localStateChanged) {
      notifyListeners();
    }
  }

  Future<void> _quietSyncDeviceStates() async {
    if (_disposed || _isQuietSyncing) return;
    _isQuietSyncing = true;
    try {
      if (_routingMode == ConnectionRoutingMode.localOnly || (_isLocalMode && _routingMode == ConnectionRoutingMode.auto)) {
        await _pollLanStateQuietly();
        if (_routingMode == ConnectionRoutingMode.localOnly) return;
        if (_isLocalMode) return;
      }

      bool stateChanged = false;
      final rawDevices = await _repository.getDevices(homeId: _activeHomeId).timeout(const Duration(milliseconds: 3000));
      _consecutiveCloudFailures = 0;
      if (_activeHomeId == null && _repository is CloudHomeRepository) {
        final repoHomeId = _repository.activeHomeId;
        if (repoHomeId != null && repoHomeId.isNotEmpty) {
          _activeHomeId = repoHomeId;
        }
      }
      if (!_isCloudReachable && _routingMode != ConnectionRoutingMode.localOnly) {
        _isCloudReachable = true;
        _connectionState = HomeConnectionState.connected;
        stateChanged = true;
      }
      // A successful cloud response is itself a verified home connection.
      // Do not leave the UI stuck in Offline merely because every physical
      // device is currently asleep or reports offline.
      if (_routingMode != ConnectionRoutingMode.localOnly && !_isLocalMode) {
        if (_connectionState != HomeConnectionState.connected ||
            _connectionMessage != 'Cloud Mode (Remote)') {
          _connectionState = HomeConnectionState.connected;
          _connectionMessage = 'Cloud Mode (Remote)';
          stateChanged = true;
        }
      }
      if (rawDevices.isEmpty) {
        if (stateChanged) notifyListeners();
        return;
      }

      for (final d in rawDevices) {
        final isOnline = d.connection == DeviceConnection.online;
        final devChannels = _channelStates.putIfAbsent(d.id, () => {});
        for (final ch in d.channels) {
          final chIdx = _parseChannelIndex(ch) ?? 1;
          final pwr = _parsePowerFromChannel(ch);
          if (pwr != null) {
            final cmdKey1 = '${d.id}_$chIdx';
            final cmdKey2 = '${d.id.toLowerCase()}_$chIdx';
            final cmdKey3 = '${d.id}_ch$chIdx';
            final lastCmd = _lastCommandTimestamps[cmdKey1] ?? _lastCommandTimestamps[cmdKey2] ?? _lastCommandTimestamps[cmdKey3];
            if (lastCmd != null && DateTime.now().difference(lastCmd).inMilliseconds < 3500) {
              // User recently toggled this switch: hold optimistic state for 3500ms to allow network roundtrip + ESP32 settling timer
              continue;
            }
            // If device is active on local LAN, hardware on LAN is authoritative
            final isLanDevice = LocalLanDeviceService.instance.getDeviceIp(d.id) != null;
            if (isLanDevice && _isLocalMode) {
              continue;
            }
            if (devChannels[chIdx] != pwr) {
              devChannels[chIdx] = pwr;
              stateChanged = true;
              _checkAndDispatchChannelAlert(d.id, chIdx, pwr);
              if (chIdx == 1 && d.roomName.toLowerCase().contains('living')) {
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
            if (isOnline && _routingMode == ConnectionRoutingMode.auto && !_isLocalMode) {
              unawaited(probeLanAndPromote(targetDeviceId: d.id));
            }
          }
        }
      }

      if (stateChanged) {
        debugPrint('[HOME] AUTO_SYNC_STATE_UPDATED live channels: $_channelStates');
        notifyListeners();
      }
    } catch (e) {
      _consecutiveCloudFailures++;
      bool connectivityChanged = false;
      if (_routingMode == ConnectionRoutingMode.cloudOnly) {
        // Explicitly locked to cloud mode: hold cloud connection active
        _isCloudReachable = true;
        _isLocalMode = false;
      } else {
        if (e is ApiException && e.statusCode != 0) {
          if (!_isCloudReachable) connectivityChanged = true;
          _isCloudReachable = true;
          _consecutiveCloudFailures = 0;
        } else if (_consecutiveCloudFailures >= 1) {
          if (_isCloudReachable) {
            _isCloudReachable = false;
            connectivityChanged = true;
          }
        }
      }
      await _pollLanStateQuietly();
      if (!_isCloudReachable && !_isLocalMode) {
        if (_connectionState != HomeConnectionState.offline) {
          _connectionState = HomeConnectionState.offline;
          _connectionMessage = 'Cloud unreachable • Devices offline';
          connectivityChanged = true;
        }
        for (int i = 0; i < _devices.length; i++) {
          if (_devices[i].online) {
            _devices[i] = _devices[i].copyWith(
              online: false,
              signalLabel: 'Offline',
            );
            connectivityChanged = true;
          }
        }
      }
      if (connectivityChanged) {
        notifyListeners();
      }
    } finally {
      _isQuietSyncing = false;
    }
  }

  /// Explicitly activates Local Wi-Fi (LAN) mode when cloud is down.
  /// Runs automated device discovery (UDP broadcast & subnet ping sweep),
  /// fetches their live hardware states directly, and enables controls.
  Future<bool> switchToLanMode({bool isBackground = false}) async {
    if (!isBackground && _devices.isEmpty) {
      _isLoading = true;
      notifyListeners();
    }
    try {
      debugPrint('[HOME] Switching to Local LAN mode via auto-discovery...');
      final discovered = await LocalLanDeviceService.instance.autoDiscoverDevices();
      bool anyFound = false;

      // Mark this active space as the LAN matched space
      _lanMatchedSpaceId = _activeSpaceId;

      for (int i = 0; i < _devices.length; i++) {
        final devId = _devices[i].id;
        final cleanDevId = devId.trim().toLowerCase();
        String? localIp = discovered[devId];
        if (localIp == null || localIp.isEmpty) {
          for (final entry in discovered.entries) {
            if (entry.key.trim().toLowerCase() == cleanDevId) {
              localIp = entry.value;
              break;
            }
          }
        }
        localIp ??= LocalLanDeviceService.instance.getDeviceIp(devId);
        if (localIp != null && localIp.isNotEmpty) {
          final devState = await LocalLanDeviceService.instance.fetchLocalDeviceState(
            deviceId: devId,
            explicitIp: localIp,
          );
          if (devState != null && devState.channels.isNotEmpty) {
            anyFound = true;
            _syncHardwareModelAndState(devId, devState);
          }
        }
      }

      if (!anyFound && discovered.isNotEmpty) {
        for (final entry in discovered.entries) {
          final devId = entry.key;
          final ip = entry.value;
          final devState = await LocalLanDeviceService.instance.fetchLocalDeviceState(deviceId: devId, explicitIp: ip);
          if (devState != null) {
            anyFound = true;
            final targetId = devState.deviceId.isNotEmpty ? devState.deviceId : devId;
            final normModel = MockProductCatalogRepository.normalizeVariantId(devState.model ?? '');
            final isSocket = normModel.contains('socket') || (devState.model ?? '').toLowerCase().contains('sk');
            final is4X = normModel.contains('4x') || (devState.model ?? '').toLowerCase().contains('4x');
            final is3X = normModel.contains('3x') || (devState.model ?? '').toLowerCase().contains('3x');
            final is2X = normModel.contains('2x') || (devState.model ?? '').toLowerCase().contains('2x');
            final is1X = normModel.contains('1x') || (devState.model ?? '').toLowerCase().contains('1x');
            final suffix = is4X ? '4X' : (is3X ? '3X' : (is2X ? '2X' : (is1X ? '1X' : '')));
            final generatedName = isSocket
                ? (suffix.isNotEmpty ? 'EH Smart Socket $suffix' : 'EH Smart Socket')
                : (suffix.isNotEmpty ? 'EH Smart Switch $suffix' : 'EH Smart Switch');

            final existingDev = _devices.cast<ConnectedDeviceSummary?>().firstWhere(
              (d) => d?.id == targetId,
              orElse: () => null,
            );
            if (existingDev == null) {
              final newDev = ConnectedDeviceSummary(
                id: targetId,
                name: generatedName,
                model: devState.model ?? (normModel.isNotEmpty ? normModel : 'eh_switch_4x'),
                firmware: '1.0.0',
                connectedVia: 'Wi-Fi (Local)',
                signalLabel: 'Local Wi-Fi',
                roomName: 'Unassigned',
                online: true,
              );
              _devices.add(newDev);
              _storageService.saveDeviceForSpace(_activeSpaceId, newDev);
            } else {
              final idx = _devices.indexOf(existingDev);
              _devices[idx] = existingDev.copyWith(
                online: true,
                signalLabel: 'Local Wi-Fi',
              );
            }
            _devices = _deduplicateDevices(_devices);
            _syncHardwareModelAndState(targetId, devState);
          }
        }
      }

      _isLocalMode = anyFound;
      if (anyFound) {
        _connectionState = HomeConnectionState.connected;
        _connectionMessage = 'Local Wi-Fi Mode Active (Direct LAN)';
        unawaited(EdgeRoutineSyncService.instance.syncRoutinesFromEdgeToApp());
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

    final cleanDevices = _deduplicateDevices(_devices);
    if (cleanDevices.isNotEmpty) {
      final Map<String, List<ConnectedDeviceSummary>> roomMap = {};
      for (final d in cleanDevices) {
        final room = d.roomName.trim().isEmpty ? 'Unassigned' : d.roomName;
        roomMap.putIfAbsent(room, () => []).add(d);
      }
      result.addAll(roomMap.entries.map((entry) {
        final roomName = entry.key;
        final roomDevices = entry.value;
        final isUnassigned = roomName.toLowerCase() == 'unassigned';
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
        final roomStatus = isUnassigned
            ? RoomStatus.attention
            : (anyOnline ? RoomStatus.normal : RoomStatus.unavailable);
        final anyChannelOnInRoom = anyOnline && roomDevices.any((d) {
          if (!d.online) return false;
          for (int ch = 1; ch <= 4; ch++) {
            if (getDeviceChannelPower(d.id, ch)) {
              return true;
            }
          }
          return false;
        });
        final roomSummary = isUnassigned
            ? '${roomDevices.length} unassigned ${roomDevices.length == 1 ? 'device' : 'devices'} · Tap to assign room'
            : (anyOnline
                ? (anyChannelOnInRoom ? 'Active · Normal' : 'Standby · Normal')
                : 'Offline · Disconnected');

        return Room(
          id: roomId,
          name: roomName,
          iconKey: isUnassigned ? 'hub' : (matchingBackendRoom?.iconKey ?? 'living'),
          deviceCount: roomDevices.length,
          connectivity: roomConnectivity,
          telemetryFreshness: anyOnline ? TelemetryFreshness.current : TelemetryFreshness.unknown,
          summary: roomSummary,
          status: roomStatus,
          capabilities: roomDevices.expand((d) {
            final norm = MockProductCatalogRepository.normalizeVariantId(d.model.isNotEmpty ? d.model : d.name);
            final isSocket = norm.contains('socket') ||
                d.name.toLowerCase().contains('socket') ||
                d.model.toLowerCase().contains('socket') ||
                d.model.toLowerCase().contains('sk');
            final is4X = norm.contains('4x') || d.name.toLowerCase().contains('4x') || d.model.toLowerCase().contains('4x');
            final is3X = norm.contains('3x') || d.name.toLowerCase().contains('3x') || d.model.toLowerCase().contains('3x') || d.model.contains('-3');
            final is2X = norm.contains('2x') || d.name.toLowerCase().contains('2x') || d.model.toLowerCase().contains('2x') || d.model.contains('-2');
            final is1X = norm.contains('1x') || d.name.toLowerCase().contains('1x') || d.model.toLowerCase().contains('1x') || d.model.contains('-1');
            final channelCount = is4X ? 4 : (is3X ? 3 : (is2X ? 2 : (is1X ? 1 : (isSocket ? 3 : 4))));
            final channelPrefix = isSocket ? 'Socket' : 'Switch';
            final labels = DeviceStorageService.getChannelLabels(d.id);

            return List.generate(channelCount, (i) {
              final ch = i + 1;
              final chName = labels[ch] ?? '$channelPrefix $ch';
              final chOn = d.online && getDeviceChannelPower(
                d.id,
                ch,
              );
              return RoomCapability(
                id: '${d.id}_ch$ch',
                label: chName,
                value: chOn ? 'On' : 'Off',
                kind: inferCapKind(d.name, d.model, chName),
                isOnline: d.online,
              );
            });
          }).toList(),
          devices: roomDevices.map((d) {
            final opName = formatOperatingName(d.name);
            final norm = MockProductCatalogRepository.normalizeVariantId(d.model.isNotEmpty ? d.model : d.name);
            final isSocket = norm.contains('socket') ||
                d.name.toLowerCase().contains('socket') ||
                d.model.toLowerCase().contains('socket') ||
                d.model.toLowerCase().contains('sk');
            final is4X = norm.contains('4x') || d.name.toLowerCase().contains('4x') || d.model.toLowerCase().contains('4x');
            final is3X = norm.contains('3x') || d.name.toLowerCase().contains('3x') || d.model.toLowerCase().contains('3x') || d.model.contains('-3');
            final is2X = norm.contains('2x') || d.name.toLowerCase().contains('2x') || d.model.toLowerCase().contains('2x') || d.model.contains('-2');
            final is1X = norm.contains('1x') || d.name.toLowerCase().contains('1x') || d.model.toLowerCase().contains('1x') || d.model.contains('-1');
            final suffix = is4X ? '4X' : (is3X ? '3X' : (is2X ? '2X' : (is1X ? '1X' : (isSocket ? '3X' : '4X'))));
            final devType =
                isSocket ? 'Smart Socket $suffix' : 'Smart Switch $suffix';
            final ch1On = d.online && getDeviceChannelPower(
              d.id,
              1,
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
    final oldLabel = DeviceStorageService.getChannelLabels(deviceId)[channelIndex];
    await DeviceStorageService.saveChannelLabel(deviceId, channelIndex, newName);
    await ChangeTrackingService.instance.recordChange(
      entityType: 'channel',
      entityId: '$deviceId:ch$channelIndex',
      field: 'label',
      oldValue: oldLabel,
      newValue: newName,
      changeType: ChangeType.modified,
    );
    _markLocalChangesDirty();
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
    await ChangeTrackingService.instance.recordChange(
      entityType: 'room',
      entityId: roomId.isNotEmpty ? roomId : oldName,
      field: 'name',
      oldValue: oldName,
      newValue: newName,
      changeType: ChangeType.modified,
    );
    _markLocalChangesDirty();
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
    await _storageService.removeRoomForSpace(_activeSpaceId, roomName);
    await DeviceStorageService.deleteRoom(roomName);
    await ChangeTrackingService.instance.recordChange(
      entityType: 'room',
      entityId: roomId.isNotEmpty ? roomId : roomName,
      field: 'name',
      oldValue: roomName,
      newValue: null,
      changeType: ChangeType.deleted,
    );
    _markLocalChangesDirty();
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
    final effectiveDevices = _deduplicateDevices(_devices.isNotEmpty ? _devices : DeviceStorageService.cachedDevices);
    if (effectiveDevices.isNotEmpty) {
      final Map<String, Map<int, String>> allChannelLabels = {};
      for (final d in effectiveDevices) {
        allChannelLabels[d.id] = DeviceStorageService.getChannelLabels(d.id);
      }
      return HomeDashboardData.forLiveDevices(
        devices: effectiveDevices,
        lightOn: _livingRoomLightOn,
        lightConfidence: _lightConfidence,
        selectedControlIds: _selectedQuickControlIds,
        channelStates: _channelStates,
        channelLabels: allChannelLabels,
        isCloudReachable: _isCloudReachable,
        isLocalMode: isLocalMode,
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
            _activeDisplayName ?? _activeSerialNumber ?? 'EH Smart Switch 4X';
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
    final cleanId = deviceId.trim();
    if (cleanId.isEmpty) return defaultValue;
    if (_channelStates[cleanId]?.containsKey(channelIndex) == true) {
      return _channelStates[cleanId]![channelIndex]!;
    }
    for (final entry in _channelStates.entries) {
      if (entry.key.trim().toLowerCase() == cleanId.toLowerCase()) {
        if (entry.value.containsKey(channelIndex)) {
          return entry.value[channelIndex]!;
        }
      }
    }
    return defaultValue;
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
        if (isOnline && _routingMode == ConnectionRoutingMode.auto && !_isLocalMode) {
          unawaited(probeLanAndPromote(targetDeviceId: devId));
        }
        break;

      case 'device.state':
        // Authoritative state convergence for toggle channels
        final state = envelope.payload;
        final devId = state['deviceId'] as String? ?? _activeDeviceId;
        if (devId != null) {
          final isLivingRoomDev = _devices.any((d) => d.id == devId && d.roomName.toLowerCase().contains('living'));
          final devChannels = _channelStates.putIfAbsent(devId, () => {});
          // 1. Handle channels as List (standard firmware envelope)
          if (state['channels'] is List) {
            for (final ch in (state['channels'] as List)) {
              if (ch is Map) {
                final chIdx = _parseChannelIndex(ch) ?? 1;
                final pwr = _parsePowerFromChannel(ch);
                if (pwr != null) {
                  if (devChannels[chIdx] != pwr) {
                    devChannels[chIdx] = pwr;
                    _checkAndDispatchChannelAlert(devId, chIdx, pwr);
                  }
                  if (chIdx == 1 && isLivingRoomDev) {
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
                if (devChannels[chIdx] != pwr) {
                  devChannels[chIdx] = pwr;
                  _checkAndDispatchChannelAlert(devId, chIdx, pwr);
                }
                if (chIdx == 1 && isLivingRoomDev) {
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
              if (devChannels[chIdx] != pwr) {
                devChannels[chIdx] = pwr;
                _checkAndDispatchChannelAlert(devId, chIdx, pwr);
              }
              if (chIdx == 1 && isLivingRoomDev) {
                _livingRoomLightOn = pwr;
                _lightConfidence = ActuatorConfidence.confirmed;
                _lightCommandPending = false;
              }
            }
          }
        }
        debugPrint('[DEVICE] STATE_RECONCILED devId=$devId');
        notifyListeners();
        if (_routingMode == ConnectionRoutingMode.auto && !_isLocalMode) {
          unawaited(probeLanAndPromote(targetDeviceId: devId));
        }
        break;

      case 'device.event':
        final event = envelope.payload;
        final devId = event['deviceId'] as String? ?? _activeDeviceId;
        if (devId != null) {
          final isLivingRoomDev = _devices.any((d) => d.id == devId && d.roomName.toLowerCase().contains('living'));
          final chIdx = _parseChannelIndex(event) ?? 1;
          final pwr = _parsePowerFromChannel(event) ??
              (event['payload'] is Map ? _parsePowerFromChannel(event['payload'] as Map) : null) ??
              (event['payload'] is bool ? (event['payload'] as bool) : null);
          if (pwr != null) {
            final devChannels = _channelStates.putIfAbsent(devId, () => {});
            if (devChannels[chIdx] != pwr) {
              devChannels[chIdx] = pwr;
              _checkAndDispatchChannelAlert(devId, chIdx, pwr);
            }
            if (chIdx == 1 && isLivingRoomDev) {
              _livingRoomLightOn = pwr;
              _lightConfidence = ActuatorConfidence.confirmed;
              _lightCommandPending = false;
            }
          }
        }
        debugPrint('[DEVICE] EVENT_RECONCILED devId=$devId');
        notifyListeners();
        if (_routingMode == ConnectionRoutingMode.auto && !_isLocalMode) {
          unawaited(probeLanAndPromote(targetDeviceId: devId));
        }
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
        _devices = _deduplicateDevices(savedList);
        _connectedDeviceSummary = _devices.first;
        _activeDeviceId = _devices.first.id;
        _activeDisplayName = _devices.first.name;
        _activeSerialNumber = _devices.first.model;
        final anyOnline = _devices.any((d) => d.online);
        _connectionState = anyOnline ? HomeConnectionState.connected : HomeConnectionState.offline;
        _connectionMessage = anyOnline
            ? '${_devices.first.name} is connected.'
            : '${_devices.first.name} is offline.';
        debugPrint('[HOME] DEVICE_REGISTERED count=${_devices.length}');
        debugPrint('[HOME] DEVICE_PERSISTED');
        debugPrint('[HOME] HOME_STATE_REFRESH');
        debugPrint('[HOME] REAL_DEVICE_COUNT=${_devices.length}');
        debugPrint('[HOME] DEVICE_STATUS=${anyOnline ? "ONLINE" : "OFFLINE"}');
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

    if (_selectedQuickControlIds.isEmpty) {
      final qControls = await _storageService.loadQuickControls();
      if (qControls.isNotEmpty) {
        _selectedQuickControlIds = List.from(qControls);
      }
    }
    final nPrefs = await _storageService.loadNotificationPrefs();
    if (nPrefs.isNotEmpty) {
      _notificationPrefs = Map.from(nPrefs);
    }
    final savedAlerts = await DeviceStorageService.loadActivityAlerts();
    if (savedAlerts.isNotEmpty) {
      _activityAlerts.clear();
      _activityAlerts.addAll(savedAlerts);
    }
    await refreshUpcomingRoutines();
    if (_routingMode == ConnectionRoutingMode.auto || _routingMode == ConnectionRoutingMode.localOnly) {
      unawaited(probeLanAndPromote());
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
    String? model,
  }) {
    _activeDeviceId = deviceId;
    _activeDisplayName = displayName;
    _activeSerialNumber = serialNumber;

    final resolvedModel = MockProductCatalogRepository.resolveCanonicalProductVariant(
      variantId: model,
      deviceName: displayName,
      serialNumber: serialNumber,
    );

    final assignedRoom = (roomName != null && roomName.trim().isNotEmpty)
        ? roomName.trim()
        : 'Unassigned';

    final summary = ConnectedDeviceSummary(
      id: deviceId,
      name: displayName,
      model: resolvedModel,
      firmware: '1.0.0',
      connectedVia: 'Wi-Fi (2.4 GHz)',
      signalLabel: 'Strong',
      roomName: assignedRoom,
      online: true,
    );
    _devices = List<ConnectedDeviceSummary>.from(_devices);
    final idx = _devices.indexWhere((d) => d.id == deviceId);
    if (idx >= 0) {
      _devices[idx] = summary;
    } else {
      _devices.add(summary);
    }
    _connectedDeviceSummary = summary;
    _connectionState = HomeConnectionState.connected;
    _connectionMessage = '$displayName is connected and online.';

    // Ensure room is registered persistently
    if (!_customEmptyRooms.any((r) => r.name.toLowerCase() == assignedRoom.toLowerCase())) {
      _customEmptyRooms.add(
        Room(
          id: assignedRoom.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_'),
          name: assignedRoom,
          iconKey: 'living',
          deviceCount: 1,
          connectivity: ConnectivityCause.online,
          telemetryFreshness: TelemetryFreshness.current,
          summary: '1 device · Configured',
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
    final canonical = MockProductCatalogRepository.resolveCanonicalProductVariant(
      variantId: resolvedModel,
      deviceName: displayName,
      serialNumber: serialNumber,
    );
    final isSocket = canonical.contains('socket');
    final nameLower = displayName.toLowerCase();
    final is4X = nameLower.contains('4x') || canonical.contains('4x');
    final is3X = nameLower.contains('3x') || canonical.contains('3x');
    final is2X = nameLower.contains('2x') || canonical.contains('2x');
    final is1X = nameLower.contains('1x') || canonical.contains('1x');
    final devChannelCount = is4X ? 4 : (is3X ? 3 : (is2X ? 2 : (is1X ? 1 : (isSocket ? 2 : 4))));
    final channelPrefix = isSocket ? 'Socket' : 'Switch';

    // Populate quick controls for all channels of the new device
    final newControlIds = List.generate(devChannelCount, (i) => '${deviceId}_ch${i + 1}');
    final updatedQuickControls = List<String>.from(_selectedQuickControlIds);
    for (final id in newControlIds) {
      if (!updatedQuickControls.contains(id)) {
        updatedQuickControls.add(id);
      }
    }
    _selectedQuickControlIds = updatedQuickControls;
    _storageService.saveQuickControls(_selectedQuickControlIds);
    _storageService.saveQuickControlsForSpace(_activeSpaceId, _selectedQuickControlIds);
    if (assignedRoom.toLowerCase() != 'unassigned') {
      DeviceStorageService.saveRoomQuickControls(assignedRoom, newControlIds);
    }

    // Only set default channel labels if custom labels don't already exist for this device
    final existingLabels = DeviceStorageService.getChannelLabels(deviceId);
    if (existingLabels.isEmpty) {
      final defaultLabels = <int, String>{
        for (int i = 1; i <= devChannelCount; i++) i: '$channelPrefix $i',
      };
      DeviceStorageService.setChannelLabelsForDevice(deviceId, defaultLabels);
    }

    if (assignedRoom.toLowerCase() != 'unassigned') {
      _storageService.addRoom(assignedRoom);
      _storageService.addRoomForSpace(_activeSpaceId, assignedRoom);
    }
    _storageService.saveDeviceForSpace(_activeSpaceId, summary);
    _spaceDevicesCache[_activeSpaceId] = List.from(_devices);

    if (_activeHomeId != null) {
      final isDevSocket = displayName.toLowerCase().contains('socket') || resolvedModel.toLowerCase().contains('socket');
      _repository.registerDevice(
        deviceId: deviceId,
        serialNumber: serialNumber.isNotEmpty ? serialNumber : 'EH-${resolvedModel.toUpperCase()}-${deviceId.substring(0, math.min(deviceId.length, 6))}',
        productVariantId: resolvedModel,
        hardwareRevision: 'HW_1_0',
        firmwareFamily: isDevSocket ? 'esp32c6-socket-platform' : 'esp32c6-switch-platform',
        firmwareVersion: '1.0.0',
      ).catchError((_) {});

      final matchingBackendRoom = _backendRooms.cast<Room?>().firstWhere(
        (br) => br?.name.toLowerCase() == assignedRoom.toLowerCase(),
        orElse: () => null,
      );
      _repository
          .claimDevice(
            deviceId: deviceId,
            homeId: _activeHomeId!,
            roomId: matchingBackendRoom?.id,
            customName: displayName,
          )
          .catchError((err) {
            debugPrint('[HOME] Warning: could not claim device on backend: $err');
          });
    }

    debugPrint(
      '[HOME] DEVICE_REGISTERED id=$deviceId name=$displayName room=${roomName ?? "Living Room"} channels=$devChannelCount',
    );
    debugPrint('[HOME] DEVICE_PERSISTED');
    debugPrint('[HOME] HOME_STATE_REFRESH');
    debugPrint('[HOME] REAL_DEVICE_COUNT=${_devices.length}');
    debugPrint('[HOME] DEVICE_STATUS=ONLINE');

    _reconcileOrphanedRoutinesForDevice(summary, devChannelCount);

    _markLocalChangesDirty();
    notifyListeners();
  }

  void _reconcileOrphanedRoutinesForDevice(ConnectedDeviceSummary newDevice, int channelCount) {
    unawaited(() async {
      try {
        final repo = const PreviewRoutineRepository();
        final routines = await repo.getRoutines();
        for (final routine in routines) {
          bool needsUpdate = false;
          final updatedActions = <RoutineAction>[];
          for (final action in routine.actions) {
            final activeDevExists = _devices.any((d) => d.id == action.deviceId);
            final targetRoom = action.targetRoomName ?? '';
            final roomMatches = targetRoom.isNotEmpty &&
                targetRoom.toLowerCase() == newDevice.roomName.toLowerCase();
            if (!activeDevExists && roomMatches) {
              if (action.channelIndex <= channelCount) {
                updatedActions.add(action.copyWith(
                  deviceId: newDevice.id,
                  targetRoomName: newDevice.roomName,
                ));
                needsUpdate = true;
                continue;
              }
            }
            updatedActions.add(action);
          }
          if (needsUpdate) {
            final draft = RoutineDraft(
              name: routine.name,
              icon: routine.icon,
              isFavorite: routine.isFavorite,
              trigger: routine.trigger,
              schedule: routine.schedule,
              conditions: routine.conditions,
              actions: updatedActions,
            );
            await repo.updateRoutine(routine.id, draft);
            debugPrint(
              '[ROUTINE] Re-linked orphaned routine "${routine.name}" to re-commissioned device ${newDevice.id} in ${newDevice.roomName}',
            );
            await EdgeRoutineSyncService.instance.syncRoutineToEdge(
              routine.copyWith(actions: updatedActions),
            );
          }
        }
      } catch (e) {
        debugPrint('[ROUTINE] Auto-reconciliation error: $e');
      }
    }());
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
    bool isToggle = false,
  }) async {
    if (!hardwareControlsAvailable) {
      debugPrint('[DEVICE] Command rejected: hardware controls unavailable (unauthenticated or offline)');
      _deviceConfidences[deviceId] = ActuatorConfidence.unavailable;
      _lightConfidence = ActuatorConfidence.unavailable;
      _lightCommandPending = false;
      notifyListeners();
      return;
    }

    final dev = _devices.cast<ConnectedDeviceSummary?>().firstWhere(
      (d) => d?.id == deviceId,
      orElse: () => null,
    );
    final isDevOnline = (_repository is FakeHomeRepository) ||
        (dev != null
            ? dev.online
            : LocalLanDeviceService.instance.isDeviceReachableOnLan(deviceId));
    if (!isDevOnline) {
      debugPrint('[DEVICE] Command rejected: device $deviceId is OFFLINE');
      _deviceConfidences[deviceId] = ActuatorConfidence.unavailable;
      _lightConfidence = ActuatorConfidence.unavailable;
      _lightCommandPending = false;
      notifyListeners();
      return;
    }

    final cmdKey1 = '${deviceId}_$channelIndex';
    final cmdKey2 = '${deviceId.toLowerCase()}_$channelIndex';
    final cmdKey3 = '${deviceId}_ch$channelIndex';
    final now = DateTime.now();
    final lastTime = _lastCommandTimestamps[cmdKey1] ?? _lastCommandTimestamps[cmdKey2] ?? _lastCommandTimestamps[cmdKey3];
    if (lastTime != null && now.difference(lastTime).inMilliseconds < 400 && _channelStates[deviceId]?[channelIndex] == value) {
      debugPrint('[DEVICE] Ignored rapid duplicate actuation for $cmdKey1 within 400ms');
      return;
    }

    // 0. Deterministic snapshot of verified previous state for rollback protection
    final previousChannelValue = _channelStates[deviceId]?[channelIndex] ?? !value;
    final previousLivingRoomState = _livingRoomLightOn;

    // Optimistically update UI in pending confidence state
    _channelStates.putIfAbsent(deviceId, () => {})[channelIndex] = value;
    _lastCommandTimestamps[cmdKey1] = now;
    _lastCommandTimestamps[cmdKey2] = now;
    _lastCommandTimestamps[cmdKey3] = now;
    final isLivingRoomDev = _devices.any((d) => d.id == deviceId && d.roomName.toLowerCase().contains('living'));
    if (channelIndex == 1 && isLivingRoomDev) {
      _livingRoomLightOn = value;
    }
    _deviceConfidences[deviceId] = ActuatorConfidence.pending;
    _lightCommandPending = true;
    _checkAndDispatchChannelAlert(deviceId, channelIndex, value);
    final chName = getDeviceChannelName(deviceId, channelIndex);
    recordActivityEvent(
      title: '$chName ${value ? "Turned ON" : "Turned OFF"}',
      message: 'Controlled $chName on ${_activeDisplayName ?? "Smart Device"}.',
      deviceId: deviceId,
    );
    debugPrint(
      '[DEVICE] COMMAND_SENT deviceId=$deviceId channel=$channelIndex enabled=$value (routingMode=$_routingMode)',
    );
    notifyListeners();

    // Rollback procedure to prevent any ghost states
    void rollback() {
      // If user has since toggled another command, do not overwrite with stale rollback
      if (_lastCommandTimestamps[cmdKey1] != now) return;

      _channelStates.putIfAbsent(deviceId, () => {})[channelIndex] = previousChannelValue;
      if (channelIndex == 1 && isLivingRoomDev) {
        _livingRoomLightOn = previousLivingRoomState;
      }
      _deviceConfidences[deviceId] = ActuatorConfidence.failed;
      _lightConfidence = ActuatorConfidence.failed;
      _lightCommandPending = false;
      debugPrint('[DEVICE] ACTUATION_FAILED_ROLLED_BACK deviceId=$deviceId channel=$channelIndex to $previousChannelValue');
      notifyListeners();
    }

    // Success confirmation procedure
    void confirmSuccess() {
      final confTime = DateTime.now();
      _lastCommandTimestamps[cmdKey1] = confTime;
      _lastCommandTimestamps[cmdKey2] = confTime;
      _lastCommandTimestamps[cmdKey3] = confTime;
      _deviceConfidences[deviceId] = ActuatorConfidence.confirmed;
      _lightConfidence = ActuatorConfidence.confirmed;
      _lightCommandPending = false;
      notifyListeners();
    }

    // 1. Cloud-Only Routing Mode: Route strictly via Cloud backend
    if (_routingMode == ConnectionRoutingMode.cloudOnly) {
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
          confirmSuccess();
          return;
        } else {
          rollback();
          return;
        }
      } catch (e) {
        debugPrint('[DEVICE] Cloud-only command error: $e');
        rollback();
        return;
      }
    }

    // 2. Local-LAN-Only Routing Mode: Route strictly via Direct Local Wi-Fi
    if (_routingMode == ConnectionRoutingMode.localOnly) {
      final localSuccess = await LocalLanDeviceService.instance.sendLocalControl(
        deviceId: deviceId,
        channelIndex: channelIndex,
        power: value,
        isToggle: isToggle,
      );
      if (localSuccess) {
        confirmSuccess();
      } else {
        rollback();
      }
      return;
    }

    // 3. Smart Auto Routing: Prioritize Local LAN for instant response, fall back to Cloud
    final localIp = LocalLanDeviceService.instance.getDeviceIp(deviceId);
    if (localIp != null || _isLocalMode || !_isCloudReachable) {
      final localSuccess = await LocalLanDeviceService.instance.sendLocalControl(
        deviceId: deviceId,
        channelIndex: channelIndex,
        power: value,
        isToggle: isToggle,
      );
      if (localSuccess) {
        _isLocalMode = true;
        _deviceMissedPolls[deviceId] = 0;
        _lanMissedPollCount = 0;
        _channelStates.putIfAbsent(deviceId, () => {})[channelIndex] = value;
        for (int i = 0; i < _devices.length; i++) {
          if (_devices[i].id == deviceId && (!_devices[i].online || _devices[i].signalLabel != 'Local Wi-Fi')) {
            _devices[i] = _devices[i].copyWith(
              signalLabel: 'Local Wi-Fi',
              online: true,
            );
          }
        }
        confirmSuccess();
        debugPrint('[DEVICE] DIRECT_LOCAL_LAN_SUCCESS deviceId=$deviceId channel=$channelIndex');
        return;
      }
    }

    // Fallback: Attempt Cloud MQTT/REST
    bool commandHandled = false;
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
        confirmSuccess();
        commandHandled = true;
      }
    } catch (e) {
      debugPrint('[DEVICE] Cloud command failed ($e), falling back to Local LAN...');
    }

    if (!commandHandled) {
      final localSuccess = await LocalLanDeviceService.instance.sendLocalControl(
        deviceId: deviceId,
        channelIndex: channelIndex,
        power: value,
      );
      if (localSuccess) {
        _isLocalMode = true;
        _deviceMissedPolls[deviceId] = 0;
        _lanMissedPollCount = 0;
        _channelStates.putIfAbsent(deviceId, () => {})[channelIndex] = value;
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
        confirmSuccess();
        debugPrint('[DEVICE] LOCAL_LAN_COMMAND_SUCCESS deviceId=$deviceId channel=$channelIndex');
      } else {
        // Complete failure across both transports -> Rollback immediately!
        rollback();
      }
    }
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
        homeId: _activeHomeId ?? _activeSpaceId,
        iconKey: iconKey,
      );
    } catch (e) {
      debugPrint('[HOME] Failed to persist room to cloud: $e');
    }

    await _storageService.addRoom(trimmed);
    await _storageService.addRoomForSpace(_activeSpaceId, trimmed);
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
      await ChangeTrackingService.instance.recordChange(
        entityType: 'room',
        entityId: roomId,
        field: 'name',
        oldValue: null,
        newValue: trimmed,
        changeType: ChangeType.created,
      );
      _markLocalChangesDirty();
      notifyListeners();
    }
  }

  Future<void> moveDeviceToRoom(String deviceId, String newRoomName) async {
    final trimmedRoom = newRoomName.trim().isEmpty ? 'Unassigned' : newRoomName.trim();
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
      await _storageService.saveDeviceForSpace(_activeSpaceId, updated);
      if (trimmedRoom.toLowerCase() != 'unassigned') {
        await _storageService.addRoom(trimmedRoom);
        await _storageService.addRoomForSpace(_activeSpaceId, trimmedRoom);
      }
      _customEmptyRooms.removeWhere((r) => r.name.toLowerCase() == trimmedRoom.toLowerCase());
      if (_connectedDeviceSummary?.id == deviceId) {
        _connectedDeviceSummary = updated;
      }

      // Re-link room quick controls
      final isSocket = old.name.toLowerCase().contains('socket') || old.model.toLowerCase().contains('socket');
      final is4X = old.name.toLowerCase().contains('4x') || old.model.toLowerCase().contains('4x');
      final is3X = old.name.toLowerCase().contains('3x') || old.model.toLowerCase().contains('3x');
      final is2X = old.name.toLowerCase().contains('2x') || old.model.toLowerCase().contains('2x');
      final is1X = old.name.toLowerCase().contains('1x') || old.model.toLowerCase().contains('1x');
      final count = is4X ? 4 : (is3X ? 3 : (is2X ? 2 : (is1X ? 1 : (isSocket ? 3 : 4))));
      final controlIds = List.generate(count, (i) => '${deviceId}_ch${i + 1}');
      DeviceStorageService.saveRoomQuickControls(trimmedRoom, controlIds);

      // Re-sync with backend if cloud connected
      if (_activeHomeId != null) {
        try {
          final matchingBackendRoom = _backendRooms.cast<Room?>().firstWhere(
            (br) => br?.name.toLowerCase() == trimmedRoom.toLowerCase(),
            orElse: () => null,
          );
          await _repository.claimDevice(
            deviceId: deviceId,
            homeId: _activeHomeId!,
            roomId: matchingBackendRoom?.id,
            customName: old.name,
          );
        } catch (e) {
          debugPrint('[HOME] Warning: Could not update device room on backend: $e');
        }
      }

      debugPrint('[HOME] Device $deviceId moved to room: $trimmedRoom');
      await ChangeTrackingService.instance.recordChange(
        entityType: 'device',
        entityId: deviceId,
        field: 'room',
        oldValue: old.roomName,
        newValue: trimmedRoom,
        changeType: ChangeType.modified,
      );
      _markLocalChangesDirty();
      notifyListeners();
    }
  }

  /// Transfers a device to another space partition (e.g. from Home to Office).
  Future<void> transferDeviceToSpace(String deviceId, String targetSpaceId) async {
    final idx = _devices.indexWhere((d) => d.id == deviceId);
    if (idx >= 0) {
      final dev = _devices[idx];
      // 1. Save in target space partition
      await _storageService.saveDeviceForSpace(targetSpaceId, dev);
      // 2. Remove from active space partition
      _devices.removeAt(idx);
      await _storageService.removeDeviceForSpace(_activeSpaceId, deviceId);
      
      if (_connectedDeviceSummary?.id == deviceId) {
        _connectedDeviceSummary = _devices.isNotEmpty ? _devices.first : null;
        _activeDeviceId = _devices.isNotEmpty ? _devices.first.id : '';
        _activeDisplayName = _devices.isNotEmpty ? _devices.first.name : '';
        _activeSerialNumber = _devices.isNotEmpty ? _devices.first.model : '';
      }
      _spaceDevicesCache[_activeSpaceId] = List.from(_devices);
      final targetDevs = List<ConnectedDeviceSummary>.from(await _storageService.loadDevicesForSpace(targetSpaceId));
      _spaceDevicesCache[targetSpaceId] = targetDevs;
      debugPrint('[HOME] Device $deviceId transferred from $_activeSpaceId to $targetSpaceId');
      await ChangeTrackingService.instance.recordChange(
        entityType: 'device',
        entityId: deviceId,
        field: 'space',
        oldValue: _activeSpaceId,
        newValue: targetSpaceId,
        changeType: ChangeType.modified,
      );
      _markLocalChangesDirty();
      notifyListeners();
    }
  }

  /// Removes device from the current app account/home space.
  /// Hardware keeps its Wi-Fi credentials intact.
  Future<void> removeDevice(String deviceId) async {
    final devName = _devices.firstWhere(
      (d) => d.id == deviceId,
      orElse: () => ConnectedDeviceSummary(
        id: deviceId,
        name: deviceId,
        model: '',
        firmware: '',
        connectedVia: '',
        signalLabel: '',
        roomName: '',
        online: false,
      ),
    ).name;
    await DeviceStorageService.addDeletedDeviceId(deviceId);
    LocalLanDeviceService.instance.unregisterDeviceIp(deviceId);
    LocalLanDeviceService.instance.markDeviceOfflineOnLan(deviceId);
    _devices.removeWhere((d) => d.id == deviceId);
    _channelStates.remove(deviceId);
    _deviceMissedPolls.remove(deviceId);
    _selectedQuickControlIds.removeWhere((id) => id.startsWith('${deviceId}_') || id == deviceId);
    _favouriteControlIds.removeWhere((id) => id.startsWith('${deviceId}_') || id == deviceId);
    await DeviceStorageService.clearChannelLabelsForDevice(deviceId);
    await _storageService.removeDevice(deviceId);
    await _storageService.removeDeviceForSpace(_activeSpaceId, deviceId);
    await _storageService.saveQuickControlsForSpace(_activeSpaceId, _selectedQuickControlIds);
    await _storageService.saveFavouritesForSpace(_activeSpaceId, _favouriteControlIds);
    await ChangeTrackingService.instance.recordChange(
      entityType: 'device',
      entityId: deviceId,
      field: 'device',
      oldValue: devName,
      newValue: null,
      changeType: ChangeType.deleted,
    );

    if (_connectedDeviceSummary?.id == deviceId) {
      _connectedDeviceSummary = _devices.isNotEmpty ? _devices.first : null;
      _activeDeviceId = _devices.isNotEmpty ? _devices.first.id : null;
      _activeDisplayName = _devices.isNotEmpty ? _devices.first.name : null;
      _activeSerialNumber = _devices.isNotEmpty ? _devices.first.model : null;
    }
    if (_devices.isEmpty) {
      _channelStates.clear();
      _activeDeviceId = null;
      _activeDisplayName = null;
      _activeSerialNumber = null;
      _connectedDeviceSummary = null;
      _livingRoomLightOn = false;
      _selectedQuickControlIds.clear();
      _favouriteControlIds.clear();
      _connectionState = HomeConnectionState.notConfigured;
      _connectionMessage = 'No devices in $_activeSpaceName yet.';
    }
    _spaceDevicesCache[_activeSpaceId] = List.from(_devices);
    debugPrint('[HOME] Device removed from app: $deviceId');

    try {
      await _repository.removeDevice(deviceId: deviceId, homeId: _activeHomeId);
    } catch (e) {
      debugPrint('[HOME] Cloud repository removeDevice error (persisted locally as deleted): $e');
    }

    _markLocalChangesDirty();
    notifyListeners();
  }

  /// Forgets the device, sending a factory reset command to the board
  /// to wipe Wi-Fi credentials and return it to BLE pairing mode,
  /// then deletes all local metadata from the app.
  Future<bool> forgetDevice(String deviceId) async {
    bool resetSent = false;
    try {
      resetSent = await LocalLanDeviceService.instance.sendFactoryReset(deviceId: deviceId);
    } catch (e) {
      debugPrint('[HOME] forgetDevice factory reset command error: $e');
    }

    await removeDevice(deviceId);
    debugPrint('[HOME] Device forgotten and factory reset triggered for $deviceId (reset_signal_sent=$resetSent)');
    notifyListeners();
    return resetSent;
  }

  Future<void> renameDevice(String deviceId, String newName) async {
    final trimmed = newName.trim();
    if (trimmed.isEmpty) return;
    final idx = _devices.indexWhere((d) => d.id == deviceId);
    if (idx >= 0) {
      final old = _devices[idx];
      final updated = ConnectedDeviceSummary(
        id: old.id,
        name: trimmed,
        model: old.model,
        firmware: old.firmware,
        connectedVia: old.connectedVia,
        signalLabel: old.signalLabel,
        roomName: old.roomName,
        online: old.online,
      );
      _devices[idx] = updated;
      await _storageService.saveDeviceForSpace(_activeSpaceId, updated);
      if (_connectedDeviceSummary?.id == deviceId) {
        _connectedDeviceSummary = updated;
        _activeDisplayName = trimmed;
      }
      _spaceDevicesCache[_activeSpaceId] = List.from(_devices);
      if (_repository is CloudHomeRepository) {
        try {
          await _repository.claimDevice(
            deviceId: deviceId,
            homeId: _activeHomeId ?? _activeSpaceId,
            customName: trimmed,
          );
        } catch (_) {}
      }
      await ChangeTrackingService.instance.recordChange(
        entityType: 'device',
        entityId: deviceId,
        field: 'name',
        oldValue: old.name,
        newValue: trimmed,
        changeType: ChangeType.modified,
      );
      _markLocalChangesDirty();
      notifyListeners();
    }
  }

  Future<void> saveQuickControlSelection(List<String> controlIds) async {
    _selectedQuickControlIds = List.from(controlIds);
    await _storageService.saveQuickControls(_selectedQuickControlIds);
    await _storageService.saveQuickControlsForSpace(_activeSpaceId, _selectedQuickControlIds);
    await ChangeTrackingService.instance.recordChange(
      entityType: 'quick_controls',
      entityId: _activeSpaceId,
      field: 'quickControls',
      oldValue: null,
      newValue: '${controlIds.length} items',
      changeType: ChangeType.modified,
    );
    _markLocalChangesDirty();
    notifyListeners();
  }

  Future<void> updateNotificationPreference(String key, bool value) async {
    _notificationPrefs[key] = value;
    await _storageService.saveNotificationPrefs({key: value});
    await ChangeTrackingService.instance.recordChange(
      entityType: 'notification_preference',
      entityId: key,
      field: key,
      oldValue: null,
      newValue: value.toString(),
      changeType: ChangeType.modified,
    );
    _markLocalChangesDirty();
    notifyListeners();
  }

  String getDeviceChannelName(String deviceId, int channelIndex) {
    final saved = DeviceStorageService.getChannelLabels(deviceId);
    if (saved.containsKey(channelIndex) && saved[channelIndex]!.trim().isNotEmpty) {
      return saved[channelIndex]!;
    }
    return 'Switch $channelIndex';
  }

  // --- Channel Activity Notification Alert Settings ---
  ChannelAlertConfig getChannelAlertConfig(String deviceId, int channelIndex) {
    return DeviceStorageService.getChannelAlertConfig(deviceId, channelIndex);
  }

  Future<void> setChannelAlertConfig(String deviceId, int channelIndex, ChannelAlertConfig config) async {
    await DeviceStorageService.saveChannelAlertConfig(deviceId, channelIndex, config);
    String? cloudId;
    if (_devices.isNotEmpty) {
      final match = _devices.firstWhere(
        (d) => d.id == deviceId || d.name.toLowerCase() == deviceId.toLowerCase(),
        orElse: () => _devices.first,
      );
      cloudId = match.id;
      if (cloudId != deviceId) {
        await DeviceStorageService.saveChannelAlertConfig(cloudId, channelIndex, config);
      }
    }

    await ChangeTrackingService.instance.recordChange(
      entityType: 'channel_alert',
      entityId: '$deviceId:ch$channelIndex',
      field: 'alertConfig',
      oldValue: null,
      newValue: 'updated',
      changeType: ChangeType.modified,
    );
    _markLocalChangesDirty();
    notifyListeners();

    if (_isCloudReachable && _repository is CloudHomeRepository) {
      try {
        final repo = _repository;
        final targetDevId = (cloudId != null && cloudId.isNotEmpty) ? cloudId : deviceId;
        await repo.updateChannelConfig(
          deviceId: targetDevId,
          channelIndex: channelIndex,
          config: config.toJson(),
        );
      } catch (e) {
        debugPrint('[HOME] setChannelAlertConfig cloud update error: $e');
      }
    }
  }

  void recordActivityEvent({
    required String title,
    required String message,
    String? deviceId,
    AlertSeverity severity = AlertSeverity.informational,
  }) {
    final alertItem = SpaceAlertItem(
      id: 'act_${DateTime.now().millisecondsSinceEpoch}',
      spaceId: _activeSpaceId,
      spaceName: _activeSpaceName,
      title: title,
      message: message,
      severity: severity,
      timestamp: DateTime.now(),
      deviceId: deviceId,
    );
    _activityAlerts.insert(0, alertItem);
    if (_activityAlerts.length > 30) {
      _activityAlerts.removeLast();
    }
    unawaited(DeviceStorageService.saveActivityAlerts(_activityAlerts));
    notifyListeners();
  }

  void _checkAndDispatchChannelAlert(String deviceId, int channelIndex, bool newPower) {
    final config = DeviceStorageService.getChannelAlertConfig(deviceId, channelIndex);
    if (config.enabled) {
      if ((newPower && config.alertOnTurnOn) || (!newPower && config.alertOnTurnOff)) {
        final chName = getDeviceChannelName(deviceId, channelIndex);
        
        // Resolve owner space of this device
        String devSpaceId = _activeSpaceId;
        String devSpaceName = _activeSpaceName;
        ConnectedDeviceSummary? dev = _devices.cast<ConnectedDeviceSummary?>().firstWhere(
          (d) => d?.id == deviceId,
          orElse: () => null,
        );

        if (dev == null) {
          for (final sp in _spaces) {
            final spId = sp['id'] as String;
            final list = _spaceDevicesCache[spId];
            final match = list?.cast<ConnectedDeviceSummary?>().firstWhere(
              (d) => d?.id == deviceId,
              orElse: () => null,
            );
            if (match != null) {
              dev = match;
              devSpaceId = spId;
              devSpaceName = sp['name'] as String;
              break;
            }
          }
        }

        final devName = dev?.name ?? 'Smart Switch';
        final defaultMsg = '$chName is now ${newPower ? 'ON' : 'OFF'} on $devName';
        final alertMsg = config.customMessage.trim().isNotEmpty ? config.customMessage.trim() : defaultMsg;

        final alertItem = SpaceAlertItem(
          id: 'act_${deviceId}_${channelIndex}_${DateTime.now().millisecondsSinceEpoch}',
          spaceId: devSpaceId,
          spaceName: devSpaceName,
          title: '$devName • $chName Alert',
          message: alertMsg,
          severity: AlertSeverity.warning,
          timestamp: DateTime.now(),
          deviceId: deviceId,
        );

        // Reset dismissal for this channel & unsuppress alert card
        _dismissedAlertIds.removeWhere((id) => id.startsWith('act_${deviceId}_$channelIndex'));
        _alertAcknowledged = false;

        _activityAlerts.insert(0, alertItem);
        if (_activityAlerts.length > 20) {
          _activityAlerts.removeLast();
        }
        unawaited(DeviceStorageService.saveActivityAlerts(_activityAlerts));

        // Broadcast to in-app listeners (SnackBars / toast notifications)
        _channelAlertStreamController.add(alertItem);

        notifyListeners();
      }
    }
  }

  // --- Connection Routing Mode Controls ---
  Future<void> setRoutingMode(ConnectionRoutingMode mode) async {
    _routingMode = mode;
    final modeStr = mode == ConnectionRoutingMode.localOnly
        ? 'localOnly'
        : mode == ConnectionRoutingMode.cloudOnly
            ? 'cloudOnly'
            : 'auto';
    await DeviceStorageService.setConnectionRoutingMode(modeStr);

    if (mode == ConnectionRoutingMode.localOnly) {
      _autoModeLanPromotionTimer?.cancel();
      _isLocalMode = true;
      _isCloudReachable = false;
      _connectionMessage = 'Locked to Local Wi-Fi Mode (Direct LAN)';
      await switchToLanMode(isBackground: true);
    } else if (mode == ConnectionRoutingMode.cloudOnly) {
      _autoModeLanPromotionTimer?.cancel();
      _isLocalMode = false;
      _isCloudReachable = true;
      _connectionMessage = 'Locked to Cloud Mode (Remote Internet)';
      await loadHomeData(isBackground: true);
    } else {
      _connectionMessage = 'Smart Auto-Routing Mode Active';
      _startAutoModeLanPromotionTimer();
      await loadHomeData(isBackground: true);
    }
    recordActivityEvent(
      title: 'Routing Mode: ${mode.name.toUpperCase()}',
      message: _connectionMessage ?? 'Connection mode updated.',
    );
    notifyListeners();
  }

  // --- Cloud Sync & Conflict Resolution Center ---
  void _markLocalChangesDirty() {
    _hasPendingCloudUpload = true;
    DeviceStorageService.setPendingCloudUpload(true);
    if (_syncMode == SyncMode.auto && _isCloudReachable) {
      uploadLocalChangesToCloud();
    }
    notifyListeners();
  }

  Future<void> setSyncMode(SyncMode mode) async {
    _syncMode = mode;
    await DeviceStorageService.setSyncMode(mode == SyncMode.auto ? 'auto' : 'manual');
    if (mode == SyncMode.auto && _hasPendingCloudUpload) {
      await uploadLocalChangesToCloud();
    }
    notifyListeners();
  }

  Future<bool> uploadLocalChangesToCloud() async {
    _isLoading = true;
    notifyListeners();

    final previousRoutingMode = _routingMode;
    final wasLocalMode = _isLocalMode;

    try {
      final repo = _repository;
      if (repo is CloudHomeRepository) {
        for (final s in _spaces) {
          final sName = s['name'] as String;
          final sId = s['id'] as String;
          try {
            if (sId.startsWith('space_') || sId == 'home_default') {
              final created = await repo.createHome(sName);
              if (created['id'] != null) {
                s['id'] = created['id'].toString();
              }
            } else {
              await repo.updateHome(sId, sName);
            }
          } catch (_) {}
        }
        await _storageService.saveSpaces(_spaces);

        final deletedRooms = DeviceStorageService.deletedRooms;
        if (deletedRooms.isNotEmpty) {
          try {
            final cloudRooms = await repo.getRooms(homeId: _activeHomeId);
            for (final cr in cloudRooms) {
              final crName = (cr['name'] ?? '').toString().trim();
              if (deletedRooms.contains(crName)) {
                final rId = (cr['id'] ?? cr['roomId'])?.toString();
                if (rId != null && rId.isNotEmpty) {
                  await repo.deleteRoom(rId);
                }
              }
            }
          } catch (e) {
            debugPrint('[HOME] deleteRoom sync error: $e');
          }
        }

        final savedRooms = await _storageService.loadRooms();
        for (final r in savedRooms) {
          if (deletedRooms.contains(r)) continue;
          try {
            await repo.createRoom(name: r, homeId: _activeHomeId);
          } catch (_) {}
        }

        // Query cloud rooms to obtain valid room IDs for device claiming
        final Map<String, String> roomNameToId = {};
        try {
          final cloudRooms = await repo.getRooms(homeId: _activeHomeId);
          for (final cr in cloudRooms) {
            final name = (cr['name'] ?? cr['label'] ?? '').toString().trim().toLowerCase();
            final id = (cr['id'] ?? cr['roomId'] ?? '').toString();
            if (name.isNotEmpty && id.isNotEmpty) {
              roomNameToId[name] = id;
            }
          }
        } catch (_) {}

        for (final d in _devices) {
          final canonicalVariant = MockProductCatalogRepository.resolveCanonicalProductVariant(
            variantId: d.model,
            deviceName: d.name,
          );
          final isSocket = canonicalVariant.contains('socket');

          final firmwareFamily = isSocket ? 'esp32c6-socket-platform' : 'esp32c6-switch-platform';
          final hwRevision = 'HW_1_0';

          try {
            await repo.registerDevice(
              deviceId: d.id,
              serialNumber: 'EH-${canonicalVariant.toUpperCase()}-${d.id.substring(0, math.min(d.id.length, 6))}',
              productVariantId: canonicalVariant,
              hardwareRevision: hwRevision,
              firmwareFamily: firmwareFamily,
              firmwareVersion: d.firmware.isNotEmpty ? d.firmware : '1.0.0',
            );
          } catch (_) {}

          // Determine target room ID for clean room association
          String? targetRoomId;
          final cleanRoom = d.roomName.trim();
          if (cleanRoom.isNotEmpty && cleanRoom.toLowerCase() != 'unassigned' && cleanRoom.toLowerCase() != 'home') {
            targetRoomId = roomNameToId[cleanRoom.toLowerCase()];
            if (targetRoomId == null || targetRoomId.isEmpty) {
              try {
                final created = await repo.createRoom(name: cleanRoom, homeId: _activeHomeId);
                if (created.containsKey('id')) {
                  targetRoomId = created['id'].toString();
                  roomNameToId[cleanRoom.toLowerCase()] = targetRoomId;
                }
              } catch (_) {}
            }
          }

          try {
            final channelLabels = DeviceStorageService.getChannelLabels(d.id);
            await repo.claimDevice(
              deviceId: d.id,
              homeId: _activeHomeId ?? _activeSpaceId,
              roomId: targetRoomId,
              customName: d.name,
              channelLabels: channelLabels.map((k, v) => MapEntry(k.toString(), v)),
            );
            for (final entry in channelLabels.entries) {
              await repo.renameChannel(
                deviceId: d.id,
                channelIndex: entry.key,
                newName: entry.value,
              );
            }
            final allAlertConfigs = DeviceStorageService.getAllChannelAlertConfigsForDevice(d.id);
            if (allAlertConfigs.isNotEmpty) {
              await repo.updateAllChannelConfigs(
                deviceId: d.id,
                channelConfigs: allAlertConfigs,
              );
            }
          } catch (_) {}
        }

        // Also sync local offline automations/routines to backend for 24/7 autonomous execution
        try {
          final routines = (await const PreviewRoutineRepository().getRoutines())
              .where((r) => !DeviceStorageService.isRoutineDeleted(r.id, routineName: r.name))
              .toList();
          final targetHome = _activeHomeId ?? _activeSpaceId;
          final cloudRoutines = await CloudRoutineRepository(repo.client).getRoutines();
          final localNames = routines.map((r) => r.name.toLowerCase().trim()).toSet();
          final localIds = routines.map((r) => r.id).toSet();
          final deletedIds = DeviceStorageService.deletedRoutineIds;

          for (final cr in cloudRoutines) {
            final crName = cr.name.toLowerCase().trim();
            if (deletedIds.contains(cr.id) ||
                deletedIds.contains(crName) ||
                (!localNames.contains(crName) && !localIds.contains(cr.id))) {
              try {
                await repo.client.delete('/api/v1/homes/$targetHome/automations/${cr.id}');
              } catch (_) {}
            }
          }

          final existingNames = cloudRoutines
              .where((cr) => !deletedIds.contains(cr.id) && !deletedIds.contains(cr.name.toLowerCase().trim()) && localNames.contains(cr.name.toLowerCase().trim()))
              .map((a) => a.name.toLowerCase().trim())
              .toSet();
          for (final r in routines) {
            if (existingNames.contains(r.name.toLowerCase().trim())) {
              continue; // Avoid recreating duplicate automations
            }
            final triggerType = r.trigger.kind == RoutineTriggerKind.timeSchedule ? 'TIME' : 'MANUAL';
            await repo.createAutomation(
              homeId: targetHome,
              name: r.name,
              triggerType: triggerType,
              triggerConfig: {
                'kind': r.trigger.kind.name,
                'time': r.trigger.timeOfDay ?? '',
                'days': r.schedule.days,
              },
              actions: r.actions.map((a) => {
                'deviceId': a.deviceId,
                'channel': a.channelIndex,
                'channelIndex': a.channelIndex,
                'action': 'setPower',
                'parameters': {'value': a.targetState, 'enabled': a.targetState},
              }).toList(),
            );
          }
        } catch (_) {}
      }

      await DeviceStorageService.recordCloudSyncSuccess();
      await ChangeTrackingService.instance.clearChanges();
      _hasPendingCloudUpload = false;
      _lastCloudSyncTime = DateTime.now();
      return true;
    } catch (e) {
      debugPrint('[HOME] uploadLocalChangesToCloud error: $e');
      return false;
    } finally {
      // If user was previously in Local-Only or Auto LAN mode, smoothly restore their operational mode
      if (previousRoutingMode == ConnectionRoutingMode.localOnly) {
        _routingMode = ConnectionRoutingMode.localOnly;
        _isLocalMode = true;
        _isCloudReachable = false;
      } else if (wasLocalMode && previousRoutingMode == ConnectionRoutingMode.auto) {
        _routingMode = ConnectionRoutingMode.auto;
        _isLocalMode = true;
      }
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> downloadCloudChanges() async {
    _isLoading = true;
    notifyListeners();
    try {
      final repo = _repository;
      if (repo is CloudHomeRepository) {
        // 1. Download Homes / Spaces from Cloud
        try {
          final cloudHomes = await repo.getHomes();
          if (cloudHomes.isNotEmpty) {
            _spaces.clear();
            _spaces.addAll(cloudHomes.map((h) => {
              'id': h['id'].toString(),
              'name': (h['name'] ?? 'Home').toString(),
            }));
            await _storageService.saveSpaces(_spaces);
            if (_spaces.isNotEmpty) {
              final firstId = _spaces.first['id'] as String;
              _activeSpaceId = firstId;
              _activeHomeId = firstId;
              repo.setActiveHomeId(firstId);
            }
          }
        } catch (e) {
          debugPrint('[HOME] download spaces warning: $e');
        }

        // 2. Clear any deleted rooms marks so cloud rooms can be restored
        for (final r in List.from(DeviceStorageService.deletedRooms)) {
          DeviceStorageService.restoreRoom(r);
        }

        // 3. Download Rooms from Cloud
        try {
          final cloudRooms = await repo.getRooms(homeId: _activeHomeId);
          final roomNames = cloudRooms
              .map((r) => (r['name'] ?? r['label'] ?? '').toString().trim())
              .where((n) => n.isNotEmpty)
              .toList();
          if (roomNames.isNotEmpty) {
            await _storageService.saveRooms(roomNames);
          }
        } catch (e) {
          debugPrint('[HOME] download rooms warning: $e');
        }

        // 4. Download Devices and Channel Configurations from Cloud
        try {
          final cloudDevices = await repo.getDevices(homeId: _activeHomeId);
          if (cloudDevices.isNotEmpty) {
            final mappedDevices = <ConnectedDeviceSummary>[];
            for (final d in cloudDevices) {
              await DeviceStorageService.removeDeletedDeviceId(d.id);
              final resolvedVariant = MockProductCatalogRepository.resolveCanonicalProductVariant(
                variantId: d.productVariantId,
                deviceName: d.name,
                hardwareModel: d.hardwareRevision,
              );

              final finalRoom = (d.roomName.isNotEmpty && d.roomName.toLowerCase() != 'home')
                  ? d.roomName
                  : 'Unassigned';

              mappedDevices.add(
                ConnectedDeviceSummary(
                  id: d.id,
                  name: d.name,
                  model: resolvedVariant,
                  firmware: d.firmwareVersion,
                  connectedVia: 'Wi-Fi (Cloud)',
                  signalLabel: d.connection == DeviceConnection.online ? 'Strong' : 'Offline',
                  roomName: finalRoom,
                  online: d.connection == DeviceConnection.online,
                ),
              );
            }
            await _storageService.saveDevicesForSpace(_activeSpaceId, mappedDevices);
            _spaceDevicesCache[_activeSpaceId] = List.from(mappedDevices);

            // Re-populate Quick Controls if empty
            if (_selectedQuickControlIds.isEmpty && mappedDevices.isNotEmpty) {
              final initialQuickIds = <String>[];
              for (final dev in mappedDevices) {
                final canonical = MockProductCatalogRepository.resolveCanonicalProductVariant(
                  variantId: dev.model,
                  deviceName: dev.name,
                );
                final nameLower = dev.name.toLowerCase();
                final is4X = nameLower.contains('4x') || canonical.contains('4x');
                final is3X = nameLower.contains('3x') || canonical.contains('3x');
                final is2X = nameLower.contains('2x') || canonical.contains('2x');
                final is1X = nameLower.contains('1x') || canonical.contains('1x');
                final count = is4X ? 4 : (is3X ? 3 : (is2X ? 2 : (is1X ? 1 : 2)));
                for (int ch = 1; ch <= count; ch++) {
                  initialQuickIds.add('${dev.id}_ch$ch');
                }
              }
              _selectedQuickControlIds = initialQuickIds;
              await _storageService.saveQuickControlsForSpace(_activeSpaceId, initialQuickIds);
              await _storageService.saveQuickControls(initialQuickIds);
            }
          }
        } catch (e) {
          debugPrint('[HOME] download devices warning: $e');
        }

        // 5. Download Automations / Routines from Cloud
        try {
          final cloudRoutines = await CloudRoutineRepository(repo.client).getRoutines();
          if (cloudRoutines.isNotEmpty) {
            await PreviewRoutineRepository.syncWithCloudRoutines(cloudRoutines);
          }
          await refreshUpcomingRoutines();
        } catch (e) {
          debugPrint('[HOME] download routines warning: $e');
        }
      }

      await loadHomeData();
      await DeviceStorageService.recordCloudSyncSuccess();
      await ChangeTrackingService.instance.clearChanges();
      _hasPendingCloudUpload = false;
      _lastCloudSyncTime = DateTime.now();
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('[HOME] downloadCloudChanges error: $e');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Timer? _routineSchedulerTimer;
  final Map<String, String> _lastRoutineExecutionMinutes = {};

  final Set<String> _activeRoutineKeys = {};

  /// Returns the active routine currently executing on the specified channel, or null if none
  Routine? getActiveRoutineForChannel(String deviceId, int channelIndex) {
    final currentPower = getDeviceChannelPower(deviceId, channelIndex);

    for (final r in PreviewRoutineRepository.liveRoutines) {
      if (!r.enabled) continue;

      final hasAction = r.actions.any((a) {
        final matchesDevice = a.deviceId.isEmpty ||
            a.deviceId == 'all' ||
            a.deviceId == 'all_sockets' ||
            a.deviceId == deviceId ||
            a.deviceId.toLowerCase() == deviceId.toLowerCase() ||
            (a.deviceId == 'default' && (devices.length <= 1 || deviceId == _activeDeviceId));
        final matchesChannel = a.channelIndex == 0 ||
            a.kind == RoutineActionKind.allChannels ||
            a.channelIndex == channelIndex;
        return matchesDevice && matchesChannel;
      });
      if (!hasAction) continue;

      if (EdgeRoutineSyncService.instance.isRoutineCurrentlyActive(
        r,
        targetChannel: channelIndex,
        currentPower: currentPower,
      )) {
        return r;
      }
    }
    return null;
  }

  void _startRoutineScheduler() {
    _routineSchedulerTimer?.cancel();
    unawaited(EdgeRoutineSyncService.instance.reconcileAllRoutinesToEdge());
    _routineSchedulerTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _evaluateScheduledRoutines();
    });
  }

  Future<void> _evaluateScheduledRoutines() async {
    if (_disposed) return;
    try {
      final now = DateTime.now();
      final minuteKey = '${now.year}-${now.month}-${now.day}-${now.hour}:${now.minute}';

      final repo = const PreviewRoutineRepository();
      final routines = await repo.getRoutines();
      for (final r in routines) {
        if (!r.enabled) continue;
        if (_lastRoutineExecutionMinutes[r.id] == minuteKey) {
          continue;
        }
        if (r.trigger.kind == RoutineTriggerKind.timeSchedule) {
          final trig = r.trigger;
          final sched = r.schedule;
          bool timeMatches = false;

          final label = trig.detail.isNotEmpty ? trig.detail : sched.label;
          if (trig.days.isNotEmpty) {
            const dayMap = {1: 'Mon', 2: 'Tue', 3: 'Wed', 4: 'Thu', 5: 'Fri', 6: 'Sat', 7: 'Sun'};
            final currentDay = dayMap[now.weekday] ?? '';
            final matchesDay = currentDay.isNotEmpty &&
                trig.days.any((d) => d.toLowerCase().startsWith(currentDay.toLowerCase()));
            if (!matchesDay) continue;
          }

          final timeRegex = RegExp(r'(\d{1,2}):(\d{2})\s*(AM|PM)?', caseSensitive: false);
          final match = timeRegex.firstMatch(label);
          if (match != null) {
            int h = int.parse(match.group(1)!);
            final m = int.parse(match.group(2)!);
            final ampm = match.group(3)?.toUpperCase();
            if (ampm == 'PM' && h < 12) h += 12;
            if (ampm == 'AM' && h == 12) h = 0;

            if (now.hour == h && now.minute == m) {
              timeMatches = true;
            }
          }

          if (timeMatches) {
            _lastRoutineExecutionMinutes[r.id] = minuteKey;
            final hasLanDevice = r.involvedDevices.any((d) => LocalLanDeviceService.instance.isDeviceReachableOnLan(d.id));
            if (!hasLanDevice) {
              debugPrint('[ROUTINE] Cloud/App fallback firing routine: ${r.name} (${r.id}) at $now');
              await repo.executeRoutine(r.id);
            } else {
              debugPrint('[ROUTINE] Edge ESP32 device handling routine "${r.name}" autonomously on hardware.');
            }
            recordActivityEvent(
              title: 'Routine executed: ${r.name}',
              message: 'Executed scheduled routine "${r.name}" successfully.',
              deviceId: r.involvedDevices.isNotEmpty ? r.involvedDevices.first.id : 'routine',
            );
          }
        }
      }
      if (_lastRoutineExecutionMinutes.length > 50) {
        _lastRoutineExecutionMinutes.removeWhere((k, v) => v != minuteKey);
      }

      // Automatically detect when a routine completes its pulse duration
      // and notify listeners so the UI clears the warning overlay immediately.
      final currentActiveKeys = <String>{};
      for (final dev in _devices) {
        for (int ch = 1; ch <= 4; ch++) {
          final activeR = getActiveRoutineForChannel(dev.id, ch);
          if (activeR != null) {
            currentActiveKeys.add('${dev.id}_$ch');
          }
        }
      }
      if (!setEquals(_activeRoutineKeys, currentActiveKeys)) {
        _activeRoutineKeys
          ..clear()
          ..addAll(currentActiveKeys);
        notifyListeners();
      }
    } catch (e) {
      debugPrint('[ROUTINE] Error evaluating scheduled routines: $e');
    }
  }

  bool _disposed = false;

  @override
  void notifyListeners() {
    if (_disposed) return;
    super.notifyListeners();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_disposed) return;
    if (state == AppLifecycleState.resumed) {
      debugPrint('[HOME] App resumed: triggering instant quiet sync');
      unawaited(_quietSyncDeviceStates());
      if (_routingMode == ConnectionRoutingMode.auto || _routingMode == ConnectionRoutingMode.localOnly) {
        unawaited(probeLanAndPromote());
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    try {
      WidgetsBinding.instance.removeObserver(this);
    } catch (_) {}
    _routineSchedulerTimer?.cancel();
    _autoSyncTimer?.cancel();
    _autoModeLanPromotionTimer?.cancel();
    _sseSubscription?.cancel();
    _channelAlertStreamController.close();
    super.dispose();
  }
}
