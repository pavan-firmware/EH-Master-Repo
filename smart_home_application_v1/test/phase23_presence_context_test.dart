import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:smart_home_application_v1/core/models/context_presence_models.dart';
import 'package:smart_home_application_v1/core/services/context_presence_service.dart';
import 'package:smart_home_application_v1/features/context/presentation/presence_dashboard_page.dart';
import 'package:smart_home_application_v1/features/context/presentation/home_context_page.dart';
import 'package:smart_home_application_v1/features/context/presentation/vacation_mode_page.dart';

void main() {
  group('Phase 23: Presence & Context Models Test Suite', () {
    test('PresenceSignalModel serialization & deserialization', () {
      final json = {
        'id': 'sig_01',
        'user_id': 'usr_01',
        'home_id': 'home_01',
        'source': 'mobile_app',
        'state': 'HOME',
        'confidence': 0.90,
        'evidence': {'wifiSsid': 'HomeMesh'},
        'observed_at': '2026-07-16T12:00:00.000Z',
      };

      final signal = PresenceSignalModel.fromJson(json);
      expect(signal.id, 'sig_01');
      expect(signal.userId, 'usr_01');
      expect(signal.source, PresenceSource.mobileApp);
      expect(signal.state, PresenceState.home);
      expect(signal.confidence, 0.90);
      expect(signal.evidence['wifiSsid'], 'HomeMesh');

      final serialized = signal.toJson();
      expect(serialized['source'], 'mobile_app');
      expect(serialized['state'], 'HOME');
    });

    test('PresenceSnapshotModel with user states & inferred rooms', () {
      final json = {
        'homeId': 'home_01',
        'state': 'HOME',
        'confidence': 0.88,
        'isOccupied': true,
        'activeUserCount': 2,
        'userStates': {
          'usr_01': {
            'state': 'HOME',
            'confidence': 0.95,
            'source': 'manual',
            'isStale': false,
          },
          'usr_02': {
            'state': 'AWAY',
            'confidence': 0.80,
            'source': 'mobile_app',
            'isStale': true,
          }
        },
        'inferredRooms': [
          {
            'roomId': 'room_living',
            'isOccupied': true,
            'confidence': 0.75,
            'isInferred': true,
            'inferenceReason': 'Device activity'
          }
        ],
        'calculatedAt': '2026-07-16T12:00:00.000Z'
      };

      final snapshot = PresenceSnapshotModel.fromJson(json);
      expect(snapshot.homeId, 'home_01');
      expect(snapshot.state, PresenceState.home);
      expect(snapshot.isOccupied, true);
      expect(snapshot.activeUserCount, 2);
      expect(snapshot.userStates.length, 2);
      expect(snapshot.userStates['usr_01']?.isStale, false);
      expect(snapshot.userStates['usr_02']?.isStale, true);
      expect(snapshot.inferredRooms.first.roomId, 'room_living');
      expect(snapshot.inferredRooms.first.isOccupied, true);
    });

    test('HomeContextModel with manual override & precedence tier', () {
      final json = {
        'homeId': 'home_01',
        'mode': 'VACATION',
        'previousMode': 'HOME',
        'precedenceTier': 'MANUAL_OVERRIDE',
        'isVacation': true,
        'isOccupied': false,
        'confidence': 1.0,
        'activeOverride': {
          'id': 'ovr_01',
          'userId': 'usr_01',
          'mode': 'VACATION',
          'reason': 'Summer trip',
          'expiresAt': '2026-07-23T12:00:00.000Z'
        },
        'updatedAt': '2026-07-16T12:00:00.000Z'
      };

      final context = HomeContextModel.fromJson(json);
      expect(context.homeId, 'home_01');
      expect(context.mode, ContextMode.vacation);
      expect(context.previousMode, ContextMode.home);
      expect(context.precedenceTier, PrecedenceTier.manualOverride);
      expect(context.isVacation, true);
      expect(context.isOccupied, false);
      expect(context.activeOverride?.reason, 'Summer trip');
    });

    test('ContextTransitionModel serialization', () {
      final json = {
        'id': 'trans_01',
        'home_id': 'home_01',
        'from_mode': 'HOME',
        'to_mode': 'AWAY',
        'trigger_source': 'reconciliation',
        'reason': 'All users departed',
        'created_at': '2026-07-16T12:00:00.000Z'
      };

      final transition = ContextTransitionModel.fromJson(json);
      expect(transition.id, 'trans_01');
      expect(transition.fromMode, ContextMode.home);
      expect(transition.toMode, ContextMode.away);
      expect(transition.triggerSource, 'reconciliation');
    });
  });

  group('Phase 23: ContextPresenceService HTTP Tests', () {
    test('fetchPresenceSnapshot returns snapshot successfully', () async {
      final mockClient = MockClient((request) async {
        if (request.url.path == '/api/v1/context/homes/home_01/presence') {
          return http.Response(
            json.encode({
              'success': true,
              'data': {
                'homeId': 'home_01',
                'state': 'HOME',
                'confidence': 0.90,
                'isOccupied': true,
                'activeUserCount': 1,
                'calculatedAt': '2026-07-16T12:00:00.000Z'
              }
            }),
            200,
          );
        }
        return http.Response('Not Found', 404);
      });

      final service = ContextPresenceService(baseUrl: 'http://test', client: mockClient, authToken: 'token');
      final res = await service.fetchPresenceSnapshot('home_01');

      expect(res, isNotNull);
      expect(res?.homeId, 'home_01');
      expect(res?.state, PresenceState.home);
      expect(res?.isOccupied, true);
    });

    test('submitPresenceSignal posts payload and refreshes snapshot', () async {
      final mockClient = MockClient((request) async {
        if (request.method == 'POST' && request.url.path == '/api/v1/context/homes/home_01/presence') {
          return http.Response(
            json.encode({
              'success': true,
              'data': {
                'signal': {'id': 'sig_01'},
                'context': {
                  'homeId': 'home_01',
                  'mode': 'HOME',
                  'precedenceTier': 'RECONCILED_PRESENCE',
                  'isVacation': false,
                  'isOccupied': true,
                  'confidence': 0.95,
                  'updatedAt': '2026-07-16T12:00:00.000Z'
                }
              }
            }),
            201,
          );
        }
        if (request.method == 'GET' && request.url.path == '/api/v1/context/homes/home_01/presence') {
          return http.Response(
            json.encode({
              'success': true,
              'data': {
                'homeId': 'home_01',
                'state': 'HOME',
                'confidence': 0.95,
                'isOccupied': true,
                'activeUserCount': 1,
                'calculatedAt': '2026-07-16T12:00:00.000Z'
              }
            }),
            200,
          );
        }
        return http.Response('Not Found', 404);
      });

      final service = ContextPresenceService(baseUrl: 'http://test', client: mockClient, authToken: 'token');
      final success = await service.submitPresenceSignal(
        homeId: 'home_01',
        source: PresenceSource.manual,
        state: PresenceState.home,
      );

      expect(success, isTrue);
      expect(service.currentSnapshot?.state, PresenceState.home);
    });

    test('setVacationMode enables vacation context', () async {
      final mockClient = MockClient((request) async {
        if (request.method == 'POST' && request.url.path == '/api/v1/context/homes/home_01/vacation') {
          return http.Response(
            json.encode({
              'success': true,
              'data': {
                'context': {
                  'homeId': 'home_01',
                  'mode': 'VACATION',
                  'precedenceTier': 'MANUAL_OVERRIDE',
                  'isVacation': true,
                  'isOccupied': false,
                  'confidence': 1.0,
                  'updatedAt': '2026-07-16T12:00:00.000Z'
                }
              }
            }),
            200,
          );
        }
        return http.Response('Not Found', 404);
      });

      final service = ContextPresenceService(baseUrl: 'http://test', client: mockClient, authToken: 'token');
      final success = await service.setVacationMode('home_01', durationDays: 14);

      expect(success, isTrue);
      expect(service.currentContext?.mode, ContextMode.vacation);
      expect(service.currentContext?.isVacation, isTrue);
    });
  });

  group('Phase 23: Presentation UI Widget Tests', () {
    testWidgets('PresenceDashboardPage renders hero card and user presence', (tester) async {
      final mockClient = MockClient((request) async {
        if (request.url.path == '/api/v1/context/homes/home_01/presence') {
          return http.Response(
            json.encode({
              'success': true,
              'data': {
                'homeId': 'home_01',
                'state': 'HOME',
                'confidence': 0.90,
                'isOccupied': true,
                'activeUserCount': 1,
                'userStates': {
                  'usr_01': {
                    'state': 'HOME',
                    'confidence': 0.90,
                    'source': 'mobile_app',
                    'isStale': false
                  }
                },
                'inferredRooms': [
                  {
                    'roomId': 'room_living',
                    'isOccupied': true,
                    'confidence': 0.75,
                    'inferenceReason': 'Device activity'
                  }
                ],
                'calculatedAt': '2026-07-16T12:00:00.000Z'
              }
            }),
            200,
          );
        }
        if (request.url.path == '/api/v1/context/homes/home_01/context') {
          return http.Response(
            json.encode({
              'success': true,
              'data': {
                'homeId': 'home_01',
                'mode': 'HOME',
                'precedenceTier': 'RECONCILED_PRESENCE',
                'isVacation': false,
                'isOccupied': true,
                'confidence': 0.90,
                'updatedAt': '2026-07-16T12:00:00.000Z'
              }
            }),
            200,
          );
        }
        return http.Response('Not Found', 404);
      });

      final service = ContextPresenceService(baseUrl: 'http://test', client: mockClient, authToken: 'token');

      await tester.pumpWidget(
        MaterialApp(
          home: PresenceDashboardPage(homeId: 'home_01', service: service),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Presence & Occupancy'), findsOneWidget);
      expect(find.text('HOME (OCCUPIED)'), findsOneWidget);
      expect(find.text("I'm Home"), findsOneWidget);
      expect(find.text("I'm Away"), findsOneWidget);
      expect(find.text('Family & Member Presence'), findsOneWidget);
      expect(find.text('Inferred Room Occupancy'), findsOneWidget);
    });

    testWidgets('HomeContextPage renders modes and transitions', (tester) async {
      final mockClient = MockClient((request) async {
        if (request.url.path == '/api/v1/context/homes/home_01/context') {
          return http.Response(
            json.encode({
              'success': true,
              'data': {
                'homeId': 'home_01',
                'mode': 'HOME',
                'precedenceTier': 'RECONCILED_PRESENCE',
                'isVacation': false,
                'isOccupied': true,
                'confidence': 0.90,
                'updatedAt': '2026-07-16T12:00:00.000Z'
              }
            }),
            200,
          );
        }
        if (request.url.path == '/api/v1/context/homes/home_01/transitions') {
          return http.Response(
            json.encode({
              'success': true,
              'data': [
                {
                  'id': 't1',
                  'home_id': 'home_01',
                  'from_mode': 'AWAY',
                  'to_mode': 'HOME',
                  'trigger_source': 'reconciliation',
                  'reason': 'User returned',
                  'created_at': '2026-07-16T12:00:00.000Z'
                }
              ]
            }),
            200,
          );
        }
        return http.Response('Not Found', 404);
      });

      final service = ContextPresenceService(baseUrl: 'http://test', client: mockClient, authToken: 'token');

      await tester.pumpWidget(
        MaterialApp(
          home: HomeContextPage(homeId: 'home_01', service: service),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Home Context & Modes'), findsOneWidget);
      expect(find.text('Set Home Context Mode'), findsOneWidget);
      expect(find.text('Precedence State Machine Hierarchy'), findsOneWidget);
    });

    testWidgets('VacationModePage renders activation controls', (tester) async {
      final mockClient = MockClient((request) async {
        if (request.url.path == '/api/v1/context/homes/home_01/context') {
          return http.Response(
            json.encode({
              'success': true,
              'data': {
                'homeId': 'home_01',
                'mode': 'HOME',
                'precedenceTier': 'RECONCILED_PRESENCE',
                'isVacation': false,
                'isOccupied': true,
                'confidence': 0.90,
                'updatedAt': '2026-07-16T12:00:00.000Z'
              }
            }),
            200,
          );
        }
        return http.Response('Not Found', 404);
      });

      final service = ContextPresenceService(baseUrl: 'http://test', client: mockClient, authToken: 'token');

      await tester.pumpWidget(
        MaterialApp(
          home: VacationModePage(homeId: 'home_01', service: service),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Vacation Mode'), findsOneWidget);
      expect(find.text('Vacation Protection'), findsOneWidget);
      expect(find.text('Trip Duration (Days)'), findsOneWidget);
      expect(find.text('Activate Vacation Mode'), findsOneWidget);
    });
  });
}
