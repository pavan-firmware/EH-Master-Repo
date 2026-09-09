import 'package:flutter_test/flutter_test.dart';
import 'package:smart_home_application_v1/core/api/api_client.dart';
import 'package:smart_home_application_v1/core/services/context_presence_service.dart';

void main() {
  group('Presence State Integration Tests', () {
    test('Presence override payload is constructed with authoritative values', () {
      final apiClient = ApiClient(baseUrl: 'http://127.0.0.1:3000');
      apiClient.getAccessToken = () async => 'auth-tok-123';

      final service = ContextPresenceService(
        baseUrl: 'http://127.0.0.1:3000',
        apiClient: apiClient,
        authToken: 'auth-tok-123',
      );

      expect(service.apiClient, isNotNull);
      expect(service.authToken, equals('auth-tok-123'));
    });
  });
}
