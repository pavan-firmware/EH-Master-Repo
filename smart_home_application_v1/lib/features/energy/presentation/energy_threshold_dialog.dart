import 'package:flutter/material.dart';
import '../../../core/models/energy_models.dart';
import '../../../core/services/energy_service.dart';
import '../../../core/theme/app_theme.dart';

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
    final tokens = context.ehColors;
    return AlertDialog(
      backgroundColor: tokens.surfaceCard,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: tokens.borderControl),
      ),
      title: Text(
        'Energy Thresholds & Budget',
        style: TextStyle(
          color: tokens.textPrimary,
          fontWeight: FontWeight.w800,
        ),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SwitchListTile(
              title: Text(
                'Enable Energy Alerts',
                style: TextStyle(
                  color: tokens.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              activeTrackColor: tokens.bluePrimary,
              value: _isEnabled,
              onChanged: (v) => setState(() => _isEnabled = v),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _highPowerCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: TextStyle(color: tokens.textPrimary),
              decoration: InputDecoration(
                labelText: 'High Load Alert Limit (Watts)',
                labelStyle: TextStyle(color: tokens.textSecondary),
                hintText: 'e.g. 2500',
                hintStyle: TextStyle(color: tokens.textSecondary),
                suffixText: 'W',
                suffixStyle: TextStyle(color: tokens.textSecondary),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: tokens.borderControl),
                  borderRadius: BorderRadius.circular(10),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: tokens.bluePrimary, width: 2),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _dailyEnergyCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: TextStyle(color: tokens.textPrimary),
              decoration: InputDecoration(
                labelText: 'Daily Energy Budget (kWh)',
                labelStyle: TextStyle(color: tokens.textSecondary),
                hintText: 'e.g. 25.0',
                hintStyle: TextStyle(color: tokens.textSecondary),
                suffixText: 'kWh',
                suffixStyle: TextStyle(color: tokens.textSecondary),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: tokens.borderControl),
                  borderRadius: BorderRadius.circular(10),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: tokens.bluePrimary, width: 2),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _tariffRateCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: TextStyle(color: tokens.textPrimary),
              decoration: InputDecoration(
                labelText: 'Electricity Tariff Rate (\$/kWh)',
                labelStyle: TextStyle(color: tokens.textSecondary),
                hintText: 'e.g. 0.15',
                hintStyle: TextStyle(color: tokens.textSecondary),
                suffixText: '\$/kWh',
                suffixStyle: TextStyle(color: tokens.textSecondary),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: tokens.borderControl),
                  borderRadius: BorderRadius.circular(10),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: tokens.bluePrimary, width: 2),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.of(context).pop(false),
          child: Text(
            'Cancel',
            style: TextStyle(color: tokens.textSecondary),
          ),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: tokens.bluePrimary,
            foregroundColor: Colors.white,
          ),
          onPressed: _isSaving ? null : _save,
          child: _isSaving
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Text('Save'),
        ),
      ],
    );
  }
}
