import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_home_application_v1/app/home_controller.dart';
import 'package:smart_home_application_v1/core/api/api_client.dart';
import 'package:smart_home_application_v1/core/models/home_dashboard_models.dart';
import 'package:smart_home_application_v1/core/models/settings_models.dart';
import 'package:smart_home_application_v1/core/repositories/auth_repository.dart';
import 'package:smart_home_application_v1/core/repositories/settings_repository.dart';
import 'package:smart_home_application_v1/core/repositories/unavailable_connection_repository.dart';
import 'package:smart_home_application_v1/core/utils/iana_timezones.dart';
import 'package:smart_home_application_v1/features/auth/auth_controller.dart';
import 'package:smart_home_application_v1/features/auth/register_screen.dart';
import 'package:smart_home_application_v1/features/dashboard/presentation/home_page.dart';
import 'package:smart_home_application_v1/features/settings/presentation/home_details_page.dart';
import 'package:smart_home_application_v1/features/settings/presentation/settings_page_rebuild.dart';

class _FakeAuthApiClient extends ApiClient {
  _FakeAuthApiClient({
    this.onPost,
  }) : super(baseUrl: 'http://127.0.0.1:8080');

  final Future<dynamic> Function(String path, dynamic body)? onPost;

  @override
  Future<dynamic> post(
    String path, {
    dynamic body,
    Map<String, String>? headers,
    Duration? timeout,
  }) async {
    if (onPost != null) {
      return await onPost!(path, body);
    }
    return {};
  }
}

class _FakeSettingsRepository implements SettingsRepository {
  HomeSettingsDraft? lastDraft;

  @override
  Future<HomeSettingsData> getHome() async {
    return HomeSettingsData(
      id: 'home-123',
      name: 'Chandra Manor',
      ownerName: 'Chandra Prakash',
      location: 'Hyderabad',
      timezone: 'Asia/Kolkata',
      createdAt: DateTime.now(),
      lastChecked: DateTime.now(),
      preferences: const HomePreferences(
        temperatureUnit: 'Celsius (°C)',
        notificationsEnabled: true,
        timeFormat: '12-hour',
      ),
      connectionAvailability: HomeConnectionAvailability.connected,
      connectionTransport: 'Cloud + Wi-Fi',
    );
  }

  @override
  Future<List<HomeMember>> getMembers() async => [];

  @override
  Future<List<HomeInvitation>> getPendingInvitations() async => [];

  @override
  Future<List<DiscoveredRoomDevice>> getNearbyDevices() async => [];

  @override
  Future<SettingsOperationResult> updateHome(HomeSettingsDraft draft) async {
    lastDraft = draft;
    return SettingsOperationResult.success;
  }

  @override
  Future<SettingsOperationResult> invitePerson(String recipient) async => SettingsOperationResult.success;

  @override
  Future<SettingsOperationResult> invitePersonWithRole(String recipient, {String role = 'MEMBER'}) async => SettingsOperationResult.success;

  @override
  Future<SettingsOperationResult> cancelInvitation(String invitationId) async => SettingsOperationResult.success;

  @override
  Future<SettingsOperationResult> resendInvitation(String invitationId) async => SettingsOperationResult.success;

  @override
  Future<SettingsOperationResult> removeMember(String memberId) async => SettingsOperationResult.success;
}

