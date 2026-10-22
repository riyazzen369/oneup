import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:oneup/core/services/haptics.dart';
import 'package:oneup/core/services/secure_store.dart';
import 'package:oneup/core/theme/app_colors.dart';
import 'package:oneup/features/articles/data/article_repository.dart';
import 'package:oneup/features/learn/learn_models.dart';
import 'package:oneup/features/learn/learn_page.dart';
import 'package:oneup/features/learn/learn_repository.dart';
import 'package:oneup/features/learn/lesson_reader.dart';
import 'package:oneup/features/learn/reader_prefs.dart';
import 'mem_store.dart';

LearnLibrary lib() => LearnLibrary.fromJson(jsonDecode(File('assets/content/learn.json').readAsStringSync()) as Map<String, dynamic>);

void main() {
  setUp(() => Haptics.enabled = false);
  readerTests();

  test('content rules', () {
    final l = lib();
    expect(l.lessons.length, inInclusiveRange(24, 60));
    expect(l.lessons.map((e) => e.id).toSet().length, l.lessons.length);
    expect(l.books.length, 9);
    for (final b in l.books) {
      final n = l.lessons.where((x) => x.bookId == b.id).length;
      expect(n, greaterThanOrEqualTo(4), reason: b.id);
      expect(b.author, isNotEmpty);
      expect(b.year, inInclusiveRange(1990, 2026));
    }
    for (final x in l.lessons) {
      expect(x.cards.length, inInclusiveRange(3, 5), reason: x.id);
      expect(x.dimensions.length, inInclusiveRange(1, 2), reason: x.id);
      expect(x.tryThis, isNotEmpty);
      expect(l.book(x.bookId), isNotNull);
      for (final c in x.cards) {
        expect(c.length, lessThan(200), reason: 'short cards: ${x.id}');
        expect(RegExp(r'\d+\s?%').hasMatch(c), isFalse, reason: 'no statistics: ${x.id}');
      }
      expect(x.sensitive, x.bookId == 'body-keeps-score', reason: x.id);
    }
    // Book-style long reads.
    final forbidden = RegExp(
        r'\b(cures?|cured|proven|guaranteed?|studies (show|prove)|research (shows|proves)|scientifically|clinically|miracle|you should invest|buy this stock)\b|\d+\s?%|\bpercent\b',
        caseSensitive: false);
    var total = 0;
    for (final x in l.lessons) {
      final b = x.body;
      expect(b, isNotNull, reason: 'body: ${x.id}');
      expect(x.wordCount, inInclusiveRange(600, 1000), reason: 'length: ${x.id}');
      total += x.wordCount;
      expect(b!.intro.length, greaterThan(150), reason: x.id);
      expect(b.sections.length, inInclusiveRange(3, 5), reason: x.id);
      for (final s in b.sections) {
        expect(s.heading, isNotEmpty);
        expect(s.paragraphs.join(' ').split(' ').length, greaterThan(25), reason: '${x.id}: ${s.heading}');
      }
      expect(b.exampleTitle, startsWith('Illustrative'), reason: x.id);
      expect(b.example, matches(RegExp(r'illustrative (story|scenario)', caseSensitive: false)), reason: x.id);
      expect(b.takeaways.length, inInclusiveRange(3, 6), reason: x.id);
      expect(b.reflect.length, 2, reason: x.id);
      expect(x.tryThis.split(' ').length, greaterThan(25), reason: x.id);
      final all = [...b.allText, x.tryThis].join('\n');
      expect(forbidden.hasMatch(all), isFalse, reason: 'forbidden claim in ${x.id}: ${forbidden.firstMatch(all)?.group(0)}');
      // No long quotes: nothing in quotation marks longer than ~20 words.
      for (final m in RegExp('["\u201C\u201D]([^"\u201C\u201D]{120,})["\u201C\u201D]').allMatches(all)) {
        expect(m.group(1)!.split(' ').length, lessThan(20), reason: 'long quote in ${x.id}');
      }
      final book = l.book(x.bookId);
      if (book.id == 'wellness8') expect(b.intro, contains('[VERIFY]'), reason: x.id);
      if (book.id == '48-laws') expect(b.intro, contains('awareness'), reason: x.id);
      if (book.id == 'body-keeps-score') expect(b.intro, contains('qualified professional'), reason: x.id);
      if (x.dimensions.contains(WellnessDimension.financial)) expect(all, contains('not financial advice'), reason: x.id);
      expect(x.readingMinutes, inInclusiveRange(3, 5));
    }
    expect(total, greaterThan(30000));
    expect(l.next(l.lessons.first.id), l.lessons[1]);
    expect(l.next(l.lessons.last.id), l.lessons.first);
    expect(l.disclaimer, contains('Summary in our own words; read the book for full context'));
    expect(l.sensitiveNote, contains('qualified professional'));
    expect(l.financialNote, contains('Not financial advice'));
    final p = l.progress({});
    expect(p[WellnessDimension.environmental]!.$2, greaterThanOrEqualTo(6));
    expect(p[WellnessDimension.financial]!.$2, greaterThanOrEqualTo(6));
    // Every dimension has at least one lesson.
    expect(l.progress({}).values.every((p) => p.$2 > 0), isTrue);
  });

  test('recommended follows focus order and skips completed', () {
    final l = lib();
    final r = l.recommended([WellnessDimension.financial, WellnessDimension.environmental], {});
    expect(r.first.dimensions, contains(WellnessDimension.financial));
    expect(r.every((x) => x.dimensions.any((d) => d == WellnessDimension.financial || d == WellnessDimension.environmental)), isTrue);
    final r2 = l.recommended([WellnessDimension.financial], {r.first.id});
    expect(r2.map((e) => e.id), isNot(contains(r.first.id)));
    expect(l.recommended([], {}), isEmpty);
  });

  test('filters', () {
    final l = lib();
    expect(l.filter(bookId: 'mindset').every((x) => x.bookId == 'mindset'), isTrue);
    expect(l.filter(dim: WellnessDimension.social).every((x) => x.dimensions.contains(WellnessDimension.social)), isTrue);
  });

  test('progress persists locally', () async {
    final s = MemStore();
    final p = LearnProgress(s, remote: false);
    await Future<void>.delayed(Duration.zero);
    await p.setDone('ms-effort', true);
    expect(s.m[LearnProgress.key], contains('ms-effort'));
    final p2 = LearnProgress(s, remote: false);
    await Future<void>.delayed(Duration.zero);
    expect(p2.state, {'ms-effort'});
    await p2.setDone('ms-effort', false);
    expect(p2.state, isEmpty);
  });

  testWidgets('learn page filters, reader scrolls, marks complete, next lesson', (t) async {
    t.view.physicalSize = const Size(1080, 2340);
    t.view.devicePixelRatio = 2.75;
    addTearDown(t.view.reset);
    final s = MemStore();
    final router = GoRouter(routes: [
      GoRoute(path: '/', builder: (_, __) => const LearnPage()),
      GoRoute(path: '/learn/:id', builder: (_, st) => LessonReader(id: st.pathParameters['id']!)),
      GoRoute(path: '/consult', builder: (_, __) => const Scaffold(body: Text('CONSULT'))),
    ]);
    await t.pumpWidget(ProviderScope(
      overrides: [
        secureStoreProvider.overrideWithValue(s),
        learnLibraryProvider.overrideWith((_) async => lib()),
        focusDimensionsProvider.overrideWithValue([WellnessDimension.emotional]),
      ],
      child: MaterialApp.router(routerConfig: router),
    ));
    await t.pumpAndSettle();
    expect(find.text('Recommended for you'), findsOneWidget);
    await t.scrollUntilVisible(find.text('All books'), 300, scrollable: find.byType(Scrollable).first);
    await t.scrollUntilVisible(find.text('Mindset'), 200,
        scrollable: find.descendant(of: find.byKey(const Key('book-filters')), matching: find.byType(Scrollable)));
    await t.ensureVisible(find.text('Mindset'));
    await t.pumpAndSettle();
    await t.tap(find.text('Mindset'));
    await t.pumpAndSettle();
    await t.scrollUntilVisible(find.text('Praise the process'), 300, scrollable: find.byType(Scrollable).first);
    expect(find.text('Small changes compound'), findsNothing);
    await t.ensureVisible(find.text('Praise the process'));
    await t.pumpAndSettle();
    await t.tap(find.text('Praise the process'));
    await t.pumpAndSettle();
    expect(find.byKey(const Key('reading-time')), findsOneWidget);
    expect(find.textContaining('min read'), findsOneWidget);
    final scroll = find.byKey(const Key('reader-scroll'));
    await t.scrollUntilVisible(find.byKey(const Key('reader-complete')), 400,
        scrollable: find.descendant(of: scroll, matching: find.byType(Scrollable)));
    await t.pumpAndSettle();
    expect(find.text('Key takeaways'), findsOneWidget);
    expect(find.text('Reflect'), findsOneWidget);
    expect(find.text('Try this'), findsOneWidget);
    expect(find.textContaining('Summary in our own words'), findsOneWidget);
    expect(find.textContaining('9781400062751'), findsOneWidget);
    final bar = t.widget<LinearProgressIndicator>(find.byKey(const Key('reading-progress')));
    expect(bar.value, greaterThan(0.8));
    await t.tap(find.text('Mark complete'));
    await t.pumpAndSettle();
    expect(s.m[LearnProgress.key], contains('ms-praise'));
    expect(find.textContaining('Completed'), findsOneWidget);
    // Next lesson.
    final next = lib().next('ms-praise')!;
    await t.tap(find.byKey(const Key('reader-next')));
    await t.pumpAndSettle();
    expect(find.text(next.title), findsWidgets);
  });

  testWidgets('sensitive lesson shows professional-support note linking to Consult', (t) async {
    t.view.physicalSize = const Size(1080, 2340);
    t.view.devicePixelRatio = 2.75;
    addTearDown(t.view.reset);
    final router = GoRouter(initialLocation: '/learn/bks-connection', routes: [
      GoRoute(path: '/learn/:id', builder: (_, st) => LessonReader(id: st.pathParameters['id']!)),
      GoRoute(path: '/consult', builder: (_, __) => const Scaffold(body: Text('CONSULT'))),
    ]);
    await t.pumpWidget(ProviderScope(
      overrides: [secureStoreProvider.overrideWithValue(MemStore()), learnLibraryProvider.overrideWith((_) async => lib())],
      child: MaterialApp.router(routerConfig: router),
    ));
    await t.pumpAndSettle();
    expect(find.text(lib().sensitiveNote), findsOneWidget);
    await t.tap(find.text('Consult'));
    await t.pumpAndSettle();
    expect(find.text('CONSULT'), findsOneWidget);
  });

  testWidgets('financial lesson shows not-financial-advice note', (t) async {
    t.view.physicalSize = const Size(1080, 2340);
    t.view.devicePixelRatio = 2.75;
    addTearDown(t.view.reset);
    final router = GoRouter(initialLocation: '/learn/btb-scheduling', routes: [
      GoRoute(path: '/learn/:id', builder: (_, st) => LessonReader(id: st.pathParameters['id']!)),
    ]);
    await t.pumpWidget(ProviderScope(
      overrides: [secureStoreProvider.overrideWithValue(MemStore()), learnLibraryProvider.overrideWith((_) async => lib())],
      child: MaterialApp.router(routerConfig: router),
    ));
    await t.pumpAndSettle();
    await t.scrollUntilVisible(find.byKey(const Key('reader-complete')), 400,
        scrollable: find.descendant(of: find.byKey(const Key('reader-scroll')), matching: find.byType(Scrollable)));
    expect(find.text(lib().financialNote), findsOneWidget);
  });
}

