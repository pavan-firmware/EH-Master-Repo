import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:smart_home_application_v1/core/models/sync_models.dart';
import 'package:smart_home_application_v1/core/services/sync_service.dart';
import 'package:smart_home_application_v1/features/sync/presentation/sync_status_widget.dart';
import 'package:smart_home_application_v1/features/sync/presentation/sync_center_page.dart';

void main() {
  group('Phase 17 — Sync Models Serialization Tests', () {
    test('PendingMutation serialize & deserialize round-trip', () {
      final now = DateTime.now();
      final mutation = PendingMutation(
        mutationId: 'mut_100',
        entityType: 'room',
        entityId: 'room_1',
        mutationType: 'update',
        payload: {'name': 'Master Suite'},
        clientTimestamp: now,
      );

      final jsonMap = mutation.toJson();
      expect(jsonMap['mutationId'], 'mut_100');
      expect(jsonMap['entityType'], 'room');
      expect(jsonMap['payload']['name'], 'Master Suite');

      final deserialized = PendingMutation.fromJson(jsonMap);
      expect(deserialized.mutationId, mutation.mutationId);
      expect(deserialized.entityType, mutation.entityType);
      expect(deserialized.payload['name'], 'Master Suite');
    });

    test('ReconciliationSummary parsing', () {
      final jsonMap = {
        'reconciledAt': DateTime.now().toIso8601String(),
        'totalMutations': 2,
        'acceptedCount': 1,
        'rejectedCount': 0,
        'conflictCount': 1,
        'results': [
          {
            'mutationId': 'mut_1',
            'status': 'ACCEPTED',
            'serverEntityId': 'server_uuid_1',
          },
          {
            'mutationId': 'mut_2',
            'status': 'CONFLICT',
            'reason': 'Target room does not belong to home',
          }
        ]
      };

      final summary = ReconciliationSummary.fromJson(jsonMap);
      expect(summary.totalMutations, 2);
      expect(summary.acceptedCount, 1);
      expect(summary.conflictCount, 1);
      expect(summary.results.length, 2);
      expect(summary.results[0].status, 'ACCEPTED');
      expect(summary.results[1].status, 'CONFLICT');
    });

    test('SyncBootstrapBundle parsing and structure validation', () {
      final bundleJson = {
        'schemaVersion': 1,
        'syncedAt': DateTime.now().toIso8601String(),
        'user': {'id': 'usr_1', 'email': 'user@example.com'},
        'homes': [{'id': 'home_1', 'name': 'Skyline Villa'}],
        'members': [{'userId': 'usr_1', 'role': 'OWNER'}],
        'rooms': [{'id': 'r_1', 'name': 'Living Room'}],
        'devices': [{'id': 'dev_1', 'customName': 'Lamp'}],
        'automations': [{'id': 'a_1', 'name': 'Morning'}],
        'scenes': [{'id': 's_1', 'name': 'Night'}],
        'schedules': [{'id': 'sc_1', 'name': 'Daily'}],
        'notificationPreferences': {'emailAlerts': true},
      };

      final bundle = SyncBootstrapBundle.fromJson(bundleJson);
      expect(bundle.schemaVersion, 1);
      expect(bundle.user['email'], 'user@example.com');
      expect(bundle.homes.length, 1);
      expect(bundle.devices.length, 1);
      expect(bundle.devices[0]['customName'], 'Lamp');
    });
  });

  group('Phase 17 — SyncService State Machine & Offline Queue Tests', () {
    test('Offline mutation queueing and status transitions', () {
      final service = SyncService();
      expect(service.status, SyncStatus.synced);
      expect(service.isOnline, true);

      // Go offline
      service.setOnlineStatus(false);
      expect(service.status, SyncStatus.offline);
      expect(service.isOnline, false);

      // Queue mutation while offline
      service.queueMutation(PendingMutation(
        mutationId: 'mut_offline_1',
        entityType: 'device',
        mutationType: 'update',
        payload: {'customName': 'Chandelier'},
        clientTimestamp: DateTime.now(),
      ));

      expect(service.pendingMutations.length, 1);
      expect(service.status, SyncStatus.offline);

      // Come back online -> status transitions to pendingChanges
      service.setOnlineStatus(true);
      expect(service.status, SyncStatus.pendingChanges);

      // Clear mutations -> status resets to synced
      service.clearPendingMutations();
      expect(service.pendingMutations.length, 0);
      expect(service.status, SyncStatus.synced);
    });

    test('BootstrapSync updates cached bundle and notifies listeners', () async {
      final mockClient = MockClient((request) async {
        if (request.url.path.contains('/api/v1/sync/bootstrap')) {
          final payload = {
            'success': true,
            'data': {
              'schemaVersion': 1,
              'syncedAt': DateTime.now().toIso8601String(),
              'user': {'id': 'usr_1', 'email': 'test@example.com'},
              'homes': [{'id': 'h_1', 'name': 'Main Home'}],
              'members': [],
              'rooms': [{'id': 'r_1', 'name': 'Kitchen'}],
              'devices': [{'id': 'd_1', 'customName': 'Smart Plug'}],
              'automations': [],
              'scenes': [],
              'schedules': [],
            }
          };
          return http.Response(json.encode(payload), 200,
              headers: {'content-type': 'application/json'});
        }
        return http.Response('Not Found', 404);
      });

      final service = SyncService(httpClient: mockClient);
      final bundle = await service.bootstrapSync(homeId: 'h_1');

      expect(bundle.homes.length, 1);
      expect(bundle.devices.length, 1);
      expect(service.cachedBundle, isNotNull);
      expect(service.status, SyncStatus.synced);
    });

    test('ReconcilePending flushes mutations and updates status', () async {
      final mockClient = MockClient((request) async {
        if (request.url.path.contains('/api/v1/sync/reconcile')) {
          final payload = {
            'success': true,
            'data': {
              'reconciledAt': DateTime.now().toIso8601String(),
              'totalMutations': 1,
              'acceptedCount': 1,
              'rejectedCount': 0,
              'conflictCount': 0,
              'results': [
                {
                  'mutationId': 'mut_101',
                  'status': 'ACCEPTED',
                }
              ]
            }
          };
          return http.Response(json.encode(payload), 200,
              headers: {'content-type': 'application/json'});
        }
        return http.Response('Not Found', 404);
      });

      final service = SyncService(httpClient: mockClient);
      service.queueMutation(PendingMutation(
        mutationId: 'mut_101',
        entityType: 'room',
        mutationType: 'create',
        payload: {'name': 'Porch'},
        clientTimestamp: DateTime.now(),
      ));

      expect(service.pendingMutations.length, 1);

      final summary = await service.reconcilePending(homeId: 'h_1');
      expect(summary.acceptedCount, 1);
      expect(service.pendingMutations.isEmpty, true);
      expect(service.status, SyncStatus.synced);
    });
  });

  group('Phase 17 — Sync UI Widgets Tests', () {
    testWidgets('SyncStatusWidget displays correct state pills', (tester) async {
      final service = SyncService();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            appBar: AppBar(
              actions: [
                SyncStatusWidget(syncService: service),
              ],
            ),
          ),
        ),
      );

      // Default: Synced
      expect(find.text('Synced'), findsOneWidget);

      // Offline
      service.setOnlineStatus(false);
      await tester.pumpAndSettle();
      expect(find.text('Offline'), findsOneWidget);

      // Pending
      service.setOnlineStatus(true);
      service.queueMutation(PendingMutation(
        mutationId: 'm1',
        entityType: 'device',
        mutationType: 'update',
        payload: {},
        clientTimestamp: DateTime.now(),
      ));
      await tester.pumpAndSettle();
      expect(find.text('1 Pending'), findsOneWidget);
    });

    testWidgets('SyncCenterPage renders actions and offline queue items', (tester) async {
      final service = SyncService();
      service.queueMutation(PendingMutation(
        mutationId: 'm_test_1',
        entityType: 'room',
        mutationType: 'create',
        payload: {'name': 'Sunroom'},
        clientTimestamp: DateTime.now(),
      ));

      await tester.pumpWidget(
        MaterialApp(
          home: SyncCenterPage(syncService: service),
        ),
      );

      expect(find.text('Cloud Sync & Recovery'), findsOneWidget);
      expect(find.text('Sync Now'), findsOneWidget);
      expect(find.text('Export Data'), findsOneWidget);
      expect(find.text('Offline Pending Queue (1)'), findsOneWidget);
      expect(find.text('CREATE room'), findsOneWidget);
    });
  });
}
