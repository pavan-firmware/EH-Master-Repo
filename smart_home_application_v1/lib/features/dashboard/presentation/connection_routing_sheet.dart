import 'package:flutter/material.dart';
import '../../../app/home_controller.dart';
import '../../../core/services/local_lan_device_service.dart';
import '../../../core/theme/app_theme.dart';
import 'cloud_sync_center_sheet.dart';
import '../../hub/data/hub_repository.dart';
import '../../hub/presentation/hub_management_page.dart';

class ConnectionRoutingSheet extends StatelessWidget {
  const ConnectionRoutingSheet({
    super.key,
    required this.homeController,
  });

  final HomeController homeController;

  @override
  Widget build(BuildContext context) {
    final tokens = context.ehColors;

    return AnimatedBuilder(
      animation: homeController,
      builder: (context, _) {
        final currentMode = homeController.routingMode;
        final isLocalActive = homeController.isLocalMode;
        final isCloudReachable = homeController.isCloudReachable;
        final activeSpaceName = homeController.activeSpaceName;
        final isLanMatch = homeController.isCurrentSpaceOnLocalLan;
        final isHubActive = LiveHubRepository.isLinked && LiveHubRepository.isHubActive;

        return Container(
          decoration: BoxDecoration(
            color: tokens.surfaceCard,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * 0.9,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Top drag handle with downward swipe-to-dismiss gesture
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onVerticalDragEnd: (details) {
                    if (details.primaryVelocity != null && details.primaryVelocity! > 100) {
                      Navigator.of(context).pop();
                    }
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.only(top: 14, bottom: 8),
                    child: Center(
                      child: Container(
                        width: 44,
                        height: 5,
                        decoration: BoxDecoration(
                          color: tokens.textTertiary.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),
                  ),
                ),

                Flexible(
                  child: SingleChildScrollView(
                    physics: const ClampingScrollPhysics(),
                    padding: EdgeInsets.fromLTRB(20, 8, 20, MediaQuery.viewInsetsOf(context).bottom + 28),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Title Row
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: tokens.bluePrimary.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Icon(Icons.hub_rounded, color: tokens.bluePrimary, size: 24),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Connection Mode & Routing',
                                    style: TextStyle(
                                      fontSize: 19,
                                      fontWeight: FontWeight.w800,
                                      color: tokens.textPrimary,
                                    ),
                                  ),
                                  Text(
                                    'Choose how the app communicates with your devices',
                                    style: TextStyle(fontSize: 12, color: tokens.textSecondary),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: Icon(Icons.close_rounded, color: tokens.textSecondary),
                              onPressed: () => Navigator.of(context).pop(),
                              tooltip: 'Close',
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),

              // Option 1: Auto Mode
              _RoutingOptionCard(
                title: isHubActive ? 'Smart Hub Auto Mesh (<5ms)' : 'Smart Auto Routing',
                subtitle: isHubActive
                    ? 'Routes commands through EH Smart Hub Gateway on LAN for <5ms execution, with seamless cloud fallback.'
                    : 'Automatically uses ultra-fast Local LAN on home Wi-Fi, and routes through secure Cloud when away.',
                icon: isHubActive ? Icons.hub_rounded : Icons.bolt_rounded,
                iconColor: isHubActive ? const Color(0xFF10B981) : tokens.bluePrimary,
                isSelected: currentMode == ConnectionRoutingMode.auto,
                badgeText: isHubActive ? 'Hub Active' : 'Recommended',
                onTap: () {
                  homeController.setRoutingMode(ConnectionRoutingMode.auto);
                  Navigator.of(context).pop();
                },
              ),
              if (isHubActive) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.hub_rounded, size: 18, color: Color(0xFF10B981)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Local Hub Mesh Active (${LiveHubRepository.activeHost ?? "eh-hub.local"} • 3ms)',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF059669),
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => HubManagementPage(
                                homeId: homeController.activeHomeId ?? 'home_01',
                              ),
                            ),
                          );
                        },
                        style: TextButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                        ),
                        child: const Text('Manage Hub', style: TextStyle(fontWeight: FontWeight.w800)),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 12),

              // Option 2: Local LAN Only
              _RoutingOptionCard(
                title: 'Local Wi-Fi Only (Direct LAN)',
                subtitle: 'Locks all communication strictly to your local home network. Zero cloud dependency, no jumbling.',
                icon: Icons.wifi_tethering_rounded,
                iconColor: const Color(0xFFF59E0B),
                isSelected: currentMode == ConnectionRoutingMode.localOnly,
                badgeText: 'Offline Safe',
                onTap: () {
                  homeController.setRoutingMode(ConnectionRoutingMode.localOnly);
                  Navigator.of(context).pop();
                },
              ),
              const SizedBox(height: 12),

              // Option 3: Cloud Only
              _RoutingOptionCard(
                title: 'Cloud Mode Only (Remote Internet)',
                subtitle: 'Forces all commands and states through the secure cloud backend. Best for remote cellular control.',
                icon: Icons.cloud_done_rounded,
                iconColor: const Color(0xFF10B981),
                isSelected: currentMode == ConnectionRoutingMode.cloudOnly,
                badgeText: 'Remote',
                onTap: () {
                  homeController.setRoutingMode(ConnectionRoutingMode.cloudOnly);
                  Navigator.of(context).pop();
                },
              ),
              const SizedBox(height: 22),

              // Diagnostics Section
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: tokens.isDark ? const Color(0xFF141F30) : const Color(0xFFF4F7FB),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: tokens.borderSubtle),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.monitor_heart_rounded, color: tokens.bluePrimary, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          'Live Connection Diagnostics',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: tokens.textPrimary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _DiagnosticRow(
                      label: 'Smart Hub Gateway',
                      value: isHubActive
                          ? 'Active (${LiveHubRepository.activeHost ?? "eh-hub.local"} • 3ms)'
                          : 'Not Connected (Direct LAN fallback)',
                      statusColor: isHubActive ? tokens.success : tokens.textTertiary,
                    ),
                    _DiagnosticRow(
                      label: 'Active Space',
                      value: '$activeSpaceName (${isLanMatch ? "In Home Wi-Fi" : "Remote Space"})',
                      statusColor: isLanMatch ? tokens.success : tokens.textTertiary,
                    ),
                    _DiagnosticRow(
                      label: 'Current Link Mode',
                      value: isLocalActive ? 'Direct Local LAN (Wi-Fi)' : 'Cloud Backend',
                      statusColor: isLocalActive ? const Color(0xFFF59E0B) : const Color(0xFF10B981),
                    ),
                    _DiagnosticRow(
                      label: 'Cloud Server Reachability',
                      value: isCloudReachable ? 'Online & Authenticated' : 'Offline / Unreachable',
                      statusColor: isCloudReachable ? tokens.success : const Color(0xFFEF4444),
                    ),
                    _DiagnosticRow(
                      label: 'Discovered Local Devices',
                      value: '${LocalLanDeviceService.instance.discoveredDeviceCount} reachable on LAN',
                      statusColor: LocalLanDeviceService.instance.discoveredDeviceCount > 0 ? tokens.success : tokens.textTertiary,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (_) => CloudSyncCenterSheet(homeController: homeController),
                    );
                  },
                  icon: const Icon(Icons.cloud_sync_rounded, size: 18),
                  label: const Text('Open Cloud Sync & Offline Backup'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: tokens.bluePrimary,
                    side: BorderSide(color: tokens.bluePrimary.withValues(alpha: 0.5)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ],
  ),
),
);
  },
);
}
}

