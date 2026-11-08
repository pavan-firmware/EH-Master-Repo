import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_home_application_v1/core/models/privacy_models.dart';
import 'package:smart_home_application_v1/core/repositories/auth_repository.dart';
import 'package:smart_home_application_v1/core/repositories/privacy_repository.dart';
import 'package:smart_home_application_v1/features/auth/auth_controller.dart';
import 'package:smart_home_application_v1/features/settings/presentation/privacy/privacy_data_detail_page.dart';

class MockAuthRepository implements AuthRepository {
  UserProfile? user;
  bool isAuth = false;

  @override
  UserProfile? get currentUser => user;

  @override
  bool get isAuthenticated => isAuth;

  @override
  Future<void> restoreSession() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Privacy Dynamic Runtime Data Tests', () {
    test('Unauthenticated session displays local protected state with zero preview-build strings', () async {
      final repo = AuthoritativePrivacyRepository();
      final summary = await repo.getSummary();

      expect(summary.statusLabel, 'Local Protected');
      expect(summary.dataCategories.length, 4);

      // Verify no preview build strings anywhere
      for (final cat in summary.dataCategories) {
        expect(cat.summary.contains('preview build'), isFalse);
        expect(cat.storageLabel != 'Local preview', isTrue);
        expect(cat.storageLabel != 'Not connected yet', isTrue);
      }

      final accountCat = summary.dataCategories.firstWhere((c) => c.kind == PrivacyDataCategoryKind.accountInfo);
      expect(accountCat.subtitle, 'Local offline profile');
      expect(accountCat.storageLabel, 'Local secure enclave');
      expect(accountCat.summary.contains('Running in local connection mode'), isTrue);
    });

    test('Authenticated session displays real user email and role without secrets', () async {
      final authRepo = MockAuthRepository()
        ..isAuth = true
        ..user = UserProfile(
          id: 'user_123',
          email: 'admin@ehhome.internal',
          emailVerified: true,
          role: 'ADMIN',
          fullName: 'Platform Admin',
        );
      final authCtrl = AuthController(authRepo);
      // Wait for auth session restoration
      if (authCtrl.restoreFuture != null) await authCtrl.restoreFuture;

      final repo = AuthoritativePrivacyRepository(authController: authCtrl);
      final summary = await repo.getSummary();

      final accountCat = summary.dataCategories.firstWhere((c) => c.kind == PrivacyDataCategoryKind.accountInfo);
      expect(accountCat.subtitle.contains('admin@ehhome.internal'), isTrue);
      expect(accountCat.summary.contains('admin@ehhome.internal'), isTrue);
      expect(accountCat.storageLabel, 'Cloud Identity Provider (Encrypted)');
      expect(accountCat.details.any((d) => d.contains('ADMIN')), isTrue);
      expect(accountCat.details.any((d) => d.contains('cryptographic tokens')), isTrue);
      expect(accountCat.details.any((d) => d.contains('zero raw passwords')), isTrue);
    });

    testWidgets('PrivacyDataDetailPage renders category details and allows activity cache clear', (tester) async {
      const category = PrivacyDataCategory(
        kind: PrivacyDataCategoryKind.activityHistory,
        title: 'Activity history',
        subtitle: 'Audit logs',
        summary: 'Operational state transitions recorded for auditability.',
        details: [
          'Relay switch toggles',
          'Automation triggers',
        ],
        whyWeUseIt: 'To visualize event timelines.',
        storageLabel: 'Local cache & cloud encrypted audit store',
        retentionLabel: '90-day rolling retention',
      );

      await tester.pumpWidget(const MaterialApp(
        home: PrivacyDataDetailPage(category: category),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Activity history'), findsOneWidget);
      expect(find.text('Relay switch toggles'), findsOneWidget);
      expect(find.text('Local cache & cloud encrypted audit store'), findsOneWidget);
      expect(find.text('Clear Local Activity Cache'), findsOneWidget);

      await tester.tap(find.text('Clear Local Activity Cache'));
      await tester.pumpAndSettle();

      expect(find.text('Clear Local Activity Cache?'), findsOneWidget);
      await tester.tap(find.text('Clear Cache'));
      await tester.pumpAndSettle();

      expect(find.text('Local activity cache cleared.'), findsOneWidget);
    });
  });
}
