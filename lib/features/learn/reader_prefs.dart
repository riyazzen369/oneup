import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/services/secure_store.dart';

enum ReaderTheme { app, sepia, night }

class ReaderPrefsState {
  const ReaderPrefsState({this.scale = 1.0, this.theme = ReaderTheme.app});
  final double scale;
  final ReaderTheme theme;
  ReaderPrefsState copyWith({double? scale, ReaderTheme? theme}) =>
      ReaderPrefsState(scale: scale ?? this.scale, theme: theme ?? this.theme);
}

final readerPrefsProvider = StateNotifierProvider<ReaderPrefs, ReaderPrefsState>((ref) => ReaderPrefs(ref.read(secureStoreProvider)));

/// Font size + reading theme, stored on device only.
class ReaderPrefs extends StateNotifier<ReaderPrefsState> {
  ReaderPrefs(this._store) : super(const ReaderPrefsState()) {
    _load();
  }
  final SecureStore _store;
  static const key = 'reader_prefs_v1';
  static const minScale = 0.8, maxScale = 1.6, step = 0.1;

  Future<void> _load() async {
    try {
      final raw = await _store.read(key);
      if (raw == null || !mounted) return;
      final j = jsonDecode(raw) as Map<String, dynamic>;
      state = ReaderPrefsState(
        scale: ((j['scale'] as num?)?.toDouble() ?? 1.0).clamp(minScale, maxScale),
        theme: ReaderTheme.values.asNameMap()[j['theme']] ?? ReaderTheme.app,
      );
    } catch (_) {}
  }

  Future<void> _save() => _store.write(key, jsonEncode({'scale': state.scale, 'theme': state.theme.name}));

  bool get canSmaller => state.scale > minScale + 0.001;
  bool get canLarger => state.scale < maxScale - 0.001;

  Future<void> bump(int dir) async {
    final s = ((state.scale + dir * step) * 10).round() / 10;
    state = state.copyWith(scale: s.clamp(minScale, maxScale));
    await _save();
  }

  Future<void> cycleTheme() async {
    state = state.copyWith(theme: ReaderTheme.values[(state.theme.index + 1) % ReaderTheme.values.length]);
    await _save();
  }
}

/// Last scroll position per lesson (0..1), stored on device only.
class ReadingPositions {
  ReadingPositions(this._store);
  final SecureStore _store;
  static const key = 'learn_pos_v1';
  Map<String, double>? _cache;

  Future<Map<String, double>> _all() async {
    if (_cache != null) return _cache!;
    try {
      final raw = await _store.read(key);
      _cache = raw == null ? {} : (jsonDecode(raw) as Map<String, dynamic>).map((k, v) => MapEntry(k, (v as num).toDouble()));
    } catch (_) {
      _cache = {};
    }
    return _cache!;
  }

  Future<double> get(String id) async => (await _all())[id] ?? 0;

  Future<void> set(String id, double f) async {
    final m = await _all();
    m[id] = double.parse(f.clamp(0.0, 1.0).toStringAsFixed(3));
    await _store.write(key, jsonEncode(m));
  }
}

final readingPositionsProvider = Provider<ReadingPositions>((ref) => ReadingPositions(ref.read(secureStoreProvider)));
