import 'package:flutter/material.dart';
import '../../../core/models/context_presence_models.dart';
import '../../../core/services/context_presence_service.dart';

class ContextAutomationPage extends StatefulWidget {
  final String homeId;
  final ContextPresenceService service;

  const ContextAutomationPage({
    super.key,
    required this.homeId,
    required this.service,
  });

  @override
  State<ContextAutomationPage> createState() => _ContextAutomationPageState();
}

class _ContextAutomationPageState extends State<ContextAutomationPage> {
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.service,
      builder: (context, _) {
        final homeContext = widget.service.currentContext;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Context Automations'),
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // 1. Context Trigger Rules Overview
              _buildRulesCard(homeContext),
              const SizedBox(height: 20),

              // 2. Manual Command Priority (Anti-Fighting Guard)
              _buildManualPriorityCard(),
              const SizedBox(height: 20),

              // 3. Away Energy Guard
              _buildAwayEnergyGuardCard(homeContext),
            ],
          ),
        );
      },
    );
  }

  Widget _buildRulesCard(HomeContextModel? contextModel) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.bolt, color: Colors.amber),
                SizedBox(width: 8),
                Text(
                  'Context-Aware Automation Rules',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildRuleItem('Arrive Home: Welcome Scene', 'Trigger: home_context == HOME', true),
            _buildRuleItem('Leave Home: Away Security & Eco', 'Trigger: home_context == AWAY', true),
            _buildRuleItem('Sleep Window: Night Dimming', 'Trigger: home_context == SLEEP', true),
            _buildRuleItem('Vacation Mode: Security Randomization', 'Trigger: home_context == VACATION', true),
          ],
        ),
      ),
    );
  }

  Widget _buildRuleItem(String name, String trigger, bool isActive) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                Text(trigger, style: const TextStyle(color: Colors.black54, fontSize: 11)),
              ],
            ),
          ),
          Switch(value: isActive, onChanged: (_) {}),
        ],
      ),
    );
  }

  Widget _buildManualPriorityCard() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(Icons.shield_outlined, color: Colors.blue, size: 28),
            const SizedBox(width: 16),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Manual Command Priority (Active)',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'When you manually turn a switch ON or OFF, automations targeting that switch are safely suppressed for 5 minutes to prevent automation fighting.',
                    style: TextStyle(fontSize: 12, color: Colors.black87),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAwayEnergyGuardCard(HomeContextModel? contextModel) {
    final isAway = contextModel?.mode == ContextMode.away || contextModel?.mode == ContextMode.vacation;

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.power, color: isAway ? Colors.green : Colors.grey),
                const SizedBox(width: 8),
                const Text(
                  'Away Energy Guard',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              isAway
                  ? 'Active: Monitoring home for unexpected power draw (> 500W) while home is unoccupied.'
                  : 'Standby: Guard activates automatically whenever home enters AWAY or VACATION mode.',
              style: const TextStyle(fontSize: 12, color: Colors.black87),
            ),
          ],
        ),
      ),
    );
  }
}