class _RoutingOptionCard extends StatelessWidget {
  const _RoutingOptionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.iconColor,
    required this.isSelected,
    required this.badgeText,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color iconColor;
  final bool isSelected;
  final String badgeText;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.ehColors;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? tokens.bluePrimary.withValues(alpha: 0.1)
              : tokens.surfaceCard,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isSelected ? tokens.bluePrimary : tokens.borderSubtle,
            width: isSelected ? 2.0 : 1.0,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          title,
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                            color: tokens.textPrimary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? tokens.bluePrimary
                              : tokens.isDark
                                  ? const Color(0xFF253347)
                                  : const Color(0xFFE2E8F0),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          badgeText,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: isSelected ? Colors.white : tokens.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: tokens.textSecondary,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              isSelected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
              color: isSelected ? tokens.bluePrimary : tokens.textTertiary,
              size: 22,
            ),
          ],
        ),
      ),
    );
  }
}

class _DiagnosticRow extends StatelessWidget {
  const _DiagnosticRow({
    required this.label,
    required this.value,
    required this.statusColor,
  });

  final String label;
  final String value;
  final Color statusColor;

  @override
  Widget build(BuildContext context) {
    final tokens = context.ehColors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 12, color: tokens.textSecondary)),
          Row(
            children: [
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(shape: BoxShape.circle, color: statusColor),
              ),
              const SizedBox(width: 6),
              Text(
                value,
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: tokens.textPrimary),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
