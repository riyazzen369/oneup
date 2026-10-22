import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/services/secure_store.dart';
import 'game_catalog.dart';

/// Best scores, stored only on this device. Gratitude Garden keeps a running total instead.
final gameScoresProvider = StateNotifierProvider<GameScores, Map<String, int>>((ref) => GameScores(ref.read(secureStoreProvider)));

class GameScores extends StateNotifier<Map<String, int>> {
  GameScores(this._store) : super(const {}) {
    _load();
  }
  final SecureStore _store;
  static String key(String id) => 'game_best_$id';

  Future<void> _load() async {
    final m = <String, int>{};
    for (final g in games) {
      final v = int.tryParse(await _store.read(key(g.id)) ?? '');
      if (v != null) m[g.id] = v;
    }
    if (mounted) state = {...m, ...state};
  }

  /// Records a result; returns true if it is a new best.
  Future<bool> record(String id, int score, {bool accumulate = false}) async {
    final old = state[id] ?? 0;
    final next = accumulate ? old + score : (score > old ? score : old);
    final isBest = accumulate ? score > 0 : score > old;
    if (next != old || !state.containsKey(id)) {
      state = {...state, id: next};
      await _store.write(key(id), '$next');
    }
    return isBest;
  }
}
