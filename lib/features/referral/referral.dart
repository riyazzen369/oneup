import 'dart:convert';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/services/secure_store.dart';
import '../../core/theme/app_colors.dart';
import '../games/game_catalog.dart';
import '../games/game_scores.dart';
import '../learn/learn_repository.dart';
import '../plus/entitlement.dart';
import '../ritual/ritual.dart';

/// DEMO referral loop. No backend: codes are made and checked on this device only,
/// nothing is sent anywhere, and "friends joined" is SAMPLE data you simulate.
const referralDemoNote = 'Demo: invite codes are checked on this device only. No contacts are read and nothing is sent for you.';
const referralRewardDays = 7;

/// Max simulated friend joins that earn days (demo cap) [VERIFY business rule].
const maxRewardedFriends = 5;
const _alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; // no 0/O/1/I
final inviteCodePattern = RegExp(r'^ONEUP-[A-HJ-NP-Z2-9]{4}$');

String normalizeCode(String raw) => raw.trim().toUpperCase().replaceAll(' ', '');
String newInviteCode(Random r) => 'ONEUP-${List.generate(4, (_) => _alphabet[r.nextInt(_alphabet.length)]).join()}';

enum ChallengeKind { ritualStreak, lessonsWeek, everyDimension }

extension ChallengeKindX on ChallengeKind {
  String get title => switch (this) {
        ChallengeKind.ritualStreak => '7-day ritual streak',
        ChallengeKind.lessonsWeek => '5 lessons in a week',
        ChallengeKind.everyDimension => 'Play every dimension game',
      };
  String get blurb => switch (this) {
        ChallengeKind.ritualStreak => 'Check in or finish your small step 7 days in a row.',
        ChallengeKind.lessonsWeek => 'Finish 5 Learn lessons within 7 days of starting.',
        ChallengeKind.everyDimension => 'Play one game in each of the 8 wellness dimensions.',
      };
  int get goal => switch (this) {
        ChallengeKind.ritualStreak => 7,
        ChallengeKind.lessonsWeek => 5,
        ChallengeKind.everyDimension => WellnessDimension.values.length
      };

  /// SAMPLE friend progress shown next to yours (not a real person).
  int get sampleFriend =>
      switch (this) { ChallengeKind.ritualStreak => 4, ChallengeKind.lessonsWeek => 2, ChallengeKind.everyDimension => 5 };
}

class ActiveChallenge {
  const ActiveChallenge(this.kind, this.startedAt, this.lessonBaseline);
  final ChallengeKind kind;
  final DateTime startedAt;
  final int lessonBaseline;
  Map<String, dynamic> toJson() => {'kind': kind.name, 'start': startedAt.toIso8601String(), 'lessons0': lessonBaseline};
  static ActiveChallenge? fromJson(Object? j) {
    if (j is! Map) return null;
    final k = ChallengeKind.values.where((e) => e.name == j['kind']).firstOrNull;
    final s = DateTime.tryParse(j['start'] as String? ?? '');
    return k == null || s == null ? null : ActiveChallenge(k, s, j['lessons0'] as int? ?? 0);
  }
}

class ReferralState {
  const ReferralState(
      {this.code, this.redeemed, this.friendsJoined = 0, this.challenge, this.homeCardDismissed = false, this.loaded = false});
  final String? code;

  /// Code this install redeemed (once per install).
  final String? redeemed;

  /// SAMPLE: simulated in the demo.
  final int friendsJoined;
  final ActiveChallenge? challenge;
  final bool homeCardDismissed, loaded;

  ReferralState copy(
          {String? code,
          String? redeemed,
          int? friendsJoined,
          ActiveChallenge? challenge,
          bool clearChallenge = false,
          bool? homeCardDismissed}) =>
      ReferralState(
          code: code ?? this.code,
          redeemed: redeemed ?? this.redeemed,
          friendsJoined: friendsJoined ?? this.friendsJoined,
          challenge: clearChallenge ? null : (challenge ?? this.challenge),
          homeCardDismissed: homeCardDismissed ?? this.homeCardDismissed,
          loaded: true);

  Map<String, dynamic> toJson() => {
        'code': code,
        if (redeemed != null) 'redeemed': redeemed,
        'friends': friendsJoined,
        if (challenge != null) 'challenge': challenge!.toJson(),
        'homeCard': homeCardDismissed,
      };
}

enum RedeemResult { ok, badFormat, ownCode, alreadyRedeemed }

