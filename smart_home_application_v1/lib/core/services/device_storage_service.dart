import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/connection_models.dart';

/// Persistent storage service for multiple commissioned EH Home devices and rooms.
class DeviceStorageService {
  DeviceStorageService();

  static const String _keyDevicesList = 'eh_devices_list_v4';
  static const String _keyRooms = 'eh_custom_rooms_v4';

  // In-memory cache for synchronous reads and instant startup
  static final List<ConnectedDeviceSummary> _cachedDevices = [];
  static final List<String> _cachedRooms = [
    'Living Room',
    'Bedroom',
    'Kitchen',
    'Office',
    'Dining Room',
    'Balcony',
  ];

  static ConnectedDeviceSummary? get primaryDevice =>
      _cachedDevices.isNotEmpty ? _cachedDevices.first : null;

  static List<ConnectedDeviceSummary> get cachedDevices =>
      List<ConnectedDeviceSummary>.unmodifiable(_cachedDevices);

  /// Global upfront initialization called from main() before runApp().
  static Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonListStr = prefs.getString(_keyDevicesList);
      if (jsonListStr != null && jsonListStr.isNotEmpty) {
        final List<dynamic> decodedList = jsonDecode(jsonListStr) as List<dynamic>;
        _cachedDevices.clear();
        for (final item in decodedList) {
          final data = item as Map<String, dynamic>;
          _cachedDevices.add(
            ConnectedDeviceSummary(
              id: data['id'] as String? ?? '',
              name: data['name'] as String? ?? 'Smart Switch 3X',
              model: data['model'] as String? ?? 'eh-smart-switch-3x',
              firmware: data['firmware'] as String? ?? '1.0.0',
              connectedVia: data['connectedVia'] as String? ?? 'Wi-Fi (2.4 GHz)',
              signalLabel: data['signalLabel'] as String? ?? 'Strong',
              roomName: data['roomName'] as String? ?? 'Living Room',
              online: data['online'] as bool? ?? true,
            ),
          );
        }
        debugPrint('[HOME] INIT_HYDRATED devices_count=${_cachedDevices.length}');
      }
      final list = prefs.getStringList(_keyRooms);
      if (list != null && list.isNotEmpty) {
        for (final r in list) {
          if (!_cachedRooms.contains(r)) {
            _cachedRooms.add(r);
          }
        }
      }
    } catch (e) {
      debugPrint('[HOME] DeviceStorageService.init warning: $e');
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

    final jsonStr = jsonEncode(jsonList);

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyDevicesList, jsonStr);
      debugPrint('[HOME] DEVICE_PERSISTED id=${device.id} room=${device.roomName} total=${_cachedDevices.length}');
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
        final List<dynamic> decodedList = jsonDecode(jsonListStr) as List<dynamic>;
        _cachedDevices.clear();
        for (final item in decodedList) {
          final data = item as Map<String, dynamic>;
          _cachedDevices.add(
            ConnectedDeviceSummary(
              id: data['id'] as String? ?? '',
              name: data['name'] as String? ?? 'Smart Switch 3X',
              model: data['model'] as String? ?? 'eh-smart-switch-3x',
              firmware: data['firmware'] as String? ?? '1.0.0',
              connectedVia: data['connectedVia'] as String? ?? 'Wi-Fi (2.4 GHz)',
              signalLabel: data['signalLabel'] as String? ?? 'Strong',
              roomName: data['roomName'] as String? ?? 'Living Room',
              online: data['online'] as bool? ?? true,
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

  static const String _keyQuickControls = 'eh_quick_controls_v4';
  static final List<String> _cachedQuickControls = [];

  /// Load selected quick control IDs.
  Future<List<String>> loadQuickControlIds() async {
    if (_cachedQuickControls.isNotEmpty) {
      return List<String>.unmodifiable(_cachedQuickControls);
    }
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
  Future<void> saveQuickControlIds(List<String> ids) async {
    _cachedQuickControls.clear();
    _cachedQuickControls.addAll(ids);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_keyQuickControls, ids);
    } catch (_) {}
  }
}
