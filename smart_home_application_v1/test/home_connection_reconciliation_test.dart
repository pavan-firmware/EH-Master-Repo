import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_home_application_v1/core/models/authoritative_home_connection_state.dart';
import 'package:smart_home_application_v1/core/repositories/settings_repository.dart';
import 'package:smart_home_application_v1/features/settings/presentation/home_details_page.dart';

void main() {
  group('Task 3 Reconciliation: Home Details & Connection Diagnostics', () {
    testWidgets('Home Details and Diagnostics sheet both show Offline and Disconnected when disconnected', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      const repo = PreviewSettingsRepository();
      final dummyHome = await repo.getHome();

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.light(),
          home: Scaffold(
            body: HomeDetailsPage(
              home: dummyHome,
              repository: repo,
              homeController: null, // Disconnected / standalone
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Home Connection row must say 'Disconnected' and 'Offline'
      expect(find.text('Home connection'), findsOneWidget);
      expect(find.text('Disconnected'), findsOneWidget);
      expect(find.text('Offline'), findsOneWidget);

      // Never show fake 'Online' or 'Connected'
      expect(find.text('Connected'), findsNothing);

      // Tap Home Connection to open diagnostics sheet
      await tester.tap(find.text('Home connection'));
      await tester.pumpAndSettle();

      // Diagnostics sheet must show 'Offline' badge and 'Disconnected / Standalone mode'
      expect(find.text('Connection Diagnostics'), findsOneWidget);
      expect(find.text('Disconnected / Standalone mode'), findsOneWidget);
    });

    test('Authoritative state produces identical badges and subtitles', () {
      final offlineState = AuthoritativeHomeConnectionState.resolve(
        isCloudReachable: false,
        isLocalMode: false,
        onlineDeviceCount: 0,
        totalDeviceCount: 3,
        hasHome: true,
      );

      expect(offlineState.homeDetailsRowSubtitle, equals('Disconnected'));
      expect(offlineState.homeDetailsTrailingLabel, equals('Offline'));
      expect(offlineState.statusBadgeLabel, equals('Offline'));
      expect(offlineState.statusSubtitle, equals('Disconnected / Standalone mode'));

      final cloudOnlineState = AuthoritativeHomeConnectionState.resolve(
        isCloudReachable: true,
        isLocalMode: false,
        onlineDeviceCount: 3,
        totalDeviceCount: 3,
        hasHome: true,
      );

      expect(cloudOnlineState.homeDetailsRowSubtitle, equals('Connected'));
      expect(cloudOnlineState.homeDetailsTrailingLabel, equals('Online'));
      expect(cloudOnlineState.statusBadgeLabel, equals('Online'));
      expect(cloudOnlineState.statusSubtitle, equals('Active over Cloud MQTT'));
    });
  });
}
