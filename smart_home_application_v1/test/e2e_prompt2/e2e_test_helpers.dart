import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_home_application_v1/core/models/device_models.dart';
import 'package:smart_home_application_v1/core/models/help_models.dart';
import 'package:smart_home_application_v1/core/models/settings_models.dart';
import 'package:smart_home_application_v1/core/repositories/help_repository.dart';
import 'package:smart_home_application_v1/core/repositories/settings_repository.dart';
import 'package:smart_home_application_v1/core/theme/app_theme.dart';

/// Test implementation of [SettingsRepository] for opaque-box E2E testing.
class TestSettingsRepository implements SettingsRepository {
  TestSettingsRepository({
    HomeSettingsData? home,
    List<HomeMember>? members,
    List<HomeInvitation>? pendingInvitations,
    List<DiscoveredRoomDevice>? nearbyDevices,
    this.inviteResult = SettingsOperationResult.success,
    this.updateRoleResult = SettingsOperationResult.success,
    this.removeMemberResult = SettingsOperationResult.success,
    this.cancelInviteResult = SettingsOperationResult.success,
    this.resendInviteResult = SettingsOperationResult.unsupported,
    this.throwOnNearbyDevices = false,
  })  : home = home ?? defaultHome,
        members = List<HomeMember>.from(members ?? defaultMembers),
        pendingInvitations = List<HomeInvitation>.from(
          pendingInvitations ?? defaultPendingInvitations,
        ),
        nearbyDevices = List<DiscoveredRoomDevice>.from(
          nearbyDevices ?? defaultNearbyDevices,
        );

  static final HomeSettingsData defaultHome = HomeSettingsData(
    id: 'home_e2e_test_01',
    name: 'EH Test Home',
    ownerName: 'Test Owner',
    location: 'Bangalore, India',
    timezone: 'Asia/Kolkata',
    createdAt: DateTime(2026, 1, 1),
    preferences: const HomePreferences(
      temperatureUnit: 'Celsius (°C)',
      notificationsEnabled: true,
      timeFormat: '12-hour',
    ),
    connectionAvailability: HomeConnectionAvailability.connected,
    connectionTransport: 'Bluetooth + Wi-Fi',
    lastChecked: DateTime(2026, 11, 1),
  );

  static const List<HomeMember> defaultMembers = [
    HomeMember(
      id: 'usr_owner_01',
      displayName: 'Alex Owner',
      role: HomeMemberRole.owner,
      status: HomeMemberStatus.active,
      initials: 'AO',
      email: 'alex.owner@example.com',
      lastActiveLabel: 'Active now',
    ),
  ];

  static const List<HomeInvitation> defaultPendingInvitations = [
    HomeInvitation(
      id: 'inv_01',
      recipientName: 'sam.guest@example.com',
      initials: 'SG',
      invitedLabel: 'Invited 1 day ago',
      expiresLabel: 'Expires in 6 days',
      role: HomeMemberRole.guest,
    ),
  ];

  static const List<DiscoveredRoomDevice> defaultNearbyDevices = [
    DiscoveredRoomDevice(
      id: 'EH-SW3X-001',
      name: 'EH Smart Switch 3X',
      model: 'eh-smart-switch-3x',
      signalLabel: 'Strong',
      signal: DeviceConnection.online,
      icon: 'switch',
    ),
  ];

  HomeSettingsData home;
  List<HomeMember> members;
  List<HomeInvitation> pendingInvitations;
  List<DiscoveredRoomDevice> nearbyDevices;

  SettingsOperationResult inviteResult;
  SettingsOperationResult updateRoleResult;
  SettingsOperationResult removeMemberResult;
  SettingsOperationResult cancelInviteResult;
  SettingsOperationResult resendInviteResult;
  bool throwOnNearbyDevices;

  // Invocations log for assertion verification
  final List<String> invitedRecipients = [];
  final List<String> invitedRoles = [];
  final List<String> removedMemberIds = [];
  final List<({String id, String role})> updatedRoles = [];
  final List<String> canceledInviteIds = [];
  final List<String> resentInviteIds = [];
  int getNearbyDevicesCallCount = 0;

  @override
  Future<HomeSettingsData> getHome() async => home;

  @override
  Future<List<HomeMember>> getMembers() async => List.unmodifiable(members);

  @override
  Future<List<HomeInvitation>> getPendingInvitations() async =>
      List.unmodifiable(pendingInvitations);

  @override
  Future<List<DiscoveredRoomDevice>> getNearbyDevices() async {
    getNearbyDevicesCallCount++;
    if (throwOnNearbyDevices) {
      throw StateError('Simulated BLE scan failure');
    }
    return List.unmodifiable(nearbyDevices);
  }

