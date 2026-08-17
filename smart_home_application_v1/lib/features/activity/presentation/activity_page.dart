import 'package:flutter/material.dart';

import '../../../core/models/activity_models.dart';
import '../../../core/models/routine_models.dart';
import '../../../core/theme/app_theme.dart';
import '../../alerts/presentation/safety_alert_page.dart';
import '../../automations/presentation/automations_page.dart';
import '../../updates/presentation/system_update_page.dart';

class ActivityPage extends StatefulWidget {
  const ActivityPage({
    super.key,
    this.repository = const PreviewActivityRepository(),
    this.deviceRepository = const PreviewActivityDeviceRepository(),
    this.routineRepository = const PreviewRoutineRepository(),
  });

  final ActivityRepository repository;
  final ActivityDeviceRepository deviceRepository;
  final RoutineRepository routineRepository;

  @override
  State<ActivityPage> createState() => _ActivityPageState();
}

class _ActivityPageState extends State<ActivityPage> {
  final _search = TextEditingController();
  final _searchFocus = FocusNode();
  final _scroll = ScrollController();
  ActivityFilter _filter = ActivityFilter.all;
  ActivitySort _sort = ActivitySort.recent;
  ActivityEventPage? _page;
  String? _error;
  bool _loading = true;
  bool _searchVisible = false;
  bool _loadingMore = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    _searchFocus.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load({bool append = false}) async {
    if (append) {
      if (_loadingMore || _page?.nextCursor == null) return;
      setState(() => _loadingMore = true);
    } else {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final result = await widget.repository.getEvents(
        ActivityQuery(
          search: _search.text,
          filter: _filter,
          sort: _sort,
          cursor: append ? _page?.nextCursor : null,
        ),
      );
      if (!mounted) return;
      setState(() {
        _page = append && _page != null
            ? ActivityEventPage(
                events: [..._page!.events, ...result.events],
                nextCursor: result.nextCursor,
                lastSyncedAt: result.lastSyncedAt,
                isCached: result.isCached,
              )
            : result;
        _loading = false;
        _loadingMore = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadingMore = false;
        _error = 'We could not load your recent activity.';
      });
    }
  }

