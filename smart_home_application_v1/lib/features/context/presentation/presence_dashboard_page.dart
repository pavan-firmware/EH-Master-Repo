import 'package:flutter/material.dart';
import '../../../core/models/context_presence_models.dart';
import '../../../core/services/context_presence_service.dart';

class PresenceDashboardPage extends StatefulWidget {
  final String homeId;
  final ContextPresenceService service;

  const PresenceDashboardPage({
    super.key,
    required this.homeId,
    required this.service,
  });

  @override
  State<PresenceDashboardPage> createState() => _PresenceDashboardPageState();
}

class _PresenceDashboardPageState extends State<PresenceDashboardPage> {
  @override
  void initState() {
    super.initState();
    _refreshData();
  }

  Future<void> _refreshData() async {
    await widget.service.fetchPresenceSnapshot(widget.homeId);
    await widget.service.fetchHomeContext(widget.homeId);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.service,
      builder: (context, _) {
        final snapshot = widget.service.currentSnapshot;
        final homeContext = widget.service.currentContext;
        final isLoading = widget.service.isLoading;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Presence & Occupancy'),
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: _refreshData,
              ),
            ],
          ),
          body: RefreshIndicator(
            onRefresh: _refreshData,
            child: isLoading && snapshot == null
                ? const Center(child: CircularProgressIndicator())
                : ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      // 1. Whole-Home Occupancy Card
                      _buildOccupancyHeroCard(snapshot, homeContext),
                      const SizedBox(height: 16),

                      // 2. Quick Manual Presence Overrides
                      _buildQuickPresenceActions(),
                      const SizedBox(height: 20),

                      // 3. User Presence Breakdown
                      const Text(
                        'Family & Member Presence',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      _buildUserStatesList(snapshot),
                      const SizedBox(height: 20),

                      // 4. Inferred Room Presence
                      const Text(
                        'Inferred Room Occupancy',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      _buildInferredRoomsList(snapshot),
                    ],
                  ),
          ),
        );
      },
    );
  }

  Widget _buildOccupancyHeroCard(PresenceSnapshotModel? snapshot, HomeContextModel? homeContext) {
    final state = snapshot?.state ?? PresenceState.unknown;
    final confidence = snapshot?.confidence ?? 0.0;

    Color stateColor = Colors.orange;
    IconData stateIcon = Icons.help_outline;
    String stateLabel = 'UNKNOWN';

    if (state == PresenceState.home) {
      stateColor = Colors.green;
      stateIcon = Icons.home;
      stateLabel = 'HOME (OCCUPIED)';
    } else if (state == PresenceState.away) {
      stateColor = Colors.blueGrey;
      stateIcon = Icons.sensor_door_outlined;
      stateLabel = 'AWAY (EMPTY)';
    } else if (state == PresenceState.sleep) {
      stateColor = Colors.indigo;
      stateIcon = Icons.bedtime;
      stateLabel = 'SLEEPING';
    }

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: [stateColor.withValues(alpha: 0.15), stateColor.withValues(alpha: 0.05)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: stateColor,
                  radius: 28,
                  child: Icon(stateIcon, color: Colors.white, size: 30),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        stateLabel,
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: stateColor),
                      ),
                      Text(
                        'Active Members Present: ${snapshot?.activeUserCount ?? 0}',
                        style: const TextStyle(color: Colors.black87),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Reconciliation Confidence', style: TextStyle(fontSize: 12, color: Colors.black54)),
                    Text(
                      '${(confidence * 100).toStringAsFixed(0)}%',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                if (homeContext != null)
                  Chip(
                    label: Text(
                      'Mode: ${homeContext.mode.toApiValue()}',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    backgroundColor: Colors.white,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickPresenceActions() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                icon: const Icon(Icons.home_outlined),
                label: const Text("I'm Home"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green.shade700,
                  foregroundColor: Colors.white,
                ),
                onPressed: () => _submitSignal(PresenceState.home),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                icon: const Icon(Icons.sensor_door),
                label: const Text("I'm Away"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueGrey.shade700,
                  foregroundColor: Colors.white,
                ),
                onPressed: () => _submitSignal(PresenceState.away),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submitSignal(PresenceState state) async {
    final success = await widget.service.submitPresenceSignal(
      homeId: widget.homeId,
      source: PresenceSource.manual,
      state: state,
      confidence: 1.0,
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(success ? 'Presence updated to ${state.toApiValue()}' : 'Failed to update presence')),
      );
    }
  }

  Widget _buildUserStatesList(PresenceSnapshotModel? snapshot) {
    if (snapshot == null || snapshot.userStates.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('No user presence signals recorded yet.'),
        ),
      );
    }

    return Column(
      children: snapshot.userStates.entries.map((e) {
        final u = e.value;
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: u.state == PresenceState.home ? Colors.green.shade100 : Colors.blueGrey.shade100,
              child: Icon(
                u.state == PresenceState.home ? Icons.person : Icons.person_outline,
                color: u.state == PresenceState.home ? Colors.green : Colors.blueGrey,
              ),
            ),
            title: Text('User: ${u.userId}'),
            subtitle: Text(
              'State: ${u.state.toApiValue()} • Source: ${u.source.toApiValue()}${u.isStale ? ' (STALE)' : ''}',
            ),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${(u.confidence * 100).toStringAsFixed(0)}%',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  u.isStale ? 'Expired' : 'Active',
                  style: TextStyle(fontSize: 10, color: u.isStale ? Colors.red : Colors.green),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildInferredRoomsList(PresenceSnapshotModel? snapshot) {
    if (snapshot == null || snapshot.inferredRooms.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('No room telemetry available for inference.'),
        ),
      );
    }

    return Column(
      children: snapshot.inferredRooms.map((r) {
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: Icon(
              r.isOccupied ? Icons.meeting_room : Icons.no_meeting_room_outlined,
              color: r.isOccupied ? Colors.green : Colors.grey,
            ),
            title: Text('Room: ${r.roomId}'),
            subtitle: Text(r.inferenceReason.isNotEmpty ? r.inferenceReason : 'Device activity analysis'),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: r.isOccupied ? Colors.green.shade50 : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                r.isOccupied ? 'Occupied' : 'Vacant',
                style: TextStyle(
                  color: r.isOccupied ? Colors.green.shade800 : Colors.grey.shade700,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
