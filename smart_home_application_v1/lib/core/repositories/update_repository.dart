import '../../app/home_controller.dart';
import '../models/update_models.dart';

abstract interface class UpdateRepository {
  Future<UpdateSummary> getSummary();
  Future<UpdateSummary> checkForUpdates();
}

class PreviewUpdateRepository implements UpdateRepository {
  const PreviewUpdateRepository();

  @override
  Future<UpdateSummary> getSummary() async {
    final ctrl = HomeController.instance;
    final deviceTargets = (ctrl?.devices ?? []).map((d) {
      return UpdateTarget(
        kind: UpdateTargetKind.device,
        name: d.name,
        currentVersion: 'Version ${d.firmware.isNotEmpty ? d.firmware : "1.0.0"}',
        status: UpdateTargetStatus.upToDate,
        iconKey: 'chip',
      );
    }).toList();

    final allTargets = [
      const UpdateTarget(
        kind: UpdateTargetKind.app,
        name: 'EH Home app',
        currentVersion: 'Version 1.0.0',
        status: UpdateTargetStatus.upToDate,
        iconKey: 'phone',
      ),
      ...deviceTargets,
    ];

    return UpdateSummary(
      overallStatus: UpdateOverallStatus.upToDate,
      title: 'Everything is up to date',
      subtitle: 'Your system is running the latest versions.',
      statusLabel: 'Up to date',
      lastChecked: DateTime.now(),
      appVersion: '1.0.0',
      targets: allTargets,
      history: const [],
    );
  }

  @override
  Future<UpdateSummary> checkForUpdates() async {
    await Future<void>.delayed(const Duration(milliseconds: 600));
    return getSummary();
  }
}