  void _toggleSearch() {
    setState(() => _searchVisible = !_searchVisible);
    if (_searchVisible) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _searchFocus.requestFocus());
    } else {
      _search.clear();
      _unfocus();
      _load();
    }
  }

  void _unfocus() {
    _searchFocus.unfocus(disposition: UnfocusDisposition.scope);
    FocusManager.instance.primaryFocus?.unfocus(disposition: UnfocusDisposition.scope);
  }

  Future<void> _chooseFilter(ActivityFilter filter) async {
    Navigator.pop(context);
    if (_filter == filter) return;
    setState(() => _filter = filter);
    await _load();
  }

  Future<void> _openFilterMenu() async {
    final tokens = context.ehColors;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: tokens.surfaceCard,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Filter activity', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: tokens.textPrimary)),
              const SizedBox(height: 8),
              ...ActivityFilter.values.map(
                (filter) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(_filterIcon(filter), color: filter == _filter ? tokens.bluePrimary : tokens.textSecondary),
                  title: Text(activityFilterLabel(filter), style: TextStyle(color: tokens.textPrimary)),
                  trailing: filter == _filter ? Icon(Icons.check_rounded, color: tokens.success) : null,
                  onTap: () => _chooseFilter(filter),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openEvent(ActivityEvent event) async {
    if (!event.isNavigable) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ActivityEventDetailPage(
          eventId: event.id,
          repository: widget.repository,
          deviceRepository: widget.deviceRepository,
          routineRepository: widget.routineRepository,
        ),
      ),
    );
  }

  Future<void> _setSort(ActivitySort sort) async {
    if (_sort == sort) return;
    setState(() => _sort = sort);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.ehColors;
    final events = _page?.events ?? const <ActivityEvent>[];
    final groups = _groupEvents(events);
    return SafeArea(
      bottom: false,
      child: Scaffold(
        backgroundColor: tokens.bgApp,
        body: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: _unfocus,
          child: RefreshIndicator(
            onRefresh: () => _load(),
            child: ListView(
              key: const PageStorageKey<String>('activity-scroll'),
              controller: _scroll,
              padding: const EdgeInsets.fromLTRB(20, 22, 20, 106),
              children: [
                _ActivityHeader(onSearch: _toggleSearch, onFilter: _openFilterMenu),
                if (_searchVisible) ...[
                  const SizedBox(height: 16),
                  TextField(
                    controller: _search,
                    focusNode: _searchFocus,
                    style: TextStyle(color: tokens.textPrimary),
                    onChanged: (_) => _load(),
                    onTapOutside: (_) => _unfocus(),
                    decoration: InputDecoration(
                      hintText: 'Search activity',
                      hintStyle: TextStyle(color: tokens.textTertiary),
                      prefixIcon: Icon(Icons.search_rounded, color: tokens.textSecondary),
                      suffixIcon: IconButton(onPressed: () { _search.clear(); _load(); }, icon: Icon(Icons.close_rounded, color: tokens.textSecondary)),
                      filled: true,
                      fillColor: tokens.surfaceCard,
                      contentPadding: const EdgeInsets.symmetric(vertical: 17),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: tokens.borderControl),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: tokens.borderControl),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: tokens.bluePrimary, width: 1.5),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 17),
                _ActivityFilterRow(selected: _filter, onSelected: (value) { setState(() => _filter = value); _load(); }),
                const SizedBox(height: 16),
                _ActivitySummary(eventCount: events.length, sort: _sort, onSort: _setSort),
                const SizedBox(height: 20),
                if (_loading)
                  const _ActivityLoading()
                else if (_error != null)
                  _ActivityError(message: _error!, onRetry: _load)
                else if (events.isEmpty)
                  const _ActivityEmpty()
                else ...[
                  ...groups.entries.map((entry) => _ActivityGroup(label: entry.key, events: entry.value, onOpen: _openEvent)),
                  if (_page?.nextCursor != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 18),
                      child: OutlinedButton.icon(
                        onPressed: _loadingMore ? null : () => _load(append: true),
                        style: OutlinedButton.styleFrom(foregroundColor: tokens.bluePrimary, side: BorderSide(color: tokens.borderControl)),
                        icon: _loadingMore ? SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: tokens.bluePrimary)) : const Icon(Icons.expand_more_rounded),
                        label: const Text('Load more'),
                      ),
                    ),
                  const SizedBox(height: 20),
                  _ActivitySyncBanner(page: _page!),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Map<String, List<ActivityEvent>> _groupEvents(List<ActivityEvent> events) {
    final groups = <String, List<ActivityEvent>>{};
    final now = DateTime.now();
    for (final event in events) {
      final label = activityDateLabel(event.timestamp, now);
      groups.putIfAbsent(label, () => []).add(event);
    }
    return groups;
  }
}

class _ActivityHeader extends StatelessWidget {
  const _ActivityHeader({required this.onSearch, required this.onFilter});
  final VoidCallback onSearch;
  final VoidCallback onFilter;
  @override
  Widget build(BuildContext context) {
    final tokens = context.ehColors;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Activity', style: TextStyle(color: tokens.textPrimary, fontSize: 29, fontWeight: FontWeight.w800, height: 1)),
          const SizedBox(height: 7),
          Text('A simple history of what your home has done.', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: tokens.textSecondary, fontSize: 13)),
        ])),
        const SizedBox(width: 8),
        _ActivityRoundAction(icon: Icons.search_rounded, tooltip: 'Search activity', onTap: onSearch),
        const SizedBox(width: 8),
        _ActivityRoundAction(icon: Icons.tune_rounded, tooltip: 'Filter activity', onTap: onFilter),
      ],
    );
  }
}

class _ActivityRoundAction extends StatelessWidget {
  const _ActivityRoundAction({required this.icon, required this.tooltip, required this.onTap});
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final tokens = context.ehColors;
    return Semantics(
      button: true,
      label: tooltip,
      child: Material(
        color: tokens.surfaceElevated,
        shape: const CircleBorder(),
        elevation: 0,
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: SizedBox(
            width: 44,
            height: 44,
            child: Icon(icon, size: 23, color: tokens.bluePrimary),
          ),
        ),
      ),
    );
  }
}

class _ActivityFilterRow extends StatelessWidget {
  const _ActivityFilterRow({required this.selected, required this.onSelected});
  final ActivityFilter selected;
  final ValueChanged<ActivityFilter> onSelected;
  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    child: Row(
      children: ActivityFilter.values.map(
        (filter) => Padding(
          padding: const EdgeInsets.only(right: 8),
          child: _ActivityPill(
            label: activityFilterLabel(filter),
            selected: selected == filter,
            icon: _filterIcon(filter),
            onTap: () => onSelected(filter),
          ),
        ),
      ).toList(),
    ),
  );
}

