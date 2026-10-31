import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'device_storage_service.dart';

class LanDeviceState {
  final String deviceId;
  final String? model;
  final int? channelCount;
  final bool? hasEnergyMetering;
  final Map<int, bool> channels;

  const LanDeviceState({
    required this.deviceId,
    this.model,
    this.channelCount,
    this.hasEnergyMetering,
    required this.channels,
  });
}

/// Production Local LAN Device Service
///
/// Provides direct HTTP REST communication with ESP32 devices on the local
/// home Wi-Fi network when the cloud backend / internet is unreachable.
class LocalLanDeviceService {
  LocalLanDeviceService._() {
    _deviceIpMap.addAll(DeviceStorageService.getAllCachedDeviceIps());
    startUdpListener();
  }
  static final LocalLanDeviceService instance = LocalLanDeviceService._();

  final http.Client _client = http.Client();
  final Map<String, String> _deviceIpMap = {};
  final Map<String, int> _deviceIpFailureCount = {};
  final Map<String, DateTime> _verifiedLiveAt = {};
  bool _isDiscovering = false;

  /// Check whether a device has been verified live on LAN within the last 45 seconds
  bool isDeviceReachableOnLan(String deviceId) {
    if (deviceId.isEmpty) return false;
    final now = DateTime.now();
    final cleanId = deviceId.trim().toLowerCase();
    for (final entry in _verifiedLiveAt.entries) {
      final key = entry.key.trim().toLowerCase();
      if (key == cleanId) {
        if (now.difference(entry.value).inSeconds <= 45) {
          return true;
        }
      }
    }
    return false;
  }


  void markDeviceReachableOnLan(String deviceId, {String? ip}) {
    final now = DateTime.now();
    _verifiedLiveAt[deviceId] = now;
    _verifiedLiveAt[deviceId.toLowerCase()] = now;
    if (ip != null && ip.trim().isNotEmpty) {
      registerDeviceIp(deviceId, ip.trim());
    }
  }

  void markDeviceOfflineOnLan(String deviceId) {
    _verifiedLiveAt.remove(deviceId);
    _verifiedLiveAt.remove(deviceId.toLowerCase());
  }

  final _stateBroadcastController =
      StreamController<LanDeviceState>.broadcast();
  Stream<LanDeviceState> get onStateBroadcast =>
      _stateBroadcastController.stream;
  RawDatagramSocket? _listenerSocket;

  bool get isDiscovering => _isDiscovering;
  int get discoveredDeviceCount => _deviceIpMap.length;

  Future<void> startUdpListener() async {
    if (_listenerSocket != null) return;
    try {
      try {
        _listenerSocket = await RawDatagramSocket.bind(
          InternetAddress.anyIPv4,
          4210,
          reuseAddress: true,
          reusePort: false,
        );
      } catch (_) {
        _listenerSocket = await RawDatagramSocket.bind(
          InternetAddress.anyIPv4,
          4210,
        );
      }
      _listenerSocket?.broadcastEnabled = true;
      _listenerSocket?.listen((event) {
        if (event == RawSocketEvent.read) {
          final datagram = _listenerSocket?.receive();
          if (datagram != null) {
            try {
              final text = utf8.decode(datagram.data);
              final map = json.decode(text);
              if (map is Map) {
                final devId = map['deviceId']?.toString();
                final devIp = datagram.address.address;
                final model = map['model']?.toString();
                final channelCount = (map['channelCount'] as num?)?.toInt();
                final hasEnergy = map['hasEnergyMetering'] as bool?;
                if (devId != null && devId.isNotEmpty) {
                  registerDeviceIp(devId, devIp);
                  markDeviceReachableOnLan(devId);
                }
                if ((map['cmd'] == 'EH_STATE_CHANGED' || map['cmd'] == 'EH_BOOT_ANNOUNCE') && devId != null && map['channels'] is List) {
                  markDeviceReachableOnLan(devId);
                  final channels = map['channels'] as List;
                  final chMap = <int, bool>{};
                  for (final ch in channels) {
                    if (ch is Map) {
                      final idx = ch['channelIndex'] as int? ?? 1;
                      final pwr = ch['power'] as bool? ?? false;
                      chMap[idx] = pwr;
                    }
                  }
                  if (chMap.isNotEmpty) {
                    _stateBroadcastController.add(LanDeviceState(
                      deviceId: devId,
                      model: model,
                      channelCount: channelCount ?? chMap.length,
                      hasEnergyMetering: hasEnergy,
                      channels: chMap,
                    ));
                    debugPrint('[LAN-UDP] Real-time state announcement received for $devId: $chMap (model=$model, channels=$channelCount)');
                  }
                } else if (map['cmd'] == 'EH_DISCOVER_RESP' && devId != null) {
                  registerDeviceIp(devId, devIp);
                  markDeviceReachableOnLan(devId, ip: devIp);
                  _stateBroadcastController.add(LanDeviceState(
                    deviceId: devId,
                    model: model,
                    channelCount: channelCount,
                    hasEnergyMetering: hasEnergy,
                    channels: const {},
                  ));
                }
              }
            } catch (_) {}
          }
        }
      });
      debugPrint('[LAN-UDP] Real-time UDP state listener active on port 4210');
    } catch (e) {
      debugPrint('[LAN-UDP] Could not bind listener socket: $e');
    }
  }

