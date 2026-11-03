import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_home_application_v1/core/models/settings_models.dart';
import 'package:smart_home_application_v1/features/connection/presentation/home_connection_page.dart';
import 'package:smart_home_application_v1/features/rooms/presentation/rooms_page.dart';
import 'package:smart_home_application_v1/features/settings/presentation/add_room_device_page.dart';
import 'package:smart_home_application_v1/features/settings/presentation/help/help_support_page.dart';
import 'package:smart_home_application_v1/features/settings/presentation/people_page.dart';

import 'e2e_test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    TestWidgetsFlutterBinding.instance.platformDispatcher.views.first.physicalSize =
        const Size(800, 1200);
    TestWidgetsFlutterBinding.instance.platformDispatcher.views.first.devicePixelRatio = 1.0;
  });

  tearDown(() {
    TestWidgetsFlutterBinding.instance.platformDispatcher.views.first.resetPhysicalSize();
    TestWidgetsFlutterBinding.instance.platformDispatcher.views.first.resetDevicePixelRatio();
  });

  group('Tier 2: Task 3 — Getting Started Navigation Flows', () {
    testWidgets('T3-1: Getting Started displays all 5 canonical options with updated descriptions',
        (tester) async {
      final helpRepo = TestHelpRepository();
      await tester.pumpWidget(
        buildTestApp(
          child: HelpSupportPage(
            repository: helpRepo,
            settingsRepository: TestSettingsRepository(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Connect your home'), findsWidgets);
      expect(find.text('Connect EH Home to your network and supported devices.'), findsOneWidget);

      expect(find.text('Add your first device'), findsOneWidget);
      expect(find.text('Discover and securely set up a supported EH device.'), findsOneWidget);

      expect(find.text('Create a room'), findsOneWidget);
      expect(find.text('Organize your home devices by room.'), findsOneWidget);

      expect(find.text('Create a routine'), findsOneWidget);
      expect(
          find.text('Automate supported device actions using triggers and schedules.'),
          findsOneWidget);

      expect(find.text('Invite someone'), findsOneWidget);
      expect(
          find.text('Share home access with authorized household members.'),
          findsOneWidget);
    });

    testWidgets('T3-2: "Connect your home" navigates to canonical HomeConnectionPage',
        (tester) async {
      final helpRepo = TestHelpRepository();
      await tester.pumpWidget(
        buildTestApp(
          child: HelpSupportPage(
            repository: helpRepo,
            settingsRepository: TestSettingsRepository(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Connect your home').first);
      await tester.pumpAndSettle();

      expect(find.byType(HomeConnectionPage), findsOneWidget);
    });

    testWidgets('T3-3: "Add your first device" navigates to canonical AddRoomDevicePage',
        (tester) async {
      final helpRepo = TestHelpRepository();
      await tester.pumpWidget(
        buildTestApp(
          child: HelpSupportPage(
            repository: helpRepo,
            settingsRepository: TestSettingsRepository(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Add your first device'));
      await tester.pumpAndSettle();

      expect(find.byType(AddRoomDevicePage), findsOneWidget);
      expect(find.text('Pair a New Device'), findsOneWidget);
    });

    testWidgets('T3-4: "Create a room" navigates to canonical RoomsPage and triggers create-room action',
        (tester) async {
      final helpRepo = TestHelpRepository();
      await tester.pumpWidget(
        buildTestApp(
          child: HelpSupportPage(
            repository: helpRepo,
            settingsRepository: TestSettingsRepository(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Create a room'));
      await tester.pumpAndSettle();

      expect(find.byType(RoomsPage), findsOneWidget);
      // autoOpenCreateRoom opens Add room dialog
      expect(find.text('Add room'), findsWidgets);
      expect(find.text('Create'), findsOneWidget);
    });

    testWidgets('T3-5: "Create a routine" navigates to canonical AutomationsPage with builder intent',
        (tester) async {
      final helpRepo = TestHelpRepository();
      await tester.pumpWidget(
        buildTestApp(
          child: HelpSupportPage(
            repository: helpRepo,
            settingsRepository: TestSettingsRepository(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Create a routine'));
      await tester.pumpAndSettle();

      // autoOpenBuilder opens the canonical RoutineBuilderPage
      expect(find.text('Create Routine'), findsWidgets);
    });

    testWidgets('T3-6: "Invite someone" navigates to canonical PeoplePage with invite intent',
        (tester) async {
      final helpRepo = TestHelpRepository();
      final settingsRepo = TestSettingsRepository();
      await tester.pumpWidget(
        buildTestApp(
          child: HelpSupportPage(
            repository: helpRepo,
            settingsRepository: settingsRepo,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Invite someone'));
      await tester.pumpAndSettle();

      expect(find.byType(PeoplePage), findsOneWidget);
      // autoOpenInvite triggers Invite to Home dialog
      expect(find.text('Invite to Home'), findsOneWidget);
      expect(find.text('Send Invite'), findsOneWidget);
    });
  });

  group('Tier 2: Task 4 — People at Home Real Data and Invitation Flows', () {
    testWidgets('T4-1: PeoplePage renders real member identities from repository',
        (tester) async {
      final repo = TestSettingsRepository(
        members: [
          const HomeMember(
            id: 'owner_01',
            displayName: 'Real Owner',
            role: HomeMemberRole.owner,
            status: HomeMemberStatus.active,
            initials: 'RO',
            email: 'owner@example.com',
            lastActiveLabel: 'Home owner',
          ),
          const HomeMember(
            id: 'member_02',
            displayName: 'Real Member',
            role: HomeMemberRole.member,
            status: HomeMemberStatus.active,
            initials: 'RM',
            email: 'member@example.com',
            lastActiveLabel: 'Member · Access active',
          ),
        ],
        pendingInvitations: const [
          HomeInvitation(
            id: 'inv_01',
            recipientName: 'guest@example.com',
            initials: 'G',
            invitedLabel: 'Guest invitation',
            expiresLabel: 'Valid for 7 days',
            role: HomeMemberRole.guest,
          ),
        ],
      );

      await tester.pumpWidget(
        buildTestApp(
          child: PeoplePage(
            repository: repo,
            home: repo.home,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Real Owner'), findsOneWidget);
      expect(find.text('Real Member'), findsOneWidget);
      expect(find.text('guest@example.com'), findsOneWidget);
      // Ensure fake preview data is absent
      expect(find.text('Pavan (You)'), findsNothing);
      expect(find.text('Arun'), findsNothing);
      expect(find.text('Priya'), findsNothing);
      expect(find.text('Rahul'), findsNothing);
    });

    testWidgets('T4-2: Empty state displays clean feedback when no members are present',
        (tester) async {
      final repo = TestSettingsRepository(
        members: const [],
        pendingInvitations: const [],
      );

      await tester.pumpWidget(
        buildTestApp(
          child: PeoplePage(
            repository: repo,
            home: repo.home,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('No members found for this home.'), findsOneWidget);
    });

    testWidgets('T4-3: Invite flow validates email format before submitting to backend',
        (tester) async {
      final repo = TestSettingsRepository();

      await tester.pumpWidget(
        buildTestApp(
          child: PeoplePage(
            repository: repo,
            home: repo.home,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap Invite someone tile
      await tester.tap(find.text('Invite someone'));
      await tester.pumpAndSettle();

      expect(find.text('Invite to Home'), findsOneWidget);

      // Enter invalid email
      await tester.enterText(find.byType(TextField), 'invalid-email');
      await tester.tap(find.text('Send Invite'));
      await tester.pumpAndSettle();

      // Expect validation error
      expect(find.text('Please enter a valid email address'), findsOneWidget);
      expect(repo.invitedRecipients, isEmpty);

      // Enter valid email and submit
      await tester.enterText(find.byType(TextField), 'valid.user@example.com');
      await tester.tap(find.text('Send Invite'));
      await tester.pumpAndSettle();

      expect(repo.invitedRecipients, contains('valid.user@example.com'));
      expect(find.text('Invitation sent to valid.user@example.com'), findsOneWidget);
    });

    testWidgets('T4-4: Unsupported invitation state displays clear feedback without fake flow',
        (tester) async {
      final repo = TestSettingsRepository(
        inviteResult: SettingsOperationResult.unsupported,
      );

      await tester.pumpWidget(
        buildTestApp(
          child: PeoplePage(
            repository: repo,
            home: repo.home,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Invite someone'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'user@example.com');
      await tester.tap(find.text('Send Invite'));
      await tester.pumpAndSettle();

      expect(find.text('Home invitations are not supported by this server.'), findsOneWidget);
    });

    testWidgets('T4-5: Owner cannot be removed from home access',
        (tester) async {
      final repo = TestSettingsRepository(
        members: [
          const HomeMember(
            id: 'owner_01',
            displayName: 'Chief Owner',
            role: HomeMemberRole.owner,
            status: HomeMemberStatus.active,
            initials: 'CO',
            email: 'chief@example.com',
            lastActiveLabel: 'Home owner',
          ),
        ],
        pendingInvitations: const [],
      );

      await tester.pumpWidget(
        buildTestApp(
          child: PeoplePage(
            repository: repo,
            home: repo.home,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Owner row displays verified badge, delete icon is not available
      expect(find.byIcon(Icons.verified_user_rounded), findsWidgets);
      expect(find.byIcon(Icons.delete_outline_rounded), findsNothing);
    });
  });
}
