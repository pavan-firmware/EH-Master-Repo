import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/connection_models.dart';

/// Persistent storage service for commissioned EH Home devices and rooms.
class DeviceStorageService {
  DeviceStorageService();

  static const String _keyPrimaryDevice = 'eh_primary_device_v3';
  static const String _keyRooms = 'eh_custom_rooms_v3';

  // In-memory cache for synchronous reads and instant startup
  static ConnectedDeviceSummary? _cachedDevice;
  static final List<String> _cachedRooms = [
    'Living Room',
    'Bedroom',
    'Kitchen',
    'Office',
    'Dining Room',
    'Balcony',
  ];

  static ConnectedDeviceSummary? get cachedDevice => _cachedDevice;

  /// Global upfront initialization called from main() before runApp().
  static Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(_keyPrimaryDevice);
      if (jsonStr != null && jsonStr.isNotEmpty) {
        final data = jsonDecode(jsonStr) as Map<String, dynamic>;
        _cachedDevice = ConnectedDeviceSummary(
          id: data['id'] as String? ?? '',
          name: data['name'] as String? ?? 'EH Smart Switch 3X',
          model: data['model'] as String? ?? 'eh-smart-switch-3x',
          firmware: data['firmware'] as String? ?? '1.0.0',
          connectedVia: data['connectedVia'] as String? ?? 'Wi-Fi (2.4 GHz)',
          signalLabel: data['signalLabel'] as String? ?? 'Strong',
          roomName: data['roomName'] as String? ?? 'Living Room',
          online: data['online'] as bool? ?? true,
        );
        debugPrint('[HOME] INIT_HYDRATED id=${_cachedDevice!.id} room=${_cachedDevice!.roomName}');
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

  /// Save a commissioned device to persistent storage.
  Future<void> saveDevice(ConnectedDeviceSummary device) async {
    _cachedDevice = device;
    final jsonMap = {
      'id': device.id,
      'name': device.name,
      'model': device.model,
      'firmware': device.firmware,
      'connectedVia': device.connectedVia,
      'signalLabel': device.signalLabel,
      'roomName': device.roomName,
      'online': device.online,
    };
    final jsonStr = jsonEncode(jsonMap);

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyPrimaryDevice, jsonStr);
      debugPrint('[HOME] DEVICE_PERSISTED (shared_preferences) id=${device.id} room=${device.roomName}');
    } catch (e) {
      debugPrint('[HOME] SharedPreferences write warning: $e');
    }
  }

  /// Load the commissioned device from persistent storage.
  Future<ConnectedDeviceSummary?> loadDevice() async {
    if (_cachedDevice != null) {
      return _cachedDevice;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(_keyPrimaryDevice);
      if (jsonStr != null && jsonStr.isNotEmpty) {
        final data = jsonDecode(jsonStr) as Map<String, dynamic>;
        _cachedDevice = ConnectedDeviceSummary(
          id: data['id'] as String? ?? '',
          name: data['name'] as String? ?? 'EH Smart Switch 3X',
          model: data['model'] as String? ?? 'eh-smart-switch-3x',
          firmware: data['firmware'] as String? ?? '1.0.0',
          connectedVia: data['connectedVia'] as String? ?? 'Wi-Fi (2.4 GHz)',
          signalLabel: data['signalLabel'] as String? ?? 'Strong',
          roomName: data['roomName'] as String? ?? 'Living Room',
          online: data['online'] as bool? ?? true,
        );
        debugPrint('[HOME] DEVICE_HYDRATED (shared_preferences) id=${_cachedDevice!.id} room=${_cachedDevice!.roomName}');
        return _cachedDevice;
      }
    } catch (e) {
      debugPrint('[HOME] SharedPreferences read warning: $e');
    }

    return null;
  }

  /// Remove the commissioned device (e.g. on "Forget Device").
  Future<void> clearDevice() async {
    _cachedDevice = null;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyPrimaryDevice);
    } catch (_) {}
    debugPrint('[HOME] DEVICE_CLEARED');
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
}
