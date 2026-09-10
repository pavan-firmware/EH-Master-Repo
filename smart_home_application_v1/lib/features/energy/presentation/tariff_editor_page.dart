import 'package:flutter/material.dart';
import '../../../core/models/energy_cost_models.dart';
import '../../../core/services/energy_cost_service.dart';
import '../../../core/theme/app_theme.dart';

/// Interactive Tariff Editor Page with TOU Period Builder
class TariffEditorPage extends StatefulWidget {
  final String homeId;
  final ElectricityTariffModel? tariff;
  final EnergyCostService costService;

  const TariffEditorPage({
    super.key,
    required this.homeId,
    this.tariff,
    required this.costService,
  });

  @override
  State<TariffEditorPage> createState() => _TariffEditorPageState();
}

class _TariffEditorPageState extends State<TariffEditorPage> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameCtrl;
  late TextEditingController _currencyCtrl;
  late TextEditingController _flatRateCtrl;
  late TextEditingController _fixedDailyChargeCtrl;
  late TextEditingController _carbonIntensityCtrl;

  late TariffType _selectedType;
  late bool _isActive;
  late List<TariffPeriodModel> _periods;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final t = widget.tariff;
    _nameCtrl = TextEditingController(text: t?.name ?? '');
    _currencyCtrl = TextEditingController(text: t?.currency ?? 'USD');
    _flatRateCtrl = TextEditingController(text: t?.flatRatePerKwh?.toString() ?? '0.15');
    _fixedDailyChargeCtrl = TextEditingController(text: t?.fixedDailyCharge.toString() ?? '0.0');
    _carbonIntensityCtrl = TextEditingController(text: t?.carbonIntensityGPerKwh?.toString() ?? '420.0');

    _selectedType = t?.tariffType ?? TariffType.flat;
    _isActive = t?.isActive ?? true;
    _periods = t?.periods.map((p) => p.copyWith()).toList() ?? [];
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _currencyCtrl.dispose();
    _flatRateCtrl.dispose();
    _fixedDailyChargeCtrl.dispose();
    _carbonIntensityCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.ehColors;
    final isEditing = widget.tariff != null;

    return Scaffold(
      backgroundColor: tokens.bgApp,
      appBar: AppBar(
        title: Text(
          isEditing ? 'Edit Tariff' : 'New Electricity Tariff',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: tokens.textPrimary,
          ),
        ),
        backgroundColor: tokens.bgApp,
        elevation: 0,
        iconTheme: IconThemeData(color: tokens.headerAction),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildGeneralSection(tokens),
              const SizedBox(height: 16),
              if (_selectedType == TariffType.flat) _buildFlatRateSection(tokens),
              if (_selectedType == TariffType.timeOfUse) _buildTouPeriodsSection(tokens),
              const SizedBox(height: 16),
              _buildCarbonSection(tokens),
              const SizedBox(height: 24),
              FilledButton(
                key: const Key('btn_save_tariff'),
                onPressed: _isSaving ? null : _saveTariff,
                style: FilledButton.styleFrom(
                  backgroundColor: tokens.bluePrimary,
                  foregroundColor: tokens.buttonText,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _isSaving
                    ? SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: tokens.buttonText),
                      )
                    : Text(
                        isEditing ? 'Save Changes' : 'Create Tariff',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGeneralSection(EHThemeTokens tokens) {
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
              'Tariff Configuration',
              style: TextStyle(color: tokens.textPrimary, fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 16),
            TextFormField(
              key: const Key('field_tariff_name'),
              controller: _nameCtrl,
              style: TextStyle(color: tokens.textPrimary),
              decoration: InputDecoration(
                labelText: 'Tariff Plan Name',
                labelStyle: TextStyle(color: tokens.textSecondary),
                filled: true,
                fillColor: tokens.bgApp,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: tokens.borderControl),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: tokens.borderControl),
                ),
              ),
              validator: (val) => val == null || val.trim().isEmpty ? 'Name is required' : null,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<TariffType>(
              key: const Key('dropdown_tariff_type'),
              initialValue: _selectedType,
              dropdownColor: tokens.surfaceElevated,
              style: TextStyle(color: tokens.textPrimary),
              decoration: InputDecoration(
                labelText: 'Tariff Type',
                labelStyle: TextStyle(color: tokens.textSecondary),
                filled: true,
                fillColor: tokens.bgApp,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: tokens.borderControl),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: tokens.borderControl),
                ),
              ),
              items: TariffType.values.map((t) {
                return DropdownMenuItem(
                  value: t,
                  child: Text(t.displayName, style: TextStyle(color: tokens.textPrimary)),
                );
              }).toList(),
              onChanged: (val) {
                if (val != null) setState(() => _selectedType = val);
              },
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    key: const Key('field_tariff_currency'),
                    controller: _currencyCtrl,
                    style: TextStyle(color: tokens.textPrimary),
                    decoration: InputDecoration(
                      labelText: 'Currency (e.g. USD)',
                      labelStyle: TextStyle(color: tokens.textSecondary),
                      filled: true,
                      fillColor: tokens.bgApp,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: tokens.borderControl),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: tokens.borderControl),
                      ),
                    ),
                    validator: (val) => val == null || val.trim().length != 3 ? '3-letter code' : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    key: const Key('field_fixed_daily_charge'),
                    controller: _fixedDailyChargeCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    style: TextStyle(color: tokens.textPrimary),
                    decoration: InputDecoration(
                      labelText: 'Fixed Daily Charge',
                      labelStyle: TextStyle(color: tokens.textSecondary),
                      filled: true,
                      fillColor: tokens.bgApp,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: tokens.borderControl),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: tokens.borderControl),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                'Set as Active Tariff',
                style: TextStyle(color: tokens.textPrimary, fontWeight: FontWeight.bold),
              ),
              subtitle: Text(
                'Used for live cost calculation and automation triggers',
                style: TextStyle(color: tokens.textSecondary, fontSize: 12),
              ),
              value: _isActive,
              activeTrackColor: tokens.switchTrackOn,
              activeThumbColor: tokens.switchThumbOn,
              onChanged: (val) => setState(() => _isActive = val),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFlatRateSection(EHThemeTokens tokens) {
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
              'Flat Rate Pricing',
              style: TextStyle(color: tokens.textPrimary, fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 12),
            TextFormField(
              key: const Key('field_flat_rate'),
              controller: _flatRateCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: TextStyle(color: tokens.textPrimary),
              decoration: InputDecoration(
                labelText: 'Price per kWh (${_currencyCtrl.text})',
                labelStyle: TextStyle(color: tokens.textSecondary),
                filled: true,
                fillColor: tokens.bgApp,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: tokens.borderControl),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: tokens.borderControl),
                ),
              ),
              validator: (val) {
                final d = double.tryParse(val ?? '');
                if (d == null || d < 0) return 'Enter a valid non-negative rate';
                return null;
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTouPeriodsSection(EHThemeTokens tokens) {
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
                  'Time-of-Use Periods',
                  style: TextStyle(color: tokens.textPrimary, fontWeight: FontWeight.bold, fontSize: 16),
                ),
                TextButton.icon(
                  key: const Key('btn_add_period'),
                  icon: Icon(Icons.add, size: 16, color: tokens.bluePrimary),
                  label: Text('Add Period', style: TextStyle(color: tokens.bluePrimary)),
                  onPressed: () => _openAddPeriodDialog(tokens),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (_periods.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12.0),
                child: Text(
                  'No TOU periods defined. Add at least one period (e.g. Peak, Off-Peak).',
                  style: TextStyle(color: tokens.textTertiary, fontSize: 12),
                ),
              ),
            ..._periods.map((p) => _buildPeriodTile(p, tokens)),
          ],
        ),
      ),
    );
  }

  Widget _buildPeriodTile(TariffPeriodModel p, EHThemeTokens tokens) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: tokens.bgApp,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: tokens.borderControl),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${p.periodType.displayName} • ${_currencyCtrl.text} ${p.pricePerKwh.toStringAsFixed(2)} / kWh',
                style: TextStyle(color: tokens.textPrimary, fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const SizedBox(height: 2),
              Text(
                'Time: ${p.startTime} - ${p.endTime}',
                style: TextStyle(color: tokens.textSecondary, fontSize: 11),
              ),
            ],
          ),
          IconButton(
            icon: Icon(Icons.delete_outline, size: 18, color: tokens.error),
            onPressed: () {
              setState(() => _periods.remove(p));
            },
          ),
        ],
      ),
    );
  }

  void _openAddPeriodDialog(EHThemeTokens tokens) {
    TariffPeriodType type = TariffPeriodType.offPeak;
    String startTime = '22:00';
    String endTime = '06:00';
    final priceCtrl = TextEditingController(text: '0.08');

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: tokens.surfaceElevated,
          title: Text('Add TOU Period', style: TextStyle(color: tokens.textPrimary)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<TariffPeriodType>(
                initialValue: type,
                dropdownColor: tokens.surfaceElevated,
                style: TextStyle(color: tokens.textPrimary),
                decoration: InputDecoration(
                  labelText: 'Period Type',
                  labelStyle: TextStyle(color: tokens.textSecondary),
                  filled: true,
                  fillColor: tokens.bgApp,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: tokens.borderControl),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: tokens.borderControl),
                  ),
                ),
                items: TariffPeriodType.values
                    .map((v) => DropdownMenuItem(
                          value: v,
                          child: Text(v.displayName, style: TextStyle(color: tokens.textPrimary)),
                        ))
                    .toList(),
                onChanged: (val) {
                  if (val != null) setDialogState(() => type = val);
                },
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      initialValue: startTime,
                      style: TextStyle(color: tokens.textPrimary),
                      decoration: InputDecoration(
                        labelText: 'Start (HH:MM)',
                        labelStyle: TextStyle(color: tokens.textSecondary),
                        filled: true,
                        fillColor: tokens.bgApp,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: tokens.borderControl),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: tokens.borderControl),
                        ),
                      ),
                      onChanged: (val) => startTime = val,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextFormField(
                      initialValue: endTime,
                      style: TextStyle(color: tokens.textPrimary),
                      decoration: InputDecoration(
                        labelText: 'End (HH:MM)',
                        labelStyle: TextStyle(color: tokens.textSecondary),
                        filled: true,
                        fillColor: tokens.bgApp,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: tokens.borderControl),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: tokens.borderControl),
                        ),
                      ),
                      onChanged: (val) => endTime = val,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: priceCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                style: TextStyle(color: tokens.textPrimary),
                decoration: InputDecoration(
                  labelText: 'Price per kWh',
                  labelStyle: TextStyle(color: tokens.textSecondary),
                  filled: true,
                  fillColor: tokens.bgApp,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: tokens.borderControl),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: tokens.borderControl),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancel', style: TextStyle(color: tokens.textSecondary)),
            ),
            ElevatedButton(
              onPressed: () {
                final price = double.tryParse(priceCtrl.text) ?? 0.0;
                final newPeriod = TariffPeriodModel(
                  id: 'p_${DateTime.now().millisecondsSinceEpoch}',
                  periodType: type,
                  startTime: startTime,
                  endTime: endTime,
                  applicableWeekdays: [1, 2, 3, 4, 5, 6, 7],
                  pricePerKwh: price,
                );
                setState(() => _periods.add(newPeriod));
                Navigator.pop(ctx);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: tokens.bluePrimary,
                foregroundColor: tokens.buttonText,
              ),
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCarbonSection(EHThemeTokens tokens) {
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
              'Grid Carbon Intensity (Optional)',
              style: TextStyle(color: tokens.textPrimary, fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            TextFormField(
              key: const Key('field_carbon_intensity'),
              controller: _carbonIntensityCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: TextStyle(color: tokens.textPrimary),
              decoration: InputDecoration(
                labelText: 'Intensity (grams CO₂ per kWh)',
                labelStyle: TextStyle(color: tokens.textSecondary),
                filled: true,
                fillColor: tokens.bgApp,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: tokens.borderControl),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: tokens.borderControl),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveTariff() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    final isEditing = widget.tariff != null;

    final flatRate = _selectedType == TariffType.flat ? double.tryParse(_flatRateCtrl.text) : null;
    final fixedCharge = double.tryParse(_fixedDailyChargeCtrl.text) ?? 0.0;
    final carbon = double.tryParse(_carbonIntensityCtrl.text);

    final model = ElectricityTariffModel(
      id: widget.tariff?.id ?? '',
      homeId: widget.homeId,
      name: _nameCtrl.text.trim(),
      tariffType: _selectedType,
      currency: _currencyCtrl.text.trim().toUpperCase(),
      flatRatePerKwh: flatRate,
      fixedDailyCharge: fixedCharge,
      carbonIntensityGPerKwh: carbon,
      effectiveFrom: widget.tariff?.effectiveFrom ?? DateTime.now(),
      effectiveTo: widget.tariff?.effectiveTo,
      isActive: _isActive,
      periods: _selectedType == TariffType.timeOfUse ? _periods : const [],
    );

    bool success = false;
    if (isEditing) {
      final updated = await widget.costService.updateTariff(model);
      success = updated != null;
    } else {
      final created = await widget.costService.createTariff(model);
      success = created != null;
    }

    if (mounted) {
      setState(() => _isSaving = false);
      if (success) {
        Navigator.pop(context, true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to save tariff. Please try again.')),
        );
      }
    }
  }
}
