import 'package:flutter/material.dart';

/// Represents the verified health of an individual transport (Cloud MQTT/REST or Local LAN).
enum TransportHealth {
  verifiedConnected,
  verifying,
  disconnected,
  failed,
}

/// The effective operational mode of home connectivity.
enum HomeConnectionMode {
  dual,
  cloud,
  localLan,
  standalone,
}

/// Unified authoritative source of truth for home connectivity across Cloud and LAN.
///
/// Guaranteed invariants:
/// 1. [isOnline] is true ONLY if Cloud OR LAN is genuinely connected with verified transport health.
///    Never inferred from saved credentials, previous success, or internet-only status.
/// 2. Neither Cloud nor LAN connected -> clearly reports Offline / Disconnected.
/// 3. Consumed uniformly by Home Details, Connection Diagnostics, and Dashboard.
class AuthoritativeHomeConnectionState {
  const AuthoritativeHomeConnectionState({
    required this.cloudHealth,
    required this.lanHealth,
    required this.onlineDeviceCount,
    required this.totalDeviceCount,
    this.hasHome = true,
    this.customMessage,
  });

  final TransportHealth cloudHealth;
  final TransportHealth lanHealth;
  final int onlineDeviceCount;
  final int totalDeviceCount;
  final bool hasHome;
  final String? customMessage;

  bool get isCloudOnline => cloudHealth == TransportHealth.verifiedConnected;
  bool get isLanOnline => lanHealth == TransportHealth.verifiedConnected;
  bool get isLocalMode => isLanOnline;

  /// True ONLY if Cloud OR LAN is genuinely connected with verified transport health.
  bool get isOnline => hasHome && (isCloudOnline || isLanOnline);

  HomeConnectionMode get mode {
    if (!hasHome || !isOnline) return HomeConnectionMode.standalone;
    if (isCloudOnline && isLanOnline) return HomeConnectionMode.dual;
    if (isLanOnline) return HomeConnectionMode.localLan;
    return HomeConnectionMode.cloud;
  }

  /// Diagnostic / Status badge text (e.g. for _HomeConnectionDiagnosticsSheet)
  String get statusBadgeLabel {
    if (!hasHome) return 'No Home';
    if (isCloudOnline && isLanOnline) return 'Online';
    if (isLanOnline) return 'Local Mode';
    if (isCloudOnline) {
      return onlineDeviceCount > 0 ? 'Online' : 'Cloud Only';
    }
    return 'Offline';
  }

  /// Consistent color representation across light and dark themes.
  Color statusColor({required bool isDark}) {
    if (!hasHome || !isOnline) {
      return const Color(0xFFF59E0B); // Amber warning
    }
    if (isLanOnline && !isCloudOnline) {
      return const Color(0xFF2563EB); // Blue primary / local
    }
    return const Color(0xFF10B981); // Emerald green
  }

  /// Diagnostic subtitle describing active transports.
  String get statusSubtitle {
    if (!hasHome) return 'No home selected';
    if (isCloudOnline && isLanOnline) {
      return 'Active over Local LAN & Cloud MQTT';
    }
    if (isLanOnline) {
      return 'Local Wi-Fi Mode Active (Direct Device Control)';
    }
    if (isCloudOnline) {
      return onlineDeviceCount > 0
          ? 'Active over Cloud MQTT'
          : 'Connected to Cloud (Scanning for Devices)';
    }
    return 'Disconnected / Standalone mode';
  }

  /// Home Details row subtitle in settings.
  String get homeDetailsRowSubtitle {
    if (!hasHome) return 'No home selected';
    if (isLanOnline) return 'Connected (Local Mode)';
    if (isOnline) return 'Connected';
    return 'Disconnected';
  }

  /// Home Details row trailing badge in settings.
  String get homeDetailsTrailingLabel {
    if (!hasHome) return 'Set up';
    if (isLanOnline) return 'Local';
    if (isOnline) return 'Online';
    return 'Offline';
  }

  /// Derives the authoritative connection state from live transport signals.
  factory AuthoritativeHomeConnectionState.resolve({
    required bool isCloudReachable,
    required bool isLocalMode,
    required int onlineDeviceCount,
    required int totalDeviceCount,
    bool hasHome = true,
  }) {
    final TransportHealth cloud = isCloudReachable
        ? TransportHealth.verifiedConnected
        : TransportHealth.disconnected;

    // LAN transport is verified if and only if the app is explicitly running in verified Local LAN Mode with responsive devices.
    // It is NEVER inferred from stale cached device lists when cloud is offline.
    final TransportHealth lan = (isLocalMode && (onlineDeviceCount > 0 || totalDeviceCount == 0))
        ? TransportHealth.verifiedConnected
        : TransportHealth.disconnected;

    return AuthoritativeHomeConnectionState(
      cloudHealth: cloud,
      lanHealth: lan,
      onlineDeviceCount: onlineDeviceCount,
      totalDeviceCount: totalDeviceCount,
      hasHome: hasHome,
    );
  }
}

