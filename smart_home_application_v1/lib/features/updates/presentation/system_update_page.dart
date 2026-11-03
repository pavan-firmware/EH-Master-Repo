import 'dart:async';
import 'package:flutter/material.dart';

import '../../../app/home_controller.dart';
import '../../../core/api/api_client.dart';
import '../../../core/config/app_config.dart';
import '../../../core/models/update_models.dart';
import '../../../core/repositories/cloud_home_repository.dart';
import '../../../core/repositories/cloud_update_repository.dart';
import '../../../core/repositories/update_repository.dart';
import '../../../core/services/check_timestamp_service.dart';
import '../../../core/theme/app_theme.dart';
import 'update_history_page.dart';
import 'update_preferences_page.dart';
import 'update_target_detail_page.dart';

class SystemUpdatePage extends StatefulWidget {
  const SystemUpdatePage({
    super.key,
    this.repository = const PreviewUpdateRepository(),
    this.homeController,
    this.timestampService,
  });

  final UpdateRepository repository;
  final HomeController? homeController;
  final CheckTimestampService? timestampService;

  @override
  State<SystemUpdatePage> createState() => _SystemUpdatePageState();
}

class _SystemUpdatePageState extends State<SystemUpdatePage> with SingleTickerProviderStateMixin {
  late Future<UpdateSummary> _summary;
  late UpdateRepository _effectiveRepository;
  bool _checking = false;
  late AnimationController _animController;
  DateTime? _lastCheckedTime;
  Timer? _ticker;

  CheckTimestampService get _timeService =>
      widget.timestampService ?? CheckTimestampService.instance;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _loadLastChecked();

    if (widget.repository is! PreviewUpdateRepository) {
      _effectiveRepository = widget.repository;
    } else if (widget.homeController != null) {
      final ctrl = widget.homeController;
      final client = (ctrl?.repository is CloudHomeRepository)
          ? (ctrl!.repository as CloudHomeRepository).client
          : ApiClient(baseUrl: AppConfig.backendBaseUrl);

      _effectiveRepository = CloudUpdateRepository(
        apiClient: client,
        timestampService: _timeService,
        getActiveHomeId: () => (ctrl?.repository is CloudHomeRepository)
            ? (ctrl!.repository as CloudHomeRepository).activeHomeId ?? ctrl.activeHomeId
            : ctrl?.activeHomeId,
        getLocalDevices: () {
          final devs = ctrl?.devices ?? [];
          if (devs.isEmpty && ctrl?.connectedDeviceSummary != null) {
            return [ctrl!.connectedDeviceSummary!];
          }
          return devs;
        },
      );
    } else {
      _effectiveRepository = widget.repository;
    }

    _load();

    _ticker = Timer.periodic(const Duration(seconds: 15), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _animController.dispose();
    super.dispose();
  }

  Future<void> _loadLastChecked() async {
    final ts = await _timeService.getLastSuccessfulCheck(
      CheckTimestampService.systemUpdateKey,
    );
    if (mounted) {
      setState(() {
        _lastCheckedTime = ts;
      });
    }
  }

  void _load() {
    setState(() {
      _summary = _effectiveRepository.getSummary();
    });
  }

