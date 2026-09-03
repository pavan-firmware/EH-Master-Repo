import 'package:flutter/material.dart';
import '../../../core/models/energy_automation_models.dart';
import '../../../core/services/energy_automation_service.dart';
import 'energy_automation_editor_page.dart';
import 'energy_automation_history_page.dart';
import 'energy_optimization_page.dart';

/// EH Home — Energy Automations List & Hub (Phase 20)
class EnergyAutomationsPage extends StatefulWidget {
  final String homeId;
  final EnergyAutomationService service;
  final List<Map<String, String>> availableDevices;
  final List<Map<String, String>> availableScenes;

  const EnergyAutomationsPage({
    super.key,
    required this.homeId,
    required this.service,
    this.availableDevices = const [],
    this.availableScenes = const [],
  });

  @override
  State<EnergyAutomationsPage> createState() => _EnergyAutomationsPageState();
}

class _EnergyAutomationsPageState extends State<EnergyAutomationsPage> {
  String _filter = 'ALL'; // ALL, ACTIVE, INACTIVE

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    await widget.service.fetchAutomations(widget.homeId);
    await widget.service.fetchOptimizationRecommendations(widget.homeId);
  }

  List<EnergyAutomationRuleModel> get _filteredRules {
    final list = widget.service.automations;
    if (_filter == 'ACTIVE') {
      return list.where((r) => r.isEnabled).toList();
    } else if (_filter == 'INACTIVE') {
      return list.where((r) => !r.isEnabled).toList();
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final service = widget.service;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Smart Energy Automations'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
            tooltip: 'Refresh',
          ),
          IconButton(
            icon: const Icon(Icons.insights),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => EnergyOptimizationPage(
                    homeId: widget.homeId,
                    service: widget.service,
                    availableDevices: widget.availableDevices,
                    availableScenes: widget.availableScenes,
                  ),
                ),
              );
            },
            tooltip: 'Optimization Recommendations',
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: widget.service,
        builder: (context, _) {
          if (service.isLoading && service.automations.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }
          return RefreshIndicator(
            onRefresh: _loadData,
            child: ListView(
              padding: const EdgeInsets.all(16.0),
              children: [
                // 1. Optimization Opportunities Banner
                if (service.optimizations.isNotEmpty)
                  Card(
                    color: Colors.amber.shade50,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: Colors.amber.shade300),
                    ),
                    child: ListTile(
                      leading: const CircleAvatar(
                        backgroundColor: Colors.amber,
                        child: Icon(Icons.lightbulb_outline, color: Colors.white),
                      ),
                      title: Text(
                        '${service.optimizations.length} Optimization Opportunities',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        'Save up to ~${service.optimizationSummary.totalMonthlyKwhSavings.toStringAsFixed(1)} kWh/mo (${service.optimizationSummary.currency} ${service.optimizationSummary.totalMonthlyCostSavings.toStringAsFixed(2)})',
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => EnergyOptimizationPage(
                              homeId: widget.homeId,
                              service: widget.service,
                              availableDevices: widget.availableDevices,
                              availableScenes: widget.availableScenes,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                if (service.optimizations.isNotEmpty) const SizedBox(height: 12),

                // 2. Filter Chips Row
                Row(
                  children: [
                    FilterChip(
                      label: Text('All (${service.automations.length})'),
                      selected: _filter == 'ALL',
                      onSelected: (_) => setState(() => _filter = 'ALL'),
                    ),
                    const SizedBox(width: 8),
                    FilterChip(
                      label: Text('Active (${service.automations.where((r) => r.isEnabled).length})'),
                      selected: _filter == 'ACTIVE',
                      onSelected: (_) => setState(() => _filter = 'ACTIVE'),
                    ),
                    const SizedBox(width: 8),
                    FilterChip(
                      label: Text('Disabled (${service.automations.where((r) => !r.isEnabled).length})'),
                      selected: _filter == 'INACTIVE',
                      onSelected: (_) => setState(() => _filter = 'INACTIVE'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // 3. Automations List or Empty State
                if (_filteredRules.isEmpty)
                  _buildEmptyState(context)
                else
                  ..._filteredRules.map((rule) => _buildRuleCard(context, rule)),
              ],
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text('New Energy Rule'),
        onPressed: () async {
          final result = await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => EnergyAutomationEditorPage(
                homeId: widget.homeId,
                service: widget.service,
                availableDevices: widget.availableDevices,
                availableScenes: widget.availableScenes,
              ),
            ),
          );
          if (result == true) {
            _loadData();
          }
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
          Icon(Icons.power_settings_new, size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            _filter == 'ALL' ? 'No Energy Automations Yet' : 'No $_filter Automations',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Create rules to automatically protect circuits from overloading, throttle power during peak hours, and cut off standby vampire power.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildRuleCard(BuildContext context, EnergyAutomationRuleModel rule) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Row: Name & Switch
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Icon(
                        rule.isEnabled ? Icons.bolt : Icons.power_off,
                        color: rule.isEnabled ? Colors.amber : Colors.grey,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          rule.name,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: rule.isEnabled ? null : Colors.grey,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: rule.isEnabled,
                  activeThumbColor: Colors.amber,
                  onChanged: (val) async {
                    await widget.service.toggleAutomation(rule.id, val);
                    setState(() {});
                  },
                ),
              ],
            ),

            if (rule.description != null && rule.description!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                rule.description!,
                style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
              ),
            ],

            const SizedBox(height: 10),

            // Chips: Scope, Condition, Hysteresis, Action
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                Chip(
                  avatar: const Icon(Icons.location_on, size: 14),
                  label: Text(rule.scopeType.toUpperCase(), style: const TextStyle(fontSize: 11)),
                  visualDensity: VisualDensity.compact,
                ),
                ...rule.conditions.map((c) {
                  return Chip(
                    backgroundColor: Colors.amber.shade50,
                    avatar: const Icon(Icons.sensors, size: 14, color: Colors.amber),
                    label: Text(
                      '${c.metric.displayName} ${c.operator.symbol} ${c.threshold} ${c.unit}',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                    ),
                    visualDensity: VisualDensity.compact,
                  );
                }),
                if (rule.hysteresis?.recoveryThreshold != null)
                  Chip(
                    backgroundColor: Colors.blue.shade50,
                    avatar: const Icon(Icons.history_toggle_off, size: 14, color: Colors.blue),
                    label: Text(
                      'Recovery: ${rule.hysteresis!.recoveryThreshold} W',
                      style: const TextStyle(fontSize: 11),
                    ),
                    visualDensity: VisualDensity.compact,
                  ),
                ...rule.actions.map((a) {
                  return Chip(
                    backgroundColor: Colors.teal.shade50,
                    avatar: const Icon(Icons.flash_on, size: 14, color: Colors.teal),
                    label: Text(
                      a.actionType == 'device_command'
                          ? (a.params?['value'] == false ? 'Turn OFF' : 'Turn ON')
                          : 'Trigger Scene',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                    ),
                    visualDensity: VisualDensity.compact,
                  );
                }),
              ],
            ),

            const Divider(height: 20),

            // Bottom Actions Row: Run, History, Edit, Delete
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                OutlinedButton.icon(
                  icon: const Icon(Icons.play_arrow, size: 16),
                  label: const Text('Test Run'),
                  onPressed: () async {
                    final res = await widget.service.evaluateAutomation(rule.id);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Test result: ${res?['status'] ?? 'Executed'}'),
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    }
                  },
                ),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.history, size: 20),
                      tooltip: 'Execution History',
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => EnergyAutomationHistoryPage(
                              automationId: rule.id,
                              automationName: rule.name,
                              service: widget.service,
                            ),
                          ),
                        );
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, size: 20),
                      tooltip: 'Edit Rule',
                      onPressed: () async {
                        final result = await Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => EnergyAutomationEditorPage(
                              homeId: widget.homeId,
                              service: widget.service,
                              existingRule: rule,
                              availableDevices: widget.availableDevices,
                              availableScenes: widget.availableScenes,
                            ),
                          ),
                        );
                        if (result == true) _loadData();
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, size: 20, color: Colors.red),
                      tooltip: 'Delete Rule',
                      onPressed: () async {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('Delete Energy Automation?'),
                            content: Text('Are you sure you want to delete "${rule.name}"?'),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                              TextButton(
                                onPressed: () => Navigator.pop(ctx, true),
                                child: const Text('Delete', style: TextStyle(color: Colors.red)),
                              ),
                            ],
                          ),
                        );
                        if (confirm == true) {
                          await widget.service.deleteAutomation(rule.id);
                          setState(() {});
                        }
                      },
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
