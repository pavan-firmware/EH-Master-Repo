import 'package:flutter/material.dart';
import '../../../core/models/reliability_models.dart';
import '../../../core/services/reliability_service.dart';

/// Phase 25 — Fleet Health Overview Page
///
/// Shows home-wide device health score, state distribution breakdown,
/// active incidents count, and top-level reliability status.
class FleetHealthPage extends StatefulWidget {
  final String homeId;
  final ReliabilityService reliabilityService;

  const FleetHealthPage({
    super.key,
    required this.homeId,
    required this.reliabilityService,
  });

  @override
  State<FleetHealthPage> createState() => _FleetHealthPageState();
}

class _FleetHealthPageState extends State<FleetHealthPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.reliabilityService.loadFleetHealth(widget.homeId);
      widget.reliabilityService.loadActiveIncidents(widget.homeId);
    });
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
        title: Text(
          'Fleet Health',
          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
      ),
      body: ListenableBuilder(
        listenable: widget.reliabilityService,
        builder: (context, _) {
          final svc = widget.reliabilityService;

          if (svc.loading && svc.fleetHealth == null) {
            return const Center(child: CircularProgressIndicator.adaptive());
          }

          final fleet = svc.fleetHealth;

          return RefreshIndicator(
            onRefresh: () async {
              await svc.loadFleetHealth(widget.homeId);
              await svc.loadActiveIncidents(widget.homeId);
            },
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                if (fleet != null) ...[
                  // ── Score Hero ───────────────────────────────────────
                  _FleetScoreCard(fleet: fleet),
                  const SizedBox(height: 20),

                  // ── State Distribution ───────────────────────────────
                  Text(
                    'Device States',
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 12),
                  ...DeviceHealthState.values.map((state) {
                    final count = fleet.stateDistribution[state.name.toUpperCase()] ?? 0;
                    return _StateRow(state: state, count: count);
                  }),
                  const SizedBox(height: 20),
                ],

                // ── Active Incidents ─────────────────────────────────
                Row(children: [
                  Expanded(
                    child: Text(
                      'Active Incidents',
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                  if (svc.activeIncidents.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEF4444).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${svc.activeIncidents.length}',
                        style: const TextStyle(
                          color: Color(0xFFEF4444),
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                ]),
                const SizedBox(height: 10),
                if (svc.activeIncidents.isEmpty)
                  const _EmptyState(
                    icon: Icons.check_circle_outline_rounded,
                    label: 'No active incidents',
                    sub: 'All devices are running normally.',
                  )
                else
                  ...svc.activeIncidents.map((inc) => _IncidentCard(incident: inc)),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _FleetScoreCard extends StatelessWidget {
  final FleetHealthSummary fleet;

  const _FleetScoreCard({required this.fleet});

  Color get _scoreColor {
    if (fleet.fleetHealthScore >= 70) return const Color(0xFF22C55E);
    if (fleet.fleetHealthScore >= 40) return const Color(0xFFF59E0B);
    return const Color(0xFFEF4444);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _scoreColor.withValues(alpha: 0.35), width: 1.5),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Fleet Health Score',
                  style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
                ),
                const SizedBox(height: 6),
                Text(
                  fleet.scoreFormatted,
                  style: TextStyle(color: _scoreColor, fontSize: 38, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 8),
                Text(
                  '${fleet.totalDevices} device(s)',
                  style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          Column(
            children: [
              _InfoChip(
                label: '${fleet.activeIncidents} incidents',
                color: fleet.activeIncidents > 0 ? const Color(0xFFEF4444) : const Color(0xFF22C55E),
              ),
              const SizedBox(height: 8),
              _InfoChip(
                label: '${fleet.criticalIncidents} critical',
                color: fleet.criticalIncidents > 0 ? const Color(0xFFEF4444) : colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final String label;
  final Color color;

  const _InfoChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _StateRow extends StatelessWidget {
  final DeviceHealthState state;
  final int count;

  const _StateRow({required this.state, required this.count});

  Color _color() => switch (state) {
    DeviceHealthState.healthy => const Color(0xFF22C55E),
    DeviceHealthState.degraded => const Color(0xFFF59E0B),
    DeviceHealthState.unstable => const Color(0xFFEF4444),
    DeviceHealthState.unavailable => const Color(0xFF9CA3AF),
    DeviceHealthState.unknown => const Color(0xFF6B7280),
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: _color(), shape: BoxShape.circle),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(state.toDisplayLabel(), style: theme.textTheme.bodyMedium),
          ),
          Text(
            '$count',
            style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 14, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _IncidentCard extends StatelessWidget {
  final ReliabilityIncident incident;

  const _IncidentCard({required this.incident});

  Color _severityColor() => switch (incident.severity) {
    ReliabilitySeverity.critical => const Color(0xFFEF4444),
    ReliabilitySeverity.high => const Color(0xFFF97316),
    ReliabilitySeverity.medium => const Color(0xFFF59E0B),
    ReliabilitySeverity.low => const Color(0xFF6B7280),
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _severityColor().withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: _severityColor().withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                incident.severity.name.toUpperCase(),
                style: TextStyle(color: _severityColor(), fontSize: 10, fontWeight: FontWeight.w800),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                incident.incidentType.toDisplayLabel(),
                style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 11, fontWeight: FontWeight.w600),
              ),
            ),
          ]),
          const SizedBox(height: 6),
          Text(
            incident.title,
            style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
          ),
          if (incident.description != null) ...[
            const SizedBox(height: 4),
            Text(
              incident.description!,
              style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 12),
            ),
          ],
          const SizedBox(height: 6),
          Text(
            '${incident.signalCount} signal(s) · ${incident.status}',
            style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String label;
  final String sub;

  const _EmptyState({required this.icon, required this.label, required this.sub});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Column(
        children: [
          Icon(icon, color: const Color(0xFF22C55E), size: 48),
          const SizedBox(height: 12),
          Text(
            label,
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          Text(sub, style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 13)),
        ],
      ),
    );
  }
}