class _ActivityPill extends StatelessWidget {
  const _ActivityPill({required this.label, required this.selected, required this.icon, required this.onTap});
  final String label;
  final bool selected;
  final IconData icon;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final tokens = context.ehColors;
    return Material(
      color: selected ? tokens.blueSelectedBg : tokens.surfaceCard,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: selected ? tokens.bluePrimary : tokens.borderControl),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: selected ? (tokens.isDark ? tokens.blueSelectedText : tokens.bluePrimary) : tokens.textSecondary),
              const SizedBox(width: 7),
              Text(
                label,
                style: TextStyle(
                  color: selected ? (tokens.isDark ? tokens.blueSelectedText : tokens.bluePrimary) : tokens.textPrimary,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActivitySummary extends StatelessWidget {
  const _ActivitySummary({required this.eventCount, required this.sort, required this.onSort});
  final int eventCount;
  final ActivitySort sort;
  final ValueChanged<ActivitySort> onSort;
  @override
  Widget build(BuildContext context) {
    final tokens = context.ehColors;
    return Card(
      color: tokens.surfaceCard,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        child: Row(
          children: [
            Icon(Icons.history_rounded, color: tokens.bluePrimary),
            const SizedBox(width: 10),
            Expanded(child: Text('$eventCount events', style: TextStyle(color: tokens.textSecondary, fontSize: 15, fontWeight: FontWeight.w700))),
            PopupMenuButton<ActivitySort>(
              onSelected: onSort,
              color: tokens.surfaceCard,
              itemBuilder: (_) => [
                PopupMenuItem(value: ActivitySort.recent, child: Text('Recent', style: TextStyle(color: tokens.textPrimary))),
                PopupMenuItem(value: ActivitySort.oldest, child: Text('Oldest', style: TextStyle(color: tokens.textPrimary))),
              ],
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 12),
                child: Row(
                  children: [
                    Text(sort == ActivitySort.recent ? 'Recent' : 'Oldest', style: TextStyle(color: tokens.bluePrimary, fontWeight: FontWeight.w700, fontSize: 13)),
                    Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: tokens.bluePrimary),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActivityGroup extends StatelessWidget {
  const _ActivityGroup({required this.label, required this.events, required this.onOpen});
  final String label;
  final List<ActivityEvent> events;
  final ValueChanged<ActivityEvent> onOpen;
  @override
  Widget build(BuildContext context) {
    final tokens = context.ehColors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(label, style: TextStyle(color: tokens.textPrimary, fontSize: 21, fontWeight: FontWeight.w800))),
            _CountBadge(count: events.length),
          ],
        ),
        const SizedBox(height: 10),
        ...events.asMap().entries.map((entry) => _ActivityEventTile(event: entry.value, isLast: entry.key == events.length - 1, onTap: () => onOpen(entry.value))),
        const SizedBox(height: 22),
      ],
    );
  }
}

class _CountBadge extends StatelessWidget {
  const _CountBadge({required this.count});
  final int count;
  @override
  Widget build(BuildContext context) {
    final tokens = context.ehColors;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: tokens.surfaceElevated,
        borderRadius: BorderRadius.circular(18),
        border: tokens.isDark ? Border.all(color: tokens.borderSubtle) : null,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        child: Text('$count ${count == 1 ? 'event' : 'events'}', style: TextStyle(color: tokens.textPrimary, fontSize: 12, fontWeight: FontWeight.w700)),
      ),
    );
  }
}

class _ActivityEventTile extends StatelessWidget {
  const _ActivityEventTile({required this.event, required this.isLast, required this.onTap});
  final ActivityEvent event;
  final bool isLast;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final tokens = context.ehColors;
    final visual = _eventVisual(event, tokens);
    final room = _roomLabel(event.roomId);
    final source = event.source == ActivitySource.routine ? (event.routineId == 'plant-care' ? 'Plant care' : 'Routine') : event.sourceLabel;
    return Semantics(
      button: event.isNavigable,
      label: '${event.title}, ${event.description}, ${visual.label}',
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: 52,
              child: Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Text(activityTimeLabel(event.timestamp), textAlign: TextAlign.right, style: TextStyle(color: tokens.textSecondary, fontSize: 12, fontWeight: FontWeight.w600)),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 42,
              child: Column(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(color: visual.background, shape: BoxShape.circle),
                    child: Icon(visual.icon, color: visual.color, size: 23),
                  ),
                  if (!isLast) Expanded(child: Container(width: 2, color: tokens.isDark ? tokens.borderSubtle : const Color(0xFFE5EAF1))),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Material(
                  color: tokens.surfaceCard,
                  borderRadius: BorderRadius.circular(14),
                  child: InkWell(
                    onTap: event.isNavigable ? onTap : null,
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        border: tokens.isDark ? Border.all(color: tokens.borderSubtle) : null,
                        boxShadow: tokens.isDark ? null : const [BoxShadow(color: Color(0x0C1D2B4B), blurRadius: 10, offset: Offset(0, 4))],
                      ),
                      padding: const EdgeInsets.fromLTRB(13, 12, 10, 12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(child: Text(event.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: tokens.textPrimary, fontWeight: FontWeight.w800, fontSize: 16))),
                                    const SizedBox(width: 5),
                                    _SeverityBadge(label: visual.label, color: visual.color, background: visual.background),
                                  ],
                                ),
                                const SizedBox(height: 5),
                                Text(event.description, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: tokens.textSecondary, fontSize: 13, height: 1.25)),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Icon(event.source == ActivitySource.routine ? Icons.auto_awesome_rounded : Icons.location_on_outlined, size: 16, color: tokens.textSecondary),
                                    const SizedBox(width: 5),
                                    Expanded(child: Text('$room  ·  $source', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: tokens.textSecondary, fontSize: 12))),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          if (event.isNavigable) Padding(padding: const EdgeInsets.only(left: 6, top: 27), child: Icon(Icons.chevron_right_rounded, color: tokens.chevron)),
                        ],
                      ),
                    ),
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

