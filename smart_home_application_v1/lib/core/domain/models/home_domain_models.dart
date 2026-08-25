import '../../capabilities/models/capability_models.dart';

enum HomeMemberRole { owner, admin, member, guest }

class UserHome {
  const UserHome({
    required this.id,
    required this.name,
    this.timezone = 'UTC',
    this.address,
    this.role = HomeMemberRole.owner,
  });

  final String id;
  final String name;
  final String timezone;
  final String? address;
  final HomeMemberRole role;
}

class HomeFloor {
  const HomeFloor({
    required this.id,
    required this.homeId,
    required this.name,
    this.level = 0,
  });

  final String id;
  final String homeId;
  final String name;
  final int level;
}

class HomeRoom {
  const HomeRoom({
    required this.id,
    required this.homeId,
    this.floorId,
    required this.name,
    this.iconKey = 'default',
    this.sortOrder = 0,
  });

  final String id;
  final String homeId;
  final String? floorId;
  final String name;
  final String iconKey;
  final int sortOrder;
}

class HomeMember {
  const HomeMember({
    required this.membershipId,
    required this.homeId,
    required this.userId,
    this.email,
    required this.role,
    this.acceptedAt,
  });

  final String membershipId;
  final String homeId;
  final String userId;
  final String? email;
  final HomeMemberRole role;
  final String? acceptedAt;
}

class DomainDeviceSummary {
  const DomainDeviceSummary({
    required this.deviceId,
    required this.serialNumber,
    required this.productVariantId,
    required this.displayName,
    this.homeId,
    this.floorId,
    this.roomId,
    this.roomName,
    required this.connectionState,
    required this.channels,
    required this.capabilities,
  });

  final String deviceId;
  final String serialNumber;
  final String productVariantId;
  final String displayName;
  final String? homeId;
  final String? floorId;
  final String? roomId;
  final String? roomName;
  final CapabilityConnectionState connectionState;
  final List<ResolvedDeviceChannel> channels;
  final List<String> capabilities;

  bool get isOnline => connectionState == CapabilityConnectionState.online;
}
