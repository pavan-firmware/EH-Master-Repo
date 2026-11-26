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
  Future<HubState> getHubState({String? homeId, bool allowSubnetSweep = false}) async {
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

  @override
  Future<bool> identifyHub({required String hubHostname}) async => true;

  @override
  Future<bool> verifyHubPin({required String hubHostname, required String pin}) async => true;

  @override
  Future<bool> resetMeshNetwork({required String hubHostname}) async => true;

  @override
  Future<bool> factoryResetHub({required String hubHostname}) async => true;

  @override
  Future<Map<String, dynamic>> getHubUpdates({required String hubHostname}) async => {
    'status': 'ok',
    'hub': {
      'currentVersion': '1.0.0-phase51',
      'latestVersion': '1.0.0-phase51',
      'updateAvailable': false,
      'platform': 'Raspberry Pi 3B+ (Debian aarch64)',
      'channel': 'stable',
    },
    'deviceOtaCache': {
      'enabled': true,
      'cachedFirmwares': [
        {
          'model': 'eh-smart-switch-3x',
          'version': '2.1.0-freertos',
          'status': 'Ready on Local LAN',
        },
      ],
    },
  };

  @override
  Future<bool> checkForUpdates({required String hubHostname}) async => true;

  @override
  Future<List<CrossDeviceRule>> getCrossDeviceRules({required String hubHostname}) async => [
    const CrossDeviceRule(
      id: 'rule_test_01',
      name: 'Hallway -> Porch Fast-Path',
      triggerDeviceId: 'sw_test_01',
      triggerChannel: 1,
      triggerState: true,
      actionDeviceId: 'sw_test_01',
      actionDeviceIp: '192.168.0.101',
      actionChannel: 2,
      actionCommand: 'TOGGLE',
    ),
  ];

  @override
  Future<bool> saveCrossDeviceRule({required String hubHostname, required CrossDeviceRule rule}) async => true;

  @override
  Future<bool> deleteCrossDeviceRule({required String hubHostname, required String ruleId}) async => true;

  @override
  Future<Map<String, dynamic>?> testCrossDeviceRule({required String hubHostname, required String ruleId}) async => {
    'status': 'ok',
    'execution': {
      'success': true,
      'latencyMs': 2,
      'method': 'FAST_PATH_UDP',
    },
  };

  @override
  Future<List<AutomationExecutionLog>> getExecutionLogs({required String hubHostname, int limit = 50}) async => [
    AutomationExecutionLog(
      id: 'log_01',
      ruleId: 'rule_test_01',
      ruleName: 'Hallway -> Porch Fast-Path',
      triggerEvent: 'sw_test_01 CH1=ON',
      actionSummary: 'sw_test_01 CH2 -> TOGGLE',
      latencyMs: 2,
      status: 'SUCCESS_FAST_PATH_UDP',
      timestamp: DateTime.now(),
    ),
  ];

  @override
  Future<Map<String, dynamic>?> getHomeEnergySummary({required String hubHostname, String period = 'today'}) async => {
    'entityType': 'home',
    'period': period,
    'currentPowerW': 420.5,
    'totalEnergyKwh': 12.8,
    'peakPowerW': 1850.0,
    'costEstimate': 1.92,
  };

  @override
  Future<Map<String, dynamic>?> getDeviceEnergyHistory({
    required String hubHostname,
    required String deviceId,
    int channel = 1,
    String period = 'today',
  }) async => {
    'entityType': 'device',
    'entityId': deviceId,
    'currentPowerW': 65.0,
    'totalEnergyKwh': 1.45,
  };

  @override
  Future<Map<String, dynamic>?> getDeviceSettings({required String deviceIp}) async => {
    'status': 'ok',
    'powerOnMode': 2,
    'childLock': false,
  };

  @override
  Future<bool> setDevicePowerOnMode({required String deviceIp, required int mode}) async => true;

  @override
  Future<bool> setDeviceChildLock({required String deviceIp, required bool enabled}) async => true;

  @override
  Future<Map<String, dynamic>?> getHomeAssistantStatus({required String hubHostname}) async => {
    'status': 'ok',
    'enabled': true,
    'discoveryPrefix': 'homeassistant',
    'entitiesCount': 4,
    'summary': {
      'switches': 1,
      'sensors': 2,
      'binarySensors': 1,
    },
  };

  @override
  Future<Map<String, dynamic>?> syncHomeAssistant({required String hubHostname}) async => {
    'status': 'ok',
    'discoveredEntitiesCount': 4,
  };

  @override
  Future<Map<String, dynamic>?> getHomeAssistantManifest({required String hubHostname}) async => {
    'status': 'ok',
    'entitiesCount': 4,
    'entities': [],
  };

  @override
  Future<Map<String, dynamic>?> exportHubBackup({required String hubHostname}) async => {
    'status': 'ok',
    'metadata': {
      'devicesCount': 1,
      'routinesCount': 1,
      'claimsCount': 1,
      'timestamp': '2026-11-23T05:00:00.000Z',
    },
    'snapshot': {},
  };

  @override
  Future<bool> restoreHubBackup({required String hubHostname, required Map<String, dynamic> backup}) async => true;

  @override
  Future<Map<String, dynamic>?> exportDiagnostics({required String hubHostname}) async => {
    'status': 'ok',
    'summary': {
      'databaseEngine': 'sqlite',
      'totalDevices': 1,
      'totalClaims': 1,
      'overlayFsActive': true,
      'ntpSynced': true,
      'uptimeSeconds': 120,
    },
  };
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
    expect(find.text('EH Smart Hub'), findsOneWidget);
    expect(find.text('Scan Local Wi-Fi for Hub'), findsOneWidget);

    // Open Hub Guide modal sheet from AppBar action icon
    await tester.tap(find.byIcon(Icons.help_outline_rounded).first);
    await tester.pumpAndSettle();

    expect(find.text('Optional Smart Hub'), findsOneWidget);
    expect(find.text('Sub-5ms Execution'), findsOneWidget);
    expect(find.text('100% Offline Autonomy'), findsOneWidget);
    expect(find.text('Flash Memory Preservation'), findsOneWidget);
    expect(find.text('Zero-Touch Adoption'), findsOneWidget);
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

    // Verify Home Assistant Auto-Discovery Bridge and Maintenance Features
    expect(find.text('HOME ASSISTANT AUTO-DISCOVERY', skipOffstage: false), findsOneWidget);
    expect(find.text('Sync Entities', skipOffstage: false), findsOneWidget);
    expect(find.text('Local MQTT / REST Bridge', skipOffstage: false), findsOneWidget);

    expect(find.text('Backup Hub Configuration', skipOffstage: false), findsOneWidget);
    expect(find.text('One-Click Diagnostics Export', skipOffstage: false), findsOneWidget);
  });
}

