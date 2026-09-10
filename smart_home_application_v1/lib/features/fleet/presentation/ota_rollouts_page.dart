import 'package:flutter/material.dart';

import '../../../core/models/fleet_models.dart';
import '../../../core/repositories/fleet_firmware_repository.dart';
import '../../../core/theme/app_theme.dart';
import 'rollout_details_page.dart';

class OtaRolloutsPage extends StatefulWidget {
  const OtaRolloutsPage({
    super.key,
    required this.repository,
  });

  final FleetFirmwareRepository repository;

  @override
  State<OtaRolloutsPage> createState() => _OtaRolloutsPageState();
}

class _OtaRolloutsPageState extends State<OtaRolloutsPage> {
  late Future<List<OtaRolloutModel>> _rolloutsFuture;

  @override
  void initState() {
    super.initState();
    _loadRollouts();
  }

  void _loadRollouts() {
    setState(() {
      _rolloutsFuture = widget.repository.listRollouts();
    });
  }

  Color _getStatusColor(String state) {
    switch (state) {
      case 'RUNNING':
        return Colors.blue;
      case 'COMPLETED':
        return Colors.green;
      case 'PAUSED':
      case 'FAILED_THRESHOLD_PAUSED':
        return Colors.orange;
      case 'ROLLING_BACK':
      case 'ROLLED_BACK':
      case 'CANCELLED':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.ehColors;

    return Scaffold(
      backgroundColor: tokens.bgApp,
      appBar: AppBar(
        title: const Text('OTA Rollout Campaigns'),
        backgroundColor: tokens.bgApp,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadRollouts,
          ),
        ],
      ),
      body: FutureBuilder<List<OtaRolloutModel>>(
        future: _rolloutsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            final errStr = snapshot.error.toString();
            final isForbidden = errStr.contains('403') ||
                errStr.toLowerCase().contains('forbidden') ||
                errStr.toLowerCase().contains('administrative privilege');

            return Center(
              child: Padding(
                padding: const EdgeInsets.all(28.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: (isForbidden ? tokens.bluePrimary : tokens.error)
                            .withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isForbidden
                            ? Icons.admin_panel_settings_outlined
                            : Icons.error_outline,
                        size: 48,
                        color: isForbidden ? tokens.bluePrimary : tokens.error,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      isForbidden
                          ? 'Administrator Access Required'
                          : 'Unable to Load Rollouts',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w700,
                        color: tokens.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      isForbidden
                          ? 'OTA rollout campaign deployment and staging are restricted to platform administrators with firmware management permissions.'
                          : 'Could not retrieve OTA rollout campaigns. Please check your connection and retry.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: tokens.textSecondary,
                        fontSize: 14,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 24),
                    FilledButton.icon(
                      onPressed: _loadRollouts,
                      icon: const Icon(Icons.refresh_rounded, size: 18),
                      label: const Text('Retry'),
                      style: FilledButton.styleFrom(
                        backgroundColor: tokens.bluePrimary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }
          final rollouts = snapshot.data ?? [];
          if (rollouts.isEmpty) {
            return Center(
              child: Text(
                'No active rollout campaigns',
                style: TextStyle(color: tokens.textSecondary, fontSize: 15),
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16.0),
            itemCount: rollouts.length,
            itemBuilder: (context, index) {
              final rollout = rollouts[index];
              final stats = rollout.statistics;
              final statusColor = _getStatusColor(rollout.rolloutState);

              return Card(
                margin: const EdgeInsets.only(bottom: 12.0),
                child: InkWell(
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => RolloutDetailsPage(
                          rolloutId: rollout.id,
                          repository: widget.repository,
                        ),
                      ),
                    ).then((_) => _loadRollouts());
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              rollout.id,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: statusColor.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                rollout.rolloutState,
                                style: TextStyle(
                                  color: statusColor,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text('Release ID: ${rollout.releaseId}'),
                        if (rollout.productScope != null)
                          Text('Product Scope: ${rollout.productScope}'),
                        Text('Channel: ${rollout.channel}'),
                        Text('Cohort: ${rollout.rolloutPercentage}% | Batch Size: ${rollout.batchSize} | Max Concurrency: ${rollout.maxConcurrency}'),
                        const SizedBox(height: 8),
                        LinearProgressIndicator(
                          value: stats.totalTargeted > 0 ? (stats.healthVerified / stats.totalTargeted) : 0,
                          backgroundColor: Colors.grey.withValues(alpha: 0.2),
                          valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Targeted: ${stats.totalTargeted}', style: const TextStyle(fontSize: 12)),
                            Text('Verified: ${stats.healthVerified}', style: const TextStyle(fontSize: 12, color: Colors.green)),
                            Text('Failed: ${stats.failed}', style: const TextStyle(fontSize: 12, color: Colors.red)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
