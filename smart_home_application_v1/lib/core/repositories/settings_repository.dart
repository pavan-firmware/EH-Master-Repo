import '../models/settings_models.dart';
import '../models/device_models.dart';

abstract interface class SettingsRepository {
  Future<HomeSettingsData> getHome();
  Future<List<HomeMember>> getMembers();
  Future<List<HomeInvitation>> getPendingInvitations();
  Future<List<DiscoveredRoomDevice>> getNearbyDevices();

  Future<SettingsOperationResult> updateHome(HomeSettingsDraft draft);
  Future<SettingsOperationResult> invitePerson(String recipient);
  Future<SettingsOperationResult> resendInvitation(String invitationId);
  Future<SettingsOperationResult> cancelInvitation(String invitationId);
}

/// Preview data keeps Settings transport-independent. Mutations deliberately
/// return [SettingsOperationResult.unsupported] until the authenticated home
/// backend and household-access APIs are available.
class PreviewSettingsRepository implements SettingsRepository {
  const PreviewSettingsRepository();

  @override
  Future<HomeSettingsData> getHome() async => HomeSettingsData(
    id: 'HN-7A28F91C',
    name: 'Pavan’s home',
    ownerName: 'Pavan',
    location: 'Hyderabad, Telangana, India',
    timezone: 'Asia/Kolkata',
    createdAt: DateTime(2026, 8, 12),
    preferences: const HomePreferences(
      temperatureUnit: 'Celsius (°C)',
      notificationsEnabled: true,
      timeFormat: '12-hour',
    ),
    connectionAvailability: HomeConnectionAvailability.setupRequired,
    connectionTransport: 'Bluetooth + Wi-Fi',
    lastChecked: null,
  );

  @override
  Future<List<HomeMember>> getMembers() async => const [
    HomeMember(
      id: 'pavan',
      displayName: 'Pavan (You)',
      role: HomeMemberRole.owner,
      status: HomeMemberStatus.active,
      initials: 'P',
      lastActiveLabel: 'Home owner',
    ),
    HomeMember(
      id: 'arun',
      displayName: 'Arun',
      role: HomeMemberRole.member,
      status: HomeMemberStatus.active,
      initials: 'A',
      lastActiveLabel: 'Last active today',
    ),
    HomeMember(
      id: 'priya',
      displayName: 'Priya',
      role: HomeMemberRole.member,
      status: HomeMemberStatus.active,
      initials: 'P',
      lastActiveLabel: 'Last active yesterday',
    ),
  ];

  @override
  Future<List<HomeInvitation>> getPendingInvitations() async => const [
    HomeInvitation(
      id: 'rahul',
      recipientName: 'Rahul',
      initials: 'R',
      invitedLabel: 'Invited 2 days ago',
      expiresLabel: 'Expires in 5 days',
    ),
  ];

  @override
  Future<List<DiscoveredRoomDevice>> getNearbyDevices() async => const [
    DiscoveredRoomDevice(
      id: 'SH-8EF248',
      name: 'Smart Mist Maker',
      model: 'SH-8EF248',
      signalLabel: 'Strong',
      signal: DeviceConnection.online,
      icon: 'mist',
    ),
    DiscoveredRoomDevice(
      id: 'SH-72A931',
      name: 'Smart Light',
      model: 'SH-72A931',
      signalLabel: 'Strong',
      signal: DeviceConnection.online,
      icon: 'light',
    ),
    DiscoveredRoomDevice(
      id: 'SH-91BC22',
      name: 'Smart Plug',
      model: 'SH-91BC22',
      signalLabel: 'Medium',
      signal: DeviceConnection.stale,
      icon: 'plug',
    ),
  ];

  @override
  Future<SettingsOperationResult> cancelInvitation(String invitationId) async =>
      SettingsOperationResult.unsupported;

  @override
  Future<SettingsOperationResult> invitePerson(String recipient) async =>
      SettingsOperationResult.unsupported;

  @override
  Future<SettingsOperationResult> resendInvitation(String invitationId) async =>
      SettingsOperationResult.unsupported;

  @override
  Future<SettingsOperationResult> updateHome(HomeSettingsDraft draft) async =>
      SettingsOperationResult.unsupported;
}
