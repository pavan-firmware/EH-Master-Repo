import 'package:flutter/material.dart';

import '../../../../core/repositories/help_repository.dart';
import '../../../diagnostics/presentation/device_health_page.dart';
import '../settings_ui.dart';
import 'support_request_page.dart';

class HelpArticlePage extends StatelessWidget {
  const HelpArticlePage({
    super.key,
    required this.articleId,
    this.repository = const PreviewHelpRepository(),
  });

  final String articleId;
  final HelpRepository repository;

  @override
  Widget build(BuildContext context) => FutureBuilder(
    future: repository.getArticle(articleId),
    builder: (context, snapshot) {
      final article = snapshot.data;
      if (article == null) {
        return NestedSettingsScaffold(
          title: 'Help',
          child: const Center(child: CircularProgressIndicator()),
        );
      }
      return NestedSettingsScaffold(
        title: article.title,
        subtitle: article.subtitle,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
          children: [
            const Text('Try these steps', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            SettingsSurface(
              child: Column(
                children: [
                  for (var i = 0; i < article.steps.length; i++)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${i + 1}.', style: const TextStyle(fontWeight: FontWeight.w800)),
                          const SizedBox(width: 8),
                          Expanded(child: Text(article.steps[i])),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            const Text('Still having trouble?', style: TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const DeviceHealthPage()),
                    ),
                    child: const Text('Check device health'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const SupportRequestPage()),
                    ),
                    child: const Text('Contact support'),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    },
  );
}
