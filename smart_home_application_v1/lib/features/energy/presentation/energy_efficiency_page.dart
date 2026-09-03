import 'package:flutter/material.dart';
import '../../../core/models/energy_predictive_models.dart';
import '../../../core/services/energy_predictive_service.dart';

class EnergyEfficiencyPage extends StatefulWidget {
  final String homeId;
  final EnergyPredictiveService service;

  const EnergyEfficiencyPage({
    super.key,
    required this.homeId,
    required this.service,
  });

  @override
  State<EnergyEfficiencyPage> createState() => _EnergyEfficiencyPageState();
}

class _EnergyEfficiencyPageState extends State<EnergyEfficiencyPage> {
  @override
  void initState() {
    super.initState();
    _loadScore();
  }

  void _loadScore() {
    widget.service.fetchEfficiencyScore(widget.homeId);
  }

  Color _gradeColor(String grade) {
    switch (grade) {
      case 'A+':
      case 'A':
        return Colors.green;
      case 'B':
        return Colors.teal;
      case 'C':
        return Colors.amber.shade700;
      case 'D':
        return Colors.orange.shade800;
      case 'F':
      default:
        return Colors.red;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.service,
      builder: (context, _) {
        final eff = widget.service.efficiencyScore;
        final isLoading = widget.service.isLoading;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Energy Efficiency Score'),
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: _loadScore,
                tooltip: 'Refresh Score',
              ),
            ],
          ),
          body: isLoading && eff == null
              ? const Center(child: CircularProgressIndicator())
              : eff == null
                  ? const Center(child: Text('Efficiency score not available.'))
                  : RefreshIndicator(
                      onRefresh: () async => _loadScore(),
                      child: ListView(
                        padding: const EdgeInsets.all(16.0),
                        children: [
                          _buildScoreHero(eff),
                          const SizedBox(height: 20),
                          const Text(
                            'Score Breakdown (Explainable Factors)',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 12),
                          _buildFactorTile(
                            'Standby Loss Score',
                            'Overnight base draw vs total usage',
                            eff.factors.standbyLossScore,
                            Icons.nightlight_outlined,
                          ),
                          _buildFactorTile(
                            'Peak Demand Score',
                            'Disproportionate peak hour usage penalty',
                            eff.factors.peakDemandScore,
                            Icons.trending_up,
                          ),
                          _buildFactorTile(
                            'Threshold Compliance',
                            'Absence of safety threshold violations',
                            eff.factors.thresholdViolationScore,
                            Icons.shield_outlined,
                          ),
                          _buildFactorTile(
                            'Tariff Efficiency',
                            'Off-peak shift optimization ratio',
                            eff.factors.tariffEfficiencyScore,
                            Icons.electric_bolt_outlined,
                          ),
                          _buildFactorTile(
                            'Consumption Trend',
                            'Progress compared to historical baseline',
                            eff.factors.trendScore,
                            Icons.insights,
                          ),
                        ],
                      ),
                    ),
        );
      },
    );
  }

  Widget _buildScoreHero(EnergyEfficiencyScore eff) {
    final gradeColor = _gradeColor(eff.grade);
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 28.0, horizontal: 20.0),
        child: Column(
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 140,
                  height: 140,
                  child: CircularProgressIndicator(
                    value: eff.score / 100.0,
                    strokeWidth: 12,
                    backgroundColor: Colors.grey[200],
                    valueColor: AlwaysStoppedAnimation<Color>(gradeColor),
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      eff.score.toStringAsFixed(0),
                      style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'Grade ${eff.grade}',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: gradeColor,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              'Home Energy Efficiency Grade',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            const Text(
              'Calculated deterministically from 5 weighted behavioral factors.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFactorTile(String title, String subtitle, double score, IconData icon) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Icon(icon, color: Colors.blueAccent, size: 28),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: score / 100.0,
                    backgroundColor: Colors.grey[200],
                    valueColor: AlwaysStoppedAnimation<Color>(
                      score > 80 ? Colors.green : (score > 60 ? Colors.orange : Colors.red),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 14),
            Text(
              score.toStringAsFixed(0),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}
