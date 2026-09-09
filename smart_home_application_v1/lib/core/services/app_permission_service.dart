import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

enum AppPermissionType {
  bluetooth,
  camera,
  notifications,
  location,
}

enum AppPermissionStatus {
  granted,
  denied,
  permanentlyDenied,
  restricted,
  unsupported,
}

class AppPermissionService {
  const AppPermissionService();

  Future<AppPermissionStatus> checkStatus(AppPermissionType type) async {
    try {
      final perm = _mapPermission(type);
      if (perm == null) return AppPermissionStatus.unsupported;
      final status = await perm.status;
      return _mapStatus(status);
    } catch (_) {
      return AppPermissionStatus.unsupported;
    }
  }

  Future<AppPermissionStatus> requestPermission(
    BuildContext context,
    AppPermissionType type, {
    String? customRationale,
  }) async {
    final perm = _mapPermission(type);
    if (perm == null) return AppPermissionStatus.unsupported;

    final currentStatus = await perm.status;
    if (currentStatus.isGranted) {
      return AppPermissionStatus.granted;
    }

    if (currentStatus.isPermanentlyDenied) {
      if (context.mounted) {
        await _showSettingsDialog(context, type);
      }
      return AppPermissionStatus.permanentlyDenied;
    }

    // Show pre-request rationale dialog if not yet requested
    if (context.mounted && (customRationale != null || _getDefaultRationale(type) != null)) {
      final proceed = await _showRationaleDialog(
        context,
        type,
        customRationale ?? _getDefaultRationale(type)!,
      );
      if (!proceed) return AppPermissionStatus.denied;
    }

    try {
      final result = await perm.request();
      final mapped = _mapStatus(result);
      if (mapped == AppPermissionStatus.permanentlyDenied && context.mounted) {
        await _showSettingsDialog(context, type);
      }
      return mapped;
    } catch (_) {
      return AppPermissionStatus.denied;
    }
  }

  Permission? _mapPermission(AppPermissionType type) {
    switch (type) {
      case AppPermissionType.bluetooth:
        return Permission.bluetoothScan;
      case AppPermissionType.camera:
        return Permission.camera;
      case AppPermissionType.notifications:
        return Permission.notification;
      case AppPermissionType.location:
        return Permission.locationWhenInUse;
    }
  }

  AppPermissionStatus _mapStatus(PermissionStatus status) {
    if (status.isGranted || status.isLimited) {
      return AppPermissionStatus.granted;
    }
    if (status.isPermanentlyDenied) {
      return AppPermissionStatus.permanentlyDenied;
    }
    if (status.isRestricted) {
      return AppPermissionStatus.restricted;
    }
    return AppPermissionStatus.denied;
  }

  String? _getDefaultRationale(AppPermissionType type) {
    switch (type) {
      case AppPermissionType.bluetooth:
        return 'EH Home needs Bluetooth access to discover and securely configure nearby smart devices.';
      case AppPermissionType.camera:
        return 'Camera access is required to scan QR codes on device hardware.';
      case AppPermissionType.notifications:
        return 'Allow notifications to receive critical alerts, device status changes, and automation updates.';
      case AppPermissionType.location:
        return 'Location access is required by Android to scan for nearby Bluetooth Low Energy devices.';
    }
  }

  String _getTitle(AppPermissionType type) {
    switch (type) {
      case AppPermissionType.bluetooth:
        return 'Bluetooth Permission';
      case AppPermissionType.camera:
        return 'Camera Permission';
      case AppPermissionType.notifications:
        return 'Notifications';
      case AppPermissionType.location:
        return 'Location Access';
    }
  }

  Future<bool> _showRationaleDialog(
    BuildContext context,
    AppPermissionType type,
    String rationale,
  ) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: Text(_getTitle(type)),
        content: Text(rationale),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(false),
            child: const Text('Not now'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogCtx).pop(true),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Future<void> _showSettingsDialog(BuildContext context, AppPermissionType type) async {
    await showDialog<void>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: Text('${_getTitle(type)} Required'),
        content: const Text(
          'This permission was previously denied. Please enable it in system settings to use this feature.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(dialogCtx).pop();
              openAppSettings();
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }
}