class _SeverityBadge extends StatelessWidget {
  const _SeverityBadge({required this.label, required this.color, this.background});
  final String label;
  final Color color;
  final Color? background;
  @override
  Widget build(BuildContext context) {
    final effectiveBg = background ?? color.withValues(alpha: .12);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(color: effectiveBg, borderRadius: BorderRadius.circular(14)),
      child: Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w800)),
    );
  }
}

class _ActivitySyncBanner extends StatelessWidget {
  const _ActivitySyncBanner({required this.page});
  final ActivityEventPage page;
  @override
  Widget build(BuildContext context) {
    final tokens = context.ehColors;
    return Card(
      color: tokens.isDark ? tokens.surfaceElevated : const Color(0xFFE7F0FC),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: tokens.isDark ? tokens.borderSubtle : const Color(0xFFC9DCF5)),
      ),
      child: ListTile(
        leading: Icon(Icons.shield_outlined, color: tokens.bluePrimary),
        title: Text(page.isCached ? 'Showing saved activity' : 'Showing latest activity', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: tokens.textPrimary)),
        subtitle: Text('Updated ${activityTimeLabel(page.lastSyncedAt)}', style: TextStyle(fontSize: 12, color: tokens.textSecondary)),
      ),
    );
  }
}

class _ActivityLoading extends StatelessWidget {
  const _ActivityLoading();
  @override
  Widget build(BuildContext context) {
    final tokens = context.ehColors;
    return Column(
      children: List.generate(
        3,
        (_) => Container(
          height: 92,
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: tokens.surfaceCard,
            borderRadius: BorderRadius.circular(14),
            border: tokens.isDark ? Border.all(color: tokens.borderSubtle) : null,
          ),
        ),
      ),
    );
  }
}

class _ActivityEmpty extends StatelessWidget {
  const _ActivityEmpty();
  @override
  Widget build(BuildContext context) {
    final tokens = context.ehColors;
    return Card(
      color: tokens.surfaceCard,
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          children: [
            Icon(Icons.history_rounded, size: 42, color: tokens.bluePrimary),
            const SizedBox(height: 10),
            Text('No activity yet', style: TextStyle(color: tokens.textPrimary, fontWeight: FontWeight.w800, fontSize: 17)),
            const SizedBox(height: 5),
            Text('Once your devices and routines start working, you will see their activity here.', textAlign: TextAlign.center, style: TextStyle(color: tokens.textSecondary)),
          ],
        ),
      ),
    );
  }
}

