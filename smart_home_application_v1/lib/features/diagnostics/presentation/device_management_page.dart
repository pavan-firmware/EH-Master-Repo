import 'package:flutter/material.dart';

import '../../../core/models/device_management_models.dart';
import '../../../core/repositories/cloud_device_management_repository.dart';
import '../../../core/theme/app_theme.dart';

class DeviceManagementPage extends StatefulWidget {
  const DeviceManagementPage({
    super.key,
    required this.homeId,
    required this.deviceId,
    required this.repository,
    this.onDeviceRemoved,
    this.onDeviceUpdated,
  });

  final String homeId;
  final String deviceId;
  final DeviceManagementRepository repository;
  final VoidCallback? onDeviceRemoved;
  final ValueChanged<DeviceDetailsModel>? onDeviceUpdated;

  @override
  State<DeviceManagementPage> createState() => _DeviceManagementPageState();
}

class _DeviceManagementPageState extends State<DeviceManagementPage> {
  late Future<DeviceDetailsModel> _detailsFuture;
  late Future<List<DeviceActivityLogItemModel>> _activityFuture;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  void _refresh() {
    setState(() {
      _detailsFuture = widget.repository.getDeviceDetails(
        widget.homeId,
        widget.deviceId,
      );
      _activityFuture = widget.repository.getDeviceActivity(
        widget.homeId,
        widget.deviceId,
      );
    });
  }

