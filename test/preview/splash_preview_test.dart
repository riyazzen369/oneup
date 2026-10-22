// Renders splash_preview.png when PREVIEW_DIR is set.
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oneup/core/widgets/stellar_agents_logo.dart';
import 'package:oneup/features/splash/splash_screen.dart';

const dir = String.fromEnvironment('PREVIEW_DIR');

void main() {
  testWidgets('splash view renders wheel + wordmark', (t) async {
    final l = FontLoader('Roboto');
    final d = '${Platform.environment['HOME']}/flutter/bin/cache/artifacts/material_fonts';
    for (final f in ['Roboto-Regular.ttf', 'Roboto-Light.ttf', 'Roboto-Thin.ttf', 'Roboto-Bold.ttf']) {
      final file = File('$d/$f');
      if (file.existsSync()) l.addFont(Future.value(ByteData.sublistView(file.readAsBytesSync())));
    }
    await l.load();
    t.view.physicalSize = const Size(1080, 2340);
    t.view.devicePixelRatio = 3;
    addTearDown(t.view.reset);
    await t.pumpWidget(MaterialApp(
      theme: ThemeData(fontFamily: 'Roboto', brightness: Brightness.dark),
      home: const RepaintBoundary(
        key: Key('shot'),
        child: SplashView(progress: AlwaysStoppedAnimation(1.0), turns: AlwaysStoppedAnimation(0.0)),
      ),
    ));
    expect(find.byType(StellarWheel), findsOneWidget);
    expect(find.text('Created by Stellar Agents'), findsOneWidget);
    if (dir.isEmpty) return;
    await t.runAsync(() async {
      final b = t.renderObject<RenderRepaintBoundary>(find.byKey(const Key('shot')));
      final img = await b.toImage(pixelRatio: 3);
      final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
      File('$dir/splash_preview.png').writeAsBytesSync(bytes!.buffer.asUint8List());
    });
  });
}