  Future<void> restartUdpListener() async {
    try {
      _listenerSocket?.close();
    } catch (_) {}
    _listenerSocket = null;
    await startUdpListener();
  }

  void registerDeviceIp(String deviceId, String ip) {
    if (ip.trim().isNotEmpty) {
      _deviceIpMap[deviceId] = ip.trim();
      DeviceStorageService.saveDeviceIp(deviceId, ip.trim());
      debugPrint('[LAN] Registered Device $deviceId at IP: $ip');
    }
  }

  void unregisterDeviceIp(String deviceId) {
    final cleanId = deviceId.trim().toLowerCase();
    _deviceIpMap.remove(deviceId);
    _deviceIpMap.removeWhere((k, _) => k.trim().toLowerCase() == cleanId);
    _deviceIpFailureCount.remove(deviceId);
    markDeviceOfflineOnLan(deviceId);
    DeviceStorageService.removeDeviceIp(deviceId);
    debugPrint('[LAN] Unregistered Device IP for $deviceId');
  }

  String? getDeviceIp(String deviceId) {
    final cleanId = deviceId.trim().toLowerCase();
    if (cleanId.isEmpty) return null;

    if (_deviceIpMap.containsKey(deviceId)) {
      return _deviceIpMap[deviceId];
    }
    for (final entry in _deviceIpMap.entries) {
      if (entry.key.trim().toLowerCase() == cleanId) {
        return entry.value;
      }
    }
    final saved = DeviceStorageService.getDeviceIp(deviceId);
    if (saved != null && saved.isNotEmpty) {
      _deviceIpMap[deviceId] = saved;
      return saved;
    }
    final allCached = DeviceStorageService.getAllCachedDeviceIps();
    if (allCached.containsKey(deviceId)) {
      final ip = allCached[deviceId]!;
      _deviceIpMap[deviceId] = ip;
      return ip;
    }
    for (final entry in allCached.entries) {
      if (entry.key.trim().toLowerCase() == cleanId) {
        _deviceIpMap[deviceId] = entry.value;
        return entry.value;
      }
    }
    return null;
  }

  static bool _is172Private(String ip) {
    final parts = ip.split('.');
    if (parts.length >= 2) {
      final sec = int.tryParse(parts[1]) ?? 0;
      return sec >= 16 && sec <= 31;
    }
    return false;
  }

