import 'package:flutter/material.dart';

import '../../../../core/models/privacy_models.dart';
import '../../../../core/repositories/privacy_repository.dart';
import '../../../../core/services/app_permission_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../settings_ui.dart';

class PrivacyPermissionDetailPage extends StatefulWidget {
  const PrivacyPermissionDetailPage({
    super.key,
    required this.permission,
    this.repository,
    this.permissionService,
  });

  final PrivacyPermission permission;
  final PrivacyRepository? repository;
  final AppPermissionService? permissionService;

  @override
  State<PrivacyPermissionDetailPage> createState() =>
      _PrivacyPermissionDetailPageState();
}

class _PrivacyPermissionDetailPageState
    extends State<PrivacyPermissionDetailPage>
    with WidgetsBindingObserver {
  late PrivacyPermission _permission;
  late AppPermissionService _service;
  bool _isRequesting = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _permission = widget.permission;
    _service = widget.permissionService ?? AppPermissionService.instance;
    _refreshStatus();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshStatus();
    }
  }

  Future<void> _refreshStatus() async {
    try {
      final status = await _service.queryPermission(_permission.id);
      if (mounted) {
        setState(() {
          _permission = _permission.copyWith(status: status);
        });
      }
    } catch (_) {}
  }

  Future<void> _requestPermission() async {
    if (_isRequesting) return;
    setState(() => _isRequesting = true);
    try {
      final newStatus = await _service.requestPermission(_permission.id);
      if (mounted) {
        setState(() {
          _permission = _permission.copyWith(status: newStatus);
          _isRequesting = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isRequesting = false);
    }
  }

  Future<void> _openSettings() async {
    await _service.openSettings();
  }

  Color get _statusColor => switch (_permission.status) {
    PrivacyPermissionStatus.allowed ||
    PrivacyPermissionStatus.whileUsing =>
      SettingsColors.green,
    PrivacyPermissionStatus.denied ||
    PrivacyPermissionStatus.permanentlyDenied =>
      SettingsColors.red,
    PrivacyPermissionStatus.notRequested ||
    PrivacyPermissionStatus.unavailable =>
      SettingsColors.muted,
  };

  @override
  Widget build(BuildContext context) {
    final tokens = context.ehColors;
    final isPermanentlyDenied =
        _permission.status == PrivacyPermissionStatus.permanentlyDenied;
    final canRequest =
        _permission.status == PrivacyPermissionStatus.notRequested ||
        _permission.status == PrivacyPermissionStatus.denied;
    return NestedSettingsScaffold(
      title: _permission.title,
      subtitle: _permission.description,
      child: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              children: [
                SettingsSurface(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  child: SizedBox(
                    width: double.infinity,
                    child: Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 12,
                      runSpacing: 8,
                      children: [
                        const Text(
                          'Current status',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: _statusColor.withValues(
                              alpha: tokens.isDark ? 0.22 : 0.12,
                            ),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            _permission.statusLabel,
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                              color: _statusColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (isPermanentlyDenied) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: tokens.isDark
                          ? const Color(0xFF331414)
                          : const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: tokens.isDark
                            ? const Color(0xFF7F1D1D)
                            : const Color(0xFFFCA5A5),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.info_outline_rounded,
                          color: SettingsColors.red,
                          size: 22,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Permission permanently denied',
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 15,
                                  color: tokens.isDark
                                      ? const Color(0xFFFCA5A5)
                                      : const Color(0xFF991B1B),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'This permission is disabled in system settings. Please open settings to grant access so EH Home can use this feature.',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: tokens.isDark
                                      ? const Color(0xFFFECACA)
                                      : const Color(0xFF7F1D1D),
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
            child: canRequest
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: _isRequesting ? null : _requestPermission,
                          child: _isRequesting
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text('Request permission'),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: _openSettings,
                          child: const Text('Open system settings'),
                        ),
                      ),
                    ],
                  )
                : SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _openSettings,
                      child: const Text('Open system settings'),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
