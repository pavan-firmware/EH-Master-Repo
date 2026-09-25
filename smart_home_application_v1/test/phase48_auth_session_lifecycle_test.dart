import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:smart_home_application_v1/app/app.dart';
import 'package:smart_home_application_v1/app/home_controller.dart';
import 'package:smart_home_application_v1/core/api/api_client.dart';
import 'package:smart_home_application_v1/core/api/sse_client.dart';
import 'package:smart_home_application_v1/core/models/access_control_models.dart';
import 'package:smart_home_application_v1/core/repositories/account_home_repository.dart';
import 'package:smart_home_application_v1/core/repositories/auth_repository.dart';
import 'package:smart_home_application_v1/core/repositories/unavailable_connection_repository.dart';
import 'package:smart_home_application_v1/core/services/realtime_event_service.dart';
import 'package:smart_home_application_v1/features/auth/auth_controller.dart';
import 'package:smart_home_application_v1/features/auth/login_screen.dart';
import 'package:smart_home_application_v1/features/onboarding/presentation/home_onboarding_screen.dart';

class MockLifecycleApiClient extends ApiClient {
  MockLifecycleApiClient({
    this.postHandler,
    this.getHandler,
    this.deleteHandler,
  }) : super(baseUrl: 'http://127.0.0.1:3000');

  Future<dynamic> Function(String path, Map<String, dynamic>? body)? postHandler;
  Future<dynamic> Function(String path)? getHandler;
  Future<dynamic> Function(String path, Map<String, dynamic>? body)? deleteHandler;

  @override
  Future<dynamic> post(String path, {Map<String, dynamic>? body}) async {
    if (postHandler != null) return postHandler!(path, body);
    return {'success': true, 'data': {}};
  }

  @override
  Future<dynamic> get(String path) async {
    if (getHandler != null) return getHandler!(path);
    return {'success': true, 'data': {}};
  }

  @override
  Future<dynamic> delete(String path, {Map<String, dynamic>? body}) async {
    if (deleteHandler != null) return deleteHandler!(path, body);
    return {'success': true, 'data': {}};
  }
}

class MockLifecycleAccountHomeRepository implements AccountHomeRepository {
  List<HomeSummaryItem> homes = [];
  Completer<void>? listHomesCompleter;

  @override
  Future<List<HomeSummaryItem>> listHomes() async {
    if (listHomesCompleter != null) {
      await listHomesCompleter!.future;
    }
    return homes;
  }

  @override
  Future<HomeSummaryItem> createHome({required String name, String? timezone, String? address}) async {
    final h = HomeSummaryItem(id: 'created-${DateTime.now().millisecondsSinceEpoch}', name: name);
    homes.add(h);
    return h;
  }

  @override
  Future<HomeSummaryItem> getHomeDetails(String homeId) async =>
      homes.firstWhere((h) => h.id == homeId, orElse: () => HomeSummaryItem(id: homeId, name: 'Home'));

  @override
  Future<HomeSummaryItem> updateHome(String homeId, {String? name, String? timezone, String? address}) async =>
      HomeSummaryItem(id: homeId, name: name ?? 'Updated');

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

class TestRealtimeService extends RealtimeEventService {
  TestRealtimeService() : super(SseClient(ApiClient(baseUrl: 'http://localhost:3000')));

  final _controller = StreamController<SSEEventEnvelope>.broadcast();
  String? connectedHomeId;
  int connectCalls = 0;
  int disconnectCalls = 0;

  @override
  Stream<SSEEventEnvelope> get events => _controller.stream;

  @override
  void connect(String homeId) {
    connectedHomeId = homeId;
    connectCalls++;
  }