  /// Auto-discover all EH devices on the local Wi-Fi network.
  /// Uses a multi-tier strategy:
  /// 0. Fast-Path: Ping previously known / cached IPs (with fast TCP pre-check)
  /// 1. UDP Discovery on Port 4210 (broadcast & directed, safe on Android)
  /// 2. Ultra-Fast Parallel TCP Port 80 Sweep (prioritizing phone's DHCP neighborhood)
  Future<Map<String, String>> autoDiscoverDevices({
    Duration timeout = const Duration(seconds: 4),
    String? targetDeviceId,
    int? expectedCount,
    List<String>? expectedDeviceIds,
  }) async {
    if (_isDiscovering) return Map.unmodifiable(_deviceIpMap);
    _isDiscovering = true;
    final discovered = <String, String>{};

    try {
      debugPrint('[LAN] Starting automated device discovery on local Wi-Fi...');

      // Fast-Path 0: Check all previously known / cached IPs
      final cachedIps = DeviceStorageService.getAllCachedDeviceIps();
      for (final entry in cachedIps.entries) {
        final devId = entry.key;
        final ip = entry.value;
        if (ip.isNotEmpty) {
          try {
            // Fast TCP socket pre-check (200ms) to avoid HTTP client stall if IP changed
            final s = await Socket.connect(ip, 80, timeout: const Duration(milliseconds: 600));
            s.destroy();
            final uri = Uri.parse('http://$ip/api/v1/ping');
            final resp = await _client.get(uri).timeout(const Duration(milliseconds: 1200));
            if (resp.statusCode == 200) {
              final body = json.decode(resp.body);
              final resolvedId = (body is Map && body['deviceId'] != null)
                  ? body['deviceId'].toString()
                  : devId;
              discovered[resolvedId] = ip;
              registerDeviceIp(resolvedId, ip);
              markDeviceReachableOnLan(resolvedId, ip: ip);
              if (devId != resolvedId) {
                _deviceIpMap.remove(devId);
              }
              debugPrint('[LAN] Fast-path ping confirmed cached device: $resolvedId at $ip');
            }
          } catch (_) {
            debugPrint('[LAN] Fast-path ping missed cached IP $ip for $devId. Retaining IP for full scan verification.');
          }
        }
      }

      // Collect all local IPv4 subnets across all network interfaces (excluding cellular / VPN)
      final subnets = <String>{};
      final phoneHostNumbers = <String, int>{};
      try {
        final interfaces = await NetworkInterface.list(
          type: InternetAddressType.IPv4,
          includeLoopback: false,
        );
        for (final iface in interfaces) {
          final ifName = iface.name.toLowerCase();
          // Skip cellular (ccmni, rmnet, pdp), vpn (tun, ppp), or virtual interfaces
          if (ifName.startsWith('rmnet') ||
              ifName.startsWith('ccmni') ||
              ifName.startsWith('pdp') ||
              ifName.startsWith('tun') ||
              ifName.startsWith('ppp') ||
              ifName.startsWith('dummy')) {
            continue;
          }
          for (final addr in iface.addresses) {
            final ip = addr.address;
            // Only keep RFC1918 private subnets: 192.168.x.x, 10.x.x.x, 172.16-31.x.x
            if (ip.startsWith('192.168.') ||
                ip.startsWith('10.') ||
                (ip.startsWith('172.') && _is172Private(ip))) {
              final parts = ip.split('.');
              if (parts.length == 4) {
                final prefix = '${parts[0]}.${parts[1]}.${parts[2]}';
                subnets.add(prefix);
                final hostNum = int.tryParse(parts[3]) ?? 100;
                phoneHostNumbers[prefix] = hostNum;
                debugPrint('[LAN] Discovered Wi-Fi Interface [${iface.name}] IP: $ip (Subnet: $prefix.0/24, Phone Host: $hostNum)');
              }
            }
          }
        }
      } catch (e) {
        debugPrint('[LAN] Error querying network interfaces: $e');
      }

      // Always include 192.168.0 (active subnet) and common subnets as fallbacks
      subnets.add('192.168.0');
      subnets.add('192.168.55');
      if (subnets.isEmpty) {
        subnets.addAll(['192.168.1', '192.168.0', '192.168.4']);
      }

      // Strategy 1: UDP Broadcast / Directed Discovery on Port 4210
      final cachedCount = cachedIps.length;
      final targetTotal = expectedCount ??
          (expectedDeviceIds != null && expectedDeviceIds.isNotEmpty
              ? expectedDeviceIds.length
              : (cachedCount > 1 ? cachedCount : 2));

      if (discovered.length < targetTotal) {
        RawDatagramSocket? socket;
        try {
          socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
          socket.broadcastEnabled = true;

          final completer = Completer<void>();
          socket.listen((event) {
            if (event == RawSocketEvent.read) {
              final datagram = socket?.receive();
              if (datagram != null) {
                try {
                  final message = utf8.decode(datagram.data);
                  final jsonMap = json.decode(message);
                  if (jsonMap is Map) {
                    final devId = jsonMap['deviceId']?.toString() ?? 'unknown';
                    final devIp = datagram.address.address;
                    discovered[devId] = devIp;
                    registerDeviceIp(devId, devIp);
                    markDeviceReachableOnLan(devId, ip: devIp);
                    debugPrint('[LAN] UDP Discovered Device: $devId at $devIp');
                  }
                } catch (_) {}
              }
            }
          });

          final nowSec = DateTime.now().millisecondsSinceEpoch ~/ 1000;
          final broadcastMsg = utf8.encode(json.encode({
            'cmd': 'EH_DISCOVER',
            'unix_time': nowSec,
            'epoch': nowSec,
          }));
          
          // Safe send to 255.255.255.255 (wrapped so Android errno 1 doesn't abort discovery)
          try {
            socket.send(broadcastMsg, InternetAddress('255.255.255.255'), 4210);
          } catch (e) {
            debugPrint('[LAN] Global UDP broadcast skipped: $e');
          }

          // Subnet-directed broadcasts
          for (final subnet in subnets) {
            try {
              socket.send(broadcastMsg, InternetAddress('$subnet.255'), 4210);
            } catch (_) {}
          }

          final waitMs = (expectedCount != null && expectedCount > 1) || (expectedDeviceIds != null && expectedDeviceIds.length > 1) ? 850 : 500;
          Timer(Duration(milliseconds: waitMs), () {
            if (!completer.isCompleted) completer.complete();
          });
          await completer.future;
        } catch (e) {
          debugPrint('[LAN] UDP discovery warning: $e');
        } finally {
          socket?.close();
        }
      }

      // Strategy 2: Ultra-Fast Parallel TCP Port 80 Sweep (Prioritizing phone's DHCP neighborhood)
      final bool needsSweep = discovered.isEmpty ||
          (expectedCount != null && discovered.length < expectedCount) ||
          (targetDeviceId != null && !discovered.containsKey(targetDeviceId)) ||
          (expectedDeviceIds != null &&
              expectedDeviceIds.any((id) => !discovered.containsKey(id) && getDeviceIp(id) == null));

      if (needsSweep) {
        for (final subnet in subnets) {
          debugPrint('[LAN] Running high-speed TCP subnet sweep on $subnet.1-254...');

          final phoneHost = phoneHostNumbers[subnet] ?? 100;
          final orderedIps = <int>[];
          final seen = <int>{};

          // Phase A: Neighborhood around phone IP (±15) - covers DHCP cluster in <50ms!
          for (int offset = 1; offset <= 15; offset++) {
            final up = phoneHost + offset;
            final down = phoneHost - offset;
            if (up >= 2 && up <= 254 && seen.add(up)) orderedIps.add(up);
            if (down >= 2 && down <= 254 && seen.add(down)) orderedIps.add(down);
          }

          // Phase B: Standard smart device DHCP ranges (.100-.250)
          for (int i = 100; i <= 250; i++) {
            if (seen.add(i)) orderedIps.add(i);
          }

          // Phase C: Lower subnet range (.2-.99)
          for (int i = 2; i < 100; i++) {
            if (seen.add(i)) orderedIps.add(i);
          }

          // Phase D: Upper range (.251-.254)
          for (int i = 251; i <= 254; i++) {
            if (seen.add(i)) orderedIps.add(i);
          }

          const batchSize = 20;
          for (int c = 0; c < orderedIps.length; c += batchSize) {
            final batch = orderedIps.sublist(
              c,
              (c + batchSize > orderedIps.length) ? orderedIps.length : c + batchSize,
            );

            // Parallel raw TCP connect test on port 80 (220ms timeout)
            final batchResults = await Future.wait(batch.map((host) async {
              final targetIp = '$subnet.$host';
              try {
                final s = await Socket.connect(targetIp, 80, timeout: const Duration(milliseconds: 220));
                s.destroy();
                return targetIp;
              } catch (_) {
                return null;
              }
            }));

            final aliveIps = batchResults.whereType<String>().toList();
            for (final targetIp in aliveIps) {
              try {
                final uri = Uri.parse('http://$targetIp/api/v1/ping');
                final resp = await _client.get(uri).timeout(const Duration(milliseconds: 900));
                if (resp.statusCode == 200) {
                  final body = json.decode(resp.body);
                  if (body is Map && (body['status'] == 'ok' || body['deviceId'] != null)) {
                    final devId = body['deviceId']?.toString() ?? 'esp32_device';
                    discovered[devId] = targetIp;
                    registerDeviceIp(devId, targetIp);
                    markDeviceReachableOnLan(devId, ip: targetIp);
                    debugPrint('[LAN] Subnet Sweep Discovered Device: $devId at $targetIp');
                  }
                }
              } catch (_) {}
            }

            if (targetDeviceId != null && discovered.containsKey(targetDeviceId)) break;
            if (expectedCount != null && discovered.length >= expectedCount) break;
          }

          if (targetDeviceId != null && discovered.containsKey(targetDeviceId)) break;
          if (expectedCount != null && discovered.length >= expectedCount) break;
        }
      }

      debugPrint('[LAN] Auto-Discovery complete. Total devices found on LAN: ${discovered.length}');
    } finally {
      _isDiscovering = false;
    }

    return Map.unmodifiable(discovered);
  }

