import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../../../core/services/device_storage_service.dart';
import '../../../core/services/local_lan_device_service.dart';
import '../domain/models/hub_models.dart';

abstract class HubRepository {
  Future<HubState> getHubState({String? homeId, bool allowSubnetSweep = false});
  Future<bool> linkHub({required String hubHostname, required String homeId});
  Future<bool> unlinkHub({required String hubHostname});
  Future<List<HubDeviceInfo>> adoptDiscoveredSwitches({
    required String hubHostname,
    required List<String> switchIds,
    List<Map<String, dynamic>>? devices,
  });
  Future<bool> updateHubDevice({
    required String hubHostname,
    required String deviceId,
    String? name,
    String? roomName,
    HubDeviceCategory? category,
  });
  Future<bool> removeHubDevice({
    required String hubHostname,
    required String deviceId,
  });
  Future<bool> sendDeviceControl({
    required String hubHostname,
    required String deviceId,
    required int channel,
    required bool power,
    bool isToggle = false,
  });
  Future<List<Map<String, dynamic>>> getRoutines({required String hubHostname});
  Future<bool> upsertHubRoutine({
    required String hubHostname,
    required Map<String, dynamic> routinePayload,
  });
  Future<bool> deleteHubRoutine({
    required String hubHostname,
    required String routineId,
  });
  Future<bool> triggerRoutine({required String hubHostname, required String routineId});
  Future<List<HubActiveTimer>> getActiveHubTimers({required String hubHostname});
  Future<bool> cancelHubTimer({required String hubHostname, required String timerId});
  Future<bool> syncAutomations({required String hubHostname});
  Future<bool> syncTimeBroadcast({required String hubHostname});
  Future<bool> restartHubCore({required String hubHostname});
  Future<bool> identifyHub({required String hubHostname});
  Future<bool> verifyHubPin({required String hubHostname, required String pin});
  Future<String?> rotateHubToken({required String hubHostname});
  Future<bool> resetMeshNetwork({required String hubHostname});
  Future<bool> factoryResetHub({required String hubHostname});
  Future<Map<String, dynamic>> getHubUpdates({required String hubHostname});
  Future<bool> checkForUpdates({required String hubHostname});
  Future<bool> deleteStagedOtaBinary({required String hubHostname, required String filename});
  Future<List<CrossDeviceRule>> getCrossDeviceRules({required String hubHostname});
  Future<bool> saveCrossDeviceRule({required String hubHostname, required CrossDeviceRule rule});
  Future<bool> deleteCrossDeviceRule({required String hubHostname, required String ruleId});
  Future<Map<String, dynamic>?> testCrossDeviceRule({required String hubHostname, required String ruleId});
  Future<List<AutomationExecutionLog>> getExecutionLogs({required String hubHostname, int limit = 50});
  Future<Map<String, dynamic>?> getHomeEnergySummary({required String hubHostname, String period = 'today'});
  Future<Map<String, dynamic>?> getDeviceEnergyHistory({required String hubHostname, required String deviceId, int channel = 1, String period = 'today'});
  Future<Map<String, dynamic>?> getDeviceSettings({required String deviceIp});
  Future<bool> setDevicePowerOnMode({required String deviceIp, required int mode});
  Future<bool> setDeviceChildLock({required String deviceIp, required bool enabled});
  Future<Map<String, dynamic>?> getHomeAssistantStatus({required String hubHostname});
  Future<Map<String, dynamic>?> saveHomeAssistantConfig({
    required String hubHostname,
    required String host,
    int port = 1883,
    String username = '',
    String password = '',
    String discoveryPrefix = 'homeassistant',
  });
  Future<Map<String, dynamic>?> syncHomeAssistant({required String hubHostname});
  Future<Map<String, dynamic>?> getHomeAssistantManifest({required String hubHostname});
  Future<Map<String, dynamic>?> exportHubBackup({required String hubHostname});
  Future<bool> restoreHubBackup({required String hubHostname, required Map<String, dynamic> backup});
  Future<List<HubBackupSummary>> listSavedBackups({required String hubHostname});
  Future<HubBackupSummary?> createSavedBackup({required String hubHostname, required String label});
  Future<bool> restoreSavedBackupById({required String hubHostname, required String backupId});
  Future<bool> deleteSavedBackup({required String hubHostname, required String backupId});
  Future<List<HubWebhookRule>> getWebhooks({required String hubHostname});
  Future<HubWebhookRule?> saveWebhook({required String hubHostname, required HubWebhookRule webhook});
  Future<bool> deleteWebhook({required String hubHostname, required String webhookId});
  Future<bool> testWebhook({required String hubHostname, required String webhookId});
  Future<Map<String, dynamic>?> exportDiagnostics({required String hubHostname});
}

class LiveHubRepository implements HubRepository {
  LiveHubRepository({http.Client? client})
      : _hasInjectedClient = client != null,
        _client = client ?? http.Client();

  final bool _hasInjectedClient;
  final http.Client _client;

  static bool isLinked = false;
  static bool isHubActive = false;
  static String? activeHost;
  static String? customHost;

  Map<String, String> _headers({bool jsonContent = true, bool closeConn = false}) {
    final token = DeviceStorageService.persistedHubToken;
    return {
      if (jsonContent) 'Content-Type': 'application/json',
      if (closeConn) 'Connection': 'close',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
      if (token != null && token.isNotEmpty) 'X-Hub-Token': token,
    };
  }

