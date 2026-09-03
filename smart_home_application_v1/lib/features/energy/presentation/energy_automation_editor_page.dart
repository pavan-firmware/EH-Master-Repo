import 'package:flutter/material.dart';
import '../../../core/models/energy_automation_models.dart';
import '../../../core/services/energy_automation_service.dart';
import 'energy_condition_builder.dart';
import 'energy_action_builder.dart';

/// EH Home — Energy Automation Rule Editor Page (Phase 20)
class EnergyAutomationEditorPage extends StatefulWidget {
  final String homeId;
  final EnergyAutomationService service;
  final EnergyAutomationRuleModel? existingRule;
  final List<Map<String, String>> availableDevices;
  final List<Map<String, String>> availableScenes;

  const EnergyAutomationEditorPage({
    super.key,
    required this.homeId,
    required this.service,
    this.existingRule,
    this.availableDevices = const [],
    this.availableScenes = const [],
  });

  @override
  State<EnergyAutomationEditorPage> createState() => _EnergyAutomationEditorPageState();
}

class _EnergyAutomationEditorPageState extends State<EnergyAutomationEditorPage> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameController;
  late TextEditingController _descController;
  late TextEditingController _recoveryThresholdController;

  late String _scopeType;
  String? _scopeId;
  late String _conditionLogic;
  late int _cooldownSeconds;

  late List<EnergyConditionModel> _conditions;
  late List<EnergyActionModel> _actions;

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final rule = widget.existingRule;

    _nameController = TextEditingController(text: rule?.name ?? '');
    _descController = TextEditingController(text: rule?.description ?? '');
    _recoveryThresholdController = TextEditingController(
      text: rule?.hysteresis?.recoveryThreshold?.toString() ?? '',
    );

    _scopeType = rule?.scopeType ?? 'home';
    _scopeId = rule?.scopeId;
    _conditionLogic = rule?.conditionLogic ?? 'AND';
    _cooldownSeconds = rule?.cooldownSeconds ?? 60;

    _conditions = rule != null && rule.conditions.isNotEmpty
        ? List.from(rule.conditions)
        : [
            const EnergyConditionModel(
              metric: EnergyMetric.instantaneousPower,
              operator: EnergyOperator.gt,
              threshold: 1500.0,
            ),
          ];

    _actions = rule != null && rule.actions.isNotEmpty
        ? List.from(rule.actions)
        : [
            const EnergyActionModel(
              actionType: 'device_command',
              command: 'setPower',
              params: {'value': false, 'power': false},
            ),
          ];
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    _recoveryThresholdController.dispose();
    super.dispose();
  }

  Future<void> _saveRule() async {
    if (!_formKey.currentState!.validate()) return;
    if (_conditions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('At least one trigger condition is required')),
      );
      return;
    }
    if (_actions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('At least one action is required')),
      );
      return;
    }

    setState(() => _isSaving = true);

    final recoveryThreshold = double.tryParse(_recoveryThresholdController.text);
    final hysteresis = recoveryThreshold != null
        ? EnergyHysteresisConfigModel(
            recoveryThreshold: recoveryThreshold,
            cooldownSeconds: _cooldownSeconds,
          )
        : null;

    final ruleModel = EnergyAutomationRuleModel(
      id: widget.existingRule?.id ?? '',
      homeId: widget.homeId,
      name: _nameController.text.trim(),
      description: _descController.text.trim().isNotEmpty ? _descController.text.trim() : null,
      isEnabled: widget.existingRule?.isEnabled ?? true,
      triggerType: 'energy_threshold',
      scopeType: _scopeType,
      scopeId: _scopeId,
      conditions: _conditions,
      conditionLogic: _conditionLogic,
      hysteresis: hysteresis,
      cooldownSeconds: _cooldownSeconds,
      actions: _actions,
    );

    if (widget.existingRule != null) {
      final updated = await widget.service.updateAutomation(
        widget.existingRule!.id,
        ruleModel.toJson(),
      );
      if (mounted) {
        setState(() => _isSaving = false);
        if (updated != null) {
          Navigator.of(context).pop(true);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(widget.service.lastError ?? 'Failed to update rule')),
          );
        }
      }
    } else {
      final created = await widget.service.createAutomation(ruleModel);
      if (mounted) {
        setState(() => _isSaving = false);
        if (created != null) {
          Navigator.of(context).pop(true);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(widget.service.lastError ?? 'Failed to create rule')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isEditing = widget.existingRule != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Energy Automation' : 'New Energy Automation'),
        actions: [
          IconButton(
            icon: const Icon(Icons.check),
            onPressed: _isSaving ? null : _saveRule,
            tooltip: 'Save Rule',
          ),
        ],
      ),
      body: _isSaving
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16.0),
                children: [
                  // 1. General Info Card
                  Card(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 2,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'General Settings',
                            style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const Divider(),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _nameController,
                            decoration: const InputDecoration(
                              labelText: 'Rule Name *',
                              hintText: 'e.g. Overload Protection or Vampire Cutoff',
                              border: OutlineInputBorder(),
                            ),
                            validator: (val) {
                              if (val == null || val.trim().isEmpty) return 'Rule name is required';
                              return null;
                            },
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _descController,
                            maxLines: 2,
                            decoration: const InputDecoration(
                              labelText: 'Description (Optional)',
                              hintText: 'Describe what this energy automation accomplishes',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: DropdownButtonFormField<String>(
                                  initialValue: _scopeType,
                                  decoration: const InputDecoration(
                                    labelText: 'Scope',
                                    border: OutlineInputBorder(),
                                  ),
                                  items: const [
                                    DropdownMenuItem(value: 'home', child: Text('Entire Home')),
                                    DropdownMenuItem(value: 'room', child: Text('Specific Room')),
                                    DropdownMenuItem(value: 'device', child: Text('Specific Device')),
                                  ],
                                  onChanged: (val) {
                                    if (val != null) {
                                      setState(() {
                                        _scopeType = val;
                                        _scopeId = null;
                                      });
                                    }
                                  },
                                ),
                              ),
                              if (_scopeType == 'device' && widget.availableDevices.isNotEmpty) ...[
                                const SizedBox(width: 12),
                                Expanded(
                                  child: DropdownButtonFormField<String?>(
                                    initialValue: _scopeId,
                                    decoration: const InputDecoration(
                                      labelText: 'Device',
                                      border: OutlineInputBorder(),
                                    ),
                                    items: widget.availableDevices.map((d) {
                                      return DropdownMenuItem(value: d['id'], child: Text(d['name'] ?? d['id']!));
                                    }).toList(),
                                    onChanged: (val) => setState(() => _scopeId = val),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // 2. Trigger Conditions Section
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'When Condition Triggers (${_conditions.length})',
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      TextButton.icon(
                        icon: const Icon(Icons.add, size: 16),
                        label: const Text('Add Condition'),
                        onPressed: () {
                          setState(() {
                            _conditions.add(
                              const EnergyConditionModel(
                                metric: EnergyMetric.instantaneousPower,
                                operator: EnergyOperator.gt,
                                threshold: 1000.0,
                              ),
                            );
                          });
                        },
                      ),
                    ],
                  ),

                  if (_conditions.length > 1) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4.0),
                      child: SegmentedButton<String>(
                        segments: const [
                          ButtonSegment(value: 'AND', label: Text('Match ALL (AND)')),
                          ButtonSegment(value: 'OR', label: Text('Match ANY (OR)')),
                        ],
                        selected: {_conditionLogic},
                        onSelectionChanged: (val) => setState(() => _conditionLogic = val.first),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],

                  ..._conditions.asMap().entries.map((entry) {
                    final idx = entry.key;
                    final cond = entry.value;
                    return EnergyConditionBuilder(
                      key: ValueKey('cond_$idx'),
                      initialCondition: cond,
                      availableDevices: widget.availableDevices,
                      onChanged: (updated) => _conditions[idx] = updated,
                      onRemove: _conditions.length > 1
                          ? () => setState(() => _conditions.removeAt(idx))
                          : null,
                    );
                  }),

                  const SizedBox(height: 16),

                  // 3. Hysteresis & Debounce Safeguard Card
                  Card(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 2,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.shield_outlined, color: Colors.indigo, size: 20),
                              const SizedBox(width: 8),
                              Text(
                                'Hysteresis & Oscillation Prevention',
                                style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          const Divider(),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _recoveryThresholdController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: const InputDecoration(
                              labelText: 'Recovery Threshold (W) — Anti-Oscillation',
                              hintText: 'e.g. 1200 (for 1500W trigger)',
                              suffixText: 'W',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<int>(
                            initialValue: _cooldownSeconds,
                            decoration: const InputDecoration(
                              labelText: 'Cooldown Debounce Interval',
                              border: OutlineInputBorder(),
                            ),
                            items: const [
                              DropdownMenuItem(value: 0, child: Text('No cooldown (0s)')),
                              DropdownMenuItem(value: 30, child: Text('30 seconds debounce')),
                              DropdownMenuItem(value: 60, child: Text('1 minute debounce (60s)')),
                              DropdownMenuItem(value: 300, child: Text('5 minutes debounce (300s)')),
                              DropdownMenuItem(value: 900, child: Text('15 minutes debounce (900s)')),
                            ],
                            onChanged: (val) {
                              if (val != null) setState(() => _cooldownSeconds = val);
                            },
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // 4. Actions Section
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Then Execute Actions (${_actions.length})',
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      TextButton.icon(
                        icon: const Icon(Icons.add, size: 16),
                        label: const Text('Add Action'),
                        onPressed: () {
                          setState(() {
                            _actions.add(
                              const EnergyActionModel(
                                actionType: 'device_command',
                                command: 'setPower',
                                params: {'value': false, 'power': false},
                              ),
                            );
                          });
                        },
                      ),
                    ],
                  ),

                  ..._actions.asMap().entries.map((entry) {
                    final idx = entry.key;
                    final action = entry.value;
                    return EnergyActionBuilder(
                      key: ValueKey('action_$idx'),
                      initialAction: action,
                      availableDevices: widget.availableDevices,
                      availableScenes: widget.availableScenes,
                      onChanged: (updated) => _actions[idx] = updated,
                      onRemove: _actions.length > 1
                          ? () => setState(() => _actions.removeAt(idx))
                          : null,
                    );
                  }),

                  const SizedBox(height: 24),

                  // 5. Save Button
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: const Icon(Icons.save),
                    label: Text(isEditing ? 'Update Energy Rule' : 'Save Energy Rule'),
                    onPressed: _isSaving ? null : _saveRule,
                  ),
                ],
              ),
            ),
    );
  }
}
