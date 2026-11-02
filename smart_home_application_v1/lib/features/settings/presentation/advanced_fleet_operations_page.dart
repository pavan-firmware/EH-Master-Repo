import 'package:flutter/material.dart';

import '../../../app/home_controller.dart';
import '../../../core/api/api_client.dart';
import '../../../core/config/app_config.dart';
import '../../../core/repositories/cloud_device_trust_repository.dart';
import '../../../core/repositories/cloud_fleet_firmware_repository.dart';
import '../../../core/repositories/cloud_operational_readiness_repository.dart';
import '../../../core/repositories/cloud_operations_repository.dart';
import '../../../core/repositories/cloud_recovery_repository.dart';
import '../../../core/services/connectivity_service.dart';
import '../../../core/services/context_presence_service.dart';
import '../../../core/services/edge_control_service.dart';
import '../../../core/services/energy_automation_service.dart';
import '../../../core/services/energy_cost_service.dart';
import '../../../core/services/reliability_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../connectivity/presentation/device_connectivity_page.dart';
import '../../context/presentation/home_context_page.dart';
import '../../context/presentation/presence_dashboard_page.dart';
import '../../device_trust/presentation/device_security_status_page.dart';
import '../../edge_control/presentation/edge_execution_dashboard_page.dart';
import '../../energy/presentation/energy_optimization_page.dart';
import '../../energy/presentation/tariff_management_page.dart';
import '../../fleet/presentation/firmware_releases_page.dart';
import '../../fleet/presentation/fleet_firmware_status_page.dart';
import '../../fleet/presentation/ota_rollouts_page.dart';
import '../../operations/presentation/operations_dashboard_page.dart';
import '../../operations/presentation/system_operational_status_page.dart';
import '../../recovery/presentation/recovery_dashboard_page.dart';
import '../../reliability/presentation/fleet_health_page.dart';
import 'settings_ui.dart';

/// Dedicated sub-hub for Enterprise, Operations, Diagnostics, and Fleet Management.
/// Keeps the primary consumer settings clean while giving administrators and engineers
/// rapid, structured access to all advanced capabilities.
class AdvancedFleetOperationsPage extends StatelessWidget {
  const AdvancedFleetOperationsPage({
    super.key,
    required this.homeId,
    this.apiClient,
    this.homeController,
    this.isAdmin = false,
  });

  final String homeId;
  final ApiClient? apiClient;
  final HomeController? homeController;
  final bool isAdmin;

