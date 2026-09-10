import 'package:flutter/material.dart';
import '../../../core/models/energy_cost_models.dart';
import '../../../core/services/energy_cost_service.dart';
import '../../../core/theme/app_theme.dart';

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
    final tokens = context.ehColors;
    final cheapest = widget.costService.cheapestPeriods;
    final opts = widget.costService.optimizations;

    return Scaffold(
      backgroundColor: tokens.bgApp,
      appBar: AppBar(
        title: Text(
          'Cost Optimization Hub',
          style: TextStyle(fontWeight: FontWeight.bold, color: tokens.textPrimary),
        ),
        backgroundColor: tokens.bgApp,
        elevation: 0,
        iconTheme: IconThemeData(color: tokens.headerAction),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: tokens.bluePrimary))
          : RefreshIndicator(
              color: tokens.bluePrimary,
              backgroundColor: tokens.surfaceElevated,
              onRefresh: _loadOptimizations,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (cheapest != null) _buildCheapestPeriodHero(cheapest, tokens),
                    const SizedBox(height: 20),
                    Text(
                      'Load-Shifting Recommendations',
                      style: TextStyle(color: tokens.textPrimary, fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    if (opts.isEmpty)
                      _buildNoRecommendationsCard(tokens)
                    else
                      ...opts.map((rec) => _buildRecommendationCard(rec, tokens)),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildCheapestPeriodHero(CheapestPeriodModel cheapest, EHThemeTokens tokens) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: tokens.successContainer,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: tokens.success.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.schedule, color: tokens.success, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Cheapest Next 24h Window',
                    style: TextStyle(color: tokens.success, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: tokens.isDark ? Colors.black26 : Colors.white.withValues(alpha: 0.8),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'SAVE ${cheapest.potentialSavingsPercent.toInt()}%',
                  style: TextStyle(color: tokens.success, fontWeight: FontWeight.bold, fontSize: 11),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '${cheapest.cheapestWindow.periodType} • ${cheapest.currency} ${cheapest.cheapestWindow.avgPricePerKwh.toStringAsFixed(2)}/kWh',
            style: TextStyle(color: tokens.textPrimary, fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            'Recommended for EV charging, laundry, and dishwasher cycles',
            style: TextStyle(color: tokens.textSecondary, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildNoRecommendationsCard(EHThemeTokens tokens) {
    return Card(
      color: tokens.surfaceCard,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: tokens.borderSubtle),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            Icon(Icons.check_circle_outline, color: tokens.success, size: 48),
            const SizedBox(height: 12),
            Text(
              'No High Peak Loads Detected',
              style: TextStyle(color: tokens.textPrimary, fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              'Your devices are running efficiently within low-cost tariff periods.',
              textAlign: TextAlign.center,
              style: TextStyle(color: tokens.textSecondary, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecommendationCard(CostOptimizationRecommendationModel rec, EHThemeTokens tokens) {
    final savings = rec.estimatedSavings;
    final monthlyCost = savings?['monthlyCostSavings'] ?? 0.0;
    final currency = savings?['currency'] ?? 'USD';

    return Card(
      color: tokens.surfaceCard,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: tokens.borderSubtle),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    rec.title,
                    style: TextStyle(color: tokens.textPrimary, fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: tokens.warningContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    rec.priority,
                    style: TextStyle(color: tokens.warning, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              rec.description,
              style: TextStyle(color: tokens.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.savings_outlined, color: tokens.success, size: 18),
                const SizedBox(width: 6),
                Text(
                  'Est. Savings: $currency ${monthlyCost.toString()} / mo',
                  style: TextStyle(color: tokens.success, fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ],
            ),
            Divider(color: tokens.borderSubtle, height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () async {
                    await widget.costService.dismissCostOptimization(widget.homeId, rec.id);
                  },
                  child: Text('Dismiss', style: TextStyle(color: tokens.textSecondary)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