Future<void> _pumpReader(WidgetTester t, MemStore s, String id, {Size size = const Size(1080, 2340), double dpr = 2.75}) async {
  t.view.physicalSize = size;
  t.view.devicePixelRatio = dpr;
  addTearDown(t.view.reset);
  final router = GoRouter(initialLocation: '/learn/$id', routes: [
    GoRoute(path: '/', builder: (_, __) => const Scaffold(body: Text('HOME'))),
    GoRoute(path: '/learn/:id', builder: (_, st) => LessonReader(id: st.pathParameters['id']!)),
    GoRoute(path: '/consult', builder: (_, __) => const Scaffold(body: Text('CONSULT'))),
  ]);
  await t.pumpWidget(ProviderScope(
    overrides: [secureStoreProvider.overrideWithValue(s), learnLibraryProvider.overrideWith((_) async => lib())],
    child: MaterialApp.router(routerConfig: router),
  ));
  await t.pumpAndSettle();
}

void readerTests() {
  testWidgets('font size A-/A+ and reading theme persist', (t) async {
    Haptics.enabled = false;
    final s = MemStore();
    await _pumpReader(t, s, 'ah-stacking');
    double size() => t.widget<Text>(find.text(lib().lesson('ah-stacking')!.body!.intro)).style!.fontSize!;
    expect(size(), closeTo(18, 0.01));
    final style = t.widget<Text>(find.text(lib().lesson('ah-stacking')!.body!.intro)).style!;
    expect(style.height, 1.6);
    await t.tap(find.byKey(const Key('font-larger')));
    await t.pumpAndSettle();
    expect(size(), closeTo(19.8, 0.01));
    await t.tap(find.byKey(const Key('font-smaller')));
    await t.tap(find.byKey(const Key('font-smaller')));
    await t.pumpAndSettle();
    expect(size(), closeTo(16.2, 0.01));
    for (var i = 0; i < 10; i++) {
      await t.tap(find.byKey(const Key('font-smaller')));
    }
    await t.pumpAndSettle();
    expect(size(), closeTo(18 * ReaderPrefs.minScale, 0.01));
    await t.tap(find.byKey(const Key('reader-theme')));
    await t.pumpAndSettle();
    expect(s.m[ReaderPrefs.key], contains('sepia'));
    await t.tap(find.byKey(const Key('reader-theme')));
    await t.pumpAndSettle();
    expect(s.m[ReaderPrefs.key], contains('night'));
    expect(t.takeException(), isNull);
  });

  testWidgets('resumes where you left off', (t) async {
    Haptics.enabled = false;
    final s = MemStore();
    await _pumpReader(t, s, 'pon-present');
    expect(find.byKey(const Key('reader-resumed')), findsNothing);
    await t.drag(find.byKey(const Key('reader-scroll')), const Offset(0, -1500));
    await t.pumpAndSettle();
    await t.pump(const Duration(seconds: 1));
    expect(s.m[ReadingPositions.key], contains('pon-present'));
    final saved = (jsonDecode(s.m[ReadingPositions.key]!) as Map)['pon-present'] as num;
    expect(saved, greaterThan(0.1));
    await t.pumpWidget(const SizedBox());
    await t.pumpAndSettle();
    await _pumpReader(t, s, 'pon-present');
    await t.pumpAndSettle();
    expect(find.byKey(const Key('reader-resumed')), findsOneWidget);
    final sc = t.widget<SingleChildScrollView>(find.byKey(const Key('reader-scroll'))).controller!;
    expect(sc.offset, greaterThan(500));
    await t.tap(find.text('Start over'));
    await t.pumpAndSettle();
    expect(sc.offset, 0);
  });

  for (final sz in const [Size(360, 640), Size(412, 915)]) {
    testWidgets('every lesson renders without overflow at ${sz.width.toInt()}x${sz.height.toInt()}', (t) async {
      Haptics.enabled = false;
      for (final x in lib().lessons) {
        await _pumpReader(t, MemStore(), x.id, size: sz, dpr: 1);
        expect(t.takeException(), isNull, reason: x.id);
        expect(find.text(x.title), findsWidgets);
        await t.scrollUntilVisible(find.byKey(const Key('reader-reference')), 600,
            scrollable: find.descendant(of: find.byKey(const Key('reader-scroll')), matching: find.byType(Scrollable)));
        expect(t.takeException(), isNull, reason: x.id);
        await t.pumpWidget(const SizedBox());
      }
    });
  }
}
