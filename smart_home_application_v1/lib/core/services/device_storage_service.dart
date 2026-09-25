import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/connection_models.dart';

/// Persistent storage service for multiple commissioned EH Home devices and rooms.
class DeviceStorageService {
  DeviceStorageService();

  static const String _keyDevicesList = 'eh_devices_list_v4';
  static const String _keyRooms = 'eh_custom_rooms_v4';
  static const String _keyQuickControls = 'eh_quick_controls_v4';
  static const String _keyNotificationPrefs = 'eh_notification_prefs_v1';
  static const String _keyChannelLabels = 'eh_channel_labels_v5';
  static const String _keyBackendUrl = 'eh_backend_base_url_v1';
  static const String _keyDeviceIps = 'eh_device_ips_v1';

  // In-memory cache for synchronous reads and instant startup
  static String? _cachedBackendUrl;
  static final List<ConnectedDeviceSummary> _cachedDevices = [];
  static final List<String> _cachedQuickControls = [];
  static final Map<String, List<String>> _cachedRoomQuickControls = {};
  static final Map<String, Map<int, String>> _cachedChannelLabels = {};
  static final Map<String, String> _cachedDeviceIps = {};
  static final Map<String, bool> _cachedNotificationPrefs = {
    'pushEnabled': true,
    'criticalAlerts': true,
    'deviceOffline': true,
    'automationFailure': true,
    'firmwareUpdates': true,
  };
  static final List<String> _cachedRooms = [
    'Living Room',
    'Bedroom',
    'Kitchen',
    'Office',
    'Dining Room',
    'Balcony',
  ];

  static String? get backendUrl => _cachedBackendUrl;

