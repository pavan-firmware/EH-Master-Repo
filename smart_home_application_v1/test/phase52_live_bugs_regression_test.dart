import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_home_application_v1/app/home_controller.dart';
import 'package:smart_home_application_v1/core/api/api_client.dart';
import 'package:smart_home_application_v1/core/models/connection_models.dart';
import 'package:smart_home_application_v1/core/models/home_dashboard_models.dart';
import 'package:smart_home_application_v1/core/models/health_models.dart';
import 'package:smart_home_application_v1/core/models/room_models.dart';
import 'package:smart_home_application_v1/core/models/routine_models.dart';
import 'package:smart_home_application_v1/core/models/settings_models.dart';
import 'package:smart_home_application_v1/core/models/update_models.dart';
import 'package:smart_home_application_v1/core/repositories/cloud_update_repository.dart';
import 'package:smart_home_application_v1/core/repositories/fake_home_repository.dart';
import 'package:smart_home_application_v1/core/repositories/settings_repository.dart';
import 'package:smart_home_application_v1/core/repositories/unavailable_connection_repository.dart';
import 'package:smart_home_application_v1/core/services/device_storage_service.dart';
import 'package:smart_home_application_v1/core/services/edge_routine_sync_service.dart';
import 'package:smart_home_application_v1/core/services/local_lan_device_service.dart';
import 'package:smart_home_application_v1/features/dashboard/presentation/home_page.dart';
import 'package:smart_home_application_v1/features/diagnostics/presentation/device_health_page.dart';
import 'package:smart_home_application_v1/features/hub/data/hub_repository.dart';
import 'package:smart_home_application_v1/features/settings/presentation/settings_page.dart';

class _FailingSettingsRepository extends PreviewSettingsRepository {
  const _FailingSettingsRepository();

  @override
  Future<HomeSettingsData> getHome() async {
    throw const SocketException('Backend unreachable');
  }
}

class _MockFleetApiClient extends ApiClient {
  _MockFleetApiClient() : super(baseUrl: 'http://127.0.0.1:3000');

  final List<String> checkedVariants = [];

