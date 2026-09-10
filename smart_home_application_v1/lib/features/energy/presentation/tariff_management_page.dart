import 'package:flutter/material.dart';
import '../../../core/models/energy_cost_models.dart';
import '../../../core/services/energy_cost_service.dart';
import '../../../core/theme/app_theme.dart';
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
    final tokens = context.ehColors;
    final tariffs = widget.costService.tariffs;

    return Scaffold(
      backgroundColor: tokens.bgApp,
      appBar: AppBar(
        title: Text(
          'Electricity Tariffs',
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
            key: const Key('btn_add_tariff'),
            icon: Icon(Icons.add, color: tokens.headerAction),
            tooltip: 'Add Tariff',
            onPressed: () => _openEditor(null),
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: tokens.bluePrimary))
          : tariffs.isEmpty
              ? _buildEmptyState(tokens)
              : RefreshIndicator(
                  color: tokens.bluePrimary,
                  backgroundColor: tokens.surfaceElevated,
                  onRefresh: _loadTariffs,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16.0),
                    itemCount: tariffs.length,
                    itemBuilder: (context, index) {
                      final t = tariffs[index];
                      return _buildTariffCard(t, tokens);
                    },
                  ),
                ),
    );
  }

  Widget _buildEmptyState(EHThemeTokens tokens) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.price_change_outlined, size: 64, color: tokens.textTertiary),
            const SizedBox(height: 16),
            Text(
              'No Tariffs Configured',
              style: TextStyle(color: tokens.textPrimary, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Configure flat or time-of-use tariffs to calculate energy cost',
              textAlign: TextAlign.center,
              style: TextStyle(color: tokens.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: () => _openEditor(null),
              icon: const Icon(Icons.add),
              label: const Text('Add Tariff'),
              style: FilledButton.styleFrom(
                backgroundColor: tokens.bluePrimary,
                foregroundColor: tokens.buttonText,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTariffCard(ElectricityTariffModel tariff, EHThemeTokens tokens) {
    final isTou = tariff.tariffType == TariffType.timeOfUse;

    return Card(
      color: tokens.surfaceCard,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: tariff.isActive ? tokens.gold.withValues(alpha: 0.6) : tokens.borderSubtle,
          width: 1,
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
                    style: TextStyle(
                      color: tokens.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: tariff.isActive
                        ? tokens.successContainer
                        : (tokens.isDark ? Colors.white10 : Colors.black12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    tariff.isActive ? 'ACTIVE' : 'INACTIVE',
                    style: TextStyle(
                      color: tariff.isActive ? tokens.success : tokens.textTertiary,
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
                  style: TextStyle(
                    color: tokens.isDark ? tokens.goldBright : tokens.bluePrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(' • ', style: TextStyle(color: tokens.textTertiary)),
                Text(
                  'Currency: ${tariff.currency}',
                  style: TextStyle(color: tokens.textSecondary, fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (!isTou && tariff.flatRatePerKwh != null)
              Text(
                '${tariff.currency} ${tariff.flatRatePerKwh!.toStringAsFixed(3)} / kWh',
                style: TextStyle(
                  color: tokens.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            if (isTou)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${tariff.periods.length} TOU Rate Periods:',
                    style: TextStyle(color: tokens.textSecondary, fontSize: 12),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: tariff.periods.map((p) {
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: tokens.bgApp,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: tokens.borderControl),
                        ),
                        child: Text(
                          '${p.periodType.displayName}: ${tariff.currency} ${p.pricePerKwh.toStringAsFixed(2)} (${p.startTime}-${p.endTime})',
                          style: TextStyle(color: tokens.textSecondary, fontSize: 11),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            Divider(color: tokens.borderSubtle, height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  icon: Icon(Icons.edit, size: 16, color: tokens.bluePrimary),
                  label: Text('Edit', style: TextStyle(color: tokens.bluePrimary)),
                  onPressed: () => _openEditor(tariff),
                ),
                TextButton.icon(
                  icon: Icon(Icons.delete_outline, size: 16, color: tokens.error),
                  label: Text('Delete', style: TextStyle(color: tokens.error)),
                  onPressed: () => _confirmDelete(tariff, tokens),
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

  void _confirmDelete(ElectricityTariffModel tariff, EHThemeTokens tokens) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: tokens.surfaceElevated,
        title: Text('Delete Tariff', style: TextStyle(color: tokens.textPrimary)),
        content: Text(
          'Are you sure you want to delete "${tariff.name}"?',
          style: TextStyle(color: tokens.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: TextStyle(color: tokens.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await widget.costService.deleteTariff(widget.homeId, tariff.id);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: tokens.error,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
