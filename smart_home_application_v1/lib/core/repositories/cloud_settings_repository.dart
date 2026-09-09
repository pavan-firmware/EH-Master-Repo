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

  Future<String?> _resolveHomeId() async {
    if (_activeHomeId != null && _activeHomeId!.isNotEmpty) {
      return _activeHomeId;
    }
    try {
      final homes = await _apiClient.get('/api/v1/homes');
      if (homes is List && homes.isNotEmpty) {
        _activeHomeId = homes.first['id']?.toString();
        return _activeHomeId;
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
      final Map<String, dynamic> data = res is Map ? Map<String, dynamic>.from(res) : {};

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
      if (res is List) {
        return res.map<HomeMember>((m) {
          final id = m['membershipId'] ?? m['id'] ?? m['userId'] ?? '';
          final email = m['email'] ?? m['userId'] ?? 'User';
          final roleStr = (m['role'] ?? 'MEMBER').toString().toUpperCase();
          final isOwner = roleStr == 'OWNER';
          final displayName = isOwner ? '$email (Owner)' : email;
          final initials = email.isNotEmpty ? email[0].toUpperCase() : 'U';

          return HomeMember(
            id: id.toString(),
            displayName: displayName,
            role: isOwner ? HomeMemberRole.owner : HomeMemberRole.member,
            status: HomeMemberStatus.active,
            initials: initials,
            lastActiveLabel: isOwner ? 'Home owner' : 'Active member',
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
      if (res is List) {
        return res.map<HomeInvitation>((inv) {
          final id = inv['id'] ?? inv['code'] ?? '';
          final email = inv['invitee_email'] ?? inv['email'] ?? 'Invited User';
          final initials = email.isNotEmpty ? email[0].toUpperCase() : 'I';

          return HomeInvitation(
            id: id.toString(),
            recipientName: email,
            initials: initials,
            invitedLabel: 'Pending invitation',
            expiresLabel: 'Valid for 7 days',
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
      if (res is List) {
        return res.map<DiscoveredRoomDevice>((dev) {
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
    final homeId = await _resolveHomeId();
    if (homeId == null || homeId.isEmpty) return SettingsOperationResult.failed;

    try {
      await _apiClient.post(
        '/api/v1/homes/$homeId/invitations',
        body: {'email': recipient.trim(), 'role': 'MEMBER'},
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
