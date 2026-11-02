import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/connection_models.dart';
import '../models/home_dashboard_models.dart';

/// Persistent storage service for multiple commissioned EH Home devices and rooms.
class DeviceStorageService {
  DeviceStorageService();

  static const String _keyDevicesList = 'eh_devices_list_v5';
  static const String _keyRooms = 'eh_custom_rooms_v5';
  static const String _keyQuickControls = 'eh_quick_controls_v5';
  static const String _keyNotificationPrefs = 'eh_notification_prefs_v1';
  static const String _keyChannelLabels = 'eh_channel_labels_v6';
  static const String _keyBackendUrl = 'eh_backend_base_url_v1';
  static const String _keyDeviceIps = 'eh_device_ips_v1';
  static const String _keyChannelAlerts = 'eh_channel_alerts_v1';
  static const String _keyPendingCloudUpload = 'eh_pending_cloud_upload_v1';
  static const String _keySyncMode = 'eh_sync_mode_v1';
  static const String _keyConnectionRoutingMode = 'eh_connection_routing_mode_v1';
  static const String _keyLastCloudSyncTime = 'eh_last_cloud_sync_time_v1';
  static const String _keyDeletedDeviceIds = 'eh_deleted_devices_v2';
  static const String _keyDeletedRooms = 'eh_deleted_rooms_v1';
  static const String _keyDeletedRoutineIds = 'eh_deleted_routines_v1';
  static const String _keyActivityAlerts = 'eh_activity_alerts_v2';
  static const String _keySavedEmail = 'eh_saved_login_email_v1';
  static const String _keySavedPassword = 'eh_saved_login_password_v1';
  static const String _keyRememberMe = 'eh_remember_me_v1';

  // In-memory cache for synchronous reads and instant startup
  static String? _cachedBackendUrl;
  static String? _cachedSavedEmail;
  static String? _cachedSavedPassword;
  static bool _cachedRememberMe = true;
  static bool _cachedPendingCloudUpload = false;
  static String _cachedSyncMode = 'manual'; // 'auto' or 'manual'
  static String _cachedConnectionRoutingMode = 'auto'; // 'auto', 'localOnly', 'cloudOnly'
  static int? _cachedLastCloudSyncTime;
  static final List<ConnectedDeviceSummary> _cachedDevices = [];
  static final Set<String> _cachedDeletedDeviceIds = {};
  static final Set<String> _cachedDeletedRooms = {};
  static final Set<String> _cachedDeletedRoutineIds = {};
  static final List<String> _cachedQuickControls = [];
  static final Map<String, List<String>> _cachedRoomQuickControls = {};
  static final Map<String, Map<int, String>> _cachedChannelLabels = {};
  static final Map<String, ChannelAlertConfig> _cachedChannelAlerts = {};
  static final Map<String, String> _cachedDeviceIps = {};
  static final Map<String, bool> _cachedNotificationPrefs = {
    'pushEnabled': true,
    'criticalAlerts': true,
    'deviceOffline': true,
    'automationFailure': true,
    'firmwareUpdates': true,
  };
  static const String _keyDeletedNotifIds = 'eh_deleted_notif_ids';
  static const String _keyReadNotifIds = 'eh_read_notif_ids';
  static final Set<String> _cachedDeletedNotifIds = {};
  static final Set<String> _cachedReadNotifIds = {};
  static final List<String> _cachedRooms = [
    'Living Room',
  ];
  static String? cachedUserName;
  static String? cachedActiveHomeId;

  static String? get backendUrl => _cachedBackendUrl;
  static String? get savedLoginEmail => _cachedSavedEmail;
  static String? get savedLoginPassword => _cachedSavedPassword;
  static bool get rememberMe => _cachedRememberMe;

