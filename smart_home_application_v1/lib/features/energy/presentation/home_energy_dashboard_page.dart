import 'package:flutter/material.dart';
import '../../../core/models/energy_models.dart';
import '../../../core/services/energy_service.dart';
import '../../../core/theme/app_theme.dart';
import 'device_energy_details_page.dart';
import 'energy_threshold_dialog.dart';

/// EH Home — Whole-Home Energy Intelligence & Telemetry Dashboard (Phase 19)
class HomeEnergyDashboardPage extends StatefulWidget {
  final EnergyService energyService;
  final String homeId;

  const HomeEnergyDashboardPage({
    super.key,
    required this.energyService,
    required this.homeId,
  });

  @override
  State<HomeEnergyDashboardPage> createState() => _HomeEnergyDashboardPageState();
}

class _HomeEnergyDashboardPageState extends State<HomeEnergyDashboardPage> {
  EnergyPeriod _selectedPeriod = EnergyPeriod.today;

  @override
  void initState() {
    super.initState();
    _loadAllData();
  }

  Future<void> _loadAllData() async {
    final p = _selectedPeriod.toApiString();
    await widget.energyService.fetchHomeSummary(widget.homeId, period: p);
    await widget.energyService.fetchHomeTrends(widget.homeId, period: p);
    await widget.energyService.fetchTopConsumers(widget.homeId, period: p);
    await widget.energyService.fetchThresholds(widget.homeId);
    await widget.energyService.fetchEvents(widget.homeId);
  }

