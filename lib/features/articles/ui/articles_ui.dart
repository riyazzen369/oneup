import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/services/haptics.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/fx.dart';
import '../data/article_repository.dart';
import '../domain/article.dart';

const externalLabel = "External content — OneUp doesn't endorse; not medical advice";

class _FilterNotifier extends StateNotifier<ArticleFilter> {
  _FilterNotifier() : super(const ForYou());
  void set(ArticleFilter f) => state = f;
}

final homeArticleFilterProvider = StateNotifierProvider<_FilterNotifier, ArticleFilter>((ref) => _FilterNotifier());
final allArticleFilterProvider = StateNotifierProvider.autoDispose<_FilterNotifier, ArticleFilter>((ref) => _FilterNotifier());

List<Article> _visible(WidgetRef ref, ArticleFeed feed, ArticleFilter f) =>
    filterArticles(feed.articles, f, focus: ref.watch(focusDimensionsProvider));

/// Home section: heading + filter chips + horizontal carousel.
class ArticlesSection extends ConsumerWidget {
  const ArticlesSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context);
    final feed = ref.watch(articlesProvider).valueOrNull;
    final f = ref.watch(homeArticleFilterProvider);
    final items = feed == null ? const <Article>[] : _visible(ref, feed, f);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Expanded(child: Text('Updates & Articles', style: t.textTheme.titleMedium)),
        TextButton(onPressed: Haptics.tap(() => context.push('/articles')), child: const Text('See all')),
      ]),
      ArticleFilterChips(selected: f, onChanged: ref.read(homeArticleFilterProvider.notifier).set),
      const SizedBox(height: 10),
      SizedBox(
        height: 188,
        child: feed == null
            ? const Center(child: CircularProgressIndicator())
            : AnimatedSwitcher(
                duration: motion(context, const Duration(milliseconds: 250)),
                child: items.isEmpty
                    ? Center(key: const ValueKey('empty'), child: Text('No articles for this filter yet.', style: t.textTheme.bodySmall))
                    : ListView.separated(
                        key: ValueKey(f.hashCode ^ items.length),
                        scrollDirection: Axis.horizontal,
                        clipBehavior: Clip.none,
                        itemCount: items.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 12),
                        itemBuilder: (_, i) => StaggerIn(
                          index: i.clamp(0, 6),
                          child: SizedBox(width: 260, child: ArticleCard(article: items[i])),
                        ),
                      ),
              ),
      ),
      const SizedBox(height: 6),
      Text(externalLabel, style: t.textTheme.labelSmall?.copyWith(color: t.colorScheme.onSurfaceVariant)),
    ]);
  }
}

class ArticleFilterChips extends StatelessWidget {
  const ArticleFilterChips({super.key, required this.selected, required this.onChanged, this.includeAll = false});
  final ArticleFilter selected;
  final ValueChanged<ArticleFilter> onChanged;
  final bool includeAll;

  @override
  Widget build(BuildContext context) {
    final f = selected;
    void set(ArticleFilter v) => onChanged(v);
    final b = Theme.of(context).brightness;
    Widget chip(String label, ArticleFilter v, {Color? color, IconData? icon}) => Padding(
          padding: const EdgeInsets.only(right: 8),
          child: ChoiceChip(
            avatar: icon == null ? null : Icon(icon, size: 16, color: color),
            label: Text(label),
            selected: f == v,
            onSelected: Haptics.pick((_) => set(v)),
          ),
        );
    return SizedBox(
      height: 40,
      child: ListView(scrollDirection: Axis.horizontal, children: [
        chip('For you', const ForYou(), icon: Icons.auto_awesome_rounded),
        if (includeAll) chip('All', const AllArticles()),
        for (final d in WellnessDimension.values) chip(d.label, ByDimension(d), color: d.color(b), icon: d.icon),
      ]),
    );
  }
}

