import '../data/question_bank.dart';

enum ScoreBand {
  needsAttention('Needs Attention', 'This area could use some care. Small steps help.'),
  developing('Developing', "You're building here. Keep going."),
  thriving('Thriving', 'This is a strength. Keep nurturing it.');

  const ScoreBand(this.label, this.guidance);
  final String label;
  final String guidance;
  String get dbValue => switch (this) {
        ScoreBand.needsAttention => 'needs_attention',
        ScoreBand.developing => 'developing',
        ScoreBand.thriving => 'thriving',
      };
}

/// Agreed formula:
///   v' = 6 - v for reverse-scored items, else v
///   S  = sum(v') over the 8 scored items (8..40); the open-text reflection is not scored
///   score = round((S - 8) / 32 * 100)
int scoreDimension(List<Question> all, Map<String, int> answers) {
  final qs = all.where((q) => !q.isOpenText).toList();
  if (qs.isEmpty) throw ArgumentError('No questions');
  var s = 0;
  for (final q in qs) {
    final v = answers[q.id];
    if (v == null || v < 1 || v > 5) throw ArgumentError('Missing/invalid answer for ${q.id}');
    s += q.reverse ? 6 - v : v;
  }
  final min = qs.length, range = qs.length * 4;
  return ((s - min) / range * 100).round();
}

/// Bands (per companion spec): 0–40 Needs Attention, 41–70 Developing, 71–100 Thriving.
ScoreBand bandFor(int score) => score <= 40 ? ScoreBand.needsAttention : (score <= 70 ? ScoreBand.developing : ScoreBand.thriving);

/// Overall = average of the 8 dimension scores; null until all 8 are done.
int? overallScore(Map<Object, int> scores) => scores.length < 8 ? null : (scores.values.reduce((a, b) => a + b) / scores.length).round();
