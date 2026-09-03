import 'package:flutter/material.dart';
import '../../../core/models/energy_predictive_models.dart';
import '../../../core/services/energy_predictive_service.dart';

class EnergyAnomaliesPage extends StatefulWidget {
  final String homeId;
  final EnergyPredictiveService service;

  const EnergyAnomaliesPage({
    super.key,
    required this.homeId,
    required this.service,
  });

  @override
  State<EnergyAnomaliesPage> createState() => _EnergyAnomaliesPageState();
}

class _EnergyAnomaliesPageState extends State<EnergyAnomaliesPage> {
  @override
  void initState() {
    super.initState();
    _loadAnomalies();
  }

  void _loadAnomalies() {
    widget.service.fetchAnomalies(widget.homeId);
  }

  Color _severityColor(AnomalySeverity severity) {
    switch (severity) {
      case AnomalySeverity.info:
        return Colors.blue;
      case AnomalySeverity.low:
        return Colors.teal;
      case AnomalySeverity.medium:
        return Colors.amber.shade700;
      case AnomalySeverity.high:
        return Colors.orange.shade800;
      case AnomalySeverity.critical:
        return Colors.red.shade700;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.service,
      builder: (context, _) {
        final anomalies = widget.service.anomalies;
        final isLoading = widget.service.isLoading;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Energy Anomalies'),
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: _loadAnomalies,
                tooltip: 'Refresh Anomalies',
              ),
            ],
          ),
          body: isLoading && anomalies.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : anomalies.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.check_circle_outline, size: 56, color: Colors.green),
                          SizedBox(height: 12),
                          Text(
                            'No Anomalies Detected',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'All monitored loads are operating within expected baselines.',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: () async => _loadAnomalies(),
                      child: ListView.separated(
                        padding: const EdgeInsets.all(16.0),
                        itemCount: anomalies.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final a = anomalies[index];
                          final color = _severityColor(a.severity);

                          return Card(
                            elevation: 2,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                                          color: color.withValues(alpha: 0.15),
                                          borderRadius: BorderRadius.circular(6),
                                          border: Border.all(color: color),
                                        ),
                                        child: Text(
                                          a.severity.name.toUpperCase(),
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: color,
                                          ),
                                        ),
                                      ),
                                      if (a.isConfirmed)
                                        const Row(
                                          children: [
                                            Icon(Icons.verified, size: 16, color: Colors.blueAccent),
                                            SizedBox(width: 4),
                                            Text(
                                              'Confirmed',
                                              style: TextStyle(fontSize: 12, color: Colors.blueAccent),
                                            ),
                                          ],
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    a.anomalyType.replaceAll('_', ' '),
                                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Scope: ${a.scopeType.toUpperCase()} (${a.scopeId})',
                                    style: const TextStyle(fontSize: 13, color: Colors.grey),
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          'Observed: ${a.observedValue.toStringAsFixed(1)}',
                                          style: const TextStyle(fontWeight: FontWeight.w600),
                                        ),
                                      ),
                                      Expanded(
                                        child: Text(
                                          'Baseline: ${a.baselineValue.toStringAsFixed(1)}',
                                          style: const TextStyle(color: Colors.grey),
                                        ),
                                      ),
                                      Text(
                                        '+${a.deviationPercentage.toStringAsFixed(0)}%',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: color,
                                        ),
                                      ),
                                    ],
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
