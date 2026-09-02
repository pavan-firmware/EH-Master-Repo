import 'package:flutter/material.dart';
import '../../../core/models/energy_models.dart';
import '../../../core/services/energy_service.dart';

/// EH Home — Device Live Telemetry & Energy Analytics Details (Phase 19)
class DeviceEnergyDetailsPage extends StatefulWidget {
  final EnergyService energyService;
  final String deviceId;
  final String deviceName;

  const DeviceEnergyDetailsPage({
    super.key,
    required this.energyService,
    required this.deviceId,
    required this.deviceName,
  });

  @override
  State<DeviceEnergyDetailsPage> createState() => _DeviceEnergyDetailsPageState();
}

class _DeviceEnergyDetailsPageState extends State<DeviceEnergyDetailsPage> {
  EnergyMeasurement? _latest;
  EnergyUsageSummary? _summary;
  bool _isLoading = true;
  String _selectedPeriod = 'today';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final latest = await widget.energyService.fetchDeviceLatest(widget.deviceId);
    final summary = await widget.energyService.fetchDeviceSummary(widget.deviceId, period: _selectedPeriod);
    if (mounted) {
      setState(() {
        _latest = latest;
        _summary = summary;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.deviceName),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: ListView(
                padding: const EdgeInsets.all(16.0),
                children: [
                  // Live Metering Card
                  _buildLiveMetricsCard(),
                  const SizedBox(height: 16),

                  // Period Selector
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildPeriodChip('today', 'Today'),
                      _buildPeriodChip('week', 'Week'),
                      _buildPeriodChip('month', 'Month'),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Aggregated Stats Card
                  if (_summary != null) _buildSummaryCard(_summary!),
                ],
              ),
            ),
    );
  }

  Widget _buildPeriodChip(String period, String label) {
    final isSelected = _selectedPeriod == period;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          setState(() => _selectedPeriod = period);
          _loadData();
        }
      },
    );
  }

  Widget _buildLiveMetricsCard() {
    final m = _latest;
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.bolt, color: Colors.amber, size: 28),
                const SizedBox(width: 8),
                const Text(
                  'Live Telemetry',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                if (m != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green.withAlpha(30),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text('ACTIVE', style: TextStyle(color: Colors.green, fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
              ],
            ),
            const Divider(height: 24),
            if (m == null)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16.0),
                child: Text('No live telemetry received yet for this device.', style: TextStyle(color: Colors.grey)),
              )
            else
              Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildMetricTile('Active Power', '${m.powerW.toStringAsFixed(1)} W', Icons.power),
                      _buildMetricTile('Voltage', '${m.voltageV.toStringAsFixed(1)} V', Icons.speed),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildMetricTile('Current', '${m.currentA.toStringAsFixed(2)} A', Icons.waves),
                      _buildMetricTile('Power Factor', m.powerFactor.toStringAsFixed(2), Icons.tune),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildMetricTile('Total Energy', '${m.totalEnergyKwh.toStringAsFixed(3)} kWh', Icons.electric_meter),
                      _buildMetricTile('Frequency', '${m.frequencyHz.toStringAsFixed(1)} Hz', Icons.graphic_eq),
                    ],
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricTile(String label, String value, IconData icon) {
    return Expanded(
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.blueGrey),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
              Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(EnergyUsageSummary s) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Period Consumption',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildSummaryStat('Total Energy', '${s.totalEnergyKwh.toStringAsFixed(2)} kWh'),
                _buildSummaryStat('Peak Power', '${s.peakPowerW.toStringAsFixed(0)} W'),
                _buildSummaryStat('Avg Power', '${s.avgPowerW.toStringAsFixed(0)} W'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryStat(String label, String value) {
    return Column(
      children: [
        Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blueAccent)),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }
}
