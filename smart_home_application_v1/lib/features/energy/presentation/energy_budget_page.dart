import 'package:flutter/material.dart';
import '../../../core/models/energy_cost_models.dart';
import '../../../core/services/energy_cost_service.dart';

/// Energy Budget Management Page — Configure spending budgets and alerts
class EnergyBudgetPage extends StatefulWidget {
  final String homeId;
  final EnergyCostService costService;

  const EnergyBudgetPage({
    super.key,
    required this.homeId,
    required this.costService,
  });

  @override
  State<EnergyBudgetPage> createState() => _EnergyBudgetPageState();
}

class _EnergyBudgetPageState extends State<EnergyBudgetPage> {
  final _formKey = GlobalKey<FormState>();

  BudgetPeriodType _periodType = BudgetPeriodType.monthly;
  late TextEditingController _budgetAmountCtrl;
  late TextEditingController _currencyCtrl;
  double _alertThreshold = 80.0;
  bool _isEnabled = true;
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _budgetAmountCtrl = TextEditingController(text: '100.0');
    _currencyCtrl = TextEditingController(text: 'USD');
    _loadBudget();
  }

  @override
  void dispose() {
    _budgetAmountCtrl.dispose();
    _currencyCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadBudget() async {
    setState(() => _isLoading = true);
    final status = await widget.costService.fetchBudgetStatus(widget.homeId, periodType: _periodType.toServerString());
    if (status != null && status.configured) {
      _budgetAmountCtrl.text = status.budgetAmount.toStringAsFixed(2);
      _currencyCtrl.text = status.currency;
    }
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = widget.costService.budgetStatus;

    return Scaffold(
      backgroundColor: const Color(0xFF121418),
      appBar: AppBar(
        title: const Text('Energy Budget & Alerts', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF1E222B),
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.amberAccent))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildPeriodSelector(),
                  const SizedBox(height: 16),
                  if (status != null && status.configured) ...[
                    _buildCurrentStatusCard(status),
                    const SizedBox(height: 16),
                  ],
                  _buildBudgetForm(),
                ],
              ),
            ),
    );
  }

  Widget _buildPeriodSelector() {
    return SegmentedButton<BudgetPeriodType>(
      segments: const [
        ButtonSegment(value: BudgetPeriodType.daily, label: Text('Daily')),
        ButtonSegment(value: BudgetPeriodType.weekly, label: Text('Weekly')),
        ButtonSegment(value: BudgetPeriodType.monthly, label: Text('Monthly')),
      ],
      selected: {_periodType},
      onSelectionChanged: (set) {
        setState(() => _periodType = set.first);
        _loadBudget();
      },
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return Colors.amberAccent.withValues(alpha: 0.2);
          }
          return const Color(0xFF1E222B);
        }),
        foregroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return Colors.amberAccent;
          }
          return Colors.white70;
        }),
      ),
    );
  }

  Widget _buildCurrentStatusCard(BudgetStatusModel status) {
    final percent = (status.percentConsumed / 100).clamp(0.0, 1.0);
    final isOverrun = status.isProjectedToExceed;

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
                Text('${status.periodType.displayName} Spending Status',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                if (isOverrun)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: Colors.redAccent.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(8)),
                    child: const Text('PROJECTED OVERRUN', style: TextStyle(color: Colors.redAccent, fontSize: 10, fontWeight: FontWeight.bold)),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: percent,
              backgroundColor: Colors.white10,
              color: isOverrun ? Colors.redAccent : Colors.greenAccent,
              minHeight: 10,
              borderRadius: BorderRadius.circular(5),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Spent So Far', style: TextStyle(color: Colors.white54, fontSize: 11)),
                    Text('${status.currency} ${status.actualCostToDate.toStringAsFixed(2)}',
                        style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Remaining Budget', style: TextStyle(color: Colors.white54, fontSize: 11)),
                    Text('${status.currency} ${status.budgetRemaining.toStringAsFixed(2)}',
                        style: const TextStyle(color: Colors.greenAccent, fontSize: 15, fontWeight: FontWeight.bold)),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text('Forecasted Total', style: TextStyle(color: Colors.white54, fontSize: 11)),
                    Text('${status.currency} ${status.projectedTotalCost.toStringAsFixed(2)}',
                        style: TextStyle(color: isOverrun ? Colors.redAccent : Colors.white70, fontSize: 15, fontWeight: FontWeight.bold)),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBudgetForm() {
    return Card(
      color: const Color(0xFF1E222B),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Set ${_periodType.displayName} Target', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      key: const Key('field_budget_amount'),
                      controller: _budgetAmountCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: 'Budget Amount',
                        labelStyle: TextStyle(color: Colors.white60),
                        filled: true,
                        fillColor: Color(0xFF121418),
                        border: OutlineInputBorder(),
                      ),
                      validator: (val) {
                        final d = double.tryParse(val ?? '');
                        if (d == null || d <= 0) return 'Must be positive';
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 100,
                    child: TextFormField(
                      key: const Key('field_budget_currency'),
                      controller: _currencyCtrl,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: 'Currency',
                        labelStyle: TextStyle(color: Colors.white60),
                        filled: true,
                        fillColor: Color(0xFF121418),
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Alert Threshold', style: TextStyle(color: Colors.white70)),
                  Text('${_alertThreshold.toInt()}%', style: const TextStyle(color: Colors.amberAccent, fontWeight: FontWeight.bold)),
                ],
              ),
              Slider(
                value: _alertThreshold,
                min: 50,
                max: 100,
                divisions: 10,
                activeColor: Colors.amberAccent,
                onChanged: (val) => setState(() => _alertThreshold = val),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Enable Overrun Notifications', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                subtitle: const Text('Receive push alerts when forecast exceeds budget', style: TextStyle(color: Colors.white54, fontSize: 12)),
                value: _isEnabled,
                activeThumbColor: Colors.amberAccent,
                onChanged: (val) => setState(() => _isEnabled = val),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                key: const Key('btn_save_budget'),
                onPressed: _isSaving ? null : _saveBudget,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amberAccent,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _isSaving
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                    : const Text('Save Budget', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _saveBudget() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    final amount = double.tryParse(_budgetAmountCtrl.text) ?? 100.0;

    final model = EnergyBudgetModel(
      id: '',
      homeId: widget.homeId,
      periodType: _periodType,
      budgetAmount: amount,
      currency: _currencyCtrl.text.trim().toUpperCase(),
      alertThresholdPercent: _alertThreshold,
      isEnabled: _isEnabled,
    );

    final saved = await widget.costService.saveBudget(model);
    if (mounted) {
      setState(() => _isSaving = false);
      if (saved != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${_periodType.displayName} budget saved successfully!')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to save budget.')),
        );
      }
    }
  }
}
