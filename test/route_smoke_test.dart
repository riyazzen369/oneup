// Pumps every route/screen at small (360x640) and large (412x915) logical sizes, with an empty and a
// seeded assessment state, and records any exception (overflow, null, assertion) per route.
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oneup/core/router/app_router.dart';
import 'package:oneup/core/services/haptics.dart';
import 'package:oneup/core/services/secure_store.dart';
import 'package:oneup/core/theme/app_colors.dart';
import 'package:oneup/features/assess/data/answer_crypto.dart';
import 'package:oneup/features/assess/data/assessment_models.dart';
import 'package:oneup/features/assess/data/assessment_repository.dart';
import 'package:oneup/features/assess/domain/assessment_controller.dart';
import 'package:oneup/features/consult/data/consult_models.dart';
import 'package:oneup/features/consult/data/consult_repository.dart';
import 'package:oneup/features/consult/ui/booking_screen.dart';
import 'package:oneup/features/consult/domain/consult_logic.dart';
import 'package:oneup/features/games/game_catalog.dart';
import 'package:oneup/main.dart';
import 'package:oneup/features/market/market_models.dart';
import 'mem_store.dart';

class _Seeded extends AssessmentController {
  _Seeded(MemStore s) : super(AssessmentRepository(s), AnswerCrypto(s));
  void seed(AssessState v) => state = v;
}

AssessState _sample() {
  final now = DateTime.now();
  return AssessState(
    cycleStart: DateTime(now.year, 1, 1),
    attempts: [
      for (final d in WellnessDimension.values) DimAttempt(id: 'n${d.index}', dimension: d, score: 40 + d.index * 7, completedAt: now),
      for (final d in WellnessDimension.values)
        DimAttempt(id: 'p${d.index}', dimension: d, score: 35 + d.index * 6, completedAt: now.subtract(const Duration(days: 40))),
    ],
    goals: const {WellnessDimension.financial: 65, WellnessDimension.emotional: 70},
  );
}

Future<void> _remount(WidgetTester t, ProviderContainer c) async {
  await t.pumpWidget(const SizedBox());
  t.takeException();
  await t.pumpWidget(UncontrolledProviderScope(container: c, child: const OneUpApp()));
  await t.pump(const Duration(seconds: 3));
  t.takeException();
}

final _sizes = {'small': const Size(360, 640), 'large': const Size(412, 915)};

List<(String, Object?)> _routes(Booking? video, Booking? audio) {
  final c = sampleConsultants.first;
  final slot = DateTime.now().add(const Duration(days: 2));
  return [
    ('/', null), ('/onboarding', null), ('/login', null), ('/otp', '+919876543210'), ('/profile-setup', null), ('/consent', null),
    ('/home', null), ('/assess', null), ('/assess/q/emotional', null), ('/assess/q/financial', null), ('/assess/done/physical', 72),
    ('/results', null), ('/results/dim/financial', null), ('/results/dim/emotional', null), ('/circle', null), ('/trends', null),
    ('/focus', null), ('/learn', null), ('/learn/ah-stacking', null), ('/learn/bks-connection', null), ('/games', null),
    for (final g in games) ('/games/${g.id}', null),
    ('/market', null), ('/market/p/sp-cushion', null), ('/market/p/ph-medicine', null), ('/market/cart', null),
    ('/market/checkout', null), ('/market/orders', null), ('/market/wishlist', null),
    for (final mc in marketCategories()) ('/market/c/${Uri.encodeComponent(mc.name)}', null),
    ('/market/c/nope', null),
    ('/consult', null), ('/consult/c/${c.id}', null), ('/consult/book/${c.id}', null),
    ('/consult/pay', BookingDraft(c, slot, c.modes.first, 'note')), ('/consult/done', video), ('/consult/sessions', null),
    ('/consult/call/${video?.id}', null), ('/consult/call/${audio?.id}', null),
    ('/companion', null), ('/crisis', null), ('/about', null), ('/articles', null), ('/profile', null), ('/profile/edit', null),
    // bad deep links must not crash
    ('/results/dim/nope', null), ('/consult/c/nope', null), ('/consult/pay', null), ('/consult/done', null), ('/games/nope', null),
    ('/nowhere', null), ('/learn/nope', null), ('/market/p/nope', null), ('/consult/call/nope', null),
  ];
}

Future<void> _font(String family, List<String> files) async {
  final l = FontLoader(family);
  final d = '${Platform.environment['HOME']}/flutter/bin/cache/artifacts/material_fonts';
  for (final f in files) {
    final file = File('$d/$f');
    if (file.existsSync()) l.addFont(Future.value(ByteData.sublistView(file.readAsBytesSync())));
  }
  await l.load();
}

