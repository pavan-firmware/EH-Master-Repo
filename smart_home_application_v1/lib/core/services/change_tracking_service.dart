import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'device_storage_service.dart';

enum ChangeType {
  created,
  modified,
  deleted;

  static ChangeType fromString(String val) {
    switch (val.toLowerCase()) {
      case 'created':
      case 'create':
        return ChangeType.created;
      case 'deleted':
      case 'delete':
        return ChangeType.deleted;
      case 'modified':
      case 'modify':
      case 'update':
      default:
        return ChangeType.modified;
    }
  }

  String get label => switch (this) {
        ChangeType.created => 'Added',
        ChangeType.modified => 'Modified',
        ChangeType.deleted => 'Removed',
      };
}

@immutable
class TrackedChange {
  final String id;
  final String entityType; // 'home', 'room', 'device', 'control', 'channel', 'notification_preference', 'quick_controls', 'favourites', 'routine'
  final String entityId;
  final String field; // 'name', 'room', 'label', 'alertConfig', 'schedule', 'status', 'value', etc.
  final String? oldValue;
  final String? newValue;
  final ChangeType changeType;
  final DateTime timestamp;

  const TrackedChange({
    required this.id,
    required this.entityType,
    required this.entityId,
    required this.field,
    this.oldValue,
    this.newValue,
    required this.changeType,
    required this.timestamp,
  });

  String get area => switch (entityType.toLowerCase()) {
        'home' || 'space' || 'homesettings' => 'Home Details & Spaces',
        'room' => 'Spaces & Rooms',
        'device' => 'Connected Hardware Nodes',
        'control' || 'channel' || 'channellabels' || 'channelalert' => 'Device Controls & Labels',
        'notification' || 'notification_preference' => 'Notification & Alert Preferences',
        'quick_controls' || 'favourites' || 'dashboard' => 'Dashboard Favourites & Tiles',
        'routine' || 'automation' => 'Routines & Automations',
        _ => 'Other Settings',
      };

  String get displaySummary {
    switch (changeType) {
      case ChangeType.created:
        if (entityType.toLowerCase() == 'room') {
          return 'Room added: $newValue';
        } else if (entityType.toLowerCase() == 'device') {
          return 'Device commissioned: $newValue';
        } else if (entityType.toLowerCase() == 'routine' || entityType.toLowerCase() == 'automation') {
          return 'Routine created: $newValue';
        }
        return '$field created: $newValue';

      case ChangeType.deleted:
        if (entityType.toLowerCase() == 'room') {
          return 'Room deleted: ${oldValue ?? entityId}';
        } else if (entityType.toLowerCase() == 'device') {
          return 'Device removed: ${oldValue ?? entityId}';
        } else if (entityType.toLowerCase() == 'routine' || entityType.toLowerCase() == 'automation') {
          return 'Routine deleted: ${oldValue ?? entityId}';
        }
        return '$field deleted: ${oldValue ?? entityId}';

      case ChangeType.modified:
        final fieldName = switch (field.toLowerCase()) {
          'name' => entityType.toLowerCase() == 'room' ? 'Room renamed' : (entityType.toLowerCase() == 'device' ? 'Device renamed' : 'Name updated'),
          'room' || 'roomname' => 'Device moved',
          'channellabel' || 'label' => 'Control renamed',
          'alertconfig' => 'Channel alert config',
          'timeformat' => 'Time format',
          'timezone' => 'Time zone',
          'location' => 'Location',
          'temperatureunit' => 'Temperature unit',
          'quickcontrols' => 'Quick controls',
          'favourites' => 'Dashboard favourites',
          _ => field,
        };

        if (oldValue != null && oldValue!.isNotEmpty && newValue != null) {
          return '$fieldName: $oldValue → $newValue';
        } else if (newValue != null) {
          return '$fieldName: $newValue';
        }
        return '$fieldName modified';
    }
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'entityType': entityType,
        'entityId': entityId,
        'field': field,
        'oldValue': oldValue,
        'newValue': newValue,
        'changeType': changeType.name,
        'timestamp': timestamp.toIso8601String(),
      };

  factory TrackedChange.fromJson(Map<String, dynamic> json) => TrackedChange(
        id: json['id'] as String? ?? 'change_${DateTime.now().microsecondsSinceEpoch}',
        entityType: json['entityType'] as String? ?? 'settings',
        entityId: json['entityId'] as String? ?? '',
        field: json['field'] as String? ?? 'value',
        oldValue: json['oldValue'] as String?,
        newValue: json['newValue'] as String?,
        changeType: ChangeType.fromString(json['changeType'] as String? ?? 'modified'),
        timestamp: json['timestamp'] != null ? DateTime.parse(json['timestamp'] as String) : DateTime.now(),
      );
}

/// Centralized change tracking service that records all local edits across
/// homes, spaces, rooms, devices, labels, alert preferences, dashboard controls,
/// and routines. Persists across app launches and merges repeated modifications.
class ChangeTrackingService extends ChangeNotifier {
  ChangeTrackingService._();
  static final ChangeTrackingService instance = ChangeTrackingService._();

  static const String _keyTrackedChanges = 'eh_tracked_pending_changes_v1';

  final List<TrackedChange> _pendingChanges = [];
  bool _initialized = false;

