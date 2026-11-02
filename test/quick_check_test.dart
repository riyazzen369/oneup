import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:oneup/core/services/haptics.dart';
import 'package:oneup/core/services/secure_store.dart';
import 'package:oneup/core/theme/app_colors.dart';
import 'package:oneup/features/assess/domain/scoring.dart';
import 'package:oneup/features/quick/quick_check.dart';
import 'package:oneup/features/quick/quick_check_screen.dart';
import 'package:oneup/features/results/wellness_wheel.dart';
import 'package:oneup/features/home/home_page.dart';
import 'mem_store.dart';

Future<ProviderContainer> _pump(WidgetTester t, MemStore store, String initial, {Size size = const Size(412, 915)}) async {
  t.view.physicalSize = size * 3;
  t.view.devicePixelRatio = 3;
  addTearDown(t.view.reset);
  final c = ProviderContainer(overrides: [secureStoreProvider.overrideWithValue(store)]);
  addTearDown(c.dispose);
  final r = GoRouter(initialLocation: initial, routes: [
    GoRoute(path: '/home', builder: (_, __) => const Scaffold(body: Text('HOME'))),
    GoRoute(path: '/quick', builder: (_, __) => const QuickCheckScreen()),
    GoRoute(path: '/quick/result', builder: (_, __) => const QuickResultScreen()),
    GoRoute(path: '/assess/q/:dim', builder: (_, s) => Scaffold(body: Text('Q ${s.pathParameters['dim']}'))),
  ]);
  await t.pumpWidget(UncontrolledProviderScope(container: c, child: MaterialApp.router(routerConfig: r)));
  await t.pump(const Duration(milliseconds: 300));
  return c;
}

