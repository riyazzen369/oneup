import 'dart:convert';

import 'package:flutter/material.dart' show IconData, Icons, Color;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/secure_store.dart';
import '../../core/theme/app_colors.dart';
import 'micro_tasks.dart';

/// Five mood options, lowest first.
enum Mood {
  low(Icons.mood_bad_rounded, 'Low', Color(0xFF8C9EFF)),
  meh(Icons.sentiment_dissatisfied_rounded, 'Meh', Color(0xFF64B5F6)),
  okay(Icons.sentiment_neutral_rounded, 'Okay', Color(0xFF4DD0C1)),
  good(Icons.sentiment_satisfied_rounded, 'Good', Color(0xFF81C784)),
  great(Icons.sentiment_very_satisfied_rounded, 'Great', Color(0xFFFFD54F));

  const Mood(this.icon, this.label, this.color);

  /// Emoji-style face icon (renders identically on every device).
  final IconData icon;
  final String label;
  final Color color;
}

/// Local calendar day key (device time zone), e.g. 2026-11-02.
String dayKey(DateTime t) =>
    '${t.year.toString().padLeft(4, '0')}-${t.month.toString().padLeft(2, '0')}-${t.day.toString().padLeft(2, '0')}';

DateTime _day(DateTime t) => DateTime(t.year, t.month, t.day);

class DayEntry {
  const DayEntry({this.mood, this.tag, this.done = false, this.swaps = 0});
  final Mood? mood;
  final String? tag;
  final bool done;
  final int swaps;

  bool get counts => mood != null || done;

  DayEntry copyWith({Mood? mood, String? tag, bool clearTag = false, bool? done, int? swaps}) => DayEntry(
        mood: mood ?? this.mood,
        tag: clearTag ? null : (tag ?? this.tag),
        done: done ?? this.done,
        swaps: swaps ?? this.swaps,
      );

  Map<String, dynamic> toJson() => {'mood': mood?.name, 'tag': tag, 'done': done, 'swaps': swaps};
  factory DayEntry.fromJson(Map<String, dynamic> j) => DayEntry(
        mood: j['mood'] == null ? null : Mood.values.byName(j['mood'] as String),
        tag: j['tag'] as String?,
        done: j['done'] as bool? ?? false,
        swaps: j['swaps'] as int? ?? 0,
      );
}

/// Weakest dimension: full scores first, else quick snapshot, else rotate by day.
WellnessDimension ritualDimension(Map<WellnessDimension, int> full, Map<WellnessDimension, int>? quick, DateTime today) {
  WellnessDimension? lowest(Map<WellnessDimension, int> m) => m.isEmpty
      ? null
      : (m.entries.toList()..sort((a, b) => a.value != b.value ? a.value.compareTo(b.value) : a.key.index.compareTo(b.key.index)))
          .first
          .key;
  return lowest(full) ?? lowest(quick ?? const {}) ?? WellnessDimension.values[_day(today).difference(DateTime(2026)).inDays.abs() % 8];
}

/// Deterministic task for the day; each swap moves to the next task in the list.
String ritualTask(WellnessDimension d, DateTime today, int swaps) {
  final list = microTasks[d]!;
  return list[(_day(today).difference(DateTime(2026)).inDays.abs() + swaps) % list.length];
}

/// Consecutive days with a check-in or a done task, ending today (or yesterday if today is still open).
int ritualStreak(Map<String, DayEntry> days, DateTime today) {
  var d = _day(today);
  if (!(days[dayKey(d)]?.counts ?? false)) d = DateTime(d.year, d.month, d.day - 1);
  var n = 0;
  while (days[dayKey(d)]?.counts ?? false) {
    n++;
    d = DateTime(d.year, d.month, d.day - 1);
  }
  return n;
}

const maxSwapsPerDay = 1;

class RitualState {
  const RitualState({this.days = const {}, this.loaded = false});
  final Map<String, DayEntry> days;
  final bool loaded;
  DayEntry on(DateTime t) => days[dayKey(t)] ?? const DayEntry();
}

class RitualController extends StateNotifier<RitualState> {
  RitualController(this._store, {DateTime Function()? clock})
      : now = clock ?? DateTime.now,
        super(const RitualState()) {
    _ready = _load();
  }
  static const key = 'ritual_v1';
  static const _keepDays = 60;
  final SecureStore _store;
  final DateTime Function() now;
  late final Future<void> _ready;
  Future<void> get ready => _ready;

  Future<void> _load() async {
    final s = await _store.read(key);
    var days = <String, DayEntry>{};
    if (s != null) {
      try {
        days = {for (final e in (jsonDecode(s) as Map).entries) e.key as String: DayEntry.fromJson(e.value as Map<String, dynamic>)};
      } catch (_) {}
    }
    if (mounted) state = RitualState(days: days, loaded: true);
  }

  Future<void> _update(DayEntry Function(DayEntry) f) async {
    await _ready;
    final k = dayKey(now());
    final days = Map<String, DayEntry>.of(state.days)..[k] = f(state.days[k] ?? const DayEntry());
    final keys = days.keys.toList()..sort();
    while (keys.length > _keepDays) {
      days.remove(keys.removeAt(0));
    }
    state = RitualState(days: days, loaded: true);
    await _store.write(key, jsonEncode({for (final e in days.entries) e.key: e.value.toJson()}));
  }

  Future<void> setMood(Mood m) => _update((e) => e.copyWith(mood: m));

  /// Optional one-word tag: trimmed, first word only, max 20 chars; empty clears it.
  Future<void> setTag(String raw) {
    final w = raw.trim().split(RegExp(r'\s+')).first;
    final t = w.length > 20 ? w.substring(0, 20) : w;
    return _update((e) => t.isEmpty ? e.copyWith(clearTag: true) : e.copyWith(tag: t));
  }

  Future<void> toggleDone() => _update((e) => e.copyWith(done: !e.done));

  /// Returns false when today's swap is already used (or the task is done).
  Future<bool> swap() async {
    await _ready;
    final e = state.on(now());
    if (e.swaps >= maxSwapsPerDay || e.done) return false;
    await _update((e) => e.copyWith(swaps: e.swaps + 1));
    return true;
  }
}

final ritualClockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

final ritualProvider = StateNotifierProvider<RitualController, RitualState>(
    (ref) => RitualController(ref.read(secureStoreProvider), clock: ref.read(ritualClockProvider)));
