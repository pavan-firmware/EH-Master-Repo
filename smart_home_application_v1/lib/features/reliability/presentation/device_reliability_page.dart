import 'package:flutter/material.dart';
import '../../../core/models/reliability_models.dart';
import '../../../core/services/reliability_service.dart';

/// Phase 25 — Device Reliability Dashboard
///
/// Shows device health score, factor breakdown, active incidents,
/// and quick action bar for initiating non-destructive recovery.
class DeviceReliabilityPage extends StatefulWidget {
  final String deviceId;
  final String deviceName;
  final ReliabilityService reliabilityService;

  const DeviceReliabilityPage({
    super.key,
    required this.deviceId,
    required this.deviceName,
    required this.reliabilityService,
  });

  @override
  State<DeviceReliabilityPage> createState() => _DeviceReliabilityPageState();
}

class _DeviceReliabilityPageState extends State<DeviceReliabilityPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.reliabilityService.loadDeviceHealth(widget.deviceId);
    });
  }

  Color _stateColor(DeviceHealthState state, ThemeData theme) => switch (state) {
    DeviceHealthState.healthy => const Color(0xFF22C55E),
    DeviceHealthState.degraded => const Color(0xFFF59E0B),
    DeviceHealthState.unstable => const Color(0xFFEF4444),
    DeviceHealthState.unavailable => const Color(0xFF9CA3AF),
    DeviceHealthState.unknown => theme.colorScheme.onSurfaceVariant,
  };

  IconData _stateIcon(DeviceHealthState state) => switch (state) {
    DeviceHealthState.healthy => Icons.check_circle_rounded,
    DeviceHealthState.degraded => Icons.warning_amber_rounded,
    DeviceHealthState.unstable => Icons.error_outline_rounded,
    DeviceHealthState.unavailable => Icons.signal_wifi_off_rounded,
    DeviceHealthState.unknown => Icons.help_outline_rounded,
  };

  Future<void> _initiateRecovery(RecoveryActionType action) async {
    final svc = widget.reliabilityService;
    final health = svc.deviceHealth;
    if (health == null) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Initiating: ${action.toDisplayLabel()}…'),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        backgroundColor: colorScheme.surface,
        elevation: 0,
        leading: const BackButton(),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.deviceName,
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            Text(
              'Reliability',
              style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
      body: ListenableBuilder(
        listenable: widget.reliabilityService,
        builder: (context, _) {
          final svc = widget.reliabilityService;
          if (svc.loading) {
            return const Center(child: CircularProgressIndicator.adaptive());
          }
          if (svc.error != null) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.error_outline, color: colorScheme.onSurfaceVariant, size: 48),
                  const SizedBox(height: 12),
                  Text(svc.error!, style: TextStyle(color: colorScheme.onSurfaceVariant)),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () => svc.loadDeviceHealth(widget.deviceId),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }
          final health = svc.deviceHealth;
          if (health == null) {
            return Center(child: Text('No data', style: TextStyle(color: colorScheme.onSurfaceVariant)));
          }

          final stateColor = _stateColor(health.healthState, theme);

          return RefreshIndicator(
            onRefresh: () => svc.loadDeviceHealth(widget.deviceId),
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                // ── Health Score Card ──────────────────────────────────────
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: stateColor.withValues(alpha: 0.4), width: 1.5),
                  ),
                  child: Column(
                    children: [
                      Icon(_stateIcon(health.healthState), color: stateColor, size: 48),
                      const SizedBox(height: 12),
                      Text(
                        health.scoreFormatted,
                        style: TextStyle(color: stateColor, fontSize: 44, fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        health.healthState.toDisplayLabel(),
                        style: TextStyle(color: stateColor, fontSize: 16, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${health.activeIncidents} active incident(s)',
                        style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 13),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // ── Factor Breakdown ──────────────────────────────────────
                Text(
                  'Health Factors',
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 10),
                _FactorBar(label: 'Connectivity', score: health.connectivityScore ?? 100),
                _FactorBar(label: 'Telemetry', score: health.telemetryScore ?? 100),
                _FactorBar(label: 'Commands', score: health.commandScore ?? 100),
                _FactorBar(label: 'Uptime', score: health.uptimeScore ?? 100),
                const SizedBox(height: 20),

                // ── Quick Actions ─────────────────────────────────────────
                Text(
                  'Recovery Actions',
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 10),
                Text(
                  'All actions are non-destructive. No factory resets or credential wipes.',
                  style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 12),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    RecoveryActionType.refreshState,
                    RecoveryActionType.requestTelemetryRefresh,
                    RecoveryActionType.reEvaluateOtaEligibility,
                  ].map((action) {
                    return ActionChip(
                      avatar: const Icon(Icons.refresh_rounded, size: 16),
                      label: Text(action.toDisplayLabel()),
                      onPressed: () => _initiateRecovery(action),
                    );
                  }).toList(),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _FactorBar extends StatelessWidget {
  final String label;
  final double score;

  const _FactorBar({required this.label, required this.score});

  Color get _color {
    if (score >= 70) return const Color(0xFF22C55E);
    if (score >= 40) return const Color(0xFFF59E0B);
    return const Color(0xFFEF4444);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(
              child: Text(label, style: theme.textTheme.bodyMedium),
            ),
            Text(
              score.toStringAsFixed(0),
              style: TextStyle(color: _color, fontSize: 13, fontWeight: FontWeight.w700),
            ),
          ]),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: score / 100,
              minHeight: 6,
              backgroundColor: colorScheme.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation(_color),
            ),
          ),
        ],
      ),
    );
  }
}
