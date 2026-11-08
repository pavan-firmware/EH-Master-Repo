import 'package:flutter/material.dart';
import '../../../core/models/context_presence_models.dart';
import '../../../core/services/context_presence_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../settings/presentation/settings_ui.dart';

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
    final tokens = context.ehColors;
    return AnimatedBuilder(
      animation: widget.service,
      builder: (context, _) {
        final currentContext = widget.service.currentContext;
        final transitions = widget.service.transitions;
        final isLoading = widget.service.isLoading;
        final errorMessage = widget.service.errorMessage;

        if (currentContext == null && errorMessage != null && !isLoading) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('Home Context & Modes'),
              actions: [
                settingsHelpAction(context, screenId: 'home_context'),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: _refresh,
                ),
              ],
            ),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.cloud_off_rounded,
                      size: 48,
                      color: tokens.error,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Failed to load home context',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: tokens.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      errorMessage,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: tokens.textSecondary,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: tokens.bluePrimary,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: _refresh,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        return Scaffold(
          appBar: AppBar(
            title: const Text('Home Context & Modes'),
            actions: [
              settingsHelpAction(context, screenId: 'home_context'),
              IconButton(icon: const Icon(Icons.refresh), onPressed: _refresh),
            ],
          ),
          body: RefreshIndicator(
            onRefresh: _refresh,
            child: isLoading && currentContext == null
                ? const Center(child: CircularProgressIndicator())
                : ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      if (errorMessage != null) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: tokens.error.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: tokens.error.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.warning_amber_rounded,
                                size: 20,
                                color: tokens.error,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  errorMessage,
                                  style: TextStyle(
                                    color: tokens.error,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      // 1. Context Hero Card
                      _buildCurrentContextCard(context, currentContext, tokens),
                      const SizedBox(height: 20),

                      // 2. Mode Selector Chips
                      Text(
                        'Set Home Context Mode',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: tokens.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 10),
                      _buildModeSelector(context, currentContext?.mode, tokens),
                      const SizedBox(height: 20),

                      // 3. Precedence Hierarchy Legend
                      _buildPrecedenceCard(
                        context,
                        currentContext?.precedenceTier,
                        tokens,
                      ),
                      const SizedBox(height: 20),

                      // 4. Transitions Timeline
                      Text(
                        'Context Transitions History',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: tokens.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 10),
                      _buildTransitionsList(context, transitions, tokens),
                    ],
                  ),
          ),
        );
      },
    );
  }

  Widget _buildCurrentContextCard(
    BuildContext context,
    HomeContextModel? contextModel,
    EHThemeTokens tokens,
  ) {
    final mode = contextModel?.mode ?? ContextMode.home;
    final precedence =
        contextModel?.precedenceTier ?? PrecedenceTier.defaultFallback;
    final isOverride = precedence == PrecedenceTier.manualOverride;

    Color color = tokens.bluePrimary;
    IconData icon = Icons.home;

    switch (mode) {
      case ContextMode.home:
        color = tokens.success;
        icon = Icons.home_rounded;
        break;
      case ContextMode.away:
        color = tokens.isDark ? Colors.blueGrey.shade300 : Colors.blueGrey;
        icon = Icons.exit_to_app_rounded;
        break;
      case ContextMode.sleep:
        color = tokens.isDark ? const Color(0xFF9FA8DA) : Colors.indigo;
        icon = Icons.nightlight_round;
        break;
      case ContextMode.vacation:
        color = tokens.isDark ? const Color(0xFFFFAB91) : Colors.deepOrange;
        icon = Icons.beach_access_rounded;
        break;
      case ContextMode.guest:
        color = tokens.isDark ? const Color(0xFFCE93D8) : Colors.purple;
        icon = Icons.people_outline_rounded;
        break;
      case ContextMode.quietHours:
        color = tokens.isDark ? const Color(0xFF80CBC4) : Colors.teal;
        icon = Icons.volume_off_rounded;
        break;
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
              color.withValues(alpha: tokens.isDark ? 0.25 : 0.15),
              color.withValues(alpha: tokens.isDark ? 0.08 : 0.03),
            ],
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
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: color,
                        ),
                      ),
                      Text(
                        isOverride
                            ? 'Manual Override Active'
                            : (contextModel?.precedenceTier ==
                                      PrecedenceTier.defaultFallback
                                  ? 'Default Baseline State'
                                  : 'Automatic Reconciled State'),
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
            if (isOverride) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: tokens.isDark
                      ? const Color(0xFF2A2016)
                      : Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: tokens.isDark
                        ? Colors.orange.shade800
                        : Colors.orange.shade200,
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.info_outline,
                      color: Colors.orange,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        contextModel?.activeOverride?.reason.isNotEmpty == true
                            ? 'Reason: ${contextModel!.activeOverride!.reason}'
                            : 'Manual override suppresses automatic presence reconciliation.',
                        style: TextStyle(
                          fontSize: 12,
                          color: tokens.textPrimary,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: _clearOverride,
                      child: const Text(
                        'Clear',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.redAccent,
                        ),
                      ),
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

  Widget _buildModeSelector(
    BuildContext context,
    ContextMode? activeMode,
    EHThemeTokens tokens,
  ) {
    final effectiveMode = activeMode ?? ContextMode.home;
    final modes = ContextMode.values;
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: modes.map((m) {
        final isSelected = m == effectiveMode;
        return ChoiceChip(
          label: Text(
            m.toApiValue(),
            style: TextStyle(
              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
              color: isSelected ? Colors.white : tokens.textPrimary,
            ),
          ),
          selected: isSelected,
          selectedColor: tokens.bluePrimary,
          backgroundColor: tokens.surfaceCard,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: BorderSide(
              color: isSelected ? tokens.bluePrimary : tokens.borderControl,
            ),
          ),
          onSelected: (selected) {
            if (selected) _selectMode(m);
          },
        );
      }).toList(),
    );
  }

  Future<void> _selectMode(ContextMode mode) async {
    final success = await widget.service.setQuickMode(widget.homeId, mode);
    if (!mounted) return;
    if (success) {
      await widget.service.fetchHomeContext(widget.homeId);
      await widget.service.fetchTransitions(widget.homeId);
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? 'Context set to ${mode.toApiValue()}'
              : (widget.service.errorMessage ?? 'Failed to set mode'),
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _clearOverride() async {
    final success = await widget.service.clearContextOverride(widget.homeId);
    if (!mounted) return;
    if (success) {
      await widget.service.fetchHomeContext(widget.homeId);
      await widget.service.fetchTransitions(widget.homeId);
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? 'Override cleared'
              : (widget.service.errorMessage ?? 'Failed to clear override'),
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Widget _buildPrecedenceCard(
    BuildContext context,
    PrecedenceTier? tier,
    EHThemeTokens tokens,
  ) {
    final effectiveTier = tier ?? PrecedenceTier.defaultFallback;
    return Card(
      elevation: 2,
      color: tokens.surfaceCard,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: tokens.borderControl),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Precedence State Machine Hierarchy',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: tokens.textPrimary,
              ),
            ),
            const SizedBox(height: 10),
            _buildTierRow(
              '1. Manual Overrides (Highest)',
              effectiveTier == PrecedenceTier.manualOverride,
              tokens,
            ),
            _buildTierRow(
              '2. Scheduled Windows (Quiet/Sleep)',
              effectiveTier == PrecedenceTier.scheduledWindow,
              tokens,
            ),
            _buildTierRow(
              '3. Reconciled Presence (Sensors/App)',
              effectiveTier == PrecedenceTier.reconciledPresence,
              tokens,
            ),
            _buildTierRow(
              '4. Default Fallback (Baseline)',
              effectiveTier == PrecedenceTier.defaultFallback,
              tokens,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTierRow(String title, bool isCurrent, EHThemeTokens tokens) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Icon(
            isCurrent
                ? Icons.check_circle_rounded
                : Icons.radio_button_unchecked_rounded,
            size: 18,
            color: isCurrent ? tokens.success : tokens.textSecondary,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontWeight: isCurrent ? FontWeight.w800 : FontWeight.normal,
                color: isCurrent
                    ? (tokens.isDark
                          ? const Color(0xFF81C784)
                          : Colors.green.shade800)
                    : tokens.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransitionsList(
    BuildContext context,
    List<ContextTransitionModel> transitions,
    EHThemeTokens tokens,
  ) {
    if (transitions.isEmpty) {
      return Card(
        color: tokens.surfaceCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: tokens.borderControl),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'No transitions recorded yet.',
            style: TextStyle(color: tokens.textSecondary),
          ),
        ),
      );
    }

    return Column(
      children: transitions.take(10).map((t) {
        return Card(
          color: tokens.surfaceCard,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: tokens.borderControl),
          ),
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: Icon(Icons.swap_horiz_rounded, color: tokens.bluePrimary),
            title: Text(
              '${t.fromMode?.toApiValue() ?? 'INITIAL'} → ${t.toMode.toApiValue()}',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: tokens.textPrimary,
              ),
            ),
            subtitle: Text(
              'Source: ${t.triggerSource}\n${t.reason}',
              style: TextStyle(color: tokens.textSecondary, fontSize: 13),
            ),
            isThreeLine: true,
            trailing: Text(
              '${t.createdAt.hour.toString().padLeft(2, '0')}:${t.createdAt.minute.toString().padLeft(2, '0')}',
              style: TextStyle(color: tokens.textSecondary, fontSize: 12),
            ),
          ),
        );
      }).toList(),
    );
  }
}
