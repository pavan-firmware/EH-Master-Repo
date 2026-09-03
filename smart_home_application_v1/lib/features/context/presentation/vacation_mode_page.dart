import 'package:flutter/material.dart';
import '../../../core/models/context_presence_models.dart';
import '../../../core/services/context_presence_service.dart';

class VacationModePage extends StatefulWidget {
  final String homeId;
  final ContextPresenceService service;

  const VacationModePage({
    super.key,
    required this.homeId,
    required this.service,
  });

  @override
  State<VacationModePage> createState() => _VacationModePageState();
}

class _VacationModePageState extends State<VacationModePage> {
  int _selectedDays = 7;
  final TextEditingController _reasonController = TextEditingController(text: 'Vacation Trip');

  @override
  void initState() {
    super.initState();
    widget.service.fetchHomeContext(widget.homeId);
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.service,
      builder: (context, _) {
        final currentContext = widget.service.currentContext;
        final isVacationActive = currentContext?.isVacation ?? false;
        final isLoading = widget.service.isLoading;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Vacation Mode'),
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // 1. Vacation Hero Card
              _buildVacationHeroCard(isVacationActive),
              const SizedBox(height: 20),

              if (!isVacationActive) ...[
                // 2. Configure Vacation Duration
                _buildDurationSelector(),
                const SizedBox(height: 20),

                // 3. Security & Energy Features Included
                _buildFeaturesCard(),
                const SizedBox(height: 24),

                // 4. Activate Button
                ElevatedButton.icon(
                  icon: const Icon(Icons.beach_access),
                  label: Text(isLoading ? 'Activating...' : 'Activate Vacation Mode'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepOrange,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: isLoading ? null : _activateVacation,
                ),
              ] else ...[
                // 5. Active Vacation Controls
                _buildActiveVacationDetails(currentContext),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  icon: const Icon(Icons.home),
                  label: const Text('End Vacation Mode & Return Home'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.shade700,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _endVacation,
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildVacationHeroCard(bool isActive) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: isActive
                ? [Colors.deepOrange.withValues(alpha: 0.2), Colors.deepOrange.withValues(alpha: 0.05)]
                : [Colors.blueGrey.withValues(alpha: 0.1), Colors.blueGrey.withValues(alpha: 0.05)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: isActive ? Colors.deepOrange : Colors.blueGrey,
              radius: 28,
              child: Icon(isActive ? Icons.beach_access : Icons.flight_takeoff, color: Colors.white, size: 30),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isActive ? 'Vacation Mode ACTIVE' : 'Vacation Protection',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isActive ? Colors.deepOrange : Colors.blueGrey,
                    ),
                  ),
                  Text(
                    isActive
                      ? 'Home security & energy optimizations are running.'
                      : 'Simulate presence and minimize power consumption while away.',
                    style: const TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDurationSelector() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Trip Duration (Days)', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('$_selectedDays Days', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.deepOrange)),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.remove_circle_outline),
                      onPressed: _selectedDays > 1 ? () => setState(() => _selectedDays--) : null,
                    ),
                    IconButton(
                      icon: const Icon(Icons.add_circle_outline),
                      onPressed: _selectedDays < 60 ? () => setState(() => _selectedDays++) : null,
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _reasonController,
              decoration: const InputDecoration(
                labelText: 'Trip Note / Reason',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeaturesCard() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Vacation Guard Features', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            _buildFeatureRow(Icons.lightbulb_outline, 'Smart Presence Simulation (Random light toggles)'),
            _buildFeatureRow(Icons.eco, 'Standby Energy Reduction (HVAC / Charger Eco mode)'),
            _buildFeatureRow(Icons.security, 'Perimeter Intrusion Alert Guard'),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureRow(IconData icon, String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.deepOrange),
          const SizedBox(width: 8),
          Expanded(child: Text(label, style: const TextStyle(fontSize: 12))),
        ],
      ),
    );
  }

  Widget _buildActiveVacationDetails(HomeContextModel? model) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Vacation Mode Status', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('Reason: ${model?.activeOverride?.reason ?? 'Vacation Trip'}'),
            if (model?.activeOverride?.expiresAt != null)
              Text('Expires: ${model!.activeOverride!.expiresAt!.toLocal()}'),
          ],
        ),
      ),
    );
  }

  Future<void> _activateVacation() async {
    final success = await widget.service.setVacationMode(
      widget.homeId,
      durationDays: _selectedDays,
      reason: _reasonController.text.trim(),
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(success ? 'Vacation Mode Enabled' : 'Failed to enable vacation mode')),
      );
    }
  }

  Future<void> _endVacation() async {
    final success = await widget.service.clearContextOverride(widget.homeId);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(success ? 'Vacation mode ended. Welcome home!' : 'Failed to end vacation mode')),
      );
    }
  }
}