  @override
  Widget build(BuildContext context) {
    final tokens = context.ehColors;
    final effectiveClient = apiClient ?? ApiClient(baseUrl: AppConfig.backendBaseUrl);
    final effectiveHomeId = homeId.isNotEmpty
        ? homeId
        : (homeController?.activeHomeId?.isNotEmpty == true
            ? homeController!.activeHomeId!
            : 'home_01');

    return NestedSettingsScaffold(
      title: 'System & Diagnostics',
      subtitle: 'Diagnostics, device firmware updates, telemetry, and security.',
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          // Banner
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: tokens.isDark
                  ? const Color(0xFF1E293B)
                  : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: tokens.isDark
                    ? const Color(0xFF334155)
                    : const Color(0xFFCBD5E1),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: tokens.bluePrimary.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.admin_panel_settings_rounded,
                    color: tokens.bluePrimary,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isAdmin ? 'Admin Console Active' : 'System Operations View',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                          color: tokens.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isAdmin
                            ? 'Administrative control over device updates and system security.'
                            : 'Inspection view of device telemetry and system performance.',
                        style: TextStyle(
                          fontSize: 12,
                          color: tokens.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // ── Observability & Operations ──────────────────────────────
          const SettingsSectionTitle('Observability & Operations'),
          SettingsSurface(
            child: Column(
              children: [
                SettingsListItem(
                  icon: Icons.monitor_heart_outlined,
                  title: 'Operations dashboard',
                  subtitle: 'Subsystem metrics, event audit, and API health',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => OperationsDashboardPage(
                        homeId: effectiveHomeId,
                        isAdmin: isAdmin,
                        repository: CloudOperationsRepository(effectiveClient),
                      ),
                    ),
                  ),
                  showDivider: true,
                ),
                SettingsListItem(
                  icon: Icons.verified_user_outlined,
                  title: 'System readiness',
                  subtitle: 'Platform operational status and subsystem health',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => SystemOperationalStatusPage(
                        repository: CloudOperationalReadinessRepository(effectiveClient),
                      ),
                    ),
                  ),
                  showDivider: true,
                ),
                SettingsListItem(
                  icon: Icons.health_and_safety_outlined,
                  title: 'Device reliability',
                  subtitle: 'Device health scores and incident diagnostics',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => FleetHealthPage(
                        homeId: effectiveHomeId,
                        reliabilityService: ReliabilityService(baseUrl: effectiveClient.baseUrl),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // ── Firmware & Updates ───────────────────────────────────
          const SettingsSectionTitle('Device Firmware & Updates'),
          SettingsSurface(
            child: Column(
              children: [
                SettingsListItem(
                  icon: Icons.developer_board_rounded,
                  title: 'Firmware releases',
                  subtitle: 'Signed artifacts, release channels, and change logs',
                  trailing: isAdmin
                      ? null
                      : SettingsStatusChip(
                          label: 'Admin only',
                          color: tokens.textSecondary,
                          background: tokens.surfaceCard,
                        ),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => FirmwareReleasesPage(
                        repository: CloudFleetFirmwareRepository(effectiveClient),
                      ),
                    ),
                  ),
                  showDivider: true,
                ),
                SettingsListItem(
                  icon: Icons.campaign_rounded,
                  title: 'OTA rollout campaigns',
                  subtitle: 'Batched deployments, canary gates, and rollbacks',
                  trailing: isAdmin
                      ? null
                      : SettingsStatusChip(
                          label: 'Admin only',
                          color: tokens.textSecondary,
                          background: tokens.surfaceCard,
                        ),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => OtaRolloutsPage(
                        repository: CloudFleetFirmwareRepository(effectiveClient),
                      ),
                    ),
                  ),
                  showDivider: true,
                ),
                SettingsListItem(
                  icon: Icons.devices_other_rounded,
                  title: 'Device firmware status',
                  subtitle: 'Per-device firmware versions, rollout states & health',
                  trailing: isAdmin
                      ? null
                      : SettingsStatusChip(
                          label: 'Admin only',
                          color: tokens.textSecondary,
                          background: tokens.surfaceCard,
                        ),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => FleetFirmwareStatusPage(
                        repository: CloudFleetFirmwareRepository(effectiveClient),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // ── Security & Resilience ──────────────────────────────────
          const SettingsSectionTitle('Security & Resilience'),
          SettingsSurface(
            child: Column(
              children: [
                SettingsListItem(
                  icon: Icons.security_rounded,
                  title: 'Device trust center',
                  subtitle: 'Certificate trust, secure boot, and anomaly detection',
                  trailing: isAdmin
                      ? null
                      : SettingsStatusChip(
                          label: 'Admin only',
                          color: tokens.textSecondary,
                          background: tokens.surfaceCard,
                        ),
                  onTap: () {
                    final targetDevice = homeController?.devices.firstOrNull;
                    final devId = targetDevice?.id ??
                        homeController?.activeDeviceId ??
                        'gateway-root';
                    final devName = targetDevice?.name ?? 'Hardware Root of Trust';
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => DeviceSecurityStatusPage(
                          deviceId: devId,
                          deviceName: devName,
                          isAdmin: isAdmin,
                          repository: CloudDeviceTrustRepository(effectiveClient),
                        ),
                      ),
                    );
                  },
                  showDivider: true,
                ),
                SettingsListItem(
                  icon: Icons.backup_rounded,
                  title: 'Disaster recovery',
                  subtitle: 'Configuration backups, checkpoints, and restore plans',
                  trailing: isAdmin
                      ? null
                      : SettingsStatusChip(
                          label: 'Admin only',
                          color: tokens.textSecondary,
                          background: tokens.surfaceCard,
                        ),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => RecoveryDashboardPage(
                        isAdmin: isAdmin,
                        repository: CloudRecoveryRepository(effectiveClient),
                      ),
                    ),
                  ),
                  showDivider: false,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // ── Edge, Protocol & Presence Telemetry ─────────────────────
          const SettingsSectionTitle('Edge Telemetry & Transports'),
          SettingsSurface(
            child: Column(
              children: [
                SettingsListItem(
                  icon: Icons.memory_rounded,
                  title: 'Edge control dashboard',
                  subtitle: 'Local-first LAN control with zero cloud latency',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => EdgeExecutionDashboardPage(
                        homeId: effectiveHomeId,
                        edgeService: EdgeControlService(baseUrl: effectiveClient.baseUrl),
                      ),
                    ),
                  ),
                  showDivider: true,
                ),
                SettingsListItem(
                  icon: Icons.hub_outlined,
                  title: 'Multi-protocol connectivity',
                  subtitle: 'BLE, MQTT, Local HTTP, and fallback transports',
                  onTap: () {
                    final targetDev = homeController?.devices.firstOrNull;
                    final connSvc = ConnectivityService(baseUrl: effectiveClient.baseUrl);
                    if (effectiveClient.getAccessToken != null) {
                      effectiveClient.getAccessToken!().then((t) {
                        if (t != null) connSvc.updateToken(t);
                      });
                    }
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => DeviceConnectivityPage(
                          deviceId: targetDev?.id ?? homeController?.activeDeviceId ?? '',
                          deviceName: targetDev?.name ?? 'EH Smart Switch',
                          connectivityService: connSvc,
                        ),
                      ),
                    );
                  },
                  showDivider: true,
                ),
                SettingsListItem(
                  icon: Icons.person_pin_circle_outlined,
                  title: 'Presence & occupancy',
                  subtitle: 'Real-time room occupancy and presence timeline',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => PresenceDashboardPage(
                        homeId: effectiveHomeId,
                        service: ContextPresenceService(
                          baseUrl: effectiveClient.baseUrl,
                          apiClient: effectiveClient,
                        ),
                      ),
                    ),
                  ),
                  showDivider: true,
                ),
                SettingsListItem(
                  icon: Icons.timeline_rounded,
                  title: 'Home context & modes',
                  subtitle: 'Set active home mode and view context transitions history',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => HomeContextPage(
                        homeId: effectiveHomeId,
                        service: ContextPresenceService(
                          baseUrl: effectiveClient.baseUrl,
                          apiClient: effectiveClient,
                        ),
                      ),
                    ),
                  ),
                  showDivider: true,
                ),
                SettingsListItem(
                  icon: Icons.eco_rounded,
                  title: 'Energy optimization engine',
                  subtitle: 'Automated shedding schedules & consumption thresholds',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => EnergyOptimizationPage(
                        homeId: effectiveHomeId,
                        service: EnergyAutomationService(baseUrl: effectiveClient.baseUrl),
                      ),
                    ),
                  ),
                  showDivider: true,
                ),
                SettingsListItem(
                  icon: Icons.price_change_outlined,
                  title: 'Tariff management & rates',
                  subtitle: 'Utility rate structures, peak hours, and billing rules',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => TariffManagementPage(
                        homeId: effectiveHomeId,
                        costService: EnergyCostService(
                          baseUrl: effectiveClient.baseUrl,
                          apiClient: effectiveClient,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