  /// Sends a direct Local LAN control packet to the ESP32 embedded web server
  Future<bool> sendLocalControl({
    required String deviceId,
    required int channelIndex,
    required bool power,
    bool isToggle = false,
    String? explicitIp,
  }) async {
    String? ip = explicitIp ?? getDeviceIp(deviceId);
    if (ip == null || ip.isEmpty) {
      debugPrint('[LAN] No local IP known for device $deviceId. Fast-checking UDP broadcast...');
      // Run auto-discovery in background without blocking this actuation turn
      unawaited(autoDiscoverDevices());
      return false;
    }

    final targetUri = Uri.parse('http://$ip/api/v1/control');
    final payloadMap = <String, dynamic>{
      'channel': channelIndex,
      'channelIndex': channelIndex,
      'power': power,
      'value': power,
      'enabled': power,
    };
    if (isToggle) {
      payloadMap['toggle'] = true;
      payloadMap['action'] = 'toggle';
    }
    final payload = json.encode(payloadMap);

    try {
      debugPrint('[LAN] Sending direct local command to $targetUri: $payload');
      final nowSec = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final response = await _client
          .post(
            targetUri,
            headers: {
              'Content-Type': 'application/json',
              'Connection': 'close',
              'X-Client-Epoch-Sec': nowSec.toString(),
            },
            body: payload,
          )
          .timeout(const Duration(milliseconds: 2500));

      if (response.statusCode == 200) {
        try {
          final body = json.decode(response.body);
          if (body is Map) {
            final returnedDevId = body['deviceId']?.toString();
            if (returnedDevId != null && returnedDevId.isNotEmpty && returnedDevId != deviceId) {
              debugPrint('[LAN] Response deviceId ($returnedDevId) mismatch requested ($deviceId). Rejecting cross-talk.');
              registerDeviceIp(returnedDevId, ip);
              markDeviceReachableOnLan(returnedDevId);
              if (_deviceIpMap[deviceId] == ip) {
                _deviceIpMap.remove(deviceId);
                DeviceStorageService.removeDeviceIp(deviceId);
              }
              return false;
            }
            if (body['success'] == true || body['status'] == 'ok' || body['power'] != null) {
              markDeviceReachableOnLan(deviceId);
              registerDeviceIp(deviceId, ip);
              debugPrint('[LAN] Direct local command SUCCESS for device $deviceId ch$channelIndex');
              return true;
            }
          }
        } catch (_) {
          // If response body is not JSON but returned HTTP 200 OK
          markDeviceReachableOnLan(deviceId);
          registerDeviceIp(deviceId, ip);
          return true;
        }
        markDeviceReachableOnLan(deviceId);
        registerDeviceIp(deviceId, ip);
        return true;
      }
      debugPrint('[LAN] Direct local command failed with status ${response.statusCode} for $targetUri');
      markDeviceOfflineOnLan(deviceId);
      debugPrint('[LAN] Direct local command returned HTTP ${response.statusCode}');
      markDeviceOfflineOnLan(deviceId);
    } catch (e) {
      debugPrint('[LAN] Direct local command error for $targetUri: $e');
      markDeviceOfflineOnLan(deviceId);
      if (ip.isNotEmpty) {
        debugPrint('[LAN] Purging stale IP $ip for device $deviceId due to error: $e');
        _deviceIpMap.remove(deviceId);
        DeviceStorageService.removeDeviceIp(deviceId);
      }
      // If error occurs, schedule quiet rediscovery in background so next command gets fresh IP
      unawaited(autoDiscoverDevices());
    }
    return false;
  }

