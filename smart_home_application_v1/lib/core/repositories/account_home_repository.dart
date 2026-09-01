import '../models/access_control_models.dart';

abstract class AccountHomeRepository {
  Future<UserAccountProfile> getAccountProfile();
  Future<UserAccountProfile> updateAccountProfile({
    String? fullName,
    String? phoneNumber,
    String? avatarUrl,
    String? timezone,
  });
  Future<void> changePassword({
    required String oldPassword,
    required String newPassword,
  });
  Future<List<AccountSessionItem>> listSessions();
  Future<void> revokeSession(String sessionId);
  Future<void> deleteAccount({required String password});

  Future<List<HomeSummaryItem>> listHomes();
  Future<HomeSummaryItem> createHome({
    required String name,
    String? timezone,
    String? address,
  });
  Future<HomeSummaryItem> getHomeDetails(String homeId);
  Future<HomeSummaryItem> updateHome(String homeId, {
    String? name,
    String? timezone,
    String? address,
  });
  Future<void> deleteHome(String homeId);
  Future<void> transferOwnership(String homeId, {required String newOwnerId});
  Future<void> leaveHome(String homeId);

  Future<List<HomeMemberItem>> listMembers(String homeId);
  Future<void> updateMemberRole(String homeId, {
    required String userId,
    required String role,
  });
  Future<void> removeMember(String homeId, {required String userId});

  Future<HomeInviteItem> createInvitation(String homeId, {
    required String email,
    required String role,
  });
  Future<List<HomeInviteItem>> listHomeInvitations(String homeId);
  Future<void> revokeInvitation(String homeId, {required String inviteId});

  Future<List<HomeInviteItem>> listPendingInvitations();
  Future<void> acceptInvitation(String inviteCode);
  Future<void> rejectInvitation(String inviteCode);
}