  static List<String> getCandidateHosts([String? overrideHost]) {
    final list = <String>[];
    if (overrideHost != null && overrideHost.trim().isNotEmpty) {
      list.add(overrideHost.trim());
    }
    final udpDiscovered = LocalLanDeviceService.instance.cachedHubHost;
    if (udpDiscovered != null && udpDiscovered.trim().isNotEmpty && !list.contains(udpDiscovered)) {
      list.add(udpDiscovered.trim());
    }
    final persisted = DeviceStorageService.persistedHubHost;
    if (persisted != null && persisted.trim().isNotEmpty && !list.contains(persisted)) {
      list.add(persisted.trim());
    }
    if (activeHost != null && activeHost!.trim().isNotEmpty && !list.contains(activeHost)) {
      list.add(activeHost!.trim());
    }
    if (customHost != null && customHost!.trim().isNotEmpty && !list.contains(customHost)) {
      list.add(customHost!.trim());
    }
    for (final def in const ['192.168.0.174', '192.168.0.100', '192.168.0.2', 'eh-hub.local', 'raspberrypi.local', '127.0.0.1', 'localhost']) {
      if (!list.contains(def)) list.add(def);
    }
    return list;
  }

  Future<HubState?> _probeSingleHost(String host) async {
    try {
      if (!_hasInjectedClient) {
        final s = await Socket.connect(host, 4210, timeout: const Duration(milliseconds: 350));
        s.destroy();
      }
      final uri = Uri.parse('http://$host:4210/api/v1/hub/info');
      final res = await _client.get(uri, headers: _headers(jsonContent: false)).timeout(const Duration(milliseconds: 1200));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final linked = data['isLinked'] as bool? ?? false;

        List<HubDeviceInfo> devices = [];
        try {
          final devUri = Uri.parse('http://$host:4210/api/v1/hub/devices');
          final devRes = await _client.get(devUri, headers: _headers(jsonContent: false)).timeout(const Duration(milliseconds: 500));
          if (devRes.statusCode == 200) {
            final devJson = jsonDecode(devRes.body) as Map<String, dynamic>;
            final rawList = devJson['devices'] as List<dynamic>? ?? [];
            devices = rawList.map((d) => HubDeviceInfo.fromJson(d as Map<String, dynamic>)).toList();
          }
        } catch (_) {}

        return HubState(
          status: linked ? HubConnectionStatus.connected : HubConnectionStatus.notConfigured,
          hubId: data['hubId'] as String? ?? 'eh-hub-pi3b',
          hostname: host,
          ipAddress: data['ipAddress'] as String? ?? host,
          model: data['model'] as String? ?? 'EH Smart Hub',
          firmwareVersion: data['version'] as String? ?? '',
          uptime: data['uptime'] as String? ?? '—',
          latencyMs: (data['latencyMs'] as num?)?.toInt() ?? 0,
          connectedDevices: devices,
          standardRoutinesCount: (data['standardRoutinesCount'] as num?)?.toInt() ?? 0,
          criticalRoutinesCount: (data['criticalRoutinesCount'] as num?)?.toInt() ?? 0,
          activeTimersCount: (data['activeTimersCount'] as num?)?.toInt() ?? 0,
          storageEngine: data['storageEngine'] as String? ?? 'atomic-wal',
          sdCardOverlayFsActive: data['overlayFs'] as bool? ?? false,
          localNtpSynced: data['ntpSynced'] as bool? ?? false,
          rssiDbm: (data['rssiDbm'] as num?)?.toInt() ?? (data['rssi'] as num?)?.toInt(),
        );
      }
    } catch (_) {}
    return null;
  }

  @override
  Future<HubState> getHubState({String? homeId, bool allowSubnetSweep = false}) async {
    final candidateHosts = getCandidateHosts();
    if (candidateHosts.isEmpty) {
      isHubActive = false;
      LocalLanDeviceService.instance.cachedHubHost = null;
      return const HubState(status: HubConnectionStatus.unreachable);
    }

    try {
      final results = await Future.wait(candidateHosts.map(_probeSingleHost));
      for (final state in results) {
        if (state != null) {
          isLinked = (state.status == HubConnectionStatus.connected);
          isHubActive = true;
          activeHost = state.hostname;
          DeviceStorageService.setPersistedHubHost(state.hostname);
          LocalLanDeviceService.instance.cachedHubHost = state.hostname;
          return state;
        }
      }
    } catch (_) {}

    if (!_hasInjectedClient && LocalLanDeviceService.instance.cachedHubHost == null) {
      try {
        final discoveredHost = await LocalLanDeviceService.instance.discoverHubNow(
          timeout: const Duration(milliseconds: 500),
        );
        if (discoveredHost != null && discoveredHost.isNotEmpty) {
          final discoveredState = await _probeSingleHost(discoveredHost);
          if (discoveredState != null) {
            isLinked = (discoveredState.status == HubConnectionStatus.connected);
            isHubActive = true;
            activeHost = discoveredState.hostname;
            DeviceStorageService.setPersistedHubHost(discoveredState.hostname);
            LocalLanDeviceService.instance.cachedHubHost = discoveredState.hostname;
            return discoveredState;
          }
        }
      } catch (_) {}
    }

    if (allowSubnetSweep) {
      final sweptHost = await _findHubOnSubnet();
      if (sweptHost != null) {
        activeHost = sweptHost;
        final sweptState = await _probeSingleHost(sweptHost);
        if (sweptState != null) {
          isLinked = (sweptState.status == HubConnectionStatus.connected);
          isHubActive = true;
          activeHost = sweptState.hostname;
          DeviceStorageService.setPersistedHubHost(sweptState.hostname);
          return sweptState;
        }
      }
    }

    isHubActive = false;
    LocalLanDeviceService.instance.cachedHubHost = null;
    return const HubState(status: HubConnectionStatus.unreachable);
  }

  static Future<String?> _findHubOnSubnet() async {
    try {
      final subnets = <String>{};
      final interfaces = await NetworkInterface.list(type: InternetAddressType.IPv4, includeLoopback: false);
      for (final iface in interfaces) {
        final name = iface.name.toLowerCase();
        if (name.startsWith('rmnet') ||
            name.startsWith('ccmni') ||
            name.startsWith('tun') ||
            name.startsWith('ppp') ||
            name.startsWith('dummy') ||
            name.startsWith('pdp')) {
          continue;
        }
        for (final addr in iface.addresses) {
          final ip = addr.address;
          if (ip.startsWith('192.168.') || ip.startsWith('10.') || ip.startsWith('172.')) {
            final parts = ip.split('.');
            if (parts.length == 4) subnets.add('${parts[0]}.${parts[1]}.${parts[2]}');
          }
        }
      }
      if (subnets.isEmpty) subnets.add('192.168.0');

      for (final subnet in subnets) {
        const batchSize = 64;
        for (int b = 1; b <= 254; b += batchSize) {
          final end = (b + batchSize > 255) ? 255 : b + batchSize;
          final batchIps = [for (int i = b; i < end; i++) '$subnet.$i'];
          final results = await Future.wait(batchIps.map((ip) async {
            try {
              final s = await Socket.connect(ip, 4210, timeout: const Duration(milliseconds: 250));
              s.destroy();
              final client = http.Client();
              try {
                final uri = Uri.parse('http://$ip:4210/api/v1/hub/info');
                final res = await client.get(uri).timeout(const Duration(milliseconds: 500));
                if (res.statusCode == 200) {
                  final data = jsonDecode(res.body);
                  if (data is Map && (data['hubId'] != null || data['model'] != null)) {
                    return ip;
                  }
                }
              } finally {
                client.close();
              }
            } catch (_) {}
            return null;
          }));

          for (final found in results) {
            if (found != null) {
              DeviceStorageService.setPersistedHubHost(found);
              LocalLanDeviceService.instance.cachedHubHost = found;
              return found;
            }
          }
        }
      }
    } catch (_) {}
    return null;
  }

  @override
  Future<bool> linkHub({required String hubHostname, required String homeId}) async {
    for (final host in getCandidateHosts(hubHostname)) {
      try {
        final uri = Uri.parse('http://$host:4210/api/v1/hub/link');
        final claimNonce = 'eh_claim_${DateTime.now().millisecondsSinceEpoch}';
        final cloudUrl = DeviceStorageService.backendUrl;
        final res = await _client.post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'homeId': homeId,
            'token': claimNonce,
            if (cloudUrl != null && cloudUrl.isNotEmpty) 'cloudUrl': cloudUrl,
          }),
        ).timeout(const Duration(seconds: 3));
        if (res.statusCode == 200) {
          try {
            final body = jsonDecode(res.body) as Map<String, dynamic>;
            final issuedToken = (body['hubAccessToken'] ?? body['accessToken'])?.toString();
            if (issuedToken != null && issuedToken.isNotEmpty) {
              await DeviceStorageService.setPersistedHubToken(issuedToken);
            }
          } catch (_) {}
          isLinked = true;
          isHubActive = true;
          activeHost = host;
          return true;
        }
      } catch (_) {}
    }
    return false;
  }

  @override
  Future<bool> unlinkHub({required String hubHostname}) async {
    for (final host in getCandidateHosts(hubHostname)) {
      try {
        final uri = Uri.parse('http://$host:4210/api/v1/hub/unlink');
        final res = await _client.post(uri, headers: _headers()).timeout(const Duration(seconds: 2));
        if (res.statusCode == 200) {
          isLinked = false;
          await DeviceStorageService.setPersistedHubToken(null);
          return true;
        }
      } catch (_) {}
    }
    return false;
  }

  @override
  Future<List<HubDeviceInfo>> adoptDiscoveredSwitches({
    required String hubHostname,
    required List<String> switchIds,
    List<Map<String, dynamic>>? devices,
  }) async {
    for (final host in getCandidateHosts(hubHostname)) {
      try {
        final uri = Uri.parse('http://$host:4210/api/v1/hub/adopt');
        final payload = <String, dynamic>{
          'switchIds': switchIds,
          'devices': ?devices,
        };
        final res = await _client.post(
          uri,
          headers: _headers(),
          body: jsonEncode(payload),
        ).timeout(const Duration(seconds: 3));
        if (res.statusCode == 200) {
          final data = jsonDecode(res.body) as Map<String, dynamic>;
          final rawList = data['devices'] as List<dynamic>? ?? [];
          return rawList.map((d) => HubDeviceInfo.fromJson(d as Map<String, dynamic>)).toList();
        }
      } catch (_) {}
    }
    return const [];
  }

  @override
  Future<bool> updateHubDevice({
    required String hubHostname,
    required String deviceId,
    String? name,
    String? roomName,
    HubDeviceCategory? category,
  }) async {
    for (final host in getCandidateHosts(hubHostname)) {
      try {
        final uri = Uri.parse('http://$host:4210/api/v1/hub/devices/${Uri.encodeComponent(deviceId)}');
        final res = await _client.patch(
          uri,
          headers: _headers(),
          body: jsonEncode({
            'name': ?name,
            'roomName': ?roomName,
            if (category != null) 'category': category.name,
          }),
        ).timeout(const Duration(seconds: 2));
        if (res.statusCode == 200) return true;
      } catch (_) {}
    }
    return false;
  }

  @override
  Future<bool> removeHubDevice({
    required String hubHostname,
    required String deviceId,
  }) async {
    for (final host in getCandidateHosts(hubHostname)) {
      try {
        final uri = Uri.parse('http://$host:4210/api/v1/hub/devices/${Uri.encodeComponent(deviceId)}');
        final res = await _client.delete(uri, headers: _headers()).timeout(const Duration(seconds: 2));
        if (res.statusCode == 200) return true;
      } catch (_) {}
    }
    return false;
  }

  @override
  Future<bool> sendDeviceControl({
    required String hubHostname,
    required String deviceId,
    required int channel,
    required bool power,
    bool isToggle = false,
  }) async {
    bool anyHubResponded = false;
    final candidates = getCandidateHosts(hubHostname).take(3).toList();
    for (final host in candidates) {
      try {
        if (!_hasInjectedClient) {
          final s = await Socket.connect(host, 4210, timeout: const Duration(milliseconds: 350));
          s.destroy();
        }
        final uri = Uri.parse('http://$host:4210/api/v1/control');
        final payload = {
          'deviceId': deviceId,
          'channel': channel,
          'channelIndex': channel,
          'power': power,
          'value': power,
          'state': power,
          if (isToggle) 'toggle': true,
          if (isToggle) 'action': 'toggle',
        };
        final res = await _client
            .post(
              uri,
              headers: _headers(closeConn: true),
              body: jsonEncode(payload),
            )
            .timeout(const Duration(milliseconds: 1600));
        if (res.statusCode == 200) {
          anyHubResponded = true;
          try {
            final parsed = jsonDecode(res.body);
            if (parsed is Map && parsed['status'] == 'ok' && parsed['localExecuted'] == true) {
              return false;
            }
          } catch (_) {}
          isHubActive = true;
          activeHost = host;
          LocalLanDeviceService.instance.cachedHubHost = host;
          return true;
        }
      } catch (_) {}
    }
    if (!anyHubResponded) {
      isHubActive = false;
    }
    return false;
  }

  @override
  Future<List<Map<String, dynamic>>> getRoutines({required String hubHostname}) async {
    for (final host in getCandidateHosts(hubHostname)) {
      try {
        final uri = Uri.parse('http://$host:4210/api/v1/routines');
        final res = await _client.get(uri, headers: _headers(jsonContent: false)).timeout(const Duration(seconds: 2));
        if (res.statusCode == 200) {
          final data = jsonDecode(res.body) as Map<String, dynamic>;
          final list = data['routines'] as List<dynamic>? ?? [];
          return list.cast<Map<String, dynamic>>();
        }
      } catch (_) {}
    }
    return [];
  }

  @override
  Future<bool> upsertHubRoutine({
    required String hubHostname,
    required Map<String, dynamic> routinePayload,
  }) async {
    for (final host in getCandidateHosts(hubHostname)) {
      try {
        final uri = Uri.parse('http://$host:4210/api/v1/routines');
        final res = await _client.post(
          uri,
          headers: _headers(),
          body: jsonEncode(routinePayload),
        ).timeout(const Duration(seconds: 2));
        if (res.statusCode == 200) return true;
      } catch (_) {}
    }
    return false;
  }

  @override
  Future<bool> deleteHubRoutine({
    required String hubHostname,
    required String routineId,
  }) async {
    for (final host in getCandidateHosts(hubHostname)) {
      try {
        final uri = Uri.parse('http://$host:4210/api/v1/routines?id=${Uri.encodeQueryComponent(routineId)}');
        final res = await _client.delete(uri, headers: _headers()).timeout(const Duration(seconds: 2));
        if (res.statusCode == 200) return true;
      } catch (_) {}
    }
    return false;
  }

  @override
  Future<bool> triggerRoutine({required String hubHostname, required String routineId}) async {
    for (final host in getCandidateHosts(hubHostname)) {
      try {
        final uri = Uri.parse('http://$host:4210/api/v1/routines/trigger');
        final res = await _client.post(
          uri,
          headers: _headers(),
          body: jsonEncode({'id': routineId}),
        ).timeout(const Duration(seconds: 2));
        if (res.statusCode == 200) return true;
      } catch (_) {}
    }
    return false;
  }

  @override
  Future<List<HubActiveTimer>> getActiveHubTimers({required String hubHostname}) async {
    for (final host in getCandidateHosts(hubHostname)) {
      try {
        final uri = Uri.parse('http://$host:4210/api/v1/routines/timers');
        final res = await _client.get(uri, headers: _headers(jsonContent: false)).timeout(const Duration(seconds: 2));
        if (res.statusCode == 200) {
          final data = jsonDecode(res.body) as Map<String, dynamic>;
          final list = data['activeTimers'] as List<dynamic>? ?? [];
          return list.map((t) => HubActiveTimer.fromJson(Map<String, dynamic>.from(t as Map))).toList();
        }
      } catch (_) {}
    }
    return const [];
  }

  @override
  Future<bool> cancelHubTimer({required String hubHostname, required String timerId}) async {
    for (final host in getCandidateHosts(hubHostname)) {
      try {
        final uri = Uri.parse('http://$host:4210/api/v1/routines/timers?id=${Uri.encodeQueryComponent(timerId)}');
        final res = await _client.delete(uri, headers: _headers()).timeout(const Duration(seconds: 2));
        if (res.statusCode == 200) return true;
      } catch (_) {}
    }
    return false;
  }

  @override
  Future<bool> syncTimeBroadcast({required String hubHostname}) async {
    for (final host in getCandidateHosts(hubHostname)) {
      try {
        final uri = Uri.parse('http://$host:4210/api/v1/hub/time/sync');
        final res = await _client.post(uri, headers: _headers()).timeout(const Duration(seconds: 2));
        if (res.statusCode == 200) return true;
      } catch (_) {}
    }
    return false;
  }

  @override
  Future<bool> syncAutomations({required String hubHostname}) async {
    for (final host in getCandidateHosts(hubHostname)) {
      try {
        final uri = Uri.parse('http://$host:4210/api/v1/routines');
        final res = await _client.get(uri, headers: _headers(jsonContent: false)).timeout(const Duration(seconds: 2));
        if (res.statusCode == 200) return true;
      } catch (_) {}
    }
    return false;
  }

  @override
  Future<bool> restartHubCore({required String hubHostname}) async {
    for (final host in getCandidateHosts(hubHostname)) {
      try {
        final uri = Uri.parse('http://$host:4210/api/v1/hub/reboot');
        final res = await _client.post(uri, headers: _headers()).timeout(const Duration(seconds: 2));
        if (res.statusCode == 200) return true;
      } catch (_) {}
    }
    return false;
  }

  @override
  Future<bool> identifyHub({required String hubHostname}) async {
    for (final host in getCandidateHosts(hubHostname)) {
      try {
        final uri = Uri.parse('http://$host:4210/api/v1/hub/identify');
        final res = await _client.post(uri, headers: _headers()).timeout(const Duration(seconds: 2));
        if (res.statusCode == 200) return true;
      } catch (_) {}
    }
    return false;
  }

  @override
  Future<bool> verifyHubPin({required String hubHostname, required String pin}) async {
    for (final host in getCandidateHosts(hubHostname)) {
      try {
        final uri = Uri.parse('http://$host:4210/api/v1/hub/auth/verify');
        final res = await _client.post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'pin': pin}),
        ).timeout(const Duration(seconds: 2));
        if (res.statusCode == 200) {
          final data = jsonDecode(res.body) as Map<String, dynamic>;
          return data['verified'] == true;
        }
      } catch (_) {}
    }
    return false;
  }

  @override
  Future<String?> rotateHubToken({required String hubHostname}) async {
    for (final host in getCandidateHosts(hubHostname)) {
      try {
        final uri = Uri.parse('http://$host:4210/api/v1/hub/auth/rotate-token');
        final res = await _client.post(uri, headers: _headers()).timeout(const Duration(seconds: 2));
        if (res.statusCode == 200) {
          final data = jsonDecode(res.body) as Map<String, dynamic>;
          final tok = (data['hubAccessToken'] ?? data['accessToken'])?.toString();
          if (tok != null && tok.isNotEmpty) {
            await DeviceStorageService.setPersistedHubToken(tok);
            return tok;
          }
        }
      } catch (_) {}
    }
    return null;
  }

  @override
  Future<bool> resetMeshNetwork({required String hubHostname}) async {
    for (final host in getCandidateHosts(hubHostname)) {
      try {
        final uri = Uri.parse('http://$host:4210/api/v1/hub/network/reset');
        final res = await _client.post(uri, headers: _headers()).timeout(const Duration(seconds: 2));
        if (res.statusCode == 200) return true;
      } catch (_) {}
    }
    return false;
  }

  @override
  Future<bool> factoryResetHub({required String hubHostname}) async {
    for (final host in getCandidateHosts(hubHostname)) {
      try {
        final uri = Uri.parse('http://$host:4210/api/v1/hub/factory-reset');
        final res = await _client.post(uri, headers: _headers()).timeout(const Duration(seconds: 2));
        if (res.statusCode == 200) {
          isLinked = false;
          await DeviceStorageService.setPersistedHubToken(null);
          return true;
        }
      } catch (_) {}
    }
    return false;
  }

  @override
  Future<Map<String, dynamic>> getHubUpdates({required String hubHostname}) async {
    for (final host in getCandidateHosts(hubHostname)) {
      try {
        final uri = Uri.parse('http://$host:4210/api/v1/hub/updates');
        final res = await _client.get(uri, headers: _headers(jsonContent: false)).timeout(const Duration(seconds: 2));
        if (res.statusCode == 200) {
          return jsonDecode(res.body) as Map<String, dynamic>;
        }
      } catch (_) {}
    }
    return {
      'status': 'unreachable',
      'hub': {'updateAvailable': false},
      'deviceOtaCache': {
        'enabled': false,
        'cachedCount': 0,
        'cachedFirmwares': const [],
      },
    };
  }

  @override
  Future<bool> checkForUpdates({required String hubHostname}) async {
    for (final host in getCandidateHosts(hubHostname)) {
      try {
        final uri = Uri.parse('http://$host:4210/api/v1/hub/updates/check');
        final res = await _client.post(uri, headers: _headers()).timeout(const Duration(seconds: 2));
        if (res.statusCode == 200) return true;
      } catch (_) {}
    }
    return false;
  }

  @override
  Future<bool> deleteStagedOtaBinary({required String hubHostname, required String filename}) async {
    for (final host in getCandidateHosts(hubHostname)) {
      try {
        final uri = Uri.parse('http://$host:4210/api/v1/ota/manifest/${Uri.encodeComponent(filename)}');
        final res = await _client.delete(uri, headers: _headers()).timeout(const Duration(seconds: 2));
        if (res.statusCode == 200) return true;
      } catch (_) {}
    }
    return false;
  }

  @override
  Future<List<CrossDeviceRule>> getCrossDeviceRules({required String hubHostname}) async {
    for (final host in getCandidateHosts(hubHostname)) {
      try {
        final uri = Uri.parse('http://$host:4210/api/v1/rules');
        final res = await _client.get(uri, headers: _headers(jsonContent: false)).timeout(const Duration(seconds: 2));
        if (res.statusCode == 200) {
          final data = jsonDecode(res.body) as Map<String, dynamic>;
          final raw = data['rules'] as List<dynamic>? ?? [];
          return raw.map((r) => CrossDeviceRule.fromJson(r as Map<String, dynamic>)).toList();
        }
      } catch (_) {}
    }
    return const [];
  }

  @override
  Future<bool> saveCrossDeviceRule({required String hubHostname, required CrossDeviceRule rule}) async {
    for (final host in getCandidateHosts(hubHostname)) {
      try {
        final uri = Uri.parse('http://$host:4210/api/v1/rules');
        final res = await _client.post(
          uri,
          headers: _headers(),
          body: jsonEncode(rule.toJson()),
        ).timeout(const Duration(seconds: 2));
        if (res.statusCode == 200) return true;
      } catch (_) {}
    }
    return false;
  }

  @override
  Future<bool> deleteCrossDeviceRule({required String hubHostname, required String ruleId}) async {
    for (final host in getCandidateHosts(hubHostname)) {
      try {
        final uri = Uri.parse('http://$host:4210/api/v1/rules?id=${Uri.encodeQueryComponent(ruleId)}');
        final res = await _client.delete(uri, headers: _headers()).timeout(const Duration(seconds: 2));
        if (res.statusCode == 200) return true;
      } catch (_) {}
    }
    return false;
  }

  @override
  Future<Map<String, dynamic>?> testCrossDeviceRule({required String hubHostname, required String ruleId}) async {
    for (final host in getCandidateHosts(hubHostname)) {
      try {
        final uri = Uri.parse('http://$host:4210/api/v1/rules/test?id=${Uri.encodeQueryComponent(ruleId)}');
        final res = await _client.post(uri, headers: _headers()).timeout(const Duration(seconds: 2));
        if (res.statusCode == 200) {
          return jsonDecode(res.body) as Map<String, dynamic>;
        }
      } catch (_) {}
    }
    return null;
  }

  @override
  Future<List<AutomationExecutionLog>> getExecutionLogs({required String hubHostname, int limit = 50}) async {
    for (final host in getCandidateHosts(hubHostname)) {
      try {
        final uri = Uri.parse('http://$host:4210/api/v1/rules/logs?limit=$limit');
        final res = await _client.get(uri, headers: _headers(jsonContent: false)).timeout(const Duration(seconds: 2));
        if (res.statusCode == 200) {
          final data = jsonDecode(res.body) as Map<String, dynamic>;
          final raw = data['logs'] as List<dynamic>? ?? [];
          return raw.map((l) => AutomationExecutionLog.fromJson(l as Map<String, dynamic>)).toList();
        }
      } catch (_) {}
    }
    return const [];
  }

  @override
  Future<Map<String, dynamic>?> getHomeEnergySummary({required String hubHostname, String period = 'today'}) async {
    for (final host in getCandidateHosts(hubHostname)) {
      try {
        final uri = Uri.parse('http://$host:4210/api/v1/hub/energy/home/summary?period=$period');
        final res = await _client.get(uri, headers: _headers(jsonContent: false)).timeout(const Duration(seconds: 2));
        if (res.statusCode == 200) {
          final data = jsonDecode(res.body) as Map<String, dynamic>;
          return data['summary'] as Map<String, dynamic>?;
        }
      } catch (_) {}
    }
    return null;
  }

  @override
  Future<Map<String, dynamic>?> getDeviceEnergyHistory({
    required String hubHostname,
    required String deviceId,
    int channel = 1,
    String period = 'today',
  }) async {
    for (final host in getCandidateHosts(hubHostname)) {
      try {
        final uri = Uri.parse('http://$host:4210/api/v1/hub/energy/devices/$deviceId/history?channel=$channel&period=$period');
        final res = await _client.get(uri, headers: _headers(jsonContent: false)).timeout(const Duration(seconds: 2));
        if (res.statusCode == 200) {
          final data = jsonDecode(res.body) as Map<String, dynamic>;
          return data['summary'] as Map<String, dynamic>?;
        }
      } catch (_) {}
    }
    return null;
  }

  @override
  Future<Map<String, dynamic>?> getDeviceSettings({required String deviceIp}) async {
    try {
      final uri = Uri.parse('http://$deviceIp:80/api/v1/settings');
      final res = await _client.get(uri).timeout(const Duration(seconds: 2));
      if (res.statusCode == 200) {
        return jsonDecode(res.body) as Map<String, dynamic>?;
      }
    } catch (_) {}
    return null;
  }

  @override
  Future<bool> setDevicePowerOnMode({required String deviceIp, required int mode}) async {
    try {
      final uri = Uri.parse('http://$deviceIp:80/api/v1/settings/power-on');
      final res = await _client.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'mode': mode}),
      ).timeout(const Duration(seconds: 2));
      return res.statusCode == 200;
    } catch (_) {}
    return false;
  }

  @override
  Future<bool> setDeviceChildLock({required String deviceIp, required bool enabled}) async {
    try {
      final uri = Uri.parse('http://$deviceIp:80/api/v1/settings/child-lock');
      final res = await _client.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'enabled': enabled}),
      ).timeout(const Duration(seconds: 2));
      return res.statusCode == 200;
    } catch (_) {}
    return false;
  }

  @override
  Future<Map<String, dynamic>?> getHomeAssistantStatus({required String hubHostname}) async {
    for (final host in getCandidateHosts(hubHostname)) {
      try {
        final uri = Uri.parse('http://$host:4210/api/v1/integrations/homeassistant/status');
        final res = await _client.get(uri, headers: _headers(jsonContent: false)).timeout(const Duration(seconds: 2));
        if (res.statusCode == 200) {
          return jsonDecode(res.body) as Map<String, dynamic>?;
        }
      } catch (_) {}
    }
    return null;
  }

  @override
  Future<Map<String, dynamic>?> saveHomeAssistantConfig({
    required String hubHostname,
    required String host,
    int port = 1883,
    String username = '',
    String password = '',
    String discoveryPrefix = 'homeassistant',
  }) async {
    for (final h in getCandidateHosts(hubHostname)) {
      try {
        final uri = Uri.parse('http://$h:4210/api/v1/integrations/homeassistant/config');
        final res = await _client.post(
          uri,
          headers: _headers(),
          body: jsonEncode({
            'host': host,
            'port': port,
            'username': username,
            'password': password,
            'discoveryPrefix': discoveryPrefix,
          }),
        ).timeout(const Duration(seconds: 4));
        if (res.statusCode == 200) {
          return jsonDecode(res.body) as Map<String, dynamic>?;
        }
      } catch (_) {}
    }
    return null;
  }

  @override
  Future<Map<String, dynamic>?> syncHomeAssistant({required String hubHostname}) async {
    for (final host in getCandidateHosts(hubHostname)) {
      try {
        final uri = Uri.parse('http://$host:4210/api/v1/integrations/homeassistant/sync');
        final res = await _client.post(uri, headers: _headers()).timeout(const Duration(seconds: 4));
        if (res.statusCode == 200) {
          return jsonDecode(res.body) as Map<String, dynamic>?;
        }
      } catch (_) {}
    }
    return null;
  }

  @override
  Future<Map<String, dynamic>?> getHomeAssistantManifest({required String hubHostname}) async {
    for (final host in getCandidateHosts(hubHostname)) {
      try {
        final uri = Uri.parse('http://$host:4210/api/v1/integrations/homeassistant/manifest');
        final res = await _client.get(uri, headers: _headers(jsonContent: false)).timeout(const Duration(seconds: 2));
        if (res.statusCode == 200) {
          return jsonDecode(res.body) as Map<String, dynamic>?;
        }
      } catch (_) {}
    }
    return null;
  }

  @override
  Future<Map<String, dynamic>?> exportHubBackup({required String hubHostname}) async {
    for (final host in getCandidateHosts(hubHostname)) {
      try {
        final uri = Uri.parse('http://$host:4210/api/v1/hub/backup');
        final res = await _client.get(uri, headers: _headers(jsonContent: false)).timeout(const Duration(seconds: 4));
        if (res.statusCode == 200) {
          return jsonDecode(res.body) as Map<String, dynamic>?;
        }
      } catch (_) {}
    }
    return null;
  }

  @override
  Future<bool> restoreHubBackup({required String hubHostname, required Map<String, dynamic> backup}) async {
    for (final host in getCandidateHosts(hubHostname)) {
      try {
        final uri = Uri.parse('http://$host:4210/api/v1/hub/restore');
        final res = await _client.post(
          uri,
          headers: _headers(),
          body: jsonEncode(backup),
        ).timeout(const Duration(seconds: 5));
        if (res.statusCode == 200) return true;
      } catch (_) {}
    }
    return false;
  }

  @override
  Future<List<HubBackupSummary>> listSavedBackups({required String hubHostname}) async {
    for (final host in getCandidateHosts(hubHostname)) {
      try {
        final uri = Uri.parse('http://$host:4210/api/v1/hub/backups');
        final res = await _client.get(uri, headers: _headers(jsonContent: false)).timeout(const Duration(seconds: 3));
        if (res.statusCode == 200) {
          final data = jsonDecode(res.body) as Map<String, dynamic>;
          final list = data['backups'] as List<dynamic>? ?? [];
          return list.map((b) => HubBackupSummary.fromJson(Map<String, dynamic>.from(b as Map))).toList();
        }
      } catch (_) {}
    }
    return const [];
  }

  @override
  Future<HubBackupSummary?> createSavedBackup({required String hubHostname, required String label}) async {
    for (final host in getCandidateHosts(hubHostname)) {
      try {
        final uri = Uri.parse('http://$host:4210/api/v1/hub/backups');
        final res = await _client.post(
          uri,
          headers: _headers(),
          body: jsonEncode({'label': label}),
        ).timeout(const Duration(seconds: 4));
        if (res.statusCode == 200) {
          final data = jsonDecode(res.body) as Map<String, dynamic>;
          if (data['backup'] is Map) {
            return HubBackupSummary.fromJson(Map<String, dynamic>.from(data['backup'] as Map));
          }
        }
      } catch (_) {}
    }
    return null;
  }

  @override
  Future<bool> restoreSavedBackupById({required String hubHostname, required String backupId}) async {
    for (final host in getCandidateHosts(hubHostname)) {
      try {
        final uri = Uri.parse('http://$host:4210/api/v1/hub/backups/${Uri.encodeComponent(backupId)}/restore');
        final res = await _client.post(uri, headers: _headers()).timeout(const Duration(seconds: 4));
        if (res.statusCode == 200) return true;
      } catch (_) {}
    }
    return false;
  }

  @override
  Future<bool> deleteSavedBackup({required String hubHostname, required String backupId}) async {
    for (final host in getCandidateHosts(hubHostname)) {
      try {
        final uri = Uri.parse('http://$host:4210/api/v1/hub/backups/${Uri.encodeComponent(backupId)}');
        final res = await _client.delete(uri, headers: _headers()).timeout(const Duration(seconds: 3));
        if (res.statusCode == 200) return true;
      } catch (_) {}
    }
    return false;
  }

  @override
  Future<List<HubWebhookRule>> getWebhooks({required String hubHostname}) async {
    for (final host in getCandidateHosts(hubHostname)) {
      try {
        final uri = Uri.parse('http://$host:4210/api/v1/hub/webhooks');
        final res = await _client.get(uri, headers: _headers(jsonContent: false)).timeout(const Duration(seconds: 2));
        if (res.statusCode == 200) {
          final data = jsonDecode(res.body) as Map<String, dynamic>;
          final list = data['webhooks'] as List<dynamic>? ?? [];
          return list.map((w) => HubWebhookRule.fromJson(Map<String, dynamic>.from(w as Map))).toList();
        }
      } catch (_) {}
    }
    return const [];
  }

  @override
  Future<HubWebhookRule?> saveWebhook({required String hubHostname, required HubWebhookRule webhook}) async {
    for (final host in getCandidateHosts(hubHostname)) {
      try {
        final uri = Uri.parse('http://$host:4210/api/v1/hub/webhooks');
        final res = await _client.post(
          uri,
          headers: _headers(),
          body: jsonEncode(webhook.toJson()),
        ).timeout(const Duration(seconds: 2));
        if (res.statusCode == 200) {
          final data = jsonDecode(res.body) as Map<String, dynamic>;
          if (data['webhook'] is Map) {
            return HubWebhookRule.fromJson(Map<String, dynamic>.from(data['webhook'] as Map));
          }
        }
      } catch (_) {}
    }
    return null;
  }

  @override
  Future<bool> deleteWebhook({required String hubHostname, required String webhookId}) async {
    for (final host in getCandidateHosts(hubHostname)) {
      try {
        final uri = Uri.parse('http://$host:4210/api/v1/hub/webhooks/${Uri.encodeComponent(webhookId)}');
        final res = await _client.delete(uri, headers: _headers()).timeout(const Duration(seconds: 2));
        if (res.statusCode == 200) return true;
      } catch (_) {}
    }
    return false;
  }

  @override
  Future<bool> testWebhook({required String hubHostname, required String webhookId}) async {
    for (final host in getCandidateHosts(hubHostname)) {
      try {
        final uri = Uri.parse('http://$host:4210/api/v1/hub/webhooks/${Uri.encodeComponent(webhookId)}/test');
        final res = await _client.post(uri, headers: _headers()).timeout(const Duration(seconds: 2));
        if (res.statusCode == 200) return true;
      } catch (_) {}
    }
    return false;
  }

  @override
  Future<Map<String, dynamic>?> exportDiagnostics({required String hubHostname}) async {
    for (final host in getCandidateHosts(hubHostname)) {
      try {
        final uri = Uri.parse('http://$host:4210/api/v1/hub/diagnostics/export');
        final res = await _client.get(uri, headers: _headers(jsonContent: false)).timeout(const Duration(seconds: 3));
        if (res.statusCode == 200) {
          return jsonDecode(res.body) as Map<String, dynamic>?;
        }
      } catch (_) {}
    }
    return null;
  }
}