  static Future<void> setBackendUrl(String url) async {
    _cachedBackendUrl = url;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyBackendUrl, url);
    } catch (_) {}
  }

  static ConnectedDeviceSummary? get primaryDevice =>
      _cachedDevices.isNotEmpty ? _cachedDevices.first : null;

  static List<ConnectedDeviceSummary> get cachedDevices =>
      List<ConnectedDeviceSummary>.unmodifiable(_cachedDevices);

  static List<String> get cachedQuickControls =>
      List<String>.unmodifiable(_cachedQuickControls);

  static Map<String, bool> get cachedNotificationPrefs =>
      Map<String, bool>.unmodifiable(_cachedNotificationPrefs);

  /// Global upfront initialization called from main() before runApp().
  static Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _cachedBackendUrl = prefs.getString(_keyBackendUrl);
      final jsonListStr = prefs.getString(_keyDevicesList);
      if (jsonListStr != null && jsonListStr.isNotEmpty) {
        final List<dynamic> decodedList =
            jsonDecode(jsonListStr) as List<dynamic>;
        _cachedDevices.clear();
        for (final item in decodedList) {
          final data = item as Map<String, dynamic>;
          _cachedDevices.add(
            ConnectedDeviceSummary(
              id: data['id'] as String? ?? '',
              name: data['name'] as String? ?? 'Smart Switch 3X',
              model: data['model'] as String? ?? 'eh-smart-switch-3x',
              firmware: data['firmware'] as String? ?? '1.0.0',
              connectedVia:
                  data['connectedVia'] as String? ?? 'Wi-Fi (2.4 GHz)',
              signalLabel: data['signalLabel'] as String? ?? 'Strong',
              roomName: data['roomName'] as String? ?? 'Living Room',
              online: data['online'] as bool? ?? true,
            ),
          );
        }
        debugPrint(
          '[HOME] INIT_HYDRATED devices_count=${_cachedDevices.length}',
        );
      }
      final list = prefs.getStringList(_keyRooms);
      if (list != null && list.isNotEmpty) {
        for (final r in list) {
          if (!_cachedRooms.contains(r)) {
            _cachedRooms.add(r);
          }
        }
      }
      final qList = prefs.getStringList(_keyQuickControls);
      if (qList != null && qList.isNotEmpty) {
        _cachedQuickControls.clear();
        _cachedQuickControls.addAll(qList);
      }
      final nStr = prefs.getString(_keyNotificationPrefs);
      if (nStr != null && nStr.isNotEmpty) {
        final Map<String, dynamic> decoded = jsonDecode(nStr);
        decoded.forEach((k, v) {
          if (v is bool) _cachedNotificationPrefs[k] = v;
        });
      }
      final chStr = prefs.getString(_keyChannelLabels);
      if (chStr != null && chStr.isNotEmpty) {
        final Map<String, dynamic> decoded = jsonDecode(chStr);
        decoded.forEach((devId, map) {
          if (map is Map) {
            final inner = <int, String>{};
            map.forEach((k, v) {
              final idx = int.tryParse(k.toString());
              if (idx != null && v != null) {
                inner[idx] = v.toString();
              }
            });
            _cachedChannelLabels[devId] = inner;
          }
        });
      }
      final ipStr = prefs.getString(_keyDeviceIps);
      if (ipStr != null && ipStr.isNotEmpty) {
        final Map<String, dynamic> decoded = jsonDecode(ipStr);
        decoded.forEach((devId, ip) {
          if (ip != null) {
            _cachedDeviceIps[devId] = ip.toString();
          }
        });
      }
    } catch (e) {
      debugPrint('[HOME] DeviceStorageService.init warning: $e');
    }
  }

  /// Get cached local IP address for a device.
  static String? getDeviceIp(String deviceId) {
    return _cachedDeviceIps[deviceId];
  }

  /// Get all cached device IP addresses.
  static Map<String, String> getAllCachedDeviceIps() {
    return Map<String, String>.unmodifiable(_cachedDeviceIps);
  }

  /// Save device local IP address persistently.
  static Future<void> saveDeviceIp(String deviceId, String ip) async {
    _cachedDeviceIps[deviceId] = ip;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyDeviceIps, jsonEncode(_cachedDeviceIps));
      debugPrint('[DeviceStorageService] Device IP persisted: devId=$deviceId ip=$ip');
    } catch (e) {
      debugPrint('[DeviceStorageService] saveDeviceIp error: $e');
    }
  }

  /// Get cached channel labels for a specific device.
  static Map<int, String> getChannelLabels(String deviceId) {
    return Map<int, String>.unmodifiable(_cachedChannelLabels[deviceId] ?? {});
  }

  /// Save or update custom channel label persistently.
  static Future<void> saveChannelLabel(String deviceId, int channelIndex, String newName) async {
    _cachedChannelLabels.putIfAbsent(deviceId, () => {})[channelIndex] = newName;
    try {
      final prefs = await SharedPreferences.getInstance();
      final toSerialize = <String, Map<String, String>>{};
      _cachedChannelLabels.forEach((devId, map) {
        toSerialize[devId] = map.map((k, v) => MapEntry(k.toString(), v));
      });
      await prefs.setString(_keyChannelLabels, jsonEncode(toSerialize));
      debugPrint('[DeviceStorageService] Channel label persisted: devId=$deviceId ch=$channelIndex label=$newName');
    } catch (e) {
      debugPrint('[DeviceStorageService] saveChannelLabel error: $e');
    }
  }

  /// Rename a room and update associated device locations.
  static Future<void> renameRoom(String oldName, String newName) async {
    final idx = _cachedRooms.indexOf(oldName);
    if (idx >= 0) {
      _cachedRooms[idx] = newName;
    } else if (!_cachedRooms.contains(newName)) {
      _cachedRooms.add(newName);
    }
    for (int i = 0; i < _cachedDevices.length; i++) {
      if (_cachedDevices[i].roomName == oldName) {
        _cachedDevices[i] = ConnectedDeviceSummary(
          id: _cachedDevices[i].id,
          name: _cachedDevices[i].name,
          model: _cachedDevices[i].model,
          firmware: _cachedDevices[i].firmware,
          connectedVia: _cachedDevices[i].connectedVia,
          signalLabel: _cachedDevices[i].signalLabel,
          roomName: newName,
          online: _cachedDevices[i].online,
        );
      }
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_keyRooms, _cachedRooms);
      final jsonList = _cachedDevices.map((d) => {
        'id': d.id,
        'name': d.name,
        'model': d.model,
        'firmware': d.firmware,
        'connectedVia': d.connectedVia,
        'signalLabel': d.signalLabel,
        'roomName': d.roomName,
        'online': d.online,
      }).toList();
      await prefs.setString(_keyDevicesList, jsonEncode(jsonList));
      debugPrint('[DeviceStorageService] Room renamed: $oldName -> $newName');
    } catch (e) {
      debugPrint('[DeviceStorageService] renameRoom error: $e');
    }
  }

  /// Delete a room from storage.
  static Future<void> deleteRoom(String roomName) async {
    _cachedRooms.remove(roomName);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_keyRooms, _cachedRooms);
      debugPrint('[DeviceStorageService] Room deleted: $roomName');
    } catch (e) {
      debugPrint('[DeviceStorageService] deleteRoom error: $e');
    }
  }

  /// Save or update a commissioned device in persistent storage.
  Future<void> saveDevice(ConnectedDeviceSummary device) async {
    final index = _cachedDevices.indexWhere((d) => d.id == device.id);
    if (index >= 0) {
      _cachedDevices[index] = device;
    } else {
      _cachedDevices.add(device);
    }

    final jsonList = _cachedDevices
        .map(
          (d) => {
            'id': d.id,
            'name': d.name,
            'model': d.model,
            'firmware': d.firmware,
            'connectedVia': d.connectedVia,
            'signalLabel': d.signalLabel,
            'roomName': d.roomName,
            'online': d.online,
          },
        )
        .toList();

    final jsonStr = jsonEncode(jsonList);

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyDevicesList, jsonStr);
      debugPrint(
        '[HOME] DEVICE_PERSISTED id=${device.id} room=${device.roomName} total=${_cachedDevices.length}',
      );
    } catch (e) {
      debugPrint('[HOME] SharedPreferences write warning: $e');
    }
  }

  /// Load all commissioned devices from persistent storage.
  Future<List<ConnectedDeviceSummary>> loadDevices() async {
    if (_cachedDevices.isNotEmpty) {
      return List<ConnectedDeviceSummary>.unmodifiable(_cachedDevices);
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonListStr = prefs.getString(_keyDevicesList);
      if (jsonListStr != null && jsonListStr.isNotEmpty) {
        final List<dynamic> decodedList =
            jsonDecode(jsonListStr) as List<dynamic>;
        _cachedDevices.clear();
        for (final item in decodedList) {
          final data = item as Map<String, dynamic>;
          _cachedDevices.add(
            ConnectedDeviceSummary(
              id: data['id'] as String? ?? '',
              name: data['name'] as String? ?? 'Smart Switch 3X',
              model: data['model'] as String? ?? 'eh-smart-switch-3x',
              firmware: data['firmware'] as String? ?? '1.0.0',
              connectedVia:
                  data['connectedVia'] as String? ?? 'Wi-Fi (2.4 GHz)',
              signalLabel: data['signalLabel'] as String? ?? 'Strong',
              roomName: data['roomName'] as String? ?? 'Living Room',
              online: data['online'] as bool? ?? false,
            ),
          );
        }
        return List<ConnectedDeviceSummary>.unmodifiable(_cachedDevices);
      }
    } catch (e) {
      debugPrint('[HOME] SharedPreferences read warning: $e');
    }

    return List<ConnectedDeviceSummary>.unmodifiable(_cachedDevices);
  }

  /// Remove a commissioned device.
  Future<void> removeDevice(String deviceId) async {
    _cachedDevices.removeWhere((d) => d.id == deviceId);
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = _cachedDevices
          .map(
            (d) => {
              'id': d.id,
              'name': d.name,
              'model': d.model,
              'firmware': d.firmware,
              'connectedVia': d.connectedVia,
              'signalLabel': d.signalLabel,
              'roomName': d.roomName,
              'online': d.online,
            },
          )
          .toList();
      await prefs.setString(_keyDevicesList, jsonEncode(jsonList));
    } catch (_) {}
    debugPrint('[HOME] DEVICE_REMOVED id=$deviceId');
  }

  /// Remove all commissioned devices (e.g. factory reset).
  Future<void> clearAllDevices() async {
    _cachedDevices.clear();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyDevicesList);
    } catch (_) {}
    debugPrint('[HOME] ALL_DEVICES_CLEARED');
  }

  /// Load available rooms (standard + user created).
  Future<List<String>> loadRooms() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList(_keyRooms);
      if (list != null && list.isNotEmpty) {
        for (final r in list) {
          if (!_cachedRooms.contains(r)) {
            _cachedRooms.add(r);
          }
        }
      }
    } catch (_) {}
    return List<String>.unmodifiable(_cachedRooms);
  }

  /// Add a new custom room.
  Future<void> addRoom(String roomName) async {
    final trimmed = roomName.trim();
    if (trimmed.isEmpty || _cachedRooms.contains(trimmed)) return;

    _cachedRooms.add(trimmed);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_keyRooms, _cachedRooms);
    } catch (_) {}
  }

  /// Load selected quick control IDs (e.g. ['${devId}_ch1', ...]).
  Future<List<String>> loadQuickControls() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList(_keyQuickControls);
      if (list != null) {
        _cachedQuickControls.clear();
        _cachedQuickControls.addAll(list);
      }
    } catch (_) {}
    return List<String>.unmodifiable(_cachedQuickControls);
  }

  /// Save selected quick control IDs.
  Future<void> saveQuickControls(List<String> controlIds) async {
    _cachedQuickControls.clear();
    _cachedQuickControls.addAll(controlIds);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_keyQuickControls, _cachedQuickControls);
    } catch (_) {}
    debugPrint('[HOME] QUICK_CONTROLS_SAVED count=${_cachedQuickControls.length}');
  }

  /// Get quick control IDs for a specific room.
  static List<String>? getRoomQuickControls(String roomName) {
    return _cachedRoomQuickControls[roomName];
  }

  /// Save quick control IDs for a specific room.
  static Future<void> saveRoomQuickControls(String roomName, List<String> controlIds) async {
    _cachedRoomQuickControls[roomName] = List.from(controlIds);
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'eh_room_quick_${roomName.toLowerCase().replaceAll(' ', '_')}';
      await prefs.setStringList(key, controlIds);
      debugPrint('[HOME] ROOM_QUICK_CONTROLS_SAVED room=$roomName count=${controlIds.length}');
    } catch (_) {}
  }

  static const String _keySpaces = 'eh_spaces_v2';
  static const String _keyDeletedSpaceIds = 'eh_deleted_spaces_v2';
  static const String _keyGroupControlsPrefix = 'eh_groups_';
  static const String _keyFavouritesPrefix = 'eh_favourites_';

  static final List<Map<String, dynamic>> _cachedSpaces = [
    {'id': 'home_default', 'name': 'My Home', 'icon': 'home'},
  ];
  static final Set<String> _cachedDeletedSpaceIds = {};

  static List<Map<String, dynamic>> get cachedSpaces =>
      List.unmodifiable(_cachedSpaces);

  /// Load set of space IDs that were deleted by the user so they never resurface.
  Future<Set<String>> loadDeletedSpaceIds() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList(_keyDeletedSpaceIds) ?? [];
      _cachedDeletedSpaceIds.clear();
      _cachedDeletedSpaceIds.addAll(list);
    } catch (_) {}
    return Set.unmodifiable(_cachedDeletedSpaceIds);
  }

  /// Mark a space ID as permanently deleted.
  Future<void> addDeletedSpaceId(String spaceId) async {
    _cachedDeletedSpaceIds.add(spaceId);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_keyDeletedSpaceIds, _cachedDeletedSpaceIds.toList());
    } catch (_) {}
  }

  /// Load user-managed spaces. Defaults to only 'My Home'.
  Future<List<Map<String, dynamic>>> loadSpaces() async {
    try {
      await loadDeletedSpaceIds();
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(_keySpaces);
      if (jsonStr != null && jsonStr.isNotEmpty) {
        final List<dynamic> list = jsonDecode(jsonStr);
        _cachedSpaces.clear();
        for (final item in list) {
          if (item is Map) {
            final mapItem = Map<String, dynamic>.from(item);
            final sId = mapItem['id']?.toString() ?? '';
            // Never load deleted spaces
            if (!_cachedDeletedSpaceIds.contains(sId)) {
              _cachedSpaces.add(mapItem);
            }
          }
        }
      }
      if (_cachedSpaces.isEmpty) {
        _cachedSpaces.add({'id': 'home_default', 'name': 'My Home', 'icon': 'home'});
      } else {
        // Enforce user-facing primary space name remains 'My Home'
        final firstName = _cachedSpaces.first['name']?.toString().toLowerCase() ?? '';
        if (firstName.contains('pavan') || firstName == 'home') {
          _cachedSpaces.first['name'] = 'My Home';
        }
      }
    } catch (_) {}
    return List.unmodifiable(_cachedSpaces);
  }

  /// Save spaces list persistently.
  Future<void> saveSpaces(List<Map<String, dynamic>> spaces) async {
    _cachedSpaces.clear();
    for (final s in spaces) {
      final copy = Map<String, dynamic>.from(s);
      _cachedSpaces.add(copy);
    }
    if (_cachedSpaces.isNotEmpty) {
      final firstName = _cachedSpaces.first['name']?.toString().toLowerCase() ?? '';
      if (firstName.contains('pavan') || firstName == 'home') {
        _cachedSpaces.first['name'] = 'My Home';
      }
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keySpaces, jsonEncode(_cachedSpaces));
    } catch (_) {}
  }

  /// Load devices partitioned strictly by space.
  Future<List<ConnectedDeviceSummary>> loadDevicesForSpace(String spaceId) async {
    final key = spaceId == 'home_default' ? _keyDevicesList : '${_keyDevicesList}_$spaceId';
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonListStr = prefs.getString(key);
      if (jsonListStr != null && jsonListStr.isNotEmpty) {
        final List<dynamic> decodedList = jsonDecode(jsonListStr) as List<dynamic>;
        final List<ConnectedDeviceSummary> result = [];
        for (final item in decodedList) {
          final data = item as Map<String, dynamic>;
          result.add(
            ConnectedDeviceSummary(
              id: data['id'] as String? ?? '',
              name: data['name'] as String? ?? 'Smart Switch',
              model: data['model'] as String? ?? 'eh-smart-switch-3x',
              firmware: data['firmware'] as String? ?? '1.0.0',
              connectedVia: data['connectedVia'] as String? ?? 'Wi-Fi (2.4 GHz)',
              signalLabel: data['signalLabel'] as String? ?? 'Strong',
              roomName: data['roomName'] as String? ?? 'Living Room',
              online: data['online'] as bool? ?? false,
            ),
          );
        }
        return List.unmodifiable(result);
      }
    } catch (e) {
      debugPrint('[DeviceStorageService] loadDevicesForSpace error: $e');
    }
    // Brand new space starts empty!
    return const [];
  }

  /// Save a device to a specific space partition.
  Future<void> saveDeviceForSpace(String spaceId, ConnectedDeviceSummary device) async {
    final key = spaceId == 'home_default' ? _keyDevicesList : '${_keyDevicesList}_$spaceId';
    try {
      final current = List<ConnectedDeviceSummary>.from(await loadDevicesForSpace(spaceId));
      final idx = current.indexWhere((d) => d.id == device.id);
      if (idx >= 0) {
        current[idx] = device;
      } else {
        current.add(device);
      }
      final prefs = await SharedPreferences.getInstance();
      final jsonList = current.map((d) => {
        'id': d.id,
        'name': d.name,
        'model': d.model,
        'firmware': d.firmware,
        'connectedVia': d.connectedVia,
        'signalLabel': d.signalLabel,
        'roomName': d.roomName,
        'online': d.online,
      }).toList();
      await prefs.setString(key, jsonEncode(jsonList));
      if (spaceId == 'home_default') {
        _cachedDevices.clear();
        _cachedDevices.addAll(current);
      }
    } catch (e) {
      debugPrint('[DeviceStorageService] saveDeviceForSpace error: $e');
    }
  }

  /// Remove a device from a specific space partition.
  Future<void> removeDeviceForSpace(String spaceId, String deviceId) async {
    final key = spaceId == 'home_default' ? _keyDevicesList : '${_keyDevicesList}_$spaceId';
    try {
      final current = List<ConnectedDeviceSummary>.from(await loadDevicesForSpace(spaceId));
      current.removeWhere((d) => d.id == deviceId);
      final prefs = await SharedPreferences.getInstance();
      final jsonList = current.map((d) => {
        'id': d.id,
        'name': d.name,
        'model': d.model,
        'firmware': d.firmware,
        'connectedVia': d.connectedVia,
        'signalLabel': d.signalLabel,
        'roomName': d.roomName,
        'online': d.online,
      }).toList();
      await prefs.setString(key, jsonEncode(jsonList));
      if (spaceId == 'home_default') {
        _cachedDevices.removeWhere((d) => d.id == deviceId);
      }
    } catch (_) {}
  }

  /// Load rooms partitioned strictly by space.
  Future<List<String>> loadRoomsForSpace(String spaceId) async {
    if (spaceId == 'home_default') {
      return loadRooms();
    }
    final key = '${_keyRooms}_$spaceId';
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList(key);
      if (list != null && list.isNotEmpty) {
        return List.unmodifiable(list);
      }
    } catch (_) {}
    return const [];
  }

  /// Add a room to a specific space partition.
  Future<void> addRoomForSpace(String spaceId, String roomName) async {
    if (spaceId == 'home_default') {
      return addRoom(roomName);
    }
    final trimmed = roomName.trim();
    if (trimmed.isEmpty) return;
    final key = '${_keyRooms}_$spaceId';
    try {
      final prefs = await SharedPreferences.getInstance();
      final current = List<String>.from(prefs.getStringList(key) ?? []);
      if (!current.contains(trimmed)) {
        current.add(trimmed);
        await prefs.setStringList(key, current);
      }
    } catch (_) {}
  }

  /// Load group controls for a specific space.
  Future<List<Map<String, dynamic>>> loadGroupControlsForSpace(String spaceId) async {
    final key = '$_keyGroupControlsPrefix$spaceId';
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(key);
      if (jsonStr != null && jsonStr.isNotEmpty) {
        final List<dynamic> list = jsonDecode(jsonStr);
        return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
    } catch (_) {}
    return [];
  }

  /// Save group controls for a specific space.
  Future<void> saveGroupControlsForSpace(String spaceId, List<Map<String, dynamic>> groups) async {
    final key = '$_keyGroupControlsPrefix$spaceId';
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(key, jsonEncode(groups));
    } catch (_) {}
  }

  /// Load favourite control IDs for a specific space.
  Future<List<String>> loadFavouritesForSpace(String spaceId) async {
    final key = '$_keyFavouritesPrefix$spaceId';
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList(key);
      if (list != null) return list;
    } catch (_) {}
    return [];
  }

  /// Save favourite control IDs for a specific space.
  Future<void> saveFavouritesForSpace(String spaceId, List<String> favouriteIds) async {
    final key = '$_keyFavouritesPrefix$spaceId';
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(key, favouriteIds);
    } catch (_) {}
  }

  static const _keyQuickControlsPrefix = 'eh_quick_controls_';

  /// Load quick control IDs pinned for a specific space.
  Future<List<String>> loadQuickControlsForSpace(String spaceId) async {
    final key = '$_keyQuickControlsPrefix$spaceId';
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList(key);
      if (list != null) return list;
    } catch (_) {}
    return [];
  }

  /// Save quick control IDs for a specific space.
  Future<void> saveQuickControlsForSpace(String spaceId, List<String> controlIds) async {
    final key = '$_keyQuickControlsPrefix$spaceId';
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(key, controlIds);
    } catch (_) {}
  }

  /// Load notification preferences.
  Future<Map<String, bool>> loadNotificationPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final nStr = prefs.getString(_keyNotificationPrefs);
      if (nStr != null && nStr.isNotEmpty) {
        final Map<String, dynamic> decoded = jsonDecode(nStr);
        decoded.forEach((k, v) {
          if (v is bool) _cachedNotificationPrefs[k] = v;
        });
      }
    } catch (_) {}
    return Map<String, bool>.unmodifiable(_cachedNotificationPrefs);
  }

  /// Save notification preferences.
  Future<void> saveNotificationPrefs(Map<String, bool> prefsMap) async {
    _cachedNotificationPrefs.addAll(prefsMap);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyNotificationPrefs, jsonEncode(_cachedNotificationPrefs));
    } catch (_) {}
    debugPrint('[HOME] NOTIFICATION_PREFS_SAVED');
  }
}