class ReferralController extends StateNotifier<ReferralState> {
  ReferralController(this._ref, this._store, this._clock, [Random? rng])
      : _rng = rng ?? Random.secure(),
        super(const ReferralState()) {
    ready = _load();
  }
  static const key = 'referral_v1';
  final Ref _ref;
  final SecureStore _store;
  final DateTime Function() _clock;
  final Random _rng;
  late final Future<void> ready;

  Future<void> _load() async {
    var s = const ReferralState(loaded: true);
    try {
      final raw = await _store.read(key);
      if (raw != null) {
        final j = jsonDecode(raw) as Map<String, dynamic>;
        s = ReferralState(
            code: j['code'] as String?,
            redeemed: j['redeemed'] as String?,
            friendsJoined: j['friends'] as int? ?? 0,
            challenge: ActiveChallenge.fromJson(j['challenge']),
            homeCardDismissed: j['homeCard'] as bool? ?? false,
            loaded: true);
      }
    } catch (_) {}
    if (!mounted) return;
    state = s;
    // Code lives in memory until first used (shared or any change), so deleting all data leaves no key behind.
    if (s.code == null || !inviteCodePattern.hasMatch(s.code!)) state = s.copy(code: newInviteCode(_rng));
  }

  /// Saves the invite code so it stays the same; called before it is shared.
  Future<void> keepCode() async {
    await ready;
    if (await _store.read(key) == null) await _save(state);
  }

  Future<void> _save(ReferralState s) async {
    state = s;
    await _store.write(key, jsonEncode(s.toJson()));
  }

  Future<RedeemResult> redeem(String raw) async {
    await ready;
    final c = normalizeCode(raw);
    if (!inviteCodePattern.hasMatch(c)) return RedeemResult.badFormat;
    if (c == state.code) return RedeemResult.ownCode;
    if (state.redeemed != null) return RedeemResult.alreadyRedeemed;
    await _save(state.copy(redeemed: c));
    await _ref.read(entitlementProvider.notifier).grantDays(referralRewardDays);
    return RedeemResult.ok;
  }

  /// DEMO: pretend a friend joined with your code. Earns 7 days up to [maxRewardedFriends].
  Future<bool> simulateFriendJoined() async {
    await ready;
    final n = state.friendsJoined + 1;
    await _save(state.copy(friendsJoined: n));
    if (n > maxRewardedFriends) return false;
    await _ref.read(entitlementProvider.notifier).grantDays(referralRewardDays);
    return true;
  }

  Future<void> startChallenge(ChallengeKind k) async {
    await ready;
    await _save(state.copy(challenge: ActiveChallenge(k, _clock(), _ref.read(learnProgressProvider).length)));
  }

  Future<void> leaveChallenge() async {
    await ready;
    await _save(state.copy(clearChallenge: true));
  }

  Future<void> dismissHomeCard() async {
    await ready;
    await _save(state.copy(homeCardDismissed: true));
  }
}

final referralProvider = StateNotifierProvider<ReferralController, ReferralState>(
    (ref) => ReferralController(ref, ref.read(secureStoreProvider), ref.read(ritualClockProvider)));

/// Your side of the challenge, from data already on this device.
int challengeProgress(ActiveChallenge c,
    {required Map<String, DayEntry> ritualDays, required int lessonsDone, required Map<String, int> gameScores, required DateTime now}) {
  final v = switch (c.kind) {
    ChallengeKind.ritualStreak => ritualStreak(ritualDays, now),
    ChallengeKind.lessonsWeek => now.difference(c.startedAt).inDays >= 7 ? 0 : lessonsDone - c.lessonBaseline,
    ChallengeKind.everyDimension => {
        for (final g in games)
          if (gameScores.containsKey(g.id)) g.dimension
      }.length,
  };
  return v.clamp(0, c.kind.goal);
}

final challengeProgressProvider = Provider<int?>((ref) {
  final c = ref.watch(referralProvider).challenge;
  if (c == null) return null;
  return challengeProgress(c,
      ritualDays: ref.watch(ritualProvider).days,
      lessonsDone: ref.watch(learnProgressProvider).length,
      gameScores: ref.watch(gameScoresProvider),
      now: ref.read(ritualClockProvider)());
});

String inviteText(String code) => 'Join me on OneUP, a small daily wellness habit app. Use my invite code $code '
    'and we both get 1 week of OneUP Plus. (Demo invite)';
String challengeText(ChallengeKind k, String code) =>
    'I\'m taking the OneUP "${k.title}" challenge: ${k.blurb} Join me with code $code. (Demo invite)';

/// System share sheet only; overridable in tests.
final inviteSharerProvider = Provider<Future<void> Function(String text)>((ref) => (t) => Share.share(t, subject: 'Join me on OneUP'));
