// Renders /workspace/home_preview.png and /workspace/radar_preview.png when PREVIEW_DIR is set.
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oneup/core/theme/app_colors.dart';
import 'package:oneup/features/assess/data/answer_crypto.dart';
import 'package:oneup/features/assess/data/assessment_repository.dart';
import 'package:oneup/features/assess/domain/assessment_controller.dart';
import 'package:oneup/features/assess/data/assessment_models.dart';
import 'package:oneup/features/home/home_page.dart';
import 'package:oneup/features/results/circle_paradigm_screen.dart';
import '../mem_store.dart';
import 'package:oneup/core/services/secure_store.dart';
import 'package:oneup/features/results/trends_screen.dart';
import 'package:oneup/features/home/welcome_dialog.dart';
import 'package:oneup/features/games/games_page.dart';
import 'package:oneup/features/learn/learn_page.dart';
import 'package:oneup/features/learn/lesson_reader.dart';
import 'package:oneup/features/market/market_page.dart';
import 'package:oneup/features/market/market_screens.dart';
import 'package:oneup/features/market/market_category.dart';

const dir = String.fromEnvironment('PREVIEW_DIR');

class _Seeded extends AssessmentController {
  _Seeded(MemStore s) : super(AssessmentRepository(s), AnswerCrypto(s));
  void seed(AssessState v) => state = v;
}

Future<void> _font(String family, List<String> files) async {
  final l = FontLoader(family);
  final d = '${Platform.environment['HOME']}/flutter/bin/cache/artifacts/material_fonts';
  for (final f in files) {
    l.addFont(Future.value(ByteData.sublistView(File('$d/$f').readAsBytesSync())));
  }
  await l.load();
}

final theme = ThemeData(
  useMaterial3: true,
  fontFamily: 'Roboto',
  colorScheme: ColorScheme.fromSeed(seedColor: AppColors.primary, brightness: Brightness.dark, surface: AppColors.darkSurface),
  scaffoldBackgroundColor: AppColors.darkBg,
);

AssessState sample() {
  const sc = [64, 72, 58, 81, 66, 74, 58, 49];
  const prev = [55, 70, 50, 77, 60, 66, 52, 45];
  final now = DateTime(2026, 10, 20);
  return AssessState(
    cycleStart: DateTime(2026, 1, 1),
    attempts: [
      for (final d in WellnessDimension.values) DimAttempt(id: 'n${d.index}', dimension: d, score: sc[d.index], completedAt: now),
      for (final d in WellnessDimension.values)
        DimAttempt(id: 'p${d.index}', dimension: d, score: prev[d.index], completedAt: now.subtract(const Duration(days: 30))),
    ],
    goals: const {WellnessDimension.environmental: 75, WellnessDimension.financial: 65, WellnessDimension.occupational: 70},
  );
}

Future<void> shot(WidgetTester t, Widget page, String name, {Size size = const Size(1080, 2340)}) async {
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 2.75;
  addTearDown(t.view.reset);
  final store = MemStore();
  _Seeded? ctl;
  final key = GlobalKey();
  await t.pumpWidget(ProviderScope(
    key: UniqueKey(),
    overrides: [
      assessmentProvider.overrideWith((ref) => ctl = _Seeded(store)),
      secureStoreProvider.overrideWithValue(store..m['welcome_shown_v1'] = 'x'),
    ],
    child: MaterialApp(debugShowCheckedModeBanner: false, theme: theme, home: RepaintBoundary(key: key, child: page)),
  ));
  await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
  ctl?.seed(sample());
  for (var i = 0; i < 30; i++) {
    await t.pump(const Duration(milliseconds: 100));
  }
  await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
  await t.pump(const Duration(milliseconds: 100));
  if (dir.isEmpty) return;
  await t.runAsync(() async {
    final b = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final img = await b.toImage(pixelRatio: 2.75);
    final png = await img.toByteData(format: ui.ImageByteFormat.png);
    File('$dir/$name').writeAsBytesSync(png!.buffer.asUint8List());
  });
}

void main() {
  setUpAll(() async {});
  testWidgets('home + radar previews', (t) async {
    await t.runAsync(() async {
      await _font('Roboto', ['Roboto-Regular.ttf', 'Roboto-Medium.ttf', 'Roboto-Bold.ttf', 'Roboto-Black.ttf']);
      await _font('MaterialIcons', ['MaterialIcons-Regular.otf']);
    });
    await shot(t, const HomePage(), 'home_preview.png');
    expect(find.text('Continue to assess'), findsOneWidget);
    await shot(t, const GamesPage(), 'games_grid_tab.png');
    expect(find.text('Mood Catcher'), findsOneWidget);
    await shot(t, const LearnPage(), 'learn_page_preview.png');
    expect(find.text('Recommended for you'), findsOneWidget);
    await shot(t, const LessonReader(id: 'ah-stacking'), 'learn_reader_preview.png');
    await shot(t, const LessonReader(id: 'ah-stacking'), 'reader_preview.png');
    await shot(t, const LessonReader(id: 'bks-connection'), 'learn_sensitive_preview.png');
    await shot(t, const MarketPage(), 'market_preview.png');
    expect(find.text('Recommended for your focus'), findsOneWidget);
    await shot(t, const ProductScreen(id: 'sp-cushion'), 'market_product_preview.png');
    await shot(t, const ProductScreen(id: 'ph-supplement'), 'market_consult_preview.png');
    await shot(t, const CircleParadigmScreen(), 'radar_preview.png');
    await shot(t, const TrendsScreen(), 'trends_preview.png');
    await shot(t, const MarketPage(), 'market_slider.png');
    await shot(t, const CategoryScreen(name: 'Yoga'), 'market_category.png');
    await shot(
        t,
        Scaffold(
            body: Stack(children: [
          const Positioned.fill(child: ColoredBox(color: Color(0xFF0E1020))),
          Container(color: Colors.black54),
          const WelcomeCard()
        ])),
        'welcome_preview.png');
  });
}
