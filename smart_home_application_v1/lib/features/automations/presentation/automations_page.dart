import 'package:flutter/material.dart';

import '../../../core/models/routine_models.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/carousel_page_indicator.dart';

class AutomationsPage extends StatefulWidget {
  const AutomationsPage({
    super.key,
    this.repository = const PreviewRoutineRepository(),
    this.onConnectHome,
  });
  final RoutineRepository repository;
  final VoidCallback? onConnectHome;

  @override
  State<AutomationsPage> createState() => _AutomationsPageState();
}

enum _RoutineFilter { all, enabled, disabled }

enum _RoutineSort { recent, nameAscending, nameDescending, lastRun }

class _AutomationsPageState extends State<AutomationsPage> {
  final _search = TextEditingController();
  final _searchFocus = FocusNode();
  _RoutineFilter _filter = _RoutineFilter.all;
  _RoutineSort _sort = _RoutineSort.recent;
  List<Routine>? _routines;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final routines = await widget.repository.getRoutines();
    if (mounted) setState(() => _routines = routines);
  }

  @override
  void dispose() {
    _search.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  List<Routine> _visible(List<Routine> source) {
    final query = _search.text.trim().toLowerCase();
    final list = source.where((routine) {
      final matchesSearch =
          query.isEmpty ||
          routine.name.toLowerCase().contains(query) ||
          routine.summary.toLowerCase().contains(query);
      final matchesFilter = switch (_filter) {
        _RoutineFilter.all => true,
        _RoutineFilter.enabled => routine.enabled,
        _RoutineFilter.disabled => !routine.enabled,
      };
      return matchesSearch && matchesFilter;
    }).toList();
    list.sort(
      (a, b) => switch (_sort) {
        _RoutineSort.recent => b.updatedAt.compareTo(a.updatedAt),
        _RoutineSort.nameAscending => a.name.compareTo(b.name),
        _RoutineSort.nameDescending => b.name.compareTo(a.name),
        _RoutineSort.lastRun =>
          (b.lastExecution?.completedAt ?? DateTime(0)).compareTo(
            a.lastExecution?.completedAt ?? DateTime(0),
          ),
      },
    );
    return list;
  }

  Future<void> _openDetail(Routine routine) async {
    FocusManager.instance.primaryFocus?.unfocus();
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            RoutineDetailPage(routine: routine, repository: widget.repository),
      ),
    );
  }

  Future<void> _toggle(Routine routine) async {
    final result = routine.enabled
        ? await widget.repository.disableRoutine(routine.id)
        : await widget.repository.enableRoutine(routine.id);
    if (!mounted) return;
    if (result == RepositoryResult.unsupported) {
      _showSecureSetup();
    } else if (result != RepositoryResult.success) {
      _showMessage('Couldn’t update this routine. Try again later.');
    }
  }

  void _showSecureSetup() {
    final tokens = context.ehColors;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: tokens.surfaceCard,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Secure setup required',
                style: TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.w800,
                  color: tokens.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Connect your home to enable and manage routines.',
                style: TextStyle(color: tokens.textSecondary),
              ),
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: () {
                  Navigator.pop(sheetContext);
                  widget.onConnectHome?.call();
                },
                style: FilledButton.styleFrom(
                  backgroundColor: tokens.blueDarker,
                ),
                icon: const Icon(Icons.bluetooth_rounded),
                label: const Text('Connect home'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showMessage(String message) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );

  @override
  Widget build(BuildContext context) {
    final tokens = context.ehColors;
    final source = _routines;
    final visible = source == null ? const <Routine>[] : _visible(source);
    final deviceCount =
        source
            ?.expand((routine) => routine.involvedDevices)
            .map((d) => d.id)
            .toSet()
            .length ??
        0;
    return SafeArea(
      bottom: false,
      child: Scaffold(
        backgroundColor: tokens.bgApp,
        body: ScrollFriendlyPage(
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
            child: ListView(
              key: const PageStorageKey<String>('routines-scroll'),
              padding: const EdgeInsets.fromLTRB(20, 22, 20, 106),
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Routines',
                            style: TextStyle(
                              color: tokens.textPrimary,
                              fontSize: 29,
                              fontWeight: FontWeight.w800,
                              height: 1,
                            ),
                          ),
                          const SizedBox(height: 7),
                          Text(
                            'Your home can take care of the small things for you.',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: tokens.textSecondary,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    _HeaderRoundAction(
                      icon: Icons.add_rounded,
                      tooltip: 'Create routine',
                      filled: true,
                      onTap: _openBuilder,
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                TextField(
                  controller: _search,
                  focusNode: _searchFocus,
                  style: TextStyle(color: tokens.textPrimary),
                  onChanged: (_) => setState(() {}),
                  onTapOutside: (_) =>
                      FocusManager.instance.primaryFocus?.unfocus(),
                  decoration: InputDecoration(
                    hintText: 'Search routines',
                    hintStyle: TextStyle(color: tokens.textTertiary),
                    prefixIcon: Icon(
                      Icons.search_rounded,
                      color: tokens.textSecondary,
                    ),
                    filled: true,
                    fillColor: tokens.surfaceCard,
                    contentPadding: const EdgeInsets.symmetric(vertical: 17),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: tokens.borderControl),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: tokens.borderControl),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: tokens.bluePrimary,
                        width: 1.5,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _FilterPill(
                        label: 'All (${source?.length ?? 0})',
                        selected: _filter == _RoutineFilter.all,
                        onTap: () =>
                            setState(() => _filter = _RoutineFilter.all),
                      ),
                      _FilterPill(
                        label:
                            'Enabled (${source?.where((r) => r.enabled).length ?? 0})',
                        selected: _filter == _RoutineFilter.enabled,
                        color: tokens.success,
                        onTap: () =>
                            setState(() => _filter = _RoutineFilter.enabled),
                      ),
                      _FilterPill(
                        label:
                            'Disabled (${source?.where((r) => !r.enabled).length ?? 0})',
                        selected: _filter == _RoutineFilter.disabled,
                        onTap: () =>
                            setState(() => _filter = _RoutineFilter.disabled),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${source?.length ?? 0} routines • $deviceCount devices',
                        style: TextStyle(
                          color: tokens.textSecondary,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    PopupMenuButton<_RoutineSort>(
                      onSelected: (value) => setState(() => _sort = value),
                      color: tokens.surfaceCard,
                      itemBuilder: (_) => [
                        PopupMenuItem(
                          value: _RoutineSort.recent,
                          child: Text(
                            'Recent',
                            style: TextStyle(color: tokens.textPrimary),
                          ),
                        ),
                        PopupMenuItem(
                          value: _RoutineSort.nameAscending,
                          child: Text(
                            'Name: A-Z',
                            style: TextStyle(color: tokens.textPrimary),
                          ),
                        ),
                        PopupMenuItem(
                          value: _RoutineSort.nameDescending,
                          child: Text(
                            'Name: Z-A',
                            style: TextStyle(color: tokens.textPrimary),
                          ),
                        ),
                        PopupMenuItem(
                          value: _RoutineSort.lastRun,
                          child: Text(
                            'Last run',
                            style: TextStyle(color: tokens.textPrimary),
                          ),
                        ),
                      ],
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: Row(
                          children: [
                            Text(
                              _sortLabel,
                              style: TextStyle(
                                color: tokens.bluePrimary,
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                              ),
                            ),
                            Icon(
                              Icons.keyboard_arrow_down_rounded,
                              size: 18,
                              color: tokens.bluePrimary,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                if (source == null)
                  const _LoadingRoutines()
                else if (visible.isEmpty)
                  const _EmptyRoutines()
                else
                  ...visible.map(
                    (routine) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: RoutineCard(
                        routine: routine,
                        onTap: () => _openDetail(routine),
                        onToggle: () => _toggle(routine),
                      ),
                    ),
                  ),
                const SizedBox(height: 6),
                _CreateRoutineBanner(onTap: _openBuilder),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String get _sortLabel => switch (_sort) {
    _RoutineSort.recent => 'Sort: Recent',
    _RoutineSort.nameAscending => 'Sort: A-Z',
    _RoutineSort.nameDescending => 'Sort: Z-A',
    _RoutineSort.lastRun => 'Sort: Last run',
  };

  void _openBuilder() => Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => RoutineBuilderPage(repository: widget.repository),
    ),
  );
}

class RoutineCard extends StatelessWidget {
  const RoutineCard({
    super.key,
    required this.routine,
    required this.onTap,
    required this.onToggle,
  });
  final Routine routine;
  final VoidCallback onTap;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final tokens = context.ehColors;
    final unavailable =
        routine.availability == RoutineAvailability.unavailable ||
        routine.availability == RoutineAvailability.partiallyAvailable;
    final statusColor = unavailable
        ? tokens.warning
        : routine.enabled
        ? tokens.success
        : tokens.textTertiary;
    return Semantics(
      button: true,
      label: '${routine.name}, ${routine.summary}',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(15),
        child: Ink(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: tokens.surfaceCard,
            borderRadius: BorderRadius.circular(15),
            border: tokens.isDark
                ? Border.all(color: tokens.borderSubtle)
                : null,
            boxShadow: tokens.isDark
                ? null
                : const [
                    BoxShadow(
                      color: Color(0x100B2448),
                      blurRadius: 16,
                      offset: Offset(0, 6),
                    ),
                  ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _RoutineIcon(icon: routine.icon, color: statusColor),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      routine.name,
                      style: TextStyle(
                        color: tokens.textPrimary,
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      routine.summary,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: tokens.textSecondary,
                        fontSize: 14,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 7,
                      runSpacing: 3,
                      children: [
                        Icon(
                          unavailable
                              ? Icons.warning_amber_rounded
                              : routine.enabled
                              ? Icons.check_circle_rounded
                              : Icons.radio_button_unchecked,
                          color: statusColor,
                          size: 16,
                        ),
                        Text(
                          unavailable
                              ? routine.availabilityLabel
                              : routine.statusLabel,
                          style: TextStyle(
                            color: statusColor,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                        if (routine.lastExecution != null)
                          Text(
                            '• Last run ${_dateLabel(routine.lastExecution!.completedAt)}',
                            style: TextStyle(
                              color: tokens.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 5),
              Column(
                children: [
                  GestureDetector(
                    onTap: onToggle,
                    child: Switch(
                      value: routine.enabled,
                      onChanged: null,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: tokens.chevron,
                    size: 27,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class RoutineDetailPage extends StatefulWidget {
  const RoutineDetailPage({
    super.key,
    required this.routine,
    required this.repository,
  });
  final Routine routine;
  final RoutineRepository repository;
  @override
  State<RoutineDetailPage> createState() => _RoutineDetailPageState();
}

class _RoutineDetailPageState extends State<RoutineDetailPage> {
  late bool _favorite = widget.routine.isFavorite;
  List<RoutineExecution>? _history;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final value = await widget.repository.getRecentExecutions(
      widget.routine.id,
    );
    if (mounted) setState(() => _history = value);
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.ehColors;
    final routine = widget.routine;
    final unavailable = routine.availability != RoutineAvailability.available;
    return Scaffold(
      backgroundColor: tokens.bgApp,
      appBar: AppBar(
        backgroundColor: tokens.bgApp,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: Icon(Icons.arrow_back_rounded, color: tokens.headerAction),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              routine.name,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: tokens.textPrimary,
              ),
            ),
            Text(
              routine.enabled ? '● Active' : '○ Disabled',
              style: TextStyle(
                color: routine.enabled ? tokens.success : tokens.textTertiary,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: () => setState(() => _favorite = !_favorite),
            icon: Icon(
              _favorite ? Icons.star_rounded : Icons.star_border_rounded,
              color: _favorite ? tokens.gold : tokens.headerAction,
            ),
          ),
          PopupMenuButton<String>(
            color: tokens.surfaceCard,
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'info',
                child: Text(
                  'Preview mode',
                  style: TextStyle(color: tokens.textPrimary),
                ),
              ),
            ],
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          Text(
            routine.summary,
            style: TextStyle(
              color: tokens.textSecondary,
              fontSize: 16,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 14),
          _DetailSection(
            label: 'WHEN',
            icon: Icons.schedule_rounded,
            color: tokens.success,
            title: routine.trigger.title,
            lines: [routine.trigger.detail, routine.schedule.label],
          ),
          if (routine.conditions.isNotEmpty)
            _DetailSection(
              label: 'IF',
              icon: Icons.filter_alt_outlined,
              color: tokens.bluePrimary,
              title: 'All conditions must be met',
              lines: routine.conditions
                  .map(
                    (condition) => '${condition.title} · ${condition.detail}',
                  )
                  .toList(),
            ),
          _DetailSection(
            label: 'THEN',
            icon: Icons.bolt_rounded,
            color: tokens.iconFgPurple,
            title: 'Run these actions',
            lines: routine.actions
                .map((action) => '${action.title} · ${action.detail}')
                .toList(),
          ),
          _DevicesSection(devices: routine.involvedDevices),
          _ActivitySection(history: _history),
          if (unavailable) _UnavailableNotice(routine: routine),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: null,
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Edit routine'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: null,
                  icon: const Icon(Icons.delete_outline_rounded),
                  label: const Text('Delete'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class RoutineBuilderPage extends StatefulWidget {
  const RoutineBuilderPage({super.key, required this.repository});
  final RoutineRepository repository;
  @override
  State<RoutineBuilderPage> createState() => _RoutineBuilderPageState();
}

class _RoutineBuilderPageState extends State<RoutineBuilderPage> {
  final _name = TextEditingController(text: 'Plant care');
  final _draft = RoutineDraft();
  int _step = 0;
  final _validator = const RoutineValidator();

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _next() {
    _draft.name = _name.text;
    if (_step < 4) setState(() => _step++);
  }

  void _chooseTrigger(RoutineTrigger trigger) {
    _draft.trigger = trigger;
    _draft.schedule = const RoutineSchedule(
      label: 'Every day · All day',
      timezone: 'Home timezone',
    );
    _draft.actions = [
      const RoutineAction(
        kind: RoutineActionKind.mistMaker,
        title: 'Mist maker',
        detail: 'Run for 30 seconds',
        deviceId: 'mist',
      ),
    ];
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.ehColors;
    final validation = _validator.validate(_draft);
    _draft.validation = validation;
    return Scaffold(
      backgroundColor: tokens.bgApp,
      appBar: AppBar(
        backgroundColor: tokens.bgApp,
        title: Text(
          _step == 4 ? 'Review routine' : 'Create routine',
          style: TextStyle(color: tokens.textPrimary),
        ),
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: Icon(Icons.arrow_back_rounded, color: tokens.headerAction),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          LinearProgressIndicator(
            value: (_step + 1) / 5,
            borderRadius: BorderRadius.circular(20),
            backgroundColor: tokens.isDark ? tokens.borderControl : null,
            valueColor: AlwaysStoppedAnimation(tokens.bluePrimary),
          ),
          const SizedBox(height: 22),
          if (_step == 0) ...[
            Text(
              'What should we call this routine?',
              style: TextStyle(
                color: tokens.textPrimary,
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'Routine name'),
            ),
            const SizedBox(height: 16),
            _TemplateChoice(
              title: 'Plant care',
              subtitle: 'Start misting when soil becomes dry',
              icon: Icons.local_florist_outlined,
              onTap: () => _name.text = 'Plant care',
            ),
          ] else if (_step == 1) ...[
            Text(
              'When should this routine start?',
              style: TextStyle(
                color: tokens.textPrimary,
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 12),
            _ChoiceCard(
              title: 'When a level changes',
              subtitle: 'Soil moisture or water level',
              icon: Icons.water_drop_outlined,
              onTap: () => _chooseTrigger(
                const RoutineTrigger(
                  kind: RoutineTriggerKind.soilMoisture,
                  title: 'Soil moisture drops below 35%',
                  detail: 'Mon – Sun · All day',
                  threshold: 35,
                ),
              ),
            ),
            _ChoiceCard(
              title: 'When the room becomes dark',
              subtitle: 'After sunset',
              icon: Icons.nightlight_outlined,
              onTap: () => _chooseTrigger(
                const RoutineTrigger(
                  kind: RoutineTriggerKind.darkness,
                  title: 'Room becomes dark',
                  detail: 'After sunset',
                ),
              ),
            ),
          ] else if (_step == 2) ...[
            Text(
              'Would you like to add a condition?',
              style: TextStyle(
                color: tokens.textPrimary,
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 12),
            _ChoiceCard(
              title: 'All day',
              subtitle: 'Run whenever the trigger crosses its threshold',
              icon: Icons.schedule_rounded,
              onTap: () => setState(() {}),
            ),
          ] else if (_step == 3) ...[
            Text(
              'What should EH Home do?',
              style: TextStyle(
                color: tokens.textPrimary,
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 12),
            _ChoiceCard(
              title: 'Control a device',
              subtitle: 'Run the plant mist maker for 30 seconds',
              icon: Icons.bolt_rounded,
              onTap: () => setState(() {}),
            ),
            _ChoiceCard(
              title: 'Send a notification',
              subtitle: 'Send a reminder to your phone',
              icon: Icons.notifications_none_rounded,
              onTap: () => setState(() {}),
            ),
          ] else ...[
            Text(
              'Review routine',
              style: TextStyle(
                color: tokens.textPrimary,
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 12),
            Card(
              color: tokens.surfaceCard,
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _draft.name.isEmpty ? 'Plant care' : _draft.name,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: tokens.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'WHEN',
                      style: TextStyle(
                        color: tokens.success,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      _draft.trigger?.title ?? 'Choose a trigger',
                      style: TextStyle(color: tokens.textPrimary),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'THEN',
                      style: TextStyle(
                        color: tokens.iconFgPurple,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      _draft.actions.isEmpty
                          ? 'Choose an action'
                          : _draft.actions.first.detail,
                      style: TextStyle(color: tokens.textPrimary),
                    ),
                  ],
                ),
              ),
            ),
            if (validation.errors.isNotEmpty)
              ...validation.errors.map(
                (error) =>
                    Text(error, style: TextStyle(color: tokens.errorText)),
              ),
            const SizedBox(height: 14),
            Text(
              'Preview only. Connect your home to save this routine.',
              style: TextStyle(color: tokens.textSecondary),
            ),
          ],
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _step == 4 ? () => Navigator.pop(context) : _next,
            style: FilledButton.styleFrom(
              backgroundColor: tokens.blueDarker,
              foregroundColor: tokens.textPrimary,
            ),
            child: Text(_step == 4 ? 'Done' : 'Continue'),
          ),
        ],
      ),
    );
  }
}

class _DetailSection extends StatelessWidget {
  const _DetailSection({
    required this.label,
    required this.icon,
    required this.color,
    required this.title,
    required this.lines,
  });
  final String label, title;
  final IconData icon;
  final Color color;
  final List<String> lines;
  @override
  Widget build(BuildContext context) {
    final tokens = context.ehColors;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: tokens.surfaceCard,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: color.withValues(alpha: tokens.isDark ? 0.20 : 0.12),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                      color: tokens.textPrimary,
                    ),
                  ),
                  ...lines.map(
                    (line) => Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        line,
                        style: TextStyle(color: tokens.textSecondary),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DevicesSection extends StatelessWidget {
  const _DevicesSection({required this.devices});
  final List<RoutineDevice> devices;
  @override
  Widget build(BuildContext context) {
    final tokens = context.ehColors;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: tokens.surfaceCard,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'DEVICES INVOLVED',
              style: TextStyle(
                color: tokens.textSecondary,
                fontWeight: FontWeight.w800,
                fontSize: 12,
              ),
            ),
            ...devices.map(
              (device) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  backgroundColor: tokens.iconBgBlue,
                  child: Icon(
                    Icons.devices_other_rounded,
                    color: tokens.bluePrimary,
                  ),
                ),
                title: Text(
                  device.name,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: tokens.buttonText,
                  ),
                ),
                subtitle: Text(
                  device.room,
                  style: TextStyle(color: tokens.textSecondary),
                ),
                trailing: Text(
                  device.online ? '● Online' : '● Offline',
                  style: TextStyle(
                    color: device.online ? tokens.success : tokens.warning,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActivitySection extends StatelessWidget {
  const _ActivitySection({required this.history});
  final List<RoutineExecution>? history;
  @override
  Widget build(BuildContext context) {
    final tokens = context.ehColors;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: tokens.surfaceCard,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'RECENT ACTIVITY',
              style: TextStyle(
                color: tokens.textSecondary,
                fontWeight: FontWeight.w800,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 8),
            if (history == null)
              LinearProgressIndicator(color: tokens.bluePrimary)
            else if (history!.isEmpty)
              Text(
                'No executions recorded yet.',
                style: TextStyle(color: tokens.textSecondary),
              )
            else
              ...history!.map(
                (entry) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    entry.result == RoutineExecutionResult.succeeded
                        ? Icons.check_circle
                        : Icons.warning_amber_rounded,
                    color: entry.result == RoutineExecutionResult.succeeded
                        ? tokens.success
                        : tokens.warning,
                  ),
                  title: Text(
                    entry.message,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: tokens.textPrimary,
                    ),
                  ),
                  subtitle: Text(
                    entry.failureReason ?? _dateLabel(entry.completedAt),
                    style: TextStyle(color: tokens.textSecondary),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _UnavailableNotice extends StatelessWidget {
  const _UnavailableNotice({required this.routine});
  final Routine routine;
  @override
  Widget build(BuildContext context) {
    final tokens = context.ehColors;
    return Card(
      color: tokens.warningContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: tokens.warning),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '${routine.availabilityLabel}. This routine may not run until the device reconnects.',
                style: TextStyle(
                  color: tokens.warning,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChoiceCard extends StatelessWidget {
  const _ChoiceCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });
  final String title, subtitle;
  final IconData icon;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final tokens = context.ehColors;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: tokens.surfaceCard,
      child: ListTile(
        minVerticalPadding: 14,
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: tokens.iconBgBlue,
          child: Icon(icon, color: tokens.bluePrimary),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: tokens.textPrimary,
          ),
        ),
        subtitle: Text(subtitle, style: TextStyle(color: tokens.textSecondary)),
        trailing: Icon(Icons.chevron_right_rounded, color: tokens.chevron),
      ),
    );
  }
}

class _TemplateChoice extends StatelessWidget {
  const _TemplateChoice({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });
  final String title, subtitle;
  final IconData icon;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) =>
      _ChoiceCard(title: title, subtitle: subtitle, icon: icon, onTap: onTap);
}

class _FilterPill extends StatelessWidget {
  const _FilterPill({
    required this.label,
    required this.selected,
    required this.onTap,
    this.color,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color? color;
  @override
  Widget build(BuildContext context) {
    final tokens = context.ehColors;
    final effectiveColor = color ?? tokens.bluePrimary;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Ink(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              color: selected ? tokens.blueSelectedBg : tokens.surfaceCard,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: selected ? tokens.bluePrimary : tokens.borderControl,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  selected ? Icons.check_circle_rounded : Icons.circle_outlined,
                  size: 17,
                  color: selected
                      ? (tokens.isDark
                            ? tokens.blueSelectedText
                            : effectiveColor)
                      : tokens.textSecondary,
                ),
                const SizedBox(width: 7),
                Text(
                  label,
                  style: TextStyle(
                    color: selected
                        ? (tokens.isDark
                              ? tokens.blueSelectedText
                              : tokens.bluePrimary)
                        : tokens.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RoutineIcon extends StatelessWidget {
  const _RoutineIcon({required this.icon, required this.color});
  final String icon;
  final Color color;
  @override
  Widget build(BuildContext context) {
    final tokens = context.ehColors;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 68,
          height: 68,
          decoration: BoxDecoration(
            color: tokens.isDark
                ? tokens.iconBgPurple
                : color.withValues(alpha: .12),
            borderRadius: BorderRadius.circular(17),
          ),
          child: Icon(
            switch (icon) {
              'plant' => Icons.local_florist_outlined,
              'night' => Icons.nightlight_outlined,
              _ => Icons.water_drop_outlined,
            },
            color: tokens.isDark
                ? tokens.iconFgPurple
                : const Color(0xFF10264B),
            size: 34,
          ),
        ),
        Positioned(
          right: -2,
          top: -2,
          child: Container(
            width: 13,
            height: 13,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(color: tokens.surfaceCard, width: 2),
            ),
          ),
        ),
      ],
    );
  }
}

class _HeaderRoundAction extends StatelessWidget {
  const _HeaderRoundAction({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.filled = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final tokens = context.ehColors;
    return Tooltip(
      message: tooltip,
      child: Material(
        color: filled ? tokens.blueDarker : tokens.surfaceElevated,
        shape: const CircleBorder(),
        elevation: 0,
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: SizedBox(
            width: 44,
            height: 44,
            child: Icon(
              icon,
              size: 23,
              color: filled ? tokens.buttonText : tokens.bluePrimary,
            ),
          ),
        ),
      ),
    );
  }
}

class _CreateRoutineBanner extends StatelessWidget {
  const _CreateRoutineBanner({required this.onTap});
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final tokens = context.ehColors;
    return Card(
      color: tokens.isDark ? tokens.surfaceElevated : const Color(0xFFEAF2FF),
      child: ListTile(
        onTap: onTap,
        leading: Icon(Icons.auto_awesome_rounded, color: tokens.bluePrimary),
        title: Text(
          'Create your own routine',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: tokens.textPrimary,
          ),
        ),
        subtitle: Text(
          'Make your home work smarter.',
          style: TextStyle(color: tokens.textSecondary),
        ),
        trailing: Icon(
          Icons.add_circle_outline_rounded,
          color: tokens.bluePrimary,
        ),
      ),
    );
  }
}

class _LoadingRoutines extends StatelessWidget {
  const _LoadingRoutines();
  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.all(32),
    child: Center(child: CircularProgressIndicator()),
  );
}

class _EmptyRoutines extends StatelessWidget {
  const _EmptyRoutines();
  @override
  Widget build(BuildContext context) {
    final tokens = context.ehColors;
    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        children: [
          Icon(
            Icons.auto_awesome_outlined,
            size: 42,
            color: tokens.bluePrimary,
          ),
          const SizedBox(height: 10),
          Text(
            'No routines match your search.',
            style: TextStyle(color: tokens.textSecondary),
          ),
        ],
      ),
    );
  }
}

String _dateLabel(DateTime time) =>
    'Today, ${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
