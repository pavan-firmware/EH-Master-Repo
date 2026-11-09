import 'package:flutter/material.dart';
import '../../../core/models/recovery_models.dart';
import '../../../core/repositories/recovery_repository.dart';
import '../../settings/presentation/settings_ui.dart';

class RecoveryDashboardPage extends StatefulWidget {
  const RecoveryDashboardPage({
    super.key,
    required this.repository,
    this.isAdmin = true,
  });

  final RecoveryRepository repository;
  final bool isAdmin;

  @override
  State<RecoveryDashboardPage> createState() => _RecoveryDashboardPageState();
}

class _RecoveryDashboardPageState extends State<RecoveryDashboardPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Tab 0: Backups state
  List<BackupRecordModel> _backups = [];
  bool _backupsLoading = true;
  String? _backupsError;

  // Tab 1: Integrity state
  List<RecoveryIntegrityModel> _integrityRecords = [];
  RecoveryIntegrityModel? _latestIntegrity;
  bool _integrityLoading = true;
  String? _integrityError;

  // Tab 2: Restore / Checkpoints state
  List<RecoveryCheckpointModel> _checkpoints = [];
  RestorePlanModel? _currentPlan;
  RestoreOperationModel? _lastRestoreResult;
  String? _selectedBackupIdForRestore;
  bool _checkpointsLoading = true;
  String? _checkpointsError;

  // Global action state
  bool _isActionRunning = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    if (widget.isAdmin) {
      _loadAll();
    } else {
      _backupsLoading = false;
      _integrityLoading = false;
      _checkpointsLoading = false;
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  String _mapError(Object err) {
    final str = err.toString().toLowerCase();
    if (str.contains('401') || str.contains('unauthorized')) {
      return 'Authentication session expired. Please sign in again.';
    }
    if (str.contains('403') || str.contains('forbidden')) {
      return 'Administrative role required. Disaster recovery requires administrative permissions.';
    }
    if (str.contains('404') || str.contains('not found')) {
      return 'Requested recovery resource was not found on the platform.';
    }
    if (str.contains('502') ||
        str.contains('503') ||
        str.contains('unavailable')) {
      return 'Backup storage is currently unavailable. Please retry shortly.';
    }
    if (str.contains('timeout') || str.contains('timed out')) {
      return 'Recovery API request timed out.';
    }
    if (str.contains('socket') ||
        str.contains('network') ||
        str.contains('connection') ||
        str.contains('failed host lookup')) {
      return 'Unable to reach the recovery API. Please check your network and retry.';
    }
    return err.toString();
  }

  Future<void> _loadBackups() async {
    setState(() {
      _backupsLoading = true;
      _backupsError = null;
    });
    try {
      final list = await widget.repository.listBackups();
      if (mounted) {
        setState(() {
          _backups = list;
          _backupsLoading = false;
          _backupsError = null;
        });
      }
    } catch (err) {
      if (mounted) {
        setState(() {
          _backupsLoading = false;
          _backupsError = _mapError(err);
        });
      }
    }
  }

  Future<void> _loadIntegrity() async {
    setState(() {
      _integrityLoading = true;
      _integrityError = null;
    });
    try {
      final results = await widget.repository.listIntegrityResults();
      if (mounted) {
        setState(() {
          _integrityRecords = results;
          if (_latestIntegrity == null && results.isNotEmpty) {
            _latestIntegrity = results.first;
          }
          _integrityLoading = false;
          _integrityError = null;
        });
      }
    } catch (err) {
      if (mounted) {
        setState(() {
          _integrityLoading = false;
          _integrityError = _mapError(err);
        });
      }
    }
  }

  Future<void> _loadCheckpoints() async {
    setState(() {
      _checkpointsLoading = true;
      _checkpointsError = null;
    });
    try {
      final list = await widget.repository.listCheckpoints();
      if (mounted) {
        setState(() {
          _checkpoints = list;
          _checkpointsLoading = false;
          _checkpointsError = null;
        });
      }
    } catch (err) {
      if (mounted) {
        setState(() {
          _checkpointsLoading = false;
          _checkpointsError = _mapError(err);
        });
      }
    }
  }

  Future<void> _loadAll() async {
    await Future.wait([_loadBackups(), _loadIntegrity(), _loadCheckpoints()]);
  }

  Future<void> _triggerBackup() async {
    setState(() => _isActionRunning = true);
    try {
      await widget.repository.createBackup(scope: 'FULL');
      await _loadBackups();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Backup snapshot created successfully.'),
          ),
        );
      }
    } catch (err) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Backup failed: ${_mapError(err)}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isActionRunning = false);
    }
  }

  Future<void> _verifyBackup(String backupId) async {
    setState(() => _isActionRunning = true);
    try {
      final report = await widget.repository.verifyBackupIntegrity(backupId);
      setState(() {
        _latestIntegrity = report;
        _integrityRecords.removeWhere((r) => r.backupId == report.backupId);
        _integrityRecords.insert(0, report);
      });
      _tabController.animateTo(1); // Switch to Integrity tab
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Integrity status: ${report.status.label} (${report.verifiedObjectsCount} verified)',
            ),
            backgroundColor: report.status == IntegrityStatus.valid
                ? Colors.green
                : Colors.orange,
          ),
        );
      }
    } catch (err) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Verification failed: ${_mapError(err)}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isActionRunning = false);
    }
  }

  Future<void> _planRestore(String backupId) async {
    setState(() {
      _isActionRunning = true;
      _selectedBackupIdForRestore = backupId;
    });
    try {
      final plan = await widget.repository.planRestore(backupId);
      setState(() {
        _currentPlan = plan;
      });
      _tabController.animateTo(2); // Switch to Restore tab
    } catch (err) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Restore planning failed: ${_mapError(err)}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isActionRunning = false);
    }
  }

  Future<void> _executeRestore(String backupId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Platform State Restore'),
        content: const Text(
          'This will restore database state to the selected backup point.\n\n'
          'Security revocations, decommissioned states, and expired credentials will be strictly preserved.\n\n'
          'Proceed with restore?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Execute Restore'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isActionRunning = true);
    try {
      final result = await widget.repository.executeRestore(backupId);
      setState(() {
        _lastRestoreResult = result;
      });
      await _loadAll();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Restore completed successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (err) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Restore failed: ${_mapError(err)}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isActionRunning = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isAdmin) {
      return Scaffold(
        appBar: AppBar(title: const Text('Disaster Recovery')),
        body: const AdminAccessRequiredView(
          message:
              'Disaster recovery snapshots, automated checkpoints, and rollback restoration require platform administrative privileges.',
        ),
      );
    }

    final bool isGlobalBusy =
        _backupsLoading ||
        _integrityLoading ||
        _checkpointsLoading ||
        _isActionRunning;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Disaster Recovery & Resilience'),
        actions: [
          settingsHelpAction(context, screenId: 'recovery'),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh all recovery data',
            onPressed: isGlobalBusy ? null : _loadAll,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Backups', icon: Icon(Icons.backup_rounded)),
            Tab(text: 'Integrity', icon: Icon(Icons.verified_user_rounded)),
            Tab(text: 'Restore', icon: Icon(Icons.restore_rounded)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildBackupsTab(),
          _buildIntegrityTab(),
          _buildRestoreTab(),
        ],
      ),
    );
  }

  Widget _buildTabErrorBanner(String error, VoidCallback onRetry) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, color: Colors.red, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Failed to refresh data',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.red,
                  ),
                ),
                Text(
                  error,
                  style: const TextStyle(fontSize: 11, color: Colors.black87),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: onRetry,
            child: const Text(
              'Retry',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyOrErrorPlaceholder({
    required IconData icon,
    required String title,
    required String message,
    String? retryLabel,
    VoidCallback? onRetry,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: Text(retryLabel ?? 'Retry'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryHeader() {
    final completedBackups = _backups
        .where((b) => b.status == BackupStatus.completed)
        .toList();
    final lastBackupTime = completedBackups.isNotEmpty
        ? completedBackups.first.createdAt.toLocal().toString().split('.')[0]
        : 'None';

    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'RECOVERY STATE OVERVIEW',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    letterSpacing: 1.1,
                  ),
                ),
                _buildStatusBadge(
                  _latestIntegrity?.status.label ?? 'OBSERVED',
                  _latestIntegrity?.status == IntegrityStatus.valid
                      ? Colors.green
                      : Colors.orange,
                ),
              ],
            ),
            const Divider(height: 24),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Last Successful Backup',
                        style: TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        lastBackupTime,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Total Snapshots',
                        style: TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${_backups.length}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Checkpoints',
                        style: TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${_checkpoints.length}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.add_circle_outline_rounded),
                label: const Text('Create New Backup Snapshot'),
                onPressed: _isActionRunning ? null : _triggerBackup,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBackupsTab() {
    if (_backupsLoading && _backups.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_backupsError != null && _backups.isEmpty) {
      return _buildEmptyOrErrorPlaceholder(
        icon: Icons.cloud_off_rounded,
        title: 'Failed to load recovery platform data',
        message: _backupsError!,
        onRetry: _loadBackups,
      );
    }

    return RefreshIndicator(
      onRefresh: _loadBackups,
      child: ListView(
        children: [
          if (_backupsError != null)
            _buildTabErrorBanner(_backupsError!, _loadBackups),
          _buildSummaryHeader(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              'AVAILABLE BACKUP SNAPSHOTS (${_backups.length})',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
                color: Colors.grey,
              ),
            ),
          ),
          if (_backups.isEmpty)
            Padding(
              padding: const EdgeInsets.all(32.0),
              child: Center(
                child: Text(
                  'No backup snapshots available yet.',
                  style: TextStyle(color: Colors.grey.shade600),
                ),
              ),
            )
          else
            ..._backups.map(_buildBackupCard),
        ],
      ),
    );
  }

  Widget _buildBackupCard(BackupRecordModel backup) {
    Color statusColor;
    switch (backup.status) {
      case BackupStatus.completed:
        statusColor = Colors.green;
        break;
      case BackupStatus.failed:
      case BackupStatus.invalid:
        statusColor = Colors.red;
        break;
      case BackupStatus.inProgress:
        statusColor = Colors.blue;
        break;
      default:
        statusColor = Colors.grey;
    }

    final sizeKb = (backup.totalBytes / 1024).toStringAsFixed(1);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    backup.backupId,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                _buildStatusBadge(backup.status.label, statusColor),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Text(
                  'Objects: ${backup.objectCount}',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(width: 16),
                Text(
                  'Size: $sizeKb KB',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(width: 16),
                Text(
                  'Scope: ${backup.scope}',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Created: ${backup.createdAt.toLocal().toString().split('.')[0]}',
              style: const TextStyle(fontSize: 11, color: Colors.grey),
            ),
            if (backup.errorMessage != null) ...[
              const SizedBox(height: 4),
              Text(
                'Error: ${backup.errorMessage}',
                style: const TextStyle(color: Colors.red, fontSize: 12),
              ),
            ],
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton.icon(
                  icon: const Icon(Icons.verified_rounded, size: 16),
                  label: const Text('Verify'),
                  onPressed: _isActionRunning
                      ? null
                      : () => _verifyBackup(backup.backupId),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  icon: const Icon(Icons.preview_rounded, size: 16),
                  label: const Text('Plan Restore'),
                  onPressed:
                      _isActionRunning ||
                          backup.status != BackupStatus.completed
                      ? null
                      : () => _planRestore(backup.backupId),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIntegrityTab() {
    if (_integrityLoading &&
        _integrityRecords.isEmpty &&
        _latestIntegrity == null) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_integrityError != null &&
        _integrityRecords.isEmpty &&
        _latestIntegrity == null) {
      return _buildEmptyOrErrorPlaceholder(
        icon: Icons.gpp_maybe_rounded,
        title: 'Failed to load integrity verification',
        message: _integrityError!,
        onRetry: _loadIntegrity,
      );
    }

    return RefreshIndicator(
      onRefresh: _loadIntegrity,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_integrityError != null)
            _buildTabErrorBanner(_integrityError!, _loadIntegrity),
          if (_latestIntegrity != null) ...[
            _buildIntegrityReportCard(_latestIntegrity!),
            const SizedBox(height: 16),
          ],
          if (_integrityRecords.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'VERIFICATION AUDIT HISTORY (${_integrityRecords.length})',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  color: Colors.grey,
                ),
              ),
            ),
            ..._integrityRecords.map(
              (r) => Card(
                margin: const EdgeInsets.symmetric(vertical: 4),
                child: ListTile(
                  dense: true,
                  leading: Icon(
                    r.status == IntegrityStatus.valid
                        ? Icons.check_circle_rounded
                        : Icons.warning_rounded,
                    color: r.status == IntegrityStatus.valid
                        ? Colors.green
                        : Colors.red,
                  ),
                  title: Text(
                    r.backupId,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  subtitle: Text(
                    '${r.status.label} · ${r.verifiedObjectsCount} objects · ${r.verifiedAt.toLocal().toString().split('.')[0]}',
                    style: const TextStyle(fontSize: 11),
                  ),
                  trailing: _buildStatusBadge(
                    r.status.label,
                    r.status == IntegrityStatus.valid
                        ? Colors.green
                        : Colors.red,
                  ),
                  onTap: () {
                    setState(() {
                      _latestIntegrity = r;
                    });
                  },
                ),
              ),
            ),
          ] else if (_latestIntegrity == null) ...[
            _buildEmptyOrErrorPlaceholder(
              icon: Icons.verified_user_outlined,
              title: 'No Integrity Records Available',
              message:
                  'Select a backup snapshot from the Backups tab and tap "Verify" to run an integrity audit.',
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildIntegrityReportCard(RecoveryIntegrityModel integrity) {
    final statusColor = integrity.status == IntegrityStatus.valid
        ? Colors.green
        : Colors.red;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'INTEGRITY AUDIT REPORT',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                _buildStatusBadge(integrity.status.label, statusColor),
              ],
            ),
            const Divider(height: 24),
            _buildReportRow('Backup ID', integrity.backupId),
            _buildReportRow(
              'Manifest Format',
              integrity.manifestValid ? 'VALID' : 'INVALID',
              integrity.manifestValid ? Colors.green : Colors.red,
            ),
            _buildReportRow(
              'SHA-256 Checksums',
              integrity.checksumsValid ? 'MATCHED' : 'FAILED',
              integrity.checksumsValid ? Colors.green : Colors.red,
            ),
            _buildReportRow(
              'Schema Version',
              integrity.schemaCompatible ? 'COMPATIBLE' : 'INCOMPATIBLE',
            ),
            _buildReportRow(
              'Migration Version',
              integrity.migrationCompatible ? 'COMPATIBLE' : 'INCOMPATIBLE',
            ),
            _buildReportRow(
              'Verified Objects',
              '${integrity.verifiedObjectsCount} / ${integrity.verifiedObjectsCount + integrity.failedObjectsCount}',
            ),
            _buildReportRow('Verified By', integrity.verifiedBy),
            _buildReportRow(
              'Timestamp',
              integrity.verifiedAt.toLocal().toString().split('.')[0],
            ),
            if (integrity.failedObjects.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text(
                'FAILED OBJECTS',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.red,
                ),
              ),
              const SizedBox(height: 8),
              ...integrity.failedObjects.map(
                (obj) => Card(
                  color: Colors.red.withValues(alpha: 0.1),
                  child: ListTile(
                    leading: const Icon(Icons.warning, color: Colors.red),
                    title: Text(obj['objectKey'] ?? 'Unknown Object'),
                    subtitle: Text(
                      'Reason: ${obj['reason'] ?? 'Checksum mismatch'}',
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildRestoreTab() {
    if (_checkpointsLoading &&
        _checkpoints.isEmpty &&
        _currentPlan == null &&
        _lastRestoreResult == null) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_checkpointsError != null &&
        _checkpoints.isEmpty &&
        _currentPlan == null &&
        _lastRestoreResult == null) {
      return _buildEmptyOrErrorPlaceholder(
        icon: Icons.restore_page_outlined,
        title: 'Failed to load recovery checkpoints',
        message: _checkpointsError!,
        onRetry: _loadCheckpoints,
      );
    }

    return RefreshIndicator(
      onRefresh: _loadCheckpoints,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_checkpointsError != null)
            _buildTabErrorBanner(_checkpointsError!, _loadCheckpoints),
          if (_currentPlan == null && _lastRestoreResult == null)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    const Icon(
                      Icons.restore_page_rounded,
                      size: 48,
                      color: Colors.grey,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'No Restore Plan Active',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Select a completed backup from the "Backups" tab and click "Plan Restore" to preview restorable entities and conflicts.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ),
          if (_currentPlan != null) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'RESTORE PRE-FLIGHT PLAN',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        _buildStatusBadge(
                          _currentPlan!.migrationCompatibility,
                          _currentPlan!.migrationCompatibility == 'COMPATIBLE'
                              ? Colors.green
                              : Colors.red,
                        ),
                      ],
                    ),
                    const Divider(height: 24),
                    Text(
                      'Target Backup: ${_selectedBackupIdForRestore ?? ""}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontFamily: 'monospace',
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Restorable Entities (${_currentPlan!.restorableEntities.length}):',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                    Wrap(
                      spacing: 6,
                      children: _currentPlan!.restorableEntities
                          .map(
                            (e) => Chip(
                              label: Text(
                                e,
                                style: const TextStyle(fontSize: 11),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Excluded Ephemeral Entities:',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                    Wrap(
                      spacing: 6,
                      children: _currentPlan!.excludedEntities
                          .map(
                            (e) => Chip(
                              label: Text(
                                e,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey,
                                ),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                    if (_currentPlan!.conflicts.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      const Text(
                        'Detected State Conflicts & Enforced Resolutions:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          color: Colors.orange,
                        ),
                      ),
                      const SizedBox(height: 6),
                      ..._currentPlan!.conflicts.map(
                        (c) => ListTile(
                          dense: true,
                          leading: const Icon(
                            Icons.security,
                            color: Colors.orange,
                            size: 20,
                          ),
                          title: Text('${c.entityType} ${c.entityId}'),
                          subtitle: Text(
                            '${c.conflictType} → ${c.resolution}',
                            style: const TextStyle(fontSize: 11),
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.warning_amber_rounded),
                        label: const Text('Execute State Restore'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                        ),
                        onPressed:
                            _isActionRunning ||
                                _selectedBackupIdForRestore == null
                            ? null
                            : () =>
                                  _executeRestore(_selectedBackupIdForRestore!),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          if (_lastRestoreResult != null) ...[
            const SizedBox(height: 16),
            Card(
              color: Colors.green.withValues(alpha: 0.08),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'RESTORE RECONCILIATION RESULT',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: Colors.green,
                          ),
                        ),
                        _buildStatusBadge(
                          _lastRestoreResult!.reconciliation?.status.label ??
                              'VERIFIED',
                          Colors.green,
                        ),
                      ],
                    ),
                    const Divider(height: 24),
                    if (_lastRestoreResult!.reconciliation != null) ...[
                      _buildReportRow(
                        'Revocations Preserved',
                        '${_lastRestoreResult!.reconciliation!.revocationsPreserved}',
                      ),
                      _buildReportRow(
                        'Decommissioned Preserved',
                        '${_lastRestoreResult!.reconciliation!.decommissionedPreserved}',
                      ),
                      _buildReportRow(
                        'Expired Credentials Preserved',
                        '${_lastRestoreResult!.reconciliation!.expiredCredentialsPreserved}',
                      ),
                      _buildReportRow(
                        'Trust Re-evaluated Devices',
                        '${_lastRestoreResult!.reconciliation!.trustReEvaluatedCount}',
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
          if (_checkpoints.isNotEmpty) ...[
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'AUTOMATED RECOVERY CHECKPOINTS (${_checkpoints.length})',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  color: Colors.grey,
                ),
              ),
            ),
            ..._checkpoints.map(
              (cp) => Card(
                margin: const EdgeInsets.symmetric(vertical: 4),
                child: ListTile(
                  dense: true,
                  leading: const Icon(Icons.bookmark_border_rounded),
                  title: Text(
                    cp.checkpointType,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  subtitle: Text(
                    'ID: ${cp.checkpointId} · ${cp.createdAt.toLocal().toString().split('.')[0]}',
                    style: const TextStyle(fontSize: 11),
                  ),
                  trailing: Text(
                    'v${cp.schemaVersionRecorded}.${cp.migrationVersionRecorded}',
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildReportRow(String label, String value, [Color? valueColor]) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color, width: 1),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}
