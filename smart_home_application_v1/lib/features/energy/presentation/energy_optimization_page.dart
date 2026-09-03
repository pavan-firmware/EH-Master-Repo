import 'package:flutter/material.dart';
import '../../../core/models/energy_automation_models.dart';
import '../../../core/services/energy_automation_service.dart';
import 'energy_automation_editor_page.dart';

/// EH Home — Energy Optimization Recommendations Hub (Phase 20)
class EnergyOptimizationPage extends StatefulWidget {
  final String homeId;
  final EnergyAutomationService service;
  final List<Map<String, String>> availableDevices;
  final List<Map<String, String>> availableScenes;

  const EnergyOptimizationPage({
    super.key,
    required this.homeId,
    required this.service,
    this.availableDevices = const [],
    this.availableScenes = const [],
  });

  @override
  State<EnergyOptimizationPage> createState() => _EnergyOptimizationPageState();
}

class _EnergyOptimizationPageState extends State<EnergyOptimizationPage> {
  @override
  void initState() {
    super.initState();
    widget.service.fetchOptimizationRecommendations(widget.homeId);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final service = widget.service;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Energy Optimization'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => service.fetchOptimizationRecommendations(widget.homeId),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: widget.service,
        builder: (context, _) {
          final summary = service.optimizationSummary;
          final recommendations = service.optimizations.where((r) => !r.isDismissed).toList();

          if (service.isLoading && service.optimizations.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }
          return RefreshIndicator(
            onRefresh: () => service.fetchOptimizationRecommendations(widget.homeId),
            child: ListView(
              padding: const EdgeInsets.all(16.0),
              children: [
                // 1. Savings Summary Card
                Card(
                  elevation: 3,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Container(
                    padding: const EdgeInsets.all(20.0),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      gradient: LinearGradient(
                        colors: [Colors.green.shade800, Colors.teal.shade700],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.eco, color: Colors.white, size: 24),
                            const SizedBox(width: 8),
                            Text(
                              'Estimated Monthly Savings',
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${summary.totalMonthlyKwhSavings.toStringAsFixed(1)} kWh',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 28,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const Text(
                                  'Energy Conservation',
                                  style: TextStyle(color: Colors.white70, fontSize: 12),
                                ),
                              ],
                            ),
                            Container(
                              height: 40,
                              width: 1,
                              color: Colors.white24,
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${summary.currency} ${summary.totalMonthlyCostSavings.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 28,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const Text(
                                  'Estimated Cost Savings',
                                  style: TextStyle(color: Colors.white70, fontSize: 12),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          '* Estimated based on current baseline telemetry and configured tariff.',
                          style: TextStyle(color: Colors.white60, fontSize: 11, fontStyle: FontStyle.italic),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // 2. Section Title
                Text(
                  'Optimization Opportunities (${recommendations.length})',
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),

                // 3. Recommendation Cards or Empty State
                if (recommendations.isEmpty)
                  _buildEmptyState(context)
                else
                  ...recommendations.map((rec) => _buildRecommendationCard(context, rec)),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
      alignment: Alignment.center,
      child: Column(
        children: [
          Icon(Icons.check_circle_outline, size: 64, color: Colors.green.shade400),
          const SizedBox(height: 16),
          Text(
            'All Systems Optimized!',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'No abnormal vampire standby or recurring energy waste detected across your devices.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildRecommendationCard(BuildContext context, EnergyOptimizationRecommendationModel rec) {
    final theme = Theme.of(context);

    Color priorityColor = Colors.orange;
    if (rec.priority == 'HIGH') priorityColor = Colors.red;
    if (rec.priority == 'LOW') priorityColor = Colors.blue;

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Category & Priority
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Chip(
                  label: Text(
                    rec.category.replaceAll('_', ' '),
                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                  backgroundColor: Colors.grey.shade100,
                  visualDensity: VisualDensity.compact,
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: priorityColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '${rec.priority} PRIORITY',
                    style: TextStyle(
                      color: priorityColor,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Title & Description
            Text(
              rec.title,
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              rec.description,
              style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
            ),

            const SizedBox(height: 12),

            // Savings & Evidence Box
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Estimated Savings',
                          style: TextStyle(fontSize: 11, color: Colors.grey),
                        ),
                        Text(
                          '~${rec.estimatedSavings.monthlyKwh.toStringAsFixed(1)} kWh/mo (${rec.estimatedSavings.currency} ${rec.estimatedSavings.monthlyCost.toStringAsFixed(2)})',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (rec.evidence != null && rec.evidence!['baselinePowerW'] != null)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Text(
                          'Observed Baseline',
                          style: TextStyle(fontSize: 11, color: Colors.grey),
                        ),
                        Text(
                          '${rec.evidence!['baselinePowerW']} W',
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                ],
              ),
            ),

            const SizedBox(height: 14),

            // Bottom Buttons: Create Rule & Dismiss
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton(
                  child: const Text('Dismiss', style: TextStyle(color: Colors.grey)),
                  onPressed: () async {
                    await widget.service.dismissOptimization(widget.homeId, rec.id);
                    setState(() {});
                  },
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Create Automation Rule'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal.shade700,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () {
                    // Pre-populate editor with suggested action
                    EnergyAutomationRuleModel? prefill;
                    if (rec.suggestedAction != null) {
                      final actionType = rec.suggestedAction!['type'] ?? 'device_command';
                      prefill = EnergyAutomationRuleModel(
                        id: '',
                        homeId: widget.homeId,
                        name: 'Auto-Fix: ${rec.title}',
                        description: 'Created from Energy Optimization: ${rec.title}',
                        scopeType: rec.deviceId != null ? 'device' : 'home',
                        scopeId: rec.deviceId,
                        conditions: [
                          EnergyConditionModel(
                            metric: rec.category == 'VAMPIRE_STANDBY_POWER'
                                ? EnergyMetric.instantaneousPower
                                : EnergyMetric.sustainedPower,
                            operator: EnergyOperator.gt,
                            threshold: (rec.evidence?['baselinePowerW'] as num?)?.toDouble() ?? 50.0,
                            deviceId: rec.deviceId,
                          ),
                        ],
                        actions: [
                          EnergyActionModel(
                            actionType: actionType,
                            deviceId: rec.deviceId,
                            channelIndex: 1,
                            command: 'setPower',
                            params: {'value': false, 'power': false},
                          ),
                        ],
                      );
                    }

                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => EnergyAutomationEditorPage(
                          homeId: widget.homeId,
                          service: widget.service,
                          existingRule: prefill,
                          availableDevices: widget.availableDevices,
                          availableScenes: widget.availableScenes,
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
