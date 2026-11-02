import '../experts/experts.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../activity/activity.dart';
import 'package:go_router/go_router.dart';
import '../../core/router/nav.dart';
import '../../core/services/haptics.dart';
import '../../core/theme/app_colors.dart';
import 'learn_repository.dart';
import 'reader_prefs.dart';
import '../plus/entitlement.dart';
import '../plus/plus_ui.dart';

/// Book-style reader: chapter scroll, progress bar, A-/A+, reading themes, resume, complete + next.
class LessonReader extends ConsumerStatefulWidget {
  const LessonReader({super.key, required this.id});
  final String id;
  @override
  ConsumerState<LessonReader> createState() => _LessonReaderState();
}

class _LessonReaderState extends ConsumerState<LessonReader> {
  final _sc = ScrollController();
  final _progress = ValueNotifier<double>(0);
  Timer? _saveTimer;
  bool _restored = false;
  bool _resumed = false;
  late final ReadingPositions _positions = ref.read(readingPositionsProvider);

  @override
  void initState() {
    super.initState();
    _positions;
    _sc.addListener(_onScroll);
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    if (_sc.hasClients) _persist();
    _sc.dispose();
    _progress.dispose();
    super.dispose();
  }

  double get _fraction {
    if (!_sc.hasClients) return 0;
    final p = _sc.position;
    return p.maxScrollExtent <= 0 ? 1 : (p.pixels / p.maxScrollExtent).clamp(0.0, 1.0);
  }

