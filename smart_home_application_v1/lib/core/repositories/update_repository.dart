import '../models/update_models.dart';

abstract interface class UpdateRepository {
  Future<UpdateSummary> getSummary();
  Future<UpdateSummary> checkForUpdates();
}

class PreviewUpdateRepository implements UpdateRepository {
  const PreviewUpdateRepository();

  static final _lastChecked = DateTime(2026, 8, 15, 9, 40);

  static final _history = [
    UpdateHistoryEntry(
      id: 'h1',
      title: 'Firmware 1.0.4',
      deviceName: 'Bedroom Node',
      result: 'Installed successfully',
      installedAt: DateTime(2026, 8, 12, 22, 22),
      releaseNotes: 'Improved connection reliability.',
    ),
    UpdateHistoryEntry(
      id: 'h2',
      title: 'Firmware 1.0.2',
      deviceName: 'Smart Mist Maker',
      result: 'Installed successfully',
      installedAt: DateTime(2026, 7, 28, 18, 40),
    ),
  ];

  @override
  Future<UpdateSummary> getSummary() async => UpdateSummary(
        overallStatus: UpdateOverallStatus.upToDate,
        title: 'Everything is up to date',
        subtitle: 'Your system is running the latest versions.',
        statusLabel: 'Up to date',
        lastChecked: _lastChecked,
        appVersion: '1.0.0',
        targets: const [
          UpdateTarget(
            kind: UpdateTargetKind.app,
            name: 'EH Home app',
            currentVersion: 'Version 1.0.0',
            status: UpdateTargetStatus.upToDate,
            iconKey: 'phone',
          ),
          UpdateTarget(
            kind: UpdateTargetKind.device,
            name: 'Smart Mist Maker',
            currentVersion: 'Version 1.0.0',
            status: UpdateTargetStatus.upToDate,
            iconKey: 'chip',
          ),
        ],
        history: _history,
      );

  @override
  Future<UpdateSummary> checkForUpdates() async {
    await Future<void>.delayed(const Duration(milliseconds: 800));
    return getSummary();
  }
}
