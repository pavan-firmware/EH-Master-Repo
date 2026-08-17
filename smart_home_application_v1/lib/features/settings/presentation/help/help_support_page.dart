import 'package:flutter/material.dart';

import '../../../../core/models/help_models.dart';
import '../../../../core/repositories/help_repository.dart';
import '../../../../core/repositories/settings_repository.dart';
import '../../../connection/presentation/home_connection_page.dart';
import '../../../diagnostics/presentation/device_health_page.dart';
import '../../../updates/presentation/system_update_page.dart';
import '../add_room_device_page.dart';
import '../people_page.dart';
import '../settings_ui.dart';
import 'help_article_page.dart';
import 'help_search_page.dart';
import 'support_request_page.dart';

class HelpSupportPage extends StatefulWidget {
  const HelpSupportPage({
    super.key,
    this.initialTopic,
    this.repository = const PreviewHelpRepository(),
  });

  final String? initialTopic;
  final HelpRepository repository;

  @override
  State<HelpSupportPage> createState() => _HelpSupportPageState();
}

class _HelpSupportPageState extends State<HelpSupportPage> {
  late Future<_HelpData> _data;
  final _scrollController = ScrollController();
  final _troubleshootingKey = GlobalKey();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    setState(() {
      _data = Future.wait([
        widget.repository.getQuickHelp(),
        widget.repository.getGettingStarted(),
        widget.repository.getTroubleshooting(),
      ]).then(
        (results) => _HelpData(
          quick: results[0] as List<HelpQuickCard>,
          gettingStarted: results[1] as List<HelpArticle>,
          troubleshooting: results[2] as List<HelpArticle>,
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) => NestedSettingsScaffold(
    title: 'Help & support',
    subtitle: 'We\'re here to help you with EH Home.',
    actions: [settingsHelpAction(context)],
    child: FutureBuilder<_HelpData>(
      future: _data,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final data = snapshot.data!;
        return ListView(
          controller: _scrollController,
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
          children: [
            TextField(
              readOnly: true,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => HelpSearchPage(repository: widget.repository),
                ),
              ),
              decoration: InputDecoration(
                hintText: 'Search for help (e.g. device offline, Wi-Fi, routine)',
                prefixIcon: const Icon(Icons.search_rounded),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                const Expanded(
                  child: Text('Quick help', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                ),
                SettingsSectionLink(
                  label: 'View all',
                  onTap: () => _scrollToTroubleshooting(),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 184,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: data.quick.length,
                separatorBuilder: (_, _) => const SizedBox(width: 10),
                itemBuilder: (context, index) => _QuickHelpCard(
                  card: data.quick[index],
                  onTap: () => _openArticle(context, data.quick[index].articleId),
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Text('Getting started', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 10),
            SettingsSurface(
              child: Column(
                children: [
                  for (var i = 0; i < data.gettingStarted.length; i++)
                    _HelpListRow(
                      article: data.gettingStarted[i],
                      showDivider: i < data.gettingStarted.length - 1,
                      onTap: () => _handleArticleAction(context, data.gettingStarted[i]),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            KeyedSubtree(
              key: _troubleshootingKey,
              child: const Text('Troubleshooting', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            ),
            const SizedBox(height: 10),
            SettingsSurface(
              child: Column(
                children: [
                  for (var i = 0; i < data.troubleshooting.length; i++)
                    _HelpListRow(
                      article: data.troubleshooting[i],
                      showDivider: i < data.troubleshooting.length - 1,
                      onTap: () => _openArticle(context, data.troubleshooting[i].id),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            SettingsSupportBanner(
              title: 'Still need help?',
              subtitle: 'Contact our support team and we\'ll get back to you.',
              actionLabel: 'Contact support',
              onAction: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SupportRequestPage()),
              ),
            ),
          ],
        );
      },
    ),
  );

  void _scrollToTroubleshooting() {
    final target = _troubleshootingKey.currentContext;
    if (target == null) return;
    Scrollable.ensureVisible(
      target,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOut,
      alignment: 0.05,
    );
  }

  void _openArticle(BuildContext context, String id) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => HelpArticlePage(articleId: id, repository: widget.repository),
      ),
    );
  }

  void _handleArticleAction(BuildContext context, HelpArticle article) async {
    switch (article.actionRoute) {
      case 'connect':
        Navigator.push(context, MaterialPageRoute(builder: (_) => const HomeConnectionPage()));
      case 'add-device':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => AddRoomDevicePage(repository: const PreviewSettingsRepository()),
          ),
        );
      case 'health':
        Navigator.push(context, MaterialPageRoute(builder: (_) => const DeviceHealthPage()));
      case 'update':
        Navigator.push(context, MaterialPageRoute(builder: (_) => const SystemUpdatePage()));
      case 'people':
        final home = await const PreviewSettingsRepository().getHome();
        if (!context.mounted) return;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PeoplePage(repository: const PreviewSettingsRepository(), home: home),
          ),
        );
      default:
        _openArticle(context, article.id);
    }
  }
}

class _HelpData {
  const _HelpData({
    required this.quick,
    required this.gettingStarted,
    required this.troubleshooting,
  });

  final List<HelpQuickCard> quick;
  final List<HelpArticle> gettingStarted;
  final List<HelpArticle> troubleshooting;
}

class _QuickHelpCard extends StatelessWidget {
  const _QuickHelpCard({required this.card, required this.onTap});
  final HelpQuickCard card;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 160,
    child: Material(
      color: Color(card.backgroundColor),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SettingsIconBadge(
                icon: _icon(card.icon),
                color: Color(card.iconColor),
                background: Colors.white,
                size: 40,
              ),
              const SizedBox(height: 10),
              Text(
                card.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
              ),
              const SizedBox(height: 4),
              Expanded(
                child: Text(
                  card.subtitle,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: SettingsColors.muted, fontSize: 12),
                ),
              ),
              const Align(
                alignment: Alignment.bottomRight,
                child: Icon(Icons.chevron_right_rounded, color: SettingsColors.muted),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  IconData _icon(String key) => switch (key) {
        'bluetooth' => Icons.bluetooth_rounded,
        'wifi' => Icons.wifi_rounded,
        'device' => Icons.devices_rounded,
        'add' => Icons.add_rounded,
        _ => Icons.help_outline_rounded,
      };
}

class _HelpListRow extends StatelessWidget {
  const _HelpListRow({
    required this.article,
    required this.onTap,
    this.showDivider = false,
  });

  final HelpArticle article;
  final VoidCallback onTap;
  final bool showDivider;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      SettingsListItem(
        icon: Icons.article_outlined,
        title: article.title,
        subtitle: article.subtitle,
        onTap: onTap,
      ),
      if (showDivider)
        const Padding(
          padding: EdgeInsets.only(left: 76),
          child: Divider(height: 1, color: SettingsColors.line),
        ),
    ],
  );
}
