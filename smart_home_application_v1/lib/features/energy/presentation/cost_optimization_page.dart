import 'package:flutter/material.dart';
import '../../../core/models/energy_cost_models.dart';
import '../../../core/services/energy_cost_service.dart';

/// Cost Optimization Hub — Load Shifting, Peak Avoidance & Savings Opportunities
class CostOptimizationPage extends StatefulWidget {
  final String homeId;
  final EnergyCostService costService;

  const CostOptimizationPage({
    super.key,
    required this.homeId,
    required this.costService,
  });

  @override
  State<CostOptimizationPage> createState() => _CostOptimizationPageState();
}

class _CostOptimizationPageState extends State<CostOptimizationPage> {
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadOptimizations();
  }

  Future<void> _loadOptimizations() async {
    setState(() => _isLoading = true);
    await Future.wait([
      widget.costService.fetchCheapestPeriods(widget.homeId),
      widget.costService.fetchCostOptimizations(widget.homeId),
    ]);
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cheapest = widget.costService.cheapestPeriods;
    final opts = widget.costService.optimizations;

    return Scaffold(
      backgroundColor: const Color(0xFF121418),
      appBar: AppBar(
        title: const Text('Cost Optimization Hub', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF1E222B),
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.amberAccent))
          : RefreshIndicator(
              onRefresh: _loadOptimizations,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (cheapest != null) _buildCheapestPeriodHero(cheapest),
                    const SizedBox(height: 20),
                    const Text(
                      'Load-Shifting Recommendations',
                      style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    if (opts.isEmpty)
                      _buildNoRecommendationsCard()
                    else
                      ...opts.map((rec) => _buildRecommendationCard(rec)),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildCheapestPeriodHero(CheapestPeriodModel cheapest) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF064E3B), Color(0xFF065F46)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.greenAccent.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.schedule, color: Colors.greenAccent, size: 20),
                  SizedBox(width: 8),
                  Text('Cheapest Next 24h Window', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(8)),
                child: Text('SAVE ${cheapest.potentialSavingsPercent.toInt()}%',
                    style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold, fontSize: 11)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '${cheapest.cheapestWindow.periodType} • ${cheapest.currency} ${cheapest.cheapestWindow.avgPricePerKwh.toStringAsFixed(2)}/kWh',
            style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            'Recommended for EV charging, laundry, and dishwasher cycles',
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildNoRecommendationsCard() {
    return Card(
      color: const Color(0xFF1E222B),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: const Padding(
        padding: EdgeInsets.all(24.0),
        child: Column(
          children: [
            Icon(Icons.check_circle_outline, color: Colors.greenAccent, size: 48),
            SizedBox(height: 12),
            Text('No High Peak Loads Detected', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            SizedBox(height: 6),
            Text('Your devices are running efficiently within low-cost tariff periods.',
                textAlign: TextAlign.center, style: TextStyle(color: Colors.white54, fontSize: 12)),
          ],
        ),
      ),
    );
  }

  Widget _buildRecommendationCard(CostOptimizationRecommendationModel rec) {
    final savings = rec.estimatedSavings;
    final monthlyCost = savings?['monthlyCostSavings'] ?? 0.0;
    final currency = savings?['currency'] ?? 'USD';

    return Card(
      color: const Color(0xFF1E222B),
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(rec.title, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: Colors.amberAccent.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(8)),
                  child: Text(rec.priority, style: const TextStyle(color: Colors.amberAccent, fontSize: 10, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(rec.description, style: const TextStyle(color: Colors.white70, fontSize: 13)),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.savings_outlined, color: Colors.greenAccent, size: 18),
                const SizedBox(width: 6),
                Text(
                  'Est. Savings: $currency ${monthlyCost.toString()} / mo',
                  style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ],
            ),
            const Divider(color: Colors.white10, height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () async {
                    await widget.costService.dismissCostOptimization(widget.homeId, rec.id);
                  },
                  child: const Text('Dismiss', style: TextStyle(color: Colors.white54)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
