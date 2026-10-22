import '../../../core/theme/app_colors.dart';
import '../data/assessment_models.dart';

/// Pure history/goal helpers (unit-tested).

List<DimAttempt> _sortedDesc(Iterable<DimAttempt> a) => a.toList()..sort((x, y) => y.completedAt.compareTo(x.completedAt));

/// Most recent score per dimension.
Map<WellnessDimension, int> latestScores(List<DimAttempt> attempts) {
  final out = <WellnessDimension, int>{};
  for (final a in _sortedDesc(attempts)) {
    out.putIfAbsent(a.dimension, () => a.score);
  }
  return out;
}

/// Second most recent score per dimension (the "Previous" radar line).
Map<WellnessDimension, int> previousScores(List<DimAttempt> attempts) {
  final seen = <WellnessDimension, int>{};
  final out = <WellnessDimension, int>{};
  for (final a in _sortedDesc(attempts)) {
    final n = (seen[a.dimension] ?? 0) + 1;
    seen[a.dimension] = n;
    if (n == 2) out[a.dimension] = a.score;
  }
  return out;
}

/// Oldest → newest attempts for one dimension (line chart).
List<DimAttempt> historyFor(List<DimAttempt> attempts, WellnessDimension d) =>
    attempts.where((a) => a.dimension == d).toList()..sort((x, y) => x.completedAt.compareTo(y.completedAt));

/// Union of local and remote attempts, de-duplicated by id (remote wins).
List<DimAttempt> mergeAttempts(List<DimAttempt> local, List<DimAttempt> remote) {
  final m = {for (final a in local) a.id: a};
  for (final a in remote) {
    m[a.id] = a;
  }
  return _sortedDesc(m.values);
}

/// Dimensions completed since the current cycle started (hub "done" state).
Set<WellnessDimension> doneInCycle(List<DimAttempt> attempts, DateTime cycleStart) => {
      for (final a in attempts)
        if (!a.completedAt.isBefore(cycleStart)) a.dimension
    };

/// The [n] lowest-scoring dimensions, lowest first (ties keep wheel order).
List<MapEntry<WellnessDimension, int>> lowestDimensions(Map<WellnessDimension, int> scores, [int n = 2]) {
  final e = scores.entries.toList()..sort((a, b) => a.value != b.value ? a.value.compareTo(b.value) : a.key.index.compareTo(b.key.index));
  return e.take(n).toList();
}

/// Goals are whole numbers 0–100.
int clampGoal(num v) => v.round().clamp(0, 100);

/// Consultant escalation (spec): suggest a professional only when the dimension was
/// "Needs Attention" in the latest 2 or more attempts. (Users can always open Consult themselves.)
bool shouldEscalate(List<DimAttempt> attempts, WellnessDimension d) {
  final h = historyFor(attempts, d);
  if (h.length < 2) return false;
  return h.reversed.take(2).every((a) => a.score <= 40);
}
