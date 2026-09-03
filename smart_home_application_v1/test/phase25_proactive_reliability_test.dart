import 'package:flutter_test/flutter_test.dart';
import 'package:smart_home_application_v1/core/models/reliability_models.dart';

void main() {
  group('Phase 25 — Reliability Models', () {
    test('DeviceHealthState.fromJson maps all values', () {
      expect(DeviceHealthState.fromJson('HEALTHY'), DeviceHealthState.healthy);
      expect(DeviceHealthState.fromJson('DEGRADED'), DeviceHealthState.degraded);
      expect(DeviceHealthState.fromJson('UNSTABLE'), DeviceHealthState.unstable);
      expect(DeviceHealthState.fromJson('UNAVAILABLE'), DeviceHealthState.unavailable);
      expect(DeviceHealthState.fromJson('UNKNOWN'), DeviceHealthState.unknown);
      expect(DeviceHealthState.fromJson('BOGUS'), DeviceHealthState.unknown);
    });

    test('DeviceHealthState display labels are non-empty', () {
      for (final state in DeviceHealthState.values) {
        expect(state.toDisplayLabel(), isNotEmpty);
      }
    });

    test('ReliabilityIncidentType.fromJson maps all values', () {
      expect(
          ReliabilityIncidentType.fromJson('DEVICE_OFFLINE'),
          ReliabilityIncidentType.deviceOffline);
      expect(
          ReliabilityIncidentType.fromJson('TELEMETRY_STALE'),
          ReliabilityIncidentType.telemetryStale);
      expect(
          ReliabilityIncidentType.fromJson('COMMAND_FAILURE'),
          ReliabilityIncidentType.commandFailure);
    });

    test('ReliabilitySeverity.fromJson maps all values', () {
      expect(ReliabilitySeverity.fromJson('LOW'), ReliabilitySeverity.low);
      expect(ReliabilitySeverity.fromJson('MEDIUM'), ReliabilitySeverity.medium);
      expect(ReliabilitySeverity.fromJson('HIGH'), ReliabilitySeverity.high);
      expect(ReliabilitySeverity.fromJson('CRITICAL'), ReliabilitySeverity.critical);
    });

    test('RecoveryActionType toApiValue round-trips correctly', () {
      expect(RecoveryActionType.refreshState.toApiValue(), 'REFRESH_STATE');
      expect(RecoveryActionType.requestTelemetryRefresh.toApiValue(),
          'REQUEST_TELEMETRY_REFRESH');
      expect(RecoveryActionType.retryCommand.toApiValue(), 'RETRY_COMMAND');
      expect(RecoveryActionType.reEvaluateOtaEligibility.toApiValue(),
          'RE_EVALUATE_OTA_ELIGIBILITY');
      expect(RecoveryActionType.markDegraded.toApiValue(), 'MARK_DEGRADED');
    });

    test('RecoveryStatus.fromJson maps all values', () {
      expect(RecoveryStatus.fromJson('RECOVERED'), RecoveryStatus.recovered);
      expect(RecoveryStatus.fromJson('PARTIALLY_RECOVERED'),
          RecoveryStatus.partiallyRecovered);
      expect(RecoveryStatus.fromJson('FAILED'), RecoveryStatus.failed);
      expect(RecoveryStatus.fromJson('VERIFYING'), RecoveryStatus.verifying);
    });

    test('DeviceHealthSnapshot.fromJson parses correctly', () {
      final json = {
        'id': 'snap_01',
        'homeId': 'home_01',
        'deviceId': 'dev_01',
        'healthState': 'DEGRADED',
        'healthScore': 45.5,
        'connectivityScore': 60.0,
        'telemetryScore': 30.0,
        'commandScore': 50.0,
        'uptimeScore': 80.0,
        'activeIncidents': 2,
        'snapshottedAt': '2026-09-03T12:00:00Z',
      };
      final snap = DeviceHealthSnapshot.fromJson(json);
      expect(snap.id, 'snap_01');
      expect(snap.healthState, DeviceHealthState.degraded);
      expect(snap.healthScore, 45.5);
      expect(snap.activeIncidents, 2);
      expect(snap.scoreFormatted, '46/100');
    });

    test('DeviceHealthSnapshot.fromJson handles snake_case keys', () {
      final json = {
        'id': 'snap_02',
        'home_id': 'home_02',
        'device_id': 'dev_02',
        'health_state': 'HEALTHY',
        'health_score': 95,
        'active_incidents': 0,
        'snapshotted_at': '2026-09-03T14:00:00Z',
      };
      final snap = DeviceHealthSnapshot.fromJson(json);
      expect(snap.healthState, DeviceHealthState.healthy);
      expect(snap.healthScore, 95.0);
    });

    test('ReliabilityIncident.fromJson parses correctly', () {
      final json = {
        'id': 'inc_01',
        'homeId': 'home_01',
        'deviceId': 'dev_01',
        'incidentType': 'DEVICE_OFFLINE',
        'severity': 'HIGH',
        'status': 'OPEN',
        'title': 'Device went offline',
        'signalCount': 3,
        'firstObservedAt': '2026-09-03T10:00:00Z',
        'lastObservedAt': '2026-09-03T11:00:00Z',
        'createdAt': '2026-09-03T10:00:00Z',
      };
      final inc = ReliabilityIncident.fromJson(json);
      expect(inc.id, 'inc_01');
      expect(inc.incidentType, ReliabilityIncidentType.deviceOffline);
      expect(inc.severity, ReliabilitySeverity.high);
      expect(inc.isActive, isTrue);
      expect(inc.signalCount, 3);
    });

    test('ReliabilityIncident isActive is false for resolved status', () {
      final json = {
        'id': 'inc_02',
        'homeId': 'home_01',
        'deviceId': 'dev_01',
        'incidentType': 'TELEMETRY_STALE',
        'severity': 'LOW',
        'status': 'RESOLVED',
        'title': 'Resolved',
        'signalCount': 1,
        'firstObservedAt': '2026-09-03T10:00:00Z',
        'lastObservedAt': '2026-09-03T10:30:00Z',
        'createdAt': '2026-09-03T10:00:00Z',
      };
      final inc = ReliabilityIncident.fromJson(json);
      expect(inc.isActive, isFalse);
    });

    test('RecoveryAttempt.fromJson parses correctly', () {
      final json = {
        'id': 'rec_01',
        'incidentId': 'inc_01',
        'homeId': 'home_01',
        'deviceId': 'dev_01',
        'actionType': 'REFRESH_STATE',
        'status': 'RECOVERED',
        'commandAccepted': true,
        'initiatedAt': '2026-09-03T12:00:00Z',
        'completedAt': '2026-09-03T12:01:30Z',
      };
      final rec = RecoveryAttempt.fromJson(json);
      expect(rec.status, RecoveryStatus.recovered);
      expect(rec.commandAccepted, isTrue);
      expect(rec.actionType, RecoveryActionType.refreshState);
    });

    test('RecoveryAttempt commandAccepted handles integer (1/0)', () {
      final json = {
        'id': 'rec_02',
        'incidentId': 'inc_01',
        'homeId': 'home_01',
        'deviceId': 'dev_01',
        'action_type': 'REFRESH_STATE',
        'status': 'FAILED',
        'command_accepted': 0,
        'initiated_at': '2026-09-03T12:00:00Z',
      };
      final rec = RecoveryAttempt.fromJson(json);
      expect(rec.commandAccepted, isFalse);
    });

    test('MaintenanceRecommendation.fromJson parses actionSteps from JSON string', () {
      final json = {
        'id': 'maint_01',
        'homeId': 'home_01',
        'deviceId': 'dev_01',
        'recommendationType': 'NETWORK_CHECK_REQUIRED',
        'priority': 'MEDIUM',
        'title': 'Check Wi-Fi',
        'description': 'Device disconnects frequently',
        'action_steps': '["Check router","Check signal strength"]',
        'status': 'PENDING',
        'created_at': '2026-09-03T08:00:00Z',
      };
      final rec = MaintenanceRecommendation.fromJson(json);
      expect(rec.actionSteps.length, 2);
      expect(rec.actionSteps[0], 'Check router');
      expect(rec.status, 'PENDING');
    });

    test('FleetHealthSummary.fromJson parses correctly', () {
      final json = {
        'homeId': 'home_01',
        'totalDevices': 5,
        'stateDistribution': {
          'HEALTHY': 3,
          'DEGRADED': 1,
          'UNSTABLE': 0,
          'UNAVAILABLE': 1,
          'UNKNOWN': 0,
        },
        'fleetHealthScore': 68.0,
        'activeIncidents': 2,
        'criticalIncidents': 0,
        'pendingRecoveries': 1,
        'generatedAt': '2026-09-03T15:00:00Z',
      };
      final fleet = FleetHealthSummary.fromJson(json);
      expect(fleet.totalDevices, 5);
      expect(fleet.fleetHealthScore, 68.0);
      expect(fleet.stateDistribution['HEALTHY'], 3);
      expect(fleet.scoreFormatted, '68/100');
    });

    test('All RecoveryActionType display labels are non-empty', () {
      for (final action in RecoveryActionType.values) {
        expect(action.toDisplayLabel(), isNotEmpty);
        expect(action.toApiValue(), isNotEmpty);
      }
    });
  });
}
