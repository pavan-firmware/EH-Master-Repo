import 'package:flutter/material.dart';
import '../../../core/models/energy_cost_models.dart';
import '../../../core/services/energy_cost_service.dart';
import '../../../core/theme/app_theme.dart';

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
    final tokens = context.ehColors;
    final status = widget.costService.budgetStatus;

    return Scaffold(
      backgroundColor: tokens.bgApp,
      appBar: AppBar(
        title: Text(
          'Energy Budget & Alerts',
          style: TextStyle(fontWeight: FontWeight.bold, color: tokens.textPrimary),
        ),
        backgroundColor: tokens.bgApp,
        elevation: 0,
        iconTheme: IconThemeData(color: tokens.headerAction),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: tokens.bluePrimary))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildPeriodSelector(tokens),
                  const SizedBox(height: 16),
                  if (status != null && status.configured) ...[
                    _buildCurrentStatusCard(status, tokens),
                    const SizedBox(height: 16),
                  ],
                  _buildBudgetForm(tokens),
                ],
              ),
            ),
    );
  }

  Widget _buildPeriodSelector(EHThemeTokens tokens) {
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
            return tokens.blueSelectedBg;
          }
          return tokens.surfaceCard;
        }),
        foregroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return tokens.blueSelectedText;
          }
          return tokens.textSecondary;
        }),
        side: WidgetStateProperty.all(BorderSide(color: tokens.borderControl)),
      ),
    );
  }

  Widget _buildCurrentStatusCard(BudgetStatusModel status, EHThemeTokens tokens) {
    final percent = (status.percentConsumed / 100).clamp(0.0, 1.0);
    final isOverrun = status.isProjectedToExceed;

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
                  '${status.periodType.displayName} Spending Status',
                  style: TextStyle(color: tokens.textPrimary, fontWeight: FontWeight.bold),
                ),
                if (isOverrun)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: tokens.errorContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'PROJECTED OVERRUN',
                      style: TextStyle(color: tokens.error, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: percent,
              backgroundColor: tokens.isDark ? Colors.white10 : Colors.black12,
              color: isOverrun ? tokens.error : tokens.success,
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
                    Text('Spent So Far', style: TextStyle(color: tokens.textSecondary, fontSize: 11)),
                    Text(
                      '${status.currency} ${status.actualCostToDate.toStringAsFixed(2)}',
                      style: TextStyle(color: tokens.textPrimary, fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Remaining Budget', style: TextStyle(color: tokens.textSecondary, fontSize: 11)),
                    Text(
                      '${status.currency} ${status.budgetRemaining.toStringAsFixed(2)}',
                      style: TextStyle(color: tokens.success, fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('Forecasted Total', style: TextStyle(color: tokens.textSecondary, fontSize: 11)),
                    Text(
                      '${status.currency} ${status.projectedTotalCost.toStringAsFixed(2)}',
                      style: TextStyle(
                        color: isOverrun ? tokens.error : tokens.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBudgetForm(EHThemeTokens tokens) {
    return Card(
      color: tokens.surfaceCard,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: tokens.borderSubtle),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Set ${_periodType.displayName} Target',
                style: TextStyle(color: tokens.textPrimary, fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      key: const Key('field_budget_amount'),
                      controller: _budgetAmountCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: TextStyle(color: tokens.textPrimary),
                      decoration: InputDecoration(
                        labelText: 'Budget Amount',
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
                      style: TextStyle(color: tokens.textPrimary),
                      decoration: InputDecoration(
                        labelText: 'Currency',
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
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Alert Threshold', style: TextStyle(color: tokens.textSecondary)),
                  Text(
                    '${_alertThreshold.toInt()}%',
                    style: TextStyle(color: tokens.bluePrimary, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              Slider(
                value: _alertThreshold,
                min: 50,
                max: 100,
                divisions: 10,
                activeColor: tokens.bluePrimary,
                onChanged: (val) => setState(() => _alertThreshold = val),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  'Enable Overrun Notifications',
                  style: TextStyle(color: tokens.textPrimary, fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  'Receive push alerts when forecast exceeds budget',
                  style: TextStyle(color: tokens.textSecondary, fontSize: 12),
                ),
                value: _isEnabled,
                activeTrackColor: tokens.switchTrackOn,
                activeThumbColor: tokens.switchThumbOn,
                onChanged: (val) => setState(() => _isEnabled = val),
              ),
              const SizedBox(height: 16),
              FilledButton(
                key: const Key('btn_save_budget'),
                onPressed: _isSaving ? null : _saveBudget,
                style: FilledButton.styleFrom(
                  backgroundColor: tokens.bluePrimary,
                  foregroundColor: tokens.buttonText,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _isSaving
                    ? SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: tokens.buttonText))
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