  /// Queries the live hardware state and model information directly from the ESP32 embedded web server
  Future<LanDeviceState?> fetchLocalDeviceState({
    required String deviceId,
    String? explicitIp,
  }) async {
    String? ip = explicitIp ?? getDeviceIp(deviceId);
    if (ip == null || ip.isEmpty) {
      return null;
    }

    final targetUri = Uri.parse('http://$ip/api/v1/state');
    try {
      final response = await _client
          .get(
            targetUri,
            headers: {'Connection': 'close'},
          )
          .timeout(const Duration(milliseconds: 2000));

      if (response.statusCode == 200) {
        final body = json.decode(response.body);
        if (body is Map) {
          final resolvedId = body['deviceId']?.toString() ?? deviceId;
          final model = body['model']?.toString();
          final channelCount = (body['channelCount'] as num?)?.toInt();
          final hasEnergy = body['hasEnergyMetering'] as bool?;
          final result = <int, bool>{};

          if (body['channels'] is List) {
            final channels = body['channels'] as List;
            for (final ch in channels) {
              if (ch is Map) {
                final idx = ch['channelIndex'] as int? ?? 1;
                final pwr = ch['power'] as bool? ?? false;
                result[idx] = pwr;
              }
            }
          }

          if (resolvedId != deviceId) {
            debugPrint('[LAN] fetchLocalDeviceState: device at $ip is $resolvedId, but requested $deviceId. Purging mismatched mapping for $deviceId.');
            registerDeviceIp(resolvedId, ip);
            markDeviceReachableOnLan(resolvedId);
            if (_deviceIpMap[deviceId] == ip) {
              _deviceIpMap.remove(deviceId);
              DeviceStorageService.removeDeviceIp(deviceId);
            }
            markDeviceOfflineOnLan(deviceId);
            return null;
          }

          registerDeviceIp(deviceId, ip);
          _deviceIpFailureCount[deviceId] = 0;
          markDeviceReachableOnLan(deviceId);

          return LanDeviceState(
            deviceId: resolvedId,
            model: model,
            channelCount: channelCount ?? (result.isNotEmpty ? result.length : 4),
            hasEnergyMetering: hasEnergy,
            channels: result,
          );
        }
      }
      markDeviceOfflineOnLan(deviceId);
    } catch (e) {
      debugPrint('[LAN] fetchLocalDeviceState error on $targetUri: $e');
      markDeviceOfflineOnLan(deviceId);
      final failures = (_deviceIpFailureCount[deviceId] ?? 0) + 1;
      _deviceIpFailureCount[deviceId] = failures;
      if (failures >= 5 && ip.isNotEmpty) {
        debugPrint('[LAN] 5 consecutive failures for $deviceId. Purging stale IP $ip and rediscovering.');
        _deviceIpMap.remove(deviceId);
        DeviceStorageService.removeDeviceIp(deviceId);
        unawaited(autoDiscoverDevices());
      }
    }
    return null;
  }

