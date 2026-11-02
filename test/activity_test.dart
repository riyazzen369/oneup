import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:oneup/core/services/haptics.dart';
import 'package:oneup/core/services/secure_store.dart';
import 'package:oneup/core/theme/app_colors.dart';
import 'package:oneup/features/activity/activity.dart';
import 'package:oneup/features/home/home_page.dart';
import 'package:oneup/features/results/wellness_wheel.dart';
import 'package:oneup/features/ritual/ritual.dart';
import 'mem_store.dart';

void main() {
  setUp(() => Haptics.enabled = false);
  final now = DateTime(2026, 11, 2, 12);
  ActivityEvent ev(WellnessDimension d, Duration ago, [String r = 'x']) => ActivityEvent(d, ActivityKind.game, now.subtract(ago), r);

  test('glow decays linearly to zero over 7 days and saturates at 1', () {
    expect(activityGlow([ev(WellnessDimension.social, Duration.zero)], now)[WellnessDimension.social], closeTo(1 / 3, 1e-6));
    expect(activityGlow([ev(WellnessDimension.social, const Duration(days: 7) ~/ 2)], now)[WellnessDimension.social], closeTo(1 / 6, 1e-3));
    expect(activityGlow([ev(WellnessDimension.social, const Duration(days: 7))], now), isEmpty);
    expect(
        activityGlow([for (var i = 0; i < 6; i++) ev(WellnessDimension.physical, Duration(minutes: i))], now)[WellnessDimension.physical],
        1.0);
    expect(activityGlow([ev(WellnessDimension.social, const Duration(hours: -1))], now), isEmpty); // future ignored
  });

  test('log dedupes by ref, unlog removes, persists encrypted store, prunes old events, tracks unseen', () async {
    final store = MemStore();
    var t = now;
    final c = ActivityController(store, clock: () => t);
    expect(await c.log(WellnessDimension.social, ActivityKind.ritual, ritualRef(now)), isTrue);
    expect(await c.log(WellnessDimension.social, ActivityKind.ritual, ritualRef(now)), isFalse);
    expect(c.state.unseen?.dimension, WellnessDimension.social);
    await c.markSeen();
    expect(c.state.unseen, isNull);
    await c.log(WellnessDimension.financial, ActivityKind.lesson, lessonRef('l1', WellnessDimension.financial));
    await c.unlog(lessonRef('l1', WellnessDimension.financial));
    expect(c.state.events.length, 1);
    expect(store.m[ActivityController.key], isNotNull);
    final c2 = ActivityController(store, clock: () => t);
    await c2.ready;
    expect(c2.state.events.single.ref, ritualRef(now));
    expect(c2.state.unseen, isNull);
    t = now.add(const Duration(days: 8));
    await c2.log(WellnessDimension.physical, ActivityKind.game, gameRef('g', t));
    expect(c2.state.events.map((e) => e.dimension), [WellnessDimension.physical]);
  });

  testWidgets('Home wheel glows the active slice, keeps scores and Quick dashes, shows a +1 badge once', (t) async {
    t.view.physicalSize = const Size(412, 915) * 3;
    t.view.devicePixelRatio = 3;
    addTearDown(t.view.reset);
    final store = MemStore()
      ..m['welcome_shown_v1'] = 'x'
      ..m['ritual_settings_v1'] = '{"popup":false}'
      ..m['quick_check_v1'] =
          '[{"takenAt":"2026-11-01T10:00:00.000","scores":{"emotional":60,"physical":60,"occupational":60,"social":60,"spiritual":60,"intellectual":60,"environmental":60,"financial":10}}]'
      ..m[ActivityController.key] = '{"events":[{"d":"social","k":"ritual","at":"2026-11-02T11:00:00.000","r":"ritual:2026-11-02"}]}';
    final c =
        ProviderContainer(overrides: [secureStoreProvider.overrideWithValue(store), ritualClockProvider.overrideWithValue(() => now)]);
    addTearDown(c.dispose);
    final r = GoRouter(initialLocation: '/home', routes: [GoRoute(path: '/home', builder: (_, __) => const HomePage())]);
    await t.pumpWidget(UncontrolledProviderScope(container: c, child: MaterialApp.router(routerConfig: r)));
    for (var i = 0; i < 10; i++) {
      await t.pump(const Duration(milliseconds: 100));
    }
    final w = t.widget<WellnessWheel>(find.byType(WellnessWheel).first);
    expect(w.glow.keys, [WellnessDimension.social]);
    expect(w.pulse, WellnessDimension.social);
    expect(w.scores[WellnessDimension.social], 60); // activity never changes scores
    expect(w.estimated.length, 8);
    expect(find.text('Social +1'), findsOneWidget);
    expect(find.byKey(const Key('home-activity-legend')), findsOneWidget);
    for (var i = 0; i < 30; i++) {
      await t.pump(const Duration(milliseconds: 100));
    }
    expect(find.text('Social +1'), findsNothing);
    expect(c.read(activityProvider).unseen, isNull); // celebrated once
  });
}
