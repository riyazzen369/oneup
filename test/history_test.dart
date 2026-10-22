import 'package:flutter_test/flutter_test.dart';
import 'package:oneup/core/theme/app_colors.dart';
import 'package:oneup/features/assess/data/answer_crypto.dart';
import 'package:oneup/features/assess/data/assessment_models.dart';
import 'package:oneup/features/assess/data/assessment_repository.dart';
import 'package:oneup/features/assess/data/question_bank.dart';
import 'package:oneup/features/assess/domain/assessment_controller.dart';
import 'package:oneup/features/assess/domain/history.dart';
import 'mem_store.dart';

const emo = WellnessDimension.emotional;
const phy = WellnessDimension.physical;
DimAttempt at(String id, WellnessDimension d, int s, int day) =>
    DimAttempt(id: id, dimension: d, score: s, completedAt: DateTime(2026, 1, day));

void main() {
  group('history helpers', () {
    final list = [at('a', emo, 40, 1), at('b', emo, 60, 5), at('c', emo, 50, 3), at('d', phy, 80, 2)];

    test('latest & previous per dimension', () {
      expect(latestScores(list), {emo: 60, phy: 80});
      expect(previousScores(list), {emo: 50});
    });

    test('historyFor is oldest → newest', () {
      expect(historyFor(list, emo).map((a) => a.score), [40, 50, 60]);
    });

    test('merge de-dupes by id, remote wins, newest first', () {
      final m = mergeAttempts([at('a', emo, 40, 1)], [at('a', emo, 45, 1), at('z', phy, 10, 9)]);
      expect(m.map((a) => a.id), ['z', 'a']);
      expect(m.last.score, 45);
    });

    test('doneInCycle respects cycle start', () {
      expect(doneInCycle(list, DateTime(2026, 1, 3)), {emo});
      expect(doneInCycle(list, DateTime(2025)), {emo, phy});
    });

    test('lowestDimensions sorts by score then wheel order', () {
      final low = lowestDimensions({phy: 30, emo: 30, WellnessDimension.social: 10});
      expect(low.map((e) => e.key), [WellnessDimension.social, emo]);
      expect(lowestDimensions({}), isEmpty);
    });

    test('clampGoal', () {
      expect(clampGoal(-5), 0);
      expect(clampGoal(72.6), 73);
      expect(clampGoal(140), 100);
    });

    test('attempt JSON round trip', () {
      final a = at('x', phy, 77, 4);
      final b = DimAttempt.fromJson(a.toJson());
      expect([b.id, b.dimension, b.score, b.completedAt], [a.id, a.dimension, a.score, a.completedAt]);
    });
  });

  group('controller (local, Supabase not configured)', () {
    late MemStore store;
    AssessmentController make() => AssessmentController(AssessmentRepository(store), AnswerCrypto(store));
    Future<AssessmentController> ready() async {
      final c = make();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      return c;
    }

    Future<int> complete(AssessmentController c, WellnessDimension d, int v) async {
      await c.ensureDraft(d, restart: true);
      final qs = scoredQuestionsFor(d);
      for (var i = 0; i < qs.length; i++) {
        await c.answer(qs[i], v, i + 1);
      }
      await c.answerText(reflectionQuestionFor(d), 'Feeling fairly steady this week.', 9);
      return c.completeDimension(d);
    }

    setUp(() => store = MemStore());

    test('redo a single dimension keeps both attempts in history', () async {
      final c = await ready();
      expect(await complete(c, emo, 4), 63);
      expect(await complete(c, emo, 3), 50);
      expect(historyFor(c.state.attempts, emo).map((a) => a.score), [63, 50]);
      expect(await c.attemptReflection(c.state.attempts.first), 'Feeling fairly steady this week.');
      expect(store.m.values.any((v) => v.contains('fairly steady')), isFalse, reason: 'reflection encrypted at rest');
      expect(c.state.latest[emo], 50);
      expect(c.state.previous[emo], 63);
      expect(c.state.attempts.map((a) => a.id).toSet().length, 2, reason: 'each redo is its own assessment');
    });

    test('drafts store ciphertext only and resume after restart', () async {
      final c = await ready();
      final q = questionsFor(phy).first;
      await c.ensureDraft(phy);
      await c.answer(q, 5, 1);
      expect(store.m.values.any((v) => v.contains('"${q.id}":"5"')), isFalse);
      final c2 = await ready();
      expect(c2.state.drafts[phy]!.position, 1);
      expect(await c2.answersFor(phy), {q.id: 5});
    });

    test('old draft with a number stored for item 9 is discarded safely', () async {
      final c = await ready();
      await c.ensureDraft(emo);
      await c.answer(reflectionQuestionFor(emo), 4, 9); // legacy 1–5 value
      expect(await c.reflectionFor(emo), isNull);
      expect(await c.answersFor(emo), isEmpty);
    });

    test('retakeAll resets status but keeps history', () async {
      final c = await ready();
      await complete(c, emo, 4);
      expect(c.state.doneCount, 1);
      await Future<void>.delayed(const Duration(milliseconds: 5));
      await c.retakeAll();
      expect(c.state.doneCount, 0);
      expect(c.state.attempts.length, 1);
      expect(c.state.latest[emo], 63);
    });

    test('goals set, clamp, clear and persist', () async {
      final c = await ready();
      await c.setGoal(emo, 150);
      await c.setGoal(phy, 70);
      expect(c.state.goals, {emo: 100, phy: 70});
      await c.setGoal(emo, null);
      final c2 = await ready();
      expect(c2.state.goals, {phy: 70});
    });
  });
}
