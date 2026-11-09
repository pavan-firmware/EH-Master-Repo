import 'dart:convert';
import 'package:http/http.dart' as http;
import '../domain/models/hub_models.dart';

abstract class HubRepository {
  Future<HubState> getHubState({String? homeId});
  Future<bool> linkHub({required String hubHostname, required String homeId});
  Future<bool> unlinkHub({required String hubHostname});
  Future<List<HubDeviceInfo>> adoptDiscoveredSwitches({
    required String hubHostname,
    required List<String> switchIds,
    List<Map<String, dynamic>>? devices,
  });
  Future<bool> sendDeviceControl({
    required String hubHostname,
    required String deviceId,
    required int channel,
    required bool power,
    bool isToggle = false,
  });
  Future<List<Map<String, dynamic>>> getRoutines({required String hubHostname});
  Future<bool> triggerRoutine({required String hubHostname, required String routineId});
  Future<bool> syncAutomations({required String hubHostname});
  Future<bool> syncTimeBroadcast({required String hubHostname});
  Future<bool> restartHubCore({required String hubHostname});
}

class LiveHubRepository implements HubRepository {
  LiveHubRepository({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  static bool isLinked = false;
  static bool isHubActive = false;
  static String? activeHost;

  @override
  Future<HubState> getHubState({String? homeId}) async {
    for (final host in ['eh-hub.local', '192.168.0.174']) {
      try {
        final uri = Uri.parse('http://$host:4210/api/v1/hub/info');
        final res = await _client.get(uri).timeout(const Duration(milliseconds: 1500));
        if (res.statusCode == 200) {
          final data = jsonDecode(res.body) as Map<String, dynamic>;
          final linked = data['isLinked'] as bool? ?? false;

          List<HubDeviceInfo> devices = [];
          try {
            final devUri = Uri.parse('http://$host:4210/api/v1/hub/devices');
            final devRes = await _client.get(devUri).timeout(const Duration(milliseconds: 1000));
            if (devRes.statusCode == 200) {
              final devJson = jsonDecode(devRes.body) as Map<String, dynamic>;
              final rawList = devJson['devices'] as List<dynamic>? ?? [];
              devices = rawList.map((d) => HubDeviceInfo.fromJson(d as Map<String, dynamic>)).toList();
            }
          } catch (_) {}

          isLinked = linked;
          isHubActive = true;
          activeHost = host;

          return HubState(
            status: linked ? HubConnectionStatus.connected : HubConnectionStatus.notConfigured,
            hubId: data['hubId'] as String? ?? 'eh-hub-pi3b',
            hostname: host,
            ipAddress: data['ipAddress'] as String? ?? host,
            model: data['model'] as String? ?? 'EH-HUB-V1-PI (Raspberry Pi 3B+ Platform)',
            firmwareVersion: data['version'] as String? ?? 'v1.0.0-phase51',
            uptime: data['uptime'] as String? ?? 'Active',
            latencyMs: (data['latencyMs'] as num?)?.toInt() ?? 3,
            connectedDevices: devices,
            standardRoutinesCount: (data['standardRoutinesCount'] as num?)?.toInt() ?? 0,
            criticalRoutinesCount: (data['criticalRoutinesCount'] as num?)?.toInt() ?? 0,
            sdCardOverlayFsActive: data['overlayFs'] as bool? ?? true,
            localNtpSynced: data['ntpSynced'] as bool? ?? true,
          );
        }
      } catch (_) {}
    }

    isHubActive = false;
    return const HubState(status: HubConnectionStatus.notConfigured);
  }

  @override
  Future<bool> linkHub({required String hubHostname, required String homeId}) async {
    for (final host in [hubHostname, 'eh-hub.local', '192.168.0.174']) {
      try {
        final uri = Uri.parse('http://$host:4210/api/v1/hub/link');
        final res = await _client.post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'homeId': homeId, 'token': 'eh_claim_token_phase51'}),
        ).timeout(const Duration(seconds: 3));
        if (res.statusCode == 200) {
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
    for (final host in [hubHostname, 'eh-hub.local', '192.168.0.174']) {
      try {
        final uri = Uri.parse('http://$host:4210/api/v1/hub/unlink');
        final res = await _client.post(uri).timeout(const Duration(seconds: 2));
        if (res.statusCode == 200) {
          isLinked = false;
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
    for (final host in [hubHostname, 'eh-hub.local', '192.168.0.174']) {
      try {
        final uri = Uri.parse('http://$host:4210/api/v1/hub/adopt');
        final payload = <String, dynamic>{
          'switchIds': switchIds,
          'devices': ?devices,
        };
        final res = await _client.post(
          uri,
          headers: {'Content-Type': 'application/json'},
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
  Future<bool> sendDeviceControl({
    required String hubHostname,
    required String deviceId,
    required int channel,
    required bool power,
    bool isToggle = false,
  }) async {
    for (final host in [hubHostname, 'eh-hub.local', '192.168.0.174']) {
      try {
        final uri = Uri.parse('http://$host:4210/api/v1/control');
        final payload = {
          'deviceId': deviceId,
          'channel': channel,
          'channelIndex': channel,
          'power': power,
          'value': power,
          'state': power,
          if (isToggle) 'toggle': true,
        };
        final res = await _client.post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(payload),
        ).timeout(const Duration(seconds: 1));
        if (res.statusCode == 200) return true;
      } catch (_) {}
    }
    return false;
  }

  @override
  Future<List<Map<String, dynamic>>> getRoutines({required String hubHostname}) async {
    for (final host in [hubHostname, 'eh-hub.local', '192.168.0.174']) {
      try {
        final uri = Uri.parse('http://$host:4210/api/v1/routines');
        final res = await _client.get(uri).timeout(const Duration(seconds: 2));
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
  Future<bool> triggerRoutine({required String hubHostname, required String routineId}) async {
    for (final host in [hubHostname, 'eh-hub.local', '192.168.0.174']) {
      try {
        final uri = Uri.parse('http://$host:4210/api/v1/routines/trigger');
        final res = await _client.post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'id': routineId}),
        ).timeout(const Duration(seconds: 2));
        if (res.statusCode == 200) return true;
      } catch (_) {}
    }
    return false;
  }

  @override
  Future<bool> syncTimeBroadcast({required String hubHostname}) async {
    for (final host in [hubHostname, 'eh-hub.local', '192.168.0.174']) {
      try {
        final uri = Uri.parse('http://$host:4210/api/v1/hub/time/sync');
        final res = await _client.post(uri).timeout(const Duration(seconds: 2));
        if (res.statusCode == 200) return true;
      } catch (_) {}
    }
    return false;
  }

  @override
  Future<bool> syncAutomations({required String hubHostname}) async {
    for (final host in [hubHostname, 'eh-hub.local', '192.168.0.174']) {
      try {
        final uri = Uri.parse('http://$host:4210/api/v1/routines');
        final res = await _client.get(uri).timeout(const Duration(seconds: 2));
        if (res.statusCode == 200) return true;
      } catch (_) {}
    }
    return true;
  }

  @override
  Future<bool> restartHubCore({required String hubHostname}) async {
    await Future.delayed(const Duration(milliseconds: 600));
    return true;
  }
}
