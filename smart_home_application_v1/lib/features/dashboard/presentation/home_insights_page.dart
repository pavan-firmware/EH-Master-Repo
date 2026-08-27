import 'package:flutter/material.dart';

import '../../../core/models/home_dashboard_models.dart';
import '../../../core/theme/app_theme.dart';

class HomeInsightsPage extends StatelessWidget {
  const HomeInsightsPage({super.key, required this.data});

  final HomeDashboardData data;

  @override
  Widget build(BuildContext context) {
    final tokens = context.ehColors;
    return Scaffold(
      backgroundColor: tokens.bgApp,
      appBar: AppBar(
        backgroundColor: tokens.bgApp,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: Icon(Icons.arrow_back_rounded, color: tokens.headerAction),
        ),
        title: Text(
          'Home insights',
          style: TextStyle(
            color: tokens.textPrimary,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _InsightRow(
            icon: Icons.devices_other_rounded,
            label: 'Devices',
            value: '${data.devicesOnline} of ${data.deviceCount} online',
          ),
          _InsightRow(
            icon: Icons.meeting_room_outlined,
            label: 'Rooms',
            value:
                '${data.roomCount} configured · ${data.activeRoomCount} active',
          ),
          _InsightRow(
            icon: Icons.wifi_rounded,
            label: data.networkLabel,
            value: data.networkDetail,
          ),
          _InsightRow(
            icon: Icons.shield_outlined,
            label: data.securityLabel,
            value: data.securityDetail,
          ),
          const SizedBox(height: 18),
          Text(
            data.source == DashboardDataSource.live
                ? 'Live device data'
                : 'Dashboard preview data',
            style: TextStyle(color: tokens.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _InsightRow extends StatelessWidget {
  const _InsightRow({
    required this.icon,
    required this.label,
    required this.value,
  });
  final IconData icon;
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) {
    final tokens = context.ehColors;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: ListTile(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: tokens.isDark
              ? BorderSide(color: tokens.borderSubtle)
              : BorderSide.none,
        ),
        tileColor: tokens.surfaceCard,
        leading: Icon(icon, color: tokens.bluePrimary),
        title: Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: tokens.textPrimary,
          ),
        ),
        subtitle: Text(value, style: TextStyle(color: tokens.textSecondary)),
      ),
    );
  }
}
