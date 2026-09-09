import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:smart_home_application_v1/core/repositories/settings_repository.dart';
import 'package:smart_home_application_v1/core/services/context_presence_service.dart';
import 'package:smart_home_application_v1/features/context/presentation/home_context_page.dart';
import 'package:smart_home_application_v1/features/context/presentation/presence_dashboard_page.dart';
import 'package:smart_home_application_v1/features/settings/presentation/help/help_support_page.dart';
import 'package:smart_home_application_v1/features/settings/presentation/people_page.dart';

void main() {
  group('Dark Theme Semantic Contrast Tests', () {
    testWidgets('HomeContextPage in Dark Theme renders readable text and contrast', (tester) async {
      final mockClient = MockClient((request) async {
        if (request.url.path.contains('/context')) {
          return http.Response(
            json.encode({
              'success': true,
              'data': {
                'homeId': 'home-1',
                'mode': 'HOME',
                'precedenceTier': 'USER_OVERRIDE',
                'isVacation': false,
                'isOccupied': true,
                'confidence': 1.0,
                'updatedAt': '2026-09-09T12:00:00.000Z',
              },
            }),
            200,
          );
        }
        if (request.url.path.contains('/transitions')) {
          return http.Response(
            json.encode({
              'success': true,
              'data': [],
            }),
            200,
          );
        }
        return http.Response('Not Found', 404);
      });

      final service = ContextPresenceService(baseUrl: 'http://test', client: mockClient);
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.light(),
          darkTheme: ThemeData.dark(),
          themeMode: ThemeMode.dark,
          home: HomeContextPage(
            homeId: 'home-1',
            service: service,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Home Context & Modes'), findsOneWidget);
      expect(find.text('Set Home Context Mode'), findsOneWidget);
      expect(find.text('Context Transitions History'), findsOneWidget);
    });

    testWidgets('PresenceDashboardPage renders readable state in Dark Theme', (tester) async {
      final mockClient = MockClient((request) async {
        return http.Response(
          json.encode({
            'success': true,
            'data': {
              'homeId': 'home-1',
              'state': 'HOME',
              'confidence': 1.0,
              'isOccupied': true,
              'activeUserCount': 1,
              'userStates': {},
              'inferredRooms': [],
              'lastReconciledAt': '2026-09-09T12:00:00.000Z',
            },
          }),
          200,
        );
      });

      final service = ContextPresenceService(baseUrl: 'http://test', client: mockClient);
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.light(),
          darkTheme: ThemeData.dark(),
          themeMode: ThemeMode.dark,
          home: PresenceDashboardPage(
            homeId: 'home-1',
            service: service,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Home'), findsWidgets);
      expect(find.text('Away'), findsWidgets);
    });

    testWidgets('PeoplePage renders cards and counts in Dark Theme', (tester) async {
      const repo = PreviewSettingsRepository();
      final homeData = await repo.getHome();
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.light(),
          darkTheme: ThemeData.dark(),
          themeMode: ThemeMode.dark,
          home: PeoplePage(
            home: homeData,
            repository: repo,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('People at home'), findsOneWidget);
    });

    testWidgets('HelpSupportPage renders cards and carousel in Dark Theme', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.light(),
          darkTheme: ThemeData.dark(),
          themeMode: ThemeMode.dark,
          home: const HelpSupportPage(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Help & support'), findsOneWidget);
      expect(find.text('Quick help'), findsOneWidget);
    });
  });
}