  static Future<void> saveLoginCredentials({
    required String email,
    required String password,
    required bool rememberMe,
  }) async {
    _cachedSavedEmail = email;
    _cachedSavedPassword = password;
    _cachedRememberMe = rememberMe;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (rememberMe) {
        await prefs.setString(_keySavedEmail, email);
        await prefs.setString(_keySavedPassword, password);
        await prefs.setBool(_keyRememberMe, true);
      } else {
        await prefs.remove(_keySavedEmail);
        await prefs.remove(_keySavedPassword);
        await prefs.setBool(_keyRememberMe, false);
      }
    } catch (_) {}
  }

  static Future<void> clearSavedLoginCredentials() async {
    _cachedSavedEmail = null;
    _cachedSavedPassword = null;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keySavedEmail);
      await prefs.remove(_keySavedPassword);
    } catch (_) {}
  }

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
      _cachedSavedEmail = prefs.getString(_keySavedEmail);
      _cachedSavedPassword = prefs.getString(_keySavedPassword);
      _cachedRememberMe = prefs.getBool(_keyRememberMe) ?? true;

      final deletedDevs = prefs.getStringList(_keyDeletedDeviceIds);
      if (deletedDevs != null && deletedDevs.isNotEmpty) {
        _cachedDeletedDeviceIds.clear();
        _cachedDeletedDeviceIds.addAll(deletedDevs);
      }

      final jsonListStr = prefs.getString(_keyDevicesList);
      if (jsonListStr != null && jsonListStr.isNotEmpty) {
        final List<dynamic> decodedList =
            jsonDecode(jsonListStr) as List<dynamic>;
        final List<ConnectedDeviceSummary> rawLoaded = [];
        for (final item in decodedList) {
          final data = item as Map<String, dynamic>;
          final dId = data['id'] as String? ?? '';
          if (_cachedDeletedDeviceIds.contains(dId)) continue;
          rawLoaded.add(
            ConnectedDeviceSummary(
              id: dId,
              name: data['name'] as String? ?? 'Smart Switch',
              model: data['model'] as String? ?? 'eh-smart-switch-4x',
              firmware: data['firmware'] as String? ?? '1.0.0',
              connectedVia: 'Offline',
              signalLabel: 'Offline',
              roomName: data['roomName'] as String? ?? 'Living Room',
              online: false,
            ),
          );
        }
        _cachedDevices.clear();
        _cachedDevices.addAll(deduplicateDevices(rawLoaded));
        debugPrint(
          '[HOME] INIT_HYDRATED devices_count=${_cachedDevices.length}',
        );
      }
      final deletedRoomsList = prefs.getStringList(_keyDeletedRooms);
      if (deletedRoomsList != null) {
        _cachedDeletedRooms.clear();
        _cachedDeletedRooms.addAll(deletedRoomsList);
      }

      final deletedRoutinesList = prefs.getStringList(_keyDeletedRoutineIds);
      if (deletedRoutinesList != null && deletedRoutinesList.isNotEmpty) {
        _cachedDeletedRoutineIds.clear();
        _cachedDeletedRoutineIds.addAll(deletedRoutinesList);
      }
      final list = prefs.getStringList(_keyRooms);
      if (list != null && list.isNotEmpty) {
        _cachedRooms.clear();
        for (final r in list) {
          final trimmed = r.trim();
          if (trimmed.isNotEmpty && !_cachedDeletedRooms.contains(trimmed) && !_cachedRooms.contains(trimmed)) {
            _cachedRooms.add(trimmed);
          }
        }
      }
      if (_cachedRooms.isEmpty) {
        _cachedRooms.add('Living Room');
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
      final alertsStr = prefs.getString(_keyChannelAlerts);
      if (alertsStr != null && alertsStr.isNotEmpty) {
        final Map<String, dynamic> decoded = jsonDecode(alertsStr);
        _cachedChannelAlerts.clear();
        decoded.forEach((key, val) {
          if (val is Map) {
            _cachedChannelAlerts[key] = ChannelAlertConfig.fromJson(Map<String, dynamic>.from(val));
          }
        });
      }
      final ipsStr = prefs.getString(_keyDeviceIps);
      if (ipsStr != null && ipsStr.isNotEmpty) {
        final Map<String, dynamic> decoded = jsonDecode(ipsStr);
        _cachedDeviceIps.clear();
        decoded.forEach((k, v) {
          if (v != null) _cachedDeviceIps[k] = v.toString();
        });
      }
      try {
        final profileStr = prefs.getString('auth_user_profile');
        if (profileStr != null && profileStr.isNotEmpty) {
          final pMap = jsonDecode(profileStr);
          if (pMap is Map) {
            cachedUserName = pMap['fullName']?.toString() ??
                pMap['full_name']?.toString() ??
                pMap['name']?.toString() ??
                pMap['email']?.toString().split('@').first;
          }
        }
      } catch (_) {}
      _cachedPendingCloudUpload = prefs.getBool(_keyPendingCloudUpload) ?? false;
      _cachedSyncMode = prefs.getString(_keySyncMode) ?? 'manual';
      _cachedConnectionRoutingMode = prefs.getString(_keyConnectionRoutingMode) ?? 'auto';
      _cachedLastCloudSyncTime = prefs.getInt(_keyLastCloudSyncTime);

      final delNotifs = prefs.getStringList(_keyDeletedNotifIds);
      if (delNotifs != null) {
        _cachedDeletedNotifIds.clear();
        _cachedDeletedNotifIds.addAll(delNotifs);
      }
      final readNotifs = prefs.getStringList(_keyReadNotifIds);
      if (readNotifs != null) {
        _cachedReadNotifIds.clear();
        _cachedReadNotifIds.addAll(readNotifs);
      }

      final deletedStr = prefs.getStringList(_keyDeletedSpaceIds);
      if (deletedStr != null && deletedStr.isNotEmpty) {
        _cachedDeletedSpaceIds.clear();
        _cachedDeletedSpaceIds.addAll(deletedStr);
      }
      final spacesStr = prefs.getString(_keySpaces);
      if (spacesStr != null && spacesStr.isNotEmpty) {
        final List<dynamic> list = jsonDecode(spacesStr);
        _cachedSpaces.clear();
        for (final item in list) {
          if (item is Map) {
            final mapItem = Map<String, dynamic>.from(item);
            final sId = mapItem['id']?.toString() ?? '';
            if (!_cachedDeletedSpaceIds.contains(sId)) {
              _cachedSpaces.add(mapItem);
            }
          }
        }
      }
      if (_cachedSpaces.isEmpty) {
        _cachedSpaces.add({'id': 'home_default', 'name': 'My Home', 'icon': 'home'});
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

  /// Invalidate/remove device local IP address persistently.
  static Future<void> removeDeviceIp(String deviceId) async {
    _cachedDeviceIps.remove(deviceId);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyDeviceIps, jsonEncode(_cachedDeviceIps));
      debugPrint('[DeviceStorageService] Device IP removed: devId=$deviceId');
    } catch (e) {
      debugPrint('[DeviceStorageService] removeDeviceIp error: $e');
    }
  }

  /// Deduplicate device list strictly by exact deviceId.
  static List<ConnectedDeviceSummary> deduplicateDevices(List<ConnectedDeviceSummary> list) {
    if (list.length <= 1) return list;
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
        unique[key] = existing.copyWith(
          name: bestName,
          roomName: bestRoom,
          online: existing.online || d.online,
        );
      }
    }
    return unique.values.toList();
  }

  /// Get cached channel labels for a specific device strictly by exact deviceId.
  static Map<int, String> getChannelLabels(String deviceId) {
    final key = deviceId.trim();
    if (_cachedChannelLabels.containsKey(key)) {
      return Map<int, String>.unmodifiable(_cachedChannelLabels[key]!);
    }
    return const {};
  }

  /// Save or update custom channel label persistently for exact deviceId.
  static Future<void> saveChannelLabel(String deviceId, int channelIndex, String newName) async {
    final key = deviceId.trim();
    _cachedChannelLabels.putIfAbsent(key, () => {})[channelIndex] = newName;
    try {
      final prefs = await SharedPreferences.getInstance();
      final toSerialize = <String, Map<String, String>>{};
      _cachedChannelLabels.forEach((devId, map) {
        toSerialize[devId] = map.map((k, v) => MapEntry(k.toString(), v));
      });
      await prefs.setString(_keyChannelLabels, jsonEncode(toSerialize));
      debugPrint('[DeviceStorageService] Channel label persisted: devId=$key ch=$channelIndex label=$newName');
    } catch (e) {
      debugPrint('[DeviceStorageService] saveChannelLabel error: $e');
    }
  }

  /// Clear all custom channel labels for a specific device.
  static Future<void> clearChannelLabelsForDevice(String deviceId) async {
    final key = deviceId.trim();
    _cachedChannelLabels.remove(key);
    try {
      final prefs = await SharedPreferences.getInstance();
      final toSerialize = <String, Map<String, String>>{};
      _cachedChannelLabels.forEach((devId, map) {
        toSerialize[devId] = map.map((k, v) => MapEntry(k.toString(), v));
      });
      await prefs.setString(_keyChannelLabels, jsonEncode(toSerialize));
      debugPrint('[DeviceStorageService] Channel labels wiped for devId=$key');
    } catch (e) {
      debugPrint('[DeviceStorageService] clearChannelLabelsForDevice error: $e');
    }
  }

  /// Explicitly set the entire map of channel labels for a device.
  static Future<void> setChannelLabelsForDevice(String deviceId, Map<int, String> labels) async {
    final key = deviceId.trim();
    _cachedChannelLabels[key] = Map<int, String>.from(labels);
    try {
      final prefs = await SharedPreferences.getInstance();
      final toSerialize = <String, Map<String, String>>{};
      _cachedChannelLabels.forEach((devId, map) {
        toSerialize[devId] = map.map((k, v) => MapEntry(k.toString(), v));
      });
      await prefs.setString(_keyChannelLabels, jsonEncode(toSerialize));
      debugPrint('[DeviceStorageService] Channel labels set for devId=$key count=${labels.length}');
    } catch (_) {}
  }

  /// Wipe all custom channel labels across all devices.
  static Future<void> resetAllChannelLabels() async {
    _cachedChannelLabels.clear();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyChannelLabels);
      debugPrint('[DeviceStorageService] All channel labels reset to defaults');
    } catch (_) {}
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

  /// Get set of rooms deleted by the user so they never resurface.
  static Set<String> get deletedRooms => Set.unmodifiable(_cachedDeletedRooms);

  /// Delete a room from storage.
  static Future<void> deleteRoom(String roomName) async {
    _cachedRooms.removeWhere((r) => r.toLowerCase() == roomName.toLowerCase());
    _cachedDeletedRooms.add(roomName);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_keyRooms, _cachedRooms);
      await prefs.setStringList(_keyDeletedRooms, _cachedDeletedRooms.toList());
      debugPrint('[DeviceStorageService] Room deleted: $roomName');
    } catch (e) {
      debugPrint('[DeviceStorageService] deleteRoom error: $e');
    }
  }

  /// Load set of device IDs that were deleted by the user so they never resurface.
  static Future<Set<String>> loadDeletedDeviceIds() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList(_keyDeletedDeviceIds) ?? [];
      _cachedDeletedDeviceIds.clear();
      _cachedDeletedDeviceIds.addAll(list);
    } catch (_) {}
    return Set.unmodifiable(_cachedDeletedDeviceIds);
  }

  /// Mark a device ID as permanently deleted.
  static Future<void> addDeletedDeviceId(String deviceId) async {
    _cachedDeletedDeviceIds.add(deviceId);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_keyDeletedDeviceIds, _cachedDeletedDeviceIds.toList());
    } catch (_) {}
  }

  /// Unmark a device ID as deleted (e.g. when newly re-commissioned).
  static Future<void> removeDeletedDeviceId(String deviceId) async {
    _cachedDeletedDeviceIds.remove(deviceId);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_keyDeletedDeviceIds, _cachedDeletedDeviceIds.toList());
    } catch (_) {}
  }

  /// Check if a device ID was permanently deleted.
  static bool isDeviceDeleted(String deviceId) => _cachedDeletedDeviceIds.contains(deviceId);

  /// Set of routine IDs and names deleted by user so they never reappear
  static Set<String> get deletedRoutineIds => Set.unmodifiable(_cachedDeletedRoutineIds);

  static Future<void> markRoutineDeleted(String routineId, {String? routineName}) async {
    final cleanId = routineId.trim().toLowerCase();
    _cachedDeletedRoutineIds.add(cleanId);
    if (routineName != null && routineName.trim().isNotEmpty) {
      _cachedDeletedRoutineIds.add(routineName.trim().toLowerCase());
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_keyDeletedRoutineIds, _cachedDeletedRoutineIds.toList());
    } catch (_) {}
  }

  static bool isRoutineDeleted(String routineId, {String? routineName}) {
    final cleanId = routineId.trim().toLowerCase();
    if (_cachedDeletedRoutineIds.contains(cleanId)) return true;
    if (routineName != null && routineName.trim().isNotEmpty) {
      if (_cachedDeletedRoutineIds.contains(routineName.trim().toLowerCase())) return true;
    }
    return false;
  }

  static Future<void> removeDeletedRoutine(String routineId) async {
    _cachedDeletedRoutineIds.remove(routineId.trim().toLowerCase());
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_keyDeletedRoutineIds, _cachedDeletedRoutineIds.toList());
    } catch (_) {}
  }

  /// Save or update a commissioned device in persistent storage.
  Future<void> saveDevice(ConnectedDeviceSummary device) async {
    await removeDeletedDeviceId(device.id);
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
      return List<ConnectedDeviceSummary>.unmodifiable(
        _cachedDevices.where((d) => !_cachedDeletedDeviceIds.contains(d.id)),
      );
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
          final dId = data['id'] as String? ?? '';
          if (_cachedDeletedDeviceIds.contains(dId)) continue;
          _cachedDevices.add(
            ConnectedDeviceSummary(
              id: dId,
              name: data['name'] as String? ?? 'Smart Switch',
              model: data['model'] as String? ?? 'eh-smart-switch-4x',
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

  /// Remove a commissioned device and wipe all its channel labels and quick controls.
  Future<void> removeDevice(String deviceId) async {
    await addDeletedDeviceId(deviceId);
    _cachedDevices.removeWhere((d) => d.id == deviceId);
    _cachedChannelLabels.remove(deviceId);
    _cachedDeviceIps.remove(deviceId);
    _cachedQuickControls.removeWhere((id) => id.startsWith('${deviceId}_') || id == deviceId);

    for (final roomKey in _cachedRoomQuickControls.keys.toList()) {
      _cachedRoomQuickControls[roomKey]?.removeWhere((id) => id.startsWith('${deviceId}_') || id == deviceId);
    }

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

      final toSerialize = <String, Map<String, String>>{};
      _cachedChannelLabels.forEach((devId, map) {
        toSerialize[devId] = map.map((k, v) => MapEntry(k.toString(), v));
      });
      await prefs.setString(_keyChannelLabels, jsonEncode(toSerialize));
      await prefs.setString(_keyDeviceIps, jsonEncode(_cachedDeviceIps));
      await prefs.setStringList(_keyQuickControls, _cachedQuickControls);
    } catch (_) {}
    debugPrint('[HOME] DEVICE_REMOVED id=$deviceId (labels and controls wiped)');
  }

  /// Remove all commissioned devices (e.g. factory reset).
  Future<void> clearAllDevices() async {
    for (final dev in _cachedDevices) {
      _cachedDeletedDeviceIds.add(dev.id);
    }
    _cachedDevices.clear();
    _cachedChannelLabels.clear();
    _cachedDeviceIps.clear();
    _cachedQuickControls.clear();
    _cachedRoomQuickControls.clear();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyDevicesList);
      await prefs.remove(_keyChannelLabels);
      await prefs.remove(_keyDeviceIps);
      await prefs.remove(_keyQuickControls);
      await prefs.setStringList(_keyDeletedDeviceIds, _cachedDeletedDeviceIds.toList());
    } catch (_) {}
    debugPrint('[HOME] ALL_DEVICES_CLEARED (labels and controls wiped)');
  }

  /// Save activity alerts persistently so history survives app restarts.
  static Future<void> saveActivityAlerts(List<SpaceAlertItem> alerts) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = alerts.map((a) => a.toJson()).toList();
      await prefs.setString(_keyActivityAlerts, jsonEncode(list));
    } catch (_) {}
  }

  /// Load activity alerts from persistent storage.
  static Future<List<SpaceAlertItem>> loadActivityAlerts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final str = prefs.getString(_keyActivityAlerts);
      if (str != null && str.isNotEmpty) {
        final decoded = jsonDecode(str) as List<dynamic>;
        return decoded
            .map((item) => SpaceAlertItem.fromJson(Map<String, dynamic>.from(item as Map)))
            .toList();
      }
    } catch (_) {}
    return [];
  }

  /// Load available rooms (standard + user created across all spaces).
  Future<List<String>> loadRooms() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList(_keyRooms);
      if (list != null && list.isNotEmpty) {
        for (final r in list) {
          final trimmed = r.trim();
          if (trimmed.isNotEmpty && !_cachedDeletedRooms.contains(trimmed) && !_cachedRooms.contains(trimmed)) {
            _cachedRooms.add(trimmed);
          }
        }
      }

      // Also discover any rooms created in space partitions
      final allKeys = prefs.getKeys();
      for (final k in allKeys) {
        if (k.startsWith('${_keyRooms}_')) {
          final spaceRooms = prefs.getStringList(k);
          if (spaceRooms != null) {
            for (final r in spaceRooms) {
              final trimmed = r.trim();
              if (trimmed.isNotEmpty && !_cachedDeletedRooms.contains(trimmed) && !_cachedRooms.contains(trimmed)) {
                _cachedRooms.add(trimmed);
              }
            }
          }
        }
      }

      _cachedRooms.removeWhere((r) => _cachedDeletedRooms.contains(r.trim()));
    } catch (_) {}
    return List<String>.unmodifiable(_cachedRooms);
  }

  /// Add a new custom room.
  Future<void> addRoom(String roomName) async {
    final trimmed = roomName.trim();
    if (trimmed.isEmpty) return;
    _cachedDeletedRooms.remove(trimmed);
    if (_cachedRooms.contains(trimmed)) return;

    _cachedRooms.add(trimmed);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_keyRooms, _cachedRooms);
      await prefs.setStringList(_keyDeletedRooms, _cachedDeletedRooms.toList());
    } catch (_) {}
  }

  /// Remove a room persistently.
  Future<void> removeRoom(String roomName) async {
    _cachedRooms.removeWhere((r) => r.toLowerCase() == roomName.toLowerCase());
    _cachedDeletedRooms.add(roomName.trim());
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_keyRooms, _cachedRooms);
      await prefs.setStringList(_keyDeletedRooms, _cachedDeletedRooms.toList());
    } catch (_) {}
  }

  /// Restore a deleted room name
  static void restoreRoom(String roomName) {
    final trimmed = roomName.trim();
    _cachedDeletedRooms.remove(trimmed);
    SharedPreferences.getInstance().then((prefs) {
      prefs.setStringList(_keyDeletedRooms, _cachedDeletedRooms.toList());
    }).catchError((_) {});
  }

  /// Save or replace room list
  Future<void> saveRooms(List<String> rooms) async {
    for (final r in rooms) {
      await addRoom(r);
    }
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

  static bool _isPrimarySpace(String spaceId) {
    if (spaceId == 'home_default' || spaceId == 'local-home' || spaceId.isEmpty) return true;
    if (_cachedSpaces.isNotEmpty && spaceId == _cachedSpaces.first['id']) return true;
    return false;
  }

  /// Load devices partitioned strictly by space.
  Future<List<ConnectedDeviceSummary>> loadDevicesForSpace(String spaceId) async {
    final isPrimary = _isPrimarySpace(spaceId);
    final key = isPrimary ? _keyDevicesList : '${_keyDevicesList}_$spaceId';
    try {
      final prefs = await SharedPreferences.getInstance();
      String? jsonListStr = prefs.getString(key);
      if ((jsonListStr == null || jsonListStr.isEmpty) && isPrimary) {
        jsonListStr = prefs.getString(_keyDevicesList);
      }
      if (jsonListStr != null && jsonListStr.isNotEmpty) {
        final List<dynamic> decodedList = jsonDecode(jsonListStr) as List<dynamic>;
        final List<ConnectedDeviceSummary> result = [];
        for (final item in decodedList) {
          final data = item as Map<String, dynamic>;
          final dId = data['id'] as String? ?? '';
          if (_cachedDeletedDeviceIds.contains(dId)) continue;
          result.add(
            ConnectedDeviceSummary(
              id: dId,
              name: data['name'] as String? ?? 'Smart Switch',
              model: data['model'] as String? ?? 'eh-smart-switch-4x',
              firmware: data['firmware'] as String? ?? '1.0.0',
              connectedVia: data['connectedVia'] as String? ?? 'Offline',
              signalLabel: 'Offline',
              roomName: data['roomName'] as String? ?? 'Living Room',
              online: false,
            ),
          );
        }
        final deduped = deduplicateDevices(result);
        if (isPrimary && deduped.isNotEmpty) {
          _cachedDevices.clear();
          _cachedDevices.addAll(deduped);
        }
        return List.unmodifiable(deduped);
      }
    } catch (e) {
      debugPrint('[DeviceStorageService] loadDevicesForSpace error: $e');
    }
    if ((isPrimary || _cachedSpaces.isEmpty || spaceId == _cachedSpaces.firstOrNull?['id']) && _cachedDevices.isNotEmpty) {
      return List<ConnectedDeviceSummary>.unmodifiable(
        _cachedDevices.where((d) => !_cachedDeletedDeviceIds.contains(d.id)),
      );
    }
    // Brand new non-primary space starts empty!
    return const [];
  }

  /// Save a device to a specific space partition.
  Future<void> saveDeviceForSpace(String spaceId, ConnectedDeviceSummary device) async {
    await removeDeletedDeviceId(device.id);
    final isPrimary = _isPrimarySpace(spaceId);
    final key = isPrimary ? _keyDevicesList : '${_keyDevicesList}_$spaceId';
    try {
      final current = List<ConnectedDeviceSummary>.from(await loadDevicesForSpace(spaceId));
      final idx = current.indexWhere((d) => d.id == device.id);
      if (idx >= 0) {
        current[idx] = device;
      } else {
        current.add(device);
      }
      final cleanList = deduplicateDevices(current);
      final prefs = await SharedPreferences.getInstance();
      final jsonList = cleanList.map((d) => {
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
      if (isPrimary) {
        await prefs.setString(_keyDevicesList, jsonEncode(jsonList));
        _cachedDevices.clear();
        _cachedDevices.addAll(cleanList);
      }
    } catch (e) {
      debugPrint('[DeviceStorageService] saveDeviceForSpace error: $e');
    }
  }

  /// Persist entire list of devices for a specific space partition.
  Future<void> saveDevicesForSpace(String spaceId, List<ConnectedDeviceSummary> devices) async {
    final cleanList = deduplicateDevices(devices);
    final isPrimary = _isPrimarySpace(spaceId);
    final key = isPrimary ? _keyDevicesList : '${_keyDevicesList}_$spaceId';
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = cleanList.map((d) => {
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
      if (isPrimary) {
        await prefs.setString(_keyDevicesList, jsonEncode(jsonList));
        _cachedDevices.clear();
        _cachedDevices.addAll(cleanList);
      }
    } catch (e) {
      debugPrint('[DeviceStorageService] saveDevicesForSpace error: $e');
    }
  }

  /// Remove a device from a specific space partition.
  Future<void> removeDeviceForSpace(String spaceId, String deviceId) async {
    await addDeletedDeviceId(deviceId);
    final isPrimary = _isPrimarySpace(spaceId);
    final key = isPrimary ? _keyDevicesList : '${_keyDevicesList}_$spaceId';
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
      if (isPrimary) {
        await prefs.setString(_keyDevicesList, jsonEncode(jsonList));
        _cachedDevices.removeWhere((d) => d.id == deviceId);
      }
      _cachedChannelLabels.remove(deviceId);
      _cachedDeviceIps.remove(deviceId);
      final toSerialize = <String, Map<String, String>>{};
      _cachedChannelLabels.forEach((devId, map) {
        toSerialize[devId] = map.map((k, v) => MapEntry(k.toString(), v));
      });
      await prefs.setString(_keyChannelLabels, jsonEncode(toSerialize));
    } catch (_) {}
  }

  /// Load rooms partitioned strictly by space.
  Future<List<String>> loadRoomsForSpace(String spaceId) async {
    final key = '${_keyRooms}_$spaceId';
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList(key);
      if (list != null && list.isNotEmpty) {
        final filtered = list.where((r) => !_cachedDeletedRooms.contains(r.trim())).toList();
        return List.unmodifiable(filtered);
      }
      if (spaceId == 'home_default') {
        final defaultList = prefs.getStringList(_keyRooms);
        if (defaultList != null && defaultList.isNotEmpty) {
          final filtered = defaultList.where((r) => !_cachedDeletedRooms.contains(r.trim())).toList();
          return List.unmodifiable(filtered);
        }
      }
    } catch (_) {}
    return const [];
  }

  /// Add a room to a specific space partition.
  Future<void> addRoomForSpace(String spaceId, String roomName) async {
    final trimmed = roomName.trim();
    if (trimmed.isEmpty) return;
    await addRoom(trimmed);
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

  /// Remove a room from a specific space partition.
  Future<void> removeRoomForSpace(String spaceId, String roomName) async {
    final trimmed = roomName.trim();
    if (trimmed.isEmpty) return;
    final key = '${_keyRooms}_$spaceId';
    try {
      final prefs = await SharedPreferences.getInstance();
      final current = List<String>.from(prefs.getStringList(key) ?? []);
      current.removeWhere((r) => r.toLowerCase() == trimmed.toLowerCase());
      await prefs.setStringList(key, current);
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

  // --- Notification Management Methods ---
  static Set<String> get deletedNotificationIds => Set.unmodifiable(_cachedDeletedNotifIds);
  static Set<String> get readNotificationIds => Set.unmodifiable(_cachedReadNotifIds);

  static Future<void> markNotificationAsRead(String id) async {
    _cachedReadNotifIds.add(id);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_keyReadNotifIds, _cachedReadNotifIds.toList());
    } catch (_) {}
  }

  static Future<void> markAllNotificationsAsRead(Iterable<String> ids) async {
    _cachedReadNotifIds.addAll(ids);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_keyReadNotifIds, _cachedReadNotifIds.toList());
    } catch (_) {}
  }

  static Future<void> deleteNotificationId(String id) async {
    _cachedDeletedNotifIds.add(id);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_keyDeletedNotifIds, _cachedDeletedNotifIds.toList());
    } catch (_) {}
  }

  static Future<void> deleteNotificationIds(Iterable<String> ids) async {
    _cachedDeletedNotifIds.addAll(ids);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_keyDeletedNotifIds, _cachedDeletedNotifIds.toList());
    } catch (_) {}
  }

  static Future<void> clearAllNotifications(Iterable<String> ids) async {
    _cachedDeletedNotifIds.addAll(ids);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_keyDeletedNotifIds, _cachedDeletedNotifIds.toList());
    } catch (_) {}
  }

  // --- Channel Activity Alert Methods ---
  static ChannelAlertConfig getChannelAlertConfig(String deviceId, int channelIndex) {
    final cleanId = deviceId.trim();
    if (cleanId.isEmpty) return const ChannelAlertConfig();

    final cleanLower = cleanId.toLowerCase();
    final cleanSanitized = cleanLower.replaceAll(RegExp(r'[^a-z0-9]'), '');
    final k1 = '${cleanId}_$channelIndex';
    final k2 = '${cleanId}_ch$channelIndex';
    final k3 = '${cleanLower}_$channelIndex';
    final k4 = '${cleanLower}_ch$channelIndex';
    final k5 = '${cleanSanitized}_$channelIndex';
    final k6 = '${cleanSanitized}_ch$channelIndex';

    if (_cachedChannelAlerts.containsKey(k1)) return _cachedChannelAlerts[k1]!;
    if (_cachedChannelAlerts.containsKey(k2)) return _cachedChannelAlerts[k2]!;
    if (_cachedChannelAlerts.containsKey(k3)) return _cachedChannelAlerts[k3]!;
    if (_cachedChannelAlerts.containsKey(k4)) return _cachedChannelAlerts[k4]!;
    if (_cachedChannelAlerts.containsKey(k5)) return _cachedChannelAlerts[k5]!;
    if (_cachedChannelAlerts.containsKey(k6)) return _cachedChannelAlerts[k6]!;

    // Fallback: check any key matching deviceId or name segment and channelIndex
    for (final entry in _cachedChannelAlerts.entries) {
      final keyLower = entry.key.toLowerCase();
      if (keyLower.endsWith('_$channelIndex') || keyLower.endsWith('_ch$channelIndex')) {
        final keyPrefix = keyLower.split('_').first;
        if (cleanLower.contains(keyPrefix) || keyLower.contains(cleanLower) || (cleanSanitized.isNotEmpty && keyLower.contains(cleanSanitized))) {
          return entry.value;
        }
      }
    }

    // Secondary fallback: if there is an active configured alert for this channel index across cached alerts, use it
    for (final entry in _cachedChannelAlerts.entries) {
      final keyLower = entry.key.toLowerCase();
      if ((keyLower.endsWith('_$channelIndex') || keyLower.endsWith('_ch$channelIndex')) && entry.value.enabled) {
        return entry.value;
      }
    }

    return const ChannelAlertConfig();
  }

  static Future<void> saveChannelAlertConfig(String deviceId, int channelIndex, ChannelAlertConfig config) async {
    final cleanId = deviceId.trim();
    if (cleanId.isEmpty) return;

    final cleanLower = cleanId.toLowerCase();
    final cleanSanitized = cleanLower.replaceAll(RegExp(r'[^a-z0-9]'), '');

    final keys = <String>{
      '${cleanId}_$channelIndex',
      '${cleanId}_ch$channelIndex',
      '${cleanLower}_$channelIndex',
      '${cleanLower}_ch$channelIndex',
      if (cleanSanitized.isNotEmpty) '${cleanSanitized}_$channelIndex',
      if (cleanSanitized.isNotEmpty) '${cleanSanitized}_ch$channelIndex',
    };

    for (final k in keys) {
      _cachedChannelAlerts[k] = config;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final mapToSave = <String, dynamic>{};
      _cachedChannelAlerts.forEach((k, v) {
        mapToSave[k] = v.toJson();
      });
      await prefs.setString(_keyChannelAlerts, jsonEncode(mapToSave));
      debugPrint('[DeviceStorageService] Channel alert config saved for keys=$keys enabled=${config.enabled}');
    } catch (e) {
      debugPrint('[DeviceStorageService] saveChannelAlertConfig error: $e');
    }
  }

  static Map<String, dynamic> getAllChannelAlertConfigsForDevice(String deviceId) {
    final result = <String, dynamic>{};
    for (int ch = 1; ch <= 8; ch++) {
      final cfg = getChannelAlertConfig(deviceId, ch);
      if (cfg.enabled || cfg.customMessage.isNotEmpty) {
        result[ch.toString()] = cfg.toJson();
      }
    }

    // Also check cached alerts directly in case saved under alias
    if (result.isEmpty) {
      for (final entry in _cachedChannelAlerts.entries) {
        if (entry.value.enabled || entry.value.customMessage.isNotEmpty) {
          final parts = entry.key.split('_');
          if (parts.isNotEmpty) {
            final last = parts.last.replaceAll('ch', '');
            final chIdx = int.tryParse(last);
            if (chIdx != null && chIdx >= 1 && chIdx <= 8) {
              result[chIdx.toString()] = entry.value.toJson();
            }
          }
        }
      }
    }

    return result;
  }

  // --- Cloud Sync & Connection Routing State Methods ---
  static bool get hasPendingCloudUpload => _cachedPendingCloudUpload;

  static Future<void> setPendingCloudUpload(bool pending) async {
    _cachedPendingCloudUpload = pending;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyPendingCloudUpload, pending);
    } catch (_) {}
  }

  static String get syncMode => _cachedSyncMode;

  static Future<void> setSyncMode(String mode) async {
    _cachedSyncMode = mode;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keySyncMode, mode);
    } catch (_) {}
  }

  static String get connectionRoutingMode => _cachedConnectionRoutingMode;

  static Future<void> setConnectionRoutingMode(String mode) async {
    _cachedConnectionRoutingMode = mode;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyConnectionRoutingMode, mode);
    } catch (_) {}
  }

  static DateTime? get lastCloudSyncTime =>
      _cachedLastCloudSyncTime != null ? DateTime.fromMillisecondsSinceEpoch(_cachedLastCloudSyncTime!) : null;

  static Future<void> recordCloudSyncSuccess() async {
    _cachedPendingCloudUpload = false;
    _cachedLastCloudSyncTime = DateTime.now().millisecondsSinceEpoch;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyPendingCloudUpload, false);
      await prefs.setInt(_keyLastCloudSyncTime, _cachedLastCloudSyncTime!);
    } catch (_) {}
  }

  /// Exports entire active home & spaces configuration to a JSON backup bundle.
  static Future<Map<String, dynamic>> exportFullBackupBundle() async {
    final spaces = await DeviceStorageService().loadSpaces();
    final devices = await DeviceStorageService().loadDevices();
    final rooms = await DeviceStorageService().loadRooms();
    final channelLabels = <String, Map<String, String>>{};
    _cachedChannelLabels.forEach((k, v) {
      channelLabels[k] = v.map((innerK, innerV) => MapEntry(innerK.toString(), innerV));
    });
    final channelAlerts = <String, dynamic>{};
    _cachedChannelAlerts.forEach((k, v) {
      channelAlerts[k] = v.toJson();
    });

    return {
      'version': 1,
      'exportedAt': DateTime.now().toIso8601String(),
      'spaces': spaces,
      'devices': devices.map((d) => {
        'id': d.id,
        'name': d.name,
        'model': d.model,
        'firmware': d.firmware,
        'connectedVia': d.connectedVia,
        'signalLabel': d.signalLabel,
        'roomName': d.roomName,
        'online': d.online,
      }).toList(),
      'rooms': rooms,
      'channelLabels': channelLabels,
      'channelAlerts': channelAlerts,
    };
  }

  static const String _keyRoutinesJson = 'eh_user_routines_v2';
  static const String _keyHomePrefsJson = 'eh_home_preferences_v2';
  static const String _keyUserAvatar = 'eh_user_avatar_v1';

  static Future<void> saveRoutinesJson(List<Map<String, dynamic>> routines) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyRoutinesJson, jsonEncode(routines));
    } catch (_) {}
  }

  static Future<List<Map<String, dynamic>>> loadRoutinesJson() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final str = prefs.getString(_keyRoutinesJson);
      if (str != null && str.isNotEmpty) {
        final list = jsonDecode(str);
        if (list is List) {
          return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        }
      }
    } catch (_) {}
    return [];
  }

  static Future<void> saveHomePreferencesJson(Map<String, dynamic> data) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyHomePrefsJson, jsonEncode(data));
    } catch (_) {}
  }

  static Future<Map<String, dynamic>> loadHomePreferencesJson() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final str = prefs.getString(_keyHomePrefsJson);
      if (str != null && str.isNotEmpty) {
        return Map<String, dynamic>.from(jsonDecode(str) as Map);
      }
    } catch (_) {}
    return {
      'temperatureUnit': 'Celsius (°C)',
      'notificationsEnabled': true,
      'timeFormat': '12-hour',
    };
  }

  static Future<void> saveUserAvatar(String avatarKey) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyUserAvatar, avatarKey);
    } catch (_) {}
  }

  static Future<String?> loadUserAvatar() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_keyUserAvatar);
    } catch (_) {}
    return null;
  }
}

