import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:oneup/core/services/haptics.dart';
import 'package:oneup/core/services/secure_store.dart';
import 'package:oneup/core/theme/app_colors.dart';
import 'package:oneup/features/ritual/micro_tasks.dart';
import 'package:oneup/features/ritual/ritual.dart';
import 'package:oneup/features/ritual/today_card.dart';
import 'mem_store.dart';

void main() {
  setUp(() => Haptics.enabled = false);

  test('micro-task library: 8 per dimension, unique, non-medical', () {
    for (final d in WellnessDimension.values) {
      final l = microTasks[d]!;
      expect(l.length, greaterThanOrEqualTo(8));
      expect(l.toSet().length, l.length);
    }
    final all = microTasks.values.expand((e) => e).join(' ').toLowerCase();
    for (final w in ['diagnos', 'therapy', 'medication', 'disorder', 'depress', 'cure', 'treat']) {
      expect(all.contains(w), isFalse, reason: w);
    }
  });

  test('task dimension: full lowest first, else quick, else rotates daily', () {
    final day = DateTime(2026, 11, 2, 9);
    expect(ritualDimension({WellnessDimension.social: 30, WellnessDimension.physical: 70}, {WellnessDimension.financial: 0}, day),
        WellnessDimension.social);
    expect(ritualDimension({}, {WellnessDimension.financial: 10, WellnessDimension.social: 50}, day), WellnessDimension.financial);
    final a = ritualDimension({}, null, day), b = ritualDimension({}, null, day.add(const Duration(days: 1)));
    expect(a, isNot(b));
    expect(ritualDimension({}, null, DateTime(2026, 11, 2, 23, 59)), a); // same local day → same pick
  });

  test('swap moves to a different task', () {
    final day = DateTime(2026, 11, 2);
    expect(ritualTask(WellnessDimension.physical, day, 0), isNot(ritualTask(WellnessDimension.physical, day, 1)));
  });

  test('streak counts consecutive days, tolerates an open today, resets quietly after a gap', () {
    final today = DateTime(2026, 11, 5, 20);
    final days = {
      '2026-11-02': const DayEntry(mood: Mood.good),
      '2026-11-03': const DayEntry(done: true),
      '2026-11-04': const DayEntry(mood: Mood.okay),
    };
    expect(ritualStreak(days, today), 3); // today still open
    expect(ritualStreak({...days, '2026-11-05': const DayEntry(mood: Mood.great)}, today), 4);
    expect(ritualStreak(days, DateTime(2026, 11, 7)), 0);
    expect(ritualStreak({'2026-10-31': const DayEntry(mood: Mood.low), '2026-11-01': const DayEntry(done: true)}, DateTime(2026, 11, 1)),
        2); // across a month boundary
  });

  test('controller: mood, one-word tag, done, one swap per day, local-day boundary, persisted', () async {
    final store = MemStore();
    var now = DateTime(2026, 11, 2, 23, 58);
    final c = RitualController(store, clock: () => now);
    await c.setMood(Mood.low);
    await c.setTag('  tired   but ok ');
    expect(c.state.on(now).tag, 'tired');
    expect(await c.swap(), isTrue);
    expect(await c.swap(), isFalse);
    await c.toggleDone();
    expect(c.state.on(now).done, isTrue);
    now = DateTime(2026, 11, 3, 0, 1); // past local midnight → fresh day
    expect(c.state.on(now).mood, isNull);
    expect(c.state.on(now).swaps, 0);
    expect(await c.swap(), isTrue);
    expect(store.m.containsKey(RitualController.key), isTrue);
    final again = RitualController(store, clock: () => now);
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    expect(again.state.days['2026-11-02']!.mood, Mood.low);
    expect(ritualStreak(again.state.days, now), 1);
    // delete-my-data path
    await store.deleteAll();
    final wiped = RitualController(store, clock: () => now);
    await Future<void>.delayed(Duration.zero);
    expect(wiped.state.days, isEmpty);
  });

  for (final size in const [Size(360, 640), Size(412, 915)]) {
    testWidgets('Today card: low mood shows support, task done + swap, streak @${size.width.toInt()}', (t) async {
      t.view.physicalSize = size * 3;
      t.view.devicePixelRatio = 3;
      addTearDown(t.view.reset);
      final store = MemStore()..m[RitualController.key] = '{"2026-11-01":{"mood":"good","tag":null,"done":false,"swaps":0}}';
      final c = ProviderContainer(overrides: [
        secureStoreProvider.overrideWithValue(store),
        ritualClockProvider.overrideWithValue(() => DateTime(2026, 11, 2, 10)),
      ]);
      addTearDown(c.dispose);
      final r = GoRouter(initialLocation: '/', routes: [
        GoRoute(
            path: '/', builder: (_, __) => const Scaffold(body: SingleChildScrollView(padding: EdgeInsets.all(16), child: TodayCard()))),
        GoRoute(path: '/companion', builder: (_, __) => const Scaffold(body: Text('COMPANION'))),
        GoRoute(path: '/crisis', builder: (_, __) => const Scaffold(body: Text('CRISIS'))),
      ]);
      await t.pumpWidget(UncontrolledProviderScope(container: c, child: MaterialApp.router(routerConfig: r)));
      await t.pump(const Duration(milliseconds: 300));
      expect(find.text('1-day streak'), findsOneWidget);
      expect(find.byKey(const Key('low-mood-note')), findsNothing);
      await t.tap(find.byKey(const Key('mood-low')));
      await t.pump(const Duration(milliseconds: 300));
      expect(find.byKey(const Key('low-mood-note')), findsOneWidget);
      expect(find.text('2-day streak'), findsOneWidget);
      final all = find.byKey(const Key('low-mood-note')).evaluate().single.widget.toString();
      expect(all.toLowerCase().contains('diagnos'), isFalse);
      // swap once, then disabled
      final before = c.read(ritualProvider).on(DateTime(2026, 11, 2)).swaps;
      await t.ensureVisible(find.byKey(const Key('today-task-swap')));
      await t.tap(find.byKey(const Key('today-task-swap')));
      await t.pump(const Duration(milliseconds: 300));
      expect(c.read(ritualProvider).on(DateTime(2026, 11, 2)).swaps, before + 1);
      expect(t.widget<IconButton>(find.byKey(const Key('today-task-swap'))).onPressed, isNull);
      await t.tap(find.byKey(const Key('today-task-done')));
      await t.pump(const Duration(milliseconds: 300));
      expect(c.read(ritualProvider).on(DateTime(2026, 11, 2)).done, isTrue);
      expect(t.takeException(), isNull);
      await t.ensureVisible(find.byKey(const Key('low-mood-support')));
      await t.tap(find.byKey(const Key('low-mood-support')));
      for (var i = 0; i < 8; i++) {
        await t.pump(const Duration(milliseconds: 100));
      }
      expect(find.text('CRISIS'), findsOneWidget);
    });
  }

  testWidgets('no-streak copy is gentle', (t) async {
    final c = ProviderContainer(overrides: [secureStoreProvider.overrideWithValue(MemStore())]);
    addTearDown(c.dispose);
    await t.pumpWidget(
        UncontrolledProviderScope(container: c, child: const MaterialApp(home: Scaffold(body: SingleChildScrollView(child: TodayCard())))));
    await t.pump(const Duration(milliseconds: 300));
    expect(find.text('Start today'), findsOneWidget);
  });
}
