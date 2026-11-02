import 'package:oneup/features/plus/entitlement.dart';
import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oneup/core/services/haptics.dart';
import 'package:oneup/core/services/secure_store.dart';
import 'package:oneup/core/theme/app_colors.dart';
import 'package:oneup/features/games/arcade.dart';
import 'package:oneup/features/games/game_catalog.dart';
import 'package:oneup/features/games/game_scores.dart';
import 'package:oneup/features/games/game_screens.dart';
import 'package:oneup/features/games/puzzle_games.dart';
import 'package:oneup/features/games/more_games.dart';
import 'package:oneup/features/games/games_page.dart';
import 'package:go_router/go_router.dart';
import 'package:oneup/features/games/sort_games.dart';
import 'mem_store.dart';

const phone = Size(392, 800);

/// Bot input: periodically touch/drag somewhere pseudo-random, release.
void simulate(Arcade g, {double seconds = 60, int seed = 1}) {
  final r = Random(seed);
  g.resize(phone);
  var held = false;
  for (var i = 0; i < seconds * 120; i++) {
    if (i % 30 == 0) {
      final p = Offset(r.nextDouble() * phone.width, 100 + r.nextDouble() * 600);
      if (held) {
        g.pointerMove(p, Offset((r.nextDouble() - 0.5) * 40, r.nextDouble() * 10));
        g.pointerUp(p);
      } else {
        g.pointerDown(p);
      }
      held = !held;
    } else if (held && i % 3 == 0) {
      g.pointerMove(Offset(r.nextDouble() * phone.width, 400), Offset((r.nextDouble() - 0.5) * 20, 2));
    }
    g.step(1 / 120);
    if (i % 60 == 0) {
      final c = ui.PictureRecorder();
      final cv = Canvas(c);
      g.paint(cv);
      g.paintFx(cv);
      c.endRecording().dispose();
    }
  }
}

