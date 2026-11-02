import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oneup/core/services/haptics.dart';
import 'package:oneup/core/services/secure_store.dart';
import 'package:oneup/features/plus/entitlement.dart';
import 'package:oneup/features/referral/referral.dart';
import 'package:oneup/features/referral/referral_ui.dart';
import 'package:oneup/features/ritual/ritual.dart';
import 'mem_store.dart';

final now = DateTime(2026, 11, 2, 10);

ProviderContainer box(MemStore s) =>
    ProviderContainer(overrides: [secureStoreProvider.overrideWithValue(s), ritualClockProvider.overrideWithValue(() => now)]);

void main() {
  setUp(() => Haptics.enabled = false);

  test('invite code is ONEUP-XXXX, stable across restarts', () async {
    expect(inviteCodePattern.hasMatch(newInviteCode(Random(1))), isTrue);
    final s = MemStore();
    final a = box(s);
    await a.read(referralProvider.notifier).ready;
    final code = a.read(referralProvider).code!;
    expect(inviteCodePattern.hasMatch(code), isTrue);
    a.dispose();
    final b = box(s);
    await b.read(referralProvider.notifier).ready;
    expect(b.read(referralProvider).code, code);
  });

  test('redeem: format, own code, once per install, grants 7 days', () async {
    final s = MemStore();
    final c = box(s);
    final r = c.read(referralProvider.notifier);
    await r.ready;
    expect(await r.redeem('hello'), RedeemResult.badFormat);
    expect(await r.redeem('ONEUP-AB1O'), RedeemResult.badFormat); // 1/O not in alphabet
    expect(await r.redeem(c.read(referralProvider).code!.toLowerCase()), RedeemResult.ownCode);
    expect(c.read(isPlusProvider), isFalse);
    expect(await r.redeem(' oneup-ab23 '), RedeemResult.ok);
    expect(c.read(entitlementProvider).daysLeft(now), 7);
    expect(await r.redeem('ONEUP-ZZ99'), RedeemResult.alreadyRedeemed);
    expect(c.read(entitlementProvider).daysLeft(now), 7);
    expect((jsonDecode(s.m['referral_v1']!) as Map)['redeemed'], 'ONEUP-AB23');
  });

  test('simulated friends add 7 days each up to the cap', () async {
    final c = box(MemStore());
    final r = c.read(referralProvider.notifier);
    for (var i = 0; i < maxRewardedFriends + 1; i++) {
      await r.simulateFriendJoined();
    }
    expect(c.read(referralProvider).friendsJoined, maxRewardedFriends + 1);
    expect(c.read(entitlementProvider).daysLeft(now), 7 * maxRewardedFriends);
  });

  test('challenge progress from local data', () {
    final ch = ActiveChallenge(ChallengeKind.lessonsWeek, now.subtract(const Duration(days: 2)), 3);
    int p(ActiveChallenge c, {int lessons = 0, Map<String, int> g = const {}, Map<String, DayEntry> d = const {}, DateTime? at}) =>
        challengeProgress(c, ritualDays: d, lessonsDone: lessons, gameScores: g, now: at ?? now);
    expect(p(ch, lessons: 5), 2);
    expect(p(ch, lessons: 20), 5);
    expect(p(ch, lessons: 5, at: now.add(const Duration(days: 6))), 0); // window over
    final streak = {for (var i = 0; i < 9; i++) dayKey(now.subtract(Duration(days: i))): const DayEntry(done: true)};
    expect(p(ActiveChallenge(ChallengeKind.ritualStreak, now, 0), d: streak), 7);
    expect(p(ActiveChallenge(ChallengeKind.everyDimension, now, 0), g: {'mood-catcher': 3, 'breath-runner': 1, 'nope': 2}), 2);
  });

  testWidgets('invite screen: share via sheet, simulate, challenge with SAMPLE friend', (t) async {
    final shared = <String>[];
    final s = MemStore();
    await t.pumpWidget(ProviderScope(overrides: [
      secureStoreProvider.overrideWithValue(s),
      ritualClockProvider.overrideWithValue(() => now),
      inviteSharerProvider.overrideWithValue((x) async => shared.add(x)),
    ], child: const MaterialApp(home: InviteScreen())));
    for (var i = 0; i < 5; i++) {
      await t.pump(const Duration(milliseconds: 100));
    }
    expect(find.text('Both of you get 1 week of OneUP Plus'), findsOneWidget);
    final code = (t.widget<Text>(find.byKey(const Key('invite-code')))).data!;
    expect(inviteCodePattern.hasMatch(code), isTrue);
    await t.tap(find.byKey(const Key('invite-share')));
    await t.pump();
    expect(shared.single, contains(code));
    await t.tap(find.byKey(const Key('invite-simulate')));
    await t.pump(const Duration(milliseconds: 200));
    expect(find.textContaining('1 friends joined · SAMPLE'), findsOneWidget);
    await t.scrollUntilVisible(find.byKey(const Key('challenge-ritualStreak')), 200);
    await t.tap(find.byKey(const Key('challenge-ritualStreak')));
    await t.pump(const Duration(milliseconds: 200));
    await t.scrollUntilVisible(find.byKey(const Key('challenge-share')), 200);
    expect(find.text('Friend · SAMPLE'), findsOneWidget);
    expect(find.text('0 / 7'), findsOneWidget);
    await t.tap(find.byKey(const Key('challenge-share')));
    await t.pump();
    expect(shared.last, allOf(contains('7-day ritual streak'), contains(code)));
    await t.pump(const Duration(seconds: 5));
  });
}
