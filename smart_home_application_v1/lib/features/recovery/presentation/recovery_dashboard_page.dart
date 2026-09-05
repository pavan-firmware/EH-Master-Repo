import 'package:flutter/material.dart';
import '../../../core/models/recovery_models.dart';
import '../../../core/repositories/recovery_repository.dart';

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

class _RecoveryDashboardPageState extends State<RecoveryDashboardPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<BackupRecordModel> _backups = [];
  RecoveryIntegrityModel? _latestIntegrity;
  List<RecoveryCheckpointModel> _checkpoints = [];
  RestorePlanModel? _currentPlan;
  RestoreOperationModel? _lastRestoreResult;

  bool _isLoading = true;
  bool _isActionRunning = false;
  String? _errorMessage;
  String? _selectedBackupIdForRestore;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadRecoveryData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadRecoveryData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final backups = await widget.repository.listBackups();
      final checkpoints = await widget.repository.listCheckpoints();

      RecoveryIntegrityModel? integrity;
      if (backups.isNotEmpty) {
        final completed = backups.where((b) => b.status == BackupStatus.completed).toList();
        if (completed.isNotEmpty) {
          integrity = await widget.repository.verifyBackupIntegrity(completed.first.backupId);
        }
      }

      if (mounted) {
        setState(() {
          _backups = backups;
          _checkpoints = checkpoints;
          _latestIntegrity = integrity;
          _isLoading = false;
        });
      }
    } catch (err) {
      if (mounted) {
        setState(() {
          _errorMessage = err.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _triggerBackup() async {
    setState(() => _isActionRunning = true);
    try {
      await widget.repository.createBackup(scope: 'FULL');
      await _loadRecoveryData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Backup snapshot created successfully.')),
        );
      }
    } catch (err) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Backup failed: $err'), backgroundColor: Colors.red),
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
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Integrity status: ${report.status.label} (${report.verifiedObjectsCount} verified)'),
            backgroundColor: report.status == IntegrityStatus.valid ? Colors.green : Colors.orange,
          ),
        );
      }
    } catch (err) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Verification failed: $err'), backgroundColor: Colors.red),
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
          SnackBar(content: Text('Restore planning failed: $err'), backgroundColor: Colors.red),
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
          'This will restore database state to the selected backup point. '
          'Security revocations, decommissioned states, and expired credentials will be strictly preserved. '
          'Proceed with restore?',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
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
      await _loadRecoveryData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Restore completed successfully!'), backgroundColor: Colors.green),
        );
      }
    } catch (err) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Restore failed: $err'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isActionRunning = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Disaster Recovery & Resilience'),
        actions: [
          if (widget.isAdmin)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _isLoading || _isActionRunning ? null : _loadRecoveryData,
            ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Backups', icon: Icon(Icons.backup)),
            Tab(text: 'Integrity', icon: Icon(Icons.verified_user)),
            Tab(text: 'Restore', icon: Icon(Icons.restore)),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? _buildErrorView()
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildBackupsTab(),
                    _buildIntegrityTab(),
                    _buildRestoreTab(),
                  ],
                ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 48),
            const SizedBox(height: 16),
            Text(
              'Failed to load recovery platform data',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(_errorMessage ?? '', style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadRecoveryData,
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryHeader() {
    final completedBackups = _backups.where((b) => b.status == BackupStatus.completed).toList();
    final lastBackupTime = completedBackups.isNotEmpty ? completedBackups.first.createdAt.toLocal().toString().split('.')[0] : 'None';

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
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 1.1),
                ),
                _buildStatusBadge(
                  _latestIntegrity?.status.label ?? 'OBSERVED',
                  _latestIntegrity?.status == IntegrityStatus.valid ? Colors.green : Colors.orange,
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
                      const Text('Last Successful Backup', style: TextStyle(color: Colors.grey, fontSize: 12)),
                      const SizedBox(height: 4),
                      Text(lastBackupTime, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Total Snapshots', style: TextStyle(color: Colors.grey, fontSize: 12)),
                      const SizedBox(height: 4),
                      Text('${_backups.length}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Checkpoints', style: TextStyle(color: Colors.grey, fontSize: 12)),
                      const SizedBox(height: 4),
                      Text('${_checkpoints.length}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (widget.isAdmin)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.add_circle_outline),
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
    return ListView(
      children: [
        _buildSummaryHeader(),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            'AVAILABLE BACKUP SNAPSHOTS (${_backups.length})',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey),
          ),
        ),
        if (_backups.isEmpty)
          const Padding(
            padding: EdgeInsets.all(32.0),
            child: Center(child: Text('No backup records available.', style: TextStyle(color: Colors.grey))),
          )
        else
          ..._backups.map(_buildBackupCard),
      ],
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
                    style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold, fontSize: 13),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                _buildStatusBadge(backup.status.label, statusColor),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Text('Objects: ${backup.objectCount}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                const SizedBox(width: 16),
                Text('Size: $sizeKb KB', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                const SizedBox(width: 16),
                Text('Scope: ${backup.scope}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Created: ${backup.createdAt.toLocal().toString().split('.')[0]}',
              style: const TextStyle(fontSize: 11, color: Colors.grey),
            ),
            if (backup.errorMessage != null) ...[
              const SizedBox(height: 4),
              Text('Error: ${backup.errorMessage}', style: const TextStyle(color: Colors.red, fontSize: 12)),
            ],
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton.icon(
                  icon: const Icon(Icons.verified, size: 16),
                  label: const Text('Verify'),
                  onPressed: _isActionRunning ? null : () => _verifyBackup(backup.backupId),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  icon: const Icon(Icons.preview, size: 16),
                  label: const Text('Plan Restore'),
                  onPressed: _isActionRunning || backup.status != BackupStatus.completed
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
    if (_latestIntegrity == null) {
      return const Center(child: Text('No integrity verification report available.', style: TextStyle(color: Colors.grey)));
    }

    final integrity = _latestIntegrity!;
    final statusColor = integrity.status == IntegrityStatus.valid ? Colors.green : Colors.red;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('INTEGRITY AUDIT REPORT', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    _buildStatusBadge(integrity.status.label, statusColor),
                  ],
                ),
                const Divider(height: 24),
                _buildReportRow('Backup ID', integrity.backupId),
                _buildReportRow('Manifest Format', integrity.manifestValid ? 'VALID' : 'INVALID', integrity.manifestValid ? Colors.green : Colors.red),
                _buildReportRow('SHA-256 Checksums', integrity.checksumsValid ? 'MATCHED' : 'FAILED', integrity.checksumsValid ? Colors.green : Colors.red),
                _buildReportRow('Schema Version', integrity.schemaCompatible ? 'COMPATIBLE' : 'INCOMPATIBLE'),
                _buildReportRow('Migration Version', integrity.migrationCompatible ? 'COMPATIBLE' : 'INCOMPATIBLE'),
                _buildReportRow('Verified Objects', '${integrity.verifiedObjectsCount} / ${integrity.verifiedObjectsCount + integrity.failedObjectsCount}'),
                _buildReportRow('Verified By', integrity.verifiedBy),
                _buildReportRow('Timestamp', integrity.verifiedAt.toLocal().toString().split('.')[0]),
              ],
            ),
          ),
        ),
        if (integrity.failedObjects.isNotEmpty) ...[
          const SizedBox(height: 16),
          const Text('FAILED OBJECTS', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
          const SizedBox(height: 8),
          ...integrity.failedObjects.map((obj) => Card(
                color: Colors.red.withValues(alpha: 0.1),
                child: ListTile(
                  leading: const Icon(Icons.warning, color: Colors.red),
                  title: Text(obj['objectKey'] ?? 'Unknown Object'),
                  subtitle: Text('Reason: ${obj['reason'] ?? 'Checksum mismatch'}'),
                ),
              )),
        ],
      ],
    );
  }

  Widget _buildRestoreTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (_currentPlan == null && _lastRestoreResult == null)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  const Icon(Icons.restore_page, size: 48, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text('No Restore Plan Active', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
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
                      const Text('RESTORE PRE-FLIGHT PLAN', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      _buildStatusBadge(_currentPlan!.migrationCompatibility, _currentPlan!.migrationCompatibility == 'COMPATIBLE' ? Colors.green : Colors.red),
                    ],
                  ),
                  const Divider(height: 24),
                  Text('Target Backup: ${_selectedBackupIdForRestore ?? ""}', style: const TextStyle(fontSize: 12, fontFamily: 'monospace')),
                  const SizedBox(height: 8),
                  Text('Restorable Entities (${_currentPlan!.restorableEntities.length}):', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  Wrap(
                    spacing: 6,
                    children: _currentPlan!.restorableEntities.map((e) => Chip(label: Text(e, style: const TextStyle(fontSize: 11)))).toList(),
                  ),
                  const SizedBox(height: 8),
                  Text('Excluded Ephemeral Entities:', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey)),
                  Wrap(
                    spacing: 6,
                    children: _currentPlan!.excludedEntities.map((e) => Chip(label: Text(e, style: const TextStyle(fontSize: 11, color: Colors.grey)))).toList(),
                  ),
                  if (_currentPlan!.conflicts.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    const Text('Detected State Conflicts & Enforced Resolutions:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.orange)),
                    const SizedBox(height: 6),
                    ..._currentPlan!.conflicts.map((c) => ListTile(
                          dense: true,
                          leading: const Icon(Icons.security, color: Colors.orange, size: 20),
                          title: Text('${c.entityType} ${c.entityId}'),
                          subtitle: Text('${c.conflictType} → ${c.resolution}', style: const TextStyle(fontSize: 11)),
                        )),
                  ],
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.warning_amber),
                      label: const Text('Execute State Restore'),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                      onPressed: _isActionRunning || _selectedBackupIdForRestore == null
                          ? null
                          : () => _executeRestore(_selectedBackupIdForRestore!),
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
                      const Text('RESTORE RECONCILIATION RESULT', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.green)),
                      _buildStatusBadge(_lastRestoreResult!.reconciliation?.status.label ?? 'VERIFIED', Colors.green),
                    ],
                  ),
                  const Divider(height: 24),
                  if (_lastRestoreResult!.reconciliation != null) ...[
                    _buildReportRow('Revocations Preserved', '${_lastRestoreResult!.reconciliation!.revocationsPreserved}'),
                    _buildReportRow('Decommissioned Preserved', '${_lastRestoreResult!.reconciliation!.decommissionedPreserved}'),
                    _buildReportRow('Expired Credentials Preserved', '${_lastRestoreResult!.reconciliation!.expiredCredentialsPreserved}'),
                    _buildReportRow('Trust Re-evaluated Devices', '${_lastRestoreResult!.reconciliation!.trustReEvaluatedCount}'),
                  ],
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildReportRow(String label, String value, [Color? valueColor]) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          Text(value, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: valueColor)),
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
        style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.8),
      ),
    );
  }
}