  @override
  Future<SettingsOperationResult> invitePerson(String recipient) async {
    return invitePersonWithRole(recipient, role: 'MEMBER');
  }

  @override
  Future<SettingsOperationResult> invitePersonWithRole(
    String recipient, {
    String role = 'MEMBER',
  }) async {
    invitedRecipients.add(recipient);
    invitedRoles.add(role);
    if (inviteResult == SettingsOperationResult.success) {
      final roleEnum = role == 'HOME_ADMIN'
          ? HomeMemberRole.admin
          : role == 'GUEST'
              ? HomeMemberRole.guest
              : HomeMemberRole.member;
      pendingInvitations.add(
        HomeInvitation(
          id: 'inv_${DateTime.now().millisecondsSinceEpoch}',
          recipientName: recipient,
          initials: recipient.substring(0, 1).toUpperCase(),
          invitedLabel: 'Just now',
          expiresLabel: 'Expires in 7 days',
          role: roleEnum,
        ),
      );
    }
    return inviteResult;
  }

  @override
  Future<SettingsOperationResult> removeMember(String memberId) async {
    removedMemberIds.add(memberId);
    if (removeMemberResult == SettingsOperationResult.success) {
      members.removeWhere((m) => m.id == memberId);
    }
    return removeMemberResult;
  }

  @override
  Future<SettingsOperationResult> updateMemberRole(
    String memberId,
    String role,
  ) async {
    updatedRoles.add((id: memberId, role: role));
    if (updateRoleResult == SettingsOperationResult.success) {
      final roleEnum = role == 'HOME_ADMIN'
          ? HomeMemberRole.admin
          : role == 'GUEST'
              ? HomeMemberRole.guest
              : HomeMemberRole.member;
      final index = members.indexWhere((m) => m.id == memberId);
      if (index >= 0) {
        final current = members[index];
        members[index] = HomeMember(
          id: current.id,
          displayName: current.displayName,
          role: roleEnum,
          status: current.status,
          initials: current.initials,
          email: current.email,
          lastActiveLabel: current.lastActiveLabel,
        );
      }
    }
    return updateRoleResult;
  }

  @override
  Future<SettingsOperationResult> cancelInvitation(String invitationId) async {
    canceledInviteIds.add(invitationId);
    if (cancelInviteResult == SettingsOperationResult.success) {
      pendingInvitations.removeWhere((inv) => inv.id == invitationId);
    }
    return cancelInviteResult;
  }

  @override
  Future<SettingsOperationResult> resendInvitation(String invitationId) async {
    resentInviteIds.add(invitationId);
    return resendInviteResult;
  }

  @override
  Future<SettingsOperationResult> updateHome(HomeSettingsDraft draft) async {
    home = HomeSettingsData(
      id: home.id,
      name: draft.name,
      ownerName: home.ownerName,
      location: draft.location,
      timezone: draft.timezone,
      createdAt: home.createdAt,
      preferences: draft.preferences,
      connectionAvailability: home.connectionAvailability,
      connectionTransport: home.connectionTransport,
      lastChecked: DateTime.now(),
    );
    return SettingsOperationResult.success;
  }
}

/// Test implementation of [HelpRepository] with canonical Prompt 2 content.
class TestHelpRepository implements HelpRepository {
  TestHelpRepository({
    List<HelpArticle>? gettingStarted,
    List<HelpArticle>? troubleshooting,
    List<HelpQuickCard>? quickHelp,
  })  : gettingStarted = gettingStarted ?? canonicalGettingStarted,
        troubleshooting = troubleshooting ?? canonicalTroubleshooting,
        quickHelp = quickHelp ?? canonicalQuickHelp;

