import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/secure_store.dart';
import '../../core/theme/app_colors.dart';
import '../activity/activity.dart';
import '../assess/data/assessment_models.dart';
import '../assess/domain/assessment_controller.dart';
import '../quick/quick_check.dart';
import '../ritual/micro_tasks.dart';
import '../ritual/ritual.dart';

const reportDisclaimer = 'OneUp is for wellness awareness, not medical advice or diagnosis.';

/// Monday 00:00 (local) of the week containing [d].
DateTime weekStartOf(DateTime d) => DateTime(d.year, d.month, d.day - (d.weekday - 1));

/// The report currently "ready": this week's on Sunday, otherwise last week's.
DateTime currentReportWeek(DateTime now) {
  final ws = weekStartOf(now);
  return now.weekday == DateTime.sunday ? ws : DateTime(ws.year, ws.month, ws.day - 7);
}

enum MoodTrend { up, steady, down, none }

/// A frozen weekly summary. Only counts and labels the user already sees in the app.
class WeeklyReport {
  const WeeklyReport({
    required this.weekStart,
    this.ritualsDone = 0,
    this.checkIns = 0,
    this.streak = 0,
    this.moods = const [null, null, null, null, null, null, null],
    this.active = const {},
    this.lessons = 0,
    this.games = 0,
    this.scoreChanges = const {},
    this.focus,
  });
  final DateTime weekStart;
  final int ritualsDone, checkIns, streak, lessons, games;

  /// Mood per day Mon..Sun (null = no check-in).
  final List<Mood?> moods;

  /// Activities per dimension this week (ritual steps, lessons, games), most first.
  final Map<WellnessDimension, int> active;

  /// Score delta for dimensions reassessed this week (vs. the previous attempt).
  final Map<WellnessDimension, int> scoreChanges;
  final WellnessDimension? focus;

  DateTime get weekEnd => DateTime(weekStart.year, weekStart.month, weekStart.day + 6);
  bool get isEmpty => checkIns == 0 && ritualsDone == 0 && active.isEmpty && scoreChanges.isEmpty;
  String get id => dayKey(weekStart);

  MoodTrend get moodTrend {
    final v = [
      for (final m in moods)
        if (m != null) m.index
    ];
    if (v.length < 2) return MoodTrend.none;
    final h = v.length ~/ 2;
    double avg(List<int> x) => x.reduce((a, b) => a + b) / x.length;
    final d = avg(v.sublist(v.length - h)) - avg(v.sublist(0, h));
    return d > 0.4 ? MoodTrend.up : (d < -0.4 ? MoodTrend.down : MoodTrend.steady);
  }

  Map<String, dynamic> toJson() => {
        'w': id,
        'r': ritualsDone,
        'c': checkIns,
        's': streak,
        'm': [for (final m in moods) m?.name],
        'a': {for (final e in active.entries) e.key.name: e.value},
        'l': lessons,
        'g': games,
        'sc': {for (final e in scoreChanges.entries) e.key.name: e.value},
        'f': focus?.name,
      };

  static WeeklyReport fromJson(Map<String, dynamic> j) {
    WellnessDimension dim(String s) => WellnessDimension.values.byName(s);
    return WeeklyReport(
      weekStart: DateTime.parse(j['w'] as String),
      ritualsDone: j['r'] as int? ?? 0,
      checkIns: j['c'] as int? ?? 0,
      streak: j['s'] as int? ?? 0,
      moods: [for (final m in (j['m'] as List? ?? List.filled(7, null))) m == null ? null : Mood.values.byName(m as String)],
      active: {for (final e in (j['a'] as Map? ?? {}).entries) dim(e.key as String): e.value as int},
      lessons: j['l'] as int? ?? 0,
      games: j['g'] as int? ?? 0,
      scoreChanges: {for (final e in (j['sc'] as Map? ?? {}).entries) dim(e.key as String): e.value as int},
      focus: j['f'] == null ? null : dim(j['f'] as String),
    );
  }
}

