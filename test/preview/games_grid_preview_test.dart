// Renders gameplay frames to PREVIEW_DIR/game_<id>.png (composed into games_grid.png by a script).
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oneup/core/services/haptics.dart';
import 'package:oneup/features/games/arcade.dart';
import 'package:oneup/features/games/game_screens.dart';
import '../games_test.dart' show simulate, phone;

const dir = String.fromEnvironment('PREVIEW_DIR');

Future<void> _font(String family, List<String> paths) async {
  final l = FontLoader(family);
  for (final f in paths) {
    if (File(f).existsSync()) l.addFont(Future.value(ByteData.sublistView(File(f).readAsBytesSync())));
  }
  await l.load();
}

void main() {
  testWidgets('game frames', (t) async {
    if (dir.isEmpty) return;
    await t.runAsync(() async {
      Haptics.enabled = false;
      final m = '${Platform.environment['HOME']}/flutter/bin/cache/artifacts/material_fonts';
      await _font('Roboto', ['$m/Roboto-Regular.ttf', '$m/Roboto-Medium.ttf', '$m/Roboto-Bold.ttf', '$m/Roboto-Black.ttf']);
      await _font('Emoji', ['/usr/share/fonts/truetype/noto/NotoColorEmoji.ttf']);
      Glyphs.family = 'Roboto';
      Glyphs.fallback = ['Emoji'];
      for (final id in [
        'mood-catcher',
        'breath-runner',
        'task-sort',
        'connect-friends',
        'eco-sort-rush',
        'coin-saver',
        'zen-lantern',
        'memory-flip',
        'bubble-calm',
        'step-jump',
        'inbox-zero',
        'pass-the-smile',
        'balance-stones',
        'pattern-snake',
        'tree-planter',
        'coin-run'
      ]) {
        final g = createGame(id);
        simulate(g, seconds: 9, seed: 4);
        g
          ..over = false
          ..invuln = 0;
        final rec = ui.PictureRecorder();
        final c = Canvas(rec)..scale(2);
        g.paint(c);
        g.paintFx(c);
        final img = await rec.endRecording().toImage((phone.width * 2).round(), (phone.height * 2).round());
        final png = await img.toByteData(format: ui.ImageByteFormat.png);
        File('$dir/game_$id.png').writeAsBytesSync(png!.buffer.asUint8List());
      }
    });
    Haptics.enabled = true;
  });
}
