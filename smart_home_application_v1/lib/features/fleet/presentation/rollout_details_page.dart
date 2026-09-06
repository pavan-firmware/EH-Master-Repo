import 'package:flutter/material.dart';

import '../../../core/models/fleet_models.dart';
import '../../../core/repositories/fleet_firmware_repository.dart';
import '../../../core/theme/app_theme.dart';

class RolloutDetailsPage extends StatefulWidget {
  const RolloutDetailsPage({
    super.key,
    required this.rolloutId,
    required this.repository,
  });

  final String rolloutId;
  final FleetFirmwareRepository repository;

  @override
  State<RolloutDetailsPage> createState() => _RolloutDetailsPageState();
}

class _RolloutDetailsPageState extends State<RolloutDetailsPage> {
  late Future<OtaRolloutModel?> _rolloutFuture;

  @override
  void initState() {
    super.initState();
    _loadDetails();
  }

  void _loadDetails() {
    setState(() {
      _rolloutFuture = widget.repository.listRollouts().then((list) {
        try {
          return list.firstWhere((r) => r.id == widget.rolloutId);
        } catch (_) {
          return null;
        }
      });
    });
  }

  Future<void> _startRollout() async {
    try {
      await widget.repository.startRollout(widget.rolloutId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Rollout started')));
      _loadDetails();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _pauseRollout() async {
    try {
      await widget.repository.pauseRollout(widget.rolloutId, reason: 'Operator requested pause');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Rollout paused')));
      _loadDetails();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _resumeRollout() async {
    try {
      await widget.repository.resumeRollout(widget.rolloutId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Rollout resumed')));
      _loadDetails();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _executeBatch() async {
    try {
      final res = await widget.repository.executeBatch(widget.rolloutId);
      final count = res['batchDispatchedCount'] ?? 0;
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Dispatched batch of $count devices')));
      _loadDetails();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error executing batch: $e')));
    }
  }

  Future<void> _initiateRollback() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Rollback'),
        content: const Text('Are you sure you want to initiate a safe authorized rollback to the previous known-good release?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Rollback'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await widget.repository.initiateRollback(widget.rolloutId, reason: 'Operator initiated rollback');
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Rollback initiated successfully')));
        _loadDetails();
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Rollback failed: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.ehColors;

    return Scaffold(
      backgroundColor: tokens.bgApp,
      appBar: AppBar(
        title: Text(widget.rolloutId),
        backgroundColor: tokens.bgApp,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadDetails),
        ],
      ),
      body: FutureBuilder<OtaRolloutModel?>(
        future: _rolloutFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final rollout = snapshot.data;
          if (rollout == null) {
            return const Center(child: Text('Rollout details not found'));
          }

          final stats = rollout.statistics;
          final state = rollout.rolloutState;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Status: $state', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                        const Divider(),
                        Text('Release ID: ${rollout.releaseId}'),
                        Text('Product Scope: ${rollout.productScope ?? 'All Compatible'}'),
                        Text('Channel: ${rollout.channel}'),
                        Text('Cohort: ${rollout.rolloutPercentage}%'),
                        Text('Batch Size: ${rollout.batchSize} | Max Concurrency: ${rollout.maxConcurrency}'),
                        Text('Failure Threshold: ${rollout.failureThresholdPercentage}% (or ${rollout.failureThresholdCount} devices)'),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Campaign Statistics', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        const Divider(),
                        Text('Total Eligible: ${stats.totalEligible}'),
                        Text('Total Targeted: ${stats.totalTargeted}'),
                        Text('In Progress: ${stats.inProgress}'),
                        Text('Installed: ${stats.installed}'),
                        Text('Boot Verified: ${stats.bootVerified}'),
                        Text('Health Verified: ${stats.healthVerified}'),
                        Text('Failed: ${stats.failed}', style: const TextStyle(color: Colors.red)),
                        Text('Rolled Back: ${stats.rolledBack}'),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Wrap(
                  spacing: 8.0,
                  runSpacing: 8.0,
                  children: [
                    if (state == 'DRAFT' || state == 'SCHEDULED')
                      ElevatedButton.icon(
                        icon: const Icon(Icons.play_arrow),
                        label: const Text('Start Rollout'),
                        onPressed: _startRollout,
                      ),
                    if (state == 'RUNNING') ...[
                      ElevatedButton.icon(
                        icon: const Icon(Icons.pause),
                        label: const Text('Pause Rollout'),
                        onPressed: _pauseRollout,
                      ),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.flash_on),
                        label: const Text('Execute Next Batch'),
                        onPressed: _executeBatch,
                      ),
                    ],
                    if (state == 'PAUSED' || state == 'FAILED_THRESHOLD_PAUSED')
                      ElevatedButton.icon(
                        icon: const Icon(Icons.play_arrow),
                        label: const Text('Resume Rollout'),
                        onPressed: _resumeRollout,
                      ),
                    if (state != 'CANCELLED' && state != 'ROLLED_BACK')
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                        icon: const Icon(Icons.undo),
                        label: const Text('Initiate Rollback'),
                        onPressed: _initiateRollback,
                      ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