WeeklyReport buildWeeklyReport({
  required DateTime weekStart,
  required Map<String, DayEntry> days,
  required List<ActivityEvent> events,
  required List<DimAttempt> attempts,
  Map<WellnessDimension, int>? latestScores,
}) {
  final end = DateTime(weekStart.year, weekStart.month, weekStart.day + 7);
  bool inWeek(DateTime t) => !t.isBefore(weekStart) && t.isBefore(end);
  final moods = <Mood?>[];
  var done = 0, checkIns = 0;
  for (var i = 0; i < 7; i++) {
    final e = days[dayKey(DateTime(weekStart.year, weekStart.month, weekStart.day + i))];
    moods.add(e?.mood);
    if (e?.mood != null) checkIns++;
    if (e?.done ?? false) done++;
  }
  final active = <WellnessDimension, int>{};
  var lessons = <String>{}, games = 0;
  for (final e in events.where((e) => inWeek(e.at))) {
    active[e.dimension] = (active[e.dimension] ?? 0) + 1;
    if (e.kind == ActivityKind.lesson) lessons.add(e.ref.split(':').elementAt(1));
    if (e.kind == ActivityKind.game) games++;
  }
  final sorted = Map.fromEntries(active.entries.toList()..sort((a, b) => b.value.compareTo(a.value)));
  // Score change: newest attempt in the week vs. the newest attempt before the week.
  final changes = <WellnessDimension, int>{};
  for (final d in WellnessDimension.values) {
    final mine = attempts.where((a) => a.dimension == d).toList()..sort((a, b) => b.completedAt.compareTo(a.completedAt));
    final inside = mine.where((a) => inWeek(a.completedAt)).toList();
    final before = mine.where((a) => a.completedAt.isBefore(weekStart)).toList();
    if (inside.isNotEmpty && before.isNotEmpty) changes[d] = inside.first.score - before.first.score;
  }
  // Gentle focus: the lowest-scored dimension that got little attention; otherwise the least active one.
  WellnessDimension? focus;
  final scores = latestScores ?? const {};
  final quiet = WellnessDimension.values.where((d) => (active[d] ?? 0) <= 1).toList();
  if (scores.isNotEmpty) {
    final cands = (quiet.where(scores.containsKey).toList()..sort((a, b) => scores[a]!.compareTo(scores[b]!)));
    focus = cands.isNotEmpty ? cands.first : null;
  }
  focus ??= quiet.isNotEmpty ? quiet.first : WellnessDimension.values.first;
  return WeeklyReport(
    weekStart: weekStart,
    ritualsDone: done,
    checkIns: checkIns,
    streak: ritualStreak(days, DateTime(weekStart.year, weekStart.month, weekStart.day + 6)),
    moods: moods,
    active: sorted,
    lessons: lessons.length,
    games: games,
    scoreChanges: changes,
    focus: focus,
  );
}

/// A small, non-clinical idea for next week, from the existing ritual task list.
String focusIdea(WellnessDimension d) => microTasks[d]!.first;

class ReportsState {
  const ReportsState({this.reports = const [], this.seen, this.loaded = false});

  /// Newest first; at most [ReportsController.keep].
  final List<WeeklyReport> reports;
  final String? seen;
  final bool loaded;
  WeeklyReport? get latest => reports.isEmpty ? null : reports.first;
  bool get unseen => latest != null && latest!.id != seen;
}

class ReportsController extends StateNotifier<ReportsState> {
  ReportsController(this._ref, this._store, this.now) : super(const ReportsState()) {
    ready = _load();
  }
  static const key = 'weekly_reports_v1';
  static const keep = 8;
  final Ref _ref;
  final SecureStore _store;
  final DateTime Function() now;
  late final Future<void> ready;

  Future<void> _load() async {
    var list = <WeeklyReport>[];
    String? seen;
    try {
      final s = await _store.read(key);
      if (s != null) {
        final j = jsonDecode(s) as Map<String, dynamic>;
        list = [for (final r in j['reports'] as List) WeeklyReport.fromJson(r as Map<String, dynamic>)];
        seen = j['seen'] as String?;
      }
    } catch (_) {}
    if (mounted) state = ReportsState(reports: list, seen: seen, loaded: true);
  }

  Future<void> _save() => _store.write(
      key,
      jsonEncode({
        'reports': [for (final r in state.reports) r.toJson()],
        'seen': state.seen
      }));

  /// Builds (or refreshes, while its week is still running) the report that is currently ready.
  Future<WeeklyReport> refresh() async {
    await ready;
    await _ref.read(ritualProvider.notifier).ready;
    await _ref.read(activityProvider.notifier).ready;
    await _ref.read(assessmentProvider.notifier).ready;
    await _ref.read(quickCheckProvider.notifier).ready;
    if (!mounted) return state.latest ?? WeeklyReport(weekStart: currentReportWeek(now()));
    final t = now();
    final ws = currentReportWeek(t);
    final existing = state.reports.where((r) => r.weekStart == ws).firstOrNull;
    final weekOver = !t.isBefore(DateTime(ws.year, ws.month, ws.day + 7));
    if (existing != null && weekOver) return existing; // frozen once the week has ended
    final a = _ref.read(assessmentProvider);
    final r = buildWeeklyReport(
      weekStart: ws,
      days: _ref.read(ritualProvider).days,
      events: _ref.read(activityProvider).events,
      attempts: a.attempts,
      latestScores: {...?_ref.read(quickCheckProvider).latest?.scores, ...a.latest},
    );
    final list = [r, ...state.reports.where((x) => x.weekStart != ws)]..sort((x, y) => y.weekStart.compareTo(x.weekStart));
    state = ReportsState(reports: list.take(keep).toList(), seen: state.seen, loaded: true);
    await _save();
    return r;
  }

  Future<void> markSeen(WeeklyReport r) async {
    if (state.seen == r.id) return;
    state = ReportsState(reports: state.reports, seen: r.id, loaded: true);
    await _save();
  }
}

final reportsProvider = StateNotifierProvider<ReportsController, ReportsState>(
    (ref) => ReportsController(ref, ref.read(secureStoreProvider), ref.read(ritualClockProvider)));
