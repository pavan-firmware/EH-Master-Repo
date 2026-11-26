import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'device_storage_service.dart';
import '../../features/hub/data/hub_repository.dart';
import '../../features/hub/domain/models/hub_models.dart';

class LanDeviceState {
  final String deviceId;
  final String? model;
  final int? channelCount;
  final bool? hasEnergyMetering;
  final Map<int, bool> channels;
  final String? firmwareVersion;
  final List<Map<String, dynamic>>? activeRoutines;
  final int? rssiDbm;

  const LanDeviceState({
    required this.deviceId,
    this.model,
    this.channelCount,
    this.hasEnergyMetering,
    required this.channels,
    this.firmwareVersion,
    this.activeRoutines,
    this.rssiDbm,
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
  final Map<String, int> _deviceRssiMap = {};

  int? getDeviceRssi(String deviceId) {
    final direct = _deviceRssiMap[deviceId];
    if (direct != null) return direct;
    return _deviceRssiMap[deviceId.trim().toLowerCase()];
  }

  void setDeviceRssi(String deviceId, int? rssi) {
    if (rssi == null || rssi >= 0 || rssi <= -115) return;
    _deviceRssiMap[deviceId] = rssi;
    _deviceRssiMap[deviceId.trim().toLowerCase()] = rssi;
  }
  bool _isDiscovering = false;
  String? _cachedHubHost;
  DateTime? _lastHubSeenAt;

  String? get cachedHubHost => _cachedHubHost;
  set cachedHubHost(String? host) {
    _cachedHubHost = host;
    if (host != null) {
      _lastHubSeenAt = DateTime.now();
    } else {
      _lastHubSeenAt = null;
    }
  }
  DateTime? get lastHubSeenAt => _lastHubSeenAt;

  static bool _isValidSwitchDeviceId(String? id) {
    if (id == null) return false;
    final clean = id.trim().toLowerCase();
    return clean.isNotEmpty && clean != 'unknown' && clean != 'null';
  }

  /// Check whether a device has been verified live on LAN within the last 90 seconds
  bool isDeviceReachableOnLan(String deviceId) {
    if (!_isValidSwitchDeviceId(deviceId)) return false;
    final now = DateTime.now();
    final cleanId = deviceId.trim().toLowerCase();
    for (final entry in _verifiedLiveAt.entries) {
      final key = entry.key.trim().toLowerCase();
      if (key == cleanId) {
        if (now.difference(entry.value).inSeconds <= 90) {
          return true;
        }
      }
    }
    return false;
  }

  /// Check whether any device has been verified live on LAN within the last 90 seconds
  bool isAnyDeviceReachableOnLan() {
    final now = DateTime.now();
    for (final entry in _verifiedLiveAt.entries) {
      if (!_isValidSwitchDeviceId(entry.key)) continue;
      if (now.difference(entry.value).inSeconds <= 90) {
        return true;
      }
    }
    return false;
  }


  void markDeviceReachableOnLan(String deviceId, {String? ip}) {
    if (!_isValidSwitchDeviceId(deviceId)) return;
    final now = DateTime.now();
    _verifiedLiveAt[deviceId] = now;
    _verifiedLiveAt[deviceId.toLowerCase()] = now;
    _deviceIpFailureCount[deviceId] = 0;
    _deviceIpFailureCount[deviceId.toLowerCase()] = 0;
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
                if (map['hubId'] != null) {
                  _cachedHubHost = datagram.address.address;
                  _lastHubSeenAt = DateTime.now();
                }
                final devId = map['deviceId']?.toString();
                final devIp = datagram.address.address;
                final model = map['model']?.toString();
                final channelCount = (map['channelCount'] as num?)?.toInt();
                final hasEnergy = map['hasEnergyMetering'] as bool?;
                final fwVersion = (map['firmwareVersion'] ?? map['firmware'])?.toString();
                final rawRssi = (map['rssi'] as num?)?.toInt() ?? (map['rssiDbm'] as num?)?.toInt();
                if (_isValidSwitchDeviceId(devId)) {
                  registerDeviceIp(devId!, devIp);
                  markDeviceReachableOnLan(devId, ip: devIp);
                  setDeviceRssi(devId, rawRssi);
                }
                if ((map['cmd'] == 'EH_STATE_CHANGED' || map['cmd'] == 'EH_BOOT_ANNOUNCE') && _isValidSwitchDeviceId(devId) && map['channels'] is List) {
                  markDeviceReachableOnLan(devId!);
                  setDeviceRssi(devId, rawRssi);
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
                    List<Map<String, dynamic>>? activeRoutines;
                    if (map['activeRoutines'] is List) {
                      activeRoutines = (map['activeRoutines'] as List)
                          .whereType<Map>()
                          .map((e) => Map<String, dynamic>.from(e))
                          .toList();
                    }
                    _stateBroadcastController.add(LanDeviceState(
                      deviceId: devId,
                      model: model,
                      channelCount: channelCount ?? chMap.length,
                      hasEnergyMetering: hasEnergy,
                      channels: chMap,
                      firmwareVersion: fwVersion,
                      activeRoutines: activeRoutines,
                      rssiDbm: getDeviceRssi(devId),
                    ));
                    debugPrint('[LAN-UDP] Real-time state announcement received for $devId: $chMap (model=$model, channels=$channelCount, fw=$fwVersion, rssi=$rawRssi)');
                  }
                } else if (map['cmd'] == 'EH_DISCOVER_RESP' && devId != null) {
                  registerDeviceIp(devId, devIp);
                  markDeviceReachableOnLan(devId, ip: devIp);
                  setDeviceRssi(devId, rawRssi);
                  _stateBroadcastController.add(LanDeviceState(
                    deviceId: devId,
                    model: model,
                    channelCount: channelCount,
                    hasEnergyMetering: hasEnergy,
                    channels: const {},
                    firmwareVersion: fwVersion,
                    rssiDbm: getDeviceRssi(devId),
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

  /// Actively broadcasts a UDP query for the Smart Home Hub and returns discovered IP
  Future<String?> discoverHubNow({Duration timeout = const Duration(milliseconds: 1500)}) async {
    RawDatagramSocket? socket;
    try {
      socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      socket.broadcastEnabled = true;
      final completer = Completer<String?>();

      socket.listen((event) {
        if (event == RawSocketEvent.read) {
          final datagram = socket?.receive();
          if (datagram != null) {
            try {
              final text = utf8.decode(datagram.data);
              final map = json.decode(text);
              if (map is Map && (map['hubId'] != null || map['type'] == 'hub' || map['cmd'] == 'EH_HUB_ANNOUNCE' || map['cmd'] == 'EH_HUB_DISCOVER_RESP')) {
                final hubIp = datagram.address.address;
                _cachedHubHost = hubIp;
                _lastHubSeenAt = DateTime.now();
                DeviceStorageService.setPersistedHubHost(hubIp);
                if (!completer.isCompleted) completer.complete(hubIp);
              }
            } catch (_) {}
          }
        }
      });

      final nowSec = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final probeMsg = utf8.encode(json.encode({
        'cmd': 'EH_HUB_DISCOVER',
        'type': 'hub',
        'unix_time': nowSec,
      }));
      final legacyProbeMsg = utf8.encode(json.encode({
        'cmd': 'EH_DISCOVER',
        'unix_time': nowSec,
      }));

      try {
        socket.send(probeMsg, InternetAddress('255.255.255.255'), 4210);
        socket.send(legacyProbeMsg, InternetAddress('255.255.255.255'), 4210);
      } catch (_) {}

      // Directed subnet broadcasts
      try {
        final interfaces = await NetworkInterface.list(type: InternetAddressType.IPv4, includeLoopback: false);
        for (final iface in interfaces) {
          for (final addr in iface.addresses) {
            final parts = addr.address.split('.');
            if (parts.length == 4) {
              final bcast = '${parts[0]}.${parts[1]}.${parts[2]}.255';
              try {
                socket.send(probeMsg, InternetAddress(bcast), 4210);
                socket.send(legacyProbeMsg, InternetAddress(bcast), 4210);
              } catch (_) {}
            }
          }
        }
      } catch (_) {
        try {
          socket.send(probeMsg, InternetAddress('192.168.0.255'), 4210);
          socket.send(legacyProbeMsg, InternetAddress('192.168.0.255'), 4210);
        } catch (_) {}
      }

      Timer(timeout, () {
        if (!completer.isCompleted) completer.complete(_cachedHubHost);
      });

      final result = await completer.future;
      return result;
    } catch (e) {
      debugPrint('[LAN] discoverHubNow error: $e');
      return _cachedHubHost;
    } finally {
      socket?.close();
    }
  }

  /// Sends a direct P2P Fast-Path UDP actuation packet (<3ms) to a smart device on port 4210.
  Future<bool> sendFastPathUdpActuate(
    String targetIp,
    int channel,
    bool power, {
    bool isToggle = false,
  }) async {
    RawDatagramSocket? socket;
    try {
      socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      final seq = 'p2p_${DateTime.now().millisecondsSinceEpoch}';
      final payload = utf8.encode(jsonEncode({
        'cmd': 'P2P_ACTUATE',
        'channel': channel,
        'power': power,
        'isToggle': isToggle,
        'seq': seq,
      }));
      final dest = InternetAddress(targetIp);
      socket.send(payload, dest, 4210);
      debugPrint('[LAN-FAST-PATH] Sent P2P UDP actuate to $targetIp:4210 CH$channel (power=$power, toggle=$isToggle)');
      return true;
    } catch (e) {
      debugPrint('[LAN-FAST-PATH] UDP actuate failed: $e');
      return false;
    } finally {
      socket?.close();
    }
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
  /// 2. Ultra-Fast Parallel TCP Port 80 Sweep (only when [allowSubnetSweep] is true, e.g. explicit user scan)
  Future<Map<String, String>> autoDiscoverDevices({
    Duration timeout = const Duration(seconds: 4),
    String? targetDeviceId,
    int? expectedCount,
    List<String>? expectedDeviceIds,
    bool allowSubnetSweep = false,
  }) async {
    if (_isDiscovering) return Map.unmodifiable(_deviceIpMap);
    _isDiscovering = true;
    final discovered = <String, String>{};

    try {
      debugPrint('[LAN] Starting automated device discovery on local Wi-Fi (sweepEnabled=$allowSubnetSweep)...');

      // Fast-Path 0: Check all previously known / cached IPs
      final cachedIps = DeviceStorageService.getAllCachedDeviceIps();
      for (final entry in cachedIps.entries) {
        final devId = entry.key;
        final ip = entry.value;
        if (ip.isNotEmpty) {
          try {
            // Fast TCP socket pre-check (150ms) to immediately bail if device is powered off
            final s = await Socket.connect(ip, 80, timeout: const Duration(milliseconds: 150));
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
            markDeviceOfflineOnLan(devId);
            debugPrint('[LAN] Fast-path ping missed cached IP $ip for $devId. Marked offline pending UDP response.');
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

      // If no Wi-Fi interface was detected, use 192.168.0 as fallback only
      if (subnets.isEmpty) {
        subnets.add('192.168.0');
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
                    final devId = jsonMap['deviceId']?.toString();
                    final devIp = datagram.address.address;
                    if (_isValidSwitchDeviceId(devId)) {
                      discovered[devId!] = devIp;
                      registerDeviceIp(devId, devIp);
                      markDeviceReachableOnLan(devId, ip: devIp);
                      debugPrint('[LAN] UDP Discovered Device: $devId at $devIp');
                    }
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

      // Strategy 2: Ultra-Fast Parallel TCP Port 80 Sweep (ONLY when allowSubnetSweep is explicitly true)
      final bool needsSweep = allowSubnetSweep && (discovered.isEmpty ||
          (expectedCount != null && discovered.length < expectedCount) ||
          (targetDeviceId != null && !discovered.containsKey(targetDeviceId)) ||
          (expectedDeviceIds != null &&
              expectedDeviceIds.any((id) => !discovered.containsKey(id) && getDeviceIp(id) == null)));

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
  /// Sends direct local actuation via UDP P2P (:4210) and waits up to 650ms for P2P_ACK.
  Future<bool> _sendUdpP2pActuateWithAck({
    required String ip,
    required String deviceId,
    required int channelIndex,
    required bool power,
    bool isToggle = false,
  }) async {
    RawDatagramSocket? sock;
    try {
      sock = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      final seq = 'app_${DateTime.now().microsecondsSinceEpoch}';
      final msg = utf8.encode(json.encode({
        'cmd': 'P2P_ACTUATE',
        'seq': seq,
        'targetDeviceId': deviceId,
        'channel': channelIndex,
        'channelIndex': channelIndex,
        'power': power,
        'state': power,
        'toggle': isToggle,
        'isToggle': isToggle,
      }));
      final completer = Completer<bool>();
      sock.listen((event) {
        if (event == RawSocketEvent.read) {
          final dg = sock?.receive();
          if (dg != null) {
            try {
              final map = json.decode(utf8.decode(dg.data));
              if (map is Map && map['cmd'] == 'P2P_ACK') {
                final ackSeq = map['seq']?.toString() ?? '';
                final ackDev = map['deviceId']?.toString() ?? '';
                if (ackSeq == seq || ackDev.trim().toLowerCase() == deviceId.trim().toLowerCase()) {
                  if (!completer.isCompleted) completer.complete(true);
                }
              }
            } catch (_) {}
          }
        }
      });

      final targetAddr = InternetAddress(ip);
      sock.send(msg, targetAddr, 4210);
      Timer(const Duration(milliseconds: 220), () {
        if (!completer.isCompleted) {
          try {
            sock?.send(msg, targetAddr, 4210);
          } catch (_) {}
        }
      });
      Timer(const Duration(milliseconds: 650), () {
        if (!completer.isCompleted) completer.complete(false);
      });
      final acked = await completer.future;
      if (acked) {
        markDeviceReachableOnLan(deviceId, ip: ip);
        debugPrint('[LAN] UDP P2P_ACK confirmed for device $deviceId ch$channelIndex at $ip');
      }
      return acked;
    } catch (e) {
      debugPrint('[LAN] UDP P2P_ACTUATE error for $ip: $e');
      return false;
    } finally {
      sock?.close();
    }
  }

  Future<bool> sendLocalControl({
    required String deviceId,
    required int channelIndex,
    required bool power,
    bool isToggle = false,
    String? explicitIp,
    bool tryHubProxy = true,
  }) async {
    // Section 4.1 & Rule 4: If Hub is active and not already attempted by caller, forward via Hub first (<5ms)
    final isHubActive = tryHubProxy &&
        LiveHubRepository.isLinked &&
        LiveHubRepository.isHubActive &&
        _cachedHubHost != null &&
        _lastHubSeenAt != null &&
        DateTime.now().difference(_lastHubSeenAt!).inSeconds < 60;

    if (isHubActive) {
      try {
        final s = await Socket.connect(_cachedHubHost!, 4210, timeout: const Duration(milliseconds: 350));
        s.destroy();
        final hubUri = Uri.parse('http://$_cachedHubHost:4210/api/v1/control');
        final hubPayload = json.encode({
          'deviceId': deviceId,
          'channel': channelIndex,
          'channelIndex': channelIndex,
          'power': power,
          'value': power,
          'state': power,
          if (isToggle) 'toggle': true,
          if (isToggle) 'action': 'toggle',
        });
        final hubResponse = await _client
            .post(
              hubUri,
              headers: {
                'Content-Type': 'application/json',
                'Connection': 'close',
              },
              body: hubPayload,
            )
            .timeout(const Duration(milliseconds: 1600));

        if (hubResponse.statusCode == 200) {
          bool actuallyForwarded = true;
          try {
            final parsed = json.decode(hubResponse.body);
            if (parsed is Map && parsed['status'] == 'ok' && parsed['localExecuted'] == true) {
              // Hub didn't have the device's LAN IP yet; still fall through to direct LAN actuation
              actuallyForwarded = false;
            }
          } catch (_) {}
          if (actuallyForwarded) {
            debugPrint('[LAN-HUB] Direct local command executed via Hub Coordinator for $deviceId ch$channelIndex');
            markDeviceReachableOnLan(deviceId);
            return true;
          }
        }
      } catch (e) {
        debugPrint('[LAN-HUB] Hub coordinator proxy failed or timed out: $e. Falling back to direct switch IP');
      }
    }

    String? ip = explicitIp ?? getDeviceIp(deviceId);
    if (ip == null || ip.isEmpty) {
      await autoDiscoverDevices(
        targetDeviceId: deviceId,
        timeout: const Duration(milliseconds: 550),
        allowSubnetSweep: false,
      );
      ip = explicitIp ?? getDeviceIp(deviceId);
      if (ip == null || ip.isEmpty) {
        debugPrint('[LAN] No local IP known for device $deviceId.');
        return false;
      }
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

    final maxHttpAttempts = isToggle ? 1 : 2;
    for (int attempt = 0; attempt < maxHttpAttempts; attempt++) {
      try {
        debugPrint('[LAN] Sending direct local command to $targetUri (attempt ${attempt + 1}): $payload');
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
            .timeout(Duration(milliseconds: attempt == 0 ? 1800 : 1500));

        if (response.statusCode == 200) {
          try {
            final body = json.decode(response.body);
            if (body is Map) {
              final returnedDevId = body['deviceId']?.toString();
              if (returnedDevId != null &&
                  returnedDevId.isNotEmpty &&
                  returnedDevId.trim().toLowerCase() != deviceId.trim().toLowerCase()) {
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
                markDeviceReachableOnLan(deviceId, ip: ip);
                debugPrint('[LAN] Direct local command SUCCESS for device $deviceId ch$channelIndex');
                return true;
              }
            }
          } catch (_) {
            // If response body is not JSON but returned HTTP 200 OK
            markDeviceReachableOnLan(deviceId, ip: ip);
            return true;
          }
          markDeviceReachableOnLan(deviceId, ip: ip);
          return true;
        }
        debugPrint('[LAN] Direct local command failed with status ${response.statusCode} for $targetUri');
      } catch (e) {
        debugPrint('[LAN] Direct local command attempt ${attempt + 1} error for $targetUri: $e');
        if (attempt == 0) {
          await Future.delayed(const Duration(milliseconds: 80));
        }
      }
    }

    // Resilient fallback: bypass busy TCP/80 sockets using direct UDP P2P_ACTUATE + P2P_ACK (<5ms)
    final p2pOk = await _sendUdpP2pActuateWithAck(
      ip: ip,
      deviceId: deviceId,
      channelIndex: channelIndex,
      power: power,
      isToggle: isToggle,
    );
    if (p2pOk) {
      return true;
    }

    final cleanId = deviceId.trim().toLowerCase();
    final failures = (_deviceIpFailureCount[cleanId] ?? 0) + 1;
    _deviceIpFailureCount[cleanId] = failures;
    _deviceIpFailureCount[deviceId] = failures;
    if (failures >= 6 && ip.isNotEmpty) {
      debugPrint('[LAN] 6 consecutive failures for $deviceId. Purging stale IP $ip.');
      _deviceIpMap.remove(deviceId);
      DeviceStorageService.removeDeviceIp(deviceId);
      markDeviceOfflineOnLan(deviceId);
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

    // Fast socket pre-check only when device isn't already known live on LAN (avoids RST churn while active)
    if (!isDeviceReachableOnLan(deviceId)) {
      bool tcpReachable = false;
      try {
        final s = await Socket.connect(ip, 80, timeout: const Duration(milliseconds: 350));
        s.destroy();
        tcpReachable = true;
      } catch (_) {}
      if (!tcpReachable) {
        final cleanId = deviceId.trim().toLowerCase();
        final failures = (_deviceIpFailureCount[cleanId] ?? 0) + 1;
        _deviceIpFailureCount[cleanId] = failures;
        if (failures >= 3) {
          markDeviceOfflineOnLan(deviceId);
        }
        return null;
      }
    }

    final targetUri = Uri.parse('http://$ip/api/v1/state');
    try {
      final response = await _client
          .get(
            targetUri,
            headers: {'Connection': 'close'},
          )
          .timeout(const Duration(milliseconds: 1200));

      if (response.statusCode == 200) {
        final body = json.decode(response.body);
        if (body is Map) {
          final resolvedId = body['deviceId']?.toString() ?? deviceId;
          final model = body['model']?.toString();
          final channelCount = (body['channelCount'] as num?)?.toInt();
          final hasEnergy = body['hasEnergyMetering'] as bool?;
          final rawRssi = (body['rssi'] as num?)?.toInt() ?? (body['rssiDbm'] as num?)?.toInt();
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

          if (resolvedId.trim().toLowerCase() != deviceId.trim().toLowerCase()) {
            debugPrint('[LAN] fetchLocalDeviceState: device at $ip is $resolvedId, but requested $deviceId. Purging mismatched mapping for $deviceId.');
            registerDeviceIp(resolvedId, ip);
            markDeviceReachableOnLan(resolvedId);
            setDeviceRssi(resolvedId, rawRssi);
            if (_deviceIpMap[deviceId] == ip) {
              _deviceIpMap.remove(deviceId);
              DeviceStorageService.removeDeviceIp(deviceId);
            }
            markDeviceOfflineOnLan(deviceId);
            return null;
          }

          registerDeviceIp(deviceId, ip);
          _deviceIpFailureCount[deviceId] = 0;
          _deviceIpFailureCount[deviceId.trim().toLowerCase()] = 0;
          markDeviceReachableOnLan(deviceId);
          setDeviceRssi(deviceId, rawRssi);
          setDeviceRssi(resolvedId, rawRssi);

          final fwVersion = (body['firmwareVersion'] ?? body['firmware'])?.toString();
          List<Map<String, dynamic>>? activeRoutines;
          if (body['activeRoutines'] is List) {
            activeRoutines = (body['activeRoutines'] as List)
                .whereType<Map>()
                .map((e) => Map<String, dynamic>.from(e))
                .toList();
          }

          return LanDeviceState(
            deviceId: resolvedId,
            model: model,
            channelCount: channelCount ?? (result.isNotEmpty ? result.length : 4),
            hasEnergyMetering: hasEnergy,
            channels: result,
            firmwareVersion: fwVersion,
            activeRoutines: activeRoutines,
            rssiDbm: getDeviceRssi(resolvedId) ?? getDeviceRssi(deviceId),
          );
        }
      }
      final cleanId = deviceId.trim().toLowerCase();
      final failures = (_deviceIpFailureCount[cleanId] ?? 0) + 1;
      _deviceIpFailureCount[cleanId] = failures;
      if (failures >= 3) {
        markDeviceOfflineOnLan(deviceId);
      }
    } catch (e) {
      debugPrint('[LAN] fetchLocalDeviceState error on $targetUri: $e');
      final cleanId = deviceId.trim().toLowerCase();
      final failures = (_deviceIpFailureCount[cleanId] ?? 0) + 1;
      _deviceIpFailureCount[cleanId] = failures;
      _deviceIpFailureCount[deviceId] = failures;
      if (failures >= 3) {
        markDeviceOfflineOnLan(deviceId);
      }
      if (failures >= 5 && ip.isNotEmpty) {
        debugPrint('[LAN] 5 consecutive failures for $deviceId at $ip. Marking offline.');
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
        markDeviceReachableOnLan(deviceId, ip: ip);
        return true;
      }
      final cleanId = deviceId.trim().toLowerCase();
      final failures = (_deviceIpFailureCount[cleanId] ?? 0) + 1;
      _deviceIpFailureCount[cleanId] = failures;
      if (failures >= 3) {
        markDeviceOfflineOnLan(deviceId);
      }
      return false;
    } catch (_) {
      final cleanId = deviceId.trim().toLowerCase();
      final failures = (_deviceIpFailureCount[cleanId] ?? 0) + 1;
      _deviceIpFailureCount[cleanId] = failures;
      if (failures >= 3) {
        markDeviceOfflineOnLan(deviceId);
      }
      if (failures >= 6 && ip.isNotEmpty) {
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

    // 1. First wipe all edge routines on the physical chip
    try {
      await sendClearAllRoutines(deviceId: deviceId, explicitIp: ip);
    } catch (_) {}

    // 2. Send factory reset command to wipe credentials and reboot
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

  /// Wipe all on-chip edge routines on physical hardware
  Future<bool> sendClearAllRoutines({required String deviceId, String? explicitIp}) async {
    final ip = explicitIp ?? getDeviceIp(deviceId);
    if (ip == null || ip.isEmpty) return false;

    try {
      final routines = await fetchLocalRoutines(deviceId: deviceId, explicitIp: ip);
      if (routines != null && routines.isNotEmpty) {
        for (final r in routines) {
          final rId = r['id']?.toString() ?? '';
          if (rId.isNotEmpty) {
            await sendLocalRoutineDelete(deviceId: deviceId, routineId: rId, explicitIp: ip);
          }
        }
      }
      final targetUri = Uri.parse('http://$ip/api/v1/routines?id=all');
      final response = await _client
          .delete(targetUri, headers: {'Connection': 'close'})
          .timeout(const Duration(milliseconds: 1500));
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('[LAN] sendClearAllRoutines error: $e');
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

  /// Dispatches a real firmware OTA update directly to the device (Port 80) or via Hub (Port 4210).
  Future<({bool ok, int statusCode, String? error})> startLocalOtaUpdate({
    required String deviceId,
    required String downloadUrl,
    String? version,
    String? sha256,
    String? releaseId,
    int? binarySizeBytes,
    String? explicitIp,
  }) async {
    final payloadMap = <String, dynamic>{
      'deviceId': deviceId,
      'downloadUrl': downloadUrl,
      if (version != null && version.isNotEmpty) 'version': version,
      if (sha256 != null && sha256.isNotEmpty) 'sha256': sha256,
      if (releaseId != null && releaseId.isNotEmpty) 'releaseId': releaseId,
      if (binarySizeBytes != null && binarySizeBytes > 0) 'binarySizeBytes': binarySizeBytes,
    };
    final body = json.encode(payloadMap);

    final isHubActive = _cachedHubHost != null &&
        _lastHubSeenAt != null &&
        DateTime.now().difference(_lastHubSeenAt!).inSeconds < 120;

    if (isHubActive) {
      try {
        final hubUri = Uri.parse('http://$_cachedHubHost:4210/api/v1/ota/trigger');
        final hubRes = await _client
            .post(hubUri, headers: {'Content-Type': 'application/json'}, body: body)
            .timeout(const Duration(milliseconds: 2500));
        if (hubRes.statusCode == 200 || hubRes.statusCode == 201) {
          return (ok: true, statusCode: hubRes.statusCode, error: null);
        }
      } catch (e) {
        debugPrint('[LAN-HUB] Hub OTA trigger notice: $e');
      }
    }

    final ip = explicitIp ?? getDeviceIp(deviceId);
    if (ip == null || ip.isEmpty) {
      return (ok: false, statusCode: 0, error: 'Device IP unknown on local Wi-Fi');
    }

    try {
      final uri = Uri.parse('http://$ip/api/v1/ota/start');
      final res = await _client
          .post(uri, headers: {'Content-Type': 'application/json', 'Connection': 'close'}, body: body)
          .timeout(const Duration(milliseconds: 3000));
      if (res.statusCode == 200 || res.statusCode == 201) {
        return (ok: true, statusCode: res.statusCode, error: null);
      }
      String errMsg = 'HTTP ${res.statusCode}';
      try {
        final decoded = json.decode(res.body);
        if (decoded is Map && decoded['error'] != null) {
          errMsg = decoded['error'].toString();
        }
      } catch (_) {}
      if (res.statusCode == 404) {
        errMsg = 'Installed board firmware lacks /api/v1/ota/start endpoint (needs base firmware update)';
      }
      return (ok: false, statusCode: res.statusCode, error: errMsg);
    } catch (e) {
      return (ok: false, statusCode: 0, error: e.toString());
    }
  }

  /// Polls live OTA flashing progress and running firmware version directly from the ESP32.
  Future<Map<String, dynamic>?> fetchLocalOtaStatus({
    required String deviceId,
    String? explicitIp,
  }) async {
    final ip = explicitIp ?? getDeviceIp(deviceId);
    if (ip == null || ip.isEmpty) return null;

    try {
      final res = await _client
          .get(Uri.parse('http://$ip/api/v1/ota/status'), headers: {'Connection': 'close'})
          .timeout(const Duration(milliseconds: 1500));
      if (res.statusCode == 200) {
        final decoded = json.decode(res.body);
        if (decoded is Map) {
          return Map<String, dynamic>.from(decoded);
        }
      }
    } catch (_) {}

    // Fallback: read firmwareVersion from /api/v1/ping after reboot
    try {
      final pingRes = await _client
          .get(Uri.parse('http://$ip/api/v1/ping'), headers: {'Connection': 'close'})
          .timeout(const Duration(milliseconds: 1500));
      if (pingRes.statusCode == 200) {
        final decoded = json.decode(pingRes.body);
        if (decoded is Map) {
          return {
            'state': 'IDLE',
            'firmwareVersion': decoded['firmwareVersion']?.toString(),
          };
        }
      }
    } catch (_) {}
    return null;
  }

  /// Pushes a cross-device P2P automation rule directly to a device's NVS flash
  /// over port 80 so it executes autonomously over UDP without the mobile app or cloud.
  Future<bool> syncPeerRuleToDevice({
    required String deviceId,
    required CrossDeviceRule rule,
    String? explicitIp,
  }) async {
    final ip = explicitIp ?? getDeviceIp(deviceId) ?? DeviceStorageService.getAllCachedDeviceIps()[deviceId];
    if (ip == null || ip.isEmpty || ip == '127.0.0.1') {
      return false;
    }

    final cachedActionIp = getDeviceIp(rule.actionDeviceId) ??
        DeviceStorageService.getAllCachedDeviceIps()[rule.actionDeviceId];
    final actionIp = (cachedActionIp != null && cachedActionIp.isNotEmpty)
        ? cachedActionIp
        : rule.actionDeviceIp;
    final cmdUpper = rule.actionCommand.toUpperCase();
    final isToggle = cmdUpper == 'TOGGLE';
    final actionPower = cmdUpper != 'OFF' && cmdUpper != 'TURN_OFF';

    final body = json.encode({
      'id': rule.id,
      'triggerDeviceId': rule.triggerDeviceId,
      'triggerChannel': rule.triggerChannel,
      'triggerState': rule.triggerState,
      'actionDeviceId': rule.actionDeviceId,
      'actionDeviceIp': actionIp,
      'actionChannel': rule.actionChannel,
      'actionCommand': cmdUpper,
      'actionPower': actionPower,
      'isToggle': isToggle,
      'enabled': rule.enabled,
    });

    try {
      final res = await _client
          .post(
            Uri.parse('http://$ip/api/v1/peer-rules'),
            headers: {'Content-Type': 'application/json', 'Connection': 'close'},
            body: body,
          )
          .timeout(const Duration(milliseconds: 2000));
      if (res.statusCode == 200 || res.statusCode == 201) {
        _peerRuleSyncedDevices.add(deviceId.toLowerCase());
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('[LAN-P2P] Failed syncing peer rule ${rule.id} to $deviceId ($ip): $e');
      return false;
    }
  }

  final Set<String> _peerRuleSyncedDevices = {};

  bool hasSyncedPeerRulesOnDevice(String deviceId) =>
      _peerRuleSyncedDevices.contains(deviceId.toLowerCase());

  /// Removes a persisted P2P cross-device rule from an ESP32 device.
  Future<bool> deletePeerRuleFromDevice({
    required String deviceId,
    required String ruleId,
    String? explicitIp,
  }) async {
    final ip = explicitIp ?? getDeviceIp(deviceId) ?? DeviceStorageService.getAllCachedDeviceIps()[deviceId];
    if (ip == null || ip.isEmpty || ip == '127.0.0.1') {
      return false;
    }
    try {
      final uri = Uri.parse('http://$ip/api/v1/peer-rules?id=${Uri.encodeQueryComponent(ruleId)}');
      final res = await _client
          .delete(uri, headers: {'Connection': 'close'})
          .timeout(const Duration(milliseconds: 2000));
      return res.statusCode == 200 || res.statusCode == 204;
    } catch (e) {
      debugPrint('[LAN-P2P] Failed deleting peer rule $ruleId from $deviceId ($ip): $e');
      return false;
    }
  }

  /// Pushes all standalone cross-device rules referencing [deviceId] (either as
  /// trigger or action device) to its NVS over LAN so physical switches always run them.
  Future<void> syncAllPeerRulesForDevice(String deviceId) async {
    final rules = await DeviceStorageService.loadStandaloneRules();
    if (rules.isEmpty) return;
    final normSelf = deviceId.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    for (final rule in rules) {
      final normTrig = rule.triggerDeviceId.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
      final normAct = rule.actionDeviceId.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
      if (normTrig == normSelf || normAct == normSelf) {
        await syncPeerRuleToDevice(deviceId: deviceId, rule: rule);
      }
    }
  }
}

