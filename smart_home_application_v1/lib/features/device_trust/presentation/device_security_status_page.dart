import 'package:flutter/material.dart';
import '../../../core/models/device_trust_models.dart';
import '../../../core/repositories/device_trust_repository.dart';

class DeviceSecurityStatusPage extends StatefulWidget {
  const DeviceSecurityStatusPage({
    super.key,
    required this.repository,
    required this.deviceId,
    this.deviceName = 'Device Security',
    this.isAdmin = false,
  });

  final DeviceTrustRepository repository;
  final String deviceId;
  final String deviceName;
  final bool isAdmin;

  @override
  State<DeviceSecurityStatusPage> createState() => _DeviceSecurityStatusPageState();
}

class _DeviceSecurityStatusPageState extends State<DeviceSecurityStatusPage> {
  DeviceTrustStateModel? _trustState;
  DeviceSecurityHistoryModel? _history;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadSecurityData();
  }

  Future<void> _loadSecurityData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final trust = await widget.repository.getTrustState(widget.deviceId);
      final history = await widget.repository.getSecurityHistory(widget.deviceId);
      setState(() {
        _trustState = trust;
        _history = history;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  Color _getStateColor(TrustState state) {
    switch (state) {
      case TrustState.trusted:
        return Colors.green;
      case TrustState.commissioned:
      case TrustState.provisioned:
        return Colors.blue;
      case TrustState.degraded:
        return Colors.orange;
      case TrustState.quarantined:
        return Colors.amber.shade900;
      case TrustState.revoked:
      case TrustState.decommissioned:
        return Colors.red.shade800;
      case TrustState.factoryReset:
        return Colors.purple;
    }
  }

  IconData _getStateIcon(TrustState state) {
    switch (state) {
      case TrustState.trusted:
        return Icons.verified_user_rounded;
      case TrustState.degraded:
        return Icons.gpp_maybe_rounded;
      case TrustState.quarantined:
        return Icons.shield_rounded;
      case TrustState.revoked:
      case TrustState.decommissioned:
        return Icons.gpp_bad_rounded;
      case TrustState.factoryReset:
        return Icons.restart_alt_rounded;
      case TrustState.provisioned:
      case TrustState.commissioned:
        return Icons.security_rounded;
    }
  }

  Future<void> _handleRotateCredentials() async {
    try {
      final gen = (_history?.lifecycleRecords.length ?? 0) + 1;
      final rot = await widget.repository.initiateRotation(
        widget.deviceId,
        keyIdentifier: 'eh_key_${widget.deviceId.substring(0, 8)}_gen$gen',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Rotation initiated: Generation ${rot.rotationGeneration} pending confirmation')),
        );
      }
      await _loadSecurityData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Rotation error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _handleQuarantine() async {
    try {
      await widget.repository.quarantineDevice(
        widget.deviceId,
        reason: 'Quarantined by user request',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Device has been moved to Quarantine')),
        );
      }
      await _loadSecurityData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Quarantine error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _handleRestoreTrust() async {
    try {
      await widget.repository.restoreTrust(
        widget.deviceId,
        reason: 'Authorized remediation completed by user',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Device trust successfully restored')),
        );
      }
      await _loadSecurityData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Restore error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.deviceName),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadSecurityData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, size: 48, color: Colors.red),
                      const SizedBox(height: 12),
                      Text('Error loading security state: $_errorMessage'),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadSecurityData,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadSecurityData,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _buildTrustHeaderCard(),
                      const SizedBox(height: 16),
                      _buildActionButtons(),
                      const SizedBox(height: 20),
                      _buildCredentialLifecycleSection(),
                      const SizedBox(height: 20),
                      _buildRevocationSection(),
                    ],
                  ),
                ),
    );
  }

  Widget _buildTrustHeaderCard() {
    final trust = _trustState;
    if (trust == null) return const SizedBox.shrink();

    final stateColor = _getStateColor(trust.trustState);
    final stateIcon = _getStateIcon(trust.trustState);

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: stateColor.withValues(alpha: 0.15),
                  child: Icon(stateIcon, size: 34, color: stateColor),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        trust.trustState.toDisplayString(),
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: stateColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Device ID: ${trust.deviceId.substring(0, 13)}...',
                        style: const TextStyle(fontSize: 13, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: stateColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: stateColor.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    '${trust.trustScore.toStringAsFixed(1)}% Trust',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: stateColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            LinearProgressIndicator(
              value: trust.trustScore / 100.0,
              backgroundColor: Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation<Color>(stateColor),
              minHeight: 8,
              borderRadius: BorderRadius.circular(4),
            ),
            if (trust.quarantinedAt != null) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, size: 16, color: Colors.amber),
                  const SizedBox(width: 6),
                  Text(
                    'Quarantined on: ${trust.quarantinedAt!.toLocal()}',
                    style: const TextStyle(fontSize: 12, color: Colors.amber),
                  ),
                ],
              ),
            ],
            if (trust.revokedAt != null) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(Icons.cancel_outlined, size: 16, color: Colors.red),
                  const SizedBox(width: 6),
                  Text(
                    'Revoked on: ${trust.revokedAt!.toLocal()}',
                    style: const TextStyle(fontSize: 12, color: Colors.red),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    final trust = _trustState;
    if (trust == null) return const SizedBox.shrink();

    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            icon: const Icon(Icons.sync_lock_rounded, size: 18),
            label: const Text('Rotate Keys'),
            onPressed: _handleRotateCredentials,
          ),
        ),
        const SizedBox(width: 12),
        if (trust.trustState == TrustState.quarantined || trust.trustState == TrustState.revoked)
          Expanded(
            child: ElevatedButton.icon(
              icon: const Icon(Icons.restore_rounded, size: 18),
              label: const Text('Restore Trust'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade700),
              onPressed: _handleRestoreTrust,
            ),
          )
        else
          Expanded(
            child: OutlinedButton.icon(
              icon: const Icon(Icons.shield_outlined, size: 18),
              label: const Text('Quarantine'),
              style: OutlinedButton.styleFrom(foregroundColor: Colors.amber.shade900),
              onPressed: _handleQuarantine,
            ),
          ),
      ],
    );
  }

  Widget _buildCredentialLifecycleSection() {
    final records = _history?.lifecycleRecords ?? [];

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.history_rounded, size: 20),
                const SizedBox(width: 8),
                const Text(
                  'Credential Lifecycle Ledger',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                Text(
                  '${records.length} records',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
            const Divider(height: 24),
            if (records.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'No credential rotations recorded yet. Initial hardware factory credentials are active.',
                  style: TextStyle(fontSize: 13, color: Colors.grey),
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: records.length,
                separatorBuilder: (_, _) => const Divider(height: 16),
                itemBuilder: (context, index) {
                  final rec = records[index];
                  return Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.blue.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Gen ${rec.rotationGeneration}',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.blue),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              rec.keyIdentifier,
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                            ),
                            Text(
                              'Type: ${rec.credentialType.toApiString()} • Issued: ${rec.issuedAt.toLocal()}',
                              style: const TextStyle(fontSize: 11, color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                      Chip(
                        label: Text(
                          rec.status.toApiString(),
                          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                        visualDensity: VisualDensity.compact,
                        backgroundColor: rec.status == CredentialLifecycleStatus.confirmed
                            ? Colors.green.withValues(alpha: 0.15)
                            : Colors.orange.withValues(alpha: 0.15),
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

  Widget _buildRevocationSection() {
    final revocations = _history?.revocations ?? [];

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.security_update_warning_rounded, size: 20),
                const SizedBox(width: 8),
                const Text(
                  'Revocation & Audit Log',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                Text(
                  '${revocations.length} records',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
            const Divider(height: 24),
            if (revocations.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'No security revocations recorded.',
                  style: TextStyle(fontSize: 13, color: Colors.grey),
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: revocations.length,
                separatorBuilder: (_, _) => const Divider(height: 16),
                itemBuilder: (context, index) {
                  final rev = revocations[index];
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            rev.revocationType,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.red),
                          ),
                          const Spacer(),
                          Text(
                            rev.createdAt.toLocal().toString().substring(0, 16),
                            style: const TextStyle(fontSize: 11, color: Colors.grey),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        rev.reason,
                        style: const TextStyle(fontSize: 12),
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