  /// Queries the live relay state directly from the ESP32 embedded web server
  Future<Map<int, bool>?> fetchLocalState({
    required String deviceId,
    String? explicitIp,
  }) async {
    final devState = await fetchLocalDeviceState(
      deviceId: deviceId,
      explicitIp: explicitIp,
    );
    return devState?.channels;
  }

  /// Ping device to verify if reachable on local network
  Future<bool> pingDevice({required String deviceId, String? explicitIp}) async {
    final ip = explicitIp ?? getDeviceIp(deviceId);
    if (ip == null || ip.isEmpty) return false;

    final targetUri = Uri.parse('http://$ip/api/v1/ping');
    try {
      final response = await _client
          .get(targetUri)
          .timeout(const Duration(milliseconds: 1200));
      if (response.statusCode == 200) {
        markDeviceReachableOnLan(deviceId);
        return true;
      }
      markDeviceOfflineOnLan(deviceId);
      return false;
    } catch (_) {
      markDeviceOfflineOnLan(deviceId);
      if (ip.isNotEmpty) {
        _deviceIpMap.remove(deviceId);
        DeviceStorageService.removeDeviceIp(deviceId);
      }
      return false;
    }
  }

  /// Sends a factory reset command to the ESP32 to wipe Wi-Fi credentials
  /// and put it into BLE provisioning mode (same as holding BOOT button).
  Future<bool> sendFactoryReset({required String deviceId, String? explicitIp}) async {
    final ip = explicitIp ?? getDeviceIp(deviceId);
    if (ip == null || ip.isEmpty) return false;

    final targetUri = Uri.parse('http://$ip/api/v1/reset');
    try {
      final response = await _client
          .post(targetUri)
          .timeout(const Duration(milliseconds: 2500));
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('[LAN] sendFactoryReset error: $e');
      return false;
    }
  }

