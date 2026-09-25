import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_home_application_v1/app/app.dart';
import 'package:smart_home_application_v1/app/home_controller.dart';
import 'package:smart_home_application_v1/core/api/api_client.dart';
import 'package:smart_home_application_v1/core/repositories/auth_repository.dart';
import 'package:smart_home_application_v1/core/repositories/cloud_account_home_repository.dart';
import 'package:smart_home_application_v1/core/repositories/cloud_home_repository.dart';
import 'package:smart_home_application_v1/core/repositories/unavailable_connection_repository.dart';
import 'package:smart_home_application_v1/features/auth/auth_controller.dart';
import 'package:smart_home_application_v1/features/auth/login_screen.dart';
import 'package:smart_home_application_v1/features/onboarding/presentation/home_onboarding_screen.dart';

class _FakeAuthApiClient extends ApiClient {
  Completer<void>? loginCompleter;

  _FakeAuthApiClient() : super(baseUrl: 'http://127.0.0.1:3000');

  @override
  Future<dynamic> post(String path, {Map<String, dynamic>? body}) async {
    if (path == '/api/v1/auth/login') {
      if (loginCompleter != null) {
        await loginCompleter!.future;
      }
      throw ApiException(
        statusCode: 401,
        message: 'Incorrect email or password.',
        code: 'INVALID_CREDENTIALS',
      );
    }
    if (path == '/api/v1/auth/register') {
      throw ApiException(
        statusCode: 409,
        message: 'An account with this email already exists. Please sign in.',
        code: 'DUPLICATE_EMAIL',
      );
    }
    return {};
  }
}

class _TestMockAuthRepository extends AuthRepository {
  final ApiClient client;
  _TestMockAuthRepository(this.client) : super(client);

  @override
  Future<void> restoreSession() async {}

  @override
  Future<void> login(String email, String password) async {
    await client.post('/api/v1/auth/login', body: {'email': email, 'password': password});
  }

  @override
  Future<void> register(String email, String password, {String? fullName}) async {
    await client.post('/api/v1/auth/register', body: {
      'email': email,
      'password': password,
      'fullName': ?fullName,
    });
  }
}

void main() {
  group('Phase 48: Auth Hardening & Bypass Prevention Tests', () {
    testWidgets('LoginScreen contains no Local Home bypass button', (tester) async {
      final fakeApi = _FakeAuthApiClient();
      final authRepo = _TestMockAuthRepository(fakeApi);
      final authController = AuthController(authRepo);
      await tester.pump();

      await tester.pumpWidget(
        MaterialApp(
          home: LoginScreen(controller: authController),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      // Verify legitimate authentication elements exist
      expect(find.text('Welcome to EH Home'), findsOneWidget);
      expect(find.text('Sign In'), findsOneWidget);
      expect(find.text("Don't have an account? Create one"), findsOneWidget);

      // Verify bypass elements DO NOT exist
      expect(find.text('Continue to Local Home'), findsNothing);
      expect(find.text('Local Home'), findsNothing);
      expect(find.text('Continue offline'), findsNothing);
      expect(find.text('Skip'), findsNothing);
    });

    testWidgets('Invalid login returns 401, stays on LoginScreen with error, no onboarding', (tester) async {
      final fakeApi = _FakeAuthApiClient();
      final loginCompleter = Completer<void>();
      fakeApi.loginCompleter = loginCompleter;

      final authRepo = _TestMockAuthRepository(fakeApi);
      final authController = AuthController(authRepo);
      await tester.pump();

      final homeController = HomeController(
        repository: CloudHomeRepository(fakeApi),
        connectionRepository: const UnavailableConnectionRepository(),
      );

      await tester.pumpWidget(
        SmartHomeApp(
          apiClient: fakeApi,
          authController: authController,
          homeController: homeController,
          accountHomeRepository: CloudAccountHomeRepository(fakeApi),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      // Find inputs
      final emailFinder = find.widgetWithText(TextFormField, 'Email Address');
      final passwordFinder = find.widgetWithText(TextFormField, 'Password');
      final signInButtonFinder = find.widgetWithText(FilledButton, 'Sign In');

      expect(emailFinder, findsOneWidget);
      expect(passwordFinder, findsOneWidget);
      expect(signInButtonFinder, findsOneWidget);

      // Enter wrong credentials
      await tester.enterText(emailFinder, 'wrong@example.com');
      await tester.enterText(passwordFinder, 'WrongPass123!');
      await tester.tap(signInButtonFinder);

      await tester.pump(); // Start authenticating
      expect(authController.state, equals(AuthState.authenticating));
      // LoginScreen must remain visible (not unmounted or flashing onboarding)
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.byType(HomeOnboardingScreen), findsNothing);

      // Complete backend login rejection (401)
      loginCompleter.complete();
      await tester.pump(const Duration(milliseconds: 100));

      // Must be failure state
      expect(authController.state, equals(AuthState.failure));
      expect(authController.errorMessage, equals('Incorrect email or password.'));

      // Login screen still visible with error
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.text('Incorrect email or password.'), findsOneWidget);
      expect(find.byType(HomeOnboardingScreen), findsNothing);
    });

    test('Duplicate signup error returns friendly message', () async {
      final fakeApi = _FakeAuthApiClient();
      final authRepo = _TestMockAuthRepository(fakeApi);
      final authController = AuthController(authRepo);

      final result = await authController.register('chandra77807@gmail.com', 'ValidPassword123!');
      expect(result, isFalse);
      expect(authController.state, equals(AuthState.failure));
      expect(
        authController.errorMessage,
        equals('An account with this email already exists. Please sign in.'),
      );
    });
  });
}
