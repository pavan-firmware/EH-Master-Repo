import 'package:flutter_test/flutter_test.dart';
import 'package:smart_home_application_v1/core/capabilities/models/capability_models.dart';
import 'package:smart_home_application_v1/core/domain/models/home_domain_models.dart';
import 'package:smart_home_application_v1/core/domain/repositories/home_domain_repository.dart';

void main() {
  group('Phase 4 Domain Models & Repository Tests', () {
    test('UserHome initializes with role and default timezone', () {
      const home = UserHome(
        id: 'home_1',
        name: 'Hilltop Villa',
        role: HomeMemberRole.owner,
      );

      expect(home.id, 'home_1');
      expect(home.name, 'Hilltop Villa');
      expect(home.timezone, 'UTC');
      expect(home.role, HomeMemberRole.owner);
    });

    test('HomeFloor and HomeRoom enforce home/floor identity hierarchy', () {
      const floor = HomeFloor(id: 'fl_0', homeId: 'home_1', name: 'Ground Floor', level: 0);
      const room = HomeRoom(id: 'rm_1', homeId: 'home_1', floorId: 'fl_0', name: 'Living Room');

      expect(floor.homeId, 'home_1');
      expect(room.homeId, 'home_1');
      expect(room.floorId, 'fl_0');
      expect(room.name, 'Living Room');
    });

    test('DomainDeviceSummary holds canonical channel and resolved capabilities', () {
      const deviceSummary = DomainDeviceSummary(
        deviceId: 'dev_sw_3x',
        serialNumber: 'SN-EH-1001',
        productVariantId: 'eh-smart-switch-3x',
        displayName: 'Living Switch',
        homeId: 'home_1',
        floorId: 'fl_0',
        roomId: 'rm_1',
        roomName: 'Living Room',
        connectionState: CapabilityConnectionState.online,
        capabilities: ['switch', 'relay', 'energy'],
        channels: [
          ResolvedDeviceChannel(channelIndex: 1, name: 'Chandelier', capabilities: ['switch', 'relay'], powerState: true),
          ResolvedDeviceChannel(channelIndex: 2, name: 'Fan', capabilities: ['switch', 'relay', 'fan_speed'], powerState: false),
        ],
      );

      expect(deviceSummary.deviceId, 'dev_sw_3x');
      expect(deviceSummary.isOnline, isTrue);
      expect(deviceSummary.channels.length, 2);
      expect(deviceSummary.channels[0].name, 'Chandelier');
      expect(deviceSummary.channels[0].powerState, isTrue);
      expect(deviceSummary.capabilities, contains('energy'));
    });

    test('MockHomeDomainRepository fetches user homes, floors, rooms, and devices', () async {
      const repo = MockHomeDomainRepository();

      final homes = await repo.getHomesForUser('user_owner');
      expect(homes.length, 1);
      expect(homes[0].name, 'Primary Residence');

      final floors = await repo.getFloorsForHome('home_main');
      expect(floors.length, 2);
      expect(floors[0].name, 'Ground Floor');

      final rooms = await repo.getRoomsForHome('home_main');
      expect(rooms.length, 3);
      expect(rooms[0].name, 'Living Room');

      final members = await repo.getMembersForHome('home_main');
      expect(members.length, 2);
      expect(members[0].role, HomeMemberRole.owner);

      final devices = await repo.getDevicesForHome('home_main');
      expect(devices.length, 1);
      expect(devices[0].displayName, 'Living Room Switch');
      expect(devices[0].channels[0].name, 'Chandelier');
    });
  });
}
