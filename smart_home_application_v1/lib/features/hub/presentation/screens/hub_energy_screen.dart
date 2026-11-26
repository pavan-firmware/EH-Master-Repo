import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/charts/eh_chart_widgets.dart';
import '../../data/hub_repository.dart';
import '../../domain/models/hub_models.dart';
import 'hub_ui_helpers.dart';

class HubEnergyScreen extends StatefulWidget {
  const HubEnergyScreen({
    super.key,
    required this.repository,
    required this.hubState,
  });

  final HubRepository repository;
  final HubState hubState;

  @override
  State<HubEnergyScreen> createState() => _HubEnergyScreenState();
}

class _HubEnergyScreenState extends State<HubEnergyScreen> {
  String _period = 'today';
  Map<String, dynamic>? _summary;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final res = await widget.repository.getHomeEnergySummary(
      hubHostname: widget.hubState.hostname,
      period: _period,
    );
    if (!mounted) return;
    setState(() {
      _summary = res;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.ehColors;
    final sampleCount = (_summary?['sampleCount'] as num?)?.toInt() ??
        (_summary?['samplesCount'] as num?)?.toInt() ?? 0;
    final hasRealData = _summary != null && (_summary?['hasData'] == true || sampleCount > 0);
    final rawTrends = _summary?['trends'] as List<dynamic>? ?? [];
    final topDevices = _summary?['topDevices'] as List<dynamic>? ?? [];

    return Scaffold(
      backgroundColor: tokens.bgApp,
      appBar: AppBar(
        backgroundColor: tokens.bgApp,
        elevation: 0,
        title: Text(
          'Local 365-Day Energy',
          style: TextStyle(color: tokens.textPrimary, fontWeight: FontWeight.w800, fontSize: 18),
        ),
        actions: [
          IconButton(icon: Icon(Icons.refresh_rounded, color: tokens.headerAction), onPressed: _load),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator.adaptive())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'today', label: Text('Today')),
                    ButtonSegment(value: 'week', label: Text('7D')),
                    ButtonSegment(value: 'month', label: Text('30D')),
                    ButtonSegment(value: 'year', label: Text('365D')),
                  ],
                  selected: {_period},
                  onSelectionChanged: (s) {
                    _period = s.first;
                    _load();
                  },
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    HubUiHelpers.buildMetricTile(tokens, 'Live Power', '${_summary?['currentPowerW'] ?? 0} W', Icons.speed_rounded),
                    const SizedBox(width: 10),
                    HubUiHelpers.buildMetricTile(tokens, 'Total Energy', '${_summary?['totalEnergyKwh'] ?? 0} kWh', Icons.bolt_rounded),
                    const SizedBox(width: 10),
                    HubUiHelpers.buildMetricTile(tokens, 'Peak Load', '${_summary?['peakPowerW'] ?? 0} W', Icons.trending_up_rounded),
                  ],
                ),
                const SizedBox(height: 18),
                if (!hasRealData)
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: tokens.surfaceCard,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: tokens.borderSubtle),
                    ),
                    child: Column(
                      children: [
                        Icon(Icons.bolt_outlined, size: 36, color: tokens.textTertiary),
                        const SizedBox(height: 8),
                        Text('No Real Energy Samples Yet', style: TextStyle(fontWeight: FontWeight.w800, color: tokens.textPrimary)),
                        const SizedBox(height: 4),
                        Text(
                          'Requires an adopted EH Energy-Monitoring device pushing BL0942 telemetry to this Hub.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 12, color: tokens.textSecondary),
                        ),
                      ],
                    ),
                  )
                else ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: tokens.surfaceCard,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: tokens.borderSubtle),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Power Load Trend ($sampleCount samples)', style: TextStyle(fontWeight: FontWeight.w800, color: tokens.textPrimary)),
                        const SizedBox(height: 12),
                        EHEnergyWaveformChart(
                          points: [
                            for (int i = 0; i < rawTrends.length; i++)
                              EHChartDataPoint(
                                x: i.toDouble(),
                                y: ((rawTrends[i] as Map)['powerW'] as num?)?.toDouble() ?? 0.0,
                                label: '$i',
                              ),
                            if (rawTrends.isEmpty)
                              EHChartDataPoint(
                                x: 0,
                                y: (_summary?['currentPowerW'] as num?)?.toDouble() ?? 0.0,
                                label: 'Now',
                              ),
                          ],
                          height: 140,
                          accentColor: const Color(0xFFF59E0B),
                          unit: 'W',
                        ),
                      ],
                    ),
                  ),
                  if (topDevices.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text('Top Consumers', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: tokens.textPrimary)),
                    const SizedBox(height: 8),
                    for (final td in topDevices)
                      Card(
                        color: tokens.surfaceCard,
                        child: ListTile(
                          title: Text((td as Map)['name']?.toString() ?? td['deviceId']?.toString() ?? 'Device'),
                          subtitle: Text('${td['energyKwh'] ?? 0} kWh'),
                          trailing: Text('${td['percentage'] ?? 0}%', style: TextStyle(fontWeight: FontWeight.w800, color: tokens.bluePrimary)),
                        ),
                      ),
                  ],
                ],
              ],
            ),
    );
  }
}