class ArticleCard extends StatelessWidget {
  const ArticleCard({super.key, required this.article, this.expanded = false});
  final Article article;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final c = article.dimension.color(t.brightness);
    return PressScale(
      semanticLabel: '${article.title}, ${article.source}',
      onTap: Haptics.tap(() => showArticleSheet(context, article)),
      child: GlassCard(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Row(children: [
            Flexible(child: DimensionChip(article.dimension)),
            const SizedBox(width: 8),
            const Spacer(),
            Text(article.dateDisplay, style: t.textTheme.labelSmall),
          ]),
          const SizedBox(height: 10),
          Text(article.title,
              maxLines: expanded ? 4 : 3,
              overflow: TextOverflow.ellipsis,
              style: t.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700, height: 1.25)),
          if (expanded) ...[
            const SizedBox(height: 6),
            Text(article.summary, maxLines: 2, overflow: TextOverflow.ellipsis, style: t.textTheme.bodySmall),
          ],
          if (!expanded) const Spacer(),
          const SizedBox(height: 8),
          Row(children: [
            Icon(Icons.public_rounded, size: 14, color: c),
            const SizedBox(width: 6),
            Expanded(
              child: Text(article.source,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: t.textTheme.labelMedium?.copyWith(color: t.colorScheme.onSurfaceVariant)),
            ),
          ]),
        ]),
      ),
    );
  }
}

class DimensionChip extends StatelessWidget {
  const DimensionChip(this.d, {super.key});
  final WellnessDimension d;
  @override
  Widget build(BuildContext context) {
    final c = d.color(Theme.of(context).brightness);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: c.withOpacity(0.15), borderRadius: BorderRadius.circular(99)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(d.icon, size: 12, color: c),
        const SizedBox(width: 4),
        Flexible(
            child: Text(d.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(color: c, fontWeight: FontWeight.w700))),
      ]),
    );
  }
}

Future<void> showArticleSheet(BuildContext context, Article a) => showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (c) {
        final t = Theme.of(c);
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [DimensionChip(a.dimension), const Spacer(), Text(a.dateDisplay, style: t.textTheme.labelMedium)]),
              const SizedBox(height: 12),
              Text(a.title, style: t.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              Text(a.source, style: t.textTheme.labelLarge?.copyWith(color: t.colorScheme.primary)),
              const SizedBox(height: 14),
              Text(a.summary, style: t.textTheme.bodyMedium),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: t.colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(12)),
                child: Row(children: [
                  Icon(Icons.info_outline_rounded, size: 18, color: t.colorScheme.onSurfaceVariant),
                  const SizedBox(width: 8),
                  Expanded(child: Text(externalLabel, style: t.textTheme.bodySmall)),
                ]),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  icon: const Icon(Icons.open_in_new_rounded),
                  label: const Text('Read at source'),
                  onPressed: () async {
                    Haptics.light();
                    final uri = Uri.parse(a.url);
                    var ok = false;
                    try {
                      ok = await launchUrl(uri, mode: LaunchMode.inAppBrowserView);
                    } catch (_) {}
                    if (!ok) {
                      try {
                        ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
                      } catch (_) {}
                    }
                    if (!ok) {
                      Haptics.error();
                      if (c.mounted) ScaffoldMessenger.of(c).showSnackBar(const SnackBar(content: Text('Could not open the link')));
                    }
                  },
                ),
              ),
            ]),
          ),
        );
      },
    );

/// "See all" full screen.
class ArticlesScreen extends ConsumerWidget {
  const ArticlesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context);
    final async = ref.watch(articlesProvider);
    final f = ref.watch(allArticleFilterProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Updates & Articles')),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (feed) {
          final items = _visible(ref, feed, f);
          return RefreshIndicator(
            onRefresh: () async {
              Haptics.medium();
              ref.invalidate(articlesProvider);
              await ref.read(articlesProvider.future);
            },
            child: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 32), children: [
              ArticleFilterChips(selected: f, onChanged: ref.read(allArticleFilterProvider.notifier).set, includeAll: true),
              const SizedBox(height: 8),
              Text(
                '$externalLabel. ${feed.live ? 'Live list' : 'Curated list, checked ${feed.fetchedAt ?? ''}'}.',
                style: t.textTheme.labelSmall?.copyWith(color: t.colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 12),
              if (items.isEmpty)
                Padding(
                    padding: const EdgeInsets.all(24),
                    child: Center(child: Text('No articles for this filter yet.', style: t.textTheme.bodySmall))),
              for (var i = 0; i < items.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: StaggerIn(index: i.clamp(0, 8), child: ArticleCard(article: items[i], expanded: true)),
                ),
            ]),
          );
        },
      ),
    );
  }
}