  List<TrackedChange> get pendingChanges => List.unmodifiable(_pendingChanges);
  bool get hasPendingChanges => _pendingChanges.isNotEmpty;

  Map<String, List<TrackedChange>> get changesByArea {
    final Map<String, List<TrackedChange>> grouped = {};
    for (final change in _pendingChanges) {
      grouped.putIfAbsent(change.area, () => []).add(change);
    }
    return grouped;
  }

  Future<void> init() async {
    if (_initialized) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final rawList = prefs.getStringList(_keyTrackedChanges);
      if (rawList != null && rawList.isNotEmpty) {
        _pendingChanges.clear();
        for (final item in rawList) {
          try {
            final map = jsonDecode(item) as Map<String, dynamic>;
            _pendingChanges.add(TrackedChange.fromJson(map));
          } catch (_) {}
        }
      }
    } catch (_) {}
    _initialized = true;
    notifyListeners();
  }

  /// Record or merge a modification to an entity
  Future<void> recordChange({
    required String entityType,
    required String entityId,
    required String field,
    required String? oldValue,
    required String? newValue,
    required ChangeType changeType,
  }) async {
    // 1. If old and new values are identical, do not record a change
    if (changeType == ChangeType.modified && oldValue != null && newValue != null && oldValue.trim() == newValue.trim()) {
      return;
    }

    // 2. Find existing pending change for the same entity and field
    final index = _pendingChanges.indexWhere(
      (c) => c.entityType.toLowerCase() == entityType.toLowerCase() &&
             c.entityId == entityId &&
             c.field.toLowerCase() == field.toLowerCase(),
    );

    if (index != -1) {
      final existing = _pendingChanges[index];

      // Merge logic:
      if (existing.changeType == ChangeType.created) {
        if (changeType == ChangeType.deleted) {
          // Created locally and then deleted locally before upload -> remove completely!
          _pendingChanges.removeAt(index);
        } else if (changeType == ChangeType.modified) {
          // Entity was created locally and now updated -> keep created with updated newValue
          _pendingChanges[index] = TrackedChange(
            id: existing.id,
            entityType: entityType,
            entityId: entityId,
            field: field,
            oldValue: existing.oldValue,
            newValue: newValue,
            changeType: ChangeType.created,
            timestamp: DateTime.now(),
          );
        }
      } else if (existing.changeType == ChangeType.modified) {
        if (changeType == ChangeType.deleted) {
          // Modified then deleted -> record deletion, keeping original oldValue
          _pendingChanges[index] = TrackedChange(
            id: existing.id,
            entityType: entityType,
            entityId: entityId,
            field: field,
            oldValue: existing.oldValue,
            newValue: null,
            changeType: ChangeType.deleted,
            timestamp: DateTime.now(),
          );
        } else if (changeType == ChangeType.modified) {
          // If reverted back to original value, remove the record completely!
          if (existing.oldValue != null && newValue != null && existing.oldValue!.trim() == newValue.trim()) {
            _pendingChanges.removeAt(index);
          } else {
            // Keep original oldValue, update newValue
            _pendingChanges[index] = TrackedChange(
              id: existing.id,
              entityType: entityType,
              entityId: entityId,
              field: field,
              oldValue: existing.oldValue,
              newValue: newValue,
              changeType: ChangeType.modified,
              timestamp: DateTime.now(),
            );
          }
        }
      } else if (existing.changeType == ChangeType.deleted) {
        if (changeType == ChangeType.created) {
          if (existing.oldValue != null && newValue != null && existing.oldValue!.trim() == newValue.trim()) {
            // Deleted then recreated with same identity -> cancels out!
            _pendingChanges.removeAt(index);
          } else {
            _pendingChanges[index] = TrackedChange(
              id: existing.id,
              entityType: entityType,
              entityId: entityId,
              field: field,
              oldValue: existing.oldValue,
              newValue: newValue,
              changeType: ChangeType.modified,
              timestamp: DateTime.now(),
            );
          }
        }
      }
    } else {
      // Create new change record
      _pendingChanges.add(
        TrackedChange(
          id: 'change_${DateTime.now().microsecondsSinceEpoch}',
          entityType: entityType,
          entityId: entityId,
          field: field,
          oldValue: oldValue,
          newValue: newValue,
          changeType: changeType,
          timestamp: DateTime.now(),
        ),
      );
    }

    await _persist();
    await DeviceStorageService.setPendingCloudUpload(hasPendingChanges);
    notifyListeners();
  }

  /// Remove specific changes after successful reconciliation or upload
  Future<void> removeChanges(List<String> ids) async {
    final idSet = ids.toSet();
    _pendingChanges.removeWhere((c) => idSet.contains(c.id));
    await _persist();
    await DeviceStorageService.setPendingCloudUpload(hasPendingChanges);
    notifyListeners();
  }

  /// Clear all tracked changes once upload succeeds
  Future<void> clearChanges() async {
    _pendingChanges.clear();
    await _persist();
    await DeviceStorageService.setPendingCloudUpload(false);
    notifyListeners();
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_pendingChanges.isEmpty) {
        await prefs.remove(_keyTrackedChanges);
      } else {
        final list = _pendingChanges.map((c) => jsonEncode(c.toJson())).toList();
        await prefs.setStringList(_keyTrackedChanges, list);
      }
    } catch (_) {}
  }
}
