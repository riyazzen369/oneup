import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/secure_store.dart';
import '../../../core/theme/app_colors.dart';
import '../data/answer_crypto.dart';
import '../data/assessment_models.dart';
import '../data/assessment_repository.dart';
import '../data/question_bank.dart';
import 'history.dart';
import 'scoring.dart';

class AssessState {
  const AssessState({
    this.drafts = const {},
    this.attempts = const [],
    required this.cycleStart,
    this.goals = const {},
    this.loading = false,
  });
  final Map<WellnessDimension, DimDraft> drafts;
  final List<DimAttempt> attempts; // newest first
  final DateTime cycleStart;
  final Map<WellnessDimension, int> goals;
  final bool loading;

  Map<WellnessDimension, int> get latest => latestScores(attempts);
  Map<WellnessDimension, int> get previous => previousScores(attempts);
  int? get overall => overallScore(latest);

  DimStatus statusOf(WellnessDimension d) {
    if ((drafts[d]?.position ?? 0) > 0) return DimStatus.inProgress;
    return doneInCycle(attempts, cycleStart).contains(d) ? DimStatus.done : DimStatus.notStarted;
  }

  int get doneCount => doneInCycle(attempts, cycleStart).length;

  AssessState copyWith({
    Map<WellnessDimension, DimDraft>? drafts,
    List<DimAttempt>? attempts,
    DateTime? cycleStart,
    Map<WellnessDimension, int>? goals,
    bool? loading,
  }) =>
      AssessState(
        drafts: drafts ?? this.drafts,
        attempts: attempts ?? this.attempts,
        cycleStart: cycleStart ?? this.cycleStart,
        goals: goals ?? this.goals,
        loading: loading ?? this.loading,
      );
}

final answerCryptoProvider = Provider((ref) => AnswerCrypto(ref.read(secureStoreProvider)));
final assessmentRepoProvider = Provider((ref) => AssessmentRepository(ref.read(secureStoreProvider)));

final assessmentProvider = StateNotifierProvider<AssessmentController, AssessState>(
  (ref) => AssessmentController(ref.read(assessmentRepoProvider), ref.read(answerCryptoProvider)),
);

class AssessmentController extends StateNotifier<AssessState> {
  AssessmentController(this._repo, this._crypto) : super(AssessState(cycleStart: DateTime.fromMillisecondsSinceEpoch(0), loading: true)) {
    _load();
  }
  final AssessmentRepository _repo;
  final AnswerCrypto _crypto;

  Future<void> _load() async {
    state = AssessState(
      drafts: await _repo.loadDrafts(),
      attempts: await _repo.loadAttempts(),
      cycleStart: await _repo.loadCycleStart(),
      goals: await _repo.loadGoals(),
    );
    await refreshFromRemote();
  }

  /// Restores history + goals from Supabase (reinstall / new phone) and merges with local.
  Future<void> refreshFromRemote() async {
    final remote = await _repo.fetchRemoteAttempts();
    if (remote != null) {
      final merged = mergeAttempts(state.attempts, remote);
      await _repo.saveAttempts(merged);
      state = state.copyWith(attempts: merged);
    }
    final goals = await _repo.fetchRemoteGoals();
    if (goals != null && goals.isNotEmpty) {
      final g = {...state.goals, ...goals};
      await _repo.saveGoals(g);
      state = state.copyWith(goals: g);
    }
  }

  Future<void> _saveDrafts(Map<WellnessDimension, DimDraft> d) async {
    await _repo.saveDrafts(d);
    state = state.copyWith(drafts: d);
  }

  /// Ensures a draft exists; [restart] discards an unfinished one.
  Future<DimDraft> ensureDraft(WellnessDimension d, {bool restart = false}) async {
    final existing = state.drafts[d];
    if (existing != null && !restart) return existing;
    final draft = DimDraft.fresh(d);
    await _saveDrafts({...state.drafts, d: draft});
    return draft;
  }

