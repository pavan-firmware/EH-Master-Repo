import 'package:flutter/material.dart';
import '../../../core/models/energy_models.dart';
import '../../../core/services/energy_service.dart';

/// Dialog for editing high power alerts and energy budget thresholds
class EnergyThresholdDialog extends StatefulWidget {
  final EnergyService energyService;
  final String homeId;
  final EnergyThresholdConfig? initialConfig;

  const EnergyThresholdDialog({
    super.key,
    required this.energyService,
    required this.homeId,
    this.initialConfig,
  });

  @override
  State<EnergyThresholdDialog> createState() => _EnergyThresholdDialogState();
}

class _EnergyThresholdDialogState extends State<EnergyThresholdDialog> {
  late TextEditingController _highPowerCtrl;
  late TextEditingController _dailyEnergyCtrl;
  late TextEditingController _tariffRateCtrl;
  bool _isEnabled = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final cfg = widget.initialConfig;
    _highPowerCtrl = TextEditingController(
      text: cfg?.highPowerW != null ? cfg!.highPowerW!.toStringAsFixed(0) : '2500',
    );
    _dailyEnergyCtrl = TextEditingController(
      text: cfg?.dailyEnergyKwh != null ? cfg!.dailyEnergyKwh!.toStringAsFixed(1) : '25.0',
    );
    _tariffRateCtrl = TextEditingController(
      text: cfg?.costPerKwh != null ? cfg!.costPerKwh.toStringAsFixed(2) : '0.15',
    );
    _isEnabled = cfg?.isEnabled ?? true;
  }

  @override
  void dispose() {
    _highPowerCtrl.dispose();
    _dailyEnergyCtrl.dispose();
    _tariffRateCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    final highPower = double.tryParse(_highPowerCtrl.text.trim());
    final dailyEnergy = double.tryParse(_dailyEnergyCtrl.text.trim());
    final tariff = double.tryParse(_tariffRateCtrl.text.trim()) ?? 0.15;

    final config = EnergyThresholdConfig(
      homeId: widget.homeId,
      highPowerW: highPower,
      dailyEnergyKwh: dailyEnergy,
      costPerKwh: tariff,
      currency: 'USD',
      isEnabled: _isEnabled,
    );

    final success = await widget.energyService.setThreshold(widget.homeId, config);
    if (mounted) {
      setState(() => _isSaving = false);
      if (success) {
        Navigator.of(context).pop(true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save threshold: ${widget.energyService.lastError}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Energy Thresholds & Budget'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SwitchListTile(
              title: const Text('Enable Energy Alerts'),
              value: _isEnabled,
              onChanged: (v) => setState(() => _isEnabled = v),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _highPowerCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'High Load Alert Limit (Watts)',
                hintText: 'e.g. 2500',
                suffixText: 'W',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _dailyEnergyCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Daily Energy Budget (kWh)',
                hintText: 'e.g. 25.0',
                suffixText: 'kWh',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _tariffRateCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Electricity Tariff Rate (\$/kWh)',
                hintText: 'e.g. 0.15',
                suffixText: '\$/kWh',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isSaving ? null : _save,
          child: _isSaving
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Save'),
        ),
      ],
    );
  }
}