  void _openThresholdDialog() async {
    final thresholds = widget.energyService.cachedThresholds;
    final currentConfig = thresholds.isNotEmpty ? thresholds.first : null;

    final updated = await showDialog<bool>(
      context: context,
      builder: (context) => EnergyThresholdDialog(
        energyService: widget.energyService,
        homeId: widget.homeId,
        initialConfig: currentConfig,
      ),
    );

    if (updated == true) {
      _loadAllData();
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.ehColors;

    return AnimatedBuilder(
      animation: widget.energyService,
      builder: (context, _) {
        final summary = widget.energyService.cachedHomeSummary;
        final trends = widget.energyService.cachedTrends;
        final topDevices = widget.energyService.cachedTopDevices;
        final events = widget.energyService.cachedEvents;
        final isLoading = widget.energyService.isLoading;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Energy Intelligence'),
            actions: [
              IconButton(
                icon: const Icon(Icons.tune),
                tooltip: 'Energy Budget & Thresholds',
                onPressed: _openThresholdDialog,
              ),
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: _loadAllData,
              ),
            ],
          ),
          body: isLoading && summary == null
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: _loadAllData,
                  child: ListView(
                    padding: const EdgeInsets.all(16.0),
                    children: [
                      // Active Power & Consumption Card
                      if (summary != null) _buildLiveGaugeCard(summary, tokens),
                      const SizedBox(height: 16),

                      // Period Selector
                      _buildPeriodSelector(tokens),
                      const SizedBox(height: 16),

                      // Anomaly Alert Banner
                      if (events.isNotEmpty) _buildAlertsBanner(events, tokens),

                      // Consumption Trend Card
                      _buildTrendsCard(trends, tokens),
                      const SizedBox(height: 16),

                      // Top Consuming Devices
                      _buildTopConsumersCard(topDevices, tokens),
                    ],
                  ),
                ),
        );
      },
    );
  }

  Widget _buildPeriodSelector(EHThemeTokens tokens) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: EnergyPeriod.values.map((p) {
          final isSelected = _selectedPeriod == p;
          return Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: ChoiceChip(
              label: Text(
                p.displayName,
                style: TextStyle(
                  color: isSelected
                      ? (tokens.isDark ? tokens.buttonText : tokens.blueSelectedText)
                      : tokens.textSecondary,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                  fontSize: 13,
                ),
              ),
              selected: isSelected,
              selectedColor: tokens.isDark ? tokens.blueSelectedBg : tokens.blueSelectedBg,
              backgroundColor: tokens.isDark ? tokens.surfaceElevated : tokens.surfaceCard,
              side: BorderSide(
                color: isSelected ? tokens.bluePrimary : tokens.borderControl,
                width: isSelected ? 1.4 : 1.0,
              ),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              showCheckmark: isSelected,
              checkmarkColor: isSelected
                  ? (tokens.isDark ? tokens.buttonText : tokens.blueSelectedText)
                  : null,
              onSelected: (selected) {
                if (selected) {
                  setState(() => _selectedPeriod = p);
                  _loadAllData();
                }
              },
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildLiveGaugeCard(EnergyUsageSummary s, EHThemeTokens tokens) {
    final comp = s.comparison;

    return Card(
      elevation: 2,
      color: tokens.surfaceCard,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: tokens.borderControl),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Total Current Load', style: TextStyle(color: tokens.textSecondary, fontSize: 13)),
                    const SizedBox(height: 4),
                    Text(
                      '${s.currentPowerW.toStringAsFixed(0)} W',
                      style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold, color: tokens.textPrimary),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: tokens.warningContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.bolt, color: tokens.warning, size: 20),
                      const SizedBox(width: 4),
                      Text(
                        '${s.devicesCount} devices active',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: tokens.warning),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            Divider(height: 32, color: tokens.borderSubtle),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildStatItem('Total Energy', '${s.totalEnergyKwh.toStringAsFixed(2)} kWh', tokens),
                _buildStatItem('Est. Cost', '${s.currency} \$${s.costEstimate?.toStringAsFixed(2) ?? "0.00"}', tokens),
                _buildStatItem('Peak Demand', '${s.peakPowerW.toStringAsFixed(0)} W', tokens),
              ],
            ),
            if (comp != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: comp.trendDirection == TrendDirection.up
                      ? tokens.errorContainer
                      : (comp.trendDirection == TrendDirection.down ? tokens.successContainer : tokens.surfaceElevated),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      comp.trendDirection == TrendDirection.up
                          ? Icons.trending_up
                          : (comp.trendDirection == TrendDirection.down ? Icons.trending_down : Icons.trending_flat),
                      size: 18,
                      color: comp.trendDirection == TrendDirection.up
                          ? tokens.error
                          : (comp.trendDirection == TrendDirection.down ? tokens.success : tokens.textSecondary),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${comp.percentageChange >= 0 ? "+" : ""}${comp.percentageChange.toStringAsFixed(1)}% vs previous period',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: comp.trendDirection == TrendDirection.up
                            ? tokens.error
                            : (comp.trendDirection == TrendDirection.down ? tokens.success : tokens.textPrimary),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, EHThemeTokens tokens) {
    return Column(
      children: [
        Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: tokens.textPrimary)),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(fontSize: 12, color: tokens.textSecondary)),
      ],
    );
  }

  Widget _buildAlertsBanner(List<EnergyAnomalyEvent> events, EHThemeTokens tokens) {
    final latestEvent = events.first;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: tokens.warningContainer,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: tokens.warning.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_amber, color: tokens.warning),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(latestEvent.eventType, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: tokens.warning)),
                Text(latestEvent.message, style: TextStyle(fontSize: 12, color: tokens.textPrimary)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrendsCard(List<EnergyTrendPoint> points, EHThemeTokens tokens) {
    return Card(
      elevation: 2,
      color: tokens.surfaceCard,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: tokens.borderControl),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Consumption Trends', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: tokens.textPrimary)),
            const SizedBox(height: 12),
            if (points.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Text('No historical interval data available yet.', style: TextStyle(color: tokens.textSecondary)),
                ),
              )
            else
              SizedBox(
                height: 120,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: points.length,
                  separatorBuilder: (context, index) => const SizedBox(width: 12),
                  itemBuilder: (context, index) {
                    final p = points[index];
                    return Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text('${p.energyKwh.toStringAsFixed(1)}k', style: TextStyle(fontSize: 10, color: tokens.textSecondary)),
                        const SizedBox(height: 4),
                        Container(
                          width: 24,
                          height: (p.energyKwh * 30).clamp(10, 80).toDouble(),
                          decoration: BoxDecoration(
                            color: tokens.bluePrimary,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${p.timestamp.hour}:00',
                          style: TextStyle(fontSize: 10, color: tokens.textSecondary),
                        ),
                      ],
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopConsumersCard(List<TopEnergyConsumer> consumers, EHThemeTokens tokens) {
    return Card(
      elevation: 2,
      color: tokens.surfaceCard,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: tokens.borderControl),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Top Consuming Devices', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: tokens.textPrimary)),
            const SizedBox(height: 12),
            if (consumers.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text('No device consumption data yet.', style: TextStyle(color: tokens.textSecondary)),
                ),
              )
            else
              ...consumers.map((c) {
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    backgroundColor: tokens.iconBgBlue,
                    child: Icon(Icons.devices, color: tokens.iconFgBlue, size: 20),
                  ),
                  title: Text(c.name, style: TextStyle(fontWeight: FontWeight.bold, color: tokens.textPrimary)),
                  subtitle: Text(
                    '${c.roomName ?? "Unassigned"} • ${c.currentPowerW.toStringAsFixed(0)} W',
                    style: TextStyle(fontSize: 12, color: tokens.textSecondary),
                  ),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('${c.energyKwh.toStringAsFixed(2)} kWh', style: TextStyle(fontWeight: FontWeight.bold, color: tokens.textPrimary)),
                      Text('${c.percentageOfTotal.toStringAsFixed(1)}%', style: TextStyle(fontSize: 11, color: tokens.textSecondary)),
                    ],
                  ),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => DeviceEnergyDetailsPage(
                          energyService: widget.energyService,
                          deviceId: c.id,
                          deviceName: c.name,
                        ),
                      ),
                    );
                  },
                );
              }),
          ],
        ),
      ),
    );
  }
}
