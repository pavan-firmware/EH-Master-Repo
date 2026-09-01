import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_home_application_v1/core/models/access_control_models.dart';
import 'package:smart_home_application_v1/core/repositories/account_home_repository.dart';
import 'package:smart_home_application_v1/features/account/presentation/account_profile_page.dart';
import 'package:smart_home_application_v1/features/home_management/presentation/home_members_page.dart';

class MockAccountHomeRepository implements AccountHomeRepository {
  UserAccountProfile profile = const UserAccountProfile(
    id: 'usr_001',
    email: 'alice@example.com',
    fullName: 'Alice Developer',
    timezone: 'UTC',
    activeSessionsCount: 2,
  );

  List<AccountSessionItem> sessions = [
    const AccountSessionItem(
      id: 'sess_1',
      userId: 'usr_001',
      deviceName: 'Pixel 8 Pro',
      ipAddress: '192.168.1.50',
      userAgent: 'EH Home Flutter Client',
    ),
  ];

  List<HomeMemberItem> members = [
    const HomeMemberItem(
      membershipId: 'mem_1',
      homeId: 'home_1',
      userId: 'usr_001',
      email: 'alice@example.com',
      role: 'OWNER',
    ),
    const HomeMemberItem(
      membershipId: 'mem_2',
      homeId: 'home_1',
      userId: 'usr_002',
      email: 'bob@example.com',
      role: 'ADMIN',
    ),
  ];

  List<HomeInviteItem> invites = [
    const HomeInviteItem(
      id: 'inv_1',
      homeId: 'home_1',
      inviterUserId: 'usr_001',
      inviteeEmail: 'charlie@example.com',
      role: 'VIEWER',
      inviteCode: 'inv_12345678',
    ),
  ];

  @override
  Future<UserAccountProfile> getAccountProfile() async => profile;

  @override
  Future<UserAccountProfile> updateAccountProfile({
    String? fullName,
    String? phoneNumber,
    String? avatarUrl,
    String? timezone,
  }) async {
    profile = UserAccountProfile(
      id: profile.id,
      email: profile.email,
      fullName: fullName ?? profile.fullName,
      phoneNumber: phoneNumber ?? profile.phoneNumber,
      avatarUrl: avatarUrl ?? profile.avatarUrl,
      timezone: timezone ?? profile.timezone,
    );
    return profile;
  }

  @override
  Future<void> changePassword({required String oldPassword, required String newPassword}) async {}

  @override
  Future<List<AccountSessionItem>> listSessions() async => sessions;

  @override
  Future<void> revokeSession(String sessionId) async {
    sessions.removeWhere((s) => s.id == sessionId);
  }

  @override
  Future<void> deleteAccount({required String password}) async {}

  @override
  Future<List<HomeSummaryItem>> listHomes() async => [
        const HomeSummaryItem(
          id: 'home_1',
          name: 'Main Villa',
          role: 'OWNER',
        ),
      ];

  @override
  Future<HomeSummaryItem> createHome({required String name, String? timezone, String? address}) async =>
      HomeSummaryItem(id: 'home_new', name: name);

  @override
  Future<HomeSummaryItem> getHomeDetails(String homeId) async =>
      const HomeSummaryItem(id: 'home_1', name: 'Main Villa', role: 'OWNER');

  @override
  Future<HomeSummaryItem> updateHome(String homeId, {String? name, String? timezone, String? address}) async =>
      HomeSummaryItem(id: homeId, name: name ?? 'Main Villa');

  @override
  Future<void> deleteHome(String homeId) async {}

  @override
  Future<void> transferOwnership(String homeId, {required String newOwnerId}) async {}

  @override
  Future<void> leaveHome(String homeId) async {}

  @override
  Future<List<HomeMemberItem>> listMembers(String homeId) async => members;

  @override
  Future<void> updateMemberRole(String homeId, {required String userId, required String role}) async {}

  @override
  Future<void> removeMember(String homeId, {required String userId}) async {
    members.removeWhere((m) => m.userId == userId);
  }

