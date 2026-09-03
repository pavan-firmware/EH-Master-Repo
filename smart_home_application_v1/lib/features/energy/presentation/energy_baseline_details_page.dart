import 'package:flutter/material.dart';
import '../../../core/services/energy_predictive_service.dart';

class EnergyBaselineDetailsPage extends StatefulWidget {
  final String homeId;
  final String? deviceId;
  final EnergyPredictiveService service;

  const EnergyBaselineDetailsPage({
    super.key,
    required this.homeId,
    this.deviceId,
    required this.service,
  });

  @override
  State<EnergyBaselineDetailsPage> createState() => _EnergyBaselineDetailsPageState();
}

class _EnergyBaselineDetailsPageState extends State<EnergyBaselineDetailsPage> {
  @override
  void initState() {
    super.initState();
    _loadBaseline();
  }

  void _loadBaseline() {
    if (widget.deviceId != null) {
      widget.service.fetchDeviceBaseline(widget.deviceId!);
    } else {
      widget.service.fetchHomeBaseline(widget.homeId);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.service,
      builder: (context, _) {
        final baseline = widget.deviceId != null ? widget.service.deviceBaseline : widget.service.homeBaseline;

        return Scaffold(
          appBar: AppBar(
            title: Text(widget.deviceId != null ? 'Device Baseline' : 'Home Baseline'),
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: _loadBaseline,
                tooltip: 'Refresh Baseline',
              ),
            ],
          ),
          body: baseline == null
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  padding: const EdgeInsets.all(16.0),
                  children: [
                    Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      child: Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Baseline Metrics (${baseline.scopeType.toUpperCase()})',
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: _buildMetricTile(
                                    'Typical Power',
                                    '${baseline.typicalPowerW.toStringAsFixed(1)} W',
                                    Icons.flash_on,
                                    Colors.orange,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _buildMetricTile(
                                    'Daily Energy',
                                    '${baseline.typicalDailyEnergyKwh.toStringAsFixed(2)} kWh',
                                    Icons.bolt,
                                    Colors.blue,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: _buildMetricTile(
                                    'Overnight Load',
                                    '${baseline.typicalOvernightWh.toStringAsFixed(0)} Wh',
                                    Icons.nightlight,
                                    Colors.indigo,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _buildMetricTile(
                                    'Observations',
                                    '${baseline.sampleCount} samples',
                                    Icons.data_usage,
                                    Colors.teal,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Active Operating Hours (00:00 - 23:00)',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: List.generate(24, (hour) {
                        final isActive = baseline.typicalOperatingHours.contains(hour);
                        final label = '${hour.toString().padLeft(2, '0')}:00';
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: isActive ? Colors.blueAccent.withValues(alpha: 0.15) : Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isActive ? Colors.blueAccent : Colors.grey.shade300,
                            ),
                          ),
                          child: Text(
                            label,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                              color: isActive ? Colors.blueAccent : Colors.grey,
                            ),
                          ),
                        );
                      }),
                    ),
                  ],
                ),
        );
      },
    );
  }

  Widget _buildMetricTile(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 6),
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          const SizedBox(height: 2),
          Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }
}
