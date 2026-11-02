import 'dart:convert';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/secure_store.dart';
import '../../core/theme/app_colors.dart';
import '../ritual/ritual.dart' show ritualClockProvider;

/// DEMO ONLY. Corporate (B2B) wellness: a SAMPLE company and SAMPLE data. Nothing is uploaded;
/// joining a team only stores a local flag. Real deployments need legal review [VERIFY].

/// Minimum group size before any aggregate may be shown (k-anonymity).
const orgMinGroup = 5;
const orgNotEnough = 'Not enough people to show safely';

/// Demo company codes → SAMPLE company names.
const demoCompanyCodes = {'STELLAR-DEMO': 'Stellar Labs (SAMPLE)'};

const orgDpdpNote = 'Designed with India\'s Digital Personal Data Protection Act, 2023 in mind: explicit opt-in consent, '
    'purpose limitation and the right to withdraw at any time [VERIFY with legal counsel].';

const orgDisclaimer = 'Demo with SAMPLE data. OneUP is for wellness awareness, not medical advice or diagnosis. '
    'Employers never see individual answers, scores, reflections or mood.';

class CompanyMembership {
  const CompanyMembership({required this.code, required this.company, required this.joinedAt});
  final String code, company;
  final DateTime joinedAt;
  Map<String, dynamic> toJson() => {'code': code, 'company': company, 'joined': joinedAt.toIso8601String()};
  factory CompanyMembership.fromJson(Map<String, dynamic> j) =>
      CompanyMembership(code: j['code'] as String, company: j['company'] as String, joinedAt: DateTime.parse(j['joined'] as String));
}

class OrgController extends StateNotifier<CompanyMembership?> {
  OrgController(this._store, this._clock) : super(null) {
    ready = _load();
  }
  static const key = 'org_membership_v1';
  final SecureStore _store;
  final DateTime Function() _clock;
  late final Future<void> ready;

  Future<void> _load() async {
    final raw = await _store.read(key);
    if (raw == null) return;
    try {
      state = CompanyMembership.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {}
  }

  /// Returns the company name for a valid demo code, else null.
  static String? lookup(String code) => demoCompanyCodes[code.trim().toUpperCase()];

  /// Join only after explicit consent. Returns false for unknown codes or missing consent.
  Future<bool> join(String code, {required bool consent}) async {
    final name = lookup(code);
    if (name == null || !consent) return false;
    state = CompanyMembership(code: code.trim().toUpperCase(), company: name, joinedAt: _clock());
    await _store.write(key, jsonEncode(state!.toJson()));
    return true;
  }

  Future<void> leave() async {
    state = null;
    await _store.delete(key);
  }
}

final orgProvider = StateNotifierProvider<OrgController, CompanyMembership?>(
    (ref) => OrgController(ref.read(secureStoreProvider), ref.read(ritualClockProvider)));

/// One employee's dimension scores (0–100). Only used inside [aggregate]; never rendered.
typedef MemberScores = Map<WellnessDimension, int>;

/// Team averages, or null when the group is smaller than [orgMinGroup]. The only way org data leaves this file.
Map<WellnessDimension, double>? aggregate(List<MemberScores> members, {int k = orgMinGroup}) {
  if (members.length < k) return null;
  return {
    for (final d in WellnessDimension.values) d: members.map((m) => m[d] ?? 0).reduce((a, b) => a + b) / members.length,
  };
}

double overall(Map<WellnessDimension, double> a) => a.values.reduce((x, y) => x + y) / a.length;

class DeptView {
  const DeptView(this.name, this.size, this.avg);
  final String name;
  final int size;

  /// Null when hidden by k-anonymity.
  final Map<WellnessDimension, double>? avg;
  bool get hidden => avg == null;
}

class OrgDashboard {
  const OrgDashboard(
      {required this.company,
      required this.eligible,
      required this.participants,
      required this.average,
      required this.trend,
      required this.departments});
  final String company;
  final int eligible, participants;
  final Map<WellnessDimension, double>? average;
  final List<(String, double)> trend;
  final List<DeptView> departments;
  double get participation => eligible == 0 ? 0 : participants / eligible;

  /// Lowest-scoring dimensions company-wide.
  List<WellnessDimension> get focusAreas {
    if (average == null) return const [];
    final l = average!.entries.toList()..sort((a, b) => a.value.compareTo(b.value));
    return [for (final e in l.take(3)) e.key];
  }
}

/// SAMPLE suggested programs per dimension [VERIFY].
const samplePrograms = {
  WellnessDimension.emotional: 'Stress-skills workshop series (SAMPLE)',
  WellnessDimension.physical: 'Team step challenge + ergonomic check (SAMPLE)',
  WellnessDimension.occupational: 'Manager 1:1 and workload clinic (SAMPLE)',
  WellnessDimension.social: 'Cross-team buddy lunches (SAMPLE)',
  WellnessDimension.spiritual: 'Weekly guided reflection session (SAMPLE)',
  WellnessDimension.intellectual: 'Learning hour + book club (SAMPLE)',
  WellnessDimension.environmental: 'Workspace refresh & green commute week (SAMPLE)',
  WellnessDimension.financial: 'Financial literacy sessions (SAMPLE)',
};

/// Builds the SAMPLE dashboard from synthetic, deterministic members. Departments below k are hidden.
OrgDashboard sampleOrgDashboard({int k = orgMinGroup}) {
  final rnd = Random(42);
  const depts = [('Engineering', 24, 0), ('Sales', 12, -6), ('Operations', 9, 3), ('People & HR', 4, 0), ('Leadership', 3, 0)];
  const base = {
    WellnessDimension.emotional: 58,
    WellnessDimension.physical: 62,
    WellnessDimension.occupational: 54,
    WellnessDimension.social: 70,
    WellnessDimension.spiritual: 60,
    WellnessDimension.intellectual: 72,
    WellnessDimension.environmental: 66,
    WellnessDimension.financial: 48,
  };
  final all = <MemberScores>[];
  final views = <DeptView>[];
  for (final (name, n, shift) in depts) {
    final members = [
      for (var i = 0; i < n; i++) {for (final e in base.entries) e.key: (e.value + shift + rnd.nextInt(21) - 10).clamp(0, 100)},
    ];
    all.addAll(members);
    views.add(DeptView(name, n, aggregate(members, k: k)));
  }
  final avg = aggregate(all, k: k);
  final now = avg == null ? 0.0 : overall(avg);
  const months = ['Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov'];
  return OrgDashboard(
    company: 'Stellar Labs (SAMPLE)',
    eligible: 80,
    participants: all.length,
    average: avg,
    trend: [for (var i = 0; i < months.length; i++) (months[i], now - (months.length - 1 - i) * 1.4)],
    departments: views,
  );
}
