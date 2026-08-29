/// Time-aware greeting utility for EH Home application.
///
/// Returns daypart-aware greeting prefixes according to the canonical daypart schedule:
/// - 05:00 - 11:59 -> "Good morning, "
/// - 12:00 - 16:59 -> "Good afternoon, "
/// - 17:00 - 20:59 -> "Good evening, "
/// - 21:00 - 04:59 -> "Good night, "
String getTimeAwareGreeting([DateTime? now]) {
  final current = now ?? DateTime.now();
  final totalMinutes = current.hour * 60 + current.minute;

  if (totalMinutes >= 5 * 60 && totalMinutes < 12 * 60) {
    return 'Good morning, ';
  } else if (totalMinutes >= 12 * 60 && totalMinutes < 17 * 60) {
    return 'Good afternoon, ';
  } else if (totalMinutes >= 17 * 60 && totalMinutes < 21 * 60) {
    return 'Good evening, ';
  } else {
    return 'Good night, ';
  }
}
