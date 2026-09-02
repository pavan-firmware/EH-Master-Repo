import 'package:flutter/material.dart';
import '../../../core/models/energy_models.dart';
import '../../../core/services/energy_service.dart';
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
                      if (summary != null) _buildLiveGaugeCard(summary),
                      const SizedBox(height: 16),

                      // Period Selector
                      _buildPeriodSelector(),
                      const SizedBox(height: 16),

                      // Anomaly Alert Banner
                      if (events.isNotEmpty) _buildAlertsBanner(events),

                      // Consumption Trend Card
                      _buildTrendsCard(trends),
                      const SizedBox(height: 16),

                      // Top Consuming Devices
                      _buildTopConsumersCard(topDevices),
                    ],
                  ),
                ),
        );
      },
    );
  }

  Widget _buildPeriodSelector() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: EnergyPeriod.values.map((p) {
        final isSelected = _selectedPeriod == p;
        return ChoiceChip(
          label: Text(p.displayName),
          selected: isSelected,
          onSelected: (selected) {
            if (selected) {
              setState(() => _selectedPeriod = p);
              _loadAllData();
            }
          },
        );
      }).toList(),
    );
  }

  Widget _buildLiveGaugeCard(EnergyUsageSummary s) {
    final comp = s.comparison;

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
                    const Text('Total Current Load', style: TextStyle(color: Colors.grey, fontSize: 13)),
                    const SizedBox(height: 4),
                    Text(
                      '${s.currentPowerW.toStringAsFixed(0)} W',
                      style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.amber.withAlpha(40),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.bolt, color: Colors.amber, size: 20),
                      const SizedBox(width: 4),
                      Text(
                        '${s.devicesCount} devices active',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildStatItem('Total Energy', '${s.totalEnergyKwh.toStringAsFixed(2)} kWh'),
                _buildStatItem('Est. Cost', '${s.currency} \$${s.costEstimate?.toStringAsFixed(2) ?? "0.00"}'),
                _buildStatItem('Peak Demand', '${s.peakPowerW.toStringAsFixed(0)} W'),
              ],
            ),
            if (comp != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: comp.trendDirection == TrendDirection.up
                      ? Colors.red.withAlpha(20)
                      : (comp.trendDirection == TrendDirection.down ? Colors.green.withAlpha(20) : Colors.grey.withAlpha(20)),
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
                          ? Colors.red
                          : (comp.trendDirection == TrendDirection.down ? Colors.green : Colors.grey),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${comp.percentageChange >= 0 ? "+" : ""}${comp.percentageChange.toStringAsFixed(1)}% vs previous period',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: comp.trendDirection == TrendDirection.up
                            ? Colors.red
                            : (comp.trendDirection == TrendDirection.down ? Colors.green : Colors.black87),
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

  Widget _buildStatItem(String label, String value) {
    return Column(
      children: [
        Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }

  Widget _buildAlertsBanner(List<EnergyAnomalyEvent> events) {
    final latestEvent = events.first;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange.withAlpha(30),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.withAlpha(80)),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber, color: Colors.orange),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(latestEvent.eventType, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                Text(latestEvent.message, style: const TextStyle(fontSize: 12, color: Colors.black87)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrendsCard(List<EnergyTrendPoint> points) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Consumption Trends', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            if (points.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(24.0),
                  child: Text('No historical interval data available yet.', style: TextStyle(color: Colors.grey)),
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
                        Text('${p.energyKwh.toStringAsFixed(1)}k', style: const TextStyle(fontSize: 10, color: Colors.grey)),
                        const SizedBox(height: 4),
                        Container(
                          width: 24,
                          height: (p.energyKwh * 30).clamp(10, 80).toDouble(),
                          decoration: BoxDecoration(
                            color: Colors.blueAccent,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${p.timestamp.hour}:00',
                          style: const TextStyle(fontSize: 10, color: Colors.black87),
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

  Widget _buildTopConsumersCard(List<TopEnergyConsumer> consumers) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Top Consuming Devices', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            if (consumers.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text('No device consumption data yet.', style: TextStyle(color: Colors.grey)),
                ),
              )
            else
              ...consumers.map((c) {
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const CircleAvatar(
                    backgroundColor: Colors.blueGrey,
                    child: Icon(Icons.devices, color: Colors.white, size: 20),
                  ),
                  title: Text(c.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(
                    '${c.roomName ?? "Unassigned"} • ${c.currentPowerW.toStringAsFixed(0)} W',
                    style: const TextStyle(fontSize: 12),
                  ),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('${c.energyKwh.toStringAsFixed(2)} kWh', style: const TextStyle(fontWeight: FontWeight.bold)),
                      Text('${c.percentageOfTotal.toStringAsFixed(1)}%', style: const TextStyle(fontSize: 11, color: Colors.grey)),
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
