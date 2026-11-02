import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:oneup/core/services/haptics.dart';
import 'package:oneup/core/services/secure_store.dart';
import 'package:oneup/features/games/game_catalog.dart';
import 'package:oneup/features/games/game_scores.dart';
import 'package:oneup/features/privacy/privacy.dart';
import 'package:oneup/features/ritual/ritual.dart';
import 'package:oneup/features/ritual/ritual_reminders.dart';
import 'mem_store.dart';

class _NoReminders extends RitualReminders {
  @override
  Future<void> cancelAll() async {}
}

MemStore seeded() {
  final s = MemStore();
  for (final k in allKnownKeys) {
    s.m[k] = '[]';
  }
  s.m['assess_attempts_v2'] = '[{"id":"a"},{"id":"b"}]';
  s.m['ritual_v1'] = '{"2026-11-01":{"mood":"good"},"2026-11-02":{}}';
  s.m['weekly_reports_v1'] = '{"reports":[{},{},{}],"seen":null}';
  s.m['wheel_activity_v1'] = '{"events":[{}],"seen":null}';
  s.m['market_v1'] = '{"wishlist":[],"cart":{},"orders":[{}]}';
  s.m['plus_entitlement_v1'] = '{"plan":"trial"}';
  s.m['answer_key_v1'] = 'SECRET-KEY';
  s.m['avatar_v1'] = 'CIPHER';
  return s;
}

void main() {
  setUp(() => Haptics.enabled = false);

  test('every storage key written in lib/ is covered by the privacy inventory', () {
    final re = RegExp(r"'([a-z_]+_v[0-9]+)'");
    final found = <String>{};
    for (final f in Directory('lib').listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart'))) {
      found.addAll(re.allMatches(f.readAsStringSync()).map((m) => m.group(1)!));
    }
    expect(found, isNotEmpty);
    expect(allKnownKeys.toSet().containsAll(found), isTrue, reason: 'missing: ${found.difference(allKnownKeys.toSet())}');
    for (final k in [SecureStore.kTheme, SecureStore.kOnboarded, SecureStore.kConsentVersion, 'haptics_enabled', 'consent_at']) {
      expect(allKnownKeys, contains(k));
    }
    expect(allKnownKeys, contains(GameScores.key(games.first.id)));
  });

  test('counts come from real storage; export excludes the device key and photo', () async {
    final s = seeded();
    final c = await dataCounts(s);
    expect(c['assess_attempts_v2'], 2);
    expect(c['ritual_v1'], 2);
    expect(c['weekly_reports_v1'], 3);
    expect(c['wheel_activity_v1'], 1);
    expect(c['market_v1'], 1);
    expect(c['plus_entitlement_v1'], 1);
    expect(c['quick_check_v1'], 0);
    final json = await exportJson(s, DateTime(2026, 11, 2));
    expect(json, isNot(contains('SECRET-KEY')));
    expect(json, isNot(contains('CIPHER')));
    final data = (jsonDecode(json) as Map)['data'] as Map;
    expect(data.containsKey('assess_attempts_v2'), isTrue);
  });

  testWidgets('Delete all my data: one confirm wipes every key; export uses share sheet', (t) async {
    t.view.physicalSize = const Size(1080, 2340);
    t.view.devicePixelRatio = 2.75;
    addTearDown(t.view.reset);
    final s = seeded()..m['some_unknown_future_key'] = 'x';
    String? shared;
    await t.pumpWidget(ProviderScope(
      overrides: [
        secureStoreProvider.overrideWithValue(s),
        ritualClockProvider.overrideWithValue(() => DateTime(2026, 11, 2, 10)),
        ritualRemindersProvider.overrideWithValue(_NoReminders()),
        exportSharerProvider.overrideWithValue((j) async => shared = j),
      ],
      child: MaterialApp.router(
          routerConfig: GoRouter(initialLocation: '/privacy', routes: [
        GoRoute(path: '/privacy', builder: (_, __) => const PrivacyScreen()),
        GoRoute(path: '/', builder: (_, __) => const Scaffold(body: Text('splash'))),
        GoRoute(path: '/splash', builder: (_, __) => const Scaffold(body: Text('splash'))),
      ])),
    ));
    for (var i = 0; i < 10; i++) {
      await t.pump(const Duration(milliseconds: 100));
    }
    expect(find.byKey(const Key('privacy-hero')), findsOneWidget);
    final sc = find.byType(Scrollable).first;
    await t.scrollUntilVisible(find.byKey(const Key('glance-assess_attempts_v2')), 300, scrollable: sc);
    await t.scrollUntilVisible(find.byKey(const Key('privacy-export')), 300, scrollable: sc);
    await t.tap(find.byKey(const Key('privacy-export')));
    await t.pump(const Duration(milliseconds: 200));
    await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await t.pump();
    expect(shared, contains('"app": "OneUP"'));
    await t.scrollUntilVisible(find.byKey(const Key('privacy-delete')), 300, scrollable: sc);
    await t.tap(find.byKey(const Key('privacy-delete')));
    await t.pump(const Duration(milliseconds: 400));
    await t.tap(find.text('Cancel'));
    await t.pump(const Duration(milliseconds: 400));
    expect(s.m, isNotEmpty);
    await t.tap(find.byKey(const Key('privacy-delete')));
    await t.pump(const Duration(milliseconds: 400));
    await t.tap(find.byKey(const Key('privacy-delete-confirm')));
    for (var i = 0; i < 8; i++) {
      await t.pump(const Duration(milliseconds: 100));
    }
    expect(s.m, isEmpty, reason: 'every key wiped');
  });
}
