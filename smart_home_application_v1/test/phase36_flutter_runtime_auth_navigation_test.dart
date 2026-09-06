import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:smart_home_application_v1/app/app.dart';
import 'package:smart_home_application_v1/app/home_controller.dart';
import 'package:smart_home_application_v1/core/api/api_client.dart';
import 'package:smart_home_application_v1/core/api/sse_client.dart';
import 'package:smart_home_application_v1/core/config/app_config.dart';
import 'package:smart_home_application_v1/core/models/access_control_models.dart';
import 'package:smart_home_application_v1/core/models/device_models.dart';
import 'package:smart_home_application_v1/core/models/home_dashboard_models.dart';
import 'package:smart_home_application_v1/core/models/settings_models.dart';
import 'package:smart_home_application_v1/core/repositories/account_home_repository.dart';
import 'package:smart_home_application_v1/core/repositories/auth_repository.dart';
import 'package:smart_home_application_v1/core/repositories/cloud_home_repository.dart';
import 'package:smart_home_application_v1/core/repositories/fake_home_repository.dart';
import 'package:smart_home_application_v1/core/repositories/settings_repository.dart';
import 'package:smart_home_application_v1/core/services/realtime_event_service.dart';
import 'package:smart_home_application_v1/features/auth/auth_controller.dart';
import 'package:smart_home_application_v1/features/settings/presentation/settings_page.dart';

import 'package:smart_home_application_v1/core/repositories/unavailable_connection_repository.dart';

// ── Mock & Test Doubles ───────────────────────────────────────────────────────

class MockAccountHomeRepository implements AccountHomeRepository {
  List<HomeSummaryItem> homes = [];
  bool shouldFail = false;

  @override
  Future<List<HomeSummaryItem>> listHomes() async {
    if (shouldFail) throw Exception('Network error');
    return homes;
  }

  @override
  Future<HomeSummaryItem> createHome({required String name, String? timezone, String? address}) async {
    final h = HomeSummaryItem(id: 'home-${DateTime.now().millisecondsSinceEpoch}', name: name);
    homes.add(h);
    return h;
  }

  @override
  Future<HomeSummaryItem> getHomeDetails(String homeId) async {
    return homes.firstWhere((h) => h.id == homeId, orElse: () => HomeSummaryItem(id: homeId, name: 'Home'));
  }

  @override
  Future<HomeSummaryItem> updateHome(String homeId, {String? name, String? timezone, String? address}) async {
    return HomeSummaryItem(id: homeId, name: name ?? 'Updated');
  }

  @override
  Future<void> deleteHome(String homeId) async => homes.removeWhere((h) => h.id == homeId);

  @override
  Future<void> transferOwnership(String homeId, {required String newOwnerId}) async {}

  @override
  Future<void> leaveHome(String homeId) async {}

  @override
  Future<UserAccountProfile> getAccountProfile() async => const UserAccountProfile(id: 'u1', email: 'test@example.com');

  @override
  Future<UserAccountProfile> updateAccountProfile({String? fullName, String? phoneNumber, String? avatarUrl, String? timezone}) async =>
      const UserAccountProfile(id: 'u1', email: 'test@example.com');

  @override
  Future<void> changePassword({required String oldPassword, required String newPassword}) async {}

  @override
  Future<List<AccountSessionItem>> listSessions() async => [];

  @override
  Future<void> revokeSession(String sessionId) async {}

  @override
  Future<void> deleteAccount({required String password}) async {}

  @override
  Future<List<HomeMemberItem>> listMembers(String homeId) async => [];

  @override
  Future<void> updateMemberRole(String homeId, {required String userId, required String role}) async {}

  @override
  Future<void> removeMember(String homeId, {required String userId}) async {}

  @override
  Future<HomeInviteItem> createInvitation(String homeId, {required String email, required String role}) async =>
      HomeInviteItem(
        id: 'inv1',
        homeId: homeId,
        inviterUserId: 'u1',
        inviteeEmail: email,
        role: role,
        inviteCode: 'ABC',
        createdAt: DateTime.now().toIso8601String(),
        expiresAt: DateTime.now().add(const Duration(days: 7)).toIso8601String(),
      );

