import '../../../core/theme/app_colors.dart';
import 'scoring.dart';

/// Default target when the user hasn't set a goal (start of the "Thriving" band).
const kDefaultTarget = 71;

class FocusItem {
  const FocusItem(this.dimension, this.score, this.target, this.hasGoal);
  final WellnessDimension dimension;
  final int score;
  final int target;
  final bool hasGoal;
  int get gap => target - score;
  ScoreBand get band => bandFor(score);
}

/// Ranks assessed dimensions for focus:
/// 1) Needs Attention band first, 2) larger gap (goal − current, or 70 − current), 3) lower score, 4) wheel order.
List<FocusItem> rankFocus(Map<WellnessDimension, int> latest, Map<WellnessDimension, int> goals, {int top = 3}) {
  final items = [
    for (final e in latest.entries) FocusItem(e.key, e.value, goals[e.key] ?? kDefaultTarget, goals.containsKey(e.key)),
  ];
  items.sort((a, b) {
    final na = a.band == ScoreBand.needsAttention ? 0 : 1, nb = b.band == ScoreBand.needsAttention ? 0 : 1;
    if (na != nb) return na.compareTo(nb);
    if (a.gap != b.gap) return b.gap.compareTo(a.gap);
    if (a.score != b.score) return a.score.compareTo(b.score);
    return a.dimension.index.compareTo(b.dimension.index);
  });
  return items.take(top).toList();
}
