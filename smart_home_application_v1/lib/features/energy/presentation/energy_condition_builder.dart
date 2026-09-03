import 'package:flutter/material.dart';
import '../../../core/models/energy_automation_models.dart';

/// EH Home — Energy Condition Builder Widget (Phase 20)
class EnergyConditionBuilder extends StatefulWidget {
  final EnergyConditionModel initialCondition;
  final ValueChanged<EnergyConditionModel> onChanged;
  final VoidCallback? onRemove;
  final List<Map<String, String>> availableDevices;

  const EnergyConditionBuilder({
    super.key,
    required this.initialCondition,
    required this.onChanged,
    this.onRemove,
    this.availableDevices = const [],
  });

  @override
  State<EnergyConditionBuilder> createState() => _EnergyConditionBuilderState();
}

class _EnergyConditionBuilderState extends State<EnergyConditionBuilder> {
  late EnergyMetric _metric;
  late EnergyOperator _operator;
  late TextEditingController _thresholdController;
  late String _unit;
  int? _durationSeconds;
  bool _hasTimeWindow = false;
  String _startTime = '22:00';
  String _endTime = '06:00';
  String? _deviceId;

  @override
  void initState() {
    super.initState();
    _metric = widget.initialCondition.metric;
    _operator = widget.initialCondition.operator;
    _thresholdController = TextEditingController(text: widget.initialCondition.threshold.toString());
    _unit = widget.initialCondition.unit;
    _durationSeconds = widget.initialCondition.durationSeconds;
    _hasTimeWindow = widget.initialCondition.timeWindow != null;
    if (_hasTimeWindow) {
      _startTime = widget.initialCondition.timeWindow!.startTime;
      _endTime = widget.initialCondition.timeWindow!.endTime;
    }
    _deviceId = widget.initialCondition.deviceId;
  }

  @override
  void dispose() {
    _thresholdController.dispose();
    super.dispose();
  }

  void _notifyChanges() {
    final thresholdVal = double.tryParse(_thresholdController.text) ?? 0.0;
    final updated = EnergyConditionModel(
      type: 'energy_condition',
      metric: _metric,
      operator: _operator,
      threshold: thresholdVal,
      unit: _unit,
      durationSeconds: _metric == EnergyMetric.sustainedPower ? _durationSeconds : null,
      timeWindow: _hasTimeWindow ? TimeWindowModel(startTime: _startTime, endTime: _endTime) : null,
      deviceId: _deviceId,
    );
    widget.onChanged(updated);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6.0),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.bolt, color: Colors.amber, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Energy Trigger Condition',
                      style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                if (widget.onRemove != null)
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                    onPressed: widget.onRemove,
                    tooltip: 'Remove Condition',
                  ),
              ],
            ),
            const Divider(),
            const SizedBox(height: 8),

            // 1. Metric Dropdown
            DropdownButtonFormField<EnergyMetric>(
              initialValue: _metric,
              decoration: const InputDecoration(
                labelText: 'Energy Metric',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              items: EnergyMetric.values.map((m) {
                return DropdownMenuItem(value: m, child: Text(m.displayName));
              }).toList(),
              onChanged: (val) {
                if (val != null) {
                  setState(() {
                    _metric = val;
                    _unit = val.defaultUnit;
                  });
                  _notifyChanges();
                }
              },
            ),
            const SizedBox(height: 12),

            // 2. Operator and Threshold Input Row
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: DropdownButtonFormField<EnergyOperator>(
                    initialValue: _operator,
                    decoration: const InputDecoration(
                      labelText: 'Operator',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    ),
                    items: EnergyOperator.values.map((op) {
                      return DropdownMenuItem(value: op, child: Text(op.symbol));
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() => _operator = val);
                        _notifyChanges();
                      }
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 3,
                  child: TextField(
                    controller: _thresholdController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: 'Threshold',
                      suffixText: _unit,
                      border: const OutlineInputBorder(),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    onChanged: (_) => _notifyChanges(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // 3. Sustained Duration (if sustained metric chosen)
            if (_metric == EnergyMetric.sustainedPower) ...[
              DropdownButtonFormField<int>(
                initialValue: _durationSeconds ?? 60,
                decoration: const InputDecoration(
                  labelText: 'Sustained Duration',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                items: const [
                  DropdownMenuItem(value: 10, child: Text('10 seconds')),
                  DropdownMenuItem(value: 30, child: Text('30 seconds')),
                  DropdownMenuItem(value: 60, child: Text('1 minute (60s)')),
                  DropdownMenuItem(value: 300, child: Text('5 minutes (300s)')),
                  DropdownMenuItem(value: 900, child: Text('15 minutes (900s)')),
                  DropdownMenuItem(value: 3600, child: Text('1 hour')),
                ],
                onChanged: (val) {
                  setState(() => _durationSeconds = val);
                  _notifyChanges();
                },
              ),
              const SizedBox(height: 12),
            ],

            // 4. Target Device Selector (Optional)
            if (widget.availableDevices.isNotEmpty) ...[
              DropdownButtonFormField<String?>(
                initialValue: _deviceId,
                decoration: const InputDecoration(
                  labelText: 'Target Device (Optional / Scope)',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                items: [
                  const DropdownMenuItem(value: null, child: Text('Any / Home Level')),
                  ...widget.availableDevices.map((d) {
                    return DropdownMenuItem(value: d['id'], child: Text(d['name'] ?? d['id']!));
                  }),
                ],
                onChanged: (val) {
                  setState(() => _deviceId = val);
                  _notifyChanges();
                },
              ),
              const SizedBox(height: 12),
            ],

            // 5. Time Window Toggle
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Restrict to Time Window', style: TextStyle(fontSize: 14)),
              value: _hasTimeWindow,
              onChanged: (val) {
                setState(() => _hasTimeWindow = val);
                _notifyChanges();
              },
            ),

            if (_hasTimeWindow)
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.access_time, size: 16),
                      label: Text('Start: $_startTime'),
                      onPressed: () async {
                        final time = await showTimePicker(
                          context: context,
                          initialTime: const TimeOfDay(hour: 22, minute: 0),
                        );
                        if (time != null) {
                          final h = time.hour.toString().padLeft(2, '0');
                          final m = time.minute.toString().padLeft(2, '0');
                          setState(() => _startTime = '$h:$m');
                          _notifyChanges();
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.access_time, size: 16),
                      label: Text('End: $_endTime'),
                      onPressed: () async {
                        final time = await showTimePicker(
                          context: context,
                          initialTime: const TimeOfDay(hour: 6, minute: 0),
                        );
                        if (time != null) {
                          final h = time.hour.toString().padLeft(2, '0');
                          final m = time.minute.toString().padLeft(2, '0');
                          setState(() => _endTime = '$h:$m');
                          _notifyChanges();
                        }
                      },
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
