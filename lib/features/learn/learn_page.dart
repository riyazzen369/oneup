import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/services/haptics.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/fx.dart';
import '../articles/data/article_repository.dart' show focusDimensionsProvider;
import 'learn_models.dart';
import 'learn_repository.dart';

/// Learn tab: short, book-based lessons summarised in our own words.
class LearnPage extends ConsumerStatefulWidget {
  const LearnPage({super.key});
  @override
  ConsumerState<LearnPage> createState() => _LearnPageState();
}

class _LearnPageState extends ConsumerState<LearnPage> {
  WellnessDimension? _dim;
  String? _book;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final lib = ref.watch(learnLibraryProvider);
    final focus = ref.watch(focusDimensionsProvider);
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: MeshBackground(
        child: SafeArea(
          bottom: false,
          child: lib.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Lessons could not be loaded.', style: t.textTheme.bodyMedium)),
            data: (l) => _body(context, l, focus),
          ),
        ),
      ),
    );
  }

  Widget _body(BuildContext context, LearnLibrary lib, List<WellnessDimension> focus) {
    final t = Theme.of(context);
    final done = ref.watch(learnProgressProvider);
    final rec = lib.recommended(focus, done);
    final list = lib.filter(dim: _dim, bookId: _book);
    final prog = lib.progress(done);
    var i = 0;
    return CustomScrollView(slivers: [
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        sliver: SliverList(
          delegate: SliverChildListDelegate([
            StaggerIn(
              index: i++,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text('Learn', style: t.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800)),
              ),
            ),
            StaggerIn(
              index: i++,
              child: GlassCard(
                child: Row(children: [
                  const Icon(Icons.menu_book_rounded, size: 30, color: AppColors.secondary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Bite-size lessons inspired by well-known books, ${lib.lessons.length} in all. ${lib.disclaimer}',
                      style: t.textTheme.bodyMedium,
                    ),
                  ),
                ]),
              ),
            ),
            const SizedBox(height: 8),
            ListTile(
              key: const Key('learn-experts'),
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.verified_outlined),
              title: const Text('Reviewed by experts (SAMPLE)'),
              subtitle: const Text('Our advisory board and how lessons are made'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => context.push('/experts'),
            ),
            const SizedBox(height: 16),
            Text('Recommended for you', style: t.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            if (focus.isEmpty)
              Text('Complete an assessment and we will suggest lessons for your focus areas.', style: t.textTheme.bodySmall)
            else if (rec.isEmpty)
              Text('You have completed every lesson for your focus areas. Nice work.', style: t.textTheme.bodySmall)
            else
              SizedBox(
                height: 150,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: rec.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 10),
                  itemBuilder: (_, k) => SizedBox(width: 240, child: _RecCard(lesson: rec[k], book: lib.book(rec[k].bookId))),
                ),
              ),
            const SizedBox(height: 16),
            Text('Your progress', style: t.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            GlassCard(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
              child: Column(children: [
                for (final d in WellnessDimension.values)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(children: [
                      Icon(d.icon, size: 16, color: d.color(t.brightness)),
                      const SizedBox(width: 8),
                      SizedBox(width: 100, child: Text(d.label, style: t.textTheme.bodySmall)),
                      Expanded(
                        child: LinearProgressIndicator(
                          value: prog[d]!.$2 == 0 ? 0 : prog[d]!.$1 / prog[d]!.$2,
                          minHeight: 6,
                          borderRadius: BorderRadius.circular(3),
                          color: d.color(t.brightness),
                          backgroundColor: d.color(t.brightness).withOpacity(0.15),
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                          width: 34, child: Text('${prog[d]!.$1}/${prog[d]!.$2}', textAlign: TextAlign.end, style: t.textTheme.labelSmall)),
                    ]),
                  ),
              ]),
            ),
            const SizedBox(height: 16),
            Text('All lessons', style: t.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            _ChipRow(children: [
              _chip('All areas', _dim == null, () => setState(() => _dim = null)),
              for (final d in WellnessDimension.values)
                _chip(d.label, _dim == d, () => setState(() => _dim = _dim == d ? null : d), icon: d.icon),
            ]),
            _ChipRow(key: const Key('book-filters'), children: [
              _chip('All books', _book == null, () => setState(() => _book = null)),
              for (final b in lib.books) _chip(b.short, _book == b.id, () => setState(() => _book = _book == b.id ? null : b.id)),
            ]),
            const SizedBox(height: 6),
          ]),
        ),
      ),
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
        sliver: list.isEmpty
            ? SliverToBoxAdapter(child: Text('No lessons match these filters.', style: t.textTheme.bodyMedium))
            : SliverList.builder(
                itemCount: list.length,
                itemBuilder: (_, k) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _LessonTile(lesson: list[k], book: lib.book(list[k].bookId), done: done.contains(list[k].id)),
                ),
              ),
      ),
    ]);
  }

  Widget _chip(String label, bool sel, VoidCallback onTap, {IconData? icon}) => Padding(
        padding: const EdgeInsets.only(right: 8),
        child: FilterChip(
          label: Text(label),
          avatar: icon == null ? null : Icon(icon, size: 16),
          selected: sel,
          showCheckmark: false,
          onSelected: (_) {
            Haptics.selection();
            onTap();
          },
        ),
      );
}