  void _onScroll() {
    _progress.value = _fraction;
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 600), _persist);
  }

  void _persist() {
    if (!_restored) return;
    final f = _fraction;
    _positions.set(widget.id, f >= 0.98 ? 0 : f);
  }

  Future<void> _restore() async {
    if (_restored) return;
    _restored = true;
    final f = await _positions.get(widget.id);
    if (!mounted || f <= 0.02) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_sc.hasClients) return;
      _sc.jumpTo(f * _sc.position.maxScrollExtent);
      setState(() => _resumed = true);
    });
  }

  ThemeData _readerTheme(ThemeData base, ReaderTheme rt) => switch (rt) {
        ReaderTheme.app => base,
        ReaderTheme.sepia => base.copyWith(
            brightness: Brightness.light,
            colorScheme: base.colorScheme.copyWith(
                brightness: Brightness.light,
                surface: const Color(0xFFF4ECD8),
                onSurface: const Color(0xFF3B2F25),
                onSurfaceVariant: const Color(0xFF6B5A48),
                surfaceContainerHighest: const Color(0xFFE9DDC2),
                primary: const Color(0xFF8A5A2B),
                onPrimary: Colors.white),
            textTheme: base.textTheme.apply(bodyColor: const Color(0xFF3B2F25), displayColor: const Color(0xFF3B2F25)),
            iconTheme: const IconThemeData(color: Color(0xFF3B2F25)),
            dividerColor: const Color(0xFFD8C8A8),
          ),
        ReaderTheme.night => base.copyWith(
            brightness: Brightness.dark,
            colorScheme: base.colorScheme.copyWith(
                brightness: Brightness.dark,
                surface: const Color(0xFF111214),
                onSurface: const Color(0xFFD9D4CA),
                onSurfaceVariant: const Color(0xFFA39E94),
                surfaceContainerHighest: const Color(0xFF1C1D21),
                primary: const Color(0xFFE0B97A),
                onPrimary: const Color(0xFF1A1305)),
            textTheme: base.textTheme.apply(bodyColor: const Color(0xFFD9D4CA), displayColor: const Color(0xFFD9D4CA)),
            iconTheme: const IconThemeData(color: Color(0xFFD9D4CA)),
            dividerColor: const Color(0xFF2A2B30),
          ),
      };

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context);
    final lib = ref.watch(learnLibraryProvider).valueOrNull;
    final lesson = lib?.lesson(widget.id);
    if (lib == null || lesson == null) {
      return Scaffold(appBar: AppBar(), body: Center(child: Text(lib == null ? 'Loading…' : 'Lesson not found')));
    }
    _restore();
    final prefs = ref.watch(readerPrefsProvider);
    final notifier = ref.read(readerPrefsProvider.notifier);
    final t = _readerTheme(base, prefs.theme);
    final book = lib.book(lesson.bookId);
    final done = ref.watch(learnProgressProvider).contains(lesson.id);
    final next = lib.next(lesson.id);
    final accent = prefs.theme == ReaderTheme.app ? lesson.dimensions.first.color(t.brightness) : t.colorScheme.primary;
    final fs = 18.0 * prefs.scale;
    final bodyStyle = t.textTheme.bodyLarge?.copyWith(fontSize: fs, height: 1.6, letterSpacing: 0.1);
    final h2 = t.textTheme.titleLarge?.copyWith(fontSize: fs * 1.22, height: 1.3, fontWeight: FontWeight.w800);
    final small = t.textTheme.bodyMedium?.copyWith(fontSize: (fs * 0.8).clamp(13, 22), height: 1.5);
    final finance = lesson.dimensions.contains(WellnessDimension.financial);
    final b = lesson.body;
    // Long reads: first chapter free; the rest is Plus. Sensitive lessons are never locked.
    final locked = b != null && b.sections.length > 1 && !lesson.sensitive && !ref.watch(isPlusProvider);

    Widget para(String s) => Padding(padding: const EdgeInsets.only(bottom: 14), child: Text(s, style: bodyStyle));
    Widget heading(String s, {IconData? icon, Key? key}) => Padding(
          key: key,
          padding: const EdgeInsets.only(top: 18, bottom: 10),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (icon != null) ...[Icon(icon, color: accent, size: fs * 1.2), const SizedBox(width: 8)],
            Expanded(child: Text(s, style: h2)),
          ]),
        );
    Widget boxed(List<Widget> children, {Key? key}) => Container(
          key: key,
          width: double.infinity,
          margin: const EdgeInsets.only(top: 8, bottom: 8),
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
          decoration: BoxDecoration(
            color: accent.withOpacity(0.10),
            borderRadius: BorderRadius.circular(16),
            border: Border(left: BorderSide(color: accent, width: 4)),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
        );
    Widget bullet(String s, {String mark = '•'}) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SizedBox(width: fs * 1.4, child: Text(mark, style: bodyStyle?.copyWith(color: accent, fontWeight: FontWeight.w800))),
            Expanded(child: Text(s, style: bodyStyle)),
          ]),
        );

    final content = <Widget>[
      Wrap(spacing: 6, runSpacing: 6, children: [
        for (final d in lesson.dimensions)
          Chip(
            visualDensity: VisualDensity.compact,
            avatar: Icon(d.icon, size: 16, color: d.color(t.brightness)),
            label: Text(d.label),
          ),
      ]),
      const SizedBox(height: 14),
      Text(lesson.title, style: t.textTheme.headlineSmall?.copyWith(fontSize: fs * 1.5, height: 1.25, fontWeight: FontWeight.w800)),
      const SizedBox(height: 8),
      Text('From ${book.short} by ${book.author}', style: small?.copyWith(fontWeight: FontWeight.w600)),
      const SizedBox(height: 6),
      const Align(alignment: Alignment.centerLeft, child: ReviewedBadge(compact: true)),
      const SizedBox(height: 4),
      Text('${lesson.readingMinutes} min read · ${lesson.wordCount} words', key: const Key('reading-time'), style: small),
      if (book.verify) ...[
        const SizedBox(height: 4),
        Text('[VERIFY] ${book.note ?? 'Details to be checked against the book.'}', style: small?.copyWith(fontStyle: FontStyle.italic)),
      ],
      const Divider(height: 32),
      if (b != null) ...[
        para(b.intro),
        for (final s in locked ? b.sections.take(1) : b.sections) ...[heading(s.heading), for (final p in s.paragraphs) para(p)],
      ],
      if (b != null && locked)
        PlusLockCard(
            feature: PlusFeature.fullLessons,
            message: 'You have read the first chapter. The other ${b.sections.length - 1} chapters, the worked example, key takeaways '
                'and reflection questions are part of OneUP Plus. "Try this" below stays free.'),
      if (b != null && !locked) ...[
        boxed([
          Text(b.exampleTitle, style: bodyStyle?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          para(b.example),
        ], key: const Key('reader-example')),
        heading('Key takeaways', icon: Icons.lightbulb_outline_rounded, key: const Key('reader-takeaways')),
        for (final x in b.takeaways) bullet(x),
        heading('Reflect', icon: Icons.self_improvement_rounded),
        for (var i = 0; i < b.reflect.length; i++) bullet(b.reflect[i], mark: '${i + 1}.'),
      ],
      if (b == null) ...[
        para('Key idea: ${lesson.idea}'),
        for (final c in lesson.cards) para(c),
      ],
      boxed([
        Row(children: [
          Icon(Icons.bolt_rounded, color: accent),
          const SizedBox(width: 6),
          Text('Try this', style: h2),
        ]),
        const SizedBox(height: 8),
        para(lesson.tryThis),
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Text('One small step is enough. Skip anything that doesn\'t feel right for you.', style: small),
        ),
      ], key: const Key('reader-try')),
      heading('Reference', icon: Icons.menu_book_rounded, key: const Key('reader-reference')),
      Text(book.title, style: small?.copyWith(fontStyle: FontStyle.italic, fontWeight: FontWeight.w600)),
      Text('${book.author} · ${book.year} · ${book.publisher}', style: small),
      if (book.isbn != null) Text('ISBN ${book.isbn}', style: small),
      Text('Chapter / idea: ${lesson.idea}', style: small),
      if (book.note != null) ...[const SizedBox(height: 4), Text(book.note!, style: small)],
      const SizedBox(height: 10),
      if (finance) Text(lib.financialNote, style: small?.copyWith(fontWeight: FontWeight.w700)),
      Text(lib.disclaimer, style: small?.copyWith(fontWeight: FontWeight.w700)),
      const SizedBox(height: 24),
      FilledButton.icon(
        key: const Key('reader-complete'),
        style: FilledButton.styleFrom(backgroundColor: accent, foregroundColor: t.colorScheme.onPrimary),
        onPressed: () {
          done ? Haptics.light() : Haptics.success();
          ref.read(learnProgressProvider.notifier).setDone(lesson.id, !done);
          final act = ref.read(activityProvider.notifier);
          for (final d in lesson.dimensions) {
            done ? act.unlog(lessonRef(lesson.id, d)) : act.log(d, ActivityKind.lesson, lessonRef(lesson.id, d));
          }
        },
        icon: Icon(done ? Icons.check_circle_rounded : Icons.check_rounded),
        label: Text(done ? 'Completed · tap to undo' : 'Mark complete'),
      ),
      if (next != null) ...[
        const SizedBox(height: 10),
        OutlinedButton.icon(
          key: const Key('reader-next'),
          onPressed: Haptics.tap(() => context.pushReplacement('/learn/${next.id}')),
          icon: const Icon(Icons.arrow_forward_rounded),
          label: Text('Next: ${next.title}', maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
      ],
      const SizedBox(height: 32),
    ];

    content.addAll([
      const SizedBox(height: 20),
      const Divider(),
      LessonReviewFooter(lessonId: lesson.id, dimension: lesson.dimensions.first),
    ]);

    return Theme(
      data: t,
      child: Scaffold(
        backgroundColor: t.colorScheme.surface,
        appBar: AppBar(
          backgroundColor: t.colorScheme.surface,
          foregroundColor: t.colorScheme.onSurface,
          leading:
              IconButton(icon: const Icon(Icons.arrow_back_rounded), tooltip: 'Back', onPressed: Haptics.tap(() => context.popOrHome())),
          title: Text(book.short, maxLines: 1, overflow: TextOverflow.ellipsis),
          actions: [
            IconButton(
              key: const Key('font-smaller'),
              tooltip: 'Smaller text',
              onPressed: notifier.canSmaller ? Haptics.tap(() => notifier.bump(-1)) : null,
              icon: const Text('A-', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
            ),
            IconButton(
              key: const Key('font-larger'),
              tooltip: 'Larger text',
              onPressed: notifier.canLarger ? Haptics.tap(() => notifier.bump(1)) : null,
              icon: const Text('A+', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
            ),
            IconButton(
              key: const Key('reader-theme'),
              tooltip: 'Reading theme: ${prefs.theme.name}',
              onPressed: Haptics.tap(notifier.cycleTheme),
              icon: Icon(switch (prefs.theme) {
                ReaderTheme.app => Icons.palette_outlined,
                ReaderTheme.sepia => Icons.wb_sunny_outlined,
                ReaderTheme.night => Icons.dark_mode_outlined,
              }),
            ),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(3),
            child: ValueListenableBuilder<double>(
              valueListenable: _progress,
              builder: (_, v, __) => LinearProgressIndicator(
                key: const Key('reading-progress'),
                value: v,
                minHeight: 3,
                color: accent,
                backgroundColor: accent.withOpacity(0.15),
              ),
            ),
          ),
        ),
        body: SafeArea(
          top: false,
          child: Column(children: [
            if (lesson.sensitive) _SensitiveBanner(text: lib.sensitiveNote),
            if (_resumed)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
                child: Row(children: [
                  Icon(Icons.bookmark_rounded, size: 16, color: accent),
                  const SizedBox(width: 6),
                  Expanded(child: Text('Resumed where you left off', key: const Key('reader-resumed'), style: small)),
                  TextButton(
                    onPressed: () {
                      _sc.jumpTo(0);
                      setState(() => _resumed = false);
                    },
                    child: const Text('Start over'),
                  ),
                ]),
              ),
            Expanded(
              child: Scrollbar(
                controller: _sc,
                child: SingleChildScrollView(
                  key: const Key('reader-scroll'),
                  controller: _sc,
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 680),
                      child: RepaintBoundary(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: content),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

class _SensitiveBanner extends StatelessWidget {
  const _SensitiveBanner({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      child: Material(
        color: t.colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
          child: Row(children: [
            Icon(Icons.favorite_border_rounded, color: t.colorScheme.onSecondaryContainer, size: 20),
            const SizedBox(width: 8),
            Expanded(child: Text(text, style: t.textTheme.bodySmall?.copyWith(color: t.colorScheme.onSecondaryContainer))),
            TextButton(onPressed: Haptics.tap(() => context.go('/consult')), child: const Text('Consult')),
          ]),
        ),
      ),
    );
  }
}
