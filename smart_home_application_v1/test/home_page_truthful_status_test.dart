import 'package:flutter_test/flutter_test.dart';
import 'package:smart_home_application_v1/core/models/connection_models.dart';
import 'package:smart_home_application_v1/core/models/home_dashboard_models.dart';

void main() {
  group('Prompt 1 Task 1: Truthful Home Dashboard State & Device Counts', () {
    test('1. When all devices are offline, dashboard data is truthful offline state', () {
      final devices = [
        const ConnectedDeviceSummary(
          id: 'dev_1',
          name: 'Living Room Switch',
          online: false,
          roomName: 'Living Room',
          model: 'EH 4X Switch',
          firmware: '1.0.0',
          connectedVia: 'Wi-Fi',
          signalLabel: 'Offline',
        ),
        const ConnectedDeviceSummary(
          id: 'dev_2',
          name: 'Kitchen Switch',
          online: false,
          roomName: 'Kitchen',
          model: 'EH 2X Switch',
          firmware: '1.0.0',
          connectedVia: 'Wi-Fi',
          signalLabel: 'Offline',
        ),
      ];

      final dashboard = HomeDashboardData.forLiveDevices(
        devices: devices,
        lightOn: false,
        lightConfidence: ActuatorConfidence.unavailable,
        isCloudReachable: false,
        isLocalMode: false,
      );

      // Must be offline, NOT ready!
      expect(dashboard.state, equals(HomeDashboardState.offline));
      expect(dashboard.devicesOnline, equals(0));
      expect(dashboard.deviceCount, equals(2));
      expect(dashboard.activeRoomCount, equals(0));
      expect(dashboard.networkDetail, equals('Offline'));
      expect(dashboard.securityDetail, equals('All devices offline'));
      expect(dashboard.telemetryFreshness, equals(TelemetryFreshness.stale));
    });

    test('2. When only some devices are online, counts and security are truthful', () {
      final devices = [
        const ConnectedDeviceSummary(
          id: 'dev_1',
          name: 'Living Room Switch',
          online: true,
          roomName: 'Living Room',
          model: 'EH 4X Switch',
          firmware: '1.0.0',
          connectedVia: 'Wi-Fi',
          signalLabel: 'Strong',
        ),
        const ConnectedDeviceSummary(
          id: 'dev_2',
          name: 'Kitchen Switch',
          online: false,
          roomName: 'Kitchen',
          model: 'EH 2X Switch',
          firmware: '1.0.0',
          connectedVia: 'Wi-Fi',
          signalLabel: 'Offline',
        ),
      ];

      final dashboard = HomeDashboardData.forLiveDevices(
        devices: devices,
        lightOn: false,
        lightConfidence: ActuatorConfidence.confirmed,
        isCloudReachable: true,
        isLocalMode: false,
      );

      expect(dashboard.state, equals(HomeDashboardState.ready));
      expect(dashboard.devicesOnline, equals(1));
      expect(dashboard.deviceCount, equals(2));
      expect(dashboard.activeRoomCount, equals(1)); // only Living Room is online
      expect(dashboard.networkDetail, equals('Connected'));
      expect(dashboard.securityDetail, equals('1 of 2 online'));
      expect(dashboard.telemetryFreshness, equals(TelemetryFreshness.current));
    });

    test('3. When all devices are online, security confirms all devices online', () {
      final devices = [
        const ConnectedDeviceSummary(
          id: 'dev_1',
          name: 'Living Room Switch',
          online: true,
          roomName: 'Living Room',
          model: 'EH 4X Switch',
          firmware: '1.0.0',
          connectedVia: 'Wi-Fi',
          signalLabel: 'Strong',
        ),
      ];

      final dashboard = HomeDashboardData.forLiveDevices(
        devices: devices,
        lightOn: true,
        lightConfidence: ActuatorConfidence.confirmed,
        isCloudReachable: true,
        isLocalMode: false,
      );

      expect(dashboard.state, equals(HomeDashboardState.ready));
      expect(dashboard.devicesOnline, equals(1));
      expect(dashboard.deviceCount, equals(1));
      expect(dashboard.activeRoomCount, equals(1));
      expect(dashboard.securityDetail, equals('All devices online'));
    });
  });
}
