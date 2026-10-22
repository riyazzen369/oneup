import 'focus.dart';
import 'scoring.dart';

/// Rule-based (not AI) one-sentence rationale for the #1 focus item.
String smartSuggestion(FocusItem f) {
  final name = f.dimension.label;
  final target = f.hasGoal ? 'your goal of ${f.target}' : 'the Thriving range (${f.target}+)';
  if (f.gap <= 0) {
    return '$name is at ${f.score}, already at or above $target, so keep nurturing what is working.';
  }
  return switch (f.band) {
    ScoreBand.needsAttention =>
      '$name is at ${f.score}, in the Needs Attention range and ${f.gap} points from $target, so a small daily step here could make a real difference.',
    ScoreBand.developing => '$name is at ${f.score} and developing, with ${f.gap} points to $target, which makes it your best next step.',
    ScoreBand.thriving =>
      '$name is at ${f.score} and thriving, ${f.gap} points from $target, so a little extra attention can lift it further.',
  };
}