  Future<void> _checkUpdates() async {
    if (_checking) return;
    setState(() => _checking = true);
    _animController.repeat();

    // Trigger LAN probe in background without stalling the update check
    if (widget.homeController != null) {
      try {
        widget.homeController!.probeLanAndPromote().catchError((_) => false);
      } catch (_) {}
    }

    try {
      final result = await _effectiveRepository.checkForUpdates();
      if (mounted) {
        _animController.stop();
        _animController.reset();

        if (result.isUnavailable) {
          setState(() {
            _summary = Future.value(result);
            _checking = false;
          });

          final isNoNet = result.errorType == UpdateErrorType.noInternet;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Icon(
                    isNoNet ? Icons.wifi_off_rounded : Icons.dns_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      result.subtitle,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                  ),
                ],
              ),
              backgroundColor: isNoNet ? const Color(0xFFD97706) : const Color(0xFFDC2626),
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 4),
            ),
          );
          return;
        }

        final completionTime = _timeService.now;
        await _timeService.recordSuccessfulCheck(
          CheckTimestampService.systemUpdateKey,
          completionTime,
        );

        if (!mounted) return;

        setState(() {
          _lastCheckedTime = completionTime;
          _summary = Future.value(result);
          _checking = false;
        });

        final updateCount = result.availableCount;
        final hasUpdates = updateCount > 0;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              hasUpdates
                  ? '$updateCount firmware update ready to install!'
                  : 'Check complete: All devices running latest firmware.',
            ),
            backgroundColor: hasUpdates ? const Color(0xFFD97706) : const Color(0xFF059669),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        _animController.stop();
        _animController.reset();
        setState(() => _checking = false);
        final lower = e.toString().toLowerCase();
        final isNet = lower.contains('failed host lookup') || lower.contains('network is unreachable');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isNet
                  ? 'Internet connection required. Please verify your Wi-Fi or data.'
                  : 'Unable to reach update server: $e',
            ),
            backgroundColor: isNet ? const Color(0xFFD97706) : const Color(0xFFDC2626),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  String _formatLastChecked(DateTime? dt) {
    if (dt == null) return 'Never';
    return _timeService.formatRelativeTime(dt);
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.ehColors;

    return Scaffold(
      backgroundColor: tokens.bgApp,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'System Update',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: tokens.textPrimary,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'Fleet firmware & app lifecycle',
              style: TextStyle(fontSize: 12, color: tokens.textSecondary),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.history_rounded, color: tokens.textSecondary),
            tooltip: 'Update History',
            onPressed: () async {
              final nav = Navigator.of(context);
              final summary = await _summary;
              if (!mounted) return;
              nav.push(
                MaterialPageRoute(
                  builder: (_) => UpdateHistoryPage(history: summary.history),
                ),
              );
            },
          ),
          IconButton(
            icon: Icon(Icons.settings_outlined, color: tokens.textSecondary),
            tooltip: 'Update Preferences',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const UpdatePreferencesPage()),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: FutureBuilder<UpdateSummary>(
        future: _summary,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.wifi_off_rounded, size: 48, color: tokens.warning),
                    const SizedBox(height: 16),
                    Text(
                      'Connection Required',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: tokens.textPrimary),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Unable to check for updates: ${snapshot.error}',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: tokens.textSecondary, fontSize: 13),
                    ),
                    const SizedBox(height: 18),
                    FilledButton.icon(
                      onPressed: _load,
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Try Again'),
                    ),
                  ],
                ),
              ),
            );
          }

          if (!snapshot.hasData) {
            return Center(
              child: CircularProgressIndicator(color: tokens.bluePrimary),
            );
          }

          final summary = snapshot.data!;
          final isUnavailable = summary.isUnavailable;
          final hasUpdate = !isUnavailable && (summary.overallStatus == UpdateOverallStatus.updateAvailable || summary.availableCount > 0);
          final deviceTargets = summary.targets.where((t) => t.kind == UpdateTargetKind.device).toList();
          final appTarget = summary.targets.firstWhere(
            (t) => t.kind == UpdateTargetKind.app,
            orElse: () => const UpdateTarget(
              kind: UpdateTargetKind.app,
              name: 'EH Home app',
              currentVersion: 'Version 1.0.0',
              status: UpdateTargetStatus.upToDate,
            ),
          );

          return ListView(
            padding: const EdgeInsets.fromLTRB(18, 8, 18, 32),
            physics: const BouncingScrollPhysics(),
            children: [
              // 1. Ambient Hero Status Card
              _buildHeroStatusCard(tokens, summary, hasUpdate),

              const SizedBox(height: 26),

              // 2. Hardware Fleet Devices Section
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      'CONNECTED HARDWARE',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: tokens.textTertiary,
                        letterSpacing: 1.1,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${deviceTargets.length} ${deviceTargets.length == 1 ? 'node' : 'nodes'} active',
                    style: TextStyle(fontSize: 11, color: tokens.textSecondary),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              if (deviceTargets.isEmpty)
                _buildEmptyHardwareCard(tokens)
              else
                for (final target in deviceTargets)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _buildDeviceUpdateTile(tokens, target),
                  ),

              const SizedBox(height: 20),

              // 3. Mobile App Client Section
              Text(
                'MOBILE APPLICATION',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: tokens.textTertiary,
                  letterSpacing: 1.1,
                ),
              ),
              const SizedBox(height: 10),
              _buildAppTargetTile(tokens, appTarget),
            ],
          );
        },
      ),
    );
  }

  Widget _buildHeroStatusCard(EHThemeTokens tokens, UpdateSummary summary, bool hasUpdate) {
    final isUnavailable = summary.isUnavailable;
    final isNoInternet = summary.errorType == UpdateErrorType.noInternet;
    final isServerIssue = summary.errorType == UpdateErrorType.serverUnreachable || summary.errorType == UpdateErrorType.serverError;

    final statusColor = isUnavailable
        ? (isNoInternet ? const Color(0xFFF59E0B) : const Color(0xFFEF4444))
        : (hasUpdate ? const Color(0xFFF59E0B) : const Color(0xFF10B981));

    final gradientColors = isUnavailable
        ? [statusColor.withValues(alpha: 0.16), statusColor.withValues(alpha: 0.04)]
        : (hasUpdate
            ? [const Color(0xFFF59E0B).withValues(alpha: 0.16), const Color(0xFFD97706).withValues(alpha: 0.05)]
            : [const Color(0xFF10B981).withValues(alpha: 0.16), const Color(0xFF059669).withValues(alpha: 0.04)]);

    final heroIcon = isUnavailable
        ? (isNoInternet
            ? Icons.wifi_off_rounded
            : (isServerIssue ? Icons.dns_rounded : Icons.error_outline_rounded))
        : (hasUpdate ? Icons.system_update_rounded : Icons.check_circle_rounded);

    final heroTitle = isUnavailable
        ? summary.title
        : (hasUpdate
            ? 'Firmware Update Ready'
            : (summary.title.isNotEmpty ? summary.title : 'Everything is up to date'));

    final heroSubtitle = isUnavailable
        ? summary.subtitle
        : (hasUpdate
            ? 'A new validated firmware image is available on your local PC backend.'
            : 'All connected switches and nodes are running verified production firmware.');

    return Container(
      decoration: BoxDecoration(
        color: tokens.surfaceCard,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: (isUnavailable || hasUpdate) ? statusColor.withValues(alpha: 0.4) : tokens.borderSubtle,
          width: (isUnavailable || hasUpdate) ? 1.5 : 1,
        ),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradientColors,
        ),
        boxShadow: [
          BoxShadow(
            color: (isUnavailable || hasUpdate) ? statusColor.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.06),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.18),
                  shape: BoxShape.circle,
                  border: Border.all(color: statusColor.withValues(alpha: 0.4), width: 1.5),
                ),
                child: Icon(
                  heroIcon,
                  color: statusColor,
                  size: 26,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      heroTitle,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: tokens.textPrimary,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      heroSubtitle,
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.35,
                        color: tokens.textSecondary,
                      ),
                    ),
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
              Expanded(
                child: Row(
                  children: [
                    Icon(Icons.schedule_rounded, size: 14, color: tokens.textTertiary),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Checked: ${_formatLastChecked(_lastCheckedTime ?? (widget.repository is! PreviewUpdateRepository ? summary.lastChecked : null))}',
                        style: TextStyle(fontSize: 12, color: tokens.textTertiary, fontWeight: FontWeight.w500),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                height: 38,
                child: ElevatedButton.icon(
                  onPressed: _checking ? null : _checkUpdates,
                  icon: _checking
                      ? RotationTransition(
                          turns: _animController,
                          child: const Icon(Icons.sync_rounded, size: 16),
                        )
                      : const Icon(Icons.refresh_rounded, size: 16),
                  label: Text(_checking ? 'Checking...' : 'Check now'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: tokens.bluePrimary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDeviceUpdateTile(EHThemeTokens tokens, UpdateTarget target) {
    final isUpdateAvailable = target.status == UpdateTargetStatus.updateAvailable;
    final isUpdating = target.status == UpdateTargetStatus.updating;

    return Material(
      color: tokens.surfaceCard,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => UpdateTargetDetailPage(
              target: target,
              updateRepository: _effectiveRepository,
              onUpdateInitiated: _checkUpdates,
            ),
          ),
        ),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isUpdateAvailable ? const Color(0xFFF59E0B).withValues(alpha: 0.5) : tokens.borderSubtle,
              width: isUpdateAvailable ? 1.5 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: isUpdateAvailable
                          ? const Color(0xFFF59E0B).withValues(alpha: 0.15)
                          : tokens.bluePrimary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      Icons.memory_rounded,
                      color: isUpdateAvailable ? const Color(0xFFF59E0B) : tokens.bluePrimary,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          target.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: tokens.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                target.currentVersion,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontSize: 12, color: tokens.textSecondary),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                              decoration: BoxDecoration(
                                color: const Color(0xFF10B981).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                'Active',
                                style: TextStyle(fontSize: 10, color: Color(0xFF10B981), fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (isUpdateAvailable)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF59E0B),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFF59E0B).withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.arrow_upward_rounded, size: 14, color: Colors.white),
                          const SizedBox(width: 4),
                          Text(
                            target.availableVersion?.replaceAll('Version ', 'v') ?? 'Update',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.white),
                          ),
                        ],
                      ),
                    )
                  else if (isUpdating)
                    const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  else
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 7,
                          height: 7,
                          decoration: const BoxDecoration(
                            color: Color(0xFF10B981),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Latest',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: tokens.textSecondary),
                        ),
                        const SizedBox(width: 4),
                        Icon(Icons.chevron_right_rounded, size: 18, color: tokens.textTertiary),
                      ],
                    ),
                ],
              ),
              if (isUpdateAvailable) ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: tokens.bgSecondary,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: tokens.borderSubtle),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFF2563EB).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.flash_on_rounded, size: 12, color: Color(0xFF2563EB)),
                                const SizedBox(width: 4),
                                Text(
                                  target.isDirectUpgrade
                                      ? 'Direct Upgrade (${target.currentVersion.replaceAll(RegExp(r'[^0-9.]'), '')} \u2192 ${target.availableVersion?.replaceAll('Version ', 'v')})'
                                      : 'Direct Release',
                                  style: const TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF2563EB),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (target.formattedSize.isNotEmpty) ...[
                            const SizedBox(width: 8),
                            Text(
                              target.formattedSize,
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: tokens.textTertiary),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        target.releaseNotes != null && target.releaseNotes!.isNotEmpty
                            ? target.releaseNotes!
                            : target.effectiveWhyUpdate,
                        style: TextStyle(
                          fontSize: 12.5,
                          height: 1.35,
                          color: tokens.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        'Why needed: ${target.effectiveWhyUpdate}',
                        style: TextStyle(
                          fontSize: 11.5,
                          height: 1.35,
                          color: tokens.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.verified_user_outlined, size: 13, color: tokens.textTertiary),
                              const SizedBox(width: 4),
                              Text(
                                target.sha256 != null
                                    ? 'SHA256: ${target.sha256!.substring(0, 10)}...'
                                    : 'Verified Binary',
                                style: TextStyle(fontSize: 10.5, color: tokens.textTertiary, fontFamily: 'monospace'),
                              ),
                            ],
                          ),
                          Text(
                            'Tap to review & install \u2192',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: tokens.bluePrimary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppTargetTile(EHThemeTokens tokens, UpdateTarget target) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: tokens.surfaceCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: tokens.borderSubtle),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFF8B5CF6).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.phone_android_rounded, color: Color(0xFF8B5CF6), size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'EH Home App',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: tokens.textPrimary),
                ),
                const SizedBox(height: 3),
                Text(
                  'Version 1.0.0 (Production Stable)',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: tokens.textSecondary),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text(
              'Up to date',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF10B981)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyHardwareCard(EHThemeTokens tokens) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: tokens.surfaceCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: tokens.borderSubtle),
      ),
      child: Row(
        children: [
          Icon(Icons.wifi_off_rounded, color: tokens.textTertiary, size: 28),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              'No smart devices registered in active space. Connect or commission a device to manage firmware.',
              style: TextStyle(fontSize: 13, color: tokens.textSecondary, height: 1.3),
            ),
          ),
        ],
      ),
    );
  }
}
