import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:oneup/core/services/haptics.dart';
import 'package:oneup/core/services/secure_store.dart';
import 'package:oneup/core/theme/app_colors.dart';
import 'package:oneup/features/activity/activity.dart';
import 'package:oneup/features/assess/data/assessment_models.dart';
import 'package:oneup/features/home/home_page.dart';
import 'package:oneup/features/report/report_screen.dart';
import 'package:oneup/features/report/weekly_report.dart';
import 'package:oneup/features/ritual/ritual.dart';
import 'package:oneup/features/ritual/ritual_reminders.dart';
import 'package:oneup/features/ritual/ritual_settings.dart';
import 'mem_store.dart';

// SAMPLE week: Mon Oct 26 – Sun Nov 1 2026.
final mon = DateTime(2026, 10, 26);
const sampleDays =
    '{"2026-10-25":{"mood":"okay","done":true,"swaps":0},"2026-10-26":{"mood":"meh","done":true,"swaps":0},"2026-10-27":{"mood":"okay","done":false,"swaps":0},"2026-10-29":{"mood":"good","done":true,"swaps":0},"2026-10-30":{"mood":"good","done":true,"swaps":0},"2026-10-31":{"mood":"great","done":true,"swaps":0},"2026-11-01":{"mood":"great","done":true,"swaps":0}}';
String ev(String d, String k, String at, String r) => '{"d":"$d","k":"$k","at":"$at","r":"$r"}';
final sampleActivity = '{"events":[${[
  ev('social', 'ritual', '2026-10-26T09:00:00.000', 'ritual:2026-10-26'),
  ev('social', 'game', '2026-10-28T09:00:00.000', 'game:g1:2026-10-28'),
  ev('social', 'lesson', '2026-10-29T09:00:00.000', 'lesson:l1:social'),
  ev('emotional', 'lesson', '2026-10-29T09:00:00.000', 'lesson:l1:emotional'),
  ev('physical', 'game', '2026-10-31T09:00:00.000', 'game:g2:2026-10-31'),
  ev('physical', 'game', '2026-10-20T09:00:00.000', 'game:g2:2026-10-20'),
].join(',')}],"seen":"2026-11-01T00:00:00.000"}';

