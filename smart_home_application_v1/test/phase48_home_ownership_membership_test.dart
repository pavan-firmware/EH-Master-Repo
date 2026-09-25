import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_home_application_v1/app/home_controller.dart';
import 'package:smart_home_application_v1/core/api/api_client.dart';
import 'package:smart_home_application_v1/core/config/device_connection_config.dart';
import 'package:smart_home_application_v1/core/models/access_control_models.dart';
import 'package:smart_home_application_v1/core/models/device_models.dart';
import 'package:smart_home_application_v1/core/models/settings_models.dart';
import 'package:smart_home_application_v1/core/repositories/account_home_repository.dart';
import 'package:smart_home_application_v1/core/repositories/cloud_settings_repository.dart';
import 'package:smart_home_application_v1/core/repositories/connection_repository.dart';
import 'package:smart_home_application_v1/core/repositories/home_repository.dart';
import 'package:smart_home_application_v1/core/repositories/settings_repository.dart';
import 'package:smart_home_application_v1/core/theme/app_theme.dart';
import 'package:smart_home_application_v1/features/invitations/presentation/pending_invitations_dialog.dart';
import 'package:smart_home_application_v1/features/onboarding/presentation/home_onboarding_screen.dart';
import 'package:smart_home_application_v1/features/settings/presentation/people_page.dart';

class MockApiClient extends ApiClient {
  MockApiClient({
    this.mockGet,
    this.mockPost,
    this.mockPatch,
    this.mockDelete,
  }) : super(baseUrl: 'http://127.0.0.1:3000');

  final Future<dynamic> Function(String endpoint)? mockGet;
  final Future<dynamic> Function(String endpoint, {Map<String, dynamic>? body})? mockPost;
  final Future<dynamic> Function(String endpoint, {Map<String, dynamic>? body})? mockPatch;
  final Future<dynamic> Function(String endpoint, {Map<String, dynamic>? body})? mockDelete;

  @override
  Future<dynamic> get(String endpoint, {Map<String, String>? headers}) async {
    if (mockGet != null) return mockGet!(endpoint);
    return {'success': true, 'data': []};
  }

  @override
  Future<dynamic> post(
    String endpoint, {
    Map<String, dynamic>? body,
    Map<String, String>? headers,
  }) async {
    if (mockPost != null) return mockPost!(endpoint, body: body);
    return {'success': true, 'data': {'id': 'mock-created-id', ...?body}};
  }

  @override
  Future<dynamic> patch(
    String endpoint, {
    Map<String, dynamic>? body,
    Map<String, String>? headers,
  }) async {
    if (mockPatch != null) return mockPatch!(endpoint, body: body);
    return {'success': true, 'data': {'id': 'mock-updated-id', ...?body}};
  }

  @override
  Future<dynamic> delete(
    String endpoint, {
    Map<String, dynamic>? body,
    Map<String, String>? headers,
  }) async {
    if (mockDelete != null) return mockDelete!(endpoint, body: body);
    return {'success': true, 'data': {'deleted': true}};
  }
}

class FakeHomeRepository implements HomeRepository {
  const FakeHomeRepository();

  @override
  Future<List<DeviceSnapshot>> getDevices({String? homeId}) async => [];

  @override
  Future<CommandReceipt> sendCommand({
    required String deviceId,
    required String action,
    required Map<String, Object?> parameters,
    required String idempotencyKey,
  }) async => const CommandReceipt(
    commandId: 'cmd-1',
    state: CommandState.succeeded,
  );

  @override
  Future<void> claimDevice({required String deviceId, required String homeId, String? roomId, String? customName, Map<String, String>? channelLabels}) async {}

  @override
  Future<void> registerDevice({required String deviceId, required String serialNumber, required String productVariantId, required String hardwareRevision, required String firmwareFamily, String firmwareVersion = '1.0.0'}) async {}

  @override
  Future<List<Map<String, dynamic>>> getRooms({String? homeId}) async => [];

  @override
  Future<Map<String, dynamic>> createRoom({required String name, String? homeId, String? iconKey}) async => {'id': 'r-1', 'name': name};

  @override
  Future<FirmwareRelease?> getAvailableRelease() async => null;

  @override
  Stream<FirmwareJob> watchFirmwareJob() => const Stream.empty();
}

class FakeConnectionRepository implements ConnectionRepository {
  const FakeConnectionRepository();

  @override
  Future<ConnectionResult> connect({required DeviceConnectionConfig config}) async =>
      const ConnectionResult(success: true, message: 'Connected');
}

class FakeAccountHomeRepository implements AccountHomeRepository {
  List<HomeSummaryItem> homes = [];
  List<HomeInviteItem> pendingInvites = [];
  bool shouldFail = false;

  @override
  Future<List<HomeSummaryItem>> listHomes() async {
    if (shouldFail) throw Exception('Network failure');
    return homes;
  }

