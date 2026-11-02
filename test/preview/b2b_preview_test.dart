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
import 'package:oneup/features/market/market_page.dart';
import 'package:oneup/features/consult/data/consult_models.dart';
import 'package:oneup/features/consult/ui/consultant_profile_screen.dart';
import 'package:oneup/features/org/org_ui.dart';
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
    GoRoute(path: '/org', builder: (_, __) => const OrgDashboardScreen()),
    GoRoute(path: '/org/join', builder: (_, __) => const OrgJoinScreen()),
    GoRoute(path: '/org/demo', builder: (_, __) => const OrgDemoFormScreen()),
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

void main() {
  setUp(() => Haptics.enabled = false);
  testWidgets('b2b previews', (t) async {
    await t.runAsync(() async {
      await _font('Roboto', ['Roboto-Regular.ttf', 'Roboto-Medium.ttf', 'Roboto-Bold.ttf', 'Roboto-Black.ttf']);
      await _font('MaterialIcons', ['MaterialIcons-Regular.otf']);
    });
    final at = DateTime(2026, 11, 2, 11);
    const member = {'org_membership_v1': '{"code":"STELLAR-DEMO","company":"Stellar Labs (SAMPLE)","joined":"2026-11-02T10:00:00.000"}'};
    Future<void> to(String k) => t.scrollUntilVisible(find.byKey(Key(k)), 200, scrollable: find.byType(Scrollable).first);
    Future<void> top(String k) async {
      await to(k);
      await t.ensureVisible(find.byKey(Key(k)));
    }

    await shot(t, '/org', 'b2b_1_dashboard_top.png', at: at);
    await shot(t, '/org', 'b2b_2_trend_departments.png', at: at, act: () => top('org-trend'));
    await shot(t, '/org', 'b2b_3_focus_programs.png', at: at, act: () => top('org-focus'));
    await shot(t, '/org/join', 'b2b_4_join_code.png', at: at);
    await shot(t, '/org/join', 'b2b_5_consent.png', at: at, act: () async {
      await t.enterText(find.byKey(const Key('org-code')), 'STELLAR-DEMO');
      await t.tap(find.byKey(const Key('org-code-next')));
    });
    await shot(t, '/profile', 'b2b_6_profile_free.png', at: at, act: () async {
      await top('profile-plus');
      await t.drag(find.byType(Scrollable).first, const Offset(0, 160));
    });
    await shot(t, '/profile', 'b2b_7_profile_company_plan.png', at: at, extraStore: member, act: () async {
      await top('profile-plus');
      await t.drag(find.byType(Scrollable).first, const Offset(0, 160));
    });
    await shot(t, '/org/demo', 'b2b_8_book_demo.png', at: at);
  });
}
