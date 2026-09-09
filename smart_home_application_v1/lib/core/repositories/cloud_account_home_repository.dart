import '../api/api_client.dart';
import '../models/access_control_models.dart';
import 'account_home_repository.dart';

class CloudAccountHomeRepository implements AccountHomeRepository {
  const CloudAccountHomeRepository(this._apiClient);

  final ApiClient _apiClient;

  List<dynamic> _extractList(dynamic response) {
    if (response is List) return response;
    if (response is Map && response['data'] is List) return response['data'] as List;
    return const [];
  }

  Map<String, dynamic> _extractMap(dynamic response) {
    if (response is Map<String, dynamic>) {
      if (response['data'] is Map<String, dynamic>) {
        return response['data'] as Map<String, dynamic>;
      }
      return response;
    }
    return const {};
  }

  @override
  Future<UserAccountProfile> getAccountProfile() async {
    final response = await _apiClient.get('/api/v1/account/me');
    final data = _extractMap(response);
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
    final data = _extractMap(response);
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
    final list = _extractList(response);
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
    final list = _extractList(response);
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
    final data = _extractMap(response);
    return HomeSummaryItem.fromJson(data);
  }

  @override
  Future<HomeSummaryItem> getHomeDetails(String homeId) async {
    final response = await _apiClient.get('/api/v1/homes/$homeId');
    final data = _extractMap(response);
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
    final data = _extractMap(response);
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
    final list = _extractList(response);
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
    final data = _extractMap(response);
    return HomeInviteItem.fromJson(data);
  }

  @override
  Future<List<HomeInviteItem>> listHomeInvitations(String homeId) async {
    final response = await _apiClient.get('/api/v1/homes/$homeId/invitations');
    final list = _extractList(response);
    return list.map((e) => HomeInviteItem.fromJson(e as Map<String, dynamic>)).toList();
  }

  @override
  Future<void> revokeInvitation(String homeId, {required String inviteId}) async {
    await _apiClient.delete('/api/v1/homes/$homeId/invitations/$inviteId');
  }

  @override
  Future<List<HomeInviteItem>> listPendingInvitations() async {
    final response = await _apiClient.get('/api/v1/invitations/pending');
    final list = _extractList(response);
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
