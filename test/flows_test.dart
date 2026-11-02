// End-to-end widget flows through the real router: demo sign-up, assess redo dialog, call placeholder,
// delete-my-data.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oneup/core/router/app_router.dart';
import 'package:oneup/core/services/haptics.dart';
import 'package:oneup/core/services/secure_store.dart';
import 'package:oneup/features/assess/data/answer_crypto.dart';
import 'package:oneup/features/assess/data/assessment_models.dart';
import 'package:oneup/features/assess/data/assessment_repository.dart';
import 'package:oneup/features/assess/domain/assessment_controller.dart';
import 'package:oneup/features/consult/data/consult_models.dart';
import 'package:oneup/features/consult/data/consult_repository.dart';
import 'package:oneup/features/consult/domain/consult_logic.dart';
import 'package:oneup/main.dart';
import 'package:oneup/core/theme/app_colors.dart';
import 'mem_store.dart';

class _Seeded extends AssessmentController {
  _Seeded(MemStore s) : super(AssessmentRepository(s), AnswerCrypto(s));
  void seed(AssessState v) => state = v;
}

Future<void> _frames(WidgetTester t, [int n = 10]) async {
  for (var i = 0; i < n; i++) {
    await t.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _tap(WidgetTester t, Finder f) async {
  await t.ensureVisible(f);
  await t.pump();
  await t.tap(f);
}

Future<ProviderContainer> _app(WidgetTester t, MemStore store, {List<Override> extra = const []}) async {
  t.view.physicalSize = const Size(1080, 1920);
  t.view.devicePixelRatio = 3;
  addTearDown(t.view.reset);
  final c = ProviderContainer(overrides: [secureStoreProvider.overrideWithValue(store), ...extra]);
  addTearDown(c.dispose);
  await t.pumpWidget(UncontrolledProviderScope(container: c, child: const OneUpApp()));
  await t.pump(const Duration(seconds: 3));
  await _frames(t);
  return c;
}

void main() {
  setUp(() => Haptics.enabled = false);

  testWidgets('demo sign-up: onboarding → login → OTP → profile → consent → home', (t) async {
    final store = MemStore()
      ..m['welcome_shown_v1'] = 'x'
      ..m['ritual_settings_v1'] = '{"popup":false}';
    await _app(t, store);
    await _tap(t, find.text('Skip'));
    await _frames(t, 30);
    await t.enterText(find.byType(TextField).first, '9876543210');
    await t.pump();
    await _tap(t, find.text('Send OTP'));
    await _frames(t);
    await t.enterText(find.byType(TextField).first, '123456');
    await t.pump();
    await _tap(t, find.text('Verify'));
    await _frames(t, 40);
    await t.enterText(find.byType(TextField).first, 'Asha');
    await _tap(t, find.byType(ChoiceChip).first);
    await t.pump();
    await t.ensureVisible(find.text('Continue'));
    await _tap(t, find.text('Continue'));
    await _frames(t, 30);
    for (final label in ['I agree to OneUp processing', 'I understand OneUp does not provide']) {
      final f = find.textContaining(label);
      await t.scrollUntilVisible(f, 200, scrollable: find.byType(Scrollable).first);
      await _tap(t, f);
      await t.pump();
    }
    await t.ensureVisible(find.text('Agree and continue'));
    await _tap(t, find.text('Agree and continue'));
    await _frames(t, 30);
    expect(find.text('Start assessment'), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets('assess: completed dimension offers View result / Redo', (t) async {
    final store = MemStore()
      ..m[SecureStore.kOnboarded] = 'true'
      ..m['welcome_shown_v1'] = 'x'
      ..m['ritual_settings_v1'] = '{"popup":false}';
    _Seeded? ctl;
    final c = await _app(t, store, extra: [assessmentProvider.overrideWith((ref) => ctl = _Seeded(store))]);
    c.read(assessmentProvider);
    await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
    await _frames(t, 3);
    ctl!.seed(AssessState(cycleStart: DateTime(DateTime.now().year, 1, 1), attempts: [
      DimAttempt(id: 'a', dimension: WellnessDimension.emotional, score: 60, completedAt: DateTime.now()),
    ]));
    c.read(routerProvider).go('/assess');
    await _frames(t);
    await _tap(t, find.text('Emotional').first);
    await _frames(t, 5);
    expect(find.text('Redo'), findsOneWidget);
    await _tap(t, find.text('View result'));
    await _frames(t, 10);
    expect(t.takeException(), isNull);
  });

  testWidgets('call placeholder: mute, camera, end', (t) async {
    final store = MemStore()..m[SecureStore.kOnboarded] = 'true';
    final c = await _app(t, store);
    final cons = sampleConsultants.firstWhere((x) => x.modes.contains(SessionMode.video));
    final now = DateTime.now();
    late Booking b;
    await t.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 30));
      final slot = generateSlots(now.add(const Duration(days: 3)), now, consultantId: cons.id, booked: c.read(bookingsProvider)).first;
      b = await c.read(bookingsProvider.notifier).book(consultant: cons, start: slot, mode: SessionMode.video);
    });
    c.read(routerProvider).go('/consult/sessions');
    await _frames(t);
    c.read(routerProvider).push('/consult/call/${b.id}');
    await _frames(t);
    await _tap(t, find.byTooltip('Mute'));
    await t.pump();
    expect(find.text('Unmute'), findsOneWidget);
    await _tap(t, find.byTooltip('Camera off'));
    await t.pump();
    expect(find.text('Camera on'), findsOneWidget);
    await _tap(t, find.byTooltip('End'));
    await _frames(t);
    expect(find.text('Mute'), findsNothing);
    expect(t.takeException(), isNull);
  });

  testWidgets('profile: delete my data wipes the device store', (t) async {
    final store = MemStore()
      ..m[SecureStore.kOnboarded] = 'true'
      ..m['welcome_shown_v1'] = 'x'
      ..m['ritual_settings_v1'] = '{"popup":false}'
      ..m['game_best_coin-run'] = '42';
    final c = await _app(t, store);
    c.read(routerProvider).go('/profile');
    await _frames(t);
    await t.scrollUntilVisible(find.text('Delete my data'), 200, scrollable: find.byType(Scrollable).first);
    await _tap(t, find.text('Delete my data'));
    await _frames(t, 3);
    await _tap(t, find.text('Delete'));
    await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await t.pump(const Duration(seconds: 3));
    await _frames(t, 10);
    expect(store.m.containsKey('game_best_coin-run'), isFalse);
    expect(store.m[SecureStore.kOnboarded], isNull);
    await t.pump(const Duration(seconds: 3));
    await _frames(t, 10);
    expect(t.takeException(), isNull);
  });
}