class _ActivityError extends StatelessWidget {
  const _ActivityError({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) {
    final tokens = context.ehColors;
    return Card(
      color: tokens.surfaceCard,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(Icons.cloud_off_rounded, size: 38, color: tokens.warning),
            const SizedBox(height: 10),
            Text(message, textAlign: TextAlign.center, style: TextStyle(color: tokens.textPrimary, fontWeight: FontWeight.w700)),
            const SizedBox(height: 14),
            FilledButton(
              onPressed: onRetry,
              style: FilledButton.styleFrom(backgroundColor: tokens.blueDarker, foregroundColor: tokens.textPrimary),
              child: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }
}

class ActivityEventDetailPage extends StatefulWidget {
  const ActivityEventDetailPage({
    super.key,
    required this.eventId,
    this.repository = const PreviewActivityRepository(),
    this.deviceRepository = const PreviewActivityDeviceRepository(),
    this.routineRepository = const PreviewRoutineRepository(),
  });

  final String eventId;
  final ActivityRepository repository;
  final ActivityDeviceRepository deviceRepository;
  final RoutineRepository routineRepository;

  @override
  State<ActivityEventDetailPage> createState() => _ActivityEventDetailPageState();
}

class _ActivityEventDetailPageState extends State<ActivityEventDetailPage> {
  ActivityEvent? _event;
  ActivityDeviceSnapshot? _device;
  Routine? _routine;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final event = await widget.repository.getEvent(widget.eventId);
    if (event != null) {
      _device = event.deviceId == null
          ? null
          : await widget.deviceRepository.getDevice(event.deviceId!);
      _routine = event.routineId == null
          ? null
          : await widget.routineRepository.getRoutine(event.routineId!);
    }
    if (mounted) {
      setState(() {
        _event = event;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.ehColors;
    if (_loading) {
      return Scaffold(
        backgroundColor: tokens.bgApp,
        body: Center(child: CircularProgressIndicator(color: tokens.bluePrimary)),
      );
    }
    final event = _event;
    if (event == null) {
      return Scaffold(
        backgroundColor: tokens.bgApp,
        appBar: AppBar(backgroundColor: tokens.bgApp, title: Text('Activity', style: TextStyle(color: tokens.textPrimary))),
        body: Center(child: Text('This activity is no longer available.', style: TextStyle(color: tokens.textSecondary))),
      );
    }

    final visual = _eventVisual(event, tokens);
    final isDeviceEvent = event.deviceId != null;
    return Scaffold(
      backgroundColor: tokens.bgApp,
      appBar: AppBar(
        backgroundColor: tokens.bgApp,
        elevation: 0,
        leading: IconButton(
          tooltip: 'Back to Activity',
          onPressed: () => Navigator.pop(context),
          icon: Icon(Icons.arrow_back_rounded, color: tokens.headerAction),
        ),
        title: Text(
          'Activity',
          style: TextStyle(
            color: tokens.bluePrimary,
            fontSize: 19,
            fontWeight: FontWeight.w800,
          ),
        ),
        actions: [
          PopupMenuButton<String>(
            tooltip: 'More options',
            color: tokens.surfaceCard,
            itemBuilder: (_) => [
              PopupMenuItem(value: 'event', child: Text('Event information', style: TextStyle(color: tokens.textPrimary))),
              PopupMenuItem(value: 'technical', child: Text('Technical details', style: TextStyle(color: tokens.textPrimary))),
            ],
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        children: [
          _EventHero(event: event, visual: visual),
          _ObservedEventCard(
            event: event,
            icon: visual.icon,
            color: visual.color,
            showIcon: isDeviceEvent,
          ),
          if (isDeviceEvent && _device != null)
            _DeviceSourceCard(
              device: _device!,
              event: event,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => DeviceDetailPage(device: _device!),
                ),
              ),
            ),
          if (event.deviceId != null && _device == null)
            const _DetailCard(
              title: 'Device',
              children: [
                Text(
                  'This device is no longer available.',
                ),
              ],
            ),
          if (_routine != null)
            _RoutineSourceCard(
              routine: _routine!,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => RoutineDetailPage(
                    routine: _routine!,
                    repository: widget.routineRepository,
                  ),
                ),
              ),
            ),
          _EventAboutCard(event: event),
          if (isDeviceEvent && _device != null)
            _WhatCanDoCard(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => DeviceDetailPage(device: _device!),
                ),
              ),
            ),
          if (isDeviceEvent && _device != null)
            _ActionButton(
              label: 'Go to device',
              icon: Icons.devices_other_rounded,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => DeviceDetailPage(device: _device!),
                ),
              ),
            ),
          if (event.type == ActivityEventType.systemUpdate)
            _ActionButton(
              label: 'View update',
              icon: Icons.system_update_alt_rounded,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SystemUpdatePage()),
              ),
            ),
          if (event.severity == ActivitySeverity.critical)
            _ActionButton(
              label: 'Review safety alert',
              icon: Icons.health_and_safety_outlined,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SafetyAlertPage()),
              ),
            ),
        ],
      ),
    );
  }
}

class _EventHero extends StatelessWidget {
  const _EventHero({required this.event, required this.visual});

  final ActivityEvent event;
  final ({IconData icon, Color color, Color background, String label}) visual;

