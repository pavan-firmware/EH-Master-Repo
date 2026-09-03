import 'package:flutter/material.dart';
import '../../../core/models/intelligence_models.dart';
import '../../../core/services/intelligence_service.dart';

class IntelligenceDecisionDetailsPage extends StatelessWidget {
  final String homeId;
  final String decisionId;
  final HomeIntelligenceService service;

  const IntelligenceDecisionDetailsPage({
    super.key,
    required this.homeId,
    required this.decisionId,
    required this.service,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: service,
      builder: (context, _) {
        final decision = service.decisions.cast<IntelligenceDecision?>().firstWhere(
              (d) => d?.id == decisionId,
              orElse: () => null,
            );

        if (decision == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Decision Details')),
            body: const Center(child: Text('Decision record not found.')),
          );
        }

        return Scaffold(
          appBar: AppBar(
            title: const Text('Decision Details'),
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
              Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            decision.decisionType,
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          Chip(
                            label: Text(decision.status.toApiValue(), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Priority Rank: ${decision.priorityRank} (${decision.priority.toApiValue()})',
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                      ),
                      const Divider(height: 24),
                      _buildDetailRow('Effect', decision.expectedEffect),
                      _buildDetailRow('Confidence', '${(decision.confidenceScore * 100).toStringAsFixed(0)}% (${decision.confidence.toApiValue()})'),
                      _buildDetailRow('Risk Level', decision.risk.toApiValue()),
                      _buildDetailRow('Auto-Executable', decision.isAutoExecutable ? 'Yes' : 'No (Requires Approval)'),
                      _buildDetailRow('Created', decision.createdAt.toLocal().toString()),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Safety Evaluation
              Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            decision.safetyResult['isSafe'] == true ? Icons.check_circle : Icons.warning,
                            color: decision.safetyResult['isSafe'] == true ? Colors.green : Colors.orange,
                          ),
                          const SizedBox(width: 8),
                          const Text('Safety Pre-Check', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        decision.safetyResult['reason']?.toString() ?? 'Pre-execution safety checks passed.',
                        style: const TextStyle(fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Evidence Section
              Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Supporting Evidence', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          decision.evidence.entries.map((e) => '${e.key}: ${e.value}').join('\n'),
                          style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              if (decision.status == DecisionStatus.generated) ...[
                const SizedBox(height: 24),
                FilledButton.icon(
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Execute Decision Now'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () async {
                    final ok = await service.executeDecision(homeId, decision.id);
                    if (context.mounted && ok) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Decision executed successfully.')),
                      );
                    }
                  },
                ),
              ],
            ],
          ),
        ),
      );
      },
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13)),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
          ),
        ],
      ),
    );
  }
}
