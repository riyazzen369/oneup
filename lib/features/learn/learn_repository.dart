import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/config/env.dart';
import '../../core/services/secure_store.dart';
import 'learn_models.dart';

const learnAsset = 'assets/content/learn.json';

final learnLibraryProvider = FutureProvider<LearnLibrary>(
    (ref) async => LearnLibrary.fromJson(jsonDecode(await rootBundle.loadString(learnAsset)) as Map<String, dynamic>));

final learnProgressProvider = StateNotifierProvider<LearnProgress, Set<String>>((ref) => LearnProgress(ref.read(secureStoreProvider)));

/// Completed lesson ids. Stored locally; mirrored to `learn_progress` when signed in.
class LearnProgress extends StateNotifier<Set<String>> {
  LearnProgress(this._store, {this.remote = true}) : super(const {}) {
    _load();
  }
  final SecureStore _store;
  final bool remote;
  static const key = 'learn_done_v1';

  SupabaseClient? get _client {
    if (!remote || !Env.isConfigured) return null;
    final c = Supabase.instance.client;
    return c.auth.currentUser == null ? null : c;
  }

  Future<void> _load() async {
    final raw = await _store.read(key);
    final local = raw == null ? <String>{} : Set<String>.from(jsonDecode(raw) as List);
    if (mounted) state = {...local, ...state};
    final c = _client;
    if (c == null) return;
    try {
      final rows = await c.from('learn_progress').select('lesson_id').timeout(const Duration(seconds: 8));
      final server = {for (final r in rows) r['lesson_id'] as String};
      if (mounted && !server.every(state.contains)) {
        state = {...state, ...server};
        await _save();
      }
    } catch (_) {}
  }

  Future<void> _save() => _store.write(key, jsonEncode(state.toList()..sort()));

  Future<void> setDone(String id, bool done) async {
    if (state.contains(id) == done) return;
    state = done ? {...state, id} : ({...state}..remove(id));
    await _save();
    final c = _client;
    if (c == null) return;
    try {
      if (done) {
        await c.from('learn_progress').upsert({'user_id': c.auth.currentUser!.id, 'lesson_id': id});
      } else {
        await c.from('learn_progress').delete().eq('lesson_id', id);
      }
    } catch (_) {}
  }
}
