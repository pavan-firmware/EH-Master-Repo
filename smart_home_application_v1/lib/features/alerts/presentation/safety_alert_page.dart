import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

class SafetyAlertPage extends StatelessWidget {
  const SafetyAlertPage({
    super.key,
    this.title = 'Safety alert notice',
    this.description = 'Your home system flagged an alert requiring your attention.',
    this.roomName,
    this.deviceName,
    this.spaceName,
    this.deviceId,
    this.timestamp,
    this.severity = 'warning',
    this.steps = const [
      'Check the physical appliance or switch to ensure safe operation.',
      'Verify Wi-Fi network and device power connections.',
      'Acknowledge alert to confirm status; monitoring remains active.',
    ],
    this.onDismiss,
  });

  final String title;
  final String description;
  final String? roomName;
  final String? deviceName;
  final String? spaceName;
  final String? deviceId;
  final DateTime? timestamp;
  final String severity;
  final List<String> steps;
  final VoidCallback? onDismiss;

  String _formatDateTime(DateTime dt) {
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    final minute = dt.minute.toString().padLeft(2, '0');
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year} • $hour:$minute $ampm';
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.ehColors;
    final isCritical = severity.toLowerCase() == 'critical';
    final isInfo = severity.toLowerCase() == 'info';

    final Color accentColor = isCritical
        ? const Color(0xFFEF4444)
        : (isInfo ? tokens.bluePrimary : const Color(0xFFF59E0B));

    final Color cardBg = tokens.surfaceCard;

    return Scaffold(
      backgroundColor: tokens.bgApp,
      appBar: AppBar(
        backgroundColor: tokens.bgApp,
        elevation: 0,
        title: Text(
          'Alert Details',
          style: TextStyle(
            color: tokens.textPrimary,
            fontSize: 17,
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: true,
        leading: IconButton(
          tooltip: 'Close',
          onPressed: () => Navigator.pop(context),
          icon: Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: tokens.textPrimary),
        ),
        actions: [
          if (onDismiss != null)
            TextButton.icon(
              onPressed: () {
                onDismiss?.call();
                Navigator.pop(context, true);
              },
              icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Colors.redAccent),
              label: const Text(
                'Clear',
                style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w700),
              ),
            ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Severity & Status Banner
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: tokens.isDark ? 0.16 : 0.08),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: accentColor.withValues(alpha: tokens.isDark ? 0.4 : 0.3),
                    width: 1.5,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: accentColor.withValues(alpha: 0.18),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isCritical
                            ? Icons.crisis_alert_rounded
                            : (isInfo ? Icons.info_rounded : Icons.warning_amber_rounded),
                        color: accentColor,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: accentColor.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              isCritical
                                  ? 'CRITICAL ALERT'
                                  : (isInfo ? 'ACTIVITY NOTICE' : 'SAFETY WARNING'),
                              style: TextStyle(
                                color: accentColor,
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            title,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: tokens.textPrimary,
                              height: 1.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 18),

              // 2. Alert Message Details
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: tokens.borderSubtle),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'EVENT DESCRIPTION',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: tokens.textSecondary,
                        letterSpacing: 0.6,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      description,
                      style: TextStyle(
                        fontSize: 15,
                        height: 1.45,
                        color: tokens.textPrimary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              // 3. Metadata context cards (Space, Room, Device, Timestamp)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: tokens.borderSubtle),
                ),
                child: Column(
                  children: [
                    _buildMetaRow(
                      tokens: tokens,
                      icon: Icons.home_outlined,
                      label: 'Space / Location',
                      value: spaceName ?? roomName ?? 'My Home',
                    ),
                    const Divider(height: 22),
                    _buildMetaRow(
                      tokens: tokens,
                      icon: Icons.meeting_room_outlined,
                      label: 'Assigned Room',
                      value: roomName ?? 'Living Room',
                    ),
                    if (deviceName != null || deviceId != null) ...[
                      const Divider(height: 22),
                      _buildMetaRow(
                        tokens: tokens,
                        icon: Icons.devices_other_rounded,
                        label: 'Device',
                        value: deviceName ?? (deviceId != null ? 'Device ID: ${deviceId!.substring(0, 8)}...' : 'Connected Switch'),
                      ),
                    ],
                    const Divider(height: 22),
                    _buildMetaRow(
                      tokens: tokens,
                      icon: Icons.access_time_rounded,
                      label: 'Triggered At',
                      value: timestamp != null ? _formatDateTime(timestamp!) : _formatDateTime(DateTime.now()),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 18),

              // 4. Recommended Action Steps
              Text(
                'RECOMMENDED ACTIONS',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: tokens.textSecondary,
                  letterSpacing: 0.6,
                ),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: tokens.borderSubtle),
                ),
                child: Column(
                  children: [
                    for (int i = 0; i < steps.length; i++)
                      _SafetyStep(
                        number: '${i + 1}',
                        text: steps[i],
                        numBg: accentColor.withValues(alpha: 0.15),
                        numColor: accentColor,
                      ),
                  ],
                ),
              ),

              const SizedBox(height: 28),

              // 5. Action Buttons: Dismiss & Clear / Acknowledge
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        onDismiss?.call();
                        Navigator.pop(context, true);
                      },
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: BorderSide(color: Colors.redAccent.withValues(alpha: 0.6)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 18),
                      label: const Text(
                        'Dismiss & Clear',
                        style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => Navigator.pop(context, true),
                      style: FilledButton.styleFrom(
                        backgroundColor: tokens.bluePrimary,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 1,
                      ),
                      icon: const Icon(Icons.check_circle_outline_rounded, color: Colors.white, size: 18),
                      label: const Text(
                        'Acknowledge',
                        style: TextStyle(fontWeight: FontWeight.w700, color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Center(
                child: Text(
                  'Acknowledging or clearing removes this alert while system monitoring stays active.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 11, color: tokens.textSecondary),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetaRow({
    required dynamic tokens,
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Icon(icon, size: 18, color: tokens.textSecondary),
        const SizedBox(width: 10),
        Text(
          label,
          style: TextStyle(fontSize: 13, color: tokens.textSecondary, fontWeight: FontWeight.w500),
        ),
        const Spacer(),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: tokens.textPrimary,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _SafetyStep extends StatelessWidget {
  const _SafetyStep({
    required this.number,
    required this.text,
    required this.numBg,
    required this.numColor,
  });
  final String number;
  final String text;
  final Color numBg;
  final Color numColor;

  @override
  Widget build(BuildContext context) {
    final tokens = context.ehColors;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: numBg, shape: BoxShape.circle),
            child: Text(
              number,
              style: TextStyle(color: numColor, fontWeight: FontWeight.w700, fontSize: 12),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 13.5,
                height: 1.35,
                color: tokens.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
