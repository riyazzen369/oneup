// Renders Weekly report previews into PREVIEW_DIR (e.g. /workspace/phase3) when set.
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
import 'package:oneup/features/activity/activity.dart';
import 'package:oneup/features/report/report_screen.dart';
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
    Future<void> Function()? act,
    String activity = '',
    int pumps = 30,
    DateTime? at}) async {
  t.view.physicalSize = const Size(1080, 2340);
  t.view.devicePixelRatio = 2.75;
  addTearDown(t.view.reset);
  final store = MemStore()
    ..m['welcome_shown_v1'] = 'x'
    ..m['ritual_settings_v1'] = settings
    ..m[QuickCheckRepository.key] = _quickJson;
  if (ritual.isNotEmpty) store.m[RitualController.key] = ritual;
  if (activity.isNotEmpty) store.m[ActivityController.key] = activity;
  final clock = at ?? DateTime(2026, 11, 1, 19, 30);
  _Seeded? ctl;
  final key = GlobalKey();
  final r = GoRouter(initialLocation: loc, routes: [
    GoRoute(path: '/home', builder: (_, __) => const HomePage()),
    GoRoute(
        path: '/today',
        builder: (_, __) => const Scaffold(body: SafeArea(child: SingleChildScrollView(padding: EdgeInsets.all(16), child: TodayCard())))),
    GoRoute(path: '/report', builder: (_, __) => const ReportScreen()),
    GoRoute(path: '/profile', builder: (_, __) => const ProfilePage()),
    GoRoute(path: '/quick', builder: (_, __) => const QuickCheckScreen()),
    GoRoute(path: '/quick/result', builder: (_, __) => const QuickResultScreen()),
  ]);
  await t.pumpWidget(ProviderScope(
    key: UniqueKey(),
    overrides: [
      assessmentProvider.overrideWith((ref) => ctl = _Seeded(store)),
      secureStoreProvider.overrideWithValue(store),
      ritualClockProvider.overrideWithValue(() => clock),
    ],
    child: RepaintBoundary(key: key, child: MaterialApp.router(debugShowCheckedModeBanner: false, theme: theme, routerConfig: r)),
  ));
  await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
  ctl?.seed(AssessState(cycleStart: DateTime(2026), attempts: [
    for (final e in full.entries) DimAttempt(id: e.key.name, dimension: e.key, score: e.value, completedAt: DateTime(2026, 10, 30)),
  ]));
  for (var i = 0; i < pumps; i++) {
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

String _e(String d, String k, String at, String r) => '{"d":"$d","k":"$k","at":"$at","r":"$r"}';

void main() {
  setUp(() => Haptics.enabled = false);
  testWidgets('weekly report previews', (t) async {
    await t.runAsync(() async {
      await _font('Roboto', ['Roboto-Regular.ttf', 'Roboto-Medium.ttf', 'Roboto-Bold.ttf', 'Roboto-Black.ttf']);
      await _font('MaterialIcons', ['MaterialIcons-Regular.otf']);
    });
    // SAMPLE week Mon Oct 26 – Sun Nov 1 2026.
    const days =
        '{"2026-10-25":{"mood":"okay","done":true,"swaps":0},"2026-10-26":{"mood":"meh","done":true,"swaps":0},"2026-10-27":{"mood":"okay","done":false,"swaps":0},"2026-10-29":{"mood":"good","done":true,"swaps":0},"2026-10-30":{"mood":"good","done":true,"swaps":0},"2026-10-31":{"mood":"great","done":true,"swaps":0},"2026-11-01":{"mood":"great","done":true,"swaps":0}}';
    final act = '{"events":[${[
      _e('social', 'ritual', '2026-10-26T09:00:00.000', 'ritual:2026-10-26'),
      _e('social', 'game', '2026-10-28T09:00:00.000', 'game:g1:2026-10-28'),
      _e('social', 'lesson', '2026-10-29T09:00:00.000', 'lesson:l1:social'),
      _e('emotional', 'lesson', '2026-10-29T09:00:00.000', 'lesson:l1:emotional'),
      _e('emotional', 'ritual', '2026-10-30T09:00:00.000', 'ritual:2026-10-30'),
      _e('physical', 'game', '2026-10-31T09:00:00.000', 'game:g2:2026-10-31'),
    ].join(',')}],"seen":"2026-11-01T19:00:00.000"}';
    final full = {WellnessDimension.emotional: 64, WellnessDimension.physical: 72, WellnessDimension.social: 81};
    Future<void> page(String name, int n) => shot(t, '/report', name, ritual: days, activity: act, full: full, act: () async {
          for (var i = 0; i < n; i++) {
            await t.tap(find.byKey(const Key('report-next')));
            for (var j = 0; j < 5; j++) {
              await t.pump(const Duration(milliseconds: 100));
            }
          }
        });
    await shot(t, '/home', 'report_0_home_card.png', ritual: days, activity: act, full: full, scroll: 900);
    await page('report_1_overview.png', 0);
    await page('report_2_most_active.png', 1);
    await page('report_3_learn_play.png', 2);
    await page('report_4_scores.png', 3);
    await page('report_5_focus.png', 4);
    await shot(t, '/report', 'report_6_privacy_note.png', ritual: days, activity: act, full: full, act: () async {
      await t.tap(find.byKey(const Key('report-share')));
    });
    await shot(t, '/report', 'report_7_empty_week.png');
  });
}
