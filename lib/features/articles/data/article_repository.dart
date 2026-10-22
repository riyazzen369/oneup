import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/env.dart';
import '../../assess/domain/assessment_controller.dart';
import '../../assess/domain/focus.dart';
import '../../../core/theme/app_colors.dart';
import '../domain/article.dart';

/// Bundled snapshot always available offline; when Supabase is configured the
/// read-only `articles` table is pulled and, if it returns valid rows, used instead.
class ArticleRepository {
  static const asset = 'assets/content/articles.json';

  Future<ArticleFeed> bundled() async => ArticleFeed.fromJson(jsonDecode(await rootBundle.loadString(asset)));

  Future<ArticleFeed> load() async {
    final local = await bundled();
    if (!Env.isConfigured) return local;
    try {
      final rows = await Supabase.instance.client
          .from('articles')
          .select('id,dimension,title,source,date_display,published_on,url,summary,type')
          .eq('is_active', true)
          .order('published_on', ascending: false)
          .limit(60)
          .timeout(const Duration(seconds: 8));
      final live = ArticleFeed.fromJson(rows, live: true);
      return live.articles.isEmpty ? local : live;
    } catch (_) {
      return local;
    }
  }
}

final articleRepositoryProvider = Provider((ref) => ArticleRepository());
final articlesProvider = FutureProvider<ArticleFeed>((ref) => ref.read(articleRepositoryProvider).load());

/// Focus dimensions for "For you" (same ranking as OneUp Focus).
final focusDimensionsProvider = Provider<List<WellnessDimension>>((ref) {
  final s = ref.watch(assessmentProvider);
  return rankFocus(s.latest, s.goals, top: 3).map((f) => f.dimension).toList();
});
