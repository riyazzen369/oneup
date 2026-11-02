import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:oneup/core/services/haptics.dart';
import 'package:oneup/core/services/secure_store.dart';
import 'package:oneup/features/games/game_catalog.dart';
import 'package:oneup/features/games/games_page.dart';
import 'package:oneup/features/learn/learn_models.dart';
import 'package:oneup/features/learn/learn_repository.dart';
import 'package:oneup/features/learn/lesson_reader.dart';
import 'package:oneup/features/plus/entitlement.dart';
import 'package:oneup/features/plus/plus_ui.dart';
import 'package:oneup/features/ritual/ritual.dart';
import 'mem_store.dart';

LearnLibrary lib() => LearnLibrary.fromJson(jsonDecode(File('assets/content/learn.json').readAsStringSync()) as Map<String, dynamic>);

void main() {
  setUp(() => Haptics.enabled = false);
  var now = DateTime(2026, 11, 2, 10);

  ProviderContainer box(MemStore s) =>
      ProviderContainer(overrides: [secureStoreProvider.overrideWithValue(s), ritualClockProvider.overrideWithValue(() => now)]);

  Future<void> pumpN(WidgetTester t, [int n = 12]) async {
    for (var i = 0; i < n; i++) {
      await t.pump(const Duration(milliseconds: 100));
    }
  }

  test('trial: 7 days, once per install, stored, then expires to Free', () async {
    now = DateTime(2026, 11, 2, 10);
    final s = MemStore();
    final c = box(s);
    final n = c.read(entitlementProvider.notifier);
    await n.ready;
    expect(c.read(isPlusProvider), isFalse);
    expect(await n.startTrial(), isTrue);
    expect(c.read(isPlusProvider), isTrue);
    expect(c.read(entitlementProvider).expiresAt, DateTime(2026, 11, 9, 10));
    expect(c.read(entitlementProvider).daysLeft(now), 7);
    expect(s.m.containsKey(EntitlementController.key), isTrue);
    expect(await n.startTrial(), isFalse);

    now = DateTime(2026, 11, 9, 11);
    final c2 = box(s);
    await c2.read(entitlementProvider.notifier).ready;
    expect(c2.read(isPlusProvider), isFalse);
    expect(c2.read(entitlementProvider).trialUsed, isTrue);
    expect(await c2.read(entitlementProvider.notifier).startTrial(), isFalse);
  });

  test('demo purchase, referral grant and cancel keep the expiry honest', () async {
    now = DateTime(2026, 11, 2);
    final c = box(MemStore());
    final n = c.read(entitlementProvider.notifier);
    await n.grantDays(10); // e.g. #17 referral
    expect(c.read(entitlementProvider).plan, PlusPlan.referral);
    expect(c.read(entitlementProvider).expiresAt, DateTime(2026, 11, 12));
    await n.demoPurchase(PlusPlan.monthly); // stacks on remaining days
    expect(c.read(entitlementProvider).expiresAt, DateTime(2026, 12, 12));
    await n.grantDays(5);
    expect(c.read(entitlementProvider).plan, PlusPlan.monthly);
    expect(c.read(entitlementProvider).expiresAt, DateTime(2026, 12, 17));
    await n.cancel();
    expect(c.read(entitlementProvider).cancelled, isTrue);
    expect(c.read(isPlusProvider), isTrue, reason: 'access continues until expiry');
    await n.resume();
    expect(c.read(entitlementProvider).cancelled, isFalse);
    final e = Entitlement.fromJson(jsonDecode(jsonEncode(c.read(entitlementProvider).toJson())) as Map<String, dynamic>);
    expect(e.expiresAt, DateTime(2026, 12, 17));
  });

  test('gating map: 8 free games (one per dimension), safety never gated', () {
    final free = games.where((g) => !isPlusGame(g.id)).toList();
    expect(free.length, freeGameCount);
    expect(free.map((g) => g.dimension).toSet().length, 8);
    final gated = PlusFeature.values.map((f) => f.title.toLowerCase()).join(' ');
    for (final w in ['crisis', 'safety', 'assessment', 'ritual', 'privacy']) {
      expect(gated.contains(w), isFalse, reason: w);
    }
    expect(alwaysFree.join(' '), contains('Crisis and safety'));
    expect(samplePriceMonthly, allOf(contains('SAMPLE'), contains('[VERIFY]')));
    expect(samplePriceYearly, allOf(contains('SAMPLE'), contains('[VERIFY]')));
  });

  Widget app(MemStore s, Widget home) {
    final r = GoRouter(routes: [
      GoRoute(path: '/', builder: (_, __) => home),
      GoRoute(path: '/plus', builder: (_, __) => const PlusScreen()),
    ]);
    return ProviderScope(
      overrides: [secureStoreProvider.overrideWithValue(s), ritualClockProvider.overrideWithValue(() => now)],
      child: MaterialApp.router(routerConfig: r),
    );
  }

  testWidgets('locked game shows soft upsell; trial from Plus screen unlocks it', (t) async {
    now = DateTime(2026, 11, 2, 10);
    t.view.physicalSize = const Size(1080, 2340);
    t.view.devicePixelRatio = 2.75;
    addTearDown(t.view.reset);
    await t.pumpWidget(app(MemStore(), const GamesPage()));
    await pumpN(t);
    final extra = games[freeGameCount];
    expect(find.byKey(Key('game-lock-${games.first.id}')), findsNothing);
    await t.scrollUntilVisible(find.byKey(Key('game-lock-${extra.id}')), 300, scrollable: find.byType(Scrollable).first);
    await t.tap(find.text(extra.title));
    await pumpN(t, 6);
    expect(find.byKey(const Key('plus-upsell')), findsOneWidget);
    await t.tap(find.byKey(const Key('upsell-see-plus')));
    await pumpN(t);
    await t.scrollUntilVisible(find.byKey(const Key('plus-always-free')), 200, scrollable: find.byType(Scrollable).first);
    expect(find.byKey(const Key('plus-always-free')), findsOneWidget);
    await t.scrollUntilVisible(find.byKey(const Key('plus-trial')), 200, scrollable: find.byType(Scrollable).first);
    await t.tap(find.byKey(const Key('plus-trial')));
    await pumpN(t);
    expect(find.byKey(const Key('plus-trial')), findsNothing);
    expect(find.byKey(const Key('plus-screen-cancel')), findsOneWidget);
    await t.pageBack();
    await pumpN(t);
    expect(find.byKey(Key('game-lock-${extra.id}')), findsNothing);
  });

  testWidgets('demo checkout flips entitlement; Profile card cancels', (t) async {
    now = DateTime(2026, 11, 2, 10);
    t.view.physicalSize = const Size(1080, 2340);
    t.view.devicePixelRatio = 2.75;
    addTearDown(t.view.reset);
    final s = MemStore();
    await t.pumpWidget(app(s, const Scaffold(body: Column(children: [PlusProfileCard(), PlusHomeBanner()]))));
    await pumpN(t);
    expect(find.text('You are on Free'), findsOneWidget);
    expect(find.byKey(const Key('home-plus-banner')), findsOneWidget);
    await t.tap(find.byKey(const Key('profile-plus')));
    await pumpN(t);
    await t.scrollUntilVisible(find.byKey(const Key('plus-buy-yearly')), 200, scrollable: find.byType(Scrollable).first);
    await t.tap(find.byKey(const Key('plus-buy-yearly')));
    await pumpN(t, 5);
    expect(find.byKey(const Key('plus-checkout')), findsOneWidget);
    await t.tap(find.byKey(const Key('plus-checkout-confirm')));
    await pumpN(t);
    await t.pageBack();
    await pumpN(t);
    expect(find.textContaining('Yearly (demo) · renews'), findsOneWidget);
    expect(find.byKey(const Key('home-plus-banner')), findsNothing);
    await t.tap(find.byKey(const Key('plus-cancel')));
    await pumpN(t, 5);
    await t.tap(find.byKey(const Key('plus-cancel-confirm')));
    await pumpN(t);
    expect(find.textContaining('cancelled, access until 02/11/2027'), findsOneWidget);
    expect(find.byKey(const Key('plus-resume')), findsOneWidget);
  });

  testWidgets('home banner dismiss persists', (t) async {
    final s = MemStore();
    await t.pumpWidget(app(s, const Scaffold(body: PlusHomeBanner())));
    await pumpN(t);
    await t.tap(find.byKey(const Key('plus-banner-dismiss')));
    await pumpN(t);
    expect(find.byKey(const Key('home-plus-banner')), findsNothing);
    await t.pumpWidget(const SizedBox());
    await t.pumpWidget(app(s, const Scaffold(body: PlusHomeBanner())));
    await pumpN(t);
    expect(find.byKey(const Key('home-plus-banner')), findsNothing);
  });

  testWidgets('long lesson: first chapter free, rest locked; sensitive lessons never locked', (t) async {
    t.view.physicalSize = const Size(1080, 2340);
    t.view.devicePixelRatio = 2.75;
    addTearDown(t.view.reset);
    final l = lib();
    final long = l.lessons.firstWhere((x) => x.body != null && x.body!.sections.length > 1 && !x.sensitive);
    Future<void> open(Lesson x, {bool plus = false}) async {
      await t.pumpWidget(ProviderScope(
        key: UniqueKey(),
        overrides: [
          secureStoreProvider.overrideWithValue(MemStore()),
          learnLibraryProvider.overrideWith((_) async => l),
          if (plus) isPlusProvider.overrideWithValue(true),
        ],
        child: MaterialApp(home: LessonReader(id: x.id)),
      ));
      await pumpN(t);
    }

    await open(long);
    Finder inList(Finder f) => find.descendant(of: find.byType(Scrollable).first, matching: f, skipOffstage: false);
    expect(inList(find.text(long.body!.sections.first.heading)), findsOneWidget);
    expect(inList(find.text(long.body!.sections[1].heading)), findsNothing);
    expect(inList(find.byKey(const Key('plus-lock-fullLessons'))), findsOneWidget);
    expect(inList(find.byKey(const Key('reader-try'))), findsOneWidget);
    await open(long, plus: true);
    expect(inList(find.byKey(const Key('plus-lock-fullLessons'))), findsNothing);
    final sens = l.lessons.where((x) => x.sensitive && x.body != null && x.body!.sections.length > 1).firstOrNull;
    if (sens != null) {
      await open(sens);
      expect(inList(find.byKey(const Key('plus-lock-fullLessons'))), findsNothing);
    }
  });
}
