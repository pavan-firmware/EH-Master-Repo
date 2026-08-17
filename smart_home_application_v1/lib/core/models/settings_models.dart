import 'device_models.dart';

enum HomeConnectionAvailability {
  connected,
  connecting,
  setupRequired,
  offline,
  unavailable,
}

enum HomeMemberRole { owner, member }

enum HomeMemberStatus { active, pending, unavailable }

enum SettingsOperationResult {
  success,
  unavailable,
  unauthorized,
  unsupported,
  failed,
}

class HomePreferences {
  const HomePreferences({
    required this.temperatureUnit,
    required this.notificationsEnabled,
    required this.timeFormat,
  });

  final String temperatureUnit;
  final bool notificationsEnabled;
  final String timeFormat;
}

class HomeSettingsData {
  const HomeSettingsData({
    required this.id,
    required this.name,
    required this.ownerName,
    required this.location,
    required this.timezone,
    required this.createdAt,
    required this.preferences,
    required this.connectionAvailability,
    required this.connectionTransport,
    required this.lastChecked,
  });

  final String id;
  final String name;
  final String ownerName;
  final String? location;
  final String timezone;
  final DateTime createdAt;
  final HomePreferences preferences;
  final HomeConnectionAvailability connectionAvailability;
  final String connectionTransport;
  final DateTime? lastChecked;
}

class HomeSettingsDraft {
  const HomeSettingsDraft({
    required this.name,
    required this.location,
    required this.timezone,
    required this.preferences,
  });

  final String name;
  final String? location;
  final String timezone;
  final HomePreferences preferences;
}

class HomeMember {
  const HomeMember({
    required this.id,
    required this.displayName,
    required this.role,
    required this.status,
    required this.initials,
    this.lastActiveLabel,
  });

  final String id;
  final String displayName;
  final HomeMemberRole role;
  final HomeMemberStatus status;
  final String initials;
  final String? lastActiveLabel;
}

class HomeInvitation {
  const HomeInvitation({
    required this.id,
    required this.recipientName,
    required this.initials,
    required this.invitedLabel,
    required this.expiresLabel,
  });

  final String id;
  final String recipientName;
  final String initials;
  final String invitedLabel;
  final String expiresLabel;
}

class DiscoveredRoomDevice {
  const DiscoveredRoomDevice({
    required this.id,
    required this.name,
    required this.model,
    required this.signalLabel,
    required this.signal,
    required this.icon,
  });

  final String id;
  final String name;
  final String model;
  final String signalLabel;
  final DeviceConnection signal;
  final String icon;
}
