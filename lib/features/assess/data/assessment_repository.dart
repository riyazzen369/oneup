import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/env.dart';
import '../../../core/services/secure_store.dart';
import '../../../core/theme/app_colors.dart';
import '../domain/scoring.dart';
import 'assessment_models.dart';
import 'question_bank.dart';

/// Local state in flutter_secure_storage; Supabase is synced best-effort and is the
/// source for restoring score history and goals after reinstall / new phone.
class AssessmentRepository {
  AssessmentRepository(this._store);
  final SecureStore _store;
  static const _kDrafts = 'assess_drafts_v2';
  static const _kAttempts = 'assess_attempts_v2';
  static const _kCycle = 'assess_cycle_v2';
  static const _kGoals = 'goals_v1';

  Future<T> _json<T>(String k, T fallback, T Function(dynamic) parse) async {
    final s = await _store.read(k);
    if (s == null) return fallback;
    try {
      return parse(jsonDecode(s));
    } catch (_) {
      return fallback;
    }
  }

  Future<Map<WellnessDimension, DimDraft>> loadDrafts() => _json(
      _kDrafts, {}, (j) => {for (final e in (j as List)) DimDraft.fromJson(e as Map<String, dynamic>).dimension: DimDraft.fromJson(e)});
  Future<void> saveDrafts(Map<WellnessDimension, DimDraft> d) =>
      _store.write(_kDrafts, jsonEncode(d.values.map((x) => x.toJson()).toList()));

  Future<List<DimAttempt>> loadAttempts() =>
      _json(_kAttempts, <DimAttempt>[], (j) => [for (final e in (j as List)) DimAttempt.fromJson(e as Map<String, dynamic>)]);
  Future<void> saveAttempts(List<DimAttempt> a) => _store.write(_kAttempts, jsonEncode(a.map((x) => x.toJson()).toList()));

  Future<DateTime> loadCycleStart() async {
    final s = await _store.read(_kCycle);
    return s == null ? DateTime.fromMillisecondsSinceEpoch(0) : DateTime.parse(s);
  }

  Future<void> saveCycleStart(DateTime t) => _store.write(_kCycle, t.toIso8601String());

  Future<Map<WellnessDimension, int>> loadGoals() =>
      _json(_kGoals, {}, (j) => {for (final e in (j as Map).entries) WellnessDimension.values.byName(e.key as String): e.value as int});
  Future<void> saveGoals(Map<WellnessDimension, int> g) =>
      _store.write(_kGoals, jsonEncode({for (final e in g.entries) e.key.name: e.value}));

  // ---------------- Supabase ----------------
  SupabaseClient? get _client {
    if (!Env.isConfigured) return null;
    final c = Supabase.instance.client;
    return c.auth.currentUser == null ? null : c;
  }

  Future<void> syncAttempt(DimDraft draft, DimAttempt a) async {
    final c = _client;
    if (c == null) return;
    try {
      await c.from('assessments').upsert({
        'id': a.id,
        'user_id': c.auth.currentUser!.id,
        'started_at': draft.startedAt.toUtc().toIso8601String(),
        'completed_at': a.completedAt.toUtc().toIso8601String(),
        'status': 'completed',
      });
      await c.from('answers').upsert([
        for (final q in questionsFor(a.dimension))
          if (draft.encAnswers[q.id] != null) {'assessment_id': a.id, 'question_id': q.id, 'value_enc': draft.encAnswers[q.id]},
      ], onConflict: 'assessment_id,question_id');
      await c.from('dimension_scores').upsert({
        'assessment_id': a.id,
        'dimension_id': a.dimension.index + 1,
        'score': a.score,
        'band': bandFor(a.score).dbValue,
      }, onConflict: 'assessment_id,dimension_id');
    } catch (e) {
      debugPrint('Attempt sync failed (kept locally): $e');
    }
  }

  /// Completed attempts from the server. Returns null if offline / not configured.
  Future<List<DimAttempt>?> fetchRemoteAttempts() async {
    final c = _client;
    if (c == null) return null;
    try {
      final rows = await c
          .from('assessments')
          .select('id, completed_at, dimension_scores(dimension_id, score), answers(question_id, value_enc)')
          .eq('status', 'completed');
      return [
        for (final r in rows)
          for (final s in (r['dimension_scores'] as List? ?? []))
            DimAttempt(
              id: r['id'] as String,
              dimension: WellnessDimension.values[(s['dimension_id'] as int) - 1],
              score: s['score'] as int,
              completedAt: DateTime.parse(r['completed_at'] as String).toLocal(),
              encReflection: _reflectionOf(r, (s['dimension_id'] as int) - 1),
            ),
      ];
    } catch (e) {
      debugPrint('History fetch failed: $e');
      return null;
    }
  }

  String? _reflectionOf(Map<String, dynamic> row, int dimIndex) {
    final qid = reflectionQuestionFor(WellnessDimension.values[dimIndex]).id;
    for (final a in (row['answers'] as List? ?? [])) {
      if (a['question_id'] == qid) return a['value_enc'] as String?;
    }
    return null;
  }

  Future<Map<WellnessDimension, int>?> fetchRemoteGoals() async {
    final c = _client;
    if (c == null) return null;
    try {
      final rows = await c.from('goals').select('dimension_id, target_score');
      return {
        for (final r in rows) WellnessDimension.values[(r['dimension_id'] as int) - 1]: r['target_score'] as int,
      };
    } catch (e) {
      debugPrint('Goals fetch failed: $e');
      return null;
    }
  }

  Future<void> syncGoal(WellnessDimension d, int? target) async {
    final c = _client;
    if (c == null) return;
    try {
      final uid = c.auth.currentUser!.id;
      if (target == null) {
        await c.from('goals').delete().eq('user_id', uid).eq('dimension_id', d.index + 1);
      } else {
        await c.from('goals').upsert({'user_id': uid, 'dimension_id': d.index + 1, 'target_score': target});
      }
    } catch (e) {
      debugPrint('Goal sync failed: $e');
    }
  }
}
