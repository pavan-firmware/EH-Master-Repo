import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../settings/presentation/settings_ui.dart';
import '../../data/hub_repository.dart';
import '../../domain/models/hub_models.dart';
import 'hub_ui_helpers.dart';

class HubAutomationsScreen extends StatefulWidget {
  const HubAutomationsScreen({
    super.key,
    required this.repository,
    required this.hubState,
  });

  final HubRepository repository;
  final HubState hubState;

  @override
  State<HubAutomationsScreen> createState() => _HubAutomationsScreenState();
}

class _HubAutomationsScreenState extends State<HubAutomationsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  List<Map<String, dynamic>> _routines = [];
  List<HubActiveTimer> _timers = [];
  List<CrossDeviceRule> _rules = [];
  List<AutomationExecutionLog> _logs = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
    _loadAll();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    final host = widget.hubState.hostname;
    final results = await Future.wait([
      widget.repository.getRoutines(hubHostname: host),
      widget.repository.getActiveHubTimers(hubHostname: host),
      widget.repository.getCrossDeviceRules(hubHostname: host),
      widget.repository.getExecutionLogs(hubHostname: host),
    ]);
    if (!mounted) return;
    setState(() {
      _routines = results[0] as List<Map<String, dynamic>>;
      _timers = results[1] as List<HubActiveTimer>;
      _rules = results[2] as List<CrossDeviceRule>;
      _logs = results[3] as List<AutomationExecutionLog>;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.ehColors;

    return Scaffold(
      backgroundColor: tokens.bgApp,
      appBar: AppBar(
        backgroundColor: tokens.bgApp,
        elevation: 0,
        title: Text(
          'Hub Automations & Rules',
          style: TextStyle(color: tokens.textPrimary, fontWeight: FontWeight.w800, fontSize: 18),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh_rounded, color: tokens.headerAction),
            onPressed: _loadAll,
          ),
        ],
        bottom: TabBar(
          controller: _tabCtrl,
          labelColor: tokens.bluePrimary,
          unselectedLabelColor: tokens.textSecondary,
          tabs: [
            Tab(text: 'Schedules (${_routines.length})'),
            Tab(text: 'Fast Rules (${_rules.length})'),
            Tab(text: 'Logs (${_logs.length})'),
          ],
        ),
      ),
      floatingActionButton: ListenableBuilder(
        listenable: _tabCtrl,
        builder: (_, _) {
          if (_tabCtrl.index == 0) {
            return FloatingActionButton.extended(
              onPressed: () => _openRoutineEditorDialog(null),
              icon: const Icon(Icons.add_alarm_rounded),
              label: const Text('New Schedule'),
            );
          }
          if (_tabCtrl.index == 1) {
            return FloatingActionButton.extended(
              onPressed: () => _openRuleEditorDialog(null),
              icon: const Icon(Icons.bolt_rounded),
              label: const Text('New Rule'),
            );
          }
          return const SizedBox.shrink();
        },
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator.adaptive())
          : TabBarView(
              controller: _tabCtrl,
              children: [
                _buildSchedulesTab(tokens),
                _buildRulesTab(tokens),
                _buildLogsTab(tokens),
              ],
            ),
    );
  }

  Widget _buildSchedulesTab(EHThemeTokens tokens) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 90),
      children: [
        if (_timers.isNotEmpty) ...[
          SettingsSectionTitle('Active Auto-Off Countdowns (${_timers.length})'),
          SettingsSurface(
            child: Column(
              children: [
                for (int i = 0; i < _timers.length; i++) ...[
                  if (i > 0) const Divider(height: 1),
                  ListTile(
                    leading: Icon(Icons.timer_rounded, color: tokens.warning),
                    title: Text(_timers[i].routineName, style: const TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: Text('Device ${_timers[i].deviceId} • CH${_timers[i].channel} • ${_timers[i].remainingSec}s remaining'),
                    trailing: TextButton(
                      onPressed: () async {
                        await widget.repository.cancelHubTimer(
                          hubHostname: widget.hubState.hostname,
                          timerId: _timers[i].id,
                        );
                        await _loadAll();
                      },
                      child: const Text('Cancel', style: TextStyle(color: Color(0xFFEF4444))),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 18),
        ],
        SettingsSectionTitle('Hub Schedules (${_routines.length})'),
        if (_routines.isEmpty)
          _emptyBox(tokens, Icons.schedule_rounded, 'No Hub schedules configured yet. Tap "New Schedule" below.')
        else
          SettingsSurface(
            child: Column(
              children: [
                for (int i = 0; i < _routines.length; i++) ...[
                  if (i > 0) const Divider(height: 1),
                  _buildRoutineRow(tokens, _routines[i]),
                ],
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildRoutineRow(EHThemeTokens tokens, Map<String, dynamic> rt) {
    final id = rt['id']?.toString() ?? '';
    final name = rt['name']?.toString() ?? 'Schedule';
    final enabled = rt['enabled'] != false;
    final hr = (rt['hour'] as num?)?.toInt() ?? 6;
    final min = (rt['minute'] as num?)?.toInt() ?? 0;
    final ch = (rt['channel'] as num?)?.toInt() ?? 1;
    final durSec = (rt['durationSec'] as num?)?.toInt() ?? 0;
    final isToggle = rt['isToggle'] == true;
    final timeStr = '${hr.toString().padLeft(2, '0')}:${min.toString().padLeft(2, '0')}';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: tokens.textPrimary)),
                    Text(
                      '$timeStr • CH$ch (${isToggle ? "Toggle" : (rt['targetState'] == false ? "OFF" : "ON")})${durSec > 0 ? " • ${durSec}s timer" : ""}',
                      style: TextStyle(fontSize: 11.5, color: tokens.textSecondary),
                    ),
                  ],
                ),
              ),
              Switch(
                value: enabled,
                activeThumbColor: tokens.bluePrimary,
                onChanged: (val) async {
                  await widget.repository.upsertHubRoutine(
                    hubHostname: widget.hubState.hostname,
                    routinePayload: {...rt, 'enabled': val},
                  );
                  await _loadAll();
                },
              ),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton.icon(
                onPressed: () async {
                  await widget.repository.triggerRoutine(hubHostname: widget.hubState.hostname, routineId: id);
                  await _loadAll();
                },
                icon: const Icon(Icons.play_arrow_rounded, size: 16),
                label: const Text('Run Now'),
              ),
              TextButton.icon(
                onPressed: () => _openRoutineEditorDialog(rt),
                icon: const Icon(Icons.edit_outlined, size: 16),
                label: const Text('Edit'),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFEF4444), size: 18),
                tooltip: 'Delete Schedule',
                onPressed: () async {
                  await widget.repository.deleteHubRoutine(hubHostname: widget.hubState.hostname, routineId: id);
                  await _loadAll();
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRulesTab(EHThemeTokens tokens) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 90),
      children: [
        if (_rules.isEmpty)
          _emptyBox(tokens, Icons.alt_route_rounded, 'No cross-device Fast-Path rules yet. Tap "New Rule" to create one.')
        else
          SettingsSurface(
            child: Column(
              children: [
                for (int i = 0; i < _rules.length; i++) ...[
                  if (i > 0) const Divider(height: 1),
                  _buildRuleRow(tokens, _rules[i]),
                ],
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildRuleRow(EHThemeTokens tokens, CrossDeviceRule rule) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(rule.name, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: tokens.textPrimary)),
                    const SizedBox(height: 2),
                    Text(
                      'IF ${rule.triggerDeviceId} CH${rule.triggerChannel} -> THEN ${rule.actionDeviceId} CH${rule.actionChannel} (${rule.actionCommand})',
                      style: TextStyle(fontSize: 11, fontFamily: 'monospace', color: tokens.textSecondary),
                    ),
                  ],
                ),
              ),
              Switch(
                value: rule.enabled,
                activeThumbColor: tokens.bluePrimary,
                onChanged: (val) async {
                  await widget.repository.saveCrossDeviceRule(
                    hubHostname: widget.hubState.hostname,
                    rule: rule.copyWith(enabled: val),
                  );
                  await _loadAll();
                },
              ),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              OutlinedButton.icon(
                onPressed: () async {
                  final res = await widget.repository.testCrossDeviceRule(
                    hubHostname: widget.hubState.hostname,
                    ruleId: rule.id,
                  );
                  if (mounted && res != null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Test fired in ${res['execution']?['latencyMs'] ?? 0}ms')),
                    );
                  }
                  await _loadAll();
                },
                icon: const Icon(Icons.play_arrow_rounded, size: 14),
                label: const Text('Test'),
              ),
              const SizedBox(width: 6),
              TextButton.icon(
                onPressed: () => _openRuleEditorDialog(rule),
                icon: const Icon(Icons.edit_outlined, size: 16),
                label: const Text('Edit'),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFEF4444), size: 18),
                tooltip: 'Delete Rule',
                onPressed: () async {
                  await widget.repository.deleteCrossDeviceRule(
                    hubHostname: widget.hubState.hostname,
                    ruleId: rule.id,
                  );
                  await _loadAll();
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLogsTab(EHThemeTokens tokens) {
    if (_logs.isEmpty) {
      return Center(child: _emptyBox(tokens, Icons.history_rounded, 'No execution audit logs recorded yet.'));
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _logs.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (_, i) {
        final log = _logs[i];
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: tokens.surfaceCard,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: tokens.borderSubtle),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(log.actionSummary, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5, color: tokens.textPrimary)),
                    Text('${log.triggerEvent} • ${log.status}', style: TextStyle(fontSize: 11, color: tokens.textSecondary)),
                  ],
                ),
              ),
              SettingsStatusChip(
                label: '${log.latencyMs}ms',
                color: tokens.bluePrimary,
                background: tokens.iconBgBlue,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _emptyBox(EHThemeTokens tokens, IconData icon, String msg) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: tokens.surfaceCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: tokens.borderSubtle),
      ),
      child: Row(
        children: [
          Icon(icon, color: tokens.bluePrimary),
          const SizedBox(width: 12),
          Expanded(child: Text(msg, style: TextStyle(fontSize: 12.5, color: tokens.textSecondary))),
        ],
      ),
    );
  }

  Future<void> _openRoutineEditorDialog(Map<String, dynamic>? existing) async {
    final devices = widget.hubState.connectedDevices;
    if (devices.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Adopt a controllable device on the Hub first.')),
      );
      return;
    }
    final nameCtrl = TextEditingController(text: existing?['name']?.toString() ?? 'Morning Schedule');
    String devId = existing?['deviceId']?.toString() ?? devices.first.id;
    if (!devices.any((d) => d.id == devId)) devId = devices.first.id;
    int ch = (existing?['channel'] as num?)?.toInt() ?? 1;
    int hour = (existing?['hour'] as num?)?.toInt() ?? 7;
    int minute = (existing?['minute'] as num?)?.toInt() ?? 0;
    int durationSec = (existing?['durationSec'] as num?)?.toInt() ?? 0;
    bool isToggle = existing?['isToggle'] == true;
    bool targetState = existing?['targetState'] != false;
    bool critical = existing?['criticalHardwareFallback'] == true;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          title: Text(existing == null ? 'Create Hub Schedule' : 'Edit Hub Schedule'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Name', border: OutlineInputBorder(), isDense: true)),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: devId,
                  decoration: const InputDecoration(labelText: 'Target Device', border: OutlineInputBorder(), isDense: true),
                  items: devices.map((d) => DropdownMenuItem(value: d.id, child: Text(HubUiHelpers.resolveFullDeviceName(d)))).toList(),
                  onChanged: (v) { if (v != null) setDlg(() => devId = v); },
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        initialValue: ch,
                        decoration: const InputDecoration(labelText: 'Channel', border: OutlineInputBorder(), isDense: true),
                        items: [1, 2, 3, 4].map((c) => DropdownMenuItem(value: c, child: Text('CH$c'))).toList(),
                        onChanged: (v) { if (v != null) setDlg(() => ch = v); },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () async {
                          final picked = await showTimePicker(context: ctx, initialTime: TimeOfDay(hour: hour, minute: minute));
                          if (picked != null) setDlg(() { hour = picked.hour; minute = picked.minute; });
                        },
                        child: Text('${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: isToggle ? 'TOGGLE' : (targetState ? 'ON' : 'OFF'),
                  decoration: const InputDecoration(labelText: 'Action', border: OutlineInputBorder(), isDense: true),
                  items: const [
                    DropdownMenuItem(value: 'ON', child: Text('Turn ON')),
                    DropdownMenuItem(value: 'OFF', child: Text('Turn OFF')),
                    DropdownMenuItem(value: 'TOGGLE', child: Text('Toggle')),
                  ],
                  onChanged: (v) => setDlg(() {
                    isToggle = v == 'TOGGLE';
                    targetState = v == 'ON';
                  }),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<int>(
                  initialValue: durationSec,
                  decoration: const InputDecoration(labelText: 'Auto-Off Duration', border: OutlineInputBorder(), isDense: true),
                  items: const [
                    DropdownMenuItem(value: 0, child: Text('No Auto-Off')),
                    DropdownMenuItem(value: 60, child: Text('1 minute')),
                    DropdownMenuItem(value: 300, child: Text('5 minutes')),
                    DropdownMenuItem(value: 900, child: Text('15 minutes')),
                    DropdownMenuItem(value: 1800, child: Text('30 minutes')),
                  ],
                  onChanged: (v) { if (v != null) setDlg(() => durationSec = v); },
                ),
                SwitchListTile(
                  title: const Text('Critical Offline Fallback'),
                  value: critical,
                  onChanged: (v) => setDlg(() => critical = v),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton(
              onPressed: () async {
                await widget.repository.upsertHubRoutine(
                  hubHostname: widget.hubState.hostname,
                  routinePayload: {
                    if (existing != null && existing['id'] != null) 'id': existing['id'],
                    'name': nameCtrl.text.trim().isEmpty ? 'Hub Schedule' : nameCtrl.text.trim(),
                    'deviceId': devId,
                    'channel': ch,
                    'targetState': targetState,
                    'isToggle': isToggle,
                    'hour': hour,
                    'minute': minute,
                    'daysMask': existing?['daysMask'] ?? 0x7F,
                    'durationSec': durationSec,
                    'enabled': existing?['enabled'] ?? true,
                    'criticalHardwareFallback': critical,
                  },
                );
                if (ctx.mounted) Navigator.pop(ctx);
                await _loadAll();
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openRuleEditorDialog(CrossDeviceRule? existing) async {
    final devices = widget.hubState.connectedDevices;
    if (devices.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No adopted devices available. Scan & adopt devices first.')),
      );
      return;
    }
    String triggerDevId = existing?.triggerDeviceId ?? devices.first.id;
    if (!devices.any((d) => d.id == triggerDevId)) triggerDevId = devices.first.id;
    int triggerCh = existing?.triggerChannel ?? 1;
    String actionDevId = existing?.actionDeviceId ?? (devices.length > 1 ? devices[1].id : devices.first.id);
    if (!devices.any((d) => d.id == actionDevId)) actionDevId = devices.first.id;
    int actionCh = existing?.actionChannel ?? 1;
    String actionCmd = existing?.actionCommand ?? 'TOGGLE';
    final nameController = TextEditingController(text: existing?.name ?? 'Cross-Device Fast-Path Link');

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          title: Text(existing == null ? 'Create Cross-Device Rule' : 'Edit Cross-Device Rule'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Rule Name', border: OutlineInputBorder(), isDense: true),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: triggerDevId,
                  isDense: true,
                  decoration: const InputDecoration(labelText: 'WHEN Trigger Device', border: OutlineInputBorder()),
                  items: devices.map((d) => DropdownMenuItem(value: d.id, child: Text(HubUiHelpers.resolveFullDeviceName(d)))).toList(),
                  onChanged: (v) => setDlgState(() => triggerDevId = v!),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<int>(
                  initialValue: triggerCh,
                  isDense: true,
                  decoration: const InputDecoration(labelText: 'Trigger Channel', border: OutlineInputBorder()),
                  items: [1, 2, 3, 4].map((ch) => DropdownMenuItem(value: ch, child: Text('Channel $ch'))).toList(),
                  onChanged: (v) => setDlgState(() => triggerCh = v!),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: actionDevId,
                  isDense: true,
                  decoration: const InputDecoration(labelText: 'THEN Target Device', border: OutlineInputBorder()),
                  items: devices.map((d) => DropdownMenuItem(value: d.id, child: Text(HubUiHelpers.resolveFullDeviceName(d)))).toList(),
                  onChanged: (v) => setDlgState(() => actionDevId = v!),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        initialValue: actionCh,
                        isDense: true,
                        decoration: const InputDecoration(labelText: 'Channel', border: OutlineInputBorder()),
                        items: [1, 2, 3, 4].map((ch) => DropdownMenuItem(value: ch, child: Text('CH$ch'))).toList(),
                        onChanged: (v) => setDlgState(() => actionCh = v!),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: actionCmd,
                        isDense: true,
                        decoration: const InputDecoration(labelText: 'Action', border: OutlineInputBorder()),
                        items: const [
                          DropdownMenuItem(value: 'TOGGLE', child: Text('TOGGLE')),
                          DropdownMenuItem(value: 'ON', child: Text('TURN ON')),
                          DropdownMenuItem(value: 'OFF', child: Text('TURN OFF')),
                        ],
                        onChanged: (v) => setDlgState(() => actionCmd = v!),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton(
              onPressed: () async {
                final targetDev = devices.firstWhere((d) => d.id == actionDevId, orElse: () => devices.first);
                final rule = CrossDeviceRule(
                  id: existing?.id ?? 'rule_${DateTime.now().millisecondsSinceEpoch}',
                  name: nameController.text.trim().isEmpty ? 'Cross-Device Rule' : nameController.text.trim(),
                  enabled: existing?.enabled ?? true,
                  triggerDeviceId: triggerDevId,
                  triggerChannel: triggerCh,
                  triggerState: existing?.triggerState ?? true,
                  actionDeviceId: actionDevId,
                  actionDeviceIp: targetDev.ipAddress,
                  actionChannel: actionCh,
                  actionCommand: actionCmd,
                );
                await widget.repository.saveCrossDeviceRule(hubHostname: widget.hubState.hostname, rule: rule);
                if (ctx.mounted) Navigator.pop(ctx);
                await _loadAll();
              },
              child: const Text('Save Rule'),
            ),
          ],
        ),
      ),
    );
  }
}
