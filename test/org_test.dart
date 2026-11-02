import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:oneup/core/services/haptics.dart';
import 'package:oneup/core/services/secure_store.dart';
import 'package:oneup/core/theme/app_colors.dart';
import 'package:oneup/features/org/org.dart';
import 'package:oneup/features/org/org_ui.dart';
import 'package:oneup/features/plus/entitlement.dart';
import 'package:oneup/features/ritual/ritual.dart';
import 'mem_store.dart';

void main() {
  setUp(() => Haptics.enabled = false);
  final now = DateTime(2026, 11, 2, 10);
  ProviderContainer box(MemStore s) =>
      ProviderContainer(overrides: [secureStoreProvider.overrideWithValue(s), ritualClockProvider.overrideWithValue(() => now)]);
  MemberScores m(int v) => {for (final d in WellnessDimension.values) d: v};

  Future<void> pumpN(WidgetTester t, [int n = 12]) async {
    for (var i = 0; i < n; i++) {
      await t.pump(const Duration(milliseconds: 100));
    }
  }

  test('k-anonymity: groups below 5 are never aggregated', () {
    expect(orgMinGroup, 5);
    expect(aggregate([for (var i = 0; i < 4; i++) m(50)]), isNull);
    expect(aggregate([]), isNull);
    final a = aggregate([m(40), m(50), m(60), m(70), m(80)])!;
    expect(a[WellnessDimension.social], 60);
  });

  test('sample dashboard hides small departments and only exposes averages', () {
    final d = sampleOrgDashboard();
    for (final dep in d.departments) {
      expect(dep.hidden, dep.size < orgMinGroup, reason: dep.name);
    }
    expect(d.departments.where((x) => x.hidden).map((x) => x.name), containsAll(['People & HR', 'Leadership']));
    expect(d.average, isNotNull);
    expect(d.focusAreas.length, 3);
    expect(d.participants, lessThanOrEqualTo(d.eligible));
    // Raising k hides everything, including the company total if too small.
    expect(sampleOrgDashboard(k: 1000).average, isNull);
  });

  test('join needs valid code + consent; gives Company plan Plus; leave removes it', () async {
    final s = MemStore();
    final c = box(s);
    final n = c.read(orgProvider.notifier);
    await n.ready;
    expect(await n.join('STELLAR-DEMO', consent: false), isFalse);
    expect(await n.join('NOPE', consent: true), isFalse);
    expect(c.read(isPlusProvider), isFalse);
    expect(await n.join('stellar-demo', consent: true), isTrue);
    expect(c.read(isPlusProvider), isTrue);
    expect(s.m[OrgController.key], contains('STELLAR-DEMO'));
    final c2 = box(s);
    await c2.read(orgProvider.notifier).ready;
    expect(c2.read(orgProvider)?.company, 'Stellar Labs (SAMPLE)');
    await n.leave();
    expect(c.read(isPlusProvider), isFalse);
    expect(s.m.containsKey(OrgController.key), isFalse);
  });

  Widget app(MemStore s, String loc) => ProviderScope(
        overrides: [secureStoreProvider.overrideWithValue(s), ritualClockProvider.overrideWithValue(() => now)],
        child: MaterialApp.router(
            routerConfig: GoRouter(initialLocation: loc, routes: [
          GoRoute(path: '/', builder: (_, __) => const Scaffold(body: OrgProfileCard())),
          GoRoute(path: '/org', builder: (_, __) => const OrgDashboardScreen()),
          GoRoute(path: '/org/join', builder: (_, __) => const OrgJoinScreen()),
          GoRoute(path: '/org/demo', builder: (_, __) => const OrgDemoFormScreen()),
        ])),
      );

  testWidgets('join flow requires explicit consent, then leave from Profile', (t) async {
    t.view.physicalSize = const Size(1080, 2340);
    t.view.devicePixelRatio = 2.75;
    addTearDown(t.view.reset);
    final s = MemStore();
    await t.pumpWidget(app(s, '/'));
    await pumpN(t);
    await t.tap(find.byKey(const Key('org-join')));
    await pumpN(t);
    await t.enterText(find.byKey(const Key('org-code')), 'WRONG');
    await t.tap(find.byKey(const Key('org-code-next')));
    await pumpN(t, 3);
    expect(find.textContaining('not recognised'), findsOneWidget);
    await t.enterText(find.byKey(const Key('org-code')), 'STELLAR-DEMO');
    await t.tap(find.byKey(const Key('org-code-next')));
    await pumpN(t, 3);
    expect(find.byKey(const Key('org-consent')), findsOneWidget);
    expect(find.textContaining('individual answers or scores'), findsOneWidget);
    await t.tap(find.byKey(const Key('org-join-confirm')));
    await pumpN(t, 3);
    expect(s.m.containsKey(OrgController.key), isFalse, reason: 'no join without consent');
    await t.scrollUntilVisible(find.byKey(const Key('org-consent-check')), 100, scrollable: find.byType(Scrollable).first);
    await t.tap(find.byKey(const Key('org-consent-check')));
    await pumpN(t, 2);
    await t.tap(find.byKey(const Key('org-join-confirm')));
    await pumpN(t);
    expect(s.m.containsKey(OrgController.key), isTrue);
    expect(find.byKey(const Key('org-member')), findsOneWidget);
    await t.tap(find.byKey(const Key('org-leave')));
    await pumpN(t, 4);
    await t.tap(find.byKey(const Key('org-leave-confirm')));
    await pumpN(t, 4);
    expect(find.byKey(const Key('org-join')), findsOneWidget);
    expect(s.m.containsKey(OrgController.key), isFalse);
  });

  testWidgets('dashboard: small groups hidden, no individual or mood data; demo form', (t) async {
    t.view.physicalSize = const Size(1080, 2340);
    t.view.devicePixelRatio = 2.75;
    addTearDown(t.view.reset);
    await t.pumpWidget(app(MemStore(), '/org'));
    await pumpN(t);
    expect(find.byKey(const Key('org-participation')), findsOneWidget);
    final sc = find.byType(Scrollable).first;
    await t.scrollUntilVisible(find.byKey(const Key('org-dept-Leadership')), 200, scrollable: sc);
    expect(find.descendant(of: find.byKey(const Key('org-dept-Leadership')), matching: find.text(orgNotEnough)), findsOneWidget);
    expect(find.descendant(of: find.byKey(const Key('org-dept-Engineering')), matching: find.text(orgNotEnough)), findsNothing);
    expect(find.textContaining(RegExp('mood|crisis', caseSensitive: false)).evaluate().length, lessThanOrEqualTo(1)); // privacy note only
    await t.scrollUntilVisible(find.byKey(const Key('org-book-demo')), 200, scrollable: sc);
    await t.tap(find.byKey(const Key('org-book-demo')));
    await pumpN(t);
    await t.tap(find.byKey(const Key('org-demo-submit')));
    await pumpN(t, 3);
    expect(find.text('Required'), findsWidgets);
    await t.enterText(find.byKey(const Key('org-demo-name')), 'Asha');
    await t.enterText(find.byKey(const Key('org-demo-email')), 'asha@example.com');
    await t.enterText(find.byKey(const Key('org-demo-company')), 'Acme');
    await t.tap(find.byKey(const Key('org-demo-submit')));
    await pumpN(t, 3);
    expect(find.byKey(const Key('org-demo-done')), findsOneWidget);
  });
}