  Future<void> _showRenameDialog(DeviceDetailsModel current) async {
    final controller = TextEditingController(text: current.displayName);
    final formKey = GlobalKey<FormState>();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rename Device'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Device Name',
              hintText: 'e.g. Living Room Main',
            ),
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Name cannot be empty';
              if (v.trim().length > 64) return 'Name too long (max 64 chars)';
              return null;
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState?.validate() ?? false) {
                Navigator.pop(ctx, true);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      setState(() => _isProcessing = true);
      try {
        await widget.repository.renameDevice(
          widget.homeId,
          widget.deviceId,
          controller.text.trim(),
        );
        _refresh();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Device renamed successfully')),
          );
        }
      } catch (err) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Failed to rename: $err')));
        }
      } finally {
        if (mounted) setState(() => _isProcessing = false);
      }
    }
  }

  Future<void> _showRemoveConfirmation() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove Device from Home'),
        content: const Text(
          'Are you sure you want to remove this device from your home? '
          'Physical identity and hardware credentials will remain intact.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      setState(() => _isProcessing = true);
      try {
        await widget.repository.removeDevice(widget.homeId, widget.deviceId);
        widget.onDeviceRemoved?.call();
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Device removed from home')),
          );
        }
      } catch (err) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to remove device: $err')),
          );
          setState(() => _isProcessing = false);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.ehColors;

    return Scaffold(
      backgroundColor: tokens.bgApp,
      appBar: AppBar(
        backgroundColor: tokens.bgApp,
        title: const Text('Device Management'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _refresh,
          ),
        ],
      ),
      body: FutureBuilder<DeviceDetailsModel>(
        future: _detailsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.error_outline_rounded,
                      size: 48,
                      color: Colors.red,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Failed to load device details',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: tokens.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${snapshot.error}',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: tokens.textSecondary),
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: _refresh,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            );
          }

          final dev = snapshot.data!;
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              // 1. Header & Status Banner
              _HeaderBanner(device: dev),
              const SizedBox(height: 16),

              // 2. Health & Connection Details
              _HealthOverviewCard(
                health: dev.health,
                connectionState: dev.connectionState,
              ),
              const SizedBox(height: 16),

              // 3. Technical & Firmware Details
              _TechnicalDetailsCard(device: dev),
              const SizedBox(height: 16),

              // 4. Quick Actions
              _ManagementActionsCard(
                onRename: () => _showRenameDialog(dev),
                onRemove: _showRemoveConfirmation,
                isProcessing: _isProcessing,
              ),
              const SizedBox(height: 24),

              // 5. Recent Activity Feed
              Text(
                'Recent Activity',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: tokens.textPrimary,
                ),
              ),
              const SizedBox(height: 10),
              FutureBuilder<List<DeviceActivityLogItemModel>>(
                future: _activityFuture,
                builder: (context, actSnap) {
                  if (actSnap.connectionState == ConnectionState.waiting) {
                    return const Padding(
                      padding: EdgeInsets.all(20),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  final logs = actSnap.data ?? [];
                  if (logs.isEmpty) {
                    return Card(
                      color: tokens.surfaceCard,
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Text(
                          'No recent activity recorded for this device.',
                          style: TextStyle(color: tokens.textSecondary),
                        ),
                      ),
                    );
                  }

                  return Column(
                    children: logs
                        .map((log) => _ActivityLogRow(log: log))
                        .toList(),
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }
}

class _HeaderBanner extends StatelessWidget {
  const _HeaderBanner({required this.device});
  final DeviceDetailsModel device;

  @override
  Widget build(BuildContext context) {
    final tokens = context.ehColors;
    final isOnline = device.connectionState == 'ONLINE';

    return Card(
      color: tokens.surfaceCard,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: isOnline
                    ? tokens.successContainer
                    : tokens.warningContainer,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                Icons.sensors_rounded,
                color: isOnline ? tokens.success : tokens.warning,
                size: 28,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    device.displayName,
                    style: TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                      color: tokens.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${device.roomName ?? "Unassigned Room"} • ${device.productVariantId}',
                    style: TextStyle(color: tokens.textSecondary, fontSize: 13),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: isOnline
                    ? Colors.green.withValues(alpha: 0.12)
                    : Colors.grey.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                device.connectionState,
                style: TextStyle(
                  color: isOnline ? Colors.green : Colors.grey,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HealthOverviewCard extends StatelessWidget {
  const _HealthOverviewCard({
    required this.health,
    required this.connectionState,
  });
  final DeviceHealthMetricsModel health;
  final String connectionState;

  @override
  Widget build(BuildContext context) {
    final tokens = context.ehColors;

    return Card(
      color: tokens.surfaceCard,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Health & Reliability',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: tokens.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            _InfoRow(label: 'Health Status', value: health.status),
            _InfoRow(
              label: 'Last Seen',
              value: health.lastSeenAt != null
                  ? '${health.lastSeenAt!.toLocal()}'
                  : 'Never',
            ),
            _InfoRow(
              label: 'Command Success Rate',
              value:
                  '${health.commandSuccessCount} ok / ${health.commandFailureCount} fail',
            ),
            if (health.degradationReason != null)
              _InfoRow(
                label: 'Degradation',
                value: health.degradationReason!,
                valueColor: Colors.orange,
              ),
          ],
        ),
      ),
    );
  }
}

class _TechnicalDetailsCard extends StatelessWidget {
  const _TechnicalDetailsCard({required this.device});
  final DeviceDetailsModel device;

  @override
  Widget build(BuildContext context) {
    final tokens = context.ehColors;

    return Card(
      color: tokens.surfaceCard,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Hardware & Firmware',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: tokens.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            _InfoRow(label: 'Serial Number', value: device.serialNumber),
            _InfoRow(
              label: 'Hardware Revision',
              value: device.hardwareRevision,
            ),
            _InfoRow(label: 'Firmware Family', value: device.firmwareFamily),
            _InfoRow(label: 'Firmware Version', value: device.firmwareVersion),
            if (device.ota != null && device.ota!.updateAvailable)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  children: [
                    const Icon(
                      Icons.system_update_rounded,
                      color: Colors.blue,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Update available: ${device.ota!.latestVersion}',
                        style: const TextStyle(
                          color: Colors.blue,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ManagementActionsCard extends StatelessWidget {
  const _ManagementActionsCard({
    required this.onRename,
    required this.onRemove,
    required this.isProcessing,
  });

  final VoidCallback onRename;
  final VoidCallback onRemove;
  final bool isProcessing;

  @override
  Widget build(BuildContext context) {
    final tokens = context.ehColors;

    return Card(
      color: tokens.surfaceCard,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            ListTile(
              leading: const Icon(Icons.edit_rounded),
              title: const Text('Rename Device'),
              subtitle: const Text(
                'Change the friendly name displayed across the app',
              ),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: isProcessing ? null : onRename,
            ),
            const Divider(),
            ListTile(
              leading: const Icon(
                Icons.delete_forever_rounded,
                color: Colors.red,
              ),
              title: const Text(
                'Remove from Home',
                style: TextStyle(color: Colors.red),
              ),
              subtitle: const Text(
                'Unclaim device from home without erasing factory identity',
              ),
              trailing: const Icon(
                Icons.chevron_right_rounded,
                color: Colors.red,
              ),
              onTap: isProcessing ? null : onRemove,
            ),
          ],
        ),
      ),
    );
  }
}

class _ActivityLogRow extends StatelessWidget {
  const _ActivityLogRow({required this.log});
  final DeviceActivityLogItemModel log;

  @override
  Widget build(BuildContext context) {
    final tokens = context.ehColors;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: tokens.surfaceCard,
      child: ListTile(
        leading: Icon(
          log.severity == 'warn' || log.severity == 'error'
              ? Icons.warning_amber_rounded
              : Icons.info_outline_rounded,
          color: log.severity == 'error'
              ? Colors.red
              : log.severity == 'warn'
              ? Colors.orange
              : tokens.bluePrimary,
        ),
        title: Text(
          log.message,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: tokens.textPrimary,
          ),
        ),
        subtitle: Text(
          '${log.eventType} • ${log.createdAt.toLocal()}',
          style: TextStyle(color: tokens.textSecondary, fontSize: 12),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value, this.valueColor});
  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final tokens = context.ehColors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(color: tokens.textSecondary, fontSize: 13),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 13,
              color: valueColor ?? tokens.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