  @override
  Future<HomeSummaryItem> createHome({
    required String name,
    String? timezone,
    String? address,
  }) async {
    if (shouldFail) throw Exception('Creation failed');
    final home = HomeSummaryItem(
      id: 'created-home-101',
      name: name,
      role: 'OWNER',
      deviceCount: 0,
      roomCount: 0,
      timezone: timezone ?? 'UTC',
      address: address,
    );
    homes.add(home);
    return home;
  }

  @override
  Future<List<HomeInviteItem>> listPendingInvitations() async => pendingInvites;

  @override
  Future<void> acceptInvitation(String inviteCode) async {
    pendingInvites.removeWhere((i) => i.inviteCode == inviteCode);
  }

  @override
  Future<void> rejectInvitation(String inviteCode) async {
    pendingInvites.removeWhere((i) => i.inviteCode == inviteCode);
  }

  @override
  Future<void> leaveHome(String homeId) async {
    homes.removeWhere((h) => h.id == homeId);
  }

  @override
  Future<UserAccountProfile> getAccountProfile() async => const UserAccountProfile(
    id: 'u-1',
    email: 'test@example.com',
    fullName: 'Test User',
    timezone: 'UTC',
    createdAt: '2026-09-15T00:00:00Z',
  );

  @override
  Future<UserAccountProfile> updateAccountProfile({String? fullName, String? phoneNumber, String? avatarUrl, String? timezone}) async => getAccountProfile();

  @override
  Future<void> changePassword({required String oldPassword, required String newPassword}) async {}

  @override
  Future<List<AccountSessionItem>> listSessions() async => [];

  @override
  Future<void> revokeSession(String sessionId) async {}

  @override
  Future<void> deleteAccount({required String password}) async {}

  @override
  Future<HomeSummaryItem> getHomeDetails(String homeId) async => homes.firstWhere((h) => h.id == homeId);

  @override
  Future<HomeSummaryItem> updateHome(String homeId, {String? name, String? timezone, String? address}) async => getHomeDetails(homeId);

  @override
  Future<void> deleteHome(String homeId) async {
    homes.removeWhere((h) => h.id == homeId);
  }

  @override
  Future<void> transferOwnership(String homeId, {required String newOwnerId}) async {}

  @override
  Future<List<HomeMemberItem>> listMembers(String homeId) async => [];

  @override
  Future<void> updateMemberRole(String homeId, {required String userId, required String role}) async {}

  @override
  Future<void> removeMember(String homeId, {required String userId}) async {}

  @override
  Future<HomeInviteItem> createInvitation(String homeId, {required String email, required String role}) async => HomeInviteItem(
    id: 'inv-1',
    homeId: homeId,
    homeName: 'Test Home',
    inviterUserId: 'u-owner',
    inviteeEmail: email,
    role: role,
    status: 'PENDING',
    inviteCode: 'CODE123',
    expiresAt: '2026-09-17T00:00:00Z',
    createdAt: '2026-09-15T00:00:00Z',
  );

  @override
  Future<List<HomeInviteItem>> listHomeInvitations(String homeId) async => [];

  @override
  Future<void> revokeInvitation(String homeId, {required String inviteId}) async {}
}

