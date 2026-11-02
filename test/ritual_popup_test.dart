import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:oneup/core/safety/safety_state.dart';
import 'package:oneup/core/services/haptics.dart';
import 'package:oneup/core/services/secure_store.dart';
import 'package:oneup/core/theme/app_colors.dart';
import 'package:oneup/features/home/home_page.dart';
import 'package:oneup/features/profile/profile_page.dart';
import 'package:oneup/features/ritual/ritual.dart';
import 'package:oneup/features/ritual/ritual_reminders.dart';
import 'package:oneup/features/ritual/ritual_settings.dart';
import 'mem_store.dart';

class FakeReminders extends RitualReminders {
  List<PlannedReminder> last = [];
  int permissionAsks = 0, cancels = 0;
  @override
  Future<bool> requestPermission() async {
    permissionAsks++;
    return true;
  }

  @override
  Future<void> replaceAll(List<PlannedReminder> plan) async => last = plan;
  @override
  Future<void> cancelAll() async {
    cancels++;
    last = [];
  }
}

WellnessDimension _d(DateTime _) => WellnessDimension.social;

void main() {
  setUp(() => Haptics.enabled = false);

  group('planReminders', () {
    test('default 9:00, next 7 days, today included before 9', () {
      final p = planReminders(now: DateTime(2026, 11, 2, 7), settings: const RitualSettings(), todayComplete: false, dimensionFor: _d);
      expect(p.length, 7);
      expect(p.first.at, DateTime(2026, 11, 2, 9));
      expect(p.last.at, DateTime(2026, 11, 8, 9));
      expect(p.first.body, contains('Social'));
      expect(reminderTitle, contains('1-minute OneUP ritual'));
    });
    test('skips today when time passed or ritual complete', () {
      expect(
          planReminders(now: DateTime(2026, 11, 2, 10), settings: const RitualSettings(), todayComplete: false, dimensionFor: _d).first.at,
          DateTime(2026, 11, 3, 9));
      final done = planReminders(now: DateTime(2026, 11, 2, 7), settings: const RitualSettings(), todayComplete: true, dimensionFor: _d);
      expect(done.length, 6);
      expect(done.first.at, DateTime(2026, 11, 3, 9));
    });
    test('custom time, month rollover, disabled', () {
      final p = planReminders(
          now: DateTime(2026, 11, 29, 21), settings: const RitualSettings(hour: 20, minute: 30), todayComplete: false, dimensionFor: _d);
      expect(p.first.at, DateTime(2026, 11, 30, 20, 30));
      expect(p[1].at, DateTime(2026, 12, 1, 20, 30));
      expect(
          planReminders(now: DateTime(2026, 11, 2), settings: const RitualSettings(notify: false), todayComplete: false, dimensionFor: _d),
          isEmpty);
    });
    test('copy makes no medical claims', () {
      final b = reminderBody(WellnessDimension.physical).toLowerCase();
      for (final w in ['cure', 'treat', 'diagnos', 'therapy', 'heal']) {
        expect(b.contains(w) || reminderTitle.toLowerCase().contains(w), isFalse);
      }
    });
  });

  test('settings persist and default sensibly', () async {
    final store = MemStore();
    final c = RitualSettingsController(store);
    await c.ready;
    expect(c.state.popup, isTrue);
    expect(c.state.notify, isTrue);
    expect((c.state.hour, c.state.minute), (9, 0));
    await c.update((s) => s.copyWith(popup: false, hour: 21, minute: 15));
    final c2 = RitualSettingsController(store);
    await c2.ready;
    expect((c2.state.popup, c2.state.hour, c2.state.minute), (false, 21, 15));
  });

  Future<(ProviderContainer, FakeReminders)> pumpHome(WidgetTester t, MemStore store, {bool crisis = false}) async {
    t.view.physicalSize = const Size(412, 915) * 3;
    t.view.devicePixelRatio = 3;
    addTearDown(t.view.reset);
    final fake = FakeReminders();
    final c = ProviderContainer(overrides: [
      secureStoreProvider.overrideWithValue(store),
      ritualRemindersProvider.overrideWithValue(fake),
      ritualClockProvider.overrideWithValue(() => DateTime(2026, 11, 2, 8)),
    ]);
    addTearDown(c.dispose);
    if (crisis) c.read(crisisModeProvider.notifier).state = true;
    final r = GoRouter(initialLocation: '/home', routes: [GoRoute(path: '/home', builder: (_, __) => const HomePage())]);
    await t.pumpWidget(UncontrolledProviderScope(container: c, child: MaterialApp.router(routerConfig: r)));
    for (var i = 0; i < 20; i++) {
      await t.pump(const Duration(milliseconds: 100));
    }
    return (c, fake);
  }

  testWidgets('pop-up shows once per day; Later dismisses for the day', (t) async {
    final store = MemStore()..m['welcome_shown_v1'] = 'x';
    final (_, fake) = await pumpHome(t, store);
    expect(find.byKey(const Key('ritual-sheet')), findsOneWidget);
    expect(store.m[RitualSettingsController.popupDayKey], '2026-11-02');
    expect(fake.last.first.at, DateTime(2026, 11, 2, 9));
    await t.tap(find.byKey(const Key('ritual-later')));
    for (var i = 0; i < 10; i++) {
      await t.pump(const Duration(milliseconds: 100));
    }
    expect(find.byKey(const Key('ritual-sheet')), findsNothing);
    // Re-landing the same day: no pop-up.
    await t.pumpWidget(const SizedBox());
    await pumpHome(t, store);
    expect(find.byKey(const Key('ritual-sheet')), findsNothing);
  });

  testWidgets('completing the ritual in the pop-up asks permission once and skips today\'s reminder', (t) async {
    final store = MemStore()..m['welcome_shown_v1'] = 'x';
    final (_, fake) = await pumpHome(t, store);
    final sheet = find.byKey(const Key('ritual-sheet'));
    await t.tap(find.descendant(of: sheet, matching: find.byKey(const Key('mood-good'))));
    for (var i = 0; i < 5; i++) {
      await t.pump(const Duration(milliseconds: 100));
    }
    await t.tap(find.descendant(of: sheet, matching: find.byKey(const Key('today-task-done'))));
    for (var i = 0; i < 5; i++) {
      await t.pump(const Duration(milliseconds: 100));
    }
    expect(fake.permissionAsks, 1);
    expect(fake.last.first.at, DateTime(2026, 11, 3, 9));
    expect(find.text('Done for today'), findsOneWidget);
    await t.tap(find.byKey(const Key('ritual-finish')));
    for (var i = 0; i < 10; i++) {
      await t.pump(const Duration(milliseconds: 100));
    }
    expect(sheet, findsNothing);
  });

  testWidgets('no pop-up over the first-run welcome, in crisis mode, or when turned off', (t) async {
    await pumpHome(t, MemStore());
    expect(find.byKey(const Key('ritual-sheet')), findsNothing);
    await t.pumpWidget(const SizedBox());
    await pumpHome(t, MemStore()..m['welcome_shown_v1'] = 'x', crisis: true);
    expect(find.byKey(const Key('ritual-sheet')), findsNothing);
    await t.pumpWidget(const SizedBox());
    await pumpHome(
        t,
        MemStore()
          ..m['welcome_shown_v1'] = 'x'
          ..m[RitualSettingsController.key] = '{"popup":false}');
    expect(find.byKey(const Key('ritual-sheet')), findsNothing);
  });

  testWidgets('tapping the reminder opens the pop-up even if already shown today', (t) async {
    final store = MemStore()
      ..m['welcome_shown_v1'] = 'x'
      ..m[RitualSettingsController.popupDayKey] = '2026-11-02';
    final (c, _) = await pumpHome(t, store);
    expect(find.byKey(const Key('ritual-sheet')), findsNothing);
    c.read(pendingRitualPopupProvider.notifier).state = true;
    for (var i = 0; i < 10; i++) {
      await t.pump(const Duration(milliseconds: 100));
    }
    expect(find.byKey(const Key('ritual-sheet')), findsOneWidget);
    expect(c.read(pendingRitualPopupProvider), isFalse);
  });

  testWidgets('delete-my-data resets ritual settings and cancels reminders', (t) async {
    final store = MemStore()
      ..m[RitualSettingsController.key] = '{"popup":false,"notify":false,"hour":21,"minute":5}'
      ..m[RitualSettingsController.popupDayKey] = '2026-11-02';
    final fake = FakeReminders();
    late WidgetRef wr;
    final c = ProviderContainer(overrides: [secureStoreProvider.overrideWithValue(store), ritualRemindersProvider.overrideWithValue(fake)]);
    addTearDown(c.dispose);
    await t.pumpWidget(UncontrolledProviderScope(
        container: c,
        child: Consumer(builder: (_, ref, __) {
          wr = ref;
          ref.watch(ritualSettingsProvider);
          return const SizedBox();
        })));
    await c.read(ritualSettingsProvider.notifier).ready;
    expect(c.read(ritualSettingsProvider).popup, isFalse);
    await deleteMyData(wr);
    await c.read(ritualSettingsProvider.notifier).ready;
    final s = c.read(ritualSettingsProvider);
    expect((s.popup, s.notify, s.hour, s.minute), (true, true, 9, 0));
    expect(store.m.containsKey(RitualSettingsController.popupDayKey), isFalse);
    expect(fake.cancels, 1);
  });
}
