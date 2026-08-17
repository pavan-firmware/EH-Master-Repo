import 'package:flutter_test/flutter_test.dart';
import 'package:smart_home_application_v1/core/models/home_dashboard_models.dart';

void main() {
  test('stale critical safety telemetry is never presented as safe', () {
    final alert = DashboardAlert(
      title: 'Gas sensor',
      message: 'Safe',
      severity: AlertSeverity.critical,
      freshness: TelemetryFreshness.stale,
      lastChecked: DateTime.now().subtract(const Duration(minutes: 20)),
    );

    expect(alert.canRepresentCurrentSafetyState, isFalse);
    expect(alert.safeDisplayMessage, contains('State unavailable'));
    expect(alert.safeDisplayMessage, isNot(contains('Safe')));
  });

  test('setup dashboard remains transport-independent', () {
    final dashboard = HomeDashboardData.setup(
      state: HomeDashboardState.wifiRequired,
      title: 'Almost there',
      message: 'Connect to Wi-Fi.',
      action: 'Continue setup',
      connectivity: ConnectivityCause.wifiUnavailable,
    );

    expect(dashboard.isSetupFlow, isTrue);
    expect(dashboard.connectivity, ConnectivityCause.wifiUnavailable);
    expect(dashboard.controls, isEmpty);
  });
}
