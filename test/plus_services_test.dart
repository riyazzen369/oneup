import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:oneup/core/services/haptics.dart';
import 'package:oneup/core/services/secure_store.dart';
import 'package:oneup/core/theme/app_colors.dart';
import 'package:oneup/features/consult/data/consult_models.dart';
import 'package:oneup/features/consult/ui/consultant_profile_screen.dart';
import 'package:oneup/features/market/market_models.dart';
import 'package:oneup/features/plus/entitlement.dart';
import 'package:oneup/features/plus/services.dart';
import 'package:oneup/features/report/monthly_report.dart';
import 'package:oneup/features/report/weekly_report.dart';
import 'package:oneup/features/ritual/ritual.dart';
import 'mem_store.dart';

final now = DateTime(2026, 11, 2, 11);

WeeklyReport wk(int month, int day, {int r = 3, int c = 4, int s = 2, Map<WellnessDimension, int> a = const {}}) => WeeklyReport(
    weekStart: DateTime(2026, month, day),
    ritualsDone: r,
    checkIns: c,
    streak: s,
    moods: const [Mood.okay, Mood.good, null, null, null, null, Mood.great],
    active: a,
    lessons: 1,
    games: 2);

final sampleWeeks = [
  wk(10, 26, a: {WellnessDimension.social: 3}),
  wk(10, 19, s: 5, a: {WellnessDimension.social: 1, WellnessDimension.emotional: 2}),
  wk(10, 12),
  wk(10, 5),
  wk(9, 28, r: 1, c: 1),
];

MemStore seeded({bool plus = false}) {
  final s = MemStore()
    ..m[ReportsController.key] = jsonEncode({
      'reports': [for (final w in sampleWeeks) w.toJson()],
      'seen': '2026-10-26'
    });
  if (plus) {
    s.m[EntitlementController.key] = '{"plan":"trial","start":"2026-11-01T00:00:00.000","exp":"2026-11-08T00:00:00.000","trialUsed":true}';
  }
  return s;
}

Widget app(MemStore s, Widget home, {List<RouteBase> extra = const []}) => ProviderScope(
      overrides: [secureStoreProvider.overrideWithValue(s), ritualClockProvider.overrideWithValue(() => now)],
      child: MaterialApp.router(
          routerConfig: GoRouter(routes: [
        GoRoute(path: '/', builder: (_, __) => home),
        GoRoute(path: '/plus', builder: (_, __) => const Scaffold(body: Text('PLUS'))),
        GoRoute(path: '/crisis', builder: (_, __) => const Scaffold(body: Text('CRISIS'))),
        GoRoute(path: '/report', builder: (_, __) => const Scaffold(body: Text('REPORT'))),
        ...extra,
      ])),
    );

