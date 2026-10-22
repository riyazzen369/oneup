import '../../../core/theme/app_colors.dart';

/// External article reference. Summary is paraphrased from the linked page only.
class Article {
  const Article({
    required this.id,
    required this.dimension,
    required this.title,
    required this.source,
    required this.dateDisplay,
    required this.date,
    required this.url,
    required this.summary,
    this.type = 'news',
  });

  final String id, title, source, dateDisplay, url, summary, type;
  final WellnessDimension dimension;
  final DateTime? date;

  /// Returns null for invalid rows (unknown dimension, missing fields, non-https URL)
  /// so a bad remote row can never crash the feed.
  static Article? tryParse(Map<String, dynamic> m) {
    final dimName = m['dimension'];
    final dim = WellnessDimension.values.where((d) => d.name == dimName).firstOrNull;
    final title = (m['title'] as String?)?.trim() ?? '';
    final url = (m['url'] as String?)?.trim() ?? '';
    final uri = Uri.tryParse(url);
    if (dim == null || title.isEmpty || uri == null || uri.scheme != 'https' || uri.host.isEmpty) return null;
    final rawDate = (m['date'] ?? m['published_on'])?.toString();
    return Article(
      id: (m['id'] ?? url).toString(),
      dimension: dim,
      title: title,
      source: (m['source'] as String?)?.trim() ?? uri.host,
      dateDisplay: (m['date_display'] as String?)?.trim() ?? rawDate ?? '',
      date: rawDate == null ? null : DateTime.tryParse(rawDate),
      url: url,
      summary: (m['summary'] as String?)?.trim() ?? '',
      type: (m['type'] as String?) ?? 'news',
    );
  }
}

class ArticleFeed {
  const ArticleFeed(this.articles, {this.fetchedAt, this.live = false});
  final List<Article> articles;
  final String? fetchedAt;
  final bool live;

  /// Parses the bundled JSON shape `{fetched_at, articles: [...]}` or a bare list.
  /// Drops invalid rows and duplicate URLs; newest first.
  factory ArticleFeed.fromJson(Object? json, {bool live = false}) {
    final list = json is Map ? json['articles'] : json;
    final seen = <String>{};
    final out = <Article>[];
    if (list is List) {
      for (final r in list) {
        if (r is! Map) continue;
        final a = Article.tryParse(Map<String, dynamic>.from(r));
        if (a != null && seen.add(a.url)) out.add(a);
      }
    }
    out.sort((a, b) => (b.date ?? DateTime(1970)).compareTo(a.date ?? DateTime(1970)));
    return ArticleFeed(out, fetchedAt: json is Map ? json['fetched_at']?.toString() : null, live: live);
  }
}

/// Filter: null = All; [forYou] = focus dimensions (falls back to all when none).
sealed class ArticleFilter {
  const ArticleFilter();
}

class AllArticles extends ArticleFilter {
  const AllArticles();
}

class ForYou extends ArticleFilter {
  const ForYou();
}

class ByDimension extends ArticleFilter {
  const ByDimension(this.dimension);
  final WellnessDimension dimension;
  @override
  bool operator ==(Object other) => other is ByDimension && other.dimension == dimension;
  @override
  int get hashCode => dimension.hashCode;
}

List<Article> filterArticles(List<Article> all, ArticleFilter f, {List<WellnessDimension> focus = const []}) {
  switch (f) {
    case AllArticles():
      return all;
    case ByDimension(:final dimension):
      return all.where((a) => a.dimension == dimension).toList();
    case ForYou():
      if (focus.isEmpty) return all;
      final rank = {for (var i = 0; i < focus.length; i++) focus[i]: i};
      final picked = all.where((a) => rank.containsKey(a.dimension)).toList();
      // stable: focus order first, then newest within a dimension
      picked.sort((a, b) {
        final r = rank[a.dimension]!.compareTo(rank[b.dimension]!);
        return r != 0 ? r : (b.date ?? DateTime(1970)).compareTo(a.date ?? DateTime(1970));
      });
      return picked;
  }
}
