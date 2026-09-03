import 'package:flutter/material.dart';
import '../../../core/models/energy_automation_models.dart';

/// EH Home — Energy Action Builder Widget (Phase 20)
class EnergyActionBuilder extends StatefulWidget {
  final EnergyActionModel initialAction;
  final ValueChanged<EnergyActionModel> onChanged;
  final VoidCallback? onRemove;
  final List<Map<String, String>> availableDevices;
  final List<Map<String, String>> availableScenes;

  const EnergyActionBuilder({
    super.key,
    required this.initialAction,
    required this.onChanged,
    this.onRemove,
    this.availableDevices = const [],
    this.availableScenes = const [],
  });

  @override
  State<EnergyActionBuilder> createState() => _EnergyActionBuilderState();
}

class _EnergyActionBuilderState extends State<EnergyActionBuilder> {
  late String _actionType;
  String? _deviceId;
  int _channelIndex = 1;
  String _command = 'setPower';
  bool _powerState = false;
  String? _sceneId;
  int? _delaySeconds;

  @override
  void initState() {
    super.initState();
    _actionType = widget.initialAction.actionType;
    _deviceId = widget.initialAction.deviceId;
    _channelIndex = widget.initialAction.channelIndex ?? 1;
    _command = widget.initialAction.command ?? 'setPower';
    _powerState = widget.initialAction.params?['value'] == true || widget.initialAction.params?['power'] == true;
    _sceneId = widget.initialAction.sceneId;
    _delaySeconds = widget.initialAction.delaySeconds;
  }

  void _notifyChanges() {
    final updated = EnergyActionModel(
      actionType: _actionType,
      deviceId: _actionType == 'device_command' ? _deviceId : null,
      channelIndex: _actionType == 'device_command' ? _channelIndex : null,
      command: _actionType == 'device_command' ? _command : null,
      params: _actionType == 'device_command' ? {'value': _powerState, 'power': _powerState} : null,
      sceneId: _actionType == 'trigger_scene' ? _sceneId : null,
      delaySeconds: _delaySeconds,
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
                    const Icon(Icons.flash_on, color: Colors.teal, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Action to Execute',
                      style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                if (widget.onRemove != null)
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                    onPressed: widget.onRemove,
                    tooltip: 'Remove Action',
                  ),
              ],
            ),
            const Divider(),
            const SizedBox(height: 8),

            // 1. Action Type Selector
            DropdownButtonFormField<String>(
              initialValue: _actionType,
              decoration: const InputDecoration(
                labelText: 'Action Type',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              items: const [
                DropdownMenuItem(value: 'device_command', child: Text('Send Device Command (e.g. Turn OFF)')),
                DropdownMenuItem(value: 'trigger_scene', child: Text('Activate Scene (e.g. Eco Mode)')),
              ],
              onChanged: (val) {
                if (val != null) {
                  setState(() => _actionType = val);
                  _notifyChanges();
                }
              },
            ),
            const SizedBox(height: 12),

            // 2. Device Command Inputs
            if (_actionType == 'device_command') ...[
              DropdownButtonFormField<String?>(
                initialValue: _deviceId,
                decoration: const InputDecoration(
                  labelText: 'Target Device',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                items: widget.availableDevices.map((d) {
                  return DropdownMenuItem(value: d['id'], child: Text(d['name'] ?? d['id']!));
                }).toList(),
                onChanged: (val) {
                  setState(() => _deviceId = val);
                  _notifyChanges();
                },
              ),
              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<bool>(
                      initialValue: _powerState,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Power State',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      items: const [
                        DropdownMenuItem(value: false, child: Text('Turn OFF')),
                        DropdownMenuItem(value: true, child: Text('Turn ON')),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setState(() => _powerState = val);
                          _notifyChanges();
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      initialValue: _channelIndex,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Channel',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      items: const [
                        DropdownMenuItem(value: 1, child: Text('CH 1')),
                        DropdownMenuItem(value: 2, child: Text('CH 2')),
                        DropdownMenuItem(value: 3, child: Text('CH 3')),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setState(() => _channelIndex = val);
                          _notifyChanges();
                        }
                      },
                    ),
                  ),
                ],
              ),
            ],

            // 3. Scene Trigger Inputs
            if (_actionType == 'trigger_scene') ...[
              DropdownButtonFormField<String?>(
                initialValue: _sceneId,
                decoration: const InputDecoration(
                  labelText: 'Target Scene',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                items: widget.availableScenes.map((s) {
                  return DropdownMenuItem(value: s['id'], child: Text(s['name'] ?? s['id']!));
                }).toList(),
                onChanged: (val) {
                  setState(() => _sceneId = val);
                  _notifyChanges();
                },
              ),
            ],

            const SizedBox(height: 12),

            // 4. Delay Seconds (Optional)
            DropdownButtonFormField<int?>(
              initialValue: _delaySeconds,
              decoration: const InputDecoration(
                labelText: 'Execution Delay (Optional)',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              items: const [
                DropdownMenuItem(value: null, child: Text('Immediate (0s)')),
                DropdownMenuItem(value: 5, child: Text('5 seconds delay')),
                DropdownMenuItem(value: 30, child: Text('30 seconds delay')),
                DropdownMenuItem(value: 60, child: Text('1 minute delay')),
                DropdownMenuItem(value: 300, child: Text('5 minutes delay')),
              ],
              onChanged: (val) {
                setState(() => _delaySeconds = val);
                _notifyChanges();
              },
            ),
          ],
        ),
      ),
    );
  }
}
