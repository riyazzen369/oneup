import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:oneup/core/services/haptics.dart';
import 'package:oneup/core/services/secure_store.dart';
import 'package:oneup/core/theme/app_colors.dart';
import 'package:oneup/features/experts/experts.dart';
import 'package:oneup/features/learn/learn_models.dart';
import 'package:oneup/features/learn/learn_repository.dart';
import 'package:oneup/features/learn/lesson_reader.dart';
import 'package:oneup/features/ritual/ritual.dart';
import 'mem_store.dart';

void main() {
  setUp(() => Haptics.enabled = false);
  final lib = LearnLibrary.fromJson(jsonDecode(File('assets/content/learn.json').readAsStringSync()) as Map<String, dynamic>);
  Future<void> pumpN(WidgetTester t, [int n = 12]) async {
    for (var i = 0; i < n; i++) {
      await t.pump(const Duration(milliseconds: 100));
    }
  }

  test('every reviewer is a clearly marked SAMPLE placeholder with a [VERIFY] role', () {
    expect(sampleReviewers.keys.toSet(), WellnessDimension.values.toSet());
    for (final r in sampleReviewers.values) {
      expect(r.name, contains('SAMPLE'));
      expect(r.role, contains('[VERIFY]'));
    }
    expect(sampleLastReviewed, contains('SAMPLE'));
    expect(expertsDisclaimer, contains('not medical advice'));
  });

  Widget app(MemStore s, String loc) => ProviderScope(
        overrides: [
          secureStoreProvider.overrideWithValue(s),
          ritualClockProvider.overrideWithValue(() => DateTime(2026, 11, 2, 10)),
          learnLibraryProvider.overrideWith((_) async => lib),
        ],
        child: MaterialApp.router(
            routerConfig: GoRouter(initialLocation: loc, routes: [
          GoRoute(path: '/experts', builder: (_, __) => const ExpertsScreen()),
          GoRoute(path: '/learn/:id', builder: (_, s) => LessonReader(id: s.pathParameters['id']!)),
        ])),
      );

  testWidgets('experts screen: placeholders, methodology, cited books, disclaimer', (t) async {
    t.view.physicalSize = const Size(1080, 2340);
    t.view.devicePixelRatio = 2.75;
    addTearDown(t.view.reset);
    await t.pumpWidget(app(MemStore(), '/experts'));
    await pumpN(t);
    expect(find.byKey(const Key('experts-sample-note')), findsOneWidget);
    final sc = find.byType(Scrollable).first;
    for (final k in ['experts-method', 'experts-sources', 'experts-disclaimer']) {
      await t.scrollUntilVisible(find.byKey(Key(k)), 300, scrollable: sc);
    }
    expect(find.textContaining(lib.books.first.title), findsOneWidget);
  });

  testWidgets('lesson: review line, badge opens /experts, report an issue stored locally', (t) async {
    t.view.physicalSize = const Size(1080, 2340);
    t.view.devicePixelRatio = 2.75;
    addTearDown(t.view.reset);
    final s = MemStore();
    final lesson = lib.lessons.first;
    await t.pumpWidget(app(s, '/learn/${lesson.id}'));
    await pumpN(t);
    final sc = find.byKey(const Key('reader-scroll'));
    await t.scrollUntilVisible(find.byKey(const Key('report-issue')), 400,
        scrollable: find.descendant(of: sc, matching: find.byType(Scrollable)));
    expect(find.textContaining(reviewerFor(lesson.dimensions.first).name), findsOneWidget);
    await t.tap(find.byKey(const Key('report-issue')));
    await pumpN(t, 4);
    await t.tap(find.text('Unclear or confusing'));
    await t.enterText(find.byKey(const Key('report-issue-note')), 'Step 2 is confusing');
    await t.tap(find.byKey(const Key('report-issue-submit')));
    await pumpN(t, 4);
    final saved = jsonDecode(s.m[ContentFeedback.key]!) as List;
    expect(saved.single['lesson'], lesson.id);
    expect(saved.single['kind'], 'Unclear or confusing');
    await t.tap(find.byKey(const Key('reviewed-badge')).last);
    await pumpN(t);
    expect(find.byKey(const Key('experts-screen')), findsOneWidget);
  });
}