  @override
  Future<HomeInviteItem> createInvitation(String homeId, {required String email, required String role}) async {
    final inv = HomeInviteItem(
      id: 'inv_new',
      homeId: homeId,
      inviterUserId: 'usr_001',
      inviteeEmail: email,
      role: role,
      inviteCode: 'inv_999999',
    );
    invites.add(inv);
    return inv;
  }

  @override
  Future<List<HomeInviteItem>> listHomeInvitations(String homeId) async => invites;

  @override
  Future<void> revokeInvitation(String homeId, {required String inviteId}) async {
    invites.removeWhere((i) => i.id == inviteId);
  }

  @override
  Future<List<HomeInviteItem>> listPendingInvitations() async => invites;

  @override
  Future<void> acceptInvitation(String inviteCode) async {}

  @override
  Future<void> rejectInvitation(String inviteCode) async {}
}

void main() {
  group('Phase 16 — Access Control & Account Models Tests', () {
    test('UserAccountProfile JSON roundtrip', () {
      final model = UserAccountProfile.fromJson({
        'id': 'usr_123',
        'email': 'test@example.com',
        'fullName': 'Test User',
        'timezone': 'America/Chicago',
        'activeSessionsCount': 3,
      });

      expect(model.id, 'usr_123');
      expect(model.email, 'test@example.com');
      expect(model.fullName, 'Test User');
      expect(model.timezone, 'America/Chicago');
      expect(model.activeSessionsCount, 3);
    });

    test('HomeAccessPermissions parsing & defaults', () {
      const perms = HomeAccessPermissions(
        canManageHome: true,
        canControlDevices: true,
      );

      expect(perms.canManageHome, isTrue);
      expect(perms.canDeleteHome, isFalse);
      expect(perms.canControlDevices, isTrue);
      expect(perms.canViewHome, isTrue);
    });

    test('HomeSummaryItem & HomeMemberItem JSON parsing', () {
      final summary = HomeSummaryItem.fromJson({
        'id': 'h_1',
        'name': 'Lake House',
        'role': 'ADMIN',
        'memberCount': 4,
        'roomCount': 5,
        'deviceCount': 12,
      });
      expect(summary.name, 'Lake House');
      expect(summary.role, 'ADMIN');
      expect(summary.deviceCount, 12);

      final member = HomeMemberItem.fromJson({
        'membershipId': 'mem_1',
        'homeId': 'h_1',
        'userId': 'u_2',
        'email': 'bob@example.com',
        'role': 'MEMBER',
      });
      expect(member.email, 'bob@example.com');
      expect(member.role, 'MEMBER');
    });
  });

  group('Phase 16 — Flutter UI Widget Tests', () {
    testWidgets('AccountProfilePage renders profile details and sessions', (tester) async {
      final repo = MockAccountHomeRepository();

      await tester.pumpWidget(MaterialApp(
        home: AccountProfilePage(repository: repo),
      ));

      await tester.pumpAndSettle();

      expect(find.text('Account & Security'), findsOneWidget);
      expect(find.text('Alice Developer'), findsOneWidget);
      expect(find.text('alice@example.com'), findsOneWidget);
      expect(find.text('Pixel 8 Pro'), findsOneWidget);
      expect(find.text('Change Password'), findsOneWidget);
    });

    testWidgets('HomeMembersPage renders member list and invitation tabs', (tester) async {
      final repo = MockAccountHomeRepository();

      await tester.pumpWidget(MaterialApp(
        home: HomeMembersPage(
          homeId: 'home_1',
          homeName: 'Main Villa',
          repository: repo,
        ),
      ));

      await tester.pumpAndSettle();

      expect(find.text('Main Villa Members'), findsOneWidget);
      expect(find.text('Members (2)'), findsOneWidget);
      expect(find.text('Invitations (1)'), findsOneWidget);
      expect(find.text('alice@example.com'), findsOneWidget);
      expect(find.text('bob@example.com'), findsOneWidget);
      expect(find.text('Invite'), findsOneWidget);

      // Switch to Invitations tab
      await tester.tap(find.text('Invitations (1)'));
      await tester.pumpAndSettle();

      expect(find.text('charlie@example.com'), findsOneWidget);
    });
  });
}
