// Release QA: one long end-to-end walk through the real router and real providers (MemStore only).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oneup/core/router/app_router.dart';
import 'package:oneup/core/services/haptics.dart';
import 'package:oneup/core/services/secure_store.dart';
import 'package:oneup/features/plus/entitlement.dart';
import 'package:oneup/features/privacy/privacy.dart';
import 'package:oneup/features/referral/referral.dart';
import 'package:oneup/features/ritual/ritual_reminders.dart';
import 'package:oneup/main.dart';
import 'mem_store.dart';

class _NoReminders extends RitualReminders {
  @override
  Future<void> cancelAll() async {}
  @override
  Future<void> replaceAll(List<PlannedReminder> plan) async {}
  @override
  Future<bool> requestPermission() async => true;
}

Future<void> _f(WidgetTester t, [int n = 10]) async {
  for (var i = 0; i < n; i++) {
    await t.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _tap(WidgetTester t, Finder f) async {
  await t.scrollUntilVisible(f, 200, scrollable: find.byType(Scrollable).last);
  await t.ensureVisible(f);
  await t.pump();
  await t.tap(f);
  await _f(t, 8);
}

void main() {
  setUp(() => Haptics.enabled = false);

  testWidgets('QA walkthrough: sign-up to invite', (t) async {
    t.view.physicalSize = const Size(1080, 2340);
    t.view.devicePixelRatio = 2.75;
    addTearDown(t.view.reset);
    final store = MemStore();
    final shared = <String>[];
    final c = ProviderContainer(overrides: [
      secureStoreProvider.overrideWithValue(store),
      ritualRemindersProvider.overrideWithValue(_NoReminders()),
      exportSharerProvider.overrideWithValue((j) async => shared.add(j)),
      inviteSharerProvider.overrideWithValue((x) async => shared.add(x)),
    ]);
    addTearDown(c.dispose);
    final r = c.read(routerProvider);
    String loc() => r.routerDelegate.currentConfiguration.uri.path;
    void ok(String step) => expect(t.takeException(), isNull, reason: step);

    await t.pumpWidget(UncontrolledProviderScope(container: c, child: const OneUpApp()));
    await t.pump(const Duration(seconds: 3));
    await _f(t, 20);
    ok('splash');
    // Onboarding → login → OTP → profile.
    await _tap(t, find.text('Skip'));
    await _f(t, 20);
    await t.enterText(find.byType(TextField).first, '9876543210');
    await _tap(t, find.text('Send OTP'));
    await t.enterText(find.byType(TextField).first, '123456');
    await _tap(t, find.text('Verify'));
    await _f(t, 30);
    await t.enterText(find.byType(TextField).first, 'Asha');
    await _tap(t, find.byType(ChoiceChip).first);
    await _tap(t, find.text('Continue'));
    await _f(t, 20);
    expect(loc(), Routes.consent);
    ok('login');
    // New user reaches /privacy from consent (pre-consent) and comes back.
    await _tap(t, find.byKey(const Key('private-badge')));
    expect(find.byKey(const Key('privacy-hero')), findsOneWidget);
    r.pop();
    await _f(t, 10);
    expect(find.byKey(const Key('privacy-hero')), findsNothing);
    expect(find.text('Agree and continue'), findsOneWidget);
    ok('consent→privacy');
    for (final label in ['I agree to OneUp processing', 'I understand OneUp does not provide']) {
      await _tap(t, find.textContaining(label));
    }
    await _tap(t, find.text('Agree and continue'));
    await _f(t, 40);
    expect(loc(), Routes.home);
    ok('consent');
    // Ritual popup may show on first Home; dismiss if present.
    if (find.byType(BottomSheet).evaluate().isNotEmpty) {
      await t.tapAt(const Offset(20, 40));
      await _f(t, 10);
    }
    ok('home + ritual popup');

    Future<void> go(String p, {int n = 20}) async {
      r.go(p);
      await _f(t, n);
      ok(p);
    }

    Future<void> push(String p, {int n = 20}) async {
      r.push(p);
      await _f(t, n);
      ok(p);
    }

    await go('/quick');
    await _tap(t, find.byKey(const Key('quick-submit')));
    await _f(t, 20);
    ok('quick submit');
    await go(Routes.home, n: 30);
    if (find.byType(BottomSheet).evaluate().isNotEmpty) {
      await t.tapAt(const Offset(20, 40));
      await _f(t, 10);
    }
    await t.drag(find.byType(Scrollable).first, const Offset(0, -2500));
    await _f(t, 10);
    ok('home scrolled');
    await go('/assess');
    await go('/results');
    await go(Routes.games);
    await go(Routes.learn);
    await go(Routes.market);
    await push('/plus');
    await _tap(t, find.byKey(const Key('plus-trial')));
    expect(c.read(isPlusProvider), isTrue);
    await _tap(t, find.byKey(const Key('plus-screen-cancel')));
    if (find.text('Cancel Plus').evaluate().length > 1 || find.byType(AlertDialog).evaluate().isNotEmpty) {
      final btns = find.descendant(of: find.byType(AlertDialog), matching: find.byType(FilledButton));
      if (btns.evaluate().isNotEmpty) await _tap(t, btns.first);
    }
    expect(c.read(entitlementProvider).cancelled, isTrue);
    ok('plus trial+cancel');
    for (final p in [
      '/reports',
      '/reports?view=monthly',
      '/coaching',
      '/support',
      '/crisis',
      '/org/join',
      '/org',
      '/experts',
      '/trends',
      '/about',
      '/articles'
    ]) {
      await push(p);
    }
    await go('/org/join');
    await t.enterText(find.byKey(const Key('org-code')), 'DEMO-ACME');
    await _tap(t, find.byKey(const Key('org-code-next')));
    ok('org code');
    await go('/invite');
    await _tap(t, find.byKey(const Key('invite-share')));
    expect(shared.last, contains(c.read(referralProvider).code));
    await _tap(t, find.byKey(const Key('invite-redeem-entry')));
    await t.enterText(find.byKey(const Key('redeem-field')), 'ONEUP-AB23');
    await t.testTextInput.receiveAction(TextInputAction.done);
    await _f(t, 10);
    expect(c.read(referralProvider).redeemed, 'ONEUP-AB23');
    ok('redeem');
    await go('/privacy');
    await _tap(t, find.byKey(const Key('privacy-export')));
    expect(shared.last, contains('"exportedAt"'));
    await _tap(t, find.byKey(const Key('privacy-delete')));
    await _tap(t, find.byKey(const Key('privacy-delete-confirm')));
    await t.pump(const Duration(seconds: 3));
    await _f(t, 30);
    expect(store.m, isEmpty);
    ok('delete all');
  });
}
