import 'package:flutter/material.dart';

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
  bool _automationFailure = true;
  bool _firmwareUpdates = true;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _storage = widget.storageService ?? DeviceStorageService();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final prefs = await _storage.loadNotificationPrefs();
    if (mounted) {
      setState(() {
        _pushEnabled = prefs['pushEnabled'] ?? true;
        _criticalAlerts = prefs['criticalAlerts'] ?? true;
        _deviceOffline = prefs['deviceOffline'] ?? true;
        _automationFailure = prefs['automationFailure'] ?? true;
        _firmwareUpdates = prefs['firmwareUpdates'] ?? true;
        _loaded = true;
      });
    }
  }

  Future<void> _updatePref(String key, bool value) async {
    setState(() {
      switch (key) {
        case 'pushEnabled':
          _pushEnabled = value;
          break;
        case 'criticalAlerts':
          _criticalAlerts = value;
          break;
        case 'deviceOffline':
          _deviceOffline = value;
          break;
        case 'automationFailure':
          _automationFailure = value;
          break;
        case 'firmwareUpdates':
          _firmwareUpdates = value;
          break;
      }
    });

    await _storage.saveNotificationPrefs({
      'pushEnabled': _pushEnabled,
      'criticalAlerts': _criticalAlerts,
      'deviceOffline': _deviceOffline,
      'automationFailure': _automationFailure,
      'firmwareUpdates': _firmwareUpdates,
    });
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
                const SettingsSectionTitle('PUSH ALERTS'),
                SettingsSurface(
                  child: Column(
                    children: [
                      SwitchListTile(
                        activeTrackColor: tokens.bluePrimary,
                        title: Text(
                          'Allow push notifications',
                          style: TextStyle(
                            color: tokens.textPrimary,
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                        subtitle: Text(
                          'Receive real-time alerts about your home on this device.',
                          style: TextStyle(
                            color: tokens.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                        value: _pushEnabled,
                        onChanged: (val) => _updatePref('pushEnabled', val),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
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
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}