  /// Push an edge routine directly to the ESP32 on-chip routine engine over local LAN
  Future<bool> sendLocalRoutineUpsert({
    required String deviceId,
    required Map<String, dynamic> routinePayload,
    String? explicitIp,
  }) async {
    final ip = explicitIp ?? getDeviceIp(deviceId);
    if (ip == null || ip.isEmpty) return false;

    final targetUri = Uri.parse('http://$ip/api/v1/routines');
    try {
      final nowSec = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final response = await _client
          .post(
            targetUri,
            headers: {
              'Content-Type': 'application/json',
              'Connection': 'close',
              'X-Client-Epoch-Sec': nowSec.toString(),
            },
            body: json.encode(routinePayload),
          )
          .timeout(const Duration(milliseconds: 2500));
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('[LAN] sendLocalRoutineUpsert error: $e');
      return false;
    }
  }

  /// Delete an edge routine from the ESP32 on-chip routine engine over local LAN
  Future<bool> sendLocalRoutineDelete({
    required String deviceId,
    required String routineId,
    String? explicitIp,
  }) async {
    final ip = explicitIp ?? getDeviceIp(deviceId);
    if (ip == null || ip.isEmpty) return false;

    final targetUri = Uri.parse('http://$ip/api/v1/routines?id=$routineId');
    try {
      final nowSec = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final response = await _client
          .delete(
            targetUri,
            headers: {
              'Connection': 'close',
              'X-Client-Epoch-Sec': nowSec.toString(),
            },
          )
          .timeout(const Duration(milliseconds: 2500));
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('[LAN] sendLocalRoutineDelete error: $e');
      return false;
    }
  }

  /// Emergency Stop: immediately cancels active pulse/timer routines and shuts down all relays
  Future<bool> sendLocalEmergencyStop({
    required String deviceId,
    String? explicitIp,
  }) async {
    final ip = explicitIp ?? getDeviceIp(deviceId);
    if (ip == null || ip.isEmpty) return false;

    bool allSuccess = true;
    // 1. Cancel all active timer routines on ESP32
    try {
      final cancelUri = Uri.parse('http://$ip/api/v1/routines/cancel');
      await _client
          .post(cancelUri, headers: {'Connection': 'close'})
          .timeout(const Duration(milliseconds: 1500));
    } catch (_) {}

    // 2. Turn off all relays via control endpoint
    try {
      final controlUri = Uri.parse('http://$ip/api/v1/control');
      final resp = await _client
          .post(
            controlUri,
            headers: {
              'Content-Type': 'application/json',
              'Connection': 'close',
            },
            body: json.encode({'channel': 0, 'power': false}),
          )
          .timeout(const Duration(milliseconds: 2000));
      if (resp.statusCode != 200) allSuccess = false;
    } catch (_) {
      allSuccess = false;
    }

    return allSuccess;
  }

  /// Queries all edge routines stored directly on the physical ESP32 board
  Future<List<Map<String, dynamic>>?> fetchLocalRoutines({
    required String deviceId,
    String? explicitIp,
  }) async {
    final ip = explicitIp ?? getDeviceIp(deviceId);
    if (ip == null || ip.isEmpty) return null;

    final targetUri = Uri.parse('http://$ip/api/v1/routines');
    try {
      final response = await _client
          .get(targetUri, headers: {'Connection': 'close'})
          .timeout(const Duration(milliseconds: 2500));
      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        if (decoded is List) {
          final list = <Map<String, dynamic>>[];
          for (final item in decoded) {
            if (item is Map) {
              list.add(Map<String, dynamic>.from(item));
            }
          }
          return list;
        }
      }
    } catch (e) {
      debugPrint('[LAN] fetchLocalRoutines error on $targetUri: $e');
    }
    return null;
  }
}