void main() {
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
  });

  group('Phase 48 Account Profile, Username & Timezone Tests', () {
    testWidgets('1. RegisterScreen includes Full Name field and submits with fullName', (tester) async {
      String? sentFullName;
      String? sentEmail;

      final client = _FakeAuthApiClient(
        onPost: (path, body) async {
          if (path == '/api/v1/auth/register') {
            sentFullName = body['fullName'];
            sentEmail = body['email'];
            return {
              'id': 'usr-123',
              'email': body['email'],
              'fullName': body['fullName'],
              'role': 'USER',
              'emailVerified': false,
            };
          }
          if (path == '/api/v1/auth/login') {
            return {
              'accessToken': 'dummy-token',
              'refreshToken': 'dummy-refresh',
              'user': {
                'id': 'usr-123',
                'email': body['email'],
                'fullName': 'Chandra Prakash',
                'role': 'USER',
                'emailVerified': false,
              }
            };
          }
          return {};
        },
      );

      final authRepo = AuthRepository(client);
      final authCtrl = AuthController(authRepo);
      await authCtrl.restoreFuture;

      await tester.pumpWidget(
        MaterialApp(
          home: RegisterScreen(controller: authCtrl),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Full Name'), findsOneWidget);
      expect(find.text('Email Address'), findsOneWidget);
      expect(find.text('Password'), findsOneWidget);
      expect(find.text('Confirm Password'), findsOneWidget);

      await tester.enterText(find.widgetWithText(TextFormField, 'Full Name'), 'Chandra Prakash');
      await tester.enterText(find.widgetWithText(TextFormField, 'Email Address'), 'chandra@example.com');
      await tester.enterText(find.widgetWithText(TextFormField, 'Password'), 'Password123!');
      await tester.enterText(find.widgetWithText(TextFormField, 'Confirm Password'), 'Password123!');

      await tester.tap(find.widgetWithText(FilledButton, 'Create Account'));
      await tester.pumpAndSettle();

      expect(sentFullName, 'Chandra Prakash');
      expect(sentEmail, 'chandra@example.com');
      expect(authCtrl.state, AuthState.authenticated);
      expect(authCtrl.currentUser?.displayName, 'Chandra Prakash');
    });

    testWidgets('2. Duplicate signup conflict displays exact friendly error message', (tester) async {
      final client = _FakeAuthApiClient(
        onPost: (path, body) async {
          if (path == '/api/v1/auth/register') {
            throw ApiException(
              statusCode: 409,
              code: 'DUPLICATE_EMAIL',
              message: 'An account with this email already exists. Please sign in.',
            );
          }
          return {};
        },
      );

      final authRepo = AuthRepository(client);
      final authCtrl = AuthController(authRepo);
      await authCtrl.restoreFuture;

      await tester.pumpWidget(
        MaterialApp(
          home: RegisterScreen(controller: authCtrl),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.widgetWithText(TextFormField, 'Full Name'), 'Chandra Prakash');
      await tester.enterText(find.widgetWithText(TextFormField, 'Email Address'), 'chandra@example.com');
      await tester.enterText(find.widgetWithText(TextFormField, 'Password'), 'Password123!');
      await tester.enterText(find.widgetWithText(TextFormField, 'Confirm Password'), 'Password123!');

      await tester.tap(find.widgetWithText(FilledButton, 'Create Account'));
      await tester.pumpAndSettle();

      expect(authCtrl.state, AuthState.failure);
      expect(find.text('An account with this email already exists. Please sign in.'), findsOneWidget);
    });

    testWidgets('3. HomePage dynamically renders authenticated user display name without Pavan', (tester) async {
      final dashboard = HomeDashboardData.designPreview(
        lightOn: false,
        lightConfidence: ActuatorConfidence.confirmed,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HomePage(
              userName: 'Chandra',
              dashboard: dashboard,
              lightOn: false,
              lightCommandPending: false,
              alertAcknowledged: true,
              onLightChanged: (_) {},
              onAlertTap: () {},
              onConnectHome: () {},
              onShowRooms: () {},
              onOpenRoom: (_) {},
              onShowRoutines: () {},
              onShowActivity: () {},
              onShowSettings: () {},
              onShowInsights: () {},
              onCustomizeControls: () {},
              onUnavailableControl: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byWidgetPredicate((w) => w is RichText && w.text.toPlainText().contains('Chandra')),
        findsOneWidget,
      );
      expect(
        find.byWidgetPredicate((w) => w is RichText && w.text.toPlainText().contains('Pavan')),
        findsNothing,
      );
    });

    testWidgets('4. SettingsPage renders real 0 rooms and 0 devices for newly created home without preview fallback', (tester) async {
      final homeCtrl = HomeController(
        connectionRepository: const UnavailableConnectionRepository(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SettingsPage(
              homeController: homeCtrl,
              repository: _FakeSettingsRepository(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify that "4 rooms" and "8 devices" preview fallback does NOT appear
      expect(find.text('4 rooms'), findsNothing);
      expect(find.text('8 devices'), findsNothing);
      expect(find.text('0 rooms'), findsOneWidget);
      expect(find.text('0 devices'), findsOneWidget);
    });

    testWidgets('5. IanaTimezones contains standard IANA timezones and modal picker filters correctly', (tester) async {
      expect(IanaTimezones.all.contains('Asia/Kolkata'), isTrue);
      expect(IanaTimezones.all.contains('America/New_York'), isTrue);
      expect(IanaTimezones.all.contains('Europe/London'), isTrue);
      expect(IanaTimezones.all.contains('UTC'), isTrue);

      String? chosenTz;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  chosenTz = await showIanaTimezonePicker(
                    context,
                    initialValue: 'UTC',
                  );
                },
                child: const Text('Open Picker'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open Picker'));
      await tester.pumpAndSettle();

      expect(find.text('Select Timezone'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);

      // Search for Kolkata
      await tester.enterText(find.byType(TextField), 'Kolkata');
      await tester.pumpAndSettle();

      expect(find.text('Asia/Kolkata'), findsOneWidget);

      // Select Asia/Kolkata
      await tester.tap(find.text('Asia/Kolkata'));
      await tester.pumpAndSettle();

      expect(chosenTz, 'Asia/Kolkata');
    });

    testWidgets('6. HomeDetailsPage updates timezone via showIanaTimezonePicker', (tester) async {
      final fakeRepo = _FakeSettingsRepository();
      final homeData = await fakeRepo.getHome();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HomeDetailsPage(
              home: homeData,
              repository: fakeRepo,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Time zone'), findsOneWidget);
      expect(find.text('Asia/Kolkata'), findsOneWidget);

      // Tap timezone tile
      await tester.tap(find.text('Time zone'));
      await tester.pumpAndSettle();

      expect(find.text('Select Timezone'), findsOneWidget);

      // Search for New_York
      await tester.enterText(find.byType(TextField), 'New_York');
      await tester.pumpAndSettle();

      await tester.tap(find.text('America/New_York'));
      await tester.pumpAndSettle();

      expect(fakeRepo.lastDraft?.timezone, 'America/New_York');
      expect(find.text('Timezone updated to America/New_York.'), findsOneWidget);
    });
  });
}
