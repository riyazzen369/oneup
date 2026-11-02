import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/secure_store.dart';
import '../../core/theme/app_colors.dart';
import '../ritual/ritual.dart';

/// Living wheel: a purely visual layer of recent activity per dimension.
/// It NEVER changes scores; it only drives slice glow / growth on Home.
enum ActivityKind { ritual, lesson, game }

class ActivityEvent {
  const ActivityEvent(this.dimension, this.kind, this.at, this.ref);
  final WellnessDimension dimension;
  final ActivityKind kind;
  final DateTime at;

  /// Dedupe key, e.g. `ritual:2026-11-02`, `lesson:<id>`, `game:<id>:2026-11-02`.
  final String ref;

  Map<String, dynamic> toJson() => {'d': dimension.name, 'k': kind.name, 'at': at.toIso8601String(), 'r': ref};
  static ActivityEvent? fromJson(Map<String, dynamic> j) {
    try {
      return ActivityEvent(WellnessDimension.values.byName(j['d'] as String), ActivityKind.values.byName(j['k'] as String),
          DateTime.parse(j['at'] as String), j['r'] as String);
    } catch (_) {
      return null;
    }
  }
}

const glowWindow = Duration(days: 7);

/// Events are kept a little longer than the glow so the weekly report can still read last week.
const keepWindow = Duration(days: 21);

/// Glow 0..1 per dimension: each event adds weight that fades linearly to zero over 7 days;
/// three fresh events saturate a slice.
Map<WellnessDimension, double> activityGlow(List<ActivityEvent> events, DateTime now) {
  final sum = <WellnessDimension, double>{};
  for (final e in events) {
    final age = now.difference(e.at);
    if (age.isNegative || age >= glowWindow) continue;
    sum[e.dimension] = (sum[e.dimension] ?? 0) + (1 - age.inMinutes / glowWindow.inMinutes);
  }
  return {for (final en in sum.entries) en.key: (en.value / 3).clamp(0.0, 1.0)};
}

class ActivityState {
  const ActivityState({this.events = const [], this.seenAt, this.loaded = false});
  final List<ActivityEvent> events;

  /// Time of the newest boost already celebrated on Home (pulse + "+1" badge).
  final DateTime? seenAt;
  final bool loaded;

  /// The newest boost the user hasn't seen celebrated yet.
  ActivityEvent? get unseen {
    if (events.isEmpty) return null;
    final last = events.last;
    return seenAt == null || last.at.isAfter(seenAt!) ? last : null;
  }
}

class ActivityController extends StateNotifier<ActivityState> {
  ActivityController(this._store, {DateTime Function()? clock})
      : now = clock ?? DateTime.now,
        super(const ActivityState()) {
    _ready = _load();
  }
  static const key = 'wheel_activity_v1';
  static const maxEvents = 200;
  final SecureStore _store;
  final DateTime Function() now;
  late final Future<void> _ready;
  Future<void> get ready => _ready;

  Future<void> _load() async {
    var events = <ActivityEvent>[];
    DateTime? seen;
    try {
      final s = await _store.read(key);
      if (s != null) {
        final j = jsonDecode(s) as Map<String, dynamic>;
        events = [for (final e in (j['events'] as List? ?? [])) ActivityEvent.fromJson(e as Map<String, dynamic>)]
            .whereType<ActivityEvent>()
            .toList();
        seen = j['seen'] == null ? null : DateTime.tryParse(j['seen'] as String);
      }
    } catch (_) {}
    if (mounted) state = ActivityState(events: events, seenAt: seen, loaded: true);
  }

  Future<void> _save() => _store.write(
      key,
      jsonEncode({
        'events': [for (final e in state.events) e.toJson()],
        'seen': state.seenAt?.toIso8601String()
      }));

  /// Records one activity; ignored when [ref] was already logged. Returns true when added.
  Future<bool> log(WellnessDimension d, ActivityKind kind, String ref) async {
    await _ready;
    if (state.events.any((e) => e.ref == ref)) return false;
    final t = now();
    // Drop events older than the glow window, and cap size.
    final kept = [
      for (final e in state.events)
        if (t.difference(e.at) < glowWindow) e,
      ActivityEvent(d, kind, t, ref)
    ];
    state =
        ActivityState(events: kept.length > maxEvents ? kept.sublist(kept.length - maxEvents) : kept, seenAt: state.seenAt, loaded: true);
    await _save();
    return true;
  }

  /// Removes a logged activity (e.g. a ritual step or lesson un-ticked).
  Future<void> unlog(String ref) async {
    await _ready;
    if (!state.events.any((e) => e.ref == ref)) return;
    state = ActivityState(events: [
      for (final e in state.events)
        if (e.ref != ref) e
    ], seenAt: state.seenAt, loaded: true);
    await _save();
  }

  Future<void> markSeen() async {
    await _ready;
    final u = state.unseen;
    if (u == null) return;
    state = ActivityState(events: state.events, seenAt: u.at, loaded: true);
    await _save();
  }
}

final activityProvider = StateNotifierProvider<ActivityController, ActivityState>(
    (ref) => ActivityController(ref.read(secureStoreProvider), clock: ref.read(ritualClockProvider)));

String ritualRef(DateTime day) => 'ritual:${dayKey(day)}';
String lessonRef(String id, WellnessDimension d) => 'lesson:$id:${d.name}';
String gameRef(String id, DateTime day) => 'game:$id:${dayKey(day)}';