  @override
  Future<dynamic> get(String path, {Map<String, String>? headers}) async {
    if (path.startsWith('/api/v1/fleet/status')) {
      return {
        'success': true,
        'data': {
          'devices': [
            {
              'deviceId': '4184a5de-a3ec-46f4-bcfb-41d13d91b699',
              'productVariantId': 'eh-smart-socket-2x',
              'customName': 'EH Smart Socket 2X',
              'firmwareVersion': '1.0.0', // intentionally stale in cloud DB
            },
            {
              'deviceId': '8a629cef-a0d9-4fa5-8d38-c1014753aa30',
              'productVariantId': 'eh-smart-switch-3x',
              'customName': 'EH Smart Switch 3X',
              'firmwareVersion': '1.0.0', // intentionally stale in cloud DB
            },
          ],
        },
      };
    }
    if (path.startsWith('/api/v1/ota/check')) {
      checkedVariants.add(path);
      if (path.contains('currentVersion=1.0.0')) {
        final uri = Uri.parse('http://localhost$path');
        final variant = uri.queryParameters['productVariantId'] ?? '';
        return {
          'success': true,
          'data': {
            'updateAvailable': true,
            'release': {
              'releaseId': 'rel_${variant}_v1_1_0',
              'version': '1.1.0',
              'releaseNotes': 'Release for $variant',
            },
          },
        };
      }
      return {
        'success': true,
        'data': {'updateAvailable': false, 'release': null},
      };
    }
    return {'success': true};
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await DeviceStorageService.init();
  });

  group('Phase 52 Live Field Bug Regressions', () {
    test('1. Routine warning is isolated to exact target deviceId and never leaks to Switch CH1', () {
      const socketId = '4184a5de-a3ec-46f4-bcfb-41d13d91b699';
      const switchId = '8a629cef-a0d9-4fa5-8d38-c1014753aa30';

      final balconyRoutine = Routine(
        id: 'rt_8caa310bd190393f34',
        name: 'balcony Light',
        icon: 'lightbulb',
        isFavorite: false,
        enabled: true,
        availability: RoutineAvailability.available,
        trigger: const RoutineTrigger(
          kind: RoutineTriggerKind.timeSchedule,
          title: 'Daily',
          detail: '07:11 PM',
          timeOfDay: '19:11',
        ),
        conditions: const [],
        actions: const [
          RoutineAction(
            kind: RoutineActionKind.switchChannel,
            title: 'Socket 1',
            detail: 'Toggle Socket 1',
            deviceId: socketId,
            channelIndex: 1,
            targetState: true,
            isToggle: true,
            pulseDurationMinutes: 1,
          ),
        ],
        schedule: const RoutineSchedule(label: 'Every day · 7:11 PM', days: ['Mon'], timezone: 'IST'),
        involvedDevices: const [
          RoutineDevice(
            id: socketId,
            name: 'EH Smart Socket 2X',
            room: 'Balcony',
            online: true,
            capabilities: [],
          ),
        ],
        lastExecution: null,
        nextRun: null,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        summary: 'Balcony CH1 Toggle',
      );

      EdgeRoutineSyncService.instance.registerActiveRoutineExecution(
        balconyRoutine,
        targetChannel: 1,
        pulseDurationSeconds: 60,
      );

      addTearDown(() {
        EdgeRoutineSyncService.instance.clearActiveRoutineExecution(socketId, 1);
      });

      final socketCh1 = EdgeRoutineSyncService.instance.getActiveOverrideRoutine(socketId, 1);
      final socketCh2 = EdgeRoutineSyncService.instance.getActiveOverrideRoutine(socketId, 2);
      final switchCh1 = EdgeRoutineSyncService.instance.getActiveOverrideRoutine(switchId, 1);

      expect(socketCh1, isNotNull);
      expect(socketCh1!.name, equals('balcony Light'));
      expect(socketCh2, isNull);
      expect(switchCh1, isNull);
    });

    test('2. Disabled routine stays disabled across cloud/edge refresh sync', () async {
      const socketId = '4184a5de-a3ec-46f4-bcfb-41d13d91b699';
      final now = DateTime.now();
      final olderCloudRoutine = Routine(
        id: '8caa310b-d190-393f-3400-000000000001',
        name: 'balcony Light',
        icon: 'timer',
        isFavorite: false,
        enabled: true,
        availability: RoutineAvailability.available,
        trigger: const RoutineTrigger(
          kind: RoutineTriggerKind.timeSchedule,
          title: 'Schedule',
          detail: '19:11',
        ),
        conditions: const [],
        actions: const [
          RoutineAction(
            kind: RoutineActionKind.switchChannel,
            title: 'Socket 1',
            detail: 'Toggle',
            deviceId: socketId,
            channelIndex: 1,
            targetState: true,
          ),
        ],
        schedule: const RoutineSchedule(label: '19:11', days: ['Mon'], timezone: 'IST'),
        involvedDevices: const [],
        lastExecution: null,
        nextRun: null,
        createdAt: now.subtract(const Duration(hours: 2)),
        updatedAt: now.subtract(const Duration(hours: 1)),
        summary: 'balcony Light',
      );

      await PreviewRoutineRepository.syncWithCloudRoutines([olderCloudRoutine], notifyHomeController: false);
      const repo = PreviewRoutineRepository();
      await repo.disableRoutine(olderCloudRoutine.id);

      // Simulate Home pull-to-refresh fetching stale enabled=true cloud routine
      await PreviewRoutineRepository.syncWithCloudRoutines([olderCloudRoutine], notifyHomeController: false);

      final after = await repo.getRoutine(olderCloudRoutine.id);
      expect(after, isNotNull);
      expect(after!.enabled, isFalse);
    });

    test('3. HomeDashboardData rooms and counts match device online truth even with warm LAN cache', () {
      const socketId = '4184a5de-a3ec-46f4-bcfb-41d13d91b699';
      const switchId = '8a629cef-a0d9-4fa5-8d38-c1014753aa30';

      // Even if LAN reachability cache hasn't expired yet, online=false must win consistently on Home & Rooms
      LocalLanDeviceService.instance.markDeviceReachableOnLan(switchId, ip: '192.168.0.166');
      addTearDown(() {
        LocalLanDeviceService.instance.markDeviceOfflineOnLan(switchId);
      });

      final dashboard = HomeDashboardData.forLiveDevices(
        devices: const [
          ConnectedDeviceSummary(
            id: socketId,
            name: 'EH Smart Socket 2X',
            model: 'eh-smart-socket-2x',
            firmware: '1.1.0',
            connectedVia: 'Wi-Fi (Local)',
            signalLabel: 'Local Wi-Fi',
            roomName: 'Balcony',
            online: true,
          ),
          ConnectedDeviceSummary(
            id: switchId,
            name: 'EH Smart Switch 3X',
            model: 'eh-smart-switch-3x',
            firmware: '1.2.0',
            connectedVia: 'Offline',
            signalLabel: 'Offline',
            roomName: 'Living Room',
            online: false,
          ),
        ],
        lightOn: false,
        lightConfidence: ActuatorConfidence.confirmed,
        isCloudReachable: true,
        isLocalMode: true,
      );

      expect(dashboard.devicesOnline, equals(1));
      final living = dashboard.rooms.firstWhere((r) => r.name == 'Living Room');
      final balcony = dashboard.rooms.firstWhere((r) => r.name == 'Balcony');
      expect(living.status, equals('Offline'));
      expect(living.summary, equals('Offline'));
      expect(balcony.status, equals('Online'));
    });

    test('4. CloudUpdateRepository preserves productVariantId and saved hardware versions without 4X fallback', () async {
      const socketId = '4184a5de-a3ec-46f4-bcfb-41d13d91b699';
      const switchId = '8a629cef-a0d9-4fa5-8d38-c1014753aa30';

      await DeviceStorageService.saveDeviceFirmwareVersion(socketId, '1.1.0');
      await DeviceStorageService.saveDeviceFirmwareVersion(switchId, '1.2.0');

      final api = _MockFleetApiClient();
      final repo = CloudUpdateRepository(
        apiClient: api,
        getLocalDevices: () => const [
          ConnectedDeviceSummary(
            id: socketId,
            name: 'EH Smart Socket 2X',
            model: 'eh-smart-socket-2x',
            firmware: '1.0.0', // stale in memory
            connectedVia: 'Wi-Fi (Cloud)',
            signalLabel: 'Strong',
            roomName: 'Balcony',
            online: true,
          ),
          ConnectedDeviceSummary(
            id: switchId,
            name: 'EH Smart Switch 3X',
            model: 'eh-smart-switch-3x',
            firmware: '1.0.0', // stale in memory
            connectedVia: 'Wi-Fi (Cloud)',
            signalLabel: 'Strong',
            roomName: 'Living Room',
            online: true,
          ),
        ],
      );

      final summary = await repo.getSummary();
      expect(api.checkedVariants.any((p) => p.contains('eh-smart-switch-4x')), isFalse);
      expect(api.checkedVariants.any((p) => p.contains('eh-smart-socket-2x') && p.contains('1.1.0')), isTrue);
      expect(api.checkedVariants.any((p) => p.contains('eh-smart-switch-3x') && p.contains('1.2.0')), isTrue);
      expect(summary.overallStatus, equals(UpdateOverallStatus.upToDate));
    });

    testWidgets('5. HomePage badge enforces Hub -> LAN Direct -> Cloud -> Offline priority and displays Hub', (tester) async {
      Widget buildHome({
        required bool isCloudReachable,
        required bool isLocalMode,
      }) {
        return MaterialApp(
          home: Scaffold(
            body: HomePage(
              dashboard: HomeDashboardData.forLiveDevices(
                devices: const [],
                lightOn: false,
                lightConfidence: ActuatorConfidence.unavailable,
                isCloudReachable: isCloudReachable,
                isLocalMode: isLocalMode,
              ),
              lightOn: false,
              lightCommandPending: false,
              alertAcknowledged: false,
              onLightChanged: (_) async {},
              onAlertTap: ([_]) {},
              onConnectHome: () async {},
              onShowRooms: () {},
              onOpenRoom: (_) {},
              onShowRoutines: () {},
              onShowActivity: () {},
              onShowSettings: () {},
              onShowInsights: () {},
              onCustomizeControls: () {},
              onUnavailableControl: () {},
              isCloudReachable: isCloudReachable,
              isLocalMode: isLocalMode,
            ),
          ),
        );
      }

      addTearDown(() {
        LiveHubRepository.isLinked = false;
        LiveHubRepository.isHubActive = false;
      });

      // Priority 1: Hub -> renders exact label 'Hub' (never 'Hub Gateway (3ms)')
      LiveHubRepository.isLinked = true;
      LiveHubRepository.isHubActive = true;
      await tester.pumpWidget(buildHome(isCloudReachable: true, isLocalMode: true));
      await tester.pumpAndSettle();
      expect(find.text('Hub'), findsOneWidget);
      expect(find.textContaining('Hub Gateway'), findsNothing);

      // Priority 2: No Hub + LAN -> renders 'LAN Direct' even when Cloud is reachable
      LiveHubRepository.isLinked = false;
      LiveHubRepository.isHubActive = false;
      await tester.pumpWidget(buildHome(isCloudReachable: true, isLocalMode: true));
      await tester.pumpAndSettle();
      expect(find.text('LAN Direct'), findsOneWidget);

      // Priority 3: No Hub + No LAN + Cloud reachable -> renders 'Cloud'
      await tester.pumpWidget(buildHome(isCloudReachable: true, isLocalMode: false));
      await tester.pumpAndSettle();
      expect(find.text('Cloud'), findsOneWidget);

      // Priority 4: Nothing reachable -> renders 'Offline'
      await tester.pumpWidget(buildHome(isCloudReachable: false, isLocalMode: false));
      await tester.pumpAndSettle();
      expect(find.text('Offline'), findsAtLeastNWidgets(1));
    });

    testWidgets('6. SettingsPage never locks out user when backend is unreachable offline', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: SettingsPage(
            repository: _FailingSettingsRepository(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Couldn’t load your home'), findsNothing);
      expect(find.text('Settings'), findsOneWidget);
      expect(find.text('Smart Home Hub'), findsOneWidget);
    });

    test('7. Auto Mode flips isLocalMode true immediately when LAN device is reachable even if cloud is up', () async {
      const devId = '4184a5de-a3ec-46f4-bcfb-41d13d91b699';
      final ctrl = HomeController(
        repository: FakeHomeRepository(),
        connectionRepository: UnavailableConnectionRepository(),
        storageService: DeviceStorageService(),
        autoSync: false,
      );
      addTearDown(() {
        LocalLanDeviceService.instance.markDeviceOfflineOnLan(devId);
        ctrl.dispose();
      });

      await ctrl.setRoutingMode(ConnectionRoutingMode.auto);
      expect(ctrl.isLocalMode, isFalse);

      LocalLanDeviceService.instance.markDeviceReachableOnLan(devId, ip: '192.168.0.168');
      expect(ctrl.isLocalMode, isTrue);
    });

    test('8. Banner and badge parity: when all devices & cloud are offline in auto/localOnly, effective mode is offline (not LAN bar)', () async {
      const devId = '4184a5de-a3ec-46f4-bcfb-41d13d91b699';
      final ctrl = HomeController(
        repository: FakeHomeRepository(),
        connectionRepository: UnavailableConnectionRepository(),
        storageService: DeviceStorageService(),
        autoSync: false,
      );
      addTearDown(() {
        LocalLanDeviceService.instance.markDeviceOfflineOnLan(devId);
        LiveHubRepository.isLinked = false;
        LiveHubRepository.isHubActive = false;
        ctrl.dispose();
      });

      LiveHubRepository.isLinked = false;
      LiveHubRepository.isHubActive = false;
      LocalLanDeviceService.instance.markDeviceOfflineOnLan(devId);

      // Even in localOnly routing mode, if 0 devices and 0 hubs are reachable on LAN,
      // both badge & top banner must resolve to Offline instead of showing "Local Wi-Fi Mode Active".
      await ctrl.setRoutingMode(ConnectionRoutingMode.localOnly);
      expect(ctrl.effectiveConnectionMode, EffectiveConnectionMode.offline);
      expect(ctrl.isBannerOfflineMode, isTrue);
      expect(ctrl.isBannerLanMode, isFalse);

      // Same in Auto mode when cloud is unreachable and 0 devices are reachable:
      await ctrl.setRoutingMode(ConnectionRoutingMode.auto);
      ctrl.setCloudEnabled(false);
      // UnavailableConnectionRepository keeps _isCloudReachable false before any successful loadHomeData
      expect(
        HomeController.resolveEffectiveConnectionMode(
          routingMode: ConnectionRoutingMode.auto,
          isHubActive: false,
          hasVerifiedLan: false,
          isLocalMode: false,
          isCloudReachable: false,
        ),
        EffectiveConnectionMode.offline,
      );
    });

    test('9. Smart Auto mode with 0 online LAN devices resolves cleanly to Cloud when cloud is reachable', () {
      // Ignore unknown deviceIds on UDP discovery/reachability
      LocalLanDeviceService.instance.markDeviceReachableOnLan('unknown', ip: '192.168.0.174');
      expect(LocalLanDeviceService.instance.isAnyDeviceReachableOnLan(), isFalse);

      final resolved = HomeController.resolveEffectiveConnectionMode(
        routingMode: ConnectionRoutingMode.auto,
        isHubActive: false,
        hasVerifiedLan: false,
        isLocalMode: false,
        isCloudReachable: true,
      );
      expect(resolved, EffectiveConnectionMode.cloud);
    });

    test('10. LocalLanDeviceService tolerates a single transient fetchLocalDeviceState failure without marking device offline', () async {
      const devId = '4184a5de-a3ec-46f4-bcfb-41d13d91b699';
      // Point device to a non-routable local port or closed IP ONLY in-memory for test cleanup
      LocalLanDeviceService.instance.markDeviceReachableOnLan(devId, ip: '127.0.0.1');
      addTearDown(() {
        LocalLanDeviceService.instance.markDeviceOfflineOnLan(devId);
        LocalLanDeviceService.instance.unregisterDeviceIp(devId);
      });

      expect(LocalLanDeviceService.instance.isDeviceReachableOnLan(devId), isTrue);

      // Failure #1 and #2 must keep device reachable on LAN (avoids flapping to Offline while tapping controls)
      await LocalLanDeviceService.instance.fetchLocalDeviceState(deviceId: devId, explicitIp: '127.0.0.1');
      expect(LocalLanDeviceService.instance.isDeviceReachableOnLan(devId), isTrue);
      await LocalLanDeviceService.instance.fetchLocalDeviceState(deviceId: devId, explicitIp: '127.0.0.1');
      expect(LocalLanDeviceService.instance.isDeviceReachableOnLan(devId), isTrue);

      // Failure #3 transitions device offline cleanly
      await LocalLanDeviceService.instance.fetchLocalDeviceState(deviceId: devId, explicitIp: '127.0.0.1');
      expect(LocalLanDeviceService.instance.isDeviceReachableOnLan(devId), isFalse);
    });

    test('11. Per-device confidence isolation prevents one failed actuation from marking sibling devices Offline', () {
      const devA = '4184a5de-a3ec-46f4-bcfb-41d13d91b699';
      const devB = '8a629cef-a0d9-4fa5-8d38-c1014753aa30';

      final dashboard = HomeDashboardData.forLiveDevices(
        devices: const [
          ConnectedDeviceSummary(
            id: devA,
            name: 'EH Smart Socket 2X',
            model: 'eh-smart-socket-2x',
            firmware: '1.2.0',
            connectedVia: 'Wi-Fi (Local)',
            signalLabel: 'Local Wi-Fi',
            roomName: 'Balcony',
            online: true,
          ),
          ConnectedDeviceSummary(
            id: devB,
            name: 'EH Smart Switch 3X',
            model: 'eh-smart-switch-3x',
            firmware: '1.3.0',
            connectedVia: 'Wi-Fi (Local)',
            signalLabel: 'Local Wi-Fi',
            roomName: 'Living Room',
            online: true,
          ),
        ],
        lightOn: true,
        lightConfidence: ActuatorConfidence.confirmed,
        deviceConfidences: const {
          devA: ActuatorConfidence.failed,
          devB: ActuatorConfidence.confirmed,
        },
        selectedControlIds: const ['${devA}_ch1', '${devB}_ch1'],
        channelStates: const {
          devA: {1: true, 2: false},
          devB: {1: false, 2: false, 3: false},
        },
        isCloudReachable: false,
        isLocalMode: true,
      );

      final ctrlA = dashboard.controls.firstWhere((c) => c.id == '${devA}_ch1');
      final ctrlB = dashboard.controls.firstWhere((c) => c.id == '${devB}_ch1');

      expect(ctrlA.confidence, equals(ActuatorConfidence.failed));
      expect(ctrlB.confidence, equals(ActuatorConfidence.confirmed));
      expect(ctrlB.value, isNot(equals('Offline')));
    });

    test('12. Banner and badge stay synchronized on Offline when routingMode is localOnly with 0 reachable devices', () async {
      const devId = '4184a5de-a3ec-46f4-bcfb-41d13d91b699';
      final ctrl = HomeController(
        repository: FakeHomeRepository(),
        connectionRepository: UnavailableConnectionRepository(),
        storageService: DeviceStorageService(),
        autoSync: false,
      );
      addTearDown(() {
        LocalLanDeviceService.instance.markDeviceOfflineOnLan(devId);
        LiveHubRepository.isLinked = false;
        LiveHubRepository.isHubActive = false;
        ctrl.dispose();
      });

      LiveHubRepository.isLinked = false;
      LiveHubRepository.isHubActive = false;
      await ctrl.setRoutingMode(ConnectionRoutingMode.localOnly);
      LocalLanDeviceService.instance.markDeviceReachableOnLan(devId, ip: '192.168.0.168');

      expect(ctrl.effectiveConnectionMode, EffectiveConnectionMode.lan);
      expect(ctrl.isBannerLanMode, isTrue);
      expect(ctrl.isBannerOfflineMode, isFalse);

      // Simulate powering off all LAN devices
      LocalLanDeviceService.instance.markDeviceOfflineOnLan(devId);
      expect(ctrl.effectiveConnectionMode, EffectiveConnectionMode.offline);
      expect(ctrl.isBannerLanMode, isFalse);
      expect(ctrl.isBannerOfflineMode, isTrue);
    });

    test('13. Device stays Online across Home, Rooms & AuthoritativeConnectionState while a routine is executing', () async {
      const devId = '4184a5de-a3ec-46f4-bcfb-41d13d91b699';
      final storage = DeviceStorageService();
      await storage.clearAllDevices();
      await storage.saveDevice(
        const ConnectedDeviceSummary(
          id: devId,
          name: 'EH Smart Socket 2X',
          model: 'eh-smart-socket-2x',
          firmware: '1.2.0',
          connectedVia: 'Wi-Fi (Local)',
          signalLabel: 'Offline',
          roomName: 'Bedroom',
          online: false,
        ),
      );

      final ctrl = HomeController(
        repository: FakeHomeRepository(),
        connectionRepository: UnavailableConnectionRepository(),
        storageService: storage,
        autoSync: false,
      );
      addTearDown(() {
        EdgeRoutineSyncService.instance.clearActiveRoutineExecution(devId, 1);
        LocalLanDeviceService.instance.markDeviceOfflineOnLan(devId);
        ctrl.dispose();
      });

      await ctrl.loadHomeData();

      // Inject active hardware routine execution on ch1
      final routine = Routine(
        id: 'rt_active_bedroom_test',
        name: 'Bedroom Evening Socket',
        icon: 'timer',
        isFavorite: false,
        enabled: true,
        availability: RoutineAvailability.available,
        trigger: const RoutineTrigger(
          kind: RoutineTriggerKind.timeSchedule,
          title: 'Schedule',
          detail: 'Active',
        ),
        conditions: const [],
        actions: const [
          RoutineAction(
            kind: RoutineActionKind.switchChannel,
            title: 'Socket 1',
            detail: 'On',
            deviceId: devId,
            channelIndex: 1,
            targetState: true,
          ),
        ],
        schedule: const RoutineSchedule(label: 'Active', days: [], timezone: 'IST'),
        involvedDevices: const [
          RoutineDevice(
            id: devId,
            name: 'EH Smart Socket 2X',
            room: 'Bedroom',
            online: true,
            capabilities: [],
          ),
        ],
        lastExecution: null,
        nextRun: null,
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
        summary: 'Bedroom Evening Socket',
      );
      EdgeRoutineSyncService.instance.registerActiveRoutineExecution(
        routine,
        targetChannel: 1,
        pulseDurationSeconds: 60,
      );
      ctrl.refreshRoutineWarningState();

      // Home devices, dashboard, rooms, and authoritative state all treat the routine-active device as online
      expect(ctrl.devices.first.online, isTrue);
      expect(ctrl.rooms.first.connectivity, equals(ConnectivityCause.online));
      expect(ctrl.rooms.first.status, equals(RoomStatus.normal));
      expect(ctrl.rooms.first.devices.first.confidence, isNot(equals(ActuatorConfidence.unavailable)));
      expect(ctrl.dashboard.devicesOnline, equals(1));
      expect(ctrl.authoritativeConnectionState.onlineDeviceCount, equals(1));
    });

    testWidgets('14. DeviceHealthPage renders real Low/Medium/High/Offline signal tiers and fixes Online · Offline bug', (tester) async {
      const sockId = '4184a5de-a3ec-46f4-bcfb-41d13d91b699';
      const swId = '8a629cef-a0d9-4fa5-8d38-c1014753aa30';
      final storage = DeviceStorageService();
      await storage.clearAllDevices();
      // 2X Socket promoted online with weak RSSI (-80 dBm) and stale connectedVia='Offline'
      await storage.saveDevice(
        const ConnectedDeviceSummary(
          id: sockId,
          name: 'EH Smart Socket 2X',
          model: 'eh-smart-socket-2x',
          firmware: '1.3.0',
          connectedVia: 'Offline',
          signalLabel: 'Local Wi-Fi',
          roomName: 'Balcony',
          online: true,
          rssiDbm: -80,
        ),
      );
      await storage.saveDevice(
        const ConnectedDeviceSummary(
          id: swId,
          name: 'EH Smart Switch 3X',
          model: 'eh-smart-switch-3x',
          firmware: '1.4.0',
          connectedVia: 'Wi-Fi (Local)',
          signalLabel: 'Local Wi-Fi',
          roomName: 'Living Room',
          online: true,
          rssiDbm: -50,
        ),
      );

      LocalLanDeviceService.instance.setDeviceRssi(sockId, -80);
      LocalLanDeviceService.instance.setDeviceRssi(swId, -50);
      final ctrl = HomeController(
        repository: FakeHomeRepository(),
        connectionRepository: UnavailableConnectionRepository(),
        storageService: storage,
        autoSync: false,
      );
      addTearDown(ctrl.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: DeviceHealthPage(homeController: ctrl),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      expect(find.textContaining('Low (-80 dBm)'), findsOneWidget);
      await tester.scrollUntilVisible(find.textContaining('High (-50 dBm)'), 150);
      expect(find.textContaining('High (-50 dBm)'), findsOneWidget);
      expect(find.textContaining('Online · Offline'), findsNothing);
      await tester.scrollUntilVisible(find.text('Run full health check'), 150);
      expect(find.text('Run full health check'), findsOneWidget);

      // Verify discrete signal classification levels directly
      expect(classifyDeviceSignal(online: true, rssiDbm: -52), SignalStrength.strong);
      expect(classifyDeviceSignal(online: true, rssiDbm: -68), SignalStrength.good);
      expect(classifyDeviceSignal(online: true, rssiDbm: -82), SignalStrength.weak);
      expect(classifyDeviceSignal(online: false, rssiDbm: -52), SignalStrength.unknown);
    });
  });
}
