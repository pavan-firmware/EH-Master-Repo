import '../models/help_models.dart';

abstract interface class HelpRepository {
  Future<List<HelpQuickCard>> getQuickHelp();
  Future<List<HelpArticle>> getGettingStarted();
  Future<List<HelpArticle>> getTroubleshooting();
  Future<List<HelpArticle>> search(String query);
  Future<HelpArticle?> getArticle(String id);
}

class PreviewHelpRepository implements HelpRepository {
  const PreviewHelpRepository();

  static final _articles = <HelpArticle>[
    const HelpArticle(
      id: 'bluetooth-connection',
      title: 'Bluetooth connection',
      subtitle: 'Can\'t find or connect device',
      category: HelpCategoryKind.quickHelp,
      keywords: ['bluetooth', 'connect', 'pair', 'nearby'],
      steps: [
        'Make sure Bluetooth is turned on.',
        'Keep your phone close to the powered-on device.',
        'Open Connect your home in Settings.',
        'Try Add a room device if the device is new.',
      ],
      actionRoute: 'connect',
      iconKey: 'bluetooth',
    ),
    const HelpArticle(
      id: 'wifi-connection',
      title: 'Wi-Fi connection',
      subtitle: 'Change or reconnect Wi-Fi',
      category: HelpCategoryKind.quickHelp,
      keywords: ['wifi', 'network', 'internet'],
      steps: [
        'Open Connect your home in Settings.',
        'Tap Change Wi-Fi network.',
        'Choose your home network and enter the password.',
        'Wait for the device to confirm connection.',
      ],
      actionRoute: 'connect',
      iconKey: 'wifi',
    ),
    const HelpArticle(
      id: 'device-offline',
      title: 'Device offline',
      subtitle: 'Fix offline or unreachable devices',
      category: HelpCategoryKind.quickHelp,
      keywords: ['offline', 'unreachable', 'disconnected'],
      steps: [
        'Make sure the device is powered on.',
        'Check that your home is connected.',
        'Open Device health and review the device status.',
        'Restart the device if needed.',
      ],
      actionRoute: 'health',
      iconKey: 'device',
    ),
    const HelpArticle(
      id: 'add-device',
      title: 'Add a device',
      subtitle: 'Set up a new EH Home device',
      category: HelpCategoryKind.quickHelp,
      keywords: ['add', 'setup', 'new device'],
      steps: [
        'Power on your EH Home device.',
        'Open Settings → Add a room device.',
        'Follow the nearby setup steps.',
      ],
      actionRoute: 'add-device',
      iconKey: 'add',
    ),
    const HelpArticle(
      id: 'connect-home',
      title: 'Connect your home',
      subtitle: 'Set up EH Home and your network',
      category: HelpCategoryKind.gettingStarted,
      keywords: ['connect', 'home', 'setup'],
      steps: [
        'Open Settings → Connect your home.',
        'Allow Bluetooth when prompted.',
        'Select your device and connect to Wi-Fi.',
      ],
      actionRoute: 'connect',
      iconKey: 'home',
    ),
    const HelpArticle(
      id: 'first-device',
      title: 'Add your first device',
      subtitle: 'Step-by-step guide to add a device',
      category: HelpCategoryKind.gettingStarted,
      keywords: ['first', 'device'],
      steps: [
        'Open Settings → Add a room device.',
        'Select the nearby device.',
        'Complete secure verification and Wi-Fi setup.',
      ],
      actionRoute: 'add-device',
    ),
    const HelpArticle(
      id: 'create-room',
      title: 'Create a room',
      subtitle: 'Organize your devices by room',
      category: HelpCategoryKind.gettingStarted,
      keywords: ['room', 'organize'],
      steps: [
        'Open the Rooms tab.',
        'Review existing rooms or add a new one when supported.',
        'Assign devices to the correct room during setup.',
      ],
      actionRoute: 'rooms',
    ),
    const HelpArticle(
      id: 'create-routine',
      title: 'Create a routine',
      subtitle: 'Make your home smarter with routines',
      category: HelpCategoryKind.gettingStarted,
      keywords: ['routine', 'automation'],
      steps: [
        'Open the Routines tab.',
        'Tap Create routine.',
        'Choose a trigger, conditions, and actions.',
      ],
      actionRoute: 'routines',
    ),
    const HelpArticle(
      id: 'invite-someone',
      title: 'Invite someone',
      subtitle: 'Share access to your home',
      category: HelpCategoryKind.gettingStarted,
      keywords: ['invite', 'member', 'share'],
      steps: [
        'Open Settings → People at home.',
        'Tap Invite someone.',
        'Send the invitation from your home owner account.',
      ],
      actionRoute: 'people',
    ),
    const HelpArticle(
      id: 'device-not-responding',
      title: 'Device not responding',
      subtitle: 'Try these steps to revive your device',
      category: HelpCategoryKind.troubleshooting,
      keywords: ['not responding', 'stuck'],
      steps: [
        'Check power and network connection.',
        'Review Device health for the latest status.',
        'Power-cycle the device and wait 30 seconds.',
      ],
      actionRoute: 'health',
    ),
    const HelpArticle(
      id: 'sensor-unavailable',
      title: 'Sensor data unavailable',
      subtitle: 'Why your sensor data might be missing',
      category: HelpCategoryKind.troubleshooting,
      keywords: ['sensor', 'data', 'missing'],
      steps: [
        'Confirm the sensor device is online.',
        'Check for weak signal in Device health.',
        'Wait a few minutes for fresh telemetry.',
      ],
      actionRoute: 'health',
    ),
    const HelpArticle(
      id: 'update-failed',
      title: 'Update failed',
      subtitle: 'Fix firmware or system update issues',
      category: HelpCategoryKind.troubleshooting,
      keywords: ['update', 'firmware', 'failed'],
      steps: [
        'Open System update in Settings.',
        'Check that the device is online and powered.',
        'Retry the update when your home is idle.',
      ],
      actionRoute: 'update',
    ),
    const HelpArticle(
      id: 'routine-failed',
      title: 'Routine didn\'t run',
      subtitle: 'Why your routine might not have executed',
      category: HelpCategoryKind.troubleshooting,
      keywords: ['routine', 'failed', 'automation'],
      steps: [
        'Check that the routine is enabled.',
        'Confirm required devices are online.',
        'Review Activity for the latest routine result.',
      ],
      actionRoute: 'routines',
    ),
    const HelpArticle(
      id: 'safety-alerts',
      title: 'Safety alerts',
      subtitle: 'Learn about safety and alert notifications',
      category: HelpCategoryKind.troubleshooting,
      keywords: ['safety', 'alert', 'notification'],
      steps: [
        'Safety alerts appear when supported sensors report issues.',
        'Review alerts in Activity and on the Home dashboard.',
        'Follow the in-app guidance for each alert type.',
      ],
      actionRoute: 'safety',
    ),
  ];