  @override
  void disconnect() {
    connectedHomeId = null;
    disconnectCalls++;
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

class LifecycleMockAuthRepository extends AuthRepository {
  LifecycleMockAuthRepository(super.apiClient);

  bool _isAuth = false;
  UserProfile? _user;
  Future<void> Function()? mockRestore;
  Future<void> Function(String email, String password)? mockLogin;
  Future<void> Function()? mockLogout;

  @override
  bool get isAuthenticated => _isAuth;

  @override
  UserProfile? get currentUser => _user;

  void setAuthenticatedManual(bool auth, UserProfile? user) {
    _isAuth = auth;
    _user = user;
  }

  @override
  Future<void> restoreSession() async {
    if (mockRestore != null) {
      await mockRestore!();
      return;
    }
  }

  @override
  Future<void> login(String email, String password) async {
    if (mockLogin != null) {
      await mockLogin!(email, password);
      return;
    }
    _isAuth = true;
    _user = UserProfile(id: 'u-login', email: email, emailVerified: true);
  }

  @override
  Future<void> logout() async {
    _isAuth = false;
    _user = null;
    if (mockLogout != null) {
      await mockLogout!();
    }
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Phase 48: Authentication & Session Lifecycle Hardening', () {
    test('1. ApiClient exempts /auth/ endpoints from onRefreshToken and does not throw Session expired on login 401', () async {
      int refreshCalls = 0;
      final client = MockLifecycleApiClient();
      client.onRefreshToken = () async {
        refreshCalls++;
        return false;
      };

      // Verify that calling login endpoint with 401 raises ApiException without calling onRefreshToken
      client.postHandler = (path, body) async {
        if (path == '/api/v1/auth/login') {
          throw ApiException(
            statusCode: 401,
            message: 'Invalid email or password',
            code: 'INVALID_CREDENTIALS',
          );
        }
        return {'data': {}};
      };

      final repo = LifecycleMockAuthRepository(client);
      repo.mockLogin = (email, password) async {
        await client.post('/api/v1/auth/login', body: {'email': email, 'password': password});
      };
      final controller = AuthController(repo);
      await controller.restoreFuture;

      final success = await controller.login('invalid@example.com', 'wrongpassword');
      expect(success, isFalse);
      expect(refreshCalls, equals(0));
      expect(controller.state, equals(AuthState.failure));
      expect(controller.errorMessage, anyOf(contains('Invalid email or password'), contains('Incorrect email or password')));
      expect(controller.errorMessage, isNot(contains('Session expired')));
    });

    test('2. Error semantics map 429, 404, and network errors correctly', () async {
      final client = MockLifecycleApiClient();
      final repo = LifecycleMockAuthRepository(client);
      repo.mockLogin = (email, password) async {
        await client.post('/api/v1/auth/login', body: {'email': email, 'password': password});
      };
      final controller = AuthController(repo);
      await controller.restoreFuture;

      // 429 Rate Limit
      client.postHandler = (path, body) async {
        throw ApiException(
          statusCode: 429,
          code: 'TOO_MANY_REQUESTS',
          message: 'Rate limit exceeded',
        );
      };
      await controller.login('spam@example.com', 'pass');
      expect(controller.errorMessage, equals('Too many login attempts. Please try again later.'));

      // Network Timeout
      client.postHandler = (path, body) async {
        throw ApiException(
          statusCode: 0,
          message: 'Network error: Connection refused',
        );
      };
      await controller.login('offline@example.com', 'pass');
      expect(controller.errorMessage, equals('Unable to connect. Check your connection and try again.'));

      // 404 User Not Found
      client.postHandler = (path, body) async {
        throw ApiException(
          statusCode: 404,
          code: 'USER_NOT_FOUND',
          message: 'Account not found',
        );
      };
      await controller.login('notfound@example.com', 'pass');
      expect(controller.errorMessage, equals('Account not found. Please check your email or create an account.'));
    });

    test('3. Operation generation tracking prevents slow restoreSession from overwriting manual login', () async {
      final client = MockLifecycleApiClient();
      final repo = LifecycleMockAuthRepository(client);

      final restoreCompleter = Completer<void>();
      repo.mockRestore = () => restoreCompleter.future;

      final controller = AuthController(repo);
      expect(controller.state, equals(AuthState.unknown));

      // User initiates manual login while restoreSession is still pending
      repo.mockLogin = (email, password) async {
        repo.setAuthenticatedManual(true, UserProfile(id: 'u-fast', email: email, emailVerified: true));
      };

      final loginFuture = controller.login('user@example.com', 'password123');
      expect(controller.state, equals(AuthState.authenticating));

      await loginFuture;
      expect(controller.state, equals(AuthState.authenticated));
      expect(controller.currentUser?.email, equals('user@example.com'));

      // Late completion from restoreSession arrives
      restoreCompleter.complete();
      await Future<void>.delayed(Duration.zero);

      // Verify controller remains authenticated and was NOT overwritten
      expect(controller.state, equals(AuthState.authenticated));
      expect(controller.currentUser?.email, equals('user@example.com'));
    });

    testWidgets('4. Invalid login never renders HomeOnboardingScreen or flashes onboarding', (tester) async {
      final client = MockLifecycleApiClient();
      final repo = LifecycleMockAuthRepository(client);
      repo.mockLogin = (email, password) async {
        throw ApiException(
          statusCode: 401,
          code: 'INVALID_CREDENTIALS',
          message: 'Invalid email or password',
        );
      };

      final authCtrl = AuthController(repo);
      await authCtrl.restoreFuture;

      final homeCtrl = HomeController(cloudEnabled: false, connectionRepository: const UnavailableConnectionRepository());
      final accountHomeRepo = MockLifecycleAccountHomeRepository()..homes = [];

      await tester.pumpWidget(
        SmartHomeApp(
          authController: authCtrl,
          homeController: homeCtrl,
          accountHomeRepository: accountHomeRepo,
          apiClient: client,
        ),
      );
      await tester.pumpAndSettle();

      // Ensure we are on LoginScreen
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.byType(HomeOnboardingScreen), findsNothing);

      // Attempt invalid login
      await authCtrl.login('wrong@example.com', 'badpass');
      await tester.pump();

      // Verify still on LoginScreen with correct error and zero onboarding presence
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.byType(HomeOnboardingScreen), findsNothing);
      expect(find.text('Invalid email or password'), findsOneWidget);
      expect(find.text('Session expired'), findsNothing);
    });

    testWidgets('5. Home onboarding guard shows progress while resolving homes, never flashes onboarding prematurely', (tester) async {
      final client = MockLifecycleApiClient();
      final repo = LifecycleMockAuthRepository(client);
      repo.setAuthenticatedManual(true, UserProfile(id: 'u-valid', email: 'valid@example.com', emailVerified: true, fullName: 'Valid User'));

      final authCtrl = AuthController(repo);
      final homeCtrl = HomeController(cloudEnabled: false, connectionRepository: const UnavailableConnectionRepository());
      final accountHomeRepo = MockLifecycleAccountHomeRepository();

      // Delay home listing to inspect in-flight state
      final completer = Completer<void>();
      accountHomeRepo.listHomesCompleter = completer;

      await tester.pumpWidget(
        SmartHomeApp(
          authController: authCtrl,
          homeController: homeCtrl,
          accountHomeRepository: accountHomeRepo,
          apiClient: client,
        ),
      );
      await tester.pump();

      // While resolving homes, must show CircularProgressIndicator, never HomeOnboardingScreen
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byType(HomeOnboardingScreen), findsNothing);

      // Complete resolution with 0 homes -> now cleanly shows HomeOnboardingScreen
      completer.complete();
      await tester.pumpAndSettle();

      expect(find.byType(HomeOnboardingScreen), findsOneWidget);
    });

