import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_home_application_v1/core/models/authoritative_home_connection_state.dart';

void main() {
  group('AuthoritativeHomeConnectionState Unit Tests', () {
    test('1. Disconnected when cloud is unreachable and LAN is inactive', () {
      final state = AuthoritativeHomeConnectionState.resolve(
        isCloudReachable: false,
        isLocalMode: false,
        onlineDeviceCount: 0,
        totalDeviceCount: 4,
        hasHome: true,
      );

      expect(state.isOnline, isFalse);
      expect(state.isCloudOnline, isFalse);
      expect(state.isLanOnline, isFalse);
      expect(state.mode, equals(HomeConnectionMode.standalone));
      expect(state.statusBadgeLabel, equals('Offline'));
      expect(state.statusSubtitle, equals('Disconnected / Standalone mode'));
      expect(state.homeDetailsRowSubtitle, equals('Disconnected'));
      expect(state.homeDetailsTrailingLabel, equals('Offline'));
      expect(state.statusColor(isDark: false), equals(const Color(0xFFF59E0B)));
      expect(state.statusColor(isDark: true), equals(const Color(0xFFF59E0B)));
    });

    test('2. Invariant: Never infer Online from saved home id alone', () {
      // Even if hasHome is true and totalDeviceCount is 10, if neither cloud nor LAN is reachable, MUST be offline
      final state = AuthoritativeHomeConnectionState.resolve(
        isCloudReachable: false,
        isLocalMode: false,
        onlineDeviceCount: 0,
        totalDeviceCount: 10,
        hasHome: true,
      );

      expect(state.isOnline, isFalse);
      expect(state.homeDetailsTrailingLabel, equals('Offline'));
      expect(state.homeDetailsRowSubtitle, equals('Disconnected'));
    });

    test('3. Cloud Online with devices -> dual or cloud online', () {
      final state = AuthoritativeHomeConnectionState.resolve(
        isCloudReachable: true,
        isLocalMode: false,
        onlineDeviceCount: 3,
        totalDeviceCount: 3,
        hasHome: true,
      );

      expect(state.isOnline, isTrue);
      expect(state.isCloudOnline, isTrue);
      expect(state.statusBadgeLabel, equals('Online'));
      expect(state.statusSubtitle, equals('Active over Cloud MQTT'));
      expect(state.homeDetailsRowSubtitle, equals('Connected'));
      expect(state.homeDetailsTrailingLabel, equals('Online'));
      expect(state.statusColor(isDark: false), equals(const Color(0xFF10B981)));
    });

    test('4. Cloud Online with 0 devices online -> Cloud Only scanning state', () {
      final state = AuthoritativeHomeConnectionState.resolve(
        isCloudReachable: true,
        isLocalMode: false,
        onlineDeviceCount: 0,
        totalDeviceCount: 2,
        hasHome: true,
      );

      expect(state.isOnline, isTrue);
      expect(state.isCloudOnline, isTrue);
      expect(state.isLanOnline, isFalse);
      expect(state.statusBadgeLabel, equals('Cloud Only'));
      expect(state.statusSubtitle, equals('Connected to Cloud (Scanning for Devices)'));
      expect(state.homeDetailsRowSubtitle, equals('Connected'));
      expect(state.homeDetailsTrailingLabel, equals('Online'));
    });

    test('5. Local LAN mode active with online devices -> Local Mode', () {
      final state = AuthoritativeHomeConnectionState.resolve(
        isCloudReachable: false,
        isLocalMode: true,
        onlineDeviceCount: 2,
        totalDeviceCount: 2,
        hasHome: true,
      );

      expect(state.isOnline, isTrue);
      expect(state.isCloudOnline, isFalse);
      expect(state.isLanOnline, isTrue);
      expect(state.mode, equals(HomeConnectionMode.localLan));
      expect(state.statusBadgeLabel, equals('Local Mode'));
      expect(state.statusSubtitle, equals('Local Wi-Fi Mode Active (Direct Device Control)'));
      expect(state.homeDetailsRowSubtitle, equals('Connected (Local Mode)'));
      expect(state.homeDetailsTrailingLabel, equals('Local'));
      expect(state.statusColor(isDark: false), equals(const Color(0xFF2563EB)));
    });

    test('6. Dual mode: Cloud and Local LAN both connected', () {
      final state = AuthoritativeHomeConnectionState(
        cloudHealth: TransportHealth.verifiedConnected,
        lanHealth: TransportHealth.verifiedConnected,
        onlineDeviceCount: 4,
        totalDeviceCount: 4,
        hasHome: true,
      );

      expect(state.isOnline, isTrue);
      expect(state.isCloudOnline, isTrue);
      expect(state.isLanOnline, isTrue);
      expect(state.mode, equals(HomeConnectionMode.dual));
      expect(state.statusBadgeLabel, equals('Online'));
      expect(state.statusSubtitle, equals('Active over Local LAN & Cloud MQTT'));
      expect(state.homeDetailsRowSubtitle, equals('Connected (Local Mode)'));
    });

    test('7. Standalone / No Home selected', () {
      final state = AuthoritativeHomeConnectionState.resolve(
        isCloudReachable: true,
        isLocalMode: false,
        onlineDeviceCount: 0,
        totalDeviceCount: 0,
        hasHome: false,
      );

      expect(state.isOnline, isFalse);
      expect(state.mode, equals(HomeConnectionMode.standalone));
      expect(state.statusBadgeLabel, equals('No Home'));
      expect(state.statusSubtitle, equals('No home selected'));
      expect(state.homeDetailsRowSubtitle, equals('No home selected'));
      expect(state.homeDetailsTrailingLabel, equals('Set up'));
    });
  });
}