class _ChipRow extends StatelessWidget {
  const _ChipRow({super.key, required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => SizedBox(
        height: 48,
        child: ListView(scrollDirection: Axis.horizontal, children: children),
      );
}

class _DimTags extends StatelessWidget {
  const _DimTags(this.dims);
  final List<WellnessDimension> dims;
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Wrap(spacing: 6, children: [
      for (final d in dims)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(color: d.color(t.brightness).withOpacity(0.18), borderRadius: BorderRadius.circular(10)),
          child: Text(d.label, style: t.textTheme.labelSmall?.copyWith(color: d.color(t.brightness), fontWeight: FontWeight.w700)),
        ),
    ]);
  }
}

class _RecCard extends StatelessWidget {
  const _RecCard({required this.lesson, required this.book});
  final Lesson lesson;
  final Book book;
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return PressScale(
      semanticLabel: 'Recommended lesson: ${lesson.title}',
      onTap: Haptics.tap(() => context.push('/learn/${lesson.id}')),
      child: GlassCard(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _DimTags(lesson.dimensions),
          const SizedBox(height: 8),
          Text(lesson.title,
              maxLines: 2, overflow: TextOverflow.ellipsis, style: t.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
          const Spacer(),
          Text('${book.short} · ${book.author}', maxLines: 1, overflow: TextOverflow.ellipsis, style: t.textTheme.bodySmall),
        ]),
      ),
    );
  }
}

class _LessonTile extends StatelessWidget {
  const _LessonTile({required this.lesson, required this.book, required this.done});
  final Lesson lesson;
  final Book book;
  final bool done;
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final c = lesson.dimensions.first.color(t.brightness);
    return PressScale(
      semanticLabel: '${lesson.title}${done ? ', completed' : ''}',
      onTap: Haptics.tap(() => context.push('/learn/${lesson.id}')),
      child: GlassCard(
        padding: const EdgeInsets.all(14),
        child: Row(children: [
          CircleAvatar(
            backgroundColor: done ? c : c.withOpacity(0.18),
            foregroundColor: done ? Colors.white : c,
            child: Icon(done ? Icons.check_rounded : lesson.dimensions.first.icon),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(lesson.title, style: t.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 2),
              Text('${book.short} · ${lesson.readingMinutes} min read', style: t.textTheme.bodySmall),
              const SizedBox(height: 6),
              _DimTags(lesson.dimensions),
            ]),
          ),
          const Icon(Icons.chevron_right_rounded),
        ]),
      ),
    );
  }
}
