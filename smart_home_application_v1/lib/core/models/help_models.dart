enum HelpCategoryKind {
  quickHelp,
  gettingStarted,
  troubleshooting,
}

class HelpArticle {
  const HelpArticle({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.category,
    required this.steps,
    this.keywords = const [],
    this.relatedArticleIds = const [],
    this.actionRoute,
    this.iconKey,
    this.iconColor,
    this.backgroundColor,
  });

  final String id;
  final String title;
  final String subtitle;
  final HelpCategoryKind category;
  final List<String> steps;
  final List<String> keywords;
  final List<String> relatedArticleIds;
  final String? actionRoute;
  final String? iconKey;
  final int? iconColor;
  final int? backgroundColor;
}

class HelpQuickCard {
  const HelpQuickCard({
    required this.articleId,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.iconColor,
    required this.backgroundColor,
  });

  final String articleId;
  final String title;
  final String subtitle;
  final String icon;
  final int iconColor;
  final int backgroundColor;
}