void main() {
  setUp(() => Haptics.enabled = false);

  test('week boundaries: Monday start; Sunday shows this week, other days last week', () {
    expect(weekStartOf(DateTime(2026, 11, 1, 20)), DateTime(2026, 10, 26));
    expect(weekStartOf(DateTime(2026, 11, 2)), DateTime(2026, 11, 2));
    expect(currentReportWeek(DateTime(2026, 11, 1, 10)), DateTime(2026, 10, 26));
    expect(currentReportWeek(DateTime(2026, 11, 4)), DateTime(2026, 10, 26));
    expect(currentReportWeek(DateTime(2026, 11, 8)), DateTime(2026, 11, 2));
  });

  test('buildWeeklyReport: rituals, moods, trend, active dims, lessons/games, score changes, focus', () {
    final store = MemStore()..m[RitualController.key] = sampleDays;
    final c = RitualController(store, clock: () => DateTime(2026, 11, 1, 20));
    final a = ActivityController(MemStore()..m[ActivityController.key] = sampleActivity, clock: () => DateTime(2026, 11, 1, 20));
    return Future.wait([c.ready, a.ready]).then((_) {
      final r = buildWeeklyReport(
        weekStart: mon,
        days: c.state.days,
        events: a.state.events,
        attempts: [
          DimAttempt(id: '1', dimension: WellnessDimension.social, score: 60, completedAt: DateTime(2026, 10, 1)),
          DimAttempt(id: '2', dimension: WellnessDimension.social, score: 66, completedAt: DateTime(2026, 10, 30)),
          DimAttempt(
              id: '3', dimension: WellnessDimension.financial, score: 40, completedAt: DateTime(2026, 10, 30)), // first ever: no delta
        ],
        latestScores: {WellnessDimension.social: 66, WellnessDimension.financial: 40, WellnessDimension.spiritual: 55},
      );
      expect(r.ritualsDone, 5);
      expect(r.checkIns, 6);
      expect(r.moods[2], isNull);
      expect(r.moods.first, Mood.meh);
      expect(r.moodTrend, MoodTrend.up);
      expect(r.streak, 4); // Oct 29 – Nov 1
      expect(r.active.keys.first, WellnessDimension.social);
      expect(r.active[WellnessDimension.social], 3);
      expect(r.active[WellnessDimension.physical], 1); // Oct 20 is outside the week
      expect(r.lessons, 1); // one lesson counted once across dimensions
      expect(r.games, 2);
      expect(r.scoreChanges, {WellnessDimension.social: 6});
      expect(r.focus, WellnessDimension.financial); // lowest score, little activity
      final back = WeeklyReport.fromJson(r.toJson());
      expect(back.toJson(), r.toJson());
    });
  });

  test('empty week is graceful', () {
    final r = buildWeeklyReport(weekStart: mon, days: const {}, events: const [], attempts: const []);
    expect(r.isEmpty, isTrue);
    expect(r.moodTrend, MoodTrend.none);
    expect(r.focus, isNotNull);
    expect(moodTrendText(r), contains('Check in'));
  });

  test('weekly reminder: Sundays 7 PM, skips passed, can be off', () {
    final p = planWeeklyReminders(now: DateTime(2026, 11, 1, 10), settings: const RitualSettings());
    expect(p.length, 4);
    expect(p.first.at, DateTime(2026, 11, 1, 19));
    expect(p.first.payload, weeklyPayload);
    expect(p.first.title, weeklyTitle);
    expect(planWeeklyReminders(now: DateTime(2026, 11, 1, 20), settings: const RitualSettings()).first.at, DateTime(2026, 11, 8, 19));
    expect(planWeeklyReminders(now: DateTime(2026, 11, 3), settings: const RitualSettings()).first.at, DateTime(2026, 11, 8, 19));
    expect(planWeeklyReminders(now: DateTime(2026, 11, 3), settings: const RitualSettings(weekly: false)), isEmpty);
    expect('$weeklyTitle $weeklyBody'.toLowerCase(), isNot(contains('diagnos')));
  });

  Future<ProviderContainer> container(MemStore store, DateTime now) async {
    final c = ProviderContainer(overrides: [
      secureStoreProvider.overrideWithValue(store),
      ritualClockProvider.overrideWithValue(() => now),
    ]);
    addTearDown(c.dispose);
    return c;
  }

  test('reports persist encrypted, freeze after the week, keep last 8', () async {
    final store = MemStore()
      ..m[RitualController.key] = sampleDays
      ..m[ActivityController.key] = sampleActivity;
    var c = await container(store, DateTime(2026, 11, 1, 20));
    final r = await c.read(reportsProvider.notifier).refresh();
    expect(r.ritualsDone, 5);
    expect(store.m[ReportsController.key], contains('2026-10-26'));
    // Next Monday: same report (frozen), not rebuilt from changed data.
    store.m[RitualController.key] = '{}';
    c = await container(store, DateTime(2026, 11, 3));
    expect((await c.read(reportsProvider.notifier).refresh()).ritualsDone, 5);
    // Ten weeks later, still at most 8 kept.
    for (var w = 1; w <= 10; w++) {
      c = await container(store, DateTime(2026, 11, 1 + 7 * w, 20));
      await c.read(reportsProvider.notifier).refresh();
    }
    await c.read(reportsProvider.notifier).ready;
    expect(c.read(reportsProvider).reports.length, ReportsController.keep);
    expect(c.read(reportsProvider).latest!.weekStart, DateTime(2027, 1, 4));
  });

  testWidgets('report: swipe pages, privacy note before share, cancel shares nothing', (t) async {
    t.view.physicalSize = const Size(412, 915) * 3;
    t.view.devicePixelRatio = 3;
    addTearDown(t.view.reset);
    final store = MemStore()
      ..m[RitualController.key] = sampleDays
      ..m[ActivityController.key] = sampleActivity;
    final shared = <Uint8List>[];
    final c = ProviderContainer(overrides: [
      secureStoreProvider.overrideWithValue(store),
      ritualClockProvider.overrideWithValue(() => DateTime(2026, 11, 1, 20)),
      shareImageProvider.overrideWithValue((png, text) async => shared.add(png)),
    ]);
    addTearDown(c.dispose);
    await t.pumpWidget(UncontrolledProviderScope(container: c, child: const MaterialApp(home: ReportScreen())));
    for (var i = 0; i < 5; i++) {
      await t.pump(const Duration(milliseconds: 100));
    }
    expect(find.byKey(const Key('story-overview')), findsOneWidget);
    expect(find.text('of 7 small steps done'), findsOneWidget);
    expect(c.read(reportsProvider).unseen, isFalse);
    await t.drag(find.byKey(const Key('report-pages')), const Offset(-600, 0));
    for (var i = 0; i < 6; i++) {
      await t.pump(const Duration(milliseconds: 100));
    }
    expect(find.byKey(const Key('story-active')), findsOneWidget);
    expect(find.text('Social'), findsOneWidget);
    await t.tap(find.byKey(const Key('report-share')));
    await t.pump(const Duration(milliseconds: 300));
    expect(find.text(sharePrivacyNote), findsOneWidget);
    await t.tap(find.text('Cancel'));
    await t.pump(const Duration(milliseconds: 300));
    expect(shared, isEmpty);
    await t.tap(find.byKey(const Key('report-share')));
    await t.pump(const Duration(milliseconds: 300));
    await t.tap(find.byKey(const Key('share-confirm')));
    await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
    await t.pump(const Duration(milliseconds: 100));
    await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
    expect(shared.length, 1);
    expect(shared.first.sublist(1, 4), [0x50, 0x4E, 0x47]); // PNG
    for (var i = 0; i < 3; i++) {
      await t.tap(find.byKey(const Key('report-next')));
      for (var j = 0; j < 5; j++) {
        await t.pump(const Duration(milliseconds: 100));
      }
    }
    expect(find.byKey(const Key('story-focus')), findsOneWidget);
    expect(find.text(reportDisclaimer), findsOneWidget);
  });

  testWidgets('Home shows "Your week is ready" on Sunday; hidden for an empty last week on Monday', (t) async {
    t.view.physicalSize = const Size(412, 915) * 3;
    t.view.devicePixelRatio = 3;
    addTearDown(t.view.reset);
    Future<ProviderContainer> home(MemStore store, DateTime now) async {
      final c = ProviderContainer(overrides: [
        secureStoreProvider.overrideWithValue(store),
        ritualClockProvider.overrideWithValue(() => now),
        ritualRemindersProvider.overrideWithValue(RitualReminders()),
      ]);
      addTearDown(c.dispose);
      final r = GoRouter(initialLocation: '/home', routes: [GoRoute(path: '/home', builder: (_, __) => const HomePage())]);
      await t.pumpWidget(UncontrolledProviderScope(container: c, child: MaterialApp.router(routerConfig: r)));
      for (var i = 0; i < 20; i++) {
        await t.pump(const Duration(milliseconds: 100));
      }
      return c;
    }

    await home(
        MemStore()
          ..m['welcome_shown_v1'] = 'x'
          ..m['ritual_settings_v1'] = '{"popup":false}'
          ..m[RitualController.key] = sampleDays,
        DateTime(2026, 11, 1, 20));
    await t.scrollUntilVisible(find.byKey(const Key('home-weekly-report')), 200, scrollable: find.byType(Scrollable).first);
    expect(find.text('Your week is ready'), findsOneWidget);
    expect(find.byKey(const Key('report-unseen-dot')), findsOneWidget);
    await t.pumpWidget(const SizedBox());
    await home(
        MemStore()
          ..m['welcome_shown_v1'] = 'x'
          ..m['ritual_settings_v1'] = '{"popup":false}',
        DateTime(2026, 11, 3, 9));
    expect(find.byKey(const Key('home-weekly-report'), skipOffstage: false), findsNothing);
  });
}
