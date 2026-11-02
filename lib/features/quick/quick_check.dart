import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/secure_store.dart';
import '../../core/theme/app_colors.dart';

/// 60-second Quick Check: one self-rating per dimension. Results are an ESTIMATE,
/// stored separately from the full (Deep dive) assessment history and never mixed into it.

/// Original plain-language prompts, one per dimension.
const quickPrompts = <WellnessDimension, String>{
  WellnessDimension.emotional: 'How balanced does your emotional life feel lately?',
  WellnessDimension.physical: 'How well are you looking after your body (sleep, movement, food) lately?',
  WellnessDimension.occupational: 'How satisfied do you feel with your work or studies lately?',
  WellnessDimension.social: 'How connected and supported do you feel by the people around you?',
  WellnessDimension.spiritual: 'How much sense of meaning or purpose do you feel lately?',
  WellnessDimension.intellectual: 'How engaged and curious does your mind feel lately?',
  WellnessDimension.environmental: 'How comfortable and safe do your surroundings feel lately?',
  WellnessDimension.financial: 'How at ease do you feel about your money situation lately?',
};

const quickMin = 1, quickMax = 10, quickDefault = 5;

/// Maps a 1–10 slider value onto the app's 0–100 score scale (1 → 0, 10 → 100).
int quickToScore(int v) => ((v.clamp(quickMin, quickMax) - quickMin) / (quickMax - quickMin) * 100).round();

class QuickSnapshot {
  const QuickSnapshot({required this.takenAt, required this.scores});
  final DateTime takenAt;
  final Map<WellnessDimension, int> scores;

  Map<String, dynamic> toJson() => {
        'takenAt': takenAt.toIso8601String(),
        'scores': {for (final e in scores.entries) e.key.name: e.value},
      };

  factory QuickSnapshot.fromJson(Map<String, dynamic> j) => QuickSnapshot(
        takenAt: DateTime.parse(j['takenAt'] as String),
        scores: {for (final e in (j['scores'] as Map).entries) WellnessDimension.values.byName(e.key as String): e.value as int},
      );
}

/// Lowest-scoring dimension (ties → wheel order).
WellnessDimension lowestQuick(Map<WellnessDimension, int> s) =>
    (s.entries.toList()..sort((a, b) => a.value != b.value ? a.value.compareTo(b.value) : a.key.index.compareTo(b.key.index))).first.key;

/// Home wheel blend: full scores always win; quick estimates fill only dimensions with no full score.
({Map<WellnessDimension, int> scores, Set<WellnessDimension> estimated}) blendScores(
    Map<WellnessDimension, int> full, QuickSnapshot? quick) {
  final out = Map<WellnessDimension, int>.of(full);
  final est = <WellnessDimension>{};
  if (quick != null) {
    for (final e in quick.scores.entries) {
      if (!full.containsKey(e.key)) {
        out[e.key] = e.value;
        est.add(e.key);
      }
    }
  }
  return (scores: out, estimated: est);
}

class QuickCheckRepository {
  QuickCheckRepository(this._store);
  final SecureStore _store;
  static const key = 'quick_check_v1';
  static const _maxKept = 30;

  Future<List<QuickSnapshot>> load() async {
    final s = await _store.read(key);
    if (s == null) return [];
    try {
      return [for (final e in jsonDecode(s) as List) QuickSnapshot.fromJson(e as Map<String, dynamic>)];
    } catch (_) {
      return [];
    }
  }

  Future<void> save(List<QuickSnapshot> all) => _store.write(key, jsonEncode(all.map((e) => e.toJson()).toList()));
}

class QuickCheckState {
  const QuickCheckState({this.history = const [], this.loaded = false});
  final List<QuickSnapshot> history;
  final bool loaded;
  QuickSnapshot? get latest => history.isEmpty ? null : history.last;
}

class QuickCheckController extends StateNotifier<QuickCheckState> {
  QuickCheckController(this._repo) : super(const QuickCheckState()) {
    _ready = _repo.load().then((h) {
      if (mounted) state = QuickCheckState(history: h, loaded: true);
    });
  }
  final QuickCheckRepository _repo;
  late final Future<void> _ready;
  Future<void> get ready => _ready;

  /// [values] are raw 1–10 slider values; returns the saved snapshot (0–100 scores).
  Future<QuickSnapshot> submit(Map<WellnessDimension, int> values, {DateTime? now}) async {
    await _ready; // never let a late initial load overwrite a fresh snapshot
    final snap = QuickSnapshot(
      takenAt: now ?? DateTime.now(),
      scores: {for (final d in WellnessDimension.values) d: quickToScore(values[d] ?? quickDefault)},
    );
    var h = [...state.history, snap];
    if (h.length > QuickCheckRepository._maxKept) h = h.sublist(h.length - QuickCheckRepository._maxKept);
    state = QuickCheckState(history: h, loaded: true);
    await _repo.save(h);
    return snap;
  }
}

final quickCheckProvider = StateNotifierProvider<QuickCheckController, QuickCheckState>(
    (ref) => QuickCheckController(QuickCheckRepository(ref.read(secureStoreProvider))));
