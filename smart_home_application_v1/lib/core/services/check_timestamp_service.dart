import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Authoritative persistent storage and relative time formatting service
/// for Device Health and System Update check operations.
class CheckTimestampService {
  CheckTimestampService({
    this.preferences,
    this.nowProvider,
  });

  final SharedPreferences? preferences;
  final DateTime Function()? nowProvider;
  SharedPreferences? _cachedPrefs;

  /// Current reference time (defaults to DateTime.now()).
  DateTime get now => nowProvider != null ? nowProvider!() : DateTime.now();

  /// SharedPreferences storage key for Device Health last successful check timestamp.
  static const String deviceHealthKey = 'device_health_last_check';

  /// SharedPreferences storage key for System Update last successful check timestamp.
  static const String systemUpdateKey = 'system_update_last_check';

  static CheckTimestampService? _instance;

  /// Shared singleton instance.
  static CheckTimestampService get instance => _instance ??= CheckTimestampService();

  /// Testing hook to set or reset the singleton instance.
  @visibleForTesting
  static void setMockInstance(CheckTimestampService? mock) {
    _instance = mock;
  }

  /// Resolves the SharedPreferences instance (cached or injected).
  Future<SharedPreferences> _getPrefs() async {
    if (_cachedPrefs != null) return _cachedPrefs!;
    if (preferences != null) {
      _cachedPrefs = preferences;
      return _cachedPrefs!;
    }
    _cachedPrefs = await SharedPreferences.getInstance();
    return _cachedPrefs!;
  }

  /// Retrieves the last recorded successful check timestamp converted to the device's
  /// local timezone. Returns `null` if no check has been recorded or if the stored value is invalid.
  Future<DateTime?> getLastSuccessfulCheck(String key) async {
    final prefs = await _getPrefs();
    final raw = prefs.getString(key);
    if (raw == null || raw.trim().isEmpty) return null;
    final parsed = DateTime.tryParse(raw.trim());
    if (parsed == null) return null;
    return parsed.toLocal();
  }

  /// Persists the completion timestamp of a confirmed successful check operation.
  /// The timestamp is stored as a UTC ISO-8601 string to maintain timezone neutrality.
  Future<void> recordSuccessfulCheck(String key, DateTime timestamp) async {
    final prefs = await _getPrefs();
    final utcIso = timestamp.toUtc().toIso8601String();
    await prefs.setString(key, utcIso);
  }

  /// Clears the recorded timestamp for the given key (useful for resets and test isolation).
  Future<void> clearLastCheck(String key) async {
    final prefs = await _getPrefs();
    await prefs.remove(key);
  }

  /// Formats a timestamp into an authoritative human-readable relative or calendar time string.
  ///
  /// Formatting Rules:
  /// - `null`: returns `'Never'`
  /// - Future clock skew (<= 60s) or elapsed < 45s: returns `'Just now'`
  /// - 45s <= elapsed < 60m: returns `'${minutes}m ago'` (where minutes is clamped to >= 1 to prevent '0m ago')
  /// - Elapsed >= 60m on the same calendar day: returns `'Today, h:mm a'` (e.g. `'Today, 9:40 AM'`)
  /// - Occurred yesterday (calendar day): returns `'Yesterday, h:mm a'`
  /// - Occurred earlier this year: returns `'MMM d, h:mm a'` (e.g. `'Aug 15, 9:40 AM'`)
  /// - Occurred in a previous year: returns `'MMM d, yyyy, h:mm a'` (e.g. `'Aug 15, 2025, 9:40 AM'`)
  ///
  /// The optional `now` parameter allows deterministic unit testing without wall-clock dependencies.
  String formatRelativeTime(DateTime? timestamp, {DateTime? now}) {
    if (timestamp == null) return 'Never';

    final reference = (now ?? this.now).toLocal();
    final localDt = timestamp.toLocal();
    final diff = reference.difference(localDt);

    // Negative difference (future skew) or strictly less than 45 seconds elapsed
    if (diff.isNegative || diff.inSeconds < 45) {
      return 'Just now';
    }

    // Between 45 seconds and 59 minutes: format as 'Xm ago'
    // Duration.inMinutes uses integer division; for 45s..59s inMinutes is 0. Clamp to 1.
    if (diff.inMinutes < 60) {
      final minutes = diff.inMinutes == 0 ? 1 : diff.inMinutes;
      return '${minutes}m ago';
    }

    // 12-hour clock format components
    final hour = localDt.hour > 12
        ? localDt.hour - 12
        : (localDt.hour == 0 ? 12 : localDt.hour);
    final ampm = localDt.hour >= 12 ? 'PM' : 'AM';
    final min = localDt.minute.toString().padLeft(2, '0');
    final timeOfDay = '$hour:$min $ampm';

    // Calendar day comparison: Same calendar day (Today)
    if (localDt.year == reference.year &&
        localDt.month == reference.month &&
        localDt.day == reference.day) {
      return 'Today, $timeOfDay';
    }

    // Calendar day comparison: Yesterday
    final yesterday = DateTime(reference.year, reference.month, reference.day - 1);
    if (localDt.year == yesterday.year &&
        localDt.month == yesterday.month &&
        localDt.day == yesterday.day) {
      return 'Yesterday, $timeOfDay';
    }

    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final month = months[localDt.month - 1];

    // Same year
    if (localDt.year == reference.year) {
      return '$month ${localDt.day}, $timeOfDay';
    }

    // Different year
    return '$month ${localDt.day}, ${localDt.year}, $timeOfDay';
  }

  /// Convenience formatter for Device Health hero card: `"Last checked: <relative>"`
  String formatDeviceHealthChecked(DateTime? timestamp, {DateTime? now}) {
    return 'Last checked: ${formatRelativeTime(timestamp, now: now)}';
  }

  /// Convenience formatter for System Update header: `"Checked: <relative>"`
  String formatSystemUpdateChecked(DateTime? timestamp, {DateTime? now}) {
    return 'Checked: ${formatRelativeTime(timestamp, now: now)}';
  }
}
