import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/secure_store.dart';
import '../games/game_catalog.dart';
import '../ritual/ritual.dart' show ritualClockProvider;

/// DEMO ONLY. No billing SDK and no real payments: every "purchase" just writes a local,
/// encrypted entitlement with an expiry. Prices are SAMPLE placeholders.
const plusDemoNote = 'Demo only: no payment is taken and nothing is billed.';
const samplePriceMonthly = 'SAMPLE ₹149/month [VERIFY]';
const samplePriceYearly = 'SAMPLE ₹1,299/year [VERIFY]';
const trialDays = 7;

/// How many of the newest weekly reports stay free.
const freeReportWeeks = 2;

/// Number of games (one per dimension) that are always free.
const freeGameCount = 8;

enum PlusPlan { trial, monthly, yearly, referral }

extension PlusPlanX on PlusPlan {
  String get label => switch (this) {
        PlusPlan.trial => '7-day free trial',
        PlusPlan.monthly => 'Monthly (demo)',
        PlusPlan.yearly => 'Yearly (demo)',
        PlusPlan.referral => 'Gifted days',
      };
  int get days => switch (this) { PlusPlan.trial => trialDays, PlusPlan.monthly => 30, PlusPlan.yearly => 365, PlusPlan.referral => 0 };
}

class Entitlement {
  const Entitlement(
      {this.plan, this.startedAt, this.expiresAt, this.cancelled = false, this.trialUsed = false, this.bannerDismissed = false});
  final PlusPlan? plan;
  final DateTime? startedAt, expiresAt;

  /// Auto-renew turned off; access continues until [expiresAt].
  final bool cancelled;
  final bool trialUsed, bannerDismissed;

  bool activeAt(DateTime now) => expiresAt != null && now.isBefore(expiresAt!);
  int daysLeft(DateTime now) => !activeAt(now) ? 0 : (expiresAt!.difference(now).inHours / 24).ceil();

  Entitlement copyWith(
          {PlusPlan? plan, DateTime? startedAt, DateTime? expiresAt, bool? cancelled, bool? trialUsed, bool? bannerDismissed}) =>
      Entitlement(
        plan: plan ?? this.plan,
        startedAt: startedAt ?? this.startedAt,
        expiresAt: expiresAt ?? this.expiresAt,
        cancelled: cancelled ?? this.cancelled,
        trialUsed: trialUsed ?? this.trialUsed,
        bannerDismissed: bannerDismissed ?? this.bannerDismissed,
      );

  Map<String, dynamic> toJson() => {
        if (plan != null) 'plan': plan!.name,
        if (startedAt != null) 'start': startedAt!.toIso8601String(),
        if (expiresAt != null) 'exp': expiresAt!.toIso8601String(),
        'cancelled': cancelled,
        'trialUsed': trialUsed,
        'banner': bannerDismissed,
      };

  factory Entitlement.fromJson(Map<String, dynamic> j) => Entitlement(
        plan: PlusPlan.values.where((p) => p.name == j['plan']).firstOrNull,
        startedAt: DateTime.tryParse(j['start'] as String? ?? ''),
        expiresAt: DateTime.tryParse(j['exp'] as String? ?? ''),
        cancelled: j['cancelled'] as bool? ?? false,
        trialUsed: j['trialUsed'] as bool? ?? false,
        bannerDismissed: j['banner'] as bool? ?? false,
      );
}

class EntitlementController extends StateNotifier<Entitlement> {
  EntitlementController(this._store, this._clock) : super(const Entitlement()) {
    ready = _load();
  }
  static const key = 'plus_entitlement_v1';
  final SecureStore _store;
  final DateTime Function() _clock;
  late final Future<void> ready;

  DateTime get now => _clock();
  bool get isPlus => state.activeAt(now);

