// Renders Daily Ritual previews into PREVIEW_DIR (e.g. /workspace/phase3) when set.
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:oneup/core/services/haptics.dart';
import 'package:oneup/core/services/secure_store.dart';
import 'package:oneup/core/theme/app_colors.dart';
import 'package:oneup/features/assess/data/answer_crypto.dart';
import 'package:oneup/features/assess/data/assessment_models.dart';
import 'package:oneup/features/assess/data/assessment_repository.dart';
import 'package:oneup/features/assess/domain/assessment_controller.dart';
import 'package:oneup/features/home/home_page.dart';
import 'package:oneup/features/quick/quick_check.dart';
import 'package:oneup/features/quick/quick_check_screen.dart';
import 'package:oneup/features/ritual/ritual.dart';
import 'package:oneup/features/ritual/today_card.dart';
import 'package:oneup/features/profile/profile_page.dart';
import '../mem_store.dart';

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

const _quickJson =
    '[{"takenAt":"2026-11-02T10:00:00.000","scores":{"emotional":56,"physical":67,"occupational":44,"social":78,"spiritual":56,"intellectual":89,"environmental":67,"financial":22}}]';

Future<void> shot(WidgetTester t, String loc, String name,
    {Map<WellnessDimension, int> full = const {},
    double scroll = 0,
    String ritual = '',
    String settings = '{"popup":false}',
    Future<void> Function()? act}) async {
  t.view.physicalSize = const Size(1080, 2340);
  t.view.devicePixelRatio = 2.75;
  addTearDown(t.view.reset);
  final store = MemStore()
    ..m['welcome_shown_v1'] = 'x'
    ..m['ritual_settings_v1'] = settings
    ..m[QuickCheckRepository.key] = _quickJson;
  if (ritual.isNotEmpty) store.m[RitualController.key] = ritual;
  _Seeded? ctl;
  final key = GlobalKey();
  final r = GoRouter(initialLocation: loc, routes: [
    GoRoute(path: '/home', builder: (_, __) => const HomePage()),
    GoRoute(
        path: '/today',
        builder: (_, __) => const Scaffold(body: SafeArea(child: SingleChildScrollView(padding: EdgeInsets.all(16), child: TodayCard())))),
    GoRoute(path: '/profile', builder: (_, __) => const ProfilePage()),
    GoRoute(path: '/quick', builder: (_, __) => const QuickCheckScreen()),
    GoRoute(path: '/quick/result', builder: (_, __) => const QuickResultScreen()),
  ]);
  await t.pumpWidget(ProviderScope(
    key: UniqueKey(),
    overrides: [
      assessmentProvider.overrideWith((ref) => ctl = _Seeded(store)),
      secureStoreProvider.overrideWithValue(store),
      ritualClockProvider.overrideWithValue(() => DateTime(2026, 11, 2, 9)),
    ],
    child: RepaintBoundary(key: key, child: MaterialApp.router(debugShowCheckedModeBanner: false, theme: theme, routerConfig: r)),
  ));
  await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
  ctl?.seed(AssessState(cycleStart: DateTime(2026), attempts: [
    for (final e in full.entries) DimAttempt(id: e.key.name, dimension: e.key, score: e.value, completedAt: DateTime(2026, 10, 30)),
  ]));
  for (var i = 0; i < 30; i++) {
    await t.pump(const Duration(milliseconds: 100));
  }
  if (act != null) {
    await act();
    for (var i = 0; i < 10; i++) {
      await t.pump(const Duration(milliseconds: 100));
    }
  }
  if (scroll > 0) {
    await t.drag(find.byType(Scrollable).first, Offset(0, -scroll));
    for (var i = 0; i < 10; i++) {
      await t.pump(const Duration(milliseconds: 100));
    }
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
  setUp(() => Haptics.enabled = false);
  testWidgets('ritual previews', (t) async {
    await t.runAsync(() async {
      await _font('Roboto', ['Roboto-Regular.ttf', 'Roboto-Medium.ttf', 'Roboto-Bold.ttf', 'Roboto-Black.ttf']);
      await _font('MaterialIcons', ['MaterialIcons-Regular.otf']);
    });
    const week =
        '{"2026-10-28":{"mood":"okay","done":true,"swaps":0},"2026-10-29":{"mood":"good","done":false,"swaps":0},"2026-10-30":{"mood":"meh","done":true,"swaps":0},"2026-10-31":{"mood":"great","done":true,"swaps":0},"2026-11-01":{"mood":"good","done":false,"swaps":0}}';
    const done =
        '{"2026-10-28":{"mood":"okay","done":true,"swaps":0},"2026-10-29":{"mood":"good","done":false,"swaps":0},"2026-10-30":{"mood":"meh","done":true,"swaps":0},"2026-10-31":{"mood":"great","done":true,"swaps":0},"2026-11-01":{"mood":"good","done":false,"swaps":0},"2026-11-02":{"mood":"good","tag":"focused","done":true,"swaps":1}}';
    await shot(t, '/home', 'ritual_1_home.png',
        ritual: week,
        scroll: 700,
        full: const {WellnessDimension.emotional: 64, WellnessDimension.physical: 72, WellnessDimension.social: 81});
    await shot(t, '/today', 'ritual_2_today_open.png', ritual: week);
    await shot(t, '/today', 'ritual_3_low_mood_support.png', ritual: week, act: () => t.tap(find.byKey(const Key('mood-low'))));
    await shot(t, '/today', 'ritual_4_done_streak.png', ritual: done);
    const full = {WellnessDimension.emotional: 64, WellnessDimension.physical: 72, WellnessDimension.social: 81};
    await shot(t, '/home', 'ritual_popup_1_sheet.png', ritual: week, settings: '{}', full: full);
    await shot(t, '/home', 'ritual_popup_2_checked_in.png', ritual: week, settings: '{}', full: full, act: () async {
      await t.tap(find.descendant(of: find.byKey(const Key('ritual-sheet')), matching: find.byKey(const Key('mood-good'))));
      await t.pump(const Duration(milliseconds: 100));
      await t.tap(find.descendant(of: find.byKey(const Key('ritual-sheet')), matching: find.byKey(const Key('today-task-done'))));
    });
    await shot(t, '/profile', 'ritual_popup_3_profile_settings.png',
        settings: '{"popup":true,"notify":true,"hour":9,"minute":0}',
        act: () => t.scrollUntilVisible(find.byKey(const Key('ritual-time')), 200, scrollable: find.byType(Scrollable).first));
  });
}
