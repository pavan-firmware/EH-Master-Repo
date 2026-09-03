import 'package:flutter/material.dart';
import '../../../core/models/energy_cost_models.dart';
import '../../../core/services/energy_cost_service.dart';
import 'tariff_editor_page.dart';

/// Tariff Management Page — View, activate, edit and delete electricity tariffs
class TariffManagementPage extends StatefulWidget {
  final String homeId;
  final EnergyCostService costService;

  const TariffManagementPage({
    super.key,
    required this.homeId,
    required this.costService,
  });

  @override
  State<TariffManagementPage> createState() => _TariffManagementPageState();
}

class _TariffManagementPageState extends State<TariffManagementPage> {
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTariffs();
  }

  Future<void> _loadTariffs() async {
    setState(() => _isLoading = true);
    await widget.costService.fetchTariffs(widget.homeId);
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tariffs = widget.costService.tariffs;

    return Scaffold(
      backgroundColor: const Color(0xFF121418),
      appBar: AppBar(
        title: const Text('Electricity Tariffs', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF1E222B),
        elevation: 0,
        actions: [
          IconButton(
            key: const Key('btn_add_tariff'),
            icon: const Icon(Icons.add),
            tooltip: 'Add Tariff',
            onPressed: () => _openEditor(null),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.amberAccent))
          : tariffs.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                  onRefresh: _loadTariffs,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16.0),
                    itemCount: tariffs.length,
                    itemBuilder: (context, index) {
                      final t = tariffs[index];
                      return _buildTariffCard(t);
                    },
                  ),
                ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.price_change_outlined, size: 64, color: Colors.white24),
          const SizedBox(height: 16),
          const Text('No Tariffs Configured', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text('Configure flat or time-of-use tariffs to calculate energy cost', style: TextStyle(color: Colors.white54, fontSize: 13)),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: () => _openEditor(null),
            icon: const Icon(Icons.add),
            label: const Text('Add Tariff'),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.amberAccent, foregroundColor: Colors.black),
          ),
        ],
      ),
    );
  }

  Widget _buildTariffCard(ElectricityTariffModel tariff) {
    final isTou = tariff.tariffType == TariffType.timeOfUse;

    return Card(
      color: const Color(0xFF1E222B),
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: tariff.isActive ? Colors.amberAccent.withValues(alpha: 0.4) : Colors.transparent,
        ),
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
                    tariff.name,
                    style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: tariff.isActive ? Colors.greenAccent.withValues(alpha: 0.2) : Colors.white10,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    tariff.isActive ? 'ACTIVE' : 'INACTIVE',
                    style: TextStyle(
                      color: tariff.isActive ? Colors.greenAccent : Colors.white38,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Text(
                  tariff.tariffType.displayName,
                  style: const TextStyle(color: Colors.amberAccent, fontSize: 12, fontWeight: FontWeight.w600),
                ),
                const Text(' • ', style: TextStyle(color: Colors.white38)),
                Text(
                  'Currency: ${tariff.currency}',
                  style: const TextStyle(color: Colors.white60, fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (!isTou && tariff.flatRatePerKwh != null)
              Text(
                '${tariff.currency} ${tariff.flatRatePerKwh!.toStringAsFixed(3)} / kWh',
                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
            if (isTou)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${tariff.periods.length} TOU Rate Periods:', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: tariff.periods.map((p) {
                      return Chip(
                        backgroundColor: const Color(0xFF121418),
                        label: Text(
                          '${p.periodType.displayName}: ${tariff.currency} ${p.pricePerKwh.toStringAsFixed(2)} (${p.startTime}-${p.endTime})',
                          style: const TextStyle(color: Colors.white70, fontSize: 11),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            const Divider(color: Colors.white10, height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  icon: const Icon(Icons.edit, size: 16, color: Colors.blueAccent),
                  label: const Text('Edit', style: TextStyle(color: Colors.blueAccent)),
                  onPressed: () => _openEditor(tariff),
                ),
                TextButton.icon(
                  icon: const Icon(Icons.delete_outline, size: 16, color: Colors.redAccent),
                  label: const Text('Delete', style: TextStyle(color: Colors.redAccent)),
                  onPressed: () => _confirmDelete(tariff),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _openEditor(ElectricityTariffModel? tariff) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TariffEditorPage(
          homeId: widget.homeId,
          tariff: tariff,
          costService: widget.costService,
        ),
      ),
    );
    if (result == true) {
      _loadTariffs();
    }
  }

  void _confirmDelete(ElectricityTariffModel tariff) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E222B),
        title: const Text('Delete Tariff', style: TextStyle(color: Colors.white)),
        content: Text('Are you sure you want to delete "${tariff.name}"?', style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await widget.costService.deleteTariff(widget.homeId, tariff.id);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
