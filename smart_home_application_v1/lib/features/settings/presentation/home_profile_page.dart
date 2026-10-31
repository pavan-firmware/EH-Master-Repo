import 'package:flutter/material.dart';

import '../../../app/home_controller.dart';
import '../../../core/models/device_models.dart';
import '../../../core/models/settings_models.dart';
import '../../../core/repositories/connection_repository.dart';
import '../../../core/repositories/settings_repository.dart';
import 'home_details_page.dart';

/// Single authoritative home profile / details entry point.
/// Unifies the previous duplicate HomeProfilePage and HomeDetailsPage screens
/// into a single production-grade interface.
class HomeProfilePage extends StatelessWidget {
  const HomeProfilePage({
    super.key,
    required this.home,
    required this.repository,
    this.connectionState,
    this.onConnectHome,
    this.homeController,
  });

  final HomeSettingsData home;
  final SettingsRepository repository;
  final HomeConnectionState? connectionState;
  final Future<ConnectionResult> Function()? onConnectHome;
  final HomeController? homeController;

  @override
  Widget build(BuildContext context) {
    return HomeDetailsPage(
      home: home,
      repository: repository,
      homeController: homeController,
    );
  }
}
