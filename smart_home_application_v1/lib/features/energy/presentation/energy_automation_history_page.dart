import 'package:flutter/material.dart';
import '../../../core/models/energy_automation_models.dart';
import '../../../core/services/energy_automation_service.dart';

/// EH Home — Energy Automation Execution History Page (Phase 20)
class EnergyAutomationHistoryPage extends StatefulWidget {
  final String automationId;
  final String automationName;
  final EnergyAutomationService service;

  const EnergyAutomationHistoryPage({
    super.key,
    required this.automationId,
    required this.automationName,
    required this.service,
  });

  @override
  State<EnergyAutomationHistoryPage> createState() => _EnergyAutomationHistoryPageState();
}

class _EnergyAutomationHistoryPageState extends State<EnergyAutomationHistoryPage> {
  String _statusFilter = 'ALL'; // ALL, SUCCEEDED, SKIPPED, FAILED

  @override
  void initState() {
    super.initState();
    widget.service.fetchExecutionHistory(widget.automationId);
  }

  List<EnergyAutomationExecutionModel> get _filteredHistory {
    final list = widget.service.executionHistory;
    if (_statusFilter == 'SUCCEEDED') {
      return list.where((e) => e.status == 'succeeded').toList();
    } else if (_statusFilter == 'SKIPPED') {
      return list.where((e) => e.status == 'skipped' || e.status == 'conditions_not_met').toList();
    } else if (_statusFilter == 'FAILED') {
      return list.where((e) => e.status == 'failed').toList();
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final service = widget.service;

    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.automationName} — History'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => service.fetchExecutionHistory(widget.automationId),
            tooltip: 'Refresh History',
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: widget.service,
        builder: (context, _) {
          if (service.isLoading && service.executionHistory.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }
          return RefreshIndicator(
            onRefresh: () => service.fetchExecutionHistory(widget.automationId),
            child: ListView(
              padding: const EdgeInsets.all(16.0),
              children: [
                // Filter Chips
                Row(
                  children: [
                    FilterChip(
                      label: Text('All (${service.executionHistory.length})'),
                      selected: _statusFilter == 'ALL',
                      onSelected: (_) => setState(() => _statusFilter = 'ALL'),
                    ),
                    const SizedBox(width: 8),
                    FilterChip(
                      label: Text('Succeeded (${service.executionHistory.where((e) => e.status == 'succeeded').length})'),
                      selected: _statusFilter == 'SUCCEEDED',
                      onSelected: (_) => setState(() => _statusFilter = 'SUCCEEDED'),
                    ),
                    const SizedBox(width: 8),
                    FilterChip(
                      label: Text('Skipped (${service.executionHistory.where((e) => e.status == 'skipped' || e.status == 'conditions_not_met').length})'),
                      selected: _statusFilter == 'SKIPPED',
                      onSelected: (_) => setState(() => _statusFilter = 'SKIPPED'),
                    ),
                    const SizedBox(width: 8),
                    FilterChip(
                      label: Text('Failed (${service.executionHistory.where((e) => e.status == 'failed').length})'),
                      selected: _statusFilter == 'FAILED',
                      onSelected: (_) => setState(() => _statusFilter = 'FAILED'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                if (_filteredHistory.isEmpty)
                  _buildEmptyState(context)
                else
                  ..._filteredHistory.map((item) => _buildExecutionCard(context, item)),
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
          Icon(Icons.history_toggle_off, size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            'No Execution Logs Recorded',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Runs triggered by live telemetry or manual evaluation will appear here with durational snapshots and skip reasons.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildExecutionCard(BuildContext context, EnergyAutomationExecutionModel item) {
    Color statusColor = Colors.grey;
    IconData statusIcon = Icons.info_outline;

    if (item.status == 'succeeded') {
      statusColor = Colors.green;
      statusIcon = Icons.check_circle_outline;
    } else if (item.status == 'skipped' || item.status == 'conditions_not_met') {
      statusColor = Colors.orange;
      statusIcon = Icons.remove_circle_outline;
    } else if (item.status == 'failed') {
      statusColor = Colors.red;
      statusIcon = Icons.error_outline;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 1,
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: statusColor.withValues(alpha: 0.15),
          child: Icon(statusIcon, color: statusColor, size: 20),
        ),
        title: Text(
          item.triggerReason ?? item.triggerType,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        subtitle: Text(
          '${item.createdAt.toLocal().toString().split('.')[0]} • ${item.durationMs}ms',
          style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: statusColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            item.status.toUpperCase(),
            style: TextStyle(
              color: statusColor,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        childrenPadding: const EdgeInsets.all(16.0),
        children: [
          if (item.skipReason != null) ...[
            Row(
              children: [
                const Text('Skip Reason: ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                Text(
                  _formatSkipReason(item.skipReason!),
                  style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.w600, fontSize: 13),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],

          if (item.errorMessage != null) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Error: ', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red, fontSize: 13)),
                Expanded(
                  child: Text(
                    item.errorMessage!,
                    style: const TextStyle(color: Colors.red, fontSize: 13),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],

          if (item.telemetryContext != null) ...[
            const Align(
              alignment: Alignment.centerLeft,
              child: Text('Telemetry Context Snapshot:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
            ),
            const SizedBox(height: 4),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                item.telemetryContext.toString(),
                style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _formatSkipReason(String reason) {
    switch (reason) {
      case 'in_cooldown':
        return 'Suppressed by Cooldown Debounce';
      case 'hysteresis_active':
        return 'Hysteresis Active (Awaiting Recovery)';
      case 'loop_detected':
        return 'Safeguard Loop / Recursion Detected';
      case 'conditions_not_met':
        return 'Trigger Threshold Not Met';
      default:
        return reason;
    }
  }
}
