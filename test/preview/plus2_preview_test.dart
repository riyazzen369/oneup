// Renders OneUP Plus services previews (plus2_*) into PREVIEW_DIR (e.g. /workspace/phase3) when set.
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
import 'package:oneup/features/plus/plus_ui.dart';
import 'package:oneup/features/games/games_page.dart';
import 'package:oneup/features/learn/learn_models.dart';
import 'package:oneup/features/learn/learn_repository.dart';
import 'package:oneup/features/learn/lesson_reader.dart';
import 'package:oneup/features/results/trends_screen.dart';
import 'dart:convert';
import 'package:oneup/features/plus/services.dart';
import 'package:oneup/features/report/monthly_report.dart';
import 'package:oneup/features/report/weekly_report.dart';
import 'package:oneup/features/market/market_page.dart';
import 'package:oneup/features/consult/data/consult_models.dart';
import 'package:oneup/features/consult/ui/consultant_profile_screen.dart';
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

final _lib = LearnLibrary.fromJson(jsonDecode(File('assets/content/learn.json').readAsStringSync()) as Map<String, dynamic>);

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
    String ent = '',
    Map<String, String> extraStore = const {},
    List<DimAttempt>? attempts,
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
  if (ent.isNotEmpty) store.m['plus_entitlement_v1'] = ent;
  store.m.addAll(extraStore);
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
    GoRoute(path: '/plus', builder: (_, __) => const PlusScreen()),
    GoRoute(path: '/reports', builder: (_, s) => ReportsDashboard(monthly: s.uri.queryParameters['view'] == 'monthly')),
    GoRoute(path: '/coaching', builder: (_, __) => const CoachingScreen()),
    GoRoute(path: '/support', builder: (_, __) => const SupportScreen()),
    GoRoute(path: '/market', builder: (_, __) => const MarketPage()),
    GoRoute(path: '/consult', builder: (_, __) => const Scaffold()),
    GoRoute(path: '/consult/c/:id', builder: (_, __) => ConsultantProfileScreen(c: sampleConsultants.first)),
    GoRoute(path: '/games', builder: (_, __) => const GamesPage()),
    GoRoute(path: '/trends', builder: (_, __) => const TrendsScreen()),
    GoRoute(path: '/learn/:id', builder: (_, s) => LessonReader(id: s.pathParameters['id']!)),
    GoRoute(path: '/quick', builder: (_, __) => const QuickCheckScreen()),
    GoRoute(path: '/quick/result', builder: (_, __) => const QuickResultScreen()),
  ]);
  await t.pumpWidget(ProviderScope(
    key: UniqueKey(),
    overrides: [
      assessmentProvider.overrideWith((ref) => ctl = _Seeded(store)),
      secureStoreProvider.overrideWithValue(store),
      ritualClockProvider.overrideWithValue(() => clock),
      learnLibraryProvider.overrideWith((_) async => _lib),
    ],
    child: RepaintBoundary(key: key, child: MaterialApp.router(debugShowCheckedModeBanner: false, theme: theme, routerConfig: r)),
  ));
  await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
  ctl?.seed(AssessState(
      cycleStart: DateTime(2026),
      attempts: attempts ??
          [
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

WeeklyReport _wk(int m, int d, int r, int c, int s, Map<WellnessDimension, int> a, List<Mood?> moods) =>
    WeeklyReport(weekStart: DateTime(2026, m, d), ritualsDone: r, checkIns: c, streak: s, moods: moods, active: a, lessons: 1, games: 2);

void main() {
  setUp(() => Haptics.enabled = false);
  testWidgets('plus services previews', (t) async {
    await t.runAsync(() async {
      await _font('Roboto', ['Roboto-Regular.ttf', 'Roboto-Medium.ttf', 'Roboto-Bold.ttf', 'Roboto-Black.ttf']);
      await _font('MaterialIcons', ['MaterialIcons-Regular.otf']);
    });
    final at = DateTime(2026, 11, 2, 11);
    const trial = '{"plan":"trial","start":"2026-11-02T10:00:00.000","exp":"2026-11-09T10:00:00.000","cancelled":false,"trialUsed":true}';
    const g = Mood.good, o = Mood.okay, gr = Mood.great, me = Mood.meh;
    final weeks = [
      _wk(10, 26, 5, 6, 4, {WellnessDimension.social: 3, WellnessDimension.emotional: 2, WellnessDimension.physical: 1},
          [me, o, null, g, g, gr, gr]),
      _wk(10, 19, 4, 5, 3, {WellnessDimension.emotional: 2, WellnessDimension.intellectual: 2}, [o, o, g, null, g, null, o]),
      _wk(10, 12, 3, 4, 2, {WellnessDimension.physical: 2}, [null, me, o, o, null, g, null]),
      _wk(10, 5, 2, 3, 2, {WellnessDimension.social: 1}, [o, null, null, me, null, o, null]),
      _wk(9, 28, 1, 2, 1, {}, [null, null, o, null, null, me, null]),
    ];
    final reports = {
      ReportsController.key: jsonEncode({
        'reports': [for (final w in weeks) w.toJson()],
        'seen': '2026-10-26'
      })
    };
    final full = {
      WellnessDimension.emotional: 64,
      WellnessDimension.physical: 72,
      WellnessDimension.social: 81,
      WellnessDimension.financial: 38,
      WellnessDimension.environmental: 52
    };
    await shot(t, '/plus', 'plus2_1_comparison.png', at: at, scroll: 180);
    await shot(t, '/profile', 'plus2_2_profile_services.png', at: at, scroll: 250);
    await shot(t, '/reports', 'plus2_3_reports_weekly_free.png', at: at, extraStore: reports);
    await shot(t, '/reports', 'plus2_4_reports_monthly_free.png', at: at, extraStore: reports, act: () async {
      await t.tap(find.text('Monthly'));
    });
    await shot(t, '/reports?view=monthly', 'plus2_5_reports_monthly_plus.png', at: at, extraStore: reports, ent: trial);
    await shot(t, '/coaching', 'plus2_6_coaching_free.png', at: at);
    await shot(t, '/coaching', 'plus2_7_coaching_slot_picker.png', at: at, ent: trial, act: () async {
      await t.tap(find.byKey(const Key('coach-emotional-book')));
      for (var i = 0; i < 6; i++) {
        await t.pump(const Duration(milliseconds: 100));
      }
      await t.tap(find.byKey(const Key('slot-1')));
    });
    await shot(t, '/support', 'plus2_8_support_plus.png', at: at, ent: trial, act: () async {
      await t.enterText(find.byKey(const Key('support-message')), 'SAMPLE: how do I export my reports?');
      await t.tap(find.byKey(const Key('support-send')));
      await t.pump(const Duration(seconds: 5));
    });
    await shot(t, '/support', 'plus2_9_support_free.png', at: at);
    Future<void> toPicked() async {
      await t.scrollUntilVisible(find.byKey(const Key('market-picked')), 300, scrollable: find.byType(Scrollable).first);
      await t.ensureVisible(find.byKey(const Key('market-picked')));
      await t.pump();
      await t.drag(find.byType(Scrollable).first, const Offset(0, 120));
    }

    await shot(t, '/market', 'plus2_10_market_picked_plus.png', at: at, full: full, ent: trial, act: toPicked);
    await shot(t, '/market', 'plus2_11_market_picked_free.png', at: at, full: full, act: toPicked);
    await shot(t, '/consult/c/x', 'plus2_12_consultant_free.png', at: at, scroll: 600);
  });
}
