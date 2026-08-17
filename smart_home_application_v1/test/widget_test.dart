import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_home_application_v1/app/app.dart';
import 'package:smart_home_application_v1/app/home_controller.dart';
import 'package:smart_home_application_v1/core/repositories/unavailable_connection_repository.dart';

void main() {
  testWidgets('shows the consumer home dashboard after splash', (tester) async {
    await tester.binding.setSurfaceSize(const Size(360, 800));
    final controller = HomeController(
      connectionRepository: const UnavailableConnectionRepository(),
    );
    await tester.pumpWidget(SmartHomeApp(homeController: controller));
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();

    expect(find.byType(RichText), findsWidgets);
    expect(find.text('All systems normal'), findsOneWidget);
    expect(find.text('Kitchen needs attention'), findsOneWidget);
    expect(find.text('Your rooms'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byIcon(Icons.notifications_none_rounded));
    await tester.pumpAndSettle();
    expect(find.text('Activity'), findsWidgets);

    controller.dispose();
    await tester.binding.setSurfaceSize(null);
  });
}