  @override
  Widget build(BuildContext context) {
    final tokens = context.ehColors;
    final badge = event.type == ActivityEventType.deviceWarning
        ? 'Alert'
        : visual.label;
    final date = _eventDateTimeLabel(event.timestamp);
    return Card(
      margin: EdgeInsets.zero,
      color: tokens.surfaceCard,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: visual.background,
                shape: BoxShape.circle,
              ),
              child: Icon(visual.icon, color: visual.color, size: 32),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    event.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: tokens.textPrimary,
                      fontSize: 21,
                      height: 1.12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _SeverityBadge(label: badge, color: visual.color, background: visual.background),
                  const SizedBox(height: 10),
                  Text(
                    event.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: tokens.textSecondary,
                      fontSize: 14,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _HeroMeta(
                    icon: Icons.schedule_rounded,
                    text: date,
                  ),
                  const SizedBox(height: 5),
                  _HeroMeta(
                    icon: Icons.location_on_outlined,
                    text: '${_roomLabel(event.roomId)} · ${event.sourceLabel}',
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

class _HeroMeta extends StatelessWidget {
  const _HeroMeta({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final tokens = context.ehColors;
    return Row(
      children: [
        Icon(icon, size: 17, color: tokens.textSecondary),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: tokens.textSecondary,
              fontSize: 13,
            ),
          ),
        ),
      ],
    );
  }
}

class _ObservedEventCard extends StatelessWidget {
  const _ObservedEventCard({
    required this.event,
    required this.icon,
    required this.color,
    required this.showIcon,
  });

  final ActivityEvent event;
  final IconData icon;
  final Color color;
  final bool showIcon;

  @override
  Widget build(BuildContext context) {
    final tokens = context.ehColors;
    return Card(
      margin: const EdgeInsets.only(top: 14),
      color: tokens.surfaceCard,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'What happened',
                    style: TextStyle(
                      color: tokens.textPrimary,
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    event.eventData['observed'] ?? event.description,
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: tokens.textSecondary,
                      fontSize: 14,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            if (showIcon) ...[
              const SizedBox(width: 10),
              Container(
                width: 52,
                height: 52,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: tokens.surfaceElevated,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: 26, color: color.withValues(alpha: .7)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _DetailCard extends StatelessWidget {
  const _DetailCard({required this.title, required this.children});
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final tokens = context.ehColors;
    return Card(
      margin: const EdgeInsets.only(top: 14),
      color: tokens.surfaceCard,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                color: tokens.textPrimary,
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _DeviceSourceCard extends StatelessWidget {
  const _DeviceSourceCard({required this.device, required this.event, required this.onTap});
  final ActivityDeviceSnapshot device;
  final ActivityEvent event;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.ehColors;
    final connected = device.connection == ActivityDeviceConnection.online;
    return Card(
      margin: const EdgeInsets.only(top: 14),
      color: tokens.surfaceCard,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Device',
                    style: TextStyle(
                      color: tokens.textPrimary,
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: onTap,
                  style: TextButton.styleFrom(foregroundColor: tokens.bluePrimary),
                  child: const Text('View device'),
                ),
                Icon(Icons.chevron_right_rounded, color: tokens.bluePrimary),
              ],
            ),
            const SizedBox(height: 5),
            Row(
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: tokens.iconBgBlue,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    Icons.air_rounded,
                    color: tokens.bluePrimary,
                    size: 30,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        device.name,
                        style: TextStyle(
                          color: tokens.textPrimary,
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(device.room, style: TextStyle(color: tokens.textSecondary)),
                      const SizedBox(height: 6),
                      Text(
                        connected ? 'Online' : 'Offline',
                        style: TextStyle(
                          color: connected ? tokens.success : tokens.warning,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            Divider(height: 26, color: tokens.borderSubtle),
            LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 360;
                final update = _Metric(
                  label: 'Last update',
                  value: device.lastSeen == null ? 'Unavailable' : activityTimeLabel(device.lastSeen!),
                  detail: device.lastSeen == null ? 'Unavailable' : 'Event time ${activityTimeLabel(event.timestamp)}',
                );
                final reading = _Metric(
                  label: 'Last reading',
                  value: device.lastReading,
                  detail: device.lastReading == 'Unavailable' ? 'Unavailable' : 'Current value',
                );
                final battery = _Metric(
                  label: 'Battery',
                  value: device.battery ?? 'Unavailable',
                  detail: device.battery == null ? 'Unavailable' : 'Good',
                );
                if (!compact) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: update),
                      const _MetricDivider(),
                      Expanded(child: reading),
                      const _MetricDivider(),
                      Expanded(child: battery),
                    ],
                  );
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    update,
                    Divider(height: 22, color: tokens.borderSubtle),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: reading),
                        const _MetricDivider(),
                        Expanded(child: battery),
                      ],
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value, required this.detail});
  final String label;
  final String value;
  final String detail;

  @override
  Widget build(BuildContext context) {
    final tokens = context.ehColors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: tokens.textSecondary, fontSize: 12)),
        const SizedBox(height: 6),
        Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: tokens.textPrimary, fontSize: 14, fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        Text(detail, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: tokens.textSecondary, fontSize: 11)),
      ],
    );
  }
}

class _MetricDivider extends StatelessWidget {
  const _MetricDivider();
  @override
  Widget build(BuildContext context) {
    final tokens = context.ehColors;
    return Container(width: 1, height: 64, margin: const EdgeInsets.symmetric(horizontal: 8), color: tokens.borderSubtle);
  }
}

class _RoutineSourceCard extends StatelessWidget {
  const _RoutineSourceCard({required this.routine, required this.onTap});
  final Routine routine;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.ehColors;
    return Card(
      margin: const EdgeInsets.only(top: 14),
      color: tokens.surfaceCard,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text('Routine', style: TextStyle(color: tokens.textPrimary, fontSize: 17, fontWeight: FontWeight.w800))),
                TextButton(
                  onPressed: onTap,
                  style: TextButton.styleFrom(foregroundColor: tokens.bluePrimary),
                  child: const Text('View routine'),
                ),
                Icon(Icons.chevron_right_rounded, color: tokens.bluePrimary),
              ],
            ),
            Text(routine.name, style: TextStyle(color: tokens.textPrimary, fontWeight: FontWeight.w700, fontSize: 16)),
            const SizedBox(height: 5),
            Text(routine.trigger.title, style: TextStyle(color: tokens.textSecondary)),
            const SizedBox(height: 5),
            Text(routine.actions.map((action) => '${action.title} · ${action.detail}').join(', '), style: TextStyle(color: tokens.textSecondary)),
          ],
        ),
      ),
    );
  }
}