  Future<void> _load() async {
    try {
      final raw = await _store.read(key);
      if (raw != null && mounted) state = Entitlement.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {/* corrupt → free */}
  }

  Future<void> _save(Entitlement e) async {
    state = e;
    await _store.write(key, jsonEncode(e.toJson()));
  }

  /// One free trial per install. Returns false if already used or already Plus.
  Future<bool> startTrial() async {
    await ready;
    if (state.trialUsed || isPlus) return false;
    final n = now;
    await _save(state.copyWith(
        plan: PlusPlan.trial, startedAt: n, expiresAt: n.add(const Duration(days: trialDays)), cancelled: false, trialUsed: true));
    return true;
  }

  /// DEMO checkout: no payment, just a local entitlement. Extends any time already left.
  Future<void> demoPurchase(PlusPlan plan) async {
    await ready;
    assert(plan == PlusPlan.monthly || plan == PlusPlan.yearly);
    final n = now;
    final base = isPlus ? state.expiresAt! : n;
    await _save(state.copyWith(plan: plan, startedAt: n, expiresAt: base.add(Duration(days: plan.days)), cancelled: false));
  }

  /// For referrals (#17) or promos: add [days] of Plus on top of whatever is left.
  Future<void> grantDays(int days) async {
    await ready;
    if (days <= 0) return;
    final n = now;
    final base = isPlus ? state.expiresAt! : n;
    await _save(state.copyWith(
        plan: isPlus ? state.plan : PlusPlan.referral, startedAt: isPlus ? state.startedAt : n, expiresAt: base.add(Duration(days: days))));
  }

  /// Turn off renewal. Access stays until the expiry date.
  Future<void> cancel() async {
    await ready;
    if (!isPlus) return;
    await _save(state.copyWith(cancelled: true));
  }

  Future<void> resume() async {
    await ready;
    if (!isPlus) return;
    await _save(state.copyWith(cancelled: false));
  }

  Future<void> dismissBanner() async {
    await ready;
    await _save(state.copyWith(bannerDismissed: true));
  }
}

final entitlementProvider = StateNotifierProvider<EntitlementController, Entitlement>(
    (ref) => EntitlementController(ref.read(secureStoreProvider), ref.read(ritualClockProvider)));

/// True while Plus is active. Re-evaluated whenever the entitlement changes.
final isPlusProvider = Provider<bool>((ref) => ref.watch(entitlementProvider).activeAt(ref.read(ritualClockProvider)()));

/// What is gated. Safety, assessment, results, ritual, privacy and the disclaimer are never listed here.
enum PlusFeature {
  consultation,
  coaching,
  pickedForYou,
  reportDashboard,
  prioritySupport,
  reportHistory,
  extraGames,
  fullLessons,
  advancedTrends,
}

extension PlusFeatureX on PlusFeature {
  String get title => switch (this) {
        PlusFeature.consultation => 'Expert consultation',
        PlusFeature.coaching => '1-on-1 wellness coaching',
        PlusFeature.pickedForYou => 'Picked for you + member prices',
        PlusFeature.reportDashboard => 'Weekly + monthly reports',
        PlusFeature.prioritySupport => 'Priority support',
        PlusFeature.reportHistory => 'Full weekly report history',
        PlusFeature.extraGames => 'All 16 games',
        PlusFeature.fullLessons => 'Full long-form lessons',
        PlusFeature.advancedTrends => 'Advanced trends',
      };
  String get free => switch (this) {
        PlusFeature.consultation => 'Browse SAMPLE experts',
        PlusFeature.coaching => 'See SAMPLE coaches',
        PlusFeature.pickedForYou => 'Focus recommendations, sample prices',
        PlusFeature.reportDashboard => 'Latest $freeReportWeeks weekly reports',
        PlusFeature.prioritySupport => 'Standard support',
        PlusFeature.reportHistory => 'Last $freeReportWeeks weeks',
        PlusFeature.extraGames => '$freeGameCount games, one per dimension',
        PlusFeature.fullLessons => 'Short lessons + first chapter of long reads',
        PlusFeature.advancedTrends => 'Wheel, goals and check-in history',
      };
  String get plus => switch (this) {
        PlusFeature.consultation => 'Book a session (demo booking)',
        PlusFeature.coaching => 'Book a coach or request a chat (demo)',
        PlusFeature.pickedForYou => 'Picks for your lowest areas + SAMPLE member price',
        PlusFeature.reportDashboard => 'Monthly reports + full history',
        PlusFeature.prioritySupport => 'Priority response (demo)',
        PlusFeature.reportHistory => 'Up to 8 weeks',
        PlusFeature.extraGames => '8 more games',
        PlusFeature.fullLessons => 'Every chapter, example and reflection',
        PlusFeature.advancedTrends => 'Change over time for each dimension',
      };
}

/// SAMPLE member discount shown on Market items for Plus (display only, demo).
const memberDiscountPct = 10;
int memberPrice(int price) => (price * (100 - memberDiscountPct) / 100).round();

/// Always free, never behind Plus.
const alwaysFree = [
  'Wellness assessment and results',
  'Daily ritual and quick check',
  'Crisis and safety help, immediate for everyone',
  'Privacy controls and delete my data',
];

/// Games after the first [freeGameCount] (one per dimension) are Plus extras.
bool isPlusGame(String id) => games.indexWhere((g) => g.id == id) >= freeGameCount;

/// SAMPLE numbers for display only [VERIFY]. Not real prices or real values.
const sampleMonthlyRupees = 149, sampleYearlyRupees = 1299;
const sampleValues = <(String, int)>[
  ('Expert consultation (1 session)', 999),
  ('1-on-1 wellness coaching (1 session)', 1499),
  ('Priority support', 299),
  ('Monthly reports + full history', 199),
  ('Full long-form lessons', 199),
  ('Member prices in Market', 149),
  ('8 extra games', 99),
];
int get sampleTotalValue => sampleValues.fold(0, (a, b) => a + b.$2);

/// Yearly saving vs 12 × monthly, rounded down (SAMPLE prices).
int get sampleYearlySavePct => ((1 - sampleYearlyRupees / (sampleMonthlyRupees * 12)) * 100).floor();

String rupees(int v) {
  final s = v.toString();
  if (s.length <= 3) return '₹$s';
  final head = s.substring(0, s.length - 3), tail = s.substring(s.length - 3);
  final b = StringBuffer();
  for (var i = 0; i < head.length; i++) {
    if (i > 0 && (head.length - i) % 2 == 0) b.write(',');
    b.write(head[i]);
  }
  return '₹$b,$tail';
}
