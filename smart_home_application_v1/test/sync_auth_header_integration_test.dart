import 'package:flutter_test/flutter_test.dart';
import 'package:smart_home_application_v1/core/api/api_client.dart';
import 'package:smart_home_application_v1/core/services/sync_service.dart';

void main() {
  group('Sync Auth Header Integration Tests', () {
    test('SyncService properly retains and resolves auth token', () {
      final apiClient = ApiClient(baseUrl: 'http://127.0.0.1:3000');
      apiClient.getAccessToken = () async => 'test-sync-token-xyz';

      final syncService = SyncService(
        baseUrl: 'http://127.0.0.1:3000',
        apiClient: apiClient,
        getAuthToken: () => 'test-sync-token-xyz',
      );

      expect(syncService.apiClient, isNotNull);
      expect(syncService.getAuthToken!(), equals('test-sync-token-xyz'));
    });
  });
}
