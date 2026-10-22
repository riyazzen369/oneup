import 'package:flutter_test/flutter_test.dart';
import 'package:oneup/core/theme/app_colors.dart';
import 'package:oneup/features/assess/data/question_bank.dart';
import 'package:oneup/features/assess/domain/scoring.dart';

void main() {
  final emo = questionsFor(WellnessDimension.emotional);
  Map<String, int> all(int v) => {for (final q in emo) q.id: v};

  test('bank: 72 items, 9 per dimension = 8 scored + 1 open text, 2-3 reverse, unique ids', () {
    expect(questionBank.length, 72);
    expect(questionBank.map((q) => q.id).toSet().length, 72);
    for (final d in WellnessDimension.values) {
      final qs = questionsFor(d);
      expect(qs.length, 9, reason: d.label);
      expect(scoredQuestionsFor(d).length, 8, reason: d.label);
      expect(qs.last.isOpenText, isTrue, reason: d.label);
      expect(qs.last.reverse, isFalse);
      expect(qs.last.text, startsWith('In a line or two, describe how you feel about your'));
      expect(qs.where((q) => q.reverse).length, inInclusiveRange(2, 3), reason: d.label);
    }
  });

  test('emotional reverse items are 3 and 6', () {
    expect([
      for (final q in emo)
        if (q.reverse) q.order
    ], [
      3,
      6
    ]);
  });

  test('worked example: all 4s -> S=6*4+2*2=28 -> round(20/32*100)=63 Developing', () {
    expect(scoreDimension(emo, all(4)), 63);
    expect(bandFor(63), ScoreBand.developing);
  });

  test('open-text item is ignored by scoring', () {
    final a = all(4)..remove(emo.last.id);
    expect(scoreDimension(emo, a), 63);
  });

  test('best and worst answers hit 100 and 0', () {
    final best = {for (final q in emo) q.id: q.reverse ? 1 : 5};
    final worst = {for (final q in emo) q.id: q.reverse ? 5 : 1};
    expect(scoreDimension(emo, best), 100);
    expect(scoreDimension(emo, worst), 0);
  });

  test('all neutral (3) -> 50', () => expect(scoreDimension(emo, all(3)), 50));

  test('missing or out-of-range answer throws', () {
    expect(() => scoreDimension(emo, {}), throwsArgumentError);
    expect(() => scoreDimension(emo, all(6)), throwsArgumentError);
  });

  test('band boundaries', () {
    expect(bandFor(0), ScoreBand.needsAttention);
    expect(bandFor(40), ScoreBand.needsAttention);
    expect(bandFor(41), ScoreBand.developing);
    expect(bandFor(70), ScoreBand.developing);
    expect(bandFor(71), ScoreBand.thriving);
    expect(bandFor(100), ScoreBand.thriving);
  });

  test('overall only when all 8 done', () {
    expect(overallScore({for (var i = 0; i < 7; i++) i: 50}), isNull);
    expect(overallScore({for (var i = 0; i < 8; i++) i: i * 10}), 35);
  });
}
