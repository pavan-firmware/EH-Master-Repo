import '../api/api_client.dart';
import '../models/access_control_models.dart';
import 'account_home_repository.dart';

class CloudAccountHomeRepository implements AccountHomeRepository {
  const CloudAccountHomeRepository(this._apiClient);

  final ApiClient _apiClient;

  @override
  Future<UserAccountProfile> getAccountProfile() async {
    final response = await _apiClient.get('/api/v1/account/me');
    final data = response['data'] as Map<String, dynamic>? ?? response;
    return UserAccountProfile.fromJson(data);
  }

  @override
  Future<UserAccountProfile> updateAccountProfile({
    String? fullName,
    String? phoneNumber,
    String? avatarUrl,
    String? timezone,
  }) async {
    final body = <String, dynamic>{};
    if (fullName != null) body['fullName'] = fullName;
    if (phoneNumber != null) body['phoneNumber'] = phoneNumber;
    if (avatarUrl != null) body['avatarUrl'] = avatarUrl;
    if (timezone != null) body['timezone'] = timezone;

    final response = await _apiClient.patch('/api/v1/account/profile', body: body);
    final data = response['data'] as Map<String, dynamic>? ?? response;
    return UserAccountProfile.fromJson(data);
  }

  @override
  Future<void> changePassword({
    required String oldPassword,
    required String newPassword,
  }) async {
    await _apiClient.post('/api/v1/account/change-password', body: {
      'oldPassword': oldPassword,
      'newPassword': newPassword,
    });
  }

  @override
  Future<List<AccountSessionItem>> listSessions() async {
    final response = await _apiClient.get('/api/v1/account/sessions');
    final list = response['data'] as List<dynamic>? ?? const [];
    return list.map((e) => AccountSessionItem.fromJson(e as Map<String, dynamic>)).toList();
  }

  @override
  Future<void> revokeSession(String sessionId) async {
    await _apiClient.delete('/api/v1/account/sessions/$sessionId');
  }

  @override
  Future<void> deleteAccount({required String password}) async {
    await _apiClient.delete('/api/v1/account', body: {'password': password});
  }

  @override
  Future<List<HomeSummaryItem>> listHomes() async {
    final response = await _apiClient.get('/api/v1/homes');
    final list = response['data'] as List<dynamic>? ?? const [];
    return list.map((e) => HomeSummaryItem.fromJson(e as Map<String, dynamic>)).toList();
  }

  @override
  Future<HomeSummaryItem> createHome({
    required String name,
    String? timezone,
    String? address,
  }) async {
    final body = <String, dynamic>{'name': name};
    if (timezone != null) body['timezone'] = timezone;
    if (address != null) body['address'] = address;

    final response = await _apiClient.post('/api/v1/homes', body: body);
    final data = response['data'] as Map<String, dynamic>? ?? response;
    return HomeSummaryItem.fromJson(data);
  }

  @override
  Future<HomeSummaryItem> getHomeDetails(String homeId) async {
    final response = await _apiClient.get('/api/v1/homes/$homeId');
    final data = response['data'] as Map<String, dynamic>? ?? response;
    return HomeSummaryItem.fromJson(data);
  }

  @override
  Future<HomeSummaryItem> updateHome(String homeId, {
    String? name,
    String? timezone,
    String? address,
  }) async {
    final body = <String, dynamic>{};
    if (name != null) body['name'] = name;
    if (timezone != null) body['timezone'] = timezone;
    if (address != null) body['address'] = address;

    final response = await _apiClient.patch('/api/v1/homes/$homeId', body: body);
    final data = response['data'] as Map<String, dynamic>? ?? response;
    return HomeSummaryItem.fromJson(data);
  }

  @override
  Future<void> deleteHome(String homeId) async {
    await _apiClient.delete('/api/v1/homes/$homeId');
  }

  @override
  Future<void> transferOwnership(String homeId, {required String newOwnerId}) async {
    await _apiClient.post('/api/v1/homes/$homeId/transfer-ownership', body: {
      'newOwnerId': newOwnerId,
    });
  }

  @override
  Future<void> leaveHome(String homeId) async {
    await _apiClient.post('/api/v1/homes/$homeId/leave', body: {});
  }

  @override
  Future<List<HomeMemberItem>> listMembers(String homeId) async {
    final response = await _apiClient.get('/api/v1/homes/$homeId/members');
    final list = response['data'] as List<dynamic>? ?? const [];
    return list.map((e) => HomeMemberItem.fromJson(e as Map<String, dynamic>)).toList();
  }

  @override
  Future<void> updateMemberRole(String homeId, {
    required String userId,
    required String role,
  }) async {
    await _apiClient.patch('/api/v1/homes/$homeId/members/$userId/role', body: {
      'role': role,
    });
  }

  @override
  Future<void> removeMember(String homeId, {required String userId}) async {
    await _apiClient.delete('/api/v1/homes/$homeId/members/$userId');
  }

  @override
  Future<HomeInviteItem> createInvitation(String homeId, {
    required String email,
    required String role,
  }) async {
    final response = await _apiClient.post('/api/v1/homes/$homeId/invitations', body: {
      'email': email,
      'role': role,
    });
    final data = response['data'] as Map<String, dynamic>? ?? response;
    return HomeInviteItem.fromJson(data);
  }

  @override
  Future<List<HomeInviteItem>> listHomeInvitations(String homeId) async {
    final response = await _apiClient.get('/api/v1/homes/$homeId/invitations');
    final list = response['data'] as List<dynamic>? ?? const [];
    return list.map((e) => HomeInviteItem.fromJson(e as Map<String, dynamic>)).toList();
  }

  @override
  Future<void> revokeInvitation(String homeId, {required String inviteId}) async {
    await _apiClient.delete('/api/v1/homes/$homeId/invitations/$inviteId');
  }

  @override
  Future<List<HomeInviteItem>> listPendingInvitations() async {
    final response = await _apiClient.get('/api/v1/invitations/pending');
    final list = response['data'] as List<dynamic>? ?? const [];
    return list.map((e) => HomeInviteItem.fromJson(e as Map<String, dynamic>)).toList();
  }

  @override
  Future<void> acceptInvitation(String inviteCode) async {
    await _apiClient.post('/api/v1/invitations/$inviteCode/accept', body: {});
  }

  @override
  Future<void> rejectInvitation(String inviteCode) async {
    await _apiClient.post('/api/v1/invitations/$inviteCode/reject', body: {});
  }
}
