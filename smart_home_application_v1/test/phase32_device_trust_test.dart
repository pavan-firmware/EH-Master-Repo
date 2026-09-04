import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_home_application_v1/core/models/device_trust_models.dart';
import 'package:smart_home_application_v1/core/repositories/device_trust_repository.dart';
import 'package:smart_home_application_v1/features/device_trust/presentation/device_security_status_page.dart';

class MockDeviceTrustRepository implements DeviceTrustRepository {
  MockDeviceTrustRepository({
    this.trustState,
    this.securityHistory,
  });

  DeviceTrustStateModel? trustState;
  DeviceSecurityHistoryModel? securityHistory;
  bool shouldThrow = false;
  bool rotationCalled = false;
  bool quarantineCalled = false;
  bool restoreCalled = false;

  @override
  Future<DeviceTrustStateModel> getTrustState(String deviceId) async {
    if (shouldThrow) throw Exception('Network connection error');
    return trustState ??
        DeviceTrustStateModel(
          deviceId: deviceId,
          trustState: TrustState.trusted,
          trustScore: 98.5,
          reasoningJson: {'verified': true},
          lastEvaluatedAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
  }

  @override
  Future<DeviceTrustStateModel> quarantineDevice(
    String deviceId, {
    required String reason,
    Map<String, dynamic>? evidence,
  }) async {
    if (shouldThrow) throw Exception('Failed to quarantine device');
    quarantineCalled = true;
    final updated = DeviceTrustStateModel(
      deviceId: deviceId,
      trustState: TrustState.quarantined,
      trustScore: 30.0,
      quarantinedAt: DateTime.now(),
      lastEvaluatedAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    trustState = updated;
    return updated;
  }

  @override
  Future<DeviceRevocationModel> revokeDevice(
    String deviceId, {
    required String reason,
    String revocationType = 'COMPROMISED',
    bool remediationAllowed = false,
  }) async {
    if (shouldThrow) throw Exception('Failed to revoke device');
    return DeviceRevocationModel(
      id: 'rev_123',
      deviceId: deviceId,
      revocationType: revocationType,
      reason: reason,
      remediationAllowed: remediationAllowed,
      createdAt: DateTime.now(),
    );
  }

  @override
  Future<DeviceTrustStateModel> restoreTrust(
    String deviceId, {
    required String reason,
    bool attestationVerified = true,
  }) async {
    if (shouldThrow) throw Exception('Failed to restore trust');
    restoreCalled = true;
    final updated = DeviceTrustStateModel(
      deviceId: deviceId,
      trustState: TrustState.trusted,
      trustScore: 100.0,
      lastEvaluatedAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    trustState = updated;
    return updated;
  }

  @override
  Future<DeviceCredentialLifecycleModel> initiateRotation(
    String deviceId, {
    required String keyIdentifier,
    String credentialType = 'MQTT',
  }) async {
    if (shouldThrow) throw Exception('Failed to initiate rotation');
    rotationCalled = true;
    return DeviceCredentialLifecycleModel(
      id: 'rot_123',
      deviceId: deviceId,
      credentialType: LifecycleCredentialType.mqtt,
      keyIdentifier: keyIdentifier,
      status: CredentialLifecycleStatus.rotationPending,
      rotationGeneration: 2,
      issuedAt: DateTime.now(),
    );
  }

  @override
  Future<DeviceCredentialLifecycleModel> confirmRotation(
    String deviceId, {
    required String rotationId,
    Map<String, dynamic>? evidence,
  }) async {
    if (shouldThrow) throw Exception('Failed to confirm rotation');
    return DeviceCredentialLifecycleModel(
      id: rotationId,
      deviceId: deviceId,
      credentialType: LifecycleCredentialType.mqtt,
      keyIdentifier: 'key_confirmed',
      status: CredentialLifecycleStatus.confirmed,
      rotationGeneration: 2,
      issuedAt: DateTime.now(),
    );
  }

  @override
  Future<DeviceSecurityHistoryModel> getSecurityHistory(String deviceId) async {
    if (shouldThrow) throw Exception('Failed to query security history');
    return securityHistory ??
        DeviceSecurityHistoryModel(
          deviceId: deviceId,
          trustState: trustState ??
              DeviceTrustStateModel(
                deviceId: deviceId,
                trustState: TrustState.trusted,
                trustScore: 98.5,
                lastEvaluatedAt: DateTime.now(),
                updatedAt: DateTime.now(),
              ),
          revocations: [
            DeviceRevocationModel(
              id: 'rev_prev',
              deviceId: deviceId,
              revocationType: 'COMPROMISED',
              reason: 'Old test incident',
              remediationAllowed: true,
              createdAt: DateTime.now().subtract(const Duration(days: 30)),
            ),
          ],
          lifecycleRecords: [
            DeviceCredentialLifecycleModel(
              id: 'rot_gen1',
              deviceId: deviceId,
              credentialType: LifecycleCredentialType.mqtt,
              keyIdentifier: 'eh_key_gen1',
              status: CredentialLifecycleStatus.confirmed,
              rotationGeneration: 1,
              issuedAt: DateTime.now().subtract(const Duration(days: 60)),
            ),
          ],
        );
  }
}

void main() {
  group('Phase 32 — Device Trust Models & Domain Entities', () {
    test('TrustState parsing and helper methods', () {
      expect(TrustState.fromString('TRUSTED'), equals(TrustState.trusted));
      expect(TrustState.fromString('DEGRADED'), equals(TrustState.degraded));
      expect(TrustState.fromString('QUARANTINED'), equals(TrustState.quarantined));
      expect(TrustState.fromString('REVOKED'), equals(TrustState.revoked));
      expect(TrustState.fromString('DECOMMISSIONED'), equals(TrustState.decommissioned));
      expect(TrustState.fromString('FACTORY_RESET'), equals(TrustState.factoryReset));

      expect(TrustState.trusted.isUsable, isTrue);
      expect(TrustState.degraded.isUsable, isTrue);
      expect(TrustState.quarantined.isUsable, isFalse);
      expect(TrustState.quarantined.isQuarantined, isTrue);
      expect(TrustState.revoked.isRevoked, isTrue);
      expect(TrustState.decommissioned.isRevoked, isTrue);
    });

    test('DeviceTrustStateModel serialization roundtrip', () {
      final now = DateTime.now();
      final model = DeviceTrustStateModel(
        deviceId: '0194fe23-7a1b-7890-a123-456789abcdef',
        trustState: TrustState.trusted,
        trustScore: 99.0,
        reasoningJson: {'authFailures': 0},
        lastEvaluatedAt: now,
        updatedAt: now,
      );

      final json = model.toJson();
      final fromJson = DeviceTrustStateModel.fromJson(json);

      expect(fromJson.deviceId, equals(model.deviceId));
      expect(fromJson.trustState, equals(TrustState.trusted));
      expect(fromJson.trustScore, equals(99.0));
      expect(fromJson.isUsableState(), isTrue);
    });

    test('DeviceCredentialLifecycleModel parsing', () {
      final json = {
        'id': 'rot_001',
        'device_id': '0194fe23-7a1b-7890-a123-456789abcdef',
        'credential_type': 'MQTT',
        'key_identifier': 'eh_key_gen2',
        'status': 'CONFIRMED',
        'rotation_generation': 2,
        'issued_at': '2026-09-04T16:00:00.000Z',
        'metadata': {'algorithm': 'Argon2id'}
      };

      final model = DeviceCredentialLifecycleModel.fromJson(json);
      expect(model.id, equals('rot_001'));
      expect(model.credentialType, equals(LifecycleCredentialType.mqtt));
      expect(model.rotationGeneration, equals(2));
      expect(model.status, equals(CredentialLifecycleStatus.confirmed));
    });
  });

  group('Phase 32 — DeviceSecurityStatusPage Widget Tests', () {
    const testDeviceId = '0194fe23-7a1b-7890-a123-456789abcdef';

    testWidgets('Renders trusted state badge and trust score meter', (tester) async {
      final mockRepo = MockDeviceTrustRepository();

      await tester.pumpWidget(
        MaterialApp(
          home: DeviceSecurityStatusPage(
            repository: mockRepo,
            deviceId: testDeviceId,
            deviceName: 'Living Room Switch Security',
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Living Room Switch Security'), findsOneWidget);
      expect(find.text('Trusted'), findsOneWidget);
      expect(find.text('98.5% Trust'), findsOneWidget);
      expect(find.text('Rotate Keys'), findsOneWidget);
      expect(find.text('Quarantine'), findsOneWidget);
      expect(find.text('Credential Lifecycle Ledger'), findsOneWidget);
      expect(find.text('Revocation & Audit Log'), findsOneWidget);
    });

    testWidgets('Tapping Rotate Keys initiates key rotation', (tester) async {
      final mockRepo = MockDeviceTrustRepository();

      await tester.pumpWidget(
        MaterialApp(
          home: DeviceSecurityStatusPage(
            repository: mockRepo,
            deviceId: testDeviceId,
          ),
        ),
      );

      await tester.pumpAndSettle();

      final rotateButton = find.text('Rotate Keys');
      expect(rotateButton, findsOneWidget);
      await tester.tap(rotateButton);
      await tester.pumpAndSettle();

      expect(mockRepo.rotationCalled, isTrue);
    });

    testWidgets('Tapping Quarantine isolates device and shows Restore button', (tester) async {
      final mockRepo = MockDeviceTrustRepository();

      await tester.pumpWidget(
        MaterialApp(
          home: DeviceSecurityStatusPage(
            repository: mockRepo,
            deviceId: testDeviceId,
          ),
        ),
      );

      await tester.pumpAndSettle();

      final quarantineButton = find.text('Quarantine');
      expect(quarantineButton, findsOneWidget);
      await tester.tap(quarantineButton);
      await tester.pumpAndSettle();

      expect(mockRepo.quarantineCalled, isTrue);
      expect(find.text('Quarantined'), findsOneWidget);
      expect(find.text('Restore Trust'), findsOneWidget);
    });

    testWidgets('Displays error state when repository throws', (tester) async {
      final mockRepo = MockDeviceTrustRepository()..shouldThrow = true;

      await tester.pumpWidget(
        MaterialApp(
          home: DeviceSecurityStatusPage(
            repository: mockRepo,
            deviceId: testDeviceId,
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.textContaining('Error loading security state'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
    });
  });
}

extension on DeviceTrustStateModel {
  bool isUsableState() => trustState.isUsable;
}
