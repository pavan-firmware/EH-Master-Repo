import 'package:flutter/material.dart';
import '../../../core/models/energy_cost_models.dart';
import '../../../core/services/energy_cost_service.dart';

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
    final isEditing = widget.tariff != null;

    return Scaffold(
      backgroundColor: const Color(0xFF121418),
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Tariff' : 'New Electricity Tariff', style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF1E222B),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildGeneralSection(),
              const SizedBox(height: 16),
              if (_selectedType == TariffType.flat) _buildFlatRateSection(),
              if (_selectedType == TariffType.timeOfUse) _buildTouPeriodsSection(),
              const SizedBox(height: 16),
              _buildCarbonSection(),
              const SizedBox(height: 24),
              ElevatedButton(
                key: const Key('btn_save_tariff'),
                onPressed: _isSaving ? null : _saveTariff,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amberAccent,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _isSaving
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                    : Text(isEditing ? 'Save Changes' : 'Create Tariff', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGeneralSection() {
    return Card(
      color: const Color(0xFF1E222B),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Tariff Configuration', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 16),
            TextFormField(
              key: const Key('field_tariff_name'),
              controller: _nameCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Tariff Plan Name',
                labelStyle: TextStyle(color: Colors.white60),
                filled: true,
                fillColor: Color(0xFF121418),
                border: OutlineInputBorder(),
              ),
              validator: (val) => val == null || val.trim().isEmpty ? 'Name is required' : null,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<TariffType>(
              key: const Key('dropdown_tariff_type'),
              initialValue: _selectedType,
              dropdownColor: const Color(0xFF1E222B),
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Tariff Type',
                labelStyle: TextStyle(color: Colors.white60),
                filled: true,
                fillColor: Color(0xFF121418),
                border: OutlineInputBorder(),
              ),
              items: TariffType.values.map((t) {
                return DropdownMenuItem(value: t, child: Text(t.displayName));
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
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      labelText: 'Currency (e.g. USD, EUR)',
                      labelStyle: TextStyle(color: Colors.white60),
                      filled: true,
                      fillColor: Color(0xFF121418),
                      border: OutlineInputBorder(),
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
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      labelText: 'Fixed Daily Charge',
                      labelStyle: TextStyle(color: Colors.white60),
                      filled: true,
                      fillColor: Color(0xFF121418),
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Set as Active Tariff', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              subtitle: const Text('Used for live cost calculation and automation triggers', style: TextStyle(color: Colors.white54, fontSize: 12)),
              value: _isActive,
              activeThumbColor: Colors.amberAccent,
              onChanged: (val) => setState(() => _isActive = val),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFlatRateSection() {
    return Card(
      color: const Color(0xFF1E222B),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Flat Rate Pricing', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 12),
            TextFormField(
              key: const Key('field_flat_rate'),
              controller: _flatRateCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Price per kWh (${_currencyCtrl.text})',
                labelStyle: const TextStyle(color: Colors.white60),
                filled: true,
                fillColor: const Color(0xFF121418),
                border: const OutlineInputBorder(),
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

  Widget _buildTouPeriodsSection() {
    return Card(
      color: const Color(0xFF1E222B),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Time-of-Use Periods', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                TextButton.icon(
                  key: const Key('btn_add_period'),
                  icon: const Icon(Icons.add, size: 16, color: Colors.amberAccent),
                  label: const Text('Add Period', style: TextStyle(color: Colors.amberAccent)),
                  onPressed: _openAddPeriodDialog,
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (_periods.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12.0),
                child: Text('No TOU periods defined. Add at least one period (e.g. Peak, Off-Peak).',
                    style: TextStyle(color: Colors.white54, fontSize: 12)),
              ),
            ..._periods.map((p) => _buildPeriodTile(p)),
          ],
        ),
      ),
    );
  }

  Widget _buildPeriodTile(TariffPeriodModel p) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF121418),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${p.periodType.displayName} • ${_currencyCtrl.text} ${p.pricePerKwh.toStringAsFixed(2)} / kWh',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const SizedBox(height: 2),
              Text(
                'Time: ${p.startTime} - ${p.endTime}',
                style: const TextStyle(color: Colors.white54, fontSize: 11),
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
            onPressed: () {
              setState(() => _periods.remove(p));
            },
          ),
        ],
      ),
    );
  }

  void _openAddPeriodDialog() {
    TariffPeriodType type = TariffPeriodType.offPeak;
    String startTime = '22:00';
    String endTime = '06:00';
    final priceCtrl = TextEditingController(text: '0.08');

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF1E222B),
          title: const Text('Add TOU Period', style: TextStyle(color: Colors.white)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<TariffPeriodType>(
                initialValue: type,
                dropdownColor: const Color(0xFF1E222B),
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(labelText: 'Period Type', labelStyle: TextStyle(color: Colors.white60)),
                items: TariffPeriodType.values.map((v) => DropdownMenuItem(value: v, child: Text(v.displayName))).toList(),
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
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(labelText: 'Start (HH:MM)', labelStyle: TextStyle(color: Colors.white60)),
                      onChanged: (val) => startTime = val,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextFormField(
                      initialValue: endTime,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(labelText: 'End (HH:MM)', labelStyle: TextStyle(color: Colors.white60)),
                      onChanged: (val) => endTime = val,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: priceCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(labelText: 'Price per kWh', labelStyle: TextStyle(color: Colors.white60)),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
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
              style: ElevatedButton.styleFrom(backgroundColor: Colors.amberAccent, foregroundColor: Colors.black),
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCarbonSection() {
    return Card(
      color: const Color(0xFF1E222B),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Grid Carbon Intensity (Optional)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            TextFormField(
              key: const Key('field_carbon_intensity'),
              controller: _carbonIntensityCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Intensity (grams CO₂ per kWh)',
                labelStyle: TextStyle(color: Colors.white60),
                filled: true,
                fillColor: Color(0xFF121418),
                border: OutlineInputBorder(),
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
