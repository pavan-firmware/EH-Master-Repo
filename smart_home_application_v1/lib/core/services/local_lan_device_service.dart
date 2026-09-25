import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'device_storage_service.dart';

/// Production Local LAN Device Service
///
/// Provides direct HTTP REST communication with ESP32 devices on the local
/// home Wi-Fi network when the cloud backend / internet is unreachable.
class LocalLanDeviceService {
  LocalLanDeviceService._() {
    startUdpListener();
  }
  static final LocalLanDeviceService instance = LocalLanDeviceService._();

  final http.Client _client = http.Client();
  final Map<String, String> _deviceIpMap = {};
  bool _isDiscovering = false;

  final _stateBroadcastController =
      StreamController<({String deviceId, Map<int, bool> channels})>.broadcast();
  Stream<({String deviceId, Map<int, bool> channels})> get onStateBroadcast =>
      _stateBroadcastController.stream;
  RawDatagramSocket? _listenerSocket;

  bool get isDiscovering => _isDiscovering;

  Future<void> startUdpListener() async {
    if (_listenerSocket != null) return;
    try {
      _listenerSocket = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        4210,
        reuseAddress: true,
        reusePort: true,
      );
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
                if (devId != null && devId.isNotEmpty) {
                  registerDeviceIp(devId, devIp);
                }
                if (map['cmd'] == 'EH_STATE_CHANGED' && devId != null && map['channels'] is List) {
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
                    _stateBroadcastController.add((deviceId: devId, channels: chMap));
                    debugPrint('[LAN-UDP] Real-time state announcement received for $devId: $chMap');
                  }
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

  void registerDeviceIp(String deviceId, String ip) {
    if (ip.trim().isNotEmpty) {
      _deviceIpMap[deviceId] = ip.trim();
      DeviceStorageService.saveDeviceIp(deviceId, ip.trim());
      debugPrint('[LAN] Registered Device $deviceId at IP: $ip');
    }
  }

  String? getDeviceIp(String deviceId) {
    if (_deviceIpMap.containsKey(deviceId)) {
      return _deviceIpMap[deviceId];
    }
    final saved = DeviceStorageService.getDeviceIp(deviceId);
    if (saved != null && saved.isNotEmpty) {
      _deviceIpMap[deviceId] = saved;
      return saved;
    }
    return null;
  }

  /// Auto-discover all EH devices on the local Wi-Fi network.
  /// Uses a dual-strategy:
  /// 1. UDP Broadcast on Port 4210 (instant response in <100ms)
  /// 2. Fast Parallel Subnet Sweep on /api/v1/ping (for routers that block broadcast)
  Future<Map<String, String>> autoDiscoverDevices({
    Duration timeout = const Duration(seconds: 4),
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
            final uri = Uri.parse('http://$ip/api/v1/ping');
            final resp = await _client.get(uri).timeout(const Duration(milliseconds: 900));
            if (resp.statusCode == 200) {
              final body = json.decode(resp.body);
              final resolvedId = (body is Map && body['deviceId'] != null)
                  ? body['deviceId'].toString()
                  : devId;
              discovered[resolvedId] = ip;
              discovered[devId] = ip;
              registerDeviceIp(resolvedId, ip);
              registerDeviceIp(devId, ip);
              debugPrint('[LAN] Fast-path ping confirmed cached device: $resolvedId at $ip');
            }
          } catch (_) {}
        }
      }

      // Collect all local IPv4 subnets across all network interfaces
      final subnets = <String>{};
      try {
        final interfaces = await NetworkInterface.list(
          type: InternetAddressType.IPv4,
          includeLoopback: false,
        );
        for (final iface in interfaces) {
          for (final addr in iface.addresses) {
            final ip = addr.address;
            if (!ip.startsWith('127.') && !ip.startsWith('169.254.')) {
              final parts = ip.split('.');
              if (parts.length == 4) {
                final prefix = '${parts[0]}.${parts[1]}.${parts[2]}';
                subnets.add(prefix);
                debugPrint('[LAN] Discovered Interface [${iface.name}] IP: $ip (Subnet: $prefix.0/24)');
              }
            }
          }
        }
      } catch (e) {
        debugPrint('[LAN] Error querying network interfaces: $e');
      }

      // Always include 192.168.55 (default home subnet) and common subnets as fallbacks
      subnets.add('192.168.55');
      if (subnets.isEmpty) {
        subnets.addAll(['192.168.1', '192.168.0', '192.168.4']);
      }

