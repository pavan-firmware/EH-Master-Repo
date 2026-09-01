import 'package:flutter/foundation.dart';

@immutable
class HomeAccessPermissions {
  const HomeAccessPermissions({
    this.canManageHome = false,
    this.canDeleteHome = false,
    this.canManageMembers = false,
    this.canTransferOwnership = false,
    this.canManageDevices = false,
    this.canControlDevices = false,
    this.canManageAutomations = false,
    this.canExecuteAutomations = false,
    this.canViewHome = true,
  });

  final bool canManageHome;
  final bool canDeleteHome;
  final bool canManageMembers;
  final bool canTransferOwnership;
  final bool canManageDevices;
  final bool canControlDevices;
  final bool canManageAutomations;
  final bool canExecuteAutomations;
  final bool canViewHome;

  factory HomeAccessPermissions.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const HomeAccessPermissions();
    return HomeAccessPermissions(
      canManageHome: json['canManageHome'] as bool? ?? false,
      canDeleteHome: json['canDeleteHome'] as bool? ?? false,
      canManageMembers: json['canManageMembers'] as bool? ?? false,
      canTransferOwnership: json['canTransferOwnership'] as bool? ?? false,
      canManageDevices: json['canManageDevices'] as bool? ?? false,
      canControlDevices: json['canControlDevices'] as bool? ?? false,
      canManageAutomations: json['canManageAutomations'] as bool? ?? false,
      canExecuteAutomations: json['canExecuteAutomations'] as bool? ?? false,
      canViewHome: json['canViewHome'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
        'canManageHome': canManageHome,
        'canDeleteHome': canDeleteHome,
        'canManageMembers': canManageMembers,
        'canTransferOwnership': canTransferOwnership,
        'canManageDevices': canManageDevices,
        'canControlDevices': canControlDevices,
        'canManageAutomations': canManageAutomations,
        'canExecuteAutomations': canExecuteAutomations,
        'canViewHome': canViewHome,
      };
}

@immutable
class UserAccountProfile {
  const UserAccountProfile({
    required this.id,
    required this.email,
    this.fullName,
    this.phoneNumber,
    this.avatarUrl,
    this.timezone = 'UTC',
    this.emailVerified = false,
    this.createdAt,
    this.activeSessionsCount = 1,
  });

  final String id;
  final String email;
  final String? fullName;
  final String? phoneNumber;
  final String? avatarUrl;
  final String timezone;
  final bool emailVerified;
  final String? createdAt;
  final int activeSessionsCount;

  factory UserAccountProfile.fromJson(Map<String, dynamic> json) {
    return UserAccountProfile(
      id: json['id'] as String? ?? '',
      email: json['email'] as String? ?? '',
      fullName: json['fullName'] as String?,
      phoneNumber: json['phoneNumber'] as String?,
      avatarUrl: json['avatarUrl'] as String?,
      timezone: json['timezone'] as String? ?? 'UTC',
      emailVerified: json['emailVerified'] as bool? ?? false,
      createdAt: json['createdAt'] as String?,
      activeSessionsCount: json['activeSessionsCount'] as int? ?? 1,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'email': email,
        'fullName': fullName,
        'phoneNumber': phoneNumber,
        'avatarUrl': avatarUrl,
        'timezone': timezone,
        'emailVerified': emailVerified,
        'createdAt': createdAt,
        'activeSessionsCount': activeSessionsCount,
      };
}

@immutable
class AccountSessionItem {
  const AccountSessionItem({
    required this.id,
    required this.userId,
    this.deviceName = 'Mobile Device',
    this.ipAddress = '127.0.0.1',
    this.userAgent = 'EH Home App',
    this.createdAt,
    this.expiresAt,
    this.isCurrent = false,
  });

  final String id;
  final String userId;
  final String deviceName;
  final String ipAddress;
  final String userAgent;
  final String? createdAt;
  final String? expiresAt;
  final bool isCurrent;