  Future<Map<String, int>> answersFor(WellnessDimension d) async {
    final draft = state.drafts[d];
    if (draft == null) return {};
    final out = <String, int>{};
    for (final q in scoredQuestionsFor(d)) {
      final enc = draft.encAnswers[q.id];
      if (enc == null) continue;
      try {
        out[q.id] = await _crypto.decrypt(enc, aad: '${draft.id}:${q.id}');
      } catch (_) {
        draft.encAnswers.remove(q.id); // unreadable (e.g. lost key) → ask again
      }
    }
    return out;
  }

  /// Decrypted reflection text in the current draft. Old drafts that stored a 1–5
  /// number for item 9 (before it became open text) are discarded safely.
  Future<String?> reflectionFor(WellnessDimension d) async {
    final draft = state.drafts[d];
    final q = reflectionQuestionFor(d);
    final enc = draft?.encAnswers[q.id];
    if (draft == null || enc == null) return null;
    try {
      final v = await _crypto.decryptText(enc, aad: '${draft.id}:${q.id}');
      if (int.tryParse(v.trim()) != null) {
        draft.encAnswers.remove(q.id);
        return null;
      }
      return v;
    } catch (_) {
      return null;
    }
  }

  Future<void> answerText(Question q, String text, int nextIndex) async {
    final draft = state.drafts[q.dimension] ?? await ensureDraft(q.dimension);
    final v = text.trim();
    final capped = v.length > kReflectionMax ? v.substring(0, kReflectionMax) : v;
    draft.encAnswers[q.id] = await _crypto.encryptText(capped, aad: '${draft.id}:${q.id}');
    draft.position = nextIndex;
    await _saveDrafts({...state.drafts, q.dimension: draft});
  }

  /// Decrypts the reflection saved with a completed attempt.
  Future<String?> attemptReflection(DimAttempt a) async {
    final enc = a.encReflection;
    if (enc == null) return null;
    try {
      return await _crypto.decryptText(enc, aad: '${a.id}:${reflectionQuestionFor(a.dimension).id}');
    } catch (_) {
      return null; // e.g. key lost after reinstall
    }
  }

  Future<void> answer(Question q, int value, int nextIndex) async {
    final draft = state.drafts[q.dimension] ?? await ensureDraft(q.dimension);
    draft.encAnswers[q.id] = await _crypto.encrypt(value, aad: '${draft.id}:${q.id}');
    draft.position = nextIndex;
    await _saveDrafts({...state.drafts, q.dimension: draft});
  }

  /// Scores the draft, appends a history attempt, clears the draft, syncs. Returns score.
  Future<int> completeDimension(WellnessDimension d) async {
    final draft = state.drafts[d]!;
    final score = scoreDimension(scoredQuestionsFor(d), await answersFor(d));
    final attempt = DimAttempt(
      id: draft.id,
      dimension: d,
      score: score,
      completedAt: DateTime.now(),
      encReflection: draft.encAnswers[reflectionQuestionFor(d).id],
    );
    final attempts = [attempt, ...state.attempts];
    await _repo.saveAttempts(attempts);
    final drafts = {...state.drafts}..remove(d);
    await _repo.saveDrafts(drafts);
    state = state.copyWith(attempts: attempts, drafts: drafts);
    await _repo.syncAttempt(draft, attempt);
    return score;
  }

  /// Full retake: every dimension shows "Not started" again; history is untouched.
  Future<void> retakeAll() async {
    final now = DateTime.now();
    await _repo.saveCycleStart(now);
    await _repo.saveDrafts({});
    state = state.copyWith(cycleStart: now, drafts: {});
  }

  Future<void> setGoal(WellnessDimension d, int? target) async {
    final g = {...state.goals};
    if (target == null) {
      g.remove(d);
    } else {
      g[d] = clampGoal(target);
    }
    await _repo.saveGoals(g);
    state = state.copyWith(goals: g);
    await _repo.syncGoal(d, g[d]);
  }
}
