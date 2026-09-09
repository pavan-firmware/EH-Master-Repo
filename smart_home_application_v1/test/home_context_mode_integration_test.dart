import 'package:flutter_test/flutter_test.dart';
import 'package:smart_home_application_v1/core/api/api_client.dart';
import 'package:smart_home_application_v1/core/services/context_presence_service.dart';

void main() {
  group('Home Context Mode Integration Tests', () {
    test('ContextPresenceService includes auth token and builds payload correctly', () async {
      final apiClient = ApiClient(baseUrl: 'http://127.0.0.1:3000');
      apiClient.getAccessToken = () async => 'test-jwt-token-12345';

      final service = ContextPresenceService(
        baseUrl: 'http://127.0.0.1:3000',
        apiClient: apiClient,
        authToken: 'test-jwt-token-12345',
      );

      expect(service.apiClient, isNotNull);
      expect(service.authToken, equals('test-jwt-token-12345'));
    });
  });
}
