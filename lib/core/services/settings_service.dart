import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'secure_store.dart';

final themeModeProvider = StateNotifierProvider<ThemeModeNotifier, ThemeMode>((ref) {
  return ThemeModeNotifier(ref.read(secureStoreProvider));
});

class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  ThemeModeNotifier(this._store) : super(ThemeMode.system) {
    _load();
  }
  final SecureStore _store;

  Future<void> _load() async {
    final v = await _store.read(SecureStore.kTheme);
    state = ThemeMode.values.firstWhere((m) => m.name == v, orElse: () => ThemeMode.system);
  }

  Future<void> set(ThemeMode m) async {
    state = m;
    await _store.write(SecureStore.kTheme, m.name);
  }
}