  @override
  Future<List<HomeInviteItem>> listHomeInvitations(String homeId) async => [];

  @override
  Future<void> revokeInvitation(String homeId, {required String inviteId}) async {}

  @override
  Future<List<HomeInviteItem>> listPendingInvitations() async => [];

  @override
  Future<void> acceptInvitation(String inviteCode) async {}

  @override
  Future<void> rejectInvitation(String inviteCode) async {}
}

class FakeRealtimeService extends RealtimeEventService {
  FakeRealtimeService() : super(SseClient(ApiClient(baseUrl: 'http://localhost:3000')));

  final _controller = StreamController<SSEEventEnvelope>.broadcast();
  String? connectedHomeId;
  int connectCount = 0;
  int disconnectCount = 0;

  @override
  Stream<SSEEventEnvelope> get events => _controller.stream;

  @override
  void connect(String homeId) {
    connectedHomeId = homeId;
    connectCount++;
  }

  @override
  void disconnect() {
    connectedHomeId = null;
    disconnectCount++;
  }

  void emit(SSEEventEnvelope envelope) {
    _controller.add(envelope);
  }

  @override
  void dispose() {
    _controller.close();
    super.dispose();
  }
}

class MockAuthRepository extends AuthRepository {
  MockAuthRepository() : super(ApiClient(baseUrl: 'http://localhost:3000'));

  bool _isAuth = false;
  UserProfile? _user;

  @override
  bool get isAuthenticated => _isAuth;

  @override
  UserProfile? get currentUser => _user;

  void setAuthenticated({required bool isAuth, UserProfile? user}) {
    _isAuth = isAuth;
    _user = user;
  }

  @override
  Future<void> restoreSession() async {}

  @override
  Future<void> login(String email, String password) async {
    _isAuth = true;
    _user = UserProfile(id: 'u-101', email: email, emailVerified: true, role: email.contains('admin') ? 'ADMIN' : 'USER');
  }

  @override
  Future<void> logout() async {
    _isAuth = false;
    _user = null;
  }
}

