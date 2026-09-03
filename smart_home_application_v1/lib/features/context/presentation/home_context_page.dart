import 'package:flutter/material.dart';
import '../../../core/models/context_presence_models.dart';
import '../../../core/services/context_presence_service.dart';

class HomeContextPage extends StatefulWidget {
  final String homeId;
  final ContextPresenceService service;

  const HomeContextPage({
    super.key,
    required this.homeId,
    required this.service,
  });

  @override
  State<HomeContextPage> createState() => _HomeContextPageState();
}

class _HomeContextPageState extends State<HomeContextPage> {
  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    await widget.service.fetchHomeContext(widget.homeId);
    await widget.service.fetchTransitions(widget.homeId);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.service,
      builder: (context, _) {
        final currentContext = widget.service.currentContext;
        final transitions = widget.service.transitions;
        final isLoading = widget.service.isLoading;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Home Context & Modes'),
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: _refresh,
              ),
            ],
          ),
          body: RefreshIndicator(
            onRefresh: _refresh,
            child: isLoading && currentContext == null
                ? const Center(child: CircularProgressIndicator())
                : ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      // 1. Context Hero Card
                      _buildCurrentContextCard(currentContext),
                      const SizedBox(height: 20),

                      // 2. Mode Selector Chips
                      const Text(
                        'Set Home Context Mode',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 10),
                      _buildModeSelector(currentContext?.mode),
                      const SizedBox(height: 20),

                      // 3. Precedence Hierarchy Legend
                      _buildPrecedenceCard(currentContext?.precedenceTier),
                      const SizedBox(height: 20),

                      // 4. Transitions Timeline
                      const Text(
                        'Context Transitions History',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 10),
                      _buildTransitionsList(transitions),
                    ],
                  ),
          ),
        );
      },
    );
  }

  Widget _buildCurrentContextCard(HomeContextModel? contextModel) {
    final mode = contextModel?.mode ?? ContextMode.home;
    final precedence = contextModel?.precedenceTier ?? PrecedenceTier.defaultFallback;
    final isOverride = precedence == PrecedenceTier.manualOverride;

    Color color = Colors.blue;
    IconData icon = Icons.home;

    switch (mode) {
      case ContextMode.home:
        color = Colors.green;
        icon = Icons.home;
        break;
      case ContextMode.away:
        color = Colors.blueGrey;
        icon = Icons.exit_to_app;
        break;
      case ContextMode.sleep:
        color = Colors.indigo;
        icon = Icons.nightlight_round;
        break;
      case ContextMode.vacation:
        color = Colors.deepOrange;
        icon = Icons.beach_access;
        break;
      case ContextMode.guest:
        color = Colors.purple;
        icon = Icons.people_outline;
        break;
      case ContextMode.quietHours:
        color = Colors.teal;
        icon = Icons.volume_off;
        break;
    }

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: [color.withValues(alpha: 0.2), color.withValues(alpha: 0.05)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: color,
                  radius: 26,
                  child: Icon(icon, color: Colors.white, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        mode.toApiValue(),
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color),
                      ),
                      Text(
                        isOverride ? 'Manual Override Active' : 'Automatic Reconciled State',
                        style: const TextStyle(color: Colors.black54),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (isOverride) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, color: Colors.orange, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        contextModel?.activeOverride?.reason.isNotEmpty == true
                            ? 'Reason: ${contextModel!.activeOverride!.reason}'
                            : 'Manual override suppresses automatic presence reconciliation.',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                    TextButton(
                      onPressed: _clearOverride,
                      child: const Text('Clear', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildModeSelector(ContextMode? activeMode) {
    final modes = ContextMode.values;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: modes.map((m) {
        final isSelected = m == activeMode;
        return ChoiceChip(
          label: Text(m.toApiValue()),
          selected: isSelected,
          onSelected: (selected) {
            if (selected) _selectMode(m);
          },
        );
      }).toList(),
    );
  }

  Future<void> _selectMode(ContextMode mode) async {
    final success = await widget.service.setQuickMode(widget.homeId, mode);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(success ? 'Context set to ${mode.toApiValue()}' : 'Failed to set mode')),
      );
    }
  }

  Future<void> _clearOverride() async {
    final success = await widget.service.clearContextOverride(widget.homeId);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(success ? 'Override cleared' : 'Failed to clear override')),
      );
    }
  }

  Widget _buildPrecedenceCard(PrecedenceTier? tier) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Precedence State Machine Hierarchy',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            _buildTierRow('1. Manual Overrides (Highest)', tier == PrecedenceTier.manualOverride),
            _buildTierRow('2. Scheduled Windows (Quiet/Sleep)', tier == PrecedenceTier.scheduledWindow),
            _buildTierRow('3. Reconciled Presence (Sensors/App)', tier == PrecedenceTier.reconciledPresence),
            _buildTierRow('4. Default Fallback (Baseline)', tier == PrecedenceTier.defaultFallback),
          ],
        ),
      ),
    );
  }

  Widget _buildTierRow(String title, bool isCurrent) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(
            isCurrent ? Icons.check_circle : Icons.radio_button_unchecked,
            size: 16,
            color: isCurrent ? Colors.green : Colors.grey,
          ),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
              color: isCurrent ? Colors.green.shade800 : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransitionsList(List<ContextTransitionModel> transitions) {
    if (transitions.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('No transitions recorded yet.'),
        ),
      );
    }

    return Column(
      children: transitions.take(10).map((t) {
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: const Icon(Icons.swap_horiz, color: Colors.blue),
            title: Text('${t.fromMode?.toApiValue() ?? 'INITIAL'} → ${t.toMode.toApiValue()}'),
            subtitle: Text('Source: ${t.triggerSource}\n${t.reason}'),
            isThreeLine: true,
            trailing: Text(
              '${t.createdAt.hour.toString().padLeft(2, '0')}:${t.createdAt.minute.toString().padLeft(2, '0')}',
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ),
        );
      }).toList(),
    );
  }
}
