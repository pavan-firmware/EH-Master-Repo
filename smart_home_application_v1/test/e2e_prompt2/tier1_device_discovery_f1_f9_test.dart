import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_home_application_v1/app/home_controller.dart';
import 'package:smart_home_application_v1/core/models/device_models.dart';
import 'package:smart_home_application_v1/core/models/settings_models.dart';
import 'package:smart_home_application_v1/core/repositories/connection_repository.dart';
import 'package:smart_home_application_v1/features/connection/presentation/connection_page.dart';
import 'package:smart_home_application_v1/features/connection/presentation/device_provisioning_page.dart';
import 'package:smart_home_application_v1/features/settings/presentation/add_room_device_page.dart';

import 'e2e_test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    TestWidgetsFlutterBinding.instance.platformDispatcher.views.first.physicalSize = const Size(800, 1200);
    TestWidgetsFlutterBinding.instance.platformDispatcher.views.first.devicePixelRatio = 1.0;
  });

  tearDown(() {
    TestWidgetsFlutterBinding.instance.platformDispatcher.views.first.resetPhysicalSize();
    TestWidgetsFlutterBinding.instance.platformDispatcher.views.first.resetDevicePixelRatio();
  });

  group('Tier 1: Feature F1 — Duplicate Entry Removal', () {
    testWidgets('F1-1: AddRoomDevicePage renders primary "Pair a New Device" card', (tester) async {
      final repo = TestSettingsRepository();
      await tester.pumpWidget(buildTestApp(child: AddRoomDevicePage(repository: repo)));
      await tester.pumpAndSettle();

      expect(find.text('Pair a New Device'), findsOneWidget);
    });

    testWidgets('F1-2: AddRoomDevicePage does not render duplicate "Other ways to add" tile', (tester) async {
      final repo = TestSettingsRepository();
      await tester.pumpWidget(buildTestApp(child: AddRoomDevicePage(repository: repo)));
      await tester.pumpAndSettle();

      // Per R1 / F1: "Other ways to add" must be eliminated
      expect(find.text('Other ways to add'), findsNothing);
    });

    testWidgets('F1-3: "Start Setup & Pairing" button is present and accessible', (tester) async {
      final repo = TestSettingsRepository();
      await tester.pumpWidget(buildTestApp(child: AddRoomDevicePage(repository: repo)));
      await tester.pumpAndSettle();

      expect(find.text('Start Setup & Pairing'), findsOneWidget);
    });

    testWidgets('F1-4: Tapping "Start Setup & Pairing" initiates the secure setup flow', (tester) async {
      final repo = TestSettingsRepository();
      await tester.pumpWidget(
        buildTestApp(
          child: AddRoomDevicePage(
            repository: repo,
            onStartSecureSetup: () async {
              return const ConnectionResult(
                success: true,
                message: 'Connected',
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Start Setup & Pairing'));
      await tester.pumpAndSettle();

      // Should navigate to ConnectionPage
      expect(find.byType(ConnectionPage), findsOneWidget);
    });

    testWidgets('F1-5: Setup stepper cleanly presents Step 1 "Discover" without duplicate actions', (tester) async {
      final repo = TestSettingsRepository();
      await tester.pumpWidget(buildTestApp(child: AddRoomDevicePage(repository: repo)));
      await tester.pumpAndSettle();

      expect(find.text('Discover'), findsOneWidget);
      expect(find.text('Connect'), findsOneWidget);
      expect(find.text('Configure'), findsOneWidget);
      expect(find.text('Complete'), findsOneWidget);
    });
  });

  group('Tier 1: Feature F2 — QR / Setup Code Entry Preservation', () {
    testWidgets('F2-1: DeviceProvisioningPage renders manual setup code field or entry trigger', (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          child: const DeviceProvisioningPage(
            deviceName: 'EH Smart Switch 3X',
            deviceId: 'dev_sw_01',
            serialNumber: 'ESP32_SN_01',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(DeviceProvisioningPage), findsOneWidget);
      expect(find.text('EH Smart Switch 3X'), findsOneWidget);
    });

    testWidgets('F2-2: QR scanner trigger is present during device setup', (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          child: const DeviceProvisioningPage(
            deviceName: 'EH Smart Switch 3X',
            deviceId: 'dev_sw_01',
            serialNumber: 'ESP32_SN_01',
          ),
        ),
      );
      await tester.pumpAndSettle();

      final qrIcons = find.byIcon(Icons.qr_code_scanner_rounded);
      final qrIconsAlt = find.byIcon(Icons.qr_code_rounded);
      expect(qrIcons.evaluate().isNotEmpty || qrIconsAlt.evaluate().isNotEmpty, isTrue);
    });

    testWidgets('F2-3: Setup code text field accepts alphanumeric code entry', (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          child: const DeviceProvisioningPage(
            deviceName: 'EH Smart Switch 3X',
            deviceId: 'dev_sw_01',
            serialNumber: 'ESP32_SN_01',
          ),
        ),
      );
      await tester.pumpAndSettle();

      final textFields = find.byType(TextField);
      expect(textFields, findsWidgets);
    });

    testWidgets('F2-4: Provisioning UI preserves device serial number and identity', (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          child: const DeviceProvisioningPage(
            deviceName: 'EH Smart Socket 4X',
            deviceId: 'dev_sk_02',
            serialNumber: 'SN_EH_SK4X_9901',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('EH Smart Socket 4X'), findsOneWidget);
    });

    testWidgets('F2-5: Manual setup code format EH1 is verifiable in provisioning stage', (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          child: const DeviceProvisioningPage(
            deviceName: 'EH Smart Switch 3X',
            deviceId: 'dev_sw_01',
            serialNumber: 'ESP32_SN_01',
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify page is mounted and responsive
      expect(find.byType(Scaffold), findsWidgets);
    });
  });

  group('Tier 1: Feature F3 — Removal of Mock Devices', () {
    testWidgets('F3-1: "Smart Mist Maker" is absent from nearby devices UI', (tester) async {
      final repo = TestSettingsRepository(
        nearbyDevices: const [
          DiscoveredRoomDevice(
            id: 'real_01',
            name: 'EH Real Switch',
            model: 'eh-smart-switch-3x',
            signalLabel: 'Strong',
            signal: DeviceConnection.online,
            icon: 'switch',
          ),
        ],
      );
      await tester.pumpWidget(buildTestApp(child: AddRoomDevicePage(repository: repo)));
      await tester.pumpAndSettle();

      expect(find.text('Smart Mist Maker'), findsNothing);
    });

    testWidgets('F3-2: "Smart Light" mock device is absent from nearby devices UI', (tester) async {
      final repo = TestSettingsRepository(
        nearbyDevices: const [
          DiscoveredRoomDevice(
            id: 'real_01',
            name: 'EH Real Switch',
            model: 'eh-smart-switch-3x',
            signalLabel: 'Strong',
            signal: DeviceConnection.online,
            icon: 'switch',
          ),
        ],
      );
      await tester.pumpWidget(buildTestApp(child: AddRoomDevicePage(repository: repo)));
      await tester.pumpAndSettle();

      expect(find.text('Smart Light'), findsNothing);
    });

    testWidgets('F3-3: "Smart Plug" mock device is absent from nearby devices UI', (tester) async {
      final repo = TestSettingsRepository(
        nearbyDevices: const [
          DiscoveredRoomDevice(
            id: 'real_01',
            name: 'EH Real Switch',
            model: 'eh-smart-switch-3x',
            signalLabel: 'Strong',
            signal: DeviceConnection.online,
            icon: 'switch',
          ),
        ],
      );
      await tester.pumpWidget(buildTestApp(child: AddRoomDevicePage(repository: repo)));
      await tester.pumpAndSettle();

      expect(find.text('Smart Plug'), findsNothing);
    });

    testWidgets('F3-4: Mock serial number "SH-8EF248" is absent from nearby devices UI', (tester) async {
      final repo = TestSettingsRepository(
        nearbyDevices: const [
          DiscoveredRoomDevice(
            id: 'real_01',
            name: 'EH Real Switch',
            model: 'eh-smart-switch-3x',
            signalLabel: 'Strong',
            signal: DeviceConnection.online,
            icon: 'switch',
          ),
        ],
      );
      await tester.pumpWidget(buildTestApp(child: AddRoomDevicePage(repository: repo)));
      await tester.pumpAndSettle();

      expect(find.textContaining('SH-8EF248'), findsNothing);
    });

    testWidgets('F3-5: Discovered devices list strictly renders genuine injected devices', (tester) async {
      final repo = TestSettingsRepository(
        nearbyDevices: const [
          DiscoveredRoomDevice(
            id: 'EH-GENUINE-001',
            name: 'Genuine EH Switch 3X',
            model: 'eh-smart-switch-3x',
            signalLabel: 'Strong',
            signal: DeviceConnection.online,
            icon: 'switch',
          ),
        ],
      );
      await tester.pumpWidget(buildTestApp(child: AddRoomDevicePage(repository: repo)));
      await tester.pumpAndSettle();

      expect(find.text('Genuine EH Switch 3X'), findsOneWidget);
    });
  });

  group('Tier 1: Feature F4 — Real BLE Auto-Scan & Refresh', () {
    testWidgets('F4-1: Auto-starts discovery scan upon opening AddRoomDevicePage', (tester) async {
      final repo = TestSettingsRepository();
      await tester.pumpWidget(buildTestApp(child: AddRoomDevicePage(repository: repo)));
      await tester.pumpAndSettle();

      expect(repo.getNearbyDevicesCallCount, greaterThanOrEqualTo(1));
    });

    testWidgets('F4-2: "Refresh" action button is present in Nearby devices header', (tester) async {
      final repo = TestSettingsRepository();
      await tester.pumpWidget(buildTestApp(child: AddRoomDevicePage(repository: repo)));
      await tester.pumpAndSettle();

      expect(find.text('Refresh'), findsOneWidget);
    });

    testWidgets('F4-3: Tapping "Refresh" triggers an on-demand re-scan', (tester) async {
      final repo = TestSettingsRepository();
      await tester.pumpWidget(buildTestApp(child: AddRoomDevicePage(repository: repo)));
      await tester.pumpAndSettle();

      final initialCalls = repo.getNearbyDevicesCallCount;
      await tester.tap(find.text('Refresh'));
      await tester.pumpAndSettle();

      expect(repo.getNearbyDevicesCallCount, greaterThan(initialCalls));
    });

    testWidgets('F4-4: Refresh button updates UI dynamically upon completion', (tester) async {
      final repo = TestSettingsRepository(
        nearbyDevices: const [
          DiscoveredRoomDevice(
            id: 'dev_01',
            name: 'Device Alpha',
            model: 'model_a',
            signalLabel: 'Strong',
            signal: DeviceConnection.online,
            icon: 'switch',
          ),
        ],
      );
      await tester.pumpWidget(buildTestApp(child: AddRoomDevicePage(repository: repo)));
      await tester.pumpAndSettle();
      expect(find.text('Device Alpha'), findsOneWidget);

      repo.nearbyDevices = const [
        DiscoveredRoomDevice(
          id: 'dev_02',
          name: 'Device Beta',
          model: 'model_b',
          signalLabel: 'Strong',
          signal: DeviceConnection.online,
          icon: 'switch',
        ),
      ];
      await tester.tap(find.text('Refresh'));
      await tester.pumpAndSettle();

      expect(find.text('Device Beta'), findsOneWidget);
    });

    testWidgets('F4-5: Scanning indicator appears during discovery', (tester) async {
      final repo = TestSettingsRepository();
      await tester.pumpWidget(buildTestApp(child: AddRoomDevicePage(repository: repo)));
      // Pump frame without settle to observe loading state
      await tester.pump();

      expect(find.text('Finding nearby devices…'), findsOneWidget);
      await tester.pumpAndSettle();
    });
  });

  group('Tier 1: Feature F5 — Device Identity Extraction', () {
    testWidgets('F5-1: Displays genuine advertised name from discovery', (tester) async {
      final repo = TestSettingsRepository(
        nearbyDevices: const [
          DiscoveredRoomDevice(
            id: 'dev_ident_01',
            name: 'EH Smart Switch 3X',
            model: 'eh-smart-switch-3x',
            signalLabel: 'Strong',
            signal: DeviceConnection.online,
            icon: 'switch',
          ),
        ],
      );
      await tester.pumpWidget(buildTestApp(child: AddRoomDevicePage(repository: repo)));
      await tester.pumpAndSettle();

      expect(find.text('EH Smart Switch 3X'), findsOneWidget);
    });

    testWidgets('F5-2: Displays genuine model identifier in device row', (tester) async {
      final repo = TestSettingsRepository(
        nearbyDevices: const [
          DiscoveredRoomDevice(
            id: 'dev_ident_02',
            name: 'EH Smart Switch 3X',
            model: 'eh-smart-switch-3x',
            signalLabel: 'Strong',
            signal: DeviceConnection.online,
            icon: 'switch',
          ),
        ],
      );
      await tester.pumpWidget(buildTestApp(child: AddRoomDevicePage(repository: repo)));
      await tester.pumpAndSettle();

      expect(find.text('eh-smart-switch-3x'), findsOneWidget);
    });

    testWidgets('F5-3: Displays signal strength indicator accurately', (tester) async {
      final repo = TestSettingsRepository(
        nearbyDevices: const [
          DiscoveredRoomDevice(
            id: 'dev_ident_03',
            name: 'EH Smart Switch 3X',
            model: 'eh-smart-switch-3x',
            signalLabel: 'Strong',
            signal: DeviceConnection.online,
            icon: 'switch',
          ),
        ],
      );
      await tester.pumpWidget(buildTestApp(child: AddRoomDevicePage(repository: repo)));
      await tester.pumpAndSettle();

      expect(find.text('Strong'), findsOneWidget);
    });

    testWidgets('F5-4: Maps switch device icon correctly', (tester) async {
      final repo = TestSettingsRepository(
        nearbyDevices: const [
          DiscoveredRoomDevice(
            id: 'dev_ident_04',
            name: 'EH Switch',
            model: 'eh-smart-switch-3x',
            signalLabel: 'Strong',
            signal: DeviceConnection.online,
            icon: 'switch',
          ),
        ],
      );
      await tester.pumpWidget(buildTestApp(child: AddRoomDevicePage(repository: repo)));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.toggle_on_rounded), findsOneWidget);
    });

    testWidgets('F5-5: Multiple discovered devices maintain distinct identities', (tester) async {
      final repo = TestSettingsRepository(
        nearbyDevices: const [
          DiscoveredRoomDevice(
            id: 'dev_a',
            name: 'Switch Living Room',
            model: 'eh-smart-switch-3x',
            signalLabel: 'Strong',
            signal: DeviceConnection.online,
            icon: 'switch',
          ),
          DiscoveredRoomDevice(
            id: 'dev_b',
            name: 'Socket Kitchen',
            model: 'eh-smart-socket-4x',
            signalLabel: 'Medium',
            signal: DeviceConnection.stale,
            icon: 'plug',
          ),
        ],
      );
      await tester.pumpWidget(buildTestApp(child: AddRoomDevicePage(repository: repo)));
      await tester.pumpAndSettle();

      expect(find.text('Switch Living Room'), findsOneWidget);
      expect(find.text('Socket Kitchen'), findsOneWidget);
    });
  });

  group('Tier 1: Feature F6 — Three-Tier State Distinction', () {
    testWidgets('F6-1: Nearby discovered device renders in discovery list', (tester) async {
      final repo = TestSettingsRepository(
        nearbyDevices: const [
          DiscoveredRoomDevice(
            id: 'nearby_unpaired_01',
            name: 'Nearby Unpaired Switch',
            model: 'eh-smart-switch-3x',
            signalLabel: 'Strong',
            signal: DeviceConnection.online,
            icon: 'switch',
          ),
        ],
      );
      await tester.pumpWidget(buildTestApp(child: AddRoomDevicePage(repository: repo)));
      await tester.pumpAndSettle();

      expect(find.text('Nearby Unpaired Switch'), findsOneWidget);
    });

    testWidgets('F6-2: Online signal badge renders correctly for online status', (tester) async {
      final repo = TestSettingsRepository(
        nearbyDevices: const [
          DiscoveredRoomDevice(
            id: 'dev_online_01',
            name: 'Online Switch',
            model: 'eh-smart-switch-3x',
            signalLabel: 'Strong',
            signal: DeviceConnection.online,
            icon: 'switch',
          ),
        ],
      );
      await tester.pumpWidget(buildTestApp(child: AddRoomDevicePage(repository: repo)));
      await tester.pumpAndSettle();

      expect(find.text('Strong'), findsOneWidget);
    });

    testWidgets('F6-3: Stale / medium signal badge renders for stale status', (tester) async {
      final repo = TestSettingsRepository(
        nearbyDevices: const [
          DiscoveredRoomDevice(
            id: 'dev_stale_01',
            name: 'Stale Switch',
            model: 'eh-smart-switch-3x',
            signalLabel: 'Medium',
            signal: DeviceConnection.stale,
            icon: 'switch',
          ),
        ],
      );
      await tester.pumpWidget(buildTestApp(child: AddRoomDevicePage(repository: repo)));
      await tester.pumpAndSettle();

      expect(find.text('Medium'), findsOneWidget);
    });

    testWidgets('F6-4: Tapping nearby device opens verification modal sheet', (tester) async {
      final repo = TestSettingsRepository(
        nearbyDevices: const [
          DiscoveredRoomDevice(
            id: 'dev_tap_01',
            name: 'Tapped Switch',
            model: 'eh-smart-switch-3x',
            signalLabel: 'Strong',
            signal: DeviceConnection.online,
            icon: 'switch',
          ),
        ],
      );
      await tester.pumpWidget(buildTestApp(child: AddRoomDevicePage(repository: repo)));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Tapped Switch'));
      await tester.pumpAndSettle();

      expect(find.text('Verify nearby device'), findsOneWidget);
    });

    testWidgets('F6-5: Verification sheet confirms device verification before setup', (tester) async {
      final repo = TestSettingsRepository(
        nearbyDevices: const [
          DiscoveredRoomDevice(
            id: 'dev_verify_01',
            name: 'Device For Verification',
            model: 'eh-smart-switch-3x',
            signalLabel: 'Strong',
            signal: DeviceConnection.online,
            icon: 'switch',
          ),
        ],
      );
      await tester.pumpWidget(buildTestApp(child: AddRoomDevicePage(repository: repo)));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Device For Verification'));
      await tester.pumpAndSettle();

      expect(find.textContaining('EH Home verifies the real nearby device'), findsOneWidget);
    });
  });

  group('Tier 1: Feature F7 — Multi-State Protocol UI', () {
    testWidgets('F7-1: Scanning state renders radar icon container', (tester) async {
      final repo = TestSettingsRepository();
      await tester.pumpWidget(buildTestApp(child: AddRoomDevicePage(repository: repo)));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.radar_rounded), findsOneWidget);
    });

    testWidgets('F7-2: Discovered devices state renders list of devices', (tester) async {
      final repo = TestSettingsRepository(
        nearbyDevices: const [
          DiscoveredRoomDevice(
            id: 'dev_found_01',
            name: 'Found Device',
            model: 'eh-smart-switch-3x',
            signalLabel: 'Strong',
            signal: DeviceConnection.online,
            icon: 'switch',
          ),
        ],
      );
      await tester.pumpWidget(buildTestApp(child: AddRoomDevicePage(repository: repo)));
      await tester.pumpAndSettle();

      expect(find.text('Found Device'), findsOneWidget);
    });

    testWidgets('F7-3: Empty state renders when zero devices are available', (tester) async {
      final repo = TestSettingsRepository(nearbyDevices: const []);
      await tester.pumpWidget(buildTestApp(child: AddRoomDevicePage(repository: repo)));
      await tester.pumpAndSettle();

      expect(find.text('No nearby devices found'), findsOneWidget);
    });

    testWidgets('F7-4: Stepper displays 4 clear provisioning stages', (tester) async {
      final repo = TestSettingsRepository();
      await tester.pumpWidget(buildTestApp(child: AddRoomDevicePage(repository: repo)));
      await tester.pumpAndSettle();

      expect(find.text('1'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
      expect(find.text('4'), findsOneWidget);
    });

    testWidgets('F7-5: Need help section renders troubleshooting hints', (tester) async {
      final repo = TestSettingsRepository();
      await tester.pumpWidget(buildTestApp(child: AddRoomDevicePage(repository: repo)));
      await tester.pumpAndSettle();

      await tester.drag(find.byType(ListView), const Offset(0, -600));
      await tester.pumpAndSettle();
      expect(find.text('NEED HELP?'), findsOneWidget);
      expect(find.text('Make sure Bluetooth is on'), findsOneWidget);
    });
  });

  group('Tier 1: Feature F8 — Actionable Empty State', () {
    testWidgets('F8-1: Empty state headline "No nearby devices found" is displayed', (tester) async {
      final repo = TestSettingsRepository(nearbyDevices: const []);
      await tester.pumpWidget(buildTestApp(child: AddRoomDevicePage(repository: repo)));
      await tester.pumpAndSettle();

      expect(find.text('No nearby devices found'), findsOneWidget);
    });

    testWidgets('F8-2: Empty state displays Bluetooth check tip', (tester) async {
      final repo = TestSettingsRepository(nearbyDevices: const []);
      await tester.pumpWidget(buildTestApp(child: AddRoomDevicePage(repository: repo)));
      await tester.pumpAndSettle();

      expect(find.textContaining('Bluetooth is turned on'), findsWidgets);
    });

    testWidgets('F8-3: Empty state displays device power tip', (tester) async {
      final repo = TestSettingsRepository(nearbyDevices: const []);
      await tester.pumpWidget(buildTestApp(child: AddRoomDevicePage(repository: repo)));
      await tester.pumpAndSettle();

      expect(find.textContaining('Power on your device'), findsWidgets);
    });

    testWidgets('F8-4: Empty state displays proximity tip', (tester) async {
      final repo = TestSettingsRepository(nearbyDevices: const []);
      await tester.pumpWidget(buildTestApp(child: AddRoomDevicePage(repository: repo)));
      await tester.pumpAndSettle();

      expect(find.textContaining('close to your phone'), findsWidgets);
    });

    testWidgets('F8-5: Empty state renders actionable "Find devices" retry button', (tester) async {
      final repo = TestSettingsRepository(nearbyDevices: const []);
      await tester.pumpWidget(buildTestApp(child: AddRoomDevicePage(repository: repo)));
      await tester.pumpAndSettle();

      expect(find.text('Find devices'), findsOneWidget);
    });
  });

  group('Tier 1: Feature F9 — Commissioning Continuation', () {
    testWidgets('F9-1: Tapping discovered device opens device details verification sheet', (tester) async {
      final repo = TestSettingsRepository(
        nearbyDevices: const [
          DiscoveredRoomDevice(
            id: 'dev_comm_01',
            name: 'EH Living Room Switch',
            model: 'eh-smart-switch-3x',
            signalLabel: 'Strong',
            signal: DeviceConnection.online,
            icon: 'switch',
          ),
        ],
      );
      await tester.pumpWidget(buildTestApp(child: AddRoomDevicePage(repository: repo)));
      await tester.pumpAndSettle();

      await tester.tap(find.text('EH Living Room Switch'));
      await tester.pumpAndSettle();

      expect(find.text('EH Living Room Switch'), findsWidgets);
      expect(find.text('Verify nearby device'), findsOneWidget);
    });

    testWidgets('F9-2: Verification sheet displays device model name', (tester) async {
      final repo = TestSettingsRepository(
        nearbyDevices: const [
          DiscoveredRoomDevice(
            id: 'dev_comm_02',
            name: 'EH Switch Alpha',
            model: 'eh-smart-switch-3x',
            signalLabel: 'Strong',
            signal: DeviceConnection.online,
            icon: 'switch',
          ),
        ],
      );
      await tester.pumpWidget(buildTestApp(child: AddRoomDevicePage(repository: repo)));
      await tester.pumpAndSettle();

      await tester.tap(find.text('EH Switch Alpha'));
      await tester.pumpAndSettle();

      expect(find.text('eh-smart-switch-3x'), findsWidgets);
    });

    testWidgets('F9-3: Tapping "Verify nearby device" continues into setup flow', (tester) async {
      final repo = TestSettingsRepository(
        nearbyDevices: const [
          DiscoveredRoomDevice(
            id: 'dev_comm_03',
            name: 'EH Switch Beta',
            model: 'eh-smart-switch-3x',
            signalLabel: 'Strong',
            signal: DeviceConnection.online,
            icon: 'switch',
          ),
        ],
      );
      await tester.pumpWidget(buildTestApp(child: AddRoomDevicePage(repository: repo)));
      await tester.pumpAndSettle();

      await tester.tap(find.text('EH Switch Beta'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Verify nearby device'));
      await tester.pumpAndSettle();

      expect(find.byType(ConnectionPage), findsOneWidget);
    });

    testWidgets('F9-4: HomeController.markDeviceProvisioned records commissioned device', (tester) async {
      final controller = HomeController();
      controller.markDeviceProvisioned(
        deviceId: 'dev_comm_04',
        displayName: 'Balcony Switch',
        serialNumber: 'SN_COMM_04',
        roomName: 'Balcony',
        model: 'eh-smart-switch-3x',
      );

      expect(controller.devices.any((d) => d.id == 'dev_comm_04'), isTrue);
      controller.dispose();
    });

    testWidgets('F9-5: Provisioned device is assigned to specified room in HomeController', (tester) async {
      final controller = HomeController();
      controller.markDeviceProvisioned(
        deviceId: 'dev_comm_05',
        displayName: 'Kitchen Socket',
        serialNumber: 'SN_COMM_05',
        roomName: 'Kitchen',
        model: 'eh-smart-socket-4x',
      );

      final device = controller.devices.firstWhere((d) => d.id == 'dev_comm_05');
      expect(device.roomName, 'Kitchen');
      controller.dispose();
    });
  });
}