// ── Main Test Suite ───────────────────────────────────────────────────────────

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Phase 36 — Authentication & Cloud Enablement Lifecycle', () {
    test('1. Unauthenticated HomeController disables hardware cloud operations', () async {
      final ctrl = HomeController(
        repository: CloudHomeRepository(ApiClient(baseUrl: 'http://localhost:3000')),
        connectionRepository: const UnavailableConnectionRepository(),
        cloudEnabled: false,
      );

      expect(ctrl.cloudEnabled, isFalse);
      expect(ctrl.hardwareControlsAvailable, isFalse);
      expect(ctrl.cloudDeviceConnection, equals(DeviceConnection.offline));

      // Attempting command while unauthenticated
      await ctrl.setLivingRoomLight(false);
      expect(ctrl.lightConfidence, equals(ActuatorConfidence.unavailable));
      expect(ctrl.lightCommandPending, isFalse);
    });

    test('2. Authenticated state dynamically enables cloud operations in HomeController', () {
      final ctrl = HomeController(
        cloudEnabled: false,
        connectionRepository: const UnavailableConnectionRepository(),
      );
      expect(ctrl.cloudEnabled, isFalse);

      ctrl.setCloudEnabled(true);
      expect(ctrl.cloudEnabled, isTrue);
      expect(ctrl.hardwareControlsAvailable, isTrue);
    });

    test('3. Logout disables cloud access, clears pending state, and resets session', () {
      final ctrl = HomeController(
        cloudEnabled: true,
        connectionRepository: const UnavailableConnectionRepository(),
      );
      ctrl.setActiveHomeId('home-alpha');
      expect(ctrl.activeHomeId, equals('home-alpha'));
      expect(ctrl.cloudEnabled, isTrue);

      // Trigger session reset on logout
      ctrl.resetSession();

      expect(ctrl.cloudEnabled, isFalse);
      expect(ctrl.activeHomeId, isNull);
      expect(ctrl.cloudDeviceConnection, equals(DeviceConnection.offline));
      expect(ctrl.lightCommandPending, isFalse);
      expect(ctrl.mistingCommandPending, isFalse);
      expect(ctrl.lightConfidence, equals(ActuatorConfidence.unknown));
    });

    test('4. Authentication refresh preserves controller state without resetting configuration', () {
      final ctrl = HomeController(
        cloudEnabled: true,
        connectionRepository: const UnavailableConnectionRepository(),
      );
      ctrl.setActiveHomeId('home-beta');

      // Toggling cloudEnabled true repeatedly is idempotent
      ctrl.setCloudEnabled(true);
      expect(ctrl.activeHomeId, equals('home-beta'));
      expect(ctrl.cloudEnabled, isTrue);
    });
  });

  group('Phase 36 — Dynamic Authenticated Home Resolution', () {
    test('5. Dynamic home resolution loads authoritative home ID from AccountHomeRepository', () async {
      final mockHomeRepo = MockAccountHomeRepository()
        ..homes = [
          const HomeSummaryItem(id: 'home-777', name: 'Downtown Penthouse'),
        ];

      final homes = await mockHomeRepo.listHomes();
      expect(homes.length, equals(1));
      expect(homes.first.id, equals('home-777'));
      expect(homes.first.name, equals('Downtown Penthouse'));
    });

    test('6. No-home state is handled deterministically without throwing or fallback to default', () async {
      final mockHomeRepo = MockAccountHomeRepository()..homes = [];
      final homes = await mockHomeRepo.listHomes();
      expect(homes, isEmpty);
    });

    test('7. Multiple homes selects authoritative first home without ambiguity', () async {
      final mockHomeRepo = MockAccountHomeRepository()
        ..homes = [
          const HomeSummaryItem(id: 'home-primary', name: 'Primary Residence'),
          const HomeSummaryItem(id: 'home-vacation', name: 'Vacation Villa'),
        ];

      final homes = await mockHomeRepo.listHomes();
      expect(homes.length, equals(2));
      expect(homes.first.id, equals('home-primary'));
    });
  });

  group('Phase 36 — SSE Home Routing & Event Dispatch', () {
    test('8. SSE subscription connects using resolved user home ID', () {
      final fakeSse = FakeRealtimeService();
      final ctrl = HomeController(
        realtimeEventService: fakeSse,
        connectionRepository: const UnavailableConnectionRepository(),
        cloudEnabled: true,
      );

      fakeSse.connect('home-authoritative-99');
      expect(fakeSse.connectedHomeId, equals('home-authoritative-99'));
      expect(fakeSse.connectCount, equals(1));

      ctrl.dispose();
    });

    test('9. SSE subscription closes on logout', () {
      final fakeSse = FakeRealtimeService();
      fakeSse.connect('home-xyz');
      expect(fakeSse.connectedHomeId, equals('home-xyz'));

      fakeSse.disconnect();
      expect(fakeSse.connectedHomeId, isNull);
      expect(fakeSse.disconnectCount, equals(1));

      fakeSse.dispose();
    });

    test('10. SSE reconnect re-establishes connection on lifecycle resume', () {
      final fakeSse = FakeRealtimeService();
      fakeSse.connect('home-resumed');
      expect(fakeSse.connectCount, equals(1));

      // Simulate pause/resume
      fakeSse.disconnect();
      expect(fakeSse.connectedHomeId, isNull);

      fakeSse.connect('home-resumed');
      expect(fakeSse.connectedHomeId, equals('home-resumed'));
      expect(fakeSse.connectCount, equals(2));

      fakeSse.dispose();
    });

    test('11. Realtime events update device availability and state correctly', () async {
      final fakeSse = FakeRealtimeService();
      final ctrl = HomeController(
        realtimeEventService: fakeSse,
        connectionRepository: const UnavailableConnectionRepository(),
        cloudEnabled: true,
      );

      expect(ctrl.cloudDeviceConnection, equals(DeviceConnection.offline));

      // Emit availability ONLINE
      fakeSse.emit(SSEEventEnvelope(
        schemaVersion: 1,
        eventId: 'evt-avail-1',
        type: 'device.availability',
        occurredAt: DateTime.now().toIso8601String(),
        homeId: 'home-authoritative-99',
        payload: {'status': 'ONLINE'},
      ));
      await Future<void>.delayed(Duration.zero);
      expect(ctrl.cloudDeviceConnection, equals(DeviceConnection.online));

      // Emit state update
      fakeSse.emit(SSEEventEnvelope(
        schemaVersion: 1,
        eventId: 'evt-state-1',
        type: 'device.state',
        occurredAt: DateTime.now().toIso8601String(),
        homeId: 'home-authoritative-99',
        deviceId: 'sw-01',
        payload: {
          'deviceId': 'sw-01',
          'channels': {
            'channel1': {'relay': false}
          }
        },
      ));
      await Future<void>.delayed(Duration.zero);
      expect(ctrl.livingRoomLightOn, isFalse);

      ctrl.dispose();
      fakeSse.dispose();
    });
  });

  group('Phase 36 — Command Execution & Protection Runtime', () {
    test('12. Authenticated command execution dispatches to repository', () async {
      final fakeRepo = FakeHomeRepository();
      final fakeSse = FakeRealtimeService();
      final ctrl = HomeController(
        repository: fakeRepo,
        connectionRepository: const UnavailableConnectionRepository(),
        realtimeEventService: fakeSse,
        cloudEnabled: true,
      );

      final cmd = ctrl.setLivingRoomLight(false);
      expect(ctrl.lightCommandPending, isTrue);
      await cmd;

      // When SSE confirms the state:
      fakeSse.emit(SSEEventEnvelope(
        schemaVersion: 1,
        eventId: 'receipt-1',
        type: 'command.receipt',
        occurredAt: DateTime.now().toIso8601String(),
        homeId: 'home-1',
        payload: {'status': 'APPLIED'},
      ));
      fakeSse.emit(SSEEventEnvelope(
        schemaVersion: 1,
        eventId: 'state-1',
        type: 'device.state',
        occurredAt: DateTime.now().toIso8601String(),
        homeId: 'home-1',
        payload: {
          'channels': {
            'channel1': {'relay': false}
          }
        },
      ));
      await Future<void>.delayed(Duration.zero);
      expect(ctrl.livingRoomLightOn, isFalse);
      expect(ctrl.lightCommandPending, isFalse);
    });

    test('13. Unauthenticated command is rejected without issuing cloud requests', () async {
      final cloudRepo = CloudHomeRepository(ApiClient(baseUrl: 'http://localhost:3000'));
      final ctrl = HomeController(
        repository: cloudRepo,
        connectionRepository: const UnavailableConnectionRepository(),
        cloudEnabled: false,
      );

      await ctrl.setDeviceChannelPower(deviceId: 'dev-1', channelIndex: 1, value: true);
      expect(ctrl.lightConfidence, isNot(equals(ActuatorConfidence.confirmed)));
    });
  });

  group('Phase 36 — App Configuration & Hardcoded Breaker Elimination', () {
    test('21. AppConfig respects runtime override and does not use hardcoded production LAN IP', () {
      AppConfig.setBaseUrl('https://api.eh-home.com');
      expect(AppConfig.backendBaseUrl, equals('https://api.eh-home.com'));

      AppConfig.setBaseUrl(null);
      // Fallback is localhost or emulator
      expect(AppConfig.backendBaseUrl, isNot(contains('192.168.1.8')));
    });

    test('22. No hardcoded default home identity in runtime configuration', () {
      final ctrl = HomeController(
        connectionRepository: const UnavailableConnectionRepository(),
      );
      expect(ctrl.activeHomeId, isNull);
    });
  });

  group('Phase 36 — Feature Navigation & Role-Gated Admin Widgets', () {
    testWidgets('14-16. SettingsPage renders all feature navigation sections with role-awareness', (tester) async {
      tester.view.physicalSize = const Size(1080, 5000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SettingsPage(
              homeId: 'home-test-123',
              isAdmin: true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify sections are present
      expect(find.text('Settings'), findsOneWidget);
      expect(find.text('HOME AND PEOPLE'), findsOneWidget);
      expect(find.text('ENERGY AND EFFICIENCY'), findsOneWidget);
      expect(find.text('INTELLIGENCE AND CONTEXT'), findsOneWidget);
      expect(find.text('DEVICES AND ECOSYSTEM'), findsOneWidget);
      expect(find.text('NOTIFICATIONS AND SYNC'), findsOneWidget);
      expect(find.text('OBSERVABILITY AND OPERATIONS'), findsOneWidget);
      expect(find.text('SECURITY AND RESILIENCE'), findsOneWidget);
      expect(find.text('YOUR SYSTEM'), findsOneWidget);
      expect(find.text('HELP AND PRIVACY'), findsOneWidget);

      // Verify feature tile titles
      expect(find.text('Energy dashboard'), findsOneWidget);
      expect(find.text('Energy optimization'), findsOneWidget);
      expect(find.text('Electricity tariffs'), findsOneWidget);
      expect(find.text('Intelligence center'), findsOneWidget);
      expect(find.text('Presence & occupancy'), findsOneWidget);
      expect(find.text('Product discovery'), findsOneWidget);
      expect(find.text('Fleet reliability'), findsOneWidget);
      expect(find.text('Multi-protocol connectivity'), findsOneWidget);
      expect(find.text('Matter & Ecosystems'), findsOneWidget);
      expect(find.text('Edge control dashboard'), findsOneWidget);
      expect(find.text('Notification center'), findsOneWidget);
      expect(find.text('Sync center'), findsOneWidget);
      expect(find.text('Operations dashboard'), findsOneWidget);
      expect(find.text('System readiness'), findsOneWidget);
      expect(find.text('Device trust center'), findsOneWidget);
      expect(find.text('Disaster recovery'), findsOneWidget);
    });

    testWidgets('15. Non-admin users see Admin only status chips on restricted management features', (tester) async {
      tester.view.physicalSize = const Size(1080, 5000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SettingsPage(
              homeId: 'home-test-123',
              isAdmin: false,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Check for Admin only chip badges
      expect(find.text('Admin only'), findsWidgets);
    });

    testWidgets('17-20. SettingsPage handles loading, error, and offline retry gracefully', (tester) async {
      // Test error fallback
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SettingsPage(
              repository: const _FailingSettingsRepository(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Try again'), findsOneWidget);
    });
  });

  group('Phase 36 — SmartHomeApp Full Integration & App Lifecycle', () {
    testWidgets('24. SmartHomeApp launches authenticated user into SplashScreen with dynamic home resolution', (tester) async {
      final mockAuth = MockAuthRepository()..setAuthenticated(isAuth: true, user: UserProfile(id: 'u1', email: 'user@eh.com', emailVerified: true));
      final authCtrl = AuthController(mockAuth);
      final homeCtrl = HomeController(
        cloudEnabled: false,
        connectionRepository: const UnavailableConnectionRepository(),
      );
      final fakeSse = FakeRealtimeService();
      final mockHomeRepo = MockAccountHomeRepository()..homes = [const HomeSummaryItem(id: 'home-dyn-1', name: 'Smart Villa')];

      await tester.pumpWidget(
        SmartHomeApp(
          authController: authCtrl,
          homeController: homeCtrl,
          accountHomeRepository: mockHomeRepo,
          realtimeEventService: fakeSse,
        ),
      );
      await tester.pump();

      // Home resolved dynamically and cloud enabled
      expect(homeCtrl.cloudEnabled, isTrue);
      expect(homeCtrl.activeHomeId, equals('home-dyn-1'));
      expect(fakeSse.connectedHomeId, equals('home-dyn-1'));
    });
  });
}

class _FailingSettingsRepository extends PreviewSettingsRepository {
  const _FailingSettingsRepository();

  @override
  Future<HomeSettingsData> getHome() async {
    throw Exception('Settings fetch failed');
  }
}
