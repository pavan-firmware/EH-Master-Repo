import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_home_application_v1/core/theme/app_theme.dart';
import 'package:smart_home_application_v1/features/hub/data/hub_repository.dart';
import 'package:smart_home_application_v1/features/hub/domain/models/hub_models.dart';
import 'package:smart_home_application_v1/features/hub/presentation/hub_management_page.dart';

class MockTestHubRepository implements HubRepository {
  MockTestHubRepository({this.initialState});

  HubState? initialState;
  bool linkCalled = false;
  bool adoptCalled = false;

  @override
  Future<HubState> getHubState({String? homeId}) async {
    return initialState ?? const HubState(status: HubConnectionStatus.notConfigured);
  }

  @override
  Future<bool> linkHub({required String hubHostname, required String homeId}) async {
    linkCalled = true;
    return true;
  }

  @override
  Future<bool> unlinkHub({required String hubHostname}) async => true;

  @override
  Future<List<HubDeviceInfo>> adoptDiscoveredSwitches({
    required String hubHostname,
    required List<String> switchIds,
    List<Map<String, dynamic>>? devices,
  }) async {
    adoptCalled = true;
    return const [
      HubDeviceInfo(
        id: 'sw_test_01',
        name: 'Living Room Switch',
        ipAddress: '192.168.0.101',
        macAddress: 'AA:BB:CC:DD:EE:FF',
        roomName: 'Living Room',
        online: true,
        activeRoutinesCount: 1,
        hasCriticalHardwareFallback: false,
        latencyMs: 3,
        channelCount: 3,
        channels: {1: false, 2: false, 3: false},
      ),
    ];
  }

  @override
  Future<bool> sendDeviceControl({
    required String hubHostname,
    required String deviceId,
    required int channel,
    required bool power,
    bool isToggle = false,
  }) async => true;

  @override
  Future<List<Map<String, dynamic>>> getRoutines({required String hubHostname}) async => [
    {
      'id': 'rt_test_01',
      'name': 'Test Porch Routine',
      'hour': 18,
      'minute': 30,
      'criticalHardwareFallback': false,
    }
  ];

  @override
  Future<bool> triggerRoutine({required String hubHostname, required String routineId}) async => true;

  @override
  Future<bool> syncTimeBroadcast({required String hubHostname}) async => true;

  @override
  Future<bool> syncAutomations({required String hubHostname}) async => true;

  @override
  Future<bool> restartHubCore({required String hubHostname}) async => true;
}

void main() {
  testWidgets('HubManagementPage renders unlinked setup view and benefits', (tester) async {
    final repo = MockTestHubRepository();

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.light().copyWith(
          extensions: [EHThemeTokens.light],
        ),
        home: HubManagementPage(repository: repo),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Smart Home Hub'), findsOneWidget);
    expect(find.text('Optional Smart Hub'), findsOneWidget);
    expect(find.text('Sub-5ms Execution'), findsOneWidget);
    expect(find.text('100% Offline Autonomy'), findsOneWidget);
    expect(find.text('Flash Memory Preservation'), findsOneWidget);
    expect(find.text('Zero-Touch Adoption'), findsOneWidget);
    expect(find.text('Link Hub to My Home'), findsOneWidget);
  });

  testWidgets('HubManagementPage renders active dashboard when connected', (tester) async {
    final repo = MockTestHubRepository(
      initialState: const HubState(
        status: HubConnectionStatus.connected,
        hostname: 'eh-hub.local',
        latencyMs: 3,
        connectedDevices: [
          HubDeviceInfo(
            id: 'sw_01',
            name: 'Master Switch',
            ipAddress: '192.168.0.105',
            macAddress: '11:22:33:44:55:66',
            roomName: 'Hall',
            online: true,
            activeRoutinesCount: 2,
            hasCriticalHardwareFallback: true,
            latencyMs: 2,
          ),
        ],
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.light().copyWith(
          extensions: [EHThemeTokens.light],
        ),
        home: HubManagementPage(repository: repo),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Local Hub Active'), findsOneWidget);
    expect(find.text('3ms Direct'), findsOneWidget);
    expect(find.text('Master Switch'), findsOneWidget);
    expect(find.text('Critical NVS'), findsOneWidget);
    expect(find.text('Sync Automations'), findsOneWidget);
    expect(find.text('Restart Hub Core'), findsOneWidget);
  });
}

