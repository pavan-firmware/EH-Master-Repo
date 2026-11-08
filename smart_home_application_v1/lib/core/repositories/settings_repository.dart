import '../capabilities/repositories/product_catalog_repository.dart';
import '../models/settings_models.dart';
import '../models/device_models.dart';
import 'package:flutter/foundation.dart';
import '../../features/onboarding/ble/ble_commissioning_channel.dart';
import '../services/ble_preflight_service.dart';
import '../services/product_asset_resolver.dart';

abstract interface class SettingsRepository {
  Future<HomeSettingsData> getHome();
  Future<List<HomeMember>> getMembers();
  Future<List<HomeInvitation>> getPendingInvitations();
  Future<List<DiscoveredRoomDevice>> getNearbyDevices();

  Future<SettingsOperationResult> updateHome(HomeSettingsDraft draft);
  Future<SettingsOperationResult> invitePerson(String recipient);
  Future<SettingsOperationResult> invitePersonWithRole(String recipient, {String role = 'MEMBER'});
  Future<SettingsOperationResult> removeMember(String memberId);
  Future<SettingsOperationResult> updateMemberRole(String memberId, String role);
  Future<SettingsOperationResult> resendInvitation(String invitationId);
  Future<SettingsOperationResult> cancelInvitation(String invitationId);
}

/// Live nearby-device source used by the Add Device flow. It never creates
/// product rows from the account or from sample data; every row originates
/// from a BLE advertisement received during this scan.
class BleDiscoverySettingsRepository implements SettingsRepository {
  BleDiscoverySettingsRepository({
    BleCommissioningChannel? channel,
    BlePreflightService? preflightService,
  }) {
    _channel = channel;
    _preflightService = preflightService;
  }

  BleCommissioningChannel? _channel;
  BleCommissioningChannel? _ownedChannel;
  BlePreflightService? _preflightService;
  BlePreflightService? _ownedPreflightService;

  BleCommissioningChannel get channel =>
      _channel ??= (_ownedChannel ??= BleCommissioningChannel());

  BlePreflightService get preflightService =>
      _preflightService ??= (_ownedPreflightService ??= BlePreflightService());

  /// Opens the most specific system surface for the failed BLE prerequisite.
  /// Location service and Bluetooth radio have dedicated Android screens;
  /// permission denials go to the app permission page.
  Future<bool> openRecoverySettings(String? error) {
    final value = (error ?? '').toLowerCase();
    if (value.contains('location') &&
        (value.contains('turned off') || value.contains('services'))) {
      return preflightService.systemActions.openLocationSettings();
    }
    if (value.contains('bluetooth') && value.contains('turned off')) {
      return preflightService.systemActions.openBluetoothSettings();
    }
    return preflightService.systemActions.openAppSettings();
  }

  @override
  Future<List<DiscoveredRoomDevice>> getNearbyDevices() async {
    return scanNearbyDevices();
  }

  Future<void> resetDiscovery() => channel.resetForDiscovery();

  Future<List<DiscoveredRoomDevice>> scanNearbyDevices({
    void Function(DiscoveredRoomDevice device)? onDeviceDiscovered,
  }) async {
    if (kIsWeb) return const [];

    // Discovery is a real radio operation, so run the same permission/radio
    // checks used by commissioning before opening the scan stream. Without
    // this, Android can return an empty stream even while Bluetooth is on.
    final preflight = await preflightService.check(requestIfNeeded: true);
    if (!preflight.isReady) {
      throw StateError('${preflight.title}: ${preflight.message}');
    }

    await channel.resetForDiscovery();
    final devices = await channel.scanForDevices(
      onDeviceFound: (device) {
        onDeviceDiscovered?.call(_toRoomDevice(device));
      },
    );
    return devices.map(_toRoomDevice).toList(growable: false);
  }

  DiscoveredRoomDevice _toRoomDevice(dynamic device) {
    final name = (device.name as String).trim();
    final devId = (device.id as String?) ?? '';
    final model = MockProductCatalogRepository.resolveCanonicalProductVariant(
      deviceName: name,
      serialNumber: devId,
    );
    final rssi = device.rssi as int;
    final signal = rssi >= -60
        ? 'Strong signal'
        : (rssi >= -75 ? 'Good signal' : 'Weak signal');
    final displayName = name.isEmpty ? 'EH Smart Device' : _displayNameFor(name, model);
    // Resolve the product hardware image from bundled assets so the
    // discovered device tile always shows the real product photo.
    final resolvedImg = resolveBundledProductAsset(model) ?? resolveBundledProductAsset(displayName);
    return DiscoveredRoomDevice(
      id: devId,
      name: displayName,
      model: model,
      signalLabel: signal,
      signal: DeviceConnection.online,
      icon: model.contains('socket') ? 'socket' : 'switch',
      productVariantId: model,
      imageUrl: resolvedImg,
    );
  }

  String _displayNameFor(String advertisedName, String model) {
    final isSocket = model.contains('socket') ||
        advertisedName.toLowerCase().contains('socket') ||
        advertisedName.toLowerCase().contains('sk');
    final match = RegExp(r'(1|2|3|4|5)x').firstMatch(model);
    final variant = match?.group(1) ?? (isSocket ? '2' : '3');
    final family = isSocket ? 'Socket' : 'Switch';
    // Keep user-facing cards readable while the stable BLE id remains the
    // actual hardware address in [DiscoveredRoomDevice.id].
    if (advertisedName.toUpperCase().startsWith('EH-') ||
        advertisedName.toUpperCase().startsWith('EH_') ||
        advertisedName.toUpperCase().startsWith('SH-')) {
      return 'EH Smart $family ${variant}X';
    }
    return advertisedName;
  }

