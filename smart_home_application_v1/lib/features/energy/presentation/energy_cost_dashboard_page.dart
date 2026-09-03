import 'package:flutter/material.dart';
import '../../../core/models/energy_cost_models.dart';
import '../../../core/services/energy_cost_service.dart';
import 'tariff_management_page.dart';
import 'energy_budget_page.dart';
import 'cost_optimization_page.dart';

/// Energy Cost Dashboard — Authoritative Cost Intelligence, Forecasting & Budgets
class EnergyCostDashboardPage extends StatefulWidget {
  final String homeId;
  final EnergyCostService costService;

  const EnergyCostDashboardPage({
    super.key,
    required this.homeId,
    required this.costService,
  });

  @override
  State<EnergyCostDashboardPage> createState() => _EnergyCostDashboardPageState();
}

class _EnergyCostDashboardPageState extends State<EnergyCostDashboardPage> {
  bool _isLoading = true;
  String _selectedPeriod = 'today';

  @override
  void initState() {
    super.initState();
    _loadAllData();
  }

  Future<void> _loadAllData() async {
    setState(() => _isLoading = true);
    await Future.wait([
      widget.costService.fetchCostSummary(widget.homeId, period: _selectedPeriod),
      widget.costService.fetchCostForecast(widget.homeId),
      widget.costService.fetchBudgetStatus(widget.homeId),
      widget.costService.fetchCheapestPeriods(widget.homeId),
      widget.costService.fetchCarbonFootprint(widget.homeId, period: _selectedPeriod),
      widget.costService.fetchCostOptimizations(widget.homeId),
    ]);
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121418),
      appBar: AppBar(
        title: const Text('Energy Cost & Optimization', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF1E222B),
        elevation: 0,
        actions: [
          IconButton(
            key: const Key('btn_manage_tariffs'),
            icon: const Icon(Icons.price_change_outlined),
            tooltip: 'Tariffs',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => TariffManagementPage(
                    homeId: widget.homeId,
                    costService: widget.costService,
                  ),
                ),
              );
            },
          ),
          IconButton(
            key: const Key('btn_manage_budget'),
            icon: const Icon(Icons.account_balance_wallet_outlined),
            tooltip: 'Budget',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => EnergyBudgetPage(
                    homeId: widget.homeId,
                    costService: widget.costService,
                  ),
                ),
              );
            },
          ),
          IconButton(
            key: const Key('btn_refresh_cost'),
            icon: const Icon(Icons.refresh),
            onPressed: _loadAllData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.amberAccent))
          : RefreshIndicator(
              onRefresh: _loadAllData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildPeriodSelector(),
                    const SizedBox(height: 16),
                    _buildCostHeroCard(),
                    const SizedBox(height: 16),
                    _buildForecastCard(),
                    const SizedBox(height: 16),
                    _buildBudgetProgressCard(),
                    const SizedBox(height: 16),
                    _buildPeakBreakdownCard(),
                    const SizedBox(height: 16),
                    _buildCheapestWindowBanner(),
                    const SizedBox(height: 16),
                    _buildCarbonFootprintCard(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildPeriodSelector() {
    return SegmentedButton<String>(
      segments: const [
        ButtonSegment(value: 'today', label: Text('Today')),
        ButtonSegment(value: 'week', label: Text('Week')),
        ButtonSegment(value: 'month', label: Text('Month')),
      ],
      selected: {_selectedPeriod},
      onSelectionChanged: (set) {
        setState(() => _selectedPeriod = set.first);
        _loadAllData();
      },
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return Colors.amberAccent.withValues(alpha: 0.2);
          }
          return const Color(0xFF1E222B);
        }),
        foregroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return Colors.amberAccent;
          }
          return Colors.white70;
        }),
      ),
    );
  }

  Widget _buildCostHeroCard() {
    final cost = widget.costService.costSummary;
    final currency = cost?.currency ?? 'USD';
    final totalCost = cost?.totalCost ?? 0.0;
    final totalKwh = cost?.totalKwh ?? 0.0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF1E293B),
            const Color(0xFF0F172A),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.amberAccent.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Energy Cost (${_selectedPeriod.toUpperCase()})',
                style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold),
              ),
              if (cost?.effectiveTariffName != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.blueAccent.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    cost!.effectiveTariffName!,
                    style: const TextStyle(color: Colors.lightBlueAccent, fontSize: 11, fontWeight: FontWeight.w600),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '$currency ${totalCost.toStringAsFixed(2)}',
            style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Text(
            '${totalKwh.toStringAsFixed(2)} kWh consumed',
            style: const TextStyle(color: Colors.white60, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildForecastCard() {
    final forecast = widget.costService.forecast;
    if (forecast == null) return const SizedBox.shrink();

    final currency = forecast.currency;
    return Card(
      color: const Color(0xFF1E222B),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.trending_up, color: Colors.orangeAccent, size: 20),
                    SizedBox(width: 8),
                    Text('Monthly Cost Projection', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.orangeAccent.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text('ESTIMATE', style: TextStyle(color: Colors.orangeAccent, fontSize: 10, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Actual to Date', style: TextStyle(color: Colors.white54, fontSize: 12)),
                    const SizedBox(height: 4),
                    Text('$currency ${forecast.actualCostToDate.toStringAsFixed(2)}',
                        style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Est. Remaining', style: TextStyle(color: Colors.white54, fontSize: 12)),
                    const SizedBox(height: 4),
                    Text('$currency ${forecast.estimatedRemainingCost.toStringAsFixed(2)}',
                        style: const TextStyle(color: Colors.white70, fontSize: 16)),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text('Projected Total', style: TextStyle(color: Colors.white54, fontSize: 12)),
                    const SizedBox(height: 4),
                    Text('$currency ${forecast.projectedTotalCost.toStringAsFixed(2)}',
                        style: const TextStyle(color: Colors.orangeAccent, fontSize: 18, fontWeight: FontWeight.bold)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: forecast.confidenceScore,
              backgroundColor: Colors.white10,
              color: Colors.orangeAccent,
              minHeight: 4,
            ),
            const SizedBox(height: 4),
            Text('Confidence: ${(forecast.confidenceScore * 100).toInt()}% based on ${forecast.daysElapsed} days of data',
                style: const TextStyle(color: Colors.white38, fontSize: 11)),
          ],
        ),
      ),
    );
  }

  Widget _buildBudgetProgressCard() {
    final status = widget.costService.budgetStatus;
    if (status == null || !status.configured) {
      return Card(
        color: const Color(0xFF1E222B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: ListTile(
          leading: const Icon(Icons.account_balance_wallet, color: Colors.greenAccent),
          title: const Text('Set Monthly Budget', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          subtitle: const Text('Track spending and get projected overrun alerts', style: TextStyle(color: Colors.white60, fontSize: 12)),
          trailing: ElevatedButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => EnergyBudgetPage(homeId: widget.homeId, costService: widget.costService)),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.amberAccent, foregroundColor: Colors.black),
            child: const Text('Configure'),
          ),
        ),
      );
    }

    final percent = (status.percentConsumed / 100).clamp(0.0, 1.0);
    final isExceeded = status.isProjectedToExceed;

    return Card(
      color: const Color(0xFF1E222B),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Monthly Budget Progress', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                if (isExceeded)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: Colors.redAccent.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(8)),
                    child: Text('Overrun: ${status.currency} ${status.projectedOverrun.toStringAsFixed(2)}',
                        style: const TextStyle(color: Colors.redAccent, fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: percent,
              backgroundColor: Colors.white10,
              color: isExceeded ? Colors.redAccent : Colors.greenAccent,
              minHeight: 8,
              borderRadius: BorderRadius.circular(4),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('${status.percentConsumed.toStringAsFixed(1)}% consumed', style: const TextStyle(color: Colors.white60, fontSize: 12)),
                Text('Budget: ${status.currency} ${status.budgetAmount.toStringAsFixed(2)}', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPeakBreakdownCard() {
    final cost = widget.costService.costSummary;
    if (cost == null) return const SizedBox.shrink();

    final peak = cost.peak;
    final offPeak = cost.offPeak;
    final standard = cost.standard;
    final currency = cost.currency;

    return Card(
      color: const Color(0xFF1E222B),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Tariff Period Breakdown', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildBreakdownColumn('Off-Peak', offPeak, Colors.greenAccent, currency),
                _buildBreakdownColumn('Standard', standard, Colors.blueAccent, currency),
                _buildBreakdownColumn('Peak', peak, Colors.redAccent, currency),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBreakdownColumn(String title, CostBreakdownItem item, Color color, String currency) {
    return Column(
      children: [
        Text(title, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text('$currency ${item.cost.toStringAsFixed(2)}', style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
        Text('${item.kwh.toStringAsFixed(1)} kWh', style: const TextStyle(color: Colors.white54, fontSize: 11)),
      ],
    );
  }

  Widget _buildCheapestWindowBanner() {
    final cheapest = widget.costService.cheapestPeriods;
    if (cheapest == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.greenAccent.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.greenAccent.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.bolt, color: Colors.greenAccent, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Cheapest Upcoming Window', style: TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 2),
                Text(
                  '${cheapest.currency} ${cheapest.cheapestWindow.avgPricePerKwh.toStringAsFixed(2)}/kWh (${cheapest.cheapestWindow.periodType}) • Save up to ${cheapest.potentialSavingsPercent.toInt()}%',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => CostOptimizationPage(homeId: widget.homeId, costService: widget.costService)),
              );
            },
            child: const Text('Optimize', style: TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildCarbonFootprintCard() {
    final carbon = widget.costService.carbonFootprint;
    if (carbon == null) return const SizedBox.shrink();

    return Card(
      color: const Color(0xFF1E222B),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            const Icon(Icons.eco, color: Colors.tealAccent, size: 30),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Estimated Carbon Footprint', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 2),
                  Text('${carbon.totalKgCO2.toStringAsFixed(2)} kg CO₂ (${carbon.carbonIntensityGPerKwh.toInt()} g/kWh)',
                      style: const TextStyle(color: Colors.white70, fontSize: 12)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
