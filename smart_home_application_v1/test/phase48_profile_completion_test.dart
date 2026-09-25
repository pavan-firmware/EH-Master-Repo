import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_home_application_v1/core/api/api_client.dart';
import 'package:smart_home_application_v1/core/repositories/auth_repository.dart';
import 'package:smart_home_application_v1/features/auth/auth_controller.dart';
import 'package:smart_home_application_v1/features/auth/profile_completion_screen.dart';

class _FakeAuthApiClient extends ApiClient {
  _FakeAuthApiClient({
    this.onPost,
    this.onPatch,
  }) : super(baseUrl: 'http://127.0.0.1:8080');

  final Future<dynamic> Function(String path, dynamic body)? onPost;
  final Future<dynamic> Function(String path, dynamic body)? onPatch;

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

  @override
  Future<dynamic> patch(
    String path, {
    dynamic body,
    Map<String, String>? headers,
    Duration? timeout,
  }) async {
    if (onPatch != null) {
      return await onPatch!(path, body);
    }
    return {};
  }
}

void main() {
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
  });

  group('Phase 48: Legacy Profile Completion UX Tests', () {
    testWidgets('1. Legacy account with full_name=null prompts ProfileCompletionScreen', (tester) async {
      final apiClient = _FakeAuthApiClient(
        onPost: (path, body) async {
          if (path == '/api/v1/auth/login') {
            return {
              'accessToken': 'jwt.token.legacy',
              'refreshToken': 'refresh.legacy',
              'user': {
                'id': '41fa1669-438e-4dac-a81b-2807ba460f7f',
                'email': 'chandra77807@gmail.com',
                'emailVerified': true,
                'role': 'USER',
                'fullName': null,
              }
            };
          }
          return {};
        },
      );

      final authRepo = AuthRepository(apiClient);
      final authController = AuthController(authRepo);
      await authController.restoreFuture;

      // Perform login with legacy null fullName
      await authController.login('chandra77807@gmail.com', 'SecurePass123!');
      expect(authController.currentUser?.fullName, isNull);
      expect(authController.currentUser?.displayName, 'chandra77807');

      await tester.pumpWidget(
        MaterialApp(
          home: ProfileCompletionScreen(
            controller: authController,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Complete Your Profile'), findsOneWidget);
      expect(find.text('Account: chandra77807@gmail.com'), findsOneWidget);
      expect(find.byKey(const Key('profile_completion_name_field')), findsOneWidget);
      expect(find.byKey(const Key('profile_completion_save_button')), findsOneWidget);
    });

    testWidgets('2. Validation prevents empty or single-character full name submission', (tester) async {
      final apiClient = _FakeAuthApiClient();
      final authRepo = AuthRepository(apiClient);
      final authController = AuthController(authRepo);
      await authController.restoreFuture;

      await tester.pumpWidget(
        MaterialApp(
          home: ProfileCompletionScreen(
            controller: authController,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Submit empty
      await tester.tap(find.byKey(const Key('profile_completion_save_button')));
      await tester.pumpAndSettle();
      expect(find.text('Please enter your full name'), findsOneWidget);

      // Submit 1 character
      await tester.enterText(find.byKey(const Key('profile_completion_name_field')), 'C');
      await tester.tap(find.byKey(const Key('profile_completion_save_button')));
      await tester.pumpAndSettle();
      expect(find.text('Full name must be at least 2 characters'), findsOneWidget);
    });

    testWidgets('3. Successful submission updates profile and triggers completion callback', (tester) async {
      final apiClient = _FakeAuthApiClient(
        onPatch: (path, body) async {
          if (path == '/api/v1/account/profile') {
            return {
              'id': '41fa1669-438e-4dac-a81b-2807ba460f7f',
              'email': 'chandra77807@gmail.com',
              'fullName': body['fullName'],
              'role': 'USER',
              'emailVerified': true,
            };
          }
          return {};
        },
      );

      final authRepo = AuthRepository(apiClient);
      final authController = AuthController(authRepo);
      await authController.restoreFuture;

      bool completed = false;
      await tester.pumpWidget(
        MaterialApp(
          home: ProfileCompletionScreen(
            controller: authController,
            onCompleted: () {
              completed = true;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('profile_completion_name_field')), 'Chandra Prakash');
      await tester.tap(find.byKey(const Key('profile_completion_save_button')));
      await tester.pumpAndSettle();

      expect(completed, isTrue);
      expect(authController.currentUser?.fullName, 'Chandra Prakash');
      expect(authController.currentUser?.displayName, 'Chandra Prakash');
    });

    test('4. AuthRepository.updateProfile updates in-memory UserProfile and persists', () async {
      final apiClient = _FakeAuthApiClient(
        onPatch: (path, body) async {
          if (path == '/api/v1/account/profile') {
            return {
              'id': '41fa1669-438e-4dac-a81b-2807ba460f7f',
              'email': 'chandra77807@gmail.com',
              'fullName': 'Chandra Prakash',
              'role': 'USER',
              'emailVerified': true,
            };
          }
          return {};
        },
      );

      final authRepo = AuthRepository(apiClient);
      final updated = await authRepo.updateProfile(fullName: 'Chandra Prakash');

      expect(updated.fullName, 'Chandra Prakash');
      expect(updated.displayName, 'Chandra Prakash');
      expect(authRepo.currentUser?.fullName, 'Chandra Prakash');
    });

    test('5. AuthController.updateProfile notifies listeners and clears error', () async {
      final apiClient = _FakeAuthApiClient(
        onPatch: (path, body) async {
          if (path == '/api/v1/account/profile') {
            return {
              'id': '41fa1669-438e-4dac-a81b-2807ba460f7f',
              'email': 'chandra77807@gmail.com',
              'fullName': 'Chandra Prakash',
            };
          }
          return {};
        },
      );

      final authRepo = AuthRepository(apiClient);
      final authController = AuthController(authRepo);
      await authController.restoreFuture;

      bool notified = false;
      authController.addListener(() {
        notified = true;
      });

      final ok = await authController.updateProfile(fullName: 'Chandra Prakash');
      expect(ok, isTrue);
      expect(notified, isTrue);
      expect(authController.currentUser?.fullName, 'Chandra Prakash');
      expect(authController.currentUser?.displayName, 'Chandra Prakash');
    });
  });
}