Future<void> pumpN(WidgetTester t, [int n = 12]) async {
  for (var i = 0; i < n; i++) {
    await t.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  setUp(() => Haptics.enabled = false);

  test('monthly report aggregates weeks starting in the month', () {
    final m = monthlyReports(sampleWeeks);
    expect(m.map((x) => x.label), ['October 2026', 'September 2026']);
    final oct = m.first;
    expect(oct.weeks, 4);
    expect(oct.ritualsDone, 12);
    expect(oct.checkIns, 16);
    expect(oct.bestStreak, 5);
    expect(oct.lessons + oct.games, 12);
    expect(oct.active.keys.first, WellnessDimension.social);
    expect(oct.active[WellnessDimension.social], 4);
    expect(oct.moods[Mood.great], 4);
    expect(buildMonthlyReport(DateTime(2026, 8), sampleWeeks).isEmpty, isTrue);
  });

  test('picked for you uses lowest dimensions; member price is a SAMPLE discount', () {
    final p = pickedForYou({WellnessDimension.financial: 30, WellnessDimension.social: 80, WellnessDimension.emotional: 45}, dims: 2);
    expect(p.map((e) => e.$2).toSet(), {WellnessDimension.financial, WellnessDimension.emotional});
    expect(p.every((e) => !e.$1.consultOnly), isTrue);
    expect(p.first.$2, WellnessDimension.financial);
    expect(memberPrice(1000), 900);
    expect(sampleCoaches.map((c) => c.dimension).toSet().length, 8);
    expect(sampleCoaches.every((c) => c.name.startsWith('SAMPLE')), isTrue);
  });

  testWidgets('dashboard: latest 2 weekly free, older + monthly locked; Plus shows months', (t) async {
    await t.pumpWidget(app(seeded(), const ReportsDashboard()));
    await pumpN(t);
    expect(find.byKey(const Key('dash-week-2026-10-26')), findsOneWidget);
    expect(find.descendant(of: find.byKey(const Key('dash-week-2026-10-12')), matching: find.byIcon(Icons.lock_outline_rounded)),
        findsOneWidget);
    expect(find.descendant(of: find.byKey(const Key('dash-week-2026-10-19')), matching: find.byIcon(Icons.lock_outline_rounded)),
        findsNothing);
    await t.tap(find.text('Monthly'));
    await pumpN(t);
    expect(find.byKey(const Key('plus-lock-reportDashboard')), findsOneWidget);

    await t.pumpWidget(const SizedBox());
    await t.pumpWidget(app(seeded(plus: true), const ReportsDashboard(monthly: true)));
    await pumpN(t);
    expect(find.byKey(const Key('month-2026-10')), findsOneWidget);
    expect(find.text('October 2026'), findsOneWidget);
  });

  testWidgets('coaching: free sees upsell; Plus books a demo slot', (t) async {
    t.view.physicalSize = const Size(1080, 2340);
    t.view.devicePixelRatio = 2.75;
    addTearDown(t.view.reset);
    await t.pumpWidget(app(MemStore(), const CoachingScreen()));
    await pumpN(t);
    expect(find.byKey(const Key('coach-disclaimer')), findsOneWidget);
    await t.tap(find.byKey(const Key('coach-emotional-book')));
    await pumpN(t, 6);
    expect(find.byKey(const Key('plus-upsell')), findsOneWidget);

    await t.pumpWidget(const SizedBox());
    final s = seeded(plus: true);
    await t.pumpWidget(app(s, const CoachingScreen()));
    await pumpN(t);
    await t.tap(find.byKey(const Key('coach-emotional-book')));
    await pumpN(t, 6);
    expect(find.byKey(const Key('demo-slot-picker')), findsOneWidget);
    await t.tap(find.byKey(const Key('slot-1')));
    await t.pump();
    await t.tap(find.byKey(const Key('slot-confirm')));
    await pumpN(t);
    expect(find.text('Coaching · SAMPLE Coach Asha'), findsOneWidget);
    expect(s.m[ServiceRequestsController.key], contains('2026-11-03T14:00'));
  });

  testWidgets('support: crisis first for everyone; priority badge only for Plus', (t) async {
    t.view.physicalSize = const Size(1080, 2340);
    t.view.devicePixelRatio = 2.75;
    addTearDown(t.view.reset);
    for (final plus in [false, true]) {
      await t.pumpWidget(const SizedBox());
      await t.pumpWidget(app(plus ? seeded(plus: true) : MemStore(), const SupportScreen()));
      await pumpN(t);
      final crisis = t.getTopLeft(find.byKey(const Key('support-crisis')));
      final form = t.getTopLeft(find.byKey(const Key('support-topic')));
      expect(crisis.dy, lessThan(form.dy));
      expect(find.text('Priority response (demo)'), plus ? findsOneWidget : findsNothing);
      await t.enterText(find.byKey(const Key('support-message')), 'How do I export?');
      await t.tap(find.byKey(const Key('support-send')));
      await pumpN(t);
      expect(find.text('Priority (demo)'), plus ? findsOneWidget : findsNothing);
      if (!plus) expect(find.text('Standard'), findsOneWidget);
      await t.tap(find.byKey(const Key('support-crisis')));
      await pumpN(t);
      expect(find.text('CRISIS'), findsOneWidget);
    }
  });

  testWidgets('consultant: SAMPLE label; free → upsell, Plus → demo booking', (t) async {
    t.view.physicalSize = const Size(1080, 2340);
    t.view.devicePixelRatio = 2.75;
    addTearDown(t.view.reset);
    final c = sampleConsultants.first;
    final book = GoRoute(path: '/consult/book/:id', builder: (_, __) => const Scaffold(body: Text('BOOKING')));
    for (final plus in [false, true]) {
      await t.pumpWidget(const SizedBox());
      await t.pumpWidget(app(plus ? seeded(plus: true) : MemStore(), ConsultantProfileScreen(c: c), extra: [book]));
      await pumpN(t);
      await t.scrollUntilVisible(find.byKey(const Key('consult-book')), 200, scrollable: find.byType(Scrollable).first);
      expect(find.text('SAMPLE expert, demo booking. Not a substitute for medical care.'), findsOneWidget);
      await t.tap(find.byKey(const Key('consult-book')));
      await pumpN(t, 6);
      expect(find.byKey(const Key('plus-upsell')), plus ? findsNothing : findsOneWidget);
      expect(find.text('BOOKING'), plus ? findsOneWidget : findsNothing);
    }
  });
}
