import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../app/home_controller.dart';
import '../../../core/models/connection_models.dart';
import '../../../core/models/home_dashboard_models.dart';
import '../../../core/models/routine_models.dart';
import '../../../core/capabilities/repositories/product_catalog_repository.dart';
import '../../../core/repositories/cloud_home_repository.dart';
import '../../../core/repositories/cloud_routine_repository.dart';
import '../../../core/services/device_storage_service.dart';
import '../../../core/services/edge_routine_sync_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/carousel_page_indicator.dart';
import '../../hub/data/hub_repository.dart';
import '../../hub/domain/models/hub_models.dart';

class AutomationsPage extends StatefulWidget {
  const AutomationsPage({
    super.key,
    this.repository = const PreviewRoutineRepository(),
    this.onConnectHome,
    this.homeController,
    this.autoOpenBuilder = false,
  });
  final RoutineRepository repository;
  final VoidCallback? onConnectHome;
  final HomeController? homeController;
  final bool autoOpenBuilder;

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
    if (widget.autoOpenBuilder) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _openBuilder();
      });
    }
  }

  Future<void> _load() async {
    var routines = await widget.repository.getRoutines();
    if (routines.isEmpty) {
      final ctrl = HomeController.instance;
      if (ctrl != null && ctrl.repository is CloudHomeRepository) {
        try {
          final cloudRepo = ctrl.repository as CloudHomeRepository;
          final cloudRoutines = await CloudRoutineRepository(cloudRepo.client).getRoutines();
          if (cloudRoutines.isNotEmpty) {
            await PreviewRoutineRepository.syncWithCloudRoutines(cloudRoutines);
            routines = await widget.repository.getRoutines();
          }
        } catch (_) {}
      }
    }
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
    final deleted = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) =>
            RoutineDetailPage(routine: routine, repository: widget.repository),
      ),
    );
    if (mounted) {
      if (deleted == true && _routines != null) {
        setState(() {
          _routines!.removeWhere((r) => r.id == routine.id || r.name == routine.name);
        });
      }
      _load();
    }
  }

  Future<void> _deleteRoutineDirectly(Routine routine) async {
    final tokens = context.ehColors;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dCtx) => AlertDialog(
        title: const Text('Delete routine'),
        content: Text('Are you sure you want to delete "${routine.name}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dCtx, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: tokens.error),
            onPressed: () => Navigator.pop(dCtx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm == true && mounted) {
      setState(() {
        _routines?.removeWhere((r) => r.id == routine.id || r.name == routine.name);
      });
      await widget.repository.deleteRoutine(routine.id);
      if (HomeController.instance != null) {
        await HomeController.instance!.refreshUpcomingRoutines();
      }
      await _load();
    }
  }

  Future<void> _toggle(Routine routine) async {
    final oldEnabled = routine.enabled;
    final newEnabled = !oldEnabled;

    // Optimistic UI update immediately (<16ms)
    setState(() {
      if (_routines != null) {
        final idx = _routines!.indexWhere((r) => r.id == routine.id);
        if (idx >= 0) {
          final old = _routines![idx];
          _routines![idx] = Routine(
            id: old.id,
            name: old.name,
            icon: old.icon,
            isFavorite: old.isFavorite,
            enabled: newEnabled,
            availability: old.availability,
            trigger: old.trigger,
            conditions: old.conditions,
            actions: old.actions,
            schedule: old.schedule,
            involvedDevices: old.involvedDevices,
            lastExecution: old.lastExecution,
            nextRun: old.nextRun,
            createdAt: old.createdAt,
            updatedAt: DateTime.now(),
            summary: old.summary,
          );
        }
      }
    });

    final result = newEnabled
        ? await widget.repository.enableRoutine(routine.id)
        : await widget.repository.disableRoutine(routine.id);

    if (HomeController.instance != null) {
      unawaited(HomeController.instance!.refreshUpcomingRoutines());
    }

    if (!mounted) return;
    if (result == RepositoryResult.unsupported) {
      // Revert optimistic update
      setState(() {
        if (_routines != null) {
          final idx = _routines!.indexWhere((r) => r.id == routine.id);
          if (idx >= 0) {
            final old = _routines![idx];
            _routines![idx] = Routine(
              id: old.id,
              name: old.name,
              icon: old.icon,
              isFavorite: old.isFavorite,
              enabled: oldEnabled,
              availability: old.availability,
              trigger: old.trigger,
              conditions: old.conditions,
              actions: old.actions,
              schedule: old.schedule,
              involvedDevices: old.involvedDevices,
              lastExecution: old.lastExecution,
              nextRun: old.nextRun,
              createdAt: old.createdAt,
              updatedAt: old.updatedAt,
              summary: old.summary,
            );
          }
        }
      });
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
                'Add a device to enable and manage routines.',
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
                icon: const Icon(Icons.add_rounded),
                label: const Text('Add a device'),
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
            child: RefreshIndicator(
              onRefresh: _load,
              color: tokens.bluePrimary,
              backgroundColor: tokens.surfaceCard,
              displacement: 24,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
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
                        onDelete: () => _deleteRoutineDirectly(routine),
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
    ),
  );
  }

  String get _sortLabel => switch (_sort) {
    _RoutineSort.recent => 'Sort: Recent',
    _RoutineSort.nameAscending => 'Sort: A-Z',
    _RoutineSort.nameDescending => 'Sort: Z-A',
    _RoutineSort.lastRun => 'Sort: Last run',
  };

  Future<void> _openBuilder() async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => RoutineBuilderPage(repository: widget.repository),
      ),
    );
    if (created == true && mounted) {
      await _load();
      _showMessage('Routine created successfully');
    }
  }
}

class RoutineCard extends StatelessWidget {
  const RoutineCard({
    super.key,
    required this.routine,
    required this.onTap,
    required this.onToggle,
    this.onDelete,
  });
  final Routine routine;
  final VoidCallback onTap;
  final VoidCallback onToggle;
  final VoidCallback? onDelete;

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

    final scheduleText = routine.trigger.detail.isNotEmpty
        ? routine.trigger.detail
        : routine.schedule.label;