    testWidgets('6. Explicit Sign Out immediately transitions to LoginScreen, resets controller and disconnects realtime', (tester) async {
      final client = MockLifecycleApiClient();
      final repo = LifecycleMockAuthRepository(client);
      repo.setAuthenticatedManual(true, UserProfile(id: 'u1', email: 'user@example.com', emailVerified: true, fullName: 'Alpha User'));

      final authCtrl = AuthController(repo);
      final homeCtrl = HomeController(cloudEnabled: false, connectionRepository: const UnavailableConnectionRepository());
      final realtimeService = TestRealtimeService();
      final accountHomeRepo = MockLifecycleAccountHomeRepository()
        ..homes = [const HomeSummaryItem(id: 'home-alpha-101', name: 'Alpha Manor')];

      await tester.pumpWidget(
        SmartHomeApp(
          authController: authCtrl,
          homeController: homeCtrl,
          accountHomeRepository: accountHomeRepo,
          realtimeEventService: realtimeService,
          apiClient: client,
        ),
      );
      await tester.pumpAndSettle();

      expect(homeCtrl.cloudEnabled, isTrue);
      expect(homeCtrl.activeHomeId, equals('home-alpha-101'));
      expect(realtimeService.connectedHomeId, equals('home-alpha-101'));

      // Perform immediate sign out
      await authCtrl.logout();
      await tester.pumpAndSettle();

      // Verified: Root returned to LoginScreen
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.byType(HomeOnboardingScreen), findsNothing);

      // Verified: Session and realtime state cleaned deterministically
      expect(homeCtrl.cloudEnabled, isFalse);
      expect(homeCtrl.activeHomeId, isNull);
      expect(realtimeService.connectedHomeId, isNull);
      expect(authCtrl.state, equals(AuthState.unauthenticated));
    });

