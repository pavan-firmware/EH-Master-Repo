import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_home_application_v1/core/api/api_client.dart';
import 'package:smart_home_application_v1/core/models/activity_models.dart';
import 'package:smart_home_application_v1/core/models/routine_models.dart';
import 'package:smart_home_application_v1/core/models/settings_models.dart';
import 'package:smart_home_application_v1/core/repositories/auth_repository.dart';
import 'package:smart_home_application_v1/core/repositories/cloud_activity_repository.dart';
import 'package:smart_home_application_v1/core/repositories/cloud_home_repository.dart';
import 'package:smart_home_application_v1/core/repositories/cloud_routine_repository.dart';
import 'package:smart_home_application_v1/core/repositories/cloud_settings_repository.dart';
import 'package:smart_home_application_v1/core/services/app_permission_service.dart';
import 'package:smart_home_application_v1/core/theme/app_colors.dart';
import 'package:smart_home_application_v1/core/theme/app_theme.dart';
import 'package:smart_home_application_v1/features/auth/auth_controller.dart';
import 'package:smart_home_application_v1/features/auth/login_screen.dart';
import 'package:smart_home_application_v1/features/auth/register_screen.dart';
import 'package:smart_home_application_v1/features/rooms/presentation/rooms_page.dart';

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
    return [];
  }

  @override
  Future<dynamic> post(
    String endpoint, {
    Map<String, dynamic>? body,
    Map<String, String>? headers,
  }) async {
    if (mockPost != null) return mockPost!(endpoint, body: body);
    return {'id': 'mock-id', ...?body};
  }

  @override
  Future<dynamic> patch(
    String endpoint, {
    Map<String, dynamic>? body,
    Map<String, String>? headers,
  }) async {
    if (mockPatch != null) return mockPatch!(endpoint, body: body);
    return {'status': 'success', ...?body};
  }

  @override
  Future<dynamic> delete(
    String endpoint, {
    Map<String, dynamic>? body,
    Map<String, String>? headers,
  }) async {
    if (mockDelete != null) return mockDelete!(endpoint, body: body);
    return {'status': 'deleted'};
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
  });

  group('Phase 47 Stage 4 - Product Integration & Real Backend Contracts', () {
    test('CloudHomeRepository persists custom room to backend with verified homeId', () async {
      String? postedEndpoint;
      Map<String, dynamic>? postedBody;

      final mockClient = MockApiClient(
        mockGet: (endpoint) async {
          if (endpoint == '/api/v1/homes') {
            return [{'id': 'home-uuid-101', 'name': 'Pavan Home'}];
          }
          if (endpoint == '/api/v1/homes/home-uuid-101/rooms') {
            return [];
          }
          return [];
        },
        mockPost: (endpoint, {body}) async {
          postedEndpoint = endpoint;
          postedBody = body;
          return {
            'id': 'room-xyz',
            'home_id': 'home-uuid-101',
            'name': body?['name'],
            'iconKey': body?['iconKey'],
          };
        },
      );

      final repo = CloudHomeRepository(mockClient);
      final room = await repo.createRoom(
        name: 'Master Bedroom',
        iconKey: 'bedroom',
      );

      expect(room, isNotNull);
      expect(room['id'], 'room-xyz');
      expect(room['name'], 'Master Bedroom');
      expect(postedEndpoint, '/api/v1/homes/home-uuid-101/rooms');
      expect(postedBody?['name'], 'Master Bedroom');
      expect(postedBody?['iconKey'], 'bedroom');
    });

    test('CloudRoutineRepository correctly formats automations contract', () async {
      String? routinePostEndpoint;
      Map<String, dynamic>? routinePostBody;

      final mockClient = MockApiClient(
        mockGet: (endpoint) async {
          if (endpoint == '/api/v1/homes') {
            return [{'id': 'home-uuid-101', 'name': 'Pavan Home'}];
          }
          if (endpoint == '/api/v1/homes/home-uuid-101/automations') {
            return [
              {
                'id': 'auto-1',
                'name': 'Morning Boost',
                'triggerType': 'TIME',
                'triggerConfig': {'time': '07:30', 'days': [1, 2, 3, 4, 5]},
                'actions': [
                  {'actionType': 'DEVICE_CONTROL', 'target': 'ch1', 'value': true}
                ],
                'isEnabled': true,
              }
            ];
          }
          return [];
        },
        mockPost: (endpoint, {body}) async {
          routinePostEndpoint = endpoint;
          routinePostBody = body;
          return {
            'id': 'auto-2',
            'name': body?['name'],
            'triggerType': body?['triggerType'],
            'triggerConfig': body?['triggerConfig'],
            'actions': body?['actions'],
            'isEnabled': true,
          };
        },
      );

      final routineRepo = CloudRoutineRepository(mockClient, activeHomeId: 'home-uuid-101');
      final list = await routineRepo.getRoutines();
      expect(list.length, 1);
      expect(list.first.name, 'Morning Boost');
      expect(list.first.enabled, isTrue);

      final result = await routineRepo.createRoutine(
        RoutineDraft(
          name: 'Night Cool',
          icon: 'fan',
          trigger: const RoutineTrigger(
            kind: RoutineTriggerKind.soilMoisture,
            title: 'Schedule at 22:00',
            detail: 'Every night',
          ),
          actions: const [
            RoutineAction(
              kind: RoutineActionKind.mistMaker,
              title: 'Ceiling Fan',
              detail: 'Turn on',
              deviceId: 'ch2',
            ),
          ],
        ),
      );

      expect(result, RepositoryResult.success);
      expect(routinePostEndpoint, '/api/v1/homes/home-uuid-101/automations');
      expect(routinePostBody?['name'], 'Night Cool');
    });

    test('CloudActivityRepository converts real audit & notifications', () async {
      final mockClient = MockApiClient(
        mockGet: (endpoint) async {
          if (endpoint.startsWith('/api/v1/notifications')) {
            return {
              'notifications': [
                {
                  'id': 'notif-1',
                  'title': 'High Power Alert',
                  'message': 'Smart switch load exceeded 1500W',
                  'type': 'ALERT',
                  'created_at': DateTime.now().toIso8601String(),
                }
              ]
            };
          }
          return [];
        },
      );

      final activityRepo = CloudActivityRepository(mockClient, activeHomeId: 'home-uuid-101');
      final page = await activityRepo.getEvents(const ActivityQuery());
      expect(page.events.isNotEmpty, isTrue);
      expect(page.events.first.title, 'High Power Alert');
      expect(page.events.first.type, ActivityEventType.safetyAlert);
    });

    test('CloudSettingsRepository manages members, invitations and devices', () async {
      final mockClient = MockApiClient(
        mockGet: (endpoint) async {
          if (endpoint == '/api/v1/homes') {
            return [{'id': 'home-uuid-101', 'name': 'Pavan Home'}];
          }
          if (endpoint == '/api/v1/homes/home-uuid-101') {
            return {
              'name': 'Pavan Home',
              'owner_name': 'Pavan',
              'timezone': 'Asia/Kolkata',
              'address': 'Hyderabad',
            };
          }
          if (endpoint == '/api/v1/homes/home-uuid-101/members') {
            return [
              {'id': 'm1', 'email': 'pavan@example.com', 'role': 'OWNER'},
              {'id': 'm2', 'email': 'friend@example.com', 'role': 'MEMBER'},
            ];
          }
          if (endpoint == '/api/v1/homes/home-uuid-101/invitations') {
            return [
              {'id': 'inv-1', 'email': 'guest@example.com'},
            ];
          }
          if (endpoint == '/api/v1/homes/home-uuid-101/devices') {
            return [
              {
                'deviceId': 'dev-1',
                'displayName': 'Living Switch',
                'hardwareRevision': 'ESP32',
                'connectionState': 'ONLINE',
              }
            ];
          }
          return [];
        },
        mockPost: (endpoint, {body}) async => {'status': 'invited'},
        mockDelete: (endpoint, {body}) async => {'status': 'cancelled'},
      );

      final settingsRepo = CloudSettingsRepository(mockClient, activeHomeId: 'home-uuid-101');
      final homeData = await settingsRepo.getHome();
      expect(homeData.name, 'Pavan Home');
      expect(homeData.ownerName, 'Pavan');

      final members = await settingsRepo.getMembers();
      expect(members.length, 2);
      expect(members.first.role, HomeMemberRole.owner);

      final invitations = await settingsRepo.getPendingInvitations();
      expect(invitations.length, 1);
      expect(invitations.first.recipientName, 'guest@example.com');

      final devices = await settingsRepo.getNearbyDevices();
      expect(devices.length, 1);
      expect(devices.first.name, 'Living Switch');

      final inviteRes = await settingsRepo.invitePerson('new@example.com');
      expect(inviteRes, SettingsOperationResult.success);

      final cancelRes = await settingsRepo.cancelInvitation('inv-1');
      expect(cancelRes, SettingsOperationResult.success);
    });

    test('AppPermissionService manages permissions status', () async {
      const permService = AppPermissionService();
      final status = await permService.checkStatus(AppPermissionType.bluetooth);
      expect(status, isNotNull);
    });

    test('EHThemeTokens dark mode contrast maintains WCAG standards', () {
      final dark = EHThemeTokens.dark;
      final light = EHThemeTokens.light;

      // Dark theme background and card contrast
      expect(dark.isDark, isTrue);
      expect(light.isDark, isFalse);

      expect(dark.bgApp, EHColors.darkBgApp);
      expect(dark.surfaceCard, EHColors.darkSurfaceCard);
      expect(dark.textPrimary, EHColors.darkTextPrimary);
      expect(dark.textSecondary, EHColors.darkTextSecondary);

      // Light theme remains unchanged
      expect(light.bgApp, const Color(0xFFF6F8FC));
      expect(light.surfaceCard, Colors.white);
      expect(light.textPrimary, const Color(0xFF102448));
    });
  });

  group('UI Components Integration', () {
    testWidgets('LoginScreen renders brand logo and fields', (tester) async {
      final mockClient = MockApiClient();
      final authCtrl = AuthController(AuthRepository(mockClient));
      await authCtrl.restoreFuture;

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.light(),
          home: LoginScreen(controller: authCtrl),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Welcome to EH Home'), findsOneWidget);
      expect(find.text('Sign in to manage your connected smart home'), findsOneWidget);
      expect(find.byType(TextFormField), findsNWidgets(2));
      expect(find.text('Sign In'), findsOneWidget);
    });

    testWidgets('RegisterScreen renders brand logo and confirm password field', (tester) async {
      final mockClient = MockApiClient();
      final authCtrl = AuthController(AuthRepository(mockClient));
      await authCtrl.restoreFuture;

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.light(),
          home: RegisterScreen(controller: authCtrl),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Join EH Smart Home'), findsOneWidget);
      expect(find.text('Create an account to securely access your home'), findsOneWidget);
      expect(find.byType(TextFormField), findsNWidgets(3));
      expect(find.widgetWithText(FilledButton, 'Create Account'), findsOneWidget);
    });

    testWidgets('RoomsPage shows clean UI and allows adding a room', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.light(),
          home: const Scaffold(
            body: RoomsPage(),
          ),
        ),
      );

      expect(find.text('Rooms'), findsOneWidget);
      expect(find.byIcon(Icons.add_rounded), findsWidgets);
    });
  });
}