  factory AccountSessionItem.fromJson(Map<String, dynamic> json) {
    return AccountSessionItem(
      id: json['id'] as String? ?? '',
      userId: json['userId'] as String? ?? '',
      deviceName: json['deviceName'] as String? ?? 'Mobile Device',
      ipAddress: json['ipAddress'] as String? ?? '127.0.0.1',
      userAgent: json['userAgent'] as String? ?? 'EH Home App',
      createdAt: json['createdAt'] as String?,
      expiresAt: json['expiresAt'] as String?,
      isCurrent: json['isCurrent'] as bool? ?? false,
    );
  }
}

@immutable
class HomeSummaryItem {
  const HomeSummaryItem({
    required this.id,
    required this.name,
    this.timezone = 'UTC',
    this.address,
    this.role = 'MEMBER',
    this.permissions = const HomeAccessPermissions(),
    this.memberCount = 1,
    this.roomCount = 0,
    this.deviceCount = 0,
  });

  final String id;
  final String name;
  final String timezone;
  final String? address;
  final String role;
  final HomeAccessPermissions permissions;
  final int memberCount;
  final int roomCount;
  final int deviceCount;

  factory HomeSummaryItem.fromJson(Map<String, dynamic> json) {
    return HomeSummaryItem(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? 'Home',
      timezone: json['timezone'] as String? ?? 'UTC',
      address: json['address'] as String?,
      role: (json['role'] as String? ?? 'MEMBER').toUpperCase(),
      permissions: HomeAccessPermissions.fromJson(json['permissions'] as Map<String, dynamic>?),
      memberCount: json['memberCount'] as int? ?? 1,
      roomCount: json['roomCount'] as int? ?? 0,
      deviceCount: json['deviceCount'] as int? ?? 0,
    );
  }
}

@immutable
class HomeMemberItem {
  const HomeMemberItem({
    required this.membershipId,
    required this.homeId,
    required this.userId,
    this.email,
    this.role = 'MEMBER',
    this.invitedAt,
    this.acceptedAt,
  });

  final String membershipId;
  final String homeId;
  final String userId;
  final String? email;
  final String role;
  final String? invitedAt;
  final String? acceptedAt;

  factory HomeMemberItem.fromJson(Map<String, dynamic> json) {
    return HomeMemberItem(
      membershipId: json['membershipId'] as String? ?? '',
      homeId: json['homeId'] as String? ?? '',
      userId: json['userId'] as String? ?? '',
      email: json['email'] as String?,
      role: (json['role'] as String? ?? 'MEMBER').toUpperCase(),
      invitedAt: json['invitedAt'] as String?,
      acceptedAt: json['acceptedAt'] as String?,
    );
  }
}

@immutable
class HomeInviteItem {
  const HomeInviteItem({
    required this.id,
    required this.homeId,
    this.homeName = 'Home',
    required this.inviterUserId,
    this.inviterEmail,
    required this.inviteeEmail,
    this.role = 'MEMBER',
    required this.inviteCode,
    this.status = 'PENDING',
    this.expiresAt,
    this.createdAt,
  });

  final String id;
  final String homeId;
  final String homeName;
  final String inviterUserId;
  final String? inviterEmail;
  final String inviteeEmail;
  final String role;
  final String inviteCode;
  final String status;
  final String? expiresAt;
  final String? createdAt;

  factory HomeInviteItem.fromJson(Map<String, dynamic> json) {
    return HomeInviteItem(
      id: json['id'] as String? ?? '',
      homeId: json['homeId'] as String? ?? '',
      homeName: json['homeName'] as String? ?? 'Home',
      inviterUserId: json['inviterUserId'] as String? ?? json['inviter_user_id'] as String? ?? '',
      inviterEmail: json['inviterEmail'] as String?,
      inviteeEmail: json['inviteeEmail'] as String? ?? json['invitee_email'] as String? ?? '',
      role: (json['role'] as String? ?? 'MEMBER').toUpperCase(),
      inviteCode: json['inviteCode'] as String? ?? json['invite_code'] as String? ?? '',
      status: json['status'] as String? ?? 'PENDING',
      expiresAt: json['expiresAt'] as String? ?? json['expires_at'] as String?,
      createdAt: json['createdAt'] as String? ?? json['created_at'] as String?,
    );
  }
}
