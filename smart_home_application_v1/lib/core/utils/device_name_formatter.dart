/// Formats device names for consumer operational UI vs detailed info.
///
/// Strips redundant brand prefixes like "EH " in normal operating UI,
/// while preserving full branding in detail/settings screens.
String formatOperatingName(String fullName) {
  var name = fullName.trim();
  if (name.startsWith('EH ')) {
    name = name.substring(3).trim();
  }
  return name.isNotEmpty ? name : 'Smart Switch 3X';
}

/// Returns formatted channel name (e.g. "Switch 1", "Switch 2", "Switch 3")
String formatSwitchChannelName(String baseName, int channelIndex) {
  return 'Switch $channelIndex';
}
