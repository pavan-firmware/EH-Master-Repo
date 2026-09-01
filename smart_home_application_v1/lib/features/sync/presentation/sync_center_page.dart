import 'package:flutter/material.dart';
import '../../../core/services/sync_service.dart';

/// EH Home — Cloud Sync & Offline Recovery Management Center (Phase 17)
class SyncCenterPage extends StatefulWidget {
  final SyncService syncService;

  const SyncCenterPage({super.key, required this.syncService});

  @override
  State<SyncCenterPage> createState() => _SyncCenterPageState();
}

class _SyncCenterPageState extends State<SyncCenterPage> {
  bool _isLoading = false;
  String? _statusMessage;

  Future<void> _handleManualSync() async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'Synchronizing with cloud...';
    });

    try {
      final homeId = widget.syncService.cachedBundle?.homes.isNotEmpty == true
          ? widget.syncService.cachedBundle!.homes.first['id'] as String?
          : null;

      if (homeId != null && widget.syncService.pendingMutations.isNotEmpty) {
        await widget.syncService.reconcilePending(homeId: homeId);
      }
      await widget.syncService.bootstrapSync(homeId: homeId);

      if (mounted) {
        setState(() {
          _statusMessage = 'Synchronization complete!';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _statusMessage = 'Sync failed: $e';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _handleExportData() async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'Generating sanitized data export...';
    });

    try {
      final data = await widget.syncService.exportData();
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Data Export Ready'),
            content: Text(
              'Exported ${data['scope']} bundle with ${data['homes']?.length ?? 0} home(s).\nZero secrets or passwords included.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Close'),
              ),
            ],
          ),
        );
        setState(() {
          _statusMessage = 'Data export successful.';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _statusMessage = 'Export failed: $e';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.syncService,
      builder: (context, _) {
        final isOnline = widget.syncService.isOnline;
        final pendingMutations = widget.syncService.pendingMutations;
        final lastSync = widget.syncService.lastSyncTime;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Cloud Sync & Recovery'),
            elevation: 0,
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh_rounded),
                tooltip: 'Sync Now',
                onPressed: _isLoading ? null : _handleManualSync,
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.all(16.0),
            children: [
              // Status Card
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isOnline
                                  ? const Color(0xFF10B981).withAlpha(30)
                                  : const Color(0xFFEF4444).withAlpha(30),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              isOnline ? Icons.cloud_done_rounded : Icons.cloud_off_rounded,
                              color: isOnline ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                              size: 32,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  isOnline ? 'Online & Synchronized' : 'Offline Mode',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  lastSync != null
                                      ? 'Last synced: ${lastSync.toLocal().toString().split('.').first}'
                                      : 'Never synced',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      if (_statusMessage != null) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.blue.withAlpha(25),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.info_outline, size: 18, color: Colors.blue),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _statusMessage!,
                                  style: const TextStyle(fontSize: 13, color: Colors.blue),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _isLoading ? null : _handleManualSync,
                      icon: _isLoading
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.sync_rounded),
                      label: const Text('Sync Now'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _isLoading ? null : _handleExportData,
                      icon: const Icon(Icons.download_rounded),
                      label: const Text('Export Data'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Pending Changes Queue
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Offline Pending Queue (${pendingMutations.length})',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (pendingMutations.isNotEmpty)
                    TextButton(
                      onPressed: () => widget.syncService.clearPendingMutations(),
                      child: const Text('Clear All', style: TextStyle(color: Colors.red)),
                    ),
                ],
              ),
              const SizedBox(height: 8),

              if (pendingMutations.isEmpty)
                Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(Icons.check_circle_outline, size: 36, color: Colors.green),
                          SizedBox(height: 8),
                          Text(
                            'No pending offline changes',
                            style: TextStyle(fontWeight: FontWeight.w500, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              else
                ...pendingMutations.map((m) {
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Colors.amber.withAlpha(40),
                        child: const Icon(Icons.edit_note, color: Colors.amber),
                      ),
                      title: Text(
                        '${m.mutationType.toUpperCase()} ${m.entityType}',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(
                        'Queued at ${m.clientTimestamp.toLocal().toString().split('.').first}',
                        style: const TextStyle(fontSize: 12),
                      ),
                      trailing: const Chip(
                        label: Text('Pending', style: TextStyle(fontSize: 11, color: Colors.amber)),
                        backgroundColor: Color(0xFFFEF3C7),
                      ),
                    ),
                  );
                }),
            ],
          ),
        );
      },
    );
  }
}
