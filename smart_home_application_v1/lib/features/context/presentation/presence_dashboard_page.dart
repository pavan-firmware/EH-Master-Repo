import 'package:flutter/material.dart';
import '../../../core/models/context_presence_models.dart';
import '../../../core/services/context_presence_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/eh_action_button.dart';

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
  bool _isSubmittingHome = false;
  bool _isSubmittingAway = false;

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
    final tokens = context.ehColors;
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
                      _buildOccupancyHeroCard(context, snapshot, homeContext, tokens),
                      const SizedBox(height: 16),

                      // 2. Quick Manual Presence Overrides
                      _buildQuickPresenceActions(context, snapshot?.state, tokens),
                      const SizedBox(height: 20),

                      // 3. User Presence Breakdown
                      Text(
                        'Family & Member Presence',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: tokens.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _buildUserStatesList(context, snapshot, tokens),
                      const SizedBox(height: 20),

                      // 4. Inferred Room Presence
                      Text(
                        'Inferred Room Occupancy',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: tokens.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _buildInferredRoomsList(context, snapshot, tokens),
                    ],
                  ),
          ),
        );
      },
    );
  }

  Widget _buildOccupancyHeroCard(
    BuildContext context,
    PresenceSnapshotModel? snapshot,
    HomeContextModel? homeContext,
    EHThemeTokens tokens,
  ) {
    final state = snapshot?.state ?? PresenceState.unknown;
    final confidence = snapshot?.confidence ?? 0.0;

    Color stateColor = tokens.warning;
    IconData stateIcon = Icons.help_outline_rounded;
    String stateLabel = 'UNKNOWN';

    if (state == PresenceState.home) {
      stateColor = tokens.success;
      stateIcon = Icons.home_rounded;
      stateLabel = 'HOME (OCCUPIED)';
    } else if (state == PresenceState.away) {
      stateColor = tokens.isDark ? Colors.blueGrey.shade300 : Colors.blueGrey;
      stateIcon = Icons.sensor_door_outlined;
      stateLabel = 'AWAY (EMPTY)';
    } else if (state == PresenceState.sleep) {
      stateColor = tokens.isDark ? const Color(0xFF9FA8DA) : Colors.indigo;
      stateIcon = Icons.bedtime_rounded;
      stateLabel = 'SLEEPING';
    }

    return Card(
      elevation: 3,
      color: tokens.surfaceCard,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: tokens.borderControl),
      ),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: [
              stateColor.withValues(alpha: tokens.isDark ? 0.22 : 0.12),
              stateColor.withValues(alpha: tokens.isDark ? 0.06 : 0.02),
            ],
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
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: stateColor,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Active Members Present: ${snapshot?.activeUserCount ?? 0}',
                        style: TextStyle(
                          color: tokens.textSecondary,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            Divider(height: 24, color: tokens.borderControl),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Reconciliation Confidence',
                      style: TextStyle(fontSize: 12, color: tokens.textSecondary),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${(confidence * 100).toStringAsFixed(0)}%',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: tokens.textPrimary,
                      ),
                    ),
                  ],
                ),
                if (homeContext != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: tokens.isDark
                          ? tokens.surfaceCard
                          : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: tokens.borderControl),
                    ),
                    child: Text(
                      'Mode: ${homeContext.mode.toApiValue()}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: tokens.textPrimary,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickPresenceActions(
    BuildContext context,
    PresenceState? currentState,
    EHThemeTokens tokens,
  ) {
    final isHome = currentState == PresenceState.home;
    final isAway = currentState == PresenceState.away;

    return Card(
      elevation: 2,
      color: tokens.surfaceCard,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: tokens.borderControl),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.touch_app_rounded, size: 16, color: tokens.textSecondary),
                const SizedBox(width: 6),
                Text(
                  'Manual App Override',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: tokens.textSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: EHSelectionButton(
                    label: 'Home',
                    icon: isHome ? Icons.check_circle_rounded : Icons.home_rounded,
                    isSelected: isHome,
                    isLoading: _isSubmittingHome,
                    selectedBackgroundColor: tokens.success,
                    selectedForegroundColor: Colors.white,
                    onPressed: () => _submitSignal(PresenceState.home),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: EHSelectionButton(
                    label: 'Away',
                    icon: isAway ? Icons.check_circle_rounded : Icons.exit_to_app_rounded,
                    isSelected: isAway,
                    isLoading: _isSubmittingAway,
                    selectedBackgroundColor: tokens.bluePrimary,
                    selectedForegroundColor: Colors.white,
                    onPressed: () => _submitSignal(PresenceState.away),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submitSignal(PresenceState state) async {
    if (_isSubmittingHome || _isSubmittingAway) return;

    setState(() {
      if (state == PresenceState.home) {
        _isSubmittingHome = true;
      } else {
        _isSubmittingAway = true;
      }
    });

    final success = await widget.service.submitPresenceSignal(
      homeId: widget.homeId,
      source: PresenceSource.mobileApp,
      state: state,
      confidence: 1.0,
    );

    if (!mounted) return;

    setState(() {
      _isSubmittingHome = false;
      _isSubmittingAway = false;
    });

    if (success) {
      await _refreshData();
    }

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? 'Presence updated to ${state.toApiValue()}'
              : (widget.service.errorMessage ?? 'Failed to update presence'),
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Widget _buildUserStatesList(
    BuildContext context,
    PresenceSnapshotModel? snapshot,
    EHThemeTokens tokens,
  ) {
    if (snapshot == null || snapshot.userStates.isEmpty) {
      return Card(
        color: tokens.surfaceCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: tokens.borderControl),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'No user presence signals recorded yet.',
            style: TextStyle(color: tokens.textSecondary),
          ),
        ),
      );
    }

    return Column(
      children: snapshot.userStates.entries.map((e) {
        final u = e.value;
        final isHome = u.state == PresenceState.home;
        return Card(
          color: tokens.surfaceCard,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: tokens.borderControl),
          ),
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: isHome
                  ? (tokens.isDark ? const Color(0xFF1E3A2F) : Colors.green.shade100)
                  : (tokens.isDark ? const Color(0xFF263238) : Colors.blueGrey.shade100),
              child: Icon(
                isHome ? Icons.person_rounded : Icons.person_outline_rounded,
                color: isHome
                    ? (tokens.isDark ? const Color(0xFF81C784) : Colors.green)
                    : (tokens.isDark ? Colors.blueGrey.shade300 : Colors.blueGrey),
              ),
            ),
            title: Text(
              'User: ${u.userId}',
              style: TextStyle(fontWeight: FontWeight.w700, color: tokens.textPrimary),
            ),
            subtitle: Text(
              'State: ${u.state.toApiValue()} • Source: ${u.source.toApiValue()}${u.isStale ? ' (STALE)' : ''}',
              style: TextStyle(color: tokens.textSecondary, fontSize: 13),
            ),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${(u.confidence * 100).toStringAsFixed(0)}%',
                  style: TextStyle(fontWeight: FontWeight.bold, color: tokens.textPrimary),
                ),
                Text(
                  u.isStale ? 'Expired' : 'Active',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: u.isStale ? tokens.error : tokens.success,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildInferredRoomsList(
    BuildContext context,
    PresenceSnapshotModel? snapshot,
    EHThemeTokens tokens,
  ) {
    if (snapshot == null || snapshot.inferredRooms.isEmpty) {
      return Card(
        color: tokens.surfaceCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: tokens.borderControl),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'No room telemetry available for inference.',
            style: TextStyle(color: tokens.textSecondary),
          ),
        ),
      );
    }

    return Column(
      children: snapshot.inferredRooms.map((r) {
        return Card(
          color: tokens.surfaceCard,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: tokens.borderControl),
          ),
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: Icon(
              r.isOccupied ? Icons.meeting_room_rounded : Icons.no_meeting_room_outlined,
              color: r.isOccupied ? tokens.success : tokens.textSecondary,
            ),
            title: Text(
              'Room: ${r.roomId}',
              style: TextStyle(fontWeight: FontWeight.w700, color: tokens.textPrimary),
            ),
            subtitle: Text(
              r.inferenceReason.isNotEmpty ? r.inferenceReason : 'Device activity analysis',
              style: TextStyle(color: tokens.textSecondary, fontSize: 13),
            ),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: r.isOccupied
                    ? (tokens.isDark ? const Color(0xFF1E3A2F) : Colors.green.shade50)
                    : (tokens.isDark ? const Color(0xFF263238) : Colors.grey.shade100),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: r.isOccupied
                      ? (tokens.isDark ? const Color(0xFF2E7D32) : Colors.green.shade200)
                      : tokens.borderControl,
                ),
              ),
              child: Text(
                r.isOccupied ? 'Occupied' : 'Vacant',
                style: TextStyle(
                  color: r.isOccupied
                      ? (tokens.isDark ? const Color(0xFF81C784) : Colors.green.shade800)
                      : tokens.textSecondary,
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
