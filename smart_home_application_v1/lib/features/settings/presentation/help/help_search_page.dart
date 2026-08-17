import 'package:flutter/material.dart';

import '../../../../core/models/help_models.dart';
import '../../../../core/repositories/help_repository.dart';
import '../settings_ui.dart';
import 'help_article_page.dart';

class HelpSearchPage extends StatefulWidget {
  const HelpSearchPage({super.key, this.repository = const PreviewHelpRepository()});

  final HelpRepository repository;

  @override
  State<HelpSearchPage> createState() => _HelpSearchPageState();
}

class _HelpSearchPageState extends State<HelpSearchPage> {
  final _controller = TextEditingController();
  List<HelpArticle> _results = [];
  bool _searched = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _search(String query) async {
    final results = await widget.repository.search(query);
    if (mounted) {
      setState(() {
        _results = results;
        _searched = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) => NestedSettingsScaffold(
    title: 'Search help',
    child: Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
          child: TextField(
            controller: _controller,
            autofocus: true,
            onSubmitted: _search,
            decoration: InputDecoration(
              hintText: 'What can we help with?',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: IconButton(
                icon: const Icon(Icons.search_rounded),
                onPressed: () => _search(_controller.text),
              ),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
            children: [
              if (_searched && _results.isEmpty)
                const Text('No results found.', style: TextStyle(color: SettingsColors.muted))
              else
                SettingsSurface(
                  child: Column(
                    children: [
                      for (var i = 0; i < _results.length; i++)
                        SettingsListItem(
                          icon: Icons.article_outlined,
                          title: _results[i].title,
                          subtitle: _results[i].subtitle,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => HelpArticlePage(
                                articleId: _results[i].id,
                                repository: widget.repository,
                              ),
                            ),
                          ),
                          showDivider: i < _results.length - 1,
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    ),
  );
}
