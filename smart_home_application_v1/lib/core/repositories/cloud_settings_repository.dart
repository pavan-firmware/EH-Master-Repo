import '../api/api_client.dart';
import '../models/device_models.dart';
import '../models/settings_models.dart';
import 'settings_repository.dart';

class CloudSettingsRepository implements SettingsRepository {
  final ApiClient _apiClient;
  String? _activeHomeId;

  CloudSettingsRepository(this._apiClient, {String? activeHomeId}) {
    _activeHomeId = activeHomeId;
  }

  void setActiveHomeId(String? homeId) => _activeHomeId = homeId;

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

  Future<String?> _resolveHomeId() async {
    if (_activeHomeId != null && _activeHomeId!.isNotEmpty) {
      return _activeHomeId;
    }
    try {
      final res = await _apiClient.get('/api/v1/homes');
      final list = _extractList(res);
      if (list.isNotEmpty) {
        final first = list.first;
        if (first is Map && first['id'] != null) {
          _activeHomeId = first['id'].toString();
          return _activeHomeId;
        }
      }
    } catch (_) {}
    return null;
  }

  @override
  Future<HomeSettingsData> getHome() async {
    final homeId = await _resolveHomeId();
    if (homeId == null || homeId.isEmpty) {
      return HomeSettingsData(
        id: '',
        name: 'No Home Configured',
        ownerName: 'Unknown',
        location: null,
        timezone: 'UTC',
        createdAt: DateTime.now(),
        preferences: const HomePreferences(
          temperatureUnit: 'Celsius (°C)',
          notificationsEnabled: true,
          timeFormat: '12-hour',
        ),
        connectionAvailability: HomeConnectionAvailability.setupRequired,
        connectionTransport: 'Bluetooth + Wi-Fi',
        lastChecked: null,
      );
    }

    try {
      final res = await _apiClient.get('/api/v1/homes/$homeId');
      final Map<String, dynamic> data = _extractMap(res);

      String ownerName = data['owner_name'] ?? data['ownerName'] ?? 'Owner';
      String name = data['name'] ?? 'My Home';
      String timezone = data['timezone'] ?? 'UTC';
      String? address = data['address'];

      DateTime createdAt = DateTime.now();
      if (data['created_at'] != null) {
        try {
          createdAt = DateTime.parse(data['created_at'].toString());
        } catch (_) {}
      }

      return HomeSettingsData(
        id: homeId,
        name: name,
        ownerName: ownerName,
        location: address,
        timezone: timezone,
        createdAt: createdAt,
        preferences: const HomePreferences(
          temperatureUnit: 'Celsius (°C)',
          notificationsEnabled: true,
          timeFormat: '12-hour',
        ),
        connectionAvailability: HomeConnectionAvailability.connected,
        connectionTransport: 'Cloud + Wi-Fi',
        lastChecked: DateTime.now(),
      );
    } catch (_) {
      return HomeSettingsData(
        id: homeId,
        name: 'Home',
        ownerName: 'Owner',
        location: null,
        timezone: 'UTC',
        createdAt: DateTime.now(),
        preferences: const HomePreferences(
          temperatureUnit: 'Celsius (°C)',
          notificationsEnabled: true,
          timeFormat: '12-hour',
        ),
        connectionAvailability: HomeConnectionAvailability.setupRequired,
        connectionTransport: 'Bluetooth + Wi-Fi',
        lastChecked: null,
      );
    }
  }