void main() {
  setUp(() => Haptics.enabled = false);
  // Real Roboto metrics (the default test font is much wider and causes false overflows).
  setUpAll(() async {
    await _font('Roboto', ['Roboto-Regular.ttf', 'Roboto-Medium.ttf', 'Roboto-Bold.ttf']);
    await _font('MaterialIcons', ['MaterialIcons-Regular.otf']);
  });

  for (final seeded in [false, true]) {
    for (final e in _sizes.entries) {
      testWidgets('all routes render without exceptions: ${e.key}, ${seeded ? 'seeded' : 'empty'}', (t) async {
        t.view.physicalSize = e.value * 3;
        t.view.devicePixelRatio = 3;
        addTearDown(t.view.reset);
        final store = MemStore()
          ..m[SecureStore.kOnboarded] = 'true'
          ..m['welcome_shown_v1'] = 'x'
          ..m['ritual_settings_v1'] = '{"popup":false}';
        _Seeded? ctl;
        final container = ProviderContainer(overrides: [
          secureStoreProvider.overrideWithValue(store),
          assessmentProvider.overrideWith((ref) => ctl = _Seeded(store)),
        ]);
        addTearDown(container.dispose);
        await t.pumpWidget(UncontrolledProviderScope(container: container, child: const OneUpApp()));
        await t.pump(const Duration(seconds: 3));
        if (seeded) {
          container.read(assessmentProvider);
          ctl!.seed(_sample());
          final c = sampleConsultants.firstWhere((c) => c.modes.contains(SessionMode.video));
          final a = sampleConsultants.firstWhere((c) => c.modes.contains(SessionMode.audio));
          final now = DateTime.now();
          await t.runAsync(() async {
            final n = container.read(bookingsProvider.notifier);
            await Future<void>.delayed(const Duration(milliseconds: 50));
            for (final (cc, m) in [(c, SessionMode.video), (a, SessionMode.audio)]) {
              final slots =
                  generateSlots(now.add(const Duration(days: 3)), now, consultantId: cc.id, booked: container.read(bookingsProvider));
              if (slots.isNotEmpty) await n.book(consultant: cc, start: slots.first, mode: m);
            }
          });
        }
        final bookings = container.read(bookingsProvider);
        final video = bookings.where((b) => b.mode == SessionMode.video).firstOrNull;
        final audio = bookings.where((b) => b.mode == SessionMode.audio).firstOrNull;
        final router = container.read(routerProvider);
        final failures = <String>[];
        final origOnError = FlutterError.onError;
        String where = '';
        FlutterError.onError = (d) {
          final m = RegExp(r'lib/[\w/]+\.dart:\d+').firstMatch(d.toDiagnosticsNode(style: DiagnosticsTreeStyle.error).toStringDeep());
          where = m?.group(0) ?? '';
          origOnError?.call(d);
        };
        addTearDown(() => FlutterError.onError = origOnError);
        for (final (path, extra) in _routes(video, audio)) {
          router.go(path, extra: extra);
          for (var i = 0; i < 12; i++) {
            await t.pump(const Duration(milliseconds: 100));
            final ex = t.takeException();
            if (ex != null) {
              failures.add('$path: ${ex.toString().split('\n').first} @ $where');
              await _remount(t, container);
              break;
            }
          }
          // scroll the main scrollable to the end to surface below-the-fold overflows
          final sc = find.byType(Scrollable);
          if (sc.evaluate().isNotEmpty) {
            try {
              await t.drag(sc.first, const Offset(0, -3000), warnIfMissed: false);
              await t.pump(const Duration(milliseconds: 300));
            } catch (_) {}
            final ex = t.takeException();
            if (ex != null) {
              failures.add('$path (scrolled): ${ex.toString().split('\n').first} @ $where');
              await _remount(t, container);
            }
          }
        }
        router.go('/home');
        await t.pump(const Duration(seconds: 3));
        expect(failures, isEmpty, reason: failures.join('\n'));
      });
    }
  }

  testWidgets('bad deep link shows not-found page', (t) async {
    final store = MemStore()..m[SecureStore.kOnboarded] = 'true';
    final container = ProviderContainer(overrides: [secureStoreProvider.overrideWithValue(store)]);
    addTearDown(container.dispose);
    await t.pumpWidget(UncontrolledProviderScope(container: container, child: const OneUpApp()));
    await t.pump(const Duration(seconds: 3));
    await t.pump(const Duration(seconds: 3));
    container.read(routerProvider).go('/consult/pay');
    await t.pump(const Duration(milliseconds: 300));
    await t.pump(const Duration(milliseconds: 300));
    expect(find.text('This page is not available.'), findsOneWidget);
  });
}
