import 'package:flutter/material.dart';
import '../../../core/models/intelligence_models.dart';
import '../../../core/services/intelligence_service.dart';

class IntelligenceHistoryPage extends StatefulWidget {
  final String homeId;
  final HomeIntelligenceService service;

  const IntelligenceHistoryPage({
    super.key,
    required this.homeId,
    required this.service,
  });

  @override
  State<IntelligenceHistoryPage> createState() => _IntelligenceHistoryPageState();
}

class _IntelligenceHistoryPageState extends State<IntelligenceHistoryPage> {
  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    await widget.service.fetchHistory(widget.homeId);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.service,
      builder: (context, _) {
        final outcomes = widget.service.historyOutcomes;
        final isLoading = widget.service.isLoading;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Intelligence Outcomes History'),
            actions: [
              IconButton(icon: const Icon(Icons.refresh), onPressed: _fetch),
            ],
          ),
          body: RefreshIndicator(
            onRefresh: _fetch,
            child: isLoading && outcomes.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : outcomes.isEmpty
                    ? const Center(child: Text('No historical decision outcomes recorded.'))
                    : ListView.builder(
                        padding: const EdgeInsets.all(16.0),
                        itemCount: outcomes.length,
                        itemBuilder: (context, index) {
                          return _buildOutcomeCard(outcomes[index]);
                        },
                      ),
          ),
        );
      },
    );
  }

  Widget _buildOutcomeCard(DecisionOutcome outcome) {
    final isSuccess = outcome.status == DecisionStatus.executed ||
        outcome.status == DecisionStatus.autoExecuted ||
        outcome.status == DecisionStatus.accepted;

    return Card(
      margin: const EdgeInsets.only(bottom: 12.0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      isSuccess ? Icons.check_circle : Icons.error_outline,
                      color: isSuccess ? Colors.green : Colors.red,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      outcome.status.toApiValue(),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: isSuccess ? Colors.green : Colors.red,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
                Text(
                  outcome.executedAt.toLocal().toString().substring(0, 16),
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                ),
              ],
            ),
            const Divider(height: 20),
            if (outcome.expectedBenefit.isNotEmpty) ...[
              Text(
                'Expected Effect: ${outcome.expectedBenefit}',
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              ),
              const SizedBox(height: 4),
            ],
            if (outcome.actualBenefit.isNotEmpty) ...[
              Text(
                'Actual Outcome: ${outcome.actualBenefit}',
                style: TextStyle(color: Colors.grey.shade800, fontSize: 13),
              ),
              const SizedBox(height: 4),
            ],
            if (outcome.feedback.isNotEmpty) ...[
              Text(
                'Feedback: "${outcome.feedback}"',
                style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey.shade700, fontSize: 12),
              ),
              const SizedBox(height: 4),
            ],
            if (outcome.failureReason != null && outcome.failureReason!.isNotEmpty) ...[
              const SizedBox(height: 6),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Failure: ${outcome.failureReason}',
                  style: const TextStyle(color: Colors.red, fontSize: 12),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
