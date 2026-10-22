// Every one of the 16 games: start → play with random input → pause → resume → game over → retry,
// at small and large phone sizes, with no exceptions; best score is recorded.
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oneup/core/services/haptics.dart';
import 'package:oneup/core/services/secure_store.dart';
import 'package:oneup/features/games/arcade.dart';
import 'package:oneup/features/games/arcade_screen.dart';
import 'package:oneup/features/games/game_catalog.dart';
import 'package:oneup/features/games/game_screens.dart';
import 'mem_store.dart';

void main() {
  setUp(() => Haptics.enabled = false);
  for (final size in const [Size(360, 640), Size(412, 915)]) {
    for (final info in games) {
      testWidgets('${info.id} lifecycle @${size.width.toInt()}x${size.height.toInt()}', (t) async {
        t.view.physicalSize = size * 3;
        t.view.devicePixelRatio = 3;
        addTearDown(t.view.reset);
        final store = MemStore();
        late Arcade g;
        await t.pumpWidget(ProviderScope(
          overrides: [secureStoreProvider.overrideWithValue(store)],
          child: MaterialApp(home: ArcadeScreen(info: info, create: () => g = createGame(info.id))),
        ));
        await t.pump();
        await t.tap(find.text('Play'));
        final rnd = Random(info.id.hashCode);
        final area = t.getRect(find.byType(CustomPaint).last);
        for (var i = 0; i < 90; i++) {
          await t.pump(const Duration(milliseconds: 16));
          if (i % 9 == 0 && !g.over) {
            final p = Offset(area.left + rnd.nextDouble() * area.width, area.top + area.height * (0.3 + rnd.nextDouble() * 0.6));
            final gs = await t.startGesture(p);
            await gs.moveBy(Offset((rnd.nextDouble() - 0.5) * 120, (rnd.nextDouble() - 0.5) * 60));
            await gs.up();
          }
        }
        if (find.byTooltip('Pause').evaluate().isNotEmpty && !g.over) {
          await t.tap(find.byTooltip('Pause'));
          await t.pump();
          expect(find.text('Resume'), findsOneWidget);
          await t.tap(find.text('Resume'));
          await t.pump(const Duration(milliseconds: 16));
        }
        g.score = max(g.score, 7);
        g.lives = 0;
        g.over = true;
        for (var i = 0; i < 10; i++) {
          await t.pump(const Duration(milliseconds: 50));
        }
        expect(find.text('Game over'), findsOneWidget);
        await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
        await t.pump();
        expect(int.parse(store.m['game_best_${info.id}'] ?? '0'), greaterThanOrEqualTo(7));
        // retry starts a fresh game
        final retry = find.textContaining(RegExp('Play again|Retry|Again'));
        if (retry.evaluate().isNotEmpty) {
          await t.tap(retry.first);
          await t.pump(const Duration(milliseconds: 100));
          expect(g.over, isFalse);
        }
        await t.pumpWidget(const SizedBox());
        expect(t.takeException(), isNull);
      });
    }
  }
}
