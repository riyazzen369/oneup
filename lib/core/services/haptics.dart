import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'secure_store.dart';

/// App-wide haptics. Respect the user's Profile → Haptics toggle (default on).
class Haptics {
  static bool enabled = true;
  static void light() {
    if (enabled) HapticFeedback.lightImpact();
  }

  static void selection() {
    if (enabled) HapticFeedback.selectionClick();
  }

  static void medium() {
    if (enabled) HapticFeedback.mediumImpact();
  }

  /// Success states (completion, booking, saved goal).
  static void success() => medium();

  /// Error / blocked states: heavy impact followed by a short vibrate pattern.
  static void error() {
    if (!enabled) return;
    HapticFeedback.heavyImpact();
    Future<void>.delayed(const Duration(milliseconds: 90), () {
      if (enabled) HapticFeedback.vibrate();
    });
  }

  /// Wraps a tap callback with a light impact (null stays null → disabled widgets stay disabled).
  static VoidCallback? tap(VoidCallback? f) => f == null
      ? null
      : () {
          light();
          f();
        };

  /// Wraps a value callback (chips, switches, checkboxes, segmented buttons) with a selection tick.
  static ValueChanged<T>? pick<T>(ValueChanged<T>? f) => f == null
      ? null
      : (v) {
          selection();
          f(v);
        };
}

final hapticsProvider = StateNotifierProvider<HapticsNotifier, bool>((ref) => HapticsNotifier(ref.read(secureStoreProvider)));

class HapticsNotifier extends StateNotifier<bool> {
  HapticsNotifier(this._store) : super(true) {
    _store.read(_k).then((v) => _apply(v != 'false'));
  }
  static const _k = 'haptics_enabled';
  final SecureStore _store;

  void _apply(bool v) {
    Haptics.enabled = v;
    state = v;
  }

  Future<void> set(bool v) async {
    _apply(v);
    if (v) Haptics.light();
    await _store.write(_k, '$v');
  }
}
