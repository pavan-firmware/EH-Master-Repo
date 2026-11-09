import 'device_models.dart';
import '../services/product_asset_resolver.dart';

enum HomeConnectionAvailability {
  connected,
  connecting,
  setupRequired,
  offline,
  unavailable,
}
enum HomeMemberRole {
  owner,
  admin,
  member,
  guest;

  String get label {
    switch (this) {
      case HomeMemberRole.owner:
        return 'Owner';
      case HomeMemberRole.admin:
        return 'Home Admin';
      case HomeMemberRole.member:
        return 'Member';
      case HomeMemberRole.guest:
        return 'Guest';
    }
  }
}
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

  HomePreferences copyWith({
    String? temperatureUnit,
    bool? notificationsEnabled,
    String? timeFormat,
  }) {
    return HomePreferences(
      temperatureUnit: temperatureUnit ?? this.temperatureUnit,
      notificationsEnabled:
          notificationsEnabled ?? this.notificationsEnabled,
      timeFormat: timeFormat ?? this.timeFormat,
    );
  }
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

  HomeSettingsData copyWith({
    String? id,
    String? name,
    String? ownerName,
    String? location,
    String? timezone,
    DateTime? createdAt,
    HomePreferences? preferences,
    HomeConnectionAvailability? connectionAvailability,
    String? connectionTransport,
    DateTime? lastChecked,
  }) {
    return HomeSettingsData(
      id: id ?? this.id,
      name: name ?? this.name,
      ownerName: ownerName ?? this.ownerName,
      location: location ?? this.location,
      timezone: timezone ?? this.timezone,
      createdAt: createdAt ?? this.createdAt,
      preferences: preferences ?? this.preferences,
      connectionAvailability:
          connectionAvailability ?? this.connectionAvailability,
      connectionTransport: connectionTransport ?? this.connectionTransport,
      lastChecked: lastChecked ?? this.lastChecked,
    );
  }
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
    this.email,
    this.lastActiveLabel,
  });

  final String id;
  final String displayName;
  final HomeMemberRole role;
  final HomeMemberStatus status;
  final String initials;
  final String? email;
  final String? lastActiveLabel;
}

class HomeInvitation {
  const HomeInvitation({
    required this.id,
    required this.recipientName,
    required this.initials,
    required this.invitedLabel,
    required this.expiresLabel,
    this.role = HomeMemberRole.member,
    this.code,
  });

  final String id;
  final String recipientName;
  final String initials;
  final String invitedLabel;
  final String expiresLabel;
  final HomeMemberRole role;
  final String? code;
}

class DiscoveredRoomDevice {
  const DiscoveredRoomDevice({
    required this.id,
    required this.name,
    required this.model,
    required this.signalLabel,
    required this.signal,
    required this.icon,
    this.imageUrl,
    this.productVariantId,
  });

  final String id;
  final String name;
  final String model;
  final String signalLabel;
  final DeviceConnection signal;
  final String icon;
  final String? imageUrl;
  final String? productVariantId;

  String? get resolvedImageUrl {
    final idOrModel = (productVariantId ?? model).toLowerCase().replaceAll('_', '-');
    // 1. Exact bundled catalog asset (placed by sync-mobile-catalog-assets.mjs)
    final bundled = resolveBundledProductAsset(idOrModel);
    if (bundled != null && bundled.isNotEmpty) return bundled;
    // 2. Explicit catalog path already stored in imageUrl
    if (imageUrl != null && imageUrl!.isNotEmpty && imageUrl!.startsWith('assets/products/catalog/')) return imageUrl;
    // 3. Any non-local imageUrl (e.g. http, /api/)
    if (imageUrl != null && imageUrl!.isNotEmpty && !imageUrl!.contains('smart_')) return imageUrl;
    // 4. Conventional catalog path based on variant id — works as soon as the
    //    admin runs "Sync Mobile Assets" and rebuilds the APK.
    if (idOrModel.contains('fan')) {
      return 'assets/products/catalog/eh-smart-fan-1x/hero.webp';
    }
    if (idOrModel.contains('socket') || idOrModel.contains('plug')) {
      return 'assets/products/catalog/eh-smart-socket-2x/hero.webp';
    }
    // For switches, use the canonical eh-smart-switch-Nx path so the catalog
    // image (once synced) is used automatically.
    final match = RegExp(r'(1|2|3|4|5)x').firstMatch(idOrModel);
    final variant = match?.group(1) ?? '3';
    return 'assets/products/catalog/eh-smart-switch-${variant}x/hero.webp';
  }
}

