import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_home_application_v1/core/models/matter_models.dart';
import 'package:smart_home_application_v1/core/theme/app_theme.dart';
import 'package:smart_home_application_v1/features/integrations/presentation/matter_device_status_card.dart';
import 'package:smart_home_application_v1/features/integrations/presentation/connected_platforms_card.dart';
import 'package:smart_home_application_v1/features/integrations/presentation/connect_platform_dialog.dart';
import 'package:smart_home_application_v1/features/integrations/presentation/matter_integration_page.dart';

Widget createTestApp(Widget child) {
  return MaterialApp(
    theme: EHAppTheme.lightTheme,
    darkTheme: EHAppTheme.darkTheme,
    home: Scaffold(body: child),
  );
}

void main() {
  group('Phase 29 — Matter & Ecosystem Models', () {
    test('MatterDeviceSummary serialization and deserialization', () {
      final json = {
        'id': 'md_001',
        'deviceId': 'dev_001',
        'homeId': 'home_001',
        'deviceName': 'Living Room Light',
        'vendorId': 4937,
        'productId': 1,
        'nodeId': '0x0000000000000001',
        'deviceType': 'ON_OFF_LIGHT',
        'deviceTypeId': 256,
        'isCommissioned': true,
        'activeFabricsCount': 2,
        'maxFabricsSupported': 5,
        'passcode': 20202021,
        'discriminator': 3840,
        'softwareVersion': '1.0.0',
        'hardwareVersion': 1,
        'lastSyncedAt': '2026-09-04T12:00:00.000Z',
        'createdAt': '2026-09-04T10:00:00.000Z',
        'updatedAt': '2026-09-04T12:00:00.000Z',
      };

      final device = MatterDeviceSummary.fromJson(json);
      expect(device.id, 'md_001');
      expect(device.deviceId, 'dev_001');
      expect(device.deviceName, 'Living Room Light');
      expect(device.vendorId, 4937);
      expect(device.isCommissioned, true);
      expect(device.activeFabricsCount, 2);
      expect(device.maxFabricsSupported, 5);

      final outJson = device.toJson();
      expect(outJson['deviceId'], 'dev_001');
      expect(outJson['isCommissioned'], true);
    });

    test('MatterFabricModel serialization and deserialization', () {
      final json = {
        'id': 'mf_001',
        'matterDeviceId': 'md_001',
        'fabricIndex': 1,
        'fabricId': 'FABRIC_APPLE_001',
        'fabricLabel': 'Apple Home',
        'rootNodeId': '0x0000000000000001',
        'rootVendorId': 4937,
        'vendorName': 'Apple',
        'status': 'ACTIVE',
        'commissionedAt': '2026-09-04T11:00:00.000Z',
      };

      final fabric = MatterFabricModel.fromJson(json);
      expect(fabric.id, 'mf_001');
      expect(fabric.fabricIndex, 1);
      expect(fabric.fabricLabel, 'Apple Home');
      expect(fabric.status, FabricStatus.active);

      final outJson = fabric.toJson();
      expect(outJson['fabricLabel'], 'Apple Home');
      expect(outJson['status'], 'ACTIVE');
    });

    test('MatterCommissioningSessionModel serialization and deserialization', () {
      final json = {
        'sessionId': 'session_001',
        'deviceId': 'dev_001',
        'homeId': 'home_001',
        'manualPairingCode': '34970112345',
        'qrCodePayload': 'MT:Y.K9042C00KA0648G00',
        'pairingWindowSeconds': 900,
        'expiresAt': '2026-09-04T12:15:00.000Z',
        'status': 'OPEN',
      };

      final session = MatterCommissioningSessionModel.fromJson(json);
      expect(session.sessionId, 'session_001');
      expect(session.manualPairingCode, '34970112345');
      expect(session.qrCodePayload, 'MT:Y.K9042C00KA0648G00');
      expect(session.pairingWindowSeconds, 900);
      expect(session.status, CommissioningSessionStatus.open);
    });

    test('ExternalPlatformLinkModel serialization and deserialization', () {
      final json = {
        'id': 'link_001',
        'homeId': 'home_001',
        'platformType': 'APPLE_HOME',
        'fabricId': 'FABRIC_APPLE_001',
        'platformHomeName': 'My Apartment',
        'externalBridgeNodeId': '0x0000000000000001',
        'linkedDevicesCount': 4,
        'status': 'ACTIVE',
        'lastSyncAt': '2026-09-04T12:00:00.000Z',
      };

      final link = ExternalPlatformLinkModel.fromJson(json);
      expect(link.id, 'link_001');
      expect(link.platformType, ExternalPlatformType.appleHome);
      expect(link.linkedDevicesCount, 4);
      expect(link.status, PlatformLinkStatus.active);
    });

    test('MatterCertificationOverview default NOT CLAIMED transparency', () {
      final cert = MatterCertificationOverview.initial();
      expect(cert.matterCertification, 'NOT CLAIMED');
      expect(cert.appleHomeCertification, 'NOT CLAIMED');
      expect(cert.googleHomeCertification, 'NOT CLAIMED');
      expect(cert.alexaCertification, 'NOT CLAIMED');
      expect(cert.physicalHardwareValidation, 'NOT RUN');
    });
  });

  group('Phase 29 — Presentation Widgets', () {
    testWidgets('MatterDeviceStatusCard renders correctly', (tester) async {
      final device = MatterDeviceSummary(
        id: 'md_001',
        deviceId: 'dev_001',
        homeId: 'home_001',
        deviceName: 'Living Room Smart Switch',
        vendorId: 4937,
        productId: 1,
        nodeId: '0x0000000000000001',
        deviceType: 'ON_OFF_LIGHT',
        deviceTypeId: 256,
        isCommissioned: true,
        activeFabricsCount: 2,
        maxFabricsSupported: 5,
        passcode: 20202021,
        discriminator: 3840,
        softwareVersion: '1.0.0',
        hardwareVersion: 1,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await tester.pumpWidget(
        createTestApp(
          MatterDeviceStatusCard(
            device: device,
            onShareDevice: () {},
            onManageFabrics: () {},
          ),
        ),
      );

      expect(find.text('Living Room Smart Switch'), findsOneWidget);
      expect(find.text('Matter Node: 0x0000000000000001'), findsOneWidget);
      expect(find.text('Active'), findsOneWidget);
      expect(find.text('2 / 5 Fabrics'), findsOneWidget);
      expect(find.text('Share / Link'), findsOneWidget);
      expect(find.text('Fabrics'), findsOneWidget);
    });

    testWidgets('ConnectedPlatformsCard renders Apple Home, Google Home, Alexa', (tester) async {
      final links = [
        ExternalPlatformLinkModel(
          id: 'link_001',
          homeId: 'home_001',
          platformType: ExternalPlatformType.appleHome,
          fabricId: 'FABRIC_APPLE_001',
          linkedDevicesCount: 3,
          status: PlatformLinkStatus.active,
          lastSyncAt: DateTime.now(),
        ),
      ];

      await tester.pumpWidget(
        createTestApp(
          ConnectedPlatformsCard(
            platformLinks: links,
            onConnectPlatform: (_) {},
            onDisconnectPlatform: (_) {},
            onSyncPlatform: (_) {},
          ),
        ),
      );

      expect(find.text('Connected Ecosystems'), findsOneWidget);
      expect(find.text('Apple Home'), findsOneWidget);
      expect(find.text('Google Home'), findsOneWidget);
      expect(find.text('Amazon Alexa'), findsOneWidget);
      expect(find.textContaining('Linked (Fabric FABRIC_A)'), findsOneWidget);
      expect(find.text('Not connected'), findsNWidgets(2));
    });

    testWidgets('ConnectPlatformDialog renders QR and manual pairing code', (tester) async {
      final session = MatterCommissioningSessionModel(
        sessionId: 'session_001',
        deviceId: 'dev_001',
        homeId: 'home_001',
        manualPairingCode: '34970112345',
        qrCodePayload: 'MT:Y.K9042C00KA0648G00',
        pairingWindowSeconds: 900,
        expiresAt: DateTime.now().add(const Duration(minutes: 15)),
        status: CommissioningSessionStatus.open,
      );

      await tester.pumpWidget(
        createTestApp(
          ConnectPlatformDialog(
            session: session,
            deviceName: 'Kitchen Dimmer',
          ),
        ),
      );

      expect(find.text('Link to Ecosystem'), findsOneWidget);
      expect(find.textContaining('Kitchen Dimmer'), findsOneWidget);
      expect(find.text('Matter QR Code'), findsOneWidget);
      expect(find.text('MANUAL PAIRING CODE'), findsOneWidget);
      expect(find.text('3497-011-2345'), findsOneWidget);
      expect(find.text('Code expires in 15 minutes'), findsOneWidget);
      expect(find.text('Done'), findsOneWidget);
    });

    testWidgets('MatterIntegrationPage renders certification disclosures', (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        createTestApp(
          const MatterIntegrationPage(homeId: 'home_001'),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Matter & Ecosystems'), findsOneWidget);
      expect(find.text('Certification & Compliance Disclosure'), findsOneWidget);
      expect(find.text('Matter Protocol'), findsOneWidget);
      expect(find.text('Apple HomeKit'), findsOneWidget);
      expect(find.text('Google Home'), findsNWidgets(2));
      expect(find.text('Amazon Alexa'), findsNWidgets(2));
      expect(find.text('NOT CLAIMED'), findsNWidgets(4));
      expect(find.text('NOT RUN'), findsOneWidget);
    });
  });
}