  static const canonicalGettingStarted = <HelpArticle>[
    HelpArticle(
      id: 'connect-home',
      title: 'Connect your home',
      subtitle: 'Connect EH Home to your network and supported devices.',
      category: HelpCategoryKind.gettingStarted,
      keywords: ['connect', 'network', 'home', 'wifi'],
      steps: [
        'Open Settings -> Connect your home.',
        'Allow Bluetooth when prompted.',
        'Select your device and connect to Wi-Fi.',
      ],
      actionRoute: 'connect',
      iconKey: 'home',
    ),
    HelpArticle(
      id: 'first-device',
      title: 'Add your first device',
      subtitle: 'Discover and securely set up a supported EH device.',
      category: HelpCategoryKind.gettingStarted,
      keywords: ['first', 'device', 'add', 'pair'],
      steps: [
        'Open Settings -> Add a room device.',
        'Select the nearby device.',
        'Complete secure verification and Wi-Fi setup.',
      ],
      actionRoute: 'add-device',
      iconKey: 'add',
    ),
    HelpArticle(
      id: 'create-room',
      title: 'Create a room',
      subtitle: 'Organize your home devices by room.',
      category: HelpCategoryKind.gettingStarted,
      keywords: ['room', 'organize', 'space'],
      steps: [
        'Open the Rooms tab.',
        'Tap Create Room.',
        'Assign devices to the room.',
      ],
      actionRoute: 'rooms',
      iconKey: 'room',
    ),
    HelpArticle(
      id: 'create-routine',
      title: 'Create a routine',
      subtitle: 'Automate supported device actions using triggers and schedules.',
      category: HelpCategoryKind.gettingStarted,
      keywords: ['routine', 'automation', 'schedule'],
      steps: [
        'Open the Routines tab.',
        'Tap Create routine.',
        'Choose triggers and device actions.',
      ],
      actionRoute: 'routines',
      iconKey: 'routine',
    ),
    HelpArticle(
      id: 'invite-someone',
      title: 'Invite someone',
      subtitle: 'Share home access with authorized household members.',
      category: HelpCategoryKind.gettingStarted,
      keywords: ['invite', 'member', 'people', 'access'],
      steps: [
        'Open Settings -> People at home.',
        'Tap Invite someone.',
        'Send the invitation to their email.',
      ],
      actionRoute: 'people',
      iconKey: 'people',
    ),
  ];

  static const canonicalTroubleshooting = <HelpArticle>[
    HelpArticle(
      id: 'device-offline',
      title: 'Device not responding',
      subtitle: 'Try these steps to revive your device',
      category: HelpCategoryKind.troubleshooting,
      keywords: ['offline', 'stuck'],
      steps: ['Power cycle the device.'],
      actionRoute: 'health',
    ),
  ];

  static const canonicalQuickHelp = <HelpQuickCard>[
    HelpQuickCard(
      articleId: 'connect-home',
      title: 'Bluetooth pairing',
      subtitle: 'Ensure Bluetooth is enabled for nearby scanning.',
      icon: 'bluetooth',
      iconColor: 0xFF155CC8,
      backgroundColor: 0xFFE0E7FF,
    ),
  ];

  final List<HelpArticle> gettingStarted;
  final List<HelpArticle> troubleshooting;
  final List<HelpQuickCard> quickHelp;

  @override
  Future<List<HelpArticle>> getGettingStarted() async =>
      List.unmodifiable(gettingStarted);

  @override
  Future<List<HelpArticle>> getTroubleshooting() async =>
      List.unmodifiable(troubleshooting);

  @override
  Future<List<HelpQuickCard>> getQuickHelp() async =>
      List.unmodifiable(quickHelp);

  @override
  Future<List<HelpArticle>> search(String query) async {
    final lower = query.toLowerCase();
    final all = [...gettingStarted, ...troubleshooting];
    return all
        .where(
          (a) =>
              a.title.toLowerCase().contains(lower) ||
              a.subtitle.toLowerCase().contains(lower) ||
              a.keywords.any((k) => k.toLowerCase().contains(lower)),
        )
        .toList();
  }

  @override
  Future<HelpArticle?> getArticle(String id) async {
    final all = [...gettingStarted, ...troubleshooting];
    final match = all.where((a) => a.id == id);
    return match.isEmpty ? null : match.first;
  }
}

/// Helper to wrap test widgets with MaterialApp and AppTheme.
Widget buildTestApp({
  required Widget child,
  ThemeMode themeMode = ThemeMode.light,
  double textScaleFactor = 1.0,
  NavigatorObserver? navigatorObserver,
  GlobalKey<NavigatorState>? navigatorKey,
}) {
  return MaterialApp(
    navigatorKey: navigatorKey,
    navigatorObservers:
        navigatorObserver != null ? [navigatorObserver] : const [],
    theme: EHAppTheme.lightTheme,
    darkTheme: EHAppTheme.darkTheme,
    themeMode: themeMode,
    home: MediaQuery(
      data: MediaQueryData(
        textScaler: TextScaler.linear(textScaleFactor),
        size: const Size(400, 800),
      ),
      child: child,
    ),
  );
}

/// Helper for navigation tracking.
class TestNavigatorObserver extends NavigatorObserver {
  final List<Route<dynamic>> pushedRoutes = [];
  final List<Route<dynamic>> poppedRoutes = [];

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    pushedRoutes.add(route);
    super.didPush(route, previousRoute);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    poppedRoutes.add(route);
    super.didPop(route, previousRoute);
  }
}