class _EventAboutCard extends StatelessWidget {
  const _EventAboutCard({required this.event});
  final ActivityEvent event;

  @override
  Widget build(BuildContext context) {
    final tokens = context.ehColors;
    return Card(
      margin: const EdgeInsets.only(top: 14),
      color: tokens.surfaceCard,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('About this event', style: TextStyle(color: tokens.textPrimary, fontSize: 17, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            _AboutRow(icon: Icons.sell_outlined, label: 'Source', value: event.sourceLabel),
            _AboutRow(icon: Icons.info_outline_rounded, label: 'Event type', value: _eventTypeLabel(event.type)),
            _AboutRow(icon: Icons.calendar_today_outlined, label: 'Recorded on', value: _eventDateTimeLabel(event.timestamp)),
          ],
        ),
      ),
    );
  }
}

class _AboutRow extends StatelessWidget {
  const _AboutRow({required this.icon, required this.label, required this.value});
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final tokens = context.ehColors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Icon(icon, size: 21, color: tokens.textSecondary),
          const SizedBox(width: 12),
          Expanded(child: Text(label, style: TextStyle(color: tokens.textSecondary, fontSize: 14))),
          Flexible(child: Text(value, textAlign: TextAlign.right, style: TextStyle(color: tokens.textPrimary, fontSize: 14, fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }
}

class _WhatCanDoCard extends StatelessWidget {
  const _WhatCanDoCard({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.ehColors;
    return Card(
      margin: const EdgeInsets.only(top: 14),
      color: tokens.surfaceCard,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('What you can do', style: TextStyle(color: tokens.textPrimary, fontSize: 17, fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            Material(
              color: tokens.warningContainer,
              borderRadius: BorderRadius.circular(14),
              child: InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(14),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      CircleAvatar(backgroundColor: tokens.surfaceCard, child: Icon(Icons.assignment_outlined, color: tokens.warning)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Check your air sensor', style: TextStyle(color: tokens.textPrimary, fontWeight: FontWeight.w800)),
                            const SizedBox(height: 4),
                            Text('Make sure the sensor is powered on and securely connected.', style: TextStyle(color: tokens.textSecondary, fontSize: 12, height: 1.25)),
                          ],
                        ),
                      ),
                      Icon(Icons.chevron_right_rounded, color: tokens.chevron),
                    ],
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

class _ActionButton extends StatelessWidget {
  const _ActionButton({required this.label, required this.icon, required this.onTap});
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.ehColors;
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: SizedBox(
        width: double.infinity,
        height: 52,
        child: FilledButton.icon(
          onPressed: onTap,
          style: FilledButton.styleFrom(backgroundColor: tokens.blueDarker, foregroundColor: tokens.textPrimary),
          icon: Icon(icon),
          label: Text(label),
        ),
      ),
    );
  }
}

class DeviceDetailPage extends StatelessWidget {
  const DeviceDetailPage({super.key, required this.device});
  final ActivityDeviceSnapshot device;

  @override
  Widget build(BuildContext context) {
    final tokens = context.ehColors;
    return Scaffold(
      backgroundColor: tokens.bgApp,
      appBar: AppBar(
        backgroundColor: tokens.bgApp,
        title: Text(device.name, style: TextStyle(color: tokens.textPrimary)),
        leading: IconButton(onPressed: () => Navigator.pop(context), icon: Icon(Icons.arrow_back_rounded, color: tokens.headerAction)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Card(
            color: tokens.surfaceCard,
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(device.room, style: TextStyle(color: tokens.textSecondary)),
                  const SizedBox(height: 10),
                  Text(
                    device.connectionLabel,
                    style: TextStyle(
                      color: device.connection == ActivityDeviceConnection.online ? tokens.success : tokens.warning,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text('Last reading: ${device.lastReading}', style: TextStyle(color: tokens.textPrimary)),
                  if (device.lastSeen != null) Text('Last update: ${activityTimeLabel(device.lastSeen!)}', style: TextStyle(color: tokens.textSecondary)),
                  if (device.battery != null) Text('Battery: ${device.battery}', style: TextStyle(color: tokens.textSecondary)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          Card(
            color: tokens.surfaceCard,
            child: ListTile(
              leading: Icon(Icons.info_outline_rounded, color: tokens.bluePrimary),
              title: Text('Controls stay protected', style: TextStyle(color: tokens.textPrimary)),
              subtitle: Text('Commands require secure device acknowledgement.', style: TextStyle(color: tokens.textSecondary)),
            ),
          ),
        ],
      ),
    );
  }
}

String _eventDateTimeLabel(DateTime value) {
  final now = DateTime.now();
  final day = activityDateLabel(value, now);
  final month = <String>['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'][value.month - 1];
  final date = day == 'Today' ? 'Today' : '$day, $month ${value.day}, ${value.year}';
  return '$date · ${activityTimeLabel(value)}';
}

String _eventTypeLabel(ActivityEventType type) => switch (type) {
      ActivityEventType.deviceStateChanged => 'Device state',
      ActivityEventType.deviceWarning => 'Sensor alert',
      ActivityEventType.routineCompleted => 'Routine',
      ActivityEventType.routineFailed => 'Routine failed',
      ActivityEventType.userAction => 'User action',
      ActivityEventType.systemUpdate => 'System update',
      ActivityEventType.connectionChanged => 'Connection',
      ActivityEventType.safetyAlert => 'Safety alert',
    };

IconData _filterIcon(ActivityFilter filter) => switch (filter) {
      ActivityFilter.all => Icons.grid_view_rounded,
      ActivityFilter.alerts => Icons.warning_amber_rounded,
      ActivityFilter.devices => Icons.devices_other_rounded,
      ActivityFilter.routines => Icons.auto_awesome_rounded,
      ActivityFilter.system => Icons.settings_suggest_outlined,
    };

String _roomLabel(String? roomId) => switch (roomId) {
      'kitchen' => 'Kitchen',
      'plant' => 'Plant Corner',
      'living' => 'Living Room',
      'tank' => 'Water Tank',
      _ => 'Home',
    };

({IconData icon, Color color, Color background, String label}) _eventVisual(ActivityEvent event, EHThemeTokens tokens) {
  if (tokens.isDark) {
    return switch (event.severity) {
      ActivitySeverity.success => (icon: Icons.check_circle_rounded, color: tokens.success, background: tokens.successContainer, label: 'Success'),
      ActivitySeverity.warning => (icon: Icons.warning_amber_rounded, color: tokens.warning, background: tokens.warningContainer, label: 'Warning'),
      ActivitySeverity.critical => (icon: Icons.error_rounded, color: tokens.errorText, background: tokens.errorContainer, label: 'Critical'),
      ActivitySeverity.info => (icon: Icons.info_outline_rounded, color: tokens.bluePrimary, background: tokens.blueSelectedBg, label: 'Info'),
    };
  }
  return switch (event.severity) {
    ActivitySeverity.success => (icon: Icons.check_circle_rounded, color: const Color(0xFF16A95A), background: const Color(0xFFE5F5EC), label: 'Success'),
    ActivitySeverity.warning => (icon: Icons.warning_amber_rounded, color: const Color(0xFFF26D12), background: const Color(0xFFFFEEE6), label: 'Warning'),
    ActivitySeverity.critical => (icon: Icons.error_rounded, color: const Color(0xFFC63D32), background: const Color(0xFFFFE4E4), label: 'Critical'),
    ActivitySeverity.info => (icon: Icons.info_outline_rounded, color: const Color(0xFF14539D), background: const Color(0xFFE8F0FF), label: 'Info'),
  };
}
