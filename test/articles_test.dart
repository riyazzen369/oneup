import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:oneup/core/theme/app_colors.dart';
import 'package:oneup/features/articles/domain/article.dart';

void main() {
  final bundled = jsonDecode(File('assets/content/articles.json').readAsStringSync());

  test('bundled JSON parses fully and covers all 8 dimensions with 2–3 each', () {
    final feed = ArticleFeed.fromJson(bundled);
    expect(feed.fetchedAt, isNotNull);
    expect(feed.articles.length, (bundled['articles'] as List).length);
    for (final d in WellnessDimension.values) {
      final n = feed.articles.where((a) => a.dimension == d).length;
      expect(n, inInclusiveRange(2, 3), reason: d.name);
    }
    for (final a in feed.articles) {
      expect(a.url, startsWith('https://'));
      expect(a.summary, isNotEmpty);
      expect(a.source, isNotEmpty);
      expect(a.dateDisplay, isNotEmpty);
    }
  });

  test('invalid rows dropped; duplicates removed; newest first', () {
    final feed = ArticleFeed.fromJson([
      {'dimension': 'social', 'title': 'Old', 'url': 'https://a.org/1', 'date': '2024-01-01'},
      {'dimension': 'social', 'title': 'New', 'url': 'https://a.org/2', 'date': '2025-06-01'},
      {'dimension': 'social', 'title': 'Dup', 'url': 'https://a.org/2', 'date': '2025-06-02'},
      {'dimension': 'nope', 'title': 'Bad dim', 'url': 'https://a.org/3'},
      {'dimension': 'social', 'title': 'Insecure', 'url': 'http://a.org/4'},
      {'dimension': 'social', 'title': '', 'url': 'https://a.org/5'},
      {'dimension': 'social', 'title': 'js', 'url': 'javascript:alert(1)'},
      'garbage',
    ], live: true);
    expect(feed.articles.map((a) => a.title), ['New', 'Old']);
    expect(feed.live, isTrue);
    expect(feed.articles.first.source, 'a.org'); // host fallback
  });

  test('supabase row shape (published_on) parses', () {
    final a = Article.tryParse({
      'id': 'x',
      'dimension': 'financial',
      'title': 'T',
      'url': 'https://x.org',
      'published_on': '2025-05-12',
      'date_display': 'May 12, 2025'
    });
    expect(a!.date, DateTime(2025, 5, 12));
    expect(a.dateDisplay, 'May 12, 2025');
  });

  group('filtering', () {
    final all = ArticleFeed.fromJson(bundled).articles;
    test('All returns everything', () => expect(filterArticles(all, const AllArticles()).length, all.length));
    test('By dimension', () {
      final r = filterArticles(all, const ByDimension(WellnessDimension.spiritual));
      expect(r, isNotEmpty);
      expect(r.every((a) => a.dimension == WellnessDimension.spiritual), isTrue);
    });
    test('For you follows focus order, falls back to all when no focus', () {
      final r = filterArticles(all, const ForYou(), focus: [WellnessDimension.financial, WellnessDimension.social]);
      expect(r.map((a) => a.dimension).toSet(), {WellnessDimension.financial, WellnessDimension.social});
      final firstSocial = r.indexWhere((a) => a.dimension == WellnessDimension.social);
      expect(r.take(firstSocial).every((a) => a.dimension == WellnessDimension.financial), isTrue);
      expect(filterArticles(all, const ForYou()).length, all.length);
    });
  });
}