  static const _quickCards = [
    HelpQuickCard(
      articleId: 'bluetooth-connection',
      title: 'Bluetooth connection',
      subtitle: 'Can\'t find or connect device',
      icon: 'bluetooth',
      iconColor: 0xFF155CC8,
      backgroundColor: 0xFFEAF1FF,
    ),
    HelpQuickCard(
      articleId: 'wifi-connection',
      title: 'Wi-Fi connection',
      subtitle: 'Change or reconnect Wi-Fi',
      icon: 'wifi',
      iconColor: 0xFFE87A15,
      backgroundColor: 0xFFFFF4E5,
    ),
    HelpQuickCard(
      articleId: 'device-offline',
      title: 'Device offline',
      subtitle: 'Fix offline or unreachable devices',
      icon: 'device',
      iconColor: 0xFF09944A,
      backgroundColor: 0xFFE9F7EE,
    ),
    HelpQuickCard(
      articleId: 'add-device',
      title: 'Add a device',
      subtitle: 'Set up a new EH Home device',
      icon: 'add',
      iconColor: 0xFF7A3DD5,
      backgroundColor: 0xFFF3ECFF,
    ),
  ];

  @override
  Future<List<HelpQuickCard>> getQuickHelp() async => _quickCards;

  @override
  Future<List<HelpArticle>> getGettingStarted() async =>
      _articles.where((a) => a.category == HelpCategoryKind.gettingStarted).toList();

  @override
  Future<List<HelpArticle>> getTroubleshooting() async =>
      _articles.where((a) => a.category == HelpCategoryKind.troubleshooting).toList();

  @override
  Future<List<HelpArticle>> search(String query) async {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return [];
    return _articles
        .where(
          (a) =>
              a.title.toLowerCase().contains(q) ||
              a.subtitle.toLowerCase().contains(q) ||
              a.keywords.any((k) => k.contains(q)),
        )
        .toList();
  }

  @override
  Future<HelpArticle?> getArticle(String id) async {
    for (final article in _articles) {
      if (article.id == id) return article;
    }
    return null;
  }
}