    testWidgets('7. Security isolation: User A login -> logout -> User B login does not leak data or activeHomeId', (tester) async {
      final client = MockLifecycleApiClient();
      final repo = LifecycleMockAuthRepository(client);
      final authCtrl = AuthController(repo);
      final homeCtrl = HomeController(cloudEnabled: false, connectionRepository: const UnavailableConnectionRepository());
      final realtimeService = TestRealtimeService();
      final accountHomeRepo = MockLifecycleAccountHomeRepository();

      // --- USER A LOGS IN ---
      repo.setAuthenticatedManual(true, UserProfile(id: 'user-a-id', email: 'userA@eh.com', emailVerified: true, fullName: 'User A'));
      accountHomeRepo.homes = [const HomeSummaryItem(id: 'home-user-a', name: 'User A Villa')];

      await tester.pumpWidget(
        SmartHomeApp(
          authController: authCtrl,
          homeController: homeCtrl,
          accountHomeRepository: accountHomeRepo,
          realtimeEventService: realtimeService,
          apiClient: client,
        ),
      );
      await tester.pumpAndSettle();

      expect(homeCtrl.activeHomeId, equals('home-user-a'));
      expect(realtimeService.connectedHomeId, equals('home-user-a'));

      // --- USER A LOGS OUT ---
      await authCtrl.logout();
      await tester.pumpAndSettle();

      expect(find.byType(LoginScreen), findsOneWidget);
      expect(homeCtrl.activeHomeId, isNull);
      expect(realtimeService.connectedHomeId, isNull);

      // --- USER B LOGS IN ---
      repo.setAuthenticatedManual(true, UserProfile(id: 'user-b-id', email: 'userB@eh.com', emailVerified: true, fullName: 'User B'));
      accountHomeRepo.homes = [const HomeSummaryItem(id: 'home-user-b', name: 'User B Apartment')];

      await authCtrl.login('userB@eh.com', 'passwordB');
      await tester.pumpAndSettle();

      // Verify User B has separate home and User A data is not retained
      expect(homeCtrl.activeHomeId, equals('home-user-b'));
      expect(homeCtrl.activeHomeId, isNot(equals('home-user-a')));
      expect(realtimeService.connectedHomeId, equals('home-user-b'));
    });
  });
}
