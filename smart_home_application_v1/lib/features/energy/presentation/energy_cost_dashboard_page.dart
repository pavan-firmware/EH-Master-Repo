import 'package:flutter/material.dart';
import '../../../core/models/energy_cost_models.dart';
import '../../../core/services/energy_cost_service.dart';
import '../../../core/theme/app_theme.dart';
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
    final tokens = context.ehColors;

    return Scaffold(
      backgroundColor: tokens.bgApp,
      appBar: AppBar(
        title: Text(
          'Energy Cost & Optimization',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: tokens.textPrimary,
          ),
        ),
        backgroundColor: tokens.bgApp,
        elevation: 0,
        iconTheme: IconThemeData(color: tokens.headerAction),
        actions: [
          IconButton(
            key: const Key('btn_manage_tariffs'),
            icon: Icon(Icons.price_change_outlined, color: tokens.headerAction),
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
            icon: Icon(Icons.account_balance_wallet_outlined, color: tokens.headerAction),
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
            icon: Icon(Icons.refresh, color: tokens.headerAction),
            onPressed: _loadAllData,
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: tokens.bluePrimary))
          : RefreshIndicator(
              color: tokens.bluePrimary,
              backgroundColor: tokens.surfaceElevated,
              onRefresh: _loadAllData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildPeriodSelector(tokens),
                    const SizedBox(height: 16),
                    _buildCostHeroCard(tokens),
                    const SizedBox(height: 16),
                    _buildForecastCard(tokens),
                    const SizedBox(height: 16),
                    _buildBudgetProgressCard(tokens),
                    const SizedBox(height: 16),
                    _buildPeakBreakdownCard(tokens),
                    const SizedBox(height: 16),
                    _buildCheapestWindowBanner(tokens),
                    const SizedBox(height: 16),
                    _buildCarbonFootprintCard(tokens),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildPeriodSelector(EHThemeTokens tokens) {
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
            return tokens.blueSelectedBg;
          }
          return tokens.surfaceCard;
        }),
        foregroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return tokens.blueSelectedText;
          }
          return tokens.textSecondary;
        }),
        side: WidgetStateProperty.all(BorderSide(color: tokens.borderControl)),
      ),
    );
  }

  Widget _buildCostHeroCard(EHThemeTokens tokens) {
    final cost = widget.costService.costSummary;
    final currency = cost?.currency ?? 'USD';
    final totalCost = cost?.totalCost ?? 0.0;
    final totalKwh = cost?.totalKwh ?? 0.0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: tokens.isDark
              ? [const Color(0xFF1E293B), const Color(0xFF0F172A)]
              : [const Color(0xFF2563EB), const Color(0xFF1D4ED8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: (tokens.isDark ? Colors.black : const Color(0xFF2563EB)).withValues(alpha: 0.25),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Energy Cost (${_selectedPeriod.toUpperCase()})',
                style: const TextStyle(color: Color(0xFFD9E8FF), fontSize: 13, fontWeight: FontWeight.bold),
              ),
              if (cost?.effectiveTariffName != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    cost!.effectiveTariffName!,
                    style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
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
            style: const TextStyle(color: Color(0xFFD9E8FF), fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildForecastCard(EHThemeTokens tokens) {
    final forecast = widget.costService.forecast;
    if (forecast == null) return const SizedBox.shrink();

    final currency = forecast.currency;
    return Card(
      color: tokens.surfaceCard,
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
                Row(
                  children: [
                    Icon(Icons.trending_up, color: tokens.warning, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Monthly Cost Projection',
                      style: TextStyle(color: tokens.textPrimary, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: tokens.warningContainer,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'ESTIMATE',
                    style: TextStyle(color: tokens.warning, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
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
                    Text('Actual to Date', style: TextStyle(color: tokens.textSecondary, fontSize: 12)),
                    const SizedBox(height: 4),
                    Text(
                      '$currency ${forecast.actualCostToDate.toStringAsFixed(2)}',
                      style: TextStyle(color: tokens.textPrimary, fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Est. Remaining', style: TextStyle(color: tokens.textSecondary, fontSize: 12)),
                    const SizedBox(height: 4),
                    Text(
                      '$currency ${forecast.estimatedRemainingCost.toStringAsFixed(2)}',
                      style: TextStyle(color: tokens.textPrimary, fontSize: 16),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('Projected Total', style: TextStyle(color: tokens.textSecondary, fontSize: 12)),
                    const SizedBox(height: 4),
                    Text(
                      '$currency ${forecast.projectedTotalCost.toStringAsFixed(2)}',
                      style: TextStyle(color: tokens.warning, fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: forecast.confidenceScore,
              backgroundColor: tokens.isDark ? Colors.white10 : Colors.black12,
              color: tokens.warning,
              minHeight: 4,
            ),
            const SizedBox(height: 4),
            Text(
              'Confidence: ${(forecast.confidenceScore * 100).toInt()}% based on ${forecast.daysElapsed} days of data',
              style: TextStyle(color: tokens.textTertiary, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBudgetProgressCard(EHThemeTokens tokens) {
    final status = widget.costService.budgetStatus;
    if (status == null || !status.configured) {
      return Card(
        color: tokens.surfaceCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: tokens.borderSubtle),
        ),
        child: ListTile(
          leading: Icon(Icons.account_balance_wallet, color: tokens.success),
          title: Text(
            'Set Monthly Budget',
            style: TextStyle(color: tokens.textPrimary, fontWeight: FontWeight.bold),
          ),
          subtitle: Text(
            'Track spending and get projected overrun alerts',
            style: TextStyle(color: tokens.textSecondary, fontSize: 12),
          ),
          trailing: FilledButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => EnergyBudgetPage(homeId: widget.homeId, costService: widget.costService)),
              );
            },
            style: FilledButton.styleFrom(
              backgroundColor: tokens.bluePrimary,
              foregroundColor: tokens.buttonText,
            ),
            child: const Text('Configure'),
          ),
        ),
      );
    }

    final percent = (status.percentConsumed / 100).clamp(0.0, 1.0);
    final isExceeded = status.isProjectedToExceed;

    return Card(
      color: tokens.surfaceCard,
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
                Text(
                  'Monthly Budget Progress',
                  style: TextStyle(color: tokens.textPrimary, fontWeight: FontWeight.bold),
                ),
                if (isExceeded)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: tokens.errorContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Overrun: ${status.currency} ${status.projectedOverrun.toStringAsFixed(2)}',
                      style: TextStyle(color: tokens.error, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: percent,
              backgroundColor: tokens.isDark ? Colors.white10 : Colors.black12,
              color: isExceeded ? tokens.error : tokens.success,
              minHeight: 8,
              borderRadius: BorderRadius.circular(4),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${status.percentConsumed.toStringAsFixed(1)}% consumed',
                  style: TextStyle(color: tokens.textSecondary, fontSize: 12),
                ),
                Text(
                  'Budget: ${status.currency} ${status.budgetAmount.toStringAsFixed(2)}',
                  style: TextStyle(color: tokens.textPrimary, fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPeakBreakdownCard(EHThemeTokens tokens) {
    final cost = widget.costService.costSummary;
    if (cost == null) return const SizedBox.shrink();

    final peak = cost.peak;
    final offPeak = cost.offPeak;
    final standard = cost.standard;
    final currency = cost.currency;

    return Card(
      color: tokens.surfaceCard,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: tokens.borderSubtle),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Tariff Period Breakdown',
              style: TextStyle(color: tokens.textPrimary, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildBreakdownColumn('Off-Peak', offPeak, tokens.success, currency, tokens),
                _buildBreakdownColumn('Standard', standard, tokens.bluePrimary, currency, tokens),
                _buildBreakdownColumn('Peak', peak, tokens.error, currency, tokens),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBreakdownColumn(
    String title,
    CostBreakdownItem item,
    Color color,
    String currency,
    EHThemeTokens tokens,
  ) {
    return Column(
      children: [
        Text(title, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(
          '$currency ${item.cost.toStringAsFixed(2)}',
          style: TextStyle(color: tokens.textPrimary, fontSize: 15, fontWeight: FontWeight.bold),
        ),
        Text(
          '${item.kwh.toStringAsFixed(1)} kWh',
          style: TextStyle(color: tokens.textTertiary, fontSize: 11),
        ),
      ],
    );
  }

  Widget _buildCheapestWindowBanner(EHThemeTokens tokens) {
    final cheapest = widget.costService.cheapestPeriods;
    if (cheapest == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: tokens.successContainer,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: tokens.success.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.bolt, color: tokens.success, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Cheapest Upcoming Window',
                  style: TextStyle(color: tokens.success, fontWeight: FontWeight.bold, fontSize: 13),
                ),
                const SizedBox(height: 2),
                Text(
                  '${cheapest.currency} ${cheapest.cheapestWindow.avgPricePerKwh.toStringAsFixed(2)}/kWh (${cheapest.cheapestWindow.periodType}) • Save up to ${cheapest.potentialSavingsPercent.toInt()}%',
                  style: TextStyle(color: tokens.textPrimary, fontSize: 12),
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
            child: Text(
              'Optimize',
              style: TextStyle(color: tokens.bluePrimary, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCarbonFootprintCard(EHThemeTokens tokens) {
    final carbon = widget.costService.carbonFootprint;
    if (carbon == null) return const SizedBox.shrink();

    return Card(
      color: tokens.surfaceCard,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: tokens.borderSubtle),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Icon(Icons.eco, color: tokens.iconFgPlant, size: 30),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Estimated Carbon Footprint',
                    style: TextStyle(color: tokens.textPrimary, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${carbon.totalKgCO2.toStringAsFixed(2)} kg CO₂ (${carbon.carbonIntensityGPerKwh.toInt()} g/kWh)',
                    style: TextStyle(color: tokens.textSecondary, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
