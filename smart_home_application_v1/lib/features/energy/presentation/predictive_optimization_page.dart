import 'package:flutter/material.dart';
import '../../../core/services/energy_predictive_service.dart';

class PredictiveOptimizationPage extends StatefulWidget {
  final String homeId;
  final EnergyPredictiveService service;

  const PredictiveOptimizationPage({
    super.key,
    required this.homeId,
    required this.service,
  });

  @override
  State<PredictiveOptimizationPage> createState() => _PredictiveOptimizationPageState();
}

class _PredictiveOptimizationPageState extends State<PredictiveOptimizationPage> {
  @override
  void initState() {
    super.initState();
    _loadOptimizations();
  }

  void _loadOptimizations() {
    widget.service.fetchPredictiveOptimizations(widget.homeId);
  }

  Color _priorityColor(String priority) {
    switch (priority.toUpperCase()) {
      case 'CRITICAL':
      case 'HIGH':
        return Colors.orange.shade800;
      case 'MEDIUM':
        return Colors.blue;
      case 'LOW':
      default:
        return Colors.teal;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.service,
      builder: (context, _) {
        final recs = widget.service.recommendations;
        final isLoading = widget.service.isLoading;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Predictive Optimization'),
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: _loadOptimizations,
                tooltip: 'Refresh Recommendations',
              ),
            ],
          ),
          body: isLoading && recs.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : recs.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.lightbulb_outline, size: 56, color: Colors.green),
                          SizedBox(height: 12),
                          Text(
                            'No Optimization Actions Needed',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Your energy usage is already optimized for current forecasts.',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: () async => _loadOptimizations(),
                      child: ListView.separated(
                        padding: const EdgeInsets.all(16.0),
                        itemCount: recs.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final r = recs[index];
                          final priorityColor = _priorityColor(r.priority);

                          return Card(
                            elevation: 2,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: priorityColor.withValues(alpha: 0.15),
                                          borderRadius: BorderRadius.circular(6),
                                          border: Border.all(color: priorityColor),
                                        ),
                                        child: Text(
                                          '${r.priority.toUpperCase()} PRIORITY',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: priorityColor,
                                          ),
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.amber.withValues(alpha: 0.2),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: const Text(
                                          'ESTIMATE',
                                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.amber),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    r.title,
                                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    r.description,
                                    style: const TextStyle(fontSize: 13, color: Colors.black87),
                                  ),
                                  const SizedBox(height: 12),
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
                                              const Text('Estimated Savings', style: TextStyle(fontSize: 11, color: Colors.grey)),
                                              const SizedBox(height: 2),
                                              Text(
                                                '${r.currency} ${r.estimatedCostSavings.toStringAsFixed(2)} / period',
                                                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              const Text('Confidence', style: TextStyle(fontSize: 11, color: Colors.grey)),
                                              const SizedBox(height: 2),
                                              Text(
                                                '${(r.confidence * 100).toInt()}%',
                                                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blueAccent),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
        );
      },
    );
  }
}
