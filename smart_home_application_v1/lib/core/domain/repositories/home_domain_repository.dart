import '../models/home_domain_models.dart';
import '../../capabilities/models/capability_models.dart';

abstract class HomeDomainRepository {
  Future<List<UserHome>> getHomesForUser(String userId);
  Future<UserHome?> getHome(String homeId);
  Future<List<HomeFloor>> getFloorsForHome(String homeId);
  Future<List<HomeRoom>> getRoomsForHome(String homeId);
  Future<List<HomeMember>> getMembersForHome(String homeId);
  Future<List<DomainDeviceSummary>> getDevicesForHome(String homeId);
  Future<DomainDeviceSummary?> getDeviceSummary(String deviceId);
}

/// Mock/Bootstrap implementation of Phase 4 Domain Repository
class MockHomeDomainRepository implements HomeDomainRepository {
  const MockHomeDomainRepository();

  static const _home1 = UserHome(
    id: 'home_main',
    name: 'Primary Residence',
    role: HomeMemberRole.owner,
  );

  static const _floors = [
    HomeFloor(id: 'fl_ground', homeId: 'home_main', name: 'Ground Floor', level: 0),
    HomeFloor(id: 'fl_first', homeId: 'home_main', name: 'First Floor', level: 1),
  ];

  static const _rooms = [
    HomeRoom(id: 'rm_living', homeId: 'home_main', floorId: 'fl_ground', name: 'Living Room', iconKey: 'living'),
    HomeRoom(id: 'rm_kitchen', homeId: 'home_main', floorId: 'fl_ground', name: 'Kitchen', iconKey: 'kitchen'),
    HomeRoom(id: 'rm_bedroom', homeId: 'home_main', floorId: 'fl_first', name: 'Master Bedroom', iconKey: 'bedroom'),
  ];

  static const _members = [
    HomeMember(membershipId: 'mem_1', homeId: 'home_main', userId: 'user_owner', email: 'owner@ehhome.com', role: HomeMemberRole.owner),
    HomeMember(membershipId: 'mem_2', homeId: 'home_main', userId: 'user_admin', email: 'admin@ehhome.com', role: HomeMemberRole.admin),
  ];

  static const _devices = [
    DomainDeviceSummary(
      deviceId: 'dev_sw_3x_living',
      serialNumber: 'SN-EH-3X-1001',
      productVariantId: 'eh-smart-switch-3x',
      displayName: 'Living Room Switch',
      homeId: 'home_main',
      floorId: 'fl_ground',
      roomId: 'rm_living',
      roomName: 'Living Room',
      connectionState: CapabilityConnectionState.online,
      capabilities: ['switch', 'relay', 'energy', 'ota'],
      channels: [
        ResolvedDeviceChannel(channelIndex: 1, name: 'Chandelier', capabilities: ['switch', 'relay'], powerState: true),
        ResolvedDeviceChannel(channelIndex: 2, name: 'Ceiling Fan', capabilities: ['switch', 'relay', 'fan_speed'], powerState: false, fanSpeed: 0),
        ResolvedDeviceChannel(channelIndex: 3, name: 'Accent Lights', capabilities: ['switch', 'relay'], powerState: true),
      ],
    ),
  ];

  @override
  Future<List<UserHome>> getHomesForUser(String userId) async => [_home1];

  @override
  Future<UserHome?> getHome(String homeId) async => homeId == _home1.id ? _home1 : null;

  @override
  Future<List<HomeFloor>> getFloorsForHome(String homeId) async =>
      _floors.where((f) => f.homeId == homeId).toList();

  @override
  Future<List<HomeRoom>> getRoomsForHome(String homeId) async =>
      _rooms.where((r) => r.homeId == homeId).toList();

  @override
  Future<List<HomeMember>> getMembersForHome(String homeId) async =>
      _members.where((m) => m.homeId == homeId).toList();

  @override
  Future<List<DomainDeviceSummary>> getDevicesForHome(String homeId) async =>
      _devices.where((d) => d.homeId == homeId).toList();

  @override
  Future<DomainDeviceSummary?> getDeviceSummary(String deviceId) async {
    for (final d in _devices) {
      if (d.deviceId == deviceId) return d;
    }
    return null;
  }
}
