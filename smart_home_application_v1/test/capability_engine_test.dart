import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_home_application_v1/core/capabilities/models/capability_models.dart';
import 'package:smart_home_application_v1/core/capabilities/renderers/capability_renderer_registry.dart';
import 'package:smart_home_application_v1/core/capabilities/services/capability_resolver.dart';
import 'package:smart_home_application_v1/core/capabilities/widgets/brightness_control.dart';
import 'package:smart_home_application_v1/core/capabilities/widgets/cct_control.dart';
import 'package:smart_home_application_v1/core/capabilities/widgets/dynamic_channel_card.dart';
import 'package:smart_home_application_v1/core/capabilities/widgets/dynamic_device_view.dart';
import 'package:smart_home_application_v1/core/capabilities/widgets/energy_card.dart';
import 'package:smart_home_application_v1/core/capabilities/widgets/fan_speed_control.dart';
import 'package:smart_home_application_v1/core/capabilities/widgets/switch_control.dart';
import 'package:smart_home_application_v1/core/theme/app_theme.dart';

void main() {
  Widget wrapWidget(Widget child) {
    return MaterialApp(
      theme: EHAppTheme.lightTheme,
      darkTheme: EHAppTheme.darkTheme,
      home: Scaffold(body: child),
    );
  }

  group('Capability Engine: Unit & Resolution Tests', () {
    test(
      'CapabilityResolver creates ResolvedDevice with custom labels and states',
      () {
        const variant = ProductVariantDefinition(
          schemaVersion: 1,
          productVariantId: 'eh-smart-switch-3x',
          productFamily: 'smart_switch',
          displayName: 'EH Smart Switch 3X',
          channelCount: 3,
          channels: [
            ProductChannelDefinition(
              channelIndex: 1,
              defaultLabel: 'Ch 1',
              capabilities: ['switch', 'relay', 'energy'],
            ),
            ProductChannelDefinition(
              channelIndex: 2,
              defaultLabel: 'Ch 2',
              capabilities: ['switch', 'relay', 'fan_speed'],
            ),
            ProductChannelDefinition(
              channelIndex: 3,
              defaultLabel: 'Ch 3',
              capabilities: ['switch', 'relay'],
            ),
          ],
          capabilities: ['switch', 'relay', 'energy', 'fan_speed'],
        );

        final resolved = CapabilityResolver.resolve(
          productVariant: variant,
          deviceId: 'dev-uuid-1',
          customDeviceName: 'Living Room Hub',
          connectionState: CapabilityConnectionState.online,
          channelLabels: {1: 'Chandelier', 2: 'Ceiling Fan'},
          channelStates: {
            1: {'power': true, 'isPending': false},
            2: {'power': true, 'speed': 3},
          },
        );

        expect(resolved.displayName, 'Living Room Hub');
        expect(resolved.channels.length, 3);
        expect(resolved.channels[0].name, 'Chandelier');
        expect(resolved.channels[0].powerState, isTrue);
        expect(resolved.channels[1].name, 'Ceiling Fan');
        expect(resolved.channels[1].fanSpeed, 3);
        expect(resolved.channels[2].name, 'Ch 3'); // Default fallback
        expect(resolved.hasEnergy, isTrue);
        expect(resolved.hasFanSpeed, isTrue);
      },
    );
  });

  group('Capability Engine: Widget Renderers', () {
    testWidgets(
      'Switch capability renders SwitchControl and responds to taps',
      (tester) async {
        bool power = false;

        await tester.pumpWidget(
          wrapWidget(
            StatefulBuilder(
              builder: (context, setState) => SwitchControl(
                isOn: power,
                label: 'Ceiling Light',
                onChanged: (val) => setState(() => power = val),
              ),
            ),
          ),
        );

        expect(find.byType(SwitchControl), findsOneWidget);
        expect(find.text('Ceiling Light'), findsOneWidget);
        expect(find.text('Turned Off'), findsOneWidget);

        await tester.tap(find.byType(SwitchControl));
        await tester.pump();

        expect(power, isTrue);
        expect(find.text('Turned On'), findsOneWidget);
      },
    );

    testWidgets(
      'Fan Speed capability renders FanSpeedControl with 0..5 levels by default',
      (tester) async {
        int speed = 0;

        await tester.pumpWidget(
          wrapWidget(
            StatefulBuilder(
              builder: (context, setState) => FanSpeedControl(
                speed: speed,
                onSpeedChanged: (s) => setState(() => speed = s),
              ),
            ),
          ),
        );

        expect(find.byType(FanSpeedControl), findsOneWidget);
        expect(find.text('Off'), findsNWidgets(2)); // Badge and button

        // Tap speed 3
        await tester.tap(find.text('3'));
        await tester.pump();

        expect(speed, 3);
        expect(find.text('Speed 3'), findsOneWidget);
      },
    );

    testWidgets('Brightness capability renders BrightnessControl', (
      tester,
    ) async {
      int brightness = 50;

      await tester.pumpWidget(
        wrapWidget(
          StatefulBuilder(
            builder: (context, setState) => BrightnessControl(
              level: brightness,
              onLevelChanged: (b) => setState(() => brightness = b),
            ),
          ),
        ),
      );

      expect(find.byType(BrightnessControl), findsOneWidget);
      expect(find.text('50%'), findsOneWidget);
      expect(find.byType(Slider), findsOneWidget);
    });

    testWidgets('CCT capability renders CCTControl with Kelvin display', (
      tester,
    ) async {
      int cct = 4000;

      await tester.pumpWidget(
        wrapWidget(
          StatefulBuilder(
            builder: (context, setState) => CCTControl(
              kelvin: cct,
              onKelvinChanged: (k) => setState(() => cct = k),
            ),
          ),
        ),
      );

      expect(find.byType(CCTControl), findsOneWidget);
      expect(find.text('4000K'), findsOneWidget);
      expect(find.text('Warm (2700K)'), findsOneWidget);
      expect(find.text('Cool (6500K)'), findsOneWidget);
    });

    testWidgets(
      'Energy capability renders EnergyCard with fixed-point metric conversions',
      (tester) async {
        const telemetry = EnergyTelemetryData(
          voltageMv: 230750, // 230.75 V
          currentMa: 850, // 0.85 A
          powerMw: 196137, // 196.1 W
          energyTotalWh: 14250, // 14.25 kWh
        );

        await tester.pumpWidget(
          wrapWidget(const EnergyCard(telemetry: telemetry)),
        );

        expect(find.byType(EnergyCard), findsOneWidget);
        expect(find.text('196.1 W'), findsOneWidget);
        expect(find.text('14.25 kWh'), findsOneWidget);
        expect(find.text('230.8 V'), findsOneWidget);
        expect(find.text('0.85 A'), findsOneWidget);
      },
    );

    testWidgets(
      'DynamicChannelCard renders only supported capabilities and hides missing',
      (tester) async {
        // Channel with switch only
        const channelSwitchOnly = ResolvedDeviceChannel(
          channelIndex: 1,
          name: 'Spotlight',
          capabilities: ['switch', 'relay'],
        );

        await tester.pumpWidget(
          wrapWidget(
            DynamicChannelCard(
              channel: channelSwitchOnly,
              onChannelUpdated: (_) {},
            ),
          ),
        );

        expect(find.byType(SwitchControl), findsOneWidget);
        expect(find.byType(FanSpeedControl), findsNothing);
        expect(find.byType(BrightnessControl), findsNothing);
        expect(find.byType(CCTControl), findsNothing);
      },
    );

    testWidgets(
      'DynamicDeviceView renders 3 channels for 3X switch and 1 channel for 1X switch',
      (tester) async {
        tester.view.physicalSize = const Size(800, 2000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        // 3X Device
        final device3X = ResolvedDevice(
          deviceId: 'dev-3x',
          productVariantId: 'eh-smart-switch-3x',
          displayName: '3-Gang Switch',
          connectionState: CapabilityConnectionState.online,
          capabilities: const ['switch', 'relay', 'energy'],
          energyTelemetry: const EnergyTelemetryData(
            voltageMv: 230000,
            currentMa: 500,
            powerMw: 115000,
            energyTotalWh: 5000,
          ),
          channels: const [
            ResolvedDeviceChannel(
              channelIndex: 1,
              name: 'Light 1',
              capabilities: ['switch'],
            ),
            ResolvedDeviceChannel(
              channelIndex: 2,
              name: 'Light 2',
              capabilities: ['switch'],
            ),
            ResolvedDeviceChannel(
              channelIndex: 3,
              name: 'Light 3',
              capabilities: ['switch'],
            ),
          ],
        );

        await tester.pumpWidget(
          wrapWidget(DynamicDeviceView(device: device3X)),
        );

        expect(find.byType(DynamicChannelCard), findsNWidgets(3));
        expect(find.text('Channels (3)'), findsOneWidget);
        expect(find.byType(EnergyCard), findsOneWidget);

        // 1X Device without energy
        final device1X = ResolvedDevice(
          deviceId: 'dev-1x',
          productVariantId: 'eh-smart-switch-1x',
          displayName: '1-Gang Switch',
          connectionState: CapabilityConnectionState.offline,
          capabilities: const ['switch'],
          channels: const [
            ResolvedDeviceChannel(
              channelIndex: 1,
              name: 'Main Light',
              capabilities: ['switch'],
            ),
          ],
        );

        await tester.pumpWidget(
          wrapWidget(DynamicDeviceView(device: device1X)),
        );

        expect(find.byType(DynamicChannelCard), findsOneWidget);
        expect(find.text('Channels (1)'), findsOneWidget);
        expect(
          find.byType(EnergyCard),
          findsNothing,
        ); // Hidden when unsupported
      },
    );

    testWidgets(
      'Future Product Extensibility: Custom registered renderer seamlessly renders',
      (tester) async {
        // Register custom capability renderer for a future product (e.g. Smart Curtain)
        CapabilityRendererRegistry.instance.register('curtain_position', (
          context,
          channel,
          onUpdated,
        ) {
          return Container(
            key: const ValueKey('custom_curtain_widget'),
            padding: const EdgeInsets.all(8),
            child: Text('Curtain Position Controller: ${channel.name}'),
          );
        });

        const curtainChannel = ResolvedDeviceChannel(
          channelIndex: 1,
          name: 'Balcony Curtain',
          capabilities: ['curtain_position'],
        );

        await tester.pumpWidget(
          wrapWidget(
            DynamicChannelCard(
              channel: curtainChannel,
              onChannelUpdated: (_) {},
            ),
          ),
        );

        expect(
          find.byKey(const ValueKey('custom_curtain_widget')),
          findsOneWidget,
        );
        expect(
          find.text('Curtain Position Controller: Balcony Curtain'),
          findsOneWidget,
        );
      },
    );
  });

  group('Phase 3 Hardening: Metadata-Driven Range & Config Tests', () {
    testWidgets('Fan 3-speed product renders exactly Off, 1, 2, 3 buttons', (
      tester,
    ) async {
      int speed = 0;
      await tester.pumpWidget(
        wrapWidget(
          StatefulBuilder(
            builder: (context, setState) => FanSpeedControl(
              speed: speed,
              minSpeed: 0,
              maxSpeed: 3,
              step: 1,
              onSpeedChanged: (s) => setState(() => speed = s),
            ),
          ),
        ),
      );

      expect(find.text('Off'), findsNWidgets(2));
      expect(find.text('1'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
      expect(
        find.text('4'),
        findsNothing,
      ); // 4 must not exist in 3-speed product
      expect(find.text('5'), findsNothing);
    });

    testWidgets('Fan 5-speed product renders Off, 1, 2, 3, 4, 5 buttons', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrapWidget(
          FanSpeedControl(
            speed: 2,
            minSpeed: 0,
            maxSpeed: 5,
            onSpeedChanged: (_) {},
          ),
        ),
      );

      expect(find.text('1'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
      expect(find.text('4'), findsOneWidget);
      expect(find.text('5'), findsOneWidget);
    });

    testWidgets(
      'CCT 2200K–6500K range configuration renders correct labels and range',
      (tester) async {
        await tester.pumpWidget(
          wrapWidget(
            CCTControl(
              kelvin: 3000,
              minKelvin: 2200,
              maxKelvin: 6500,
              stepKelvin: 50,
              onKelvinChanged: (_) {},
            ),
          ),
        );

        expect(find.text('Warm (2200K)'), findsOneWidget);
        expect(find.text('Cool (6500K)'), findsOneWidget);
        expect(find.text('3000K'), findsOneWidget);
      },
    );

    testWidgets('CCT 2700K–5700K range configuration renders correct labels', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrapWidget(
          CCTControl(
            kelvin: 4000,
            minKelvin: 2700,
            maxKelvin: 5700,
            stepKelvin: 100,
            onKelvinChanged: (_) {},
          ),
        ),
      );

      expect(find.text('Warm (2700K)'), findsOneWidget);
      expect(find.text('Cool (5700K)'), findsOneWidget);
      expect(find.text('4000K'), findsOneWidget);
    });

    testWidgets('Brightness custom step and range control', (tester) async {
      int brightness = 20;
      await tester.pumpWidget(
        wrapWidget(
          StatefulBuilder(
            builder: (context, setState) => BrightnessControl(
              level: brightness,
              min: 10,
              max: 90,
              step: 5,
              onLevelChanged: (b) => setState(() => brightness = b),
            ),
          ),
        ),
      );

      expect(find.text('20%'), findsOneWidget);
      expect(find.byType(Slider), findsOneWidget);
    });

    testWidgets(
      'EnergyCard with missing/unsupported measurements renders unavailable -- cleanly',
      (tester) async {
        // Telemetry object with only Power and Voltage; Current and Total Energy are null
        const partialTelemetry = EnergyTelemetryData(
          powerMw: 45000, // 45.0 W
          voltageMv: 232000, // 232.0 V
          currentMa: null, // Missing / unsupported
          energyTotalWh: null, // Missing / unsupported
        );

        await tester.pumpWidget(
          wrapWidget(const EnergyCard(telemetry: partialTelemetry)),
        );

        expect(find.text('45.0 W'), findsOneWidget);
        expect(find.text('232.0 V'), findsOneWidget);
        expect(
          find.text('--'),
          findsNWidgets(2),
        ); // Missing current and total energy
      },
    );
  });
}
