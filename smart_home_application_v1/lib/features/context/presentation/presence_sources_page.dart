import 'package:flutter/material.dart';
import '../../../core/models/context_presence_models.dart';
import '../../../core/services/context_presence_service.dart';

class PresenceSourcesPage extends StatefulWidget {
  final String homeId;
  final ContextPresenceService service;

  const PresenceSourcesPage({
    super.key,
    required this.homeId,
    required this.service,
  });

  @override
  State<PresenceSourcesPage> createState() => _PresenceSourcesPageState();
}

class _PresenceSourcesPageState extends State<PresenceSourcesPage> {
  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    await widget.service.fetchSignals(widget.homeId);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.service,
      builder: (context, _) {
        final signals = widget.service.recentSignals;
        final isLoading = widget.service.isLoading;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Presence Signal Sources'),
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: _refresh,
              ),
            ],
          ),
          body: RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // 1. Source Confidence Weighting Matrix
                _buildSourceWeightingCard(),
                const SizedBox(height: 20),

                // 2. TTL Expiration Policy
                _buildTtlPolicyCard(),
                const SizedBox(height: 20),

                // 3. Raw Signal Ingestion Stream
                const Text(
                  'Recent Ingested Signals',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                if (isLoading && signals.isEmpty)
                  const Center(child: CircularProgressIndicator())
                else
                  _buildSignalsList(signals),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSourceWeightingCard() {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.tune, color: Colors.indigo),
                SizedBox(width: 8),
                Text(
                  'Multi-Source Confidence Matrix',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildSourceWeightRow('Manual User Action', '100% (1.0)', Colors.green),
            _buildSourceWeightRow('Mobile App Geofence', '90% (0.90)', Colors.blue),
            _buildSourceWeightRow('Local LAN / Wi-Fi', '80% (0.80)', Colors.teal),
            _buildSourceWeightRow('BLE Beacon Telemetry', '75% (0.75)', Colors.cyan),
            _buildSourceWeightRow('PIR / Presence Sensor', '70% (0.70)', Colors.orange),
            _buildSourceWeightRow('Connected Device Activity', '65% (0.65)', Colors.deepOrange),
          ],
        ),
      ),
    );
  }

  Widget _buildSourceWeightRow(String label, String weight, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 13)),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              weight,
              style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTtlPolicyCard() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(Icons.timer_outlined, color: Colors.purple, size: 28),
            const SizedBox(width: 16),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Signal TTL Expiration (30 Min)',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Stale signals are expired after 30 minutes to prevent ghost occupancy. Empty evidence resolves safely to UNKNOWN without assuming AWAY.',
                    style: TextStyle(fontSize: 12, color: Colors.black87),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSignalsList(List<PresenceSignalModel> signals) {
    if (signals.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('No signals recorded yet.'),
        ),
      );
    }

    return Column(
      children: signals.map((s) {
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: Icon(
              s.state == PresenceState.home ? Icons.sensors : Icons.sensors_off,
              color: s.state == PresenceState.home ? Colors.green : Colors.blueGrey,
            ),
            title: Text('${s.source.toApiValue().toUpperCase()} → ${s.state.toApiValue()}'),
            subtitle: Text('User: ${s.userId}\nConfidence: ${(s.confidence * 100).toStringAsFixed(0)}%'),
            isThreeLine: true,
            trailing: Text(
              '${s.observedAt.hour.toString().padLeft(2, '0')}:${s.observedAt.minute.toString().padLeft(2, '0')}',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ),
        );
      }).toList(),
    );
  }
}
