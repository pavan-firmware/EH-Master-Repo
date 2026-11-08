class EventClassification {
  const EventClassification._();

  /// Returns true if an event or alert represents a routine everyday control operation
  /// (such as standard ON/OFF toggling) that should not create notifications or flood
  /// the notification center.
  ///
  /// Alert-worthy events (including per-control opt-in alerts with "Alert") return false.
  static bool isRoutineControlOperation({
    required String title,
    String? message,
  }) {
    final lowerTitle = title.toLowerCase();
    final lowerMsg = (message ?? '').toLowerCase();

    // If it's an explicit channel alert (from per-control opt-in "Alert"), it is alert-worthy.
    if (lowerTitle.contains('alert') || lowerMsg.contains('alert')) {
      return false;
    }

    // Check for standard ON/OFF toggle patterns
    if (lowerTitle.contains('turned on') || lowerTitle.contains('turned off')) {
      return true;
    }

    if (lowerTitle.startsWith('controlled ') ||
        lowerTitle.contains('switched on') ||
        lowerTitle.contains('switched off')) {
      return true;
    }

    return false;
  }
}