  @override Future<HomeSettingsData> getHome() async =>
      PreviewSettingsRepository().getHome();
  @override Future<List<HomeMember>> getMembers() async =>
      PreviewSettingsRepository().getMembers();
  @override Future<List<HomeInvitation>> getPendingInvitations() async =>
      PreviewSettingsRepository().getPendingInvitations();
  @override Future<SettingsOperationResult> updateHome(HomeSettingsDraft draft) async =>
      SettingsOperationResult.unsupported;
  @override Future<SettingsOperationResult> invitePerson(String recipient) async =>
      SettingsOperationResult.unsupported;
  @override Future<SettingsOperationResult> invitePersonWithRole(String recipient, {String role = 'MEMBER'}) async =>
      SettingsOperationResult.unsupported;
  @override Future<SettingsOperationResult> removeMember(String memberId) async =>
      SettingsOperationResult.unsupported;
  @override Future<SettingsOperationResult> updateMemberRole(String memberId, String role) async =>
      SettingsOperationResult.unsupported;
  @override Future<SettingsOperationResult> resendInvitation(String invitationId) async =>
      SettingsOperationResult.unsupported;
  @override Future<SettingsOperationResult> cancelInvitation(String invitationId) async =>
      SettingsOperationResult.unsupported;
}

/// Preview data keeps Settings transport-independent. Mutations deliberately
/// return [SettingsOperationResult.unsupported] until the authenticated home
/// backend and household-access APIs are available.
class PreviewSettingsRepository implements SettingsRepository {
  const PreviewSettingsRepository();

  @override
  Future<SettingsOperationResult> updateMemberRole(String memberId, String role) async =>
      SettingsOperationResult.unsupported;

  @override
  Future<SettingsOperationResult> invitePersonWithRole(String recipient, {String role = 'MEMBER'}) async =>
      SettingsOperationResult.unsupported;

  @override
  Future<SettingsOperationResult> removeMember(String memberId) async =>
      SettingsOperationResult.unsupported;

  @override
  Future<HomeSettingsData> getHome() async => HomeSettingsData(
    id: 'HN-7A28F91C',
    name: 'Pavan’s home',
    ownerName: 'Pavan',
    location: 'Hyderabad, Telangana, India',
    timezone: 'Asia/Kolkata',
    createdAt: DateTime(2026, 8, 12),
    preferences: const HomePreferences(
      temperatureUnit: 'Celsius (°C)',
      notificationsEnabled: true,
      timeFormat: '12-hour',
    ),
    connectionAvailability: HomeConnectionAvailability.setupRequired,
    connectionTransport: 'Bluetooth + Wi-Fi',
    lastChecked: null,
  );

  @override
  Future<List<HomeMember>> getMembers() async => const [
    HomeMember(
      id: 'pavan',
      displayName: 'Pavan (You)',
      role: HomeMemberRole.owner,
      status: HomeMemberStatus.active,
      initials: 'P',
      lastActiveLabel: 'Home owner',
    ),
    HomeMember(
      id: 'arun',
      displayName: 'Arun',
      role: HomeMemberRole.member,
      status: HomeMemberStatus.active,
      initials: 'A',
      lastActiveLabel: 'Last active today',
    ),
    HomeMember(
      id: 'priya',
      displayName: 'Priya',
      role: HomeMemberRole.member,
      status: HomeMemberStatus.active,
      initials: 'P',
      lastActiveLabel: 'Last active yesterday',
    ),
  ];

  @override
  Future<List<HomeInvitation>> getPendingInvitations() async => const [
    HomeInvitation(
      id: 'rahul',
      recipientName: 'Rahul',
      initials: 'R',
      invitedLabel: 'Invited 2 days ago',
      expiresLabel: 'Expires in 5 days',
    ),
  ];

  @override
  Future<List<DiscoveredRoomDevice>> getNearbyDevices() async => const [
    DiscoveredRoomDevice(
      id: 'SH-8EF248',
      name: 'EH Smart Switch 3X',
      model: 'eh-smart-switch-3x',
      signalLabel: 'Strong signal',
      signal: DeviceConnection.online,
      icon: 'switch',
      imageUrl: 'assets/products/catalog/eh-smart-switch-3x/hero.webp',
      productVariantId: 'eh-smart-switch-3x',
    ),
    DiscoveredRoomDevice(
      id: 'SH-72A931',
      name: 'EH Smart Socket 2X',
      model: 'eh-smart-socket-2x',
      signalLabel: 'Good signal',
      signal: DeviceConnection.online,
      icon: 'socket',
      imageUrl: 'assets/products/catalog/eh-smart-socket-2x/hero.webp',
      productVariantId: 'eh-smart-socket-2x',
    ),
  ];

  @override
  Future<SettingsOperationResult> cancelInvitation(String invitationId) async =>
      SettingsOperationResult.unsupported;

  @override
  Future<SettingsOperationResult> invitePerson(String recipient) async =>
      SettingsOperationResult.unsupported;

  @override
  Future<SettingsOperationResult> resendInvitation(String invitationId) async =>
      SettingsOperationResult.unsupported;

  @override
  Future<SettingsOperationResult> updateHome(HomeSettingsDraft draft) async =>
      SettingsOperationResult.unsupported;
}
