import 'package:flutter/material.dart';
import '../../../core/models/intelligence_models.dart';
import '../../../core/services/intelligence_service.dart';
import 'intelligence_recommendations_page.dart';
import 'intelligence_decision_details_page.dart';
import 'intelligence_history_page.dart';

class IntelligenceCenterPage extends StatefulWidget {
  final String homeId;
  final HomeIntelligenceService service;

  const IntelligenceCenterPage({
    super.key,
    required this.homeId,
    required this.service,
  });

  @override
  State<IntelligenceCenterPage> createState() => _IntelligenceCenterPageState();
}

class _IntelligenceCenterPageState extends State<IntelligenceCenterPage> {
  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    await widget.service.fetchSummary(widget.homeId);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.service,
      builder: (context, _) {
        final summary = widget.service.currentSummary;
        final snapshot = summary?.snapshot;
        final recommendations = widget.service.recommendations;
        final decisions = widget.service.decisions;
        final isLoading = widget.service.isLoading;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Home Intelligence Center'),
            actions: [
              IconButton(
                icon: const Icon(Icons.history),
                tooltip: 'Outcome History',
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => IntelligenceHistoryPage(
                        homeId: widget.homeId,
                        service: widget.service,
                      ),
                    ),
                  );
                },
              ),
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: _refresh,
              ),
            ],
          ),
          body: RefreshIndicator(
            onRefresh: _refresh,
            child: isLoading && summary == null
                ? const Center(child: CircularProgressIndicator())
                : ListView(
                    padding: const EdgeInsets.all(16.0),
                    children: [
                      // Unified Home State Card
                      _buildUnifiedStateCard(snapshot),
                      const SizedBox(height: 16),

                      // Fast Action Toolbar
                      _buildActionToolbar(),
                      const SizedBox(height: 24),

                      // Recommendations Section
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Active Recommendations (${recommendations.length})',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          TextButton(
                            onPressed: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => IntelligenceRecommendationsPage(
                                    homeId: widget.homeId,
                                    service: widget.service,
                                  ),
                                ),
                              );
                            },
                            child: const Text('View All'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (recommendations.isEmpty)
                        _buildEmptyCard('No pending recommendations. All systems optimized.')
                      else
                        ...recommendations.take(3).map((r) => _buildRecommendationCard(r)),

                      const SizedBox(height: 24),

                      // Recent Decisions Section
                      Text(
                        'Recent Autonomous Decisions',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      if (decisions.isEmpty)
                        _buildEmptyCard('No autonomous decisions evaluated yet.')
                      else
                        ...decisions.take(4).map((d) => _buildDecisionTile(d)),
                    ],
                  ),
          ),
        );
      },
    );
  }

  Widget _buildUnifiedStateCard(HomeIntelligenceSnapshot? snapshot) {
    if (snapshot == null) return const SizedBox.shrink();

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(16.0),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: [
              Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.6),
              Theme.of(context).colorScheme.surface,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      snapshot.isOccupied ? Icons.home : Icons.door_front_door_outlined,
                      color: Theme.of(context).colorScheme.primary,
                      size: 28,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Mode: ${snapshot.homeContext}',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                Chip(
                  label: Text(
                    snapshot.isOccupied ? 'OCCUPIED' : 'UNOCCUPIED',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                  ),
                  backgroundColor: snapshot.isOccupied ? Colors.green.withValues(alpha: 0.2) : Colors.orange.withValues(alpha: 0.2),
                ),
              ],
            ),
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatMetric('Total Load', '${snapshot.totalPowerW.toStringAsFixed(0)} W', Icons.bolt),
                _buildStatMetric('Active Devices', '${snapshot.activeDevicesCount} / ${snapshot.deviceCount}', Icons.devices),
                _buildStatMetric('Tariff Rate', '\$${snapshot.tariffPrice.toStringAsFixed(2)}/kWh', Icons.payments_outlined),
                _buildStatMetric('Anomalies', '${snapshot.activeAnomalyCount}', Icons.warning_amber, isAlert: snapshot.activeAnomalyCount > 0),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatMetric(String label, String value, IconData icon, {bool isAlert = false}) {
    return Column(
      children: [
        Icon(icon, size: 20, color: isAlert ? Colors.red : Theme.of(context).colorScheme.primary),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
            color: isAlert ? Colors.red : null,
          ),
        ),
        Text(
          label,
          style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
        ),
      ],
    );
  }

  Widget _buildActionToolbar() {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            icon: const Icon(Icons.psychology_outlined),
            label: const Text('Evaluate Rules'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () async {
              final ok = await widget.service.triggerEvaluation(widget.homeId);
              if (mounted && ok) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Intelligence evaluation cycle completed.')),
                );
              }
            },
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: OutlinedButton.icon(
            icon: const Icon(Icons.flash_auto),
            label: const Text('Auto-Execute Safe'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () async {
              final ok = await widget.service.triggerAutoExecution(widget.homeId);
              if (mounted && ok) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Safe auto-execution executed.')),
                );
              }
            },
          ),
        ),
      ],
    );
  }

  Widget _buildRecommendationCard(IntelligenceRecommendation rec) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    rec.title,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
                _buildPriorityChip(rec.priority),
              ],
            ),
            const SizedBox(height: 6),
            Text(rec.description, style: TextStyle(color: Colors.grey.shade700, fontSize: 13)),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.trending_down, color: Colors.green, size: 16),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      rec.expectedBenefit,
                      style: const TextStyle(color: Colors.green, fontWeight: FontWeight.w600, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () async {
                    await widget.service.rejectRecommendation(widget.homeId, rec.id);
                  },
                  child: const Text('Dismiss'),
                ),
                const SizedBox(width: 8),
                FilledButton.tonal(
                  onPressed: () async {
                    await widget.service.acceptRecommendation(widget.homeId, rec.id);
                  },
                  child: const Text('Accept Action'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDecisionTile(IntelligenceDecision d) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      leading: CircleAvatar(
        backgroundColor: _getStatusColor(d.status).withValues(alpha: 0.15),
        child: Icon(Icons.bolt, color: _getStatusColor(d.status)),
      ),
      title: Text(d.expectedEffect.isNotEmpty ? d.expectedEffect : d.decisionType, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
      subtitle: Text('Priority: ${d.priority.toApiValue()} • Risk: ${d.risk.toApiValue()}', style: const TextStyle(fontSize: 12)),
      trailing: Chip(
        label: Text(d.status.toApiValue(), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
        backgroundColor: _getStatusColor(d.status).withValues(alpha: 0.12),
      ),
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => IntelligenceDecisionDetailsPage(
              homeId: widget.homeId,
              decisionId: d.id,
              service: widget.service,
            ),
          ),
        );
      },
    );
  }

  Widget _buildPriorityChip(DecisionPriority priority) {
    Color color;
    switch (priority) {
      case DecisionPriority.safety:
        color = Colors.red;
        break;
      case DecisionPriority.energyCostOptimization:
        color = Colors.teal;
        break;
      case DecisionPriority.explicitHomeMode:
        color = Colors.indigo;
        break;
      default:
        color = Colors.blueGrey;
    }
    return Chip(
      label: Text(priority.toApiValue(), style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
      backgroundColor: color.withValues(alpha: 0.1),
      visualDensity: VisualDensity.compact,
    );
  }

  Color _getStatusColor(DecisionStatus status) {
    switch (status) {
      case DecisionStatus.autoExecuted:
      case DecisionStatus.executed:
      case DecisionStatus.accepted:
        return Colors.green;
      case DecisionStatus.rejected:
      case DecisionStatus.failed:
        return Colors.red;
      case DecisionStatus.skipped:
        return Colors.amber;
      case DecisionStatus.generated:
      default:
        return Colors.blue;
    }
  }

  Widget _buildEmptyCard(String message) {
    return Card(
      elevation: 0,
      color: Colors.grey.withValues(alpha: 0.08),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Center(
          child: Text(message, style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
        ),
      ),
    );
  }
}