      // Strategy 1: UDP Broadcast Discovery on Port 4210
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
                  debugPrint('[LAN] UDP Discovered Device: $devId at $devIp');
                }
              } catch (_) {}
            }
          }
        });

        final broadcastMsg = utf8.encode(json.encode({'cmd': 'EH_DISCOVER'}));
        socket.send(broadcastMsg, InternetAddress('255.255.255.255'), 4210);

        for (final subnet in subnets) {
          try {
            socket.send(broadcastMsg, InternetAddress('$subnet.255'), 4210);
          } catch (_) {}
        }

        Timer(const Duration(milliseconds: 1400), () {
          if (!completer.isCompleted) completer.complete();
        });
        await completer.future;
      } catch (e) {
        debugPrint('[LAN] UDP broadcast warning: $e');
      } finally {
        socket?.close();
      }

      // Strategy 2: Parallel Subnet Ping Sweep on /api/v1/ping (Batch-controlled)
      if (discovered.isEmpty) {
        for (final subnet in subnets) {
          debugPrint('[LAN] Running chunked subnet ping sweep on $subnet.1-254...');

          // Prioritize standard smart device DHCP ranges (.100-.250 then .2-.99)
          final orderedIps = <int>[
            for (int i = 100; i <= 250; i++) i,
            for (int i = 2; i < 100; i++) i,
            for (int i = 251; i <= 254; i++) i,
          ];

          const chunkSize = 32;
          for (int c = 0; c < orderedIps.length; c += chunkSize) {
            final chunk = orderedIps.sublist(
              c,
              (c + chunkSize > orderedIps.length) ? orderedIps.length : c + chunkSize,
            );

            final chunkFutures = chunk.map((i) async {
              final targetIp = '$subnet.$i';
              try {
                final uri = Uri.parse('http://$targetIp/api/v1/ping');
                final resp = await _client.get(uri).timeout(const Duration(milliseconds: 700));
                if (resp.statusCode == 200) {
                  final body = json.decode(resp.body);
                  if (body is Map && (body['status'] == 'ok' || body['deviceId'] != null)) {
                    final devId = body['deviceId']?.toString() ?? 'esp32_device';
                    discovered[devId] = targetIp;
                    registerDeviceIp(devId, targetIp);
                    debugPrint('[LAN] Subnet Sweep Discovered Device: $devId at $targetIp');
                  }
                }
              } catch (_) {}
            });

            await Future.wait(chunkFutures);
            if (discovered.isNotEmpty) break;
          }

          if (discovered.isNotEmpty) break;
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
    String? explicitIp,
  }) async {
    final ip = explicitIp ?? getDeviceIp(deviceId);
    if (ip == null || ip.isEmpty) {
      debugPrint('[LAN] No local IP known for device $deviceId. Attempting auto-discovery...');
      final discovered = await autoDiscoverDevices();
      final discoveredIp = discovered[deviceId];
      if (discoveredIp == null || discoveredIp.isEmpty) {
        return false;
      }
      return sendLocalControl(
        deviceId: deviceId,
        channelIndex: channelIndex,
        power: power,
        explicitIp: discoveredIp,
      );
    }

    final targetUri = Uri.parse('http://$ip/api/v1/control');
    final payload = json.encode({
      'channel': channelIndex,
      'channelIndex': channelIndex,
      'power': power,
      'value': power,
      'enabled': power,
    });

    try {
      debugPrint('[LAN] Sending direct local command to $targetUri: $payload');
      final response = await _client
          .post(
            targetUri,
            headers: {'Content-Type': 'application/json'},
            body: payload,
          )
          .timeout(const Duration(milliseconds: 1800));

      if (response.statusCode == 200) {
        final body = json.decode(response.body);
        if (body is Map && body['success'] == true) {
          debugPrint('[LAN] Direct local command SUCCESS for device $deviceId ch$channelIndex');
          return true;
        }
      }
      debugPrint('[LAN] Direct local command failed with HTTP ${response.statusCode}');
      return false;
    } catch (e) {
      debugPrint('[LAN] Direct local command error for $targetUri: $e');
      return false;
    }
  }

  /// Queries the live relay state directly from the ESP32 embedded web server
  Future<Map<int, bool>?> fetchLocalState({
    required String deviceId,
    String? explicitIp,
  }) async {
    final ip = explicitIp ?? getDeviceIp(deviceId);
    if (ip == null || ip.isEmpty) return null;

    final targetUri = Uri.parse('http://$ip/api/v1/state');
    try {
      final response = await _client
          .get(targetUri)
          .timeout(const Duration(milliseconds: 1800));

      if (response.statusCode == 200) {
        final body = json.decode(response.body);
        if (body is Map && body['channels'] is List) {
          final channels = body['channels'] as List;
          final result = <int, bool>{};
          for (final ch in channels) {
            if (ch is Map) {
              final idx = ch['channelIndex'] as int? ?? 1;
              final pwr = ch['power'] as bool? ?? false;
              result[idx] = pwr;
            }
          }
          return result;
        }
      }
    } catch (e) {
      debugPrint('[LAN] fetchLocalState error: $e');
    }
    return null;
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
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}
