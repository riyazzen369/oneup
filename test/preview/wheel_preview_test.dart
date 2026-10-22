// Renders a preview PNG of the Home wheel layout. Run: flutter test test/preview --dart-define=PREVIEW_OUT=/workspace/wheel_preview.png
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oneup/core/theme/app_colors.dart';
import 'package:oneup/core/widgets/fx.dart';
import 'package:oneup/features/results/wellness_wheel.dart';

const out = String.fromEnvironment('PREVIEW_OUT');

Future<void> _font(String family, List<String> files) async {
  final l = FontLoader(family);
  final dir = '${Platform.environment['HOME']}/flutter/bin/cache/artifacts/material_fonts';
  for (final f in files) {
    l.addFont(Future.value(ByteData.sublistView(File('$dir/$f').readAsBytesSync())));
  }
  await l.load();
}

void main() {
  testWidgets('wheel preview', (t) async {
    await t.runAsync(() async {
      await _font('Roboto', ['Roboto-Regular.ttf', 'Roboto-Medium.ttf', 'Roboto-Bold.ttf', 'Roboto-Black.ttf']);
      await _font('MaterialIcons', ['MaterialIcons-Regular.otf']);
    });
    t.view.physicalSize = const Size(1080, 1500);
    t.view.devicePixelRatio = 3;
    addTearDown(t.view.reset);
    final key = GlobalKey();
    final theme = ThemeData(colorSchemeSeed: AppColors.primary, fontFamily: 'Roboto', useMaterial3: true);
    const scores = {
      WellnessDimension.emotional: 62,
      WellnessDimension.physical: 78,
      WellnessDimension.occupational: 45,
      WellnessDimension.social: 84,
      WellnessDimension.spiritual: 56,
      WellnessDimension.intellectual: 71,
      WellnessDimension.environmental: 66,
      WellnessDimension.financial: 38,
    };
    await t.pumpWidget(MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: theme,
      home: RepaintBoundary(
        key: key,
        child: Scaffold(
          body: MeshBackground(
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: LayoutBuilder(builder: (context, c) {
                  final tt = Theme.of(context).textTheme;
                  return Column(children: [
                    Align(
                        alignment: Alignment.centerLeft,
                        child: Text('OneUp', style: tt.headlineMedium?.copyWith(fontWeight: FontWeight.w800))),
                    const SizedBox(height: 8),
                    Text('Overall wellness', style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surface,
                          shape: BoxShape.circle,
                          boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.25), blurRadius: 36, spreadRadius: 2)]),
                      child: WellnessWheel(scores: scores, overall: 63, size: c.maxWidth - 36, labelFontFamily: 'Roboto'),
                    ),
                    const SizedBox(height: 10),
                    Text('Developing',
                        style: tt.titleSmall?.copyWith(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w700)),
                  ]);
                }),
              ),
            ),
          ),
        ),
      ),
    ));
    await t.pump(const Duration(seconds: 3));
    if (out.isEmpty) return;
    await t.runAsync(() async {
      final b = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final img = await b.toImage(pixelRatio: 3);
      final png = await img.toByteData(format: ui.ImageByteFormat.png);
      File(out).writeAsBytesSync(png!.buffer.asUint8List());
    });
  });
}
