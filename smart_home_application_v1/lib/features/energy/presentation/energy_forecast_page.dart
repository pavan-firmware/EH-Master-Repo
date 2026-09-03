import 'package:flutter/material.dart';
import '../../../core/models/energy_predictive_models.dart';
import '../../../core/services/energy_predictive_service.dart';

class EnergyForecastPage extends StatefulWidget {
  final String homeId;
  final EnergyPredictiveService service;

  const EnergyForecastPage({
    super.key,
    required this.homeId,
    required this.service,
  });

  @override
  State<EnergyForecastPage> createState() => _EnergyForecastPageState();
}

class _EnergyForecastPageState extends State<EnergyForecastPage> {
  ForecastHorizon _selectedHorizon = ForecastHorizon.next24Hours;

  @override
  void initState() {
    super.initState();
    _loadForecast();
  }

  void _loadForecast() {
    widget.service.fetchForecast(widget.homeId, horizon: _selectedHorizon);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.service,
      builder: (context, _) {
        final fc = widget.service.currentForecast;
        final isLoading = widget.service.isLoading;
        final error = widget.service.errorMessage;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Energy Forecast & Predictions'),
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: _loadForecast,
                tooltip: 'Refresh Forecast',
              ),
            ],
          ),
          body: isLoading && fc == null
              ? const Center(child: CircularProgressIndicator())
              : error != null && fc == null
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.error_outline, size: 48, color: Colors.red),
                          const SizedBox(height: 12),
                          Text(error, textAlign: TextAlign.center),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: _loadForecast,
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: () async => _loadForecast(),
                      child: ListView(
                        padding: const EdgeInsets.all(16.0),
                        children: [
                          _buildHorizonSelector(),
                          const SizedBox(height: 16),
                          if (fc != null) ...[
                            _buildHeroForecastCard(fc),
                            const SizedBox(height: 16),
                            _buildConfidenceCard(fc),
                            const SizedBox(height: 16),
                            _buildPointsList(fc),
                          ] else
                            const Center(child: Text('No forecast data available.')),
                        ],
                      ),
                    ),
        );
      },
    );
  }

  Widget _buildHorizonSelector() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _buildHorizonChip('Next 1 Hour', ForecastHorizon.nextHour),
          const SizedBox(width: 8),
          _buildHorizonChip('Next 24 Hours', ForecastHorizon.next24Hours),
          const SizedBox(width: 8),
          _buildHorizonChip('Next 7 Days', ForecastHorizon.next7Days),
          const SizedBox(width: 8),
          _buildHorizonChip('Current Month', ForecastHorizon.currentMonth),
        ],
      ),
    );
  }

  Widget _buildHorizonChip(String label, ForecastHorizon horizon) {
    final isSelected = _selectedHorizon == horizon;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          setState(() {
            _selectedHorizon = horizon;
          });
          _loadForecast();
        }
      },
    );
  }

  Widget _buildHeroForecastCard(EnergyForecast fc) {
    final theme = Theme.of(context);
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.auto_graph, color: Colors.blueAccent),
                    const SizedBox(width: 8),
                    Text('Predicted Consumption', style: theme.textTheme.titleMedium),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.amber),
                  ),
                  child: const Text(
                    'ESTIMATE',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.amber),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Energy', style: theme.textTheme.bodySmall),
                      const SizedBox(height: 4),
                      Text(
                        '${fc.predictedKwh.toStringAsFixed(2)} kWh',
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.blueAccent),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Projected Cost', style: theme.textTheme.bodySmall),
                      const SizedBox(height: 4),
                      Text(
                        '${fc.currency} ${fc.predictedCost.toStringAsFixed(2)}',
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.green),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConfidenceCard(EnergyForecast fc) {
    final pct = (fc.confidenceScore * 100).toInt();
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Prediction Confidence', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(
                    'Coverage: ${fc.dataCoverage} • Methodology: ${fc.methodology.replaceAll('_', ' ')}',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: fc.confidenceScore,
                    backgroundColor: Colors.grey[200],
                    valueColor: AlwaysStoppedAnimation<Color>(
                      pct > 75 ? Colors.green : (pct > 50 ? Colors.orange : Colors.red),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Text(
              '$pct%',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPointsList(EnergyForecast fc) {
    if (fc.points.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Timeline Breakdown (Predicted Points)',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        ...fc.points.take(24).map((pt) {
          final timeStr = '${pt.timestamp.hour.toString().padLeft(2, '0')}:${pt.timestamp.minute.toString().padLeft(2, '0')}';
          return ListTile(
            dense: true,
            leading: const Icon(Icons.schedule, size: 20, color: Colors.grey),
            title: Text('$timeStr • ${pt.predictedPowerW.toStringAsFixed(0)} W'),
            subtitle: Text('${pt.predictedEnergyWh.toStringAsFixed(1)} Wh'),
            trailing: Text(
              '${fc.currency} ${pt.predictedCost.toStringAsFixed(3)}',
              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green),
            ),
          );
        }),
      ],
    );
  }
}