void main() {
  group('Phase 48: Home Ownership, Membership, Invitation & RBAC Models', () {
    test('HomeMemberRole labels and mapping handles all canonical roles', () {
      expect(HomeMemberRole.owner.label, equals('Owner'));
      expect(HomeMemberRole.admin.label, equals('Home Admin'));
      expect(HomeMemberRole.member.label, equals('Member'));
      expect(HomeMemberRole.guest.label, equals('Guest'));

      expect(HomeMemberRole.values.firstWhere((r) => r.name.toLowerCase() == 'owner'), equals(HomeMemberRole.owner));
      expect(HomeMemberRole.values.firstWhere((r) => r.name.toLowerCase() == 'admin'), equals(HomeMemberRole.admin));
      expect(HomeMemberRole.values.firstWhere((r) => r.name.toLowerCase() == 'member'), equals(HomeMemberRole.member));
      expect(HomeMemberRole.values.firstWhere((r) => r.name.toLowerCase() == 'guest'), equals(HomeMemberRole.guest));
    });

    test('HomeInvitation model constructor retains role and code', () {
      const invitation = HomeInvitation(
        id: 'inv-123',
        recipientName: 'Alice Smith',
        initials: 'AS',
        invitedLabel: 'Invited 2 hours ago',
        expiresLabel: 'Expires in 2 days',
        role: HomeMemberRole.admin,
        code: 'ABC890',
      );

      expect(invitation.id, equals('inv-123'));
      expect(invitation.recipientName, equals('Alice Smith'));
      expect(invitation.role, equals(HomeMemberRole.admin));
      expect(invitation.code, equals('ABC890'));
      expect(invitation.role.label, equals('Home Admin'));
    });

    test('CloudSettingsRepository extracts members and invitations cleanly', () async {
      final client = MockApiClient(
        mockGet: (endpoint) async {
          if (endpoint.contains('/members')) {
            return {
              'success': true,
              'data': [
                {
                  'id': 'mem-1',
                  'user_id': 'u-1',
                  'name': 'Pavan Owner',
                  'email': 'pavan@example.com',
                  'role': 'OWNER',
                  'joined_at': '2026-09-15T08:00:00Z',
                },
                {
                  'id': 'mem-2',
                  'user_id': 'u-2',
                  'name': 'Sarah Admin',
                  'email': 'sarah@example.com',
                  'role': 'ADMIN',
                  'joined_at': '2026-09-15T09:00:00Z',
                }
              ]
            };
          }
          if (endpoint.contains('/invitations')) {
            return {
              'success': true,
              'data': [
                {
                  'id': 'inv-1',
                  'invitee_email': 'guest@example.com',
                  'role': 'GUEST',
                  'status': 'PENDING',
                  'invite_code': 'GUEST1',
                  'created_at': '2026-09-15T09:00:00Z',
                }
              ]
            };
          }
          return {'success': true, 'data': []};
        },
      );

      final repo = CloudSettingsRepository(client, activeHomeId: 'home-101');
      final members = await repo.getMembers();
      final invitations = await repo.getPendingInvitations();

      expect(members.length, equals(2));
      expect(members[0].displayName, contains('Pavan Owner'));
      expect(members[0].role, equals(HomeMemberRole.owner));
      expect(members[1].displayName, contains('Sarah Admin'));
      expect(members[1].role, equals(HomeMemberRole.admin));

      expect(invitations.length, equals(1));
      expect(invitations[0].recipientName, equals('guest@example.com'));
      expect(invitations[0].role, equals(HomeMemberRole.guest));
      expect(invitations[0].code, equals('GUEST1'));
    });
  });

  group('Phase 48: UI Onboarding & Invitations Widgets', () {
    testWidgets('HomeOnboardingScreen renders properly and handles creation', (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final repo = FakeAccountHomeRepository();
      final controller = HomeController(
        repository: const FakeHomeRepository(),
        connectionRepository: FakeConnectionRepository(),
        cloudEnabled: false,
      );
      String? createdHomeId;

      await tester.pumpWidget(
        MaterialApp(
          theme: EHAppTheme.lightTheme,
          home: HomeOnboardingScreen(
            accountHomeRepository: repo,
            homeController: controller,
            onHomeCreated: (id) => createdHomeId = id,
          ),
        ),
      );

      // Verify zero-home onboarding UI
      expect(find.text('Welcome to EH Home'), findsOneWidget);
      expect(find.text('Home Name'), findsOneWidget);
      expect(find.text('Create Home'), findsOneWidget);

      // Enter home name and tap create
      await tester.enterText(find.byType(TextFormField).first, 'Pavan Villa');
      await tester.tap(find.text('Create Home'));
      await tester.pumpAndSettle();

      // Verify success screen
      expect(find.text('Home Created!'), findsOneWidget);
      expect(find.textContaining('You are now the Owner of "Pavan Villa"'), findsOneWidget);

      // Tap continue
      await tester.tap(find.text('Continue to Dashboard'));
      expect(createdHomeId, equals('created-home-101'));
      expect(controller.activeHomeId, equals('created-home-101'));
    });

    testWidgets('PendingInvitationsDialog displays invitations and handles accept', (tester) async {
      final repo = FakeAccountHomeRepository();
      repo.pendingInvites.add(
        const HomeInviteItem(
          id: 'inv-1',
          homeId: 'home-88',
          homeName: 'Grand Manor',
          inviterUserId: 'u-suresh',
          inviteeEmail: 'pavan@example.com',
          role: 'HOME_ADMIN',
          status: 'PENDING',
          inviteCode: '889900',
          expiresAt: '2026-09-17T00:00:00Z',
          createdAt: '2026-09-15T00:00:00Z',
        ),
      );

      String? acceptedHomeId;

      await tester.pumpWidget(
        MaterialApp(
          theme: EHAppTheme.lightTheme,
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () {
                  showDialog(
                    context: ctx,
                    builder: (_) => PendingInvitationsDialog(
                      accountHomeRepository: repo,
                      onAccepted: (homeId) {
                        acceptedHomeId = homeId;
                      },
                    ),
                  );
                },
                child: const Text('Open Invitations'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Invitations'));
      await tester.pumpAndSettle();

      expect(find.text('Home Invitations'), findsOneWidget);
      expect(find.text('Grand Manor'), findsOneWidget);
      expect(find.text('Accept'), findsOneWidget);

      await tester.tap(find.text('Accept'));
      await tester.pumpAndSettle();

      expect(acceptedHomeId, equals('home-88'));
    });

    testWidgets('PeoplePage renders members, roles, and supports inviting with roles', (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      const repo = PreviewSettingsRepository();
      final home = await repo.getHome();

      await tester.pumpWidget(
        MaterialApp(
          theme: EHAppTheme.lightTheme,
          home: PeoplePage(
            repository: repo,
            home: home,
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('People at home'), findsOneWidget);
      expect(find.text('PEOPLE WITH ACCESS'), findsOneWidget);
      expect(find.text('Pavan (You)'), findsOneWidget);
      expect(find.text('Owner'), findsWidgets);
    });
  });
}