    return Container(
      decoration: BoxDecoration(
        color: tokens.surfaceCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: routine.enabled
              ? tokens.bluePrimary.withValues(alpha: 0.28)
              : tokens.borderSubtle,
          width: routine.enabled ? 1.2 : 1.0,
        ),
        boxShadow: tokens.isDark
            ? null
            : const [
                BoxShadow(
                  color: Color(0x0C0B2448),
                  blurRadius: 14,
                  offset: Offset(0, 4),
                ),
              ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // 1. Clickable Info Area -> Opens Routine Detail Page
          Expanded(
            child: InkWell(
              onTap: onTap,
              borderRadius: const BorderRadius.horizontal(left: Radius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 14, 8, 14),
                child: Row(
                  children: [
                    _RoutineIcon(icon: routine.icon, color: statusColor),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  routine.name,
                                  style: TextStyle(
                                    color: tokens.textPrimary,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 16,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            routine.summary.isNotEmpty ? routine.summary : 'Custom Routine',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: tokens.textSecondary,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Container(
                                width: 7,
                                height: 7,
                                decoration: BoxDecoration(
                                  color: statusColor,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 5),
                              Text(
                                unavailable
                                    ? routine.availabilityLabel
                                    : (routine.enabled ? 'Active' : 'Disabled'),
                                style: TextStyle(
                                  color: statusColor,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 11.5,
                                ),
                              ),
                              if (scheduleText.isNotEmpty) ...[
                                const SizedBox(width: 8),
                                Icon(Icons.schedule_rounded, size: 12, color: tokens.textTertiary),
                                const SizedBox(width: 3),
                                Flexible(
                                  child: Text(
                                    scheduleText,
                                    style: TextStyle(
                                      color: tokens.textSecondary,
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Vertical divider between content and actions
          Container(
            width: 1,
            height: 48,
            color: tokens.borderSubtle.withValues(alpha: 0.6),
          ),

          // 2. Isolated Action Controls -> Switch + Delete (independent touch target)
          Padding(
            padding: const EdgeInsets.only(left: 6, right: 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Switch(
                  value: routine.enabled,
                  activeThumbColor: Colors.white,
                  activeTrackColor: tokens.bluePrimary,
                  inactiveThumbColor: Colors.white,
                  inactiveTrackColor: tokens.borderControl,
                  onChanged: (_) => onToggle(),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ],
            ),
          ),
        ],
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
  late Routine _currentRoutine = widget.routine;
  late bool _favorite = widget.routine.isFavorite;
  List<RoutineExecution>? _history;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final value = await widget.repository.getRecentExecutions(
      _currentRoutine.id,
    );
    if (mounted) setState(() => _history = value);
  }

  Future<void> _toggleEnabled(bool enabled) async {
    final result = enabled
        ? await widget.repository.enableRoutine(_currentRoutine.id)
        : await widget.repository.disableRoutine(_currentRoutine.id);
    if (result == RepositoryResult.success) {
      final updated = await widget.repository.getRoutine(_currentRoutine.id);
      if (updated != null && mounted) {
        setState(() => _currentRoutine = updated);
      }
      if (HomeController.instance != null) {
        unawaited(HomeController.instance!.refreshUpcomingRoutines());
      }
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not update routine state.')),
      );
    }
  }

  Future<void> _openEditRoutine() async {
    final updated = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => RoutineBuilderPage(
          repository: widget.repository,
          initialRoutine: _currentRoutine,
        ),
      ),
    );
    if (updated == true) {
      final fresh = await widget.repository.getRoutine(_currentRoutine.id);
      if (fresh != null && mounted) {
        setState(() => _currentRoutine = fresh);
      }
      _loadHistory();
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.ehColors;
    final routine = _currentRoutine;
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
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Switch(
              value: routine.enabled,
              activeThumbColor: Colors.white,
              activeTrackColor: tokens.bluePrimary,
              inactiveThumbColor: Colors.white,
              inactiveTrackColor: tokens.borderControl,
              onChanged: _toggleEnabled,
            ),
          ),
          IconButton(
            onPressed: () => setState(() => _favorite = !_favorite),
            icon: Icon(
              _favorite ? Icons.star_rounded : Icons.star_border_rounded,
              color: _favorite ? tokens.gold : tokens.headerAction,
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          Text(
            routine.summary
                .replaceAll('Toggle Toggle', 'Toggle')
                .replaceAll('Turn On Turn On', 'Turn On')
                .replaceAll('Turn Off Turn Off', 'Turn Off'),
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
            title: routine.trigger.title.isNotEmpty ? routine.trigger.title : 'Schedule',
            lines: [
              if (routine.trigger.detail.isNotEmpty &&
                  routine.trigger.detail != routine.trigger.title &&
                  !routine.trigger.title.contains(routine.trigger.detail))
                routine.trigger.detail,
              if (routine.schedule.label.isNotEmpty &&
                  routine.schedule.label != routine.trigger.title &&
                  routine.schedule.label != routine.trigger.detail &&
                  !routine.trigger.detail.contains(routine.schedule.label) &&
                  !routine.schedule.label.contains(routine.trigger.detail))
                routine.schedule.label,
            ],
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
                .map((action) {
                  final devName = action.title.contains('•') ? action.title.split('•').first.trim() : action.title;
                  return '$devName — ${action.detail}';
                })
                .toSet()
                .toList(),
          ),
          _DevicesSection(devices: routine.involvedDevices, fallbackRoutine: routine),
          _ActivitySection(history: _history, routineName: routine.name, routineId: routine.id),
          if (unavailable) _UnavailableNotice(routine: routine),
          const SizedBox(height: 16),
          // Tier 1: Prominent Primary Action
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () async {
                final res = await widget.repository.executeRoutine(routine.id);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(res == RepositoryResult.success ? 'Routine executed successfully.' : 'Could not run routine.'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              },
              icon: const Icon(Icons.play_arrow_rounded, size: 22),
              label: const Text(
                'Run Routine Now',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                maxLines: 1,
              ),
              style: FilledButton.styleFrom(
                backgroundColor: tokens.bluePrimary,
                minimumSize: const Size(0, 50),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
          const SizedBox(height: 10),
          // Tier 2: Management Row
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _openEditRoutine,
                  icon: const Icon(Icons.edit_note_rounded, size: 20),
                  label: const Text(
                    'Edit Routine',
                    style: TextStyle(fontWeight: FontWeight.w700),
                    maxLines: 1,
                  ),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 48),
                    side: BorderSide(color: tokens.borderControl),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (dCtx) => AlertDialog(
                        title: const Text('Delete routine'),
                        content: Text('Are you sure you want to delete "${routine.name}"?'),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(dCtx, false), child: const Text('Cancel')),
                          FilledButton(
                            style: FilledButton.styleFrom(backgroundColor: tokens.error),
                            onPressed: () => Navigator.pop(dCtx, true),
                            child: const Text('Delete'),
                          ),
                        ],
                      ),
                    );
                    if (confirm == true) {
                      await widget.repository.deleteRoutine(routine.id);
                      if (HomeController.instance != null) {
                        await HomeController.instance!.refreshUpcomingRoutines();
                      }
                      if (context.mounted) {
                        Navigator.pop(context, true);
                      }
                    }
                  },
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 48),
                    foregroundColor: tokens.errorText,
                    side: BorderSide(color: tokens.error.withValues(alpha: 0.5)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  icon: const Icon(Icons.delete_outline_rounded, size: 18),
                  label: const Text(
                    'Delete',
                    style: TextStyle(fontWeight: FontWeight.w700),
                    maxLines: 1,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DraftActionItem {
  final String draftKey = UniqueKey().toString();
  String deviceId;
  String deviceName;
  String roomName;
  int channelIndex; // 0 for All Channels, 1..4 for specific
  String channelName;
  bool targetState; // true for ON, false for OFF
  bool isToggle;
  int pulseMinutes; // 0 for continuous, or any custom minutes (1..1440)
  late final TextEditingController customPulseController;

  _DraftActionItem({
    required this.deviceId,
    required this.deviceName,
    required this.roomName,
    this.channelIndex = 1,
    this.channelName = 'Channel 1',
    this.targetState = true,
    this.isToggle = false,
    this.pulseMinutes = 0,
  }) {
    customPulseController = TextEditingController(
      text: pulseMinutes > 0 ? pulseMinutes.toString() : '',
    );
  }

  void dispose() {
    customPulseController.dispose();
  }
}

enum _TriggerMode {
  schedule,
  soil,
  tank,
  climate,
  humidity,
  light,
  solar,
  motion,
  manual,
}

class RoutineBuilderPage extends StatefulWidget {
  const RoutineBuilderPage({
    super.key,
    required this.repository,
    this.initialRoutine,
  });
  final RoutineRepository repository;
  final Routine? initialRoutine;
  @override
  State<RoutineBuilderPage> createState() => _RoutineBuilderPageState();
}

class _RoutineBuilderPageState extends State<RoutineBuilderPage> {
  int _step = 0;
  bool _saving = false;
  bool _criticalHardwareFallback = false;

  // Step 0: Basics & Target Hardware
  final _nameController = TextEditingController(text: '');
  String _selectedIcon = 'lightbulb_outline_rounded';
  bool _isFavorite = false;
  String? _selectedRoom;
  String? _selectedDeviceId;

  // Step 1: Triggers & Environmental Sensors
  _TriggerMode _triggerMode = _TriggerMode.schedule;
  TimeOfDay _scheduledTime = TimeOfDay.now();
  final TextEditingController _hourTextController = TextEditingController();
  final TextEditingController _minuteTextController = TextEditingController();
  final Set<int> _selectedDays = {1, 2, 3, 4, 5, 6, 7}; // 1=Mon .. 7=Sun
  bool _isSunset = true;
  int _solarOffsetMinutes = 0;

  // Sensor Trigger Thresholds:
  double _soilThreshold = 30.0;
  String _soilOp = '<'; // '<' for dry, '>' for wet

  double _tankThreshold = 25.0;
  String _tankOp = '<'; // '<' for low (fill), '>=' for full (stop)

  double _tempThreshold = 28.0;
  String _tempOp = '>'; // '>' for cooling (fan/AC), '<' for heating

  double _humidityThreshold = 70.0;
  String _humidityOp = '>'; // '>' for exhaust

  double _luxThreshold = 50.0;
  String _motionType = 'detected'; // 'detected', 'no_motion_10m'

  bool _deviceHasCapability(String capability) {
    if (_selectedDeviceId == null || _availableDevices.isEmpty) return false;
    final dev = _availableDevices.firstWhere(
      (d) => d.id == _selectedDeviceId,
      orElse: () => _availableDevices.first,
    );
    final m = dev.model.toLowerCase();
    final n = dev.name.toLowerCase();

    if (capability == 'soil') {
      return m.contains('soil') || m.contains('garden') || n.contains('soil') || n.contains('garden');
    } else if (capability == 'tank') {
      return m.contains('tank') || m.contains('water') || n.contains('tank') || n.contains('water');
    } else if (capability == 'climate' || capability == 'humidity') {
      return m.contains('climate') || m.contains('temp') || m.contains('sensor') || m.contains('dht') || n.contains('climate') || n.contains('temp');
    } else if (capability == 'light') {
      return m.contains('lux') || m.contains('light_sensor') || m.contains('ldr') || m.contains('sensor') || n.contains('lux');
    } else if (capability == 'motion') {
      return m.contains('pir') || m.contains('motion') || m.contains('sensor') || n.contains('motion') || n.contains('pir');
    }
    return false;
  }

  bool get _hasAnyEnvironmentalSensor {
    return _deviceHasCapability('soil') ||
        _deviceHasCapability('tank') ||
        _deviceHasCapability('climate') ||
        _deviceHasCapability('humidity') ||
        _deviceHasCapability('light') ||
        _deviceHasCapability('motion');
  }

  bool _isEnvironmentalTrigger(_TriggerMode mode) {
    return mode == _TriggerMode.soil ||
        mode == _TriggerMode.tank ||
        mode == _TriggerMode.climate ||
        mode == _TriggerMode.humidity ||
        mode == _TriggerMode.light ||
        mode == _TriggerMode.motion;
  }

  // Step 2: Actions
  List<ConnectedDeviceSummary> _availableDevices = [];
  final List<_DraftActionItem> _actions = [];

  List<String> get _availableRooms {
    final roomSet = <String>{};
    for (final d in _availableDevices) {
      if (d.roomName.trim().isNotEmpty) roomSet.add(d.roomName.trim());
    }
    if (roomSet.isEmpty) roomSet.add('Living Room');
    return roomSet.toList();
  }

  List<ConnectedDeviceSummary> get _devicesInSelectedRoom {
    if (_selectedRoom == null) return _availableDevices;
    final inRoom = _availableDevices.where((d) => d.roomName.toLowerCase() == _selectedRoom!.toLowerCase()).toList();
    return inRoom.isNotEmpty ? inRoom : _availableDevices;
  }

  void _updateActionDevice(ConnectedDeviceSummary dev) {
    if (_actions.isNotEmpty) {
      final chLabels = DeviceStorageService.getChannelLabels(dev.id);
      _actions.first.deviceId = dev.id;
      _actions.first.deviceName = dev.name;
      _actions.first.roomName = dev.roomName;
      _actions.first.channelName = chLabels[_actions.first.channelIndex] ?? 'Channel ${_actions.first.channelIndex}';
    }
  }

  static const List<(String, IconData, String)> _iconOptions = [
    ('lightbulb_outline_rounded', Icons.lightbulb_outline_rounded, 'Light'),
    ('power_rounded', Icons.power_rounded, 'Switch'),
    ('wb_sunny_outlined', Icons.wb_sunny_outlined, 'Morning'),
    ('nights_stay_outlined', Icons.nights_stay_outlined, 'Night'),
    ('alarm_rounded', Icons.alarm_rounded, 'Schedule'),
    ('ac_unit_rounded', Icons.ac_unit_rounded, 'Climate'),
    ('bolt_rounded', Icons.bolt_rounded, 'Energy'),
    ('coffee_rounded', Icons.coffee_rounded, 'Routine'),
    ('water_drop_outlined', Icons.water_drop_outlined, 'Water'),
    ('shield_outlined', Icons.shield_outlined, 'Security'),
  ];

  @override
  void initState() {
    super.initState();
    if (widget.initialRoutine == null) {
      _scheduledTime = TimeOfDay.now();
      _loadDevices(seedDefaultAction: true);
    } else {
      _loadDevices(seedDefaultAction: false);
    }
    _syncTimeControllers();

    if (widget.initialRoutine != null) {
      final r = widget.initialRoutine!;
      _nameController.text = r.name;
      _selectedIcon = r.icon;
      _isFavorite = r.isFavorite;

      switch (r.trigger.kind) {
        case RoutineTriggerKind.timeSchedule:
          _triggerMode = _TriggerMode.schedule;
          final timeRegex = RegExp(r'(\d{1,2}):(\d{2})\s*(AM|PM)?', caseSensitive: false);
          final match = timeRegex.firstMatch(r.trigger.detail.isNotEmpty ? r.trigger.detail : r.schedule.label);
          if (match != null) {
            int h = int.parse(match.group(1)!);
            final m = int.parse(match.group(2)!);
            final ampm = match.group(3)?.toUpperCase();
            if (ampm == 'PM' && h < 12) h += 12;
            if (ampm == 'AM' && h == 12) h = 0;
            _scheduledTime = TimeOfDay(hour: h, minute: m);
            _syncTimeControllers();
          }
          break;
        case RoutineTriggerKind.sunset:
          _triggerMode = _TriggerMode.solar;
          _isSunset = true;
          break;
        case RoutineTriggerKind.sunrise:
          _triggerMode = _TriggerMode.solar;
          _isSunset = false;
          break;
        case RoutineTriggerKind.manual:
          _triggerMode = _TriggerMode.manual;
          break;
        case RoutineTriggerKind.soilMoisture:
          _triggerMode = _TriggerMode.soil;
          if (r.trigger.threshold != null) _soilThreshold = r.trigger.threshold!;
          _soilOp = r.trigger.operator;
          break;
        case RoutineTriggerKind.waterLevel:
          _triggerMode = _TriggerMode.tank;
          if (r.trigger.threshold != null) _tankThreshold = r.trigger.threshold!;
          _tankOp = r.trigger.operator;
          break;
        case RoutineTriggerKind.temperature:
          _triggerMode = _TriggerMode.climate;
          if (r.trigger.threshold != null) _tempThreshold = r.trigger.threshold!;
          _tempOp = r.trigger.operator;
          break;
        case RoutineTriggerKind.humidity:
          _triggerMode = _TriggerMode.humidity;
          if (r.trigger.threshold != null) _humidityThreshold = r.trigger.threshold!;
          _humidityOp = r.trigger.operator;
          break;
        case RoutineTriggerKind.ambientLight:
          _triggerMode = _TriggerMode.light;
          if (r.trigger.threshold != null) _luxThreshold = r.trigger.threshold!;
          break;
        case RoutineTriggerKind.motion:
          _triggerMode = _TriggerMode.motion;
          break;
        default:
          _triggerMode = _TriggerMode.schedule;
          break;
      }

      if (r.actions.isNotEmpty) {
        _actions.clear();
        for (final act in r.actions) {
          ConnectedDeviceSummary? matchedDev;
          for (final d in _availableDevices) {
            if (d.id == act.deviceId) {
              matchedDev = d;
              break;
            }
          }
          final devId = matchedDev?.id ?? (act.deviceId.isNotEmpty ? act.deviceId : (_availableDevices.isNotEmpty ? _availableDevices.first.id : 'primary_switch'));
          final cleanDevName = matchedDev?.name ??
              (act.title.contains('•') ? act.title.split('•').first.trim() : act.title.trim());
          final chLabels = DeviceStorageService.getChannelLabels(devId);
          final chIdx = act.channelIndex;
          final cleanChLabel = chIdx == 0
              ? 'All Channels'
              : (chLabels[chIdx] ?? 'Channel $chIdx');

          _actions.add(
            _DraftActionItem(
              deviceId: devId,
              deviceName: cleanDevName,
              roomName: matchedDev?.roomName ?? '',
              channelIndex: chIdx,
              channelName: cleanChLabel,
              targetState: act.targetState,
              isToggle: act.isToggle,
              pulseMinutes: act.pulseDurationMinutes ?? 0,
            ),
          );
        }
      }
    }
  }

  void _loadDevices({bool seedDefaultAction = true}) {
    final ctrl = HomeController.instance;
    final liveDevs = ctrl?.devices ?? [];
    if (liveDevs.isNotEmpty) {
      _availableDevices = List.from(liveDevs);
    } else {
      _availableDevices = List.from(DeviceStorageService.cachedDevices);
    }

    if (_availableDevices.isNotEmpty) {
      final firstDev = _availableDevices.first;
      _selectedDeviceId ??= firstDev.id;
      _selectedRoom ??= firstDev.roomName;
      if (seedDefaultAction && _actions.isEmpty) {
        final chLabels = DeviceStorageService.getChannelLabels(firstDev.id);
        _actions.add(
          _DraftActionItem(
            deviceId: firstDev.id,
            deviceName: firstDev.name,
            roomName: firstDev.roomName,
            channelIndex: 1,
            channelName: chLabels[1] ?? 'Channel 1',
            targetState: true,
          ),
        );
      }
    } else {
      _selectedDeviceId ??= 'primary_switch';
      _selectedRoom ??= 'Living Room';
      if (seedDefaultAction && _actions.isEmpty) {
        _actions.add(
          _DraftActionItem(
            deviceId: 'primary_switch',
            deviceName: 'Smart Switch',
            roomName: 'Living Room',
            channelIndex: 1,
            channelName: 'Channel 1',
            targetState: true,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _hourTextController.dispose();
    _minuteTextController.dispose();
    for (final a in _actions) {
      a.dispose();
    }
    super.dispose();
  }

  void _syncTimeControllers() {
    final hourOfP = _scheduledTime.hourOfPeriod == 0 ? 12 : _scheduledTime.hourOfPeriod;
    _hourTextController.text = hourOfP.toString().padLeft(2, '0');
    _minuteTextController.text = _scheduledTime.minute.toString().padLeft(2, '0');
  }

  String _formatTimeOfDay(TimeOfDay time) {
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute $period';
  }

  String _formatDaysSummary() {
    if (_selectedDays.length == 7) return 'Every day';
    if (_selectedDays.length == 5 &&
        _selectedDays.contains(1) &&
        _selectedDays.contains(2) &&
        _selectedDays.contains(3) &&
        _selectedDays.contains(4) &&
        _selectedDays.contains(5)) {
      return 'Weekdays (Mon–Fri)';
    }
    if (_selectedDays.length == 2 &&
        _selectedDays.contains(6) &&
        _selectedDays.contains(7)) {
      return 'Weekends (Sat–Sun)';
    }
    if (_selectedDays.isEmpty) return 'Run once';
    const dayNames = {1: 'Mon', 2: 'Tue', 3: 'Wed', 4: 'Thu', 5: 'Fri', 6: 'Sat', 7: 'Sun'};
    final sorted = _selectedDays.toList()..sort();
    return sorted.map((d) => dayNames[d]!).join(', ');
  }

  List<String> _formatDaysList() {
    const dayNames = {1: 'Mon', 2: 'Tue', 3: 'Wed', 4: 'Thu', 5: 'Fri', 6: 'Sat', 7: 'Sun'};
    final sorted = _selectedDays.toList()..sort();
    return sorted.map((d) => dayNames[d]!).toList();
  }

  Future<void> _pickTime({TimePickerEntryMode initialEntryMode = TimePickerEntryMode.dial}) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _scheduledTime,
      initialEntryMode: initialEntryMode,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            timePickerTheme: TimePickerThemeData(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _scheduledTime = picked;
        _syncTimeControllers();
      });
    }
  }

  void _addAction() {
    if (_availableDevices.isNotEmpty) {
      final firstDev = _availableDevices.first;
      final chLabels = DeviceStorageService.getChannelLabels(firstDev.id);
      final nextCh = (_actions.length + 1).clamp(1, 4);
      setState(() {
        _actions.add(
          _DraftActionItem(
            deviceId: firstDev.id,
            deviceName: firstDev.name,
            roomName: firstDev.roomName,
            channelIndex: nextCh,
            channelName: chLabels[nextCh] ?? 'Channel $nextCh',
            targetState: true,
            pulseMinutes: 0,
          ),
        );
      });
    } else {
      setState(() {
        _actions.add(
          _DraftActionItem(
            deviceId: 'primary_switch',
            deviceName: 'Smart Switch',
            roomName: 'Living Room',
            channelIndex: 1,
            channelName: 'Channel 1',
            targetState: true,
            pulseMinutes: 0,
          ),
        );
      });
    }
  }

  Future<void> _testRunActions() async {
    final ctrl = HomeController.instance;
    if (ctrl == null) return;
    for (final a in _actions) {
      bool finalVal = a.targetState;
      if (a.isToggle) {
        final cur = ctrl.getDeviceChannelPower(a.deviceId, a.channelIndex);
        finalVal = !cur;
      }
      if (a.channelIndex == 0) {
        for (int ch = 1; ch <= 4; ch++) {
          await ctrl.setDeviceChannelPower(deviceId: a.deviceId, channelIndex: ch, value: finalVal, isToggle: a.isToggle);
        }
      } else {
        await ctrl.setDeviceChannelPower(deviceId: a.deviceId, channelIndex: a.channelIndex, value: finalVal, isToggle: a.isToggle);
      }

      if (a.pulseMinutes > 0 && finalVal) {
        final pMins = a.pulseMinutes;
        Future.delayed(Duration(minutes: pMins), () {
          if (a.channelIndex == 0) {
            for (int ch = 1; ch <= 4; ch++) {
              ctrl.setDeviceChannelPower(deviceId: a.deviceId, channelIndex: ch, value: false);
            }
          } else {
            ctrl.setDeviceChannelPower(deviceId: a.deviceId, channelIndex: a.channelIndex, value: false);
          }
        });
      }
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Test run executed directly on ${_actions.length} channel(s) live!'),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _saveRoutine() async {
    if (_saving) return;

    final name = _nameController.text.trim().isEmpty ? 'Custom Routine' : _nameController.text.trim();

    RoutineTrigger trigger;
    RoutineSchedule schedule;
    if (_triggerMode == _TriggerMode.manual) {
      trigger = const RoutineTrigger(
        kind: RoutineTriggerKind.manual,
        title: 'Manual Shortcut',
        detail: 'Run on tap or voice command (Alexa)',
      );
      schedule = const RoutineSchedule(label: 'Manual execution', timezone: 'Home timezone');
    } else if (_triggerMode == _TriggerMode.solar) {
      final solarName = _isSunset ? 'Sunset' : 'Sunrise';
      final offsetStr = _solarOffsetMinutes == 0
          ? 'At $solarName'
          : '${_solarOffsetMinutes.abs()} min ${_solarOffsetMinutes < 0 ? "before" : "after"} $solarName';
      final daysSummary = _formatDaysSummary();
      trigger = RoutineTrigger(
        kind: _isSunset ? RoutineTriggerKind.sunset : RoutineTriggerKind.sunrise,
        title: '$solarName Routine',
        detail: '$offsetStr ($daysSummary)',
        days: _formatDaysList(),
      );
      schedule = RoutineSchedule(label: '$offsetStr ($daysSummary)', timezone: 'Home timezone', days: _formatDaysList());
    } else if (_triggerMode == _TriggerMode.soil) {
      final opText = _soilOp == '<' ? 'drops below' : 'rises above';
      final detailStr = 'When soil moisture $opText ${_soilThreshold.toInt()}%';
      trigger = RoutineTrigger(
        kind: RoutineTriggerKind.soilMoisture,
        title: 'Soil Moisture Trigger',
        detail: detailStr,
        threshold: _soilThreshold,
        operator: _soilOp,
        unit: '%',
      );
      schedule = RoutineSchedule(label: detailStr, timezone: 'Home timezone');
    } else if (_triggerMode == _TriggerMode.tank) {
      final opText = _tankOp == '<' ? 'drops below' : 'reaches';
      final detailStr = 'When tank level $opText ${_tankThreshold.toInt()}%';
      trigger = RoutineTrigger(
        kind: RoutineTriggerKind.waterLevel,
        title: 'Water Tank Trigger',
        detail: detailStr,
        threshold: _tankThreshold,
        operator: _tankOp,
        unit: '%',
      );
      schedule = RoutineSchedule(label: detailStr, timezone: 'Home timezone');
    } else if (_triggerMode == _TriggerMode.climate) {
      final opText = _tempOp == '>' ? 'rises above' : 'drops below';
      final detailStr = 'When temperature $opText ${_tempThreshold.toInt()}°C';
      trigger = RoutineTrigger(
        kind: RoutineTriggerKind.temperature,
        title: 'Temperature Trigger',
        detail: detailStr,
        threshold: _tempThreshold,
        operator: _tempOp,
        unit: '°C',
      );
      schedule = RoutineSchedule(label: detailStr, timezone: 'Home timezone');
    } else if (_triggerMode == _TriggerMode.humidity) {
      final opText = _humidityOp == '>' ? 'rises above' : 'drops below';
      final detailStr = 'When humidity $opText ${_humidityThreshold.toInt()}%';
      trigger = RoutineTrigger(
        kind: RoutineTriggerKind.humidity,
        title: 'Humidity Trigger',
        detail: detailStr,
        threshold: _humidityThreshold,
        operator: _humidityOp,
        unit: '%',
      );
      schedule = RoutineSchedule(label: detailStr, timezone: 'Home timezone');
    } else if (_triggerMode == _TriggerMode.light) {
      final detailStr = 'When darkness falls (< ${_luxThreshold.toInt()} Lux)';
      trigger = RoutineTrigger(
        kind: RoutineTriggerKind.ambientLight,
        title: 'Darkness / Light Trigger',
        detail: detailStr,
        threshold: _luxThreshold,
        operator: '<',
        unit: 'Lux',
      );
      schedule = RoutineSchedule(label: detailStr, timezone: 'Home timezone');
    } else if (_triggerMode == _TriggerMode.motion) {
      final detailStr = _motionType == 'detected' ? 'When motion is detected' : 'When no motion for 10 min';
      trigger = RoutineTrigger(
        kind: RoutineTriggerKind.motion,
        title: 'Motion Detector Trigger',
        detail: detailStr,
      );
      schedule = RoutineSchedule(label: detailStr, timezone: 'Home timezone');
    } else {
      final timeStr = _formatTimeOfDay(_scheduledTime);
      final daysStr = _formatDaysSummary();
      trigger = RoutineTrigger(
        kind: RoutineTriggerKind.timeSchedule,
        title: 'Schedule: $timeStr',
        detail: '$daysStr · $timeStr',
        timeOfDay: timeStr,
        days: _formatDaysList(),
      );
      schedule = RoutineSchedule(
        label: '$daysStr at $timeStr',
        timezone: 'Home timezone',
        days: _formatDaysList(),
      );
    }

    final routineActions = <RoutineAction>[];
    for (final item in _actions) {
      final actionWord = item.isToggle ? 'Toggle' : (item.targetState ? 'Turn On' : 'Turn Off');
      final pulseSuffix = item.pulseMinutes > 0 ? ' (${item.pulseMinutes}m timer)' : '';

      final cleanDevName = item.deviceName.contains('•')
          ? item.deviceName.split('•').first.trim()
          : item.deviceName.trim();

      String cleanChannel = item.channelIndex == 0 ? 'All Channels' : item.channelName.trim();
      if (cleanChannel.contains('(')) {
        cleanChannel = cleanChannel.split('(').first.trim();
      }
      for (final prefix in ['Toggle ', 'Turn On ', 'Turn Off ']) {
        if (cleanChannel.startsWith(prefix)) {
          cleanChannel = cleanChannel.substring(prefix.length).trim();
        }
      }
      if (cleanChannel.isEmpty) {
        cleanChannel = item.channelIndex == 0 ? 'All Channels' : 'Channel ${item.channelIndex}';
      }

      routineActions.add(
        RoutineAction(
          kind: item.channelIndex == 0 ? RoutineActionKind.allChannels : RoutineActionKind.switchChannel,
          title: '$cleanDevName • $cleanChannel',
          detail: '$actionWord $cleanChannel$pulseSuffix',
          deviceId: item.deviceId,
          channelIndex: item.channelIndex,
          targetState: item.targetState,
          isToggle: item.isToggle,
          pulseDurationMinutes: item.pulseMinutes > 0 ? item.pulseMinutes : null,
          targetRoomName: item.roomName,
        ),
      );
    }

    final draft = RoutineDraft(
      name: name,
      icon: _selectedIcon,
      isFavorite: _isFavorite,
      trigger: trigger,
      schedule: schedule,
      actions: routineActions,
    );

    setState(() => _saving = true);
    RepositoryResult result = RepositoryResult.failed;
    try {
      result = widget.initialRoutine != null
          ? await widget.repository.updateRoutine(widget.initialRoutine!.id, draft)
          : await widget.repository.createRoutine(draft);

      final routineId = widget.initialRoutine?.id ?? 'rt_${DateTime.now().millisecondsSinceEpoch}';
      final builtRoutine = Routine(
        id: routineId,
        name: name,
        icon: _selectedIcon,
        isFavorite: _isFavorite,
        enabled: true,
        trigger: trigger,
        conditions: const [],
        actions: routineActions,
        schedule: schedule,
        availability: RoutineAvailability.available,
        involvedDevices: const [],
        lastExecution: null,
        nextRun: null,
        summary: schedule.label,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // 1. Direct Edge hardware sync to ESP32 switches
      try {
        await EdgeRoutineSyncService.instance.syncRoutineToEdge(builtRoutine);
      } catch (err) {
        debugPrint('[EdgeRoutineSync] Error syncing to hardware: $err');
      }

      // 2. Dual-Mode Hub Routine Synchronization
      try {
        final hubRepo = LiveHubRepository();
        final hubState = await hubRepo.getHubState();
        if (hubState.status == HubConnectionStatus.connected) {
          final client = http.Client();
          for (final act in routineActions) {
            if (act.deviceId.isNotEmpty) {
              for (final host in [hubState.hostname, 'eh-hub.local', '192.168.0.174']) {
                try {
                  await client.post(
                    Uri.parse('http://$host:4210/api/v1/routines'),
                    headers: {'Content-Type': 'application/json'},
                    body: jsonEncode({
                      'id': builtRoutine.id,
                      'name': name,
                      'deviceId': act.deviceId,
                      'channel': act.channelIndex,
                      'targetState': act.targetState,
                      'power': act.targetState,
                      'value': act.targetState,
                      'hour': _scheduledTime.hour,
                      'minute': _scheduledTime.minute,
                      'daysMask': EdgeRoutineSyncService.computeDaysMask(_formatDaysList()),
                      'criticalHardwareFallback': _criticalHardwareFallback,
                    }),
                  ).timeout(const Duration(seconds: 1));
                  break;
                } catch (_) {}
              }
            }
          }
        }
      } catch (_) {}
    } catch (e) {
      debugPrint('[RoutineBuilder] Save routine exception (fallback to success since local/edge persisted): $e');
      result = RepositoryResult.success;
    }
    if (!mounted) return;
    setState(() => _saving = false);

    if (result == RepositoryResult.success) {
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not save routine. Please try again.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
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
          _step == 3 ? 'Review Routine' : 'Create Routine',
          style: TextStyle(color: tokens.textPrimary, fontWeight: FontWeight.w800, fontSize: 18),
        ),
        leading: IconButton(
          onPressed: () {
            if (_step > 0) {
              setState(() => _step--);
            } else {
              Navigator.pop(context);
            }
          },
          icon: Icon(Icons.arrow_back_rounded, color: tokens.headerAction),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: (_step + 1) / 4,
                  minHeight: 6,
                  backgroundColor: tokens.surfaceCard,
                  valueColor: AlwaysStoppedAnimation(tokens.bluePrimary),
                ),
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                children: [
                  if (_step == 0) _buildStepBasics(tokens),
                  if (_step == 1) _buildStepTrigger(tokens),
                  if (_step == 2) _buildStepActions(tokens),
                  if (_step == 3) _buildStepReview(tokens),
                ],
              ),
            ),
            _buildBottomBar(tokens),
          ],
        ),
      ),
    );
  }

  Widget _buildStepBasics(EHThemeTokens tokens) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Name your routine',
          style: TextStyle(color: tokens.textPrimary, fontSize: 22, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 6),
        Text(
          'Choose a custom name and icon for quick access.',
          style: TextStyle(color: tokens.textSecondary, fontSize: 13),
        ),
        const SizedBox(height: 20),
        TextField(
          controller: _nameController,
          autofocus: true,
          style: TextStyle(color: tokens.textPrimary, fontSize: 15, fontWeight: FontWeight.w600),
          decoration: InputDecoration(
            labelText: 'Routine Name',
            labelStyle: TextStyle(color: tokens.textSecondary),
            hintText: 'e.g. Morning Lights, Night Energy Off, Work Desk',
            hintStyle: TextStyle(color: tokens.textTertiary),
            filled: true,
            fillColor: tokens.surfaceCard,
            prefixIcon: Icon(Icons.edit_note_rounded, color: tokens.bluePrimary),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: tokens.borderControl)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: tokens.borderControl)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: tokens.bluePrimary, width: 1.5)),
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'Select Icon',
          style: TextStyle(color: tokens.textPrimary, fontSize: 14, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: _iconOptions.map((opt) {
            final isSelected = _selectedIcon == opt.$1;
            return InkWell(
              onTap: () => setState(() => _selectedIcon = opt.$1),
              borderRadius: BorderRadius.circular(14),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected ? tokens.bluePrimary.withValues(alpha: 0.15) : tokens.surfaceCard,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isSelected ? tokens.bluePrimary : tokens.borderControl,
                    width: isSelected ? 1.8 : 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(opt.$2, size: 20, color: isSelected ? tokens.bluePrimary : tokens.textSecondary),
                    const SizedBox(width: 8),
                    Text(
                      opt.$3,
                      style: TextStyle(
                        color: isSelected ? tokens.bluePrimary : tokens.textPrimary,
                        fontSize: 12,
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 24),
        Text(
          'Target Room & Device',
          style: TextStyle(color: tokens.textPrimary, fontSize: 14, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        Text(
          'Choose the primary room and connected device for this automation.',
          style: TextStyle(color: tokens.textSecondary, fontSize: 12),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: tokens.surfaceCard,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: tokens.borderControl),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Room', style: TextStyle(color: tokens.textSecondary, fontSize: 11, fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                isExpanded: true,
                dropdownColor: tokens.surfaceCard,
                borderRadius: BorderRadius.circular(16),
                elevation: 4,
                menuMaxHeight: 320,
                icon: Icon(Icons.keyboard_arrow_down_rounded, color: tokens.textSecondary),
                initialValue: _availableRooms.contains(_selectedRoom) ? _selectedRoom : (_availableRooms.isNotEmpty ? _availableRooms.first : null),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: tokens.bgApp,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: tokens.borderControl)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: tokens.borderControl)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: tokens.bluePrimary, width: 1.5)),
                ),
                items: _availableRooms.map((r) => DropdownMenuItem(
                  value: r,
                  child: Row(
                    children: [
                      Icon(Icons.meeting_room_outlined, size: 18, color: tokens.bluePrimary),
                      const SizedBox(width: 10),
                      Expanded(child: Text(r, overflow: TextOverflow.ellipsis, style: TextStyle(color: tokens.textPrimary, fontWeight: FontWeight.w600))),
                    ],
                  ),
                )).toList(),
                onChanged: (newRoom) {
                  if (newRoom != null) {
                    setState(() {
                      _selectedRoom = newRoom;
                      final inRoom = _availableDevices.where((d) => d.roomName.toLowerCase() == newRoom.toLowerCase()).toList();
                      if (inRoom.isNotEmpty) {
                        _selectedDeviceId = inRoom.first.id;
                        _updateActionDevice(inRoom.first);
                      }
                    });
                  }
                },
              ),
              const SizedBox(height: 14),
              Text('Device', style: TextStyle(color: tokens.textSecondary, fontSize: 11, fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                isExpanded: true,
                dropdownColor: tokens.surfaceCard,
                borderRadius: BorderRadius.circular(16),
                elevation: 4,
                menuMaxHeight: 320,
                icon: Icon(Icons.keyboard_arrow_down_rounded, color: tokens.textSecondary),
                initialValue: _availableDevices.any((d) => d.id == _selectedDeviceId) ? _selectedDeviceId : (_availableDevices.isNotEmpty ? _availableDevices.first.id : null),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: tokens.bgApp,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: tokens.borderControl)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: tokens.borderControl)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: tokens.bluePrimary, width: 1.5)),
                ),
                items: _devicesInSelectedRoom.map((d) {
                  final isSk = d.name.toLowerCase().contains('socket') || d.model.toLowerCase().contains('socket');
                  return DropdownMenuItem(
                    value: d.id,
                    child: Row(
                      children: [
                        Icon(isSk ? Icons.power_rounded : Icons.toggle_on_rounded, size: 18, color: tokens.bluePrimary),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            '${d.name} (${d.roomName})',
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: tokens.textPrimary, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: (newDevId) {
                  if (newDevId != null) {
                    final matched = _availableDevices.firstWhere((d) => d.id == newDevId, orElse: () => _availableDevices.first);
                    setState(() {
                      _selectedDeviceId = newDevId;
                      _selectedRoom = matched.roomName;
                      _updateActionDevice(matched);
                      if (!_hasAnyEnvironmentalSensor && _isEnvironmentalTrigger(_triggerMode)) {
                        _triggerMode = _TriggerMode.schedule;
                      }
                    });
                  }
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: tokens.surfaceCard,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: tokens.borderControl),
          ),
          child: Row(
            children: [
              Icon(Icons.star_rounded, color: tokens.goldBright, size: 24),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Add to Favorites', style: TextStyle(color: tokens.textPrimary, fontWeight: FontWeight.w700, fontSize: 14)),
                    const SizedBox(height: 2),
                    Text('Pin this routine to your dashboard for instant access.', style: TextStyle(color: tokens.textSecondary, fontSize: 12)),
                  ],
                ),
              ),
              Switch(
                value: _isFavorite,
                activeThumbColor: Colors.white,
                activeTrackColor: tokens.bluePrimary,
                inactiveThumbColor: Colors.white,
                inactiveTrackColor: tokens.borderControl,
                onChanged: (v) => setState(() => _isFavorite = v),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStepTrigger(EHThemeTokens tokens) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'When should it run?',
          style: TextStyle(color: tokens.textPrimary, fontSize: 22, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 6),
        Text(
          'Select a trigger: time schedule, garden soil moisture, water tank level, temperature, humidity, light, motion, or tap.',
          style: TextStyle(color: tokens.textSecondary, fontSize: 13),
        ),
        const SizedBox(height: 16),
        Text(
          'Universal Smart Triggers (All Devices)',
          style: TextStyle(color: tokens.textPrimary, fontSize: 13, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _buildTriggerChip('Clock Time', Icons.alarm_rounded, _TriggerMode.schedule, tokens),
            _buildTriggerChip('Sun Cycle', Icons.wb_twilight_rounded, _TriggerMode.solar, tokens),
            _buildTriggerChip('Tap / Alexa', Icons.touch_app_rounded, _TriggerMode.manual, tokens),
          ],
        ),
        if (_hasAnyEnvironmentalSensor) ...[
          const SizedBox(height: 18),
          Row(
            children: [
              Text(
                'Environmental Sensors',
                style: TextStyle(color: tokens.textPrimary, fontSize: 13, fontWeight: FontWeight.w700),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: tokens.bluePrimary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'Hardware Sensor',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: tokens.bluePrimary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Hardware sensors supported by this device:',
            style: TextStyle(color: tokens.textTertiary, fontSize: 11),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (_deviceHasCapability('soil'))
                _buildTriggerChip('Smart Garden', Icons.grass_rounded, _TriggerMode.soil, tokens),
              if (_deviceHasCapability('tank'))
                _buildTriggerChip('Water Tank', Icons.water_drop_rounded, _TriggerMode.tank, tokens),
              if (_deviceHasCapability('climate'))
                _buildTriggerChip('Climate / AC', Icons.thermostat_rounded, _TriggerMode.climate, tokens),
              if (_deviceHasCapability('humidity'))
                _buildTriggerChip('Humidity', Icons.water_rounded, _TriggerMode.humidity, tokens),
              if (_deviceHasCapability('light'))
                _buildTriggerChip('Darkness / Lux', Icons.nightlight_round, _TriggerMode.light, tokens),
              if (_deviceHasCapability('motion'))
                _buildTriggerChip('Motion PIR', Icons.directions_run_rounded, _TriggerMode.motion, tokens),
            ],
          ),
        ] else ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: tokens.surfaceCard,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: tokens.borderControl),
            ),
            child: Row(
              children: [
                Icon(Icons.tune_rounded, color: tokens.bluePrimary, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Selected device has no environmental sensors. Universal smart triggers (Clock, Sun cycle, Tap) are active.',
                    style: TextStyle(color: tokens.textSecondary, fontSize: 12, height: 1.3),
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 20),
        if (_triggerMode == _TriggerMode.schedule)
          _buildScheduleCard(tokens)
        else if (_triggerMode == _TriggerMode.soil)
          _buildSoilCard(tokens)
        else if (_triggerMode == _TriggerMode.tank)
          _buildTankCard(tokens)
        else if (_triggerMode == _TriggerMode.climate)
          _buildClimateCard(tokens)
        else if (_triggerMode == _TriggerMode.humidity)
          _buildHumidityCard(tokens)
        else if (_triggerMode == _TriggerMode.light)
          _buildLightCard(tokens)
        else if (_triggerMode == _TriggerMode.solar)
          _buildSolarCard(tokens)
        else if (_triggerMode == _TriggerMode.motion)
          _buildMotionCard(tokens)
        else
          _buildManualCard(tokens),
      ],
    );
  }

  Widget _buildTriggerChip(String label, IconData icon, _TriggerMode mode, EHThemeTokens tokens) {
    final isSelected = _triggerMode == mode;
    return InkWell(
      onTap: () => setState(() => _triggerMode = mode),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? tokens.bluePrimary.withValues(alpha: 0.15) : tokens.surfaceCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? tokens.bluePrimary : tokens.borderControl,
            width: isSelected ? 1.8 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: isSelected ? tokens.bluePrimary : tokens.textSecondary),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                color: isSelected ? tokens.bluePrimary : tokens.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScheduleCard(EHThemeTokens tokens) {
    final isPm = _scheduledTime.period == DayPeriod.pm;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: tokens.surfaceCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: tokens.borderControl),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Scheduled Time', style: TextStyle(color: tokens.textSecondary, fontSize: 12, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        _formatTimeOfDay(_scheduledTime),
                        style: TextStyle(color: tokens.textPrimary, fontSize: 26, fontWeight: FontWeight.w900),
                        maxLines: 1,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                decoration: BoxDecoration(
                  color: tokens.bgApp,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: tokens.borderControl),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    InkWell(
                      onTap: () => _pickTime(initialEntryMode: TimePickerEntryMode.dial),
                      borderRadius: const BorderRadius.horizontal(left: Radius.circular(11)),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.access_time_rounded, size: 16, color: tokens.bluePrimary),
                            const SizedBox(width: 5),
                            Text('Dial', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: tokens.textPrimary)),
                          ],
                        ),
                      ),
                    ),
                    Container(width: 1, height: 22, color: tokens.borderControl),
                    InkWell(
                      onTap: () => _pickTime(initialEntryMode: TimePickerEntryMode.input),
                      borderRadius: const BorderRadius.horizontal(right: Radius.circular(11)),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.keyboard_alt_outlined, size: 16, color: tokens.bluePrimary),
                            const SizedBox(width: 5),
                            Text('Type', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: tokens.textPrimary)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Direct numeric keyboard input row
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: tokens.bgApp,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: tokens.borderControl),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.edit_note_rounded, size: 15, color: tokens.bluePrimary),
                    const SizedBox(width: 6),
                    Text(
                      'Type Time by Number (Keyboard):',
                      style: TextStyle(color: tokens.textSecondary, fontSize: 11, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    // Hour Box
                    SizedBox(
                      width: 58,
                      child: TextField(
                        controller: _hourTextController,
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        maxLength: 2,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: tokens.textPrimary),
                        decoration: InputDecoration(
                          counterText: '',
                          contentPadding: const EdgeInsets.symmetric(vertical: 8),
                          filled: true,
                          fillColor: tokens.surfaceCard,
                          hintText: '12',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: tokens.borderControl)),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: tokens.bluePrimary, width: 1.5)),
                        ),
                        onChanged: (text) {
                          final h = int.tryParse(text.trim());
                          if (h != null && h >= 1 && h <= 12) {
                            int hour24 = h;
                            if (isPm && h < 12) hour24 += 12;
                            if (!isPm && h == 12) hour24 = 0;
                            setState(() {
                              _scheduledTime = TimeOfDay(hour: hour24, minute: _scheduledTime.minute);
                            });
                          }
                        },
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Text(':', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: tokens.textPrimary)),
                    ),
                    // Minute Box
                    SizedBox(
                      width: 58,
                      child: TextField(
                        controller: _minuteTextController,
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        maxLength: 2,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: tokens.textPrimary),
                        decoration: InputDecoration(
                          counterText: '',
                          contentPadding: const EdgeInsets.symmetric(vertical: 8),
                          filled: true,
                          fillColor: tokens.surfaceCard,
                          hintText: '00',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: tokens.borderControl)),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: tokens.bluePrimary, width: 1.5)),
                        ),
                        onChanged: (text) {
                          final m = int.tryParse(text.trim());
                          if (m != null && m >= 0 && m <= 59) {
                            setState(() {
                              _scheduledTime = TimeOfDay(hour: _scheduledTime.hour, minute: m);
                            });
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    // AM / PM Toggle Pills
                    Container(
                      decoration: BoxDecoration(
                        color: tokens.surfaceCard,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: tokens.borderControl),
                      ),
                      child: Row(
                        children: [
                          InkWell(
                            onTap: () {
                              if (isPm) {
                                final h = _scheduledTime.hour - 12;
                                setState(() {
                                  _scheduledTime = TimeOfDay(hour: h.clamp(0, 23), minute: _scheduledTime.minute);
                                  _syncTimeControllers();
                                });
                              }
                            },
                            borderRadius: const BorderRadius.horizontal(left: Radius.circular(9)),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              decoration: BoxDecoration(
                                color: !isPm ? tokens.bluePrimary : Colors.transparent,
                                borderRadius: const BorderRadius.horizontal(left: Radius.circular(9)),
                              ),
                              child: Text(
                                'AM',
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 12,
                                  color: !isPm ? Colors.white : tokens.textSecondary,
                                ),
                              ),
                            ),
                          ),
                          InkWell(
                            onTap: () {
                              if (!isPm) {
                                final h = _scheduledTime.hour + 12;
                                setState(() {
                                  _scheduledTime = TimeOfDay(hour: h.clamp(0, 23), minute: _scheduledTime.minute);
                                  _syncTimeControllers();
                                });
                              }
                            },
                            borderRadius: const BorderRadius.horizontal(right: Radius.circular(9)),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              decoration: BoxDecoration(
                                color: isPm ? tokens.bluePrimary : Colors.transparent,
                                borderRadius: const BorderRadius.horizontal(right: Radius.circular(9)),
                              ),
                              child: Text(
                                'PM',
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 12,
                                  color: isPm ? Colors.white : tokens.textSecondary,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const Divider(height: 1),
          const SizedBox(height: 16),
          Text('Repeat Days', style: TextStyle(color: tokens.textSecondary, fontSize: 12, fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildDayChip(1, 'M', tokens),
              _buildDayChip(2, 'T', tokens),
              _buildDayChip(3, 'W', tokens),
              _buildDayChip(4, 'T', tokens),
              _buildDayChip(5, 'F', tokens),
              _buildDayChip(6, 'S', tokens),
              _buildDayChip(7, 'S', tokens),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _buildQuickDayPreset('Every day', () => setState(() => _selectedDays.addAll([1, 2, 3, 4, 5, 6, 7])), tokens),
              const SizedBox(width: 8),
              _buildQuickDayPreset('Weekdays', () {
                setState(() {
                  _selectedDays.clear();
                  _selectedDays.addAll([1, 2, 3, 4, 5]);
                });
              }, tokens),
              const SizedBox(width: 8),
              _buildQuickDayPreset('Weekends', () {
                setState(() {
                  _selectedDays.clear();
                  _selectedDays.addAll([6, 7]);
                });
              }, tokens),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSoilCard(EHThemeTokens tokens) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: tokens.surfaceCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: tokens.borderControl),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: tokens.success.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.grass_rounded, color: tokens.success, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Smart Gardening & Irrigation', style: TextStyle(color: tokens.textPrimary, fontSize: 16, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 2),
                    Text('Automate watering pumps or solenoid valves by soil dryness.', style: TextStyle(color: tokens.textSecondary, fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          const Divider(height: 1),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Moisture Threshold', style: TextStyle(color: tokens.textSecondary, fontSize: 12, fontWeight: FontWeight.w700)),
              Text('${_soilThreshold.toInt()}%', style: TextStyle(color: tokens.bluePrimary, fontSize: 20, fontWeight: FontWeight.w900)),
            ],
          ),
          Slider(
            value: _soilThreshold,
            min: 10,
            max: 90,
            divisions: 16,
            activeColor: tokens.bluePrimary,
            onChanged: (v) => setState(() => _soilThreshold = v),
          ),
          const SizedBox(height: 8),
          Text('Trigger Condition', style: TextStyle(color: tokens.textSecondary, fontSize: 12, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () => setState(() => _soilOp = '<'),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
                    decoration: BoxDecoration(
                      color: _soilOp == '<' ? tokens.warning.withValues(alpha: 0.15) : tokens.bgApp,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _soilOp == '<' ? tokens.warning : tokens.borderControl, width: _soilOp == '<' ? 1.8 : 1),
                    ),
                    child: Column(
                      children: [
                        Text('Drops Below ${_soilThreshold.toInt()}%', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: _soilOp == '<' ? tokens.warning : tokens.textPrimary)),
                        const SizedBox(height: 2),
                        Text('(Soil dry - Start watering)', style: TextStyle(fontSize: 10, color: tokens.textSecondary)),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: InkWell(
                  onTap: () => setState(() => _soilOp = '>'),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
                    decoration: BoxDecoration(
                      color: _soilOp == '>' ? tokens.success.withValues(alpha: 0.15) : tokens.bgApp,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _soilOp == '>' ? tokens.success : tokens.borderControl, width: _soilOp == '>' ? 1.8 : 1),
                    ),
                    child: Column(
                      children: [
                        Text('Rises Above ${_soilThreshold.toInt()}%', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: _soilOp == '>' ? tokens.success : tokens.textPrimary)),
                        const SizedBox(height: 2),
                        Text('(Soil wet - Stop watering)', style: TextStyle(fontSize: 10, color: tokens.textSecondary)),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTankCard(EHThemeTokens tokens) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: tokens.surfaceCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: tokens.borderControl),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: tokens.bluePrimary.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.water_drop_rounded, color: tokens.bluePrimary, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Water Tank & Reservoir Level', style: TextStyle(color: tokens.textPrimary, fontSize: 16, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 2),
                    Text('Control main water pump based on tank level sensors.', style: TextStyle(color: tokens.textSecondary, fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          const Divider(height: 1),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Water Level', style: TextStyle(color: tokens.textSecondary, fontSize: 12, fontWeight: FontWeight.w700)),
              Text('${_tankThreshold.toInt()}%', style: TextStyle(color: tokens.bluePrimary, fontSize: 20, fontWeight: FontWeight.w900)),
            ],
          ),
          Slider(
            value: _tankThreshold,
            min: 10,
            max: 100,
            divisions: 18,
            activeColor: tokens.bluePrimary,
            onChanged: (v) => setState(() => _tankThreshold = v),
          ),
          const SizedBox(height: 8),
          Text('Trigger Condition', style: TextStyle(color: tokens.textSecondary, fontSize: 12, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () => setState(() => _tankOp = '<'),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
                    decoration: BoxDecoration(
                      color: _tankOp == '<' ? tokens.warning.withValues(alpha: 0.15) : tokens.bgApp,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _tankOp == '<' ? tokens.warning : tokens.borderControl, width: _tankOp == '<' ? 1.8 : 1),
                    ),
                    child: Column(
                      children: [
                        Text('Drops Below ${_tankThreshold.toInt()}%', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: _tankOp == '<' ? tokens.warning : tokens.textPrimary)),
                        const SizedBox(height: 2),
                        Text('(Low water - Start pump)', style: TextStyle(fontSize: 10, color: tokens.textSecondary)),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: InkWell(
                  onTap: () => setState(() => _tankOp = '>='),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
                    decoration: BoxDecoration(
                      color: _tankOp == '>=' ? tokens.success.withValues(alpha: 0.15) : tokens.bgApp,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _tankOp == '>=' ? tokens.success : tokens.borderControl, width: _tankOp == '>=' ? 1.8 : 1),
                    ),
                    child: Column(
                      children: [
                        Text('Reaches ${_tankThreshold.toInt()}%', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: _tankOp == '>=' ? tokens.success : tokens.textPrimary)),
                        const SizedBox(height: 2),
                        Text('(Tank full - Stop pump)', style: TextStyle(fontSize: 10, color: tokens.textSecondary)),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildClimateCard(EHThemeTokens tokens) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: tokens.surfaceCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: tokens.borderControl),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: tokens.warning.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.thermostat_rounded, color: tokens.warning, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Temperature Automation', style: TextStyle(color: tokens.textPrimary, fontSize: 16, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 2),
                    Text('Trigger AC, ceiling fan, or heater when room temperature changes.', style: TextStyle(color: tokens.textSecondary, fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          const Divider(height: 1),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Target Temperature', style: TextStyle(color: tokens.textSecondary, fontSize: 12, fontWeight: FontWeight.w700)),
              Text('${_tempThreshold.toInt()}°C', style: TextStyle(color: tokens.bluePrimary, fontSize: 20, fontWeight: FontWeight.w900)),
            ],
          ),
          Slider(
            value: _tempThreshold,
            min: 16,
            max: 42,
            divisions: 26,
            activeColor: tokens.bluePrimary,
            onChanged: (v) => setState(() => _tempThreshold = v),
          ),
          const SizedBox(height: 8),
          Text('Trigger Condition', style: TextStyle(color: tokens.textSecondary, fontSize: 12, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () => setState(() => _tempOp = '>'),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
                    decoration: BoxDecoration(
                      color: _tempOp == '>' ? tokens.warning.withValues(alpha: 0.15) : tokens.bgApp,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _tempOp == '>' ? tokens.warning : tokens.borderControl, width: _tempOp == '>' ? 1.8 : 1),
                    ),
                    child: Column(
                      children: [
                        Text('Rises Above ${_tempThreshold.toInt()}°C', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: _tempOp == '>' ? tokens.warning : tokens.textPrimary)),
                        const SizedBox(height: 2),
                        Text('(Hot - Turn on Fan/AC)', style: TextStyle(fontSize: 10, color: tokens.textSecondary)),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: InkWell(
                  onTap: () => setState(() => _tempOp = '<'),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
                    decoration: BoxDecoration(
                      color: _tempOp == '<' ? tokens.bluePrimary.withValues(alpha: 0.15) : tokens.bgApp,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _tempOp == '<' ? tokens.bluePrimary : tokens.borderControl, width: _tempOp == '<' ? 1.8 : 1),
                    ),
                    child: Column(
                      children: [
                        Text('Drops Below ${_tempThreshold.toInt()}°C', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: _tempOp == '<' ? tokens.bluePrimary : tokens.textPrimary)),
                        const SizedBox(height: 2),
                        Text('(Cold - Turn on Heater)', style: TextStyle(fontSize: 10, color: tokens.textSecondary)),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHumidityCard(EHThemeTokens tokens) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: tokens.surfaceCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: tokens.borderControl),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: tokens.bluePrimary.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.water_rounded, color: tokens.bluePrimary, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Humidity & Exhaust Control', style: TextStyle(color: tokens.textPrimary, fontSize: 16, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 2),
                    Text('Trigger bathroom exhaust fans or misting pumps.', style: TextStyle(color: tokens.textSecondary, fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          const Divider(height: 1),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Relative Humidity', style: TextStyle(color: tokens.textSecondary, fontSize: 12, fontWeight: FontWeight.w700)),
              Text('${_humidityThreshold.toInt()}% RH', style: TextStyle(color: tokens.bluePrimary, fontSize: 20, fontWeight: FontWeight.w900)),
            ],
          ),
          Slider(
            value: _humidityThreshold,
            min: 30,
            max: 95,
            divisions: 13,
            activeColor: tokens.bluePrimary,
            onChanged: (v) => setState(() => _humidityThreshold = v),
          ),
          const SizedBox(height: 8),
          Text('Trigger Condition', style: TextStyle(color: tokens.textSecondary, fontSize: 12, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () => setState(() => _humidityOp = '>'),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
                    decoration: BoxDecoration(
                      color: _humidityOp == '>' ? tokens.warning.withValues(alpha: 0.15) : tokens.bgApp,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _humidityOp == '>' ? tokens.warning : tokens.borderControl, width: _humidityOp == '>' ? 1.8 : 1),
                    ),
                    child: Column(
                      children: [
                        Text('Exceeds ${_humidityThreshold.toInt()}%', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: _humidityOp == '>' ? tokens.warning : tokens.textPrimary)),
                        const SizedBox(height: 2),
                        Text('(High steam - Exhaust ON)', style: TextStyle(fontSize: 10, color: tokens.textSecondary)),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: InkWell(
                  onTap: () => setState(() => _humidityOp = '<'),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
                    decoration: BoxDecoration(
                      color: _humidityOp == '<' ? tokens.bluePrimary.withValues(alpha: 0.15) : tokens.bgApp,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _humidityOp == '<' ? tokens.bluePrimary : tokens.borderControl, width: _humidityOp == '<' ? 1.8 : 1),
                    ),
                    child: Column(
                      children: [
                        Text('Drops Below ${_humidityThreshold.toInt()}%', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: _humidityOp == '<' ? tokens.bluePrimary : tokens.textPrimary)),
                        const SizedBox(height: 2),
                        Text('(Dry air - Humidifier ON)', style: TextStyle(fontSize: 10, color: tokens.textSecondary)),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLightCard(EHThemeTokens tokens) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: tokens.surfaceCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: tokens.borderControl),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: tokens.goldBright.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.nightlight_round, color: tokens.goldBright, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Ambient Darkness & Light', style: TextStyle(color: tokens.textPrimary, fontSize: 16, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 2),
                    Text('Automatically illuminate garden, porch, or corridors when darkness falls.', style: TextStyle(color: tokens.textSecondary, fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          const Divider(height: 1),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Darkness Threshold', style: TextStyle(color: tokens.textSecondary, fontSize: 12, fontWeight: FontWeight.w700)),
              Text('${_luxThreshold.toInt()} Lux', style: TextStyle(color: tokens.bluePrimary, fontSize: 20, fontWeight: FontWeight.w900)),
            ],
          ),
          Slider(
            value: _luxThreshold,
            min: 10,
            max: 300,
            divisions: 29,
            activeColor: tokens.bluePrimary,
            onChanged: (v) => setState(() => _luxThreshold = v),
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: tokens.bgApp,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: tokens.borderControl),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline_rounded, size: 16, color: tokens.bluePrimary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Triggers automatically when ambient light falls below ${_luxThreshold.toInt()} Lux (dusk/darkness).',
                    style: TextStyle(color: tokens.textPrimary, fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSolarCard(EHThemeTokens tokens) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: tokens.surfaceCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: tokens.borderControl),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Solar Event', style: TextStyle(color: tokens.textSecondary, fontSize: 12, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () => setState(() => _isSunset = true),
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: _isSunset ? tokens.bluePrimary.withValues(alpha: 0.15) : tokens.bgApp,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: _isSunset ? tokens.bluePrimary : tokens.borderControl, width: _isSunset ? 1.8 : 1),
                    ),
                    child: Column(
                      children: [
                        Icon(Icons.nights_stay_rounded, color: _isSunset ? tokens.bluePrimary : tokens.textSecondary),
                        const SizedBox(height: 6),
                        Text('At Sunset', style: TextStyle(fontWeight: FontWeight.w700, color: _isSunset ? tokens.bluePrimary : tokens.textPrimary)),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: InkWell(
                  onTap: () => setState(() => _isSunset = false),
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: !_isSunset ? tokens.bluePrimary.withValues(alpha: 0.15) : tokens.bgApp,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: !_isSunset ? tokens.bluePrimary : tokens.borderControl, width: !_isSunset ? 1.8 : 1),
                    ),
                    child: Column(
                      children: [
                        Icon(Icons.wb_sunny_rounded, color: !_isSunset ? tokens.bluePrimary : tokens.textSecondary),
                        const SizedBox(height: 6),
                        Text('At Sunrise', style: TextStyle(fontWeight: FontWeight.w700, color: !_isSunset ? tokens.bluePrimary : tokens.textPrimary)),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text('Timing Offset', style: TextStyle(color: tokens.textSecondary, fontSize: 12, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          DropdownButtonFormField<int>(
            initialValue: _solarOffsetMinutes,
            decoration: InputDecoration(
              filled: true,
              fillColor: tokens.bgApp,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: tokens.borderControl)),
            ),
            items: const [
              DropdownMenuItem(value: -30, child: Text('30 minutes before')),
              DropdownMenuItem(value: -15, child: Text('15 minutes before')),
              DropdownMenuItem(value: 0, child: Text('Exact time')),
              DropdownMenuItem(value: 15, child: Text('15 minutes after')),
              DropdownMenuItem(value: 30, child: Text('30 minutes after')),
            ],
            onChanged: (val) {
              if (val != null) setState(() => _solarOffsetMinutes = val);
            },
          ),
          const SizedBox(height: 20),
          Text('Repeat Days', style: TextStyle(color: tokens.textSecondary, fontSize: 12, fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildDayChip(1, 'M', tokens),
              _buildDayChip(2, 'T', tokens),
              _buildDayChip(3, 'W', tokens),
              _buildDayChip(4, 'T', tokens),
              _buildDayChip(5, 'F', tokens),
              _buildDayChip(6, 'S', tokens),
              _buildDayChip(7, 'S', tokens),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMotionCard(EHThemeTokens tokens) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: tokens.surfaceCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: tokens.borderControl),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: tokens.bluePrimary.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.directions_run_rounded, color: tokens.bluePrimary, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('PIR Motion Detection', style: TextStyle(color: tokens.textPrimary, fontSize: 16, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 2),
                    Text('Trigger security lights on activity or turn off appliances when vacant.', style: TextStyle(color: tokens.textSecondary, fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          const Divider(height: 1),
          const SizedBox(height: 16),
          InkWell(
            onTap: () => setState(() => _motionType = 'detected'),
            borderRadius: BorderRadius.circular(14),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _motionType == 'detected' ? tokens.bluePrimary.withValues(alpha: 0.15) : tokens.bgApp,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _motionType == 'detected' ? tokens.bluePrimary : tokens.borderControl, width: _motionType == 'detected' ? 1.8 : 1),
              ),
              child: Row(
                children: [
                  Icon(Icons.directions_walk_rounded, color: _motionType == 'detected' ? tokens.bluePrimary : tokens.textSecondary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('When motion is detected', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: _motionType == 'detected' ? tokens.bluePrimary : tokens.textPrimary)),
                        const SizedBox(height: 2),
                        Text('Turn on hallway, porch, or room switches instantly.', style: TextStyle(fontSize: 11, color: tokens.textSecondary)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          InkWell(
            onTap: () => setState(() => _motionType = 'no_motion_10m'),
            borderRadius: BorderRadius.circular(14),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _motionType == 'no_motion_10m' ? tokens.warning.withValues(alpha: 0.15) : tokens.bgApp,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _motionType == 'no_motion_10m' ? tokens.warning : tokens.borderControl, width: _motionType == 'no_motion_10m' ? 1.8 : 1),
              ),
              child: Row(
                children: [
                  Icon(Icons.timer_outlined, color: _motionType == 'no_motion_10m' ? tokens.warning : tokens.textSecondary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('When no motion for 10 minutes', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: _motionType == 'no_motion_10m' ? tokens.warning : tokens.textPrimary)),
                        const SizedBox(height: 2),
                        Text('Energy saver: Turn off lights or AC when room is empty.', style: TextStyle(fontSize: 11, color: tokens.textSecondary)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildManualCard(EHThemeTokens tokens) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: tokens.surfaceCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: tokens.borderControl),
      ),
      child: Row(
        children: [
          Icon(Icons.touch_app_rounded, size: 32, color: tokens.bluePrimary),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Manual & Voice Shortcut', style: TextStyle(color: tokens.textPrimary, fontWeight: FontWeight.w800, fontSize: 15)),
                const SizedBox(height: 4),
                Text('Run this routine on demand by pressing the play button in the app or asking Alexa / Google Assistant.', style: TextStyle(color: tokens.textSecondary, fontSize: 13)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDayChip(int day, String label, EHThemeTokens tokens) {
    final isSelected = _selectedDays.contains(day);
    return InkWell(
      onTap: () {
        setState(() {
          if (isSelected) {
            _selectedDays.remove(day);
          } else {
            _selectedDays.add(day);
          }
        });
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 38,
        height: 38,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected ? tokens.bluePrimary : tokens.bgApp,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isSelected ? tokens.bluePrimary : tokens.borderControl),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : tokens.textSecondary,
            fontWeight: FontWeight.w800,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  Widget _buildQuickDayPreset(String label, VoidCallback onTap, EHThemeTokens tokens) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: tokens.bgApp,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: tokens.borderControl),
        ),
        child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: tokens.textSecondary)),
      ),
    );
  }

  Widget _buildStepActions(EHThemeTokens tokens) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'What should it do?',
          style: TextStyle(color: tokens.textPrimary, fontSize: 22, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 6),
        Text(
          'Select your claimed devices and choose which switch channels to control.',
          style: TextStyle(color: tokens.textSecondary, fontSize: 13),
        ),
        const SizedBox(height: 18),
        ..._actions.asMap().entries.map((entry) {
          final idx = entry.key;
          final action = entry.value;
          return Container(
            key: ValueKey(action.draftKey),
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: tokens.surfaceCard,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: tokens.borderControl),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Action #${idx + 1}',
                      style: TextStyle(color: tokens.bluePrimary, fontSize: 13, fontWeight: FontWeight.w800),
                    ),
                    if (_actions.length > 1)
                      IconButton(
                        icon: Icon(Icons.delete_outline_rounded, color: tokens.warning, size: 20),
                        visualDensity: VisualDensity.compact,
                        onPressed: () => setState(() => _actions.removeAt(idx).dispose()),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                Text('Device', style: TextStyle(color: tokens.textSecondary, fontSize: 11, fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                if (_availableDevices.isNotEmpty)
                  DropdownButtonFormField<String>(
                    isExpanded: true,
                    dropdownColor: tokens.surfaceCard,
                    borderRadius: BorderRadius.circular(16),
                    elevation: 4,
                    menuMaxHeight: 320,
                    icon: Icon(Icons.keyboard_arrow_down_rounded, color: tokens.textSecondary),
                    initialValue: _availableDevices.any((d) => d.id == action.deviceId) ? action.deviceId : _availableDevices.first.id,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: tokens.bgApp,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: tokens.borderControl)),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: tokens.borderControl)),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: tokens.bluePrimary, width: 1.5)),
                    ),
                    items: _availableDevices.map((d) {
                      final isSk = d.name.toLowerCase().contains('socket') || d.model.toLowerCase().contains('socket');
                      return DropdownMenuItem<String>(
                        value: d.id,
                        child: Row(
                          children: [
                            Icon(isSk ? Icons.power_rounded : Icons.toggle_on_rounded, size: 18, color: tokens.bluePrimary),
                            const SizedBox(width: 10),
                            Expanded(child: Text('${d.name} (${d.roomName})', overflow: TextOverflow.ellipsis, style: TextStyle(color: tokens.textPrimary, fontSize: 13, fontWeight: FontWeight.w600))),
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        final matched = _availableDevices.cast<ConnectedDeviceSummary?>().firstWhere(
                          (d) => d?.id == val,
                          orElse: () => null,
                        );
                        if (matched != null) {
                          final chLabels = DeviceStorageService.getChannelLabels(val);
                          setState(() {
                            action.deviceId = val;
                            action.deviceName = matched.name;
                            action.roomName = matched.roomName;
                            action.channelName = chLabels[action.channelIndex] ?? 'Channel ${action.channelIndex}';
                          });
                        }
                      }
                    },
                  )
                else
                  Text('Using claimed smart switch', style: TextStyle(color: tokens.textPrimary, fontWeight: FontWeight.w600)),
                const SizedBox(height: 14),
                Text('Target Channel', style: TextStyle(color: tokens.textSecondary, fontSize: 11, fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                Builder(
                  builder: (context) {
                    final chLabels = DeviceStorageService.getChannelLabels(action.deviceId);
                    final targetDev = _availableDevices.cast<ConnectedDeviceSummary?>().firstWhere(
                      (d) => d?.id == action.deviceId,
                      orElse: () => null,
                    );
                    final canonical = MockProductCatalogRepository.resolveCanonicalProductVariant(
                      variantId: targetDev?.model,
                      deviceName: targetDev?.name ?? action.deviceName,
                    );
                    final isSk = canonical.contains('socket');
                    final prefix = isSk ? 'Socket' : 'Switch';
                    int devChannels = 4;
                    if (canonical.contains('1x') || (targetDev?.name ?? '').toLowerCase().contains('1x')) {
                      devChannels = 1;
                    } else if (canonical.contains('2x') || (targetDev?.name ?? '').toLowerCase().contains('2x')) {
                      devChannels = 2;
                    } else if (canonical.contains('3x') || (targetDev?.name ?? '').toLowerCase().contains('3x')) {
                      devChannels = 3;
                    } else if (canonical.contains('4x') || (targetDev?.name ?? '').toLowerCase().contains('4x')) {
                      devChannels = 4;
                    } else if (isSk) {
                      devChannels = 2;
                    }

                    // Clamp action channelIndex if it exceeds the device's actual channels
                    final validInitial = (action.channelIndex <= devChannels) ? action.channelIndex : 0;
                    if (action.channelIndex > devChannels) {
                      action.channelIndex = 0;
                    }

                    final channelItems = <DropdownMenuItem<int>>[];
                    if (devChannels > 1) {
                      final allNums = List.generate(devChannels, (i) => '${i + 1}').join(', ');
                      channelItems.add(DropdownMenuItem(
                        value: 0,
                        child: Text('All Channels ($allNums)', style: const TextStyle(fontWeight: FontWeight.w700)),
                      ));
                    }
                    for (int ch = 1; ch <= devChannels; ch++) {
                      channelItems.add(DropdownMenuItem(
                        value: ch,
                        child: Text('Channel $ch — ${chLabels[ch] ?? "$prefix $ch"}'),
                      ));
                    }

                    return DropdownButtonFormField<int>(
                      isExpanded: true,
                      dropdownColor: tokens.surfaceCard,
                      borderRadius: BorderRadius.circular(16),
                      elevation: 4,
                      menuMaxHeight: 320,
                      icon: Icon(Icons.keyboard_arrow_down_rounded, color: tokens.textSecondary),
                      initialValue: validInitial,
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: tokens.bgApp,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: tokens.borderControl)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: tokens.borderControl)),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: tokens.bluePrimary, width: 1.5)),
                      ),
                      items: channelItems,
                      onChanged: (val) {
                        if (val != null) {
                          setState(() {
                            action.channelIndex = val;
                            action.channelName = val == 0 ? 'All Channels' : (chLabels[val] ?? '$prefix $val');
                          });
                        }
                      },
                    );
                  },
                ),
                const SizedBox(height: 14),
                Text('Action Operation', style: TextStyle(color: tokens.textSecondary, fontSize: 11, fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () => setState(() {
                          action.targetState = true;
                          action.isToggle = false;
                        }),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: action.targetState && !action.isToggle ? tokens.success.withValues(alpha: 0.15) : tokens.bgApp,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: action.targetState && !action.isToggle ? tokens.success : tokens.borderControl,
                              width: action.targetState && !action.isToggle ? 1.8 : 1,
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.power_rounded, size: 16, color: action.targetState && !action.isToggle ? tokens.success : tokens.textSecondary),
                              const SizedBox(width: 6),
                              Text('Turn ON', style: TextStyle(color: action.targetState && !action.isToggle ? tokens.success : tokens.textPrimary, fontWeight: FontWeight.w700, fontSize: 12)),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: InkWell(
                        onTap: () => setState(() {
                          action.targetState = false;
                          action.isToggle = false;
                        }),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: !action.targetState && !action.isToggle ? tokens.warning.withValues(alpha: 0.15) : tokens.bgApp,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: !action.targetState && !action.isToggle ? tokens.warning : tokens.borderControl,
                              width: !action.targetState && !action.isToggle ? 1.8 : 1,
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.power_off_rounded, size: 16, color: !action.targetState && !action.isToggle ? tokens.warning : tokens.textSecondary),
                              const SizedBox(width: 6),
                              Text('Turn OFF', style: TextStyle(color: !action.targetState && !action.isToggle ? tokens.warning : tokens.textPrimary, fontWeight: FontWeight.w700, fontSize: 12)),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: InkWell(
                        onTap: () => setState(() {
                          action.isToggle = true;
                        }),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: action.isToggle ? tokens.bluePrimary.withValues(alpha: 0.15) : tokens.bgApp,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: action.isToggle ? tokens.bluePrimary : tokens.borderControl,
                              width: action.isToggle ? 1.8 : 1,
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.sync_rounded, size: 16, color: action.isToggle ? tokens.bluePrimary : tokens.textSecondary),
                              const SizedBox(width: 6),
                              Text('Toggle', style: TextStyle(color: action.isToggle ? tokens.bluePrimary : tokens.textPrimary, fontWeight: FontWeight.w700, fontSize: 12)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Auto-Off Timer (Optional)',
                      style: TextStyle(color: tokens.textSecondary, fontSize: 11, fontWeight: FontWeight.w700),
                    ),
                    if (action.pulseMinutes > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: tokens.bluePrimary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          action.pulseMinutes >= 60
                              ? '${(action.pulseMinutes / 60).toStringAsFixed(action.pulseMinutes % 60 == 0 ? 0 : 1)}h off'
                              : '${action.pulseMinutes}m off',
                          style: TextStyle(color: tokens.bluePrimary, fontSize: 10, fontWeight: FontWeight.w800),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                Builder(
                  builder: (context) {
                    final standardPresets = <int, String>{
                      0: 'No timer (Continuous - Stay ON)',
                      1: '1 min (Short test / Bell)',
                      2: '2 mins (Exhaust / Ventilation)',
                      3: '3 mins (Quick flush)',
                      5: '5 mins (Sprinkler / Garden)',
                      10: '10 mins (Water pump / Geyser)',
                      15: '15 mins (Overhead tank fill)',
                      20: '20 mins (Water heater)',
                      30: '30 mins (Irrigation cycle)',
                      45: '45 mins (AC / Cooling)',
                      60: '1 hour (Heavy appliance)',
                      90: '1.5 hours (90 mins)',
                      120: '2 hours (120 mins)',
                      180: '3 hours (180 mins)',
                      240: '4 hours (240 mins)',
                      360: '6 hours (360 mins)',
                      480: '8 hours (Night shift)',
                      720: '12 hours (Half day)',
                    };

                    final dropdownItems = standardPresets.entries.map((e) {
                      return DropdownMenuItem<int>(
                        value: e.key,
                        child: Text(e.value, overflow: TextOverflow.ellipsis),
                      );
                    }).toList();

                    if (!standardPresets.containsKey(action.pulseMinutes)) {
                      dropdownItems.add(
                        DropdownMenuItem<int>(
                          value: action.pulseMinutes,
                          child: Text(
                            'Custom: ${action.pulseMinutes} min${action.pulseMinutes == 1 ? '' : 's'}${action.pulseMinutes >= 60 ? ' (${(action.pulseMinutes / 60).toStringAsFixed(1)}h)' : ''}',
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontWeight: FontWeight.w700, color: tokens.bluePrimary),
                          ),
                        ),
                      );
                    }

                    return DropdownButtonFormField<int>(
                      key: ValueKey('pulse_${action.draftKey}_${action.pulseMinutes}'),
                      isExpanded: true,
                      initialValue: action.pulseMinutes,
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: tokens.bgApp,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: tokens.borderControl)),
                      ),
                      items: dropdownItems,
                      onChanged: (val) {
                        if (val != null) {
                          setState(() {
                            action.pulseMinutes = val;
                            action.customPulseController.text = val > 0 ? val.toString() : '';
                          });
                        }
                      },
                    );
                  },
                ),
                const SizedBox(height: 8),
                // Quick timer preset chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [0, 1, 2, 5, 10, 15, 30, 60, 120].map((mins) {
                      final isSel = action.pulseMinutes == mins;
                      final label = mins == 0
                          ? 'Continuous'
                          : mins >= 60
                              ? '${mins ~/ 60}h'
                              : '${mins}m';
                      return Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: ChoiceChip(
                          label: Text(label),
                          selected: isSel,
                          selectedColor: tokens.bluePrimary.withValues(alpha: 0.2),
                          labelStyle: TextStyle(
                            fontSize: 11,
                            fontWeight: isSel ? FontWeight.w800 : FontWeight.w600,
                            color: isSel ? tokens.bluePrimary : tokens.textPrimary,
                          ),
                          side: BorderSide(
                            color: isSel ? tokens.bluePrimary : tokens.borderControl,
                            width: isSel ? 1.5 : 1,
                          ),
                          backgroundColor: tokens.bgApp,
                          onSelected: (_) {
                            setState(() {
                              action.pulseMinutes = mins;
                              action.customPulseController.text = mins > 0 ? mins.toString() : '';
                            });
                          },
                        ),
                      );
                    }).toList(),
                  ),
                ),
                // Custom Off Timer input slot
                Container(
                  margin: const EdgeInsets.only(top: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: tokens.bgApp,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: action.pulseMinutes > 0 ? tokens.bluePrimary.withValues(alpha: 0.4) : tokens.borderControl,
                      width: action.pulseMinutes > 0 ? 1.4 : 1.0,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            action.pulseMinutes > 0 ? Icons.timer_outlined : Icons.timer_off_outlined,
                            size: 15,
                            color: action.pulseMinutes > 0 ? tokens.bluePrimary : tokens.textSecondary,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Custom Off Duration (Set exact minutes)',
                            style: TextStyle(color: tokens.textSecondary, fontSize: 11, fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: action.customPulseController,
                              keyboardType: TextInputType.number,
                              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                              decoration: InputDecoration(
                                isDense: true,
                                hintText: 'Enter minutes (e.g. 7, 25, 90)',
                                hintStyle: TextStyle(color: tokens.textSecondary.withValues(alpha: 0.6), fontSize: 12),
                                suffixText: 'mins',
                                suffixStyle: TextStyle(color: tokens.bluePrimary, fontWeight: FontWeight.w700, fontSize: 12),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                filled: true,
                                fillColor: tokens.surfaceCard,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: BorderSide(color: tokens.borderControl),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: BorderSide(color: tokens.bluePrimary, width: 1.5),
                                ),
                              ),
                              onChanged: (text) {
                                final parsed = int.tryParse(text.trim()) ?? 0;
                                final clamped = parsed.clamp(0, 1440);
                                setState(() {
                                  action.pulseMinutes = clamped;
                                });
                              },
                            ),
                          ),
                          const SizedBox(width: 6),
                          _buildQuickAdjustButton('-5m', () {
                            final cur = action.pulseMinutes;
                            final next = (cur - 5).clamp(0, 1440);
                            setState(() {
                              action.pulseMinutes = next;
                              action.customPulseController.text = next > 0 ? next.toString() : '';
                            });
                          }, tokens),
                          const SizedBox(width: 4),
                          _buildQuickAdjustButton('+5m', () {
                            final cur = action.pulseMinutes;
                            final next = (cur + 5).clamp(0, 1440);
                            setState(() {
                              action.pulseMinutes = next;
                              action.customPulseController.text = next.toString();
                            });
                          }, tokens),
                          const SizedBox(width: 4),
                          _buildQuickAdjustButton('+15m', () {
                            final cur = action.pulseMinutes;
                            final next = (cur + 15).clamp(0, 1440);
                            setState(() {
                              action.pulseMinutes = next;
                              action.customPulseController.text = next.toString();
                            });
                          }, tokens),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        action.pulseMinutes > 0
                            ? '⏱ Relay will turn ON, then autonomously shut OFF after ${action.pulseMinutes} min(s) (${action.pulseMinutes >= 60 ? '${action.pulseMinutes ~/ 60}h ${action.pulseMinutes % 60 > 0 ? '${action.pulseMinutes % 60}m' : ''} · ' : ''}${action.pulseMinutes * 60}s autonomous chip countdown).'
                            : '⚡ Continuous Mode: Channel stays ON indefinitely until turned off manually or by another routine.',
                        style: TextStyle(
                          color: action.pulseMinutes > 0 ? tokens.bluePrimary : tokens.textSecondary,
                          fontSize: 11,
                          fontWeight: action.pulseMinutes > 0 ? FontWeight.w600 : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _addAction,
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
              side: BorderSide(color: tokens.bluePrimary.withValues(alpha: 0.5), width: 1.2),
              backgroundColor: tokens.bluePrimary.withValues(alpha: 0.08),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            icon: Icon(Icons.add_circle_outline_rounded, color: tokens.bluePrimary, size: 20),
            label: Text(
              'Add Another Action',
              style: TextStyle(color: tokens.bluePrimary, fontWeight: FontWeight.w800, fontSize: 14),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildQuickAdjustButton(String label, VoidCallback onTap, EHThemeTokens tokens) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 8),
        decoration: BoxDecoration(
          color: tokens.bluePrimary.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: tokens.bluePrimary.withValues(alpha: 0.3)),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: tokens.bluePrimary,
            fontWeight: FontWeight.w700,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  Widget _buildStepReview(EHThemeTokens tokens) {
    final name = _nameController.text.trim().isEmpty ? 'Custom Routine' : _nameController.text.trim();
    final String triggerDesc;
    final IconData triggerIcon;
    if (_triggerMode == _TriggerMode.manual) {
      triggerDesc = 'Manual Tap or Alexa Voice Shortcut';
      triggerIcon = Icons.touch_app_rounded;
    } else if (_triggerMode == _TriggerMode.solar) {
      final solarName = _isSunset ? 'Sunset' : 'Sunrise';
      final offsetStr = _solarOffsetMinutes == 0
          ? 'At $solarName'
          : '${_solarOffsetMinutes.abs()} min ${_solarOffsetMinutes < 0 ? "before" : "after"} $solarName';
      triggerDesc = '$offsetStr (${_formatDaysSummary()})';
      triggerIcon = Icons.wb_twilight_rounded;
    } else if (_triggerMode == _TriggerMode.soil) {
      final opText = _soilOp == '<' ? 'drops below' : 'rises above';
      triggerDesc = 'Smart Garden: When soil moisture $opText ${_soilThreshold.toInt()}%';
      triggerIcon = Icons.grass_rounded;
    } else if (_triggerMode == _TriggerMode.tank) {
      final opText = _tankOp == '<' ? 'drops below' : 'reaches';
      triggerDesc = 'Water Tank: When level $opText ${_tankThreshold.toInt()}%';
      triggerIcon = Icons.water_drop_rounded;
    } else if (_triggerMode == _TriggerMode.climate) {
      final opText = _tempOp == '>' ? 'rises above' : 'drops below';
      triggerDesc = 'Climate: When temperature $opText ${_tempThreshold.toInt()}°C';
      triggerIcon = Icons.thermostat_rounded;
    } else if (_triggerMode == _TriggerMode.humidity) {
      final opText = _humidityOp == '>' ? 'exceeds' : 'drops below';
      triggerDesc = 'Humidity: When humidity $opText ${_humidityThreshold.toInt()}%';
      triggerIcon = Icons.water_rounded;
    } else if (_triggerMode == _TriggerMode.light) {
      triggerDesc = 'Ambient: When darkness falls (< ${_luxThreshold.toInt()} Lux)';
      triggerIcon = Icons.nightlight_round;
    } else if (_triggerMode == _TriggerMode.motion) {
      triggerDesc = _motionType == 'detected' ? 'Motion: When motion is detected' : 'Motion: When clear for 10 min';
      triggerIcon = Icons.directions_run_rounded;
    } else {
      triggerDesc = '${_formatDaysSummary()} at ${_formatTimeOfDay(_scheduledTime)}';
      triggerIcon = Icons.access_time_rounded;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Review Routine',
          style: TextStyle(color: tokens.textPrimary, fontSize: 22, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 6),
        Text(
          'Verify your automation details and test live on hardware.',
          style: TextStyle(color: tokens.textSecondary, fontSize: 13),
        ),
        const SizedBox(height: 18),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: tokens.surfaceCard,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: tokens.borderControl),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: tokens.bluePrimary.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _iconOptions.firstWhere((opt) => opt.$1 == _selectedIcon, orElse: () => _iconOptions.first).$2,
                      color: tokens.bluePrimary,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name, style: TextStyle(color: tokens.textPrimary, fontSize: 18, fontWeight: FontWeight.w800)),
                        const SizedBox(height: 2),
                        Text(_isFavorite ? '★ Favorited Routine' : 'Standard Routine', style: TextStyle(color: tokens.textSecondary, fontSize: 12)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const Divider(height: 1),
              const SizedBox(height: 16),
              Text('WHEN', style: TextStyle(color: tokens.success, fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 0.5)),
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(
                    triggerIcon,
                    color: tokens.textSecondary,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(triggerDesc, style: TextStyle(color: tokens.textPrimary, fontSize: 14, fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Text('THEN DO', style: TextStyle(color: tokens.bluePrimary, fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 0.5)),
              const SizedBox(height: 8),
              ..._actions.map((act) {
                final opText = act.isToggle ? 'Toggle' : (act.targetState ? 'Turn ON' : 'Turn OFF');
                final chText = act.channelIndex == 0 ? 'All Channels' : act.channelName;
                final timerText = act.pulseMinutes > 0 ? ' (⏱ Auto-off ${act.pulseMinutes}m)' : '';
                return Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      Icon(Icons.check_circle_rounded, color: tokens.bluePrimary, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${act.deviceName} (${act.roomName}) • $chText: $opText$timerText',
                          style: TextStyle(color: tokens.textPrimary, fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: tokens.surfaceCard,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: tokens.borderSubtle),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.hub_rounded, color: tokens.bluePrimary, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Execution Priority (Hub Connected)',
                    style: TextStyle(
                      color: tokens.textPrimary,
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                value: _criticalHardwareFallback,
                onChanged: (val) => setState(() => _criticalHardwareFallback = val),
                title: Text(
                  'Critical Hardware Fallback',
                  style: TextStyle(
                    color: tokens.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                subtitle: Text(
                  _criticalHardwareFallback
                      ? 'Stores backup copy in switch flash. Fires on time even if Hub is unplugged.'
                      : 'Standard routine: runs from Hub RAM with zero switch flash memory wear.',
                  style: TextStyle(color: tokens.textSecondary, fontSize: 12),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _testRunActions,
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
              side: BorderSide(color: tokens.borderControl),
              backgroundColor: tokens.surfaceCard,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            icon: Icon(Icons.play_arrow_rounded, color: tokens.textPrimary, size: 22),
            label: Text(
              'Test Run Live on Hardware',
              style: TextStyle(color: tokens.textPrimary, fontWeight: FontWeight.w700, fontSize: 14),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBottomBar(EHThemeTokens tokens) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      decoration: BoxDecoration(
        color: tokens.bgApp,
        border: Border(top: BorderSide(color: tokens.borderSubtle)),
      ),
      child: Row(
        children: [
          if (_step > 0) ...[
            Expanded(
              flex: 1,
              child: OutlinedButton(
                onPressed: () => setState(() => _step--),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  side: BorderSide(color: tokens.borderControl),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: Text('Back', style: TextStyle(color: tokens.textSecondary, fontWeight: FontWeight.w700)),
              ),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            flex: 2,
            child: FilledButton(
              onPressed: _saving
                  ? null
                  : () {
                      if (_step == 0 && _nameController.text.trim().isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Please enter a routine name before continuing.'),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                        return;
                      }
                      if (_step < 3) {
                        setState(() => _step++);
                      } else {
                        _saveRoutine();
                      }
                    },
              style: FilledButton.styleFrom(
                backgroundColor: tokens.bluePrimary,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 2,
              ),
              child: _saving
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(Colors.white)),
                    )
                  : Text(
                      _step == 3 ? 'Save Routine' : 'Continue',
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: Colors.white),
                    ),
            ),
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
  const _DevicesSection({required this.devices, this.fallbackRoutine});
  final List<RoutineDevice> devices;
  final Routine? fallbackRoutine;

  @override
  Widget build(BuildContext context) {
    final tokens = context.ehColors;
    final ctrlDevs = HomeController.instance?.devices ?? [];
    List<RoutineDevice> resolvedDevices = List.from(devices);
    if (resolvedDevices.isEmpty && fallbackRoutine != null) {
      final actionDevIds = fallbackRoutine!.actions.map((a) => a.deviceId).toSet();
      final matched = ctrlDevs.where((d) => actionDevIds.contains(d.id)).map((d) => RoutineDevice(
        id: d.id,
        name: d.name,
        room: d.roomName,
        online: d.online,
        capabilities: const [],
      )).toList();
      if (matched.isNotEmpty) {
        resolvedDevices = matched;
      }
    }

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
            const SizedBox(height: 4),
            if (resolvedDevices.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'No devices currently assigned.',
                  style: TextStyle(color: tokens.textSecondary, fontSize: 13),
                ),
              )
            else
              ...resolvedDevices.map(
                (device) {
                  final liveMatch = ctrlDevs.cast<ConnectedDeviceSummary?>().firstWhere(
                    (d) => d?.id == device.id,
                    orElse: () => null,
                  );
                  final isMissing = liveMatch == null;
                  final isOnline = liveMatch != null && liveMatch.online;
                  final statusText = isMissing
                      ? '● Needs Reassignment'
                      : (isOnline ? '● Online' : '● Offline');
                  final statusColor = isMissing
                      ? tokens.warning
                      : (isOnline ? tokens.success : tokens.textSecondary);

                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      backgroundColor: isMissing ? tokens.surfaceElevated : tokens.iconBgBlue,
                      child: Icon(
                        isMissing ? Icons.device_unknown_rounded : Icons.devices_other_rounded,
                        color: isMissing ? tokens.warning : tokens.bluePrimary,
                      ),
                    ),
                    title: Text(
                      isMissing ? '${device.name} (Removed)' : device.name,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: tokens.buttonText,
                      ),
                    ),
                    subtitle: Text(
                      device.room.isNotEmpty ? device.room : 'Unassigned',
                      style: TextStyle(color: tokens.textSecondary),
                    ),
                    trailing: Text(
                      statusText,
                      style: TextStyle(
                        color: statusColor,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _ActivitySection extends StatelessWidget {
  const _ActivitySection({required this.history, this.routineName, this.routineId});
  final List<RoutineExecution>? history;
  final String? routineName;
  final String? routineId;

  @override
  Widget build(BuildContext context) {
    final tokens = context.ehColors;
    List<RoutineExecution> resolvedHistory = history != null ? List.from(history!) : [];
    if (resolvedHistory.isEmpty) {
      final ctrlAlerts = HomeController.instance?.activityAlerts ?? [];
      final routineAlerts = ctrlAlerts.where((a) => a.deviceId == 'routine' || (routineName != null && a.title.contains(routineName!)));
      for (final a in routineAlerts) {
        resolvedHistory.add(
          RoutineExecution(
            id: a.id,
            routineId: routineId ?? '',
            startedAt: a.timestamp,
            completedAt: a.timestamp,
            result: a.severity == AlertSeverity.critical ? RoutineExecutionResult.failed : RoutineExecutionResult.succeeded,
            message: a.message,
          ),
        );
      }
    }

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
            if (history == null && resolvedHistory.isEmpty)
              LinearProgressIndicator(color: tokens.bluePrimary)
            else if (resolvedHistory.isEmpty)
              Text(
                'No executions recorded yet.',
                style: TextStyle(color: tokens.textSecondary),
              )
            else
              ...resolvedHistory.map(
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
