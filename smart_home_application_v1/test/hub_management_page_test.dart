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
  bool controlCalled = false;
  bool updateDeviceCalled = false;
  bool removeDeviceCalled = false;
  bool upsertRoutineCalled = false;
  bool deleteRoutineCalled = false;

  final List<HubBackupSummary> _savedBackups = [
    HubBackupSummary(
      id: 'bak_01',
      label: 'Before Refactor Snapshot',
      createdAt: DateTime(2026, 11, 23, 5),
      devicesCount: 2,
      routinesCount: 1,
      rulesCount: 1,
    ),
  ];

  final List<HubWebhookRule> _webhooks = [
    const HubWebhookRule(
      id: 'wh_01',
      name: 'Hallway Scene Hook',
      event: 'scene.evening',
      routineId: 'rt_test_01',
    ),
  ];

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
    return initialState?.connectedDevices ??
        const [
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
  Future<bool> updateHubDevice({
    required String hubHostname,
    required String deviceId,
    String? name,
    String? roomName,
    HubDeviceCategory? category,
  }) async {
    updateDeviceCalled = true;
    return true;
  }

  @override
  Future<bool> removeHubDevice({
    required String hubHostname,
    required String deviceId,
  }) async {
    removeDeviceCalled = true;
    return true;
  }

  @override
  Future<bool> sendDeviceControl({
    required String hubHostname,
    required String deviceId,
    required int channel,
    required bool power,
    bool isToggle = false,
  }) async {
    controlCalled = true;
    return true;
  }

  @override
  Future<List<Map<String, dynamic>>> getRoutines({required String hubHostname}) async => [
        {
          'id': 'rt_test_01',
          'name': 'Test Porch Routine',
          'hour': 18,
          'minute': 30,
          'enabled': true,
          'targetState': true,
          'criticalHardwareFallback': false,
        },
      ];

  @override
  Future<bool> upsertHubRoutine({
    required String hubHostname,
    required Map<String, dynamic> routinePayload,
  }) async {
    upsertRoutineCalled = true;
    return true;
  }

  @override
  Future<bool> deleteHubRoutine({
    required String hubHostname,
    required String routineId,
  }) async {
    deleteRoutineCalled = true;
    return true;
  }

  @override
  Future<bool> triggerRoutine({required String hubHostname, required String routineId}) async => true;

  @override
  Future<List<HubActiveTimer>> getActiveHubTimers({required String hubHostname}) async => [];

  @override
  Future<bool> cancelHubTimer({required String hubHostname, required String timerId}) async => true;

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
  Future<String?> rotateHubToken({required String hubHostname}) async => 'rotated_test_token';

  @override
  Future<bool> resetMeshNetwork({required String hubHostname}) async => true;

  @override
  Future<bool> factoryResetHub({required String hubHostname}) async => true;

  @override
  Future<Map<String, dynamic>> getHubUpdates({required String hubHostname}) async => {
        'status': 'ok',
        'hub': {
          'currentVersion': '2.0.0',
          'latestVersion': '2.0.0',
          'updateAvailable': false,
          'platform': 'Raspberry Pi 3B+ (Debian aarch64)',
          'channel': 'stable',
        },
        'deviceOtaCache': {
          'enabled': true,
          'cachedFirmwares': const [],
        },
      };

  @override
  Future<bool> checkForUpdates({required String hubHostname}) async => true;

  @override
  Future<bool> deleteStagedOtaBinary({
    required String hubHostname,
    required String filename,
  }) async =>
      true;

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
  Future<Map<String, dynamic>?> saveHomeAssistantConfig({
    required String hubHostname,
    required String host,
    int port = 1883,
    String username = '',
    String password = '',
    String discoveryPrefix = 'homeassistant',
  }) async =>
      {
        'status': 'ok',
        'enabled': true,
        'mqttConnected': true,
        'discoveryPrefix': discoveryPrefix,
        'entitiesCount': 4,
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
        'entities': const [],
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
        'snapshot': const {},
      };

  @override
  Future<bool> restoreHubBackup({required String hubHostname, required Map<String, dynamic> backup}) async => true;

  @override
  Future<List<HubBackupSummary>> listSavedBackups({required String hubHostname}) async =>
      List.unmodifiable(_savedBackups);

  @override
  Future<HubBackupSummary?> createSavedBackup({
    required String hubHostname,
    required String label,
  }) async {
    final created = HubBackupSummary(
      id: 'bak_${_savedBackups.length + 1}',
      label: label,
      createdAt: DateTime.now(),
      devicesCount: 1,
      routinesCount: 1,
      rulesCount: 1,
    );
    _savedBackups.insert(0, created);
    return created;
  }

  @override
  Future<bool> restoreSavedBackupById({
    required String hubHostname,
    required String backupId,
  }) async =>
      true;

  @override
  Future<bool> deleteSavedBackup({
    required String hubHostname,
    required String backupId,
  }) async {
    _savedBackups.removeWhere((b) => b.id == backupId);
    return true;
  }

  @override
  Future<List<HubWebhookRule>> getWebhooks({required String hubHostname}) async =>
      List.unmodifiable(_webhooks);

  @override
  Future<HubWebhookRule?> saveWebhook({
    required String hubHostname,
    required HubWebhookRule webhook,
  }) async {
    _webhooks.add(webhook);
    return webhook;
  }

  @override
  Future<bool> deleteWebhook({required String hubHostname, required String webhookId}) async {
    _webhooks.removeWhere((w) => w.id == webhookId);
    return true;
  }

  @override
  Future<bool> testWebhook({required String hubHostname, required String webhookId}) async => true;

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

    await tester.tap(find.byIcon(Icons.help_outline_rounded).first);
    await tester.pumpAndSettle();

    expect(find.text('Optional Smart Hub'), findsOneWidget);
    expect(find.text('Sub-5ms Execution'), findsOneWidget);
    expect(find.text('100% Offline Autonomy'), findsOneWidget);
    expect(find.text('Flash Memory Preservation'), findsOneWidget);
    expect(find.text('Zero-Touch Adoption'), findsOneWidget);
  });

  testWidgets('HubManagementPage renders nested overview & opens Adopted Devices screen', (tester) async {
    final socketFromHub = HubDeviceInfo.fromJson(const {
      'id': 'dev_b699',
      'name': 'EH Socket (b699)',
      'ipAddress': '192.168.0.106',
      'macAddress': '11:22:33:44:55:99',
      'roomName': 'Kitchen',
      'online': false,
      'model': 'eh-smart-socket-2x',
      'channelCount': 2,
      'channels': {'1': true, '2': false},
    });
    final onlineSwitch = HubDeviceInfo.fromJson(const {
      'id': 'dev_aa30',
      'name': 'Master Switch',
      'ipAddress': '192.168.0.105',
      'macAddress': '11:22:33:44:55:66',
      'roomName': 'Hall',
      'online': true,
      'model': 'eh-smart-switch-3x',
      'activeRoutinesCount': 2,
      'hasCriticalHardwareFallback': true,
      'latencyMs': 2,
      'channelCount': 3,
      'channels': {'1': false, '2': false, '3': false},
    });
    final fanDevice = HubDeviceInfo.fromJson(const {
      'id': 'dev_fn01',
      'name': 'Bedroom Fan',
      'ipAddress': '192.168.0.108',
      'roomName': 'Bedroom',
      'online': true,
      'category': 'fans',
      'channelCount': 1,
      'channels': {'1': false},
    });

    final repo = MockTestHubRepository(
      initialState: HubState(
        status: HubConnectionStatus.connected,
        hostname: 'eh-hub.local',
        ipAddress: '192.168.0.12',
        firmwareVersion: '2.0.0',
        storageEngine: 'sqlite-wal',
        uptime: '2h 15m',
        latencyMs: 3,
        connectedDevices: [onlineSwitch, socketFromHub, fanDevice],
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
    expect(find.text('SQLITE-WAL'), findsOneWidget);
    expect(find.text('ADOPTED DEVICES (3)'), findsOneWidget);
    expect(find.text('ADOPTED SWITCHES (3)'), findsNothing);
    expect(find.text('Master Switch'), findsOneWidget);
    expect(find.text('EH Smart Socket 2X · B699'), findsOneWidget);
    expect(find.text('EH Socket (b699)'), findsNothing);
    expect(find.text('LAN OK'), findsNothing);

    // Navigate into nested Adopted Devices screen
    final devicesTile = find.text('Adopted Devices & Hardware Controls');
    await tester.scrollUntilVisible(devicesTile, 200);
    await tester.tap(devicesTile);
    await tester.pumpAndSettle();

    expect(find.text('Sockets (1)'), findsOneWidget);
    expect(find.text('Fans (1)'), findsOneWidget);
    final deviceListScroll = find.byType(Scrollable).last;
    await tester.scrollUntilVisible(
      find.text('Device Offline — Controls Locked'),
      200,
      scrollable: deviceListScroll,
    );
    expect(find.text('Device Offline — Controls Locked'), findsOneWidget);
    expect(find.text('LAN OK'), findsNothing);

    // Tapping channel on an offline device must NOT invoke sendDeviceControl
    await tester.scrollUntilVisible(
      find.text('CH1: Offline'),
      150,
      scrollable: deviceListScroll,
    );
    await tester.tap(find.text('CH1: Offline'));
    await tester.pumpAndSettle();
    expect(repo.controlCalled, isFalse);

    // Tapping channel on an online device invokes sendDeviceControl
    await tester.scrollUntilVisible(
      find.text('CH1: OFF'),
      -150,
      scrollable: deviceListScroll,
    );
    await tester.tap(find.text('CH1: OFF'));
    await tester.pumpAndSettle();
    expect(repo.controlCalled, isTrue);

    // Edit & Remove menu controls exist
    expect(find.byType(PopupMenuButton<String>), findsNWidgets(3));
  });

  testWidgets('HubManagementPage navigates to Automations & Integrations nested CRUD screens', (tester) async {
    final repo = MockTestHubRepository(
      initialState: const HubState(
        status: HubConnectionStatus.connected,
        hostname: 'eh-hub.local',
        latencyMs: 2,
        connectedDevices: [],
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

    final autoTile = find.text('Schedules, Timers & Fast Rules');
    await tester.scrollUntilVisible(autoTile, 200);
    await tester.tap(autoTile);
    await tester.pumpAndSettle();

    expect(find.text('Test Porch Routine'), findsOneWidget);
    expect(find.text('New Schedule'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();

    final intTile = find.text('Backups, Home Assistant & Webhooks');
    await tester.scrollUntilVisible(intTile, 200);
    await tester.tap(intTile);
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(find.text('Before Refactor Snapshot'), 200);
    expect(find.text('Before Refactor Snapshot'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Hallway Scene Hook'), 200);
    expect(find.text('Hallway Scene Hook'), findsOneWidget);
  });
}