void main() {
  setUp(() => Haptics.enabled = false);

  test('1-10 maps onto 0-100 and bands follow 0-40 / 41-70 / 71-100', () {
    expect(quickToScore(1), 0);
    expect(quickToScore(10), 100);
    expect(quickToScore(5), 44);
    expect(bandFor(quickToScore(4)), ScoreBand.needsAttention); // 33
    expect(bandFor(quickToScore(7)), ScoreBand.developing); // 67
    expect(bandFor(quickToScore(8)), ScoreBand.thriving); // 78
  });

  test('every dimension has an original prompt', () {
    for (final d in WellnessDimension.values) {
      expect(quickPrompts[d], isNotNull);
      expect(quickPrompts[d]!.endsWith('?'), isTrue);
    }
    final all = quickPrompts.values.join(' ').toLowerCase();
    for (final w in ['diagnos', 'disorder', 'depress', 'anxiety', 'treat', 'cure']) {
      expect(all.contains(w), isFalse, reason: w);
    }
  });

  test('blend: full scores always win, quick only fills gaps and is marked', () {
    final quick = QuickSnapshot(takenAt: DateTime(2026), scores: {for (final d in WellnessDimension.values) d: 10});
    final b = blendScores({WellnessDimension.emotional: 80}, quick);
    expect(b.scores[WellnessDimension.emotional], 80);
    expect(b.estimated.contains(WellnessDimension.emotional), isFalse);
    expect(b.estimated.length, 7);
    expect(blendScores({WellnessDimension.emotional: 80}, null).estimated, isEmpty);
  });

  test('lowest picks min, ties by wheel order', () {
    expect(lowestQuick({WellnessDimension.social: 20, WellnessDimension.physical: 20, WellnessDimension.financial: 50}),
        WellnessDimension.physical);
  });

  test('submit stores separately (own key), persists, never touches full assessment keys', () async {
    final store = MemStore()..m['assess_attempts_v2'] = '[{"keep":1}]';
    final c = ProviderContainer(overrides: [secureStoreProvider.overrideWithValue(store)]);
    addTearDown(c.dispose);
    await Future<void>.delayed(Duration.zero);
    await c.read(quickCheckProvider.notifier).submit({WellnessDimension.financial: 2});
    expect(store.m['assess_attempts_v2'], '[{"keep":1}]');
    expect(store.m.containsKey(QuickCheckRepository.key), isTrue);
    final again = await QuickCheckRepository(store).load();
    expect(again.single.scores[WellnessDimension.financial], 11);
    expect(again.single.scores[WellnessDimension.emotional], 44);
    // delete-my-data path: wipe + invalidate leaves no snapshot
    await store.deleteAll();
    c.invalidate(quickCheckProvider);
    c.read(quickCheckProvider);
    await Future<void>.delayed(Duration.zero);
    expect(c.read(quickCheckProvider).latest, isNull);
  });

  for (final size in const [Size(360, 640), Size(412, 915)]) {
    testWidgets('quick check flow: disclaimer, sliders, result, lowest + deep dive CTA @${size.width.toInt()}', (t) async {
      final store = MemStore();
      final c = await _pump(t, store, '/quick', size: size);
      expect(find.textContaining('OneUp is for wellness awareness, not medical diagnosis.'), findsOneWidget);
      expect(find.byType(Slider), findsWidgets);
      // Drag Social to the far left (1/10) → lowest.
      final s = find.byKey(const Key('quick-slider-social'));
      await t.scrollUntilVisible(s, 200, scrollable: find.byType(Scrollable).first);
      await t.pump();
      await t.drag(s, const Offset(-600, 0));
      await t.pump();
      expect(find.text('1/10'), findsOneWidget);
      final submit = find.byKey(const Key('quick-submit'));
      await t.scrollUntilVisible(submit, 200, scrollable: find.byType(Scrollable).first);
      await t.pump();
      await t.tap(submit);
      for (var i = 0; i < 20; i++) {
        await t.pump(const Duration(milliseconds: 100));
      }
      expect(c.read(quickCheckProvider).latest!.scores[WellnessDimension.social], 0);
      expect(find.byKey(const Key('quick-estimate-tag')), findsOneWidget);
      final wheel = t.widget<WellnessWheel>(find.byType(WellnessWheel));
      expect(wheel.estimated.length, 8);
      final cta = find.text('Take the deep dive for Social');
      await t.scrollUntilVisible(cta, 200, scrollable: find.byType(Scrollable).first);
      expect(find.text('Social · lowest right now'), findsOneWidget);
      expect(cta, findsOneWidget);
      expect(t.takeException(), isNull);
    });
  }

  testWidgets('deep dive CTA shows the assessment disclaimer then opens that dimension', (t) async {
    final store = MemStore()
      ..m[QuickCheckRepository.key] =
          '[{"takenAt":"2026-11-01T10:00:00.000","scores":{"emotional":60,"physical":60,"occupational":60,"social":60,"spiritual":60,"intellectual":60,"environmental":60,"financial":10}}]';
    await _pump(t, store, '/quick/result');
    await t.pump(const Duration(milliseconds: 300));
    final cta = find.byKey(const Key('quick-deep-dive'));
    await t.scrollUntilVisible(cta, 200, scrollable: find.byType(Scrollable).first);
    await t.pump();
    expect(find.text('Take the deep dive for Financial'), findsOneWidget);
    await t.tap(cta);
    await t.pump(const Duration(milliseconds: 400));
    expect(find.text('Before you begin'), findsOneWidget);
    await t.tap(find.text('I understand'));
    for (var i = 0; i < 10; i++) {
      await t.pump(const Duration(milliseconds: 100));
    }
    expect(find.text('Q financial'), findsOneWidget);
  });

  testWidgets('Home offers Quick Check and marks quick-estimate segments only where no full score exists', (t) async {
    final store = MemStore()
      ..m['welcome_shown_v1'] = 'x'
      ..m[QuickCheckRepository.key] =
          '[{"takenAt":"2026-11-01T10:00:00.000","scores":{"emotional":60,"physical":60,"occupational":60,"social":60,"spiritual":60,"intellectual":60,"environmental":60,"financial":10}}]';
    t.view.physicalSize = const Size(412, 915) * 3;
    t.view.devicePixelRatio = 3;
    addTearDown(t.view.reset);
    final c = ProviderContainer(overrides: [secureStoreProvider.overrideWithValue(store)]);
    addTearDown(c.dispose);
    final r = GoRouter(initialLocation: '/home', routes: [GoRoute(path: '/home', builder: (_, __) => const HomePage())]);
    await t.pumpWidget(UncontrolledProviderScope(container: c, child: MaterialApp.router(routerConfig: r)));
    for (var i = 0; i < 20; i++) {
      await t.pump(const Duration(milliseconds: 100));
    }
    expect(find.byKey(const Key('home-quick-check')), findsOneWidget);
    expect(find.byKey(const Key('home-quick-legend')), findsOneWidget);
    final wheel = t.widget<WellnessWheel>(find.byType(WellnessWheel).first);
    expect(wheel.estimated.length, 8);
    expect(wheel.overall, isNull); // a quick estimate never produces an overall score
  });
}