void main() {
  setUp(() => Haptics.enabled = false);

  test('two games per dimension, unique ids, all constructible', () {
    for (final d in WellnessDimension.values) {
      expect(games.where((g) => g.dimension == d).length, 2, reason: d.name);
    }
    expect(games.map((g) => g.id).toSet().length, 16);
    for (final g in games) {
      expect(createGame(g.id).tip, isNotEmpty);
    }
  });

  for (final info in games) {
    test('${info.id}: 60 s of bot play without errors, ends or keeps sane state', () {
      for (var seed = 1; seed <= 3; seed++) {
        final g = createGame(info.id)..rnd;
        simulate(g, seed: seed);
        expect(g.score, greaterThanOrEqualTo(0));
        expect(g.lives, lessThanOrEqualTo(5));
        expect(g.meter, inInclusiveRange(0, 1.5));
        expect(g.particles.length, lessThan(2000));
      }
    });
  }

  test('reduced motion: no particles', () {
    final g = createGame('mood-catcher')..fx = false;
    simulate(g, seconds: 20);
    expect(g.particles, isEmpty);
  });

  test('task sort uses urgency/importance lanes', () {
    expect(TaskSort.laneFor(urgent: true, important: true), 0);
    expect(TaskSort.laneFor(urgent: false, important: true), 1);
    expect(TaskSort.laneFor(urgent: true, important: false), 2);
    expect(TaskSort.laneFor(urgent: false, important: false), 3);
  });

  test('sorted item lands in the lane under it', () {
    final g = TaskSort(Random(3))..resize(phone);
    final it = SortItem('x', '', 1, Offset(g.laneW * 1.5, g.binTop - 1), 100);
    g.items.add(it);
    g.step(0.05);
    expect(g.score, 10);
    final bad = SortItem('y', '', 3, Offset(g.laneW * 0.5, g.binTop - 1), 100);
    g.items.add(bad);
    g.step(0.05);
    expect(g.lives, 2);
  });

  test('eco sort has every bin and hazard examples', () {
    expect(EcoSortRush.waste.map((e) => e.$3).toSet(), {0, 1, 2});
  });

  test('memory flip: match adds time and score, mismatch closes', () {
    final g = MemoryFlip(Random(2))..resize(phone);
    final a = g.cards.indexWhere((c) => c.face == 0);
    final b = g.cards.lastIndexWhere((c) => c.face == 0);
    final t0 = g.timeLeft!;
    expect(g.tapCard(a), isNull);
    expect(g.tapCard(b), isTrue);
    expect(g.score, 20);
    expect(g.timeLeft, greaterThan(t0));
    final x = g.cards.indexWhere((c) => !c.done);
    final y = g.cards.indexWhere((c) => !c.done && c.face != g.cards[x].face);
    g.tapCard(x);
    expect(g.tapCard(y), isFalse);
    g.step(1);
    expect(g.cards[x].up, isFalse);
  });

  test('memory flip clears board and grows grid', () {
    final g = MemoryFlip(Random(2))..resize(phone);
    final n = g.cards.length;
    for (var f = 0; f < n ~/ 2; f++) {
      final idx = [
        for (var i = 0; i < g.cards.length; i++)
          if (g.cards[i].face == f) i
      ];
      g.tapCard(idx[0]);
      g.tapCard(idx[1]);
    }
    expect(g.cards.length, greaterThan(n));
  });

  test('connect friends chain of 3 scores and removes bubbles', () {
    final g = ConnectFriends(Random(1))..resize(phone);
    g.bubbles
      ..clear()
      ..addAll([
        Bubble(const Offset(100, 300), Offset.zero, 0),
        Bubble(const Offset(160, 300), Offset.zero, 0),
        Bubble(const Offset(220, 300), Offset.zero, 0)
      ]);
    g.pointerDown(const Offset(100, 300));
    g.pointerMove(const Offset(160, 300), const Offset(60, 0));
    g.pointerMove(const Offset(220, 300), const Offset(60, 0));
    g.pointerUp(const Offset(220, 300));
    expect(g.score, 60);
    expect(g.bubbles, isEmpty);
  });

  testWidgets('arcade screen: play, pause, game over records best', (t) async {
    t.view.physicalSize = const Size(1080, 2340);
    t.view.devicePixelRatio = 2.75;
    addTearDown(t.view.reset);
    final s = MemStore();
    await t.pumpWidget(ProviderScope(
      overrides: [secureStoreProvider.overrideWithValue(s)],
      child: MaterialApp(home: gameScreen('memory-flip')),
    ));
    await t.pump();
    expect(find.text('Play'), findsOneWidget);
    await t.tap(find.text('Play'));
    for (var i = 0; i < 20; i++) {
      await t.pump(const Duration(milliseconds: 16));
    }
    await t.tap(find.byTooltip('Pause'));
    await t.pump();
    expect(find.text('Resume'), findsOneWidget);
    await t.tap(find.text('Resume'));
    for (var i = 0; i < 1500; i++) {
      await t.pump(const Duration(milliseconds: 33));
      if (find.text('Game over').evaluate().isNotEmpty) break;
    }
    expect(find.text('Game over'), findsOneWidget);
    expect(find.textContaining('recall'), findsOneWidget);
    await t.pump(const Duration(seconds: 1));
  });

  test('best score keeps max; persisted locally', () async {
    final s = MemStore();
    final g = GameScores(s);
    await Future<void>.delayed(Duration.zero);
    expect(await g.record('memory-grid', 5), isTrue);
    expect(await g.record('memory-grid', 3), isFalse);
    expect(g.state['memory-grid'], 5);
    await g.record('gratitude-garden', 3, accumulate: true);
    await g.record('gratitude-garden', 3, accumulate: true);
    expect(g.state['gratitude-garden'], 6);
    expect(s.m['game_best_memory-grid'], '5');
  });

  testWidgets('every game screen builds', (t) async {
    t.view.physicalSize = const Size(1080, 2340);
    t.view.devicePixelRatio = 2.75;
    addTearDown(t.view.reset);
    for (final g in games) {
      await t.pumpWidget(ProviderScope(
        key: UniqueKey(),
        overrides: [secureStoreProvider.overrideWithValue(MemStore()), isPlusProvider.overrideWithValue(true)],
        child: MaterialApp(home: gameScreen(g.id)),
      ));
      await t.pump(const Duration(milliseconds: 100));
      expect(find.text(g.title), findsOneWidget, reason: g.id);
      expect(find.text('For fun and practice. Sound off.'), findsOneWidget);
    }
    await t.pumpWidget(const SizedBox());
  });

  test('bubble calm: chain pops same colour, stress bubble costs a life', () {
    final g = BubbleCalm(Random(1))..resize(phone);
    g.bubbles
      ..clear()
      ..addAll([
        CalmBubble(const Offset(100, 300), 20, 0, 0, 0),
        CalmBubble(const Offset(140, 300), 20, 0, 0, 0),
        CalmBubble(const Offset(180, 300), 20, 0, 0, 0),
        CalmBubble(const Offset(300, 500), 20, 4, 0, 0)
      ]);
    g.pointerDown(const Offset(100, 300));
    expect(g.bubbles.length, 1);
    expect(g.score, 30);
    g.pointerDown(const Offset(300, 500));
    expect(g.lives, 2);
  });

  test('step jump: bounces off a platform and climbs', () {
    final g = StepJump(Random(1))..resize(phone);
    for (var i = 0; i < 240; i++) {
      g.step(1 / 120);
    }
    expect(g.lives, 3);
    expect(g.score, greaterThan(0));
  });

  test('inbox zero: slice spam scores, slice important hurts, tap keeps', () {
    final g = InboxZero(Random(1))..resize(phone);
    g.mails.addAll([Mail(const Offset(100, 400), Offset.zero, true, 'x'), Mail(const Offset(300, 400), Offset.zero, false, 'y')]);
    g.pointerDown(const Offset(60, 400));
    g.pointerMove(const Offset(140, 400), const Offset(80, 0));
    g.pointerUp(const Offset(140, 400));
    expect(g.score, 10);
    g.pointerDown(const Offset(300, 400));
    g.pointerUp(const Offset(300, 400));
    expect(g.score, greaterThan(10));
    expect(g.lives, 3);
    g.mails.add(Mail(const Offset(200, 600), Offset.zero, false, 'y'));
    g.pointerDown(const Offset(160, 600));
    g.pointerMove(const Offset(240, 600), const Offset(80, 0));
    expect(g.lives, 2);
  });

  test('pass the smile: aimed toss is caught', () {
    final g = PassTheSmile(Random(1))..resize(phone);
    g.amp = 0;
    g.myFreq = 0;
    g.pointerDown(Offset.zero);
    for (var i = 0; i < 120 && g.flying; i++) {
      g.step(1 / 120);
    }
    expect(g.score, greaterThan(0));
    expect(g.lives, 3);
  });

  test('balance stones: perfect drop keeps width, total miss costs a life', () {
    final g = BalanceStones(Random(1))..resize(phone);
    final w0 = g.w;
    g.x = g.stack.last.left;
    g.pointerDown(Offset.zero);
    expect(g.stack.length, 2);
    expect(g.w, w0);
    g.x = 0;
    g.w = 20;
    g.pointerDown(Offset.zero);
    expect(g.lives, 2);
  });

  test('pattern snake: eat in order, wrong order costs a life', () {
    final g = PatternSnake(Random(1))..resize(phone);
    final h = g.body.first;
    g.targets
      ..clear()
      ..[Point(h.x + 1, h.y)] = 1
      ..[Point(h.x + 2, h.y)] = 3;
    g.step(0.25);
    expect(g.score, 10);
    expect(g.want, 2);
    g.step(0.25);
    expect(g.lives, 2);
  });

  test('tree planter: plant uses a seed and grown tree clears smog', () {
    final g = TreePlanter(Random(1))..resize(phone);
    g.pointerDown(Offset(g.plotX(2), g.groundY));
    expect(g.seeds, 1);
    g.growth[2] = 1;
    g.smog.add(Smog(Offset(g.plotX(2), 200), 0, 1));
    g.spawnIn = 99;
    for (var i = 0; i < 240; i++) {
      g.step(1 / 120);
    }
    expect(g.score, greaterThan(0));
  });

  test('coin run: coins score, debt trap costs a life, tap changes lane', () {
    final g = CoinRun(Random(1))..resize(phone);
    g.spawnIn = 99;
    g.objs.add(Lane(1, g.py, 0));
    g.step(0.001);
    expect(g.score, 4);
    expect(g.saved, 2);
    g.pointerDown(const Offset(10, 400));
    g.pointerUp(const Offset(10, 400));
    expect(g.lane, 0);
    g.objs.add(Lane(0, g.py, 1));
    g.step(0.001);
    expect(g.lives, 2);
  });

  testWidgets('games grid: 16 tiles with dimension tags, filter by dimension', (t) async {
    t.view.physicalSize = const Size(1080, 2340);
    t.view.devicePixelRatio = 2.75;
    addTearDown(t.view.reset);
    final r = GoRouter(routes: [GoRoute(path: '/', builder: (_, __) => const GamesPage())]);
    await t.pumpWidget(ProviderScope(
      overrides: [secureStoreProvider.overrideWithValue(MemStore())],
      child: MaterialApp.router(routerConfig: r),
    ));
    await t.pumpAndSettle();
    expect(find.byType(GameTile), findsWidgets);
    final chip = find.descendant(of: find.byKey(const Key('game-filters')), matching: find.text('Financial'));
    await t.dragUntilVisible(
        chip, find.descendant(of: find.byKey(const Key('game-filters')), matching: find.byType(Scrollable)), const Offset(-200, 0));
    await t.pumpAndSettle();
    await t.tap(chip);
    await t.pumpAndSettle();
    expect(find.byType(GameTile), findsNWidgets(2));
    expect(find.text('Coin Saver'), findsOneWidget);
    expect(find.text('Coin Run'), findsOneWidget);
  });
}