/// Configuration for individual channel active/inactive activity alerts.
class ChannelAlertConfig {
  final bool enabled;
  final bool alertOnTurnOn;
  final bool alertOnTurnOff;
  final String customMessage;

  const ChannelAlertConfig({
    this.enabled = false,
    this.alertOnTurnOn = true,
    this.alertOnTurnOff = true,
    this.customMessage = '',
  });

  Map<String, dynamic> toJson() => {
    'enabled': enabled,
    'alertOnTurnOn': alertOnTurnOn,
    'alertOnTurnOff': alertOnTurnOff,
    'customMessage': customMessage,
  };

  factory ChannelAlertConfig.fromJson(Map<String, dynamic> json) => ChannelAlertConfig(
    enabled: json['enabled'] as bool? ?? false,
    alertOnTurnOn: json['alertOnTurnOn'] as bool? ?? true,
    alertOnTurnOff: json['alertOnTurnOff'] as bool? ?? true,
    customMessage: json['customMessage'] as String? ?? '',
  );

  ChannelAlertConfig copyWith({
    bool? enabled,
    bool? alertOnTurnOn,
    bool? alertOnTurnOff,
    String? customMessage,
  }) => ChannelAlertConfig(
    enabled: enabled ?? this.enabled,
    alertOnTurnOn: alertOnTurnOn ?? this.alertOnTurnOn,
    alertOnTurnOff: alertOnTurnOff ?? this.alertOnTurnOff,
    customMessage: customMessage ?? this.customMessage,
  );
}
