import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../plus/entitlement.dart';
import '../plus/plus_ui.dart';
import 'arcade.dart';
import 'arcade_screen.dart';
import 'catch_games.dart';
import 'fly_games.dart';
import 'more_games.dart';
import 'game_catalog.dart';
import 'puzzle_games.dart';
import 'sort_games.dart';

Arcade createGame(String id) => switch (id) {
      'mood-catcher' => MoodCatcher(),
      'breath-runner' => BreathRunner(),
      'task-sort' => TaskSort(),
      'connect-friends' => ConnectFriends(),
      'zen-lantern' => ZenLantern(),
      'memory-flip' => MemoryFlip(),
      'eco-sort-rush' => EcoSortRush(),
      'coin-saver' => CoinSaver(),
      'bubble-calm' => BubbleCalm(),
      'step-jump' => StepJump(),
      'inbox-zero' => InboxZero(),
      'pass-the-smile' => PassTheSmile(),
      'balance-stones' => BalanceStones(),
      'pattern-snake' => PatternSnake(),
      'tree-planter' => TreePlanter(),
      'coin-run' => CoinRun(),
      _ => throw ArgumentError('Unknown game $id'),
    };

Widget gameScreen(String id) {
  if (!games.any((g) => g.id == id)) return const Scaffold(body: Center(child: Text('Game not found')));
  if (!isPlusGame(id)) return ArcadeScreen(info: gameById(id), create: () => createGame(id));
  return Consumer(
    builder: (_, ref, __) => ref.watch(isPlusProvider)
        ? ArcadeScreen(info: gameById(id), create: () => createGame(id))
        : Scaffold(
            appBar: AppBar(title: Text(gameById(id).title)),
            body: const Padding(
              padding: EdgeInsets.all(16),
              child: PlusLockCard(
                  feature: PlusFeature.extraGames, message: 'This game is one of 8 extras in OneUP Plus. All 8 core games stay free.'),
            ),
          ),
  );
}