  @override
  Future<List<HomeMember>> getMembers() async {
    final homeId = await _resolveHomeId();
    if (homeId == null || homeId.isEmpty) return [];

    try {
      final res = await _apiClient.get('/api/v1/homes/$homeId/members');
      final list = _extractList(res);
      if (list.isNotEmpty) {
        return list.map<HomeMember>((m) {
          final id = m['userId'] ?? m['id'] ?? m['membershipId'] ?? '';
          final name = m['name'] ?? m['fullName'];
          final email = m['email'] ?? m['userId'] ?? 'User';
          final primaryName = (name != null && name.toString().trim().isNotEmpty)
              ? name.toString()
              : email.toString();
          final roleStr = (m['role'] ?? 'MEMBER').toString().toUpperCase();
          final isOwner = roleStr == 'OWNER';
          final isAdmin = roleStr == 'ADMIN' || roleStr == 'HOME_ADMIN';
          final isGuest = roleStr == 'GUEST';

          final displayName = isOwner
              ? '$primaryName (Owner)'
              : (isAdmin ? '$primaryName (Home Admin)' : primaryName);
          final initials = primaryName.isNotEmpty ? primaryName[0].toUpperCase() : 'U';

          final HomeMemberRole memberRole = isOwner
              ? HomeMemberRole.owner
              : (isAdmin
                  ? HomeMemberRole.admin
                  : (isGuest ? HomeMemberRole.guest : HomeMemberRole.member));

          final String activeLabel = isOwner
              ? 'Home owner'
              : (isAdmin
                  ? 'Home Admin · Access active'
                  : 'Member · Access active');

          return HomeMember(
            id: id.toString(),
            displayName: displayName,
            role: memberRole,
            status: HomeMemberStatus.active,
            initials: initials,
            email: email.toString(),
            lastActiveLabel: activeLabel,
          );
        }).toList();
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  @override
  Future<List<HomeInvitation>> getPendingInvitations() async {
    final homeId = await _resolveHomeId();
    if (homeId == null || homeId.isEmpty) return [];

    try {
      final res = await _apiClient.get('/api/v1/homes/$homeId/invitations');
      final list = _extractList(res);
      if (list.isNotEmpty) {
        return list.map<HomeInvitation>((inv) {
          final id = inv['id'] ?? inv['code'] ?? '';
          final email = inv['invitee_email'] ?? inv['email'] ?? 'Invited User';
          final initials = email.isNotEmpty ? email[0].toUpperCase() : 'I';
          final roleStr = (inv['role'] ?? 'MEMBER').toString().toUpperCase();
          final isOwner = roleStr == 'OWNER';
          final isAdmin = roleStr == 'ADMIN' || roleStr == 'HOME_ADMIN';
          final isGuest = roleStr == 'GUEST';
          final role = isOwner
              ? HomeMemberRole.owner
              : (isAdmin
                  ? HomeMemberRole.admin
                  : (isGuest ? HomeMemberRole.guest : HomeMemberRole.member));

          final String invitedLabel = isOwner
              ? 'Owner invitation'
              : (isAdmin
                  ? 'Home Admin invitation'
                  : (isGuest ? 'Guest invitation' : 'Pending invitation'));

          return HomeInvitation(
            id: id.toString(),
            recipientName: email,
            initials: initials,
            invitedLabel: invitedLabel,
            expiresLabel: 'Valid for 7 days',
            role: role,
            code: inv['invite_code'] ?? inv['code'],
          );
        }).toList();
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  @override
  Future<List<DiscoveredRoomDevice>> getNearbyDevices() async {
    final homeId = await _resolveHomeId();
    if (homeId == null || homeId.isEmpty) return [];

    try {
      final res = await _apiClient.get('/api/v1/homes/$homeId/devices');
      final list = _extractList(res);
      if (list.isNotEmpty) {
        return list.map<DiscoveredRoomDevice>((dev) {
          final id = dev['deviceId'] ?? dev['id'] ?? '';
          final name = dev['displayName'] ?? dev['label'] ?? dev['customName'] ?? 'Smart Device';
          final model = dev['product_sku'] ?? dev['hardwareRevision'] ?? 'ESP32';
          final conn = (dev['connectionState'] == 'ONLINE')
              ? DeviceConnection.online
              : DeviceConnection.offline;

          return DiscoveredRoomDevice(
            id: id.toString(),
            name: name.toString(),
            model: model.toString(),
            signalLabel: conn == DeviceConnection.online ? 'Online' : 'Offline',
            signal: conn,
            icon: 'socket',
          );
        }).toList();
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  @override
  Future<SettingsOperationResult> updateHome(HomeSettingsDraft draft) async {
    final homeId = await _resolveHomeId();
    if (homeId == null || homeId.isEmpty) return SettingsOperationResult.failed;

    try {
      await _apiClient.patch(
        '/api/v1/homes/$homeId',
        body: {
          'name': draft.name,
          'timezone': draft.timezone,
          'address': draft.location,
        },
      );
      return SettingsOperationResult.success;
    } catch (e) {
      if (e is ApiException && (e.statusCode == 401 || e.statusCode == 403)) {
        return SettingsOperationResult.unauthorized;
      }
      return SettingsOperationResult.failed;
    }
  }

  @override
  Future<SettingsOperationResult> invitePerson(String recipient) async {
    return invitePersonWithRole(recipient, role: 'MEMBER');
  }

  @override
  Future<SettingsOperationResult> invitePersonWithRole(
    String recipient, {
    String role = 'MEMBER',
  }) async {
    final homeId = await _resolveHomeId();
    if (homeId == null || homeId.isEmpty) return SettingsOperationResult.failed;

    try {
      await _apiClient.post(
        '/api/v1/homes/$homeId/invitations',
        body: {'email': recipient.trim(), 'role': role},
      );
      return SettingsOperationResult.success;
    } catch (e) {
      if (e is ApiException && (e.statusCode == 401 || e.statusCode == 403)) {
        return SettingsOperationResult.unauthorized;
      }
      return SettingsOperationResult.failed;
    }
  }

  @override
  Future<SettingsOperationResult> removeMember(String memberId) async {
    final homeId = await _resolveHomeId();
    if (homeId == null || homeId.isEmpty) return SettingsOperationResult.failed;

    try {
      await _apiClient.delete('/api/v1/homes/$homeId/members/$memberId');
      return SettingsOperationResult.success;
    } catch (e) {
      if (e is ApiException && (e.statusCode == 401 || e.statusCode == 403)) {
        return SettingsOperationResult.unauthorized;
      }
      return SettingsOperationResult.failed;
    }
  }

  @override
  Future<SettingsOperationResult> resendInvitation(String invitationId) async {
    // Backend creates invitations which can be reinvited
    return SettingsOperationResult.success;
  }

  @override
  Future<SettingsOperationResult> cancelInvitation(String invitationId) async {
    final homeId = await _resolveHomeId();
    if (homeId == null || homeId.isEmpty) return SettingsOperationResult.failed;

    try {
      await _apiClient.delete('/api/v1/homes/$homeId/invitations/$invitationId');
      return SettingsOperationResult.success;
    } catch (e) {
      if (e is ApiException && (e.statusCode == 401 || e.statusCode == 403)) {
        return SettingsOperationResult.unauthorized;
      }
      return SettingsOperationResult.failed;
    }
  }
}
