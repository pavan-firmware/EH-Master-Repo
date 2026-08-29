import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models/connection_models.dart';

/// Persistent storage service for commissioned EH Home devices and rooms.
class DeviceStorageService {
  DeviceStorageService({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  static const String _keyPrimaryDevice = 'eh_primary_device_v1';
  static const String _keyRooms = 'eh_custom_rooms_v1';

  // In-memory cache for fast access and fallback in headless/test environments
  static ConnectedDeviceSummary? _cachedDevice;
  static final List<String> _cachedRooms = [
    'Living Room',
    'Bedroom',
    'Kitchen',
    'Office',
    'Dining Room',
    'Balcony',
  ];

  /// Save a commissioned device to persistent storage.
  Future<void> saveDevice(ConnectedDeviceSummary device) async {
    _cachedDevice = device;
    try {
      final data = {
        'id': device.id,
        'name': device.name,
        'model': device.model,
        'firmware': device.firmware,
        'connectedVia': device.connectedVia,
        'signalLabel': device.signalLabel,
        'roomName': device.roomName,
        'online': device.online,
      };
      await _storage.write(key: _keyPrimaryDevice, value: jsonEncode(data));
      debugPrint('[HOME] DEVICE_PERSISTED id=${device.id} room=${device.roomName}');
    } catch (e) {
      debugPrint('[HOME] Storage write warning (using memory cache): $e');
    }
  }

  /// Load the commissioned device from persistent storage.
  Future<ConnectedDeviceSummary?> loadDevice() async {
    if (_cachedDevice != null) {
      return _cachedDevice;
    }

    try {
      final jsonStr = await _storage.read(key: _keyPrimaryDevice);
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
        debugPrint('[HOME] DEVICE_HYDRATED id=${_cachedDevice!.id}');
        return _cachedDevice;
      }
    } catch (e) {
      debugPrint('[HOME] Storage read warning: $e');
    }
    return null;
  }

  /// Remove the commissioned device (e.g. on "Forget Device").
  Future<void> clearDevice() async {
    _cachedDevice = null;
    try {
      await _storage.delete(key: _keyPrimaryDevice);
      debugPrint('[HOME] DEVICE_CLEARED');
    } catch (e) {
      debugPrint('[HOME] Storage delete warning: $e');
    }
  }

  /// Load available rooms (standard + user created).
  Future<List<String>> loadRooms() async {
    try {
      final jsonStr = await _storage.read(key: _keyRooms);
      if (jsonStr != null && jsonStr.isNotEmpty) {
        final list = (jsonDecode(jsonStr) as List<dynamic>).map((e) => e.toString()).toList();
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
      await _storage.write(key: _keyRooms, value: jsonEncode(_cachedRooms));
    } catch (_) {}
  }
}
