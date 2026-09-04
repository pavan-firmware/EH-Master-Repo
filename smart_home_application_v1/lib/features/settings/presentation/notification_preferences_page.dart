import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/services/device_storage_service.dart';
import '../../../core/theme/app_theme.dart';
import 'settings_ui.dart';

/// Consumer settings page for configuring and persisting notification preferences.
class NotificationPreferencesPage extends StatefulWidget {
  const NotificationPreferencesPage({super.key, this.storageService});

  final DeviceStorageService? storageService;

  @override
  State<NotificationPreferencesPage> createState() =>
      _NotificationPreferencesPageState();
}

class _NotificationPreferencesPageState
    extends State<NotificationPreferencesPage> {
  late final DeviceStorageService _storage;
  bool _pushEnabled = true;
  bool _criticalAlerts = true;
  bool _deviceOffline = true;
  bool _deviceHealth = true;
  bool _automationFailure = true;
  bool _firmwareUpdates = true;
  bool _energyAlerts = true;
  bool _matterAlerts = true;
  bool _securityAlerts = true;
  bool _quietHoursEnabled = false;
  String _quietHoursStart = '22:00';
  String _quietHoursEnd = '07:00';
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _storage = widget.storageService ?? DeviceStorageService();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final prefs = await _storage.loadNotificationPrefs();
    final sp = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _pushEnabled = prefs['pushEnabled'] ?? true;
        _criticalAlerts = prefs['criticalAlerts'] ?? true;
        _deviceOffline = prefs['deviceOffline'] ?? true;
        _deviceHealth = prefs['deviceHealth'] ?? true;
        _automationFailure = prefs['automationFailure'] ?? true;
        _firmwareUpdates = prefs['firmwareUpdates'] ?? true;
        _energyAlerts = prefs['energyAlerts'] ?? true;
        _matterAlerts = prefs['matterAlerts'] ?? true;
        _securityAlerts = prefs['securityAlerts'] ?? true;
        _quietHoursEnabled = prefs['quietHoursEnabled'] ?? false;
        _quietHoursStart = sp.getString('eh_quiet_hours_start') ?? '22:00';
        _quietHoursEnd = sp.getString('eh_quiet_hours_end') ?? '07:00';
        _loaded = true;
      });
    }
  }

  Future<void> _updatePref(String key, dynamic value) async {
    setState(() {
      switch (key) {
        case 'pushEnabled':
          _pushEnabled = value as bool;
          break;
        case 'criticalAlerts':
          _criticalAlerts = value as bool;
          break;
        case 'deviceOffline':
          _deviceOffline = value as bool;
          break;
        case 'deviceHealth':
          _deviceHealth = value as bool;
          break;
        case 'automationFailure':
          _automationFailure = value as bool;
          break;
        case 'firmwareUpdates':
          _firmwareUpdates = value as bool;
          break;
        case 'energyAlerts':
          _energyAlerts = value as bool;
          break;
        case 'matterAlerts':
          _matterAlerts = value as bool;
          break;
        case 'securityAlerts':
          _securityAlerts = value as bool;
          break;
        case 'quietHoursEnabled':
          _quietHoursEnabled = value as bool;
          break;
        case 'quietHoursStart':
          _quietHoursStart = value as String;
          break;
        case 'quietHoursEnd':
          _quietHoursEnd = value as String;
          break;
      }
    });

    final boolMap = <String, bool>{
      'pushEnabled': _pushEnabled,
      'criticalAlerts': _criticalAlerts,
      'deviceOffline': _deviceOffline,
      'deviceHealth': _deviceHealth,
      'automationFailure': _automationFailure,
      'firmwareUpdates': _firmwareUpdates,
      'energyAlerts': _energyAlerts,
      'matterAlerts': _matterAlerts,
      'securityAlerts': _securityAlerts,
      'quietHoursEnabled': _quietHoursEnabled,
    };
    await _storage.saveNotificationPrefs(boolMap);
    final sp = await SharedPreferences.getInstance();
    await sp.setString('eh_quiet_hours_start', _quietHoursStart);
    await sp.setString('eh_quiet_hours_end', _quietHoursEnd);
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.ehColors;

    return NestedSettingsScaffold(
      title: 'Notifications',
      subtitle: 'Choose what alerts and updates you receive.',
      child: !_loaded
          ? Center(
              child: CircularProgressIndicator(color: tokens.bluePrimary),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              children: [
                // Master Push Toggle
                const SettingsSectionTitle('PUSH ALERTS'),
                SettingsSurface(
                  child: SwitchListTile(
                    activeTrackColor: tokens.bluePrimary,
                    title: Text(
                      'Push Notifications',
                      style: TextStyle(
                        color: tokens.textPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                    subtitle: Text(
                      'Receive instant push updates on your device',
                      style: TextStyle(
                        color: tokens.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                    value: _pushEnabled,
                    onChanged: (val) => _updatePref('pushEnabled', val),
                  ),
                ),
                const SizedBox(height: 16),
                const SettingsSectionTitle('ALERT CATEGORIES'),
                SettingsSurface(
                  child: Column(
                    children: [
                      SwitchListTile(
                        activeTrackColor: tokens.bluePrimary,
                        title: Text(
                          'Critical safety alerts',
                          style: TextStyle(
                            color: tokens.textPrimary,
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                        ),
                        subtitle: Text(
                          'Hazard sensor triggers, power safety trips, and emergency notifications.',
                          style: TextStyle(
                            color: tokens.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                        value: _criticalAlerts,
                        onChanged: _pushEnabled
                            ? (val) => _updatePref('criticalAlerts', val)
                            : null,
                      ),
                      const Divider(height: 1),
                      SwitchListTile(
                        activeTrackColor: tokens.bluePrimary,
                        title: Text(
                          'Device offline alerts',
                          style: TextStyle(
                            color: tokens.textPrimary,
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                        ),
                        subtitle: Text(
                          'Notify when a home switch or sensor disconnects or loses power.',
                          style: TextStyle(
                            color: tokens.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                        value: _deviceOffline,
                        onChanged: _pushEnabled
                            ? (val) => _updatePref('deviceOffline', val)
                            : null,
                      ),
                      const Divider(height: 1),
                      SwitchListTile(
                        activeTrackColor: tokens.bluePrimary,
                        title: Text(
                          'Device health & self-healing',
                          style: TextStyle(
                            color: tokens.textPrimary,
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                        ),
                        subtitle: Text(
                          'Notify when proactive self-healing or recovery events occur.',
                          style: TextStyle(
                            color: tokens.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                        value: _deviceHealth,
                        onChanged: _pushEnabled
                            ? (val) => _updatePref('deviceHealth', val)
                            : null,
                      ),
                      const Divider(height: 1),
                      SwitchListTile(
                        activeTrackColor: tokens.bluePrimary,
                        title: Text(
                          'Automation & routine failures',
                          style: TextStyle(
                            color: tokens.textPrimary,
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                        ),
                        subtitle: Text(
                          'Notify if a scheduled scene or automation rule fails to execute.',
                          style: TextStyle(
                            color: tokens.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                        value: _automationFailure,
                        onChanged: _pushEnabled
                            ? (val) => _updatePref('automationFailure', val)
                            : null,
                      ),
                      const Divider(height: 1),
                      SwitchListTile(
                        activeTrackColor: tokens.bluePrimary,
                        title: Text(
                          'Firmware & system updates',
                          style: TextStyle(
                            color: tokens.textPrimary,
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                        ),
                        subtitle: Text(
                          'Notify when new security and firmware releases are ready.',
                          style: TextStyle(
                            color: tokens.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                        value: _firmwareUpdates,
                        onChanged: _pushEnabled
                            ? (val) => _updatePref('firmwareUpdates', val)
                            : null,
                      ),
                      const Divider(height: 1),
                      SwitchListTile(
                        activeTrackColor: tokens.bluePrimary,
                        title: Text(
                          'Energy alerts & budgets',
                          style: TextStyle(
                            color: tokens.textPrimary,
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                        ),
                        subtitle: Text(
                          'Notify when power thresholds or monthly budgets are exceeded.',
                          style: TextStyle(
                            color: tokens.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                        value: _energyAlerts,
                        onChanged: _pushEnabled
                            ? (val) => _updatePref('energyAlerts', val)
                            : null,
                      ),
                      const Divider(height: 1),
                      SwitchListTile(
                        activeTrackColor: tokens.bluePrimary,
                        title: Text(
                          'Matter ecosystem integrations',
                          style: TextStyle(
                            color: tokens.textPrimary,
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                        ),
                        subtitle: Text(
                          'Notify when Apple Home, Google Home, or Alexa platform bridges disconnect.',
                          style: TextStyle(
                            color: tokens.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                        value: _matterAlerts,
                        onChanged: _pushEnabled
                            ? (val) => _updatePref('matterAlerts', val)
                            : null,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                // Quiet Hours Card
                const SettingsSectionTitle('QUIET HOURS'),
                SettingsSurface(
                  child: SwitchListTile(
                    activeTrackColor: tokens.bluePrimary,
                    title: Text(
                      'Enable quiet hours',
                      style: TextStyle(
                        color: tokens.textPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                    subtitle: Text(
                      'Defer non-critical notifications from $_quietHoursStart to $_quietHoursEnd. Critical safety alerts will always come through.',
                      style: TextStyle(
                        color: tokens.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                    value: _quietHoursEnabled,
                    onChanged: (val) => _updatePref('quietHoursEnabled', val),
                  ),
                ),
              ],
            ),
    );
  }
}
