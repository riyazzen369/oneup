import 'package:flutter/material.dart';
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
  return ArcadeScreen(info: gameById(id), create: () => createGame(id));
}
