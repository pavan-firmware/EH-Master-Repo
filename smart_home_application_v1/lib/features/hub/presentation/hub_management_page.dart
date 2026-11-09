import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../settings/presentation/settings_ui.dart';
import '../data/hub_repository.dart';
import '../domain/models/hub_models.dart';

class HubManagementPage extends StatefulWidget {
  const HubManagementPage({
    super.key,
    this.homeId = 'home_01',
    this.repository,
  });

  final String homeId;
  final HubRepository? repository;

  @override
  State<HubManagementPage> createState() => _HubManagementPageState();
}

class _HubManagementPageState extends State<HubManagementPage> {
  late final HubRepository _repo;
  late Future<HubState> _stateFuture;
  bool _isAdopting = false;
  double _adoptionProgress = 0.0;
  String _adoptionStatusText = '';

  @override
  void initState() {
    super.initState();
    _repo = widget.repository ?? LiveHubRepository();
    _stateFuture = _repo.getHubState(homeId: widget.homeId);
  }

  void _reload() {
    setState(() {
      _stateFuture = _repo.getHubState(homeId: widget.homeId);
    });
  }

  Future<void> _startZeroTouchAdoption(String hostname) async {
    setState(() {
      _isAdopting = true;
      _adoptionProgress = 0.1;
      _adoptionStatusText = 'Broadcasting UDP EH_DISCOVER on port 4210...';
    });

    await Future.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;
    setState(() {
      _adoptionProgress = 0.45;
      _adoptionStatusText = 'Exchanging HMAC-SHA256 tokens with switches...';
    });

    await Future.delayed(const Duration(milliseconds: 700));
    if (!mounted) return;
    setState(() {
      _adoptionProgress = 0.85;
      _adoptionStatusText = 'Performing non-disruptive read-only state sync...';
    });

    await _repo.linkHub(hubHostname: hostname, homeId: widget.homeId);
    await _repo.adoptDiscoveredSwitches(
      hubHostname: hostname,
      switchIds: ['sw_living_room_01', 'sw_kitchen_02', 'sw_motor_03'],
    );

    if (!mounted) return;
    setState(() {
      _adoptionProgress = 1.0;
      _adoptionStatusText = 'Adoption complete! Sub-5ms mesh active.';
      _isAdopting = false;
    });
    _reload();
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
          'Smart Home Hub',
          style: TextStyle(
            color: tokens.textPrimary,
            fontWeight: FontWeight.w800,
            fontSize: 20,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh_rounded, color: tokens.headerAction),
            tooltip: 'Refresh Status',
            onPressed: _reload,
          ),
        ],
      ),
      body: FutureBuilder<HubState>(
        future: _stateFuture,
        builder: (context, snapshot) {
          if (_isAdopting) {
            return _buildAdoptionProgressView(tokens);
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator.adaptive());
          }

          final state = snapshot.data ?? const HubState(status: HubConnectionStatus.notConfigured);

          if (!state.isLinked) {
            return _buildUnlinkedSetupView(context, tokens, state);
          }

          return _buildHubActiveDashboard(context, tokens, state);
        },
      ),
    );
  }

  Widget _buildAdoptionProgressView(EHThemeTokens tokens) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: tokens.iconBgBlue,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.hub_rounded, color: tokens.bluePrimary, size: 36),
            ),
            const SizedBox(height: 24),
            Text(
              'Zero-Touch Device Adoption',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: tokens.textPrimary,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              _adoptionStatusText,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: tokens.textSecondary, height: 1.4),
            ),
            const SizedBox(height: 24),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: _adoptionProgress,
                minHeight: 8,
                backgroundColor: tokens.borderSubtle,
                valueColor: AlwaysStoppedAnimation<Color>(tokens.bluePrimary),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.shield_outlined, color: tokens.success, size: 16),
                const SizedBox(width: 6),
                Text(
                  'Zero relay toggling • Flash wear protected',
                  style: TextStyle(color: tokens.textSecondary, fontSize: 12),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUnlinkedSetupView(
    BuildContext context,
    EHThemeTokens tokens,
    HubState state,
  ) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 32),
      children: [
        Container(
          padding: const EdgeInsets.all(20),
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
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: tokens.iconBgBlue,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.hub_rounded, color: tokens.bluePrimary, size: 26),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Optional Smart Hub',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: tokens.textPrimary,
                          ),
                        ),
                        Text(
                          'Local brain & accelerator for your home',
                          style: TextStyle(fontSize: 13, color: tokens.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 14),
              _buildFeatureRow(tokens, Icons.bolt_rounded, 'Sub-5ms Execution', 'Multi-room automations execute instantly over LAN.'),
              const SizedBox(height: 10),
              _buildFeatureRow(tokens, Icons.wifi_off_rounded, '100% Offline Autonomy', 'Routines fire on time even if internet fiber is disconnected.'),
              const SizedBox(height: 10),
              _buildFeatureRow(tokens, Icons.memory_rounded, 'Flash Memory Preservation', 'Comfort routines live on Hub SQLite, saving switch flash cycles.'),
              const SizedBox(height: 10),
              _buildFeatureRow(tokens, Icons.touch_app_rounded, 'Zero-Touch Adoption', 'No resetting switches or re-entering Wi-Fi credentials.'),
            ],
          ),
        ),
        const SizedBox(height: 20),
        const SettingsSectionTitle('Discovered on Local Network'),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: tokens.surfaceCard,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: tokens.bluePrimary.withValues(alpha: 0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.radar_rounded, color: tokens.bluePrimary, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'EH Smart Hub Ready to Pair',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: tokens.textPrimary,
                      fontSize: 15,
                    ),
                  ),
                  const Spacer(),
                  SettingsStatusChip(
                    label: 'LAN Ready',
                    color: tokens.success,
                    background: tokens.successContainer,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                'Platform: ${state.model}',
                style: TextStyle(fontSize: 13, color: tokens.textSecondary),
              ),
              Text(
                'Hostname: ${state.hostname}  •  IP: ${state.ipAddress}',
                style: TextStyle(fontSize: 13, color: tokens.textSecondary),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => _startZeroTouchAdoption(state.hostname),
                  icon: const Icon(Icons.link_rounded),
                  label: const Text('Link Hub to My Home'),
                  style: FilledButton.styleFrom(
                    backgroundColor: tokens.bluePrimary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHubActiveDashboard(
    BuildContext context,
    EHThemeTokens tokens,
    HubState state,
  ) {
    final devices = state.connectedDevices;

    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 32),
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: tokens.surfaceCard,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: tokens.success.withValues(alpha: 0.4)),
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
                      color: tokens.successContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.hub_rounded, color: tokens.success, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Local Hub Active',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: tokens.textPrimary,
                          ),
                        ),
                        Text(
                          '${state.hostname} • Sub-5ms Subnet Mesh',
                          style: TextStyle(fontSize: 13, color: tokens.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  SettingsStatusChip(
                    label: '${state.latencyMs}ms Direct',
                    color: tokens.success,
                    background: tokens.successContainer,
                    leading: Icon(Icons.bolt_rounded, size: 14, color: tokens.success),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 14),
              Row(
                children: [
                  _buildMetricTile(tokens, 'Devices', '${devices.length} Active', Icons.devices_rounded),
                  const SizedBox(width: 12),
                  _buildMetricTile(tokens, 'Routines', '${state.standardRoutinesCount + state.criticalRoutinesCount} Rules', Icons.schedule_rounded),
                  const SizedBox(width: 12),
                  _buildMetricTile(tokens, 'SD Health', 'Read-Only OK', Icons.security_rounded),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        SettingsSectionTitle('Coordinated Devices (${devices.length})'),
        SettingsSurface(
          child: Column(
            children: [
              for (int i = 0; i < devices.length; i++) ...[
                if (i > 0) const Divider(height: 1, indent: 56),
                _buildDeviceTile(tokens, devices[i]),
              ],
            ],
          ),
        ),
        const SizedBox(height: 20),
        const SettingsSectionTitle('Hub Operations & Maintenance'),
        SettingsSurface(
          child: Column(
            children: [
              SettingsListItem(
                icon: Icons.sync_rounded,
                title: 'Sync Automations',
                subtitle: 'Re-sync standard and critical schedules with switch NVS',
                onTap: () async {
                  await _repo.syncAutomations(hubHostname: state.hostname);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Automations synchronized with Local Hub.')),
                    );
                  }
                },
              ),
              const Divider(height: 1, indent: 56),
              SettingsListItem(
                icon: Icons.restart_alt_rounded,
                title: 'Restart Hub Core',
                subtitle: 'Restarts local MQTT and scheduler daemon safely',
                onTap: () async {
                  await _repo.restartHubCore(hubHostname: state.hostname);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Hub daemon restarted cleanly.')),
                    );
                  }
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMetricTile(EHThemeTokens tokens, String label, String value, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
        decoration: BoxDecoration(
          color: tokens.surfaceElevated,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: tokens.borderSubtle),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 16, color: tokens.textSecondary),
            const SizedBox(height: 6),
            Text(value, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: tokens.textPrimary)),
            Text(label, style: TextStyle(fontSize: 11, color: tokens.textSecondary)),
          ],
        ),
      ),
    );
  }

  Widget _buildDeviceTile(EHThemeTokens tokens, HubDeviceInfo device) {
    return ListTile(
      leading: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: tokens.iconBgBlue,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(Icons.toggle_on_outlined, color: tokens.bluePrimary, size: 22),
      ),
      title: Text(
        device.name,
        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: tokens.textPrimary),
      ),
      subtitle: Text(
        '${device.roomName} • ${device.ipAddress} • ${device.latencyMs}ms',
        style: TextStyle(fontSize: 12, color: tokens.textSecondary),
      ),
      trailing: device.hasCriticalHardwareFallback
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: tokens.warningContainer,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                'Critical NVS',
                style: TextStyle(color: tokens.warning, fontSize: 11, fontWeight: FontWeight.w700),
              ),
            )
          : Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: tokens.iconBgBlue,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                'Hub Coordinated',
                style: TextStyle(color: tokens.bluePrimary, fontSize: 11, fontWeight: FontWeight.w600),
              ),
            ),
    );
  }

  Widget _buildFeatureRow(
    EHThemeTokens tokens,
    IconData icon,
    String title,
    String description,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: tokens.bluePrimary),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: tokens.textPrimary,
                ),
              ),
              Text(
                description,
                style: TextStyle(
                  fontSize: 12,
                  color: tokens.textSecondary,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
